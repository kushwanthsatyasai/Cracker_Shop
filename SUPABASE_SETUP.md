# Supabase Setup Guide for Cracker Shop App

This guide will help you set up Supabase and connect it with your Flutter app.

## 1. Supabase Project Setup

### Create a new Supabase project:
1. Go to [supabase.com](https://supabase.com)
2. Sign up or log in
3. Click "New Project"
4. Choose your organization
5. Enter project details:
   - Name: `cracker-shop`
   - Database Password: Choose a strong password
   - Region: Select closest to your users
6. Click "Create new project"

### Wait for the project to be created (usually takes 1-2 minutes)

## 2. Database Schema Setup

### Run the following SQL in your Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username character varying NOT NULL UNIQUE,
  email character varying NOT NULL,
  full_name character varying NOT NULL,
  role character varying NOT NULL DEFAULT 'biller'::character varying CHECK (role::text = ANY (ARRAY['admin'::character varying, 'biller'::character varying]::text[])),
  status character varying NOT NULL DEFAULT 'active'::character varying CHECK (status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

-- Create products table
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name character varying NOT NULL,
  category character varying NOT NULL,
  price numeric NOT NULL,
  stock_quantity integer NOT NULL DEFAULT 0,
  discount_limit numeric DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  company_type character varying CHECK (company_type::text = ANY (ARRAY['Standard'::character varying, 'Others'::character varying]::text[])),
  selling_price numeric CHECK (selling_price > 0::numeric),
  CONSTRAINT products_pkey PRIMARY KEY (id)
);

-- Create bills table
CREATE TABLE public.bills (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  bill_number character varying NOT NULL UNIQUE,
  customer_name character varying NOT NULL,
  customer_mobile character varying NOT NULL,
  biller_id uuid NOT NULL,
  subtotal numeric NOT NULL,
  tax_amount numeric NOT NULL,
  total_amount numeric NOT NULL,
  payment_method character varying DEFAULT 'cash'::character varying,
  status character varying DEFAULT 'completed'::character varying CHECK (status::text = ANY (ARRAY['completed'::character varying, 'cancelled'::character varying]::text[])),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT bills_pkey PRIMARY KEY (id),
  CONSTRAINT bills_biller_id_fkey FOREIGN KEY (biller_id) REFERENCES public.profiles(id)
);

-- Create bill_items table
CREATE TABLE public.bill_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  bill_id uuid,
  product_id uuid,
  product_name character varying NOT NULL,
  category character varying NOT NULL,
  quantity integer NOT NULL,
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT bill_items_pkey PRIMARY KEY (id),
  CONSTRAINT bill_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT bill_items_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bills(id)
);

-- Create stock_movements table
CREATE TABLE public.stock_movements (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  product_id uuid,
  movement_type character varying NOT NULL CHECK (movement_type::text = ANY (ARRAY['in'::character varying, 'out'::character varying, 'adjustment'::character varying]::text[])),
  quantity integer NOT NULL,
  reference_type character varying,
  reference_id uuid,
  notes text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT stock_movements_pkey PRIMARY KEY (id),
  CONSTRAINT stock_movements_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
  CONSTRAINT stock_movements_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);

-- Create indexes for better performance
CREATE INDEX idx_products_category ON public.products(category);
CREATE INDEX idx_products_is_active ON public.products(is_active);
CREATE INDEX idx_bills_biller_id ON public.bills(biller_id);
CREATE INDEX idx_bills_created_at ON public.bills(created_at);
CREATE INDEX idx_bill_items_bill_id ON public.bill_items(bill_id);
CREATE INDEX idx_stock_movements_product_id ON public.stock_movements(product_id);
```

## 3. Row Level Security (RLS) Setup

### Enable RLS and create policies:

```sql
-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Products policies (read-only for all authenticated users)
CREATE POLICY "Authenticated users can view products" ON public.products
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admin users can manage products" ON public.products
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Bills policies
CREATE POLICY "Users can view bills they created" ON public.bills
  FOR SELECT USING (biller_id = auth.uid());

CREATE POLICY "Users can create bills" ON public.bills
  FOR INSERT WITH CHECK (biller_id = auth.uid());

CREATE POLICY "Users can update bills they created" ON public.bills
  FOR UPDATE USING (biller_id = auth.uid());

-- Bill items policies
CREATE POLICY "Users can view bill items for their bills" ON public.bill_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE id = bill_id AND biller_id = auth.uid()
    )
  );

CREATE POLICY "Users can create bill items for their bills" ON public.bill_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE id = bill_id AND biller_id = auth.uid()
    )
  );

-- Stock movements policies
CREATE POLICY "Users can view stock movements" ON public.stock_movements
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admin users can manage stock movements" ON public.stock_movements
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

## 4. Get API Credentials

### From your Supabase project dashboard:
1. Go to Settings → API
2. Copy the following values:
   - Project URL
   - Anon (public) key
   - Service role key (keep this secret!)

### Update your `lib/config/supabase_config.dart`:
   ```dart
class SupabaseConfig {
  static const String url = 'YOUR_PROJECT_URL';
  static const String anonKey = 'YOUR_ANON_KEY';
  static const String serviceRoleKey = 'YOUR_SERVICE_ROLE_KEY';
  // ... rest of the config
}
```

## 5. Authentication Setup

### In Supabase Dashboard:
1. Go to Authentication → Settings
2. Configure email templates if needed
3. Set up any additional providers (Google, etc.) if required

### Create your first admin user:
1. Go to Authentication → Users
2. Click "Add user"
3. Enter email and password
4. Go to SQL Editor and run:
```sql
INSERT INTO public.profiles (id, username, full_name, role, status)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'admin@example.com'),
  'admin',
  'Admin User',
  'admin',
  'active'
);
```

## 6. Test the Connection

### Run your Flutter app:
1. Make sure you've run `flutter pub get`
2. Check that Supabase is initialized in `main.dart`
3. Try to sign in with the admin user you created

## 7. Troubleshooting

### Common issues:
1. **Connection failed**: Check your URL and API keys
2. **RLS errors**: Make sure policies are correctly set up
3. **Table not found**: Verify the SQL schema was executed
4. **Authentication errors**: Check user creation and profile setup

### Debug tips:
1. Check the Flutter console for error messages
2. Use Supabase Dashboard → Logs to see API requests
3. Test queries in the SQL Editor first
4. Verify RLS policies with the policy checker

## 8. Next Steps

After successful setup:
1. Add sample products to the database
2. Test billing functionality
3. Set up stock management
4. Configure additional features as needed

## Support

If you encounter issues:
1. Check the [Supabase documentation](https://supabase.com/docs)
2. Review the Flutter app logs
3. Verify database schema and policies
4. Test with simple queries first 