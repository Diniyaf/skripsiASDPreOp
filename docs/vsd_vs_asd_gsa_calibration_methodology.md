# Perbandingan Metodologi GSA dan Kalibrasi: Unified VSD vs Adaptasi ASD

**Tanggal:** 2026-06-05  
**Scope:** penjelasan metodologi untuk membedakan pipeline Hafiz/Keisya unified VSD dan pipeline ASD pre-closure yang sekarang dipakai untuk Zoya/Indira.  
**Tujuan dokumen:** membantu menjelaskan di skripsi dan saat sidang kenapa ASD mengikuti struktur ilmiah VSD, tetapi tidak menyalin semua stage VSD secara mentah.

---

## 1. Jawaban Singkat

Pipeline ASD yang sekarang dibuat **sudah mengikuti prinsip utama unified VSD**:

```text
baseline/scaling
-> clinical seeding
-> GSA sebelum kalibrasi
-> active mask dari Sobol ST
-> staged calibration
-> validity/plausibility/rollback
-> export best/accepted candidate
```

Namun ASD **tidak fully identical** dengan VSD karena:

1. VSD memakai **PCE-based GSA** melalui UQLab/SoBioS pattern, sedangkan ASD sekarang memakai **direct Saltelli/Sobol ODE GSA**.
2. VSD sudah punya satu orchestrator besar `main_run.m`, sedangkan ASD sekarang memakai kombinasi `run_asd_patient_case.m` plus wrapper GSA/kalibrasi per pasien.
3. VSD punya stage kalibrasi lebih lengkap: Stage A, B, C, D, E, F. ASD saat ini memakai Stage A dan Stage C dengan post-calibration gate/rollback.
4. Target VSD dan ASD tidak sama secara fisiologi. VSD adalah shunt ventrikel, ASD adalah shunt atrium; parameter shunt, pressure gradient, dan identifiability berbeda.
5. Data pasien ASD yang tersedia tidak selalu sepadat VSD. Zoya dan Indira punya target pressure-flow, tetapi tidak punya semua target volume/EF pre-closure. Jadi tidak semua stage VSD bisa dijalankan dengan aman tanpa overfitting.

Kesimpulan metodologis:

> ASD pipeline sekarang bukan copy penuh VSD, tetapi merupakan adaptasi yang benar: struktur GSA-first dan mask-based calibration dipertahankan, sementara target tier, parameter group, shunt mechanism, dan rollback disesuaikan dengan fisiologi ASD serta data pasien yang tersedia.

---

## 2. Apa yang Dilakukan Unified VSD

### 2.1 Workflow Utama VSD

Di `C:/Users/Diniya/unified-vsd-temp/main_run.m`, komentar workflow menyebut langkah:

```text
1. Apply allometric scaling
2. Map clinical SVR/PVR/HR with params_from_clinical
3. Baseline simulation
4. Initial GSA with PCE surrogate
5. Build optimisation mask
6. Masked calibration
7. Final GSA with PCE after calibration
8. Validation report
9. Plots
10. Save artefacts
```

Artinya VSD tidak langsung melakukan optimasi semua parameter. Ia melakukan:

1. Membangun parameter baseline pasien.
2. Menjalankan GSA untuk melihat parameter mana yang mempengaruhi output klinis.
3. Membuat mask parameter aktif dari Sobol total-order index.
4. Mengkalibrasi hanya parameter yang masuk mask.
5. Melakukan final GSA setelah kalibrasi untuk melihat perubahan dominansi parameter.
6. Menyimpan best candidate dan accepted candidate secara terpisah.

### 2.2 GSA VSD

VSD memakai file:

```text
C:/Users/Diniya/unified-vsd-temp/src/gsa/gsa_pce_setup.m
C:/Users/Diniya/unified-vsd-temp/src/gsa/gsa_run_pce.m
```

Intinya:

1. Candidate parameter didefinisikan dari parameter registry VSD.
2. Parameter diberi distribusi uniform pada lower-upper bound.
3. Model ODE dievaluasi pada training sample.
4. PCE surrogate dibangun dengan UQLab.
5. Sobol indices dihitung dari surrogate.

Dalam `gsa_pce_setup.m`, parameter VSD mencakup resistances, compliances, ventricular elastances, atrial elastances, unstressed volumes, dan shunt parameter:

```text
R.SAR, R.SC, R.SVEN, R.PAR, R.PCOX, R.PVEN
C.SAR, C.SVEN, C.PAR, C.PVEN
E.LV.EA, E.LV.EB, E.RV.EA, E.RV.EB
E.LA.EA, E.RA.EA
V0.LV, V0.RV, V0.LA, V0.RA
R.vsd or vsd.Cd
```

Untuk `pre_surgery`, VSD primary metrics pada `gsa_pce_setup.m` adalah:

```text
QpQs, PAP_mean, PVR, SAP_mean, CO_Lmin
```

Secondary metrics mencakup RAP, LV/RV volumes, pressure extrema, SVR, EF, dan lain-lain. Kemudian `main_run.m` memakai gabungan primary plus secondary untuk membangun mask, tetapi tetap dibatasi oleh `case_profile`.

### 2.3 Active Mask VSD

Di `main_run.m`, Step 5 membangun `optMask` dari Sobol ST:

```text
ST_calib -> create_optimization_mask -> optMask
```

File:

```text
C:/Users/Diniya/unified-vsd-temp/src/utils/create_optimization_mask.m
```

Logikanya:

1. `ST` adalah Sobol total-order index.
2. Threshold default adalah `ST >= 0.10`.
3. Jika multi-output, dipakai agregasi konservatif:

```text
ST_agg(i) = max_j ST(i,j)
```

4. Parameter dengan ST di atas threshold dijadikan active parameter.
5. `caseProfile.allowedFreeParameters` dapat membatasi parameter agar sesuai bukti klinis.

Makna ilmiahnya:

> GSA dipakai untuk mengurangi ruang parameter sebelum optimasi. Ini mencegah optimasi terlalu banyak parameter yang tidak identifiable dari data klinis.

### 2.4 Kalibrasi VSD

VSD memakai:

```text
C:/Users/Diniya/unified-vsd-temp/src/calibration/run_calibration.m
C:/Users/Diniya/unified-vsd-temp/src/calibration/objective_calibration.m
```

`run_calibration.m` menyebut staged pediatric calibration:

```text
Stage A - vascular/shunt fit
Stage B - chamber volume/function fit
Stage C - joint polish on <=5 sensitive parameters
Stage D - optional systemic-output polish
Stage E - optional plausibility polish
Stage F - optional validation-gate polish
```

Optimasi memakai `fmincon`, dengan active parameter yang berasal dari mask. Jadi VSD tidak mengoptimasi semua parameter secara bebas.

Objective VSD di `objective_calibration.m` berbentuk:

```text
J = J_primary
  + lambda_secondary * J_secondary
  + J_systemic
  + J_pressure
  + J_shunt
  + J_clinical_guard
  + J_reg
  + J_param_plausibility
  + J_boundary
  + J_validity
```

Yang penting: VSD juga **tidak memperlakukan semua angka klinis sebagai target independen yang sama bobotnya**. Ada fungsi seperti:

```text
build_systemic_bundle
build_pressure_waveform_bundle
build_shunt_fraction_bundle
is_validation_only_metric
is_consistency_only_metric
```

Contoh: MAP, RAP, CO/Qs, dan SVR dapat menjadi satu bundle sistemik agar tidak double-counting. Ini penting karena SVR secara matematis diturunkan dari tekanan dan flow:

```text
SVR = (MAP - RAP) / CO
```

Kalau MAP, RAP, CO, dan SVR semuanya dimasukkan sebagai target primer dengan bobot setara, objective menghitung informasi yang sama lebih dari sekali.

### 2.5 Best Candidate vs Accepted Candidate pada VSD

Di `main_run.m`, VSD membuat:

```text
best_candidate
accepted_candidate
```

Jika calibrated candidate menurunkan objective tetapi gagal rollback gate, maka:

```text
best_candidate = hasil kalibrasi terbaik secara objective
accepted_candidate = baseline atau kandidat aman yang lolos gate
```

Jadi rollback bukan berarti hasil terbaik hilang. VSD memang memisahkan:

1. **best candidate**: kandidat ilmiah yang informatif, walau mungkin tidak diterima sebagai final.
2. **accepted candidate**: kandidat yang aman untuk dipakai sebagai output final pipeline.

Ini sudah mulai diadaptasi ke ASD, terutama untuk Indira, dengan export best rejected candidate.

---

## 3. Landasan Teori GSA

### 3.1 Apa itu GSA?

Global Sensitivity Analysis adalah metode untuk menilai seberapa besar variasi input parameter menyebabkan variasi output model. Dalam model kardiovaskular 0D, ini penting karena:

1. Parameter banyak.
2. Hubungan parameter-output nonlinear.
3. Closed-loop cardiovascular model sangat coupled.
4. Satu parameter bisa mempengaruhi banyak output sekaligus.
5. Ada interaksi antarparameter.

Berbeda dari one-at-a-time local sensitivity, GSA mengeksplorasi ruang parameter secara simultan.

### 3.2 Sobol S1 dan ST

Sobol variance-based GSA memecah varians output `Y` menjadi kontribusi parameter:

```text
Var(Y) = kontribusi parameter tunggal + kontribusi interaksi + residual
```

Interpretasi:

```text
S1_i = first-order Sobol index
     = kontribusi langsung parameter i saja

ST_i = total-order Sobol index
     = kontribusi parameter i + semua interaksi dengan parameter lain
```

Dalam cardiovascular model, `ST` sering lebih penting untuk active mask karena parameter bekerja melalui interaksi. Contoh:

```text
R.PCOX bisa mempengaruhi PAP_mean secara langsung,
tetapi efeknya terhadap Qp/Qs dapat bergantung pada shunt parameter dan venous/preload state.
```

Jadi parameter dengan `S1` kecil tetapi `ST` besar tetap bisa penting.

### 3.3 Kenapa GSA Dilakukan Sebelum Kalibrasi?

Alasan ilmiah:

1. **Identifiability**: jangan mengoptimasi parameter yang outputnya tidak sensitif terhadap data klinis yang tersedia.
2. **Overfitting control**: semakin banyak parameter bebas, semakin mudah model cocok secara numerik tetapi tidak fisiologis.
3. **Interpretability**: ranking ST menjelaskan kenapa parameter tertentu masuk active set.
4. **Workflow traceability**: reviewer bisa melihat bahwa parameter dipilih karena sensitivitas, bukan karena trial-and-error.

### 3.4 PCE vs Direct Saltelli/Sobol ODE

Ada dua pendekatan:

#### PCE-based GSA

Dipakai VSD.

```text
ODE evaluations -> train PCE surrogate -> Sobol indices from surrogate
```

Kelebihan:

1. Jauh lebih cepat untuk banyak parameter.
2. Post-calibration GSA bisa dilakukan tanpa total evaluasi `N*(d+2)`.
3. Cocok untuk pipeline thesis/paper yang stabil.

Risiko:

1. Harus memastikan surrogate cukup akurat.
2. Butuh dependency UQLab/SoBioS dan konfigurasi tambahan.
3. Kalau model ASD punya failure/steady-state issue, surrogate bisa belajar artefak jika training samples tidak bersih.

#### Direct Saltelli/Sobol ODE GSA

Dipakai ASD saat ini.

```text
Saltelli sample matrices A, B, AB_i
-> run ODE directly for every sample
-> compute S1/ST from model output
```

Kelebihan:

1. Lebih transparan.
2. Tidak ada error surrogate.
3. Setiap sample punya log numerical failure dan physiology warning.

Kekurangan:

1. Lebih lama.
2. Untuk `d = 25`, total evaluasi adalah:

```text
N * (d + 2)
```

Misalnya:

```text
N = 128, d = 25 -> 128 * 27 = 3456 ODE simulations
```

Inilah kenapa ASD GSA lebih lama dari VSD PCE-GSA.

---

## 4. Apa yang Diadaptasi ke ASD

### 4.1 File Mapping VSD ke ASD

| Unified VSD | ASD sekarang | Status |
|---|---|---|
| `main_run.m` | `run_asd_patient_case.m` + wrapper GSA/kalibrasi pasien | Adapted, belum satu orchestrator penuh |
| `build_case_calibration_profile.m` | `build_asd_case_calibration_profile.m` | Adapted dan patient-generic |
| `build_target_tiers.m` | `build_asd_target_tiers.m` | Adapted dan ASD-specific |
| `calibration_param_sets.m` | `asd_candidate_param_sets.m` + `build_asd_curated_parameter_library.m` | Adapted dengan Group A/B/C |
| `create_optimization_mask.m` | `build_asd_active_mask_from_gsa.m` | Adapted |
| `objective_calibration.m` | `objective_calibration_asd.m` | Adapted, lebih sederhana tetapi ASD-specific |
| `run_calibration.m` | `run_zoya_asd_calibration.m`, `run_indira_asd_calibration.m` | Partially adapted, belum fully generic |
| `gsa_pce_setup.m` + `gsa_run_pce.m` | `run_zoya_asd_gsa_curated.m`, `run_indira_asd_gsa_curated.m` | Metode berbeda: direct Saltelli/Sobol ODE |
| `run_validation_gate_polish.m` | belum ada ASD equivalent penuh | Belum fully implemented |

### 4.2 ASD Case Profile

File:

```text
src/calibration/build_asd_case_calibration_profile.m
```

Fungsinya sama secara konsep dengan VSD case profile:

1. Memilih scenario `pre_surgery/pre_closure`.
2. Mendeteksi clinical fields yang available/missing.
3. Menentukan apakah data kaya atau sparse.
4. Menentukan target availability.
5. Menentukan allowed candidate groups.
6. Mencatat excluded targets dan prediction-only outputs.

Ini membuat pipeline lebih aman untuk pasien berikutnya karena target tidak di-hardcode hanya untuk Zoya atau Indira.

### 4.3 ASD Target Tiers

File:

```text
src/calibration/build_asd_target_tiers.m
```

Target-tier ASD yang sekarang:

#### Primary pressure-flow targets

```text
QpQs
Qp_Lmin
Qs_Lmin
SAP_mean
PAP_mean
LAP_mean
RAP_mean, jika measured
```

Alasan:

1. Ini target utama ASD pre-closure: shunt severity, systemic flow, pulmonary flow, systemic pressure, pulmonary pressure, atrial filling pressure.
2. Target ini paling langsung mengikat model pressure-flow.
3. Untuk Indira, RAP available, sehingga masuk hard primary.

#### Secondary/guard targets

```text
SAP_max / SBP
SAP_min / DBP
PAP_max / PAP_sys
PAP_min / PAP_dia
DeltaP_LA_RA jika available
Q_ASD_Lmin jika direct atau derived
```

Alasan:

1. Systolic/diastolic waveform extrema penting untuk menjaga bentuk tekanan.
2. Tetapi extrema lebih mudah berubah akibat compliance/phase/timing dan tidak selalu sekuat mean pressure sebagai target utama.
3. `DeltaP_LA_RA = LAP - RAP` adalah mechanism guard karena ia bukan target independen jika LAP dan RAP sudah dipakai.
4. `Q_ASD_Lmin = Qp - Qs` bukan direct shunt-flow measurement jika hanya diturunkan dari Qp dan Qs.

#### Validation/seeding-only

```text
SVR
PVR
```

Alasan:

SVR dan PVR sering dapat dihitung dari pressure-flow:

```text
SVR = (SAP_mean - RAP_mean) / Qs
PVR = (PAP_mean - LAP_mean) / Qp
```

Kalau `SAP_mean`, `RAP_mean`, `Qs`, `PAP_mean`, `LAP_mean`, dan `Qp` sudah menjadi target, maka SVR/PVR adalah informasi turunan. SVR/PVR tetap penting untuk:

1. Validasi hasil akhir.
2. Seeding awal jika dipakai.
3. Diskusi fisiologi.

Tetapi menjadikannya primary target tambahan dapat double-count informasi yang sama.

#### Prediction-only / excluded

```text
LVEDV, LVESV, RVEDV, RVESV, LVEF, RVEF
```

Untuk pasien tanpa data volume/EF pre-closure, metrik ini dilaporkan sebagai model prediction only. Ia boleh dibahas, tetapi tidak boleh dipakai sebagai primary calibration target karena tidak ada clinical anchor.

### 4.4 ASD Candidate Parameter Groups

File:

```text
src/calibration/asd_candidate_param_sets.m
```

#### Group A: Primary vascular + shunt

Contoh:

```text
asd.Cd or R.asd
R.SAR, R.SC, R.SVEN, C.SAR
R.PAR, R.PCOX, R.PCNO, R.PVEN, C.PAR
```

Alasan:

1. Paling langsung terkait pressure-flow evidence.
2. Mengontrol Qp, Qs, Qp/Qs, MAP, PAP, dan shunt load.
3. Untuk ASD orifice mode, shunt knob adalah `asd.Cd`.
4. Untuk ASD linear mode, shunt knob adalah `R.asd`.

#### Group B: Atrial/preload

Contoh:

```text
E.LA.EA, E.LA.EB, E.RA.EA, E.RA.EB
V0.LA, V0.RA, V0.SVEN, V0.PVEN
C.SVEN, C.PVEN
```

Alasan:

ASD shunt terjadi pada atrium, sehingga flow tergantung pada:

```text
P_LA - P_RA
```

Parameter atrial stiffness, atrial unstressed volume, venous reservoir, dan preload bisa mengubah LAP/RAP dan gradient shunt. Ini tidak sekuat Group A secara data support, tetapi dapat menjadi kunci jika Group A tidak cukup.

#### Group C: Ventricular exploratory

Contoh:

```text
E.LV.EA, E.LV.EB, E.RV.EA, E.RV.EB
V0.LV, V0.RV
```

Alasan:

Ventricular parameters mengubah SV, EF, EDV/ESV, dan pressure-volume behavior. Namun tanpa data LV/RV volume/EF pre-closure, parameter ini under-identified. Karena itu Group C:

1. Masuk GSA sebagai monitored candidate.
2. Tidak otomatis masuk kalibrasi kecuali explicitly enabled.
3. Harus diberi interpretasi sebagai exploratory.

---

## 5. Kenapa ASD Tidak Fully Implement Semua Stage VSD

### 5.1 Stage B VSD Tidak Aman untuk ASD Jika Volume/EF Tidak Ada

VSD punya Stage B chamber volume/function fit. Stage ini masuk akal bila clinical LVEDV, LVESV, RVEDV, RVESV, LVEF, atau RVEF tersedia.

Pada Zoya pre-closure:

```text
LVEDV, LVESV, RVEDV, RVESV, LVEF, RVEF = missing
```

Maka Stage B tidak punya anchor klinis. Jika tetap dipaksa:

1. Optimizer dapat mengubah ventricular elastance/V0 untuk mengejar Qp/Qs atau flow.
2. Hasil bisa terlihat RMSE turun, tetapi parameter chamber tidak identifiable.
3. Ini berisiko menjadi overfitting.

Pada Indira, data pressure-flow lebih lengkap daripada Zoya, tetapi jika volume/EF pre-closure tetap tidak tersedia, prinsip yang sama tetap berlaku: Group C harus hati-hati.

### 5.2 Stage D/E/F VSD Belum Sepenuhnya Di-ASD-kan

VSD punya:

```text
Stage D - systemic-output polish
Stage E - plausibility polish
Stage F - validation-gate polish
```

ASD saat ini punya beberapa komponen sejenis:

1. Objective ASD punya pressure guards, shunt guards, ratio-chasing guard, MAP guard, RAP physiological guard.
2. ASD calibration runner punya 11 validity gates.
3. Ada plausibility check dan rollback.
4. Indira sudah menyimpan best candidate dan best rejected candidate.

Namun belum ada satu fungsi generic ASD yang setara penuh dengan `run_validation_gate_polish.m`.

Apakah ini salah? Tidak otomatis.

Untuk skripsi yang waktunya mepet, yang penting adalah:

1. Pre-calibration GSA sudah dilakukan.
2. Active mask transparan.
3. Kalibrasi staged.
4. Validity/plausibility/rollback ada.
5. Best rejected dan accepted candidate disimpan.
6. Limitasi Stage D/E/F yang belum penuh ditulis.

### 5.3 PCE Final GSA Belum Dipakai di ASD

VSD melakukan final PCE-GSA setelah kalibrasi. ASD belum.

Alasan praktis dan ilmiah:

1. ASD direct ODE GSA sudah mahal secara komputasi.
2. PCE butuh setup surrogate dan validasi surrogate.
3. ASD model punya sample warnings/failures yang perlu dipisahkan sebelum surrogate dipercaya.
4. Untuk thesis-deadline, direct Sobol pre-calibration sudah cukup untuk active-set selection.

Yang bisa ditulis sebagai limitation:

> Post-calibration GSA dengan PCE belum dilakukan pada pipeline ASD ini. Sensitivitas yang dilaporkan terutama digunakan untuk pre-calibration screening dan active-set selection.

---

## 6. Perbedaan Target: Kenapa Tidak Semua Data Klinis Jadi Primary?

Pertanyaan penting:

> Kalau output model punya data klinis, kenapa tidak semuanya dimasukkan sebagai primary target?

Jawabannya:

> Karena tidak semua data klinis bersifat independen, tidak semua punya reliability yang sama, dan beberapa adalah turunan matematis dari target lain.

Contoh untuk Indira:

```text
Primary:
QpQs, Qp_Lmin, Qs_Lmin, SAP_mean, PAP_mean, LAP_mean, RAP_mean

Secondary/guard:
SAP_max, SAP_min, PAP_max, PAP_min, DeltaP_LA_RA, Q_ASD_Lmin

Validation/seeding:
SVR, PVR
```

Kenapa demikian?

1. `Qp`, `Qs`, `QpQs`, `SAP_mean`, `PAP_mean`, `LAP_mean`, `RAP_mean` adalah pressure-flow anchors utama.
2. `DeltaP_LA_RA` berasal dari `LAP_mean - RAP_mean`, sehingga jika LAP/RAP sudah primary, DeltaP tidak independen.
3. `Q_ASD_Lmin` sering berasal dari `Qp - Qs`, sehingga jika Qp dan Qs sudah primary, Q_ASD bukan direct measurement.
4. `SVR` berasal dari `(SAP_mean - RAP_mean)/Qs`.
5. `PVR` berasal dari `(PAP_mean - LAP_mean)/Qp`.
6. SBP/DBP/PAP_sys/PAP_dia penting, tetapi lebih tepat sebagai waveform guards agar mean pressure dan flow tidak dicocokkan dengan bentuk gelombang yang rusak.

Jadi, target tier bukan berarti output secondary tidak penting. Secondary guard tetap mengendalikan hasil, tetapi tidak diberi status primary yang dapat mendominasi objective.

Catatan penting:

> VSD juga melakukan pemisahan seperti ini. Di `objective_calibration.m`, VSD punya systemic bundle untuk mencegah MAP, RAP, CO, dan SVR dihitung berulang sebagai informasi independen.

---

## 7. Apakah ASD Bisa Fully Implement VSD?

Jawaban: **bisa sebagian, tetapi tidak sebaiknya disalin penuh tanpa adaptasi.**

### Yang bisa dan sebaiknya disamakan

1. Satu orchestrator generic:

```text
run_asd_patient_case
-> GSA
-> mask
-> calibration
-> validation
-> export
```

2. Best candidate vs accepted candidate.
3. Stage history lengkap.
4. Final report lengkap.
5. Optional final GSA/post-calibration sensitivity.
6. Generic calibration runner, bukan hanya `run_zoya...` dan `run_indira...`.
7. Validation-gate polish setara VSD, jika waktu cukup.

### Yang tidak boleh disalin mentah

1. VSD shunt parameter `R.vsd`/`vsd.Cd` tidak sama dengan ASD shunt mechanism.
2. VSD target seperti `PVR` sebagai primary belum tentu tepat untuk ASD jika PVR hanya turunan.
3. Stage B chamber fitting tidak boleh dipaksa tanpa volume/EF targets.
4. VSD systemic polish tidak boleh dipakai tanpa memeriksa pressure-flow consistency ASD.
5. Post-surgery/post-closure logic harus dipisah karena Jovano pipeline berbeda dan data waktunya berbeda.

---

## 8. Penilaian Pipeline ASD Sekarang

### 8.1 Yang sudah benar

1. Healthy baseline dipisah dari ASD disease simulation.
2. ASD clinical seeding dilakukan sebelum baseline disease simulation.
3. GSA dilakukan sebelum kalibrasi.
4. Candidate parameter library Group A/B/C sudah fisiologi-spesifik ASD.
5. Active mask dibuat dari Sobol ST dan target-tier governance.
6. Kalibrasi tidak memakai semua parameter secara bebas.
7. Objective ASD punya:
   - primary pressure-flow bundle
   - secondary pressure guard
   - shunt mechanism guard
   - MAP/ratio/RAP safety guard
   - validity and boundary penalties
8. Rollback dipakai agar RMSE rendah tidak otomatis diterima bila fisiologi rusak.
9. Best rejected candidate sekarang disimpan untuk Indira, sehingga hasil Stage C yang baik tidak hilang.

### 8.2 Yang belum setara penuh dengan VSD

1. ASD belum punya satu `run_calibration_asd.m` generic seperti VSD `run_calibration.m`.
2. ASD belum punya Stage D/E/F generic seperti VSD.
3. ASD belum punya final PCE-GSA otomatis setelah kalibrasi.
4. ASD GSA masih direct ODE, bukan PCE surrogate.
5. Zoya dan Indira calibration runner masih wrapper spesifik pasien, walau konteks patient-generic sudah mulai dipakai.

### 8.3 Apakah ini cukup benar untuk skripsi?

Ya, dengan catatan dokumentasi yang jujur.

Formulasi yang bisa dipakai:

> Pipeline ASD mengadaptasi struktur unified VSD pada level metodologi, yaitu pediatric scaling, clinical seeding, pre-calibration GSA, Sobol-ST-based active mask, staged constrained calibration, dan post-calibration validity/plausibility gate. Namun implementasinya tidak identik karena ASD memiliki lokasi shunt atrial, data klinis yang berbeda, dan keterbatasan target volume/function pre-closure. Oleh karena itu, target tiers dan candidate parameter groups dibangun khusus untuk ASD agar kalibrasi tetap identifiable dan fisiologis.

---

## 9. Implikasi untuk Zoya dan Indira

### 9.1 Zoya

Zoya adalah kasus sparse-volume:

```text
Ada:
Qp, Qs, QpQs, SAP_mean, PAP_mean, LAP_mean, ASD diameter

Tidak ada:
RAP, PVR/SVR direct, ASD gradient, direct Q_ASD, LV/RV volume/EF
```

Konsekuensi:

1. `asd.Cd` dipakai sebagai shunt knob pada orifice mode.
2. `Q_ASD` adalah comparison dari model, bukan direct target.
3. Group B atrial/preload terbukti penting karena shunt ASD bergantung pada LA-RA pressure gradient.
4. Group C harus ditulis sebagai exploratory karena volume/EF tidak tersedia.
5. RMSE tidak terlalu rendah bukan semata gagal optimizer, tetapi mencerminkan keterbatasan identifiability dan kemungkinan inconsistency/ketidakcukupan target.

### 9.2 Indira

Indira lebih baik secara data pressure-flow:

```text
Ada:
Qp, Qs, QpQs, SAP_mean, PAP_mean, LAP_mean, RAP_mean, ASD gradient

Turunan:
Q_ASD = Qp - Qs
SVR = (SAP_mean - RAP_mean) / Qs
PVR = (PAP_mean - LAP_mean) / Qp
```

Konsekuensi:

1. `R.asd` dapat disemai pada linear shunt mode karena gradient dan shunt-flow estimate tersedia.
2. RAP bisa masuk primary karena measured.
3. DeltaP_LA_RA lebih cocok sebagai mechanism guard karena ia turunan dari LAP/RAP.
4. SVR/PVR lebih cocok sebagai validation/seeding karena turunan dari pressure-flow anchors.
5. Stage C yang near-perfect tetapi rollback karena secondary waveform harus dibaca sebagai: candidate numerik kuat, tetapi perlu keputusan metodologis apakah secondary waveform guard adalah hard veto atau warning-level guard.

---

## 10. Rekomendasi Thesis-Ready

Karena sudah mendekati sidang, rekomendasi terbaik bukan memperbesar semua pipeline supaya identik VSD, tetapi:

1. **Pertahankan ASD direct Sobol GSA N=128** sebagai metode GSA utama.
2. **Tulis jelas bahwa VSD memakai PCE, ASD memakai direct ODE Saltelli/Sobol** sebagai adaptasi yang lebih transparan tetapi lebih mahal.
3. **Jangan memaksa Stage B volume/function** jika data volume/EF pre-closure tidak tersedia.
4. **Simpan dan laporkan best candidate serta accepted candidate**.
5. **Untuk Indira, perlakukan secondary waveform guard sebagai keputusan metodologis eksplisit**, bukan error kode.
6. **Gunakan target tier governance** untuk menjelaskan kenapa semua output yang punya angka klinis tidak otomatis menjadi primary.
7. **Cantumkan limitation** bahwa post-calibration PCE-GSA belum dilakukan pada pipeline ASD.
8. **Untuk pasien berikutnya**, jangan hardcode target. Biarkan `patient_*.m -> caseProfile -> target_tiers -> candidate_set -> GSA -> mask -> calibration`.

---

## 11. Kalimat Metode yang Bisa Dipakai

Versi singkat:

> The ASD workflow followed the methodological sequence of the unified VSD pipeline: pediatric scaling, clinical seeding, pre-calibration global sensitivity analysis, Sobol total-order-based active parameter selection, staged constrained calibration, and post-calibration validity/plausibility assessment. The implementation was adapted to ASD physiology because the shunt occurs between the atria, making atrial pressure gradients and ASD-specific shunt parameters central to the calibration problem.

Versi Indonesia:

> Workflow ASD pada penelitian ini mengikuti struktur metodologis unified VSD, yaitu scaling pediatrik, clinical seeding, GSA sebelum kalibrasi, pemilihan parameter aktif berdasarkan indeks Sobol total-order, kalibrasi bertahap dengan batas fisiologis, serta validasi dan rollback. Namun implementasinya tidak disalin sepenuhnya karena ASD memiliki lokasi shunt atrial, mekanisme shunt yang berbeda, serta ketersediaan data klinis yang tidak sama dengan kasus VSD. Oleh karena itu target kalibrasi dibagi menjadi primary, secondary guard, validation/seeding only, dan prediction-only agar optimasi tetap identifiable dan tidak double-counting data turunan.

---

## 12. Referensi Metode

Referensi teori utama:

1. Sobol IM. 2001. Global sensitivity indices for nonlinear mathematical models and their Monte Carlo estimates. *Mathematics and Computers in Simulation*. DOI: https://doi.org/10.1016/S0378-4754(00)00270-6
2. Saltelli A, Annoni P, Azzini I, Campolongo F, Ratto M, Tarantola S. 2010. Variance based sensitivity analysis of model output. Design and estimator for the total sensitivity index. *Computer Physics Communications*. DOI: https://doi.org/10.1016/j.cpc.2009.09.018
3. Jansen MJW. 1999. Analysis of variance designs for model output. *Computer Physics Communications*. DOI: https://doi.org/10.1016/S0010-4655(98)00154-4
4. UQLab documentation for polynomial chaos expansions and Sobol sensitivity workflows: https://www.uqlab.com/
5. MATLAB `fmincon` documentation for constrained nonlinear optimization: https://www.mathworks.com/help/optim/ug/fmincon.html

Referensi internal kode:

1. `C:/Users/Diniya/unified-vsd-temp/main_run.m`
2. `C:/Users/Diniya/unified-vsd-temp/src/gsa/gsa_pce_setup.m`
3. `C:/Users/Diniya/unified-vsd-temp/src/calibration/run_calibration.m`
4. `C:/Users/Diniya/unified-vsd-temp/src/calibration/objective_calibration.m`
5. `C:/Users/Diniya/unified-vsd-temp/src/utils/create_optimization_mask.m`
6. `src/calibration/build_asd_case_calibration_profile.m`
7. `src/calibration/build_asd_target_tiers.m`
8. `src/calibration/asd_candidate_param_sets.m`
9. `src/calibration/build_asd_active_mask_from_gsa.m`
10. `src/calibration/objective_calibration_asd.m`
11. `scripts/run_zoya_asd_gsa_curated.m`
12. `scripts/run_indira_asd_gsa_curated.m`
13. `scripts/run_zoya_asd_calibration.m`
14. `scripts/run_indira_asd_calibration.m`

---

## 13. Final Position

Keputusan metodologis yang paling defensible:

```text
Jangan klaim ASD fully identical dengan unified VSD.
Klaim bahwa ASD mengadaptasi metodologi unified VSD secara stage-wise,
dengan target-tier dan parameter-library yang disesuaikan untuk fisiologi ASD.
```

Pipeline ASD sekarang **benar sebagai adaptasi** karena mempertahankan prinsip:

```text
GSA first -> active mask -> constrained staged calibration -> validity gate
```

Pipeline ASD belum fully VSD-equivalent pada aspek:

```text
PCE surrogate
post-calibration final GSA
generic Stage D/E/F polish
single main_run-style orchestration
```

Tetapi untuk skripsi pre-closure ASD, ini masih dapat dipertahankan sebagai metode yang kuat selama limitation dan perbedaan implementasi ditulis jelas.
