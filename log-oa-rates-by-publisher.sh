#!/bin/bash
#
# records the current number of articles with each oa_status for the top 5 publishers

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="unpaywall.tmp_articles_by_oa_status_publisher_$RANDOM"

bq_query="
select * from (
    select
        current_timestamp() as time,
        case
            when regexp_contains(publisher, r'(?i)\\belsevier\\b') then 'Elsevier'
            when regexp_contains(publisher, r'(?i)\\bwiley\\b') then 'Wiley'
            when regexp_contains(publisher, r'(?i)\\bspringer\\b') then 'Springer'
            when regexp_contains(publisher, r'(?i)\\binforma\\b') or (regexp_contains(publisher, r'(?i)\\btaylor\\b') and regexp_contains(publisher, r'(?i)\\bfrancis\\b')) then 'Taylor & Francis'
            when regexp_contains(publisher, r'(?i)\\boxford university press\\b') then 'OUP'
            else null
        end as publisher,
        oa_status,
        count(*) as num_articles
    from unpaywall.api_live
    where oa_status is not null
    group by 1, 2, 3
) where publisher is not null;
"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    "$bq_query"

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_articles_by_oa_status_publisher_$RANDOM.csv"

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
local_csv=$workdir/num_articles_by_oa_status_publisher.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert counts

echo updating pg logs.num_articles_by_time_publisher_oa_status

psql $DATABASE_URL <<SQL
create temp table tmp_num_articles_by_time_oa_status_publisher as (select * from logs.num_articles_by_time_publisher_oa_status limit 0);

\\copy tmp_num_articles_by_time_oa_status_publisher from $local_csv csv header

insert into logs.num_articles_by_time_publisher_oa_status (
    select *
    from tmp_num_articles_by_time_oa_status_publisher
) on conflict (publisher, time, oa_status) do update
    set num_articles = excluded.num_articles
;
SQL
