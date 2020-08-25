create table tmp_pmcid_lookup (like pmcid_lookup including all);
\copy tmp_pmcid_lookup (doi, pmcid, release_date) from _CSV_FILE_ csv header

update tmp_pmcid_lookup set doi = lower(doi), pmcid = lower(pmcid);

begin;

drop table pmcid_lookup;
alter table tmp_pmcid_lookup rename to pmcid_lookup;

commit;

--create temp table tmp_published_date as (
--    select
--        pmc.pmcid,
--        pmh.record_timestamp as published_date
--    from
--        pmcid_lookup pmc join pmh_record pmh on pmh.pmh_id = 'oai:pubmedcentral.nih.gov:' || replace(pmc.pmcid, 'pmc', '')
--    where
--        pmh.endpoint_id = 'ac9de7698155b820de7'
--        and pmc.release_date = 'live'
--        and pmh.record_timestamp is not null
--);
--
--insert into pmcid_published_date_lookup (select * from tmp_published_date where pmcid not in (select pmcid from pmcid_published_date_lookup));
