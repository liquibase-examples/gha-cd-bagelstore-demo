--liquibase formatted sql
--changeset demo:005-create-indexes

-- Create indexes for better query performance
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(order_date);

--rollback DROP INDEX IF EXISTS idx_order_items_order_id;
--rollback DROP INDEX IF EXISTS idx_order_items_product_id;
--rollback DROP INDEX IF EXISTS idx_orders_status;
--rollback DROP INDEX IF EXISTS idx_orders_date;
