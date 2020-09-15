#!/bin/bash
#
# records the current number of articles with each oa_status

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="unpaywall.tmp_articles_by_oa_status_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    'select coalesce(oa_status, '\''null'\'') as status, current_timestamp() as time, count(1) as num_articles from unpaywall.api_live group by 1;'

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_articles_by_oa_status_$RANDOM.csv"

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
local_csv=$workdir/num_articles_by_oa_status.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert counts

echo updating pg num_articles_by_time_oa_status

psql $DATABASE_URL <<SQL
create temp table tmp_num_articles_by_time_oa_status as (select * from num_articles_by_time_oa_status limit 0);

\\copy tmp_num_articles_by_time_oa_status from $local_csv csv header

insert into num_articles_by_time_oa_status (
    select *
    from tmp_num_articles_by_time_oa_status
) on conflict (status, time) do update
    set num_articles = excluded.num_articles
;
SQL
