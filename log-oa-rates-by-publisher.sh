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
            when regexp_contains(publisher, r'(?i)\\bsage publication') then 'SAGE'
            when regexp_contains(publisher, r'\\bMDPI\\b') then 'MDPI AG'
            when regexp_contains(publisher, r'(?i)\\binstitute of electrical and electronics engineers\\b') or regexp_contains(publisher, r'(?i)\\bieee\\b') then 'IEEE'
            when regexp_contains(publisher, r'(?i)\\bamerican chemical society\\b') then 'American Chemical Society'
            when regexp_contains(publisher, r'(?i)\\bIOP Publishing\\b') then 'IOP Publishing'
            when regexp_contains(publisher, r'(?i)\\bWolters Kluwer Health\\b') then 'Wolters Kluwer Health'
            when regexp_contains(publisher, r'(?i)\\bRoyal Society of Chemistry\\b') then 'Royal Society of Chemistry'
            when regexp_contains(publisher, r'(?i)\\bCambridge University Press\\b') then 'Cambridge University Press'
            when regexp_contains(publisher, r'(?i)\\bGeorg Thieme\\b') then 'Georg Thieme Verlag KG'
            when regexp_contains(publisher, r'(?i)\\bPublic Library of Science\\b') then 'Public Library of Science'
            when regexp_contains(publisher, r'(?i)\\bBMJ Publishing\\b') then 'BMJ Publishing'
            when regexp_contains(publisher, r'(?i)\\bWalter de Gruyter\\b') then 'Walter de Gruyter'
            when regexp_contains(publisher, r'(?i)\\bSciELO\\b') then 'SciELO'
            when regexp_contains(publisher, r'(?i)\\bHindawi Limited\\b') then 'Hindawi Limited'
            when regexp_contains(publisher, r'(?i)\\bEDP Sciences\\b') then 'EDP Sciences'
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
