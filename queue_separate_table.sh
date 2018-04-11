#!/bin/bash

#
# Bash script implementation of queue_separate_table.py functionality
#
# Export from 'export_main_changed_with_versions' or 'export_main_no_versions' view to files in S3.
# Apply time filter if needed
#

usage() {
    echo "
Usage: $0  --export_with_versions|--export_no_versions [--view <view_name>] [--week]
Export from database to S3

--export_with_versions  perform export with versions
--export_no_versions    perform export without versions
--view <view_name>      view name to export from
--week                  export only last week of data

The following environmental variables are required:

PSQL_CONNECT_STRING     connection string for database
S3_WITH_VERSIONS        destination S3 bucket name, must be name suitable to use
                        with 'aws s3 cp' command. Default is 'oadoi-for-clarivate'
S3_NO_VERSIONS          destination S3 bucket name, must be name suitable to use
                        with 'aws s3 cp' command. Default is 'unpaywall-data-updates'

Requires a properly configured aws cli to allow S3 upload.

"
}

logger() {
    echo "$(date --utc +'%Y-%m-%d %H:%M:%S') : $1"
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --export_with_versions)
        EXPORT_WITH_VERSIONS="yes"
        shift # past argument
        ;;
        --export_no_versions)
        EXPORT_NO_VERSIONS="yes"
        shift # past argument
        ;;
        --view)
        VIEW="$2"
        shift # past argument
        shift # past value
        ;;
        --week)
        WEEK="yes"
        shift # past argument
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done

# make sure we have an export type and only one
if [[ "$EXPORT_WITH_VERSIONS" == "" ]] && [[ "$EXPORT_NO_VERSIONS" == "" ]]; then
    echo "Need export_with_versions or export_no_versions"
    usage
    exit 1
fi
if [[ "$EXPORT_WITH_VERSIONS" == "yes" ]] && [[ "$EXPORT_NO_VERSIONS" == "yes" ]]; then
    echo "Need only one of export_with_versions and export_no_versions"
    usage
    exit 1
fi

if [[ "$PSQL_CONNECT_STRING" == "" ]]; then
    echo "Missing PSQL_CONNECT_STRING environment variable"
    usage
    exit 1
fi

# set default values for destination buckets if none provided
if [[ "$S3_WITH_VERSIONS" == "" ]]; then
    S3_WITH_VERSIONS="oadoi-for-clarivate"
fi
if [[ "$S3_NO_VERSIONS" == "" ]]; then
    S3_NO_VERSIONS="unpaywall-data-updates"
fi

if [[ "$AWS_PROFILE_EXPORT" != "" ]]; then
    AWS_CMD="/usr/bin/aws s3 cp --profile=$AWS_PROFILE_EXPORT "
else
    AWS_CMD="/usr/bin/aws s3 cp "
fi

TODAY_FOR_FILE=$(date --utc +'%Y-%m-%d %H%M%S' )
LAST_WEEK_FOR_VIEW=$(date --utc --date '9 day ago' +'%Y-%m-%d %H:%M:%S')
LAST_WEEK_FOR_FILE=$(date --utc --date '9 day ago' +'%Y-%m-%d %H%M%S')

if [[ "$EXPORT_WITH_VERSIONS" == "yes" ]]; then

    PROCESS="export_with_versions"
    BUCKET="$S3_WITH_VERSIONS"

    if [[ "$WEEK" == "yes" ]]; then
        VIEW="export_main_changed_with_versions where last_changed_date >= '${LAST_WEEK_FOR_VIEW}'::timestamp and updated > '1043-01-01'::timestamp"
        FILENAME="changed_dois_with_versions_${LAST_WEEK_FOR_FILE}_to_${TODAY_FOR_FILE}.csv"
    else
        FILENAME="dois_with_versions_${TODAY_FOR_FILE}.csv"
    fi

    if  [[ "$VIEW" == "" ]]; then
        VIEW="export_main_changed_with_versions"
    fi
else

    PROCESS="export_no_versions"
    BUCKET="$S3_WITH_VERSIONS"

    if [[ "$WEEK" == "yes" ]]; then
        VIEW="export_main_changed_no_versions where last_changed_date >= '${LAST_WEEK_FOR_VIEW}'::timestamp and updated > '1043-01-01'::timestamp"
        FILENAME="changed_dois_${LAST_WEEK_FOR_FILE}_to_${TODAY_FOR_FILE}.csv"
    else
        FILENAME="dois_${TODAY_FOR_FILE}.csv"
    fi

    if  [[ "$VIEW" == "" ]]; then
        VIEW="export_main_no_versions"
    fi
fi

logger "Process  : $PROCESS"
logger "View     : $VIEW"
logger "Filename : $FILENAME"

logger "Exporting view to file"
/usr/bin/psql "${PSQL_CONNECT_STRING}?ssl=true" -c "\copy (select * from ${VIEW}) to '${FILENAME}' WITH (FORMAT CSV, HEADER);"
PSQL_EXIT_CODE=$?

if [[ $PSQL_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${PSQL_EXIT_CODE} while running psql"
    exit 2
fi
logger "Created $FILENAME: $(stat -c%s """$FILENAME""") bytes"

logger "Compressing"
/bin/gzip -9 -c "$FILENAME" > "$FILENAME.gz"
GZIP_EXIT_CODE=$?
if [[ $GZIP_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${GZIP_EXIT_CODE} while running gzip"
    exit 3
fi
logger "Created archive $FILENAME.gz: $(stat -c%s """$FILENAME.gz""") bytes"

logger "Computing checksum"
/usr/bin/md5sum "$FILENAME.gz" > "$FILENAME.gz.DONE"
MD5SUM_EXIT_CODE=$?
if [[ $MD5SUM_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${MD5SUM_EXIT_CODE} while running md5sum"
    exit 4
fi
logger "Created checksum $FILENAME.gz.DONE: $(stat -c%s """$FILENAME.gz.DONE""") bytes"

logger "Uploading export"
$AWS_CMD "$FILENAME.gz" "s3://$BUCKET/$FILENAME.gz"
S3CP_EXIT_CODE=$?
if [[ $S3CP_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${S3CP_EXIT_CODE} while uploading export"
    exit 5
fi
logger "Done"

logger "Uploading export checksum"
$AWS_CMD "$FILENAME.gz.DONE" "s3://$BUCKET/$FILENAME.gz.DONE"
S3CP_EXIT_CODE=$?
if [[ $S3CP_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${S3CP_EXIT_CODE} while uploading export checksum"
    exit 5
fi
logger "Done"

# clean-up
rm -f "$FILENAME"
rm -f "$FILENAME.gz"
rm -f "$FILENAME.gz.DONE"
