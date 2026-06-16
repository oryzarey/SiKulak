-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.todos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  is_complete boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT todos_pkey PRIMARY KEY (id)
);
CREATE TABLE public.categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  image_url text,
  price numeric DEFAULT 0,
  unit text,
  last_price numeric,
  CONSTRAINT products_pkey PRIMARY KEY (id)
);
CREATE TABLE public.suppliers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  CONSTRAINT suppliers_pkey PRIMARY KEY (id)
);
CREATE TABLE public.supplier_products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid,
  supplier_id uuid,
  price numeric NOT NULL,
  lead_time_days integer,
  last_updated timestamp with time zone DEFAULT now(),
  CONSTRAINT supplier_products_pkey PRIMARY KEY (id),
  CONSTRAINT supplier_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT supplier_products_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id)
);
CREATE TABLE public.inventories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  name text NOT NULL,
  qty_available integer DEFAULT 0,
  capital_price numeric NOT NULL,
  selling_price numeric NOT NULL,
  exp_date date,
  updated_at timestamp with time zone,
  image_url text,
  lead_time integer DEFAULT 3,
  safety_stock integer DEFAULT 0,
  reorder_point integer DEFAULT 0,
  abc_class text CHECK (abc_class = ANY (ARRAY['A'::text, 'B'::text, 'C'::text])),
  brand text,
  satuan character varying DEFAULT 'pcs'::character varying,
  CONSTRAINT inventories_pkey PRIMARY KEY (id),
  CONSTRAINT inventories_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.pos_customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  name text NOT NULL,
  phone text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pos_customers_pkey PRIMARY KEY (id),
  CONSTRAINT pos_customers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.pos_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  customer_id uuid,
  invoice_number text NOT NULL UNIQUE,
  total_gross numeric NOT NULL DEFAULT 0,
  total_profit numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL,
  payment_status text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pos_orders_pkey PRIMARY KEY (id),
  CONSTRAINT pos_orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT pos_orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.pos_customers(id)
);
CREATE TABLE public.pos_order_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  inventory_id uuid,
  qty integer NOT NULL CHECK (qty > 0),
  price_at_sale numeric NOT NULL,
  profit_at_sale numeric NOT NULL,
  total_price numeric NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pos_order_items_pkey PRIMARY KEY (id),
  CONSTRAINT pos_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.pos_orders(id),
  CONSTRAINT pos_order_items_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventories(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text NOT NULL,
  avatar_url text,
  phone_number text,
  store_name text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  total_price numeric NOT NULL DEFAULT 0,
  total_profit numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'completed'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.transaction_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid,
  product_id uuid,
  quantity integer NOT NULL DEFAULT 1,
  price_at_purchase numeric NOT NULL,
  profit_at_purchase numeric NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT transaction_items_pkey PRIMARY KEY (id),
  CONSTRAINT transaction_items_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id),
  CONSTRAINT transaction_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  title text NOT NULL,
  body text,
  type text,
  related_inventory_id uuid,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT notifications_related_inventory_id_fkey FOREIGN KEY (related_inventory_id) REFERENCES public.inventories(id)
);