set -e
set -o pipefail

csv_fields=\
"Journal title,"\
"Alternative title,"\
"Journal ISSN (print version),"\
"Journal EISSN (online version),"\
"When did the journal start to publish all content using an open license?,"\
"Journal license"

curl -s -L https://doaj.org/csv |
csvtool namedcol "$csv_fields" -
