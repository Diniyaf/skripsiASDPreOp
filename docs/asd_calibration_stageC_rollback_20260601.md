# Patient Zoya ASD Calibration Run - Stage C Rollback Analysis

**Date:** 2026-06-01  
**Run folder:** `results/calibration/zoya_asd_calib_20260601_225554`  
**GSA source:** `results/tables/zoya_asd_gsa_curated_20260601_193817.mat`  
**Scenario:** Patient Zoya ASD pre-closure  
**Mode:** Calibration only; no equation changes; post-closure/Jovano not used

---

## 1. What Happened

The calibration runner loaded the latest curated ASD GSA result with `N=128`
and built an active mask from Sobol ST plus ASD target-tier governance.

Because `ASD_CALIB_ALLOW_GROUPC=1` was active, the runner selected six
parameters:

| Parameter | Group | Role |
|---|---|---|
| `V0.SVEN` | Group B | systemic venous reservoir / preload |
| `R.SC` | Group A | systemic capillary resistance |
| `C.SVEN` | Group B | systemic venous compliance / preload |
| `R.PCOX` | Group A | oxygenated pulmonary capillary resistance |
| `E.RV.EB` | Group C | RV passive elastance, exploratory only |
| `E.LV.EB` | Group C | LV passive elastance, exploratory only |

The runner then performed:

1. Baseline simulation.
2. Stage A calibration using the four non-ventricular selected parameters:
   `V0.SVEN`, `R.SC`, `C.SVEN`, `R.PCOX`.
3. Stage C exploratory calibration by adding `E.RV.EB` and `E.LV.EB`.
4. Post-calibration validity gates.
5. Clinical fit guard.
6. Parameter plausibility check.
7. Rollback/accept decision.

The ODE remained numerically stable. Stage C passed the 11 hard validity gates,
but it failed the clinical fit guard. Therefore the accepted candidate was
rolled back to the baseline `params0_ASD_pre`.

---

## 2. Baseline vs Stage A vs Stage C

| Metric | Target | Baseline | Stage A | Stage C |
|---|---:|---:|---:|---:|
| Qs_Lmin | 3.23 | 2.536 | 3.836 | 2.595 |
| Qp_Lmin | 12.266 | 3.608 | 5.128 | 6.865 |
| SAP_mean | 90 | 90.34 | 82.62 | 67.64 |
| PAP_mean | 23 | 18.81 | 19.87 | 23.07 |
| LAP_mean | 14 | 6.925 | 9.356 | 9.322 |
| QpQs | 3.79 | 1.423 | 1.337 | 2.646 |
| RMSE | lower is better | 0.4515 | 0.3933 | 0.2878 |

Stage A improved RMSE modestly, but it did not improve shunt severity:
`QpQs` actually decreased from 1.423 to 1.337. It increased both Qp and Qs,
but Qs increased enough that the ratio did not move toward the clinical target.

Stage C improved Qp, PAP_mean, and Qp/Qs more strongly, but it did so by
damaging the systemic pressure state. The MAP/SAP_mean target was initially
excellent at baseline and became clearly unacceptable after Stage C.

---

## 3. Rollback Reason

The runner correctly applied rollback because the clinical fit guard failed:

| Guard | Baseline error | Stage C error | Interpretation |
|---|---:|---:|---|
| SAP_mean | 0.4% | 24.8% | MAP was good at baseline, then destroyed |
| SAP_max | 8.2% | 28.2% | SBP guard worsened beyond tolerance |
| SAP_min | 9.6% | 22.3% | DBP guard worsened beyond tolerance |
| PAP_min | 20.3% | 40.2% | Pulmonary diastolic pressure also worsened |

The rollback was scientifically appropriate. A lower global RMSE is not enough
to accept a calibrated parameter set if it sacrifices a measured variable that
was already close to the clinical target.

Accepted output therefore equals the baseline output:

`accepted_candidate = accepted_candidate_rollback_to_baseline`

---

## 4. Parameter Behavior

Stage A fitted values:

| Parameter | Initial | Fitted |
|---|---:|---:|
| `V0.SVEN` | 564.705 | 563.806 |
| `R.SC` | 1.756 | 0.929 |
| `C.SVEN` | 13.665 | 6.833 |
| `R.PCOX` | 0.138 | 0.058 |

Stage C fitted values:

| Parameter | Initial | Fitted | Comment |
|---|---:|---:|---|
| `V0.SVEN` | 564.705 | 563.783 | essentially unchanged |
| `R.SC` | 1.756 | 1.144 | reduced from baseline |
| `C.SVEN` | 13.665 | 6.853 | near lower bound warning |
| `R.PCOX` | 0.138 | 0.055 | near lower bound warning |
| `E.RV.EB` | 0.137 | 0.082 | near lower bound warning |
| `E.LV.EB` | 0.176 | 0.241 | moved upward, still inside bounds |

The boundary warnings are meaningful. The optimizer pushed several parameters
to the edge of the allowed physiological space, which suggests it was trying to
force shunt severity using limited handles rather than finding a robust
patient-specific operating point.

---

## 5. Scientific Interpretation

This run shows a real trade-off:

- The model can increase Qp/Qs and match PAP_mean better.
- But with the current objective and active set, it achieves this by lowering
  systemic pressure too much.
- `asd.Cd` was not selected by N=128 GSA because the model is not mainly
  orifice-limited; it is operating-point limited.
- The limiting physiology appears to be preload and atrial/ventricular pressure
  balance, not simply ASD size.

The most important observation is that Zoya's clinical target requires a very
large shunt:

`Q_ASD_target approximately Qp - Qs = 12.266 - 3.23 = 9.04 L/min`

The baseline model produced only about `1.07 L/min`, and Stage C still only
reached approximately:

`Q_ASD_StageC approximately 6.865 - 2.595 = 4.27 L/min`

So even the exploratory ventricular extension did not reach the clinical shunt
target.

---

## 6. Why This Happened

### 6.1 The objective still lets systemic pressure be sacrificed during search

`SAP_mean` is in the primary target bundle, but it competes numerically with
large errors in Qp, Qp/Qs, and LAP. Because Qp/Qs and Qp are far from target,
the optimizer can lower the total objective by improving pulmonary/shunt
metrics even while worsening MAP. The post-hoc clinical fit guard correctly
catches this, but only after optimization.

### 6.2 Group C is influential but weakly identifiable

`E.RV.EB` and `E.LV.EB` strongly affect Qp/Qs in the GSA, but Patient Zoya
does not have pre-closure LV/RV volume or EF targets. That means ventricular
elastance changes can improve pressure-flow targets while producing an
unverifiable ventricular operating point. This is why Group C must remain
exploratory unless guarded tightly.

### 6.3 Current active set cannot raise LAP enough

LAP_mean moved from 6.925 to only about 9.3 mmHg, still far below the 14 mmHg
target. A large left-to-right ASD shunt requires the LA/RA pressure relation to
support high net LA-to-RA flow. The current selected parameters mostly affect
vascular/preload balance and ventricular filling, but they did not create a
clinically consistent atrial pressure state.

### 6.4 Some fitted parameters reached warning zones

`C.SVEN`, `R.PCOX`, and `E.RV.EB` were near their lower bounds. This is a sign
that the optimizer is pressing against the allowed model space. When several
parameters hit edges but the target remains unmatched, the problem may require
better constraints, additional physiologically justified handles, or target
reconciliation, not simply more optimization.

---

## 7. What Not To Do

Do not accept the Stage C candidate just because RMSE improved.

Do not disable the clinical fit guard. The guard is doing its job: preserving
measured systemic pressure that was already close to target.

Do not freely open Group C as the main calibration solution. Ventricular
parameters are sensitive, but Zoya lacks the volume/function data needed to
identify them safely.

Do not interpret the accepted CSV as the calibrated best candidate. Because
rollback occurred, the accepted CSV intentionally equals baseline. The best
candidate information is stored in the MAT package and console log.

---

## 8. Recommended Next Strategy

### Step 1 - Preserve this run as evidence

Treat this run as evidence that:

- GSA-based active masking works.
- Stage C can improve RMSE.
- The validity gates pass numerically.
- The clinical fit guard correctly rejects a physiologically unsafe trade-off.

### Step 2 - Move systemic pressure protection into the objective

Before rerunning Stage C, the objective should penalize destruction of already
good systemic pressure more strongly during optimization, not only reject it
afterward.

Recommended policy:

- If baseline SAP_mean error is already <5%, impose a hard or high-weight guard
  that keeps SAP_mean within a clinically acceptable band.
- Keep SBP/DBP as secondary guards with stronger penalty when they worsen.
- Preserve MAP near 90 mmHg while optimizing Qp, Qp/Qs, PAP_mean, and LAP_mean.

This follows the same scientific logic as the rollback guard but gives the
optimizer a chance to search inside the clinically acceptable region.

### Step 3 - Rerun Stage A with Group C off as an official non-ventricular result

Run once with:

`ASD_CALIB_ALLOW_GROUPC = 0`

This gives a clean Stage A-only result for the thesis: vascular/preload
parameters alone improve RMSE modestly but cannot reproduce severe shunt.

### Step 4 - If Stage A is insufficient, run guarded exploratory Stage C

Only after Step 2 should Group C be re-enabled:

`ASD_CALIB_ALLOW_GROUPC = 1`

This should be reported as exploratory because LV/RV volume and EF targets are
missing. If used, Stage C must be accepted only if systemic pressure guards pass.

### Step 5 - Consider a targeted atrial/preload expansion

If guarded Stage C still cannot raise LAP and Qp/Qs without damaging MAP, the
next scientific candidate class should be atrial/preload mechanics, not wider
ventricular tuning.

Potential exploratory handles, only with tight bounds and clear rationale:

- `E.LA.EB`
- `E.RA.EB`
- `V0.LA`
- `V0.RA`
- pulmonary venous compliance/reservoir parameters if supported

Reason: ASD shunt depends directly on the LA-RA pressure relationship, and the
current run could not raise LAP_mean enough.

### Step 6 - Recheck clinical target consistency and definitions

Before further tuning, confirm:

- Qp, Qs, and Qp/Qs are from the same cath/Fick source.
- Model Qp and Qs definitions match clinical Qp and Qs definitions.
- LAP_mean target is a true measured LA/wedge pressure and not a phase-specific
  or procedural value.
- RFA/cath pressure source remains the selected systemic pressure source.

The clinical targets are internally consistent (`12.266 / 3.23 = 3.80`), but
the model still cannot reach them without pressure trade-offs, so target-source
definition matters.

---

## 9. Current Scientific Verdict

**Accepted candidate:** baseline, due rollback.  
**Best numerical candidate:** Stage C, RMSE 0.2878, but scientifically rejected.  
**Model status:** stable, ASD active, calibration framework functioning.  
**Main unresolved issue:** severe shunt target cannot yet be matched while
preserving systemic pressure and left atrial pressure targets.

The next defensible move is not to accept Stage C. The next move is to improve
the objective/guard structure so the optimizer searches only within acceptable
systemic-pressure physiology, then rerun Stage A and a guarded exploratory
Stage C if needed.

