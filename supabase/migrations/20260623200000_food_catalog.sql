-- Global food catalog: curated staples + USDA references + AI-learned entries.
-- Read-only for clients; writes via service role (edge functions).

create extension if not exists "pgcrypto";

create table if not exists public.food_catalog (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    name_normalized text not null,
    search_aliases text[] not null default '{}',
    serving_description text not null,
    calories_low int not null check (calories_low >= 0),
    calories_mid int not null check (calories_mid >= 0),
    calories_high int not null check (calories_high >= 0),
    protein_low int not null check (protein_low >= 0),
    protein_mid int not null check (protein_mid >= 0),
    protein_high int not null check (protein_high >= 0),
    source text not null check (source in ('curated', 'usda', 'ai_cached')),
    external_id text,
    region text not null default 'global',
    usage_count int not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint food_catalog_name_normalized_unique unique (name_normalized)
);

create index if not exists food_catalog_name_normalized_idx
    on public.food_catalog (name_normalized);

create index if not exists food_catalog_source_idx
    on public.food_catalog (source);

create index if not exists food_catalog_aliases_gin_idx
    on public.food_catalog using gin (search_aliases);

alter table public.food_catalog enable row level security;

drop policy if exists food_catalog_select_authenticated on public.food_catalog;
create policy food_catalog_select_authenticated
    on public.food_catalog
    for select
    to authenticated
    using (true);

-- Seed curated staples (Indian + global). ON CONFLICT keeps migrations re-runnable.
insert into public.food_catalog (
    name, name_normalized, search_aliases, serving_description,
    calories_low, calories_mid, calories_high,
    protein_low, protein_mid, protein_high,
    source, region
) values
    ('Milk tea (chai)', 'milk tea chai', array['tea with sugar', 'chai', 'indian tea', '1 cup tea with sugar', 'cup tea with sugar', 'tea with milk'], '1 cup (~240 ml)', 70, 90, 110, 2, 3, 4, 'curated', 'south_asia'),
    ('Black tea with sugar', 'black tea with sugar', array['tea sugar', 'black tea'], '1 cup (~240 ml)', 25, 40, 55, 0, 0, 1, 'curated', 'global'),
    ('Plain black tea', 'plain black tea', array['black tea', 'tea without milk', 'green tea'], '1 cup (~240 ml)', 0, 2, 5, 0, 0, 0, 'curated', 'global'),
    ('Coffee with milk and sugar', 'coffee with milk and sugar', array['coffee milk sugar', 'filter coffee'], '1 cup (~240 ml)', 80, 100, 120, 2, 3, 4, 'curated', 'south_asia'),
    ('Idli', 'idli', array['idly', '2 idli'], '2 pieces', 60, 78, 95, 2, 3, 4, 'curated', 'south_asia'),
    ('Plain dosa', 'plain dosa', array['dosa', '1 dosa'], '1 medium dosa', 95, 120, 145, 2, 3, 4, 'curated', 'south_asia'),
    ('Masala dosa', 'masala dosa', array['masala dosa'], '1 serving', 220, 280, 340, 6, 8, 10, 'curated', 'south_asia'),
    ('Chicken biryani', 'chicken biryani', array['biryani', 'chicken biriyani'], '1 plate (~350 g)', 560, 680, 820, 22, 28, 34, 'curated', 'south_asia'),
    ('Vegetable biryani', 'vegetable biryani', array['veg biryani'], '1 plate (~350 g)', 420, 520, 620, 10, 12, 15, 'curated', 'south_asia'),
    ('Dal tadka', 'dal tadka', array['dal', 'yellow dal', 'toor dal'], '1 cup', 140, 180, 220, 8, 10, 12, 'curated', 'south_asia'),
    ('Roti / chapati', 'roti chapati', array['roti', 'chapati', 'phulka'], '1 piece', 55, 70, 85, 2, 2, 3, 'curated', 'south_asia'),
    ('Paratha plain', 'paratha plain', array['paratha', 'plain paratha'], '1 piece', 180, 230, 280, 4, 5, 6, 'curated', 'south_asia'),
    ('White rice cooked', 'white rice cooked', array['rice', 'steamed rice', '1 cup rice'], '1 cup cooked', 180, 206, 235, 3, 4, 5, 'curated', 'global'),
    ('Brown rice cooked', 'brown rice cooked', array['brown rice'], '1 cup cooked', 190, 216, 245, 4, 5, 6, 'curated', 'global'),
    ('Boiled egg', 'boiled egg', array['egg', 'eggs', '1 egg', '2 eggs'], '1 large egg', 62, 78, 95, 5, 6, 7, 'curated', 'global'),
    ('Omelette', 'omelette', array['omelet', '2 egg omelette'], '2-egg omelette', 140, 180, 220, 10, 12, 14, 'curated', 'global'),
    ('Chicken curry', 'chicken curry', array['chicken curry gravy'], '1 cup with gravy', 180, 240, 300, 18, 22, 26, 'curated', 'south_asia'),
    ('Paneer butter masala', 'paneer butter masala', array['paneer masala', 'paneer curry'], '1 cup', 280, 360, 440, 12, 14, 17, 'curated', 'south_asia'),
    ('Samosa', 'samosa', array['1 samosa', '2 samosas'], '1 piece', 200, 260, 320, 4, 5, 6, 'curated', 'south_asia'),
    ('Poha', 'poha', array['pohe', 'flattened rice'], '1 plate', 180, 230, 280, 4, 5, 6, 'curated', 'south_asia'),
    ('Upma', 'upma', array['rava upma'], '1 plate', 200, 250, 300, 5, 6, 8, 'curated', 'south_asia'),
    ('Curd / yogurt plain', 'curd yogurt plain', array['curd', 'yogurt', 'dahi'], '1 cup', 120, 150, 180, 8, 11, 13, 'curated', 'south_asia'),
    ('Banana', 'banana', array['1 banana'], '1 medium', 85, 105, 125, 1, 1, 2, 'curated', 'global'),
    ('Apple', 'apple', array['1 apple'], '1 medium', 70, 95, 115, 0, 0, 1, 'curated', 'global'),
    ('Oats cooked with milk', 'oats cooked with milk', array['oatmeal', 'oats'], '1 bowl', 200, 250, 300, 8, 10, 12, 'curated', 'global'),
    ('Grilled chicken breast', 'grilled chicken breast', array['chicken breast'], '100 g cooked', 140, 165, 190, 28, 31, 34, 'curated', 'global'),
    ('Salmon cooked', 'salmon cooked', array['salmon', 'fish'], '100 g', 180, 208, 235, 20, 22, 25, 'curated', 'global'),
    ('Caesar salad', 'caesar salad', array['salad'], '1 bowl', 220, 320, 420, 8, 12, 16, 'curated', 'global'),
    ('Pizza slice cheese', 'pizza slice cheese', array['pizza', '1 slice pizza'], '1 large slice', 220, 285, 350, 10, 12, 14, 'curated', 'global'),
    ('Protein shake whey', 'protein shake whey', array['protein shake', 'whey shake'], '1 scoop with water', 100, 120, 140, 20, 24, 28, 'curated', 'global')
on conflict (name_normalized) do update set
    name = excluded.name,
    search_aliases = excluded.search_aliases,
    serving_description = excluded.serving_description,
    calories_low = excluded.calories_low,
    calories_mid = excluded.calories_mid,
    calories_high = excluded.calories_high,
    protein_low = excluded.protein_low,
    protein_mid = excluded.protein_mid,
    protein_high = excluded.protein_high,
    source = excluded.source,
    region = excluded.region,
    updated_at = now();
