#!/bin/bash

echo "vac pub_queue";
. $HOME/.bash_profile;
. $HOME/.bashrc;
psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction'";
psql $DATABASE_URL -c "vacuum verbose analyze pub_queue"

. install_heroku_cli.sh;

