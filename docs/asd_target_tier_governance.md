# ASD Target-Tier Governance

## Purpose

Target-tier governance defines which Patient Zoya pre-closure clinical
measurements are allowed to guide GSA and later calibration. It is a
checkpoint before any optimisation so the model is not fitted to missing,
derived, weak, or physiologically inappropriate targets.

This phase does not tune parameters. It only classifies target outputs.

## Relationship to the Unified VSD Workflow

The Hafiz/Keisya VSD workflow separates parameter seeding, baseline disease
simulation, GSA, optimisation, and validation. The ASD workflow keeps that
same staged logic:

```text
healthy baseline
-> pediatric scaling
-> ASD clinical seeding
-> ASD baseline simulation
-> target-tier governance
-> GSA
-> optimisation later
```

The target-tier step prevents the GSA and later optimisation from using
outputs simply because the model can compute them. A model output should be
a fitting target only when there is defensible clinical evidence.

## Patient Zoya Primary Targets

Patient Zoya pre-closure currently has pressure-flow evidence, so the hard
primary targets are:

- `QpQs`
- `Qp_Lmin`
- `Qs_Lmin`
- `SAP_mean`
- `PAP_mean`
- `LAP_mean`

These targets are most relevant to the current baseline mismatch: the model
is stable and the ASD shunt is active, but shunt severity and pulmonary
flow are underestimated while MAP is already close to the clinical target.

## Soft Secondary Targets

The secondary targets are:

- `SAP_max`
- `SAP_min`
- `PAP_max`
- `PAP_min`
- `Q_ASD_Lmin`

The pressure extrema describe waveform shape, but they should not dominate
the first pressure-flow GSA. `Q_ASD_Lmin` is derived from `Qp_Lmin -
Qs_Lmin` because direct ASD shunt flow is not reported. Therefore, it is
useful for interpretation but should not be treated as a direct measured
flow target.

## Prediction-Only Outputs

The following outputs can be reported but should not be fitted directly:

- `RAP_mean`
- `SVR`
- `PVR`

Clinical RAP, SVR, and PVR are missing for Patient Zoya pre-closure. These
outputs may help interpret physiology, but they are model predictions or
derived quantities under incomplete evidence.

## Excluded Primary Targets

The following are excluded from primary calibration and Stage A parameter
selection:

- `LVEDV`
- `LVESV`
- `RVEDV`
- `RVESV`
- `LVEF`
- `RVEF`

Patient Zoya pre-closure does not currently have ventricular volume or
ejection-fraction targets. Using these outputs as primary calibration
targets would make ventricular chamber parameters poorly identifiable and
could produce a numerically good but physiologically unsupported fit.

## Why Prediction-Only Outputs Are Still Useful

Prediction-only outputs are still recorded because they can reveal whether
the simulated operating point is plausible. For example, a high RAP or
unexpected PVR may suggest a problem in preload or pulmonary vascular
balance. They should be interpreted as model behavior, not as fitted
evidence.
