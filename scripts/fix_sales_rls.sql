-- Fix RLS policies for POS checkout flow.
-- Run this in Supabase SQL Editor once. Paste the full contents and click Run.

/*
  Summary:
  - Enables RLS on tables used by the POS.
  - Drops any previous known policies for these tables (safe to re-run).
  - Creates owner-based policies that allow authenticated users to insert/select/update/delete their own transactions,
    insert/select transaction_items only for transactions they own, and read/update their own inventories.
*/

begin;

alter table if exists public.transactions enable row level security;
alter table if exists public.transaction_items enable row level security;
alter table if exists public.inventories enable row level security;

-- DROP a few known policy names if they exist (idempotent)
drop policy if exists transactions_select_own on public.transactions;
drop policy if exists transactions_insert_own on public.transactions;
drop policy if exists transactions_update_own on public.transactions;
drop policy if exists transactions_delete_own on public.transactions;

drop policy if exists transaction_items_select_own on public.transaction_items;
drop policy if exists transaction_items_insert_own on public.transaction_items;

drop policy if exists inventories_select_own on public.inventories;
drop policy if exists inventories_update_own on public.inventories;

-- Transactions: owner can perform all actions on their rows
create policy transactions_select_own
  on public.transactions
  for select
  to authenticated
  using (user_id = auth.uid());

create policy transactions_insert_own
  on public.transactions
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy transactions_update_own
  on public.transactions
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy transactions_delete_own
  on public.transactions
  for delete
  to authenticated
  using (user_id = auth.uid());

-- Transaction items: only accessible/insertable when the parent transaction belongs to the current user
create policy transaction_items_select_own
  on public.transaction_items
  for select
  to authenticated
  using (
    exists (
      select 1 from public.transactions t
      where t.id = public.transaction_items.transaction_id
        and t.user_id = auth.uid()
    )
  );

create policy transaction_items_insert_own
  on public.transaction_items
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.transactions t
      where t.id = public.transaction_items.transaction_id
        and t.user_id = auth.uid()
    )
  );

-- Inventories: owner can read and update their inventory rows
create policy inventories_select_own
  on public.inventories
  for select
  to authenticated
  using (user_id = auth.uid());

create policy inventories_update_own
  on public.inventories
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

commit;
