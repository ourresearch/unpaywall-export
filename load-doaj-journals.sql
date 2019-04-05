\set ON_ERROR_STOP on

create temp table doaj_csv (
    title       text,
    alt_title   text,
    issn        text,
    e_issn      text,
    year        integer,
    license     text
);

\copy doaj_csv (title, alt_title, issn, e_issn, year, license) from program 'bash get-doaj-csv.sh' csv header null as ''

delete from doaj_journals;
insert into doaj_journals (select * from doaj_csv);
