# ASD Calibration Implementation — Complete Reference

**Date:** 2026-06-04 (updated)  
**Status:** Production — validated on 2 patients (Zoya, Indira)  
**Replaces:** `asd_calibration_improvements_v2.md` (merged)

---

## 1. Overview

GSA-driven staged calibration framework for ASD pre-closure, adapted from
Hafiz-Keisya unified VSD. Patient-generic — same code for all patients,
auto-detects shunt mode (orifice vs linear), target tiers adapt to data
availability.

### Files

| File | Role |
|---|---|
| `scripts/run_zoya_asd_calibration.m` | Reference implementation (Zoya) |
| `scripts/run_indira_asd_calibration.m` | Patient-generic copy (Indira) |
| `src/calibration/objective_calibration_asd.m` | Multi-term objective function |
| `src/calibration/asd_candidate_param_sets.m` | Mode-aware parameter library + bounds |
| `src/calibration/build_asd_active_mask_from_gsa.m` | GSA→calibration mask builder |
| `src/calibration/build_asd_target_tiers.m` | Auto-detect data→target classification |
| `run_asd_patient_case.m` | Generic patient context builder |

---

## 2. Calibration Workflow

```
run_*_asd_calibration.m
  │
  ├─[1] LOAD baseline (run_asd_patient_case → params0_ASD_pre)
  │
  ├─[2] LOAD GSA results (auto-find latest curated GSA .mat)
  │
  ├─[3] BUILD active mask from GSA Sobol ST
  │     ├─ ST ≥ 0.05 threshold (configurable)
  │     ├─ Force shunt param (asd.Cd or R.asd, mode-aware)
  │     ├─ Min 5 non-ventricular params
  │     ├─ Group C: monitor-only unless ASD_CALIB_ALLOW_GROUPC=1
  │     └─ Stage A = non-ventricular mask ∩ selected
  │         Stage C = ventricular mask ∩ selected (exploratory)
  │
  ├─[4] BASELINE simulation → RMSE_baseline
  │
  ├─[5] STAGE A — fmincon (interior-point + LBFGS)
  │     → Optimize non-ventricular active params
  │     → Stage A RMSE
  │
  ├─[6] STAGE A GATE
  │     RMSE_A < 0.10?
  │       YES → skip Stage C
  │       NO  → proceed to Stage C (if Group C params available)
  │
  ├─[7] STAGE C — fmincon (if applicable)
  │     → Add ventricular params to active set
  │     → Optimize full set from Stage A starting point
  │
  ├─[8] POST-CALIBRATION VALIDATION (11 gates)
  │     → Steady state, finite states, volumes ≥ 0, PVR/SVR/EF bounds
  │     → ASD geometry valid, shunt direction valid
  │
  ├─[9] CLINICAL FIT GUARD
  │     → Primary metrics: hard reject if worsened beyond tolerance
  │     → Secondary waveform: soft warning only (no rejection)
  │
  ├─[10] PARAMETER PLAUSIBILITY
  │     → OK / WARNING (near bound) / FAIL (outside bound)
  │
  └─[11] 3-LEVEL ROLLBACK
        RMSE improved + validity PASS + plausibility no FAIL + clinical fit PASS?
          YES → ACCEPTED
          NO  → ROLLBACK to baseline
```

---

## 3. Objective Function

`objective_calibration_asd.m` — multi-term, patient-generic:

```
J = J_primary                        error against clinical targets
  + λ_sec × J_secondary              waveform guard (soft)
  + λ_shunt × J_shunt_guard          Q_ASD direction, Qp/Qs ≥ 1
  + λ_pres × J_pressure_guard        prevent worsening of good metrics
  + λ_map × J_map_guard              MAP band [patient-specific]
  + λ_rap × J_rap_guard              RAP band [0, 15]
  + λ_ratio × J_ratio_guard          prevent Qp/Qs↑ via Qs↓ (ratio cheating)
  + λ_drift × J_parameter_drift      discourage movement from baseline
  + λ_plaus × J_plausibility         near-boundary penalty
  + λ_bound × J_boundary             outside-boundary penalty
  + J_validity                        physiological output envelope
  + J_ss                              steady-state failure
```

### Guards

| Guard | Lambda | Mechanism |
|---|---|---|
| MAP band | 5.0 | Soft penalty outside [default: 85,95] — patient-configurable |
| RAP band | 3.0 | Soft penalty outside [0,15] |
| Ratio chasing | 8.0 | Qp/Qs improves AND Qs drops >10% → penalty |
| Shunt mechanism | 1.0 | Q_ASD < 0 → penalty |
| Pressure preservation | 0.5 | Good metrics worsen >5% → penalty |

### Metric Weights

Auto-computed from baseline error: higher error → higher weight (1.0–2.0×).
Configurable per patient via `calib.metricWeights`.

---

## 4. Key Design Decisions

### 4.1 Mode-Aware Shunt (v2 fix)

| Mode | Shunt Parameter | How Detected |
|---|---|---|
| `orifice_bidirectional` (Zoya) | `asd.Cd` | Geometry available, no gradient |
| `linear_bidirectional` (Indira) | `R.asd` | ΔP + Q_shunt available |

Auto-detected by `configure_asd()` in `params_from_clinical.m`. Candidate
library and force-shunt logic are mode-aware.

### 4.2 ST Threshold (v2)

Lowered from 0.10 → **0.05** to capture borderline-sensitive vascular parameters.
Configurable per patient.

### 4.3 Mask Expansion (v2)

- Force active shunt parameter always (asd.Cd or R.asd)
- Minimum 5 non-ventricular params (auto-expand from ST ranking)
- Group C: monitor-only unless `ASD_CALIB_ALLOW_GROUPC=1`

### 4.4 Atrial Expansion (v4, Zoya-specific lesson)

Zoya required manual atrial expansion (V0.LA, V0.RA, E.LA.EB) after 3 failed
vascular-only calibrations. Indira did NOT — RAP+LAP already constrain atria.
This expansion is applied per-patient based on GSA evidence + physiological
judgment, not hardcoded.

### 4.5 Clinical Fit Gate — Secondary Waveforms

Primary metrics → hard reject. Secondary waveform extrema → **soft warning only.**
Justification: systolic/diastolic pressures have higher beat-to-beat variability
(±10-15%) than mean pressures (±3-5%). Rejecting candidates with excellent
primary fits because of waveform shape degradation prioritizes noise over signal.

### 4.6 Ratio-Chasing Guard (v3)

Prevents fmincon from "improving" Qp/Qs by collapsing systemic flow.
Reads target QpQs from `calib.targets.QpQs` (patient-generic, not hardcoded).

---

## 5. Differences from VSD Pipeline

| Aspect | VSD | ASD |
|---|---|---|
| **Stages** | A(vascular)→B(chamber)→C(top-5)→D(sys)→E(plaus)→F(valid) | A(vascular+preload)→C(ventricular, conditional) |
| **Stage B (chamber)** | Yes (volume targets exist) | Skipped (no volume data) |
| **Shunt modes** | VSD only (orifice/linear) | Orifice + linear, mode-aware |
| **Objective** | 10-term via `objective_calibration.m` | Multi-term via `objective_calibration_asd.m` |
| **Active set** | 17 params, GSA mask | Dynamic, patient-specific |
| **Clinical fit gate** | Primary + secondary, all hard reject | Primary = hard reject, secondary waveform = soft warning |
| **Recipe system** | Yes | Not yet (planned after accepted candidates) |
| **PCE surrogate** | Yes (UQLab) | No (direct Sobol Monte Carlo) |

---

## 6. Output Files Per Run

```
results/calibration/<patient>_asd_calib_YYYYMMDD_HHMMSS/
  ├─ *_calibration_*.mat           Full calibration package
  ├─ *_baseline_*.csv              26-metric baseline table
  ├─ *_calibrated_*.csv            26-metric accepted table
  ├─ *_best_candidate_*.csv        Best candidate metrics (if rejected)
  ├─ *_best_candidate_parameters_*.csv  Best candidate params
  ├─ *_rollback_decision_*.csv     Rollback audit
  └─ console_*.log                 Console diary
```

---

## 7. How to Run

```matlab
% Start pool (optional)
parpool('local', 6);
setenv('ASD_CALIB_PARALLEL_FMINCON', '1');
setenv('ASD_CALIB_ALLOW_GROUPC', '1');  % Enable ventricular extension

% Run (patient-specific script)
run('scripts/run_zoya_asd_calibration.m');
run('scripts/run_indira_asd_calibration.m');
```

---

## 8. Results Summary

| Patient | Iterations | Baseline RMSE | Accepted RMSE | Best RMSE |
|---|---|---|---|---|
| Zoya | 4 (v1→v4) | 0.45 | 0.35 (v4) | — |
| Indira | 1 | 0.20 | **0.042** (Stage C) | — |
