-- Create a database trigger to automatically update stock when bill is completed
-- This approach is more reliable than client-side stock updates

-- Step 1: Create a function to process stock updates
CREATE OR REPLACE FUNCTION process_bill_stock_updates()
RETURNS TRIGGER AS $$
DECLARE
    movement_record RECORD;
    product_record RECORD;
    new_stock_quantity INTEGER;
BEGIN
    -- Only process when payment_method is updated (bill completion)
    IF OLD.payment_method IS DISTINCT FROM NEW.payment_method THEN
        
        RAISE NOTICE 'Processing stock updates for completed bill: %', NEW.id;
        
        -- Get all stock movements for this bill
        FOR movement_record IN 
            SELECT product_id, quantity, movement_type, notes
            FROM stock_movements 
            WHERE reference_type = 'bill' 
            AND reference_id = NEW.id::text
            AND movement_type = 'out'
        LOOP
            -- Get current product stock
            SELECT stock_quantity, name INTO product_record
            FROM products 
            WHERE id = movement_record.product_id;
            
            IF NOT FOUND THEN
                RAISE WARNING 'Product not found: %', movement_record.product_id;
                CONTINUE;
            END IF;
            
            -- Check if sufficient stock available
            IF product_record.stock_quantity < movement_record.quantity THEN
                RAISE WARNING 'Insufficient stock for %: required %, available %', 
                    product_record.name, movement_record.quantity, product_record.stock_quantity;
                CONTINUE;
            END IF;
            
            -- Calculate new stock quantity
            new_stock_quantity := product_record.stock_quantity - movement_record.quantity;
            
            -- Update product stock
            UPDATE products 
            SET 
                stock_quantity = new_stock_quantity,
                updated_at = NOW()
            WHERE id = movement_record.product_id;
            
            RAISE NOTICE 'Stock updated for %: % -> %', 
                product_record.name, product_record.stock_quantity, new_stock_quantity;
            
        END LOOP;
        
        RAISE NOTICE 'Stock updates completed for bill: %', NEW.id;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Create the trigger
DROP TRIGGER IF EXISTS bill_completion_stock_update ON bills;

CREATE TRIGGER bill_completion_stock_update
    AFTER UPDATE ON bills
    FOR EACH ROW
    EXECUTE FUNCTION process_bill_stock_updates();

-- Step 3: Grant necessary permissions
-- The function runs with SECURITY DEFINER, so it has elevated privileges

-- Step 4: Test the trigger (optional)
-- You can test this by updating a bill's payment method:
-- UPDATE bills SET payment_method = 'online' WHERE id = 'your-bill-id';

RAISE NOTICE 'Stock update trigger created successfully!';
RAISE NOTICE 'Stock will now be automatically updated when bill payment_method is changed.';
