with

source as (

    select * from {{ source('acerinox_demo', 'production_orders') }}

),

renamed as (
    select
        orderid             as order_id,
        plantid             as plant_id,
        gradeid             as grade_id,
        productlineid       as product_line_id,
        order_date,
        planned_start_date,
        actual_start_date,
        planned_end_date,
        actual_end_date,
        target_tons,
        produced_tons,
        order_status,
        campaign_id,
        -- derived: schedule delay in days (positive = late)
        datediff('day', planned_start_date, actual_start_date) as start_delay_days,
        datediff('day', planned_end_date, actual_end_date)     as end_delay_days,
        -- derived: production yield vs target
        round(produced_tons / nullif(target_tons, 0) * 100, 2) as yield_pct
    from source
)

select * from renamed
