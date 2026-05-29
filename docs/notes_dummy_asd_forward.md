# Notes Dummy ASD Forward Simulation

Dokumen ini menjelaskan alur `scripts/run_dummy_asd_forward.m` dengan bahasa
yang bisa dipakai ulang untuk Methods dan Results/Discussion skripsi.

## Tujuan

Runner ini adalah uji forward-only untuk memastikan arsitektur ASD bekerja
secara fisiologis sebelum masuk ke Patient Z. Dummy ASD berasal dari median
kohort literatur, bukan data pasien individual. Karena itu, kasus ini tidak
dipakai untuk GSA, optimasi, kalibrasi, atau tuning parameter.

Pernyataan metodologis:

> The literature-based ASD dummy case is used as an intermediate
> forward-simulation plausibility check between healthy baseline validation
> and patient-specific Patient Z simulation. Because the values are cohort
> medians rather than individual paired measurements, the case is not used for
> GSA or calibration. Instead, it is used to test whether the ASD shunt
> architecture produces physiologically plausible trends such as Q_ASD
> activation, Qp/Qs elevation before closure, and near-normal Qp/Qs after
> closure.

## Input Yang Diload

Runner memuat dua sumber utama:

1. `config/default_parameters.m`: parameter adult healthy baseline. Ini adalah
   basis model tertutup tanpa shunt.
2. `config/patient_dummy_ASD.m`: profil dummy ASD dari Sjoberg et al. 2024
   Table 1. Yang dipakai adalah nilai pre-closure dan post-closure yang
   tersedia. Nilai yang tidak dilaporkan tetap `NaN`.

Untuk dummy pediatric scaling, bobot tidak dilaporkan di sumber utama. Karena
`apply_scaling.m` membutuhkan bobot untuk rekonsiliasi blood volume, runner
menghitung bobot model-only dari inverse Mosteller:

`weight_kg = BSA^2 * 3600 / height_cm`

Nilai ini bukan data literatur dan bukan target kalibrasi.

## Mengapa Healthy_Adult_ref Ada Di Excel

`Healthy_Adult_ref` dipertahankan sebagai global baseline integrity check. Ia
menjawab pertanyaan sederhana: apakah model default yang sehat dan tertutup
masih menghasilkan Qp/Qs sekitar 1 dan Q_ASD sekitar 0?

Kasus ini bukan pembanding ukuran tubuh langsung untuk dummy pediatric ASD.
Pembanding langsungnya adalah `Healthy_Pediatric_Dummy_Baseline`.

## Baseline Pediatric Healthy

Runner sekarang menambahkan `Healthy_Pediatric_Dummy_Baseline`.

Alurnya:

adult reference parameters
-> apply pediatric scaling memakai antropometri dummy pre-closure
-> ASD tetap ditutup/inaktif
-> run solver
-> compute clinical indices

Tujuannya adalah membedakan efek ukuran tubuh pediatric dari efek penyakit ASD.
Ekspektasinya:

- Qp/Qs sekitar 1
- Q_ASD sekitar 0
- tidak ada shunt penyakit

## Cara Dummy Pre-Closure ASD Dibuat

Pre-closure dummy dibuat dari parameter adult reference yang diskalakan ke
antropometri pre-closure dummy. HR akhir diambil dari tabel dummy bila tersedia.
Setelah itu ASD diaktifkan melalui coupling LA-RA pada `system_rhs.m`.

Konvensi tanda:

- `Q_ASD > 0` berarti aliran LA -> RA
- `Q_ASD < 0` berarti aliran RA -> LA

Karena dummy literature tidak melaporkan diameter ASD, area ASD, pressure
gradient, atau shunt flow langsung, runner tidak dapat menghitung resistansi
ASD dari data klinis. Untuk uji arsitektur forward-only, runner memakai:

`R.asd = 0.1 mmHg*s/mL`

Ini adalah placeholder resistansi terbuka agar jalur LA-RA aktif. Nilai ini
bukan hasil kalibrasi dan tidak boleh diperlakukan sebagai parameter final
Patient Z.

## Cara Dummy Post-Closure ASD Dibuat

Post-closure dummy dibuat dari parameter adult reference yang diskalakan ke
antropometri post-closure dummy. Setelah itu ASD ditutup dengan konvensi:

`R.asd = Inf`

Dengan resistansi tak hingga, shunt ASD tidak aktif sehingga Q_ASD harus nol
atau sangat dekat nol, dan Qp/Qs kembali mendekati 1.

## Interpretasi Qp/Qs

Pada pre-closure, Qp/Qs naik di atas 1 karena aliran tambahan dari LA ke RA
menambah beban sisi kanan dan pulmonary flow. Ini menunjukkan perilaku dasar
ASD yang benar.

Qp/Qs model tidak harus sama persis dengan target literatur 1.8 pada fase ini.
Alasannya:

- tidak ada GSA
- tidak ada optimasi
- tidak ada tuning `R.asd`
- diameter/area/gradient ASD tidak dilaporkan
- data dummy adalah median kohort, bukan pasangan data individual yang
  konsisten secara internal

Karena itu mismatch Qp/Qs adalah informasi plausibility, bukan kegagalan
kalibrasi.

## Model Predictions vs Literature Targets

Model predictions adalah keluaran yang dihitung dari ODE:

- Q_ASD mean
- Q_ASD direction
- Qp model
- Qs model
- Qp/Qs model
- LVEDV, LVESV, LVSV, LVEF
- RVEDV, RVESV, RVSV, RVEF
- CO/CI model
- SBP, DBP, MAP
- PAP, RAP, LAP

Literature targets adalah angka dari `patient_dummy_ASD.m`, terutama dari
Sjoberg et al. 2024 Table 1:

- age, height, BSA, HR
- Qp/Qs pre-closure
- SBP dan DBP
- indexed LV/RV volumes
- LV/RV EF
- LV/RV cardiac index

Beberapa target adalah derived values dari median literatur:

- LVEDV_mL = LVEDVi * BSA
- RVEDV_mL = RVEDVi * BSA
- CO_Lmin = LV_CI * BSA
- Qp/Qs_from_CI = RV_CI / LV_CI

Nilai yang tidak dilaporkan tetap `NaN` atau `Not reported`.

## Cara Membaca Workbook

Sheet penting:

- `Summary`: ringkasan semua skenario.
- `Forward_Output_Healthy`: output adult healthy reference.
- `Forward_Output_Pediatric`: output pediatric healthy dummy baseline.
- `Forward_Output_PreClosure`: output dummy ASD pre-closure.
- `Forward_Output_PostClosure`: output dummy ASD post-closure.
- `Parameters_*`: parameter aktual yang dipakai pada tiap run.
- `PreClosure_Target_Comparison`: model vs target literatur untuk pre-closure.
- `PostClosure_Target_Comparison`: model vs target literatur untuk post-closure.
- `Plausibility_Checks`: cek fisiologi utama.
- `Interpretation`: narasi singkat untuk Results/Discussion.
- `Missing_Data_and_Limitations`: data yang tidak tersedia dan keterbatasan
  sumber.

## Kesimpulan Metodologis

Workflow ini aman untuk uji arsitektur ASD karena healthy baseline tetap
tertutup, pediatric dummy baseline tetap tertutup, pre-closure mengaktifkan
shunt LA->RA, dan post-closure menutup shunt kembali. Namun hasil ini belum
boleh dianggap validasi pasien spesifik karena belum ada kalibrasi dan karena
dummy case berasal dari median kohort.

Langkah berikutnya setelah ini adalah Patient Z forward-only simulation, masih
tanpa GSA/optimasi, untuk melihat apakah data pasien spesifik menghasilkan
perilaku ASD yang masuk akal sebelum masuk ke sensitivity analysis dan
calibration.

## Diagnostic R_ASD Sweep

Dummy ASD forward run pertama sudah lulus mechanism checks: healthy adult,
healthy pediatric dummy, dan post-closure tetap closed-shunt dengan Q_ASD
mendekati nol dan Qp/Qs mendekati 1, sedangkan pre-closure mengaktifkan shunt
LA->RA dan menaikkan Qp/Qs di atas 1. Namun run tersebut belum mencapai
kesesuaian kuantitatif dengan target median literatur, terutama Qp/Qs
pre-closure yang dilaporkan sekitar 1.8.

Hal ini tidak ditafsirkan sebagai kegagalan kalibrasi, karena pada fase ini
tidak ada kalibrasi. Nilai `R_ASD = 0.1 mmHg*s/mL` hanya placeholder untuk
membuka jalur LA-RA secara forward-only. Profil dummy juga berasal dari median
kohort, bukan data pasien individual berpasangan, sehingga angkanya tidak
harus konsisten sebagai satu keadaan hemodinamik pasien tunggal.

Karena diameter ASD, pressure gradient LA-RA, dan direct shunt flow tidak
dilaporkan, langkah diagnostik berikutnya adalah sweep terbatas pada
`R_ASD = [0.2, 0.1, 0.05, 0.02, 0.01] mmHg*s/mL`. Tujuannya hanya memastikan
bahwa ketika resistansi shunt diturunkan, Q_ASD dan Qp/Qs bergerak meningkat
secara fisiologis dan monotonic.

Sweep ini tetap bukan GSA, bukan optimasi, dan bukan pemilihan nilai R_ASD
final. GSA dan optimization tetap ditunda sampai Patient Z forward simulation
stabil dan defensible.
