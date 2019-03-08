#!/bin/bash

echo "refresh materialized views for metrics";

. $HOME/.bash_profile;
. $HOME/.bashrc;

psql $DATABASE_URL -c "refresh materialized view pub_refresh_priority_histo_mv";
psql $DATABASE_URL -c "refresh materialized view pub_refresh_rate_mv";
psql $DATABASE_URL -c "refresh materialized view pub_update_rate_mv";

