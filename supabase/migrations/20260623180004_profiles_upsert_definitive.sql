-- Definitive fix for profiles POST 403 (PostgREST error 42501 / RLS).
-- Run in Supabase SQL editor. Safe to re-run.

-- ---------------------------------------------------------------------------
-- Schema: support both id = auth.uid() and legacy user_id ownership
-- ---------------------------------------------------------------------------

alter table public.profiles
    add column if not exists user_id uuid references auth.users (id) on delete cascade;

alter table public.profiles
    add column if not exists target_weight_kg numeric default 0;

alter table public.profiles
    add column if not exists goal_deadline timestamptz default now();

alter table public.profiles
    add column if not exists updated_at timestamptz default now();

alter table public.profiles
    alter column goal set default '';

-- Keep id and user_id aligned for existing rows
update public.profiles
set user_id = id
where user_id is null
  and id is not null;

update public.profiles
set id = user_id
where user_id is not null
  and id is distinct from user_id
  and not exists (
      select 1 from public.profiles p2
      where p2.id = profiles.user_id
        and p2.ctid <> profiles.ctid
  );

-- ---------------------------------------------------------------------------
-- Auto-create profile on signup (row exists before iOS upsert)
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, user_id, goal, created_at, updated_at)
    values (new.id, new.id, '', now(), now())
    on conflict (id) do update
        set user_id = excluded.user_id,
            updated_at = now();
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

insert into public.profiles (id, user_id, goal, created_at, updated_at)
select u.id, u.id, '', coalesce(u.created_at, now()), now()
from auth.users u
where not exists (
    select 1
    from public.profiles p
    where p.id = u.id
       or p.user_id = u.id
);

-- ---------------------------------------------------------------------------
-- Drop every policy on profiles (old names may still block writes)
-- ---------------------------------------------------------------------------

do $$
declare
    pol record;
begin
    for pol in
        select policyname
        from pg_policies
        where schemaname = 'public'
          and tablename = 'profiles'
    loop
        execute format('drop policy if exists %I on public.profiles', pol.policyname);
    end loop;
end;
$$;

alter table public.profiles enable row level security;

-- Owner = auth user matches profiles.id OR profiles.user_id
create policy "profiles_select_own"
    on public.profiles
    for select
    to authenticated
    using (
        (select auth.uid()) = id
        or (select auth.uid()) = user_id
    );

create policy "profiles_insert_own"
    on public.profiles
    for insert
    to authenticated
    with check (
        (select auth.uid()) = id
        and (
            user_id is null
            or (select auth.uid()) = user_id
        )
    );

create policy "profiles_update_own"
    on public.profiles
    for update
    to authenticated
    using (
        (select auth.uid()) = id
        or (select auth.uid()) = user_id
    )
    with check (
        (select auth.uid()) = id
        or (select auth.uid()) = user_id
    );

create policy "profiles_delete_own"
    on public.profiles
    for delete
    to authenticated
    using (
        (select auth.uid()) = id
        or (select auth.uid()) = user_id
    );

-- ---------------------------------------------------------------------------
-- Table grants (RLS still applies)
-- ---------------------------------------------------------------------------

grant usage on schema public to authenticated;

grant select, insert, update, delete
    on table public.profiles
    to authenticated;
