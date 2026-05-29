# ASD Clinical Seeding

## Purpose

Clinical seeding is the step that converts a pediatric healthy scaled
baseline into a patient-seeded ASD parameter set before any disease baseline
simulation is run.

For Patient Zoya pre-closure, the output of this phase is:

`params0_ASD_pre`

This is analogous to the Hafiz/Keisya VSD variable `params0` after:

`params0 = params_from_clinical(params_scaled, clinical, scenario, ...)`

## Workflow Position

Hafiz/Keisya unified VSD workflow:

adult healthy baseline
-> pediatric scaling
-> params_from_clinical
-> baseline disease simulation
-> GSA
-> optimization
-> calibrated operating point

ASD workflow used here:

adult healthy baseline
-> pediatric scaling
-> ASD clinical seeding
-> ASD baseline simulation
-> GSA
-> optimization
-> calibrated ASD operating point

This document covers only the ASD clinical seeding step. It does not cover
baseline simulation, GSA, optimization, calibration, or post-closure modeling.

## ASD-Specific Seeding

The active ASD model places the shunt between the left atrium and right atrium.

Sign convention:

`Q_ASD > 0` means LA -> RA.

The seeding function stores ASD geometry in:

- `params.asd.diameter_mm`
- `params.asd.area_mm2`
- `params.asd.location` if reported
- `params.asd.mode`
- `params.asd.mapping_status`

For Patient Zoya pre-closure, `ASD_diameter_mm` is available. The area is
computed as:

`ASD_area_mm2 = pi * (ASD_diameter_mm / 2)^2`

## Qp/Qs Is A Target, Not A Parameter

Clinical `QpQs` is stored as a target for later validation/calibration. It is
not forced into the ODE and it is not used to overwrite `Qp`, `Qs`, or
`Q_ASD`.

This matters because Qp/Qs is an emergent model output determined by shunt
flow, atrial pressure balance, venous return, chamber mechanics, vascular
resistances, and compliance.

## Why R_ASD Cannot Be Directly Computed

A linear ASD resistance can be computed from:

`R_ASD = DeltaP_ASD / Q_ASD`

only when both variables are directly available:

- LA-to-RA pressure gradient
- direct ASD shunt flow

For Patient Zoya pre-closure, the ASD diameter is available, but the ASD
pressure gradient and direct shunt flow are missing. Therefore, `R_ASD` is not
computed from `DeltaP/Q`.

If an open ASD baseline simulation needs a finite seed or an orifice model, the
mapping status must explicitly mark that choice as an uncalibrated seed, not a
calibrated patient-specific resistance.

## HR Override

The scaled pediatric baseline gives a prior HR. If clinical HR exists for the
selected scenario or `clinical.common`, it overrides the scaled HR. Timing
variables are recomputed from the final HR, including ventricular and atrial
activation durations.

The seeding report records:

- scaled HR before seeding
- final HR after seeding
- HR source
- recomputed timing values

## SVR, PVR, And Compliance

If `SVR_WU` or `PVR_WU` is reported, the corresponding vascular resistance
block can be seeded. If those fields are missing, the pediatric scaled
resistances are retained.

Compliance seeding is intentionally conservative:

- systemic arterial compliance requires systemic stroke volume or CO/HR plus
  systemic pulse pressure
- pulmonary arterial compliance requires pulmonary stroke volume or Qp/HR plus
  pulmonary pulse pressure

If required variables are missing, compliance seeding is skipped and documented.

## Chamber Tuning Is Disabled For Patient Z Pre-Closure

Patient Zoya pre-closure currently lacks LVEDV, LVESV, RVEDV, RVESV, LVEF, and
RVEF. Therefore, seeding does not tune:

- `E.LV`
- `E.RV`
- `V0.LV`
- `V0.RV`

Dummy literature ASD volumes are not used to tune Patient Z because the dummy
case is a cohort-median plausibility case, not patient-level calibration data.

## Initial Conditions And Blood Volume

After seeding, vascular unstressed volume is reconciled with the patient blood
volume target, and `build_initial_conditions` rebuilds the 14-state initial
condition vector.

If weight is missing in a future case but BSA is available, any model-only
weight estimate must be documented as a model input helper and must not be
written back as reported clinical data.

## Criteria Before Baseline ASD Simulation

Before moving to ASD pre-closure baseline simulation:

1. Patient Z pre-closure data load without error.
2. HR override is documented.
3. ASD diameter and area are stored.
4. Qp/Qs is stored as a target only.
5. R_ASD is not computed unless both DeltaP and direct Q_ASD exist.
6. Missing PVR/SVR do not crash the mapper.
7. Missing volumes do not trigger chamber tuning.
8. Initial conditions are finite and blood-volume reconciliation is documented.
9. A timestamped seeding workbook is generated.

