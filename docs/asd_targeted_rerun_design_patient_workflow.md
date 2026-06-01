# ASD Targeted Rerun Design and Patient-Specific Workflow

Date: 2026-06-01

This note records the methodological discussion about targeted GSA rerun design and how the workflow should be handled when the ASD model is applied to a different patient. It is intended as a thesis-facing explanation, not as a code change or calibration result.

## Context

Patient Zoya ASD pre-closure calibration has shown a useful but incomplete response:

- Baseline ASD model was stable and had an active LA-to-RA shunt.
- Calibration increased shunt severity:
  - Qp/Qs increased from approximately 1.42 to 2.91.
  - Q_ASD increased from approximately 1.07 L/min to 5.06 L/min.
  - PAP_sys moved close to the clinical target.
- However, systemic pressure degraded:
  - MAP decreased from approximately 90 mmHg to 73 mmHg.
  - SBP and DBP moved farther from the clinical targets.
- Therefore, the calibrated candidate is useful as a diagnostic candidate, but it should not yet be accepted as the final calibrated operating point.

The main interpretation is that the current active set can increase pulmonary shunt flow, but does not sufficiently preserve systemic pressure-flow balance.

## Q1. What Is Targeted Rerun Design?

Targeted rerun design means repeating GSA with a focused subset of physiologically relevant parameters, instead of rerunning a very large GSA with all available parameters.

The goal is not to blindly increase sample size or parameter count. The goal is to ask a sharper physiological question:

> Which parameters are most likely to explain the remaining mismatch in Qp/Qs, Qp, Qs, LAP, PAP, and systemic pressure?

In this case, the mismatch suggests that the next GSA should focus on:

- ASD shunt strength.
- Systemic pressure and systemic flow.
- Pulmonary pressure and pulmonary flow.
- Venous/preload reserve only if needed.

## Q2. Why Not Immediately Rerun Full 26-Parameter GSA?

A full 26-parameter direct Sobol/Saltelli GSA is expensive and can be noisy. With direct Sobol sampling, total model evaluations scale approximately as:

```text
N * (d + 2)
```

where `N` is the base sample size and `d` is the number of parameters.

For example:

```text
N = 256, d = 26 -> approximately 7168 simulations
```

This may take several hours. More importantly, it may not solve the methodological problem if the objective function or active-set logic still allows systemic pressure to collapse while improving Qp/Qs.

Therefore, the more defensible next step is:

```text
diagnostic calibration result
-> audit previous GSA ranking
-> rerun targeted GSA
-> rebuild active set
-> recalibrate with stricter validity gates
```

## Q3. Candidate Targeted Parameter Set for Patient Zoya

For Patient Zoya pre-closure, the targeted candidate set should include parameters that can plausibly influence the observed mismatch.

### Shunt

- `asd.Cd`

Rationale: ASD is currently modeled in orifice mode, so `asd.Cd` controls shunt flow strength more directly than `R.asd`.

Expected affected outputs:

- Q_ASD
- Qp/Qs
- Qp
- LAP/RAP pressure relationship

### Systemic Pressure and Flow

- `R.SAR`
- `R.SC`
- `R.SVEN`
- `C.SAR`

Rationale: after calibration, MAP/SBP/DBP became worse. These parameters are needed to test whether systemic pressure can be preserved while increasing shunt severity.

Expected affected outputs:

- MAP
- SBP
- DBP
- Qs
- systemic pressure-flow balance

### Pulmonary Pressure and Flow

- `R.PAR`
- `R.PCOX`
- `R.PCNO`
- `R.PVEN`
- `C.PAR`

Rationale: Patient Zoya has pulmonary pressure targets and a high Qp/Qs target. Pulmonary vascular parameters can influence PAP, Qp, and pulmonary pressure-flow balance.

Expected affected outputs:

- PAP_sys
- PAP_dia
- PAP_mean
- Qp
- Qp/Qs
- LAP/pulmonary venous pressure relationship

### Secondary Preload Reserve

- `V0.SVEN`
- `C.SVEN`

Rationale: venous reservoir/preload parameters may help maintain flow and pressure balance, but they should be interpreted carefully because direct venous volume data are unavailable.

## Q4. Suggested Rerun Sequence

The recommended sequence is:

```text
1. Freeze current calibrated output as a diagnostic or rejected candidate.
2. Audit current GSA result and active-set selection.
3. Run targeted GSA with a smaller physiologically focused candidate set.
4. Start with N = 64 as a smoke/preliminary run.
5. Check steady-state failures, NaN outputs, and physiological sensitivity pattern.
6. If stable, rerun targeted GSA with N = 128 or N = 256.
7. Build a new active set from Sobol ST and physiological rationale.
8. Recalibrate using stricter validity gates for MAP, SBP, DBP, Qp/Qs, PAP, and LAP.
9. Run final validation and, if needed, final post-calibration GSA.
```

The N = 64 run should not be treated as thesis-final. It is a diagnostic to verify that the chosen parameter set and solver settings behave sensibly.

## Q5. How This Mirrors the Unified VSD Workflow

The unified VSD methodology uses a staged workflow:

```text
healthy/adult baseline
-> pediatric scaling
-> clinical seeding
-> baseline disease simulation
-> initial GSA
-> optimization mask
-> masked calibration
-> final GSA / validation
```

The ASD workflow should preserve the same logic:

```text
healthy/adult baseline
-> pediatric scaling
-> ASD clinical seeding
-> ASD baseline disease simulation
-> ASD GSA
-> ASD active-set selection
-> ASD calibration
-> ASD validation/final GSA
```

The important point is that GSA is used to guide calibration, not to replace calibration. Likewise, calibration should not be accepted only because one target improves; it must preserve global physiological plausibility.

## Q6. What Happens When We Change Patient?

When moving to another ASD patient, the overall workflow remains the same, but the final active calibration set should not be assumed to transfer automatically.

Reusable across patients:

- ASD shunt model.
- Healthy baseline validation.
- Pediatric scaling functions.
- ASD clinical seeding structure.
- Candidate parameter library.
- Target-tier governance.
- Excel/reporting structure.
- Sobol ST threshold concept, such as `ST >= 0.10`.
- Group A/B/C physiological grouping.

Patient-specific and should be re-evaluated:

- Clinical targets.
- Baseline disease mismatch.
- Sobol ranking.
- Active calibration subset.
- Final calibrated parameter values.
- Objective weighting if data availability changes.
- Accepted operating point.

Therefore, the thesis method should state:

```text
A common ASD calibration framework was used for all patients. The candidate parameter library was defined from cardiovascular physiology, but the active calibration subset was selected per patient using pre-calibration GSA and data availability.
```

This is more defensible than forcing all patients to use the same active set, because different patients may have different ASD size, BSA, HR, Qp/Qs severity, pressure profile, and data completeness.

## Q7. Practical Rule for Future Patients

For each new patient:

```text
1. Run healthy baseline integrity check.
2. Apply patient-specific pediatric scaling.
3. Apply patient-specific ASD clinical seeding.
4. Run pre-calibration ASD baseline simulation.
5. Identify the dominant mismatch pattern.
6. Select a targeted GSA candidate set based on that mismatch and available data.
7. Run GSA.
8. Select active parameters using sensitivity plus physiology.
9. Calibrate only the selected parameters.
10. Validate the calibrated result against available clinical targets and physiological plausibility gates.
```

Example:

- If Qp/Qs is low and MAP collapses during calibration, include shunt plus systemic pressure-flow handles.
- If PAP is mismatched but MAP is preserved, emphasize pulmonary vascular candidates.
- If ventricular volume/EF data are missing, keep ventricular elastance and V0 parameters fixed or exploratory only.
- If ventricular volume/EF data are available, Group C parameters may be considered more justifiable.

## Key Takeaway

Targeted rerun design is not a shortcut and not manual tuning. It is a structured way to rerun GSA with a physiologically justified candidate set, based on the failure mode observed in the current model output.

For Patient Zoya, the immediate need is not simply "more parameters" or "larger N". The immediate need is to verify which shunt, pulmonary, systemic, and preload parameters can improve Qp/Qs and pulmonary flow while preserving systemic pressure.

## Catatan Sumber Targeted GSA

Targeted GSA untuk Patient Zoya tidak boleh ditulis seolah-olah parameter set-nya "langsung didapat" atau "langsung diputuskan" dari satu kali run full-parameter GSA N = 128. Wording seperti itu terlalu kuat, karena N = 128 untuk jumlah parameter besar masih bersifat preliminary dan masih dapat mengandung sampling noise.

Wording yang lebih aman secara metodologi:

```text
Set parameter targeted GSA ditentukan berdasarkan tiga sumber: hasil screening awal full-parameter GSA N = 128, pola mismatch setelah kalibrasi awal, dan rasional fisiologi ASD. Karena N = 128 masih bersifat preliminary untuk jumlah parameter yang besar, hasil tersebut tidak digunakan sebagai keputusan final, tetapi sebagai dasar untuk merancang rerun GSA yang lebih fokus.
```

Dalam bahasa Inggris untuk skripsi:

```text
The targeted GSA set was not treated as a final active set. It was constructed after an initial full-parameter N = 128 screening GSA and an initial calibration attempt revealed a trade-off between improving Qp/Qs and preserving systemic arterial pressure. Therefore, the rerun GSA focused on shunt, systemic vascular, pulmonary vascular, and selected preload parameters that were physiologically capable of explaining the remaining pressure-flow mismatch.
```

Jadi, full-parameter GSA N = 128 adalah salah satu sumber informasi, tetapi bukan satu-satunya dasar keputusan. Targeted GSA berasal dari gabungan:

1. Hasil full-parameter GSA N = 128 sebagai screening awal.
2. Hasil kalibrasi awal yang menunjukkan Qp/Qs dan Q_ASD membaik, tetapi MAP, SBP, dan DBP memburuk.
3. Rasional fisiologi ASD, terutama hubungan antara shunt LA-to-RA, pulmonary flow, systemic pressure-flow balance, dan venous/preload reserve.
4. Ketersediaan data Patient Zoya, yaitu adanya target Qp/Qs, Qp, Qs, MAP, PAP, dan LAP, tetapi tidak adanya target LV/RV volume dan EF pre-closure.

Implikasinya:

- Parameter seperti `asd.Cd` tetap penting karena mengatur kekuatan shunt ASD dalam orifice mode.
- Parameter systemic seperti `R.SAR`, `R.SC`, `R.SVEN`, dan `C.SAR` perlu dicek ulang karena MAP/SBP/DBP memburuk setelah kalibrasi awal.
- Parameter pulmonary seperti `R.PAR`, `R.PCOX`, `R.PCNO`, `R.PVEN`, dan `C.PAR` tetap relevan karena target PAP dan Qp tersedia.
- Parameter preload seperti `V0.SVEN` dan `C.SVEN` dapat dipertimbangkan sebagai cadangan, tetapi harus diinterpretasikan hati-hati karena data volume venous langsung tidak tersedia.
- Parameter ventricular Group C tidak menjadi fokus utama karena Patient Zoya pre-closure tidak memiliki target LVEDV, LVESV, RVEDV, RVESV, LVEF, atau RVEF.

Kesimpulan metodologis:

```text
Targeted GSA adalah desain ulang GSA yang dipandu oleh hasil screening awal, pola kegagalan kalibrasi, dan fisiologi ASD. Targeted GSA bukan active set final dan bukan tuning manual. Active set final tetap harus diputuskan setelah rerun GSA yang lebih stabil dan dievaluasi menggunakan Sobol ST, target-tier governance, serta plausibility gate.
```
