-- int_quality_summary.sql
-- Aggregates quality inspection records to one row per coil,
-- resolving the potential M:1 relationship between inspections and coils.

with inspections as (

    select * from {{ ref('stg_acx_quality_inspections') }}

),

aggregated as (
    select
        coil_id,
        order_id,
        plant_id,
        count(*)                                                as inspection_count,
        -- overall pass/fail: a coil passes only if ALL inspections passed
        min(passed::int)                                        as all_inspections_passed,
        -- non-conformance: any single NC flag is enough to flag the coil
        max(nonconformance_flag::int)                           as any_nonconformance,
        -- surface quality: take the worst rating seen (A > B > C)
        min(surface_rating)                                     as worst_surface_rating,
        -- thickness deviation: average across all inspection events
        round(avg(thickness_deviation_mm), 4)                   as avg_thickness_deviation_mm,
        round(max(thickness_deviation_mm), 4)                   as max_thickness_deviation_mm,
        -- flag: at least one measurement was outside tolerance
        max(thickness_out_of_tolerance::int)                    as any_thickness_out_of_tolerance,
        -- most recent inspection metadata
        max(inspection_date)                                    as last_inspection_date,
        max_by(inspector_id, inspection_date)                   as last_inspector_id,
        max_by(surface_rating, inspection_date)                 as final_surface_rating,
        max_by(passed, inspection_date)                         as final_inspection_passed,
        max_by(inspection_notes, inspection_date)               as final_inspection_notes
    from inspections
    group by 1, 2, 3
),

quality_summary as (
    select
        aggregated.*
    from aggregated
    -- status_id lives on coil_outputs, not on inspections.
    -- The join to coil_status happens downstream in int_fct_coil_quality.
)

select * from quality_summary
