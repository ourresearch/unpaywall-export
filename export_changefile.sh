#!/bin/bash

#
# Bash script to export weekly changefiles of unpaywall data
#
# Export from 'export_main_changed_with_versions' or 'export_main_no_versions' view to files in S3.
# All the data that has been changed in the last week
#

usage() {
    echo "
Usage: $0
Export a weekly changefule from database to S3

The following environmental variables are required:

DATABASE_URL     connection string for database
Requires a properly configured aws cli to allow S3 upload.

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

if [[ "$AWS_PROFILE_EXPORT" != "" ]]; then
    AWS_CP_CMD="/usr/bin/aws s3 cp --profile=$AWS_PROFILE_EXPORT "
else
    AWS_CP_CMD="/usr/bin/aws s3 cp "
fi

TODAY_FOR_FILE=$(date --utc +'%Y-%m-%dT%H%M%S' )
LAST_WEEK_FOR_VIEW=$(date --utc --date '9 day ago' +'%Y-%m-%dT%H:%M:%S')
LAST_WEEK_FOR_FILE=$(date --utc --date '9 day ago' +'%Y-%m-%dT%H%M%S')


# function
export_file() {

    if [ "$1" == 'export_no_versions' ] ; then
        PROCESS="export_no_versions"
        BUCKET="unpaywall-data-feed"
        FILENAME="changed_dois_${LAST_WEEK_FOR_FILE}_to_${TODAY_FOR_FILE}"
        CSV_VIEW="export_main_changed_no_versions"
    else
        PROCESS="export_with_versions"
        BUCKET="oadoi-for-clarivate"
        FILENAME="changed_dois_with_versions_${LAST_WEEK_FOR_FILE}_to_${TODAY_FOR_FILE}"
        CSV_VIEW="export_main_changed_with_versions"
    fi

    if [ "$2" == 'csv' ] ; then
        FILENAME="${FILENAME}.csv"
    else
        FILENAME="${FILENAME}.jsonl"
    fi

    logger "Process  : $PROCESS"
    logger "Filename : $FILENAME"

    if [ "$2" == 'csv' ] ; then
        logger "Exporting view to file csv"
        /usr/bin/psql "${DATABASE_URL}" -c "\copy (select * from ${CSV_VIEW} where last_changed_date >= '${LAST_WEEK_FOR_VIEW}'::timestamp and updated > '1043-01-01'::timestamp) to '${FILENAME}' WITH (FORMAT CSV, HEADER);"
        PSQL_EXIT_CODE=$?
    else
        logger "Exporting view to file json"
        /usr/bin/psql "${DATABASE_URL}" -c "\copy (select response_jsonb from pub where last_changed_date >= '${LAST_WEEK_FOR_VIEW}'::timestamp and updated > '1043-01-01'::timestamp) to '${FILENAME}';"
        PSQL_EXIT_CODE=$?
    fi

    if [[ $PSQL_EXIT_CODE -ne 0 ]] ; then
        logger "Error ${PSQL_EXIT_CODE} while running psql"
        exit 2
    fi
    logger "Created $FILENAME: $(stat -c%s """$FILENAME""") bytes"
    logger "wc on $FILENAME: $(wc -l < """$FILENAME""") lines"

    if [ "$2" == 'json' ] ; then
        logger "Cleaning, fixing bad characters"
        sed -i 's/\\\\/\\/g' "$FILENAME"
        sed -i 's/\n\n/\n/g' "$FILENAME"
    fi

    if [ "$1" == 'export_no_versions' ] ; then
        logger "Cleaning, removing versions"
        sed -i 's/"publishedVersion"/null/g; s/"submittedVersion"/null/g; s/"acceptedVersion"/null/g' "$FILENAME"
    fi

    logger "Compressing"
    /bin/gzip -9 -c "$FILENAME" > "$FILENAME.gz"
    GZIP_EXIT_CODE=$?
    if [[ $GZIP_EXIT_CODE -ne 0 ]] ; then
        logger "Error ${GZIP_EXIT_CODE} while running gzip"
        exit 3
    fi
    logger "Created archive $FILENAME.gz: $(stat -c%s """$FILENAME.gz""") bytes"

    logger "Uploading export"
    UPDATED=$(date --utc +'%Y-%m-%dT%H:%M:%S')
    LINES=$(wc -l < $"""$FILENAME""")
    $AWS_CP_CMD "$FILENAME.gz" "s3://$BUCKET/$FILENAME.gz" --metadata """lines=$LINES,updated='$UPDATED'"""
    S3CP_EXIT_CODE=$?
    if [[ $S3CP_EXIT_CODE -ne 0 ]] ; then
        logger "Error ${S3CP_EXIT_CODE} while uploading export"
        exit 5
    fi
    logger "Done"
    logger "***"
    logger ""
}

# export no version
export_file export_no_versions csv
export_file export_no_versions json

# export with versions
export_file export_with_versions csv
export_file export_with_versions json

