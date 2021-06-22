#!/bin/bash
#
# adds a row to the postgres table logs.trailing_week_api_changes reflecting change statistics for the last week

set -e

: ${DATABASE_URL:?environment variable must be set}

echo extracting query to temp table

bq_temp_table="journals.tmp_week_api_changes_$RANDOM"

bq query \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 <<BQ_SQL
        select
            current_datetime() as time,
            num_changed,
            num_new_dois,
            num_became_oa,
            num_became_closed,
            num_changed_oa_status,
            num_changed_best_url,
            num_changed_oa_locations,
            num_changed_title,
            num_changed_genre,
            num_changed_publisher,
            num_changed_journal_name,
            num_changed_authors,
            num_changed_journal_issns,
            num_changed_journal_issn_l,
            num_changed_published_date
        from unpaywall.api_changed_last_week_stats;
BQ_SQL

# extract the table to CSV and delete the temp table

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/tmp_week_api_changes_$RANDOM.csv"

bq extract \
    --headless --quiet \
    --project_id='unpaywall-bhd' \
    --format=csv \
    $bq_temp_table \
    $gcs_csv

bq rm -f \
    --project_id='unpaywall-bhd' \
    $bq_temp_table

# download the CSV and delete the remote file

workdir=$(mktemp -d)
local_csv=$workdir/last_week_change_stats.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# insert row

echo updating pg logs.trailing_week_api_changes

psql $DATABASE_URL <<SQL
begin;
\\copy logs.trailing_week_api_changes from $local_csv csv header
commit;
SQL
