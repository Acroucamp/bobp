-- =====================================================================
-- Tester sign-ups from the lekkerbook.co.za landing page.
-- The public (anon) role may INSERT only. Nobody can read, change or delete
-- rows through the API. You read the list in the Supabase dashboard
-- (Table Editor -> tester_signups -> Export to CSV).
-- Additive migration: safe to run while the live app is in use.
-- =====================================================================

create table if not exists public.tester_signups (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  full_name   text,
  source      text not null default 'landing',
  created_at  timestamptz not null default now(),
  constraint tester_signups_email_format
    check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and char_length(email) <= 254),
  constraint tester_signups_name_len
    check (full_name is null or char_length(full_name) <= 100),
  constraint tester_signups_source_len
    check (char_length(source) <= 40)
);

-- one row per person, regardless of upper/lower case
create unique index if not exists tester_signups_email_key
  on public.tester_signups (lower(email));

alter table public.tester_signups enable row level security;

drop policy if exists "anyone can sign up as a tester" on public.tester_signups;
create policy "anyone can sign up as a tester"
  on public.tester_signups
  for insert
  to anon, authenticated
  with check (true);

-- No select / update / delete policies on purpose.
revoke all on public.tester_signups from anon, authenticated;
grant insert on public.tester_signups to anon, authenticated;
