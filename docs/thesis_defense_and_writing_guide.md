# Thesis Defense & Writing Guide — ASD Calibration Framework

**Date:** 2026-06-05
**Purpose:** Comprehensive reference for framing the thesis methodology, defense
arguments, and writing strategy across all chapters.

---

## 1. Framework Robustness — Staged Calibration

### Kenapa Stage Diperlukan

Stage bukan "buah kegagalan data tidak lengkap." Stage adalah **konsekuensi dari
kompleksitas sistem kardiovaskular.** Ada 3 kelas parameter, masing-masing
di-constrain oleh jenis data berbeda:

| Kelas Parameter | Contoh | Di-constrain Oleh |
|---|---|---|
| Vascular + shunt | R.SAR, R.SC, R.asd | Pressure-flow (MAP, PAP, Qp, Qs, Qp/Qs) |
| Chamber mechanics | E.LV, E.RV, V0.LV, V0.RV | Volume + EF (LVEDV, LVESV, RVEDV, RVEF) |
| Atrial mechanics | E.LA, E.RA, V0.LA, V0.RA | Atrial pressure (LAP, RAP) |

Kalau semua parameter dikalibrasi sekaligus, optimizer bisa "meminjam" dari
kelas yang tidak punya data untuk memperbaiki kelas yang punya data —
menghasilkan solusi numerically good tapi physiologically unverifiable.

**Stage = strategi optimasi, bukan kompensasi data hilang.** Bahkan dengan data
lengkap, landscape 20-dimensi tidak bisa dieksplorasi sekaligus.

### Thesis Text (Metode)

> *"Kalibrasi dilakukan secara bertahap (staged) untuk mengatasi kompleksitas
> ruang parameter: dengan lebih dari 20 parameter yang saling terkait dalam
> sistem kardiovaskular tertutup, optimasi simultan seluruh parameter tidak
> feasible secara komputasi dan berisiko menghasilkan solusi spurious. Setiap
> stage mengkalibrasi subset parameter yang di-constrain oleh jenis data
> klinis yang sesuai — dimulai dari parameter dengan constraint terkuat
> (vaskular dan shunt, Stage A) hingga parameter dengan constraint terlemah
> (ventrikel, Stage C, eksploratif)."*

---

## 2. Atrial Expansion — Defense & Patient-Generic Rule

### Apa Itu Atrial Expansion

Menambahkan **V0.LA, V0.RA, E.LA.EB** ke active set — parameter yang langsung
mengontrol P_LA dan P_RA. Karena:

```
Q_ASD = Cd × A × √(2 × |P_LA − P_RA| / ρ)
                ↑
        Inilah yang tidak bisa dikontrol
        oleh parameter vascular/shunt saja
```

### Kenapa Zoya Perlu, Indira Tidak

| | Zoya | Indira |
|---|---|---|
| LAP target | 14 mmHg | 8 mmHg |
| LAP baseline | 6.9 | 6.9 |
| RAP data | ❌ | ✅ 6 mmHg |
| ΔP data | ❌ | ✅ 2 mmHg |
| Atrial constrained? | ❌ P_RA tidak diketahui | ✅ P_RA=6, P_LA=8 → seimbang |
| Atrial expansion? | ✅ Ya (v4) | ❌ Tidak perlu |

### Kenapa GSA Tidak Mendeteksi Atrial Parameters

GSA mengukur sensitivitas **di sekitar baseline.** Di baseline Zoya:

```
P_LA ≈ 7, P_RA ≈ 7 → ΔP ≈ 0
Ubah V0.LA sedikit → P_LA berubah 6.8 → 7.2
ΔP tetap ≈ 0 → Q_ASD tidak berubah → Qp/Qs tidak berubah
GSA: "V0.LA tidak sensitif" → ST rendah ✓ (benar, di titik INI)
```

Tapi model **perlu mencapai** LAP = 14. Di operating point itu, V0.LA akan
SANGAT sensitif — tapi GSA tidak memprediksinya karena sampling di baseline.

### Defense: Tidak Mengikuti GSA — Justru Kekuatan

> *"Parameter atrium (V0.LA, V0.RA, E.LA.EB) ditambahkan ke dalam set
> kalibrasi berdasarkan justifikasi fisiologis, bukan berdasarkan hasil
> GSA. Hal ini mencerminkan keterbatasan yang telah terdokumentasi dari
> analisis sensitivitas berbasis varians: GSA mengukur sensitivitas lokal
> di sekitar titik sampling (baseline), dan tidak dapat memprediksi
> perubahan sensitivitas pada operating point yang jauh dari baseline.
> Pada baseline Zoya, selisih tekanan atrium (ΔP_LA-RA) mendekati nol,
> sehingga parameter atrium tampak tidak sensitif. Namun, target klinis
> memerlukan LAP = 14 mmHg — suatu operating point di mana parameter
> atrium diprediksi menjadi sangat berpengaruh berdasarkan hukum orifice
> Gorlin (Q ∝ √ΔP). Ekspansi ini dilakukan secara eksplisit, dengan
> label 'exploratory', dan didokumentasikan sebagai keputusan yang
> diinformasikan oleh fisiologi — bukan oleh GSA. Transparansi ini
> justru memperkuat kredibilitas metodologis: framework tidak
> memperlakukan GSA sebagai otoritas absolut, melainkan sebagai alat
> bantu yang hasilnya diinterpretasikan dalam konteks fisiologis."*

### Rule Generik, Bukan Hardcode Zoya

```
Rule: "Jika Stage A gagal menaikkan LAP, cek apakah atrial parameters
       ada di active set. Jika tidak, pertimbangkan atrial expansion."

Zoya:   LAP stuck + RAP missing → EXPAND ✓
Indira: LAP solved + RAP available → SKIP ✓
```

Rule yang sama, dua keputusan berbeda berdasarkan data — bukan nama pasien.

---

## 3. Menguji Framework — Bukan Membangun Model

### Beda Narasi

| Narasi "Membangun Model" (Salah) | Narasi "Menguji Framework" (Benar) |
|---|---|
| "Saya mengadaptasi metode VSD untuk ASD" | "Saya menguji apakah framework GSA-driven calibration bisa diterapkan ke ASD dengan data klinis terbatas" |
| "Saya menjalankan GSA → kalibrasi → dapat model" | "Saya mengidentifikasi adaptasi apa yang diperlukan, batasan apa yang muncul, dan kenapa" |
| Hasil = model | Hasil = framework + documented adaptations + identified limitations |

### Posisi di Bab Skripsi

**Bab 1 (Pendahuluan):**
> *"Penelitian ini bertujuan mengembangkan dan memvalidasi framework
> kalibrasi berbasis Global Sensitivity Analysis untuk model lumped-
> parameter kardiovaskular pada atrial septal defect pediatrik —
> serta mengidentifikasi batasan metodologis ketika data klinis
> bersifat sparse."*

**Bab 3 (Metode):** Adaptasi framework (mode-aware shunt, target tier, atrial
expansion, clinical fit gate, staged calibration).

**Bab 4 (Hasil):** Output kalibrasi + batasan yang ditemukan (GSA tidak detek
atrial params, LAP bottleneck, data sparse, rollback events).

**Bab 5 (Kesimpulan & Saran):** Framework validated, documented limitations,
future work untuk generalisasi.

---

## 4. Stage A-F — Yang Belum Di-Solve

### Yang Sudah Ditangani

| Kategori | Mekanisme |
|---|---|
| Parameter sensitif | GSA → ST ranking → active mask |
| Mode shunt berbeda | Mode-aware detection (orifice vs linear) |
| Data sparse | Target tiers auto-adapt |
| Solusi spurious | Guards (MAP, RAP, ratio, shunt) + 11 validity gates |
| Waveform degradation | Soft warning classification |
| Starting point buruk | Staged calibration (A dulu, C conditional) |

### Yang Belum Ditangani (Dokumentasi di Bab 5)

| Skenario | Kenapa Belum | Prioritas |
|---|---|---|
| Pasien dengan 3+ mode shunt berbeda (ΔP mendukung linear, diameter besar mendukung orifice, Q_shunt tidak konsisten) | Butuh mode selection logic yang lebih canggih | Rendah — belum muncul di data |
| Model structural limitation (atrial septal aneurysm, ventricular interdependence, respiratory variation) | 14-state tidak punya mekanisme untuk fenomena ini | Fundamental — di luar scope S1 |
| ODE instability di region parameter ekstrem | 0.69-2.17% failure rate — acceptable. Bounds + warmup sudah mengurangi | Rendah |
| Data klinis kontradiktif | Diselesaikan dengan definisi operasional pengambilan data | Tidak relevan |

### Kenapa Ini Bukan "Kekurangan"

Framework dirancang untuk bisa **di-extend.** Setiap batasan yang teridentifikasi
menjadi input untuk pengembangan berikutnya — bukan "bug" yang harus diperbaiki.
Di Bab 5:

> *"Framework ini mencakup mekanisme penanganan untuk failure modes yang
> teridentifikasi dari pengalaman dua pasien ASD. Seperti semua scientific
> software, framework dirancang untuk dapat diperluas — bukan untuk
> mengklaim cakupan sempurna. Setiap keputusan (threshold, klasifikasi
> tier, stage policy) bersifat eksplisit dan terdokumentasi, sehingga
> researcher berikutnya dapat memahami, memodifikasi, atau menambah
> stage baru tanpa membongkar arsitektur inti."*

---

## 5. Stage = Strategi Optimasi, Bukan Kompensasi Data

### Kenapa Landscape 20-Dimensi Tidak Bisa Dieksplorasi Sekaligus

Bahkan dengan data lengkap, kalibrasi semua parameter sekaligus tetap bermasalah:

```
20 parameter × gradient-based search:
  → Curse of dimensionality: volume ruang pencarian eksponensial
  → Local minima: semakin banyak dimensi, semakin banyak lembah palsu
  → Coupling: parameter saling terkait → gradient tidak informatif
```

**Stage = memecah masalah besar menjadi masalah kecil yang bisa diselesaikan.**
Ini strategi optimasi fundamental, bukan "karena data kurang."

### Thesis Text

> *"Pendekatan staged calibration didasarkan pada prinsip bahwa tidak
> semua parameter dalam model lumped-parameter kardiovaskular dapat
> di-constrain secara setara oleh data klinis yang tersedia —
> maupun dioptimasi secara simultan mengingat dimensi ruang parameter
> yang tinggi dan kopling antar parameter yang kuat."*

---

## 6. Paradoks Gold Standard

### Kondisi Saat Ini (Fase 1)

Model membutuhkan data kateterisasi (invasive) untuk dilatih dan divalidasi.

### Visi Jangka Panjang

Dengan cukup data (50+ pasien), model belajar hubungan antara data non-invasif
(echo, ECG, BSA) dan output hemodinamik — sehingga bisa memprediksi tanpa
kateterisasi.

### Thesis Text

**Bab 1 (Pendahuluan):**
> *"Dalam jangka panjang, model lumped-parameter yang tervalidasi berpotensi
> mengurangi ketergantungan pada prosedur kateterisasi diagnostik — khususnya
> untuk pasien ASD di mana keputusan klinis dapat diinformasikan oleh prediksi
> hemodinamik non-invasif. Namun, pengembangan model tersebut memerlukan
> data kateterisasi sebagai gold standard untuk validasi."*

**Bab 5 (Kesimpulan):**
> *"Ketergantungan model pada data kateterisasi untuk seeding dan kalibrasi
> merupakan batasan yang inheren pada tahap pengembangan ini. Seperti seluruh
> model komputasional dalam kedokteran, validasi terhadap gold standard
> (kateterisasi) adalah prasyarat sebelum model dapat digunakan secara
> independen. Hasil dari dua pasien menunjukkan bahwa kualitas seeding —
> yang bergantung pada kelengkapan data kateterisasi — adalah determinan
> utama akurasi model. Temuan ini memberikan rekomendasi konkret untuk
> pengambilan data klinis di masa depan."*

---

## 7. Refinement vs Missing Parameter Class

| | Refinement (Stage D/E/F) | Missing Parameter Class (Atrial Expansion) |
|---|---|---|
| **Masalah** | Solusi sudah ada, tapi belum optimal | **Tidak ada** parameter yang mengontrol aspek fisiologis tertentu |
| **Yang dilakukan** | Iterasi tambahan pada parameter yang SAMA | **Menambah** parameter baru ke active set |
| **Analoginya** | Masakan sudah enak, tinggal tambah garam sedikit | Masakan tidak ada garamnya sama sekali |

Contoh konkret:

```
Zoya — Missing Parameter Class:
  Stage A selesai → LAP stuck di 7 (target 14)
  Tidak ada parameter di active set yang mengontrol P_LA
  → Harus TAMBAH parameter atrium (atrial expansion)
  → Stage D/E/F tidak akan membantu karena masalahnya bukan refinement

Indira — Refinement (tapi tidak diperlukan):
  Stage C selesai → semua primary target < 10%
  Parameter sudah cukup, solusi sudah excellent
  → Stage D: mungkin naikkan MAP 69→72 (tapi bisa rusak Qp/Qs)
  → Stage E: mungkin dorong E.RV.EB menjauh dari bound (tapi bisa rusak PAP)
  → Risk merusak solusi > potential gain
  → TIDAK dijalankan karena cost > benefit
```

---

## 8. Apakah Ini Terlalu Customized? (Tidak — Ini Generic)

Yang kamu lakukan = menguji rule pada 2 pasien dengan profil berbeda:

| Rule | Zoya | Indira |
|---|---|---|
| "Kalau RAP + ΔP tersedia → seeding akurat → GSA active set cukup" | FALSE → perlu atrial expansion | TRUE → tidak perlu |
| "Kalau LAP stuck → cek atrial parameters" | TRUE → expand | FALSE → skip |
| "Kalau waveform membrurk → soft warning, bukan reject" | Tidak terpicu | TRUE → Stage C accepted |

**Yang generik = diagnostic rule. Yang berbeda = data pasien.** Framework tidak
peduli nama pasien — framework merespons profil data klinis.

### Framing di Skripsi

> *"Kedua pasien ASD pre-closure dalam penelitian ini — Zoya dan Indira —
> mewakili dua profil data klinis yang berbeda: sparse (Zoya) dan lebih
> lengkap (Indira). Penerapan framework yang identik pada kedua pasien
> menghasilkan keputusan kalibrasi yang berbeda — ekspansi atrial pada
> Zoya, tanpa ekspansi pada Indira — yang seluruhnya didasarkan pada
> kriteria objektif berbasis data, bukan pada identitas pasien. Ini
> mendemonstrasikan bahwa framework bersifat patient-generic: responsnya
> terhadap profil data klinis — bukan terhadap pasien tertentu."*

---

## 9. Kenapa Stage D/E/F Tidak Dijalankan di Indira

### Jawaban: Stage C Sudah Konvergen

fmincon Exit=2 (StepTolerance): **tidak ada arah yang menurunkan objective
secara bermakna.** Landscape sudah datar. Stage D/E/F menggunakan parameter yang
SAMA dengan Stage C — hanya dengan objective yang sedikit berbeda.

```
Stage C: J = J_primary + λ×J_secondary + guards + plausibility
Stage D: J = J_primary + 2λ×J_secondary + MAP_penalty + ...
Stage E: J = J + boundary_push_penalty
Stage F: J = J + validation_gate_penalty

Kalau landscape sudah datar di Stage C:
  → Iterasi Stage D: "tidak ada downhill direction" → hasil sama
  → Iterasi Stage E: "tidak ada downhill direction" → hasil sama
  → Iterasi Stage F: "tidak ada downhill direction" → hasil sama
```

**Kalau mau bukti:** Run Stage D pada Indira dan laporkan hasilnya sebagai
konfirmasi. "Stage D tidak mengubah RMSE secara signifikan (0.042 → 0.041),
mengkonfirmasi bahwa Stage C sudah optimal."

### Pasien Berikutnya dengan Profil Mirip Indira

**Ya, akan mengikuti alur yang sama:**
- Data lengkap → seeding akurat → baseline bagus
- GSA active set kecil
- Stage A → mungkin sudah cukup, atau Stage C → accepted
- Stage D/E/F → hanya kalau ada masalah spesifik (MAP degradation, parameter bound)

**Yang berubah = nilai target. Tapi rule-nya sama.** Rule tidak peduli target-nya
75 atau 90 — yang penting pola kegagalannya.

---

## 10. Syarat Stage Transition — Reference dari VSD

Dari `run_calibration.m` VSD:

```
Stage A: SELALU jalan (vascular + shunt)
  → Kalibrasi parameter dengan constraint terkuat

Stage B: JALAN kalau objective function TURUN dari Stage A
  → "Apakah chamber parameters memperbaiki fit?"
  → Di ASD: SKIP — tidak ada data volume/EF

Stage C: JALAN kalau ada parameter dengan ST tinggi di GSA
  → Top-5 by GSA score yang belum dikalibrasi
  → Di ASD: JALAN kalau Group C enabled + Stage A RMSE ≥ 0.10

Stage D (systemic polish):
  → JALAN kalau caseProfile mengaktifkannya
  → Default VSD: pre_surgery = ON, post_surgery = OFF

Stage E (plausibility):
  → JALAN kalau Stage A-C menghasilkan WARNING pada parameter
  → "Apakah parameter di bound bisa didorong menjauh?"

Stage F (validation):
  → JALAN kalau caseProfile mengaktifkannya
  → Default VSD: OFF
```

**Semua stage SELALU dicek, tapi hanya dijalankan kalau syarat terpenuhi.**
Bukan "harus A→B→C→D→E→F." Tapi "cek satu per satu, jalankan yang relevan."

### Framing di Skripsi

> *"Transisi antar stage kalibrasi ditentukan oleh kriteria objektif — bukan
> urutan tetap. Stage A selalu dijalankan sebagai kalibrasi primer. Stage C
> dijalankan secara kondisional bila Stage A gagal mencapai RMSE target.
> Stage D, E, dan F bersifat opsional dan hanya diaktifkan bila pola
> kegagalan spesifik terdeteksi: degradasi tekanan sistemik (D), parameter
> di batas bound (E), atau kegagalan gate validasi (F). Pendekatan berbasis
> kriteria ini — bukan urutan kaku — memungkinkan pipeline beradaptasi
> terhadap profil data klinis yang berbeda antar pasien."*

---

## 11. Kenapa VSD Butuh DEF — Domino Effect dari Stage B

### DEF Bukan Fitur "Jaga-Jaga" — DEF Adalah Solusi untuk Masalah Nyata

Di VSD, Stage B (chamber calibration) mengubah parameter ventrikel (E.LV, E.RV,
V0.LV, V0.RV). Ini memicu reaksi berantai yang memerlukan stage tambahan:

```
Stage A: vascular calibration → OK ✅
    │
Stage B: chamber calibration (E.LV, E.RV, V0) ← PEMICU
    │
    │  Mengubah E.LV → LV pumping berubah
    │  → MAP dan CO sekarang meleset dari target
    │  → Systemic pressure RUSAK setelah Stage B
    │
    ▼
Stage D: systemic polish ← MEMPERBAIKI kerusakan dari Stage B
    │  "Adjust R.SAR, R.SC supaya MAP balik ke target
    │   tanpa merusak fit chamber yang sudah dicapai."
    │
    │  Setelah 3 stage (A+B+D) → banyak parameter bergerak
    │  → beberapa parameter nyangkut di bound
    │
    ▼
Stage E: plausibility polish ← MENDORONG parameter dari bound
    │
    │  Setelah semua stage → mungkin ada 1 gate FAIL
    │  (misal SVR terlalu tinggi karena R.SC akumulasi perubahan)
    │
    ▼
Stage F: validation polish ← FINAL CHECK sebelum accepted
```

### Analogi Mekanik

```
Stage B = ganti mesin mobil.
  → Mesin baru bikin mobil lebih bertenaga.
  → Tapi sekarang rem blong (MAP rusak karena E.LV berubah).
  → Stage D: setel ulang rem (adjust R.SAR, R.SC).
  → Setelah rem disetel, spion agak miring (parameter di bound).
  → Stage E: betulin spion (dorong parameter dari bound).
  → Terakhir, cek semua: ada lampu sein mati (1 gate FAIL).
  → Stage F: ganti bohlam (final validation).

ASD: Tidak ganti mesin (tidak ada Stage B).
  → Rem, spion, lampu — semua masih OK dari awal.
  → Tidak perlu D/E/F.
```

### Kenapa ASD Tidak Mengalami Masalah Ini

| VSD | ASD |
|---|---|
| Stage B mengubah E.LV, V0.LV → systemic berubah | **Tidak ada Stage B** → systemic tidak terganggu |
| 3+ stage → akumulasi parameter drift → bound warnings | Hanya 2 stage → pergerakan parameter minimal |
| 17 parameter → kemungkinan gate failure lebih tinggi | 5-7 parameter → lebih sedikit interaksi tak terduga |

**DEF bukan fitur yang "dihilangkan" dari ASD. DEF adalah solusi untuk masalah
yang TIDAK TERJADI di ASD karena Stage B tidak dijalankan.** Begitu suatu hari
ASD memiliki pasien dengan data volume dan Stage B diimplementasikan, DEF akan
otomatis menjadi relevan.

---

## 12. Framework Stage A+C — Justifikasi Fisiologis Mandiri

### Kenapa Bisa Berdiri Sendiri Tanpa Referensi ke VSD

Framework ini tidak perlu menyebut VSD untuk menjelaskan strukturnya. Cukup
dijelaskan dari prinsip fisiologis: **kalibrasi dimulai dari parameter yang
paling kuat di-constrain oleh data klinis, lalu berlanjut ke parameter dengan
constraint lebih lemah — hanya jika diperlukan.**

### Thesis Text (Metode — Mandiri, Tanpa VSD)

> *"Kalibrasi dilakukan dalam dua stage berdasarkan kekuatan constraint data
> klinis terhadap masing-masing kelas parameter:
>
> **Stage A — Parameter dengan constraint kuat.** Parameter vaskular,
> shunt, dan preload (Group A dan B non-ventrikel) secara langsung
> mempengaruhi tekanan dan aliran yang terukur secara klinis: MAP, PAP,
> Qp, Qs, Qp/Qs, LAP, dan RAP. Setiap perubahan pada parameter ini
> menghasilkan perubahan yang terdeteksi pada metric dengan data klinis —
> sehingga hasil kalibrasi Stage A dapat divalidasi terhadap data yang
> tersedia.
>
> **Stage C (kondisional) — Parameter dengan constraint lemah.** Parameter
> ventrikel (E.LV.EB, E.RV.EB — Group C) mempengaruhi tekanan dan aliran
> melalui kopling tidak langsung dalam sistem kardiovaskular tertutup.
> Tanpa data volume ventrikel (LVEDV, LVESV, RVEDV, RVESV) dan fraksi
> ejeksi (LVEF, RVEF), perubahan pada parameter ini tidak dapat divalidasi
> secara independen terhadap pengukuran klinis. Oleh karena itu, Stage C
> hanya dijalankan bila Stage A gagal mencapai RMSE target (< 0.10) —
> dan hasilnya dilaporkan secara eksplisit sebagai eksploratif, dengan
> catatan bahwa parameter ventrikel tidak dapat divalidasi tanpa data
> volume.
>
> Parameter atrium (Group B: E.LA.EB, V0.LA, V0.RA) diperlakukan secara
> adaptif: pada pasien dengan data RAP dan ΔP yang lengkap, tekanan
> atrium cukup di-constrain oleh data klinis sehingga parameter ini
> tidak memerlukan kalibrasi terpisah. Pada pasien tanpa data tersebut,
> ekspansi parameter atrium dipertimbangkan berdasarkan justifikasi
> fisiologis — Q_ASD ∝ √(P_LA − P_RA) — sebagai perluasan Stage A,
> bukan sebagai stage baru."

### Kenapa Ini Lebih Kuat

| Menyebut VSD | Berdiri Sendiri |
|---|---|
| "Saya adaptasi 6-stage VSD, hilangkan B, DEF opsional..." | "Framework ini punya 2 stage berdasarkan constraint strength data klinis" |
| Penguji tanya: "Kenapa VSD punya 6?" | Tidak perlu dijawab — justifikasi internal |
| Terkesan "mengurangi" | Terkesan "merancang tepat guna" |
| 3 halaman penjelasan | 1 halaman penjelasan |
