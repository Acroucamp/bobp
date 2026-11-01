-- =====================================================================
-- Booking functions: available slots + atomic booking.
-- Customers cannot read other people's appointments (RLS), so availability
-- is computed server-side with SECURITY DEFINER functions that return only
-- free time slots, never personal data.
--
-- TEMPORARY: opening hours (08:00-17:00), 30-minute steps and the
-- Africa/Johannesburg time zone are constants. Week 5 replaces them with
-- per-staff working hours.
-- =====================================================================

create function public.get_available_slots(
  p_business_id uuid,
  p_service_id  uuid,
  p_day         date
)
returns table (slot_start timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
declare
  dur    integer;
  tz     constant text := 'Africa/Johannesburg';
  opens  constant time := '08:00';
  closes constant time := '17:00';
  step   constant interval := '30 minutes';
begin
  if (select auth.uid()) is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  select s.duration_minutes into dur
    from public.services s
   where s.id = p_service_id and s.business_id = p_business_id and s.is_active;

  if dur is null then
    raise exception 'Invalid or inactive service' using errcode = '22023';
  end if;

  return query
  select g.t
    from generate_series(
           ((p_day + opens) at time zone tz),
           ((p_day + closes) at time zone tz) - make_interval(mins => dur),
           step
         ) as g(t)
   where g.t > now()
     and exists (
       select 1
         from public.business_members m
        where m.business_id = p_business_id
          and not exists (
            select 1
              from public.appointments a
             where a.staff_id = m.user_id
               and a.status in ('pending', 'confirmed')
               and tstzrange(a.start_at, a.end_at)
                   && tstzrange(g.t, g.t + make_interval(mins => dur))
          )
     )
   order by g.t;
end;
$$;

create function public.book_appointment(
  p_business_id uuid,
  p_service_id  uuid,
  p_start_at    timestamptz
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  tz     constant text := 'Africa/Johannesburg';
  dur    integer;
  chosen uuid;
  new_id uuid;
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  select s.duration_minutes into dur
    from public.services s
   where s.id = p_service_id and s.business_id = p_business_id and s.is_active;

  if dur is null then
    raise exception 'Invalid or inactive service' using errcode = '22023';
  end if;

  -- the requested time must be one of the offered slots
  if not exists (
    select 1
      from public.get_available_slots(
             p_business_id, p_service_id, (p_start_at at time zone tz)::date
           ) g
     where g.slot_start = p_start_at
  ) then
    raise exception 'That time slot is no longer available' using errcode = '23P01';
  end if;

  -- pick the first provider who is free for the whole appointment
  select m.user_id into chosen
    from public.business_members m
   where m.business_id = p_business_id
     and not exists (
       select 1
         from public.appointments a
        where a.staff_id = m.user_id
          and a.status in ('pending', 'confirmed')
          and tstzrange(a.start_at, a.end_at)
              && tstzrange(p_start_at, p_start_at + make_interval(mins => dur))
     )
   order by m.created_at
   limit 1;

  if chosen is null then
    raise exception 'That time slot is no longer available' using errcode = '23P01';
  end if;

  -- triggers snapshot the service, set end_at and force status = pending;
  -- the exclusion constraint is the final guard against double booking
  insert into public.appointments (business_id, service_id, customer_id, staff_id, start_at)
  values (p_business_id, p_service_id, uid, chosen, p_start_at)
  returning id into new_id;

  return new_id;
exception
  when exclusion_violation then
    raise exception 'That time slot is no longer available' using errcode = '23P01';
end;
$$;

-- Functions in `public` are callable as API endpoints: lock them down.
revoke execute on function public.get_available_slots(uuid, uuid, date)        from public, anon;
revoke execute on function public.book_appointment(uuid, uuid, timestamptz)    from public, anon;
grant  execute on function public.get_available_slots(uuid, uuid, date)        to authenticated;
grant  execute on function public.book_appointment(uuid, uuid, timestamptz)    to authenticated;
