#!/bin/bash
#
# retrieve pmc ids

: ${DATABASE_URL:?environment variable must be set}

workdir=$(mktemp -d)
echo "*** working in $workdir ***"

# get the issn to pmc id file
echo "*** getting pmc id file ***"

wget \
    --directory=$workdir \
    --no-verbose \
    ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/PMC-ids.csv.gz

extracted_csv=$workdir/doi-to-pmc.csv

echo "*** extracting pmc id file ***"
gunzip -c $workdir/PMC-ids.csv.gz |
csvtool namedcol 'DOI,PMCID,Release Date' - > $extracted_csv

# bail if the file looks too small,
# because we're replacing the whole table, not updating

lines=$(wc -l $extracted_csv | cut -f1 -d' ')

if [ $lines -lt "5000000" ]; then
    echo "expected at least 5M lines in pmc id file, got $lines"
    exit 1
fi

echo "*** updating pmcid_lookup table ***"
sed "s|_CSV_FILE_|$extracted_csv|" load-pmc-lookup.sql | psql $DATABASE_URL
