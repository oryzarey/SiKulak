-- Auto-update updated_at on inventories changes
-- Run in Supabase SQL editor

create or replace function public.set_inventories_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_inventories_updated_at on public.inventories;

create trigger set_inventories_updated_at
before update on public.inventories
for each row
execute function public.set_inventories_updated_at();
