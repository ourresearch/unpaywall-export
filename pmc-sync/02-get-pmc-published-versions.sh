#!/bin/bash
#
# retrieve published pmc ids

: ${DATABASE_URL:?environment variable must be set}

workdir=$(mktemp -d)
echo "*** working in $workdir ***"

# get the published pmc id file
id_file=$workdir/ids.csv
echo "*** getting published pmc id file $id_file ***"

python download-published-versions.py > $id_file

# bail if the file looks too small,
# because we're replacing the whole table, not updating

lines=$(wc -l $id_file | cut -f1 -d' ')

if [ $lines -lt "4500000" ]; then
    echo "expected at least 4.5M lines in published pmc id file, got $lines"
    exit 1
fi

echo "*** updating pmcid_published_version_lookup table ***"
sed "s|_CSV_FILE_|$id_file|" load-pmc-published-version-lookup.sql | psql $DATABASE_URL
