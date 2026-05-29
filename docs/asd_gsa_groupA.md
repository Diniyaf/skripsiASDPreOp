# Patient Zoya ASD Group A Pre-Calibration GSA

## Purpose

This document records the first pre-calibration Global Sensitivity Analysis
(GSA) for Patient Zoya ASD pre-closure. The run is used to identify which
Group A parameters most influence the pressure-flow outputs before any
optimisation is attempted.

GSA is not calibration. No parameter is tuned by this step.

## Why Group A Is Tested First

Group A was evaluated first because Patient Zoya pre-closure provides
pressure-flow targets but lacks ventricular volume/function targets.
Therefore, the first GSA was restricted to shunt, systemic vascular, and
pulmonary vascular parameters that are most directly identifiable from Qp,
Qs, Qp/Qs, MAP, PAP, and LAP. Group B atrial/preload parameters are
reserved for later expansion if Group A cannot explain the residual
mismatch, while Group C ventricular parameters remain fixed/exploratory
because pre-closure ventricular volume/function data are unavailable.

## Parameters Included

Only Group A parameters are varied:

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

Because the current ASD shunt mode is `orifice_bidirectional`, the shunt
candidate is `asd.Cd`, not `R.asd`.

## Parameters Held for Later

Group B is held for later:

- atrial elastance
- atrial unstressed volume
- venous compliance
- venous reservoir/preload terms

These parameters can influence the atrial pressure gradient `P_LA - P_RA`,
but Patient Zoya currently lacks RAP and atrial-volume evidence, so these
parameters should not be opened before Group A has been tested.

Group C remains fixed/exploratory:

- ventricular elastance
- ventricular unstressed volume

Patient Zoya pre-closure currently lacks LVEDV, LVESV, RVEDV, RVESV, LVEF,
and RVEF targets.

## Outputs Used

Primary GSA outputs:

- `QpQs`
- `Qp_Lmin`
- `Qs_Lmin`
- `PAP_mean`
- `SAP_mean`
- `LAP_mean`

Secondary outputs:

- `PAP_max`
- `PAP_min`
- `SAP_max`
- `SAP_min`
- `Q_ASD_Lmin`

All flows are reported in L/min, pressures in mmHg, and Sobol sensitivity
indices are dimensionless.

## ST and S1 Interpretation

The total-order Sobol index `ST` measures the total contribution of a
parameter, including interactions with other parameters. `ST` is prioritized
for active-parameter selection because closed-loop cardiovascular models are
nonlinear and coupled.

The first-order index `S1` is still useful. If `S1` is low but `ST` is high,
the parameter likely acts through interactions rather than a simple
independent main effect.

## Selection Rule for Later Stage A Optimization

This GSA only recommends a future active set. It does not optimise.

The Stage A recommendation rule is:

1. Select parameters with `Max_ST_Primary >= 0.10` for at least one primary
   target.
2. If fewer than four parameters are selected, add top-ranked parameters by
   `Mean_ST_Primary` until four to six parameters are selected.
3. Prioritize parameters affecting `QpQs`, `Qp_Lmin`, `PAP_mean`,
   `SAP_mean`, and `LAP_mean`.
4. Avoid selecting too many parameters in a sparse clinical-data case.
5. Do not select a parameter only because it affects one output if the
   physiological rationale is weak.

## Reproducibility

The preliminary Group A GSA uses a fixed random seed and records the sample
size, sampling method, parameter bounds, timestamp, and MATLAB version in
the exported workbook and MAT file.

The default sample size is `N = 64`, so the run should be interpreted as a
smoke/preliminary GSA. For thesis-final parameter selection, rerun with
`N = 128` or `N = 256` if runtime allows and if failed/nonvalid samples are
low.

## Criteria for Opening Group B Later

Group B should be considered later if:

- Group A has low sensitivity for `QpQs`, `Qp_Lmin`, `Q_ASD_Lmin`, or
  `LAP_mean`.
- The shunt remains underpredicted even when `asd.Cd` and vascular
  pressure-flow parameters show plausible sensitivity.
- Sensitivity interpretation suggests that the limiting factor is the
  atrial operating point or preload rather than vascular resistance alone.
