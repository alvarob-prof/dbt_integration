-- int_plant_order_metrics.sql
-- Aggregates production order KPIs at the plant level.
-- One row per plant + campaign combination.

with orders as (

    select * from {{ ref('stg_acx_production_orders') }}

),

plants as (

    select * from {{ ref('stg_acx_plants') }}

),

plant_order_metrics as (
    select
        orders.plant_id,
        plants.plant_name,
        plants.country        as plant_country,
        plants.capacity_tons_per_year,
        orders.campaign_id,

        count(orders.order_id)                                              as total_orders,
        sum(orders.target_tons)                                             as total_target_tons,
        sum(orders.produced_tons)                                           as total_produced_tons,
        round(sum(orders.produced_tons) / nullif(sum(orders.target_tons), 0) * 100, 2)
                                                                            as overall_yield_pct,
        round(avg(orders.yield_pct), 2)                                     as avg_order_yield_pct,

        -- Schedule performance
        sum(case when orders.end_delay_days > 0 then 1 else 0 end)         as late_orders,
        sum(case when orders.end_delay_days <= 0 then 1 else 0 end)        as on_time_orders,
        round(
            sum(case when orders.end_delay_days <= 0 then 1 else 0 end)
            / nullif(count(orders.order_id), 0) * 100,
            2
        )                                                                   as on_time_rate_pct,
        round(avg(orders.end_delay_days), 1)                               as avg_end_delay_days,
        round(avg(orders.start_delay_days), 1)                             as avg_start_delay_days
    from orders
    left join plants
        on orders.plant_id = plants.plant_id
    group by 1, 2, 3, 4, 5
)

select * from plant_order_metrics
