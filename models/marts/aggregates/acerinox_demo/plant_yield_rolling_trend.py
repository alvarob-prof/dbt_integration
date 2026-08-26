import pandas as pd
import numpy as np


def model(dbt, session):
    """
    Rolling production yield trend per plant, aggregated by month.

    Why Python?
    -----------
    Rolling windows that span a variable number of time-bucketed rows are
    awkward in SQL — you need RANGE BETWEEN clauses tied to date arithmetic.
    pandas .rolling() with a time-aware DatetimeIndex handles this in two
    lines and makes the intent immediately obvious.

    The model also computes:
    - month-over-month yield delta
    - a 3-month centred rolling average (requires look-ahead, unavailable
      in SQL without a self-join)
    - a simple linear trend slope over the full available window, so a
      single number can answer "is this plant's yield improving?"

    Output: one row per plant × calendar month with raw and smoothed yield.
    """
    dbt.config(
        packages=["pandas", "numpy", "pyarrow", "scipy"]
    )

    # ── 1. Pull upstream data ──────────────────────────────────────────────
    orders = dbt.ref("int_plant_order_metrics").to_pandas()
    orders.columns = orders.columns.str.upper()

    coils = dbt.ref("int_coil_production").to_pandas()
    coils.columns = coils.columns.str.upper()

    # ── 2. Build monthly coil-level yield grain ────────────────────────────
    # Coil weight deviation as a proxy for yield precision
    coils["PRODUCTION_MONTH"] = pd.to_datetime(coils["PRODUCTION_DATE"]).dt.to_period("M").dt.to_timestamp()

    monthly_coils = (
        coils
        .groupby(["PLANT_NAME", "PLANT_COUNTRY", "PRODUCTION_MONTH"])
        .agg(
            coils_produced=("COIL_ID", "count"),
            total_actual_kg=("ACTUAL_WEIGHT_KG", "sum"),
            total_target_kg=("TARGET_WEIGHT_KG", "sum"),
            avg_weight_dev_pct=("WEIGHT_DEVIATION_PCT", "mean"),
            avg_tensile_mpa=("TENSILE_STRENGTH_MPA", "mean"),
        )
        .reset_index()
    )

    monthly_coils["MONTHLY_WEIGHT_YIELD_PCT"] = (
        monthly_coils["total_actual_kg"]
        / monthly_coils["total_target_kg"].replace(0, np.nan)
        * 100
    ).round(3)

    # ── 3. Compute rolling statistics per plant ────────────────────────────
    results = []

    for plant, grp in monthly_coils.groupby("PLANT_NAME"):
        grp = grp.sort_values("PRODUCTION_MONTH").copy()
        grp = grp.set_index("PRODUCTION_MONTH")

        n = len(grp)
        yield_col = grp["MONTHLY_WEIGHT_YIELD_PCT"]

        # 3-month trailing rolling average (min 1 period so first row isn't NaN)
        grp["YIELD_ROLLING_3M_AVG"] = (
            yield_col.rolling(window=3, min_periods=1).mean().round(3)
        )

        # 3-month centred rolling average (requires min 1 so edges are filled)
        grp["YIELD_ROLLING_3M_CENTRED"] = (
            yield_col.rolling(window=3, min_periods=1, center=True).mean().round(3)
        )

        # Month-over-month delta
        grp["YIELD_MOM_DELTA_PCT"] = yield_col.diff().round(3)

        # Linear trend slope (yield units per month) over the full window
        # scipy linregress gives us p-value and r² too
        if n >= 3:
            from scipy import stats as scipy_stats
            x = np.arange(n)
            slope, intercept, r_value, p_value, _ = scipy_stats.linregress(
                x, yield_col.fillna(method="ffill")
            )
            grp["TREND_SLOPE_PER_MONTH"] = round(slope, 4)
            grp["TREND_R2"] = round(r_value ** 2, 4)
            grp["TREND_P_VALUE"] = round(p_value, 4)
            grp["TREND_DIRECTION"] = (
                "IMPROVING" if slope > 0.05
                else "DECLINING" if slope < -0.05
                else "STABLE"
            )
        else:
            grp["TREND_SLOPE_PER_MONTH"] = np.nan
            grp["TREND_R2"] = np.nan
            grp["TREND_P_VALUE"] = np.nan
            grp["TREND_DIRECTION"] = "INSUFFICIENT_DATA"

        grp = grp.reset_index()
        results.append(grp)

    # ── 4. Assemble final output ───────────────────────────────────────────
    output = pd.concat(results, ignore_index=True)

    output = output.rename(columns={
        "coils_produced":       "COILS_PRODUCED",
        "total_actual_kg":      "TOTAL_ACTUAL_KG",
        "total_target_kg":      "TOTAL_TARGET_KG",
        "avg_weight_dev_pct":   "AVG_WEIGHT_DEV_PCT",
        "avg_tensile_mpa":      "AVG_TENSILE_MPA",
    })

    output.columns = output.columns.str.upper()

    keep = [
        "PLANT_NAME", "PLANT_COUNTRY", "PRODUCTION_MONTH",
        "COILS_PRODUCED", "TOTAL_ACTUAL_KG", "TOTAL_TARGET_KG",
        "MONTHLY_WEIGHT_YIELD_PCT",
        "YIELD_ROLLING_3M_AVG",
        "YIELD_ROLLING_3M_CENTRED",
        "YIELD_MOM_DELTA_PCT",
        "AVG_WEIGHT_DEV_PCT",
        "AVG_TENSILE_MPA",
        "TREND_SLOPE_PER_MONTH",
        "TREND_R2",
        "TREND_P_VALUE",
        "TREND_DIRECTION",
    ]
    return output[keep].sort_values(["PLANT_NAME", "PRODUCTION_MONTH"]).reset_index(drop=True)
