# ASD Pre-Closure Active Set Decision Memo

**Date:** 2026-05-31  
**Patient:** Zoya (7.07 yr, ASD 19.25 mm, Qp/Qs = 3.79)  
**Context:** GSA 26-parameter full Sobol (N=128, Saltelli/Jansen estimator) completed.
Active-set selection uses only **hard_primary** target-tier metrics: QpQs, Qp, Qs,
PAP_mean, SAP_mean, LAP_mean. No ventricular volume/function data exist pre-closure.

---

## 1. GSA Results — Top 6 Ranked Parameters

Parameters ranked by Mean_ST across primary pressure-flow targets (ST >= 0.10 threshold).

| # | Parameter | Group | Class | Mean_ST | Max_ST | Sensitive Targets |
|---|---|---|---|---|---|---|
| 1 | **E.RV.EB** | C | RV passive elastance | 0.194 | **0.412** | QpQs, Qp, PAP |
| 2 | **E.LV.EB** | C | LV passive elastance | 0.227 | **0.353** | QpQs, Qp, Qs, SAP, PAP, LAP |
| 3 | **V0.SVEN** | B | Systemic venous V0 | 0.161 | 0.274 | Qp, Qs, SAP, PAP, LAP |
| 4 | **C.PAR** | A | Pulmonary arterial C | 0.116 | 0.206 | Qp, PAP, LAP |
| 5 | **C.SVEN** | B | Systemic venous C | 0.109 | 0.185 | Qp, SAP, PAP, LAP |
| 6 | **R.SC** | A | Systemic capillary R | 0.090 | **0.327** | Qs, SAP |

### Notable Parameters NOT in Top 6

| Parameter | Group | Mean_ST | Max_ST | Why Not Selected |
|---|---|---|---|---|
| **asd.Cd** | A | <0.10 | <0.10 | Shunt geometry 19.25 mm is already "wide open" — Cd variation has limited additional effect on QpQs at this diameter |
| E.LA.EA | B | <0.10 | <0.10 | Atrial elastance sensitivity low at this operating point |
| E.RA.EA | B | <0.10 | <0.10 | Atrial elastance sensitivity low at this operating point |
| R.PAR | A | <0.10 | <0.10 | Pulmonary resistance less sensitive than compliance for ASD |
| R.SAR | A | <0.10 | <0.10 | Systemic arterial resistance has low sensitivity for this case |

### Interpretation

1. **Ventricular passive elastance dominates** — E.LV.EB and E.RV.EB control diastolic stiffness, which sets ventricular filling and therefore stroke volume, which cascades to ALL pressure-flow outputs. This is physiologically expected and NOT a GSA artifact.

2. **Venous preload matters** — V0.SVEN and C.SVEN (systemic venous reservoir) rank highly, confirming that preload/venous return couples strongly to atrial filling, shunt gradient, and pulmonary flow in ASD.

3. **Pulmonary compliance** — C.PAR sensitivity is expected: right ventricular afterload is pulmonary, and ASD loads the right heart.

4. **asd.Cd is surprisingly low** — The 19.25 mm ASD diameter is so large that the shunt behaves like a "common atrium" — Cd variation within [0.2, 1.2] changes flow magnitude only marginally.

---

## 2. Decision Options

### Option A — Full GSA-Driven (6 parameters)

**Active set:** E.RV.EB, E.LV.EB, V0.SVEN, C.PAR, C.SVEN, R.SC

| Pro | Con |
|---|---|
| Methodologically consistent: GSA results determine active set, no manual override | Ventricular elastance optimized without LVEDV/RVEDV/EF targets — identifiability concern |
| Maximises degrees of freedom to match 6 clinical targets | Risk: calibrated E.LV.EB and E.RV.EB could drift to implausible values that still reduce pressure-flow RMSE |
| All 6 parameters have ST > 0.10 for at least one primary target | Thesis examiner may ask: "how do you validate the calibrated ventricular elastance without echo data?" |
| Paper trail is clean: "GSA ranked → selected" | Requires tight plausibility gates and strict ventricular bounds |

**Bounds strategy for ventricular parameters under Option A:**
- E.LV.EB: [0.60×, 2.50×] (Zhang 2019, already in registry)
- E.RV.EB: [0.60×, 2.50×] (Zhang 2019, already in registry)
- Post-optimisation: if E.LV.EB or E.RV.EB are flagged as plausibility WARNING or FAIL → rollback

---

### Option B — Physiology-Constrained (4 parameters, exclude ventricular)

**Active set:** V0.SVEN, C.PAR, C.SVEN, R.SC

| Pro | Con |
|---|---|
| Conservative: only parameters directly interpretable from available data | Ignores GSA evidence that ventricular elastance is the MOST sensitive parameter |
| No identifiability concerns — all 4 parameters map directly to measurable physiology | May underfit: with only 4 parameters matching 6 targets, residual mismatch likely remains larger |
| Easier to defend at thesis examination | Examiner may ask: "if GSA says ventricular matters, why did you exclude it?" |
| Ventricular parameters stay at pediatric scaled baseline (validated against healthy baseline) | |

---

### Option C — Staged (6 parameters, but ventricular opened only if vascular insufficient)

**Active set Stage 1 (vascular/preload only):** V0.SVEN, C.PAR, C.SVEN, R.SC

After Stage 1 calibration:
- If RMSE < 0.15 (15% across all primary targets) → STOP, ventricular stays fixed
- If RMSE >= 0.15 → open ventricular: E.RV.EB, E.LV.EB as Stage 2

| Pro | Con |
|---|---|
| Scientifically rigorous: demonstrates that vascular parameters alone CAN or CANNOT match targets | Requires two calibration runs (more compute time) |
| If Stage 1 succeeds → strong argument for model parsimony | If Stage 1 fails → same as Option A but with extra justification step |
| If Stage 1 fails → opening ventricular is justified by (a) GSA evidence + (b) demonstrated insufficiency of vascular calibration | |
| Clean paper trail: "vascular first → insufficient → ventricular added per GSA ranking" | |

---

### Option D — Expanded (6 parameters + asd.Cd despite low ST)

**Active set:** Same as Option A + asd.Cd

| Pro | Con |
|---|---|
| Shunt knob is the direct ASD parameter — including it is physiologically defensible | asd.Cd has ST < 0.10 — adds a parameter with minimal leverage |
| Future-proof: if Cd is important for other patients with smaller ASD, having it in the set ensures consistency | Extra parameter = extra identifiability burden with no clear benefit for Patient Zoya |

---

## 3. Scientific Recommendation

**Recommended: Option C — Staged Approach**

**Rationale:**

1. **Methodological alignment with Hafiz-Keisya VSD**
   The VSD pipeline uses staged calibration (Stage A: vascular → Stage B: chamber).
   Option C mirrors this while adapting to the ASD-specific context where
   ventricular volume targets are absent.

2. **Thesis defensibility**
   "We first calibrated vascular and preload parameters (V0.SVEN, C.PAR, C.SVEN, R.SC)
   because they are directly interpretable from available pressure-flow targets.
   When residual mismatch exceeded X%, we opened ventricular passive elastance
   (E.LV.EB, E.RV.EB) per GSA ranking, constrained by Zhang 2019 pediatric bounds."

   This narrative is stronger than either:
   - "We opened ventricular because GSA said so" (Option A — ignores the data gap), or
   - "We ignored ventricular" (Option B — ignores the GSA evidence).

3. **Quantitative stopping rule**
   Stage 1 success/failure is adjudicated by a clear, pre-registered threshold
   (e.g., RMSE < 0.15), not by post-hoc judgment. This prevents cherry-picking.

4. **Fallback guarantee**
   If Stage 1 already achieves acceptable RMSE, the model is parsimonious
   (4 parameters, 6 targets) and the thesis demonstrates that ASD pre-closure
   hemodynamics can be explained by vascular + preload adjustments alone —
   a defensible physiological conclusion.

---

## 4. Implementation Plan

```
Step 2a: Calibrate Stage 1 (V0.SVEN, C.PAR, C.SVEN, R.SC)
         ↓
     RMSE < 0.15? ── YES ──→ Report Stage 1 as final; document why
         │                     ventricular was not needed despite GSA ranking
         │
         NO
         ↓
Step 2b: Calibrate Stage 2 (add E.RV.EB, E.LV.EB, same bounds)
         ↓
     Plausibility OK? ── YES ──→ Report Stage 2 as final
         │
         NO
         ↓
     ROLLBACK to Stage 1 accepted candidate; document why ventricular
     calibration failed plausibility despite reducing RMSE
```

---

## 5. Bounds for Active Set (from ASD Parameter Registry)

| Parameter | Current | lb | ub | Source |
|---|---|---|---|---|
| V0.SVEN | 564.7 | 395.3 | 762.4 | Blood volume consistency |
| C.PAR | 8.017 | 5.612 | 11.625 | Windkessel SV/PP |
| C.SVEN | 13.665 | 6.832 | 24.597 | Kung R-C coupled |
| R.SC | 1.756 | 0.703 | 4.391 | Kung 2013 |
| E.RV.EB | 0.137 | 0.082 | 0.342 | Zhang 2019 |
| E.LV.EB | 0.176 | 0.105 | 0.439 | Zhang 2019 |

---

## 6. Open Questions for Supervisor Discussion

1. **RMSE threshold for Stage 1 acceptance:** 0.15 (15% mean relative error across
   6 primary targets) — reasonable for preliminary calibration or too lenient?

2. **asd.Cd inclusion:** Not in top 6 by GSA. Should it be forced into the active
   set as a "mandatory shunt knob" regardless of ST ranking, for consistency
   across patients?

3. **Post-calibration GSA:** Should a second Sobol run be performed after calibration
   to confirm that parameter rankings are stable at the calibrated operating point?
   (VSD pipeline does this via `gsa_pce_setup` + `gsa_run_pce`.)

4. **N=128 vs N=256:** Current GSA used N=128. For thesis-final confidence, should
   the GSA be re-run at N=256 and with bootstrap 95% CI before locking the active set?

---

## 7. Supervisor's Perspective — Recommended Answers

### Q1: RMSE Threshold for Stage 1 Acceptance

**Recommended value: 0.10 (10%), not 0.15.**

**Reasoning:**

A 15% relative error threshold is too lenient for a pre-closure ASD case where
the model already produces Qp/Qs = 1.42 vs target 3.79. At RMSE = 0.15, the
model could still underpredict Qp/Qs by a factor of 2-3x — this would be
physiologically meaningless.

Thresholds should be benchmarked against clinical measurement uncertainty:

| Metric | Typical clinical uncertainty | 10% of target |
|---|---|---|
| Qp/Qs = 3.79 | ±15-20% (Fick oximetry) | ±0.38 |
| PAP_mean = 23 | ±2-3 mmHg (RHC) | ±2.3 mmHg |
| SAP_mean = 90 | ±3-5 mmHg (arterial line) | ±9 mmHg |
| Qp = 12.27 | ±15% (Fick) | ±1.2 L/min |

An RMSE of 0.10 means the model's average normalized error is 10% — within or
near measurement uncertainty for most targets. RMSE = 0.15 would exceed
measurement uncertainty for PAP and Qp/Qs.

**Practical note:** If Stage 1 cannot achieve RMSE < 0.10, that itself is a
finding — it demonstrates that vascular + preload parameters alone cannot
explain the observed shunt severity, which justifies opening ventricular
parameters. Do not relax the threshold to avoid this conclusion; the
conclusion IS the scientific result.

---

### Q2: asd.Cd Inclusion Despite Low ST

**Recommended answer: Include asd.Cd as the 7th parameter, but DO NOT force it
if it degrades calibration.**

**Reasoning:**

Three arguments converge:

**a) Physiological primacy.** `asd.Cd` is the ONLY parameter in the model that
directly controls shunt orifice behavior. Every other parameter affects shunt
flow indirectly (through pressure gradients, preload, afterload). Excluding the
direct shunt knob from calibration is methodologically awkward — it is
analogous to calibrating a stenosis model without touching the stenosis
coefficient.

**b) GSA result interpretation.** The low ST for `asd.Cd` has a specific
physiological explanation at Zoya's large defect size (19.25 mm = 291 mm²).
At this diameter, the shunt behaves like a "common atrium" — the orifice is so
large that varying Cd within [0.2, 1.2] changes flow only marginally. This is
NOT evidence that Cd is physiologically irrelevant; it is evidence that the
current ASD is near the "unrestrictive" regime. The GSA captured this correctly.

**c) Cross-patient consistency.** For patients with smaller ASDs (e.g., 5-10 mm),
Cd WILL show high ST. If the calibration framework excludes Cd for Zoya but
includes it for other patients, the methodology becomes inconsistent and harder
to defend. Including Cd as a standard calibration parameter ensures the same
pipeline works for all patients.

**Implementation:**
- Add `asd.Cd` as a 7th parameter in Stage 1
- Bounds: [0.20, 1.20] (absolute, from VSD orifice Cd prior)
- If Cd hits bounds during optimization → document as "shunt at unrestrictive limit"
- If Cd drift degrades RMSE → it will self-correct via the objective function

**Note on parsimony:** Adding 1 parameter to go from 6→7 active parameters,
with 6 clinical targets, is still a reasonably determined system. The
identifiability concern is manageable given Cd's narrow bounds.

---

### Q3: Post-Calibration GSA

**Recommended answer: Yes, but as a lightweight confirmatory step, not a full
re-run at N=128.**

**Reasoning:**

The VSD pipeline performs post-calibration GSA for two reasons:
1. Confirm that parameter sensitivity rankings are stable at the calibrated
   operating point (vs. the pre-calibration baseline)
2. Provide final Sobol indices for publication

For the ASD thesis:

**What to do:**
- After calibration completes, run a **confirmatory GSA at N=64** (or reuse the
  existing N=128 infrastructure but at reduced cost by evaluating only the
  active set parameters around the calibrated point)
- Primary output: a 6×6 heatmap (6 active params × 6 primary targets) at the
  calibrated operating point
- Compare: does the ranking order change? Document any shifts.

**What NOT to do:**
- Do NOT re-run full 26-parameter GSA at N=256 post-calibration. The
  computational cost (~9,000+ simulations) is not justified for a confirmatory
  step when the pre-calibration GSA already established the parameter landscape.

**Thesis framing:**
> "Post-calibration Sobol analysis at the calibrated operating point confirmed
> that parameter sensitivity rankings were consistent with the pre-calibration
> screening (Figure X). No parameter crossed the ST=0.10 threshold in either
> direction, validating the active-set selection."

---

### Q4: N=128 vs N=256 for Final GSA

**Recommended answer: Re-run at N=256 with bootstrap 95% CI for the
thesis-final figure, but ONLY for the primary target metrics.**

**Reasoning:**

**a) Current N=128 is borderline for d=26.** The Saltelli estimator precision
scales as ~1/√N. At N=128, the 95% confidence interval width for ST ≈ 0.1
is approximately ±0.05 (Jansen 1999). This means a parameter with ST=0.09
(just below the 0.10 threshold) could have a true ST anywhere from 0.04 to 0.14
— the ranking for borderline parameters is NOT reliable.

At N=256, the CI narrows to approximately ±0.035, which is sufficient to
confidently classify parameters near the 0.10 threshold.

**b) Bootstrap CI is essential for thesis defense.** Without CI, the ranking
is just a point estimate. A thesis examiner will ask: "How do you know
parameter X is truly more influential than parameter Y?" Bootstrap CI provides
the statistical answer: "ST_X = 0.21 [0.15, 0.27] vs ST_Y = 0.09 [0.03, 0.15]
— the confidence intervals overlap, but X's lower bound exceeds Y's upper
bound for metric Z."

**c) Cost-benefit is favorable.** N=256 × (26+2) = 7,168 simulations.
At ~1-2 seconds per simulation with warmup=30 cycles, this is approximately
2-4 hours of runtime — acceptable for a thesis-final run that need only be
performed once.

**Implementation priority:**
1. First: proceed with calibration using the N=128 active set (the ranking is
   stable enough for practical purposes)
2. In parallel or after: re-run GSA at N=256 with bootstrap CI
3. Replace the N=128 figures with N=256 + CI figures in the final thesis
4. If the N=256 ranking changes the active set → document the change and
   justify the final choice

**Bootstrap implementation note:** Bootstrap is computationally cheap — it
only resamples the already-computed YA, YB, YAB matrices. The ~7,000 ODE
evaluations are the expensive part; the 200 bootstrap iterations add negligible
cost.

---

## 8. Revised Implementation Plan (Incorporating Supervisor Feedback)

```
PHASE 1 — Calibration (now, with N=128 active set)
  ├─ Stage 1: V0.SVEN, C.PAR, C.SVEN, R.SC, asd.Cd  (5 params)
  │   └─ Target: RMSE < 0.10
  ├─ Stage 2 (if needed): + E.RV.EB, E.LV.EB  (7 params total)
  └─ Post-cal: validation, plausibility, rollback decision

PHASE 2 — Confirmatory (parallel or after calibration)
  ├─ Post-calibration GSA: N=64, active params only, around calibrated point
  └─ Compare pre vs post ST rankings

PHASE 3 — Thesis Final (before submission)
  ├─ Re-run GSA at N=256 with bootstrap 95% CI
  ├─ Replace all figures with N=256 versions
  └─ Document any ranking changes and justification
```

---

## 9. Summary of Decisions

| Question | Answer | Rationale |
|---|---|---|
| RMSE threshold | **0.10** (not 0.15) | Within clinical measurement uncertainty |
| asd.Cd inclusion | **Yes** — add as 7th param | Physiological primacy + cross-patient consistency |
| Post-cal GSA | **Yes** — lightweight N=64 confirmatory | Confirms ranking stability at calibrated point |
| N=128 → N=256 | **Yes** — re-run before thesis final | CI precision needed for thesis defense |
| Bootstrap CI | **Yes** — add to compute_sobol_indices | Essential for thesis statistical rigor |

