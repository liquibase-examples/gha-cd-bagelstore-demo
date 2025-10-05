--liquibase formatted sql
--changeset demo:004-create-order-items-table

-- Create order_items table for line items in orders
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

--rollback DROP TABLE order_items;
