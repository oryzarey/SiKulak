-- Supabase setup for the `todos` table used by SiKulak.
-- Run this in the Supabase SQL editor.

create extension if not exists pgcrypto;

create table if not exists public.todos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  is_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.todos enable row level security;

drop policy if exists "public can read todos" on public.todos;
create policy "public can read todos"
  on public.todos
  for select
  using (true);

comment on table public.todos is 'Task list used by SiKulak home page.';
