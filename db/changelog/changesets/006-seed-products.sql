--liquibase formatted sql
--changeset demo:006-seed-products

-- Insert sample bagel products
INSERT INTO products (name, description, price) VALUES
('Plain Bagel', 'Classic New York style plain bagel, perfect for any topping', 2.50),
('Everything Bagel', 'Loaded with sesame seeds, poppy seeds, garlic, and onion', 3.00),
('Blueberry Bagel', 'Sweet and fruity with real blueberries baked in', 3.25),
('Cinnamon Raisin Bagel', 'Sweet cinnamon swirl with plump raisins throughout', 3.25),
('Asiago Cheese Bagel', 'Topped with savory Asiago cheese for a rich flavor', 3.50);

--rollback DELETE FROM products WHERE name IN ('Plain Bagel', 'Everything Bagel', 'Blueberry Bagel', 'Cinnamon Raisin Bagel', 'Asiago Cheese Bagel');
