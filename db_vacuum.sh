#!/bin/bash

echo "vac pub_queue";
. $HOME/.bash_profile;
. $HOME/.bashrc;

sudo sh install_heroku_cli.sh;

heroku ps:scale update=0 --app=oadoi

psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction'";
psql $DATABASE_URL -c "vacuum verbose analyze pub_queue"

heroku ps:scale update=30 --app=oadoi
