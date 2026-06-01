# Diniya vs Jovano — ASD Codebase Comparison & Post-Op Strategy

**Date:** 2026-06-01  
**Context:** Diniya (pre-closure) and Jovano (post-closure) are building complementary
ASD models for the same patient Zoya. Neither has ideal data like Hafiz-Keisya's
VSD case. This document compares both codebases and proposes a pre→post handoff strategy.

---

## 1. Structural Comparison

| Feature | Diniya (`skripsiASDPreOp`) | Jovano (`ASD-Model-pre-post`) |
|---|---|---|
| **ODE states** | 14 (volume-based: 9 vols + 4 flows + 1 pressure) | 14 (pressure-based: 4 vols + 6 pressures + 4 flows) |
| **State vector ref** | Valenti Eq. 2.7 (mixed vol/pressure) | Valenti Eqs. (1)-(14) (pure pressure vascular) |
| **ASD shunt model** | 3 modes: orifice_bidirectional, linear_bidirectional, linear_L→R_only | 1 mode: linear Ohmic only |
| **Shunt knob** | `asd.Cd` (orifice mode, Bernoulli law) | `R_ASD` (linear Ohmic resistance) |
| **Valve model** | Smooth tanh soft-switching | Smooth max/min |
| **Jacobian (JPattern)** | Yes — sparse 14×14 | No |
| **Batch integration** | 5-cycle batches | 1 cycle per call |
| **Precomputed hot-path** | 5 constants (R_SC_half, C_PC_total, etc.) | None |
| **Maturation** | `apply_maturation.m` (pediatric PVR drop) | Not implemented |
| **Parameter struct** | Nested dot-notation (`params.E.LV.EA`) | Flat (`params.Emax_lv`) |

---

## 2. GSA Comparison

| Feature | Diniya | Jovano |
|---|---|---|
| **Method** | Sobol Monte Carlo (Saltelli + Jansen) | Sobol Monte Carlo (Saltelli + Jansen) |
| **Sampling** | Quasi-random Sobol | Scrambled Sobol (MatousekAffineOwen) |
| **N default** | 128 | 128 |
| **Total params varied** | 25 (Groups A+B+C curated) | 28 (flat, all parameters) |
| **Bounds** | 12 distinct policies (Kung 2013, Zhang 2019, Windkessel) | Uniform ±30% for all |
| **Bootstrap CI** | Yes (200 iterations) | No |
| **Failed sample handling** | NaN-safe + numerical/physiology separation | NaN → excluded |
| **Parallel** | Opt-in (env var gated, 6 worker) | Always on (parfor) |
| **Output organization** | 3-tier target governance (hard_primary / soft_secondary / prediction_only) | Flat metric list |

### Key Takeaway

Diniya's GSA is more rigorous — literature-cited bounds, bootstrap CI, separated
failure categories. Jovano's GSA is simpler but functional for its purpose
(pre vs post comparison). Both use Saltelli + Jansen at N=128.

---

## 3. Calibration Comparison

| Feature | Diniya | Jovano |
|---|---|---|
| **Stages** | Stage A (vascular+shunt) → Stage C (joint top-GSA) | Single-stage: top-4 GSA parameters |
| **Solver** | fmincon (interior-point + LBFGS) | fmincon (SQP) |
| **Objective** | Multi-term: RMSE targets + plausibility + boundary + validity | Weighted MSRE: w_RV_SV=4, w_PAP=3, w_RV_EF=2, w_CO=2 |
| **Active set** | Dynamic from GSA ST + target-tier governance | Top-4 by aggregate ST |
| **Post-cal validation** | 11 validity gates + parameter plausibility + 3-level rollback | Simple RMSE comparison |
| **Group C governance** | Monitor-only unless `ASD_CALIB_ALLOW_GROUPC=1` | N/A (flat list) |
| **Stage B (volumes)** | Skipped for Zoya (no pre-closure volume data) | N/A — Jovano HAS post-closure volumes |

### Key Mismatch

Diniya calibrates to **pressure-flow targets** (no volumes available pre-closure).
Jovano calibrates to **volume + EF targets** (limited pressures available
post-closure). This is complementary — Diniya's calibrated hemodynamics can seed
Jovano's post-closure run, and Jovano's volume data can validate the RV unloading
prediction.

---

## 4. Pre → Post Handoff Strategy

### The Time Gap Problem

Zoya's clinical data has a time gap between pre-closure catheterization and
post-closure echocardiography. The exact dates are in the clinical record.
Unlike Hafiz-Keisya's VSD case (same catheterization before and after surgery
in one session), ASD closure involves:

```
Pre-closure (cath) → [surgery: ASD closure] → [recovery weeks/months] → Post-closure (echo)
```

The model cannot directly simulate "weeks of recovery" — it's a **hemodynamic
model**, not a growth/remodeling model. The strategy:

### Strategy: Parameter Snapshot Transfer

```
DINIYA (PRE)                          JOVANO (POST)
────────────                          ─────────────
params0_ASD_pre                       
  → GSA                               
  → Calibration                        
  → accepted_params_pre               
       │                               
       │ EXPORT:                       
       │  - parameter values           
       │  - initial conditions         
       │  - metrics (baseline + cal)   
       │                               
       ▼                               
     params_seed_post                  params_post (from patient_post_asd_params)
       │                               
       │ R.asd → Inf (closure)         
       │ (optional: re-scale for       
       │  any growth between pre       
       │  and post measurements)       
       │                               
       ▼                               
     integrate_system (post) → compare with Jovano's clinical targets:
                                 • RV volumes ↓ (unloaded)
                                 • LV volumes ↑ (improved filling)
                                 • Qp/Qs → 1.0
                                 • PAP ↓ (if PVR normal)
```

### What Diniya Should Export for Jovano

| Export | Content | Format |
|---|---|---|
| `accepted_params_pre.mat` | Full params struct after calibration | `.mat` |
| `active_params_vector.csv` | x_opt values for calibrated params | `.csv` |
| `initial_conditions.csv` | 14-state IC vector from accepted candidate | `.csv` |
| `pre_metrics.csv` | `asd_output_table` for baseline + calibrated | `.csv` |
| `calibration_summary.md` | Stage A/C RMSE, active set, rollback status | `.md` |

### What Jovano Should Do

1. Load Diniya's `accepted_params_pre`
2. Set `R_ASD = 1e9` (closure)
3. Set post-closure HR if different from pre
4. Optionally: scale parameters if BSA/weight changed between pre and post
5. Run simulation → compare outputs to post-closure clinical targets
6. Calibrate remaining parameters if needed (RV elastance, RV V0 — since these change post-closure)

### Handling the Time Gap

Since ASD closure causes **acute** hemodynamic changes (shunt eliminated → RV
immediately unloaded) and the model is a steady-state hemodynamic simulator:

- **Acute changes** (immediate): R_ASD → Inf → Qp/Qs → 1.0. Model handles this directly.
- **Chronic remodeling** (weeks-months): RV mass regression, LV adaptation. These are
  NOT modeled. Jovano's calibration to post-closure volumes will absorb these
  changes into parameter adjustments (e.g., lower RV elastance to represent
  reverse remodeling).

**Thesis framing:**
> "Model pre- dan post-closure dijalankan secara independen dengan parameter
> closure (R_ASD → Inf) sebagai transisi. Adaptasi kronis ventrikel pasca-operasi
> direpresentasikan melalui kalibrasi parameter post-closure terhadap data
> ekokardiografi. Prediksi perubahan akut (Qp/Qs, tekanan) dapat divalidasi
> terhadap data post-kateterisasi bila tersedia."

---

## 5. Data Situation — Both Non-Ideal

| | Diniya (PRE) | Jovano (POST) | Hafiz-Keisya (VSD) |
|---|---|---|---|
| **Pressures** | PAP, SAP, LAP ✓ | Limited (PAP dummy=15) | Complete (RHC) |
| **Flows** | Qp, Qs, Qp/Qs ✓ | CO ✓ | Complete (Fick) |
| **Volumes** | None ❌ | LVEDV, LVESV, RVEDV, RVESV ✓ | LVEDV/ESV (Teichholz), RV incomplete |
| **EF** | None ❌ | LVEF=0.67, RVEF=0.45 ✓ | LVEF only |
| **Shunt gradient** | None ❌ | N/A (closed) | VSD gradient ✓ |
| **SVR/PVR** | None ❌ | None ❌ | SVR/PVR ✓ |
| **Recipe** | Not yet | Not yet | Yes (mature) |

### Implication

Neither Diniya nor Jovano has complete data. Diniya is pressure-flow-rich but
volume-poor; Jovano is volume-rich but pressure-poor. This means:

1. **Diniya's calibration** focuses on matching QpQs, Qp, Qs, PAP, SAP, LAP
2. **Jovano's calibration** focuses on matching RVEDV, RVESV, LVEDV, LVESV,
   RVEF, LVEF
3. **Neither can independently validate both** — this is inherent to the
   clinical data, not a model limitation
4. **Cross-validation is the strength:** Diniya's calibrated pre model should
   predict RV volume overload; Jovano's post data should confirm RV unloading.
   If they agree, both models are validated.

---

## 6. Action Items

### Diniya (Now)
- [ ] Complete GSA N=128
- [ ] Run calibration → accepted candidate
- [ ] Export `pre_to_post_seed.mat` (params + ICs + metrics)
- [ ] Generate `asd_output_table` (baseline + calibrated)

### Jovano
- [ ] Load Diniya's seed
- [ ] Apply R_ASD → Inf
- [ ] Run post-closure simulation
- [ ] Compare model predictions with post-closure echo data
- [ ] Calibrate RV parameters if needed

### Joint
- [ ] Document pre→post methodology in joint thesis section
- [ ] Cross-validate: does pre model's RV overload prediction match post model's
  unloading response?
- [ ] Publish joint parameter set for Zoya (pre + post)
