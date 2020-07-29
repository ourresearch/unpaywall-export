#!/bin/bash

echo "maintain pub update and refresh queues";
. $HOME/.bash_profile;
. $HOME/.bashrc;

function sleep_wait() {
    while ps -p $1 &>/dev/null; do
        sleep 1
    done
}

alias heroku="/usr/local/bin/heroku"

# check we have the needed heroku
heroku --version

UPDATE_WORKERS=$(heroku ps -a oadoi update | grep '^update\.' | wc -l)
REFRESH_WORKERS=$(heroku ps -a articlepage refresh | grep '^refresh\.' | wc -l)
REFRESH_AUX_WORKERS=$(heroku ps -a articlepage refresh_aux | grep '^refresh_aux\.' | wc -l)
GREEN_SCRAPE_WORKERS=$(heroku ps -a oadoi green_scrape | grep '^green_scrape\.' | wc -l)
REPO_HARVEST_WORKERS=$(heroku ps -a oadoi run_repo | grep '^run_repo\.' | wc -l)
PDF_CHECK_WORKERS=$(heroku ps -a articlepage run_pdf_url_check | grep '^run_pdf_url_check\.' | wc -l)

heroku ps:scale update=0 --app=oadoi
heroku ps:scale refresh=0 --app=articlepage
heroku ps:scale refresh_aux=0 --app=articlepage
heroku ps:scale green_scrape=0 --app=oadoi
heroku ps:scale run_repo=0 --app=oadoi
heroku ps:scale run_pdf_url_check=0 --app=articlepage

psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction'";

(
    psql $DATABASE_URL -c "update pub_queue set started = null where started is not null"
    psql $DATABASE_URL -c "vacuum verbose analyze pub_queue"
) & update_vac=$!

(
    psql $DATABASE_URL -c "update pub_refresh_queue set started = null where started is not null"
    psql $DATABASE_URL -c "update pub_refresh_queue_aux set started = null where started is not null"
    psql $DATABASE_URL -c "vacuum verbose analyze pub_refresh_queue"
    psql $DATABASE_URL -c "vacuum verbose analyze pub_refresh_queue_aux"
    heroku ps:scale refresh=$REFRESH_WORKERS --app=articlepage
    heroku ps:scale refresh_aux=$REFRESH_AUX_WORKERS --app=articlepage
) & refresh_vac=$!


(
    psql $DATABASE_URL -c "update page_green_scrape_queue set started = null where started is not null"
    psql $DATABASE_URL -c "update endpoint set last_harvest_started = null where last_harvest_started is not null"
    psql $DATABASE_URL -c "vacuum verbose analyze page_green_scrape_queue"
    psql $DATABASE_URL -c "vacuum verbose analyze page_new"
    psql $DATABASE_URL -c "vacuum verbose analyze pmh_record"
    heroku ps:scale green_scrape=$GREEN_SCRAPE_WORKERS --app=oadoi
    heroku ps:scale run_repo=$REPO_HARVEST_WORKERS --app=oadoi
) & green_scrape_vac=$!

(
    psql $DATABASE_URL -c "update pdf_url_check_queue set started = null where started is not null"
    psql $DATABASE_URL -c "vacuum verbose analyze pdf_url_check_queue"
    heroku ps:scale run_pdf_url_check=$PDF_CHECK_WORKERS --app=articlepage
) & pdf_check_vac=$!

wait $update_vac $refresh_vac $green_scrape_vac $pdf_check_vac

heroku ps:scale update=$UPDATE_WORKERS --app=oadoi
