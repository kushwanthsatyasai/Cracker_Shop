-- Sample data for Cracker Shop App
-- Run this after setting up the database schema

-- Insert sample products
INSERT INTO public.products (name, category, price, stock_quantity, discount_limit, company_type, selling_price) VALUES
('Sparklers (10 pack)', 'Sparklers', 25.00, 100, 5.00, 'Standard', 25.00),
('Rocket Crackers', 'Rockets', 150.00, 50, 10.00, 'Standard', 150.00),
('Flower Pots', 'Ground', 35.00, 75, 5.00, 'Standard', 35.00),
('Chakri (Wheel)', 'Ground', 20.00, 120, 3.00, 'Standard', 20.00),
('Bomb Crackers', 'Sound', 200.00, 30, 15.00, 'Others', 180.00),
('Color Smoke', 'Fancy', 45.00, 80, 5.00, 'Standard', 45.00),
('Anaar (Pomegranate)', 'Fancy', 60.00, 40, 8.00, 'Standard', 60.00),
('Snake Tablets', 'Ground', 15.00, 200, 2.00, 'Standard', 15.00),
('Sky Shot', 'Rockets', 180.00, 25, 12.00, 'Standard', 180.00),
('Ground Spinner', 'Ground', 30.00, 90, 4.00, 'Standard', 30.00),
('Premium Rockets', 'Rockets', 250.00, 20, 20.00, 'Others', 220.00),
('Deluxe Sparklers', 'Sparklers', 40.00, 60, 6.00, 'Others', 35.00);

-- Note: You'll need to create users first through the Supabase Auth dashboard
-- Then manually insert their profiles using the user IDs from auth.users

-- Example of how to insert a profile (replace with actual user ID):
-- INSERT INTO public.profiles (id, username, full_name, role, status) VALUES
-- ('actual-user-uuid-here', 'admin', 'Admin User', 'admin', 'active');
