with

source as (

    select * from {{ source('acerinox_demo', 'steel_grades') }}

),

renamed as (
    select
        gradeid                as grade_id,
        graderef               as grade_ref,
        grade_name,
        family                 as grade_family,
        nickel_pct_min,
        nickel_pct_max,
        chromium_pct_min,
        chromium_pct_max,
        molybdenum_pct_min,
        molybdenum_pct_max,
        typical_application
    from source
)

select * from renamed
