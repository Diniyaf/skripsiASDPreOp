# ASD Calibration Implementation

**Date:** 2026-05-31  
**Status:** Implemented, ready to run

---

## 1. Overview

This document records the calibration implementation for Patient Zoya ASD pre-closure,
adapted from the Hafiz-Keisya unified VSD workflow. The calibration finds parameter
values that minimize the discrepancy between model outputs and clinical targets.

---

## 2. Files Created/Modified

| File | Action | Purpose |
|---|---|---|
| `scripts/run_zoya_asd_calibration.m` | **NEW** | Main calibration runner — 2-stage fmincon with gates |
| `src/calibration/asd_calibration_objective.m` | **NEW** | ASD-specific objective function for fmincon |
| `src/calibration/asd_candidate_param_sets.m` | **MODIFIED** | Updated `bounds_for` from 3 → 17 policy levels with VSD citations |
| `docs/asd_parameter_bounds_registry.md` | (existing) | 25-parameter bounds registry with VSD comparison |
| `docs/asd_active_set_decision.md` | (existing) | Active set decision framework + supervisor perspective |
| `docs/asd_calibration_implementation.md` | **NEW** | This file |

---

## 3. Calibration Workflow

```
run_zoya_asd_calibration.m
  │
  ├─[1] LOAD params0_ASD_pre (scaled + clinically seeded baseline)
  │
  ├─[2] BUILD active parameter sets from asd_candidate_param_sets bounds
  │     Stage 1: V0.SVEN, C.PAR, C.SVEN, R.SC, asd.Cd  (5 params)
  │     Stage 2: + E.RV.EB, E.LV.EB                     (2 params, conditional)
  │
  ├─[3] BASELINE SIMULATION — pre-calibration reference
  │
  ├─[4] STAGE 1 CALIBRATION
  │     fmincon(interior-point + LBFGS)
  │     → optimize 5 parameters
  │     → compute Stage 1 RMSE
  │
  ├─[5] STAGE 1 GATE
  │     RMSE < 0.10 ?
  │       YES → ACCEPT, skip Stage 2
  │       NO  → proceed to Stage 2
  │
  ├─[6] STAGE 2 CALIBRATION (conditional)
  │     fmincon(interior-point + LBFGS)
  │     → optimize 7 parameters (add ventricular)
  │     → compute Stage 2 RMSE
  │
  ├─[7] POST-CALIBRATION VALIDATION
  │     evaluate_simulation_validity (hard gates)
  │     Steady state, negative volumes, PVR/SVR/EF bounds
  │
  ├─[8] PARAMETER PLAUSIBILITY
  │     Check fitted values vs bounds
  │     Flag: OK | WARNING (<10% from bound) | FAIL (outside bound)
  │
  └─[9] ROLLBACK DECISION
        ├─ RMSE worsened? → ROLLBACK
        ├─ Validity failed? → ROLLBACK
        ├─ Plausibility FAIL? → ROLLBACK
        └─ All OK → ACCEPT
```

---

## 4. Objective Function Design

`asd_calibration_objective.m` computes:

```
J = J_primary                    error against 6 clinical targets
  + λ_plaus × J_plausibility     parameter plausibility penalty
  + λ_bound  × J_boundary        boundary violation penalty
  + J_validity                   physiological output gate penalty
  + J_ss                         steady-state failure penalty
```

### 4.1 Primary Targets (enter J_primary)

| Metric | Clinical Value | Normalization |
|---|---|---|
| QpQs | 3.79 | 5% acceptance target |
| Qp_Lmin | 12.27 | 5% |
| Qs_Lmin | 3.23 | 5% |
| PAP_mean | 23 mmHg | 5% |
| SAP_mean | 90 mmHg | 5% |
| LAP_mean | 14 mmHg | 5% |

### 4.2 Plausibility Penalties

Parameters within 10% of either bound incur a quadratic penalty, discouraging
the optimizer from parking at boundary values without physiological justification.

### 4.3 Validity Penalties

Hard physiological limits on model outputs:
- QpQs < 0.8 or > 8.0 → +100
- LVEF < 0.05 or > 0.95 → +50
- RVEF < 0.05 or > 0.95 → +50
- SVR < 0.5 or > 50 → +20
- PVR < 0.1 or > 20 → +20
- RAP_mean < -2 or > 25 → +20
- Simulation crash → +1e6
- Steady state not reached → +1e5

### 4.4 Penalty Weights

| Term | Lambda | Rationale |
|---|---|---|
| Plausibility | 0.50 | Moderate — discourages boundary parking |
| Boundary | 20.0 | Strong — prevents boundary violation (safety net) |

---

## 5. Optimizer Configuration

| Setting | Value |
|---|---|
| Algorithm | `interior-point` |
| Hessian | `lbfgs` |
| Finite differences | Forward, step 1e-5 |
| MaxFunctionEvaluations | 2000 |
| MaxIterations | 150 |
| OptimalityTolerance | 1e-5 |
| StepTolerance | 1e-6 |

---

## 6. Active Parameters with Bounds

### Stage 1 (5 parameters)

| Parameter | Initial | lb | ub | Source |
|---|---|---|---|---|
| V0.SVEN | 564.7 | 395.3 | 762.4 | Blood volume consistency |
| C.PAR | 8.017 | 5.612 | 11.625 | Windkessel SV/PP |
| C.SVEN | 13.665 | 6.832 | 24.597 | Kung R-C coupled |
| R.SC | 1.756 | 0.703 | 4.391 | Kung 2013 |
| asd.Cd | 0.700 | 0.200 | 1.200 | Orifice Cd range |

### Stage 2 (add 2 parameters, conditional on RMSE >= 0.10)

| Parameter | Initial | lb | ub | Source |
|---|---|---|---|---|
| E.RV.EB | 0.137 | 0.082 | 0.342 | Zhang 2019 |
| E.LV.EB | 0.176 | 0.105 | 0.439 | Zhang 2019 |

---

## 7. Differences from VSD Pipeline

| Aspect | VSD (`run_calibration.m`) | ASD (`run_zoya_asd_calibration.m`) |
|---|---|---|
| **Parameter count** | 17 (with GSA mask) | 5 (Stage 1) + 2 (Stage 2) |
| **Stages** | A (vascular), B (chamber), C (top-5), D (systemic polish), E (plausibility), F (validation) | 1 (vascular+shunt+preload), 2 (ventricular, conditional) |
| **Objective function** | 10-term multi-objective via `objective_calibration.m` (645 lines) | Simplified 5-term objective via `asd_calibration_objective.m` (~180 lines) |
| **Parameter registry** | `build_parameter_registry.m` from database | `asd_candidate_param_sets.m` with VSD-adapted bounds |
| **Systemic bundle** | Complex (MAP + RAP + CO + SVR bundle) | Not needed — systemic metrics are primary targets directly |
| **PCE surrogate** | Optional (uq_evalModel short-circuit) | Not implemented |
| **Parallel fmincon** | Supported via env var | Not implemented |
| **Plausibility polish stage** | Stage E (separate) | Integrated into objective via J_plausibility |
| **Rollback** | 3-level gate with multiple candidate snapshots | Simplified single-gate rollback |
| **Volume targets** | LVEDV, LVESV, RVEDV, RVESV, LVEF, RVEF | NONE (skipped, no data) |

---

## 8. Output Artifacts

Each run produces a timestamped folder under `results/calibration/`:
```
results/calibration/zoya_asd_calib_YYYYMMDD_HHMMSS/
  ├─ zoya_asd_calibration_YYYYMMDD_HHMMSS.mat    full calibration package
  ├─ zoya_asd_calibration_params_YYYYMMDD_HHMMSS.csv  parameter changes table
  └─ console_YYYYMMDD_HHMMSS.log                 console diary
```

---

## 9. How to Run

```matlab
cd('C:\Users\Diniya\skripsiASDPreOp');
addpath(genpath(pwd));
run('scripts/run_zoya_asd_calibration.m');
```

Or from terminal:
```powershell
matlab -batch "addpath(genpath('C:\Users\Diniya\skripsiASDPreOp')); run('scripts/run_zoya_asd_calibration.m')"
```

---

## 10. Scientific Decisions Embedded in this Implementation

1. **RMSE threshold = 0.10** — derived from clinical measurement uncertainty analysis
2. **asd.Cd forced into active set** — physiological primacy + cross-patient consistency
3. **Stage 2 conditional on Stage 1 failure** — staged approach shows which parameter class is necessary
4. **No volume targets in objective** — consistent with Hafiz-Keisya VSD approach of ignoring targets without clinical evidence
5. **VSD literature bounds** — all bounds sourced from Kung 2013, Zhang 2019, Windkessel theory
