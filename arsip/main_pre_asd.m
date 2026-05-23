% MAIN_PRE_ASD
% -----------------------------------------------------------------------
% Entry point for the PEDIATRIC ASD PRE-OPERATIVE 0D cardiovascular
% simulation. This file is the pre-op counterpart to main.m (post-op).
%
% Design rationale — WHY a separate file instead of modifying main.m:
%   - main.m is the validated post-op entry point; modifying it risks
%     breaking a working pipeline while the pre-op config is still
%     uncalibrated.
%   - A parallel entry point keeps the two scenarios independently
%     runnable, comparable, and version-controllable.
%   - When both are eventually calibrated, they can be refactored into
%     a shared runner if desired.
%
% STRUCTURE: identical to main.m. Only two things differ:
%   1. Parameters are loaded from patient_pre_asd_parameters()
%   2. Clinical validation targets are pre-op estimates (not post-op)
%
% USAGE:
%   >> main_pre_asd
%
% SCENARIO:
%   Pre-op ASD — params.R_ASD = 5.0 mmHg·s/mL (open shunt, L→R flow)
%
% STATUS: SCAFFOLD — not yet calibrated. Simulation will run to steady
%   state, but outputs are NOT validated against clinical data yet.
%   Calibration is a separate subsequent step.
%
% EXPECTED PRE-OP FINGERPRINTS (qualitative, before calibration):
%   - Qp/Qs     > 1.0    (active L→R shunt; target ~1.5–2.5)
%   - RV_EDV    > LV_EDV (RV volume overload)
%   - P_pa_mean > 15 mmHg (mildly elevated pulmonary pressure)
%   - CO_systemic < CO_pulmonary (blood recirculates through shunt)
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter ASD model.
%   [2] Arvidsson et al. (2026). Pediatric ASD cohort data.
%   See docs/theory_notes.md for governing equations.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-03-20
% VERSION:  0.1 — pre-calibration scaffold
% -----------------------------------------------------------------------

clear; clc; close all;

%% ── 1. ADD PATHS ────────────────────────────────────────────────────────

addpath(fullfile(pwd, 'config'));
addpath(fullfile(pwd, 'models'));
addpath(fullfile(pwd, 'solvers'));
addpath(fullfile(pwd, 'utils'));
addpath(fullfile(pwd, 'tests'));

%% ── 2. LOAD PRE-OP PARAMETERS AND INITIAL CONDITIONS ───────────────────
% patient_pre_asd_parameters.m calls default_parameters() → pediatric_scaling()
% → patient-specific overrides, with R_ASD = 5.0 (finite, shunt open).

[params, X0] = patient_pre_asd_parameters();

fprintf('Running PRE-OP ASD simulation for pediatric patient...\n');
fprintf('  Scenario:  ASD pre-operative (shunt OPEN)\n');
fprintf('  R_ASD  = %.2f [mmHg.s/mL]  (finite -> active shunt)\n', params.R_ASD);
fprintf('  HR     = %.0f bpm\n',  params.HR);
fprintf('  Cycles: %d total, %d warm-up\n', params.n_cycles, params.n_warmup);

%% ── 3. INTEGRATE SYSTEM ─────────────────────────────────────────────────

[t_sol, X_sol, t_ss, X_ss] = integrate_system(params, X0);

%% ── 4. COMPUTE CLINICAL INDICES ──────────────────────────────────────────

indices = compute_clinical_indices(t_ss, X_ss, params);

%% ── 4b. ATRIAL PRESSURE + SHUNT DIAGNOSTICS ─────────────────────────────
% Runs automatically every execution. Reports LAP_mean, RAP_mean,
% LAP-RAP gradient, and mean/peak Q_shunt_asd.
% If LAP-RAP < 1 mmHg, the shunt is gradient-limited (not R_ASD-limited).

diag = diagnose_atrial_pressures(t_ss, X_ss, params);

%% ── 5. PRE-OP QUALITATIVE VALIDATION TARGETS ─────────────────────────────
% These are PHYSIOLOGICALLY MOTIVATED RANGES, not yet calibrated to a
% specific patient. They encode what pre-op ASD haemodynamics should look
% like qualitatively. Failing any of these is a model-level red flag.
%
% Source: Arvidsson et al. (2026) pre-closure cohort; general ASD physiology
%   literature (Geva T et al. Lancet 2014; Webb G et al. Circulation 2010).

fprintf('\n=== PRE-OP QUALITATIVE VALIDATION CHECKS ===\n');
fprintf('(These are physiological ranges, NOT yet patient-calibrated targets)\n');

pass_count = 0;
fail_count = 0;

% Check 1: Qp/Qs > 1 — fundamental fingerprint of active L→R shunt
qpqs = indices.Q_ratio;
if qpqs > 1.0
    fprintf('  [PASS] Qp/Qs = %.3f  (> 1.0 — L to R shunt active)\n', qpqs);
    pass_count = pass_count + 1;
else
    fprintf('  [FAIL] Qp/Qs = %.3f  (should be > 1.0 for pre-op ASD)\n', qpqs);
    fail_count = fail_count + 1;
end

% Check 2: RV_EDV > LV_EDV — RV volume overload
rv_edv = indices.V_rv_ed;
lv_edv = indices.V_lv_ed;
if rv_edv > lv_edv
    fprintf('  [PASS] RV_EDV (%.1f mL) > LV_EDV (%.1f mL)  (RV volume overload)\n', rv_edv, lv_edv);
    pass_count = pass_count + 1;
else
    fprintf('  [FAIL] RV_EDV (%.1f mL) not > LV_EDV (%.1f mL) [expected RV dilation]\n', rv_edv, lv_edv);
    fail_count = fail_count + 1;
end

% Check 3: P_pa_mean in 12–30 mmHg (mildly elevated; no PAH)
ppa = indices.P_pa_mean;
if ppa >= 12 && ppa <= 30
    fprintf('  [PASS] P_pa_mean = %.1f mmHg  (range 12-30 mmHg; mild elevation expected)\n', ppa);
    pass_count = pass_count + 1;
else
    fprintf('  [FAIL] P_pa_mean = %.1f mmHg  (OOR [12-30]; check pulmonary resistance)\n', ppa);
    fail_count = fail_count + 1;
end

% Check 4: Qs (CO_systemic) in 2.5–5.5 L/min for this age/HR
qs = indices.CO_systemic;
if qs >= 2.5 && qs <= 5.5
    fprintf('  [PASS] CO_systemic = %.2f L/min  (range 2.5-5.5 L/min for age 10)\n', qs);
    pass_count = pass_count + 1;
else
    fprintf('  [FAIL] CO_systemic = %.2f L/min  (OOR [2.5-5.5]; check LV function)\n', qs);
    fail_count = fail_count + 1;
end

% Check 5: LV_EF in 0.50–0.75 (LV should be grossly normal pre-op)
ef_lv = indices.EF_lv;
if ef_lv >= 0.50 && ef_lv <= 0.75
    fprintf('  [PASS] LV_EF = %.2f  (range 0.50-0.75; LV function preserved)\n', ef_lv);
    pass_count = pass_count + 1;
else
    fprintf('  [FAIL] LV_EF = %.2f  (OOR [0.50-0.75]; check LV elastance)\n', ef_lv);
    fail_count = fail_count + 1;
end

fprintf('\n--- Pre-op qualitative checks: %d/%d passed ---\n', pass_count, pass_count + fail_count);
if fail_count == 0
    fprintf('All qualitative fingerprints consistent with pre-op ASD physiology.\n');
    fprintf('NOTE: Quantitative calibration against patient data is still pending.\n');
else
    fprintf('WARNING: %d check(s) failed. Review elastance / R_ASD / initial conditions.\n', fail_count);
    fprintf('Failing checks indicate model-level issues, not calibration drift.\n');
end

%% ── 6. FULL RESULTS TABLE ────────────────────────────────────────────────
% Side-by-side reference:   Simulated | Pre-op physiology range
% Column 3 shows literature-derived expected ranges.
% No "dummy patient" column yet — calibration will add that in Step 3.

fprintf('\n=== SIMULATED INDICES (Pre-op ASD Scaffold) ===\n');
fprintf('%-20s  %10s  %s\n', 'Metric', 'Simulated', 'Expected range (pre-op)');
fprintf('%s\n', repmat('-', 1, 55));
fprintf('%-20s  %10.1f  %s\n', 'LV_EDV [mL]',    indices.V_lv_ed,    '~70-110 (pre-op normal or mild increase)');
fprintf('%-20s  %10.1f  %s\n', 'LV_ESV [mL]',    indices.V_lv_es,    '~25-50');
fprintf('%-20s  %10.1f  %s\n', 'LV_SV [mL]',     indices.SV_lv,      '~45-70');
fprintf('%-20s  %10.1f  %s\n', 'LV_EF [%%]',      indices.EF_lv*100,  '50-75%%');
fprintf('%-20s  %10.1f  %s\n', 'RV_EDV [mL]',    indices.V_rv_ed,    '~110-180 (dilated; >LV_EDV)');
fprintf('%-20s  %10.1f  %s\n', 'RV_ESV [mL]',    indices.V_rv_es,    '~50-90');
fprintf('%-20s  %10.1f  %s\n', 'RV_SV [mL]',     indices.SV_rv,      '~70-120 (elevated; Qp>Qs)');
fprintf('%-20s  %10.1f  %s\n', 'RV_EF [%%]',      indices.EF_rv*100,  '40-60%%');
fprintf('%-20s  %10.2f  %s\n', 'CO_sys [L/min]', indices.CO_systemic,'2.5-5.5');
fprintf('%-20s  %10.2f  %s\n', 'CO_pulm [L/min]',indices.Q_pulmonary,'4.0-10.0 (Qp elevated)');
fprintf('%-20s  %10.3f  %s\n', 'Qp/Qs',          indices.Q_ratio,    '>1.0 (target ~1.5-2.5)');
fprintf('%-20s  %10.1f  %s\n', 'P_ao_sys [mmHg]',indices.P_ao_sys,   '90-130');
fprintf('%-20s  %10.1f  %s\n', 'P_ao_dia [mmHg]',indices.P_ao_dia,   '55-85');
fprintf('%-20s  %10.1f  %s\n', 'P_pa_mean [mmHg]',indices.P_pa_mean, '12-30 (mildly elevated)');
fprintf('%-20s  %10.3f  %s\n', 'SVR [mmHg.s/mL]',indices.SVR,        '~1.2-2.5 (normal sys resist)');
fprintf('%-20s  %10.3f  %s\n', 'PVR [mmHg.s/mL]',indices.PVR,        '~0.05-0.20 (low; no PAH)');
fprintf('%s\n', repmat('-', 1, 55));

%% ── 7. GENERATE FIGURES ──────────────────────────────────────────────────

plotting_tools(t_ss, X_ss, indices, params);

fprintf('\nPre-op simulation complete. Calibration step is PENDING.\n');
