# Acerinox Intermediate Layer — Model Documentation

{% docs int_coil_production %}
This model enriches raw coil output records with full contextual information:
plant details, steel grade composition, product line classification, and
production order schedule metrics. The goal is to produce a single wide,
human-readable record per coil that downstream marts and BI tools can
consume directly without further joins.

Key derivations:
- `order_delay_flag`: whether the production order ended late
- `days_in_production`: calendar days from order start to actual end
- `grade_nickel_midpoint` / `grade_chromium_midpoint`: midpoint of the
  alloy composition range, useful for chemical profiling analytics
{% enddocs %}


{% docs int_quality_summary %}
Aggregates quality inspection outcomes at the coil level. Because a coil
may in principle receive multiple inspection passes (e.g. in-process +
final), this intermediate resolves the M:1 relationship and exposes only
the final rolled-up quality verdict per coil.

Key derivations:
- `any_nonconformance`: true if any single inspection raised a non-conformance
- `inspection_count`: total inspections logged for the coil
- `final_surface_rating`: surface rating from the most recent inspection
{% enddocs %}


{% docs int_plant_order_metrics %}
Aggregates production order data at the plant level for a given time period.
Resolves the relationship between plants and their orders so that downstream
plant-performance reports can compute KPIs without fanning out rows.

Key derivations:
- `total_orders`: number of orders executed in the period
- `avg_yield_pct`: average tonnage yield across all orders
- `late_orders`: count of orders that finished after their planned end date
- `on_time_rate_pct`: percentage of orders completed on time
{% enddocs %}


{% docs int_grade_quality_metrics %}
Joins quality inspection outcomes back to steel grade metadata to surface
per-grade quality KPIs. Useful for understanding which alloy families
have higher non-conformance rates or dimensional deviation trends.

Key derivations:
- `nonconformance_rate_pct`: share of coils with at least one non-conformance
- `avg_thickness_deviation_mm`: mean absolute thickness deviation from nominal
- `pass_rate_pct`: share of inspection events that passed
{% enddocs %}


{% docs int_fct_coil_quality %}
The main fact model for the intermediate layer. Combines enriched coil
production data (`int_coil_production`) with the rolled-up quality summary
(`int_quality_summary`) to produce one row per coil with full production
context and quality verdict side by side.

This is the recommended starting point for building mart models around
production quality, plant performance, and grade analysis.
{% enddocs %}
