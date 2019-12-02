create temp table tmp_pmcid_published_version_lookup (pmcid text);
\copy tmp_pmcid_published_version_lookup from _CSV_FILE_ csv

begin;
delete from pmcid_published_version_lookup;
insert into pmcid_published_version_lookup (pmcid) (
    select pmcid from tmp_pmcid_published_version_lookup
);
commit;
