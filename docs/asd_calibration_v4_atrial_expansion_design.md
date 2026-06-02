# ASD Calibration v4 — Atrial Expansion Design & Methodology Q&A

**Date:** 2026-06-02
**Context:** After v1-v3 vascular calibration attempts failed to achieve accepted
results, atrial expansion was designed as an exploratory next step.

---

## 1. What Is Atrial Expansion?

**Definition:** Adding parameters that directly control P_LA and P_RA into the
active calibration set, bypassing GSA ranking.

### Why Bypass GSA?

GSA measures sensitivity **around the baseline operating point**. At Zoya's
baseline (Qp/Qs=1.42, LAP≈7 mmHg, RAP≈7 mmHg, ΔP≈0), atrial parameters
appear insensitive because:

```
Baseline:    P_LA ≈ 7, P_RA ≈ 7  →  ΔP ≈ 0  →  Q_ASD small
GSA result:  V0.LA ST < 0.05     →  "not influential"

But after calibration pushes P_LA to 10+ mmHg:
Calibrated:  P_LA ≈ 10, P_RA ≈ 7  →  ΔP = 3  →  Q_ASD larger
             → V0.LA changes now HAVE large effect on ΔP
             → GSA at baseline couldn't detect this
```

**Atrial expansion adds parameters based on physiological reasoning:
Q_ASD = f(P_LA - P_RA), and P_LA/P_RA are controlled by atrial mechanics,
not by vascular resistance.**

### Parameters Added

| Parameter | How It Controls Shunt |
|---|---|
| `V0.LA` | Left atrial unstressed volume → shifts P_LA operating point |
| `V0.RA` | Right atrial unstressed volume → shifts P_RA operating point |
| `E.LA.EB` | Left atrial passive elastance → controls P_LA at given volume |

### Parameter Intentionally Excluded

| Parameter | Why Excluded |
|---|---|
| `E.RA.EB` | RAP clinical data is missing for Zoya. Free RA elastance could let the optimizer fabricate a shunt gradient by arbitrarily lowering/raising RAP without clinical anchor |

---

## 2. Why Label It EXPLORATORY?

**Methodological honesty.** Parameters added outside the GSA evidence chain
must be transparently labeled:

> *"Atrial parameters (V0.LA, V0.RA, E.LA.EB) were added exploratorily because
> GSA did not detect their sensitivity around the baseline — yet ASD physiology
> dictates that P_LA and P_RA are direct determinants of shunt flow. This
> expansion was necessary after three calibration attempts (v1-v3) failed to
> raise LAP and Qp/Qs through vascular parameters alone. Results from this
> stage are labeled exploratory and interpreted with appropriate caution."*

**Effect on thesis:**
- Not presented as "final calibrated operating point"
- Presented as "exploratory atrial expansion to investigate the LA-RA
  pressure gradient bottleneck identified in v1-v3"
- If it succeeds → strong physiological argument for including atrial
  parameters in the standard active set
- If it fails → documented limitation that even direct atrial control
  cannot overcome the model's constraint

---

## 3. RAP Physiological Guard — Literature Justification

### Guard: RAP must remain in [0, 15] mmHg

| Source | Normal Pediatric RAP |
|---|---|
| Rudolph AM (2009). *Congenital Diseases of the Heart*. 3rd ed. Wiley-Blackwell. | 2-6 mmHg (child) |
| Baumgartner H et al. (2020). 2020 ESC Guidelines for adult congenital heart disease. *European Heart Journal*, 42(6):563-645. | 0-8 mmHg (adult); RAP > 15 = sign of RV dysfunction or pulmonary hypertension |
| Feltes TF et al. (2011). Indications for cardiac catheterization and intervention in pediatric cardiac disease. *Circulation*, 123(22):2607-2652. | 1-5 mmHg (infant), 2-6 mmHg (child) |
| Webb G, Gatzoulis MA. (2006). Atrial septal defect in the adult. *Circulation*, 114(15):1645-1653. | RAP rarely exceeds 12 mmHg in isolated secundum ASD without pulmonary hypertension |

### Bound Justification

| Bound | Reason |
|---|---|
| **Lower = 0** | Negative RAP is non-physiological (except transiently during deep inspiration). Sustained negative RAP indicates model error |
| **Upper = 15** | RAP > 15 mmHg in isolated ASD without pulmonary hypertension is extremely rare. Zoya's PAP_mean = 23 mmHg (mildly elevated, not systemic) makes RAP > 15 implausible. Values above 15 suggest the optimizer is fabricating a shunt gradient artificially |

### Implementation

```matlab
J_guard = 50 × deviation²   % aggressive — RAP outside [0,15] is non-physiological
```

The penalty is stronger than the MAP guard (10×) because RAP has no clinical
target — if the optimizer drives RAP to extremes, there's no anchor to pull
it back.

---

## 4. Impact of LA-RA Gradient Data on Future Patients

### Patient with Measured ΔP_LA-RA — Game Changer

If a future patient has direct LA-RA pressure gradient measurement, the
calibration becomes significantly more constrained:

**a. Direct shunt seeding:**
```matlab
% With ΔP and Q_ASD available:
R_ASD = ΔP_ASD / Q_ASD  % direct calculation — no calibration needed for shunt
% OR for orifice mode:
Cd = Q_ASD / (A × √(2 × ΔP / ρ))  % direct Cd estimation
```

Zoya cannot do this → Cd must be fully calibrated (difficult).
Ideal patient CAN → Cd/R_ASD starts near correct value → calibration only fine-tunes.

**b. Additional calibration target:**
```
Zoya targets:    6 (QpQs, Qp, Qs, MAP, PAP, LAP)
Ideal targets:   7 (+ ΔP_LA-RA)
```

More targets = better identifiability = parameters more constrained = fewer
spurious solutions. The additional target is **orthogonal** to Qp/Qs —
providing independent information about shunt mechanics.

**c. Independent validation:**
The model could match Qp/Qs but fail to match ΔP → this would reveal issues
in the shunt model (orifice vs linear, Cd estimation, effective area). This
is a validation pathway Zoya cannot provide.

### Will v4 Changes Work for Future Patients?

**Yes. All v4 changes are patient-generic:**

| v4 Feature | Applies to All Patients? | Customizable? |
|---|---|---|
| Atrial expansion (V0.LA, V0.RA, E.LA.EB) | Yes — P_LA/P_RA control always relevant for ASD | Can be disabled per patient |
| RAP guard [0, 15] | Yes — universal physiological bound | Override via `calib.rapBand` |
| MAP guard [85, 95] | Yes — default pediatric normotensive | Override via `calib.mapBand` |
| Ratio-chasing guard | Yes — should never improve QpQs by collapsing Qs | — |
| asd.Cd forced | Yes — shunt knob always relevant | — |
| EXPLORATORY label | Only when GSA doesn't select params | Removed if future GSA selects them |

### Zoya = Worst-Case Scenario

Zoya has the sparsest data: no ΔP, no RAP, no volumes, no SVR/PVR. She is the
**hardest patient to calibrate**. If the pipeline produces defensible results
for Zoya (even if RMSE > 0.10), it will perform even better for patients with
more complete data. This makes Zoya an excellent primary case for the thesis:
she demonstrates the framework's behavior under maximum uncertainty.

---

## 5. v4 Execution Plan

```matlab
% Run (env vars already set from previous session)
run('scripts/run_zoya_asd_calibration.m');
```

**Expected active set:**
- Stage A: 9 params (6 vascular/shunt + 3 atrial expansion)
- Stage C: +3 ventricular (if RMSE ≥ 0.10)

**Guards active:**
- MAP band [85, 95] — lambda 5.0
- RAP band [0, 15] — lambda 3.0
- Ratio-chasing — lambda 8.0
- Re-weight QpQs 5×, Qp 3×, LAP 2×

**Success criteria (exploratory):**
- LAP rises above 9.4 mmHg (previous best)
- Qp/Qs improves beyond 2.82 (previous best without cheating)
- No RAP violation
- No validity gate failure
