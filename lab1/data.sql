INSERT INTO dining_tables (table_number, capacity, status) VALUES
(1, 2, 'occupied'),
(2, 4, 'free'),
(3, 6, 'reserved'),
(4, 2, 'free');

INSERT INTO employees (full_name, role, phone) VALUES
('Иванов Алексей Сергеевич', 'waiter', '+79991112233'),
('Петрова Ольга Игоревна', 'waiter', '+79992223344'),
('Сидоров Дмитрий Владимирович', 'chef', '+79993334455'),
('Смирнова Анна Олеговна', 'manager', '+79994445566');

INSERT INTO menu_items (name, category, price) VALUES
('Салат Цезарь', 'starter', 450.00),
('Стейк Рибай', 'main', 1800.00),
('Паста Карбонара', 'main', 550.00),
('Тирамису', 'dessert', 350.00),
('Капучино', 'beverage', 200.00);

INSERT INTO orders (table_id, employee_id, status, created_at) VALUES
(1, 1, 'open', CURRENT_TIMESTAMP - INTERVAL '30 minutes'),
(2, 2, 'paid', CURRENT_TIMESTAMP - INTERVAL '2 hours');

UPDATE orders SET closed_at = CURRENT_TIMESTAMP - INTERVAL '1 hour' WHERE order_id = 2;

INSERT INTO order_items (order_id, item_id, quantity, price_at_time, item_status) VALUES
(1, 1, 2, 450.00, 'served'),
(1, 5, 2, 200.00, 'served'),
(2, 2, 1, 1800.00, 'served'),
(2, 4, 1, 350.00, 'served');