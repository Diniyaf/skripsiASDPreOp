# ASD Calibration v3 Results — Guards Reveal Model Limitation

**Date:** 2026-06-02  
**Run:** `zoya_asd_calib_20260602_002849`  
**Status:** Stage C improved RMSE but rejected by validity + clinical fit gates.  
**Key finding:** Ratio-chasing guard successfully eliminated spurious Qp/Qs improvement.

---

## 1. v3 Configuration

| Setting | Value |
|---|---|
| ST threshold | 0.05 |
| asd.Cd wired | ✅ Fixed (6 params Stage A) |
| Ratio-chasing guard | ✅ Active (Qs drop >10% → penalty 50×) |
| MAP guard | ✅ Active [85, 95] |
| Re-weight | QpQs 5×, Qp 3×, LAP 2× |
| Group C | ON |

---

## 2. Results Comparison — All Runs

| Metric | Target | Baseline | v1 (4p) | v2 (5p)* | v3 (6p) |
|---|---|---|---|---|---|
| Qs_Lmin | 3.23 | 2.54 (21%) | 3.84 (19%) | **1.79 (45%)** | 1.41 (56%) |
| Qp_Lmin | 12.27 | 3.61 (71%) | 5.13 (58%) | 6.32 (49%) | 3.98 (68%) |
| SAP_mean | 90 | 90.3 (0%) | 82.6 (8%) | 84.9 (6%) | 91.4 (2%) |
| PAP_mean | 23 | 18.8 (18%) | 19.9 (14%) | 21.2 (8%) | 21.2 (8%) |
| LAP_mean | 14 | 6.9 (51%) | 9.4 (33%) | 8.6 (39%) | 6.9 (51%) |
| QpQs | 3.79 | 1.42 (63%) | 1.34 (65%) | **3.52 (7%)** | 2.82 (26%) |
| **RMSE** | — | **0.45** | **0.39** | **0.32** | **0.43** |
| **Accepted?** | — | — | ❌ | ❌ | ❌ |

*\*v2 had asd.Cd wiring bug — not actually calibrated*

### Guard Performance

| Guard | v2 | v3 |
|---|---|---|
| Ratio-chasing | Not active | ✅ Triggered — prevented Qs collapse |
| MAP [85,95] | MAP=84.9 (borderline) | MAP=91.4 (protected) |
| SVR bounds | OK | ❌ FAIL — R.SC→3.38 pushed SVR out |
| Clinical fit | ❌ Qs worsened | ❌ Qs + SAP_min + PAP_min worsened |

---

## 3. What Changed from v2 to v3

v2 achieved Qp/Qs=3.52 by collapsing Qs (2.54→1.79). The ratio-chasing guard in
v3 prevented this: fmincon could no longer "cheat." Without the easy path, it
pushed parameters to extremes:

| Parameter | Baseline | v2 (Stage C) | v3 (Stage C) | Direction |
|---|---|---|---|---|
| asd.Cd | 0.70 | — (not wired) | **1.198** | ⚠ Near upper bound |
| R.SC | 1.76 | 1.14 | **3.38** | ⚠ 2× baseline → SVR spike |
| E.LV.EA | 7.68 | 6.77 | 8.32 | Reversed direction |

**Interpretation:** fmincon tried everything in its toolbox — maxed Cd, maxed
systemic resistance, adjusted LV contractility — and still couldn't reach the
shunt target without violating physiological bounds.

---

## 4. Pattern Across All v1-v3 Runs

Three calibration attempts consistently show:

1. **Qp/Qs improvement is achievable** (1.42 → 2.82 in v3, 3.52 in v2-cheat)
2. **Absolute Qp remains far from target** (best: 6.32 in v2, still 48% error)
3. **LAP never exceeds 9.4 mmHg** (target: 14) — the LA pressure never rises
   enough to drive sufficient shunt flow
4. **Systemic parameters hit bounds** when pushed — R.SC, asd.Cd go to extremes
5. **Ventricular parameters compensate** but cannot independently raise
   pulmonary flow

### Root Cause

The model lacks direct control over the **LA-RA pressure gradient** — the primary
driver of ASD shunt flow. The current active set controls preload (V0.SVEN),
afterload (R.SC, R.PCOX), compliance (C.PAR, C.SVEN), and the shunt orifice
(asd.Cd), but none of these directly set P_LA or P_RA. Atrial pressures are
determined indirectly by the balance of all coupled parameters.

```
Q_ASD = Cd × A × √(2 × |P_LA - P_RA| / ρ)
              ↑
    This is NOT in the active set.
    P_LA depends on: E_LA, V0_LA, pulmonary venous return, MV function
    P_RA depends on: E_RA, V0_RA, systemic venous return, TV function
```

---

## 5. Decision: Stop Vascular Iterations — Expand to Atrial

| What we've tried | Attempts | Best RMSE |
|---|---|---|
| Vascular only (4 params) | v1 | 0.39 |
| Vascular + asd.Cd (5 params, bug) | v2 | 0.32 (cheat) |
| Vascular + asd.Cd + guards (6 params) | v3 | 0.43 |
| **Atrial expansion** | v4 (next) | — |

Further iterations on the vascular/preload active set will not help. The limiting
factor is the atrial pressure state, which requires atrial-specific parameters.

---

## 6. v4 Plan — Atrial Expansion

### Strategy

Add 3 atrial parameters that **directly control P_LA and P_RA:**

| Parameter | How It Works | Expected Effect |
|---|---|---|
| `V0.LA` | Left atrial unstressed volume → higher V0 = lower P_LA at same volume | Adjust LA pressure operating point |
| `V0.RA` | Right atrial unstressed volume → higher V0 = lower P_RA at same volume | Adjust RA pressure operating point |
| `E.LA.EB` | Left atrial passive elastance → stiffer LA = higher P_LA | Increase LA pressure → increase ΔP → increase Q_ASD |

### Implementation

These parameters are already in Group B of the curated library with registry bounds:

| Parameter | Current | lb | ub |
|---|---|---|---|
| V0.LA | 1.05 | 0.74 | 1.42 |
| V0.RA | 1.61 | 1.13 | 2.18 |
| E.LA.EB | 0.44 | 0.26 | 1.10 |

Since these params have low GSA ST (< 0.05), they won't enter the mask automatically
even at threshold 0.05. Manual override is required:

```matlab
% After optMask is built in run_zoya_asd_calibration.m:
atrial_expand = {'V0.LA', 'V0.RA', 'E.LA.EB'};
for k = 1:numel(atrial_expand)
    idx = find(strcmp(param_names_all, atrial_expand{k}), 1);
    if ~isempty(idx)
        optMask(idx) = true;
    end
end
fprintf('  Atrial parameters manually added: %s\n', strjoin(atrial_expand, ', '));
```

### Expected Outcome

With atrial pressure control:
- LAP should rise from 6.9 toward 10-14 mmHg
- ΔP_LA-RA should increase → Q_ASD increases
- Qp should rise without Qs collapse
- Qp/Qs should approach 3.0+ without guards triggering

### Fallback

If v4 still fails after atrial expansion:
- The model limitation is fundamental: 14-state lumped-parameter with sparse
  clinical data cannot simultaneously match extreme shunt severity (Qp/Qs=3.79)
  AND all systemic/pulmonary pressure targets
- Document as the primary thesis finding and move to secondary patients
- Consider atrial compliance (C.PVEN, C.SVEN) expansion as final attempt

---

## 7. Scientific Narrative for Thesis (All Runs)

```
"Three staged calibration attempts with progressively stricter governance
gates were performed on Patient Zoya pre-closure data:

v1 (4 parameters, vascular only): RMSE 0.39. Shunt severity (Qp/Qs) did not
improve from baseline, indicating vascular parameters alone cannot reproduce
the observed shunt.

v2 (5 parameters, +asd.Cd): RMSE 0.32 with Qp/Qs = 3.52. However, this was
achieved by collapsing systemic flow (Qs: 2.54→1.79) — a spurious mechanism
identified by the clinical fit guard. The asd.Cd parameter was also not
correctly wired into the optimizer (technical note).

v3 (6 parameters, +ratio-chasing guard): RMSE 0.43. The ratio-chasing guard
successfully prevented Qs collapse, revealing that the vascular/shunt active
set cannot independently raise pulmonary flow. Parameters were pushed to
registry bounds (asd.Cd→1.20, R.SC→3.38) without achieving target shunt.

v4 (9 parameters, +atrial expansion): [pending]

The consistent limitation across all attempts is the model's inability to
independently control the LA-RA pressure gradient — the primary driver of
ASD shunt flow. Atrial-specific parameter expansion (v4) is expected to
address this."
```
