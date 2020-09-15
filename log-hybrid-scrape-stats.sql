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

begin;

create temp table tmp_publisher_scrape_72_hr as (
    select * from (
        select
            now() as time,
            case
                when response_jsonb->>'publisher' ~* '\yelsevier\y' then 'Elsevier'
                when response_jsonb->>'publisher' ~* '\ywiley\y' then 'Wiley'
                when response_jsonb->>'publisher' ~* '\yspringer\y' then 'Springer'
                when response_jsonb->>'publisher' ~* '\yinforma\y' or (response_jsonb->>'publisher' ~*'\ytaylor\y' and response_jsonb->>'publisher' ~ '\yfrancis\y') then 'Taylor & Francis'
                when response_jsonb->>'publisher' ~* '\yoxford university press\y' then 'OUP'
                when response_jsonb->>'publisher' ~* '\ysage publication' then 'SAGE'
                else 'other'
            end as publisher,
            response_jsonb->>'oa_status' as oa_status,
            count(*) as num_articles
        from pub
        where scrape_updated > now() - interval '72 hours'
        and response_jsonb->>'oa_status' is not null
        group by 1, 2, 3
    ) x where publisher != 'other'
);

insert into logs.hybrid_scrape_oa_status_by_publisher (time, publisher, interval, oa_status, count) (
    select time, publisher, interval '72 hours', oa_status, num_articles from tmp_publisher_scrape_72_hr
);

commit;
