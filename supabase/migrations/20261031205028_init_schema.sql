-- =====================================================================
-- Init schema: Business Operations & Booking Platform
-- Tables, enums, helper functions, triggers, indexes, RLS policies.
-- Money is stored as integer minor units (cents). Times are timestamptz.
-- =====================================================================

create extension if not exists btree_gist with schema extensions;

-- Helper functions live in a schema that is NOT exposed through the API,
-- so they cannot be called as RPC endpoints by clients.
create schema if not exists private;
grant usage on schema private to authenticated;

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
create type public.business_role as enum ('owner', 'staff');
create type public.appointment_status as enum
  ('pending', 'confirmed', 'cancelled', 'completed');

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '',
  email       text,
  created_at  timestamptz not null default now()
);

create table public.businesses (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(trim(name)) between 2 and 120),
  description text check (char_length(description) <= 1000),
  owner_id    uuid not null references public.profiles (id),
  created_at  timestamptz not null default now()
);

create table public.business_members (
  business_id uuid not null references public.businesses (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  role        public.business_role not null,
  created_at  timestamptz not null default now(),
  primary key (business_id, user_id)
);

create table public.services (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses (id) on delete cascade,
  name             text not null check (char_length(trim(name)) between 1 and 120),
  price_cents      integer not null check (price_cents >= 0),
  duration_minutes integer not null check (duration_minutes between 5 and 1440),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now()
);

create table public.appointments (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses (id) on delete cascade,
  service_id       uuid not null references public.services (id),
  customer_id      uuid not null references public.profiles (id),
  staff_id         uuid references public.profiles (id),
  start_at         timestamptz not null,
  end_at           timestamptz not null,
  status           public.appointment_status not null default 'pending',
  -- snapshot of the service at booking time (later edits don't rewrite history)
  service_name     text not null,
  price_cents      integer not null check (price_cents >= 0),
  duration_minutes integer not null check (duration_minutes > 0),
  created_at       timestamptz not null default now(),
  constraint appointment_time_order check (end_at > start_at),
  -- booking integrity: the same staff member cannot have overlapping
  -- pending/confirmed appointments (cancelled/completed are ignored)
  constraint appointments_no_staff_overlap exclude using gist (
    staff_id with =,
    tstzrange(start_at, end_at) with &&
  ) where (status in ('pending', 'confirmed') and staff_id is not null)
);

create table public.appointment_events (
  id             uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments (id) on delete cascade,
  actor_id       uuid,
  old_status     public.appointment_status,
  new_status     public.appointment_status not null,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------
create index business_members_user_idx   on public.business_members (user_id);
create index services_business_idx       on public.services (business_id);
create index appointments_business_idx   on public.appointments (business_id, start_at);
create index appointments_customer_idx   on public.appointments (customer_id, start_at);
create index appointments_staff_idx      on public.appointments (staff_id, start_at);
create index appointment_events_appt_idx on public.appointment_events (appointment_id);

-- ---------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER to avoid RLS recursion)
-- ---------------------------------------------------------------------
create function private.is_business_owner(b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.business_members
    where business_id = b
      and user_id = (select auth.uid())
      and role = 'owner'
  );
$$;

create function private.user_in_business(b uuid, u uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.business_members
    where business_id = b and user_id = u
  );
$$;

-- Can the current user see this profile? (self, same business, or
-- customer/staff relationship through an appointment)
create function private.can_view_profile(p uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select
    p = (select auth.uid())
    or exists (
      select 1
      from public.business_members m1
      join public.business_members m2 on m1.business_id = m2.business_id
      where m1.user_id = (select auth.uid()) and m2.user_id = p
    )
    or exists (
      select 1 from public.appointments a
      where a.customer_id = p
        and (private.is_business_owner(a.business_id)
             or a.staff_id = (select auth.uid()))
    )
    or exists (
      select 1 from public.appointments a
      where a.customer_id = (select auth.uid()) and a.staff_id = p
    );
$$;

grant execute on function
  private.is_business_owner(uuid),
  private.user_in_business(uuid, uuid),
  private.can_view_profile(uuid)
to authenticated;

-- ---------------------------------------------------------------------
-- Trigger: create a profile when a user signs up
-- ---------------------------------------------------------------------
create function private.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Backfill profiles for users created before this migration
insert into public.profiles (id, email, full_name)
select id, email, coalesce(raw_user_meta_data ->> 'full_name', '')
from auth.users
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Trigger: owner automatically becomes an 'owner' member of the business
-- ---------------------------------------------------------------------
create function private.add_owner_membership()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.business_members (business_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;

create trigger on_business_created
  after insert on public.businesses
  for each row execute function private.add_owner_membership();

-- ---------------------------------------------------------------------
-- Trigger: appointment insert rules (snapshot, end time, validation)
-- ---------------------------------------------------------------------
create function private.appointments_before_insert()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  s record;
begin
  select business_id, name, price_cents, duration_minutes, is_active
    into s
    from public.services
   where id = new.service_id;

  if not found or s.business_id <> new.business_id or not s.is_active then
    raise exception 'Invalid or inactive service' using errcode = '22023';
  end if;

  if new.start_at <= now() then
    raise exception 'Appointments must start in the future' using errcode = '22023';
  end if;

  if new.staff_id is not null
     and not private.user_in_business(new.business_id, new.staff_id) then
    raise exception 'Staff member does not belong to this business' using errcode = '22023';
  end if;

  new.service_name     := s.name;
  new.price_cents      := s.price_cents;
  new.duration_minutes := s.duration_minutes;
  new.end_at           := new.start_at + make_interval(mins => s.duration_minutes);
  new.status           := 'pending';
  return new;
end;
$$;

create trigger appointments_before_insert
  before insert on public.appointments
  for each row execute function private.appointments_before_insert();

-- ---------------------------------------------------------------------
-- Trigger: appointment update rules (immutable fields, status machine)
-- ---------------------------------------------------------------------
create function private.appointments_before_update()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  actor    uuid := (select auth.uid());
  is_owner boolean;
  is_staff boolean;
  is_cust  boolean;
begin
  if (new.business_id, new.service_id, new.customer_id, new.start_at,
      new.end_at, new.service_name, new.price_cents, new.duration_minutes)
     is distinct from
     (old.business_id, old.service_id, old.customer_id, old.start_at,
      old.end_at, old.service_name, old.price_cents, old.duration_minutes) then
    raise exception 'Booking details cannot be changed' using errcode = '22023';
  end if;

  is_owner := private.is_business_owner(old.business_id);
  is_staff := old.staff_id = actor;
  is_cust  := old.customer_id = actor;

  if new.staff_id is distinct from old.staff_id then
    if actor is not null and not is_owner then
      raise exception 'Only owners can assign staff' using errcode = '42501';
    end if;
    if new.staff_id is not null
       and not private.user_in_business(new.business_id, new.staff_id) then
      raise exception 'Staff member does not belong to this business' using errcode = '22023';
    end if;
  end if;

  if new.status is distinct from old.status then
    if not (
      (old.status = 'pending'   and new.status in ('confirmed', 'cancelled')) or
      (old.status = 'confirmed' and new.status in ('cancelled', 'completed'))
    ) then
      raise exception 'Invalid status change: % -> %', old.status, new.status
        using errcode = '22023';
    end if;

    -- customers may only cancel their own bookings
    if actor is not null and not (is_owner or is_staff) then
      if not (is_cust and new.status = 'cancelled') then
        raise exception 'Not allowed to make this status change' using errcode = '42501';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger appointments_before_update
  before update on public.appointments
  for each row execute function private.appointments_before_update();

-- ---------------------------------------------------------------------
-- Trigger: audit trail (clients can never write events directly)
-- ---------------------------------------------------------------------
create function private.log_appointment_event()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.appointment_events (appointment_id, actor_id, old_status, new_status)
    values (new.id, (select auth.uid()), null, new.status);
  elsif new.status is distinct from old.status then
    insert into public.appointment_events (appointment_id, actor_id, old_status, new_status)
    values (new.id, (select auth.uid()), old.status, new.status);
  end if;
  return null;
end;
$$;

create trigger appointments_audit
  after insert or update on public.appointments
  for each row execute function private.log_appointment_event();

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles           enable row level security;
alter table public.businesses         enable row level security;
alter table public.business_members   enable row level security;
alter table public.services           enable row level security;
alter table public.appointments       enable row level security;
alter table public.appointment_events enable row level security;

-- profiles (rows are created by the signup trigger, never by clients)
create policy "profiles: view allowed"
  on public.profiles for select to authenticated
  using (private.can_view_profile(id));

create policy "profiles: update own"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- businesses: anyone signed in can browse; only owners change them
create policy "businesses: browse"
  on public.businesses for select to authenticated
  using (true);

create policy "businesses: create as self"
  on public.businesses for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "businesses: owner update"
  on public.businesses for update to authenticated
  using (private.is_business_owner(id))
  with check (private.is_business_owner(id));

create policy "businesses: owner delete"
  on public.businesses for delete to authenticated
  using (private.is_business_owner(id));

-- business_members
create policy "members: view own or as owner"
  on public.business_members for select to authenticated
  using (user_id = (select auth.uid()) or private.is_business_owner(business_id));

create policy "members: owner adds staff"
  on public.business_members for insert to authenticated
  with check (private.is_business_owner(business_id) and role = 'staff');

create policy "members: owner removes staff"
  on public.business_members for delete to authenticated
  using (private.is_business_owner(business_id) and role = 'staff');

-- services: customers see active services; members see all of their own
create policy "services: view"
  on public.services for select to authenticated
  using (is_active or private.user_in_business(business_id, (select auth.uid())));

create policy "services: owner insert"
  on public.services for insert to authenticated
  with check (private.is_business_owner(business_id));

create policy "services: owner update"
  on public.services for update to authenticated
  using (private.is_business_owner(business_id))
  with check (private.is_business_owner(business_id));

create policy "services: owner delete"
  on public.services for delete to authenticated
  using (private.is_business_owner(business_id));

-- appointments: customer sees own; owner sees business; staff sees assigned
create policy "appointments: view"
  on public.appointments for select to authenticated
  using (
    customer_id = (select auth.uid())
    or staff_id = (select auth.uid())
    or private.is_business_owner(business_id)
  );

create policy "appointments: customer books for self"
  on public.appointments for insert to authenticated
  with check (customer_id = (select auth.uid()));

create policy "appointments: update (details enforced by trigger)"
  on public.appointments for update to authenticated
  using (
    customer_id = (select auth.uid())
    or staff_id = (select auth.uid())
    or private.is_business_owner(business_id)
  )
  with check (
    customer_id = (select auth.uid())
    or staff_id = (select auth.uid())
    or private.is_business_owner(business_id)
  );

-- appointment_events: read-only, visible if the appointment is visible
create policy "events: view via appointment"
  on public.appointment_events for select to authenticated
  using (
    exists (
      select 1 from public.appointments a
      where a.id = appointment_id
    )
  );