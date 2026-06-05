# params0_ASD_pre — Detailed Explanation

**What it is:** The fully seeded patient-specific parameter struct — the starting
point for ALL subsequent steps (baseline simulation, GSA, calibration).

---

## 1. Creation Pipeline

```
Step 1: Adult Healthy Baseline
  config/default_parameters.m
  → Valenti (2023) 14-state model, 70kg adult
  → All parameters: E, V0, R, C, L, timing fractions

Step 2: Pediatric Scaling
  apply_scaling(params_ref, patient)
  → Lundquist BSA allometry
  → Scaling exponents per parameter class
  → Maturation (pediatric PVR drop)
  → Blood volume reconciliation (V0.SVEN)
  → Build initial conditions (build_initial_conditions)

Step 3: Clinical Seeding
  params_from_clinical(params_scaled, clinical, scenario)
  → HR override (clinical.common.HR)
  → Recompute timing from HR
  → SVR/PVR seeding → scale resistances
  → Arterial compliance seeding (SV/pulse pressure)
  → ASD geometry (diameter → area)
  → ASD shunt mode detection (linear vs orifice)
  → R_ASD computation (if ΔP + Q_shunt available)
  → Store Qp/Qs as target (NOT forced into ODE)
  → Close legacy VSD (R.vsd = 1e6)
  → Rebuild IC vector with blood volume reconciliation

Output: params0_ASD_pre ← THIS IS THE STARTING POINT
```

---

## 2. What's Inside params0_ASD_pre

### Cardiac Mechanics
| Field | Source | Example (Indira) |
|---|---|---|
| `E.LV.EA`, `E.LV.EB` | Scaled from adult | ~0.10, ~2.5 |
| `E.RV.EA`, `E.RV.EB` | Scaled from adult | ~0.06, ~0.6 |
| `E.LA.EA`, `E.LA.EB` | Scaled from adult | ~0.08, ~0.35 |
| `E.RA.EA`, `E.RA.EB` | Scaled from adult | ~0.05, ~0.20 |
| `V0.LV`, `V0.RV`, `V0.LA`, `V0.RA` | Scaled from adult | ~2, ~5, ~1.5, ~1.5 |
| `V0.SVEN` | Blood volume reconciled | ~2310 |

### Vascular
| Field | Source | Example |
|---|---|---|
| `R.SAR`, `R.SC`, `R.SVEN` | Scaled + SVR-seeded | |
| `R.PAR`, `R.PCOX`, `R.PCNO`, `R.PVEN` | Scaled + PVR-seeded | |
| `C.SAR`, `C.PAR` | SV/PP seeded | |
| `C.SVEN`, `C.PVEN` | Scaled | |
| `L.SAR`, `L.SVEN`, `L.PAR`, `L.PVEN` | Scaled (fixed) | |

### ASD Shunt
| Field | Source | Example (Indira) |
|---|---|---|
| `asd.mode` | Auto-detected from data | `'linear_bidirectional'` |
| `asd.diameter_mm` | Clinical input | 22.3 |
| `asd.area_mm2` | Computed from diameter | 390.6 |
| `R.asd` | Computed: ΔP/Q_shunt (if available) | **0.0278 mmHg·s/mL** |
| `asd.Cd` | Default (only used in orifice mode) | 0.7 |
| `R.vsd` | Closed (legacy) | 1e6 |

### Other
| Field | Content |
|---|---|
| `HR` | Clinical HR override |
| `T_cardiac`, `Tc_LV`, `Tr_LV`, etc. | Timing recomputed from HR |
| `idx` | State vector index struct |
| `sim` | Solver settings (nCycles, tolerances) |
| `conv` | Unit conversion factors |
| `ic.V` | 14-state initial condition vector |
| `clinical_override` | Audit trail of all seeding decisions |
| `scaling` | Scaling metadata (mode, exponents, BSA) |

---

## 3. What params0_ASD_pre Feeds

```
params0_ASD_pre
       │
       ├── integrate_system(params) → sim → compute_clinical_indices → baseline metrics
       │
       ├── GSA: 25 params varied around params0, sensitivity measured
       │
       └── Calibration: fmincon starts from params0, varies active subset
                          to minimize objective function
```

---

## 4. Objective of params0_ASD_pre

**There is NO optimization objective for params0.** It's a **deterministic mapping**
from clinical data to parameter values. Its "objective" is:

> "Given the available clinical measurements, produce the best possible
> initial parameter estimate using only physics-based scaling and
> Ohm's-law/Gorlin-equation seeding — no fitting, no optimization."

The quality of params0_ASD_pre depends ENTIRELY on data completeness:

| Data Available | Seeding Quality | Baseline RMSE |
|---|---|---|
| Full (ΔP, RAP, SVR, PVR, volumes) | Near-perfect | < 0.10 |
| Moderate (Indira: ΔP, RAP, SVR, PVR, no volumes) | Good | 0.20 |
| Sparse (Zoya: no ΔP, no RAP, no SVR/PVR) | Poor | 0.45 |

---

## 5. For Thesis — How to Explain

> *"`params0_ASD_pre` adalah parameter struct yang dihasilkan dari tiga tahap
> deterministik: (1) scaling pediatrik berbasis BSA Lundquist, (2) seeding
> klinis berbasis hukum Ohm untuk resistensi vaskular dan persamaan Gorlin
> untuk resistensi shunt, dan (3) rekonsiliasi volume darah untuk kondisi
> awal. Tidak ada optimasi atau fitting pada tahap ini — seluruh pemetaan
> bersifat deterministik dan reproducible. Kualitas `params0_ASD_pre` —
> yang diukur dari RMSE baseline terhadap target klinis — bergantung pada
> kelengkapan data klinis yang tersedia."*
