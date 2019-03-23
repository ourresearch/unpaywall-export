#!/bin/bash

echo "maintain pub update and refresh queues";
. $HOME/.bash_profile;
. $HOME/.bashrc;

alias heroku="/usr/local/bin/heroku"

# check we have the needed heroku
heroku --version

UPDATE_WORKERS=$(heroku ps -a oadoi update | grep '^update' | wc -l)
REFRESH_WORKERS=$(heroku ps -a articlepage refresh | grep '^refresh' | wc -l)

heroku ps:scale update=0 --app=oadoi
heroku ps:scale refresh=0 --app=articlepage

psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction'";
psql $DATABASE_URL -c "vacuum full verbose analyze pub_queue"
psql $DATABASE_URL -c "vacuum verbose analyze pub"
psql $DATABASE_URL -c "update pub_queue set started = null where started is not null"

psql $DATABASE_URL -c "vacuum full verbose analyze pub_refresh_queue"
psql $DATABASE_URL -c "update pub_refresh_queue set started = null where started is not null"

heroku ps:scale update=$UPDATE_WORKERS --app=oadoi
heroku ps:scale refresh=$REFRESH_WORKERS --app=articlepage

