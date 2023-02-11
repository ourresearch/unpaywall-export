#!/bin/bash

echo "unstick queues";
. $HOME/.bash_profile;
. $HOME/.bashrc;

psql $DATABASE_URL -c "update recordthresher.doi_record_queue set started = null where started < now() - interval '8 hours';"
psql $DATABASE_URL -c "update recordthresher.pubmed_record_queue set started = null where started < now() - interval '8 hours';"
psql $DATABASE_URL -c "update recordthresher.pmh_record_queue set started = null where started < now() - interval '8 hours';"

psql $DATABASE_URL -c "update pub_queue set started = null where started < now() - interval '8 hours';"
psql $DATABASE_URL -c "update pub_refresh_queue set started = null where started < now() - interval '8 hours';"
psql $DATABASE_URL -c "update pub_refresh_queue_aux set started = null where started < now() - interval '8 hours';"
psql $DATABASE_URL -c "update page_green_scrape_queue set started = null where started < now() - interval '8 hours';"
psql $DATABASE_URL -c "update pdf_url_check_queue set started = null where started < now() - interval '8 hours';"
