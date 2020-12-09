#!/bin/bash
#
# populates the postgres table num_articles_by_journal_repo from bigquery

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting query to temp table

bq_temp_table="journals.tmp_num_articles_by_journal_repo_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    'select journal_issn_l as issn_l, oa_location.endpoint_id, count(distinct doi) as num_articles from unpaywall.api_live, unnest(oa_locations) as oa_location where  oa_location.endpoint_id is not null and journal_issn_l is not null group by 1, 2 order by 1, 2;'

# extract the table to CSV and delete the temp table

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_num_articles_by_journal_repo_$RANDOM.csv"

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
local_csv=$workdir/num_articles_by_journal_repo.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert article counts and delete missing keys

csv_lines=$(wc -l $local_csv | cut -f1 -d' ')

if [ $csv_lines -lt "1000000" ]; then
    echo "expected at least 1M lines in num_articles_by_journal_repo.csv but got $csv_lines. quitting."
    exit 1
fi

echo updating pg num_articles_by_journal_repo

psql $DATABASE_URL <<SQL
begin;
create temp table tmp_num_articles_by_journal_repo as (select * from num_articles_by_journal_repo limit 0);

\\copy tmp_num_articles_by_journal_repo from $local_csv csv header

insert into num_articles_by_journal_repo (
    select *
    from tmp_num_articles_by_journal_repo
) on conflict (issn_l, endpoint_id) do update
    set num_articles = excluded.num_articles
;

delete from num_articles_by_journal_repo n where not exists (
    select 1 from tmp_num_articles_by_journal_repo t
    where
        t.issn_l = n.issn_l and
        t.endpoint_id = n.endpoint_id
);

commit;
SQL
