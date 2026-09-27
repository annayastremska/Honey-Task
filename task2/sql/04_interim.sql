-- Метрики старих станом на кожну дату перегляду: тест від 01.08 до дати перегляду.
-- Для нових окрема таблиця не потрібна: на дату перегляду беруться ті, чиє 7-денне вікно вже закрилось.

create or replace table interim_old as
with looks as (
    select * from (values (date '2022-08-08'), (date '2022-08-15'), (date '2022-08-22'), (date '2022-08-25')) as l(look_date)
),
grid as (
    select u.id, u.consent, u.split_group, l.look_date
    from users_pop u cross join looks l
    where u.population = 'old'
)
select
    g.id, g.consent, g.split_group, g.look_date,
    coalesce((select sum(t.amount) from transactions t
              where t.user_id = g.id and t.date between date '2022-08-01' and g.look_date
                and t.date not in (date '2022-08-14', date '2022-08-15')), 0) as revenue,
    coalesce((select count(*) from visits v
              where v.user_id = g.id and v.date between date '2022-08-01' and g.look_date), 0) as active_days
from grid g;
