# ASD Curated GSA

Date: 2026-06-01

The main ASD GSA path is:

```text
scripts/run_zoya_asd_gsa_curated.m
```

The legacy file:

```text
scripts/run_zoya_asd_gsa_groupA.m
```

is retained only as a compatibility wrapper.

## Why Curated A+B+C GSA

The ASD GSA samples the curated candidate library across Groups A, B, and C,
then uses target-tier governance to decide which parameters should enter
calibration. This matches the VSD idea of screening first, then masking
calibration parameters from Sobol total-order sensitivity.

## Parameter Groups

Group A: shunt and vascular parameters.

- Most directly supported by Zoya pressure-flow targets.
- Includes `asd.Cd`, systemic vascular parameters, and pulmonary vascular
  parameters.

Group B: atrial and preload parameters.

- Important for ASD because Q_ASD depends on the LA-to-RA pressure gradient.
- Secondary because RAP and atrial volume data are missing for Zoya.

Group C: ventricular exploratory parameters.

- Included in GSA for monitoring.
- Not calibrated by default for Zoya because LV/RV volume and EF targets are
  missing.
- Can only be enabled explicitly with `ASD_CALIB_ALLOW_GROUPC=1`.

## Target Tiers

Hard primary targets:

- `QpQs`
- `Qp_Lmin`
- `Qs_Lmin`
- `SAP_mean`
- `PAP_mean`
- `LAP_mean`

Measured secondary guards:

- `SAP_max`
- `SAP_min`
- `PAP_max`
- `PAP_min`

Derived comparison:

- `Q_ASD_Lmin` from Qp minus Qs, unless direct shunt flow is reported.

## Reproducibility

The curated GSA runner records:

- random seed.
- sample size.
- sampling method.
- parameter bounds.
- target tiers.
- failed/nonstandard simulations.
- Sobol `S1` and `ST`.
- active-mask recommendation.

Small-N runs are smoke tests only. Thesis-level selection should use an
approved `N` after the governance workbook is reviewed.
