with

source as (

    select * from {{ source('acerinox_demo', 'plants') }}

),

renamed as (
    select
        plantid       as plant_id,
        plantref      as plant_ref,
        name          as plant_name,
        location,
        country,
        lat           as latitude,
        lng           as longitude,
        capacity_tons_per_year,
        founded_year,
        planned_maintenance_window
        -- omit internal metadata columns if present
    from source
)

select * from renamed