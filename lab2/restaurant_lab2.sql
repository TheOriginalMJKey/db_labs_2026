-- Лабораторная работа № 2. Информационная система ресторана (PostgreSQL).
-- Запускать ПОСЛЕ создания и заполнения пяти таблиц из ЛР № 1.
-- Исходные таблицы не удаляются, ограничения не меняются.
-- Блоки 1.1 и 1.2 выполняются последовательно; аналитические SELECT можно повторять.

-- =============================================================
-- ЧАСТЬ 1.1. СОДЕРЖАТЕЛЬНЫЙ НАБОР ДАННЫХ
-- =============================================================
BEGIN;

-- Столики 50 и 51 намеренно не будут использоваться в заказах.
INSERT INTO dining_tables (table_number, capacity, status) VALUES
 (5, 4, 'free'), (6, 6, 'occupied'), (7, 2, 'reserved'),
 (8, 8, 'free'), (9, 4, 'occupied'), (10, 2, 'free'),
 (11, 6, 'free'), (12, 4, 'reserved'),
 (50, 2, 'free'), (51, 20, 'reserved')
ON CONFLICT (table_number) DO NOTHING;

INSERT INTO employees (full_name, role, phone, hire_date) VALUES
 ('Кузнецова Мария Андреевна', 'waiter', '+79995556677', DATE '2025-09-01'),
 ('Орлов Николай Павлович', 'waiter', '+79996667788', DATE '2025-10-15'),
 ('Волкова Елена Викторовна', 'chef', '+79997778899', DATE '2025-06-20'),
 ('Захаров Павел Ильич', 'manager', '+79998889900', DATE '2025-01-10')
ON CONFLICT (phone) DO NOTHING;

-- Часть дополнительных блюд сознательно ни разу не заказывали.
INSERT INTO menu_items (name, category, price, is_available) VALUES
 ('Брускетта', 'starter', 320.00, TRUE),
 ('Суп Том Ям', 'starter', 690.00, TRUE),
 ('Борщ', 'starter', 390.00, TRUE),
 ('Куриный шницель', 'main', 750.00, TRUE),
 ('Лосось на гриле', 'main', 1250.00, TRUE),
 ('Чизкейк', 'dessert', 410.00, TRUE),
 ('Мороженое', 'dessert', 250.00, TRUE),
 ('Чай зелёный', 'beverage', 180.00, TRUE),
 ('Лимонад', 'beverage', 280.00, TRUE),
 ('Редкое сезонное блюдо', 'main', 2200.00, FALSE)
ON CONFLICT (name) DO NOTHING;

-- 48 дополнительных заказов: по 12 в январе, феврале, марте и апреле 2026 г.
-- Варианты состояний: open, paid, cancelled.
-- Фиксированные даты позволяют повторить наполнение без дублирования заказов.
WITH source_orders AS (
    SELECT
        g.n,
        (TIMESTAMP '2026-01-10 12:00:00'
         + ((g.n - 1) / 12) * INTERVAL '1 month'
         + ((g.n - 1) % 12) * INTERVAL '1 day') AS created_at,
        ((g.n - 1) % 12) + 1 AS table_number,
        CASE WHEN g.n % 2 = 0 THEN '+79991112233' ELSE '+79992223344' END AS waiter_phone,
        CASE
            WHEN g.n % 8 = 0 THEN 'cancelled'
            WHEN g.n % 3 = 0 THEN 'open'
            ELSE 'paid'
        END AS order_status
    FROM generate_series(1, 48) AS g(n)
)
INSERT INTO orders (table_id, employee_id, status, created_at, closed_at)
SELECT dt.table_id, e.employee_id, s.order_status, s.created_at,
       CASE WHEN s.order_status IN ('paid', 'cancelled')
            THEN s.created_at + INTERVAL '90 minutes'
            ELSE NULL END
FROM source_orders s
JOIN dining_tables dt ON dt.table_number = s.table_number
JOIN employees e ON e.phone = s.waiter_phone
WHERE NOT EXISTS (
    SELECT 1 FROM orders o
    WHERE o.table_id = dt.table_id
      AND o.employee_id = e.employee_id
      AND o.created_at = s.created_at
);

-- В каждом новом заказе по три разных блюда (не менее 144 новых строк).
-- Для отменённых заказов позиции тоже отменены.
-- Для открытых заказов: одно блюдо готовится, остальные ожидают/поданы.
-- У некоторых заказов напиток предоставлен бесплатно (price_at_time = 0).
WITH seeded_orders AS (
    SELECT o.order_id, o.status,
           ROW_NUMBER() OVER (ORDER BY o.created_at, o.order_id) AS seq
    FROM orders o
    WHERE o.created_at >= TIMESTAMP '2026-01-10 12:00:00'
      AND o.created_at < TIMESTAMP '2026-05-01 00:00:00'
      AND EXTRACT(HOUR FROM o.created_at) = 12
      AND EXTRACT(MINUTE FROM o.created_at) = 0
      AND EXTRACT(SECOND FROM o.created_at) = 0
), chosen_items AS (
    SELECT s.order_id, s.status, s.seq, v.slot, v.item_name, v.qty
    FROM seeded_orders s
    CROSS JOIN LATERAL (VALUES
        (1, CASE WHEN s.seq % 2 = 0 THEN 'Салат Цезарь' ELSE 'Брускетта' END, 1 + (s.seq % 3)::int),
        (2, CASE WHEN s.seq % 2 = 0 THEN 'Паста Карбонара' ELSE 'Куриный шницель' END, 1 + (s.seq % 2)::int),
        (3, 'Капучино', 1 + (s.seq % 3)::int)
    ) AS v(slot, item_name, qty)
)
INSERT INTO order_items (order_id, item_id, quantity, price_at_time, item_status)
SELECT c.order_id, mi.item_id, c.qty,
       CASE WHEN c.slot = 3 AND c.seq % 11 = 0
            THEN 0::numeric(10,2)
            ELSE mi.price END,
       CASE
           WHEN c.status = 'cancelled' THEN 'cancelled'
           WHEN c.status = 'paid' THEN 'served'
           WHEN c.slot = 2 THEN 'cooking'
           WHEN c.slot = 1 THEN 'ordered'
           ELSE 'served'
       END
FROM chosen_items c
JOIN menu_items mi ON mi.name = c.item_name
ON CONFLICT (order_id, item_id) DO NOTHING;
COMMIT;

-- Проверка объёма, месяцев, статусов и пограничных случаев.
SELECT 'dining_tables' AS entity, COUNT(*) AS rows_count FROM dining_tables
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'menu_items', COUNT(*) FROM menu_items
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;

SELECT status, COUNT(*) AS order_count FROM orders GROUP BY status ORDER BY status;
SELECT DATE_TRUNC('month', created_at)::date AS month, COUNT(*) AS order_count
FROM orders GROUP BY 1 ORDER BY 1;
SELECT COUNT(*) AS zero_price_rows FROM order_items WHERE price_at_time = 0;
SELECT COUNT(*) AS null_closed_at_rows FROM orders WHERE closed_at IS NULL;

-- =============================================================
-- ЧАСТЬ 1.2. INSERT / UPDATE / МАССОВЫЙ UPDATE / DELETE / ROLLBACK
-- =============================================================
BEGIN;
-- 1) Новая сущность (столик 99) и связанные с ней заказ и позиции.
INSERT INTO dining_tables (table_number, capacity, status)
VALUES (99, 4, 'occupied')
ON CONFLICT (table_number) DO NOTHING;

WITH new_order AS (
    INSERT INTO orders (table_id, employee_id, status, created_at)
    SELECT dt.table_id, e.employee_id, 'open', TIMESTAMP '2026-05-15 18:00:00'
    FROM dining_tables dt
    JOIN employees e ON e.phone = '+79995556677'
    WHERE dt.table_number = 99
      AND NOT EXISTS (
          SELECT 1 FROM orders o
          WHERE o.table_id = dt.table_id
            AND o.employee_id = e.employee_id
            AND o.created_at = TIMESTAMP '2026-05-15 18:00:00'
      )
    RETURNING order_id
)
INSERT INTO order_items (order_id, item_id, quantity, price_at_time, item_status)
SELECT no.order_id, mi.item_id, v.qty, mi.price, 'ordered'
FROM new_order no
CROSS JOIN (VALUES ('Брускетта', 2), ('Лимонад', 2)) AS v(item_name, qty)
JOIN menu_items mi ON mi.name = v.item_name;

-- 2) Изменение состояния существующего заказа: открытый -> оплаченный.
-- Позиции сначала переводим в served, а заказ затем закрываем.
UPDATE order_items oi
SET item_status = 'served'
FROM orders o
JOIN dining_tables dt ON dt.table_id = o.table_id
WHERE oi.order_id = o.order_id
  AND dt.table_number = 99
  AND o.created_at = TIMESTAMP '2026-05-15 18:00:00';

UPDATE orders o
SET status = 'paid', closed_at = o.created_at + INTERVAL '75 minutes'
FROM dining_tables dt
WHERE dt.table_id = o.table_id
  AND dt.table_number = 99
  AND o.created_at = TIMESTAMP '2026-05-15 18:00:00'
  AND o.status = 'open';

-- 3) Массовый UPDATE: повышение текущих цен напитков дешевле 300 на 10%.
-- Зафиксированная цена в order_items.price_at_time не изменяется.
UPDATE menu_items
SET price = ROUND(price * 1.10, 2)
WHERE category = 'beverage' AND price < 300 AND is_available = TRUE;

-- 4) DELETE для позиции без связанных заказов (ограничение RESTRICT не нарушено).
INSERT INTO menu_items (name, category, price)
VALUES ('Временная позиция для удаления', 'dessert', 100.00)
ON CONFLICT (name) DO NOTHING;

DELETE FROM menu_items mi
WHERE mi.name = 'Временная позиция для удаления'
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.item_id = mi.item_id);
COMMIT;

-- 5) Демонстрация ROLLBACK: изменение НЕ должно сохраниться.
BEGIN;
UPDATE dining_tables SET capacity = 10 WHERE table_number = 99;
SELECT table_number, capacity AS capacity_inside_transaction
FROM dining_tables WHERE table_number = 99;
ROLLBACK;
SELECT table_number, capacity AS capacity_after_rollback
FROM dining_tables WHERE table_number = 99;

-- =============================================================
-- ЧАСТЬ 2.1. ТРИ МНОГОТАБЛИЧНЫХ ЗАПРОСА (JOIN, >=3 ТАБЛИЦ)
-- =============================================================
-- 2.1.1. Подробный состав заказов: столик, официант, позиция, сумма.
SELECT o.order_id, o.created_at, o.status AS order_status,
       dt.table_number, e.full_name AS waiter, mi.name AS dish,
       oi.quantity, oi.price_at_time, oi.item_status,
       (oi.quantity * oi.price_at_time) AS line_amount
FROM orders o
JOIN dining_tables dt ON dt.table_id = o.table_id
JOIN employees e ON e.employee_id = o.employee_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN menu_items mi ON mi.item_id = oi.item_id
ORDER BY o.created_at, o.order_id, mi.name;

-- 2.1.2. Столики, для которых ни разу не было заказов.
-- LEFT JOIN к orders и order_items сохраняет столики без связанных данных.
SELECT dt.table_id, dt.table_number, dt.capacity, dt.status,
       COUNT(DISTINCT o.order_id) AS order_count,
       COUNT(oi.item_id) AS ordered_lines
FROM dining_tables dt
LEFT JOIN orders o ON o.table_id = dt.table_id
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY dt.table_id, dt.table_number, dt.capacity, dt.status
HAVING COUNT(DISTINCT o.order_id) = 0
ORDER BY dt.table_number;

-- 2.1.3. Открытые заказы за столиками >=4 мест,
-- в которых официант обслуживает хотя бы одно горячее блюдо в приготовлении.
SELECT o.order_id, dt.table_number, dt.capacity,
       e.full_name AS waiter, COUNT(*) FILTER (
           WHERE mi.category = 'main' AND oi.item_status = 'cooking'
       ) AS cooking_mains
FROM orders o
JOIN dining_tables dt ON dt.table_id = o.table_id
JOIN employees e ON e.employee_id = o.employee_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN menu_items mi ON mi.item_id = oi.item_id
WHERE o.status = 'open' AND dt.capacity >= 4 AND e.role = 'waiter'
GROUP BY o.order_id, dt.table_number, dt.capacity, e.full_name
HAVING COUNT(*) FILTER (
    WHERE mi.category = 'main' AND oi.item_status = 'cooking'
) >= 1
ORDER BY cooking_mains DESC, o.order_id;

-- =============================================================
-- ЧАСТЬ 2.2. ТРИ АНАЛИТИЧЕСКИХ ЗАПРОСА (GROUP BY)
-- =============================================================
-- 2.2.1. Нагрузка на каждого сотрудника (в том числе не обслуживавших заказы).
SELECT e.employee_id, e.full_name, e.role,
       COUNT(DISTINCT o.order_id) AS all_orders,
       COUNT(DISTINCT o.order_id) FILTER (WHERE o.status = 'paid') AS paid_orders,
       COUNT(DISTINCT o.order_id) FILTER (WHERE o.status = 'cancelled') AS cancelled_orders,
       COALESCE(SUM(oi.quantity * oi.price_at_time)
                FILTER (WHERE o.status = 'paid' AND oi.item_status <> 'cancelled'), 0) AS paid_revenue
FROM employees e
LEFT JOIN orders o ON o.employee_id = e.employee_id
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY e.employee_id, e.full_name, e.role
ORDER BY paid_revenue DESC, e.employee_id;

-- 2.2.2. Категории блюд с суммарными продажами >= 5 порций
-- по оплаченным заказам; HAVING фильтрует уже сгруппированные строки.
SELECT mi.category,
       COUNT(DISTINCT mi.item_id) AS dishes_in_category,
       SUM(oi.quantity) AS portions_sold,
       SUM(oi.quantity * oi.price_at_time) AS revenue,
       ROUND(AVG(oi.price_at_time), 2) AS avg_unit_price_at_order,
       MIN(oi.price_at_time) AS min_unit_price_at_order,
       MAX(oi.price_at_time) AS max_unit_price_at_order
FROM menu_items mi
JOIN order_items oi ON oi.item_id = mi.item_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.status = 'paid' AND oi.item_status <> 'cancelled'
GROUP BY mi.category
HAVING SUM(oi.quantity) >= 5
ORDER BY revenue DESC;

-- 2.2.3. Сравнение месяцев: выручка, количество заказов, средний чек.
-- Сначала вычисляется сумма каждого заказа, чтобы не завышать COUNT.
WITH order_totals AS (
    SELECT o.order_id, o.created_at, o.status,
           COALESCE(SUM(CASE WHEN oi.item_status <> 'cancelled'
                             THEN oi.quantity * oi.price_at_time ELSE 0 END), 0) AS total
    FROM orders o
    LEFT JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.created_at, o.status
)
SELECT DATE_TRUNC('month', created_at)::date AS month,
       COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE status = 'paid') AS paid_orders,
       COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_orders,
       COALESCE(SUM(total) FILTER (WHERE status = 'paid'), 0) AS revenue,
       COALESCE(ROUND(AVG(total) FILTER (WHERE status = 'paid'), 2), 0) AS average_paid_check
FROM order_totals
GROUP BY DATE_TRUNC('month', created_at)::date
ORDER BY month;

-- =============================================================
-- ЧАСТЬ 3. ЧЕТЫРЕ ЗАПРОСА С ПОДЗАПРОСАМИ
-- =============================================================
-- 3.1. Блюда дороже среднего блюда своей категории.
SELECT mi.item_id, mi.name, mi.category, mi.price,
       (SELECT ROUND(AVG(m2.price), 2)
        FROM menu_items m2 WHERE m2.category = mi.category) AS category_avg_price
FROM menu_items mi
WHERE mi.price > (
    SELECT AVG(m2.price) FROM menu_items m2 WHERE m2.category = mi.category
)
ORDER BY mi.category, mi.price DESC;

-- 3.2. EXISTS: блюда, которые хотя бы раз покупали в количестве >=2
-- в одном оплаченном заказе.
SELECT mi.item_id, mi.name, mi.category
FROM menu_items mi
WHERE EXISTS (
    SELECT 1 FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE oi.item_id = mi.item_id
      AND oi.quantity >= 2
      AND oi.item_status <> 'cancelled'
      AND o.status = 'paid'
)
ORDER BY mi.category, mi.name;

-- 3.3. NOT EXISTS: блюда, по которым никогда не было оплаченной продажи.
-- Они могут вообще не заказываться или присутствовать лишь в открытых/отменённых заказах.
SELECT mi.item_id, mi.name, mi.category, mi.is_available
FROM menu_items mi
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE oi.item_id = mi.item_id
      AND o.status = 'paid'
      AND oi.item_status <> 'cancelled'
)
ORDER BY mi.category, mi.name;

-- 3.4. Коррелированный подзапрос: оплаченные заказы,
-- чек которых выше среднего чека оплаченных заказов ТОГО ЖЕ столика.
SELECT o.order_id, dt.table_number, o.created_at,
       (SELECT COALESCE(SUM(oi.quantity * oi.price_at_time), 0)
        FROM order_items oi
        WHERE oi.order_id = o.order_id AND oi.item_status <> 'cancelled') AS order_amount,
       (SELECT ROUND(AVG(t.order_amount), 2)
        FROM (
            SELECT o2.order_id, SUM(oi2.quantity * oi2.price_at_time) AS order_amount
            FROM orders o2
            JOIN order_items oi2 ON oi2.order_id = o2.order_id
            WHERE o2.table_id = o.table_id
              AND o2.status = 'paid'
              AND oi2.item_status <> 'cancelled'
            GROUP BY o2.order_id
        ) t) AS avg_amount_for_table
FROM orders o
JOIN dining_tables dt ON dt.table_id = o.table_id
WHERE o.status = 'paid'
  AND (SELECT COALESCE(SUM(oi.quantity * oi.price_at_time), 0)
       FROM order_items oi
       WHERE oi.order_id = o.order_id AND oi.item_status <> 'cancelled')
      > (SELECT AVG(t.order_amount)
         FROM (
            SELECT o2.order_id, SUM(oi2.quantity * oi2.price_at_time) AS order_amount
            FROM orders o2
            JOIN order_items oi2 ON oi2.order_id = o2.order_id
            WHERE o2.table_id = o.table_id
              AND o2.status = 'paid'
              AND oi2.item_status <> 'cancelled'
            GROUP BY o2.order_id
         ) t)
ORDER BY dt.table_number, order_amount DESC;

-- =============================================================
-- ЧАСТЬ 4. КОМПЛЕКСНЫЙ АНАЛИТИЧЕСКИЙ ОТЧЁТ С CTE
-- Вопрос: какова результативность каждого официанта по месяцам?
-- Исходные данные: orders + order_items + employees.
-- Промежуточные показатели: чек по каждому заказу (order_amounts).
-- Агрегация: показатели официантов в разрезе месяцев (waiter_monthly).
-- Итог: выручка, средний чек, отмены, доля в выручке месяца, рейтинг.
-- =============================================================
WITH order_amounts AS (
    SELECT o.order_id, o.employee_id, o.created_at, o.status, o.table_id,
           COALESCE(SUM(CASE WHEN oi.item_status <> 'cancelled'
                             THEN oi.quantity * oi.price_at_time ELSE 0 END), 0) AS order_amount
    FROM orders o
    LEFT JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.employee_id, o.created_at, o.status, o.table_id
),
waiter_monthly AS (
    SELECT DATE_TRUNC('month', oa.created_at)::date AS month,
           e.employee_id, e.full_name,
           COUNT(*) AS all_orders,
           COUNT(*) FILTER (WHERE oa.status = 'paid') AS paid_orders,
           COUNT(*) FILTER (WHERE oa.status = 'cancelled') AS cancelled_orders,
           COUNT(DISTINCT oa.table_id) AS tables_served,
           COALESCE(SUM(oa.order_amount) FILTER (WHERE oa.status = 'paid'), 0) AS revenue,
           COALESCE(ROUND(AVG(oa.order_amount) FILTER (WHERE oa.status = 'paid'), 2), 0) AS avg_paid_check
    FROM order_amounts oa
    JOIN employees e ON e.employee_id = oa.employee_id
    WHERE e.role = 'waiter'
    GROUP BY DATE_TRUNC('month', oa.created_at)::date, e.employee_id, e.full_name
),
month_totals AS (
    SELECT month, SUM(revenue) AS total_month_revenue
    FROM waiter_monthly
    GROUP BY month
)
SELECT w.month, w.full_name AS waiter,
       w.all_orders, w.paid_orders, w.cancelled_orders, w.tables_served,
       w.revenue, w.avg_paid_check,
       ROUND(100.0 * w.revenue / NULLIF(mt.total_month_revenue, 0), 2) AS revenue_share_percent,
       DENSE_RANK() OVER (PARTITION BY w.month ORDER BY w.revenue DESC) AS revenue_rank_in_month
FROM waiter_monthly w
JOIN month_totals mt ON mt.month = w.month
ORDER BY w.month, revenue_rank_in_month, w.full_name;

-- Итоговые проверки сохранения ограничений и контроль объёма.
SELECT
    (SELECT COUNT(*) FROM dining_tables) AS tables_count,
    (SELECT COUNT(*) FROM employees) AS employees_count,
    (SELECT COUNT(*) FROM menu_items) AS menu_count,
    (SELECT COUNT(*) FROM orders) AS orders_count,
    (SELECT COUNT(*) FROM order_items) AS order_items_count,
    (SELECT COUNT(*) FROM dining_tables) +
    (SELECT COUNT(*) FROM employees) +
    (SELECT COUNT(*) FROM menu_items) +
    (SELECT COUNT(*) FROM orders) +
    (SELECT COUNT(*) FROM order_items) AS total_rows;
