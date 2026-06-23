-- VAYA iOS sync — RLS for existing table names
-- profiles.id = auth.uid(); all other tables use user_id uuid

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_sync_owner(record_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select auth.uid() = record_user_id;
$$;

create or replace function public.is_profile_owner(profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select auth.uid() = profile_id;
$$;

revoke all on function public.is_sync_owner(uuid) from public;
revoke all on function public.is_profile_owner(uuid) from public;
grant execute on function public.is_sync_owner(uuid) to authenticated;
grant execute on function public.is_profile_owner(uuid) to authenticated;

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
-- profiles (owned by id, not user_id)
-- ---------------------------------------------------------------------------

drop policy if exists "sync_select_own" on public.profiles;
drop policy if exists "sync_insert_own" on public.profiles;
drop policy if exists "sync_update_own" on public.profiles;
drop policy if exists "sync_delete_own" on public.profiles;

create policy "sync_select_own" on public.profiles
    for select to authenticated
    using (public.is_profile_owner(id));

create policy "sync_insert_own" on public.profiles
    for insert to authenticated
    with check (public.is_profile_owner(id));

create policy "sync_update_own" on public.profiles
    for update to authenticated
    using (public.is_profile_owner(id))
    with check (public.is_profile_owner(id));

create policy "sync_delete_own" on public.profiles
    for delete to authenticated
    using (public.is_profile_owner(id));

-- ---------------------------------------------------------------------------
-- Standard user_id tables
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
        execute format('drop policy if exists "sync_select_own" on public.%I', tbl);
        execute format('drop policy if exists "sync_insert_own" on public.%I', tbl);
        execute format('drop policy if exists "sync_update_own" on public.%I', tbl);
        execute format('drop policy if exists "sync_delete_own" on public.%I', tbl);

        execute format(
            'create policy "sync_select_own" on public.%I
             for select to authenticated using (public.is_sync_owner(user_id))',
            tbl
        );
        execute format(
            'create policy "sync_insert_own" on public.%I
             for insert to authenticated with check (public.is_sync_owner(user_id))',
            tbl
        );
        execute format(
            'create policy "sync_update_own" on public.%I
             for update to authenticated
             using (public.is_sync_owner(user_id))
             with check (public.is_sync_owner(user_id))',
            tbl
        );
        execute format(
            'create policy "sync_delete_own" on public.%I
             for delete to authenticated using (public.is_sync_owner(user_id))',
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
