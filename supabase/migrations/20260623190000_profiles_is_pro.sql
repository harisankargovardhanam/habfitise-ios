-- Server-side Pro flag + block client from self-granting Pro.
-- Also maintained in habfitise-functions repo.

alter table public.profiles
  add column if not exists is_pro boolean not null default false;

comment on column public.profiles.is_pro is
  'Set only by RevenueCat webhook or service role — not by mobile clients.';

create or replace function public.protect_profiles_is_pro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.is_pro is distinct from old.is_pro then
    if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
      return new;
    end if;
    if auth.uid() is not null then
      new.is_pro := old.is_pro;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profiles_is_pro_trigger on public.profiles;
create trigger protect_profiles_is_pro_trigger
  before update on public.profiles
  for each row
  execute function public.protect_profiles_is_pro();

create index if not exists profiles_user_id_idx on public.profiles (user_id);
