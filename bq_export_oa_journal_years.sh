#!/bin/bash
#
# populates the postgres table oa_issn_l_years

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="journals.tmp_oa_issn_l_years_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    'select distinct journal_issn_l as issn_l, year from unpaywall.api_live where journal_is_oa and journal_issn_l is not null and year is not null;'

# extract the temp table to CSV and delete the temp table

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_oa_issn_l_years_$RANDOM.csv"

bq extract \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --format=csv \
    $bq_temp_table \
    $gcs_csv

bq rm -f \
    --project_id='unpaywall-bhd' \
    $bq_temp_table

# download the CSV and delete the remote file

workdir=$(mktemp -d)
local_csv=$workdir/oa_issn_l_years.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# overwrite pg table

csv_lines=$(wc -l $local_csv | cut -f1 -d' ')

if [ $csv_lines -lt "100000" ]; then
    echo "expected at least 100K lines in $local_csv but got $csv_lines. quitting."
    exit 1
fi

echo updating pg oa_issn_l_years

psql $DATABASE_URL <<SQL
begin;

truncate oa_issn_l_years;
\\copy oa_issn_l_years from $local_csv csv header

commit;
SQL
