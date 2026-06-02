# ASD Calibration v4 — Accepted Candidate: Opencode vs ChatGPT Comparison

**Date:** 2026-06-02
**Context:** v4 atrial expansion achieved ACCEPTED status (first time). Both AI
assistants provided analysis. This document compares their perspectives for
thesis consultation.

---

## 1. Run Summary — What v4 Achieved

| Metric | Baseline | v4 Accepted | Target | Error |
|---|---|---|---|---|
| QpQs | 1.42 | 2.27 | 3.79 | 40% |
| Qp_Lmin | 3.61 | 5.56 L/min | 12.27 | 55% |
| Qs_Lmin | 2.54 | 2.45 L/min | 3.23 | 24% |
| LAP_mean | 6.9 | 7.9 mmHg | 14 | 43% |
| SAP_mean | 90.3 | 84.8 mmHg | 90 | 6% |
| PAP_mean | 18.8 | 19.1 mmHg | 23 | 17% |
| **RMSE** | **0.45** | **0.35** | — | **22% improvement** |
| **ΔP_LA-RA** | 0.22 | 0.65 mmHg | — | **3× increase** |
| **Q_ASD** | 1.07 | 3.12 L/min | — | **3× increase** |
| **All 11 validity gates** | — | **PASS** | — | ✅ |
| **Clinical fit guard** | — | **PASS** | — | ✅ |
| **Plausibility** | — | 10 OK, 2 WARNING | — | ✅ |
| **Rollback** | — | **NO** — ACCEPTED | — | ✅ |

---

## 2. Opencode's Position

### Core Argument

v4 is sufficient for Zoya. The user has an accepted candidate, documented progress
across 4 calibration iterations, and a defense-ready narrative. Time should be
spent on writing the thesis and running subsequent patients — not on chasing
RMSE < 0.10 that may be fundamentally unachievable with sparse data.

### Recommended Next Action

**Stop Zoya. Move to Patient X.**

| Reason | Detail |
|---|---|
| Accepted candidate exists | First time all gates passed across 4 attempts |
| Narrative is complete | GSA → calibration → gates → rollback → atrial expansion → accepted |
| LAP bottleneck is documented | Not a bug — a model limitation from sparse data |
| Time efficiency | 7 patients waiting; Zoya already consumed most development time |
| Thesis value | 4-iteration journey is more impressive than 1 perfect run |

### Strengths of This Position

- Respects the user's stated desire to move to other patients
- Acknowledges that RMSE 0.10 may be unachievable (Qp target 12.27 L/min is 3.4× baseline CO)
- Values the governance narrative (v1-v3 rollback → v4 accepted) as scientific evidence
- Practical: thesis deadlines are real

### Weaknesses

- Could be seen as "settling" rather than exhausting all options
- Doesn't address the `ratio_chasing_guard` hardcoding bug
- Doesn't propose a mechanism audit to strengthen the v4 narrative

---

## 3. ChatGPT's Position

### Core Argument

v4 is a milestone but NOT sufficient as "final calibrated operating point."
One more diagnostic step (mechanism audit) is needed before writing up.
The RMSE 0.35 and dependence on Stage C ventricular parameters (no volume data)
require careful qualification in the thesis.

### Recommended Next Action

**Freeze v4 → mechanism audit → optional targeted v5**

| Step | Detail |
|---|---|
| 1. Freeze v4 | Don't overwrite. Save as "accepted exploratory candidate" |
| 2. Mechanism audit | Compare baseline vs v4: ΔP_LA-RA, Q_ASD, RVSV, RVEDV, LAP. This strengthens the thesis narrative |
| 3. Optional v5 | Targeted pulmonary venous expansion (`C.PVEN`) as one-last diagnostic, NOT default |
| 4. Fix `ratio_chasing_guard` | Currently hardcodes 3.79. Must read from `calib.targets.QpQs` for future patients |
| 5. Then other patients | After mechanism audit (and optional v5) |

### Strengths of This Position

- More rigorous: mechanism audit strengthens the scientific narrative
- Identifies a real bug (`ratio_chasing_guard` hardcoding)
- Correctly flags Stage C ventricular dependence as a methodological caveat
- Proposes targeted (not blind) next diagnostics

### Weaknesses

- Risk of "one more run" syndrome — could delay other patients indefinitely
- Mechanism audit takes writing time, not just compute time
- v5 (`C.PVEN`) has the same identifiability problem as other atrial parameters
- Potentially over-cautious: an accepted candidate with documented limitations is already thesis-worthy

---

## 4. Points of Agreement

| Topic | Both Agree |
|---|---|
| Atrial expansion was the missing key | ✅ — v4 mechanism proves it |
| v2 was "ratio cheating" | ✅ — clinically meaningless |
| v4 is a milestone, not perfect | ✅ — RMSE 0.35 is progress, not completion |
| LAP remains the bottleneck | ✅ — stuck at ~8 vs target 14 |
| Stage C dependence = caveat | ✅ — must be noted in thesis |
| Governance framework works | ✅ — v1-v3 rollback → v4 accepted proves it |

---

## 5. Points of Disagreement

| Topic | Opencode | ChatGPT |
|---|---|---|
| **Stop Zoya now?** | Yes — enough for thesis | No — do mechanism audit first |
| **v5 pulmonary expansion?** | Not needed | Optional targeted test |
| **Priority** | Move to other patients | Strengthen Zoya narrative |
| **Bug in ratio_chasing_guard** | Deferred (secondary) | Must fix before other patients |

---

## 6. Synthesis — Recommended Path for Thesis Consultation

Based on both perspectives, the following compromise is recommended:

### Immediate (Before Other Patients)

1. **Freeze v4** as `accepted_exploratory_candidate` — save all outputs
2. **Mechanism audit** (1-2 hours writing, no compute):
   - Build comparison table: baseline vs v4 for ΔP_LA-RA, Q_ASD, RVSV, RVEDV, LAP, RAP, Qp/Qs
   - Write interpretation: "atrial expansion amplified shunt mechanism (ΔP 3×, Q_ASD 3×) but could not fully close the gap to clinical targets"
3. **Fix `ratio_chasing_guard` hardcoding** (5 min code change):
   - Replace hardcoded `3.79` with `calib.targets.QpQs`
   - This is needed for all future patients

### After Mechanism Audit

4. **Move to Patient X** (primary case #2) — test if the pipeline generalizes
5. **After Patient X**: optional v5 for Zoya with `C.PVEN` if time permits
6. **Write thesis** with Zoya as primary case showing the full journey (v1→v4)

---

## 7. Thesis Framing for v4

Regardless of which path is chosen, v4 should be presented as:

> *"Calibration v4 incorporated exploratory atrial expansion (V0.LA, V0.RA,
> E.LA.EB) based on physiological reasoning derived from the v1-v3 failure
> pattern — persistent LAP underestimation limiting shunt flow. This expansion
> produced the first accepted candidate (all 11 validity gates, clinical fit
> guard, and plausibility checks passed). The calibrated parameters demonstrated
> correct ASD mechanism amplification: ΔP_LA-RA increased 3×, Q_ASD increased
> 3×, and RV stroke volume showed appropriate volume loading. However,
> quantitative targets remained under-predicted (RMSE 0.35), particularly
> Qp (55% error) and LAP (43% error), reflecting the fundamental limitation
> of calibrating a 14-state lumped-parameter model with sparse clinical data
> that lacks atrial pressure gradient, RAP, and ventricular volume measurements."*

---

## 8. Quick Reference — v1→v4 Journey

| Run | Params | Key Change | RMSE | Accepted? | Lesson |
|---|---|---|---|---|---|
| v1 | 4 | Vascular only | 0.39 | ❌ | Vascular params insufficient |
| v2 | 5 (+Cd) | asd.Cd added (bug: not wired) | 0.32 | ❌ | Ratio chasing detected |
| v3 | 6 (+guards) | Ratio-chasing guard | 0.43 | ❌ | Guard prevented cheating; SVR violation |
| v4 | 9 (+atrial) | EXPLORATORY atrial expansion | 0.35 | ✅ | Atrial control = missing key |
