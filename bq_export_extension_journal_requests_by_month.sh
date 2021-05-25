#!/bin/bash
#
# populates the postgres table extension_journal_requests_by_month from bigquery

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="journals.tmp_extension_journal_requests_by_month_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    'select month, issn_l, requests from unpaywall.extension_journal_requests_by_month ;'

# extract the table to CSV and delete the temp table

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_extension_journal_requests_by_month_$RANDOM.csv"

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
local_csv=$workdir/extension_journal_requests_by_month.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert article counts and delete missing keys

csv_lines=$(wc -l $local_csv | cut -f1 -d' ')

if [ $csv_lines -lt "500000" ]; then
    echo "expected at least 500K lines in extension_journal_requests_by_month.csv but got $csv_lines. quitting."
    exit 1
fi

echo updating pg extension_journal_requests_by_month

psql $DATABASE_URL <<SQL
begin;
create temp table tmp_extension_journal_requests_by_month as (select month, issn_l, requests from extension_journal_requests_by_month limit 0);

\\copy tmp_extension_journal_requests_by_month from $local_csv csv header

insert into extension_journal_requests_by_month (
    select month, issn_l, requests
    from tmp_extension_journal_requests_by_month
) on conflict (month, issn_l) do update
    set requests = excluded.requests
;

delete from extension_journal_requests_by_month n where not exists (
    select 1 from tmp_extension_journal_requests_by_month t
    where
        t.month = n.month and
        t.issn_l = n.issn_l
);

commit;
SQL
