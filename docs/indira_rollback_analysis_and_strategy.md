# Indira Rollback Analysis And Strategy

**Date:** 2026-06-04  
**Context:** Indira ASD pre-closure calibration after curated GSA `N=128`.  
**Status:** Stage A-only and Stage C both rolled back, but for different reasons.

---

## 1. Main Conclusion

The two rollbacks should not be interpreted the same way.

| Run | Trigger | Interpretation |
|---|---|---|
| Stage A only | `Qs_Lmin` worsened from 17.4% to 23.9% | Correct rollback. A primary target worsened, so the active set is insufficient. |
| Stage C | `SAP_max` and `PAP_min` secondary guards worsened to ~15% | Not a numerical failure. This is a target-governance decision about whether secondary waveform extrema should be hard vetoes. |

The best thesis-facing interpretation is:

> Stage A is rejected. Stage C is a strong calibrated candidate with secondary waveform warnings.

---

## 2. Stage A Rollback Is Scientifically Appropriate

Stage A active parameters:

- `R.asd`
- `R.SC`
- `R.PCOX`
- `V0.SVEN`
- `C.SVEN`

Stage A improved global RMSE only slightly:

| Metric | Baseline Error | Stage A Error | Direction |
|---|---:|---:|---|
| Qs_Lmin | 17.4% | 23.9% | worsened |
| Qp_Lmin | 23.0% | 18.1% | improved |
| SAP_mean | 15.9% | 3.0% | improved |
| PAP_mean | 20.1% | 16.5% | improved |
| LAP_mean | 13.9% | 15.1% | worsened slightly |
| RAP_mean | 0.8% | 6.5% | worsened |
| QpQs | 34.3% | 33.9% | nearly unchanged |

The rollback reason was:

> `Qs_Lmin worsened 17.4% -> 23.9%`

This is a primary target. Therefore this should remain a hard veto.

Scientific interpretation:

> The non-ventricular Stage A active set cannot independently improve pulmonary flow, systemic flow, and shunt ratio in Indira. The optimizer improved some pressures and Qp but sacrificed Qs, so the calibration should not be accepted.

No need to rerun Stage A only. It has answered its methodological question.

---

## 3. Stage C Rollback Is Different

Stage C added:

- `E.LV.EB`
- `E.RV.EB`

Stage C achieved excellent primary-target fit:

| Metric | Target | Stage C | Error |
|---|---:|---:|---:|
| Qs_Lmin | 3.22 | 3.401 | 5.6% |
| Qp_Lmin | 7.54 | 7.805 | 3.5% |
| SAP_mean | 75 | 68.76 | 8.3% |
| PAP_mean | 25 | 24.51 | 2.0% |
| LAP_mean | 8 | 8.018 | 0.2% |
| RAP_mean | 6 | 6.011 | 0.2% |
| QpQs | 2.34 | 2.295 | 1.9% |
| RMSE | - | 0.0416 | - |

Validity:

- steady state: OK
- finite state: OK
- volume gates: OK
- PVR/SVR bounds: OK
- EF bounds: OK
- ASD direction: OK

Plausibility:

- 6 OK
- 1 WARNING (`E.RV.EB` near lower bound)
- 0 FAIL

Rollback occurred only because:

| Secondary Guard | Baseline Error | Stage C Error |
|---|---:|---:|
| SAP_max | 5.3% | 15.0% |
| PAP_min | 3.6% | 15.5% |

This is not the same as Stage A. Stage C fits the main hemodynamic state and only worsens waveform extrema.

---

## 4. How To Decide: Hard Veto Or Warning-Level Guard?

Use target tier and physiological consequence, not emotion about RMSE.

### Hard Veto

A metric should be a hard veto if at least one is true:

1. It is a primary target.
2. It is independently measured and clinically central to the calibration goal.
3. Worsening suggests nonphysical physiology or unsafe model behavior.
4. The candidate fails validity or parameter plausibility.
5. The candidate improves one metric by destroying another primary metric.

Examples:

- `Qs_Lmin` worsening in Stage A: hard veto.
- solver failure: hard veto.
- invalid shunt direction: hard veto.
- parameter outside bound: hard veto.

### Warning-Level Guard

A metric should be warning-level if most of these are true:

1. It is secondary, not primary.
2. It is a waveform extremum rather than a mean pressure-flow state.
3. The model still passes validity and plausibility.
4. All primary targets improve strongly or are within target tolerance.
5. The deviation is modest and explainable as waveform-shape trade-off.

Examples:

- `SAP_max` around 15% when MAP and flows strongly improve.
- `PAP_min` around 15.5% when PAP_mean, Qp, Qs, LAP, RAP, and Qp/Qs are all close.

For Indira Stage C, the secondary waveform guard is better treated as a warning, not an automatic rollback veto.

---

## 5. Critique Of The Previous Recommendation

The previous recommendation said:

> Accept baseline as final because baseline RMSE 0.20 is already good.

I do not think that is the best final methodology.

Why:

1. Baseline is not near-optimal if Stage C reaches RMSE 0.0416 with all primary targets under 10%.
2. Accepting baseline hides the strongest evidence that the model can reproduce Indira physiology.
3. The reason for rejecting Stage C is secondary waveform extrema, not invalid physiology.
4. The ASD workflow already distinguishes primary targets from secondary guards. Treating secondary waveform guards as absolute vetoes contradicts that hierarchy.

More defensible thesis framing:

> Baseline is a strong seeded starting point, but Stage C is the best calibrated operating point. Stage C is accepted with secondary waveform warnings, or at minimum reported as the best valid/plausible candidate while accepted-baseline rollback is documented as a conservative governance outcome.

---

## 6. Best Option For Thesis Deadline

Avoid new expensive GSA or broad reruns.

Recommended path:

1. Keep Stage A rejected.
2. Keep Stage C result.
3. Export both `accepted_candidate` and `best_rejected_candidate`.
4. Update rollback interpretation so secondary waveform extrema can be reported as warnings when:
   - primary RMSE improves strongly,
   - all primary targets are within 10%,
   - validity passes,
   - plausibility has no FAIL.

This is better than:

- rerunning Stage A repeatedly,
- changing parameter bounds ad hoc,
- relaxing every guard blindly,
- pretending baseline is the only result.

---

## 7. Practical Decision For Current Code

Immediate code change:

> Always export the best candidate even if rollback occurs.

This has now become necessary because the current CSV export only shows the accepted candidate. When rollback happens, the accepted CSV becomes baseline and the best calibrated candidate is hidden unless the MAT file is manually inspected.

Future optional code change:

> Add an `accepted_with_secondary_warnings` state.

This would preserve governance while avoiding the false impression that Stage C is unusable.

---

## 8. Recommended Thesis Wording

> Stage A calibration was rejected because it worsened the primary systemic flow target, indicating that the selected vascular/shunt parameter subset could not independently resolve the Qp-Qs trade-off. Stage C, which added ventricular passive elastance parameters, produced a substantially improved primary pressure-flow fit with RMSE 0.0416 and all seven primary targets within 10%. The candidate passed numerical validity and parameter plausibility checks, but triggered secondary waveform warnings in SAP_max and PAP_min. Therefore, Stage C is interpreted as the best calibrated operating point with secondary waveform limitations, while the rollback result is retained as a conservative governance record.

---

## 9. Bottom Line

For Indira:

- Stage A rollback: correct and final.
- Stage C rollback: too conservative if secondary waveform guards are hard vetoes.
- Best methodological choice near thesis deadline: preserve and report Stage C as the best calibrated candidate with secondary waveform warnings, while documenting the conservative rollback logic.

