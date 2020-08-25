\set ON_ERROR_STOP on

create temp table old_doaj as (
    select issn, e_issn, year from doaj_journals
);

create temp table doaj_csv (
    title       text,
    alt_title   text,
    issn        text,
    e_issn      text,
    year        integer,
    license     text
);

\copy doaj_csv (title, alt_title, issn, e_issn, year, license) from program 'bash get-doaj-csv.sh' csv header null as ''

begin;

truncate doaj_journals;
insert into doaj_journals (select * from doaj_csv);

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
