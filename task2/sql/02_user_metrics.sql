-- Метрики кожного користувача за його вікно.
-- Нові: 7 днів від реєстрації. Старі: тест 01.08–25.08 і база 18.07–31.07.
-- 14–15.08 оплат у даних нема (втрата даних), тому ці дні не входять у виручку.

create or replace table transactions as
select user_id, cast(created_at as date) as date, amount
from read_csv_auto('transactions.csv');

create or replace table visits as
select user_id, cast(date as date) as date
from read_csv_auto('visits.csv');

create or replace table reads as
select user_id, cast(date as date) as date, count_episodes
from read_csv_auto('reading_log.csv');

create or replace table windows as
select
    id, population,
    case population when 'new' then reg_date else date '2022-08-01' end as test_start,
    case population when 'new' then reg_date + 6 else date '2022-08-25' end as test_end,
    case population when 'old' then date '2022-07-18' end as base_start,
    case population when 'old' then date '2022-07-31' end as base_end
from users_pop
where population in ('new', 'old');

create or replace table user_metrics as
with rev as (
    select w.id,
        sum(t.amount) filter (where t.date between w.test_start and w.test_end
                                and t.date not in (date '2022-08-14', date '2022-08-15')) as revenue,
        sum(t.amount) filter (where t.date between w.base_start and w.base_end)         as revenue_base
    from windows w join transactions t on t.user_id = w.id
    group by w.id
),
act as (
    select w.id,
        count(*) filter (where v.date between w.test_start and w.test_end) as active_days,
        count(*) filter (where v.date between w.base_start and w.base_end) as active_days_base
    from windows w join visits v on v.user_id = w.id
    group by w.id
),
eps as (
    select w.id,
        sum(r.count_episodes) filter (where r.date between w.test_start and w.test_end) as episodes,
        sum(r.count_episodes) filter (where r.date between w.base_start and w.base_end) as episodes_base
    from windows w join reads r on r.user_id = w.id
    group by w.id
)
select
    u.id, u.population, u.consent, u.split_group, u.segment, u.reg_week, u.reg_date,
    coalesce(rev.revenue, 0)      as revenue,
    coalesce(rev.revenue, 0) > 0  as payer,
    coalesce(act.active_days, 0)  as active_days,
    coalesce(eps.episodes, 0)     as episodes,
    -- база лише для старих; у нових даних до тесту нема
    case when u.population = 'old' then coalesce(rev.revenue_base, 0) end      as revenue_base,
    case when u.population = 'old' then coalesce(rev.revenue_base, 0) > 0 end  as payer_base,
    case when u.population = 'old' then coalesce(act.active_days_base, 0) end  as active_days_base,
    case when u.population = 'old' then coalesce(eps.episodes_base, 0) end     as episodes_base
from users_pop u
left join rev using (id)
left join act using (id)
left join eps using (id)
where u.population in ('new', 'old');
