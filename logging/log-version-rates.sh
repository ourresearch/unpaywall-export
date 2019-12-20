#!/bin/bash
#
# records the current number of articles with each oa_status and green version

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="unpaywall.tmp_articles_by_oa_status_version_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    'select coalesce(oa_status, '\''null'\'') as oa_status, coalesce(best_oa_location.version, '\''null'\'') as version, count(1) as num_articles from unpaywall.api_live group by 1, 2;'

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_articles_by_oa_status_version_$RANDOM.csv"

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
local_csv=$workdir/num_articles_by_oa_status_version.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert counts

echo updating pg logs.articles_by_oa_status_version

psql $DATABASE_URL <<SQL
create temp table tmp_num_articles_by_time_oa_status (oa_status text, version text, num_articles integer);

\\copy tmp_num_articles_by_time_oa_status from $local_csv csv header

insert into logs.articles_by_oa_status_version (
    select now(), *
    from tmp_num_articles_by_time_oa_status
);
SQL
