#!/bin/bash

# usage: get-logs.sh DAY (YYYY-MM-DD)
# extract DOIs requested by the unpaywall extension on DAY

day=$1

work_dir=$(mktemp -d)

./generate-hours.sh $day \
    | parallel -j 25% "./papertrail-log-download.sh {} $work_dir"

cat $work_dir/*
