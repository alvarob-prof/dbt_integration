-- int_coil_production.sql
-- Enriches each coil record with plant, grade, product line,
-- and production order context.

with coils as (

    select * from {{ ref('stg_acx_coil_outputs') }}

),

orders as (

    select * from {{ ref('stg_acx_production_orders') }}

),

plants as (

    select * from {{ ref('stg_acx_plants') }}

),

grades as (

    select * from {{ ref('stg_acx_steel_grades') }}

),

product_lines as (

    select * from {{ ref('stg_acx_product_lines') }}

),

int_coil_production as (
    select
        -- coil identifiers
        coils.coil_id,
        coils.coil_serial,
        coils.order_id,
        coils.production_date,
        coils.line_id,
        coils.shift,

        -- physical properties
        coils.thickness_mm,
        coils.width_mm,
        coils.actual_weight_kg,
        coils.target_weight_kg,
        coils.weight_deviation_kg,
        coils.weight_deviation_pct,
        coils.surface_finish,

        -- mechanical properties
        coils.tensile_strength_mpa,
        coils.yield_strength_mpa,
        coils.elongation_pct,
        coils.hardness_hv,
        coils.status_id,

        -- plant context
        plants.plant_id,
        plants.plant_name,
        plants.location       as plant_location,
        plants.country        as plant_country,
        plants.capacity_tons_per_year,

        -- grade context
        grades.grade_id,
        grades.grade_ref,
        grades.grade_name,
        grades.grade_family,
        grades.typical_application,
        -- midpoint alloy composition (useful for clustering / profiling)
        round((grades.nickel_pct_min + grades.nickel_pct_max) / 2, 2)     as grade_nickel_midpoint,
        round((grades.chromium_pct_min + grades.chromium_pct_max) / 2, 2) as grade_chromium_midpoint,

        -- product line context
        product_lines.product_line_id,
        product_lines.product_line_name,
        product_lines.target_market,

        -- production order context
        orders.campaign_id,
        orders.order_date,
        orders.planned_start_date,
        orders.actual_start_date,
        orders.planned_end_date,
        orders.actual_end_date,
        orders.target_tons     as order_target_tons,
        orders.produced_tons   as order_produced_tons,
        orders.yield_pct       as order_yield_pct,
        orders.start_delay_days,
        orders.end_delay_days,
        -- flag: did the order finish after its planned end date?
        case when orders.end_delay_days > 0 then true else false end       as order_delay_flag,
        -- days from actual start to actual end
        datediff('day', orders.actual_start_date, orders.actual_end_date)  as days_in_production

    from coils
    left join orders
        on coils.order_id = orders.order_id
    left join plants
        on coils.plant_id = plants.plant_id
    left join grades
        on coils.grade_id = grades.grade_id
    left join product_lines
        on orders.product_line_id = product_lines.product_line_id
)

select * from int_coil_production
