# ASD GSA Smoke Test Analysis - N=16

**Date:** 2026-06-01  
**Script:** `scripts/run_zoya_asd_gsa_curated.m`  
**Patient:** Zoya pre-closure ASD  
**Workbook:** `results/tables/zoya_asd_gsa_curated_20260601_160120.xlsx`  
**MAT file:** `results/tables/zoya_asd_gsa_curated_20260601_160120.mat`  
**Config:** N=16, seed=42 (`combRecursive`), warmup=40 cycles, serial execution

This note summarizes the N=16 curated ASD GSA smoke test. It should be treated
as a pipeline/debugging run only, not as thesis-level sensitivity evidence.

---

## 1. Run Summary

| Metric | Value |
|---|---:|
| Parameters sampled | 25 |
| Total simulations | 432 = N x (d + 2) = 16 x 27 |
| Failed/nonstandard records | 111 / 432 = 25.7% |
| Numerical failures | 1 / 432 = 0.23% |
| Physiological warning records | 110 / 432 = 25.5% |
| Warmup cycles | 40 |
| Execution mode | Serial |
| Observed duration | about 1.5 hours |

The workbook summary confirms 111 failed/nonstandard records. MATLAB inspection
of the MAT file confirms that only one of these is a true numerical failure.
The remaining records are physiology warnings.

---

## 2. Failure Type Distribution

| Failure Type | Count | Percent of flagged records | Severity |
|---|---:|---:|---|
| `opposite_shunt_direction` (`Q_ASD_Lmin < 0`) | 110 | 99.1% | Warning only; outputs remain finite |
| `steady_state_failure` | 1 | 0.9% | Numerical issue; outputs are NaN |

### Interpretation

`opposite_shunt_direction` is not a solver crash. It means the sampled
parameter combination pushed the atrial pressure balance into net RA -> LA
flow. Because the ASD model is bidirectional, this is mathematically allowed.
These records are therefore logged for interpretation but still contribute
finite outputs to the Sobol calculation.

The single `steady_state_failure` is the only actual numerical failure in this
smoke run.

### Documentation improvement recommended

In future exports, separate the current `Failed_Simulations` sheet into:

- `Numerical_Failures`: solver exceptions, steady-state failure, NaN/Inf output.
- `Physiology_Warnings`: opposite shunt direction or unexpected but finite
  physiology.

This will avoid the false impression that 25% of the run numerically failed.

---

## 3. Sobol Index Quality at N=16

N=16 is too small for reliable Sobol ranking with 25 parameters. The bootstrap
confidence intervals are very wide, and some upper bounds exceed 1.0, which is
a clear sign that the estimates are noisy.

| Parameter | Max ST | 95% CI | CI Width | Interpretation |
|---|---:|---:|---:|---|
| `V0.SVEN` | 0.660 | [0.315, 1.227] | 0.912 | Strong signal, but noisy |
| `E.LV.EB` | 0.533 | [0.206, 1.343] | 1.137 | Sensitive but Group C; not actionable yet |
| `C.SVEN` | 0.304 | [0.132, 0.679] | 0.547 | Plausible preload signal, noisy |
| `R.SC` | 0.212 | [0.093, 0.372] | 0.279 | Plausible systemic pressure signal |
| `E.RV.EB` | 0.205 | [0.105, 0.331] | 0.226 | Sensitive but Group C; monitor only |

Conclusion: N=16 validates that the pipeline runs, logging works, figures are
created, and the active-mask logic executes. It does not provide a defensible
final active set.

---

## 4. Active Set Interpretation

The recommended active set from this smoke run was:

1. `V0.SVEN`
2. `C.SVEN`
3. `R.SC`
4. `E.RA.EB`

This should not be accepted as final. `E.RA.EB` was selected mainly because the
active-mask rule enforces a minimum number of active parameters. Its
`Max_ST_Primary` was 0.093, below the usual 0.10 threshold, and the workbook
marks `none >= threshold`.

Group C parameters such as `E.LV.EB`, `E.RV.EB`, and `E.LV.EA` show sensitivity
signals, but they remain monitor-only for Patient Zoya pre-closure because LV/RV
volume and EF targets are missing. Selecting them would be weakly identifiable
and methodologically hard to defend.

---

## 5. Physiological Reading

The strongest actionable pattern is not "one best parameter"; it is that Zoya's
ASD severity is controlled by preload/venous reservoir balance and systemic
pressure-flow balance:

- `V0.SVEN` strongly affects LAP_mean, PAP_mean, Qp_Lmin, and Qs_Lmin.
- `C.SVEN` also affects LAP_mean and pulmonary/systemic flow.
- `R.SC` mainly affects systemic pressure outputs, especially SAP_mean/SAP_min.
- `asd.Cd` is not dominant in this N=16 run, likely because the current shunt is
  limited by atrial pressure gradient/preload balance rather than only by the
  orifice coefficient.

The high fraction of opposite-shunt warnings is important. It means the current
25-parameter bounds include many parameter combinations that are numerically
valid but not Zoya-like left-to-right ASD physiology. This can inflate the
importance of preload and ventricular parameters in GSA.

---

## 6. Runtime Implication

The previous note incorrectly listed the N=16 duration as about 5 minutes.
The observed runtime was about 1.5 hours. Using the same serial direct-Saltelli
settings, the rough runtime scaling is:

| N | Total evaluations | Approx serial time |
|---:|---:|---:|
| 16 | 432 | about 1.5 hours |
| 64 | 1728 | about 6 hours |
| 128 | 3456 | about 12 hours |
| 256 | 6912 | about 24 hours |

If warmup is increased from 40 to 50 cycles, runtime may increase by roughly
25%, so direct N=128 could approach 15 hours.

These are estimates, not guarantees. Individual samples can be slower if the
ODE becomes stiff.

---

## 7. Direct Sobol vs PCE

Hafiz/Keisya's unified VSD pipeline contains both direct Saltelli/Sobol tools
and a PCE path. In the VSD `main_run.m`, the staged workflow uses:

`gsa_pce_setup` -> `gsa_run_pce` -> Sobol ST mask -> staged calibration

The important methodological idea is not only the value of N. It is that PCE
uses a shared training design and then computes Sobol indices from a surrogate,
so the number of expensive ODE evaluations is much smaller than direct
Saltelli.

Current ASD status:

- `src/gsa/gsa_pce_setup.m` and `src/gsa/gsa_run_pce.m` exist, but they are
  still VSD-style and not yet ASD-governance-ready.
- They still contain VSD parameter/metric assumptions such as `vsd.Cd`,
  `R.vsd`, and VSD-oriented QoI naming.
- The PCE failure fallback currently writes zeros on failure, which is not
  acceptable for ASD thesis reporting without clearer warning/failure handling.

Recommendation: do not run ASD PCE blindly yet. Adapt the PCE setup to the ASD
curated parameter library, ASD target tiers, and ASD failure/warning logging
first.

---

## 8. Recommended Next Step

Do not jump directly from N=16 to direct N=128 using the current serial
Saltelli runner unless overnight runtime is acceptable.

Recommended sequence:

1. Keep this N=16 run as smoke-test evidence only.
2. Fix reporting separation: numerical failures vs physiology warnings.
3. Decide whether final thesis GSA should be:
   - direct Sobol N=64/128, expensive but simple; or
   - ASD-adapted PCE, more aligned with the VSD main pipeline and likely faster.
4. If following Hafiz/Keisya methodology closely, adapt PCE for ASD first.
5. After PCE adaptation, run a small ASD PCE smoke test and compare the top
   ranked parameters against the N=16 direct Sobol pattern.
6. Use direct Sobol N=64 or N=128 only as confirmation if needed.

For now, the most defensible thesis statement is:

> The N=16 curated ASD GSA was used only to verify the execution pipeline,
> warning classification, result export, and preliminary sensitivity behavior.
> Because the confidence intervals were wide and runtime scaled poorly for
> direct Saltelli sampling, thesis-level GSA should use either a larger direct
> Sobol run or an ASD-adapted PCE workflow aligned with the Hafiz/Keisya VSD
> methodology.

---

## 9. Actionable Checks Before Full GSA

- Confirm whether `opposite_shunt_direction` should remain a warning only or be
  treated as an exclusion for a Zoya-specific left-to-right ASD parameter space.
- Decide whether bounds should remain broad for mechanism exploration or be
  narrowed around clinically plausible pre-closure physiology.
- Keep Group C ventricular parameters monitor-only unless LV/RV volume or EF
  targets become available.
- If PCE is adapted, ensure failed samples are not silently replaced with zero.
- If direct Sobol is retained, run at least N=64 before N=128 to estimate runtime
  and ranking stability.

