# ASD Pipeline Cleanup Notes - 2026-06-01

## Purpose

This note documents the cleanup performed after the Patient Zoya ASD GSA and
calibration scripts were expanded beyond the original Group-A-only workflow.
The goal was to improve reproducibility, align the code with the written
methodology, and prevent a fragile MATLAB parallel pool from aborting GSA runs.

No model equations were changed.

## 1. GSA Parallel-Pool Failure Handling

**Problem:** MATLAB reported that the parallel pool using the `Processes`
profile shut down because the client lost connection to worker 14. A worker
loss can abort a long GSA even when the model itself is numerically valid.

**Change:** The active curated runner,
`scripts/run_zoya_asd_gsa_curated.m`, defaults to serial execution. Parallel
execution is opt-in only with:

```matlab
setenv('ASD_GSA_USE_PARALLEL','1')
```

If parallel execution is requested and a worker/pool failure occurs, the
affected Saltelli matrix is re-run serially instead of aborting the whole GSA.

**Reason:** GSA is a reproducibility step. It is better to finish more slowly
in serial mode than to lose a multi-hour run because one worker disconnects.

## 2. Curated GSA Runner Name Clarified

**Problem:** `run_zoya_asd_gsa_groupA.m` originally meant Group-A-only GSA, but
the current implementation samples Groups A+B+C.

**Change:** The active runner is now `scripts/run_zoya_asd_gsa_curated.m`.
The old `scripts/run_zoya_asd_gsa_groupA.m` file is kept only as a
compatibility wrapper. Current outputs are `zoya_asd_gsa_curated_*`.

**Reason:** Existing commands keep working, but future readers will not mistake
the current curated ASD GSA for the earlier Group-A-only run.

## 3. Calibration Active Set Derived From GSA and Target Tiers

**Problem:** The calibration runner previously depended on an older hardcoded
active set:

- Stage A: `V0.SVEN`, `C.PAR`, `C.SVEN`, `R.SC`, `asd.Cd`
- Stage C/ventricular extension: `E.RV.EB`, `E.LV.EB`

That made the implementation less traceable to the current curated GSA result.

**Change:** `scripts/run_zoya_asd_calibration.m` now reads the latest curated
GSA `.mat`, builds target tiers from `build_asd_target_tiers.m`, and creates
the active mask with `build_asd_active_mask_from_gsa.m`.

**Reason:** This keeps the thesis narrative defensible: parameters are selected
from Sobol total-order sensitivity (`ST`) against the ASD primary and measured
secondary target tiers, with an active-set cap for identifiability.

## 4. Stage C Is Conditional

**Problem:** Ventricular Group C parameters can improve numerical fit while
remaining poorly identifiable because Patient Zoya has no pre-closure LV/RV
volume or EF targets.

**Change:** Group C remains monitor-only by default. It can only enter the
calibration mask if `ASD_CALIB_ALLOW_GROUPC=1` is explicitly set and the
GSA/target-tier mask selects it.

**Reason:** This implements the staged parsimony rule: do not add ventricular
degrees of freedom unless the user explicitly approves it after reviewing
Group A/B limitations.

## 5. ASD Direction and LA-RA Gradient Field Names Fixed

**Problem:** Some validation/output code expected fields named `P_LA`, `P_RA`,
and `Q_ASD`, but `reconstruct_hemodynamic_signals.m` returns `P.LA`, `P.RA`,
and `Q.ASD`.

**Change:** `run_zoya_asd_calibration.m` and `src/utils/asd_output_table.m` now
use the actual reconstructed signal field names.

**Reason:** This allows the ASD direction and LA-RA pressure-gradient checks to
use the intended time-series data instead of falling back silently to mean-flow
logic.

## 6. Output Table Direction Readability Improved

**Problem:** `ASD_direction` appeared as `NaN` in CSV output because the numeric
`Value` column could not store text.

**Change:** `asd_output_table.m` now adds `Qualitative_Value`, with
`ASD_direction` reported as `L->R`, `R->L`, or `balanced`.

**Reason:** Direction is qualitative, not numeric. The workbook/CSV should show
it explicitly so the ASD shunt mechanism can be interpreted without reading the
description text.

## 7. Objective and RMSE Reporting Separated

**Problem:** Calibration logs printed lines such as `J: 0.4515 -> 416`, mixing
baseline RMSE with objective-function value.

**Change:** The calibration runner now labels optimizer output as
`Objective J_A` or `Objective J_C`, while RMSE remains reported separately.

**Reason:** The objective includes normalized target error, plausibility
penalties, boundary penalties, and validity penalties. It is not the same unit
as RMSE and should not be interpreted as a direct before/after RMSE comparison.

## Verification To Run

Use the lightweight syntax/objective smoke test first:

```matlab
cd('C:\Users\Diniya\skripsiASDPreOp');
addpath(genpath(pwd));
test_calib_syntax
```

For GSA smoke testing without parallel workers:

```matlab
setenv('ASD_GSA_FULL_N','4');
setenv('ASD_GSA_NCYCLES','40');
setenv('ASD_GSA_USE_PARALLEL','0');
run('scripts/run_zoya_asd_gsa_curated.m');
```

For a full GSA, clear `ASD_GSA_FULL_N` and keep serial mode unless the local
parallel pool is stable.
