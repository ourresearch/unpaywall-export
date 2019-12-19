#!/bin/bash
#
# populates the postgres journal_oa_start_year view and dependencies using bigquery

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
    'select issn_l, year, oa_status, count(1) as num_dois from unpaywall.api_live left join journals.our_doi_to_issnl using (doi) where published_date < date_sub(current_date(), interval 1 month) group by 1, 2, 3;'

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

csv_lines=$(wc -l $local_csv | cut -f1 -d' ')

if [ $csv_lines -lt "1000000" ]; then
    echo "expected at least 1M lines in num_dois_by_issnl_year_oa_status.csv but got $csv_lines. quitting."
    exit 1
fi

echo updating pg num_dois_by_journal_year_status

psql $DATABASE_URL <<SQL
begin;

create temp table tmp_num_dois_by_journal_year_status as (select * from num_dois_by_journal_year_status limit 0);

\\copy tmp_num_dois_by_journal_year_status from $local_csv csv header

insert into num_dois_by_journal_year_status (
    select *
    from tmp_num_dois_by_journal_year_status
    where issn_l is not null and year is not null and oa_status is not null
) on conflict (issn_l, year, oa_status) do update
    set num_dois = excluded.num_dois
;

delete from num_dois_by_journal_year_status n where not exists (
    select 1 from tmp_num_dois_by_journal_year_status t
    where
        t.issn_l = n.issn_l and
        t.year = n.year and
        t.oa_status = n.oa_status
);


refresh materialized view oa_rates_by_journal_year;

create temp table old_journal_oa_start_year as (select * from journal_oa_start_year);

refresh materialized view journal_oa_start_year;

insert into logs.oa_journal_updates (select now(), 'XXXX-XXXX', null, null);

insert into logs.oa_journal_updates (
    select
        now() as update_time,
        issn_l,
        old.oa_year as old_oa_year,
        new.oa_year as new_oa_year
    from
        old_journal_oa_start_year old
        full outer join journal_oa_start_year new using (issn_l)
    where
        old.oa_year is distinct from new.oa_year
);

commit;
SQL
