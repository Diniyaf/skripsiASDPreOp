# Strategi Penyatuan Pipeline Kalibrasi ASD
## Menuju `run_asd_calibration.m` Terpusat

**Konteks:** Diniya (pre-closure ASD) — Skripsi Pemodelan Teknik Biomedik  
**Status saat ini:** Steps 1–6 sudah berjalan tapi terpisah per pasien (Zoya & Indira)  
**Tujuan:** Satu file terpusat yang robust untuk semua pasien, mengacu pola `main_run.m` unified VSD

---

## 1. Referensi: 11 Step Pipeline Unified VSD

Pipeline lengkap `main_run.m` (Hafis-Keisya) sebagai acuan metodologi:

| Step | Nama | Deskripsi | Status di ASD saat ini |
|:---:|---|---|:---:|
| 1 | **Allometric scaling** | Scaling parameter dewasa → pediatrik via Lundquist BSA | ✅ Sudah ada via `run_asd_patient_case` |
| 2 | **Map clinical → params** | Seed parameter dari data klinis pasien | ✅ Sudah ada via `run_asd_patient_case` |
| 3 | **Baseline simulation** | Simulasi ODE sebelum kalibrasi, hitung RMSE awal | ✅ Sudah ada di kedua file |
| 4 | **Initial GSA** | Analisis sensitivitas global → ranking parameter | ⚠️ **ASD: Sobol manual (BUKAN PCE)**, file terpisah per pasien |
| 5 | **Build optimisation mask** | Pilih parameter aktif dari Sobol ST + target tiers | ✅ Sudah ada, tapi logic personalized per pasien |
| 6 | **Calibration (staged)** | fmincon: Stage A → (B skip) → C | ⚠️ Sudah ada tapi personalized, hanya A+C |
| 7 | **Final GSA post-kalibrasi** | Verifikasi sensitivitas setelah kalibrasi | ❌ Belum ada di ASD |
| 8 | **Validation + rollback** | 11 gates + 3-level rollback | ✅ Sudah ada tapi sedikit berbeda Zoya vs Indira |
| 9 | **Plots** | PV loop, pressure traces, hemodynamic summary | ❌ Belum terpusat |
| 10 | **Save artefacts** | CSV, MAT, log | ⚠️ Sudah ada tapi nama file hardcoded per pasien |
| 11 | **Save calibrated params + seed** | Handoff ke post-closure (Jovano) | ❌ Belum ada di ASD |

> **Catatan penting Step 4:** ASD tidak menggunakan PCE/UQLab seperti VSD. GSA ASD menggunakan Sobol sampling manual (Monte Carlo). Ini keputusan metodologi yang valid dan perlu didokumentasikan di skripsi. File GSA (`run_zoya_asd_gsa_curated.m`, `run_indira_asd_gsa_curated.m`) sudah ada tapi juga masih per pasien.

---

## 2. Diagnosis: Apa Masalahnya di File Saat Ini?

### 2.1 Perbedaan yang Hardcoded Per Pasien (seharusnya Data-Driven)

| Aspek | `run_zoya_asd_calibration.m` | `run_indira_asd_calibration.m` | Seharusnya |
|---|---|---|---|
| **Nama file GSA yang dicari** | `zoya_asd_gsa_curated_*.mat` | `indira_asd_gsa_curated_*.mat` | Dari `caseProfile.patient_label` |
| **Nama folder output** | `zoya_asd_calib_%s` | `indira_asd_calib_%s` | Dari `patient_label` |
| **Nama file MAT** | `zoya_asd_calibration_*.mat` | `indira_asd_calibration_*.mat` | Dari `patient_label` |
| **Nama file CSV** | `zoya_asd_*.csv` | `indira_asd_*.csv` | Dari `patient_label` |
| **ST_THRESHOLD** | `0.05` (diturunkan karena sparse data) | `0.10` (standar) | Via `options` struct dengan default |
| **Atrial expansion** | Force-add `{V0.LA, V0.RA, E.LA.EB}` | Tidak ada force-add | Dari `caseProfile.dataFlags` |
| **Metric weights** | Fixed: `QpQs=5.0`, `Qp_Lmin=3.0` | Auto dari baseline error | Satu policy adaptif |
| **Secondary guard behavior** | Secondary → **reject** rollback | Secondary → **warning only** | Satu policy (warning, sudah diputuskan) |
| **`best_rejected_candidate` export** | Tidak ada | Ada | Satu policy export |
| **Error message ID** | `run_zoya_asd_calibration:...` | `run_indira_asd_calibration:...` | Generic: `run_asd_calibration:...` |

### 2.2 Duplikasi Kode yang Identik (DRY Violation)

Blok-blok berikut **100% identik** di kedua file tapi di-copy-paste:

| Blok kode | Baris di Zoya | Baris di Indira | Risiko duplikasi |
|---|:---:|:---:|---|
| `apply_sim_overrides()` | 644–648 | 723–727 | Bug fix harus dilakukan 2× |
| `apply_calibrated_params()` | 650–659 | 729–738 | Idem |
| `metric_oob()` | 661–665 | 740–744 | Idem |
| `iif()` | 667–669 | 746–748 | Idem |
| `resolve_allow_group_c()` | 749–753 | 917–921 | Idem |
| `resolve_parallel_fmincon()` | 755–769 | 923–937 | Idem |
| 11 validity gates (flags) | 406–451 | 410–451 | Perubahan 1 gate → update 2 file |
| Blok Stage A fmincon + metrics | 272–320 | 272–320 | Idem |
| Blok Stage C logic | 322–386 | 322–386 | Idem |
| Blok rollback 3-level | 507–569 | 512–568 | Sedikit berbeda — sumber inkonsistensi |

### 2.3 Inkonsistensi Logika yang Berisiko

Selain duplikasi, ada **perbedaan logika nyata** yang tidak disengaja (silently diverged):

| Logika | Zoya | Indira | Risiko |
|---|---|---|---|
| **`evaluate_clinical_fit_gate` — secondary** | Secondary langsung tambah ke `reasons` → trigger rollback | Secondary masuk ke `secondary_warnings` → hanya print | Satu pasien bisa rollback, satunya tidak, padahal kondisi klinis mirip |
| **`best` struct fields** | `best.params = final_params` (vektor nilai) | `best.params = best_params_struct` (params struct penuh) | MAT file tidak kompatibel → tidak bisa dibandingkan programatik |
| **`accepted_candidate` struct** | Tidak ada struct terpisah | Ada `accepted_candidate` struct eksplisit | Script analisis downstream harus handle dua format berbeda |
| **`map_band_from_target`** | Tidak ada (MAP band otomatis dari objective) | Ada panggilan eksplisit | Indira dapat perlindungan MAP guard ekstra |
| **`metric_weights_from_baseline`** | Tidak ada fungsi ini, weights fixed | Ada, auto-compute | Dua filosofi berbeda dalam satu metodologi |

---

## 3. Gambaran Besar Skema Terpusat

### 3.1 Konsep Utama

Satu fungsi `run_asd_calibration(patient_fn, patient_label, options)` yang menerima:
- `patient_fn` — function handle ke config pasien, misal `@patient_zoya`
- `patient_label` — string label, misal `'zoya'`
- `options` — struct opsional untuk override default

Semua keputusan diambil secara data-driven dari:

```
clinical struct    →  apakah RAP ada? LAP? QpQs? ASD gradient?
caseProfile        →  dataFlags, shunt mode, patient_label
options struct     →  ST_threshold override, budget fmincon, flag allow_groupC
```

### 3.2 Cara Pakai per Pasien (target akhir)

```matlab
% run_zoya.m — 3 baris, tidak ada logic
run_asd_calibration(@patient_zoya, 'zoya');

% run_indira.m — 3 baris, tidak ada logic
run_asd_calibration(@patient_indira, 'indira');

% Pasien baru — zero additional code
run_asd_calibration(@patient_baru, 'baru');
```

### 3.3 Alur Internal File Terpusat (Steps 1–6 + Post-Cal)

```
run_asd_calibration(patient_fn, patient_label, options)
│
├── [STEP 1+2] LOAD + CONTEXT
│   run_asd_patient_case(patient_fn, patient_label, 'pre_surgery', ...)
│   → clinical, params0, caseProfile  (scaling + seeding sudah di dalamnya)
│
├── [STEP 4 proxy] LOAD GSA RESULTS
│   Cari: {patient_label}_asd_gsa_curated_*.mat  (ambil terbaru)
│   Fallback: {patient_label}_asd_gsa_*.mat
│   Jika tidak ada → error dengan petunjuk: "Run run_asd_gsa.m first"
│
├── [STEP 5] BUILD OPTIMISATION MASK
│   build_asd_active_mask_from_gsa(...)   →  optMask dasar dari Sobol ST
│   force_shunt_param(params0)            →  asd.Cd atau R.asd (mode-aware)
│   decide_atrial_expansion(dataFlags)    →  data-driven (lihat §3.4)
│   ensure_min_nonventricular(5)          →  GSA expansion fallback
│
├── [STEP 3] BASELINE SIMULATION
│   integrate_system → metrics_base → guardBaselineMetrics
│   compute_adaptive_weights(metrics_base, targets)  (lihat §3.5)
│
├── [STEP 6] CALIBRATION
│   Stage A: fmincon — vascular + shunt + preload
│   Stage C: fmincon — ventricular extension (hanya jika ASD_CALIB_ALLOW_GROUPC=1
│             DAN rmse_A >= threshold)
│
├── [POST-CAL] VALIDATION
│   11 validity gates  (identik semua pasien)
│   Clinical fit gate: primary=reject, secondary=WARNING saja
│   Parameter plausibility
│   3-level rollback
│
└── [STEP 10] EXPORT
    Semua nama file dari patient_label + timestamp
    MAT + CSV: baseline, calibrated, best_candidate, parameters, decision
    Format struct konsisten untuk semua pasien
```

### 3.4 Resolusi Masalah Atrial Expansion (Data-Driven)

Logika ini menggantikan hardcode per pasien:

| Kondisi data klinis | Keputusan | Alasan fisiologi |
|---|---|---|
| `has_lap = true` AND `has_rap = false` | **Force-add** `{V0.LA, V0.RA, E.LA.EB}` | LAP tersedia sebagai anchor, tapi tanpa RAP constraint, gradient atrial perlu derajat kebebasan ekstra untuk match Qp/Qs |
| `has_lap = true` AND `has_rap = true` | **Skip expansion** | Kedua atrial pressure ter-constraint oleh target → cukup dari mask GSA biasa |
| `has_lap = false` AND `has_rap = false` | **Skip expansion + warning** | Tidak ada anchor atrial → expansion berisiko drift tanpa kontrol |
| `has_lap = false` AND `has_rap = true` | **Tergantung GSA** | Tidak umum, biarkan GSA yang menentukan |

> Kondisi Zoya masuk baris 1 (LAP ada, RAP tidak ada) → force expansion.  
> Kondisi Indira masuk baris 2 (LAP dan RAP ada) → skip expansion.  
> Logika yang sama untuk pasien baru — otomatis.

### 3.5 Resolusi Masalah Metric Weights (Policy Adaptif)

Menggabungkan filosofi Zoya (prioritas eksplisit) dan Indira (adaptif dari error):

```
weight(metric) = clip(baseline_error_pct / 20, floor, ceiling)
    floor   = 1.0  (semua metric tetap dihitung)
    ceiling = 5.0  (tidak ada yang mendominasi)

Override floor khusus untuk metrik kritis ASD:
    QpQs     → floor = 1.5  (shunt severity, selalu prioritas)
    LAP_mean → floor = 1.5  (atrial pressure driver, kritis ASD)
    Qp_Lmin  → floor = 1.2  (mendukung QpQs interpretation)
```

**Dapat dilaporkan di skripsi sebagai:**
> *"Bobot metrik dikalibrasi secara adaptif berdasarkan kesalahan relatif pada simulasi baseline, dengan batas bawah 1.5 untuk metrik kritis ASD (Qp/Qs dan LAP) guna memastikan shunt severity selalu menjadi prioritas optimisasi."*

---

## 4. Masalah Konkret yang Muncul Jika File Saat Ini Digabungkan

Ini adalah daftar hal yang **harus diselesaikan** agar penggabungan berjalan benar:

### 4.1 Masalah Kode

| No. | Masalah | File terdampak | Aksi yang diperlukan |
|:---:|---|---|---|
| M1 | `evaluate_clinical_fit_gate` berbeda signature dan behavior | Zoya vs Indira | Standardkan ke versi Indira (secondary=warning), hapus versi Zoya |
| M2 | `best` struct memiliki tipe berbeda (vector vs params struct) | Kedua file | Standardkan ke struct lengkap seperti Indira (lebih informatif) |
| M3 | `accepted_candidate` struct hanya ada di Indira | Zoya tidak punya | Tambahkan ke semua, wajib untuk downstream analysis |
| M4 | `map_band_from_target` hanya dipanggil Indira | Zoya | Jadikan bagian default `calib_cfg` untuk semua pasien |
| M5 | `metric_weights_from_baseline` fungsi hanya ada di Indira | Zoya pakai fixed | Ganti semua dengan policy adaptif §3.5 |
| M6 | Duplikasi 9 local functions | Kedua file | Pindahkan ke `src/calibration/` sebagai shared utilities |
| M7 | ST_THRESHOLD berbeda (0.05 vs 0.10) tanpa penjelasan | Kedua file | Satu default + optional override via `options.st_threshold` |

### 4.2 Masalah Struktural Output (MAT Compatibility)

| No. | Masalah | Dampak |
|:---:|---|---|
| S1 | `pkg.best_candidate.params` = vektor di Zoya, struct di Indira | Script analisis downstream tidak bisa membaca MAT keduanya secara seragam |
| S2 | `pkg.best_rejected_candidate` tidak ada di Zoya | Saat rollback terjadi di Zoya, tidak ada catatan kandidat terbaik yang ditolak |
| S3 | `pkg.accepted_candidate` tidak ada di Zoya | Harus reconstruct dari fields terpisah → rawan kesalahan |
| S4 | CSV di Zoya: 2 file. CSV di Indira: 5 file | Tidak bisa dibandingkan programatik antar pasien |

### 4.3 Masalah Metodologi (Perlu Keputusan)

| No. | Masalah | Opsi | Rekomendasi |
|:---:|---|---|---|
| P1 | **Atrial expansion**: kapan dilakukan? | (a) Selalu manual per pasien, (b) Data-driven dari `dataFlags` | → Opsi (b), lihat §3.4 |
| P2 | **Metric weights**: fixed atau adaptif? | (a) Fixed untuk semua ASD, (b) Adaptif dengan floor/ceiling | → Opsi (b) adaptif, lihat §3.5 |
| P3 | **ST_THRESHOLD**: satu nilai atau per pasien? | (a) Satu default 0.05 untuk ASD sparse data, (b) Configurable | → Default 0.05, override via `options` |
| P4 | **Stage C trigger**: fixed 10% atau configurable? | (a) Fixed 0.10, (b) Via `options.stage_a_success_rmse` | → Default 0.10, override via `options` |
| P5 | **Stage B**: di VSD ada, di ASD skip karena tidak ada volume target | Tetap skip kecuali `caseProfile.has_ventricular_volume` | → Tetap skip by default |

---

## 5. Ringkasan: Apa yang Perlu Dibuat

Untuk mencapai file terpusat, ada **2 output utama**:

### Output A — `run_asd_calibration.m` (file terpusat, di `/scripts/`)
Menggantikan `run_zoya_asd_calibration.m` dan `run_indira_asd_calibration.m`.  
Menerima `(patient_fn, patient_label, options)` dan menjalankan Steps 1–6 + post-cal untuk pasien apapun.

### Output B — Shared utility functions (di `/src/calibration/`)
Local functions yang sekarang ada di kedua file dipindahkan ke satu tempat:
- `targets_from_tiers`
- `evaluate_clinical_fit_gate` (versi final: secondary=warning)
- `compute_adaptive_weights`
- `decide_atrial_expansion`
- `apply_sim_overrides`
- `apply_calibrated_params`
- `build_parameter_export_table`
- `build_rollback_decision_table`

> **Catatan untuk skripsi:** File per pasien (`run_zoya.m`, `run_indira.m`) tetap ada sebagai entry point yang sangat ringkas, sehingga ada dokumentasi audit trail per pasien yang jelas. Yang hilang hanya logic — bukan file pasien-nya.

---

## 6. Open Questions (Perlu Konfirmasi Diniya)

| # | Pertanyaan | Pilihan | Status |
|:---:|---|---|:---:|
| Q1 | Secondary guard: reject atau warning? | **Warning** | ✅ Sudah diputuskan |
| Q2 | Atrial expansion logic | Data-driven dari `dataFlags` | ⏳ Perlu konfirmasi |
| Q3 | Metric weights policy | Adaptif dengan floor/ceiling | ⏳ Perlu konfirmasi |
| Q4 | ST_THRESHOLD default | 0.05 (lebih sensitif untuk ASD sparse) | ⏳ Perlu konfirmasi |
| Q5 | Stage C trigger threshold | 0.10 RMSE, configurable | ⏳ Perlu konfirmasi |
| Q6 | File GSA juga akan disatukan? | `run_asd_gsa.m` terpusat? | ⏳ Diskusi terpisah |

---

## 7. Opencode Review & Recommendations

### 7.1 Overall Assessment

Strategi yang kamu tuangkan **sangat solid.** Diagnosis duplikasi (M1-M7), inkonsistensi
(S1-S4), dan policy decisions (P1-P5) sudah akurat. Struktur `run_asd_calibration`
yang diusulkan di §3.3 juga tepat — mirip `main_run.m` VSD tanpa over-engineering.

Dua area yang perlu diperkuat:

### 7.2 Critical Missing: GSA Integration

Saat ini GSA dan Kalibrasi adalah **dua file terpisah** per pasien. Idealnya GSA
juga masuk pipeline terpusat. Tapi ada trade-off:

| Opsi | Pro | Con |
|---|---|---|
| **GSA + Kalibrasi terpisah** (sekarang) | GSA bisa di-run sekali, kalibrasi bisa di-ulang berkali-kali tanpa re-run GSA | Dua file, dua kali run |
| **GSA + Kalibrasi jadi satu** (`run_asd_pipeline.m`) | Satu command, semua otomatis | Kalau kalibrasi gagal dan butuh re-run, GSA juga re-run (boros) |

**Rekomendasi:** Tetap pisah seperti VSD. VSD juga melakukan ini — `gsa_pce_setup`
+ `gsa_run_pce` bisa di-skip kalau `.mat` GSA sudah ada (Step 4 di `main_run.m`
ada conditional skip). Pattern yang sama:

```matlab
% Di run_asd_calibration.m (Step 4 proxy):
gsa_file = find_latest_gsa(patient_label);  % auto-find
if isempty(gsa_file)
    error('Run run_asd_gsa(%s) first.', patient_label);
end
```

Ini persis yang sudah kamu rencanakan di §3.2. Lanjutkan.

### 7.3 Step Ordering — Baseline Seharusnya Sebelum Mask

Di §3.3, baseline simulation (Step 3) ditempatkan **setelah** mask building (Step 5).
Ini tidak tepat karena:

1. Baseline metrics dibutuhkan untuk **compute_adaptive_weights** (butuh baseline error)
2. Baseline RMSE dibutuhkan untuk **rollback comparison** nanti
3. Di VSD, baseline simulation = Step 3, sebelum GSA mask = Step 5

**Perbaikan:** Pindahkan baseline simulation ke **sebelum** mask building:

```
[STEP 1+2] LOAD + CONTEXT
[STEP 3]   BASELINE SIMULATION  ← di sini, bukan setelah mask
[STEP 4]   LOAD GSA RESULTS
[STEP 5]   BUILD MASK
[STEP 6]   CALIBRATION
```

### 7.4 Jawaban untuk Open Questions (Q2-Q5)

**Q2 — Atrial expansion logic: SETUJU dengan data-driven.** Logic di §3.4 sudah
tepat. Tambahan: kalau LAP tersedia tapi baseline LAP sudah dekat target (<15%
error), skip expansion meskipun RAP missing — karena tidak ada kebutuhan fisiologis.

**Q3 — Metric weights: SETUJU dengan adaptif + floor.** Formula di §3.5 masuk akal.
Satu catatan: floor=1.5 untuk QpQs dan LAP harus di-justifikasi di skripsi
("shunt severity dan atrial pressure adalah target klinis paling relevan untuk ASD").

**Q4 — ST_THRESHOLD default: 0.05.** Setuju. Tapi perlu documented rationale:
"Threshold 0.05 dipilih berdasarkan pengalaman Zoya — di mana parameter dengan
ST 0.05-0.10 (R.SAR, R.SVEN) ternyata penting untuk systemic pressure control
meskipun tidak terdeteksi di threshold 0.10."

**Q5 — Stage C trigger: 0.10 RMSE.** Setuju. Tapi perlu diakui bahwa 0.10 adalah
target ambisius yang mungkin tidak achievable untuk semua pasien. Di VSD, recipe
system mengakomodasi ini via `accept_initial_seed_rmse_max`. Framework ASD bisa
menambah `options.stage_a_accept_rmse` yang default 0.10 tapi bisa di-override.

### 7.5 Tambahan: Pre-to-Post Seed Export (Step 11 VSD)

Ini belum dibahas di dokumen. Untuk handoff ke Jovano, perlu export:

```matlab
% Di akhir run_asd_calibration, setelah accepted:
if strcmp(scenario, 'pre_surgery') && options.export_seed
    seed = struct();
    seed.params = accepted_params;
    seed.metrics = accepted_metrics;
    seed.ic_vector = accepted_params.ic.V;
    seed.source_run = run_folder;
    save(fullfile(run_folder, sprintf('%s_pre_to_post_seed.mat', patient_label)), 'seed');
end
```

Ini Step 11 di VSD — opsional, diaktifkan via `options.export_seed = true`.

### 7.6 Shared Utilities — Satu File Saja

Usulan di §5 (Output B) menyebut 8 shared functions. Sebaiknya **satu file**
`src/calibration/calibration_shared_utils.m` daripada 8 file kecil — mengurangi
path clutter. Atau langsung taruh sebagai local functions di `run_asd_calibration.m`
(dan extract ke shared file nanti kalau sudah >500 baris).

### 7.7 Satu Hal yang Belum Terbahas: GSA File Naming Convention

Saat ini GSA menyimpan file dengan prefix hardcoded (`zoya_asd_gsa_curated_*.mat`).
Kalau calibration script mencari `{patient_label}_asd_gsa_curated_*.mat`, maka
GSA script juga harus menyimpan dengan format yang sama. Ini sinkronisasi yang
perlu dipastikan.

### 7.8 Implementation Priority

| Priority | Task | Effort |
|---|---|---|
| **P0** | Buat `run_asd_calibration.m` terpusat | 2-3 jam |
| **P0** | Standardkan M1-M7 (semua masalah kode) | 1 jam |
| **P1** | Tambah `export_seed` untuk Jovano | 15 menit |
| **P1** | Pindahkan shared utils | 30 menit |
| **P2** | Buat `run_asd_gsa.m` terpusat | 2 jam |
| **P2** | Test regression: Zoya + Indira hasil sama | 1 jam |

### 7.9 Rekomendasi Final

**Jangan buat `main_run` ala VSD sekarang.** Prioritas: `run_asd_calibration.m`
terpusat + standardisasi. GSA unification bisa menyusul. Dengan 2 file terpusat
(`run_asd_gsa.m` + `run_asd_calibration.m`), kamu sudah punya "pipeline" yang
cukup untuk skripsi — tanpa perlu 1.459 baris `main_run.m`. Itu bisa jadi
"future work" setelah sidang.

---

## 8. Implementasi 2026-06-07 - Generic Calibration Runner

Sudah dibuat runner terpusat:

```matlab
run_asd_calibration(patient_fn, patient_label, scenario, options)
```

Wrapper pasien dapat menjadi tipis, misalnya:

```matlab
run_asd_calibration(@patient_aluna, 'aluna', 'pre_surgery', options);
```

### Step yang Sudah Dicakup

| Step unified | Status ASD runner generic | Catatan |
|---|---|---|
| Validation report + rollback logic | Implemented | Hard validity gates, primary clinical fit guard, secondary warning-only guard, plausibility table, rollback decision CSV |
| Plots | Implemented | Pressure overlay, ASD shunt/DeltaP overlay, PV-loop overlay in run-specific `figures/` folder |
| Save artefacts | Implemented | MAT package, baseline/accepted/best-candidate CSV, validation-gate CSV, clinical-fit-gate CSV, rollback-decision CSV, run README |
| Save calibrated params + pre-to-post seed | Implemented | Timestamped `{patient}_pre_to_post_seed_*.mat` in the calibration run folder |
| Final GSA post-calibrasi | Postponed | Planned after accepted calibration; not run automatically |

### Methodological Boundary

The generic runner does not change model equations, clinical seeding,
target-tier construction, or GSA results. It only standardizes calibration
orchestration and post-calibration artefact export. Final post-calibration GSA
remains a separate future step so that calibration and sensitivity verification
stay methodologically separated.
