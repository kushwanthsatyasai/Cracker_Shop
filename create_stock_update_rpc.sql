-- Create RPC function to update stock quantities after bill completion
-- This function should be run in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION update_stock_after_bill_completion(
  p_bill_id UUID,
  p_updated_by UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with elevated privileges
AS $$
DECLARE
  bill_record RECORD;
  item_record RECORD;
  stock_update_count INTEGER := 0;
  error_products TEXT[] := ARRAY[]::TEXT[];
  result JSON;
BEGIN
  -- Check if bill exists and is completed
  SELECT * INTO bill_record 
  FROM bills 
  WHERE id = p_bill_id AND status = 'completed';
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Bill not found or not completed',
      'bill_id', p_bill_id
    );
  END IF;
  
  -- Process each bill item
  FOR item_record IN 
    SELECT bi.product_id, bi.quantity, bi.product_name, p.stock_quantity
    FROM bill_items bi
    JOIN products p ON p.id = bi.product_id
    WHERE bi.bill_id = p_bill_id
  LOOP
    -- Check if sufficient stock is available
    IF item_record.stock_quantity < item_record.quantity THEN
      error_products := array_append(error_products, 
        item_record.product_name || ' (available: ' || item_record.stock_quantity || ', needed: ' || item_record.quantity || ')'
      );
      CONTINUE;
    END IF;
    
    -- Update product stock
    UPDATE products 
    SET 
      stock_quantity = stock_quantity - item_record.quantity,
      updated_at = NOW()
    WHERE id = item_record.product_id;
    
    -- Create stock movement record
    INSERT INTO stock_movements (
      product_id,
      movement_type,
      quantity,
      reference_type,
      reference_id,
      notes,
      created_by,
      created_at
    ) VALUES (
      item_record.product_id,
      'out',
      item_record.quantity,
      'bill',
      p_bill_id,
      'Stock deducted for bill: ' || bill_record.bill_number,
      COALESCE(p_updated_by, bill_record.biller_id),
      NOW()
    );
    
    stock_update_count := stock_update_count + 1;
  END LOOP;
  
  -- Return result
  IF array_length(error_products, 1) > 0 THEN
    result := json_build_object(
      'success', false,
      'error', 'Insufficient stock for some products',
      'error_products', array_to_json(error_products),
      'updated_count', stock_update_count,
      'bill_id', p_bill_id
    );
  ELSE
    result := json_build_object(
      'success', true,
      'message', 'Stock updated successfully',
      'updated_count', stock_update_count,
      'bill_id', p_bill_id
    );
  END IF;
  
  RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_stock_after_bill_completion(UUID, UUID) TO authenticated;

-- Example usage:
-- SELECT update_stock_after_bill_completion('your-bill-uuid-here');
-- SELECT update_stock_after_bill_completion('your-bill-uuid-here', 'user-uuid-here');
