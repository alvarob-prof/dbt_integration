with

source as (

    select * from {{ source('acerinox_demo', 'coil_status') }}

),

renamed as (
    select
        statusid            as status_id,
        status,
        status_category,
        description         as status_description
    from source
)

select * from renamed
