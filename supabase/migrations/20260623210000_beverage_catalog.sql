-- Common beverages missing from initial seed (coffee, etc.)

insert into public.food_catalog (
    name, name_normalized, search_aliases, serving_description,
    calories_low, calories_mid, calories_high,
    protein_low, protein_mid, protein_high,
    source, region
) values
    (
        'Coffee with milk',
        'coffee with milk',
        array['cup of coffee with milk', 'one cup of coffee with milk', 'coffee milk', 'coffee with milk no sugar'],
        '1 cup (~240 ml)',
        30, 45, 60,
        2, 3, 4,
        'curated', 'global'
    ),
    (
        'Black coffee',
        'black coffee',
        array['plain coffee', 'coffee without milk', 'espresso', 'americano'],
        '1 cup (~240 ml)',
        0, 5, 10,
        0, 0, 1,
        'curated', 'global'
    ),
    (
        'Latte',
        'latte',
        array['caffe latte', 'coffee latte', 'latte coffee'],
        '1 cup (~240 ml)',
        90, 120, 150,
        4, 6, 8,
        'curated', 'global'
    )
on conflict (name_normalized) do update set
    search_aliases = excluded.search_aliases,
    serving_description = excluded.serving_description,
    calories_low = excluded.calories_low,
    calories_mid = excluded.calories_mid,
    calories_high = excluded.calories_high,
    protein_low = excluded.protein_low,
    protein_mid = excluded.protein_mid,
    protein_high = excluded.protein_high,
    updated_at = now();
