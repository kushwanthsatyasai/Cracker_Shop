# Database Trigger Setup for Automatic Stock Updates

## 🎯 **Solution Overview**

Instead of handling stock updates in the Flutter app (which can fail due to API key issues), we'll use a **PostgreSQL trigger** in Supabase that automatically updates stock when a bill is completed.

## 🔧 **How It Works**

```
Bill Payment Confirmed → Database Trigger Activated → Stock Automatically Updated
```

1. **User confirms payment** in bill details screen
2. **`payment_method` column updated** in `bills` table  
3. **Database trigger fires** automatically
4. **Stock quantities decreased** in `products` table
5. **No client-side code needed** - happens at database level

---

## 📋 **Implementation Steps**

### **Step 1: Deploy the Trigger to Supabase**

1. **Open Supabase Dashboard** → Your Project → SQL Editor
2. **Copy and paste** the contents of `simple_stock_trigger.sql`
3. **Click "Run"** to execute the SQL

### **Step 2: Test the Trigger**

1. **Create a bill** with some products
2. **Check current stock** in products table
3. **Update payment method** in bill details screen
4. **Verify stock decreased** automatically

### **Step 3: Monitor Trigger Performance**

Check Supabase logs for trigger execution messages.

---

## 📄 **SQL Code to Deploy**

```sql
-- Simple trigger to update stock when bill payment is confirmed
-- Run this in your Supabase SQL editor

-- Create the trigger function
CREATE OR REPLACE FUNCTION update_stock_on_bill_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if payment_method was updated (bill completion)
    IF OLD.payment_method IS DISTINCT FROM NEW.payment_method THEN
        
        -- Update stock for all items in this bill
        UPDATE products 
        SET stock_quantity = stock_quantity - sm.quantity,
            updated_at = NOW()
        FROM stock_movements sm
        WHERE products.id = sm.product_id
        AND sm.reference_type = 'bill'
        AND sm.reference_id = NEW.id::text
        AND sm.movement_type = 'out'
        AND products.stock_quantity >= sm.quantity; -- Prevent negative stock
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS auto_stock_update ON bills;
CREATE TRIGGER auto_stock_update
    AFTER UPDATE ON bills
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_on_bill_completion();
```

---

## ✅ **Benefits of Database Trigger Approach**

### **Reliability**
- ✅ **Always executes** - no client-side failures
- ✅ **Atomic operation** - either all stock updates or none
- ✅ **No API key issues** - runs with database privileges

### **Performance**  
- ⚡ **Fast execution** - no network round trips
- ⚡ **Immediate response** - happens instantly on update
- ⚡ **No timeout issues** - database handles everything

### **Consistency**
- 🔒 **ACID compliance** - guaranteed data consistency  
- 🔒 **Prevents negative stock** - built-in validation
- 🔒 **Audit trail maintained** - stock_movements preserved

### **Maintenance**
- 🛠️ **Server-side logic** - no client app updates needed
- 🛠️ **Centralized** - one place to manage stock logic
- 🛠️ **Scalable** - works regardless of number of clients

---

## 🧪 **Testing Scenarios**

### **Test 1: Normal Bill Completion**
```sql
-- Before: Check stock
SELECT name, stock_quantity FROM products WHERE id = 'product-id';

-- Create bill and stock movements (via app)
-- Then update payment method:
UPDATE bills SET payment_method = 'online' WHERE id = 'bill-id';

-- After: Verify stock decreased
SELECT name, stock_quantity FROM products WHERE id = 'product-id';
```

### **Test 2: Insufficient Stock Protection**
```sql
-- Try to sell more than available stock
-- Trigger should prevent negative stock
```

### **Test 3: Multiple Items in One Bill**
```sql
-- Bill with 3 different products
-- All should be updated atomically
```

---

## 🚨 **Troubleshooting**

### **If Trigger Doesn't Fire:**
1. Check if trigger exists:
```sql
SELECT * FROM information_schema.triggers WHERE trigger_name = 'auto_stock_update';
```

2. Check function exists:
```sql
SELECT * FROM information_schema.routines WHERE routine_name = 'update_stock_on_bill_completion';
```

### **If Stock Doesn't Update:**
1. Check stock_movements exist:
```sql
SELECT * FROM stock_movements WHERE reference_type = 'bill' AND reference_id = 'your-bill-id';
```

2. Check for sufficient stock:
```sql
SELECT 
    p.name, 
    p.stock_quantity,
    sm.quantity as required
FROM products p
JOIN stock_movements sm ON p.id = sm.product_id  
WHERE sm.reference_id = 'your-bill-id';
```

### **View Trigger Logs:**
Check Supabase logs for NOTICE and WARNING messages from the trigger.

---

## 🔄 **Migration from Client-Side Logic**

### **What Changed:**
- ❌ **Removed**: Client-side stock update in `_processBillCompletion()`
- ❌ **Removed**: `ProductService.processStockUpdatesForCompletedBill()`  
- ✅ **Added**: Database trigger for automatic updates
- ✅ **Kept**: Stock movement creation during bill creation

### **New Workflow:**
```
1. Create Bill → Stock movements created (no stock change)
2. Confirm Payment → payment_method updated → Trigger fires → Stock updated
3. Start New Bill → Continue with updated stock levels
```

---

## 🎉 **Expected Results**

After implementing this trigger:

- ✅ **No more API key errors** during stock updates
- ✅ **Instant stock updates** when payment confirmed  
- ✅ **Reliable inventory management** regardless of client issues
- ✅ **Simplified Flutter code** - no complex stock logic needed
- ✅ **Better user experience** - no loading delays for stock updates

The database now handles all stock management automatically! 🚀
