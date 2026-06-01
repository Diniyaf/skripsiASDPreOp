# ASD Parameter Bounds Registry

**Date:** 2026-05-31  
**Purpose:** Define calibration bounds for all 26 ASD GSA parameters by adapting the
VSD `build_parameter_registry.m` bounds from Hafiz-Keisya. Bounds are expressed as
multipliers of the ASD-seeded baseline (`params0_ASD_pre`) unless marked otherwise.

**Patient:** Zoya (7.07 yr, 18.2 kg, 119 cm, BSA 0.788 m²)

---

## 1. Bounds Summary — All 26 Parameters

`lb_mult` and `ub_mult` are relative to `Current_Value`. For `asd.Cd`, bounds are absolute.

| # | Parameter | Current | lb_mult | ub_mult | Absolute lb | Absolute ub | Source | Action |
|---|---|---|---|---|---|---|---|---|
| | **Resistances** | | | | | | | |
| 1 | `R.SAR` | 0.110 | 0.40 | 2.50 | 0.044 | 0.275 | Kung 2013 | ✓ Copy |
| 2 | `R.SC` | 1.756 | 0.40 | 2.50 | 0.702 | 4.391 | Kung 2013 | ✓ Copy |
| 3 | `R.SVEN` | 0.110 | 0.40 | 3.00 | 0.044 | 0.329 | Kung + R-C coupling | ✓ Copy |
| 4 | `R.PAR` | 0.022 | 0.40 | 2.50 | 0.009 | 0.055 | Kung 2013 | ✓ Copy |
| 5 | `R.PCOX` | 0.138 | 0.40 | 2.50 | 0.055 | 0.346 | Kung 2013 | ✓ Copy |
| 6 | `R.PCNO` | 2.775 | 0.40 | 2.50 | 1.110 | 6.938 | Kung 2013 | ✓ Copy |
| 7 | `R.PVEN` | 0.044 | 0.40 | 3.00 | 0.018 | 0.132 | Kung + R-C coupling | ✓ Copy |
| | **Compliances** | | | | | | | |
| 8 | `C.SAR` | 0.835 | 0.75 | 1.35 | 0.626 | **1.127** | Windkessel SV/PP | ⚠ **Adjust** |
| 9 | `C.PAR` | 8.017 | 0.70 | 1.45 | 5.612 | **11.625** | Windkessel SV/PP | ⚠ **Adjust** |
| 10 | `C.SVEN` | 13.665 | 0.50 | 1.80 | 6.832 | 24.596 | Kung R-C coupled | ✓ Copy |
| 11 | `C.PVEN` | 6.263 | 0.50 | 1.80 | 3.132 | 11.273 | Kung R-C coupled | ✓ Copy |
| | **Elastances (ventricular)** | | | | | | | |
| 12 | `E.LV.EA` | 7.684 | 0.60 | 2.20 | 4.610 | 16.905 | Zhang 2019 | ✓ Copy |
| 13 | `E.LV.EB` | 0.176 | 0.60 | 2.50 | 0.105 | 0.439 | Zhang + EB wider | ✓ Copy |
| 14 | `E.RV.EA` | 1.626 | 0.55 | 2.60 | 0.894 | 4.229 | RV more variable | ✓ Copy |
| 15 | `E.RV.EB` | 0.137 | 0.60 | 2.50 | 0.082 | 0.342 | Zhang + EB wider | ✓ Copy |
| | **Elastances (atrial)** | | | | | | | |
| 16 | `E.LA.EA` | 0.768 | 0.20 | 2.50 | 0.154 | **1.921** | Atrial wider | ⚠ **Adjust** |
| 17 | `E.LA.EB` | 0.439 | 0.60 | 2.50 | 0.263 | 1.098 | Atrial EB (derived) | ✓ Copy |
| 18 | `E.RA.EA` | 0.976 | 0.20 | 2.50 | 0.195 | **2.440** | Atrial wider | ⚠ **Adjust** |
| 19 | `E.RA.EB` | 0.325 | 0.60 | 2.50 | 0.195 | 0.813 | Atrial EB (derived) | ✓ Copy |
| | **Unstressed volumes (chamber)** | | | | | | | |
| 20 | `V0.LV` | 1.612 | 0.75 | 1.40 | 1.209 | 2.256 | Blood vol consistency | ✓ Copy |
| 21 | `V0.RV` | 3.829 | 0.70 | 1.35 | 2.680 | 5.169 | Blood vol consistency | ✓ Copy |
| 22 | `V0.LA` | 1.052 | 0.70 | 1.35 | 0.736 | 1.420 | Default V0 prior | ✓ Copy |
| 23 | `V0.RA` | 1.612 | 0.70 | 1.35 | 1.128 | 2.176 | Default V0 prior | ✓ Copy |
| | **Unstressed volumes (vascular)** | | | | | | | |
| 24 | `V0.SVEN` | 564.705 | 0.70 | 1.35 | 395.3 | 762.4 | Default V0 prior | ✓ Copy |
| 25 | `V0.PVEN` | 0 | — | — | — | — | — | ✗ **Exclude** (value ≤0) |
| | **Shunt** | | | | | | | |
| 26 | `asd.Cd` | 0.700 | 0.20 | 1.20 | 0.200 | 1.200 | Orifice Cd range | ✓ Copy |

---

## 2. Parameters Requiring Bound Adjustment (4 of 26)

These 4 parameters have bounds in the current ASD `asd_candidate_param_sets.m` that
differ from VSD `build_parameter_registry.m` and should be updated.

| # | Parameter | ASD lb (old) | ASD ub (old) | VSD lb (new) | VSD ub (new) | Direction | Reason |
|---|---|---|---|---|---|---|---|
| 8 | `C.SAR` | 0.417 (0.50×) | 1.669 (2.00×) | **0.626 (0.75×)** | **1.127 (1.35×)** | Narrower | Arterial compliance anchored to SV/pulse-pressure; too wide = non-physiological |
| 9 | `C.PAR` | 4.009 (0.50×) | 16.034 (2.00×) | **5.612 (0.70×)** | **11.625 (1.45×)** | Narrower | Same as C.SAR — pulmonary arterial compliance should be tightly constrained |
| 16 | `E.LA.EA` | 0.384 (0.50×) | 1.537 (2.00×) | **0.154 (0.20×)** | **1.921 (2.50×)** | Wider | Atrial elastance is poorly constrained by clinical data; wider prior prevents lock-in |
| 18 | `E.RA.EA` | 0.488 (0.50×) | 1.952 (2.00×) | **0.195 (0.20×)** | **2.440 (2.50×)** | Wider | Atrial elastance is poorly constrained by clinical data; wider prior prevents lock-in |

---

## 3. Excluded Parameters

| # | Parameter | Value | Reason |
|---|---|---|---|
| 25 | `V0.PVEN` | 0 | Non-positive value — cannot be calibrated. Excluded automatically by `add_candidate_checked`. |
| — | `L.SAR` | — | Inertance — fixed. "Narrow architecture-dependent placeholder" per VSD registry. |
| — | `L.SVEN` | — | Inertance — fixed. |
| — | `L.PAR` | — | Inertance — fixed. |
| — | `L.PVEN` | — | Inertance — fixed. |
| — | `R.valve.open` | — | Valve constant — fixed. |
| — | `R.valve.closed` | — | Valve constant — fixed. |
| — | `C.SC` | — | Capillary — excluded (low impact). |
| — | `C.PCOX` | — | Capillary — excluded (low impact). |
| — | `C.PCNO` | — | Capillary — excluded (low impact). |

---

## 4. VSD Reference: 17 Calibration Parameters with Bounds

For comparison, these are the 17 parameters and bounds used in the VSD `calibration_param_sets.m`
(pre_surgery), sourced from `config/build_parameter_registry.m`.

| # | Parameter | Multiplier Range | Source | Notes |
|---|---|---|---|---|
| 1 | `R.SAR` | [0.40, 2.50] | Kung 2013 | |
| 2 | `R.SC` | [0.40, 2.50] | Kung 2013 | |
| 3 | `R.SVEN` | [0.40, 3.00] | Kung + R-C coupling | Wider for venous |
| 4 | `R.PAR` | [0.40, 2.50] | Kung 2013 | |
| 5 | `R.PCOX` | [0.40, 2.50] | Kung 2013 | |
| 6 | `R.PVEN` | [0.40, 3.00] | Kung + R-C coupling | Wider for venous |
| 7 | `C.SAR` | [0.75, 1.35] | Windkessel SV/PP | Tightest of all bounds |
| 8 | `C.PAR` | [0.70, 1.45] | Windkessel SV/PP | |
| 9 | `E.LV.EA` | [0.60, 2.20] | Zhang 2019 | |
| 10 | `E.LV.EB` | [0.60, 2.50] | Zhang 2019 | EB term slightly wider |
| 11 | `E.RV.EA` | [0.55, 2.60] | Zhang 2019 | RV more variable |
| 12 | `E.RV.EB` | [0.60, 2.50] | Zhang 2019 | |
| 13 | `E.LA.EA` | [0.20, 2.50] | Zhang 2019 | Widest — sparse atrial data |
| 14 | `E.RA.EA` | [0.20, 2.50] | Zhang 2019 | Widest — sparse atrial data |
| 15 | `V0.LV` | [0.75, 1.40] | Blood volume consistency | |
| 16 | `V0.RV` | [0.70, 1.35] | Blood volume consistency | |
| 17 | `R.vsd` / `vsd.Cd` | [0.05, 20.0] / [0.20, 1.20] | Patient-specific box / Cd range | Depends on shunt mode |

---

## 5. How to Use

### For GSA (current)
The current `asd_candidate_param_sets.m` bounds are consumed through the
curated runner `scripts/run_zoya_asd_gsa_curated.m`. The legacy
`run_zoya_asd_gsa_groupA.m` name is now only a compatibility wrapper.

### For calibration (future)
Before running calibration:

1. Copy VSD bounds for the 20 "✓ Copy" parameters
2. Adjust bounds for the 4 "⚠ Adjust" parameters (Section 2)
3. Exclude V0.PVEN (value = 0)
4. Implement these bounds in an ASD-specific registry or directly in the
   calibration setup

### Bounds class hierarchy (from VSD)
```
Resistances:     0.40× – 2.50×  (venous: 0.40× – 3.00×)
Arterial C:      0.70× – 1.45×  (tightest, Windkessel-anchored)
Venous C:        0.50× – 1.80×
Ventricular E:   0.55× – 2.60×  (RV wider than LV)
Atrial E:        0.20× – 2.50×  (widest, sparse data)
V0:              0.70× – 1.40×  (blood volume-constrained)
Cd (orifice):    [0.20, 1.20]   (absolute, dimensionless)
```

---

## 6. Literature References

1. **Kung 2013** — Kung E, Pennati G, et al. (2013). Multiscale modeling of the
   cardiovascular system. *Ann Biomed Eng*. Used for resistance and R-C coupling priors.
2. **Zhang 2019** — Zhang Y, et al. (2019). Pediatric cardiovascular lumped parameter
   model elastance priors.
3. **Windkessel theory** — Stergiopulos et al. (1994). Pulse pressure method for arterial
   compliance. *Am J Physiol*. Pulmonary: Thenappan et al. (2016).
4. **Blood volume** — Lundquist et al. (2025). Patient-specific pediatric cardiovascular
   lumped parameter modeling. *ASAIO Journal*. 85 mL/kg for infants, 70 mL/kg for children.
5. **Orifice discharge coefficient** — Gorlin & Gorlin (1951). Hydraulic formula for
   calculation of the area of the stenotic mitral valve. *Am Heart J*.
