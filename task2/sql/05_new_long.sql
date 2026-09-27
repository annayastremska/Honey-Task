-- Нові з реєстрацією 01–07.08: у них є щонайменше 18 днів даних (день 0–17).
-- Метрики за дні 0–6 і 7–17 від реєстрації — чи не падає b нижче a після першого тижня.

create or replace table new_long as
with users as (
    select id, consent, split_group, reg_date
    from users_pop
    where population = 'new' and reg_date <= date '2022-08-07'
),
rev as (
    select u.id,
        sum(t.amount) filter (where t.date - u.reg_date between 0 and 6)  as revenue_0_6,
        sum(t.amount) filter (where t.date - u.reg_date between 7 and 17) as revenue_7_17
    from users u join transactions t on t.user_id = u.id
    where t.date not in (date '2022-08-14', date '2022-08-15')
    group by u.id
),
act as (
    select u.id,
        count(*) filter (where v.date - u.reg_date between 0 and 6)  as active_0_6,
        count(*) filter (where v.date - u.reg_date between 7 and 17) as active_7_17
    from users u join visits v on v.user_id = u.id
    group by u.id
)
select
    u.id, u.consent, u.split_group,
    coalesce(act.active_0_6, 0)   as active_0_6,
    coalesce(act.active_7_17, 0)  as active_7_17,
    coalesce(rev.revenue_0_6, 0)  as revenue_0_6,
    coalesce(rev.revenue_7_17, 0) as revenue_7_17
from users u
left join act using (id)
left join rev using (id);

-- Частка тих, хто зайшов, по днях 0–17
create or replace table new_long_daily as
select u.consent, u.split_group, d.n as day_n,
       count(*)         as users,
       count(v.user_id) as active_users
from new_long u
join users_pop p using (id)
cross join range(0, 18) as d(n)
left join visits v on v.user_id = u.id and v.date = p.reg_date + cast(d.n as integer)
group by all;
