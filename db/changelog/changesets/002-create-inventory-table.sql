--liquibase formatted sql
--changeset demo:002-create-inventory-table

-- Create inventory table to track stock levels
CREATE TABLE inventory (
    product_id INTEGER PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--rollback DROP TABLE inventory;
