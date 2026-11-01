-- Users can report a business listing (spam, offensive, misleading, other).
-- Apps that show user-generated content are expected to offer a way to report it.
-- Reports are write-only for users; you review them in the Supabase dashboard
-- (Table Editor > business_reports) and remove a business if needed.

create table public.business_reports (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  reporter_id uuid not null default auth.uid()
                references public.profiles (id) on delete cascade,
  category    text not null check (category in ('spam', 'offensive', 'misleading', 'other')),
  details     text check (char_length(details) <= 500),
  created_at  timestamptz not null default now(),
  unique (business_id, reporter_id)
);

alter table public.business_reports enable row level security;

create policy "reports: create as self"
  on public.business_reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));

-- No select/update/delete policies: users cannot read reports.
