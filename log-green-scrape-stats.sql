begin;

insert into logs.green_scrape (
    select
        now() as time ,
        count(1) as pages_scraped_last_hour,
        sum(case when error is not null and error != '' then 1 else 0 end) as errors_last_hour
    from
        page_new
    where
        scrape_updated > now() - interval '1 hour'
);

update logs.green_scrape set error_rate = errors_last_hour::real / pages_scraped_last_hour where time = now();

commit;
