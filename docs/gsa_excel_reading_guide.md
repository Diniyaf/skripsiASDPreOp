# Panduan Membaca Excel Hasil GSA — ASD Calibration Framework

**Tanggal:** 2026-06-07  
**Konteks:** Global Sensitivity Analysis (Sobol, Monte Carlo) untuk model lumped parameter ASD  
**Tujuan dokumen:** Menjelaskan urutan dan prioritas membaca tiap sheet Excel hasil GSA  
**Berlaku untuk:** `zoya_asd_gsa_curated_*.mat`, `indira_asd_gsa_curated_*.mat`, dan pasien berikutnya

---

## Daftar Sheet yang Ada

| No. | Nama Sheet | Kategori |
|:---:|---|:---:|
| 1 | Candidate Parameter | Referensi |
| 2 | Target Tier | Referensi |
| 3 | Sobol ST Primary | **Tier 1 — Inti** |
| 4 | Sobol S1 Primary | Tier 3 |
| 5 | Sobol ST Secondary | Tier 3 |
| 6 | ST CI Primary | **Tier 2 — Diagnosa** |
| 7 | Parameter Ranking | **Tier 1 — Inti** |
| 8 | Recommendation Active Set | **Tier 1 — Inti** |
| 9 | Numerical Failures | **Tier 2 — Diagnosa** |
| 10 | Physiology Warning | **Tier 2 — Diagnosa** |
| 11 | ST Heatmap Matrix | **Tier 1 — Inti** |
| 12 | S1 Heatmap Matrix | Tier 3 |
| 13 | Heatmap Interpretation | Tier 4 — Referensi |
| 14 | Notes | Tier 4 — Referensi |

---

## Tier 1 — Wajib Dibaca Pertama (Inti Analisis)

> Empat sheet ini menjawab pertanyaan utama: *"Parameter mana yang harus
> masuk active set kalibrasi?"*

---

### 1. ST Heatmap Matrix ← **Mulai dari sini**

**Tujuan:** Gambaran besar satu pandang.

- Baris = parameter kandidat
- Kolom = output klinis (MAP, PAP_mean, QpQs, LAP, CO, dll.)
- Isi sel = intensitas warna proporsional dengan nilai ST

**Yang dicari:**
- Baris yang konsisten berwarna gelap di banyak kolom → parameter pengaruh luas
- Baris yang hanya gelap di 1 kolom → parameter spesifik untuk output tertentu
- Sel dengan warna maksimum (ST mendekati atau = 1) → perlu diagnosa lebih lanjut (lihat Tier 2)
- Baris yang semua putih/terang → parameter tidak berpengaruh, aman dibuang dari active set

**Pertanyaan yang dijawab sheet ini:**
> *"Apakah ada satu parameter yang mendominasi semua output?"*  
> *"Apakah ada parameter yang sama sekali tidak berpengaruh?"*

---

### 2. Sobol ST Primary

**Tujuan:** Angka pasti dari heatmap untuk output primer klinis.

- Baris = parameter
- Kolom = output primer (yang masuk `target_tiers` tier `hard_primary`)
- Nilai = ST (Total Sobol Index), range [0, 1]

**Interpretasi nilai:**

| Nilai ST | Interpretasi |
|---|---|
| ST < 0.05 | Tidak sensitif — kandidat untuk dibuang dari active set |
| 0.05 ≤ ST < 0.20 | Pengaruh rendah — masuk active set hanya jika tidak ada alternatif |
| 0.20 ≤ ST < 0.50 | Pengaruh sedang — kandidat kuat active set |
| ST ≥ 0.50 | Pengaruh tinggi — prioritas utama active set |
| ST ≈ 1.00 | Dominasi penuh — perlu diagnosa (lihat §Diagnosa ST=1) |

**Sheet ini yang secara langsung digunakan oleh:**
```matlab
build_asd_active_mask_from_gsa(gsa_data, all_params, target_tiers, ...)
```
di file kalibrasi, dengan `ST_THRESHOLD` sebagai batas masuk active set.

---

### 3. Parameter Ranking

**Tujuan:** Sintesis dari ST Primary — parameter diurutkan dari paling berpengaruh.

Biasanya berisi:
- Kolom: Parameter, ST_max (nilai ST tertinggi di antara semua output), Group, Rank
- Sudah diurutkan descending

**Yang dicari:**
- Top-5 parameter → kandidat utama Stage A
- Parameter Group C yang masuk top-5 → kandidat Stage C (jika enabled)
- Parameter dengan ST_max sangat rendah (< 0.02) → aman diabaikan

**Pertanyaan yang dijawab:**
> *"Kalau hanya bisa memilih 5 parameter untuk dikalibrasi, mana yang dipilih?"*

---

### 4. Recommendation Active Set

**Tujuan:** Output actionable — rekomendasi langsung untuk dipakai di kalibrasi.

Berisi daftar parameter yang direkomendasikan masuk active set berdasarkan:
- ST_max ≥ threshold
- Pertimbangan minimum coverage per group
- Flag khusus (forced shunt param, atrial expansion, dll.)

**Cara menggunakan sheet ini:**
Bandingkan isi sheet ini dengan parameter yang benar-benar dipakai di file kalibrasi:

```
Recommendation Active Set    vs    optMask di run_asd_calibration.m
─────────────────────────         ─────────────────────────────────
R.asd          ✓                  R.asd          ✓   → konsisten
R.SAR          ✓                  R.SAR          ✓   → konsisten
V0.LA          ✗ (not listed)     V0.LA          ✓   → FORCE-ADD (atrial expansion)
E.LV.EB        ✓                  E.LV.EB        ✗   → Stage C disabled
```

Ketidakcocokan harus terdokumentasi dengan alasan eksplisit.

---

## Tier 2 — Wajib untuk Diagnosa Kualitas GSA

> Tiga sheet ini menjawab: *"Apakah hasil ST yang saya lihat bisa dipercaya?"*

---

### 5. ST CI Primary ← Krusial untuk kasus ST = 1

**Tujuan:** Confidence interval dari estimasi ST — mengukur reliabilitas angka.

Berisi lower bound dan upper bound untuk tiap nilai ST di Sobol ST Primary.

**Interpretasi:**

```
ST = 1.00, CI = [0.85, 1.00]  →  estimasi stabil → mungkin riil
ST = 1.00, CI = [0.20, 1.00]  →  CI sangat lebar → TIDAK DAPAT DIPERCAYA
ST = 0.30, CI = [0.28, 0.32]  →  estimasi sangat stabil → sangat reliable
ST = 0.30, CI = [0.05, 0.55]  →  CI lebar → perlu N lebih besar
```

**Aturan praktis:**
- Lebar CI < 0.10 → estimasi reliable untuk keputusan kalibrasi
- Lebar CI 0.10–0.20 → gunakan dengan hati-hati, pertimbangkan re-run dengan N lebih besar
- Lebar CI > 0.20 → tidak cukup sampel, N perlu dinaikkan

**Sheet ini wajib dibaca setelah melihat nilai ST yang ekstrem (< 0.02 atau > 0.90).**

---

### 6. Numerical Failures

**Tujuan:** Berapa banyak sampel parameter yang gagal diintegrasikan ODE.

Berisi:
- Jumlah sampel total yang dijalankan
- Jumlah sampel yang gagal (ODE error, non-convergence, NaN output)
- Persentase failure rate
- Distribusi failure berdasarkan region parameter (jika tersedia)

**Interpretasi failure rate:**

| Failure Rate | Interpretasi |
|---|---|
| < 1% | Sangat baik — estimasi ST tidak terdistorsi |
| 1–5% | Acceptable — sedikit bias, masih dapat digunakan |
| 5–15% | Perhatian — ST mungkin bias ke arah tertentu |
| > 15% | Bermasalah — estimasi ST tidak reliable |

**Hubungan dengan ST = 1:**
> Failure rate tinggi di region tertentu (misal nilai R.asd sangat rendah)
> menyebabkan sampel yang survive bias ke region lain. Ini bisa membuat
> ST parameter tertentu tampak tinggi secara artifisial.

**Failure rate 0.69–2.17% yang tercatat di ASD → acceptable, tidak mendistorsi ST secara signifikan.**

---

### 7. Physiology Warning

**Tujuan:** Berapa banyak sampel yang berhasil diintegrasikan ODE tapi menghasilkan nilai yang tidak masuk akal fisiologis.

Contoh warning:
- EF < 0.05 atau EF > 0.95
- Volume negatif
- QpQs < 0.5 atau QpQs > 10
- Tekanan negatif

**Cara membaca:**
- Sampel dengan physiology warning idealnya **dibuang** dari estimasi ST
- Kalau diikutsertakan → ST bias karena sampel dari region yang tidak representatif
- Perhatikan apakah warning terkonsentrasi di range parameter tertentu → sinyal bahwa bounds terlalu lebar

**Pertanyaan yang dijawab:**
> *"Apakah ada region parameter di mana model menghasilkan hasil tidak masuk akal?
> Apakah region itu berkontribusi ke estimasi ST yang ada?"*

---

## Tier 3 — Untuk Analisis Lebih Dalam

---

### 8. Sobol S1 Primary

**Tujuan:** First-order Sobol index — pengaruh parameter secara mandiri (tanpa interaksi).

**Perbandingan S1 vs ST adalah diagnostik paling informatif:**

```
ST ≈ S1  →  parameter bekerja independen, interaksi minimal
            → batas parameter aman diperluas/dipersempit tanpa efek samping

ST >> S1 →  parameter sangat berinteraksi dengan parameter lain
            → harus dikalibrasi bersama (tidak bisa independen)
            → Stage A + C harus berjalan bersamaan untuk kelas ini

ST = 1, S1 = 0.1 → dominasi hampir seluruhnya via interaksi → mencurigakan
ST = 1, S1 = 0.9 → dominasi mandiri → lebih masuk akal secara fisiologis
```

**Untuk setiap parameter di active set:**
> Hitung `(ST - S1) / ST` = rasio interaksi.  
> Rasio > 0.5 → parameter ini berinteraksi kuat → perlu dikalibrasi dalam konteks parameter lain.

---

### 9. S1 Heatmap Matrix

**Tujuan:** Versi heatmap dari S1 — baca setelah ST Heatmap.

**Yang dicari:**
- Sel yang gelap di ST Heatmap tapi terang di S1 Heatmap → interaksi dominan
- Sel yang gelap di keduanya → pengaruh langsung yang kuat
- Sel yang terang di keduanya → parameter tidak relevan untuk output itu

---

### 10. Sobol ST Secondary

**Tujuan:** ST untuk output sekunder (SBP, DBP, PAP_sys, PAP_dia, dll.).

> Output sekunder tidak digunakan sebagai target kalibrasi primer (lihat
> `asd_unified_pipeline_strategy.md` §3.5 tentang kenapa nilai puncak
> waveform tidak cocok sebagai hard target). Namun sheet ini berguna untuk:

- Memverifikasi bahwa parameter yang dipilih tidak secara tidak sengaja
  mendestabilisasi output sekunder
- Memahami mengapa waveform warning muncul setelah kalibrasi

---

## Tier 4 — Referensi / Konteks (Baca Sekali)

### 11. Candidate Parameter
Daftar lengkap parameter yang divariasikan di GSA beserta bounds yang dipakai.  
**Baca untuk:** Verifikasi apakah bounds fisiologis atau terlalu lebar/sempit.  
**Bounds terlalu lebar** → ST parameter itu mungkin overestimated.

### 12. Target Tier
Daftar output yang dijadikan metrik GSA dan klasifikasi tier-nya.  
**Baca untuk:** Memahami mengapa output tertentu ada di ST Primary vs ST Secondary.

### 13. Heatmap Interpretation
Panduan membaca heatmap (skala warna, threshold, simbol).  
**Baca sekali di awal sebelum membuka heatmap manapun.**

### 14. Notes
Catatan kontekstual dari sesi GSA (N yang dipakai, tanggal run, keputusan khusus).  
**Baca terakhir** sebagai audit trail.

---

## Urutan Membaca yang Disarankan

```
LANGKAH 1 — Orientasi (5 menit)
  └── Heatmap Interpretation   →  pahami cara baca skala warna

LANGKAH 2 — Gambaran Besar (10 menit)
  └── ST Heatmap Matrix        →  identifikasi pola dominasi dan nilai ekstrem

LANGKAH 3 — Verifikasi Kualitas (15 menit)
  ├── ST CI Primary            →  apakah nilai ekstrem (ST≈1 atau ST≈0) reliable?
  ├── Numerical Failures        →  failure rate masuk akal?
  └── Physiology Warning        →  ada sampel tidak fisiologis yang mencemari estimasi?

LANGKAH 4 — Analisis Kuantitatif (15 menit)
  ├── Sobol ST Primary         →  baca angka detail
  ├── Parameter Ranking         →  siapa top-5?
  └── Recommendation Active Set →  bandingkan dengan optMask di kalibrasi

LANGKAH 5 — Analisis Interaksi (opsional, 10 menit)
  ├── Sobol S1 Primary         →  hitung rasio interaksi (ST-S1)/ST
  └── S1 Heatmap Matrix        →  visualisasi pola interaksi

LANGKAH 6 — Konteks Waveform (opsional, 10 menit)
  └── Sobol ST Secondary       →  apakah active set mengganggu output sekunder?

LANGKAH 7 — Audit Trail
  ├── Candidate Parameter      →  verifikasi bounds
  ├── Target Tier              →  verifikasi output yang digunakan
  └── Notes                   →  baca catatan kontekstual
```

---

## Diagnostik Khusus: Apa yang Harus Dilakukan Kalau ST = 1?

```
TEMUKAN ST = 1 di ST Heatmap Matrix
│
├── Cek ST CI Primary untuk parameter + output yang sama
│   ├── CI lebar (> 0.30) → artifact numerik → tidak bisa dipercaya
│   │   └── AKSI: Naikkan N dan re-run GSA
│   └── CI sempit (< 0.10) → estimasi stabil → lanjut analisis
│
├── Cek Numerical Failures
│   ├── Failure rate > 5% → bias sampel → ST mungkin distorted
│   └── Failure rate < 2% → bukan penyebab utama
│
├── Cek Physiology Warning
│   ├── Warning rate tinggi → sampel mencemari estimasi
│   └── Warning rate rendah → bukan penyebab
│
├── Bandingkan S1 Primary untuk parameter yang sama
│   ├── S1 ≈ 1 (ST=1, S1=0.9) → dominasi mandiri → mungkin riil
│   │   └── Cek: apakah bounds parameter terlalu lebar?
│   └── S1 << 1 (ST=1, S1=0.1) → dominasi via interaksi → mencurigakan
│       └── AKSI: Cek apakah ada parameter lain yang co-linear
│
└── Cek Candidate Parameter untuk bounds
    ├── Bounds sangat lebar → dominasi artifisial
    │   └── AKSI: Persempit bounds ke range fisiologis, re-run GSA
    └── Bounds sudah realistis → dominasi kemungkinan riil
        └── DOKUMENTASI: Catat parameter mana, output mana, alasan fisiologis
```

---

## Hubungan Sheet Ini dengan File Kalibrasi

| Sheet GSA | Digunakan oleh | Cara penggunaan |
|---|---|---|
| Sobol ST Primary | `build_asd_active_mask_from_gsa` | ST ≥ `ST_THRESHOLD` → masuk optMask |
| Parameter Ranking | `run_asd_calibration.m` | Logging top-parameter di console |
| Recommendation Active Set | Investigator | Verifikasi manual konsistensi optMask |
| Numerical Failures | `run_asd_calibration.m` | Informasi, tidak mengubah mask |
| ST CI Primary | Investigator | Penilaian reliabilitas sebelum kalibrasi |

> **Penting:** `ST_THRESHOLD` (0.05 atau 0.10) **tidak diatur di file GSA**.
> Threshold ini adalah parameter kalibrasi yang diatur di `run_asd_calibration.m`
> (atau `options.st_threshold` di file terpusat yang direncanakan).
> File GSA hanya menyimpan nilai ST mentah — keputusan threshold adalah
> tanggung jawab pipeline kalibrasi.

---

## Referensi Silang Dokumen

- [`asd_unified_pipeline_strategy.md`](asd_unified_pipeline_strategy.md) — Konteks ST_THRESHOLD dalam pipeline terpusat (§3, Q3–Q4)
- [`thesis_defense_and_writing_guide.md`](thesis_defense_and_writing_guide.md) — Justifikasi GSA tidak deteksi atrial params (§2), defense ST rendah untuk V0.LA
- [`vsd_vs_asd_gsa_calibration_methodology.md`](vsd_vs_asd_gsa_calibration_methodology.md) — Perbandingan metodologi GSA VSD (PCE) vs ASD (Sobol manual)
