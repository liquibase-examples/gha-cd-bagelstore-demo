--liquibase formatted sql
--changeset demo:003-create-orders-table

-- Create orders table for customer orders
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
);

--rollback DROP TABLE orders;
