-- LAUNCH METRICS: run in the Supabase SQL editor. No analytics SDK needed.
-- Play Console shows installs; these show what people did afterwards.

-- Sign-ups per day by account type
select (created_at at time zone 'Africa/Johannesburg')::date as day,
       account_type,
       count(*) as signups
  from public.profiles
 group by 1, 2
 order by 1 desc, 2;

-- Totals
select
  (select count(*) from public.profiles where account_type = 'customer') as customers,
  (select count(*) from public.profiles where account_type = 'provider') as providers,
  (select count(*) from public.businesses)                                as businesses,
  (select count(*) from public.services)                                  as services,
  (select count(*) from public.appointments)                              as bookings,
  (select count(*) from public.appointments where status = 'completed')   as completed;

-- Funnel: of customers who signed up, how many booked at least once?
select count(*) as customers,
       count(*) filter (where exists (
         select 1 from public.appointments a where a.customer_id = p.id
       )) as customers_who_booked
  from public.profiles p
 where account_type = 'customer';

-- Providers who finished setup (a business with at least one active service)
select count(*) as providers,
       count(*) filter (where exists (
         select 1 from public.businesses b
           join public.services s on s.business_id = b.id and s.is_active
          where b.owner_id = p.id
       )) as providers_ready
  from public.profiles p
 where account_type = 'provider';

-- Bookings per day
select (created_at at time zone 'Africa/Johannesburg')::date as day, count(*) as bookings
  from public.appointments
 group by 1 order by 1 desc;

-- Unreviewed reports
select r.created_at, b.name as business, r.category, r.details
  from public.business_reports r
  join public.businesses b on b.id = r.business_id
 order by r.created_at desc;

-- PRE-LAUNCH CHECK: every public table must have RLS enabled (rowsecurity = true)
select tablename, rowsecurity
  from pg_tables
 where schemaname = 'public'
 order by tablename;
