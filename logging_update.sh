#!/bin/bash

echo "refresh materialized views for metrics";

. $HOME/.bash_profile;
. $HOME/.bashrc;

./logging/log-license-rates.sh
./logging/log-version-rates.sh
./logging/log-crawlera-stats.sh

psql $DATABASE_URL < log-green-scrape-stats.sql
psql $DATABASE_URL < log-hybrid-scrape-stats.sql
psql $DATABASE_URL < logging/changefile-size.sql
psql $DATABASE_URL -c "refresh materialized view pub_refresh_priority_histo_mv";
psql $DATABASE_URL -c "refresh materialized view pub_refresh_rate_mv";
psql $DATABASE_URL -c "refresh materialized view pub_update_rate_mv";
psql $DATABASE_URL -c "refresh materialized view green_scrape_rate_mv";
psql $DATABASE_URL -c "refresh materialized view pdf_check_rate_mv";
psql $DATABASE_URL -c "insert into pub_refresh_overdue_fraction (select now(),  1.0 * (select sum(count) from pub_refresh_priority_histo_mv where priority > 1) / (select sum(count) from pub_refresh_priority_histo_mv))";

psql $DATABASE_URL -c "\
    insert into logs.refresh_oa_status_results_trailing_8_hr ( \
        time, oa_status_before, oa_status_after, num_dois \
    ) ( \
        select now(), oa_status_before, oa_status_after, count(distinct id) as num_dois \
        from pub_refresh_result \
        where refresh_time >= now() - interval '8 hours' and oa_status_before is not null and oa_status_after is not null \
        group by 1, 2, 3 \
    );"


psql $DATABASE_URL -c "\
    insert into pub_volatility ( \
        select \
            now() as time, \
            '2 days'::interval as interval, \
            (select count(1) from pub_queue where finished > now() - '2 days'::interval and started is null) as updated, \
            (select count(1) from pub join pub_queue q using (id) where q.finished > now() - '2 days'::interval and last_changed_date > now() - '2 days'::interval) as changed \
    );"

psql $DATABASE_URL -c "\
    insert into pub_volatility ( \
        select \
            now() as time, \
            '2 hours'::interval as interval, \
            (select count(1) from pub_queue where finished > now() - '2 hours'::interval and started is null) as updated, \
            (select count(1) from pub join pub_queue q using (id) where q.finished > now() - '2 hours'::interval and last_changed_date > now() - '2 hours'::interval) as changed \
    );"

psql $DATABASE_URL -c "\
    insert into pdf_validity ( \
        select \
            now() as time, \
            count(1) as num_urls, \
            sum(case when is_pdf is null or is_pdf then 1 else 0 end) as num_valid_pdfs, \
            sum(case when is_pdf is null or http_status is not null then 1 else 0 end) as num_responses, \
            sum(case when is_pdf is null or http_status = 200 then 1 else 0 end) as num_200, \
            sum(case when is_pdf is null then 1 else 0 end) as num_unchecked_pdfs, \
            sum(case when is_pdf is not null and not is_pdf then 1 else 0 end) as num_invalid_pdfs \
        from pdf_url \
    );"
