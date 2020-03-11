#!/bin/bash

echo "refresh materialized views for metrics";

. $HOME/.bash_profile;
. $HOME/.bashrc;

./logging/log-license-rates.sh
./logging/log-version-rates.sh
./logging/log-crawlera-stats.sh

heroku run -a oadoi python -m monitoring.data_feed

psql $DATABASE_URL < log-green-scrape-stats.sql
psql $DATABASE_URL < logging/changefile-size.sql
psql $DATABASE_URL -c "refresh materialized view pub_refresh_priority_histo_mv";
psql $DATABASE_URL -c "refresh materialized view pub_refresh_rate_mv";
psql $DATABASE_URL -c "refresh materialized view pub_update_rate_mv";
psql $DATABASE_URL -c "refresh materialized view green_scrape_rate_mv";
psql $DATABASE_URL -c "refresh materialized view pdf_check_rate_mv";
psql $DATABASE_URL -c "insert into pub_refresh_overdue_fraction (select now(),  1.0 * (select sum(count) from pub_refresh_priority_histo_mv where priority > 1) / (select sum(count) from pub_refresh_priority_histo_mv))";

psql $DATABASE_URL -c "\
    insert into pub_volatility ( \
        select \
            now() as time, \
            '2 days'::interval as interval, \
            (select count(1) from pub_queue where finished > now() - '2 days'::interval and started is null) as updated, \
            (select count(1) from pub where last_changed_date > now() - '2 days'::interval) as changed \
    );"

psql $DATABASE_URL -c "\
    insert into pub_volatility ( \
        select \
            now() as time, \
            '2 hours'::interval as interval, \
            (select count(1) from pub_queue where finished > now() - '2 hours'::interval and started is null) as updated, \
            (select count(1) from pub where last_changed_date > now() - '2 hours'::interval) as changed \
    );"

psql $DATABASE_URL -c "\
    insert into pdf_validity ( \
        select \
            now() as time, \
            count(1) as num_urls, \
            sum(case when is_pdf then 1 else 0 end) as num_valid_pdfs, \
            sum(case when http_status is not null then 1 else 0 end) as num_responses, \
            sum(case when http_status = 200 then 1 else 0 end) as num_200, \
            sum(case when is_pdf is null then 1 else 0 end) as num_unchecked_pdfs, \
            sum(case when not is_pdf then 1 else 0 end) as num_invalid_pdfs \
        from pdf_url \
    );"
