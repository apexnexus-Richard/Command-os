-- supabase/sql/002_rls.sql
-- Command OS v1: RLS + indexes
-- Assumes tables already exist in public schema.

-- Enable RLS
alter table public.devices  enable row level security;
alter table public.tasks    enable row level security;
alter table public.approvals enable row level security;
alter table public.events   enable row level security;
alter table public.artifacts enable row level security;

-- Owner-scoped CRUD for core tables
create policy "devices_owner_crud"
on public.devices
for all
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

create policy "tasks_owner_crud"
on public.tasks
for all
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

create policy "approvals_owner_crud"
on public.approvals
for all
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

create policy "artifacts_owner_crud"
on public.artifacts
for all
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

-- Events: owner can READ, but writes are reserved for service_role (edge functions).
create policy "events_owner_read"
on public.events
for select
using (owner_user_id = auth.uid());

-- Explicitly deny events mutations for authenticated users (defense in depth).
-- With RLS enabled and no insert/update/delete policies, these operations are blocked.

-- Indexes for task queue + timelines
create index if not exists idx_tasks_status on public.tasks(status);
create index if not exists idx_tasks_lease_expires_at on public.tasks(lease_expires_at);
create index if not exists idx_events_created_at on public.events(created_at);
create index if not exists idx_artifacts_task_id on public.artifacts(task_id);
