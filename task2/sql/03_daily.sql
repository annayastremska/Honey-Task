-- Денні показники для когортної динаміки.
-- Нові: за днем від реєстрації (0–6) у кожній тижневій когорті.
-- Старі: за календарним днем від бази 18.07 до кінця тесту 25.08.

create or replace table daily_new as
with days as (
    select u.id, u.consent, u.split_group, u.reg_week, u.reg_date + cast(d.n as integer) as date, d.n as day_n
    from users_pop u
    cross join range(0, 7) as d(n)
    where u.population = 'new'
)
select
    d.consent, d.split_group, d.reg_week, d.day_n,
    count(*)                    as users,
    count(v.user_id)            as active_users,
    coalesce(sum(t.revenue), 0) as revenue,
    -- у ці дні оплат у даних нема
    bool_or(d.date in (date '2022-08-14', date '2022-08-15')) as has_missing_revenue_days
from days d
left join visits v on v.user_id = d.id and v.date = d.date
left join (
    select user_id, date, sum(amount) as revenue from transactions group by all
) t on t.user_id = d.id and t.date = d.date
group by all;

create or replace table daily_old as
with days as (
    select u.id, u.consent, u.split_group, cast(d.date as date) as date
    from users_pop u
    cross join range(date '2022-07-18', date '2022-08-26', interval 1 day) as d(date)
    where u.population = 'old'
)
select
    d.consent, d.split_group, d.date,
    d.date >= date '2022-08-01' as is_test,
    d.date in (date '2022-08-14', date '2022-08-15') as missing_revenue,
    count(*)                    as users,
    count(v.user_id)            as active_users,
    coalesce(sum(t.revenue), 0) as revenue
from days d
left join visits v on v.user_id = d.id and v.date = d.date
left join (
    select user_id, date, sum(amount) as revenue from transactions group by all
) t on t.user_id = d.id and t.date = d.date
group by all;
