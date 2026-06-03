# ASD Model — Complete Bounds Reference

**Date:** 2026-06-03  
**Purpose:** Single-source reference for all parameter bounds, output validity bounds, and physiological guard thresholds in the ASD calibration pipeline.

---

## 1. Parameter Bounds (26 GSA Parameters)

All bounds expressed as multipliers of the pediatric-scaled baseline (`params0_ASD_pre`).
Absolute bounds depend on patient (different baseline values).

### Resistances [0.40×, 2.50×] — Kung 2013

| Parameter | lb | ub | Source |
|---|---|---|---|
| R.SAR | 0.40× | 2.50× | Kung 2013 resistance prior |
| R.SC | 0.40× | 2.50× | Kung 2013 resistance prior |
| R.PAR | 0.40× | 2.50× | Kung 2013 resistance prior |
| R.PCOX | 0.40× | 2.50× | Kung 2013 resistance prior |
| R.PCNO | 0.40× | 2.50× | Kung 2013 resistance prior |
| R.asd (linear mode) | 0.40× | 2.50× | Kung 2013 resistance prior |

### Venous Resistances [0.40×, 3.00×] — Kung + R-C Coupling

| Parameter | lb | ub | Source |
|---|---|---|---|
| R.SVEN | 0.40× | 3.00× | Kung + R-C coupling (wider for venous) |
| R.PVEN | 0.40× | 3.00× | Kung + R-C coupling (wider for venous) |

### Arterial Compliances — Windkessel SV/PP (tightest)

| Parameter | lb | ub | Source |
|---|---|---|---|
| C.SAR | **0.75×** | **1.35×** | Windkessel SV/pulse pressure |
| C.PAR | **0.70×** | **1.45×** | Windkessel SV/pulse pressure |

### Venous Compliances [0.50×, 1.80×] — Kung R-C Coupled

| Parameter | lb | ub | Source |
|---|---|---|---|
| C.SVEN | 0.50× | 1.80× | Kung R-C coupled |
| C.PVEN | 0.50× | 1.80× | Kung R-C coupled |

### Ventricular Elastances — Zhang 2019

| Parameter | lb | ub | Source |
|---|---|---|---|
| E.LV.EA | 0.60× | 2.20× | Zhang 2019 LV active elastance |
| E.LV.EB | 0.60× | 2.50× | Zhang 2019 LV passive (EB wider) |
| E.RV.EA | 0.55× | 2.60× | Zhang 2019 RV active (more variable) |
| E.RV.EB | 0.60× | 2.50× | Zhang 2019 RV passive |

### Atrial Elastances — Zhang 2019 (widest)

| Parameter | lb | ub | Source |
|---|---|---|---|
| E.LA.EA | **0.20×** | **2.50×** | Zhang 2019 — sparse atrial data |
| E.LA.EB | 0.60× | 2.50× | Zhang 2019 atrial passive |
| E.RA.EA | **0.20×** | **2.50×** | Zhang 2019 — sparse atrial data |
| E.RA.EB | 0.60× | 2.50× | Zhang 2019 atrial passive |

### Unstressed Volumes [0.70×, 1.40×] — Blood Volume Consistency

| Parameter | lb | ub | Source |
|---|---|---|---|
| V0.LV | 0.75× | 1.40× | Blood volume consistency (LV) |
| V0.RV | 0.70× | 1.35× | Blood volume consistency (RV) |
| V0.LA | 0.70× | 1.35× | Blood volume consistency |
| V0.RA | 0.70× | 1.35× | Blood volume consistency |
| V0.SVEN | 0.70× | 1.35× | Blood volume consistency |

### Shunt Parameters — Absolute (not multiplier)

| Parameter | lb | ub | Source |
|---|---|---|---|
| asd.Cd (orifice mode) | **0.20** | **1.20** | Orifice discharge coefficient |
| R.asd (linear mode) | 0.40× baseline | 2.50× baseline | Kung 2013 resistance prior |

---

## 2. Output Validity Bounds — 11 Gates

Applied post-calibration. Any FAIL → rollback.

| # | Gate | Bound | Severity |
|---|---|---|---|
| 1 | Steady state | `ss_reached == true` | Hard |
| 2 | Non-finite states | No NaN/Inf in V | Hard |
| 3 | Negative chamber volumes | V_RA, V_RV, V_LA, V_LV ≥ 0 | Hard |
| 4 | Negative vascular volumes | All vascular V ≥ 0 | Hard |
| 5 | V0-adjusted volume | V_LV-V0_LV ≥ -1, V_RV-V0_RV ≥ -1 | Hard |
| 6 | Flow collapse | QpQs > 0 AND Qs ≥ 1e-3 | Hard |
| 7 | PVR bounds | [0.1, 20] WU | Hard |
| 8 | SVR bounds | [0.5, 50] WU | Hard |
| 9 | EF bounds | [0.05, 0.95] | Hard |
| 10 | ASD geometry | area ∈ [0, 500] mm² | Hard |
| 11 | Shunt direction | Bidirectional when gradient exists | Hard |

---

## 3. Physiological Guards — During Optimization (Soft Penalties)

Guard parameters are in the objective function, not the post-hoc gates.

| Guard | Bound | Penalty | Lambda | File |
|---|---|---|---|---|
| **MAP band** | [85, 95] mmHg | `10 × deviation²` outside band | 5.0 | `systemic_pressure_band_guard` |
| **RAP band** | [0, 15] mmHg | `50 × deviation²` outside band | 3.0 | `rap_physiological_guard` |
| **Ratio chasing** | Qs ≥ 90% of baseline | `50 × fraction²` if QpQs↑ and Qs↓ | 8.0 | `ratio_chasing_guard` |
| **Shunt direction** | Q_ASD ≥ 0 (L→R) | `25 × (1+|Q_ASD|)` | 1.0 | `asd_shunt_mechanism_guard` |
| **Parameter near boundary** | ≥ 10% from lb/ub | `(0.10 - dist)²` per param | 0.5 | `near_boundary_penalty` |
| **Parameter outside boundary** | Inside [lb, ub] | `(deviation/value)²` | 20.0 | `outside_boundary_penalty` |
| **Parameter drift** | Near x0 | `log(x/x0)²` | 0.10 | `parameter_drift_penalty` |

### Output Plausibility — In-Objective Broad Envelope

| Metric | Bound | Penalty |
|---|---|---|
| QpQs | [0.5, 8.0] | +100 outside |
| LVEF/RVEF | [0.05, 0.95] | +50 outside |
| SVR | [0.5, 60] | +20 outside |
| PVR | [0.05, 25] | +20 outside |
| RAP/LAP | [-5, 30] | +20 outside |
| PAP_mean | [2, 80] | +20 outside |
| SAP_mean | [30, 160] | +20 outside |

---

## 4. Plausibility Flags — Post-Calibration

| Flag | Condition |
|---|---|
| **OK** | Inside bounds, ≥ 10% from both boundaries |
| **WARNING** | Inside bounds, but ≤ 10% from lower or upper bound |
| **FAIL** | Outside bounds, non-finite, or positive-definite param ≤ 0 |

---

## 5. Output Classification Thresholds — `asd_output_table.m`

For metrics WITH clinical targets:

| Status | Condition |
|---|---|
| **OK (<5%)** | |model - target| / target < 5% |
| **WARNING (5-15%)** | Error between 5% and 15% |
| **MISMATCH (>15%)** | Error > 15% |

For metrics WITHOUT clinical targets:

| Status | Condition |
|---|---|
| **Prediction Only** | No clinical target available |

---

## 6. Clinical Fit Gate — Post-Calibration Rollback

| Check | Threshold |
|---|---|
| Primary metric worsened | `new_err > 15% AND new_err > base_err + 5%` |
| Secondary guard worsened | `new_err > 15% AND new_err > base_err + 5%` |

---

## 7. fmincon Configuration

| Setting | Value |
|---|---|
| Algorithm | interior-point |
| Hessian | LBFGS |
| Finite differences | Forward, step 1e-5 |
| MaxFunEvals (Stage A) | 2500 |
| MaxFunEvals (Stage C) | 1500 |
| MaxIterations | 200 |
| OptimalityTolerance | 1e-5 |
| StepTolerance | 1e-6 |
