import requests

from sys import stdout

retstart = 0
pagesize = 100*1000  # the max retmax is 100k
retmax = pagesize

while retmax >= pagesize:
	# look for published, because want to default to author manuscript if we don't know for sure it is published
	url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pmc&term=pmc%20all[filter]%20NOT%20author%20manuscript[filter]&retmax={retmax}&retstart={retstart}&retmode=json".format(
		retmax=retmax, retstart=retstart)

	r = requests.get(url)
	json_data = r.json()
	count = int(json_data["esearchresult"]["count"])
	retmax = int(json_data["esearchresult"]["retmax"])  # get new retmax, which is 0 when no more pages left
	published_version_pmcids_raw = json_data["esearchresult"]["idlist"]
	published_version_pmcids = ["pmc{}".format(pmcid) for pmcid in published_version_pmcids_raw]
	for pmcid in published_version_pmcids:
		stdout.writelines(u'{}\n'.format(pmcid))
	retstart += retmax
