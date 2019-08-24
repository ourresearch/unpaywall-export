#!/bin/bash

usage() {
    echo "
Usage: $0
load the the last 2 days of api response changes to bigquery

The following environmental variables are required:

DATABASE_URL     connection string for database
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

require_success() {
    if [[ $1 -ne 0 ]] ; then
        logger "Error $1 while running $3"
        exit $2
    fi
}

FILENAME=$(mktemp -t bigquery_changefile_XXXXXX.jsonl)
MIN_CHANGED=$(date --utc --date '2 days ago' +'%Y-%m-%dT%H:%M:%S')

logger "Export changes since $MIN_CHANGED to $FILENAME"

/usr/bin/psql "${DATABASE_URL}" -c "\copy (select response_jsonb from pub where response_jsonb is not null and last_changed_date between '$MIN_CHANGED'::timestamp and now() and updated > '1043-01-01'::timestamp) to '${FILENAME}';"
require_success $? 2 'psql'

logger "Created $FILENAME: $(stat -c%s """$FILENAME""") bytes"
logger "wc on $FILENAME: $(wc -l < """$FILENAME""") lines"

logger "Cleaning, fixing bad characters"
sed -i '/^\s*$/d' "$FILENAME"
sed -i 's:\\\\:\\:g' "$FILENAME"

TEMP_SUFFIX=$RANDOM
STAGING_TABLE="unpaywall.api_changes_staging_${TEMP_SUFFIX}"
logger "uploading changefile $FILENAME to staging table $STAGING_TABLE"
bq --headless --quiet load --source_format=CSV -F '\t' --schema 'data:string' $STAGING_TABLE $FILENAME
require_success $? 3 'bq'

EXTRACTED_STAGING_TABLE="unpaywall.api_changes_extracted_staging_${TEMP_SUFFIX}"
logger "extracting $STAGING_TABLE to $EXTRACTED_STAGING_TABLE"
bq --headless --quiet query --max_rows=0 --destination_table="$EXTRACTED_STAGING_TABLE" "$(cat bigquery_raw_transform.sql | sed "s/__API_RAW_STAGING_TABLE__/${STAGING_TABLE}/")"
require_success $? 4 'bq'

logger "delete raw staging table $STAGING_TABLE"
bq --headless --quiet rm -f $STAGING_TABLE
require_success $? 5 'bq'

LIVE_TABLE="unpaywall.api_live"
logger "delete updated rows from live table $LIVE_TABLE"
bq --headless --quiet query --use_legacy_sql=false "delete from $LIVE_TABLE where doi in (select doi from $EXTRACTED_STAGING_TABLE);"
require_success $? 6 'bq'

logger "insert updated rows from $EXTRACTED_STAGING_TABLE to live table $LIVE_TABLE"
bq --headless --quiet query --use_legacy_sql=false "\
    insert into $LIVE_TABLE (\
        doi, doi_url, is_oa, oa_status, best_oa_location, oa_locations, data_standard, title, year, journal_is_oa, journal_is_in_doaj, \
        journal_issns, journal_issn_l, journal_name, publisher, published_date, updated, genre, z_authors, json_data \
    ) select * from $EXTRACTED_STAGING_TABLE;"
require_success $? 7 'bq'

logger "delete extracted staging table $EXTRACTED_STAGING_TABLE"
bq --headless --quiet rm -f $EXTRACTED_STAGING_TABLE
require_success $? 8 'bq'
