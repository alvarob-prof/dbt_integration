with

source as (

    select * from {{ source('acerinox_demo', 'coil_outputs') }}

),

renamed as (
    select
        coilid              as coil_id,
        orderid             as order_id,
        gradeid             as grade_id,
        plantid             as plant_id,
        coil_serial,
        thickness_mm,
        width_mm,
        actual_weight_kg,
        target_weight_kg,
        surface_finish,
        production_date,
        line_id,
        shift,
        tensile_strength_mpa,
        yield_strength_mpa,
        elongation_pct,
        hardness_hv,
        statusid            as status_id,
        -- derived: weight deviation from target
        actual_weight_kg - target_weight_kg as weight_deviation_kg,
        round((actual_weight_kg - target_weight_kg) / nullif(target_weight_kg, 0) * 100, 3) as weight_deviation_pct
    from source
)

select * from renamed
