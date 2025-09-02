# Supabase RPC Setup for Stock Updates

This guide explains how to set up the PostgreSQL RPC (Remote Procedure Call) function for handling stock updates after bill completion.

## Why Use RPC?

Using a PostgreSQL RPC function provides several benefits:
- **Atomicity**: All stock updates happen in a single database transaction
- **Consistency**: Prevents race conditions and ensures data integrity  
- **Performance**: Reduces network calls between Flutter and database
- **Security**: Runs with elevated privileges (SECURITY DEFINER)
- **Error Handling**: Comprehensive validation and error reporting

## Setup Instructions

### 1. Deploy the RPC Function

1. **Open Supabase Dashboard**
   - Go to your project: https://supabase.com/dashboard/project/ffnemdxaenxwlgbcppgg
   - Navigate to **SQL Editor**

2. **Run the RPC Creation Script**
   - Copy the contents of `create_stock_update_rpc.sql`
   - Paste into SQL Editor
   - Click **Run** to execute

3. **Verify Function Creation**
   ```sql
   -- Check if function exists
   SELECT routine_name, routine_type 
   FROM information_schema.routines 
   WHERE routine_name = 'update_stock_after_bill_completion';
   ```

### 2. Test the Function

```sql
-- Example: Test with a real bill ID from your database
SELECT update_stock_after_bill_completion('your-bill-uuid-here');

-- With specific user
SELECT update_stock_after_bill_completion('your-bill-uuid-here', 'user-uuid-here');
```

### 3. Expected Response Format

**Success Response:**
```json
{
  "success": true,
  "message": "Stock updated successfully",
  "updated_count": 3,
  "bill_id": "bill-uuid"
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Insufficient stock for some products",
  "error_products": [
    "Product A (available: 2, needed: 5)",
    "Product B (available: 0, needed: 1)"
  ],
  "updated_count": 1,
  "bill_id": "bill-uuid"
}
```

## How It Works

### 1. Validation
- Checks if bill exists and has 'completed' status
- Validates sufficient stock for each product

### 2. Stock Updates
- Deducts quantities from `products.stock_quantity`
- Updates `products.updated_at` timestamp
- Creates audit records in `stock_movements` table

### 3. Error Handling
- Returns detailed error information for insufficient stock
- Continues processing other products even if some fail
- Provides summary of successful and failed updates

## Flutter Integration

The RPC function is called from Flutter using:

```dart
final result = await ProductService.updateStockAfterBillCompletion(
  billId: 'bill-uuid',
  updatedBy: 'user-uuid', // optional
);

if (result['success'] == true) {
  // Handle success
  print('Updated ${result['updatedCount']} products');
} else {
  // Handle errors
  print('Error: ${result['error']}');
  final errorProducts = result['errorProducts'] as List?;
  // Show detailed error info to user
}
```

## Security Notes

- Function uses `SECURITY DEFINER` to run with elevated privileges
- Only authenticated users can execute the function
- All operations are wrapped in a transaction for atomicity
- Input validation prevents SQL injection

## Troubleshooting

### Function Not Found
- Verify the function was created successfully
- Check function permissions for authenticated role

### Permission Denied
- Ensure `GRANT EXECUTE ON FUNCTION` was run
- Verify user is authenticated when calling

### Timeout Issues
- Function includes 30-second timeout in Flutter
- For large bills, consider batch processing

## Migration from Trigger Approach

If you previously used the database trigger approach:
1. The RPC method is now the primary stock update mechanism
2. You can remove the old trigger if desired
3. RPC provides better error handling and user feedback
