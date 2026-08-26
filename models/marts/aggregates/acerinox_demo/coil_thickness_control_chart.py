import pandas as pd
import numpy as np


def model(dbt, session):
    """
    Statistical Process Control (SPC) — X-bar / σ control chart for coil
    thickness deviation, computed per steel grade.

    Why Python?
    -----------
    SPC requires computing rolling statistics (mean ± k·std) that are
    significantly more natural in pandas than in SQL window functions.
    The model also flags individual coil violations and outputs the control
    limits alongside the raw measurements so a BI tool can overlay both
    in one query.

    Output: one row per coil, with its grade-level control limits and a
    flag indicating whether it breaches the ±3σ (UCL/LCL) boundary.
    """
    dbt.config(
        packages=["pandas", "numpy", "pyarrow"],
        materialized="table",
    )

    # ── 1. Pull upstream data ──────────────────────────────────────────────
    fct = dbt.ref("int_fct_coil_quality").to_pandas()

    # Snowflake returns column names in uppercase
    fct.columns = fct.columns.str.upper()

    # ── 2. Compute per-grade SPC parameters ───────────────────────────────
    # Use absolute thickness deviation as the process variable.
    # A real SPC chart would use the actual measured value; here we use the
    # deviation because the target thickness differs by grade/order.
    process_var = "AVG_THICKNESS_DEVIATION_MM"

    grade_stats = (
        fct
        .dropna(subset=[process_var, "GRADE_REF"])
        .groupby("GRADE_REF")[process_var]
        .agg(
            process_mean="mean",
            process_std="std",
            n="count",
        )
        .reset_index()
    )
    grade_stats["UCL_3SIGMA"] = (
        grade_stats["process_mean"] + 3 * grade_stats["process_std"]
    )
    grade_stats["LCL_3SIGMA"] = (
        grade_stats["process_mean"] - 3 * grade_stats["process_std"]
    ).clip(lower=0)   # deviation cannot be negative
    grade_stats["UCL_2SIGMA"] = (
        grade_stats["process_mean"] + 2 * grade_stats["process_std"]
    )
    grade_stats["LCL_2SIGMA"] = (
        grade_stats["process_mean"] - 2 * grade_stats["process_std"]
    ).clip(lower=0)

    # ── 3. Join control limits back to each coil ──────────────────────────
    chart = fct.merge(
        grade_stats[[
            "GRADE_REF",
            "process_mean", "process_std",
            "UCL_3SIGMA", "LCL_3SIGMA",
            "UCL_2SIGMA", "LCL_2SIGMA",
            "n",
        ]],
        on="GRADE_REF",
        how="left",
    )

    # ── 4. Classify each coil's control status ────────────────────────────
    def classify_control(row):
        val = row[process_var]
        if pd.isna(val):
            return "NO_DATA"
        if val > row["UCL_3SIGMA"] or val < row["LCL_3SIGMA"]:
            return "OUT_OF_CONTROL"      # beyond ±3σ — process signal
        if val > row["UCL_2SIGMA"] or val < row["LCL_2SIGMA"]:
            return "WARNING"             # between 2σ and 3σ — watch zone
        return "IN_CONTROL"

    chart["SPC_STATUS"] = chart.apply(classify_control, axis=1)
    chart["SPC_VIOLATION_FLAG"] = chart["SPC_STATUS"] == "OUT_OF_CONTROL"

    # ── 5. Select and rename output columns ───────────────────────────────
    output = chart[[
        "COIL_ID",
        "COIL_SERIAL",
        "PRODUCTION_DATE",
        "PLANT_NAME",
        "GRADE_REF",
        "GRADE_FAMILY",
        "THICKNESS_MM",
        process_var,
        "process_mean",
        "process_std",
        "UCL_3SIGMA",
        "LCL_3SIGMA",
        "UCL_2SIGMA",
        "LCL_2SIGMA",
        "n",
        "SPC_STATUS",
        "SPC_VIOLATION_FLAG",
        "ANY_NONCONFORMANCE",
        "FINAL_INSPECTION_PASSED",
    ]].rename(columns={
        "process_mean": "GRADE_PROCESS_MEAN_MM",
        "process_std":  "GRADE_PROCESS_STD_MM",
        "n":            "GRADE_SAMPLE_SIZE",
    })

    output.columns = output.columns.str.upper()
    return output.sort_values(["GRADE_REF", "PRODUCTION_DATE"]).reset_index(drop=True)
