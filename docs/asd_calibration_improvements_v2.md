# ASD Calibration Improvements v2

**Date:** 2026-06-01  
**Context:** Stage A (4 params) reached RMSE 0.39 but shunt severity (Qp/Qs, Qp)
remained under-predicted. Stage C (6 params) improved RMSE to 0.29 but was
rolled back because systemic pressure (MAP) was sacrificed. This document
records the three modifications made to address these issues.

---

## 1. Changes Made

### Change 1: ST Threshold Lowered (0.10 → 0.05)

**File:** `scripts/run_zoya_asd_calibration.m`, line 53

**Before:** Only parameters with Sobol ST ≥ 0.10 entered the active mask.
At N=128, the bootstrap CI width for ST ≈ 0.08 is approximately ±0.06.
Parameters with ST in [0.05, 0.10] may be truly influential but not detected
at the conservative threshold.

**After:** Threshold lowered to 0.05, allowing borderline-sensitive vascular
parameters (R.SAR, R.SVEN, R.PAR) to enter the mask.

**Expected improvement:** R.SAR and R.SVEN provide independent systemic
control. Previously, R.SC was the only systemic resistance knob — reducing it
lowered MAP. With R.SAR + R.SVEN also active, the optimizer can redistribute
systemic resistance across compartments, potentially maintaining MAP while
improving flow.

**Patient-generic?** Yes. The threshold is configurable; different patients
will have different GSA results but the same algorithm.

### Change 2: asd.Cd Forced into Mask + Minimum Active Set Expansion

**File:** `scripts/run_zoya_asd_calibration.m`, after mask construction

**Before:** asd.Cd was not in the mask because ST < 0.10 (expected for
unrestrictive ASD at 19.25 mm). No minimum active set enforced.

**After:** Two additions:
1. `asd.Cd` is forced into the mask every run — it is the only direct shunt
   control parameter and must be available for methodological consistency.
2. If fewer than 5 non-ventricular parameters are in the mask, the remaining
   top-ST parameters are automatically added to reach the minimum.

**Expected improvement:** asd.Cd provides a dedicated shunt knob. Even though
its sensitivity is low at large defect sizes, having it in the active set
ensures the optimizer has direct shunt control. For smaller defects in future
patients, this will be essential.

**Patient-generic?** Yes. Both rules are parameter-class-aware, not
patient-specific. The minimum-size guard prevents underpowered calibration
for any patient. asd.Cd is forced universally as a shunt knob.

### Change 3: Objective Re-weighting + Asymmetric MAP Guard

**File:** `src/calibration/objective_calibration_asd.m`

**Before:** All 6 primary targets had equal weight (1.0). No protection for
systemic pressure beyond the post-hoc clinical fit gate (which rejects after
optimization, not during).

**After:** Three additions to the objective:

**3a. Metric Weights** — `calib.metricWeights` struct with per-metric multipliers:

| Metric | Weight | Rationale |
|---|---|---|
| QpQs | 5.0 | Baseline error 65% — highest priority |
| Qp_Lmin | 3.0 | Baseline error 70% |
| LAP_mean | 2.0 | Baseline error 50% |
| Others | 1.0 | Default |

Weight reads from `target_bundle_penalty()` via `optional_scalar`. Unrecognised
fields default to 1.0. Future patients can have different weights — or remove
`metricWeights` entirely for equal weighting.

**3b. Asymmetric MAP Band Guard** — `systemic_pressure_band_guard()`:

```
If MAP in [85, 95] mmHg → zero penalty
If MAP < 85 or > 95 → J = 10 × deviation²
```

This is a soft penalty (quadratic, not hard wall). It gives fmincon room to
explore but makes leaving the band increasingly expensive. Unlike the
post-hoc clinical fit gate (which only REJECTS after optimization), this guard
STEERS the optimizer away from unacceptable MAP values DURING search.

**3c. Guard Lambda** — `mapGuardLambda = 5.0` (configurable in calib_cfg).

**Expected improvement:**
- Re-weighting forces fmincon to prioritise shunt severity metrics. Previously,
  the optimizer could reduce overall RMSE by improving Qs_Lmin (21% error) and
  SAP_mean (0.4% error) while ignoring QpQs (65% error) — because all had
  equal weight.
- The MAP band guard prevents the optimizer from "solving" shunt severity by
  dropping systemic pressure. With guard active, fmincon must find a
  combination that BOTH increases Qp/Qs AND keeps MAP ≥ 85 mmHg.

**Patient-generic?** Yes:
- Weights are a configuration field, not hardcoded logic. Different patients
  can have different weights or none at all.
- The MAP band defaults to [85, 95] but can be overridden via
  `calib.mapBand = [lower, upper]` — per-patient physiological bands.
- If `mapBand` is not set, the guard activates at default [85, 95] which is
  a reasonable pediatric normotensive range.

---

## 2. Expected Impact on Calibration Results

| Metric | Baseline Error | Previous Stage A | Expected v2 |
|---|---|---|---|
| QpQs | 65% | 65% (worsened) | **Improve** — 5× weight + asd.Cd available |
| Qp_Lmin | 71% | 58% | **Improve** — 3× weight |
| LAP_mean | 51% | 33% | **Improve** — 2× weight |
| SAP_mean | 0.4% | 8.2% | **Protected** — MAP band guard |
| Qs_Lmin | 22% | 19% | May drift — not weighted |
| PAP_mean | 18% | 14% | May drift — not weighted |

### Risk Assessment

| Risk | Mitigation |
|---|---|
| Re-weighting over-constrains fmincon | Weights are multipliers, not hard constraints. fmincon can still trade off |
| MAP guard creates local minima at band boundary | Guard is quadratic (soft), not a step function. fmincon can cross with penalty |
| asd.Cd adds noise (low ST) | Narrow bounds [0.2, 1.2] limit Cd's influence; it won't dominate the search |
| Expansion adds too many params (underdetermined) | Only to reach minimum 5; capped by registry bounds |

---

## 3. Patient-Generic Guarantee

All three changes are **parameterised, not hardcoded for Zoya**:

| Aspect | How It Stays Generic |
|---|---|
| **ST threshold** | Configurable in `run_zoya_asd_calibration.m` line 53. Future patients can use different thresholds. |
| **asd.Cd forcing** | Hardcoded as a universal rule: all ASD calibration runs force the shunt knob. This is physiologically defensible for any ASD patient. |
| **Minimum active set** | 5 is a configurable floor. Works for any patient with >=5 calibratable parameters. |
| **Metric weights** | Stored in `calib.metricWeights`. If absent → all weights = 1.0 (equal). Different patients can have different weights or none. |
| **MAP band** | Read from `calib.mapBand`. Default [85, 95] applies to pediatric normotension. Can be set per patient from clinical data. If unset → uses default. |

A future patient run only needs:
```matlab
run_asd_patient_case(@patient_xxx, 'xxx', 'pre_surgery', options)
```
The GSA → mask → calibration pipeline is identical regardless of patient.

---

## 4. How to Run

```matlab
% Start parallel pool (optional, for faster fmincon)
parpool('local', 6);
setenv('ASD_CALIB_PARALLEL_FMINCON', '1');

% Enable Group C (ventricular extension if Stage A insufficient)
setenv('ASD_CALIB_ALLOW_GROUPC', '1');

% Run
run('scripts/run_zoya_asd_calibration.m');
```

Without environment variables, the script defaults to:
- Serial fmincon
- Group C OFF
- Weights and MAP guard active (they are in the code, not env-var-gated)

---

## 5. Success Criteria

| Criterion | Threshold |
|---|---|
| RMSE | < 0.10 (primary targets) |
| MAP | Remains within [85, 95] mmHg |
| Qp/Qs | Approaches 3.79 (currently 1.42 baseline) |
| No plausibility FAIL | All calibrated params inside bounds |
| No validity gate FAIL | All 11 gates pass |
| Clinical fit gate | No metric worsened beyond tolerance |

---

## 6. If v2 Still Fails

If RMSE remains > 0.10 after these changes:

1. **Atrial/preload expansion** — manually add E.LA.EB, V0.LA, V0.RA to the mask.
   The current pipeline selects from GSA ranking only; atrial parameters that
   directly control P_LA - P_RA may need explicit addition for ASD physiology.
2. **Multi-start fmincon** — run from 3-5 different starting points.
3. **Increase fmincon budget** — MaxFunEvals 2500 → 5000.
4. **Document as limitation** — the model cannot simultaneously match extreme
   shunt severity (Qp/Qs=3.79) and systemic pressure with available parameters.
   This is a valid scientific finding, not a failure.
