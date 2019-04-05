set -e
set -o pipefail

csv_fields=\
"Journal title,"\
"Alternative title,"\
"Journal ISSN (print version),"\
"Journal EISSN (online version),"\
"First calendar year journal provided online Open Access content,"\
"Journal license"

curl -s curl https://doaj.org/csv |
csvtool namedcol "$csv_fields" -
