-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

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
  company_type USER-DEFINED CHECK (company_type::text = ANY (ARRAY['Standard'::character varying::text, 'Others'::character varying::text])),
  selling_price numeric CHECK (selling_price > 0::numeric),
  CONSTRAINT products_pkey PRIMARY KEY (id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username character varying NOT NULL UNIQUE,
  full_name character varying NOT NULL,
  role character varying NOT NULL DEFAULT 'biller'::character varying CHECK (role::text = ANY (ARRAY['admin'::character varying, 'biller'::character varying]::text[])),
  status character varying NOT NULL DEFAULT 'active'::character varying CHECK (status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  email character varying NOT NULL,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
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