-- Verification script to check if stock updates are working

-- Step 1: Check current stock levels for products that were in the recent bill
SELECT 
    id,
    name,
    stock_quantity,
    company_type,
    updated_at
FROM products 
WHERE id IN (
    'd977e644-b29a-4bf7-a9bc-686b618a4196',  -- Snake Tablets
    'dd2f4154-65d4-490a-920c-79b4ddae16dd',  -- Sparklers (10 pack)
    'b6f478bd-cbc8-4bbe-a0ce-c2ebe7a4565b',  -- Premium Rockets
    'f670d4be-85c8-45b7-a02f-0ea26a6cec93'   -- Ground Spinner
)
ORDER BY name;

-- Step 2: Check recent stock movements
SELECT 
    sm.id,
    sm.product_id,
    p.name as product_name,
    sm.movement_type,
    sm.quantity,
    sm.reference_type,
    sm.reference_id,
    sm.notes,
    sm.created_at
FROM stock_movements sm
JOIN products p ON sm.product_id = p.id
WHERE sm.reference_type = 'bill'
ORDER BY sm.created_at DESC
LIMIT 10;

-- Step 3: Check recent bills and their items
SELECT 
    b.id as bill_id,
    b.bill_number,
    b.customer_name,
    b.created_at,
    bi.product_name,
    bi.quantity,
    bi.price
FROM bills b
JOIN bill_items bi ON b.id = bi.bill_id
WHERE b.id = '50545591-4c84-4802-a187-506f158b82a3'  -- Latest bill ID from logs
ORDER BY b.created_at DESC;

-- Step 4: Expected vs Actual stock levels
-- Snake Tablets: Expected 199 (was 200, sold 1)
-- Sparklers: Expected 99 (was 100, sold 1) 
-- Premium Rockets: Expected 19 (was 20, sold 1)
-- Ground Spinner: Expected 89 (was 90, sold 1)

-- Step 5: Check if RLS policies are blocking updates
-- Run this as admin to see if there are any RLS policy issues
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'products';
