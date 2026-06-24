-- Fix profiles 403 on upsert — drop ALL old policies, recreate with Supabase-recommended pattern.
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- Schema safety (columns the iOS app writes)
-- ---------------------------------------------------------------------------

alter table public.profiles
    add column if not exists target_weight_kg numeric default 0;

alter table public.profiles
    add column if not exists goal_deadline timestamptz default now();

alter table public.profiles
    add column if not exists updated_at timestamptz default now();

alter table public.profiles
    alter column goal set default '';

-- ---------------------------------------------------------------------------
-- Auto-create profile row on signup (upsert becomes UPDATE, fewer RLS edge cases)
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, goal, created_at, updated_at)
    values (new.id, '', now(), now())
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

-- Backfill profiles for existing auth users missing a row
insert into public.profiles (id, goal, created_at, updated_at)
select id, '', coalesce(created_at, now()), now()
from auth.users u
where not exists (
    select 1 from public.profiles p where p.id = u.id
);

-- ---------------------------------------------------------------------------
-- Drop every existing RLS policy on sync tables (old names may block writes)
-- ---------------------------------------------------------------------------

do $$
declare
    r record;
begin
    for r in
        select schemaname, tablename, policyname
        from pg_policies
        where schemaname = 'public'
          and tablename in (
              'profiles',
              'workout_sessions',
              'workout_sets',
              'habits',
              'habit_completions',
              'tasks',
              'mood_checkins',
              'water_logs',
              'water_goals'
          )
    loop
        execute format(
            'drop policy if exists %I on %I.%I',
            r.policyname,
            r.schemaname,
            r.tablename
        );
    end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sets enable row level security;
alter table public.habits enable row level security;
alter table public.habit_completions enable row level security;
alter table public.tasks enable row level security;
alter table public.mood_checkins enable row level security;
alter table public.water_logs enable row level security;
alter table public.water_goals enable row level security;

-- ---------------------------------------------------------------------------
-- profiles — id must equal auth.uid()
-- ---------------------------------------------------------------------------

create policy "profiles_select_own"
    on public.profiles for select to authenticated
    using ((select auth.uid()) = id);

create policy "profiles_insert_own"
    on public.profiles for insert to authenticated
    with check ((select auth.uid()) = id);

create policy "profiles_update_own"
    on public.profiles for update to authenticated
    using ((select auth.uid()) = id)
    with check ((select auth.uid()) = id);

create policy "profiles_delete_own"
    on public.profiles for delete to authenticated
    using ((select auth.uid()) = id);

-- ---------------------------------------------------------------------------
-- All other tables — user_id must equal auth.uid()
-- ---------------------------------------------------------------------------

do $$
declare
    tbl text;
begin
    foreach tbl in array array[
        'workout_sessions',
        'workout_sets',
        'habits',
        'habit_completions',
        'tasks',
        'mood_checkins',
        'water_logs',
        'water_goals'
    ]
    loop
        execute format(
            'create policy %I on public.%I for select to authenticated
             using ((select auth.uid()) = user_id)',
            tbl || '_select_own',
            tbl
        );
        execute format(
            'create policy %I on public.%I for insert to authenticated
             with check ((select auth.uid()) = user_id)',
            tbl || '_insert_own',
            tbl
        );
        execute format(
            'create policy %I on public.%I for update to authenticated
             using ((select auth.uid()) = user_id)
             with check ((select auth.uid()) = user_id)',
            tbl || '_update_own',
            tbl
        );
        execute format(
            'create policy %I on public.%I for delete to authenticated
             using ((select auth.uid()) = user_id)',
            tbl || '_delete_own',
            tbl
        );
    end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

grant usage on schema public to authenticated;

grant select, insert, update, delete on table
    public.profiles,
    public.workout_sessions,
    public.workout_sets,
    public.habits,
    public.habit_completions,
    public.tasks,
    public.mood_checkins,
    public.water_logs,
    public.water_goals
to authenticated;
