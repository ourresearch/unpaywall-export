#!/bin/bash
#
# populates the postgres table num_dois_by_journal_year_status
# and refreshes the derived oa_rates_by_journal_year view

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting view to temp table

bq_temp_table="journals.tmp_num_dois_by_issnl_year_oa_status_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 <<BQ_SQL
        select * from (
            select journal_issn_l as issn_l, year, oa_status, count(1) as num_dois
            from unpaywall.api_live
            where published_date < date_sub(current_date(), interval 1 month) group by 1, 2, 3
        )
        where issn_l is not null and year is not null and oa_status is not null;
BQ_SQL

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

create temp table tmp_num_dois_by_journal_year_status as (select issn_l, year, oa_status, num_dois from num_dois_by_journal_year_status limit 0);

\\copy tmp_num_dois_by_journal_year_status from $local_csv csv header

insert into num_dois_by_journal_year_status (issn_l, year, oa_status, num_dois) (
    select issn_l, year, oa_status, num_dois
    from tmp_num_dois_by_journal_year_status
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

commit;
SQL
