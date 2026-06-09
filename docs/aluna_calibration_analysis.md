# Aluna Calibration — Boundary Case Analysis

**Date:** 2026-06-07  
**Run folders:** `aluna_asd_calib_20260607_180330` (Stage A), `aluna_asd_calib_20260607_181140` (Stage A+C)  
**Status:** Both rejected — SVR violation. Framework boundary established.  
**Key finding:** 2 primary targets insufficient. E.RV.EB helps but can't rescue SVR.

---

## 1. Configuration

| Setting | Stage A | Stage C |
|---|---|---|
| Primary targets | SAP=104, PAP=15.5 | Same |
| Active params | 5 (Cd, R.SC, R.PCOX, V0.SVEN, C.SVEN) | 6 (+E.RV.EB) |
| Group C | OFF | ON |

---

## 2. Results Summary

| Metric | Target | Baseline | Stage A | Stage C |
|---|---|---|---|---|
| SAP_mean | 104 | 69.3 (33%) | 126.4 (22%) | **96.3 (7.4%)** |
| PAP_mean | 15.5 | 11.9 (23%) | 13.5 (13%) | **14.1 (8.9%)** |
| **RMSE** | — | **0.287** | **0.178** | **0.082** |
| SVR (WU) | — | 62 | 143 | 90 |
| **Accepted?** | — | — | ❌ | ❌ |

---

## 3. Why Rollback — SVR Violation in Both Runs

### Stage A: R.SC Pushed to Bound → SVR = 143 WU

| Parameter | Baseline | Stage A | Flag |
|---|---|---|---|
| R.SC | 3.29 | **8.21** (upper bound) | WARNING |
| asd.Cd | 0.70 | 0.66 | OK |
| V0.SVEN | 390 | 369 | OK |

**Mechanism:** fmincon overshoots MAP (69→126) by pushing R.SC to bound. SVR
explodes: 62→143. Only 2 iterations before step tolerance — no downhill direction found.

### Stage C: E.RV.EB Saves R.SC — But SVR Still >50

| Parameter | Baseline | Stage A | Stage C | Flag |
|---|---|---|---|---|
| R.SC | 3.29 | 8.21 | **4.99** | OK (not at bound!) |
| E.RV.EB | 0.35 | — | 0.35 | OK (barely changed) |
| MAP | 69 | 126 | **96** | Closer to target |
| SVR | 62 | 143 | **90** | Still > 50 |

**Key insight:** E.RV.EB barely changed (0.351→0.352). The optimizer did NOT
use the ventricular parameter. Instead it explored the landscape better: R.SC
came down from 8.21→4.99, MAP came down from 126→96. But SVR = 90 still > 50.

**Why E.RV.EB couldn't help more:** With only 2 pressure targets, RV elastance
affects both systemic and pulmonary pressures through coupling. No independent
flow target (Qp, Qs) to differentiate the effect. E.RV.EB is not identifiable
with pressure-only targets.

### Plausibility Comparison

| Run | Param OK | WARNING | FAIL |
|---|---|---|---|
| Stage A | 4 | 1 (R.SC at bound) | 0 |
| Stage C | **6** | **0** | **0** |

Stage C is more physiologically plausible — all 6 parameters comfortably inside
bounds. Yet it still fails the SVR gate. This confirms the gate works correctly:
it rejects a parameter set that is statistically well-behaved but produces a
physiologically implausible output.

---

## 4. Baseline SVR Already >50 — Infant Physiology

```
SVR = (MAP - RAP) / CO

Aluna baseline: SVR = (69-4) / 1.05 = 62 WU ← SUDAH >50 sebelum kalibrasi!
```

Bound [0.5, 50] WU adalah referensi dewasa. Untuk infant 8.9kg dengan CO ≈ 1
L/min, SVR normal sudah 30-60 WU. Bound 50 terlalu ketat.

**Thesis framing:** *"Bound SVR dewasa [0.5, 50] WU tidak sesuai untuk populasi
infant — sebagaimana ditunjukkan oleh SVR baseline Aluna (62 WU) yang sudah
melebihi bound sebelum kalibrasi. Ini merupakan batasan metodologis yang
teridentifikasi: penggunaan bound validitas absolut tanpa penyesuaian usia."*

---

## 5. Three Patients — Three Outcomes

| Patient | Targets | Baseline RMSE | Best RMSE | Accepted? | Lesson |
|---|---|---|---|---|---|
| Zoya | 6 | 0.45 | 0.35 | ✅ (v4) | Sparse → 4 iterasi, atrial expansion |
| Indira | 7 | 0.20 | 0.042 | ✅ (Stage C) | Rich → 1 iterasi, seeding akurat |
| Aluna | **2** | 0.29 | 0.082 | ❌ | Boundary: <3 targets insufficient |
