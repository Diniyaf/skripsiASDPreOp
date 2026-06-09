## 4.2 Karakteristik Data Klinis

Keberhasilan framework kalibrasi berbasis GSA sangat bergantung pada ketersediaan
dan kualitas data klinis yang digunakan sebagai target optimasi. Subbab ini
memaparkan profil demografi ketiga pasien (4.2.1), klasifikasi metrik hemodinamik
ke dalam tier target berdasarkan ketersediaan data (4.2.2), serta analisis
dampak ketidaklengkapan data terhadap kemampuan identifikasi parameter (4.2.3).

---

## 4.2.1 Profil Demografi Pasien

Penelitian ini menggunakan data tiga pasien anak dengan diagnosis atrial septal
defek (ASD) sekundum yang menjalani kateterisasi jantung kanan di Rumah Sakit
Anak dan Bunda (RSAB) Harapan Kita. Ketiga pasien memiliki karakteristik klinis
yang berbeda — mencakup variasi usia, berat badan, dan kelengkapan data
hemodinamik — sehingga memungkinkan evaluasi framework kalibrasi pada spektrum
kondisi klinis yang beragam.

**Tabel 4.1 Profil Demografi dan Klinis Pasien**

| Parameter | Zoya | Indira | Aluna |
|---|---|---|---|
| Usia (tahun) | 7.07 | 15.83 | 1.42 |
| Jenis kelamin | Perempuan | Perempuan | Perempuan |
| Berat badan (kg) | 18.2 | 47.5 | 8.9 |
| Tinggi badan (cm) | 119 | 153 | 76 |
| BSA (m²) | 0.788 | 1.420 | 0.420 |
| Heart rate (bpm) | 90 | 73 | 132 |
| Diameter ASD (mm) | 19.25 | 22.30 | 17.55 |
| Lokasi ASD | Secundum moderate-large | Secundum large | Secundum large |
| Mode shunt | Orifice | Linear | Orifice |
| ΔP LA-RA (mmHg) | Tidak tersedia | 2.00 | Tidak tersedia |
| SVR (WU) | Tidak tersedia | 21.43* | Tidak tersedia |
| PVR (WU) | Tidak tersedia | 2.25* | Tidak tersedia |
| Riwayat operasi | Tidak | Tidak (rim tipis) | Tidak |

*\*Nilai derived — dihitung dari data kateterisasi yang tersedia.*

Ketiga pasien memiliki ASD sekundum berukuran besar (17.6–22.3 mm) tanpa riwayat
operasi penutupan. Perbedaan utama antar pasien terletak pada kelengkapan data
hemodinamik — dari yang paling lengkap (Indira: ΔP, RAP, SVR, PVR tersedia)
hingga paling terbatas (Aluna: hanya tekanan sistemik dan pulmonal) — yang
memungkinkan analisis pengaruh ketersediaan data terhadap kualitas kalibrasi.

---

## 4.2.2 Penentuan Target Hemodinamik

Tidak seluruh metrik hemodinamik yang diukur secara klinis dapat dijadikan
target kalibrasi. Pemilihan target dilakukan melalui sistem klasifikasi
bertingkat (target-tier governance) yang mengelompokkan setiap metrik ke
dalam tiga kategori: **hard primary** (target kalibrasi utama — data tersedia
dan reliabel), **soft secondary** (guard/pengawas — data tersedia namun
memiliki ketidakpastian pengukuran lebih tinggi), dan **prediction-only**
(prediksi model — data klinis tidak tersedia).

**Tabel 4.2 Klasifikasi Target Hemodinamik per Pasien**

| Metrik | Zoya | Indira | Aluna |
|---|---|---|---|---|
| Qp/Qs | **Primary** (3.79) | **Primary** (2.34) | ❌ Tidak tersedia |
| Qp (L/min) | **Primary** (12.27) | **Primary** (7.54) | ❌ Tidak tersedia |
| Qs (L/min) | **Primary** (3.23) | **Primary** (3.22) | ❌ Tidak tersedia |
| MAP (mmHg) | **Primary** (90) | **Primary** (75) | **Primary** (104) |
| PAP_mean (mmHg) | **Primary** (23) | **Primary** (25) | **Primary** (15.5) |
| LAP_mean (mmHg) | **Primary** (14) | **Primary** (8) | ❌ Tidak tersedia |
| RAP_mean (mmHg) | ❌ Tidak tersedia | **Primary** (6) | ❌ Tidak tersedia |
| SBP/DBP (mmHg) | Secondary guard | Secondary guard | Secondary guard |
| PAP_sys/dia (mmHg) | Secondary guard | Secondary guard | Secondary guard |
| ΔP LA-RA (mmHg) | ❌ Tidak tersedia | Derived guard | ❌ Tidak tersedia |
| Q_ASD (L/min) | Derived comparison | Derived comparison | ❌ Tidak tersedia |
| LVEDV/LVESV/RVEDV/RVESV | ❌ Prediction-only | ❌ Prediction-only | ❌ Prediction-only |
| LVEF/RVEF | ❌ Prediction-only | ❌ Prediction-only | ❌ Prediction-only |
| SVR/PVR | ❌ Prediction-only | ❌ Prediction-only | ❌ Prediction-only |

**Zoya** memiliki 6 target primer (Qp/Qs, Qp, Qs, MAP, PAP, LAP) — profil
pressure-flow tanpa data atrial kanan dan resistensi vaskular. **Indira**
memiliki 7 target primer (tambahan RAP) serta data ΔP, SVR, dan PVR yang
memungkinkan seeding parameter shunt secara langsung — profil paling lengkap.
**Aluna** hanya memiliki 2 target primer (MAP, PAP) — profil paling terbatas
yang hanya memungkinkan kalibrasi tekanan tanpa validasi shunt.

Klasifikasi ini bersifat adaptif: setiap metrik diperiksa terhadap ketersediaan
data klinis pada masing-masing pasien, dan tier ditentukan secara otomatis oleh
`build_asd_target_tiers()`. Metrik yang tidak tersedia tetap dihitung oleh
model sebagai prediksi dan dilaporkan dalam output — namun tidak mempengaruhi
arah optimasi maupun keputusan penerimaan kandidat kalibrasi.

---

## 4.2.3 Analisis Keterbatasan Data

Ketiga pasien dalam penelitian ini tidak memiliki data ekokardiografi
pre-closure — khususnya volume ventrikel (LVEDV, LVESV, RVEDV, RVESV) dan
fraksi ejeksi (LVEF, RVEF). Ketiadaan data ini bersifat sistemik pada
populasi ASD yang menjalani kateterisasi diagnostik tanpa ekokardiografi
simultan, dan berdampak langsung pada kemampuan framework mengidentifikasi
parameter ventrikel secara independen.

**Tabel 4.3 Data yang Tidak Tersedia dan Dampaknya terhadap Kalibrasi**

| Data yang Tidak Tersedia | Zoya | Indira | Aluna | Dampak terhadap Kalibrasi |
|---|---|---|---|---|
| ΔP LA-RA | ❌ | ✅ | ❌ | **Zoya & Aluna:** Parameter shunt (Cd) tidak dapat di-seed dari data → harus dikalibrasi penuh. **Indira:** R_ASD dapat dihitung langsung (0.46 mmHg·s/mL) |
| RAP | ❌ | ✅ | ❌ | **Zoya & Aluna:** Tekanan atrium kanan tidak ter-constrain → keseimbangan tekanan atrium tidak dapat divalidasi |
| SVR / PVR | ❌ | ✅* | ❌ | Resistensi vaskular tetap pada nilai scaled → seeding kurang akurat |
| Qp, Qs, Qp/Qs | ✅ | ✅ | ❌ | **Aluna:** Tidak dapat menargetkan severity shunt → kalibrasi terbatas pada tekanan saja |
| LVEDV/LVESV/RVEDV/RVESV | ❌ | ❌ | ❌ | Parameter ventrikel (Group C) tidak dapat divalidasi → tetap monitor-only |
| LVEF/RVEF | ❌ | ❌ | ❌ | Sama seperti di atas — tidak ada anchor untuk fungsi ventrikel |

*\*Nilai derived, bukan measured langsung.*

Kombinasi ketidaksediaan data ini menghasilkan **tiga tingkat kelengkapan**
yang berbeda: Indira (paling lengkap — 7 target primer, seeding shunt
langsung), Zoya (moderat — 6 target, tanpa RAP dan ΔP), dan Aluna (paling
terbatas — hanya 2 target primer). Gradasi ini memungkinkan analisis
sistematis tentang pengaruh kelengkapan data klinis terhadap kualitas
kalibrasi — dari RMSE 0.042 (Indira) hingga 0.287 (Aluna).
