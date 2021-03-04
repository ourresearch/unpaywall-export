#!/bin/bash

usage() {
    echo "
Usage: $0 YYYY-MM-DD
load a day's worth of unpaywall extension doi requests to bigquery

The following environment variables are required:

DATABASE_URL: connection string for database
PAPERTRAIL_API_KEY: the API token needed to access papertrail logs
"
}

logger() {
    echo "$(date --utc +'%Y-%m-%dT%H:%M:%S') : $1"
}

if [[ "$DATABASE_URL" == "" ]]; then
    echo "Missing DATABASE_URL environment variable"
    usage
    exit 1
fi

if [[ "$PAPERTRAIL_API_KEY" == "" ]]; then
    echo "Missing PAPERTRAIL_API_KEY environment variable"
    usage
    exit 1
fi


bq_tablename='unpaywall.extension_doi_requests'
log_date=$1

if [ -z "$log_date" ]; then
    logger "No date specified, picking the earliest unpopulated day."
    min_log_date=$(date --utc --date='364 days ago' +'%Y-%m-%d')
    max_log_date=$(date --utc --date='2 days ago' +'%Y-%m-%d')
    log_date=$(
        bq query --use_legacy_sql=false --format=prettyjson --quiet \
            "select min(range_day) as log_day from unnest(generate_date_array(date('$min_log_date'), date('$max_log_date'))) as range_day where not exists (select 1 from $bq_tablename req where req.day = range_day);" |
            jq -r '.[] | .log_day'
    )
    if [[ "$log_date" ==  "null" ]]; then
        echo "All dates from $min_log_date to $max_log_date already populated."
        exit 0
    fi
fi

logger "Getting logs for $log_date"

logger "Checking for log retrieval in progress for $log_date..."

runs_in_progress=$(psql $DATABASE_URL -t --no-align -c "select count(*) from extension_log_retrieval_run where log_date = '$log_date' and finished is null and started > now() - interval '1 hour';")

if [[ $runs_in_progress -gt 0 ]]; then
    logger "Found a log retrieval run in progress for $log_date"
    exit 1
fi


logger "Checking for existing records from $log_date..."

existing_rows=$(
    bq query --format=prettyjson --use_legacy_sql=false --quiet \
        "select count(*) as records from $bq_tablename where day = date('$log_date');" |
        jq '.[] | .records | tonumber'
)

if [[ $existing_rows -gt 0 ]]; then
    logger "Found $existing_rows row(s) for $log_date in $bq_tablename. Delete them and try again."
    exit 1
fi

psql $DATABASE_URL -t --no-align -c "insert into extension_log_retrieval_run (log_date, started) values ('$log_date', now()) on conflict (log_date) do update set started = excluded.started;"

logger "Getting extension requests for $log_date"

work_dir=$(mktemp -d)
log_file="${work_dir}/${log_date}.csv"

./get-logs.sh $log_date | sed "s/^/\"$log_date\",/" > $log_file

logger "Wrote requests to $log_file"

logger "Loading $log_file to $bq_tablename"

bq load --source_format=CSV $bq_tablename $log_file day:DATE,time:TIMESTAMP,doi:STRING

psql $DATABASE_URL -t --no-align -c "update extension_log_retrieval_run set finished = now() where log_date = '$log_date';"
