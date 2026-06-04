# Indira — Stage C ACCEPTED (RMSE 0.0416)

**Date:** 2026-06-04  
**Run folder:** `results/calibration/indira_asd_calib_20260604_063632`  
**Status:** ✅ **ACCEPTED** — all gates passed, waveform warnings only

---

## 1. Calibration Summary

| Metric | Target | Baseline | Stage C | Error |
|---|---|---|---|---|
| Qs_Lmin | 3.22 | 3.78 (17%) | 3.40 | **5.6%** |
| Qp_Lmin | 7.54 | 5.81 (23%) | 7.80 | **3.5%** |
| SAP_mean | 75 | 86.9 (16%) | 68.8 | **8.3%** |
| PAP_mean | 25 | 20.0 (20%) | 24.5 | **2.0%** |
| LAP_mean | 8 | 6.89 (14%) | 8.02 | **0.2%** |
| RAP_mean | 6 | 5.95 (0.8%) | 6.01 | **0.2%** |
| QpQs | 2.34 | 1.54 (34%) | 2.30 | **1.9%** |
| **RMSE** | — | **0.2021** | **0.0416** | **79% improvement** |

**All 7 primary targets within 10% error.**

---

## 2. Shunt Mechanism Restoration

| Metric | Baseline | Stage C | Target |
|---|---|---|---|
| Q_ASD (L/min) | 2.03 | **4.40** | 4.32 |
| ΔP_LA-RA (mmHg) | 1.02 | **2.14** | 2.0 |
| RVEDV (mL) | 120 | **157** | — |
| RVSV (mL) | 80 | **107** | — |

Q_ASD restored from 2.03 → 4.40 L/min (target 4.32). ΔP nearly perfectly matched
(2.14 vs 2.0 mmHg). RV shows appropriate volume loading (RVEDV 157 mL).

---

## 3. Calibrated Parameters

| Parameter | Initial | Stage C | Bound | Flag |
|---|---|---|---|---|
| R.asd | 0.0278 | 0.0274 | [0.011, 0.069] | OK |
| R.SC | 1.143 | 0.964 | [0.457, 2.857] | OK |
| R.PCOX | 0.0947 | 0.0854 | [0.038, 0.237] | OK |
| V0.SVEN | 2310 | 2310 | [1617, 3118] | OK |
| C.SVEN | 19.91 | 17.08 | [9.96, 35.85] | OK |
| E.LV.EB | 0.0975 | 0.132 | [0.058, 0.244] | OK |
| E.RV.EB | 0.0565 | 0.0355 | [0.034, 0.141] | ⚠ WARNING |

R.asd barely changed from seed (0.0278→0.0274) — confirming that seeding from
ΔP/Q was near-perfect. E.RV.EB lowered to near bound — consistent pattern with Zoya.

---

## 4. Governance Summary

| Gate | Result |
|---|---|
| 11 validity gates | ✅ All PASS |
| Clinical fit guard (primary) | ✅ PASS |
| Waveform warnings (secondary) | ⚠ SAP_max 5.3%→15.0%, PAP_min 3.6%→15.5% |
| Parameter plausibility | 6 OK, 1 WARNING |
| **Rollback** | **NO — ACCEPTED** ✅ |

---

## 5. Key Output Files

| File | Path |
|---|---|
| **Accepted MAT package** | `indira_asd_calibration_20260604_063632.mat` |
| **Baseline CSV** (26 metrics) | `indira_asd_baseline_20260604_063632.csv` |
| **Calibrated CSV** (26 metrics, accepted) | `indira_asd_calibrated_20260604_063632.csv` |
| **Best candidate CSV** | `indira_asd_best_candidate_20260604_063632.csv` |
| **Best candidate parameters** | `indira_asd_best_candidate_parameters_20260604_063632.csv` |
| Console log | `console_*.log` |

Full path: `results/calibration/indira_asd_calib_20260604_063632/`

---

## 6. Comparison: Zoya vs Indira (Both Accepted)

| | Zoya v4 | Indira Stage C |
|---|---|---|
| RMSE | 0.35 | **0.042** |
| Primary targets < 10% | 2/6 | **7/7** |
| Shunt mode | Orifice (Cd) | Linear (R.asd) |
| R.asd seeded? | No (Cd guessed) | **Yes (ΔP/Q)** |
| RAP data? | No | **Yes** |
| ΔP data? | No | **Yes** |
| Iterations | 4 (v1→v4) | **1** |
| Active params | 12 | **7** |
| Atrial expansion? | Yes | No |

---

## 7. Thesis Table — Chapter 4

| Parameter | Initial | Fitted | Group | Flag |
|---|---|---|---|---|
| R.asd | 0.0278 | 0.0274 | A (shunt) | OK |
| R.SC | 1.143 | 0.964 | A (vascular) | OK |
| R.PCOX | 0.0947 | 0.0854 | A (vascular) | OK |
| V0.SVEN | 2310 | 2310 | B (preload) | OK |
| C.SVEN | 19.91 | 17.08 | B (preload) | OK |
| E.LV.EB | 0.0975 | 0.132 | C (ventricular) | OK |
| E.RV.EB | 0.0565 | 0.0355 | C (ventricular) | WARNING |
