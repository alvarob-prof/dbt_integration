-- int_grade_quality_metrics.sql
-- Aggregates quality inspection outcomes by steel grade.
-- Useful for understanding which alloy grades have higher
-- defect rates or dimensional deviation trends.

with inspections as (

    select * from {{ ref('stg_acx_quality_inspections') }}

),

coils as (

    select * from {{ ref('stg_acx_coil_outputs') }}

),

grades as (

    select * from {{ ref('stg_acx_steel_grades') }}

),

coil_inspections as (
    select
        inspections.*,
        coils.grade_id
    from inspections
    left join coils
        on inspections.coil_id = coils.coil_id
),

grade_quality_metrics as (
    select
        coil_inspections.grade_id,
        grades.grade_ref,
        grades.grade_name,
        grades.grade_family,
        grades.typical_application,

        count(distinct coil_inspections.coil_id)                            as total_coils_inspected,
        count(*)                                                             as total_inspection_events,
        sum(coil_inspections.passed::int)                                    as passed_inspections,
        sum(coil_inspections.nonconformance_flag::int)                       as total_nonconformances,

        -- Pass rate across all inspection events for this grade
        round(
            sum(coil_inspections.passed::int)
            / nullif(count(*), 0) * 100,
            2
        )                                                                    as pass_rate_pct,

        -- Non-conformance rate at coil level
        round(
            count(distinct case when coil_inspections.nonconformance_flag then coil_inspections.coil_id end)
            / nullif(count(distinct coil_inspections.coil_id), 0) * 100,
            2
        )                                                                    as nonconformance_rate_pct,

        -- Dimensional quality
        round(avg(coil_inspections.thickness_deviation_mm), 4)              as avg_thickness_deviation_mm,
        round(max(coil_inspections.thickness_deviation_mm), 4)              as max_thickness_deviation_mm,

        -- Surface quality distribution
        sum(case when coil_inspections.surface_rating = 'A' then 1 else 0 end) as surface_a_count,
        sum(case when coil_inspections.surface_rating = 'B' then 1 else 0 end) as surface_b_count,
        sum(case when coil_inspections.surface_rating = 'C' then 1 else 0 end) as surface_c_count
    from coil_inspections
    left join grades
        on coil_inspections.grade_id = grades.grade_id
    group by 1, 2, 3, 4, 5
)

select * from grade_quality_metrics