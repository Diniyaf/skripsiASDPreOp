# Diniya-Jovano Handoff Strategy for Zoya ASD Pre-to-Post Closure

Date: 2026-06-02  
Scope: methodology and handoff strategy only. This note does not change model equations, calibration results, or patient data.

## 1. Executive Summary

Diniya's accepted Zoya pre-closure result and Jovano's post-closure result should be connected through a shared physiological narrative and a shared output/data contract, not by directly copying calibrated parameter values from one codebase into the other.

Reason: the two models are structurally different.

- Diniya's active repository (`skripsiASDPreOp`) models pre-closure ASD physiology with an active ASD shunt, target-tier governance, GSA-based parameter selection, staged calibration, rollback/accept gates, and 26-output discussion tables.
- Jovano's repository (`ASD-Model-pre-post`) is currently a post-closure closed-shunt model. The active post-closure code uses flat parameter names (`Emax_lv`, `Emin_lv`, `R_sa`, etc.), closes the ASD with `R_ASD = 1e9`, and fits a different objective dominated by post-closure volume/function targets.

Therefore, the handoff should be:

1. Diniya sends a reproducible pre-closure result package.
2. Jovano sends a reproducible post-closure result package.
3. Both compare physiological transitions and shared clinical outputs.
4. Direct parameter transfer is used only for documentation or adapter experiments, not as the main scientific link.

## 2. Current Results

### Diniya: Zoya Pre-Closure ASD

Accepted run:

`results/calibration/zoya_asd_calib_20260602_011418/zoya_asd_calibration_20260602_011418.mat`

Key accepted outputs:

| Metric | Clinical Target | Accepted Model | Interpretation |
|---|---:|---:|---|
| QpQs | 3.79 | 2.274 | Still underestimates shunt severity, but improved vs baseline. |
| Q_ASD_Lmin | derived comparison | 3.116 L/min | Active LA-to-RA shunt. |
| Qs_Lmin | 3.23 | 2.446 L/min | Low systemic output. |
| Qp_Lmin | 12.27 | 5.562 L/min | Pulmonary flow still much lower than target. |
| SAP_mean | 90 | 84.78 mmHg | Guard passed. |
| PAP_mean | 23 | 19.07 mmHg | Mild residual mismatch. |
| LAP_mean | 14 | 7.93 mmHg | Major residual bottleneck. |
| RMSE | NA | 0.3507 | Accepted by current gates, not a near-perfect fit. |

Important interpretation:

- This is a difficult pre-closure disease state with active shunt physiology.
- Zoya pre-closure has pressure-flow targets but lacks pre-closure LV/RV volumes, EF, and RAP.
- The accepted result is scientifically useful because it passes validity and clinical-fit guards, not because every target is matched.

### Jovano: Zoya Post-Closure ASD

User-reported post-closure performance:

| Stage | RMSE/MSRE | Summary |
|---|---:|---|
| Baseline | 0.0053 | Already very close to clinical post-closure targets. |
| Calibrated | 0.0015 | Excellent fit to post-closure CO, ventricular volumes/EF, Qp/Qs, and PAP_mean. |

Important interpretation:

- Jovano's post-closure state is a closed-shunt problem.
- The data include LV/RV volume and EF targets, which strongly constrain ventricular parameters.
- The baseline is already near the post-closure target, so calibration only needs small local adjustments.

## 3. Why Jovano's RMSE Can Be Much Lower

This is not because Jovano's model is automatically "better" or because Diniya's result is invalid. The calibration problem is easier.

### 3.1 Post-closure is physiologically simpler

In Jovano's code, `config/patient_post_asd_parameters.m` sets:

```matlab
params.R_ASD = 1e9;
```

This effectively closes the ASD. In `models/asd_shunt_model.m`, if `R_ASD` is infinite, shunt flow is zero. Therefore the model is close to a healthy closed-loop circulation where `Qp/Qs` naturally approaches 1.

Pre-closure Diniya must reproduce a large active ASD shunt, elevated pulmonary flow, and atrial pressure coupling. That is much harder.

### 3.2 Jovano has stronger post-closure targets

Jovano's objective includes:

- HR
- CO
- LVEDV, LVESV, LVSV, LVEF
- RVEDV, RVESV, RVSV, RVEF
- Qp/Qs
- PAP_mean

These targets directly constrain chamber mechanics. Diniya's pre-closure Zoya data do not include LV/RV volume or EF targets, so ventricular parameters are weakly identifiable and must remain prediction-only or exploratory.

### 3.3 Jovano's baseline is already patient-shaped

Jovano's `patient_post_asd_parameters.m` is not a raw adult baseline. It already contains:

- patient anthropometry and HR override;
- ventricular elastance multipliers;
- vascular multipliers;
- fixed optimized-looking values for `R_pc`, `C_pv`, and `C_pa`;
- closed ASD;
- initial conditions placed near post-closure clinical LVEDV/RVEDV.

This explains why the baseline RMSE can already be extremely low. It is a post-closure patient-specific baseline, not a disease-naive starting point.

### 3.4 Jovano's optimization is lower-dimensional

In `run_pipeline.m`, Jovano selects the top 4 parameters from aggregate Sobol ST and optimizes only those. Diniya's Zoya pre-closure problem needed a larger exploratory set because the shunt, atrial pressure gradient, venous reservoir, and vascular pressure-flow balance are coupled.

## 4. Why Direct Parameter Transfer Is Not the Right Main Handoff

Directly sending Diniya's accepted ASD parameter values to Jovano is not sufficient because the namespaces and meanings differ.

| Concept | Diniya code | Jovano code | Direct numeric transfer? |
|---|---|---|---|
| LV active/passive mechanics | `E.LV.EA`, `E.LV.EB` | `Emax_lv`, `Emin_lv` | Not directly safe. |
| RV active/passive mechanics | `E.RV.EA`, `E.RV.EB` | `Emax_rv`, `Emin_rv` | Not directly safe. |
| ASD shunt | orifice or linear mode, `asd.Cd`/`R.asd` | linear `R_ASD` | Only conceptually comparable. |
| Vascular parameters | nested fields such as `R.SAR`, `R.PCOX` | flat fields such as `R_sa`, `R_pc` | Requires explicit adapter. |
| Objective tiers | primary/secondary/prediction-only | MSRE over selected clinical targets | Different objective design. |

So the main handoff should not be "copy these calibrated numbers". The main handoff should be "here is my accepted pre-closure operating point, here are its outputs, and here is how closure should physiologically change the system."

## 5. What Diniya Should Send to Jovano

### Required pre-closure package

Send these files or a zipped folder:

1. `zoya_asd_calibration_20260602_011418.mat`
   - contains `pkg.accepted_params`, `pkg.params0`, `pkg.accepted_metrics`, `pkg.target_tiers`, `pkg.caseProfile`, rollback/accept status, and RMSE.

2. `zoya_asd_calibrated_20260602_011418.csv`
   - 26-output accepted model table with target, output tier, error, and status.

3. `zoya_asd_baseline_20260602_011418.csv`
   - baseline comparison before calibration.

4. `console_20260602_011418.log`
   - exact calibration trace, gates, rollback/accept decision, and parameter plausibility.

5. A short README/handoff note containing:
   - patient: Zoya;
   - scenario: pre_surgery / pre_closure;
   - scaling mode;
   - HR, BSA, weight, height used;
   - ASD mode and sign convention;
   - accepted RMSE and gate status;
   - list of calibrated parameters and bounds;
   - statement that pre-closure volume/EF targets are missing.

### Optional but useful

1. A parameter-change summary table:
   - parameter name;
   - physiological group;
   - initial value;
   - accepted value;
   - percent change;
   - bounds;
   - plausibility flag.

2. A model-output trace package if available:
   - pressure traces;
   - volume traces;
   - ASD flow trace;
   - PV loops.

3. A "close ASD in Diniya model" simulation:
   - same accepted pre-closure params;
   - set ASD closed in Diniya's own model;
   - compare acute closure prediction against Jovano's chronic post-closure model.

## 6. What Jovano Should Send Back

Jovano should send a symmetric post-closure package:

1. `post_params.mat`
   - final post-closure parameter struct and initial conditions.

2. `post_baseline_metrics.csv`
   - baseline post-closure model outputs before calibration.

3. `post_calibrated_metrics.csv`
   - calibrated post-closure outputs.

4. `post_calibration_log.txt`
   - selected parameters, initial/final values, bounds, objective value, exit flag.

5. `post_method_summary.md`
   - data sources;
   - targets included in objective;
   - whether values are patient-specific or cohort-derived;
   - whether baseline contains manual overrides before optimization.

This matters because Jovano's baseline appears already strongly patient-shaped. That is acceptable if documented, but it must not be described as raw uncalibrated physiology.

## 7. Unified Workflow Strategy

The best strategy is a unified methodology, not necessarily one identical MATLAB codebase immediately.

### Phase 1: Agree on shared output contract

Both models should export the same clinical comparison table columns:

- Patient_ID
- Scenario
- Timepoint
- Metric
- Unit
- Clinical_Target
- Model_Output
- Error_pct
- Target_Type
- Source
- Output_Tier
- IncludeInObjective
- Notes

This solves the biggest thesis problem: results can be compared even when internal parameter names differ.

### Phase 2: Keep model-specific calibration

Diniya:

`adult baseline -> pediatric scaling -> ASD clinical seeding -> pre-closure baseline -> GSA -> staged calibration -> accepted pre-closure operating point`

Jovano:

`adult baseline -> pediatric scaling -> post-closure profile -> post-closure baseline -> GSA -> optimization -> accepted post-closure operating point`

Both can be valid as long as:

- targets are declared;
- missing data are excluded;
- parameter selection is documented;
- acceptance criteria are explicit.

### Phase 3: Add a bridge analysis

The bridge analysis is:

`Diniya accepted pre-closure params -> numerically close ASD in Diniya model -> acute post-closure prediction -> compare direction/trend with Jovano chronic post-closure calibrated state`

This is not expected to perfectly match Jovano's post-closure clinical data if there is a time gap between measurements.

### Phase 4: Only later build a code adapter

If Jovano wants to import Diniya's parameters, create an explicit adapter such as:

`import_diniya_pre_to_jovano_adapter.m`

But this adapter should map only fields with verified equivalent meaning. Unknown or non-equivalent fields should be left unmapped and documented.

## 8. Handling the Time Gap Between Pre and Post Data

This is scientifically important.

Pre-closure and post-closure data are not necessarily the same physiological state separated only by "ASD open" vs "ASD closed". If there is a time gap, then post-closure data may include:

- recovery/remodeling of RV volume overload;
- different HR;
- different loading conditions;
- growth or body-size change;
- different measurement conditions;
- different imaging/catheterization methods.

Therefore the workflow should distinguish two questions:

### Question A: Acute closure mechanism

"If the pre-closure operating point is closed immediately in the same model, do shunt flow and Qp/Qs normalize, and does RV load decrease?"

This tests mechanism.

### Question B: Chronic post-closure fit

"After the real clinical time gap, can a post-closure model match the measured post-closure echo/hemodynamic state?"

This tests patient-specific post-closure calibration.

These are both useful, but they are not the same validation. Diniya's accepted pre-closure parameters should not be expected to directly reproduce Jovano's post-closure clinical values without remodeling or re-calibration.

## 9. How to Explain the RMSE Difference in Thesis Discussion

Suggested wording:

> The pre-closure and post-closure calibration problems were not equally constrained. The pre-closure model was fitted to sparse pressure-flow data in the presence of an active ASD shunt, while ventricular volume and ejection fraction targets were unavailable. In contrast, the post-closure model represented a closed-shunt circulation and was fitted to LV/RV volume and functional targets, which directly constrain chamber elastance and unstressed-volume parameters. Therefore, the much lower post-closure RMSE reflects a better-constrained and physiologically simpler fitting problem, not necessarily a superior model structure.

## 10. Recommended Next Steps

### Step 1: Freeze Diniya's Zoya pre-closure package

Do not keep modifying Zoya pre-closure calibration while moving to Indira. Mark the current accepted result as:

`Zoya_PreClosure_Diniya_v4_Accepted_20260602_011418`

### Step 2: Ask Jovano for a reproducibility package

Ask for:

- exact code commit or timestamp;
- post-closure parameter file;
- baseline and calibrated outputs;
- objective definition;
- selected parameters and bounds;
- whether the baseline file includes manual/patient-specific overrides before optimization.

### Step 3: Build a shared comparison workbook

One workbook should compare:

- Diniya pre-closure accepted;
- Diniya acute-closure prediction, if run;
- Jovano post-closure baseline;
- Jovano post-closure calibrated.

Rows should be metrics; columns should be model/timepoint.

### Step 4: Run Diniya acute closure simulation in Diniya's own code

This is the safest bridge because it avoids cross-code parameter mismatch.

Expected qualitative checks:

- Q_ASD approaches zero;
- Qp/Qs approaches 1;
- RV stroke volume and RVEDV decrease from pre-closure;
- pulmonary flow decreases;
- LV filling may improve or move toward post-closure values;
- pressures remain physiologically valid.

### Step 5: Compare with Jovano as trend, not exact match

Because of the time gap, do not demand exact equality. Compare:

- direction of change;
- order of magnitude;
- whether post-closure Qp/Qs is near 1;
- whether RV overload decreases;
- whether LV/RV volumes move toward Jovano's measured post-closure state.

## 11. Bottom-Line Recommendation

Do not send only the accepted ASD parameter values and ask Jovano to run them directly.

Send a reproducible pre-closure result package plus a shared metric table. Then connect the two models with a bridge analysis:

`pre-closure accepted state -> ASD numerically closed -> acute closure prediction -> compare with Jovano post-closure calibrated state`

This preserves scientific traceability, respects the different code structures, and gives the thesis a stronger story: Diniya models the pathological pre-closure shunt state, Jovano models the recovered post-closure state, and the bridge analysis tests whether the transition direction is physiologically coherent.
