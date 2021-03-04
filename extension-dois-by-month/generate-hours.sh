#!/bin/bash

# usage: generate-hours.sh day ("YYYY-MM-DD")
# list all of a day's hours in papertrail url format
# eg 2018-12-01-01

day=$1
first_hour="${day}T00:00:00Z"
last_hour=$(date -u -d "$first_hour + 1 day" +%Y-%m-%dT%H:00:00Z)
hour=$first_hour

while [ "$hour" \< "$last_hour" ]; do
    hour_str=$(date -u -d "$hour" +%Y-%m-%d-%H)
    echo $hour_str
    hour=$(date -u -d "$hour + 1 hour" +%Y-%m-%dT%H:00:00Z)
done
