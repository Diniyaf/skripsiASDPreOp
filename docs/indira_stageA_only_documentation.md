# Indira — Stage A Only Calibration (Group C OFF)

**Date:** 2026-06-04  
**Run folder:** `results/calibration/indira_asd_calib_20260604_053629`  
**Config:** Group C OFF, 5 params, waveform = soft warning

---

## 1. Configuration

| Setting | Value |
|---|---|
| Active parameters | R.asd, R.SC, R.PCOX, V0.SVEN, C.SVEN (5) |
| Clinical fit gate | Primary: hard reject | Secondary waveform: soft warning |
| Group C | OFF |

## 2. Results

| Metric | Target | Baseline | Stage A | Error |
|---|---|---|---|---|
| Qs_Lmin | 3.22 | 3.78 | 3.99 | 23.9% |
| Qp_Lmin | 7.54 | 5.81 | 6.17 | 18.1% |
| SAP_mean | 75 | 86.9 | 72.7 | 3.0% |
| PAP_mean | 25 | 20.0 | 20.9 | 16.5% |
| LAP_mean | 8 | 6.89 | 6.79 | 15.1% |
| RAP_mean | 6 | 5.95 | 6.39 | 6.5% |
| QpQs | 2.34 | 1.54 | 1.55 | 33.9% |
| **RMSE** | — | **0.2021** | **0.1926** | **4.7% improvement** |

## 3. Rejection Reason

```
Qs_Lmin: baseline 17.4% → Stage A 23.9% (worsening +6.5%)
→ PRIMARY metric rejection
```

## 4. Parameter Changes

| Parameter | Initial | Stage A | Bound | Flag |
|---|---|---|---|---|
| R.asd | 0.0278 | 0.0112 | [0.011, 0.069] | ⚠ WARNING (lower bound) |
| R.SC | 1.143 | 0.855 | [0.457, 2.857] | OK |
| R.PCOX | 0.0947 | 0.0964 | [0.038, 0.237] | OK |
| V0.SVEN | 2310 | 2310 | [1617, 3118] | OK (unchanged) |
| C.SVEN | 19.91 | 19.8 | [9.96, 35.85] | OK |

## 5. Key Finding

5-parameter vascular set cannot independently control Qp vs Qs. Stage C
(+ventricular EB) is required for meaningful improvement.

## 6. Output Files

| File | Path |
|---|---|
| Baseline CSV | `indira_asd_baseline_20260604_053629.csv` |
| Calibrated CSV | `indira_asd_calibrated_20260604_053629.csv` (rollback = baseline values) |
| MAT package | `indira_asd_calibration_20260604_053629.mat` |
