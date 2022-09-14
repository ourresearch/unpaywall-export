#!/bin/bash

# usage: get-dois.sh HOUR OUT_DIR
# extract unpaywall DOIs from logs for hour HOUR to directory OUT_DIR/HOUR
# HOUR format is YYYY-MM-DD-HH

date_str=$1
out_dir=$2
print_date=$(echo $date_str | cut -c1-10)

>&2 echo "retreiving ${date_str}"

if [[ "$print_date" < "2019-08-17" ]]; then
    s3_object="s3://ourresearch-papertrail/logs/${date_str}.tsv.gz"
else
    s3_object="s3://ourresearch-papertrail/logs/dt=${print_date}/${date_str}.tsv.gz"
fi

aws s3 cp "$s3_object" - \
| gunzip -c - \
| grep 'logthis:' \
| grep '"email": "unpaywall@impactstory.org"' \
| sed -r 's/[0-9]+[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}).*"doi": "([^"]*)".*/"\1","\2"/' \
> $out_dir/$date_str.txt
