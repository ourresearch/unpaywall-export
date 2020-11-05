begin;

insert into logs.green_scrape (
    select
        now() as time ,
        count(1)::real / 8 as pages_scraped_per_hour,
        sum(case when error is not null and error != '' then 1 else 0 end)::real / 8 as errors_per_hour
    from
        page_new
    where
        scrape_updated > now() - interval '8 hours'
);

update logs.green_scrape set error_rate = errors_per_hour::real / greatest(pages_scraped_per_hour, 1) where time = now();

insert into logs.green_scrape_by_endpoint (
    select * from (
        select
            now() as time,
            endpoint_id,
            count(1)::real / 8 as pages_scraped_per_hour,
            sum(case when error is not null and error != '' then 1 else 0 end)::real / 8 as errors_per_hour
        from
            page_new
        where
            scrape_updated > now() - interval '8 hours'
        group by endpoint_id
    ) x
    where errors_per_hour > 0
);

update logs.green_scrape_by_endpoint set error_rate = errors_per_hour::real / greatest(pages_scraped_per_hour, 1) where time = now();

create temp table tmp_scrape_2hr as (select scrape_version, scrape_license, scrape_pdf_url is not null as has_pdf, scrape_metadata_url is not null as has_metadata_url from page_new where scrape_updated > now() - interval '2 hours');
create temp table tmp_scrape_8hr as (select scrape_version, scrape_license, scrape_pdf_url is not null as has_pdf, scrape_metadata_url is not null as has_metadata_url from page_new where scrape_updated > now() - interval '8 hours');

insert into logs.green_scrape_versions (
    select now(), interval '2 hours' as interval, scrape_version, count(*) as count from tmp_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, scrape_version, count(*) as count from tmp_scrape_8hr group by 1, 2, 3
);

insert into logs.green_scrape_licenses (
    select now(), interval '2 hours' as interval, scrape_license, count(*) as count from tmp_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, scrape_license, count(*) as count from tmp_scrape_8hr group by 1, 2, 3
);

insert into logs.green_scrape_pdf_urls (
    select now(), interval '2 hours' as interval, has_pdf, count(*) as count from tmp_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, has_pdf, count(*) as count from tmp_scrape_8hr group by 1, 2, 3
);

insert into logs.green_scrape_metadata_urls (
    select now(), interval '2 hours' as interval, has_metadata_url, count(*) as count from tmp_scrape_2hr group by 1, 2, 3
    union
    select now(), interval '8 hours' as interval, has_metadata_url, count(*) as count from tmp_scrape_8hr group by 1, 2, 3
);


commit;
