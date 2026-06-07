# Aluna ASD GSA — Smoke Test N=16 Analysis

**Date:** 2026-06-06  
**Script:** `run_aluna_asd_gsa_curated.m`  
**Patient:** Aluna, 1.4yr female, large secundum ASD (17.55mm), orifice mode  
**Config:** N=16, seed=42, warmup=40, parallel 4 workers

---

## 1. Pipeline Verification

| Check | Status |
|---|---|
| Orifice mode auto-detected | ✅ — `asd.Cd` in parameter list (no ΔP available) |
| All 25 params varied | ✅ — Groups A+B+C complete |
| All 27 matrices evaluated | ✅ — A, B, 25×AB |
| Bootstrap CI computed | ✅ — 200 iterations |
| Excel + MAT + Figures exported | ✅ |

---

## 2. Critical Context: Pressure-Only GSA

Aluna has **only 2 primary targets** — the sparsest of all three patients:

| Patient | Primary Targets | Flow Data? | Shunt Severity Assessable? |
|---|---|---|---|
| Zoya | 6 (Qp, Qs, QpQs, MAP, PAP, LAP) | ✅ | ✅ |
| Indira | 7 (+RAP) | ✅ | ✅ |
| **Aluna** | **2 (MAP, PAP)** | **❌** | **❌** |

**This GSA answers:** *"Which parameters influence systemic and pulmonary pressures in Patient Aluna?"*  
**This GSA does NOT answer:** *"Which parameters control Aluna's ASD shunt severity?"*

No Qp/Qs, no LAP, no RAP, no flow data, no volume/EF. Shunt mechanism cannot be
validated against clinical targets — it can only be monitored as model prediction.

---

## 3. Failure Analysis

| Type | Count | % | Severity |
|---|---|---|---|
| Numerical (steady_state) | 27 | **6.25%** | ⚠ Higher than Zoya (0.69%) & Indira (2.17%) |
| Physiology (opposite shunt) | 144 | **33.3%** | ⚠ Much higher — shunt mechanism unanchored |

### Why Higher Failure Rates?

1. **Infant physiology (1.4yr, 8.9kg):** Scaled parameters are much smaller →
   ODE more sensitive to parameter variation → more steady-state failures
2. **No LAP/RAP data:** Atrial pressures completely unconstrained → many
   parameter combinations produce RA > LA → reverse shunt
3. **No flow targets:** Optimizer has no anchor → shunt direction unstable

### Comparison Across Patients (Smoke Tests)

| | Zoya N=16 | Indira N=16 | Aluna N=16 |
|---|---|---|---|
| Numerical | 0.23% | 0.23% | **6.25%** ⚠ |
| Opposite shunt | 25% | 12% | **33%** ⚠ |
| Valid pairs (est.) | ~99% | ~99% | ~93% |

---

## 4. GSA Ranking (N=16 — screening only)

| # | Parameter | Max_ST | Group | Sensitive To |
|---|---|---|---|---|
| 1 | V0.SVEN | 1.00 | B | All SAP/PAP metrics |
| 2 | C.SVEN | 0.20 | B | SAP (all), PAP (all) |
| 3 | R.SC | 0.11 | A | SAP_min, SAP_mean |
| 4 | R.PCOX | 0.04 | A | None above threshold |

### Notes on Ranking

- **V0.SVEN dominant** — consistent across all three patients. Universal finding.
- **C.SVEN second** — venous compliance coupled to preload, affects pressure balance.
- **R.PCOX (ST=0.04):** Included likely due to minimum-active-set rule, NOT because
  of genuine sensitivity evidence at N=16. Label as "pending N=128 confirmation."
- **R.SC (ST=0.11):** Systemic capillary resistance — well-constrained CI expected
  at N=128 based on Zoya/Indira experience.

### R.PCOX Caveat

Do NOT report R.PCOX as "confirmed influential from GSA" based on N=16. The
ST=0.04 + wide CI at N=16 make it unreliable. At N=128, bootstrap CI will
clarify. Use phrasing: *"included as low-rank/minimum active-set candidate
pending N=128 confirmation."*

---

## 5. Clinical Data Note — NIBP Pulse Pressure

Aluna NIBP: 109/98, MAP=104. **Pulse pressure = 11 mmHg** — unusually narrow.

This is likely NIBP artifact (cuff measurement in infant) rather than true
physiology. NIBP tends to underestimate systolic and overestimate diastolic,
compressing pulse pressure. SAP_max/SAP_min are correctly placed as secondary
guards — SAP_mean is the more reliable primary target.

---

## 6. Next Step: Full N=128

```matlab
delete(gcp('nocreate'));
parpool('local', 4);
setenv('ASD_GSA_USE_PARALLEL', '1');
run('run_aluna_asd_gsa_curated.m');
```

### Expected at N=128

| Expectation | Basis |
|---|---|
| V0.SVEN remains dominant | Confirmed Zoya + Indira |
| Numerical failures < 10% | N=16 was 6.25% — N=128 likely 5-8% |
| CI width tightens for top params | N=128 precision |
| R.PCOX ST may remain <0.10 | Confirm as low-sensitivity — don't force |
| No ventricular params in active set | N=128 will confirm |

### For Calibration After N=128

```matlab
setenv('ASD_CALIB_ALLOW_GROUPC', '0');
run('run_aluna_asd_calibration.m');
```

**Label as:** *"Exploratory pressure-only calibration."*

Do NOT present as full patient-specific ASD shunt calibration — Aluna lacks
Qp/Qs, Qp, Qs, LAP/RAP, and volume/EF data to anchor shunt severity. The
calibration can match MAP and PAP, and may predict shunt direction, but
cannot validate shunt magnitude against clinical targets.

---

## 7. Thesis Framing — Three Patients, Three Data Profiles

| Patient | Data Completeness | Primary Targets | Baseline RMSE | Calibration Label |
|---|---|---|---|---|
| Zoya | Moderate | 6 | 0.45 | Full calibration with atrial expansion |
| Indira | Rich | 7 | 0.20 | Full calibration with shunt seeding |
| **Aluna** | **Sparse** | **2** | ? | **Exploratory pressure-only** |

> *"Patient Aluna represents the sparsest data profile in this study, with
> only systemic and pulmonary pressure measurements available (no flow data,
> no atrial pressures, no volume/EF). Calibration for this patient is
> therefore labeled exploratory pressure-only: the model can be tuned to
> match MAP and PAP, and may produce physiologically plausible shunt
> predictions, but shunt severity cannot be validated against clinical
> targets. Aluna serves as a boundary case — demonstrating the framework's
> behavior under maximum data sparsity."*
