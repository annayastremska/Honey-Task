-- Хто в якій популяції аналізу і в яких розрізах.
-- Нові: реєстрація 01.08–19.08, щоб повні 7 днів вмістились до 25.08.
-- Старі: реєстрація до 18.07, щоб мати повну базу 18.07–31.07.
-- Згода на листи ділить кожну популяцію на основну частину і контроль.

create or replace table users_pop as
select
    id,
    split_group,
    is_validated,
    cast(created_at as date) as reg_date,
    case
        when created_at >= date '2022-08-01' and cast(created_at as date) <= date '2022-08-19' then 'new'
        when created_at < date '2022-07-18' then 'old'
        else 'excluded'
    end as population,
    case when is_validated then 'consent' else 'control' end as consent,
    'country ' || country_code || ' / ' || default_os as segment,
    case
        when cast(created_at as date) between date '2022-08-01' and date '2022-08-07' then '01–07.08'
        when cast(created_at as date) between date '2022-08-08' and date '2022-08-14' then '08–14.08'
        when cast(created_at as date) between date '2022-08-15' and date '2022-08-19' then '15–19.08'
    end as reg_week
from read_csv_auto('users.csv');
