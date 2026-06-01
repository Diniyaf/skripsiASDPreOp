# Thesis Writing Guide — GSA Section: Dasar Teori & Metode

**Date:** 2026-06-01
**Scope:** Global Sensitivity Analysis (Sobol Monte Carlo) for ASD lumped-parameter model

---

## 1. Overview: Dasar Teori vs Metode

| | **Dasar Teori (Chapter 2)** | **Metode Penelitian (Chapter 3)** |
|---|---|---|
| **Apa yang dijelaskan** | KONSEP — definisi, rumus, kenapa metode ini dipilih | IMPLEMENTASI — parameter, bounds, konfigurasi, handling |
| **Referensi** | Jurnal/papers (Saltelli, Sobol, Jansen) | Parameter registry, clinical data, model setup |
| **Tone** | "Global sensitivity analysis adalah..." | "GSA dilakukan pada 25 parameter..." |
| **Batasan** | Tidak menyebut pasien spesifik | Spesifik ke Zoya dan ASD |

---

## 2. Dasar Teori — Sub-bab yang Perlu Ditulis

### 2.1 Global Sensitivity Analysis dalam Model Kardiovaskular

**Isi:**
- Definisi GSA: metode untuk mengukur kontribusi setiap parameter input terhadap varians output model
- Beda dengan local sensitivity (OAT/one-at-a-time): GSA mengeksplorasi seluruh ruang parameter secara simultan
- Kenapa diperlukan di lumped-parameter cardiovascular model:
  - Parameter banyak (>20) → interaksi signifikan
  - Nonlinear (valve switching, elastance time-varying)
  - Coupled (perubahan R.SAR mempengaruhi P_LV, V_LV, Qs, MAP sekaligus)
- Variance-based GSA = gold standard karena model-free dan menangkap interaksi

**Referensi:**
1. Saltelli A, Ratto M, Andres T, et al. (2008). *Global Sensitivity Analysis: The Primer*. John Wiley & Sons. — **Buku utama.**
2. Saltelli A, Annoni P. (2010). How to avoid a perfunctory sensitivity analysis. *Environmental Modelling & Software*, 25(12):1508-1517. — **Justifikasi kenapa GSA > local.**
3. Eck VG, Donders WP, Sturdy J, et al. (2016). A guide to uncertainty quantification and sensitivity analysis for cardiovascular models. *Int J Numer Method Biomed Eng*, 32(8):e02755. — **Kontekstualisasi ke kardiovaskular.**

### 2.2 Sobol Variance Decomposition

**Isi:**
- Konsep dekomposisi varians: `V(Y) = Σ V_i + Σ V_ij + ... + V_12...k`
- First-order index: `S1_i = V_i / V(Y)` — kontribusi parameter i saja
- Total-order index: `ST_i = (V_i + Σ V_ij + ...) / V(Y)` — kontribusi parameter i + semua interaksi
- Interpretasi:
  - `ST_i ≈ 0` → parameter tidak berpengaruh
  - `ST_i ≈ 1` → parameter mendominasi
  - `S1_i << ST_i` → parameter bekerja melalui interaksi
- Kenapa ST diprioritaskan untuk pemilihan parameter aktif: model kardiovaskular closed-loop sangat coupled

**Referensi:**
4. Sobol IM. (2001). Global sensitivity indices for nonlinear mathematical models and their Monte Carlo estimates. *Mathematics and Computers in Simulation*, 55(1-3):271-280. — **Paper orisinal Sobol.**
5. Saltelli A, Annoni P, Azzini I, et al. (2010). Variance based sensitivity analysis of model output. Design and estimator for the total sensitivity index. *Computer Physics Communications*, 181(2):259-270. — **Paper Saltelli yang dipakai semua orang.**

### 2.3 Saltelli Sampling dan Jansen Estimator

**Isi:**
- Metode sampling: quasi-random Sobol sequence → low-discrepancy, lebih efisien dari pure random
- Saltelli design: dua matriks independen A dan B (N × k), matriks silang AB_i = A dengan kolom i diganti B
- Total evaluasi = N × (k + 2)
- Estimator Jansen (1999):
  - `ST_i = (1/2N) Σ (y_A - y_AB_i)² / V(Y)`
  - `S1_i = 1 - (1/2N) Σ (y_B - y_AB_i)² / V(Y)`
- Keunggulan Jansen: efisien (konvergen lebih cepat dari estimator Sobol asli), stabil secara numerik

**Referensi:**
6. Jansen MJW. (1999). Analysis of variance designs for model output. *Computer Physics Communications*, 117(1-2):35-43. — **Paper orisinal Jansen estimator.**
7. Saltelli A, Ratto M, Andres T, et al. (2010). — Sama dengan [5], mencakup Saltelli design + Jansen estimator.

### 2.4 Bootstrap Confidence Intervals

**Isi:**
- Kenapa perlu: Sobol indices adalah point estimates; tanpa CI tidak bisa membedakan parameter dengan ST=0.12 dari ST=0.08
- Metode: resample matriks output dengan replacement → hitung ulang ST → ulangi 200× → persentil 2.5% dan 97.5%
- Interpretasi: kalau CI_lebar > ST_point → ranking tidak reliable; perlu N lebih besar

**Referensi:**
8. Efron B, Tibshirani RJ. (1994). *An Introduction to the Bootstrap*. Chapman & Hall/CRC. — **Buku referensi bootstrap.**
9. Archer GEB, Saltelli A, Sobol IM. (1997). Sensitivity measures, ANOVA-like techniques and the use of bootstrap. *Journal of Statistical Computation and Simulation*, 58(2):99-120. — **Bootstrap khusus untuk Sobol indices.**

---

## 3. Metode Penelitian — Sub-bab yang Perlu Ditulis

### 3.1 Parameter Selection dan Bounds

**Isi:**
- 25 parameter dikelompokkan dalam 3 grup berdasarkan relevansi fisiologis:
  - **Group A (vaskular/shunt):** `asd.Cd`, 6 resistances, 3 compliances — didukung langsung oleh target pressure-flow
  - **Group B (atrial/preload):** 4 atrial elastance, 4 unstressed volumes, 2 venous compliance — relevan untuk ASD karena shunt di atrium
  - **Group C (ventrikel/monitor-only):** 4 ventricular elastance, 2 unstressed volumes — tidak dikalibrasi tanpa data volume
- Bounds parameter: multiplier terhadap baseline pediatric scaled (Tabel 3.1)
- Sumber bounds: resistances (Kung et al., 2013), elastance (Zhang et al., 2019), arterial compliance (Windkessel theory)

**Tabel yang perlu dibuat:**

| Kelas Parameter | Multiplier Range | Sumber |
|---|---|---|
| Resistances (R.SAR, R.SC, etc.) | 0.40–2.50× | Kung 2013 |
| R.SVEN, R.PVEN | 0.40–3.00× | Kung + R-C coupling |
| C.SAR | 0.75–1.35× | Windkessel SV/PP |
| C.PAR | 0.70–1.45× | Windkessel SV/PP |
| C.SVEN, C.PVEN | 0.50–1.80× | Kung R-C coupled |
| E.LV | 0.60–2.20× | Zhang 2019 |
| E.RV | 0.55–2.60× | Zhang 2019 |
| E.LA/RA | 0.20–2.50× | Zhang 2019 |
| V0 (all) | 0.70–1.40× | Blood volume consistency |
| asd.Cd | [0.20, 1.20] | Orifice coefficient |

**Referensi:**
10. Kung E, Pennati G, Migliavacca F, et al. (2013). Multiscale modeling of the cardiovascular system. *Annals of Biomedical Engineering*. — **Sumber bounds resistances.**
11. Zhang Y, et al. (2019). — **Sumber bounds elastance.**
12. Stergiopulos N, Meister JJ, Westerhof N. (1994). Simple and accurate way for estimating total and segmental arterial compliance. *American Journal of Physiology*. — **Windkessel compliance.**
13. Lundquist et al. (2025). Patient-specific pediatric cardiovascular lumped parameter modeling. *ASAIO Journal*. — **Pediatric scaling.**

### 3.2 Sampling Configuration

**Isi:**
- Desain Saltelli dengan N=128 base samples
- Quasi-random Sobol sequence (Statistics Toolbox), seed=42 untuk reproduktibilitas
- Total evaluasi model: N × (k+2) = 128 × 27 = 3,456 simulasi ODE
- Parallel execution: Parallel Computing Toolbox, 6 workers, `parfor` loop

### 3.3 Model Evaluation

**Isi:**
- Setiap sampel: terapkan nilai parameter → `integrate_system` → `compute_clinical_indices`
- Warmup: 40 cardiac cycles, toleransi steady state relaxed (1.0 mmHg, 1.0 mL)
- Primary outputs: QpQs, Qp_Lmin, Qs_Lmin, SAP_mean, PAP_mean, LAP_mean
- Secondary outputs: SAP_max/min, PAP_max/min, Q_ASD_Lmin

### 3.4 Failed Sample Handling

**Isi:**
- **Numerical failures** (solver gagal, steady state tidak tercapai, NaN): output diisi NaN → dieksklusi dari perhitungan Sobol via `isfinite()` masking
- **Physiology warnings** (Q_ASD < 0, QpQs < 1): output TETAP valid → masuk perhitungan Sobol
- Alasan: mengisi failed sample dengan 0 menghasilkan varians artifisial yang overestimate ST
- Kedua kategori dicatat terpisah untuk transparansi

**Tabel yang perlu dibuat:**

| Failure Type | Count | % | Handled as |
|---|---|---|---|
| `steady_state_failure` | X | X.X% | NaN → excluded |
| `opposite_shunt_direction` | XXX | XX% | Valid → included |
| `unexpected_physiology` | X | X% | Valid → included |

### 3.5 Target Tier Governance

**Isi:**
- Hanya metric dengan data klinis yang menentukan active set selection
- Hard primary: QpQs, Qp_Lmin, Qs_Lmin, SAP_mean, PAP_mean, LAP_mean → digunakan untuk ranking ST
- Soft secondary: SAP_max/min, PAP_max/min, Q_ASD_Lmin → informasi tambahan
- Prediction-only: RAP_mean, SVR, PVR — dilaporkan, tidak menentukan keputusan
- Excluded: LVEDV, LVESV, RVEDV, RVESV, LVEF, RVEF — data klinis tidak tersedia

### 3.6 Active Set Selection

**Isi:**
- Threshold: ST_max ≥ 0.10 untuk minimal satu primary target
- Minimum 4, maksimum 8 parameter untuk identifiability
- Group C ventricular parameters: monitor-only (environment variable gate `ASD_CALIB_ALLOW_GROUPC`)
- `asd.Cd` di-force masuk active set (fisiologis primer, shunt knob langsung)

---

## 4. Complete Literature List

### Buku / Monographs
| # | Reference | Digunakan untuk |
|---|---|---|
| [1] | Saltelli A, et al. (2008). *Global Sensitivity Analysis: The Primer*. Wiley. | Definisi GSA, konsep dasar |
| [8] | Efron B, Tibshirani RJ. (1994). *An Introduction to the Bootstrap*. CRC Press. | Bootstrap CI |

### Journal Papers — GSA Methodology
| # | Reference | Digunakan untuk |
|---|---|---|
| [4] | Sobol IM. (2001). *Math Comput Simul*, 55:271-280. | Sobol variance decomposition |
| [5] | Saltelli A, et al. (2010). *Comput Phys Commun*, 181:259-270. | Saltelli design, Jansen estimator |
| [6] | Jansen MJW. (1999). *Comput Phys Commun*, 117:35-43. | Jansen estimator |
| [9] | Archer GEB, et al. (1997). *J Stat Comput Simul*, 58:99-120. | Bootstrap untuk Sobol |
| [2] | Saltelli A, Annoni P. (2010). *Environ Model Softw*, 25:1508. | Justifikasi GSA > local |

### Journal Papers — Cardiovascular Modeling Context
| # | Reference | Digunakan untuk |
|---|---|---|
| [3] | Eck VG, et al. (2016). *Int J Numer Method Biomed Eng*, 32:e02755. | GSA di model kardiovaskular |
| [10] | Kung E, et al. (2013). *Ann Biomed Eng*. | Bounds resistances |
| [11] | Zhang Y, et al. (2019). | Bounds elastance pediatric |
| [12] | Stergiopulos N, et al. (1994). *Am J Physiol*. | Windkessel compliance |
| [13] | Lundquist et al. (2025). *ASAIO Journal*. | Pediatric scaling |

### Thesis / Internal Documents
| # | Reference | Digunakan untuk |
|---|---|---|
| [14] | Valenti (2023). Full-order 0-D cardiovascular model. Thesis. | Model ODE baseline |

---

## 5. Figure Suggestions

| Figure | Isi |
|---|---|
| **Heatmap ST matrix** (25 params × 6 primary targets) | Dari `zoya_asd_gsa_curated_ST_heatmap_*.pdf` |
| **Ranked bar chart** per primary metric | Dari `zoya_asd_gsa_curated_ST_bar_*.pdf` |
| **Bootstrap CI summary table** | ST ± CI untuk top 10 parameters |
| **Parameter grouping diagram** | Flowchart Group A/B/C dengan bounds dan justifikasi |
| **Target tier table** | Primary / secondary / prediction-only / excluded |

---

## 6. Writing Checklist

- [ ] Dasar Teori: definisi GSA + justifikasi untuk model kardiovaskular [ref 1,2,3]
- [ ] Dasar Teori: Sobol variance decomposition + rumus S1, ST [ref 4,5]
- [ ] Dasar Teori: Saltelli design + Jansen estimator [ref 5,6]
- [ ] Dasar Teori: bootstrap CI [ref 8,9]
- [ ] Metode: parameter selection + bounds table + sumber [ref 10,11,12,13]
- [ ] Metode: sampling configuration (N=128, seed=42, quasi-random Sobol)
- [ ] Metode: model evaluation (warmup, parallel, metrics)
- [ ] Metode: failed sample handling (NaN vs 0, numerical vs physiology)
- [ ] Metode: target tier governance (primary/secondary/prediction-only)
- [ ] Metode: active set selection rule + Group C governance
