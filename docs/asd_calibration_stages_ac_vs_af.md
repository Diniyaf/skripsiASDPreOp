# ASD Calibration Stages — A+C vs Full A–F

**Date:** 2026-06-04
**Context:** Current ASD calibration uses Stage A (vascular+shunt+preload) and
Stage C (ventricular extension, conditional). VSD pipeline uses A→F. This
document compares both approaches and recommends whether to expand.

---

## 1. Current ASD: Stage A + Stage C

```
Stage A — Vascular, shunt, preload params
  → Kalibrasi parameter yang paling langsung constrain oleh data klinis
  → Kalau RMSE < 0.10 → STOP (kalibrasi selesai)
  → Kalau RMSE ≥ 0.10 → lanjut Stage C

Stage C — Ventricular extension (conditional, exploratory)
  → Hanya jalan kalau Stage A gagal + Group C diizinkan
  → Tambah E.LV.EB, E.RV.EB ke active set
  → Label: exploratory — tidak ada data volume untuk validasi
```

### Pros

| Pro | Detail |
|---|---|
| **Simpel** | 2 stage, mudah dijelaskan di thesis |
| **Defensible** | Stage A = parameter yang constrain-nya kuat. Stage C = exploratory, transparan |
| **Cepat** | 1-2× fmincon per pasien, bukan 4-6× |
| **Mencegah overfitting** | Tidak bisa "over-optimize" karena stage terbatas |
| **Sudah menghasilkan accepted candidates** | Zoya v4 (RMSE 0.35), Indira Stage C (RMSE 0.042) |

### Cons

| Con | Detail |
|---|---|
| **Tidak ada systemic polish** | MAP degradation di Zoya dan Indira tidak bisa di-refine setelah Stage C |
| **Plausibility hanya post-hoc** | Parameter WARNING tidak bisa dikurangi — cuma dicatat |
| **Tidak bisa "mundur"** | Begitu Stage C jalan, tidak bisa kembali refine Stage A params |
| **Validation cuma check** | 11 gates hanya mendeteksi masalah, tidak memperbaiki |

---

## 2. Full VSD: Stage A→F

| Stage | Apa yang Dilakukan | Relevant untuk ASD? |
|---|---|---|
| **A** | Vascular + shunt → pressure-flow matching | ✅ Sudah dilakukan |
| **B** | Chamber volumes → LVEDV, RVEDV, EF matching | ❌ Skip — tidak ada data volume/EF |
| **C** | Joint polish → top-GSA params | ✅ Sudah dilakukan (Stage C = ventricular extension) |
| **D** | Systemic polish → SAP, CO, SVR refinement | ⚠ Bisa membantu — MAP degradation issue |
| **E** | Plausibility polish → kurangi WARNING count | ⚠ Bisa membantu — E.RV.EB sering WARNING |
| **F** | Validation gate polish | ⚠ Bisa membantu — refine sampai semua gate PASS |

### Pros A–F

| Pro | Detail |
|---|---|
| **Systemic pressure bisa direcover** | Stage D khusus memperbaiki MAP tanpa merusak fit lainnya |
| **Parameter WARNING bisa dikurangi** | Stage E mendorong params menjauh dari bounds |
| **Iterasi sampai semua gate PASS** | Stage F = safety net terakhir |
| **Metodologi "lengkap"** | Persis seperti VSD — lebih mudah dipertahankan sebagai adaptasi |
| **Narrative lebih kaya** | "6-stage calibration dengan governance bertingkat" > "2-stage calibration" |

### Cons A–F

| Con | Detail |
|---|---|
| **Komputasi lebih berat** | 4-6× fmincon per pasien vs 1-2× |
| **Over-engineering untuk data sparse** | Stage B tetap harus skip. Stage D/E/F = refinement yang mungkin tidak mengubah hasil signifikan |
| **Risk overfitting** | Lebih banyak stage = lebih banyak kesempatan untuk "memaksa" fit |
| **Kompleksitas kode** | Tambah ~200 baris per stage |
| **Deadline** | Tidak cukup waktu implementasi + test sebelum sidang |
| **Nilai tambah marginal** | Zoya: 0.35 → mungkin 0.32. Indira: 0.042 → mungkin 0.038. Tidak game-changing |

---

## 3. Stage-by-Stage Feasibility for ASD

| Stage | Feasible? | Kenapa |
|---|---|---|
| **A** | ✅ Yes | Sudah implemented |
| **B** | ❌ No | Tidak ada data volume/EF untuk Zoya maupun Indira |
| **C** | ✅ Yes | Sudah implemented (ventricular extension) |
| **D** | ⚠ Partial | Bisa membantu Zoya (MAP turun 90→85) dan Indira (SAP_mean turun 87→69). Tapi perlu 6-8 parameter systemic-specific. Saat ini parameter systemic (R.SAR, R.SC) sudah di Stage A |
| **E** | ⚠ Partial | Bisa membantu — E.RV.EB hampir selalu WARNING. Tapi kalau bound memang fisiologis, memaksa parameter menjauh dari bound = memaksa keluar dari range yang valid |
| **F** | ⚠ Partial | 11 gates sudah dicek post-hoc. Stage F = re-optimize dengan gate constraints sebagai hard constraints di objective. Kompleksitas tinggi, nilai tambah rendah |

---

## 4. Recommendation: Stay with A+C for S1

### Why Not Expand to A–F

1. **Stage B** = impossible (no volume data). Already correctly skipped.
2. **Stage D** = the only one with real added value for ASD. But the systemic parameters are already in Stage A. A dedicated systemic polish would re-tune the SAME parameters with tighter bounds — marginal improvement.
3. **Stage E** = risks overfitting. E.RV.EB at lower bound may be physiologically correct (RV remodeling in ASD). Pushing it away from bound could produce worse physiology.
4. **Stage F** = over-engineering. 11 gates + clinical fit guard already handle validation.

### What to Write in Thesis

> *"Framework kalibrasi ASD mengadopsi struktur staged calibration dari
> unified VSD (Hafiz-Keisya) dengan penyesuaian berikut: Stage A (vaskular,
> shunt, preload) dipertahankan sebagai kalibrasi primer untuk pressure-flow
> matching. Stage B (chamber volumes) tidak diimplementasikan karena ketiadaan
> data volume/EF ventrikel pada kedua pasien. Stage C diadaptasi sebagai
> ekstensi ventrikel eksploratif (conditional). Stage D (systemic polish),
> Stage E (plausibility polish), dan Stage F (validation gate polish) tidak
> diimplementasikan — fungsinya telah dicakup oleh clinical fit guard,
> parameter plausibility check, dan 11 validity gates yang berjalan sebagai
> post-calibration governance. Penyederhanaan ini sesuai dengan ketersediaan
> data klinis yang terbatas dan dijustifikasi oleh hasil: kedua pasien
> mencapai accepted candidates dengan RMSE 0.04–0.35."*

### Future Work (S2/S3)

Jika data volume/EF tersedia untuk pasien pre-closure:
- Implement Stage B untuk chamber volume calibration
- Implement Stage D untuk systemic refinement pasca-volume-matching
- Pertimbangkan Stage E kalau parameter WARNING menjadi masalah sistematis

---

## 5. Summary Table

| | A+C (Current) | A–F (Full VSD) |
|---|---|---|
| **Stages** | 2 | 6 |
| **fmincon calls per patient** | 1-2 | 4-6 |
| **Thesis narrative** | "Adapted and simplified for sparse ASD data" | "Full VSD methodology replication" |
| **Feasible with current data?** | Yes — Stage B correctly skipped | Partially — Stage B impossible |
| **RMSE impact (estimated)** | 0.04–0.35 (achieved) | 0.03–0.32 (marginal gain) |
| **Risk of overfitting** | Low | Medium-High (with sparse data) |
| **Implementation time** | Done | 2-3 days |
