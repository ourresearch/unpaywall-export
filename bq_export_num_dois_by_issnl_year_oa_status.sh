#!/bin/bash
#
# populates the postgres num_dois_by_issnl_year_oa_status table using bigquery

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="journals.tmp_num_dois_by_issnl_year_oa_status_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    'select issn_l, year, oa_status, count(1) as num_dois from unpaywall.api_live left join journals.our_doi_to_issnl using (doi) group by 1, 2, 3;'

# extract the mapping file to CSV and delete the temp table

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_num_dois_by_issnl_year_oa_status_$RANDOM.csv"

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
local_csv=$workdir/num_dois_by_issnl_year_oa_status.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert article counts and delete missing keys

echo updating pg journal table

psql $DATABASE_URL <<SQL
create temp table tmp_num_dois_by_journal_year_status as (select * from num_dois_by_journal_year_status limit 0);

\\copy tmp_num_dois_by_journal_year_status from $local_csv csv header

insert into num_dois_by_journal_year_status (
    select *
    from tmp_num_dois_by_journal_year_status
    where issn_l is not null and year is not null and oa_status is not null
) on conflict (issn_l, year, oa_status) do update
    set num_dois = excluded.num_dois
;

delete from num_dois_by_journal_year_status where (issn_l, year, oa_status) not in (
    select issn_l, year, oa_status from tmp_num_dois_by_journal_year_status
);

refresh materialized view oa_rates_by_journal_year;
SQL
