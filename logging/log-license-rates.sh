#!/bin/bash
#
# records the current proportion of articles with licenses in their best oa locations

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="unpaywall.tmp_articles_by_license_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    'select sum(case when best_oa_location.license is not null then 1 else 0 end) * 1.0 / count(1) as proportion_of_dois_with_license from unpaywall.api_live;'

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_articles_by_license_$RANDOM.csv"

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
local_csv=$workdir/proportion_of_dois_with_license.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert counts

echo updating pg logs.num_articles_by_time_oa_status

psql $DATABASE_URL <<SQL
create temp table tmp_proportion_of_dois_with_license (proportion_of_dois_with_license real);

\\copy tmp_proportion_of_dois_with_license from $local_csv csv header

insert into logs.num_articles_by_time_oa_status (
    select now(), proportion_of_dois_with_license from tmp_proportion_of_dois_with_license
);
SQL
