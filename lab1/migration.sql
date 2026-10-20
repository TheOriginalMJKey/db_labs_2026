CREATE TABLE restaurant_building (
    restaurant_id SERIAL PRIMARY KEY,
    adress VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL UNIQUE,
    opening_time TIMESTAMP NOT NULL,
    closing_time TIMESTAMP NOT NULL   
)
CREATE TABLE building_employees_orders(
    restaurant_id INT NOT NULL REFERENCES restaurant_building(restaurant_id) ON DELETE RESTRICT,
    employee_id INT NOT NULL REFERENCES restaurant_building(restaurant_id) ON DELETE CASCADE,
    PRIMARY KEY (restaurant_id, employee_id),
    order_id INT NOT NULL REFERENCES order(order_id) ON DELETE RESTRICT
)
ALTER TABLE employees (
    ADD COLUMN restaurant_id INT NOT NULL REFERENCES restaurant_building(restaurant_id) ON DELETE RESTRICT
)
ALTER TABLE dining_tables (
    ADD COLUMN restaurant_id INT NOT NULL REFERENCES restaurant_building(restaurant_id) ON DELETE RESTRICT
)
ALTER TABLE menu_items (
    ADD COLUMN restaurant_id INT NOT NULL REFERENCES restaurant_building(restaurant_id) ON DELETE RESTRICT
)
ALTER TABLE orders (
    ADD COLUMN restaurant_id INT NOT NULL REFERENCES restaurant_building(restaurant_id) ON DELETE RESTRICT
)