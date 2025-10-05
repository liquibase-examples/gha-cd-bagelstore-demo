--liquibase formatted sql
--changeset demo:007-seed-inventory

-- Insert initial inventory (50 of each bagel type)
INSERT INTO inventory (product_id, quantity, last_updated)
SELECT id, 50, CURRENT_TIMESTAMP
FROM products;

--rollback DELETE FROM inventory;
