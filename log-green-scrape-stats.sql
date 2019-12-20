begin;

insert into logs.green_scrape (
    select
        now() as time ,
        count(1)::real / 2 as pages_scraped_per_hour,
        sum(case when error is not null and error != '' then 1 else 0 end)::real / 2 as errors_per_hour
    from
        page_new
    where
        scrape_updated > now() - interval '2 hours'
);

update logs.green_scrape set error_rate = errors_per_hour::real / greatest(pages_scraped_per_hour, 1) where time = now();

insert into logs.green_scrape_by_endpoint (
    select * from (
        select
            now() as time,
            endpoint_id,
            count(1)::real / 2 as pages_scraped_per_hour,
            sum(case when error is not null and error != '' then 1 else 0 end)::real / 2 as errors_per_hour
        from
            page_new
        where
            scrape_updated > now() - interval '2 hours'
        group by endpoint_id
    ) x
    where errors_per_hour > 0
);

update logs.green_scrape_by_endpoint set error_rate = errors_per_hour::real / greatest(pages_scraped_per_hour, 1) where time = now();

commit;
