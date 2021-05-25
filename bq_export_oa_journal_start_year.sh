#!/bin/bash
#
# refreshes the postgres journal_oa_start_year view and logs changes

set -e

: ${DATABASE_URL:?environment variable must be set}

echo updating pg journal_oa_start_year

psql $DATABASE_URL <<SQL
begin;

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
