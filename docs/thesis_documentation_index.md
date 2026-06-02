# Thesis Documentation Index — ASD Pre-Closure Model

**Date:** 2026-06-02  
**Primary Case:** Patient Zoya (7.07 yr, 18.2 kg, ASD 19.25 mm)

---

## 1. GSA Outputs

| File | Content | Use in Thesis |
|---|---|---|
| `results/tables/zoya_asd_gsa_curated_20260601_193817.mat` | Full GSA workspace: sobol, YA/YB/YAB, cfg, CI | Data source |
| `results/tables/zoya_asd_gsa_curated_20260601_193817.xlsx` | 14-sheet workbook: ST matrix, S1, CI, Ranking, etc. | Appendix table |
| `results/figures/zoya_asd_gsa_curated_ST_heatmap_*.pdf` | ST heatmap (25 params × 6 primary targets) | Figure in Methods/Results |
| `results/figures/zoya_asd_gsa_curated_ST_bar_QpQs_*.pdf` | Ranked ST bar for Qp/Qs | Figure in Results |

### GSA Key Numbers

| Metric | Value |
|---|---|
| Sample size | N = 128 |
| Parameters varied | 25 (Groups A+B+C) |
| Total simulations | 3,456 |
| Numerical failure rate | 0.69% (24/3456) |
| Bootstrap CI iterations | 200 |
| **Top 3 params (ST)** | V0.SVEN (0.57), E.RV.EB (0.41), R.SC (0.36) |

---

## 2. Calibration Outputs — v4 Accepted

| File | Content | Use in Thesis |
|---|---|---|
| `results/calibration/zoya_asd_calib_20260602_011418/zoya_asd_calibration_*.mat` | Full package: params0, accepted_params, all metrics, gates, rollback | Data source |
| `results/calibration/zoya_asd_calib_20260602_011418/zoya_asd_baseline_*.csv` | 26-metric baseline table | Appendix table |
| `results/calibration/zoya_asd_calib_20260602_011418/zoya_asd_calibrated_*.csv` | 26-metric calibrated table | Appendix table |
| `results/calibration/zoya_asd_calib_20260602_011418/console_*.log` | Full console diary | Supplementary |

### Baseline vs Calibrated — Key Metrics

| Metric | Target | Baseline | Error% | v4 Accepted | Error% | Δ |
|---|---|---|---|---|---|---|
| QpQs | 3.79 | 1.42 | 62.5% | 2.27 | 40.0% | +0.85 |
| Qp_Lmin | 12.27 | 3.61 | 70.6% | 5.56 | 54.7% | +1.95 |
| Qs_Lmin | 3.23 | 2.54 | 21.5% | 2.45 | 24.3% | -0.09 |
| SAP_mean | 90 | 90.3 | 0.4% | 84.8 | 5.8% | -5.5 |
| PAP_mean | 23 | 18.8 | 18.2% | 19.1 | 17.1% | +0.3 |
| LAP_mean | 14 | 6.9 | 50.5% | 7.9 | 43.3% | +1.0 |
| **RMSE** | — | **0.4515** | — | **0.3507** | — | **-22%** |

### Shunt Mechanism Amplification

| Metric | Baseline | v4 | Change |
|---|---|---|---|
| ΔP_LA-RA (mmHg) | 0.22 | 0.65 | **3.0×** |
| Q_ASD (L/min) | 1.07 | 3.12 | **2.9×** |
| RV SV (mL) | 40.3 | 62.0 | +54% |
| RVEDV (mL) | 55.8 | 78.4 | +41% |

### Calibrated Parameters

| Parameter | Initial | Fitted | Bound [lb, ub] | Status |
|---|---|---|---|---|
| asd.Cd | 0.700 | 0.629 | [0.20, 1.20] | OK |
| R.SC | 1.756 | 1.677 | [0.70, 4.39] | OK |
| R.PCOX | 0.138 | 0.055 | [0.055, 0.346] | WARNING |
| C.PAR | 8.017 | 7.739 | [5.61, 11.63] | OK |
| **E.LA.EB** | 0.439 | **0.613** | [0.26, 1.10] | OK |
| **V0.LA** | 1.052 | 1.058 | [0.74, 1.42] | OK |
| **V0.RA** | 1.612 | **1.762** | [1.13, 2.18] | OK |
| V0.SVEN | 564.7 | 564.6 | [395, 762] | OK |
| C.SVEN | 13.66 | 11.95 | [6.83, 24.6] | OK |
| E.LV.EA | 7.684 | 8.423 | [4.61, 16.9] | OK |
| E.LV.EB | 0.176 | 0.190 | [0.105, 0.439] | OK |
| E.RV.EB | 0.137 | 0.082 | [0.082, 0.342] | WARNING |

### Calibration Journey — All Runs

| Run | Params | Key Change | RMSE | Gates | Accepted? |
|---|---|---|---|---|---|
| v1 | 4 | Vascular only | 0.39 | Failed clinical fit | ❌ |
| v2 | 5 | +asd.Cd (bug: not wired) | 0.32 | Failed clinical fit (ratio cheat) | ❌ |
| v3 | 6 | +ratio-chasing guard | 0.43 | Failed validity (SVR) + clinical fit | ❌ |
| **v4** | **9** | **+atrial expansion (V0.LA, V0.RA, E.LA.EB)** | **0.35** | **ALL PASS** | ✅ |

---

## 3. Baseline Validation Outputs

| File | Content |
|---|---|
| `results/tables/baseline_parameter_comparison_*.xlsx` | 5 baseline configs (Adult, Zhang/Lundquist × Reyna/Zoya) |
| `results/tables/baseline_parameter_comparison_*_clinical_output.csv` | Clinical output comparison across baselines |
| `results/tables/baseline_parameter_comparison_*_range_check.csv` | Physiological range checks |

### Baseline Validation — Key Checks

| Case | Qp/Qs | HR | Scaling | Valid? |
|---|---|---|---|---|
| Adult_ref | ~1.0 | ~70 | None | ✅ |
| Zhang_ReynaReferenceChild | ~1.0 | Scaled | Zhang weight | ✅ |
| Lundquist_ReynaReferenceChild | ~1.0 | Scaled | Lundquist BSA | ✅ |
| Zhang_Zoya | ~1.0 | 90 | Zhang weight | ✅ |
| Lundquist_Zoya | ~1.0 | 90 | Lundquist BSA | ✅ |

All healthy baselines show closed-shunt physiology (Qp/Qs ≈ 1.0, Q_ASD ≈ 0).

---

## 4. Parameter & Bounds Documentation

| File | Content |
|---|---|
| `docs/asd_parameter_bounds_registry.md` | 25-parameter bounds with VSD comparison and literature citations |
| `docs/asd_candidate_param_sets.md` | Group A/B/C candidate rationale |
| `docs/asd_target_tier_governance.md` | Primary/secondary/prediction-only tier classification |

---

## 5. Methodology Documentation

| File | Content | Thesis Section |
|---|---|---|
| `docs/asd_pipeline_governance.md` | VSD-to-ASD file mapping | Methods |
| `docs/asd_pipeline_workflow_complete.md` | End-to-end patient-generic workflow | Methods |
| `docs/thesis_gsa_writing_guide.md` | GSA dasar teori + metode + referensi | Chapter 2 & 3 |
| `docs/asd_gsa_n128_analysis.md` | Complete GSA N=128 analysis | Results |
| `docs/asd_gsa_smoke_test_n16_analysis.md` | N=16 smoke test pipeline verification | Supplementary |

---

## 6. Calibration Design Documentation

| File | Content |
|---|---|
| `docs/asd_active_set_decision.md` | Active set options + supervisor perspective (4 open questions answered) |
| `docs/asd_calibration_implementation.md` | Stage A/C design, objective function, VSD comparison |
| `docs/asd_calibration_improvements_v2.md` | ST threshold, asd.Cd force, re-weight, MAP guard |
| `docs/asd_calibration_v2_results_v3_plan.md` | v2 analysis, v3 plan, thesis writing strategy |
| `docs/asd_calibration_v3_results.md` | v3 analysis — guards reveal model limitation |
| `docs/asd_calibration_v4_atrial_expansion_design.md` | Atrial expansion rationale, RAP guard literature, future patients |
| `docs/asd_calibration_v4_opencode_vs_chatgpt.md` | AI assistant comparison + synthesis for consultation |

---

## 7. Comparison & Collaboration

| File | Content |
|---|---|
| `docs/diniya_vs_jovano_codebase_comparison.md` | Structural comparison + pre→post handoff strategy |
| `docs/asd_validity_gates.md` | 11 validity gates (ASD-adapted from VSD) with literature gaps |

---

## 8. Thesis Figure-Ready Assets

| Asset | File | Caption |
|---|---|---|
| ST Heatmap | `results/figures/*ST_heatmap_*.pdf` | Total-order Sobol indices for 25 parameters against 6 primary clinical targets |
| ST Bar (QpQs) | `results/figures/*ST_bar_QpQs_*.pdf` | Parameter ranking by ST for pulmonary-to-systemic flow ratio |
| ST Bar (others) | `results/figures/*ST_bar_*_*.pdf` | Per-metric ranked ST for remaining primary targets |
| Baseline table | `*baseline_*.csv` | 26-metric output before calibration |
| Calibrated table | `*calibrated_*.csv` | 26-metric output after calibration (accepted candidate) |
| Calibration journey | (build from Section 2 table) | RMSE across v1→v4 with gate status |
| Mechanism amplification | (build from Section 2 table) | ΔP, Q_ASD, RVSV, RVEDV changes |

---

## 9. What You Still Need

| Item | Priority | Time |
|---|---|---|
| Mechanism audit table (baseline vs v4, per ChatGPT/Claude recommendation) | High | 30 min |
| Cross-patient comparison table (after running other patients) | High | 30 min/patient |
| Clean figure versions (no timestamp in filename, thesis-ready captions) | Medium | 1 hr |
| Methods section draft using pipeline workflow document | High | 1-2 hr |
| Results section draft using GSA + calibration outputs | High | 1-2 hr |
