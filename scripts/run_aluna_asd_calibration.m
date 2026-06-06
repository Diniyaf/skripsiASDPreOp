%% run_aluna_asd_calibration.m
% RUN_ALUNA_ASD_CALIBRATION
% -------------------------------------------------------------------------
% Staged calibration wrapper for Patient Aluna ASD pre-closure.
% 1yr 5mo female, large secundum ASD (17.55 mm), sparse pressure-only
% clinical data. Aluna has no reported Qp/Qs, Qp, Qs, LAP, RAP, direct
% shunt flow, or LA-RA pressure gradient. The clinical seeding path should
% therefore use geometry/orifice ASD mode when diameter is available, and
% target-tier governance should exclude missing flow/atrial targets.
%
% Calibration stages (VSD-adapted):
%   Stage A - Vascular + shunt (Group A parameters, GSA-masked)
%   Stage B - SKIPPED (no ventricular volume/function targets)
%   Stage C - Joint polish (top-GSA parameters from all groups, dynamic)
%
% Active set is built from the latest curated ASD GSA using Sobol ST plus
% target-tier governance, mirroring the unified VSD mask-based workflow.
% Group C ventricular parameters remain monitor-only unless explicitly
% enabled with ASD_CALIB_ALLOW_GROUPC=1.
% Post-calibration: separate plausibility stage + 3-level rollback.
%
% WORKFLOW:
%   adult healthy baseline
%   -> pediatric scaling (Lundquist BSA)
%   -> ASD clinical seeding -> params0_ASD_pre
%   -> curated ASD GSA
%   -> active mask from ST + target tiers
%   -> Stage A: selected shunt/vascular/preload calibration
%   -> Stage C: optional exploratory Group C polish if explicitly enabled
%   -> Post-cal: validity (11 gates) -> plausibility -> rollback (3-level)
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-31
% VERSION:  3.0  (curated GSA active mask + secondary guards)
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
restoredefaultpath;
addpath(project_root);
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

%% ========================================================================
%  OUTPUT PATHS
%% ========================================================================
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(project_root, 'results', 'calibration');
run_dir = fullfile(output_dir, sprintf('aluna_asd_calib_%s', timestamp));
if ~exist(run_dir, 'dir'), mkdir(run_dir); end
diary_file = fullfile(run_dir, sprintf('console_%s.log', timestamp));
diary(diary_file); diary on;

%% ========================================================================
%  CONFIGURATION
%% ========================================================================
ST_THRESHOLD          = 0.10;     % Sobol ST threshold aligned with curated ASD GSA report
STAGE_A_SUCCESS_RMSE  = 0.10;     % Stage 1 accepted if primary RMSE < 10%
MAX_FUN_EVALS_A       = 2500;     % fmincon budget Stage A
MAX_FUN_EVALS_C       = 1500;     % fmincon budget Stage C
MAX_ITERATIONS        = 200;      % fmincon iteration budget
OPTIMALITY_TOL        = 1e-5;
STEP_TOL              = 1e-6;
PLAUSIBILITY_LAMBDA   = 0.50;
BOUNDARY_LAMBDA       = 20.0;
PRIMARY_TARGET_PCT    = 0.05;     % 5% clinical acceptance
SECONDARY_TARGET_PCT  = 0.15;     % 15% guard band for measured waveform targets
SECONDARY_LAMBDA      = 0.35;     % lower weight than primary pressure-flow targets
MAX_PRIMARY_WORSENING_PCT = 5.0;  % reject if an already-good primary target degrades
MAX_SECONDARY_WORSENING_PCT = 5.0; % reject if measured guards degrade strongly

%% ========================================================================
%  LOAD BASELINE + GSA RESULTS
%% ========================================================================
fprintf('=== Loading Patient Aluna ASD baseline + GSA ===\n');
fprintf('  MODE: sparse pressure-only ASD case; shunt mode resolved by clinical seeding.\n');
fprintf('  Target policy: only finite clinical targets are fitted; missing flow/atrial targets remain prediction-only.\n\n');

ctx_options = struct('scaling_mode', 'lundquist_bsa', ...
    'runBaselineSimulation', false);
ctx = run_asd_patient_case(@patient_aluna, 'aluna', 'pre_surgery', ctx_options);
clinical = ctx.clinical;
params0 = ctx.params0;
caseProfile = ctx.caseProfile;

fprintf('  Age: %.1f yr | Weight: %.1f kg | BSA: %.3f m2 | HR: %d bpm\n', ...
    clinical.common.age_years, clinical.common.weight_kg, ...
    clinical.common.BSA, clinical.common.HR);

% Load GSA results (prefer latest curated GSA, fallback to legacy full GSA)
gsa_dir = fullfile(project_root, 'results', 'tables');
gsa_files = dir(fullfile(gsa_dir, 'aluna_asd_gsa_curated_*.mat'));
if isempty(gsa_files)
    gsa_files = dir(fullfile(gsa_dir, 'aluna_asd_gsa_*_*.mat'));
end
if isempty(gsa_files)
    error('No GSA results found. Run scripts/run_aluna_asd_gsa_curated.m first.');
end
[~, idx] = sort(cell2mat({gsa_files.datenum}), 'descend');
gsa_data = load(fullfile(gsa_files(idx(1)).folder, gsa_files(idx(1)).name));
fprintf('  GSA loaded: %s (N=%d, %d params)\n', ...
    gsa_files(idx(1)).name, gsa_data.cfg.N, numel(gsa_data.sobol.Parameter));

%% ========================================================================
%  BUILD CANDIDATE REGISTRY + OPTIMIZATION MASK
%% ========================================================================
fprintf('\n=== Building candidate parameters + GSA mask ===\n');

candidate_report = ctx.candidate_report;
all_params = ctx.curated_library;
param_names_all = cellstr(all_params.Parameter);
x0_all = all_params.Initial_Value;
lb_all = all_params.Lower_Bound;
ub_all = all_params.Upper_Bound;
group_all = cellstr(all_params.Group);

target_tiers = ctx.target_tiers;
allow_group_c = resolve_allow_group_c();
[active_selection, optMask] = build_asd_active_mask_from_gsa( ...
    gsa_data, all_params, target_tiers, struct( ...
    'Threshold', ST_THRESHOLD, ...
    'MinActive', 4, ...
    'MaxActive', 8, ...
    'AllowGroupC', allow_group_c, ...
    'UseSecondaryGuards', true, ...
    'CaseProfile', caseProfile));

% Build ST_max from GSA data (needed before mask expansion below)
ST_max = zeros(numel(param_names_all), 1);
gsa_param_names = gsa_data.sobol.Parameter;
for i = 1:numel(param_names_all)
    g_idx = find(strcmp(gsa_param_names, param_names_all{i}), 1);
    if ~isempty(g_idx)
        st_row = gsa_data.sobol.ST(g_idx, :);
        ST_max(i) = max(st_row(isfinite(st_row)));
    end
end

% Force active shunt parameter into mask (mode-aware: asd.Cd or R.asd).
shunt_mode = lower(char(params0.asd.mode));
if strcmp(shunt_mode, 'orifice_bidirectional')
    shunt_force = 'asd.Cd';
else
    shunt_force = 'R.asd';
end
shunt_idx = find(strcmp(param_names_all, shunt_force), 1);
if ~isempty(shunt_idx) && ~optMask(shunt_idx)
    optMask(shunt_idx) = true;
    fprintf('  %s forced into active set (shunt knob, %s mode).\n', shunt_force, shunt_mode);
end

% Aluna has no measured LAP/RAP or shunt-flow targets, so atrial/preload
% parameters are not force-added from the Zoya exploration. They enter only
% if supported by the patient-generic GSA active-mask rule below.

% Expand mask: ensure >=5 non-ventricular params for sufficient coverage.
nv_mask = optMask & ~startsWith(string(group_all), "C_");
if sum(nv_mask) < 5
    remaining = find(~optMask & ~startsWith(string(group_all), "C_"));
    [~, order] = sort(ST_max(remaining), 'descend');
    add_n = min(5 - sum(nv_mask), numel(remaining));
    optMask(remaining(order(1:add_n))) = true;
    fprintf('  Expanded mask by %d param(s) to reach min 5 non-ventricular.\n', add_n);
end

% Rebuild stage assignments from updated optMask.
stageA_mask = optMask & ~startsWith(string(group_all), "C_");
stageC_mask = optMask & startsWith(string(group_all), "C_");
stageA_names_expected = param_names_all(stageA_mask);
stageC_names_expected = param_names_all(stageC_mask);
stageA_names_expected = reshape(stageA_names_expected, 1, []);
stageC_names_expected = reshape(stageC_names_expected, 1, []);
stageA_loc = find(stageA_mask);
stageC_loc = find(stageC_mask);

fprintf('  GSA ST threshold for evidence review: %.2f\n', ST_THRESHOLD);
fprintf('  Curated active-mask calibration parameters: %d/%d\n', ...
    sum(optMask), numel(param_names_all));
for i = 1:numel(param_names_all)
    if optMask(i)
        fprintf('    %-12s  ST=%.3f  Group=%s\n', ...
            param_names_all{i}, ST_max(i), group_all{i});
    end
end

fprintf('\n  Stage A (selected non-ventricular ASD parameters): %d params (%s)\n', ...
    numel(stageA_names_expected), strjoin(stageA_names_expected, ', '));
fprintf('  Stage C exploratory Group C enabled: %s\n', iif(allow_group_c, 'YES', 'NO'));
fprintf('  Stage C exploratory candidates if enabled and selected: %d params (%s)\n', ...
    numel(stageC_names_expected), strjoin(stageC_names_expected, ', '));

%% ========================================================================
%  CLINICAL TARGETS
%% ========================================================================
calib_cfg = struct();
[calib_cfg.targets, calib_cfg.targetFields] = targets_from_tiers(target_tiers, ...
    'hard_primary');
[calib_cfg.secondaryTargets, calib_cfg.secondaryTargetFields] = targets_from_tiers( ...
    target_tiers, 'soft_secondary_guard');
calib_cfg.primaryTarget   = PRIMARY_TARGET_PCT;
calib_cfg.secondaryTarget = SECONDARY_TARGET_PCT;
calib_cfg.secondaryLambda = SECONDARY_LAMBDA;
calib_cfg.plausibilityLambda = PLAUSIBILITY_LAMBDA;
calib_cfg.boundaryLambda     = BOUNDARY_LAMBDA;
calib_cfg.mapBand = map_band_from_target(calib_cfg.targets);
calib_cfg.caseProfile = caseProfile;
calib_cfg.simOverrides.nCyclesSteady = 40;
calib_cfg.simOverrides.ss_tol_P = 0.5;
calib_cfg.simOverrides.ss_tol_V = 0.5;
calib_cfg.metricWeights = struct();

fprintf('\n  Clinical targets:\n');
for i = 1:numel(calib_cfg.targetFields)
    fn = calib_cfg.targetFields{i};
    fprintf('    %s = %.4g\n', fn, calib_cfg.targets.(fn));
end
fprintf('  Secondary measured guards:\n');
for i = 1:numel(calib_cfg.secondaryTargetFields)
    fn = calib_cfg.secondaryTargetFields{i};
    fprintf('    %s = %.4g\n', fn, calib_cfg.secondaryTargets.(fn));
end

%% ========================================================================
%  BASELINE SIMULATION
%% ========================================================================
fprintf('\n=== Baseline simulation ===\n');
params_tmp = apply_sim_overrides(params0, calib_cfg.simOverrides);
sim_base = integrate_system(params_tmp);
metrics_base = compute_clinical_indices(sim_base, params_tmp);
calib_cfg.guardBaselineMetrics = metrics_base;

fprintf('  %-12s %10s %10s %10s\n', 'Metric', 'Model', 'Target', 'Error%%');
base_errors = zeros(numel(calib_cfg.targetFields), 1);
for i = 1:numel(calib_cfg.targetFields)
    fn = calib_cfg.targetFields{i};
    mv = metrics_base.(fn);
    tv = calib_cfg.targets.(fn);
    err = abs(mv - tv) / max(abs(tv), 1e-6) * 100;
    base_errors(i) = err;
    fprintf('  %-12s %10.4g %10.4g %9.1f%%\n', fn, mv, tv, err);
end
rmse_baseline = sqrt(mean((base_errors / 100).^2));
fprintf('  Baseline RMSE: %.4f\n', rmse_baseline);

calib_cfg.metricWeights = metric_weights_from_baseline(metrics_base, calib_cfg);
fprintf('  Primary metric weights from baseline error:\n');
for i = 1:numel(calib_cfg.targetFields)
    fn = calib_cfg.targetFields{i};
    fprintf('    %-12s weight = %.2f\n', fn, calib_cfg.metricWeights.(fn));
end

%% ========================================================================
%  OPTIMIZER CONFIG
%% ========================================================================
optsA = optimoptions('fmincon', 'Algorithm', 'interior-point', ...
    'HessianApproximation', 'lbfgs', 'FiniteDifferenceType', 'forward', ...
    'FiniteDifferenceStepSize', 1e-5, ...
    'MaxFunctionEvaluations', MAX_FUN_EVALS_A, ...
    'MaxIterations', MAX_ITERATIONS, ...
    'OptimalityTolerance', OPTIMALITY_TOL, ...
    'StepTolerance', STEP_TOL, 'Display', 'iter-detailed', ...
    'UseParallel', resolve_parallel_fmincon());

optsC = optimoptions('fmincon', 'Algorithm', 'interior-point', ...
    'HessianApproximation', 'lbfgs', 'FiniteDifferenceType', 'forward', ...
    'FiniteDifferenceStepSize', 1e-5, ...
    'MaxFunctionEvaluations', MAX_FUN_EVALS_C, ...
    'MaxIterations', MAX_ITERATIONS, ...
    'OptimalityTolerance', OPTIMALITY_TOL, ...
    'StepTolerance', STEP_TOL, 'Display', 'iter-detailed', ...
    'UseParallel', resolve_parallel_fmincon());

%% ========================================================================
%  STAGE A - Vascular + Shunt
%% ========================================================================
fprintf('\n===============================================================\n');
fprintf('  STAGE A - Vascular + Preload + Shunt (%d parameters)\n', numel(stageA_names_expected));
fprintf('===============================================================\n');

namesA = stageA_names_expected;
x0_A = x0_all(stageA_loc);
lb_A = lb_all(stageA_loc);
ub_A = ub_all(stageA_loc);

fprintf('  Active: %s\n', strjoin(namesA, ', '));
fprintf('  x0: [%s]\n', sprintf('%.4g ', x0_A));
fprintf('  lb: [%s]\n', sprintf('%.4g ', lb_A));
fprintf('  ub: [%s]\n', sprintf('%.4g ', ub_A));

calib_cfg.x0Reference = x0_A(:);
f_objA = @(x) objective_calibration_asd(x, params0, calib_cfg, namesA, lb_A, ub_A, ...
    @apply_sim_overrides, @integrate_system, @compute_clinical_indices);

tic;
[xA, fA, efA, outA] = fmincon(f_objA, x0_A, [], [], [], [], lb_A, ub_A, [], optsA);
elapsedA = toc;

fprintf('\n  Stage A complete (%.1f s) | Exit=%d | Iter=%d | Func=%d\n', ...
    elapsedA, efA, outA.iterations, outA.funcCount);
fprintf('  Objective J_A: %.6f (reported separately from RMSE)\n', fA);

% Apply Stage A
paramsA = apply_calibrated_params(params0, namesA, xA);
paramsA = apply_sim_overrides(paramsA, calib_cfg.simOverrides);
simA = integrate_system(paramsA);
metricsA = compute_clinical_indices(simA, paramsA);

fprintf('\n  Stage A metrics vs targets:\n');
fprintf('  %-12s %10s %10s %10s\n', 'Metric', 'Model', 'Target', 'Error%%');
sA_errors = zeros(numel(calib_cfg.targetFields), 1);
for i = 1:numel(calib_cfg.targetFields)
    fn = calib_cfg.targetFields{i};
    mv = metricsA.(fn);
    tv = calib_cfg.targets.(fn);
    err = abs(mv - tv) / max(abs(tv), 1e-6) * 100;
    sA_errors(i) = err;
    fprintf('  %-12s %10.4g %10.4g %9.1f%%\n', fn, mv, tv, err);
end
rmse_A = sqrt(mean((sA_errors / 100).^2));
fprintf('  Stage A RMSE: %.4f (baseline: %.4f, improvement: %.1f%%)\n', ...
    rmse_A, rmse_baseline, max(0, (rmse_baseline - rmse_A) / rmse_baseline * 100));

%% ========================================================================
%  STAGE C - Joint Top-GSA Polish
%% ========================================================================
run_stageC = rmse_A >= STAGE_A_SUCCESS_RMSE && ~isempty(stageC_loc);
if ~run_stageC
    if rmse_A < STAGE_A_SUCCESS_RMSE
        fprintf('\n=== Stage C SKIPPED: Stage A RMSE %.4f < %.4f threshold ===\n', ...
            rmse_A, STAGE_A_SUCCESS_RMSE);
    else
        fprintf('\n=== Stage C SKIPPED (no ventricular extension params available) ===\n');
    end
    paramsC = paramsA;
    simC = simA;
    metricsC = metricsA;
    rmse_C = rmse_A;
    fC = fA;
    xC = xA;
    namesC = namesA;
    stageC_ran = false;
else
    fprintf('\n===============================================================\n');
    fprintf('  STAGE C - Ventricular extension (%d parameters)\n', ...
        numel(stageA_names_expected) + numel(stageC_names_expected));
    fprintf('===============================================================\n');

    namesC = [namesA, stageC_names_expected];
    x0_C = [xA(:); x0_all(stageC_loc)];
    lb_C = [lb_A(:); lb_all(stageC_loc)];
    ub_C = [ub_A(:); ub_all(stageC_loc)];

    fprintf('  Adding to active set: %s\n', strjoin(stageC_names_expected, ', '));
    fprintf('  Total active: %d params\n', numel(namesC));

    calib_cfg.x0Reference = x0_C(:);
    f_objC = @(x) objective_calibration_asd(x, params0, calib_cfg, namesC, lb_C, ub_C, ...
        @apply_sim_overrides, @integrate_system, @compute_clinical_indices);

    tic;
    [xC, fC, efC, outC] = fmincon(f_objC, x0_C, [], [], [], [], lb_C, ub_C, [], optsC);
    elapsedC = toc;

    fprintf('\n  Stage C complete (%.1f s) | Exit=%d | Iter=%d | Func=%d\n', ...
        elapsedC, efC, outC.iterations, outC.funcCount);
    fprintf('  Objective J_C: %.6f (reported separately from RMSE)\n', fC);

    paramsC = apply_calibrated_params(params0, namesC, xC);
    paramsC = apply_sim_overrides(paramsC, calib_cfg.simOverrides);
    simC = integrate_system(paramsC);
    metricsC = compute_clinical_indices(simC, paramsC);

    fprintf('\n  Stage C metrics vs targets:\n');
    fprintf('  %-12s %10s %10s %10s\n', 'Metric', 'Model', 'Target', 'Error%%');
    sC_errors = zeros(numel(calib_cfg.targetFields), 1);
    for i = 1:numel(calib_cfg.targetFields)
        fn = calib_cfg.targetFields{i};
        mv = metricsC.(fn);
        tv = calib_cfg.targets.(fn);
        err = abs(mv - tv) / max(abs(tv), 1e-6) * 100;
        sC_errors(i) = err;
        fprintf('  %-12s %10.4g %10.4g %9.1f%%\n', fn, mv, tv, err);
    end
    rmse_C = sqrt(mean((sC_errors / 100).^2));
    stageC_ran = true;
    fprintf('  Stage C RMSE: %.4f\n', rmse_C);
end

%% ========================================================================
%  POST-CALIBRATION VALIDATION (11 gates, ASD-adapted from VSD)
%% ========================================================================
fprintf('\n=== Post-Calibration Validation (11 gates) ===\n');

% Use Stage C if it ran, otherwise Stage A
if stageC_ran
    validity_params = paramsC;
    validity_sim = simC;
    validity_metrics = metricsC;
else
    validity_params = paramsA;
    validity_sim = simA;
    validity_metrics = metricsA;
end

XV = validity_sim.V;
sidx = validity_params.idx;
vol_idx = [sidx.V_RA sidx.V_RV sidx.V_LA sidx.V_LV ...
           sidx.V_SAR sidx.V_SC sidx.V_SVEN sidx.V_PAR sidx.V_PVEN];
chamber_idx = [sidx.V_RA sidx.V_RV sidx.V_LA sidx.V_LV];

flags = struct();
flags.steady_state_not_reached   = ~isfield(validity_sim,'ss_reached')||~logical(validity_sim.ss_reached);
flags.nonfinite_state            = any(~isfinite(XV(:)));
flags.negative_chamber_volume    = any(any(XV(:, chamber_idx) < 0));
flags.negative_total_volume_state = any(any(XV(:, vol_idx) < 0));
flags.unrealistic_v0_adjusted_volume = any(any(XV(:,sidx.V_LV)-validity_params.V0.LV<-1|...
    XV(:,sidx.V_RV)-validity_params.V0.RV<-1));
flags.flow_collapse = false;
if isfield(validity_metrics,'Qs_Lmin')&&isfield(validity_metrics,'QpQs')
    flags.flow_collapse = isfinite(validity_metrics.QpQs)&&abs(validity_metrics.QpQs)>0&&...
        abs(validity_metrics.Qs_Lmin)<1e-3;
end
flags.pvr_out_of_bounds = metric_oob(validity_metrics,'PVR',0.1,20);
flags.svr_out_of_bounds = metric_oob(validity_metrics,'SVR',0.5,50);
flags.ef_out_of_bounds  = metric_oob(validity_metrics,'LVEF',0.05,0.95)||...
    metric_oob(validity_metrics,'RVEF',0.05,0.95);
flags.asd_geometry_invalid = false;
if isfield(validity_params,'asd')&&isfield(validity_params.asd,'area_mm2')
    flags.asd_geometry_invalid = validity_params.asd.area_mm2<0||validity_params.asd.area_mm2>500;
end
flags.asd_shunt_direction_invalid = false;
if isfield(validity_params,'asd')&&isfield(validity_params.asd,'mode')&&...
        contains(lower(validity_params.asd.mode),'bidirectional')
    try
        [Ph,Qh]=reconstruct_hemodynamic_signals(validity_sim.t(:),validity_sim.V,validity_params);
        reverse_possible=any((Ph.RA-Ph.LA)>1e-6);
        reverse_present=any(Qh.ASD<-1e-6);
        flags.asd_shunt_direction_invalid=reverse_possible&&~reverse_present;
    catch
        if isfield(validity_metrics,'Q_ASD_Lmin')&&isfield(validity_metrics,'QpQs')&&...
                isfinite(validity_metrics.QpQs)
            flags.asd_shunt_direction_invalid=...
                (validity_metrics.Q_ASD_Lmin<0&&abs(validity_metrics.Q_ASD_Lmin)>0.05)||...
                validity_metrics.QpQs<0.9;
        end
    end
end

flag_names = fieldnames(flags);
flag_values = struct2cell(flags); flag_values = cellfun(@logical, flag_values);
validity = struct('flags',flags,'failed_flags',{flag_names(flag_values)},...
    'is_valid',~any(flag_values),'penalty',1e3*sum(flag_values));

fprintf('  Checks (11 total):\n');
for i = 1:numel(flag_names)
    fprintf('    %-40s %s\n', flag_names{i}, iif(~flags.(flag_names{i}),'OK','** FAIL **'));
end
fprintf('  Valid: %s | Penalty: %.0f\n', iif(validity.is_valid,'YES','NO'),validity.penalty);

fit_gate = evaluate_clinical_fit_gate(metrics_base, validity_metrics, calib_cfg, ...
    MAX_PRIMARY_WORSENING_PCT, MAX_SECONDARY_WORSENING_PCT);
fprintf('\n=== Clinical Fit Guard ===\n');
fprintf('  Pass: %s\n', iif(fit_gate.pass, 'YES', 'NO'));
if ~fit_gate.pass
    fprintf('  Primary rejection reasons: %s\n', strjoin(fit_gate.failed_reasons, '; '));
end
if ~isempty(fit_gate.secondary_warnings)
    fprintf('  Secondary waveform warnings (not rejecting):\n');
    for w = 1:numel(fit_gate.secondary_warnings)
        fprintf('    WARNING: %s\n', fit_gate.secondary_warnings{w});
    end
end

%% ========================================================================
%  PARAMETER PLAUSIBILITY (separate stage, like VSD Stage E)
%% ========================================================================
fprintf('\n=== Parameter Plausibility ===\n');

if stageC_ran
    final_params = xC;
    final_names = namesC;
else
    final_params = xA;
    final_names = namesA;
end

[~, ploc] = ismember(final_names, param_names_all);
plausibility = struct();
plausibility.n_ok = 0; plausibility.n_warning = 0; plausibility.n_fail = 0;
plausibility.table_data = {};

fprintf('  %-12s %10s %10s %10s %10s %10s\n', ...
    'Parameter','Initial','Fitted','lb','ub','Flag');
for i = 1:numel(final_names)
    inside = final_params(i)>=lb_all(ploc(i))&&final_params(i)<=ub_all(ploc(i));
    span = max(ub_all(ploc(i))-lb_all(ploc(i)),1e-9);
    near_lower = final_params(i)<=lb_all(ploc(i))+0.10*span;
    near_upper = final_params(i)>=ub_all(ploc(i))-0.10*span;
    if ~inside
        flag = 'FAIL'; plausibility.n_fail = plausibility.n_fail+1;
    elseif near_lower||near_upper
        flag = 'WARNING'; plausibility.n_warning = plausibility.n_warning+1;
    else
        flag = 'OK'; plausibility.n_ok = plausibility.n_ok+1;
    end
    fprintf('  %-12s %10.4g %10.4g %10.4g %10.4g %10s\n', ...
        final_names{i}, x0_all(ploc(i)), final_params(i), ...
        lb_all(ploc(i)), ub_all(ploc(i)), flag);
end
fprintf('\n  Plausibility: %d OK | %d WARNING | %d FAIL\n', ...
    plausibility.n_ok, plausibility.n_warning, plausibility.n_fail);

%% ========================================================================
%  3-LEVEL ROLLBACK (VSD-aligned: best / scientific / accepted)
%% ========================================================================
fprintf('\n=== Rollback Decision (3-level) ===\n');

% Best candidate = lowest RMSE from the staged optimizer. It is always
% exported, even when rollback chooses a different accepted candidate.
best_params_struct = validity_params;
best_metrics = validity_metrics;
best_sim = validity_sim;
best_stage_label = iif(stageC_ran, 'stageC_best_candidate', 'stageA_best_candidate');
best = struct('params', best_params_struct, ...
    'parameter_names', {final_names}, ...
    'parameter_values', final_params, ...
    'rmse', rmse_C, ...
    'metrics', best_metrics, ...
    'validity', validity, ...
    'fit_gate', fit_gate, ...
    'plausibility', plausibility, ...
    'label', best_stage_label);

% Scientific candidate = best among valid+plausible candidates
scientific = best;

% Level 1: best candidate RMSE improvement?
rmse_improved = rmse_C < rmse_baseline;
fprintf('  RMSE: baseline=%.4f, calibrated=%.4f (%s)\n', ...
    rmse_baseline, rmse_C, iif(rmse_improved,'IMPROVED','WORSE'));

% Level 2: validity gates
fprintf('  Validity: %s (%d/11 gates failed)\n', ...
    iif(validity.is_valid,'PASS','FAIL'), numel(validity.failed_flags));

% Level 3: plausibility
fprintf('  Plausibility: %d OK | %d WARNING | %d FAIL\n', ...
    plausibility.n_ok, plausibility.n_warning, plausibility.n_fail);

rollback = false;
rollback_reason = '';

if ~rmse_improved
    rollback = true;
    rollback_reason = sprintf('RMSE worsened (baseline=%.4f, calibrated=%.4f)',...
        rmse_baseline, rmse_C);
elseif ~validity.is_valid
    rollback = true;
    rollback_reason = sprintf('Validity gates failed: %s',...
        strjoin(validity.failed_flags,', '));
elseif ~fit_gate.pass
    rollback = true;
    rollback_reason = sprintf('Clinical fit guard failed: %s', ...
        strjoin(fit_gate.failed_reasons, '; '));
elseif plausibility.n_fail > 0
    rollback = true;
    rollback_reason = sprintf('Parameter plausibility hard failures=%d',...
        plausibility.n_fail);
end

if rollback
    fprintf('\n  ** ROLLBACK **: %s\n', rollback_reason);
    fprintf('  Accepted candidate = baseline (params0_ASD_pre, RMSE=%.4f)\n', rmse_baseline);
    accepted_params = params0;
    accepted_metrics = metrics_base;
    accepted_rmse = rmse_baseline;
    accepted_label = 'accepted_candidate_rollback_to_baseline';
else
    fprintf('\n  ** ACCEPTED **: all gates passed.\n');
    if stageC_ran
        accepted_params = paramsC;
        accepted_metrics = metricsC;
    else
        accepted_params = paramsA;
        accepted_metrics = metricsA;
    end
    accepted_rmse = rmse_C;
    accepted_label = 'accepted_candidate';
end

accepted_candidate = struct('params', accepted_params, ...
    'metrics', accepted_metrics, ...
    'rmse', accepted_rmse, ...
    'label', accepted_label);
if rollback
    best_rejected_candidate = best;
    best_rejected_candidate.rejection_reason = rollback_reason;
else
    best_rejected_candidate = struct();
end

%% ========================================================================
%  FINAL SUMMARY
%% ========================================================================
fprintf('\n===============================================================\n');
fprintf('  CALIBRATION SUMMARY\n');
fprintf('===============================================================\n');
fprintf('  Baseline RMSE:  %.4f\n', rmse_baseline);
fprintf('  Stage A RMSE:   %.4f\n', rmse_A);
if stageC_ran, fprintf('  Stage C RMSE:   %.4f\n', rmse_C); end
fprintf('  Best candidate RMSE:  %.4f\n', rmse_C);
fprintf('  Accepted RMSE:        %.4f\n', accepted_rmse);
fprintf('  Rollback:   %s\n', iif(rollback,'YES','NO'));
fprintf('  Stage C ran: %s\n', iif(stageC_ran,'yes','no'));

%% ========================================================================
%  EXPORT
%% ========================================================================
fprintf('\n=== Exporting Results ===\n');
pkg = struct();
pkg.timestamp = timestamp;
pkg.patient = char(caseProfile.patient_label); pkg.scenario = char(caseProfile.scenario_key);
pkg.params0 = params0; pkg.accepted_params = accepted_params;
pkg.metrics_base = metrics_base; pkg.accepted_metrics = accepted_metrics;
pkg.stageA.rmse = rmse_A; pkg.stageA.names = namesA; pkg.stageA.x = xA;
if stageC_ran
    pkg.stageC.rmse = rmse_C; pkg.stageC.names = namesC; pkg.stageC.x = xC;
end
pkg.optMask = optMask; pkg.ST_max = ST_max;
pkg.active_selection = active_selection;
pkg.target_tiers = target_tiers;
pkg.caseProfile = caseProfile;
pkg.validity = validity; pkg.fit_gate = fit_gate; pkg.plausibility = plausibility;
pkg.rollback = rollback; pkg.rollback_reason = rollback_reason;
pkg.best_candidate = best;
pkg.best_rejected_candidate = best_rejected_candidate;
pkg.accepted_candidate = accepted_candidate;
pkg.accepted_label = accepted_label;
pkg.baseline_rmse = rmse_baseline; pkg.accepted_rmse = accepted_rmse;

mat_file = fullfile(run_dir, sprintf('aluna_asd_calibration_%s.mat', timestamp));
save(mat_file, 'pkg');
fprintf('  MAT saved: %s\n', mat_file);

% Output table (baseline vs calibrated)
fprintf('\n===============================================================\n');
fprintf('  BASELINE OUTPUT TABLE\n');
fprintf('===============================================================\n');
T_base = asd_output_table(sim_base, params0, clinical, 'pre_surgery');

if rollback
    calib_sim = sim_base;
elseif stageC_ran
    calib_sim = simC;
else
    calib_sim = simA;
end
fprintf('\n===============================================================\n');
fprintf('  CALIBRATED OUTPUT TABLE (%s)\n', accepted_label);
fprintf('===============================================================\n');
T_cal  = asd_output_table(calib_sim, accepted_params, clinical, 'pre_surgery');

if rollback
    fprintf('\n===============================================================\n');
    fprintf('  BEST REJECTED CANDIDATE OUTPUT TABLE (%s)\n', best.label);
    fprintf('===============================================================\n');
    T_best = asd_output_table(best_sim, best_params_struct, clinical, 'pre_surgery');
else
    T_best = T_cal;
end

T_best_params = build_parameter_export_table(final_names, final_params, ...
    param_names_all, x0_all, lb_all, ub_all, group_all);
T_decision = build_rollback_decision_table(rollback, rollback_reason, ...
    accepted_label, rmse_baseline, rmse_A, rmse_C, accepted_rmse, ...
    stageC_ran, validity, fit_gate, plausibility);

% Export tables as CSV
csv_base = fullfile(run_dir, sprintf('aluna_asd_baseline_%s.csv', timestamp));
csv_cal  = fullfile(run_dir, sprintf('aluna_asd_calibrated_%s.csv', timestamp));
csv_best = fullfile(run_dir, sprintf('aluna_asd_best_candidate_%s.csv', timestamp));
csv_best_params = fullfile(run_dir, sprintf('aluna_asd_best_candidate_parameters_%s.csv', timestamp));
csv_decision = fullfile(run_dir, sprintf('aluna_asd_rollback_decision_%s.csv', timestamp));
writetable(T_base, csv_base);
writetable(T_cal, csv_cal);
writetable(T_best, csv_best);
writetable(T_best_params, csv_best_params);
writetable(T_decision, csv_decision);
fprintf('\n  Baseline CSV: %s\n', csv_base);
fprintf('  Calibrated CSV: %s\n', csv_cal);
fprintf('  Best candidate CSV: %s\n', csv_best);
fprintf('  Best candidate parameter CSV: %s\n', csv_best_params);
fprintf('  Rollback decision CSV: %s\n', csv_decision);

if rollback
    csv_best_rejected = fullfile(run_dir, sprintf('aluna_asd_best_rejected_candidate_%s.csv', timestamp));
    csv_best_rejected_params = fullfile(run_dir, sprintf('aluna_asd_best_rejected_candidate_parameters_%s.csv', timestamp));
    writetable(T_best, csv_best_rejected);
    writetable(T_best_params, csv_best_rejected_params);
    fprintf('  Best rejected candidate CSV: %s\n', csv_best_rejected);
    fprintf('  Best rejected parameter CSV: %s\n', csv_best_rejected_params);
else
    csv_best_rejected = "";
    csv_best_rejected_params = "";
end

pkg.output_paths = struct('mat_file', string(mat_file), ...
    'baseline_csv', string(csv_base), ...
    'accepted_csv', string(csv_cal), ...
    'best_candidate_csv', string(csv_best), ...
    'best_candidate_parameters_csv', string(csv_best_params), ...
    'rollback_decision_csv', string(csv_decision), ...
    'best_rejected_candidate_csv', string(csv_best_rejected), ...
    'best_rejected_candidate_parameters_csv', string(csv_best_rejected_params));
save(mat_file, 'pkg');
fprintf('  MAT updated with output paths and best candidate structs.\n');

diary off;

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function params = apply_sim_overrides(params, ov)
if isfield(ov,'nCyclesSteady'),params.sim.nCyclesSteady=ov.nCyclesSteady;end
if isfield(ov,'ss_tol_P'),params.sim.ss_tol_P=ov.ss_tol_P;end
if isfield(ov,'ss_tol_V'),params.sim.ss_tol_V=ov.ss_tol_V;end
end

function params = apply_calibrated_params(params0, names, values)
params = params0;
for i = 1:numel(names)
    parts = strsplit(names{i}, '.');
    switch numel(parts)
        case 2, params.(parts{1}).(parts{2}) = values(i);
        case 3, params.(parts{1}).(parts{2}).(parts{3}) = values(i);
    end
end
end

function tf = metric_oob(metrics, fn, lb, ub)
tf = false;
if ~isfield(metrics,fn)||~isfinite(metrics.(fn)),return;end
tf = metrics.(fn)<lb||metrics.(fn)>ub;
end

function s = iif(cond, t, f)
if cond, s = t; else, s = f; end
end

function [targets, fields] = targets_from_tiers(target_tiers, tier_name)
% TARGETS_FROM_TIERS - build target struct from finite tier rows.
if strcmp(tier_name, 'soft_secondary_guard')
    mask = startsWith(target_tiers.Tier, tier_name) & ...
        target_tiers.IncludeInCalibrationLater;
else
    mask = strcmp(target_tiers.Tier, tier_name) & ...
        target_tiers.IncludeInCalibrationLater;
end
rows = target_tiers(mask, :);
targets = struct();
fields = {};
for idx = 1:height(rows)
    field_name = char(rows.ModelField(idx));
    target_value = rows.ClinicalTarget(idx);
    if isfinite(target_value) && ~isfield(targets, field_name)
        targets.(field_name) = target_value;
        fields{end + 1} = field_name; %#ok<AGROW>
    end
end
end

function gate = evaluate_clinical_fit_gate(metrics_base, metrics_final, calib_cfg, ...
    max_primary_worsening_pct, max_secondary_worsening_pct)
% EVALUATE_CLINICAL_FIT_GATE - reject candidates that sacrifice primary targets.
% Secondary waveform metrics generate warnings only (not rejection) because
% systolic/diastolic extrema have high beat-to-beat variability (+/-10-15%).
reasons = {};
secondary_warnings = {};

for idx = 1:numel(calib_cfg.targetFields)
    fn = calib_cfg.targetFields{idx};
    target = calib_cfg.targets.(fn);
    base_err = metric_error_pct(metrics_base, fn, target);
    final_err = metric_error_pct(metrics_final, fn, target);
    if isfinite(base_err) && isfinite(final_err) && ...
            final_err > 15 && final_err > base_err + max_primary_worsening_pct
        reasons{end + 1} = sprintf('%s worsened %.1f%% -> %.1f%%', ...
            fn, base_err, final_err); %#ok<AGROW>
    end
end

for idx = 1:numel(calib_cfg.secondaryTargetFields)
    fn = calib_cfg.secondaryTargetFields{idx};
    target = calib_cfg.secondaryTargets.(fn);
    base_err = metric_error_pct(metrics_base, fn, target);
    final_err = metric_error_pct(metrics_final, fn, target);
    if isfinite(base_err) && isfinite(final_err) && ...
            final_err > 15 && final_err > base_err + max_secondary_worsening_pct
        secondary_warnings{end + 1} = sprintf('%s worsened %.1f%% -> %.1f%%', ...
            fn, base_err, final_err); %#ok<AGROW>
    end
end

gate = struct();
gate.pass = isempty(reasons);
gate.failed_reasons = reasons;
gate.secondary_warnings = secondary_warnings;
end

function err = metric_error_pct(metrics, field_name, target_value)
% METRIC_ERROR_PCT - absolute percent error for one metric.
err = NaN;
if isfield(metrics, field_name) && isfinite(metrics.(field_name)) && ...
        isfinite(target_value) && abs(target_value) > 1e-9
    err = abs(metrics.(field_name) - target_value) / abs(target_value) * 100;
end
end

function T = build_parameter_export_table(names, values, all_names, x0_all, lb_all, ub_all, group_all)
% BUILD_PARAMETER_EXPORT_TABLE - export fitted values and bound status.
n = numel(names);
parameter = strings(n, 1);
group = strings(n, 1);
initial_value = nan(n, 1);
fitted_value = nan(n, 1);
lower_bound = nan(n, 1);
upper_bound = nan(n, 1);
percent_change = nan(n, 1);
bound_position = nan(n, 1);
plausibility_flag = strings(n, 1);

for idx = 1:n
    parameter(idx) = string(names{idx});
    loc = find(strcmp(all_names, names{idx}), 1);
    fitted_value(idx) = values(idx);
    if isempty(loc)
        group(idx) = "missing_from_registry";
        plausibility_flag(idx) = "REVIEW";
        continue;
    end
    group(idx) = string(group_all{loc});
    initial_value(idx) = x0_all(loc);
    lower_bound(idx) = lb_all(loc);
    upper_bound(idx) = ub_all(loc);
    span = max(upper_bound(idx) - lower_bound(idx), 1e-9);
    bound_position(idx) = (fitted_value(idx) - lower_bound(idx)) / span;
    if abs(initial_value(idx)) > 1e-12
        percent_change(idx) = (fitted_value(idx) - initial_value(idx)) / abs(initial_value(idx)) * 100;
    end
    if fitted_value(idx) < lower_bound(idx) || fitted_value(idx) > upper_bound(idx)
        plausibility_flag(idx) = "FAIL";
    elseif bound_position(idx) <= 0.10 || bound_position(idx) >= 0.90
        plausibility_flag(idx) = "WARNING";
    else
        plausibility_flag(idx) = "OK";
    end
end

T = table(parameter, group, initial_value, fitted_value, lower_bound, ...
    upper_bound, percent_change, bound_position, plausibility_flag, ...
    'VariableNames', {'Parameter','Group','Initial_Value','Fitted_Value', ...
    'Lower_Bound','Upper_Bound','Percent_Change','Bound_Position_0to1', ...
    'Plausibility_Flag'});
end

function T = build_rollback_decision_table(rollback, rollback_reason, accepted_label, ...
    rmse_baseline, rmse_A, rmse_C, accepted_rmse, stageC_ran, validity, fit_gate, plausibility)
% BUILD_ROLLBACK_DECISION_TABLE - compact audit trail for acceptance decision.
topics = [
    "Rollback"
    "Rollback_Reason"
    "Accepted_Label"
    "Baseline_RMSE"
    "Stage_A_RMSE"
    "Best_Candidate_RMSE"
    "Accepted_RMSE"
    "Stage_C_Ran"
    "Validity_Pass"
    "Validity_Failed_Flags"
    "Clinical_Fit_Guard_Pass"
    "Clinical_Fit_Guard_Reasons"
    "Plausibility_OK_Count"
    "Plausibility_WARNING_Count"
    "Plausibility_FAIL_Count"
    ];

failed_flags = "";
if isfield(validity, 'failed_flags') && ~isempty(validity.failed_flags)
    failed_flags = strjoin(string(validity.failed_flags), '; ');
end
fit_reasons = "";
if isfield(fit_gate, 'failed_reasons') && ~isempty(fit_gate.failed_reasons)
    fit_reasons = strjoin(string(fit_gate.failed_reasons), '; ');
end

values = [
    string(iif(rollback, 'YES', 'NO'))
    string(rollback_reason)
    string(accepted_label)
    string(sprintf('%.6g', rmse_baseline))
    string(sprintf('%.6g', rmse_A))
    string(sprintf('%.6g', rmse_C))
    string(sprintf('%.6g', accepted_rmse))
    string(iif(stageC_ran, 'YES', 'NO'))
    string(iif(validity.is_valid, 'YES', 'NO'))
    failed_flags
    string(iif(fit_gate.pass, 'YES', 'NO'))
    fit_reasons
    string(plausibility.n_ok)
    string(plausibility.n_warning)
    string(plausibility.n_fail)
    ];

T = table(topics, values, 'VariableNames', {'Decision_Item','Value'});
end

function band = map_band_from_target(targets)
% MAP_BAND_FROM_TARGET - patient-generic systemic pressure safety band.
target = NaN;
if isstruct(targets) && isfield(targets, 'SAP_mean') && isfinite(targets.SAP_mean)
    target = targets.SAP_mean;
end
if isfinite(target)
    margin = max(5, 0.10 * abs(target));
    band = [target - margin, target + margin];
else
    band = [70, 100];
end
end

function weights = metric_weights_from_baseline(metrics, calib_cfg)
% METRIC_WEIGHTS_FROM_BASELINE - one-pass weighting from baseline mismatch.
% This avoids patient-name hardcoding while still giving extra emphasis to
% severely underfit measured primary targets.
weights = struct();
for idx = 1:numel(calib_cfg.targetFields)
    fn = calib_cfg.targetFields{idx};
    target_value = calib_cfg.targets.(fn);
    err_pct = metric_error_pct(metrics, fn, target_value);
    if ~isfinite(err_pct)
        weight = 1.0;
    elseif err_pct >= 50
        weight = 3.0;
    elseif err_pct >= 30
        weight = 2.0;
    elseif err_pct >= 15
        weight = 1.3;
    else
        weight = 1.0;
    end
    weights.(fn) = weight;
end
end

function allow_group_c = resolve_allow_group_c()
% RESOLVE_ALLOW_GROUP_C - keep ventricular Group C fixed unless requested.
env_value = getenv('ASD_CALIB_ALLOW_GROUPC');
allow_group_c = any(strcmpi(strtrim(env_value), {'1','true','yes','on'}));
end

function use_par = resolve_parallel_fmincon()
% RESOLVE_PARALLEL_FMINCON - enable parallel gradient estimation for fmincon.
% Requires a running parallel pool. Controlled via ASD_CALIB_PARALLEL_FMINCON.
env_value = getenv('ASD_CALIB_PARALLEL_FMINCON');
use_par = any(strcmpi(strtrim(env_value), {'1','true','yes','on'}));
if use_par
    pool = gcp('nocreate');
    if isempty(pool)
        warning('run_aluna_asd_calibration:noPoolForFmincon', ...
            ['Parallel fmincon requested but no pool is running. ', ...
             'Start a pool with parpool(''local'', N) first.']);
        use_par = false;
    end
end
end
