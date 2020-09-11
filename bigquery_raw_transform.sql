#standardSQL
create temp function extract_oa_location(json string) AS (
  (
    select
      case when json is null then null
      else struct(
        cast(json_extract_scalar(json, '$.updated') as datetime) as updated,
        json_extract_scalar(json, '$.url') as url,
        json_extract_scalar(json, '$.url_for_pdf') as url_for_pdf,
        json_extract_scalar(json, '$.url_for_landing_page') as url_for_landing_page,
        json_extract_scalar(json, '$.evidence') as evidence,
        json_extract_scalar(json, '$.license') as license,
        json_extract_scalar(json, '$.version') as version,
        json_extract_scalar(json, '$.host_type') as host_type,
        cast(json_extract_scalar(json, '$.is_best') as bool) as is_best,
        json_extract_scalar(json, '$.pmh_id') as pmh_id,
        json_extract_scalar(json, '$.endpoint_id') as endpoint_id,
        cast(json_extract_scalar(json, '$.oa_date') as date) as oa_date
      )
      end as oa_location
  )
);

create temp function extract_oa_locations(json string) AS (
  (
    select array_agg(locations ignore nulls) as oa_locations
    from unnest ([
      extract_oa_location(json_extract(json, '$[0]')),
      extract_oa_location(json_extract(json, '$[1]')),
      extract_oa_location(json_extract(json, '$[2]')),
      extract_oa_location(json_extract(json, '$[3]')),
      extract_oa_location(json_extract(json, '$[4]')),
      extract_oa_location(json_extract(json, '$[5]')),
      extract_oa_location(json_extract(json, '$[6]')),
      extract_oa_location(json_extract(json, '$[7]')),
      extract_oa_location(json_extract(json, '$[8]')),
      extract_oa_location(json_extract(json, '$[9]'))
    ]) locations
  )
);

create temp function extract_author(json string) AS (
  (
    select
      case when json is null then null
      else struct(
        json_extract_scalar(json, '$.given') as given,
        json_extract_scalar(json, '$.family') as family,
        json_extract_scalar(json, '$.ORCID') as ORCID,
        cast(json_extract_scalar(json, '$.authenticated-orcid') as bool) as authenticated_orcid
      )
      end as oa_location
  )
);

create temp function extract_authors(json string) AS (
  (
    select array_agg(authors ignore nulls) as authors
    from unnest ([
      extract_author(json_extract(json, '$[0]')),
      extract_author(json_extract(json, '$[1]')),
      extract_author(json_extract(json, '$[2]')),
      extract_author(json_extract(json, '$[3]')),
      extract_author(json_extract(json, '$[4]')),
      extract_author(json_extract(json, '$[5]')),
      extract_author(json_extract(json, '$[6]')),
      extract_author(json_extract(json, '$[7]')),
      extract_author(json_extract(json, '$[8]')),
      extract_author(json_extract(json, '$[9]'))
    ]) authors
  )
);

select
  json_extract_scalar(data, '$.doi') as doi,
  concat('https://doi.org/', json_extract_scalar(data, '$.doi')) as doi_url,
  cast(json_extract_scalar(data, '$.is_oa') as bool) as is_oa,
  json_extract_scalar(data, '$.oa_status') as oa_status,
  extract_oa_location(json_extract(data, '$.best_oa_location')) as best_oa_location,
  extract_oa_location(json_extract(data, '$.first_oa_location')) as first_oa_location,
  extract_oa_locations(json_extract(data, "$.oa_locations")) as oa_locations,
  cast(json_extract_scalar(data, '$.data_standard') as INT64) as data_standard,
  json_extract_scalar(data, '$.title') as title,
  json_extract_scalar(data, '$.year') as year,
  cast(json_extract_scalar(data, '$.journal_is_oa') as bool) as journal_is_oa,
  cast(json_extract_scalar(data, '$.journal_is_in_doaj') as bool) as journal_is_in_doaj,
  json_extract_scalar(data, '$.journal_issns') as journal_issns,
  json_extract_scalar(data, '$.journal_issn_l') as journal_issn_l,
  json_extract_scalar(data, '$.journal_name') as journal_name,
  json_extract_scalar(data, '$.publisher') as publisher,
  cast(replace(json_extract(data, '$.published_date'), '"', '') as date) as published_date,
  cast(replace(json_extract(data, '$.updated'), '"', '') as datetime) as updated,
  json_extract_scalar(data, '$.genre') as genre,
  extract_authors(json_extract(data, '$.z_authors')) as z_authors,
  json_extract(data, '$') as json_data
from `__API_RAW_STAGING_TABLE__`
;
