#!/bin/bash

echo "refresh materialized views for metrics";

. $HOME/.bash_profile;
. $HOME/.bashrc;

psql $DATABASE_URL -c "refresh materialized view pub_refresh_priority_histo_mv";
psql $DATABASE_URL -c "refresh materialized view pub_refresh_rate_mv";
psql $DATABASE_URL -c "refresh materialized view pub_update_rate_mv";
psql $DATABASE_URL -c "insert into pub_refresh_overdue_fraction (select now(),  1.0 * (select sum(count) from pub_refresh_priority_histo_mv where priority > 1) / (select sum(count) from pub_refresh_priority_histo_mv))";

