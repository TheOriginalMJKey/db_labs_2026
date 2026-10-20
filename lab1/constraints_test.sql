-- check constraint "dining_tables_capacity_check"
INSERT INTO dining_tables (table_number, capacity) VALUES (5, 0);

--  unique constraint "dining_tables_table_number_key"
INSERT INTO dining_tables (table_number, capacity) VALUES (1, 4);

-- check constraint "menu_items_price_check"
INSERT INTO menu_items (name, category, price) VALUES ('Бесплатный хлеб', 'starter', -10.00);

--  check constraint "chk_order_dates"
INSERT INTO orders (table_id, employee_id, created_at, closed_at) 
VALUES (1, 1, '2026-10-01 12:00:00', '2026-10-01 10:00:00');

--  foreign key constraint "orders_employee_id_fkey"
INSERT INTO orders (table_id, employee_id) VALUES (1, 99);