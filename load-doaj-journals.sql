\set ON_ERROR_STOP on

create temp table old_doaj as (
    select issn, e_issn, year from doaj_journals
);

create temp table doaj_csv (
    title       text,
    alt_title   text,
    issn        text,
    e_issn      text,
    license     text
);

\copy doaj_csv (title, alt_title, issn, e_issn, license) from program 'bash get-doaj-csv.sh' csv header null as ''

begin;

update
    doaj_journals
set
    title = doaj_csv.title,
    alt_title = doaj_csv.alt_title,
    license = doaj_csv.license
from
    doaj_csv
where
    doaj_journals.issn = doaj_csv.issn
    or doaj_journals.e_issn = doaj_csv.e_issn
    or (
        doaj_journals.title = doaj_csv.title
        and doaj_journals.issn is not distinct from doaj_csv.issn
        and doaj_journals.e_issn is not distinct from doaj_csv.e_issn
    )
;

insert into doaj_journals (title, alt_title, issn, e_issn, year, license) (
    select
        title,
        alt_title,
        issn,
        e_issn,
        extract(year from now()),
        license
    from
        doaj_csv
    where not exists (
        select 1 from doaj_journals
        where
            doaj_journals.issn = doaj_csv.issn
            or doaj_journals.e_issn = doaj_csv.e_issn
            or (
                doaj_journals.title = doaj_csv.title
                and doaj_journals.issn is not distinct from doaj_csv.issn
                and doaj_journals.e_issn is not distinct from doaj_csv.e_issn
            )
    )
);

delete from doaj_journals
where not exists (
    select 1 from doaj_csv
    where
        doaj_journals.issn = doaj_csv.issn
        or doaj_journals.e_issn = doaj_csv.e_issn
        or (
            doaj_journals.title = doaj_csv.title
            and doaj_journals.issn is not distinct from doaj_csv.issn
            and doaj_journals.e_issn is not distinct from doaj_csv.e_issn
        )
);

commit;

insert into logs.doaj_updates (select now(), 'XXXX-XXXX', null, null);

insert into logs.doaj_updates (
    select
        now() as update_time,
        issn,
        old.year as old_year,
        new.year as new_year
    from
        old_doaj old
        full outer join doaj_journals new using (issn)
    where
        issn is not null
        and old.year is distinct from new.year
);

insert into logs.doaj_updates (
    select
        now() as update_time,
        e_issn,
        old.year as old_year,
        new.year as new_year
    from
        old_doaj old
        full outer join doaj_journals new using (e_issn)
    where
        e_issn is not null
        and old.year is distinct from new.year
);
