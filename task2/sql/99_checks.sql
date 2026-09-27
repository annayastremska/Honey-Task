-- Звірка таблиць із сирими даними: різниця в кожному рядку має бути 0.

with raw_users as (select count(*) as n from read_csv_auto('users.csv'))
select 'усі користувачі розкладені по популяціях' as check_name,
       (select n from raw_users) as expected, (select count(*) from users_pop) as actual

union all
select 'у метриках — усі нові й старі, по одному рядку',
       (select count(*) from users_pop where population in ('new', 'old')),
       (select count(distinct id) from user_metrics)

union all
select 'виручка нових = сирі оплати у їхніх вікнах без 14–15.08',
       (select sum(t.amount) from transactions t join windows w on t.user_id = w.id
        where w.population = 'new' and t.date between w.test_start and w.test_end
          and t.date not in (date '2022-08-14', date '2022-08-15')),
       (select sum(revenue) from user_metrics where population = 'new')

union all
select 'виручка старих у тесті = сирі оплати 01.08–25.08 без 14–15.08',
       (select sum(t.amount) from transactions t join users_pop u on t.user_id = u.id
        where u.population = 'old' and t.date between date '2022-08-01' and date '2022-08-25'
          and t.date not in (date '2022-08-14', date '2022-08-15')),
       (select sum(revenue) from user_metrics where population = 'old')

union all
select 'виручка старих у базі = сирі оплати 18.07–31.07',
       (select sum(t.amount) from transactions t join users_pop u on t.user_id = u.id
        where u.population = 'old' and t.date between date '2022-07-18' and date '2022-07-31'),
       (select sum(revenue_base) from user_metrics where population = 'old')

union all
select 'активні дні нових = сирі візити у їхніх вікнах',
       (select count(*) from visits v join windows w on v.user_id = w.id
        where w.population = 'new' and v.date between w.test_start and w.test_end),
       (select sum(active_days) from user_metrics where population = 'new')

union all
select 'епізоди старих у тесті = сирий лог 01.08–25.08',
       (select sum(r.count_episodes) from reads r join users_pop u on r.user_id = u.id
        where u.population = 'old' and r.date between date '2022-08-01' and date '2022-08-25'),
       (select sum(episodes) from user_metrics where population = 'old')

union all
select 'денні нові: сума активних = сума активних днів у метриках',
       (select sum(active_days) from user_metrics where population = 'new'),
       (select sum(active_users) from daily_new)

union all
select 'денні старі: виручка тесту = виручка тесту в метриках',
       (select sum(revenue) from user_metrics where population = 'old'),
       (select sum(revenue) from daily_old where is_test and not missing_revenue)

union all
select 'проміжні старі на 25.08 = фінальна виручка старих',
       (select sum(revenue) from user_metrics where population = 'old'),
       (select sum(revenue) from interim_old where look_date = date '2022-08-25');
