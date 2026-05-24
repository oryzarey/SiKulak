-- Alter inventories table to support additional item details (weight and photo URL)
-- Run this in your Supabase SQL Editor.

alter table public.inventories 
add column if not exists image_url text,
add column if not exists weight_gr numeric default 0;

comment on column public.inventories.image_url is 'User-uploaded photo URL for custom inventory items.';
comment on column public.inventories.weight_gr is 'Weight of the inventory item in grams (Gr).';
