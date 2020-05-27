begin;

create temp table tmp_hybrid_scrape_2hr as (select scrape_evidence, scrape_license, scrape_pdf_url is not null as has_pdf, scrape_metadata_url is not null as has_metadata_url, response_jsonb->>'oa_status' as oa_status from pub where scrape_updated > now() - interval '2 hours');
create temp table tmp_hybrid_scrape_8hr as (select scrape_evidence, scrape_license, scrape_pdf_url is not null as has_pdf, scrape_metadata_url is not null as has_metadata_url, response_jsonb->>'oa_status' as oa_status from pub where scrape_updated > now() - interval '8 hours');

insert into logs.hybrid_scrape_evidence (
    select now(), interval '2 hours' as interval, scrape_evidence, count(*) as count from tmp_hybrid_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, scrape_evidence, count(*) as count from tmp_hybrid_scrape_8hr group by 1, 2, 3
);

insert into logs.hybrid_scrape_licenses (
    select now(), interval '2 hours' as interval, scrape_license, count(*) as count from tmp_hybrid_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, scrape_license, count(*) as count from tmp_hybrid_scrape_8hr group by 1, 2, 3
);

insert into logs.hybrid_scrape_pdf_urls (
    select now(), interval '2 hours' as interval, has_pdf, count(*) as count from tmp_hybrid_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, has_pdf, count(*) as count from tmp_hybrid_scrape_8hr group by 1, 2, 3
);

insert into logs.hybrid_scrape_metadata_urls (
    select now(), interval '2 hours' as interval, has_metadata_url, count(*) as count from tmp_hybrid_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, has_metadata_url, count(*) as count from tmp_hybrid_scrape_8hr group by 1, 2, 3
);

insert into logs.hybrid_scrape_oa_status (
    select now(), interval '2 hours' as interval, oa_status, count(*) as count from tmp_hybrid_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, oa_status, count(*) as count from tmp_hybrid_scrape_8hr group by 1, 2, 3
);

commit;
