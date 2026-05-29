# Literature-Based ASD Dummy Case

## Purpose

The literature-based ASD dummy case is used as an intermediate forward-simulation plausibility check between healthy baseline validation and patient-specific Patient Z simulation. Because the values are cohort medians rather than individual paired measurements, the case is not used for GSA or calibration. Instead, it is used to test whether the ASD shunt architecture produces physiologically plausible trends such as Q_ASD activation, Qp/Qs elevation before closure, and near-normal Qp/Qs after closure.

This case is implemented in `config/patient_dummy_ASD.m`.

## Workflow Position

1. Healthy pediatric baseline validation.
2. Literature-based ASD dummy forward simulation.
3. Patient Zoya ASD pre-closure forward simulation.
4. Patient Zoya GSA.
5. Patient Zoya optimization.

The dummy case is deliberately placed before Patient Zoya because it tests the ASD disease architecture with literature cohort medians before introducing patient-specific data limitations.

## Data Sources

Primary source:

- Sjoberg et al. (2024), Table 1, "Atrial septal defect closure in children at young age is beneficial for left ventricular function."

Supplementary source:

- Arvidsson/Clausen/Sjoberg et al. (2026), pre-proof Table 1.

Current implementation policy:

- Numeric values in `patient_dummy_ASD.m` are retained from the primary Table 1 when available.
- The supplementary source is recorded in metadata but no supplementary numeric value is currently imported.
- Weight is kept as `NaN` because it is not reported in the primary Table 1 and should not be silently filled.
- Post-closure Qp/Qs is kept as `NaN` because it is not reported in the primary Table 1.

## Primary-Source Variables

Pre-closure values retained from Sjoberg 2024 Table 1:

- Age, BSA, height, HR.
- Qp/Qs.
- SBP and DBP.
- LV EDVi, LV ESVi, LV SVi, LVEF, LV cardiac index.
- RV EDVi, RV ESVi, RV SVi, RVEF, RV cardiac index.

Post-closure values retained from Sjoberg 2024 Table 1:

- Age, BSA, height, HR.
- Time from ASD closure to second CMR.
- SBP and DBP.
- LV EDVi, LV ESVi, LV SVi, LVEF, LV cardiac index.
- RV EDVi, RV ESVi, RV SVi, RVEF, RV cardiac index.

## Derived Variables

Indexed CMR values are converted to absolute volumes using the scenario-specific BSA:

- `LVEDV_mL = LVEDVi_mL_m2 * BSA`
- `LVESV_mL = LVESVi_mL_m2 * BSA`
- `LVSV_mL = LVSVi_mL_m2 * BSA`
- `RVEDV_mL = RVEDVi_mL_m2 * BSA`
- `RVESV_mL = RVESVi_mL_m2 * BSA`
- `RVSV_mL = RVSVi_mL_m2 * BSA`
- `CO_Lmin = LV_CI_Lmin_m2 * BSA`
- `RV_CO_Lmin = RV_CI_Lmin_m2 * BSA`
- `Qs_Lmin = CO_Lmin`
- `Qp_Lmin = RV_CO_Lmin`
- `QpQs_from_CI = RV_CI_Lmin_m2 / LV_CI_Lmin_m2`

Cohort medians are not internally constrained, so `QpQs_from_CI` may not exactly equal the reported median Qp/Qs.

## Missing Variables

The following remain `NaN` unless explicitly reported in a source and intentionally mapped later:

- ASD diameter.
- ASD area.
- ASD pressure gradient.
- PAP systolic, diastolic, and mean.
- LAP.
- RAP.
- PVR.
- SVR.
- Ventricular filling pressures.
- Weight.

## Post-Closure Handling

The codebase currently uses `pre_surgery` and `post_surgery` scenario names. For ASD, these are interpreted as:

- `pre_surgery` = pre-closure.
- `post_surgery` = post-closure.

The profile also mirrors these as `pre_closure` and `post_closure` aliases for readability, while preserving compatibility with current functions.

For post-closure, ASD status is documented as closed. `Q_shunt_Lmin = 0` is stored as a closure target/assumption, not as a directly reported Table 1 measurement. The model runner or clinical mapper should close ASD through `params.R.asd = Inf` or equivalent closed-shunt handling.

## Known Limitations

- This is not individual patient-level data.
- Median values are not paired within the same virtual subject.
- Derived flow ratios from cardiac index medians are approximate and should not be treated as independent measured targets.
- Sjoberg 2024 Table 1 reports post-closure RV EDVi as `80 (82-101) mL/m^2`, where the median appears below the lower quartile. The model profile retains the median value 80 as reported and documents the IQR inconsistency as a source limitation.
- This profile must not be used for GSA or optimization.

