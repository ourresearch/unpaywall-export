create temp table tmp_pmcid_lookup (doi text, pmcid text, release_date text);
\copy tmp_pmcid_lookup from _CSV_FILE_ csv header

begin;
delete from pmcid_lookup;
insert into pmcid_lookup (doi, pmcid, release_date) (
    select lower(doi), lower(pmcid), release_date from tmp_pmcid_lookup
);
commit;
