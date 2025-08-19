-- 1. РАСЧЕТ DAU
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),

-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),

-- Соединяем таблицы с новыми и активными пользователями
daily_retention AS
    (SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date)

-- Считаем DAU
SELECT CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц", day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND(1.0*COUNT(DISTINCT user_id)/MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date)),2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;
-- 2. РАСЧЕТ CONVERSION RATE
SELECT log_date, ROUND(1.0*COUNT(DISTINCT user_id) FILTER (WHERE event = 'order')/COUNT(DISTINCT user_id), 2) AS cr
FROM analytics_events JOIN cities USING (city_id)
WHERE (log_date BETWEEN '2021-05-01' AND '2021-06-30') AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date
LIMIT 10;
-- 3. РАСЧЕТ СРЕДНЕГО ЧЕКА
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT *,
            revenue::NUMERIC * commission::NUMERIC AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')
-- Считаем средний чек
SELECT DATE_TRUNC('month', log_date)::DATE AS "Месяц",
    COUNT(DISTINCT order_id) AS "Количество заказов",
    ROUND(SUM(commission_revenue), 2) AS "Сумма комиссии",
    ROUND(SUM(commission_revenue)/COUNT(DISTINCT order_id), 2) AS "Средний чек"
FROM orders
GROUP BY 1
ORDER BY 1;
-- 4. РАСЧЕТ LTV РЕСТОРАНОВ
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            revenue::NUMERIC * commission::NUMERIC AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

SELECT orders.rest_id, chain AS "Название сети", type AS "Тип кухни",
    ROUND(SUM(commission_revenue), 2) AS ltv
FROM orders LEFT JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
GROUP BY 1, 2, 3
ORDER BY ltv DESC
LIMIT 3;
-- 5. САМЫЕ ПОПУЛЯРНЫЕ БЛЮДА
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'), 

-- Рассчитываем два ресторана с наибольшим LTV 
top_ltv_restaurants AS
    (SELECT orders.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders
     JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2)

-- Находим блюда
SELECT chain AS "Название сети", name AS "Название блюда", spicy, fish, meat, 
    ROUND(SUM(commission_revenue::NUMERIC), 2) AS ltv
FROM orders JOIN top_ltv_restaurants USING (rest_id) LEFT JOIN dishes USING (object_id)
GROUP BY object_id, 1, 2, 3, 4, 5
ORDER BY 6 DESC
LIMIT 5;
-- 6. РАСЧЕТ RETENTION RATE
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),

-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

-- Считаем Retention Rate
SELECT log_date - first_date AS day_since_install, COUNT(DISTINCT user_id) AS retained_users,
    ROUND(1.0*COUNT(DISTINCT user_id)/MAX(COUNT(DISTINCT user_id)) OVER (), 2) AS retention_rate
FROM active_users JOIN new_users USING (user_id)
WHERE log_date >= first_date AND log_date - first_date <= 7
GROUP BY day_since_install
ORDER BY day_since_install;
-- 7. СРАВНЕНИЕ RETENTION RATE ПО ДВУМ КОГОРТАМ
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),

-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),

-- Соединяем таблицы с новыми и активными пользователями
daily_retention AS
    (SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date)

-- Строим итоговую таблицу
SELECT CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц", day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND(1.0*COUNT(DISTINCT user_id)/MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date)),2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;