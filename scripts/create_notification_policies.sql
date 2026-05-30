-- Enable Row Level Security for notifications
alter table public.notifications enable row level security;

-- Users can only read their own notifications
create policy "Users can view own notifications"
on public.notifications
for select
using (auth.uid() = user_id);

-- Users can only insert notifications for themselves
create policy "Users can insert own notifications"
on public.notifications
for insert
with check (auth.uid() = user_id);

-- Users can only update their own notifications (for is_read, etc.)
create policy "Users can update own notifications"
on public.notifications
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
