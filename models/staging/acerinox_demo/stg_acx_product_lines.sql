with

source as (

    select * from {{ source('acerinox_demo', 'product_lines') }}

),

renamed as (
    select
        productlineid   as product_line_id,
        productlineref  as product_line_ref,
        name            as product_line_name,
        description     as product_line_description,
        target_market,
        is_active
    from source
)

select * from renamed
