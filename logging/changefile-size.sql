begin;


create temp table tmp_export_time as (
    select export_time from (
        select
            day at time zone 'UTC' + interval '8 hours' as export_time
        from
            generate_series (
                current_date + '0 days'::interval,
                current_date + '7 days'::interval,
                '1 day'
            ) as s(day)
    ) x
where
    extract(isodow from export_time) = '4'
    and export_time > now()
);

select export_time from tmp_export_time \gset
\set export_time '\'' :export_time '\''

insert into logs.next_data_feed_size (
    select
        now(),
        :export_time as next_export,
        count(1) as num_dois
    from pub
    where
        last_changed_date between :export_time::timestamp without time zone - '9 days'::interval and :export_time::timestamp without time zone
        and updated > '1043-01-01'::timestamp
);

commit;
