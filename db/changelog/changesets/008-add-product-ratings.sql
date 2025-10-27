--liquibase formatted sql
--changeset demo:008-add-product-ratings

-- Add rating column to products table
ALTER TABLE products
ADD COLUMN rating INTEGER NOT NULL DEFAULT 4
CHECK (rating >= 1 AND rating <= 5);

-- Seed ratings for existing products
UPDATE products SET rating = 4 WHERE name = 'Plain Bagel';
UPDATE products SET rating = 5 WHERE name = 'Everything Bagel';
UPDATE products SET rating = 4 WHERE name = 'Blueberry Bagel';
UPDATE products SET rating = 5 WHERE name = 'Cinnamon Raisin Bagel';
UPDATE products SET rating = 4 WHERE name = 'Asiago Cheese Bagel';

--rollback ALTER TABLE products DROP COLUMN rating;
