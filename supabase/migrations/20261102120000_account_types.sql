-- =====================================================================
-- Account types: users choose at registration whether they NEED a service
-- ('customer') or PROVIDE one ('provider'). Enforced in the database so a
-- modified client cannot bypass it.
-- =====================================================================

create type public.account_type as enum ('customer', 'provider');

alter table public.profiles
  add column account_type public.account_type not null default 'customer';

-- Backfill: anyone who already belongs to a business is a provider.
update public.profiles p
   set account_type = 'provider'
 where exists (select 1 from public.business_members m where m.user_id = p.id);

-- Signup trigger now reads the chosen type from the signup metadata.
-- Anything other than 'provider' falls back to 'customer'.
create or replace function private.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, account_type)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    case when new.raw_user_meta_data ->> 'account_type' = 'provider'
         then 'provider'::public.account_type
         else 'customer'::public.account_type
    end
  );
  return new;
end;
$$;

create function private.is_provider()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
     where id = (select auth.uid()) and account_type = 'provider'
  );
$$;

grant execute on function private.is_provider() to authenticated;

-- Only providers can create businesses.
drop policy "businesses: create as self" on public.businesses;

create policy "businesses: providers create as self"
  on public.businesses for insert to authenticated
  with check (owner_id = (select auth.uid()) and private.is_provider());

-- Users may edit their own profile, but not identity or account type.
create function private.protect_profile_columns()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and (
       new.id is distinct from old.id
    or new.email is distinct from old.email
    or new.account_type is distinct from old.account_type
  ) then
    raise exception 'These profile fields cannot be changed' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_protect_columns
  before update on public.profiles
  for each row execute function private.protect_profile_columns();
