# ASD Lumped-Parameter Model — Complete Workflow & Patient-Generic Design

**Date:** 2026-06-02  
**Purpose:** Explain the end-to-end pipeline, why each component is patient-generic,
and how the framework supports future patients without code changes.

---

## 1. The Big Picture — End to End

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SHARED INFRASTRUCTURE                            │
│  (same for ALL patients — adult, pediatric, ASD, VSD)                   │
│                                                                         │
│  config/default_parameters.m     Adult healthy baseline (Valenti 2023)  │
│  src/models/system_rhs.m         14-state RLC ODE + ASD shunt coupling  │
│  src/models/asd_shunt_model.m    Orifice/linear bidirectional shunt     │
│  src/models/elastance_model.m    Time-varying chamber elastance         │
│  src/models/valve_model.m        Smooth tanh valve switching            │
│  src/solvers/integrate_system.m  ode15s with batch integration          │
│  src/utils/apply_scaling.m       Lundquist BSA pediatric scaling        │
│  src/utils/compute_clinical_indices.m  26-metric output computation     │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     PATIENT-SPECIFIC INPUT                              │
│  (one file per patient)                                                 │
│                                                                         │
│  config/patient_zoya.m           Demographics + clinical measurements   │
│  config/patient_xxx.m            Next patient — different data          │
│  config/patient_template.m       Empty template for new patients        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PIPELINE — GENERIC FOR ALL PATIENTS                  │
│                                                                         │
│  STEP 1: Pediatric Scaling                                              │
│    run_asd_patient_case(@patient_fn, label, scenario)                   │
│    → BSA allometry → params_scaled (auto)                              │
│                                                                         │
│  STEP 2: Clinical Seeding                                               │
│    params_from_clinical(params_scaled, clinical)                        │
│    → Map HR, ASD geometry, Qp/Qs → params0_ASD_pre                      │
│                                                                         │
│  STEP 3: Target Tier Governance                                         │
│    build_asd_target_tiers(clinical)                                     │
│    → Classify metrics: hard_primary / soft_secondary / prediction_only  │
│    → Auto-adapts to available data per patient                          │
│                                                                         │
│  STEP 4: Curated Parameter Library                                      │
│    build_asd_curated_parameter_library(params0, caseProfile)           │
│    → Groups A+B+C with registry bounds                                  │
│    → Bounds fixed per parameter class (not per patient)                 │
│                                                                         │
│  STEP 5: GSA (Sobol Monte Carlo)                                        │
│    run_zoya_asd_gsa_curated.m (edit patient reference)                 │
│    → 25 params, N=128, Saltelli/Jansen, bootstrap CI                    │
│    → Output: ST matrix → ranking → active mask                          │
│                                                                         │
│  STEP 6: Calibration                                                    │
│    run_zoya_asd_calibration.m (edit patient reference)                  │
│    → Load GSA → build mask → Stage A fmincon → Stage C fmincon          │
│    → Post-cal: validity (11 gates) → clinical fit → plausibility        │
│    → 3-level rollback → ACCEPTED or ROLLBACK                            │
│                                                                         │
│  STEP 7: Output                                                        │
│    asd_output_table(sim, params, clinical)                              │
│    → 26-metric panel: baseline vs calibrated, target vs error           │
│    → CSV + MAT export                                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Why It Must Be Patient-Generic

### The Core Principle

**The pipeline is the contribution. The Zoya results are the validation.**

If the pipeline only works for Zoya, it's not a research contribution — it's
curve-fitting. If it works for any ASD patient (with their own data), it's a
**calibration framework** that can be cited, reused, and extended.

### What Changes Per Patient

| Component | Patient A (Zoya) | Patient B (new) |
|---|---|---|
| **Clinical data** | QpQs=3.79, MAP=90, PAP=23, LAP=14, no volume | Whatever is available — auto-detected |
| **Target tiers** | 6 hard_primary, 4 soft, rest prediction-only | Auto-built from data availability |
| **GSA ranking** | V0.SVEN top, Cd insensitive at 19mm | Will differ — smaller ASD → Cd more sensitive |
| **Active set** | 9 params (GSA + atrial expansion) | Auto-selected by GSA mask |
| **Calibration result** | RMSE 0.35 accepted | Different RMSE — depends on data completeness |

### What Stays Identical

| Component | Why |
|---|---|
| **ODE model** (14-state, ASD shunt) | Same physiology for all ASD patients |
| **Pediatric scaling** (Lundquist BSA) | Same allometric law |
| **Bounds registry** | Same literature-cited bounds per parameter class |
| **Objective function** | Same multi-term: RMSE + guards + plausibility |
| **11 validity gates** | Same physiological checks |
| **Rollback logic** | Same 3-level governance |
| **Output format** | Same 26-metric panel |

---

## 3. How to Run a New Patient

### Step 1: Create Patient File

```matlab
% config/patient_xxx.m
function clinical = patient_xxx()
    clinical.common.age_years = ...;
    clinical.common.weight_kg = ...;
    clinical.common.BSA = ...;
    clinical.common.HR = ...;
    
    clinical.pre_surgery.QpQs = ...;
    clinical.pre_surgery.PAP_mean_mmHg = ...;
    % ... fill all available fields, leave NaN for missing
end
```

### Step 2: Run GSA (1 hour, parallel 6-worker)

```matlab
% Edit run_zoya_asd_gsa_curated.m:
%   Line 65: @patient_zoya → @patient_xxx
%   Line 65: 'zoya' → 'xxx'
% Then run:
run('scripts/run_zoya_asd_gsa_curated.m');
```

### Step 3: Run Calibration (30 min, parallel fmincon)

```matlab
% Edit run_zoya_asd_calibration.m:
%   Line 89: @patient_zoya → @patient_xxx
%   Line 89: 'zoya' → 'xxx'
% Then run:
setenv('ASD_CALIB_ALLOW_GROUPC', '1');
run('scripts/run_zoya_asd_calibration.m');
```

### Step 4: Review Output

```matlab
% Auto-generated:
%   results/calibration/zoya_asd_calib_*/zoya_asd_calibrated_*.csv
%   → 26 metrics: model vs target, error%, status
```

---

## 4. Robustness Guarantees — Built Into the Architecture

### Guard 1: Target Tiers Auto-Adapt

```matlab
% build_asd_target_tiers.m checks EVERY clinical field:
if isfinite(src.QpQs)          → hard_primary
if isfinite(src.LVEDV_mL)      → hard_primary (volume target exists!)
if isnan(src.LVEDV_mL)         → excluded_missing_volume_function
```

**Effect:** A patient with volume data automatically gets LVEDV as primary target.
A patient without it (like Zoya) automatically excludes it. No manual
classification needed.

### Guard 2: Parameter Bounds from Literature

```matlab
% asd_candidate_param_sets.m → policy_for(name):
'R.SAR' → 'resistances_kung2013'     → [0.40×, 2.50×]
'E.LV.EA' → 'ventricular_elastance_lv' → [0.60×, 2.20×]
'asd.Cd' → 'physical_Cd'              → [0.20, 1.20]
```

**Effect:** A parameter that reaches its bound during calibration triggers
WARNING (within 10%) or FAIL (outside). This happens automatically for any
patient — the bounds don't care whose data is being fitted.

### Guard 3: GSA Mask Is Patient-Specific

```matlab
% build_asd_active_mask_from_gsa(gsa_data, library, target_tiers):
optMask = ST_max >= threshold;  % threshold = 0.05
```

**Effect:** Zoya's active set = 12 params (V0.SVEN dominant, Cd insensitive).
Next patient's active set = whatever their GSA says. The algorithm is identical;
only the input data changes.

### Guard 4: Validity Gates Are Patient-Agnostic

```
11 checks:
  1-6: Universal (steady state, finite, volumes > 0, etc.)
  7-8: PVR/SVR bounds [0.1, 20], [0.5, 50]
  9:   EF bounds [0.05, 0.95]
  10:  ASD geometry [0, 500] mm²
  11:  Shunt direction (bidirectional when gradient exists)
```

**Effect:** Whether the patient is Zoya or someone else, the same 11 checks run.
No patient-specific thresholds hidden in the code.

### Guard 5: Rollback Is Automatic

```matlab
if RMSE worsened OR validity failed OR plausibility failed
    → accepted = baseline  (ROLLBACK)
else
    → accepted = calibrated (ACCEPTED)
```

**Effect:** A spurious calibration result (like v2/v3) is automatically rejected,
regardless of which patient. The framework protects itself.

---

## 5. Why This Matters for Your Thesis

### Research Contribution Statement

> *"This thesis presents a GSA-driven staged calibration framework for
> patient-specific lumped-parameter modeling of atrial septal defect. The
> framework adapts the Hafiz-Keisya VSD methodology to ASD physiology, adding
> ASD-specific shunt modeling, target-tier governance for sparse clinical data,
> and physiological guard mechanisms. The framework was validated on Patient
> Zoya (primary case) and is designed for direct application to additional
> patients without modification of core algorithms."*

### What You Can Claim

| Claim | Evidence |
|---|---|
| Framework is reproducible | Seed=42, documented pipeline, same code for all patients |
| Framework is generalizable | Only patient file changes between patients |
| Framework prevents overfitting | v1-v3 rollback demonstrates guard effectiveness |
| Framework identifies its own limits | LAP bottleneck documented, not hidden |
| Framework is physiology-aware | Atrial expansion justified by mechanism, not by RMSE |

### What You Should NOT Claim

| Avoid | Why |
|---|---|
| "Model perfectly fits Zoya" | RMSE 0.35, Qp/Qs still 40% error |
| "Model works for all ASD patients" | Only validated on 1 patient so far |
| "Calibration is fully automated" | Atrial expansion was manual; future patients may need similar guidance |

---

## 6. Future Roadmap — After Zoya

```
Zoya (done):
  ✅ GSA N=128
  ✅ Calibration v1→v4
  ✅ ACCEPTED candidate

Patient X (primary #2, next):
  □ Create patient_xxx.m
  □ Run GSA N=128
  □ Run calibration
  □ Compare active set vs Zoya

Patient Y (shared with Jovano):
  □ Pre calibration (Diniya)
  □ Export seed to Jovano
  □ Post calibration (Jovano)
  □ Cross-validate pre/post

Patients 4-7 (batch):
  □ Sequential GSA + calibration
  □ Cross-patient comparison table
  □ Identify common active parameters vs patient-specific ones
```
