-- int_fct_coil_quality.sql
-- Main intermediate fact model: one row per coil with full
-- production context AND quality verdict combined.
-- This is the primary input for all mart-level analytics.

with int_coil_production as (

    select * from {{ ref('int_coil_production') }}

),

int_quality_summary as (

    select * from {{ ref('int_quality_summary') }}

),

coil_status as (

    select * from {{ ref('stg_acx_coil_status') }}

),

fct_coil_quality as (
    select
        -- ── Coil identifiers ───────────────────────────────────
        int_coil_production.coil_id,
        int_coil_production.coil_serial,
        int_coil_production.order_id,
        int_coil_production.campaign_id,
        int_coil_production.production_date,
        int_coil_production.line_id,
        int_coil_production.shift,

        -- ── Plant ──────────────────────────────────────────────
        int_coil_production.plant_id,
        int_coil_production.plant_name,
        int_coil_production.plant_location,
        int_coil_production.plant_country,
        int_coil_production.capacity_tons_per_year,

        -- ── Steel grade ────────────────────────────────────────
        int_coil_production.grade_id,
        int_coil_production.grade_ref,
        int_coil_production.grade_name,
        int_coil_production.grade_family,
        int_coil_production.typical_application,
        int_coil_production.grade_nickel_midpoint,
        int_coil_production.grade_chromium_midpoint,

        -- ── Product line ───────────────────────────────────────
        int_coil_production.product_line_id,
        int_coil_production.product_line_name,
        int_coil_production.target_market,

        -- ── Physical properties ────────────────────────────────
        int_coil_production.thickness_mm,
        int_coil_production.width_mm,
        int_coil_production.actual_weight_kg,
        int_coil_production.target_weight_kg,
        int_coil_production.weight_deviation_kg,
        int_coil_production.weight_deviation_pct,
        int_coil_production.surface_finish,

        -- ── Mechanical properties ──────────────────────────────
        int_coil_production.tensile_strength_mpa,
        int_coil_production.yield_strength_mpa,
        int_coil_production.elongation_pct,
        int_coil_production.hardness_hv,

        -- ── Production order schedule ──────────────────────────
        int_coil_production.order_date,
        int_coil_production.planned_start_date,
        int_coil_production.actual_start_date,
        int_coil_production.planned_end_date,
        int_coil_production.actual_end_date,
        int_coil_production.order_target_tons,
        int_coil_production.order_produced_tons,
        int_coil_production.order_yield_pct,
        int_coil_production.start_delay_days,
        int_coil_production.end_delay_days,
        int_coil_production.order_delay_flag,
        int_coil_production.days_in_production,

        -- ── Quality outcomes ───────────────────────────────────
        int_quality_summary.inspection_count,
        int_quality_summary.all_inspections_passed,
        int_quality_summary.any_nonconformance,
        int_quality_summary.avg_thickness_deviation_mm,
        int_quality_summary.max_thickness_deviation_mm,
        int_quality_summary.any_thickness_out_of_tolerance,
        int_quality_summary.worst_surface_rating,
        int_quality_summary.final_surface_rating,
        int_quality_summary.final_inspection_passed,
        int_quality_summary.last_inspection_date,
        int_quality_summary.last_inspector_id,
        int_quality_summary.final_inspection_notes,

        -- ── Coil status (from lookup) ──────────────────────────
        int_coil_production.status_id,
        coil_status.status,
        coil_status.status_category,
        coil_status.status_description,

        -- ── Composite quality flag ─────────────────────────────
        -- A coil is fully conformant only when it passed all inspections,
        -- had no non-conformances, and was released or shipped.
        case
            when int_quality_summary.all_inspections_passed = 1
             and int_quality_summary.any_nonconformance = 0
             and coil_status.status_category = 'OK'
            then true
            else false
        end as fully_conformant_flag

    from int_coil_production
    left join int_quality_summary
        on int_coil_production.coil_id = int_quality_summary.coil_id
    left join coil_status
        on int_coil_production.status_id = coil_status.status_id
)

select * from fct_coil_quality