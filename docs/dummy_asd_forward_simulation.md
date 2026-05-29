# Dummy ASD Forward Simulation

## Purpose

The literature-based ASD dummy case is used as an intermediate forward-simulation plausibility check between healthy baseline validation and patient-specific Patient Z simulation. Because the values are cohort medians rather than individual paired measurements, the case is not used for GSA or calibration. Instead, it is used to test whether the ASD shunt architecture produces physiologically plausible trends such as Q_ASD activation, Qp/Qs elevation before closure, and near-normal Qp/Qs after closure.

## Why It Runs Before Patient Z

The healthy baseline has already established the closed-circuit reference state. Before moving to Patient Zoya, the model should first be challenged with a generic literature-based ASD state. This separates two questions:

1. Does the ASD architecture behave physiologically when the atrial shunt path is opened?
2. Can the model later be personalized to Patient Zoya?

The dummy case answers only the first question.

## Why It Is Not Used For GSA Or Optimization

The dummy profile in `config/patient_dummy_ASD.m` is based on cohort medians from literature. These medians are not paired measurements from one individual child. Therefore, exact target matching would be methodologically misleading. The forward run is allowed to show mismatch against the median targets, and those mismatches are interpreted as diagnostic context rather than calibration error.

GSA and optimization are postponed until Patient Zoya pre-closure, where the workflow is patient-specific.

## Literature Values Used

Primary source:

- Sjoberg et al. (2024), Table 1, "Atrial septal defect closure in children at young age is beneficial for left ventricular function."

Pre-closure fields retained from the primary source include:

- Age, BSA, height, HR.
- Qp/Qs.
- SBP and DBP.
- LV EDVi, LV ESVi, LV SVi, LVEF, LV cardiac index.
- RV EDVi, RV ESVi, RV SVi, RVEF, RV cardiac index.

Post-closure fields retained from the primary source include:

- Age, BSA, height, HR.
- Time from ASD closure to second CMR.
- SBP and DBP.
- LV EDVi, LV ESVi, LV SVi, LVEF, LV cardiac index.
- RV EDVi, RV ESVi, RV SVi, RVEF, RV cardiac index.

Supplementary source:

- Arvidsson/Clausen/Sjoberg et al. (2026), pre-proof Table 1.

No supplementary numeric values are currently imported into the dummy profile unless explicitly marked in `patient_dummy_ASD.m`.

## Missing Values

The following remain missing in the dummy profile unless later verified from an explicit source:

- ASD diameter.
- ASD area.
- ASD pressure gradient.
- Direct shunt flow.
- PAP systolic, diastolic, and mean.
- RAP and LAP.
- PVR and SVR.
- Ventricular filling pressures.
- Weight.

Because `apply_scaling.m` requires body mass for blood-volume reconciliation, `scripts/run_dummy_asd_forward.m` derives a model-only weight from reported BSA and height using the inverse Mosteller relation. This derived value is not written back into the clinical profile and is not treated as a reported target.

## Expected Physiological Behavior

Healthy baseline:

- Qp/Qs should remain near 1.
- Q_ASD should remain approximately 0.

Dummy ASD pre-closure:

- Q_ASD should become nonzero if the ASD path is activated.
- Dominant shunt direction should ideally be LA to RA.
- Qp/Qs should rise above 1.
- RV flow or RV stroke volume should exceed LV/systemic flow if the ASD load is expressed.

Dummy ASD post-closure:

- Q_ASD should return to approximately 0.
- Qp/Qs should return toward 1.
- RV volume/load should decrease relative to pre-closure.
- LV filling/output should improve or move toward the post-closure dummy target.

## Interpreting Mismatch

The dummy target values are cohort medians. They are not a self-consistent individual state vector. A mismatch between the model output and the dummy targets does not automatically mean the model is invalid. In this phase, the primary question is whether opening and closing the ASD pathway produces the expected directional physiology.

If Qp/Qs does not match the reported median, the result should be documented and interpreted as a forward-model limitation or an operating-point clue. It should not be corrected by tuning in this dummy phase.

## Current Runner

Run from MATLAB or PowerShell:

```matlab
run('scripts/run_dummy_asd_forward.m')
```

The runner exports a timestamped workbook:

```text
results/tables/dummy_asd_forward_YYYYMMDD_HHMMSS.xlsx
```

The runner intentionally does not call:

- GSA.
- PCE/Sobol analysis.
- Optimization.
- Calibration.
- Patient Zoya files.
- Post-closure Jovano logic.

