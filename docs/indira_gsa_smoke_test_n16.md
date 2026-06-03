# Indira ASD Curated GSA Smoke Test N=16

Tanggal run: 2026-06-02  
Script: `scripts/run_indira_asd_gsa_curated.m`  
Mode: pre-calibration GSA only, tanpa optimisasi dan tanpa tuning parameter  
Sampling: Saltelli/Sobol, `N = 16`, seed `42`, warmup `40` cardiac cycles  
Total evaluasi model: `432`  
Workbook: `results/tables/indira_asd_gsa_curated_20260602_204432.xlsx`  
MAT file: `results/tables/indira_asd_gsa_curated_20260602_204432.mat`

## 1. Tujuan Smoke Test

Smoke test ini bukan hasil thesis-final GSA. Tujuannya hanya memastikan bahwa pipeline Indira sudah berjalan dari:

`patient_indira` -> pediatric scaling -> ASD clinical seeding -> curated ASD parameter library -> Sobol/Saltelli sampling -> output extraction -> failure logging -> Excel/MAT/figure export.

Karena `N = 16` sangat kecil untuk 25 parameter, ranking sensitivitas hanya boleh dipakai sebagai pemeriksaan awal. Ranking final harus berasal dari `N = 128` atau lebih besar.

## 2. Ringkasan Pipeline

| Pemeriksaan | Hasil | Interpretasi |
|---|---:|---|
| Parameter shunt yang dipakai | `R.asd` | Benar untuk Indira karena ASD memakai linear resistance seed dari gradient dan shunt flow. |
| Jumlah parameter curated | 25 | Groups A+B+C ikut disampling untuk screening, bukan otomatis dikalibrasi semua. |
| Matriks Saltelli | A, B, 25 AB | Semua matriks selesai dievaluasi. |
| Bootstrap CI | 200 iterasi | Berhasil dihitung, tetapi CI masih lebar karena `N = 16`. |
| Export | Excel, MAT, figures | Export berhasil. |
| Paralel | 14 worker, sempat fallback serial | Workflow robust karena tidak abort saat worker gagal. Untuk run besar sebaiknya pakai 6 worker atau serial. |

## 3. Failure dan Warning

| Jenis catatan | Count | Persen dari 432 evaluasi | Interpretasi |
|---|---:|---:|---|
| Numerical failure | 1 | 0.23% | Satu sampel tidak mencapai steady state dalam 40 cycles. Ini rendah dan tidak mengganggu smoke test. |
| Physiology warning | 50 | 11.57% | Semua berupa `opposite_shunt_direction`, yaitu `Q_ASD_Lmin < 0`. Ini numerically valid, bukan solver failure. |
| Total flagged records | 51 | 11.81% | Masih acceptable untuk smoke test. Perlu dimonitor pada `N = 128`. |

Satu numerical failure terjadi pada matriks `AB_V0.SVEN`, sample 5, dengan failure type `steady_state_failure`. Ini konsisten dengan fakta bahwa `V0.SVEN` sangat kuat mengubah preload dan blood-volume distribution. Untuk run besar, jika failure fraction tetap rendah, ini cukup dicatat. Jika meningkat, baru pertimbangkan warmup lebih panjang atau bounds yang lebih konservatif.

`opposite_shunt_direction` tidak boleh diperlakukan sebagai kegagalan numerik. Dalam model ASD bidirectional, arah shunt ditentukan oleh gradien tekanan atrium. Beberapa kombinasi parameter GSA dapat membuat `P_RA` lebih tinggi dari `P_LA`, sehingga flow menjadi RA-to-LA. Untuk pasien Indira pre-closure, arah klinis yang diharapkan tetap left-to-right, jadi warning ini penting sebagai physiology guard untuk tahap kalibrasi.

## 4. Ranking Sensitivitas N=16

Top recommended active set dari smoke test:

| Parameter | Group | Max_ST primary | Mean_ST primary | Status dari mask | Catatan |
|---|---|---:|---:|---|---|
| `V0.SVEN` | B secondary atrial/preload | 1.000 | 0.830 | selected | Dominan pada hampir semua output primer dan sekunder. |
| `R.SC` | A primary vascular/shunt | 0.109 | 0.023 | selected | Utama pada systemic pressure, terutama `SAP_mean` dan `SAP_min`. |
| `C.SVEN` | B secondary atrial/preload | 0.109 | 0.080 | selected | Mempengaruhi `SAP_mean` dan `LAP_mean`. |
| `E.RA.EB` | B secondary atrial/preload | 0.035 | 0.010 | selected by fallback/min-active | Evidence N=16 lemah; jangan disimpulkan final. |

Parameter Group C yang sensitif tetapi tidak masuk mask default:

| Parameter | Max_ST primary | Alasan tidak langsung dikalibrasi |
|---|---:|---|
| `E.LV.EB` | 0.176 | Group C tetap monitor-only karena Indira tidak punya target LVEDV/LVESV/LVEF. |
| `E.RV.EB` | 0.259 | Group C tetap monitor-only karena Indira tidak punya target RVEDV/RVESV/RVEF. |
| `E.RV.EA` | 0.124 | Sensitif pada `QpQs`, tetapi identifiability lemah tanpa volume/EF. |

## 5. Koreksi Terhadap Interpretasi Awal

Beberapa temuan awal sudah benar:

1. Pipeline Indira berhasil berjalan sampai export.
2. Mode-aware shunt logic bekerja: Indira memakai `R.asd`, bukan `asd.Cd`.
3. Failure numerical sangat rendah.
4. `V0.SVEN` muncul sebagai parameter dominan.
5. `N = 16` hanya smoke test, bukan dasar final untuk active set thesis.

Namun ada beberapa bagian yang perlu diluruskan:

1. `R.asd` yang low ST tidak otomatis berarti seed `R.asd` sudah pasti akurat. Interpretasi yang lebih aman: pada rentang sampel dan output yang diuji di `N = 16`, perubahan global preload/venous reservoir lebih dominan daripada variasi `R.asd`. Karena `R.asd` berasal dari `DeltaP / Q_ASD` klinis-terturun, ia tetap penting secara fisiologis walaupun ST smoke-test rendah.
2. `Q_shunt_Lmin` Indira berasal dari `Qp - Qs`, bukan pengukuran shunt flow langsung independen. Jadi untuk metodologi, sebut sebagai derived shunt-flow estimate. Jangan tulis sebagai direct measured Q_ASD kecuali ada sumber klinis yang memang mengukur langsung.
3. `E.RA.EB` masuk active set karena fallback/min-active rule, bukan karena melewati threshold ST 0.10. Ini boleh dipantau, tetapi tidak boleh diklaim sebagai parameter sensitif dari N=16.
4. Group C memang terlihat sensitif, tetapi tetap tidak boleh menjadi parameter utama kalibrasi selama target volume/EF tidak tersedia. Jika nanti dipakai, statusnya harus exploratory dan perlu justification.
5. Parallel worker crash bukan temuan fisiologi. Itu isu stabilitas eksekusi. Fallback serial membuktikan runner cukup robust, tetapi untuk N=128 sebaiknya jangan pakai 14 worker.

## 6. Perbandingan Metodologis Dengan Zoya

Indira lebih kuat daripada Zoya untuk mekanisme hemodinamik shunt karena memiliki:

| Data | Zoya | Indira | Dampak |
|---|---|---|---|
| ASD diameter/area | Ada | Missing | Zoya lebih kuat untuk geometry/orifice. |
| ASD gradient | Missing | Ada, 2 mmHg | Indira bisa seed `R.asd`. |
| Qp dan Qs | Ada | Ada | Keduanya punya flow target. |
| Derived Q_ASD = Qp - Qs | Ada | Ada | Keduanya dapat membandingkan shunt estimate, tetapi bukan direct flow independen. |
| RAP | Missing | Ada, 8 mmHg | Indira lebih baik untuk atrial pressure constraint. |
| LAP | Ada | Ada | Keduanya punya left atrial pressure target. |
| LV/RV volume dan EF | Missing | Missing | Group C tetap poorly identifiable untuk keduanya. |

Secara praktis, Indira harus lebih defensible untuk kalibrasi pressure-flow karena `R.asd`, RAP, LAP, Qp, Qs, dan Qp/Qs tersedia. Tetapi Indira tetap sparse untuk chamber-volume validation.

## 7. Bootstrap CI dan Kualitas Statistik

Bootstrap CI masih sangat lebar:

| Parameter | Max_ST | CI 95% | Width | Interpretasi |
|---|---:|---|---:|---|
| `V0.SVEN` | 1.000 | 0.586 sampai 1.527 | 0.941 | Dominan, tetapi estimasi N=16 sangat tidak presisi. |
| `R.SC` | 0.109 | 0.049 sampai 0.214 | 0.165 | Borderline; perlu N=128. |
| `C.SVEN` | 0.109 | 0.042 sampai 0.241 | 0.199 | Borderline; perlu N=128. |
| `E.LV.EB` | 0.176 | 0.071 sampai 0.327 | 0.256 | Sensitif tetapi Group C monitor-only. |
| `E.RV.EB` | 0.259 | 0.002 sampai 0.427 | 0.425 | Sangat tidak presisi; jangan dipakai sebagai keputusan final. |

Catatan: nilai CI bisa melewati 1 karena bootstrap pada estimasi Sobol kecil-sampel dapat menghasilkan rentang tidak terikat. Ini tanda noise statistik, bukan berarti ST fisik lebih dari 1.

## 8. Scientific Verdict

Smoke test Indira dinyatakan PASS sebagai pipeline smoke test.

Alasannya:

1. Semua matriks GSA selesai.
2. Export Excel/MAT/figure berhasil.
3. Numerical failure sangat rendah.
4. Warning fisiologi dipisahkan dari failure numerik.
5. Parameter shunt mode-aware sudah benar memakai `R.asd`.
6. Target-tier dan candidate-library dapat berjalan untuk pasien selain Zoya.

Tetapi hasil ini belum boleh dipakai untuk active set final atau keputusan kalibrasi thesis karena `N = 16` terlalu kecil dan CI masih lebar.

## 9. Rekomendasi Langkah Lanjut

Langkah lanjut yang paling masuk akal:

1. Jangan kalibrasi dulu.
2. Jalankan Indira curated GSA `N = 128` dengan seed yang sama (`42`) dan warmup `40 cycles`.
3. Gunakan 6 worker paralel atau serial overnight. Hindari 14 worker karena sudah terbukti sempat mematikan pool.
4. Setelah N=128, cek:
   - numerical failure fraction idealnya tetap < 5%;
   - physiology warning fraction dicatat, bukan langsung dianggap gagal;
   - apakah `V0.SVEN` tetap dominan;
   - apakah `R.SC` dan `C.SVEN` tetap melewati ST >= 0.10;
   - apakah `R.asd` tetap rendah atau mulai muncul;
   - apakah Group C tetap hanya monitor-only.
5. Jika ranking N=128 stabil, baru bangun active mask Indira untuk staged calibration.
6. Untuk kalibrasi Indira, gunakan target primer pressure-flow:
   - `QpQs`
   - `Qp_Lmin`
   - `Qs_Lmin`
   - `SAP_mean`
   - `PAP_mean`
   - `LAP_mean`
   - dan pertimbangkan `RAP_mean` sebagai secondary guard karena Indira punya RAP.
7. Jangan masukkan LV/RV volume dan EF ke objective karena datanya tetap missing.

## 10. Catatan Untuk Perbaikan Kecil Sebelum Thesis-Final

Perbaikan berikut bersifat governance/reporting, bukan perubahan persamaan model:

1. Pastikan semua report menulis `Q_shunt_Lmin` Indira sebagai derived from `Qp_Lmin - Qs_Lmin`, bukan direct independent shunt flow.
2. Pastikan warning/report tidak lagi menyebut "RAP missing" untuk Indira, karena RAP tersedia.
3. Pastikan output table tidak hardcode label Zoya saat dipakai untuk Indira.
4. Pertahankan pemisahan `Numerical_Failures` dan `Physiology_Warnings`.
5. Untuk N=128, catat random seed, sample size, worker count, warmup cycles, dan timestamp di workbook.

## 11. Perintah Run N=128 Yang Disarankan

Di MATLAB:

```matlab
delete(gcp('nocreate'));
parpool('local', 6);
setenv('ASD_GSA_USE_PARALLEL', '1');
run('scripts/run_indira_asd_gsa_curated.m');
```

Jika parallel pool kembali tidak stabil:

```matlab
delete(gcp('nocreate'));
setenv('ASD_GSA_USE_PARALLEL', '0');
run('scripts/run_indira_asd_gsa_curated.m');
```

Untuk thesis-final precision, `N = 128` adalah langkah berikutnya yang sejalan dengan workflow Hafiz/Keisya. `N = 256` dapat dipertimbangkan setelah N=128 jika CI masih terlalu lebar atau ranking parameter masih berubah.
