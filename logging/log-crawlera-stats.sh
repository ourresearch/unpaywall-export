#!/bin/bash

start_date=$(date -u -Iminutes -d '12 hours ago')


clean_requests=$(
    curl -G -u $CRAWLERA_API_KEY: \
        --data-urlencode "start_date=$start_date" \
        https://crawlera-stats.scrapinghub.com/stats/ |
    jq '.results[0].clean'
)

echo $clean_requests

psql $DATABASE_URL <<SQL
insert into logs.crawlera_request_rate (
    select now() - '12 hours'::interval as window_start, now() as window_end, $clean_requests / 12 as requests_per_hr
);
SQL
