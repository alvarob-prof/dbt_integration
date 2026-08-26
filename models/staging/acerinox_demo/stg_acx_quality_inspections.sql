with

source as (

    select * from {{ source('acerinox_demo', 'quality_inspections') }}

),

renamed as (
    select
        inspectionid                            as inspection_id,
        coilid                                  as coil_id,
        orderid                                 as order_id,
        plantid                                 as plant_id,
        inspection_date,
        inspector_id,
        inspection_type,
        thickness_actual_mm,
        thickness_tolerance_mm,
        width_actual_mm,
        width_tolerance_mm,
        weight_actual_kg,
        surface_rating,
        passed::boolean                         as passed,
        nonconformance_flag::boolean            as nonconformance_flag,
        inspection_notes,
        -- derived: absolute thickness deviation
        abs(thickness_actual_mm - thickness_tolerance_mm) as thickness_deviation_mm,
        -- derived: flag if thickness is out of tolerance (> tolerance band)
        case
            when abs(thickness_actual_mm - thickness_tolerance_mm) > thickness_tolerance_mm
            then true
            else false
        end                                     as thickness_out_of_tolerance
    from source
)

select * from renamed
