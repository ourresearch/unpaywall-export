#!/bin/bash

# usage: get-dois.sh HOUR OUT_DIR
# extract unpaywall DOIs from logs for hour HOUR to directory OUT_DIR/HOUR
# HOUR format is YYYY-MM-DD-HH

date_str=$1
out_dir=$2

>&2 echo "retreiving ${date_str}"

curl --no-include -L -s \
    -H "X-Papertrail-Token: $PAPERTRAIL_API_KEY" \
    https://papertrailapp.com/api/v1/archives/$date_str/download \
| gunzip -c - \
| grep 'logthis:' \
| grep '"email": "unpaywall@impactstory.org"' \
| sed -r 's/[0-9]+[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}).*"doi": "([^"]*)".*/"\1","\2"/' \
> $out_dir/$date_str.txt
