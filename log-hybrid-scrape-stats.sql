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

create temp table tmp_publisher_scrape_intervals as (
    with recent_pubs as materialized (
        select
            scrape_updated,
            response_jsonb->>'publisher' as publisher,
            response_jsonb->>'oa_status' as oa_status
        from pub
        where scrape_updated > now() - interval '2 weeks'
    )
    select
        now() as time,
        interval,
        publisher,
        oa_status,
        sum(case when scrape_updated > now() - interval then 1 else 0 end) as num_articles
    from (
        select * from (
            select
                scrape_updated,
                case
                    when publisher ~* '\yelsevier\y' then 'Elsevier'
                    when publisher ~* '\ywiley\y' then 'Wiley'
                    when publisher ~* '\yspringer\y' then 'Springer'
                    when publisher ~* '\yinforma\y' or (publisher ~*'\ytaylor\y' and publisher ~ '\yfrancis\y') then 'Taylor & Francis'
                    when publisher ~* '\yoxford university press\y' then 'OUP'
                    when publisher ~* '\ysage publication' then 'SAGE'
                    else 'other'
                end as publisher,
                oa_status
            from recent_pubs
        ) assigned_pubs where publisher != 'other' and oa_status is not null
    ) filtered_pubs
    cross join (
        select interval '1 day' as interval
        union
        select interval '3 days'
        union
        select interval '1 week'
        union
        select interval '2 weeks'
    ) intervals
    group by 1, 2, 3, 4
);

insert into logs.hybrid_scrape_oa_status_by_publisher (time, publisher, interval, oa_status, count) (
    select time, publisher, interval, oa_status, num_articles from tmp_publisher_scrape_intervals
);

commit;
