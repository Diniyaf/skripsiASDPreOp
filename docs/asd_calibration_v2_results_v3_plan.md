# ASD Calibration v2 Results & v3 Updates — Zoya Primary Case

**Date:** 2026-06-02  
**Status:** v2 complete (rollback documented), v3 running (asd.Cd fix + ratio-chasing guard)

---

## 1. v2 Calibration Results — Complete Analysis

### Configuration

| Setting | Value |
|---|---|
| ST threshold | 0.05 |
| Active set (Stage A) | 5 params: V0.SVEN, R.SC, C.SVEN, R.PCOX, C.PAR |
| Active set (Stage C) | 8 params: + E.RV.EB, E.LV.EB, E.LV.EA |
| asd.Cd in mask? | Yes — but **NOT wired into Stage A** (bug, fixed in v3) |
| Objective | Re-weight (QpQs 5×, Qp 3×, LAP 2×) + MAP guard [85,95] |
| Ratio-chasing guard? | Not yet |

### Results

| Metric | Target | Baseline | Stage A | Stage C | Baseline Err | Stage C Err |
|---|---|---|---|---|---|---|
| Qs_Lmin | 3.23 | 2.54 | 2.54 | **1.79** | 21.5% | **44.5%** ⚠ |
| Qp_Lmin | 12.27 | 3.61 | 3.72 | 6.32 | 70.6% | 48.5% |
| SAP_mean | 90 | 90.3 | 95.2 | 84.9 | 0.4% | 5.6% |
| PAP_mean | 23 | 18.8 | 18.0 | 21.2 | 18.2% | 7.8% |
| LAP_mean | 14 | 6.9 | 7.0 | 8.6 | 50.5% | 38.9% |
| QpQs | 3.79 | 1.42 | 1.46 | **3.52** | 62.5% | **7.1%** ✅ |
| **RMSE** | — | **0.4515** | **0.4482** | **0.3158** | — | — |

### Key Finding: Ratio Chasing

Stage C achieved Qp/Qs = 3.52 (error 7.1%) — impressive from baseline 1.42. But it did so by
**collapsing systemic flow** (Qs: 2.54 → 1.79, -30%) rather than raising pulmonary flow.
The shunt mechanism was:

```
Q_ASD = Qp - Qs = 6.32 - 1.79 = 4.53 L/min  (target: 9.04)
Qp/Qs = 3.52  (close to target 3.79)
```

E.LV.EA dropped from 7.68 → 6.77, making LV weaker → lower systemic output → denominator
of Qp/Qs dropped → ratio improved. This is **mathematically correct but physiologically
incorrect** for ASD: the shunt should increase Qp without decreasing Qs.

### Rollback Decision

| Gate | Result | Status |
|---|---|---|
| RMSE improved (0.45 → 0.32) | Yes | ✅ |
| 11 validity gates | All OK | ✅ |
| Plausibility | 6 OK, 2 WARNING, 0 FAIL | ✅ |
| **Clinical fit guard** | Qs_Lmin worsened 21.5%→44.5% | ❌ **ROLLBACK** |

**Accepted = baseline** (RMSE 0.4515). **Best = Stage C** (RMSE 0.3158, rejected).

### Bug Identified: asd.Cd Not Wired

`optMask` was correctly forced to include `asd.Cd`, but `stageA_names_expected` was built
from the pre-modification `active_selection.Mask_Selected`. Result: asd.Cd appeared in the
printed mask but was **never passed to fmincon**. The optimizer operated on only 5 parameters.

---

## 2. v3 Updates — Currently Running

### Fixes Applied

| # | Fix | File | Effect |
|---|---|---|---|
| 1 | **Stage assignments from final optMask** | `run_zoya_asd_calibration.m` L141-150 | asd.Cd now correctly enters Stage A |
| 2 | **Ratio-chasing guard** | `objective_calibration_asd.m` L231-255 | If QpQs improves AND Qs drops >10% → penalty 50× |
| 3 | ST_max from GSA data directly | `run_zoya_asd_calibration.m` L151-158 | No dependency on stale active_selection |

### Expected Improvements

| Aspect | v2 | v3 (expected) |
|---|---|---|
| asd.Cd wired | ❌ Bug | ✅ Fixed — 6 params Stage A |
| Ratio chasing prevented | ❌ Qs dropped 30% | ✅ Penalized if QpQs ↑ while Qs ↓ |
| MAP guard | ✅ Active | ✅ Active |
| Re-weight | ✅ Active | ✅ Active |
| Group C available | ✅ Yes | ✅ Yes |

---

## 3. Rollback vs Accepted — Framework Explanation

The calibration pipeline uses a **3-level governance system**:

```
Level 1 — VALIDITY (11 hard gates)
  Are states finite? Volumes positive? Steady state reached?
  → FAIL = model crash. MUST pass for any acceptance.

Level 2 — CLINICAL FIT (guard)
  Did calibration sacrifice an already-good metric to improve another?
  → FAIL = physiologically compromised result. Rollback triggered.

Level 3 — PLAUSIBILITY (parameter bounds)
  Are calibrated parameters within registry bounds?
  → FAIL = non-physiological parameter values. Rollback triggered.
```

### Rollback Behavior

| Scenario | Accepted Candidate |
|---|---|
| All 3 levels PASS | `accepted = paramsC` (calibrated) |
| Any level FAIL | `accepted = params0` (baseline) |
| Best candidate | **Always saved** in MAT, regardless of acceptance |

### Why Rollback Is Valuable

Rollback is NOT failure. It is **scientific governance**:

> *"The calibration framework correctly rejected a candidate that achieved lower
> RMSE (0.32 vs 0.45) because it violated the clinical fit guard (Qs systemic
> flow degraded beyond tolerance). This demonstrates that the framework
> prioritizes physiological validity over numerical optimization."*

---

## 4. Thesis Writing — How to Present Candidates

### Candidate Naming for Thesis

| Term | MATLAB Variable | Meaning | Where in Thesis |
|---|---|---|---|
| **Baseline** | `params0`, `metrics_base` | Pediatric scaled + clinically seeded, before any calibration | Reference point for all comparisons |
| **Best Candidate** | `pkg.best_candidate` | Lowest RMSE achieved, regardless of gates | Discussion only — "the optimizer found this, but..." |
| **Scientific Candidate** | Stage A result (if all gates pass) | Conservative calibration without ventricular modification | Results section, if Stage A passes gates |
| **Accepted Candidate** | `pkg.accepted_params` | The parameter set that passed ALL gates | Results section, primary reported result |

### Example Thesis Text

**Methods:**
> *"Three candidate parameter sets were tracked: the baseline (pre-calibration),
> the best numerical candidate (lowest RMSE regardless of physiological
> constraints), and the accepted candidate (lowest RMSE that satisfied all
> validity, clinical fit, and plausibility gates). Rollback to baseline or a
> prior stage occurred when any gate failed."*

**Results (if v3 succeeds):**
> *"Stage A calibration with 6 parameters (V0.SVEN, R.SC, C.SVEN, R.PCOX, C.PAR,
> asd.Cd) achieved RMSE X.XX. Stage C extended with ventricular parameters
> (E.RV.EB, E.LV.EB, E.LV.EA) further improved RMSE to Y.YY. The accepted
> candidate after all governance gates is [Stage A/C/baseline], representing
> the best physiologically valid parameter set."*

**Results (if v3 rolls back):**
> *"Stage C achieved the lowest RMSE (0.XX) with Qp/Qs = X.XX, but was rejected
> by the clinical fit guard due to [specific reason]. The accepted parameter set
> therefore remains [Stage A/baseline]. This outcome demonstrates a fundamental
> trade-off in the model: [explanation]. The best numerical candidate is
> preserved for scientific discussion."*

### Figures for Thesis

| Figure | Content |
|---|---|
| **RMSE progression** | Bar chart: Baseline → Stage A → Stage C → Accepted |
| **Target comparison table** | 6 metrics × 4 columns (Target, Baseline, Best, Accepted) |
| **Parameter change plot** | Waterfall chart of Δx from baseline to calibrated |
| **Gate summary table** | 11 validity + clinical fit + plausibility — PASS/FAIL |
| **Rollback flow diagram** | Flowchart of decision tree |

---

## 5. Running Subsequent Patients

### Pipeline — Identical for All Patients

The calibration framework is patient-generic. Only the clinical data changes:

```matlab
% Patient X (new primary patient)
ctx = run_asd_patient_case(@patient_xxx, 'xxx', 'pre_surgery', ...
    struct('scaling_mode', 'lundquist_bsa', 'runBaselineSimulation', false));

% GSA (run once per patient)
run('scripts/run_zoya_asd_gsa_curated.m');  % ← edit patient reference inside

% Calibration (run after GSA .mat available)
run('scripts/run_zoya_asd_calibration.m');  % ← edit patient reference inside
```

### What Changes Per Patient

| Component | Changes Needed |
|---|---|
| **Patient file** | New `patient_xxx.m` with demographics + clinical data |
| **GSA script** | Change `@patient_zoya` → `@patient_xxx`, label `'zoya'` → `'xxx'` |
| **Calibration script** | Change `@patient_zoya` → `@patient_xxx`, label `'zoya'` → `'xxx'` |
| **Target tiers** | Auto-generated from `build_asd_target_tiers(clinical, scenario)` |
| **GSA mask** | Auto-computed from patient-specific Sobol ST |
| **Active set** | Auto-selected by `build_asd_active_mask_from_gsa` |
| **Weights** | Same default weights (QpQs 5×, Qp 3×, LAP 2×) — can override |

### What Stays the Same

| Component | Reason |
|---|---|
| **ODE model** (system_rhs.m, asd_shunt_model.m) | Same physiology regardless of patient |
| **Bounds registry** (asd_candidate_param_sets.m) | Same literature-cited bounds per parameter class |
| **Objective function** (objective_calibration_asd.m) | Same multi-term structure with guards |
| **Validity gates** (11 ASD-adapted) | Same physiological plausibility checks |
| **Rollback logic** | Same 3-level governance |
| **Output tables** (asd_output_table.m) | Same 26-metric panel |

### Thesis Description for Multi-Patient

> *"The calibration framework was validated on Patient Zoya (primary case, n=1)
> and subsequently applied to [N] additional patients (secondary cases) to
> assess generalizability. For each patient, the pipeline proceeded identically:
> (1) pediatric scaling using Lundquist BSA allometry, (2) clinical seeding
> from available catheterization/echocardiography data, (3) 25-parameter Sobol
> GSA with N=128, (4) GSA-driven active mask selection via ST threshold = 0.05,
> (5) staged calibration with governance gates, and (6) acceptance/rejection
> via the 3-level rollback framework. Differences in active sets between
> patients reflect patient-specific sensitivity landscapes, while the
> calibration methodology remained constant."*

---

## 6. Current Status and Next Steps

| Phase | Status |
|---|---|
| Zoya GSA N=128 | ✅ Complete |
| Zoya Calibration v1 (4 params) | ✅ Complete — RMSE 0.39, rollback |
| Zoya Calibration v2 (5 params, no Cd) | ✅ Complete — RMSE 0.32, rollback (ratio chasing) |
| **Zoya Calibration v3 (6 params + guards)** | 🔄 **Running now** |
| Zoya Final — write thesis section | ⏳ After v3 |
| Patient X GSA | ⏳ |
| Patient X Calibration | ⏳ |
| Patient Y (shared w/ Jovano) | ⏳ |
| Batch secondary patients | ⏳ |
| Cross-patient comparison table | ⏳ |
