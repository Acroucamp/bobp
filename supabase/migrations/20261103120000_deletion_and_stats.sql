-- =====================================================================
-- 1. Account deletion support
--    - Customer deleted  -> their bookings stay for the business's records
--                           (customer_id becomes NULL, shown as former customer)
--    - Staff deleted     -> their appointments become unassigned (staff_id NULL)
--    - Owner deleted     -> their businesses (and services/bookings) are deleted
-- 2. Business statistics for the owner dashboard
-- =====================================================================

alter table public.appointments alter column customer_id drop not null;

alter table public.appointments
  drop constraint appointments_customer_id_fkey,
  add  constraint appointments_customer_id_fkey
       foreign key (customer_id) references public.profiles (id) on delete set null;

alter table public.appointments
  drop constraint appointments_staff_id_fkey,
  add  constraint appointments_staff_id_fkey
       foreign key (staff_id) references public.profiles (id) on delete set null;

alter table public.businesses
  drop constraint businesses_owner_id_fkey,
  add  constraint businesses_owner_id_fkey
       foreign key (owner_id) references public.profiles (id) on delete cascade;

-- The update trigger must allow customer_id -> NULL (what the FK action does
-- when a customer deletes their account), while still blocking any other
-- change to booking details.
create or replace function private.appointments_before_update()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  actor    uuid := (select auth.uid());
  is_owner boolean;
  is_staff boolean;
  is_cust  boolean;
begin
  if (new.business_id, new.service_id, new.start_at, new.end_at,
      new.service_name, new.price_cents, new.duration_minutes)
     is distinct from
     (old.business_id, old.service_id, old.start_at, old.end_at,
      old.service_name, old.price_cents, old.duration_minutes)
     or (new.customer_id is distinct from old.customer_id
         and new.customer_id is not null) then
    raise exception 'Booking details cannot be changed' using errcode = '22023';
  end if;

  is_owner := private.is_business_owner(old.business_id);
  is_staff := old.staff_id = actor;
  is_cust  := old.customer_id = actor;

  if new.staff_id is distinct from old.staff_id and new.staff_id is not null then
    if actor is not null and not is_owner then
      raise exception 'Only owners can assign staff' using errcode = '42501';
    end if;
    if not private.user_in_business(new.business_id, new.staff_id) then
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

    if actor is not null and not (is_owner or is_staff) then
      if not (is_cust and new.status = 'cancelled') then
        raise exception 'Not allowed to make this status change' using errcode = '42501';
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Owner statistics: totals by status + per-day bookings and revenue.
-- Revenue = completed appointments only, using the price snapshot.
-- Days are grouped in the business time zone (constant for now).
-- ---------------------------------------------------------------------
create function public.get_business_stats(
  p_business_id uuid,
  p_from        date,
  p_to          date
)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  tz     constant text := 'Africa/Johannesburg';
  result jsonb;
begin
  if not private.is_business_owner(p_business_id) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  if p_to < p_from or p_to - p_from > 366 then
    raise exception 'Invalid date range' using errcode = '22023';
  end if;

  with appts as (
    select a.status, a.price_cents,
           (a.start_at at time zone tz)::date as day
      from public.appointments a
     where a.business_id = p_business_id
       and (a.start_at at time zone tz)::date between p_from and p_to
  ),
  days as (
    select (p_from + g)::date as day
      from generate_series(0, p_to - p_from) g
  ),
  per_day as (
    select d.day,
           count(a.status) filter (where a.status <> 'cancelled') as bookings,
           coalesce(sum(a.price_cents) filter (where a.status = 'completed'), 0) as revenue_cents
      from days d
      left join appts a on a.day = d.day
     group by d.day
  )
  select jsonb_build_object(
    'total',         (select count(*) from appts),
    'pending',       (select count(*) from appts where status = 'pending'),
    'confirmed',     (select count(*) from appts where status = 'confirmed'),
    'completed',     (select count(*) from appts where status = 'completed'),
    'cancelled',     (select count(*) from appts where status = 'cancelled'),
    'revenue_cents', (select coalesce(sum(price_cents), 0) from appts where status = 'completed'),
    'daily',         (select coalesce(
                        jsonb_agg(jsonb_build_object(
                          'day', day,
                          'bookings', bookings,
                          'revenue_cents', revenue_cents
                        ) order by day), '[]'::jsonb)
                       from per_day)
  ) into result;

  return result;
end;
$$;

revoke execute on function public.get_business_stats(uuid, date, date) from public, anon;
grant  execute on function public.get_business_stats(uuid, date, date) to authenticated;
