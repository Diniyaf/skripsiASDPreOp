# Diniya vs Jovano — Deep Calibration Comparison (Post-Calibration Results)

**Date:** 2026-06-02  
**Update:** Added after Jovano's post-closure calibration results were obtained (RMSE 0.0015)  
**Existing comparison:** `docs/diniya_vs_jovano_codebase_comparison.md` (structural comparison)

---

## 1. Summary of Findings

Jovano's RMSE 0.0015 is NOT evidence that his methodology is superior. It's evidence
that **post-closure + manual pre-tuning = fundamentally easier problem**.

## 2. The "Secret Sauce" — Manual Pre-Tuning

Jovano's baseline is NOT pure pediatric scaling. His `patient_post_asd_parameters.m`
applies **6 multiplicative overrides + 3 hardcoded values** on top of scaling:

```matlab
% Ventricular overrides (applied after scaling):
params.Emax_lv = params.Emax_lv * 1.30;   % ↑30% systolic
params.Emin_lv = params.Emin_lv * 1.15;   % ↑15% diastolic stiffness
params.Emax_rv = params.Emax_rv * 0.80;    % ↓20% RV systolic (unloaded post-closure)
params.Emin_rv = params.Emin_rv * 0.83;    % ↓17% RV diastolic
params.V0_rv   = params.V0_rv * 1.59;      % ↑59% RV unstressed volume

% Vascular overrides:
params.R_sa = params.R_sa * 1.25;   % SVR ↑25%
params.R_pa = params.R_pa * 0.67;   % PVR ↓33%
params.C_sv = params.C_sv * 1.35;   % Venous compliance ↑35%

% Specific hardcoded values:
params.R_pc = 0.023874809;
params.C_pv = 8.360275392;
params.C_pa = 4.410649463;
```

**Result:** Baseline RMSE = 0.0053 — already near-perfect before any calibration.
The 4-parameter fmincon only polishes from 0.0053 → 0.0015.

### Comparison: Diniya Has NO Manual Tuning

| | Jovano | Diniya |
|---|---|---|
| Baseline source | Pediatric scaling **+ 6 manual overrides + 3 hardcoded values** | Pediatric scaling only |
| Baseline RMSE | **0.0053** (near-perfect) | **0.45** (large gap) |
| Calibration role | Polish (0.0053 → 0.0015) | Find operating point (0.45 → 0.35) |
| RMSE improvement | **72%** | **22%** |

---

## 3. Calibration Methodology Comparison

| Aspect | Jovano | Diniya |
|---|---|---|
| **GSA params** | 28, uniform ±30% | 25, VSD-adapted asymmetric bounds |
| **GSA N** | 128 (3,840 evals) | 128 (3,456 evals) |
| **Active selection** | Top-4 by sum ST (all 24 outputs) | ST ≥ threshold + manual expansion (atrial, shunt) |
| **Optimizer** | fmincon SQP | fmincon interior-point + LBFGS |
| **Targets** | 12 metrics (CO, LVEDV, LVESV, LVSV, LVEF, RVEDV, RVESV, RVSV, RVEF, Qp_Qs, PAP_mean, HR) | 6 primary + 5 secondary = 11 total |
| **Objective** | Simple unweighted MSRE: `mean((sim-clin)/clin)²` | Multi-term: primary + secondary + shunt_guard + MAP_guard + ratio_guard + RAP_guard + drift + plausibility + boundary + validity |
| **Weights** | None in pipeline; separate manual RV-weighted pass | QpQs 5×, Qp 3×, LAP 2× |
| **Guards** | None | 5 guards + 11 validity gates + clinical fit gate |
| **Rollback** | None | 3-level (best → scientific → accepted) |
| **ExitFlag** | 1 (converged) | 2 (step tolerance — may be local minimum) |

---

## 4. Why Post-Closure Is Inherently Easier

| Factor | Post-Closure (Jovano) | Pre-Closure (Diniya) |
|---|---|---|
| **Shunt status** | Closed (R_ASD = 1e9) | Active orifice (Cd = 0.63) |
| **Qp/Qs** | ≈ 1.0 (by definition) | Must match 3.79 (extreme) |
| **Model complexity** | Closed circuit — healthy baseline already correct | Open shunt — pathological state far from baseline |
| **Volume data** | LVEDV, LVESV, RVEDV, RVESV, LVEF, RVEF | None |
| **Data → parameter mapping** | Direct: volumes → E, V0 | Indirect: pressures → flows → ΔP → shunt |
| **Baseline gap** | Tiny (0.0053) | Large (0.45) |

---

## 5. What Diniya Can Learn from Jovano

| Lesson | Applicable to Diniya? |
|---|---|
| **Manual pre-tuning** could help baseline | ⚠ Risk: overfitting without clinical justification. "Manual tuning" = trial-and-error, not reproducible. Diniya's approach is more defensible for thesis |
| **Simple unweighted MSRE works** when baseline is already close | Works for Jovano because baseline RMSE 0.0053. Would NOT work for Diniya (baseline 0.45) — unweighted would let QpQs drift while improving MAP |
| **Top-4 GSA selection** | Diniya HAS this — but sparser data means more params needed |
| **ExitFlag=1 (converged)** | Suggests Jovano's landscape is convex around baseline. Diniya's landscape is more complex (exitflag=2, step tolerance) |

---

## 6. What Jovano Can Learn from Diniya

| Lesson | Applicable to Jovano? |
|---|---|
| **Guards prevent spurious solutions** | Jovano's simple MSRE could accept a solution that improves RVEF by collapsing CO. His exitflag=1 + good RMSE suggest this didn't happen, but it COULD for another patient |
| **Parameter plausibility** | Jovano has no plausibility check — a calibrated Emax_rv=0.001 or C_sa=50 would pass his objective |
| **Target-tier governance** | If Jovano had a metric with unreliable data, he has no mechanism to exclude it |

---

## 7. Bottom Line

Jovano's RMSE 0.0015 and Diniya's RMSE 0.35 are answering **different questions:**

| Jovano | Diniya |
|---|---|
| "Given a pre-tuned baseline, can 4-parameter optimization polish it to 0.0015?" | "Can GSA-driven staged calibration find a physiologically valid ASD operating point from scaling alone?" |
| Answer: **Yes** (trivial) | Answer: **Partially** (22% improvement, documented limitations) |

Diniya's result is **more scientifically meaningful** because it starts from an UNBIASED baseline and demonstrates exactly where the model succeeds and where it fails.
