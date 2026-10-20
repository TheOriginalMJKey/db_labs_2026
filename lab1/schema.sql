DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS menu_items CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS dining_tables CASCADE;

CREATE TABLE dining_tables (
    table_id SERIAL PRIMARY KEY,
    table_number INT NOT NULL UNIQUE, 
    capacity INT NOT NULL CHECK (capacity > 0 AND capacity <= 20), 
    status VARCHAR(20) NOT NULL DEFAULT 'free' CHECK (status IN ('free', 'occupied', 'reserved')) 
);

CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('waiter', 'chef', 'manager')),
    phone VARCHAR(20) NOT NULL UNIQUE, 
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE menu_items (
    item_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL CHECK (category IN ('starter', 'main', 'dessert', 'beverage')),
    price NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    table_id INT NOT NULL REFERENCES dining_tables(table_id) ON DELETE RESTRICT,
    employee_id INT NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'paid', 'cancelled')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP,
    CONSTRAINT chk_order_dates CHECK (closed_at IS NULL OR closed_at >= created_at)
);

CREATE TABLE order_items (
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    item_id INT NOT NULL REFERENCES menu_items(item_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_time NUMERIC(10, 2) NOT NULL CHECK (price_at_time >= 0),
    item_status VARCHAR(20) NOT NULL DEFAULT 'ordered' CHECK (item_status IN ('ordered', 'cooking', 'served', 'cancelled')),
    PRIMARY KEY (order_id, item_id)
);