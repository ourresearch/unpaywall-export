#!/bin/bash

#
# Bash script to export snapshot of unpaywall data
#

usage() {
    echo "
Usage: $0
Export a the crossref api snapshot from database to S3

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

FILENAME="crossref_api_snapshot_${TODAY_FOR_FILE}.jsonl"

logger "Filename : $FILENAME"

logger "Exporting database column to file"
/usr/bin/psql "${DATABASE_URL}?ssl=true" -c "\copy (select crossref_api_raw_new from pub where crossref_api_raw_new is not null) to '${FILENAME}';"
PSQL_EXIT_CODE=$?

if [[ $PSQL_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${PSQL_EXIT_CODE} while running psql"
    exit 2
fi


logger "Created $FILENAME: $(stat -c%s """$FILENAME""") bytes"

logger "Cleaning, fixing bad characters"
sed -i '/^\s*$/d' "$FILENAME"
sed -i 's:\\\\:\\:g' "$FILENAME"

logger "Compressing main file"
/bin/gzip -9 -c "$FILENAME" > "$FILENAME.gz"
GZIP_EXIT_CODE=$?
if [[ $GZIP_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${GZIP_EXIT_CODE} while running gzip"
    exit 3
fi
logger "Created archive $FILENAME.gz: $(stat -c%s """$FILENAME.gz""") bytes"

logger "Uploading crossref snapshot to main place"
$AWS_CP_CMD "$FILENAME.gz" "s3://crossref-api-snapshots/$FILENAME.gz" --acl public-read
S3CP_EXIT_CODE=$?
if [[ $S3CP_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${S3CP_EXIT_CODE} while uploading crossref export"
    exit 5
fi

logger "Done"

