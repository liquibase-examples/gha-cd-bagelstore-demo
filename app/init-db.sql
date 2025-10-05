-- Bagel Store Database Schema and Seed Data

-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create inventory table
CREATE TABLE IF NOT EXISTS inventory (
    product_id INTEGER PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- Insert sample bagel products
INSERT INTO products (name, description, price) VALUES
('Plain Bagel', 'Classic New York style plain bagel, perfect for any topping', 2.50),
('Everything Bagel', 'Loaded with sesame seeds, poppy seeds, garlic, and onion', 3.00),
('Blueberry Bagel', 'Sweet and fruity with real blueberries baked in', 3.25),
('Cinnamon Raisin Bagel', 'Sweet cinnamon swirl with plump raisins throughout', 3.25),
('Asiago Cheese Bagel', 'Topped with savory Asiago cheese for a rich flavor', 3.50);

-- Insert initial inventory (50 of each bagel type)
INSERT INTO inventory (product_id, quantity, last_updated)
SELECT id, 50, CURRENT_TIMESTAMP
FROM products;

-- Create indexes for better performance
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(order_date);
