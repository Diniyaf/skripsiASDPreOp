# ASD Pipeline Governance

Date: 2026-06-01

This note records the patient-generic ASD workflow before thesis-level GSA
and calibration. The goal is to mirror the Hafiz-Keisya unified VSD staged
methodology while preserving ASD-specific physiology.

## Staged Workflow

```text
adult healthy baseline
-> pediatric scaling
-> ASD clinical seeding
-> ASD case calibration profile
-> target-tier governance
-> curated ASD parameter library
-> curated ASD GSA
-> ST-based active mask
-> staged calibration with validity gates
```

This is equivalent in structure to the VSD pattern:

```text
baseline/scaling
-> clinical mapping
-> initial GSA
-> optimization mask
-> masked calibration
-> validation/final reporting
```

## VSD-to-ASD File Mapping

| Unified VSD component | ASD component | Adaptation |
|---|---|---|
| `main_run.m` orchestration | `run_asd_patient_case.m` plus wrapper scripts | ASD context is patient-generic; Zoya scripts are wrappers. |
| `build_case_calibration_profile.m` | `build_asd_case_calibration_profile.m` | ASD profile records shunt, pressure-flow, and sparse-volume limitations. |
| `build_target_tiers.m` | `build_asd_target_tiers.m` | ASD tiers use Qp/Qs, Qp, Qs, MAP, PAP, LAP, and shunt-direction governance. |
| `calibration_param_sets.m` / registry | `asd_candidate_param_sets.m` plus `build_asd_curated_parameter_library.m` | ASD uses `asd.Cd` in orifice mode and Group A/B/C physiology. |
| `create_optimization_mask.m` | `build_asd_active_mask_from_gsa.m` | ASD adds target-tier filtering and Group C governance. |
| `objective_calibration.m` | `objective_calibration_asd.m` | ASD objective has pressure-flow bundles and ASD shunt mechanism guards. |
| `run_calibration.m` | `scripts/run_zoya_asd_calibration.m` | Zoya wrapper calls patient-generic context and ASD objective. |
| `src/gsa/*` | `scripts/run_zoya_asd_gsa_curated.m` | Curated A+B+C Sobol screening; no optimization. |

## Patient Generic Design

Patient-specific data should enter only through:

```matlab
run_asd_patient_case(@patient_zoya, 'zoya', 'pre_surgery', options)
```

For a future patient, the intended change is the patient function and label,
not the objective or target-tier logic.

## Zoya Case Classification

Patient Zoya pre-closure is classified as:

```text
pressure_flow_preclosure_sparse_volume
```

because Qp/Qs, Qp, Qs, MAP, PAP, and LAP are available, while LV/RV volumes,
EF, RAP, PVR, SVR, direct Q_ASD, and ASD pressure gradient are missing.

## Methodological Boundary

This governance refactor does not tune parameters, run optimization, or
change model equations. It only makes the GSA and calibration setup more
traceable and reusable.
