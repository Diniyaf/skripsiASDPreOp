# ASD Simulation Validity Gates

**Date:** 2026-05-31  
**Adapted from:** `evaluate_simulation_validity.m` (Hafiz-Keisya unified VSD)  
**Scope:** All 11 validity checks applied post-simulation and post-calibration

---

## 1. Overview

Eleven hard physiological validity gates are applied to every completed ASD
simulation. These gates prevent implausible parameter combinations from being
accepted as calibrated results, even if they produce numerically low RMSE.

The gates are adapted from the VSD `evaluate_simulation_validity.m` with
VSD-specific checks (checks 10-11) replaced by ASD-specific equivalents.

---

## 2. Validity Gates — Complete List

### Gate 1: Steady State Reached

| Field | Value |
|---|---|
| **Flag** | `steady_state_not_reached` |
| **Check** | `sim.ss_reached == true` |
| **Goal** | Ensure the ODE solver reached periodic steady state. A simulation still in transient from cold-start initial conditions has not converged and its metrics are not representative of the limit cycle. |
| **ASD relevance** | Universal — not ASD-specific. ASD shunt adds an additional coupling path (LA↔RA) that may require more cycles to stabilize than a closed-circuit baseline. |
| **Literature** | Standard ODE integration practice. Reference: Valenti (2023) Eqs. 2.1–2.7. |
| **Need lit check?** | No — standard numerical practice |

---

### Gate 2: Non-Finite States

| Field | Value |
|---|---|
| **Flag** | `nonfinite_state` |
| **Check** | `all(isfinite(XV(:)))` — no NaN or Inf in state vector |
| **Goal** | Catch solver divergence. NaN/Inf states indicate the ODE has produced a non-physical solution (e.g., division by zero due to parameter combination causing C→0 or R→0). |
| **ASD relevance** | Universal. ASD shunt does not introduce additional singularities but extreme parameter combinations (e.g., Cd→0 with very large ΔP) could cause numerical instability. |
| **Literature** | Standard numerical practice |
| **Need lit check?** | No — standard numerical practice |

---

### Gate 3: Negative Chamber Volumes

| Field | Value |
|---|---|
| **Flag** | `negative_chamber_volume` |
| **Check** | `any(V_RA, V_RV, V_LA, V_LV < 0)` — no cardiac chamber ever collapses below zero volume |
| **Goal** | Physically impossible: a heart chamber cannot have negative blood volume. Negative volumes typically arise from (a) excessive elastance compressing V below V0, or (b) extreme valve incompetence causing net outflow > content. |
| **ASD relevance** | For ASD, negative LA volume is a specific risk: large ASD + high pulmonary venous return + stiff LA could theoretically drain the LA faster than it fills. Gate 3 catches this. |
| **Literature** | Universal physiological constraint. |
| **Need lit check?** | No — physical impossibility |

---

### Gate 4: Negative Vascular Volumes

| Field | Value |
|---|---|
| **Flag** | `negative_total_volume_state` |
| **Check** | `any(V_SAR, V_SC, V_SVEN, V_PAR, V_PVEN < 0)` |
| **Goal** | Same as Gate 3 but for vascular compartments. Vascular unstressed volume reconciliation (V0.SVEN) can fail if blood volume target is inconsistent with chamber volumes, producing negative SVEN volume. |
| **ASD relevance** | ASD increases total pulmonary blood volume (Qp >> Qs), which can stress the pulmonary venous reservoir if compliance is too low. |
| **Literature** | Universal physiological constraint. |
| **Need lit check?** | No — physical impossibility |

---

### Gate 5: Unrealistic V0-Adjusted Volume

| Field | Value |
|---|---|
| **Flag** | `unrealistic_v0_adjusted_volume` |
| **Check** | `V_LV - V0.LV >= -1 mL` and `V_RV - V0.RV >= -1 mL` — the distending volume (V - V0) must not be substantially negative |
| **Goal** | Pressure is computed as `P = E × (V - V0)`. If V < V0 by more than 1 mL, the chamber is operating below its unstressed volume, suggesting V0 was overestimated or elastance was driven too high by calibration. |
| **ASD relevance** | RV is particularly at risk in ASD: volume overload from left-to-right shunt increases RVEDV, but if V0.RV is calibrated too high, the model may show normal pressures with implausible (V-V0) values. |
| **Literature** | Sagawa K, Maughan L, Suga H, Sunagawa K (1988). *Cardiac Contraction and the Pressure-Volume Relationship*. Oxford University Press. |
| **Need lit check?** | ⚠ **Yes** — verify the -1 mL tolerance is appropriate for pediatric ventricles (adult convention may not scale linearly) |

---

### Gate 6: Flow Collapse

| Field | Value |
|---|---|
| **Flag** | `flow_collapse` |
| **Check** | `QpQs > 0 AND Qs < 1e-3 L/min` — systemic flow collapsed to near-zero despite ongoing pulmonary flow |
| **Goal** | Detect pathological parameter combinations where systemic circulation collapses while pulmonary circulation continues (e.g., extreme systemic vasodilation or shunt stealing all systemic output). |
| **ASD relevance** | Large ASD can theoretically cause "shunt steal" where pulmonary flow dominates and systemic flow collapses. This is a model failure mode, not a clinical scenario — it should not occur at calibrated operating points. |
| **Literature** | ⚠ **Yes** — verify that Qs < 1e-3 L/min is the correct clinical threshold for flow collapse in pediatric ASD. In adults, cardiac output < 1 L/min is incompatible with life; pediatric threshold may differ. |
| **Need lit check?** | ⚠ **Yes** |

---

### Gate 7: PVR Out of Physiological Bounds

| Field | Value |
|---|---|
| **Flag** | `pvr_out_of_bounds` |
| **Check** | `PVR in [0.1, 20] Wood units` |
| **Goal** | Pulmonary vascular resistance outside this range is physiologically implausible. PVR < 0.1 WU suggests near-zero pulmonary resistance (non-physiological). PVR > 20 WU indicates severe pulmonary hypertension beyond what is expected for isolated ASD. |
| **ASD relevance** | ASD patients typically have **normal or mildly elevated PVR** (not severely elevated, which would suggest Eisenmenger physiology). Zoya's clinical picture: PAP_mean = 23 mmHg, Qp = 12.27 L/min → estimated PVR ≈ (23-14)/12.27 ≈ 0.7 WU — should be low. |
| **Literature** | ⚠ **Yes** — bounds [0.1, 20] WU are adult-derived defaults from VSD. For pediatric ASD, the upper bound may be lower. Reference: |
| | - Rudolph AM (2009). *Congenital Diseases of the Heart*. 3rd ed. Wiley-Blackwell. Chapter on ASD hemodynamics. |
| | - Baumgartner H et al. (2020). ESC Guidelines for adult congenital heart disease. *Eur Heart J*. |
| **Need lit check?** | ⚠ **Yes** — confirm pediatric PVR range for isolated secundum ASD |

---

### Gate 8: SVR Out of Physiological Bounds

| Field | Value |
|---|---|
| **Flag** | `svr_out_of_bounds` |
| **Check** | `SVR in [0.5, 50] Wood units` |
| **Goal** | Catch systemic vascular resistance values outside plausible range. SVR < 0.5 WU suggests severe vasoplegia; SVR > 50 WU suggests extreme vasoconstriction. |
| **ASD relevance** | ASD does not directly affect systemic resistance, but calibration may compensate for shunt mismatch by altering SVR. The bound prevents this compensatory drift from producing implausible systemic hemodynamics. |
| **Literature** | ⚠ **Yes** — same as Gate 7. Pediatric SVR reference ranges needed. |
| | - de Simone G et al. (2005). Reference values for SVR in children. *J Hypertens*. |
| **Need lit check?** | ⚠ **Yes** |

---

### Gate 9: Ejection Fraction Out of Bounds

| Field | Value |
|---|---|
| **Flag** | `ef_out_of_bounds` |
| **Check** | `LVEF in [0.05, 0.95]` AND `RVEF in [0.05, 0.95]` |
| **Goal** | EF outside [5%, 95%] is physiologically impossible. Note: Zoya does NOT have clinical EF targets — this check acts as a plausibility floor/ceiling only, not a calibration target. |
| **ASD relevance** | In ASD, RVEF may be reduced due to chronic volume overload. LVEF is typically preserved (normal or hyperdynamic). EF < 5% or > 95% suggests model failure, not a clinical finding. |
| **Literature** | ⚠ **Yes** — bounds are generous but the upper bound (95%) may be too high for volume-loaded RV. |
| | - Sjöberg G et al. (2024). ASD closure in children — LV and RV function. *reference in docs/literature_dummy_asd_case.md* |
| **Need lit check?** | ⚠ **Yes** — confirm whether RVEF > 90% is ever reported in pediatric ASD pre-closure |

---

### Gate 10: ASD Geometry Valid

| Field | Value |
|---|---|
| **Flag** | `asd_geometry_invalid` |
| **Check** | `asd.area_mm2 in [0, 500]` (non-negative, not absurdly large) |
| **Goal** | Catch pathological shunt geometry. Area < 0 is impossible (mathematical error). Area > 500 mm² (≈25 mm diameter) — larger than the atrial septum in a 7-year-old child. |
| **ASD relevance** | Direct ASD check. Zoya's ASD: 291 mm² (19.25 mm) — well within bounds. Large secundum ASDs in children rarely exceed 25-30 mm. |
| **Literature** | ⚠ **Yes** — upper bound 500 mm² needs anatomic justification. |
| | - McMahon CJ et al. (2002). Natural history of secundum ASD size. *Heart*. |
| | - Hanslik A et al. (2006). ASD diameter and shunt quantification. *Eur J Echocardiogr*. |
| **Need lit check?** | ⚠ **Yes** — confirm maximum plausible ASD area for pediatric atrial septum |

---

### Gate 11: ASD Shunt Direction Valid

| Field | Value |
|---|---|
| **Flag** | `asd_shunt_direction_invalid` |
| **Check** | Primary: reconstruct full hemodynamic time series → check `any(Q_ASD < 0)` at any time point. If LA>RA gradient exists but flow is NEVER reversed → flag. Fallback: mean Q_ASD < 0 AND |Q_ASD| > 0.05 L/min, OR QpQs < 0.9. |
| **Goal** | For an orifice_bidirectional ASD model, if the pressure gradient allows bidirectional flow (P_LA > P_RA at some times, P_LA < P_RA at others), the model should produce bidirectional flow. Unidirectional flow despite a reversing gradient indicates the shunt model is not capturing bidirectional physiology. |
| **ASD relevance** | This is the core ASD-specific check. Large secundum ASDs are unrestrictive and should exhibit bidirectional or nearly-bidirectional flow patterns with net left-to-right predominance. Pure unidirectional L→R flow despite LA<RA gradient suggests the model orifice is overly restrictive. |

**Why time series, not mean threshold (difference from previous version):**

| Aspect | Threshold on Mean (old) | Time Series Full (current, = VSD method) |
|---|---|---|
| **Method** | `mean(Q_ASD) < -0.1 L/min` | `any(Q_ASD(t) < 0)` at any time point |
| **Detects transient reverse?** | No — mean smooths out transients | Yes — catches even 1-sample reversal |
| **Example miss** | Mean Q_ASD = +2.0 but Q_ASD = -3.0 for 20 ms during early diastole → NOT flagged | Same scenario → IS detected |
| **Physiological basis** | Arbitrary threshold (-0.1) | Physics-based: if P_LA < P_RA exists, reverse flow is physically possible and should be present in a bidirectional model |
| **Risk** | False negative (misses real bidirectional behavior issues) | False positive (flags transient numerical noise as real) — mitigated by requiring gradient-driven possibility |

| **Literature** | ⚠ **Yes** — bidirectional shunt patterns in ASD need documentation |
| | - Webb G, Gatzoulis MA (2006). Atrial septal defect in the adult. *Circulation*. |
| | - Minette MS, Sahn DJ (2006). Ventricular septal defects. *Circulation*. (Adapted shunt flow principles) |
| | - Valente AM et al. (2014). ACC/AHA guidelines for ACHD. *J Am Coll Cardiol*. |
| **Need lit check?** | ⚠ **Yes** — confirm that bidirectional shunt flow is expected in large unrestrictive secundum ASD |

---

## 3. Summary — Literature Gaps

All 6 gates flagged ⚠ need literature verification. Priority order:

| Priority | Gate | What to Verify | Suggested Source |
|---|---|---|---|
| **High** | 11 | Bidirectional flow expected in large ASD | Webb & Gatzoulis (2006) |
| **High** | 7 | Pediatric PVR range for ASD | Rudolph (2009), ESC Guidelines (2020) |
| **High** | 9 | RVEF range in pediatric ASD pre-closure | Sjöberg et al. (2024) |
| **Medium** | 8 | Pediatric SVR reference range | de Simone et al. (2005) |
| **Medium** | 10 | Maximum ASD area in pediatric septum | McMahon et al. (2002) |
| **Low** | 5 | V0 tolerance for pediatric ventricles | Sagawa et al. (1988) |
| **Low** | 6 | Flow collapse threshold for pediatric CO | Standard physiology texts |

---

## 4. Gate Summary Table

| # | Flag | Check | ASD-Specific? | Lit Needed? |
|---|---|---|---|---|
| 1 | `steady_state_not_reached` | `ss_reached == true` | No | No |
| 2 | `nonfinite_state` | No NaN/Inf in V | No | No |
| 3 | `negative_chamber_volume` | V chambers ≥ 0 | No | No |
| 4 | `negative_total_volume_state` | V vascular ≥ 0 | No | No |
| 5 | `unrealistic_v0_adjusted_volume` | V_LV-V0_LV ≥ -1, V_RV-V0_RV ≥ -1 | No | ⚠ Low |
| 6 | `flow_collapse` | QpQs>0, Qs>1e-3 | No | ⚠ Low |
| 7 | `pvr_out_of_bounds` | PVR ∈ [0.1, 20] WU | No (bounds AS) | ⚠ High |
| 8 | `svr_out_of_bounds` | SVR ∈ [0.5, 50] WU | No (bounds AS) | ⚠ Medium |
| 9 | `ef_out_of_bounds` | EF ∈ [0.05, 0.95] | No (bounds AS) | ⚠ High |
| 10 | `asd_geometry_invalid` | area ∈ [0, 500] mm² | **Yes** | ⚠ Medium |
| 11 | `asd_shunt_direction_invalid` | bidirectional when gradient exists | **Yes** | ⚠ High |

---

## 5. Validity Penalty Structure

Following the VSD convention (`evaluate_simulation_validity.m` line 91-93):

```matlab
validity.is_valid = ~any(flag_values);          % all 11 gates must PASS
validity.penalty  = 1e3 × sum(flag_values);    % 1000 per failed gate
```

A single gate failure adds 1000 to the objective function — effectively rejecting
the candidate unless all 11 gates pass simultaneously.

---

## 6. Integration with Rollback

Validity is checked AFTER calibration, before acceptance:

```
Calibration complete
  → Validity (11 gates)
    → All PASS → proceed to plausibility check
    → Any FAIL → rollback to baseline (even if RMSE is low)
```
