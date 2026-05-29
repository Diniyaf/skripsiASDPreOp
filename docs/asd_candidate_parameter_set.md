# ASD Candidate Parameter Set for Patient Z Pre-Closure

## Purpose

This document defines the candidate calibration parameter sets for the
Patient Zoya ASD pre-closure model before any GSA or optimisation is run.
The purpose is to make the future sensitivity-analysis surface explicit,
physiologically traceable, and defensible before parameters are varied.

This phase does **not** tune parameters. It only documents which
parameters are scientifically reasonable candidates for future GSA.

## Relationship to the Hafiz/Keisya VSD Workflow

The Hafiz/Keisya VSD workflow uses staged parameter selection after
clinical seeding:

```text
adult healthy baseline
-> pediatric scaling
-> params_from_clinical
-> baseline disease simulation
-> GSA
-> optimization
-> calibrated operating point
```

The ASD workflow mirrors the same structure:

```text
adult healthy baseline
-> pediatric scaling
-> ASD clinical seeding
-> ASD baseline simulation
-> GSA
-> optimization
-> calibrated ASD operating point
```

The difference is physiological: VSD shunt candidates cannot be copied
directly into ASD. The active ASD shunt is between the left atrium and the
right atrium, and the sign convention is:

```text
Q_ASD > 0 means LA -> RA
```

## Why ASD Uses `asd.Cd` Instead of `R.asd`

Patient Zoya currently uses:

```text
params.asd.mode = 'orifice_bidirectional'
```

In this mode, `src/models/asd_shunt_model.m` computes the shunt flow from
ASD area, discharge coefficient, blood density, and the pressure
difference `P_LA - P_RA`. Therefore, `R.asd` is not the active shunt knob
in the current model mode.

For the current ASD mode:

```text
Candidate shunt parameter: asd.Cd
Not active in orifice mode: R.asd
```

`R.asd` should only become a calibration candidate if the model is
explicitly switched to a linear resistance ASD mode.

## Group A: Primary Vascular and Shunt Candidates

Group A is the recommended first candidate set for Patient Z pre-closure
GSA.

It includes:

- `asd.Cd`
- `R.SAR`
- `R.SC`
- `R.SVEN`
- `C.SAR`
- `R.PAR`
- `R.PCOX`
- `R.PCNO`
- `R.PVEN`
- `C.PAR`

These parameters are primary because Patient Z has pressure and flow
targets that directly constrain systemic and pulmonary pressure-flow
balance:

- Qp/Qs
- Qp
- Qs
- PAP_mean
- MAP
- LAP_mean

The model currently underestimates shunt severity, while MAP is already
close to target. This makes the shunt and pulmonary/systemic vascular
blocks the most defensible first screening set.

## Group B: Secondary Atrial and Preload Candidates

Group B contains ASD-specific atrial and preload-related parameters:

- `E.LA.EA`
- `E.LA.EB`
- `E.RA.EA`
- `E.RA.EB`
- `V0.LA`
- `V0.RA`
- `C.SVEN`
- `C.PVEN`
- `V0.SVEN`

The rationale is that ASD shunt flow is driven by the atrial pressure
gradient:

```text
P_LA - P_RA
```

Therefore, atrial elastance, atrial unstressed volume, venous compliance,
and venous reservoir preload can affect `Q_ASD` and `Qp/Qs`.

However, Patient Z does not currently have atrial volume data or RAP
measurements. These parameters should therefore be secondary, tightly
bounded, and interpreted cautiously.

## Group C: Fixed or Exploratory Ventricular Parameters

Group C contains ventricular chamber parameters:

- `E.LV.EA`
- `E.LV.EB`
- `E.RV.EA`
- `E.RV.EB`
- `V0.LV`
- `V0.RV`

These are fixed by default for Patient Z pre-closure calibration.

The reason is identifiability. Patient Z pre-closure currently has no:

- LVEDV
- LVESV
- RVEDV
- RVESV
- LVEF
- RVEF

Without ventricular volume/function targets, freely optimising
ventricular elastance or unstressed volume could create a numerically good
fit for the wrong physiological reason.

These parameters may be revisited later only if new volume/function data
are added or if a supervised exploratory phase is explicitly approved.

## Preliminary Bound Strategy

The first candidate definition uses conservative bounds around
`params0_ASD_pre`:

| Parameter class | Preliminary bound |
|---|---|
| `asd.Cd` | 0.2 to 1.2 |
| Resistances | 0.5x to 2.0x current value |
| Compliances | 0.5x to 2.0x current value |
| Atrial elastance | 0.5x to 2.0x current value |
| Atrial/ventricular V0 | 0.8x to 1.2x current value |

If a parameter is zero, `Inf`, `NaN`, missing, or not active in the current
ASD mode, it is not automatically included and is reported in the warnings
or excluded-parameter sheet.

## Future GSA Targets

Primary future GSA targets should be:

- Qp/Qs
- Qp
- Qs
- PAP_mean
- MAP
- LAP_mean

Secondary targets should be:

- PAP_sys
- PAP_dia
- SBP
- DBP
- Q_ASD, derived from Qp - Qs for comparison only

`RAP_mean` should remain a model prediction only because Patient Z RAP is
missing.

The following should be excluded as primary targets for now:

- LVEDV
- LVESV
- RVEDV
- RVESV
- LVEF
- RVEF

## Why This Is Not Yet Optimisation

This candidate set is a pre-GSA methodological checkpoint. It defines the
parameter search space but does not vary the model, rank sensitivity,
minimise an objective function, or update the operating point.

This separation is important because the model is currently stable and the
ASD shunt is active, but the baseline underestimates shunt severity. The
next scientific step is to test which physiologic blocks control that
mismatch before allowing any optimisation.
