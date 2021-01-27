set -e
set -o pipefail

csv_fields=\
"Journal title,"\
"Alternative title,"\
"Journal ISSN (print version),"\
"Journal EISSN (online version),"\
"Journal license"

curl -s -L https://doaj.org/csv |
csvtool namedcol "$csv_fields" -
