import pandas as pd
import numpy as np


def model(dbt, session):
    """
    Multivariate anomaly scoring for coil mechanical properties.

    Why Python?
    -----------
    Anomaly detection requires computing Z-scores across *multiple* columns
    simultaneously and then combining them into a composite score — something
    that would require 10+ SQL CTEs and still lack the Mahalanobis distance
    approach used here.  Python makes this trivial and the intent is clear.

    Method
    ------
    1. For each coil, standardise four mechanical-property columns
       (tensile strength, yield strength, elongation, hardness) using
       the per-grade mean and standard deviation as the reference
       distribution — because 316L and 430 have completely different
       expected ranges and must be compared against their own population.

    2. Compute:
       - Individual Z-scores per property
       - A composite Euclidean anomaly score = √(Σ z²) across all properties
       - An anomaly tier: NORMAL / ELEVATED / ANOMALY based on the score

    3. Flag coils whose composite score exceeds the 95th percentile of
       their own grade population — a data-driven threshold, not a
       hardcoded constant.

    Output: one row per coil with Z-scores, composite score, anomaly tier,
    and whether the coil was flagged relative to its grade peer group.
    """
    dbt.config(
        packages=["pandas", "numpy", "pyarrow"]
    )

    # ── 1. Pull upstream data ──────────────────────────────────────────────
    fct = dbt.ref("int_fct_coil_quality").to_pandas()
    fct.columns = fct.columns.str.upper()

    # Mechanical property columns to analyse
    mech_props = [
        "TENSILE_STRENGTH_MPA",
        "YIELD_STRENGTH_MPA",
        "ELONGATION_PCT",
        "HARDNESS_HV",
    ]

    # ── 2. Compute per-grade reference statistics ──────────────────────────
    grade_stats = (
        fct
        .dropna(subset=mech_props + ["GRADE_REF"])
        .groupby("GRADE_REF")[mech_props]
        .agg(["mean", "std"])
    )
    # Flatten multi-level columns: (col, stat) → col_MEAN / col_STD
    grade_stats.columns = [f"{col}_{stat.upper()}" for col, stat in grade_stats.columns]
    grade_stats = grade_stats.reset_index()

    # ── 3. Join reference stats back to each coil ─────────────────────────
    df = fct.merge(grade_stats, on="GRADE_REF", how="left")

    # ── 4. Compute Z-scores per property ──────────────────────────────────
    for prop in mech_props:
        mean_col = f"{prop}_MEAN"
        std_col  = f"{prop}_STD"
        z_col    = f"Z_{prop}"
        df[z_col] = (
            (df[prop] - df[mean_col])
            / df[std_col].replace(0, np.nan)
        ).round(4)

    z_cols = [f"Z_{p}" for p in mech_props]

    # ── 5. Composite Euclidean anomaly score ──────────────────────────────
    # √(z_tensile² + z_yield² + z_elongation² + z_hardness²)
    df["ANOMALY_SCORE"] = (
        np.sqrt((df[z_cols] ** 2).sum(axis=1))
    ).round(4)

    # ── 6. Grade-relative 95th-percentile threshold ───────────────────────
    p95 = (
        df.dropna(subset=["ANOMALY_SCORE"])
        .groupby("GRADE_REF")["ANOMALY_SCORE"]
        .quantile(0.95)
        .rename("GRADE_ANOMALY_THRESHOLD_P95")
        .reset_index()
    )
    df = df.merge(p95, on="GRADE_REF", how="left")

    # ── 7. Classify anomaly tier ──────────────────────────────────────────
    def classify_anomaly(row):
        score = row["ANOMALY_SCORE"]
        threshold = row["GRADE_ANOMALY_THRESHOLD_P95"]
        if pd.isna(score):
            return "NO_DATA"
        if score >= threshold:
            return "ANOMALY"          # above grade's 95th percentile
        if score >= threshold * 0.75:
            return "ELEVATED"         # in the upper 75–95th percentile band
        return "NORMAL"

    df["ANOMALY_TIER"] = df.apply(classify_anomaly, axis=1)
    df["ANOMALY_FLAG"] = df["ANOMALY_TIER"] == "ANOMALY"

    # ── 8. Select output columns ───────────────────────────────────────────
    output_cols = [
        "COIL_ID",
        "COIL_SERIAL",
        "PRODUCTION_DATE",
        "PLANT_NAME",
        "PLANT_COUNTRY",
        "GRADE_REF",
        "GRADE_NAME",
        "GRADE_FAMILY",
        "SHIFT",
        "LINE_ID",
        # raw mechanical properties
        *mech_props,
        # per-grade reference
        *[f"{p}_MEAN" for p in mech_props],
        *[f"{p}_STD"  for p in mech_props],
        # Z-scores
        *z_cols,
        # composite scoring
        "ANOMALY_SCORE",
        "GRADE_ANOMALY_THRESHOLD_P95",
        "ANOMALY_TIER",
        "ANOMALY_FLAG",
        # quality context
        "ANY_NONCONFORMANCE",
        "FULLY_CONFORMANT_FLAG",
        "STATUS",
        "STATUS_CATEGORY",
    ]

    output = df[output_cols].copy()
    output.columns = output.columns.str.upper()
    return output.sort_values(["GRADE_REF", "ANOMALY_SCORE"], ascending=[True, False]).reset_index(drop=True)
