# ASD Objective Calibration Design

Date: 2026-06-01

The ASD objective is now implemented in:

```text
src/calibration/objective_calibration_asd.m
```

`src/calibration/asd_calibration_objective.m` remains only as a
backward-compatible wrapper.

## Why It Mirrors VSD But Is Not a Copy

The Hafiz-Keisya VSD objective uses target tiers, clinical guards, validity
penalties, and parameter plausibility penalties. ASD needs the same
architecture, but the shunt mechanism is different:

- VSD shunt driver: ventricular LV-to-RV pressure relationship.
- ASD shunt driver: atrial LA-to-RA pressure relationship.
- Current ASD mode: orifice flow, so `asd.Cd` is the active shunt parameter.
- `R.asd` is not the active knob in orifice mode.

## Objective Components

Primary pressure-flow bundle:

- `QpQs`
- `Qp_Lmin`
- `Qs_Lmin`
- `SAP_mean`
- `PAP_mean`
- `LAP_mean`

Secondary pressure guard bundle:

- `SAP_max`
- `SAP_min`
- `PAP_max`
- `PAP_min`

ASD shunt mechanism guard:

- pre-closure `Q_ASD_Lmin` should be positive when a left-to-right ASD is expected.
- pre-closure `QpQs` should remain above 1.
- opposite direction is a physiological warning, not automatically a solver failure.

Parameter plausibility:

- penalizes parking near lower/upper bounds.
- optionally penalizes excessive movement from seeded baseline.

Validity penalties:

- solver failure.
- no steady state.
- NaN/Inf outputs.
- broad nonphysiological pressure/flow/EF envelopes.

## Excluded Targets For Zoya Pre-Closure

LV/RV volume and EF outputs remain prediction-only for Patient Zoya
pre-closure because the clinical targets are missing. They should not drive
ventricular elastance or V0 calibration unless new clinical data are added.

## Calibration Boundary

The objective is ready for future optimization, but this governance phase
does not run optimization or change parameters.
