#!/bin/bash

#
# Bash script to export snapshot of unpaywall data
#

usage() {
    echo "
Usage: $0
Export from database to S3

The following environmental variables are required:

DATABASE_URL     connection string for database
S3_SNAPSHOT_BUCKET      destination S3 bucket name 'unpaywall-data-snapshots'

Requires a properly configured aws cli to allow S3 upload.

"
}

logger() {
    echo "$(date --utc +'%Y-%m-%d %H:%M:%S') : $1"
}

if [[ "$DATABASE_URL" == "" ]]; then
    echo "Missing DATABASE_URL environment variable"
    usage
    exit 1
fi

# set default values for destination buckets if none provided
if [[ "$S3_SNAPSHOT_BUCKET" == "" ]]; then
    S3_SNAPSHOT_BUCKET="unpaywall-data-snapshots"
fi


if [[ "$AWS_PROFILE_EXPORT" != "" ]]; then
    $AWS_CP_CMD="/usr/bin/aws s3 cp --profile=$AWS_PROFILE_EXPORT "
else
    $AWS_CP_CMD="/usr/bin/aws s3 cp "
fi

TODAY_FOR_FILE=$(date --utc +'%Y-%m-%d %H%M%S' )

PROCESS="export_snapshot"
BUCKET="$S3_SNAPSHOT_BUCKET"
FILENAME="unpaywall_snapshot_${TODAY_FOR_FILE}.jsonl"

logger "Process  : $PROCESS"
logger "Filename : $FILENAME"

## temporarily comment this out and use existing filename instead
logger "Exporting database column to file"
/usr/bin/psql "${DATABASE_URL}?ssl=true" -c "\copy (select response_jsonb from pub) to '${FILENAME}';"
PSQL_EXIT_CODE=$?

if [[ $PSQL_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${PSQL_EXIT_CODE} while running psql"
    exit 2
fi

# logger "Using filename already given"
# FILENAME="unpaywall_snapshot_2018-03-29T113154.jsonl"

logger "Created $FILENAME: $(stat -c%s """$FILENAME""") bytes"

logger "Cleaning, removing versions"
sed -i 's/"publishedVersion"/null/g; s/"submittedVersion"/null/g; s/"acceptedVersion"/null/g' "$FILENAME"

logger "Cleaning, fixing bad characters"
sed -i 's/\\\\/\\/g' "$FILENAME"
sed -i 's/\n\n/\n/g' "$FILENAME"

logger "Compressing"
/bin/gzip -9 -c "$FILENAME" > "$FILENAME.gz"
GZIP_EXIT_CODE=$?
if [[ $GZIP_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${GZIP_EXIT_CODE} while running gzip"
    exit 3
fi
logger "Created archive $FILENAME.gz: $(stat -c%s """$FILENAME.gz""") bytes"

logger "Uploading snapshot"
$AWS_CP_CMD "$FILENAME.gz" "s3://$BUCKET/$FILENAME.gz" --acl public-read
S3CP_EXIT_CODE=$?
if [[ $S3CP_EXIT_CODE -ne 0 ]] ; then
    logger "Error ${S3CP_EXIT_CODE} while uploading export"
    exit 5
fi
logger "Done"

