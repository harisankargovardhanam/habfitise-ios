-- VAYA iOS sync — align EXISTING Supabase schema (safe to re-run)
-- Your project already has: profiles, workout_sessions, workout_sets, habits, etc.
-- This migration only ADDs missing columns + creates water tables.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- profiles (row id = auth user uuid; no separate user_id column)
-- ---------------------------------------------------------------------------

alter table public.profiles
    add column if not exists target_weight_kg numeric default 0;

alter table public.profiles
    add column if not exists goal_deadline timestamptz default now();

alter table public.profiles
    add column if not exists updated_at timestamptz default now();

-- ---------------------------------------------------------------------------
-- workout_sessions (uses scheduled_date, not started_at)
-- ---------------------------------------------------------------------------

alter table public.workout_sessions
    add column if not exists name text default '';

alter table public.workout_sessions
    add column if not exists type text default 'Weight Training';

alter table public.workout_sessions
    add column if not exists total_volume_kg numeric default 0;

alter table public.workout_sessions
    add column if not exists total_calories int4;

alter table public.workout_sessions
    add column if not exists mood int4 default 3;

alter table public.workout_sessions
    add column if not exists perceived_exertion int4 default 5;

-- ---------------------------------------------------------------------------
-- workout_sets
-- ---------------------------------------------------------------------------

alter table public.workout_sets
    add column if not exists exercise_category text default 'full';

alter table public.workout_sets
    add column if not exists duration_seconds int4;

alter table public.workout_sets
    add column if not exists distance_km numeric;

alter table public.workout_sets
    add column if not exists is_warmup boolean default false;

alter table public.workout_sets
    add column if not exists is_personal_record boolean default false;

alter table public.workout_sets
    add column if not exists updated_at timestamptz default now();

-- ---------------------------------------------------------------------------
-- habits / habit_completions / tasks / mood_checkins
-- ---------------------------------------------------------------------------

alter table public.habits
    add column if not exists updated_at timestamptz default now();

alter table public.habit_completions
    add column if not exists updated_at timestamptz default now();

alter table public.tasks
    add column if not exists updated_at timestamptz default now();

alter table public.mood_checkins
    add column if not exists updated_at timestamptz default now();

-- ---------------------------------------------------------------------------
-- water (new tables — use uuid user_id like your other tables)
-- ---------------------------------------------------------------------------

create table if not exists public.water_logs (
    id uuid primary key,
    user_id uuid not null,
    amount_ml integer not null,
    logged_at timestamptz not null default now(),
    source text not null default 'manual',
    updated_at timestamptz not null default now()
);

create table if not exists public.water_goals (
    id uuid primary key,
    user_id uuid not null,
    daily_goal_ml integer not null default 2500,
    reminder_interval_minutes integer not null default 120,
    reminder_start_time timestamptz not null default now(),
    reminder_end_time timestamptz not null default now(),
    is_reminder_enabled boolean not null default true,
    updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes (only columns that exist in your schema)
-- ---------------------------------------------------------------------------

create index if not exists profiles_updated_at_idx
    on public.profiles (updated_at desc);

create index if not exists workout_sessions_user_scheduled_idx
    on public.workout_sessions (user_id, scheduled_date desc);

create index if not exists workout_sets_session_id_idx
    on public.workout_sets (session_id);

create index if not exists workout_sets_user_id_idx
    on public.workout_sets (user_id);

create index if not exists habits_user_id_idx
    on public.habits (user_id);

create index if not exists habit_completions_user_id_idx
    on public.habit_completions (user_id);

create index if not exists habit_completions_habit_id_idx
    on public.habit_completions (habit_id);

create index if not exists tasks_user_id_idx
    on public.tasks (user_id);

create index if not exists mood_checkins_user_id_idx
    on public.mood_checkins (user_id);

create index if not exists water_logs_user_id_idx
    on public.water_logs (user_id);

create index if not exists water_logs_logged_at_idx
    on public.water_logs (user_id, logged_at desc);

create index if not exists water_goals_user_id_idx
    on public.water_goals (user_id);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

do $$
declare
    t text;
begin
    foreach t in array array[
        'profiles',
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
            'drop trigger if exists set_%s_updated_at on public.%I',
            t,
            t
        );
        execute format(
            'create trigger set_%s_updated_at before update on public.%I
             for each row execute function public.set_updated_at()',
            t,
            t
        );
    end loop;
end;
$$;
