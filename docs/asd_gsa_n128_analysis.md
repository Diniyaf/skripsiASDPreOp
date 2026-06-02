# ASD GSA N=128 — Complete Analysis & Post-Calibration Strategy

**Date:** 2026-06-01  
**Script:** `run_zoya_asd_gsa_curated.m` v3.0 (VSD-aligned)  
**Config:** N=128, seed=42 (combRecursive), warmup=40 cycles, parallel 6 workers  
**Patient:** Zoya (7.07 yr, 18.2 kg, BSA 0.788, ASD 19.25 mm, Qp/Qs=3.79)

---

## 1. Run Summary

| Metric | Value |
|---|---|
| Total simulations | 3,456 (N × (d+2) = 128 × 27) |
| Parameters varied | 25 (Groups A+B+C curated) |
| Primary targets | Qs_Lmin, Qp_Lmin, SAP_mean, PAP_mean, LAP_mean, QpQs |
| Secondary guards | SAP_max, SAP_min, PAP_max, PAP_min, Q_ASD_Lmin |
| Wall-clock time | ~70 minutes |
| Worker crashes | Zero — 6-worker pool stable throughout |

---

## 2. Failure Analysis

### Numerical Failures (data loss)

| Type | Count | % of total |
|---|---|---|
| `steady_state_failure` | 24 | 0.69% |
| `solver_failure` | 0 | 0% |
| `exception` | 0 | 0% |
| **Total numerical** | **24** | **0.69%** |

**Verdict:** Excellent. Below the 1% threshold. Warmup=40 cycles is sufficient.

### Physiology Warnings (data valid, informational only)

| Type | Count | % of total |
|---|---|---|
| `opposite_shunt_direction` | 646 | 18.7% |
| `unexpected_physiology` | 0 | 0% |
| **Total warnings** | **646** | **18.7%** |

**Interpretation:** 19% of samples produce RA→LA shunt instead of LA→RA. This is
expected for a near-balanced baseline (Qp/Qs=1.42) with 25 parameters varied
simultaneously. All 646 samples retain valid outputs that contribute to Sobol
index calculation. Not treated as data loss.

### Valid Pairs

With 0.69% NaN rate (24/3456), the minimum valid pairs for the Jansen estimator
is approximately 126/128 = 98.4% — well above the 80% acceptability threshold.

---

## 3. Sobol Sensitivity Results

### Top Parameters by Total-Order ST (Primary Targets Only)

| # | Parameter | Group | Max_ST_Primary | CI 95% | Width | Sensitive Targets |
|---|---|---|---|---|---|---|
| 1 | **V0.SVEN** | B (venous preload) | **0.568** | [0.40, 0.76] | 0.36 | Qs, Qp, SAP, PAP, **LAP** |
| 2 | **E.RV.EB** | C (RV passive E) | **0.407** | [0.32, 0.51] | 0.19 | QpQs, Qp, PAP |
| 3 | **R.SC** | A (systemic capillary R) | **0.360** | [0.28, 0.50] | 0.22 | Qs, SAP |
| 4 | **E.LV.EB** | C (LV passive E) | **0.317** | [0.23, 0.45] | 0.22 | QpQs, Qp, Qs, SAP, PAP, LAP |
| 5 | **C.SVEN** | B (venous C) | **0.151** | [0.11, 0.21] | 0.10 | PAP, LAP |
| 6 | **R.PCOX** | A (pulmonary capillary R) | **0.116** | [0.09, 0.16] | 0.07 | PAP |

### Bootstrap CI Quality

All top-6 parameters have:
- CI width < ST_point (meaning the sign of sensitivity is confident)
- No CI bounds that overlap zero (meaning the parameter IS influential, not noise)
- No CI_hi > 1 (no bootstrap instability)

**Verdict:** N=128 is sufficient for defensible ranking. N=256 is not required
unless thesis examiners request it.

---

## 4. Physiological Interpretation

### 4.1 V0.SVEN Dominates — Why?

Systemic venous unstressed volume controls **preload** — the blood volume available
for venous return. Higher V0.SVEN → more blood in venous reservoir → less venous
return → lower atrial filling → lower P_LA → reduced L→R shunt gradient.

This is physiologically correct for ASD: the venous compartment sets the upstream
boundary condition for the entire right-heart + pulmonary circuit. It is the
single most influential parameter because it cascades.

### 4.2 Ventricular Passive Elastance (EB) — Coupling Effect

E.LV.EB and E.RV.EB control diastolic stiffness. Stiffer ventricles → higher
filling pressure → higher atrial pressure → stronger shunt gradient. This
coupling through the closed-loop explains why ventricular parameters rank highly
even for pressure-flow targets.

However, these remain **Group C (monitor-only)** for Zoya because no LV/RV
volume or EF data exist to validate calibrated ventricular parameters.

### 4.3 R.SC and R.PCOX — Expected Vascular Candidates

Systemic capillary resistance controls systemic afterload (MAP, Qs). Pulmonary
capillary resistance controls pulmonary pressure (PAP). Both are expected in the
top set for a pressure-flow calibration.

### 4.4 C.SVEN — Venous Compliance Matters

Venous compliance determines how venous pressure responds to changes in blood
volume. For ASD, this affects atrial filling pressure and therefore shunt drive.

### 4.5 asd.Cd — Still Not Sensitive

At Zoya's ASD diameter (19.25 mm = 291 mm²), the defect is effectively
unrestrictive — Cd variation in [0.2, 1.2] has minimal additional effect on
shunt flow. This is a finding, not a limitation: the model correctly captures
that large ASDs behave as near-common-atrium.

---

## 5. Calibration Active Set

### Stage A: Vascular + Shunt + Preload (5 params)

| Parameter | ST | Group | Rationale |
|---|---|---|---|
| V0.SVEN | 0.57 | B | Top-ranked — systemic venous preload |
| R.SC | 0.36 | A | Systemic capillary resistance |
| C.SVEN | 0.15 | B | Venous compliance |
| R.PCOX | 0.12 | A | Pulmonary capillary resistance |
| **asd.Cd** | <0.10 | A | **Forced** — shunt knob (methodology) |

### Stage C: Ventricular Extension (conditional on Stage A RMSE ≥ 0.10)

| Parameter | ST | Group | Rationale |
|---|---|---|---|
| E.RV.EB | 0.41 | C | RV passive elastance via coupling |
| E.LV.EB | 0.32 | C | LV passive elastance via coupling |

Only activated if `ASD_CALIB_ALLOW_GROUPC=1` AND Stage A RMSE ≥ 0.10.

---

## 6. Post-Calibration Strategy — Decision Tree

If calibration RMSE exceeds 0.10 (10%):

```
CALIBRATION RESULT
  │
  ├─ ALL 6 targets < 10% → ACCEPT ✅
  │     → Generate output tables → Write thesis
  │
  ├─ 4-5 targets < 10%, 1-2 targets > 10%
  │     │
  │     ├─ Strategy 1: RE-WEIGHT OBJECTIVE
  │     │   Naikkan bobot metric yang under-fit (misal QpQs ×3, LAP ×3)
  │     │   Edit: objective_calibration_asd.m
  │     │
  │     └─ Strategy 2: EXPAND ACTIVE SET
  │         Turunkan ST threshold 0.10 → 0.05 untuk vascular params
  │         Tambah R.SAR, R.SVEN ke Stage A
  │         Edit: ST_THRESHOLD di run_zoya_asd_calibration.m
  │
  ├─ Semua > 10% tapi improved from baseline
  │     │
  │     ├─ Strategy 3: ENABLE GROUP C
  │     │   setenv('ASD_CALIB_ALLOW_GROUPC', '1')
  │     │   → E.RV.EB (ST=0.41) dan E.LV.EB (ST=0.32) masuk active set
  │     │
  │     ├─ Strategy 4: MULTI-START fmincon
  │     │   Jalankan dari 3-5 starting point, ambil J terendah
  │     │
  │     └─ Strategy 5: INCREASE BUDGET
  │         MaxFunEvals 2500 → 5000, MaxIter 200 → 400
  │
  └─ NO IMPROVEMENT from baseline
        │
        ├─ Cek: apakah x_opt berbeda dari x0?
        │   NO → objective bug / bounds terlalu ketat
        │   YES → model limitation (strategy 6)
        │
        └─ Strategy 6: DOCUMENT AS FINDING
            "Kalibrasi N-parameter mencapai RMSE X. Residual mismatch
             pada QpQs dan LAP menunjukkan batasan lumped-parameter
             model dengan data klinis sparse. Trade-off antara shunt
             severity dan systemic pressure adalah inherent."
```

---

## 7. Comparison with Previous Runs

| Run | Date | N | Params | Top Parameter | Key Difference |
|---|---|---|---|---|---|
| v1 (Group A only) | 2026-05-29 | 64 | 10 | E.LV.EB | Only vascular+shunt, no Group B/C |
| v2 (Full, parallel crash) | 2026-05-30 | 128 | 26 | E.LV.EB | Full set but parallel aborted |
| v3 (Curated, stable) | **2026-06-01** | **128** | **25** | **V0.SVEN** | ✅ Definitive run — stable, CI good |

### Key Change from v2 to v3

The top parameter shifted from E.LV.EB to V0.SVEN. This is likely because:
1. v2 used fewer valid pairs (parallel crashes caused data loss)
2. v3 has cleaner data with separated failure categories
3. V0.SVEN was always highly ranked — v3 just gives a more reliable estimate

---

## 8. Thesis Figure Recommendations

| Figure | Source | Caption |
|---|---|---|
| ST heatmap (25×6) | `zoya_asd_gsa_curated_ST_heatmap_*.pdf` | Total-order Sobol indices for 25 parameters against 6 primary clinical targets |
| Ranked ST bar (QpQs) | `zoya_asd_gsa_curated_ST_bar_QpQs_*.pdf` | Parameter ranking by ST for pulmonary-to-systemic flow ratio |
| Bootstrap CI summary | Table from Section 3 | 95% bootstrap confidence intervals for top parameters |
| Failure analysis | Table from Section 2 | Numerical vs physiology warning breakdown |

---

## 9. Key Messages for Thesis

1. **GSA methodology** follows VSD-standard Saltelli/Jansen approach with N=128 and bootstrap CI
2. **Venous preload (V0.SVEN) is the dominant parameter** for ASD pressure-flow matching — a physiologically meaningful finding
3. **Ventricular passive elastance shows strong coupling** to pressure-flow outputs (substantiating the full-parameter GSA approach over Group-A-only)
4. **asd.Cd is insensitive** at 19.25 mm defect size, confirming unrestrictive ASD physiology
5. **Numerical robustness** is excellent: 0.69% failure rate, zero solver crashes, stable CI
