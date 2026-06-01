%% run_zoya_asd_gsa_curated.m
% RUN_ZOYA_ASD_GSA_CURATED
% -------------------------------------------------------------------------
% Patient Zoya ASD pre-closure curated-parameter Sobol GSA.
%
% Methodology adapted from Hafiz-Keisya unified VSD gsa_sobol_setup.m:
% ALL candidate parameters (Groups A, B, and C) are varied in GSA, not
% just Group A. Parameter ranking and active-set selection are then
% filtered by target-tier governance to use only metrics with clinical
% evidence. Target tiers themselves are unchanged — the same set of
% hard_primary / soft_secondary / prediction_only / excluded metrics
% governs ranking, not sampling.
%
% WORKFLOW:
%   adult healthy baseline
%   -> pediatric scaling using Zoya BSA
%   -> ASD clinical seeding
%   -> curated Groups A + B + C candidate parameter library
%   -> Saltelli/Sobol GSA
%   -> active mask from Sobol ST + ASD target-tier governance
%   -> workbook, MAT, and figures
%
% This script does not run optimization, calibration, parameter tuning,
% model-equation edits, post-closure logic, or Jovano workflow.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-29
% VERSION:  3.0  (curated ASD GSA, target-tier active mask)
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(project_root);
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

output_dir = fullfile(project_root, 'results', 'tables');
figure_dir = fullfile(project_root, 'results', 'figures');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
if ~exist(figure_dir, 'dir'), mkdir(figure_dir); end

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
excel_path = make_unique_output_path(output_dir, ...
    sprintf('zoya_asd_gsa_curated_%s.xlsx', timestamp));
mat_path = make_unique_output_path(output_dir, ...
    sprintf('zoya_asd_gsa_curated_%s.mat', timestamp));

scenario = 'pre_surgery';
seed = 42;
N = resolve_sample_size(256);
rng(seed, 'combRecursive');
use_parallel = resolve_parallel_mode();

fprintf('===============================================================\n');
fprintf('  Patient Zoya ASD Curated-Parameter Pre-Calibration GSA\n');
fprintf('===============================================================\n');
fprintf('Mode: GSA only (curated Groups A+B+C, VSD-aligned); no optimization.\n');
fprintf('Execution mode: %s\n', ternary(use_parallel, ...
    'parallel requested with automatic serial fallback', ...
    'serial; parallel disabled by default'));

ctx_options = struct('scaling_mode', 'lundquist_bsa', ...
    'runBaselineSimulation', false);
ctx = run_asd_patient_case(@patient_zoya, 'zoya', scenario, ctx_options);
clinical = ctx.clinical;
patient = ctx.patient;
params0_ASD_pre = ctx.params0;
params_gsa = apply_gsa_solver_overrides(params0_ASD_pre);

caseProfile = ctx.caseProfile;
target_tiers = ctx.target_tiers;
candidate_report = ctx.candidate_report;
all_params = ctx.curated_library;

names = cellstr(all_params.Parameter);
x0 = all_params.Initial_Value;
lb = all_params.Lower_Bound;
ub = all_params.Upper_Bound;
d = numel(names);

primary_metrics = cellstr(target_tiers.ModelField( ...
    strcmp(target_tiers.Tier, 'hard_primary') & target_tiers.IncludeInGSA));
secondary_metrics = cellstr(target_tiers.ModelField( ...
    startsWith(target_tiers.Tier, 'soft_secondary') & target_tiers.IncludeInGSA));
all_metrics = unique([primary_metrics(:); secondary_metrics(:)], 'stable')';

[saltelli, sampling_method] = build_saltelli_samples(N, d, lb, ub, seed);
cfg = struct('scenario', scenario, 'N', N, 'seed', seed, ...
    'sampling_method', sampling_method, 'names', {names}, 'x0', x0, ...
    'lb', lb, 'ub', ub, 'primary_metrics', {primary_metrics}, ...
    'secondary_metrics', {secondary_metrics}, 'all_metrics', {all_metrics}, ...
    'timestamp', timestamp, 'matlab_version', version, ...
    'use_parallel', use_parallel, ...
    'gsa_sim_overrides', solver_override_table(params_gsa));

fprintf('N=%d Saltelli/Sobol | seed=%d (combRecursive) | warmup=%d cycles\n', ...
    N, seed, params_gsa.sim.nCyclesSteady);
fprintf('[Curated GSA] Parameters (Groups A+B+C): %s\n', strjoin(names, ', '));
fprintf('[Curated GSA] Primary outputs: %s\n', strjoin(primary_metrics, ', '));
fprintf('[Curated GSA] Secondary/guard outputs: %s\n', strjoin(secondary_metrics, ', '));
fprintf('[Curated GSA] Total model evaluations: %d\n', N * (d + 2));

[YA, logA] = evaluate_sample_matrix(saltelli.A, params_gsa, names, all_metrics, 'A', use_parallel);
[YB, logB] = evaluate_sample_matrix(saltelli.B, params_gsa, names, all_metrics, 'B', use_parallel);
YAB = cell(d, 1);
logAB = cell(d, 1);
for param_idx = 1:d
    label = sprintf('AB_%s', names{param_idx});
    [YAB{param_idx}, logAB{param_idx}] = evaluate_sample_matrix( ...
        saltelli.AB{param_idx}, params_gsa, names, all_metrics, label, use_parallel);
end

sample_log = vertcat(logA, logB, logAB{:});
failed_all = sample_log(sample_log.Record_For_Failed_Sheet, :);

is_numerical = failed_all.Numerical_Failure;
numerical_failures = failed_all(is_numerical, :);
physiology_warnings = failed_all(~is_numerical, :);

fprintf('[GSA] Numerical failures: %d | Physiology warnings: %d\n', ...
    height(numerical_failures), height(physiology_warnings));
if height(numerical_failures) > 0
    fprintf('[GSA] Numerical failure types:\n');
    tabulate(categorical(numerical_failures.Failure_Type));
end
if height(physiology_warnings) > 0
    fprintf('[GSA] Physiology warning types:\n');
    tabulate(categorical(physiology_warnings.Failure_Type));
end

sobol = compute_sobol_indices(YA, YB, YAB, names, primary_metrics, ...
    secondary_metrics, all_metrics);

ST_primary = matrix_table(sobol.ST, names, all_metrics, primary_metrics);
S1_primary = matrix_table(sobol.S1, names, all_metrics, primary_metrics);
ST_secondary = matrix_table(sobol.ST, names, all_metrics, secondary_metrics);
ST_CI_primary = ci_matrix_table(sobol, names, all_metrics, primary_metrics, 'ST');
gsa_for_mask = struct('sobol', sobol, 'cfg', cfg);
[ranking, optMask] = build_asd_active_mask_from_gsa(gsa_for_mask, all_params, ...
    target_tiers, struct('Threshold', 0.10, 'MinActive', 4, 'MaxActive', 8, ...
    'AllowGroupC', resolve_allow_group_c(), 'UseSecondaryGuards', true, ...
    'CaseProfile', caseProfile));
recommended = ranking(ranking.Mask_Selected, :);
interpretation = build_heatmap_interpretation(sobol.ST, names, primary_metrics);
summary = build_summary_table(cfg, sample_log, numerical_failures, physiology_warnings, recommended);
notes = build_notes_table();

figure_paths = create_gsa_figures(sobol.ST, sobol.S1, names, primary_metrics, ...
    figure_dir, timestamp);

write_gsa_workbook(excel_path, summary, all_params, target_tiers, ST_primary, ...
    S1_primary, ST_secondary, ST_CI_primary, ranking, recommended, ...
    numerical_failures, physiology_warnings, interpretation, notes);
save(mat_path, 'cfg', 'saltelli', 'params0_ASD_pre', 'params_gsa', ...
    'clinical', 'patient', 'caseProfile', 'target_tiers', 'all_params', 'YA', 'YB', 'YAB', ...
    'sample_log', 'numerical_failures', 'physiology_warnings', 'sobol', 'ranking', 'recommended', 'optMask', ...
    'figure_paths');

fprintf('\n===============================================================\n');
fprintf('  Top Recommended Calibration Active Set\n');
fprintf('===============================================================\n');
disp(recommended(:, {'Parameter','Group','Mean_ST_Primary','Max_ST_Primary', ...
    'Max_ST_PrimarySecondary','Sensitive_PrimarySecondary_Targets'}));
fprintf('\n  Bootstrap 95%% CI Summary (ST, primary targets):\n');
fprintf('  %-12s %8s %8s %8s %s\n', 'Parameter', 'Max_ST', 'CI_lo', 'CI_hi', 'Width');
[~, p_loc] = ismember(primary_metrics, all_metrics);
p_loc = p_loc(p_loc > 0);
for i = 1:numel(names)
    st_row = sobol.ST(i, p_loc);
    [max_st, max_j] = max(st_row);
    if isfinite(max_st) && max_st >= 0.05
        ci_lo = sobol.ST_CI_lo(i, p_loc(max_j));
        ci_hi = sobol.ST_CI_hi(i, p_loc(max_j));
        fprintf('  %-12s %8.3f %8.3f %8.3f  (%.3f)\n', ...
            names{i}, max_st, ci_lo, ci_hi, ci_hi - ci_lo);
    end
end
fprintf('\nExcel written:\n  %s\n', excel_path);
fprintf('MAT saved:\n  %s\n', mat_path);
fprintf('Figures saved under:\n  %s\n', figure_dir);
fprintf('===============================================================\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function params = apply_gsa_solver_overrides(params)
% APPLY_GSA_SOLVER_OVERRIDES - ASD-adapted relaxed warmup for GSA screening.
%
% Hafiz-Keisya VSD GSA used 10 cycles with relaxed tolerances. Patient Zoya
% ASD diagnostic GSA showed frequent steady-state failures at 10 cycles, so
% the ASD curated runner defaults to 40 cycles while preserving environment
% overrides for smoke tests.
params.sim.nCyclesSteady = resolve_gsa_cycles(40); % [cycles]
params.sim.ss_tol_P = 1.0;         % [mmHg]
params.sim.ss_tol_V = 1.0;         % [mL]
end

function n_cycles = resolve_gsa_cycles(default_cycles)
% RESOLVE_GSA_CYCLES - optional GSA warmup override.
n_cycles = default_cycles;
env_value = getenv('ASD_GSA_NCYCLES');
if isempty(env_value)
    return;
end
candidate = str2double(env_value);
if isfinite(candidate) && candidate > 0
    n_cycles = round(candidate);
end
end

function N = resolve_sample_size(default_N)
% RESOLVE_SAMPLE_SIZE - optional debug override for full-parameter GSA.
N = default_N;
env_value = getenv('ASD_GSA_FULL_N');
if isempty(env_value)
    env_value = getenv('ASD_GSA_GROUPA_N'); % backward-compatible alias
end
if isempty(env_value)
    return;
end
candidate = str2double(env_value);
if isfinite(candidate) && candidate > 0
    N = round(candidate);
end
end

function use_parallel = resolve_parallel_mode()
% RESOLVE_PARALLEL_MODE - default to serial to avoid fragile worker crashes.
%
% Set ASD_GSA_USE_PARALLEL=1 only when the local MATLAB parallel pool is
% stable. If a worker disconnects, evaluate_sample_matrix falls back to
% serial execution for the affected matrix instead of aborting the run.
env_value = getenv('ASD_GSA_USE_PARALLEL');
use_parallel = any(strcmpi(strtrim(env_value), {'1','true','yes','on'}));
if use_parallel && license('test', 'Distrib_Computing_Toolbox') ~= 1
    warning('run_zoya_asd_gsa_curated:noParallelToolbox', ...
        'Parallel requested but Parallel Computing Toolbox is unavailable. Falling back to serial.');
    use_parallel = false;
end
end

function allow_group_c = resolve_allow_group_c()
% RESOLVE_ALLOW_GROUP_C - Group C is monitor-only unless explicitly enabled.
env_value = getenv('ASD_CALIB_ALLOW_GROUPC');
allow_group_c = any(strcmpi(strtrim(env_value), {'1','true','yes','on'}));
end

function tbl = solver_override_table(params)
% SOLVER_OVERRIDE_TABLE - reproducibility metadata.
tbl = table(["nCyclesSteady"; "ss_tol_P"; "ss_tol_V"], ...
    [params.sim.nCyclesSteady; params.sim.ss_tol_P; params.sim.ss_tol_V], ...
    ["cycles"; "mmHg"; "mL"], ...
    'VariableNames', {'Setting','Value','Unit'});
end

function [saltelli, sampling_method] = build_saltelli_samples(N, d, lb, ub, seed)
% BUILD_SALTELLI_SAMPLES - create A, B, and A_Bi matrices.
rng(seed, 'twister');
try
    sob = sobolset(2 * d, 'Skip', 1e3, 'Leap', 1e2);
    raw = net(sob, N);
    sampling_method = 'sobolset_quasi_random_saltelli';
catch
    raw = rand(N, 2 * d);
    sampling_method = 'pseudo_random_saltelli_fallback';
end
A01 = raw(:, 1:d);
B01 = raw(:, (d + 1):(2 * d));
A = scale_unit_samples(A01, lb, ub);
B = scale_unit_samples(B01, lb, ub);
AB = cell(d, 1);
for idx = 1:d
    AB{idx} = A;
    AB{idx}(:, idx) = B(:, idx);
end
saltelli = struct('A', A, 'B', B, 'AB', {AB});
end

function X = scale_unit_samples(U, lb, ub)
% SCALE_UNIT_SAMPLES - map [0,1] samples to parameter bounds.
X = bsxfun(@plus, lb(:)', bsxfun(@times, U, (ub(:) - lb(:))'));
end

function [Y, log_tbl] = evaluate_sample_matrix(Xmat, params0, names, metrics, label, use_parallel)
% EVALUATE_SAMPLE_MATRIX - safely evaluate each sampled parameter row.
Nlocal = size(Xmat, 1);
n_metrics = numel(metrics);
Y = nan(Nlocal, n_metrics);
fprintf('[GSA] Evaluating %s (%d samples)\n', label, Nlocal);
records = cell(Nlocal, 1);

if use_parallel
    try
        parfor sample_idx = 1:Nlocal
            warning('off', 'integrate_system:noSteadyState');
            params = apply_sample_row(params0, names, Xmat(sample_idx, :)');
            [outputs, record] = evaluate_one_sample(params, names, Xmat(sample_idx, :)', ...
                metrics, label, sample_idx);
            Y(sample_idx, :) = outputs;
            if record.Record_For_Failed_Sheet
                records{sample_idx} = record;
            end
        end
    catch ME
        warning('run_zoya_asd_gsa_curated:parallelFallback', ...
            ['Parallel evaluation failed for %s (%s). Re-running this matrix ', ...
             'serially so the GSA does not abort.'], label, ME.message);
        Y = nan(Nlocal, n_metrics);
        records = cell(Nlocal, 1);
        use_parallel = false;
    end
end

if ~use_parallel
    for sample_idx = 1:Nlocal
        warning('off', 'integrate_system:noSteadyState');
        params = apply_sample_row(params0, names, Xmat(sample_idx, :)');
        [outputs, record] = evaluate_one_sample(params, names, Xmat(sample_idx, :)', ...
            metrics, label, sample_idx);
        Y(sample_idx, :) = outputs;
        if record.Record_For_Failed_Sheet
            records{sample_idx} = record;
        end
        if mod(sample_idx, max(1, floor(Nlocal / 4))) == 0 || sample_idx == Nlocal
            fprintf('[GSA]   %s: %d/%d complete\n', label, sample_idx, Nlocal);
        end
    end
end
records = records(~cellfun(@isempty, records));
fprintf('[GSA]   %s: %d/%d complete; nonstandard records=%d\n', ...
    label, Nlocal, Nlocal, numel(records));
log_tbl = records_to_table(records, names);
end

function [outputs, record] = evaluate_one_sample(params, names, values, metrics, label, sample_idx)
% EVALUATE_ONE_SAMPLE - integrate model and classify numerical/physiology status.
outputs = nan(1, numel(metrics));
record = base_record(label, sample_idx, names, values);
try
    lastwarn('');
    sim = integrate_system(params);
    [warn_msg, warn_id] = lastwarn;
    metrics_out = compute_clinical_indices(sim, params);
    solver_success = isfield(sim, 't') && ~isempty(sim.t) && ...
        isfield(sim, 'V') && all(isfinite(sim.V(:)));
    steady_state = isfield(sim, 'ss_reached') && logical(sim.ss_reached);
    record.Solver_Success = solver_success;
    record.Steady_State = steady_state;
    record.Warning_ID = string(warn_id);
    record.Warning_Message = string(warn_msg);

    for metric_idx = 1:numel(metrics)
        field_name = metrics{metric_idx};
        if isfield(metrics_out, field_name) && isnumeric(metrics_out.(field_name)) && ...
                isscalar(metrics_out.(field_name))
            outputs(metric_idx) = metrics_out.(field_name);
        end
    end

    invalid_outputs = any(~isfinite(outputs));
    if ~solver_success || ~steady_state || invalid_outputs
        record.Numerical_Failure = true;
        record.Record_For_Failed_Sheet = true;
        if ~solver_success
            record.Failure_Type = "solver_failure";
            record.Failure_Reason = "integration returned empty or non-finite states";
        elseif ~steady_state
            record.Failure_Type = "steady_state_failure";
            record.Failure_Reason = "steady-state criterion was not reached";
        else
            record.Failure_Type = "nonfinite_output";
            record.Failure_Reason = "one or more requested GSA outputs were NaN/Inf/missing";
        end
        outputs(:) = NaN;
        return;
    end

    qasd = value_or_nan(metrics_out, 'Q_ASD_Lmin');        % [L/min]
    qpqs = value_or_nan(metrics_out, 'QpQs');              % [-]
    if isfinite(qasd) && qasd < 0
        record.Record_For_Failed_Sheet = true;
        record.Failure_Type = "opposite_shunt_direction";
        record.Failure_Reason = "Q_ASD_Lmin < 0; numerically valid but opposite physiology";
    elseif isfinite(qpqs) && qpqs < 1
        record.Record_For_Failed_Sheet = true;
        record.Failure_Type = "unexpected_physiology";
        record.Failure_Reason = "QpQs < 1; numerically valid but unexpected for left-to-right ASD";
    elseif strlength(record.Warning_ID) > 0 || strlength(record.Warning_Message) > 0
        record.Record_For_Failed_Sheet = true;
        record.Failure_Type = "solver_warning";
        record.Failure_Reason = "MATLAB warning was issued during sample evaluation";
    end
catch ME
    record.Numerical_Failure = true;
    record.Record_For_Failed_Sheet = true;
    record.Solver_Success = false;
    record.Steady_State = false;
    record.Failure_Type = "exception";
    record.Failure_Reason = string(ME.message);
    record.Warning_ID = "";
    record.Warning_Message = "";
    outputs(:) = NaN;
end
end

function record = base_record(label, sample_idx, names, values)
% BASE_RECORD - initialise one sample log row.
record = struct();
record.Matrix = string(label);
record.Sample_Index = sample_idx;
record.Numerical_Failure = false;
record.Record_For_Failed_Sheet = false;
record.Solver_Success = false;
record.Steady_State = false;
record.Failure_Type = "none";
record.Failure_Reason = "";
record.Warning_ID = "";
record.Warning_Message = "";
for idx = 1:numel(names)
    record.(safe_field_name(names{idx})) = values(idx);
end
end

function tbl = records_to_table(records, names)
% RECORDS_TO_TABLE - convert sample log records into a table.
var_names = [{'Matrix','Sample_Index','Numerical_Failure','Record_For_Failed_Sheet', ...
    'Solver_Success','Steady_State','Failure_Type','Failure_Reason', ...
    'Warning_ID','Warning_Message'}, ...
    cellfun(@safe_field_name, names, 'UniformOutput', false)'];
if isempty(records)
    tbl = empty_sample_log_table(var_names);
    return;
end
tbl = struct2table(vertcat(records{:}));
tbl = tbl(:, var_names);
end

function tbl = empty_sample_log_table(var_names)
% EMPTY_SAMPLE_LOG_TABLE - typed empty table for vertical concatenation.
tbl = table('Size', [0, numel(var_names)], ...
    'VariableTypes', repmat({'double'}, 1, numel(var_names)), ...
    'VariableNames', var_names);
string_vars = {'Matrix','Failure_Type','Failure_Reason','Warning_ID','Warning_Message'};
logical_vars = {'Numerical_Failure','Record_For_Failed_Sheet','Solver_Success','Steady_State'};
for idx = 1:numel(string_vars)
    if ismember(string_vars{idx}, var_names)
        tbl.(string_vars{idx}) = strings(0, 1);
    end
end
for idx = 1:numel(logical_vars)
    if ismember(logical_vars{idx}, var_names)
        tbl.(logical_vars{idx}) = false(0, 1);
    end
end
end

function params = apply_sample_row(params0, names, values)
% APPLY_SAMPLE_ROW - write sampled parameter values into params.
params = params0;
for idx = 1:numel(names)
    parts = strsplit(names{idx}, '.');
    switch numel(parts)
        case 2
            params.(parts{1}).(parts{2}) = values(idx);
        case 3
            params.(parts{1}).(parts{2}).(parts{3}) = values(idx);
        otherwise
            error('run_zoya_asd_gsa_curated:unsupportedParameterDepth', ...
                'Unsupported parameter path: %s', names{idx});
    end
end
end

function sobol = compute_sobol_indices(YA, YB, YAB, names, primary_metrics, secondary_metrics, all_metrics)
% COMPUTE_SOBOL_INDICES - Jansen S1/ST estimators with NaN-safe masks
%                         + bootstrap 95% CI (VSD-aligned, 200 iterations).
d = numel(names);
n_metrics = numel(all_metrics);
N_samples = size(YA, 1);
S1 = nan(d, n_metrics);
ST = nan(d, n_metrics);
Valid_Pairs_ST = zeros(d, n_metrics);
Valid_Pairs_S1 = zeros(d, n_metrics);

% --- Point estimates (Jansen 1999) ---
for metric_idx = 1:n_metrics
    yA = YA(:, metric_idx);
    yB = YB(:, metric_idx);
    y_var = [yA(isfinite(yA)); yB(isfinite(yB))];
    if numel(y_var) < 4, continue; end
    VY = max(var(y_var, 1), 1e-12);
    for param_idx = 1:d
        yAB = YAB{param_idx}(:, metric_idx);
        mask_st = isfinite(yA) & isfinite(yAB);
        mask_s1 = isfinite(yB) & isfinite(yAB);
        Valid_Pairs_ST(param_idx, metric_idx) = sum(mask_st);
        Valid_Pairs_S1(param_idx, metric_idx) = sum(mask_s1);
        if sum(mask_st) >= 4
            ST(param_idx, metric_idx) = mean((yA(mask_st) - yAB(mask_st)).^2) / (2 * VY);
        end
        if sum(mask_s1) >= 4
            S1(param_idx, metric_idx) = 1 - mean((yB(mask_s1) - yAB(mask_s1)).^2) / (2 * VY);
        end
    end
end
ST = min(max(ST, 0), 1);
S1 = min(max(S1, -0.2), 1);

% --- Bootstrap 95% CI (VSD-aligned, 200 iterations) ---
n_boot = 200;
S1_CI_lo = nan(d, n_metrics);
S1_CI_hi = nan(d, n_metrics);
ST_CI_lo = nan(d, n_metrics);
ST_CI_hi = nan(d, n_metrics);

fprintf('[GSA] Computing bootstrap 95%% CI (%d iterations)...\n', n_boot);
for metric_idx = 1:n_metrics
    yA = YA(:, metric_idx);
    yB = YB(:, metric_idx);
    % Only bootstrap if we have enough valid data
    y_all = [yA(isfinite(yA)); yB(isfinite(yB))];
    if numel(y_all) < 10, continue; end

    S1_boot = nan(d, n_boot);
    ST_boot = nan(d, n_boot);
    for b = 1:n_boot
        idx_b = randi(N_samples, N_samples, 1);
        yA_b = yA(idx_b);
        yB_b = yB(idx_b);
        VY_b = max(var([yA_b(isfinite(yA_b)); yB_b(isfinite(yB_b))], 1), 1e-12);
        for param_idx = 1:d
            yAB_b = YAB{param_idx}(idx_b, metric_idx);
            mask_b_st = isfinite(yA_b) & isfinite(yAB_b);
            mask_b_s1 = isfinite(yB_b) & isfinite(yAB_b);
            if sum(mask_b_st) >= 4
                ST_boot(param_idx, b) = mean((yA_b(mask_b_st) - yAB_b(mask_b_st)).^2) / (2 * VY_b);
            end
            if sum(mask_b_s1) >= 4
                S1_boot(param_idx, b) = 1 - mean((yB_b(mask_b_s1) - yAB_b(mask_b_s1)).^2) / (2 * VY_b);
            end
        end
    end
    S1_CI_lo(:, metric_idx) = prctile(S1_boot, 2.5, 2);
    S1_CI_hi(:, metric_idx) = prctile(S1_boot, 97.5, 2);
    ST_CI_lo(:, metric_idx) = prctile(ST_boot, 2.5, 2);
    ST_CI_hi(:, metric_idx) = prctile(ST_boot, 97.5, 2);
end

sobol = struct('Parameter', {names}, 'Metric', {all_metrics}, ...
    'PrimaryMetrics', {primary_metrics}, 'SecondaryMetrics', {secondary_metrics}, ...
    'S1', S1, 'ST', ST, ...
    'S1_CI_lo', S1_CI_lo, 'S1_CI_hi', S1_CI_hi, ...
    'ST_CI_lo', ST_CI_lo, 'ST_CI_hi', ST_CI_hi, ...
    'Valid_Pairs_ST', Valid_Pairs_ST, ...
    'Valid_Pairs_S1', Valid_Pairs_S1, ...
    'n_boot', n_boot);
end

function tbl = ci_matrix_table(sobol, names, all_metrics, selected_metrics, which)
% CI_MATRIX_TABLE - bootstrap CI table: Parameter | Metric1_ST [lo, hi] | ...
[is_present, loc] = ismember(selected_metrics, all_metrics);
if ~all(is_present)
    error('ci_matrix_table:missingMetric', 'Missing CI metric: %s', ...
        strjoin(selected_metrics(~is_present), ', '));
end
n_params = numel(names);
n_metrics = numel(selected_metrics);
data = cell(n_params, 1 + n_metrics);
data(:, 1) = names(:);
for j = 1:n_metrics
    m_idx = loc(j);
    for i = 1:n_params
        if strcmpi(which, 'ST')
            lo = sobol.ST_CI_lo(i, m_idx);
            hi = sobol.ST_CI_hi(i, m_idx);
            val = sobol.ST(i, m_idx);
        else
            lo = sobol.S1_CI_lo(i, m_idx);
            hi = sobol.S1_CI_hi(i, m_idx);
            val = sobol.S1(i, m_idx);
        end
        if isfinite(val) && isfinite(lo) && isfinite(hi)
            data{i, j + 1} = sprintf('%.3f [%.3f, %.3f]', val, lo, hi);
        else
            data{i, j + 1} = 'NA';
        end
    end
end
metric_labels = matlab.lang.makeValidName(selected_metrics);
tbl = cell2table(data, 'VariableNames', ['Parameter', metric_labels(:)']);
end

function tbl = matrix_table(matrix_values, names, all_metrics, selected_metrics)
% MATRIX_TABLE - sensitivity matrix as table with parameters in rows.
metric_names = matlab.lang.makeValidName(selected_metrics);
[is_present, loc] = ismember(selected_metrics, all_metrics);
if ~all(is_present)
    error('run_zoya_asd_gsa_curated:missingMatrixMetric', ...
        'Missing sensitivity matrix metric: %s', strjoin(selected_metrics(~is_present), ', '));
end
tbl = array2table(matrix_values(:, loc), ...
    'VariableNames', metric_names);
tbl = addvars(tbl, string(names(:)), 'Before', 1, 'NewVariableNames', 'Parameter');
end

function interpretation = build_heatmap_interpretation(ST, names, primary_metrics)
% BUILD_HEATMAP_INTERPRETATION - physiology sanity checks after full GSA.
rows = {};
rows = add_interpretation(rows, 'asd.Cd_shunt_effect', ...
    sensitivity_text(ST, names, primary_metrics, 'asd.Cd', {'QpQs','Qp_Lmin'}), ...
    'asd.Cd should affect Qp/Qs, Qp_Lmin, and Q_ASD-related behavior in orifice mode.');
rows = add_interpretation(rows, 'pulmonary_vascular_effect', ...
    max_family_text(ST, names, primary_metrics, {'R.PAR','R.PCOX','R.PCNO','R.PVEN','C.PAR'}, {'PAP_mean','Qp_Lmin'}), ...
    'Pulmonary vascular parameters should affect PAP_mean and pulmonary flow.');
rows = add_interpretation(rows, 'systemic_vascular_effect', ...
    max_family_text(ST, names, primary_metrics, {'R.SAR','R.SC','R.SVEN','C.SAR'}, {'SAP_mean','Qs_Lmin'}), ...
    'Systemic vascular parameters should affect MAP/SAP_mean and Qs_Lmin.');
rows = add_interpretation(rows, 'atrial_preload_effect', ...
    max_family_text(ST, names, primary_metrics, {'E.LA.EA','E.LA.EB','E.RA.EA','E.RA.EB','V0.LA','V0.RA'}, {'LAP_mean','QpQs'}), ...
    'Atrial elastance and unstressed volume should affect LAP_mean and shunt drive (QpQs).');
rows = add_interpretation(rows, 'ventricular_effect_on_pressure_flow', ...
    max_family_text(ST, names, primary_metrics, {'E.LV.EA','E.LV.EB','E.RV.EA','E.RV.EB','V0.LV','V0.RV'}, {'SAP_mean','PAP_mean','Qs_Lmin'}), ...
    'Ventricular parameters may affect systemic/pulmonary pressures through afterload coupling even without volume targets.');
rows = add_interpretation(rows, 'low_sensitivity_outputs', ...
    low_sensitivity_text(ST, primary_metrics), ...
    'Low sensitivity to all parameters for a primary output suggests the output is constrained by the model structure, not by a single parameter class.');
interpretation = cell2table(rows, 'VariableNames', {'Check','Finding','Interpretation'});
end

function rows = add_interpretation(rows, check, finding, interp)
% ADD_INTERPRETATION - append interpretation row.
rows(end + 1, :) = {string(check), string(finding), string(interp)};
end

function text = sensitivity_text(ST, names, metrics, param_name, target_metrics)
% SENSITIVITY_TEXT - summarize one parameter against selected outputs.
param_idx = find(strcmp(names, param_name), 1, 'first');
vals = [];
labels = {};
for idx = 1:numel(target_metrics)
    metric_idx = find(strcmp(metrics, target_metrics{idx}), 1, 'first');
    if ~isempty(param_idx) && ~isempty(metric_idx)
        vals(end + 1) = ST(param_idx, metric_idx); %#ok<AGROW>
        labels{end + 1} = sprintf('%s=%.3f', target_metrics{idx}, vals(end)); %#ok<AGROW>
    end
end
if isempty(labels)
    text = 'not available';
else
    text = strjoin(labels, '; ');
end
end

function text = max_family_text(ST, names, metrics, family_names, target_metrics)
% MAX_FAMILY_TEXT - summarize max ST for a parameter family.
labels = {};
for idx = 1:numel(target_metrics)
    metric_idx = find(strcmp(metrics, target_metrics{idx}), 1, 'first');
    family_idx = find(ismember(names, family_names));
    if ~isempty(metric_idx) && ~isempty(family_idx)
        [value, loc] = max(ST(family_idx, metric_idx));
        labels{end + 1} = sprintf('%s max %.3f by %s', ...
            target_metrics{idx}, value, names{family_idx(loc)}); %#ok<AGROW>
    end
end
text = strjoin(labels, '; ');
end

function text = low_sensitivity_text(ST, primary_metrics)
% LOW_SENSITIVITY_TEXT - identify primary outputs with all ST below threshold.
max_by_metric = max(ST(:, 1:numel(primary_metrics)), [], 1, 'omitnan');
low = primary_metrics(max_by_metric < 0.10);
if isempty(low)
    text = 'No primary outputs have all full-GSA parameter ST below 0.10.';
else
    text = sprintf('Low full-GSA sensitivity for: %s', strjoin(low, ', '));
end
end

function summary = build_summary_table(cfg, sample_log, numerical_failures, physiology_warnings, recommended)
% BUILD_SUMMARY_TABLE - workbook summary and reproducibility block.
numerical_count = sum(sample_log.Numerical_Failure);
rows = {
    "Purpose", "Patient Zoya ASD curated-parameter pre-calibration GSA (Groups A+B+C)."
    "No optimization", "No optimization, calibration, parameter tuning, equation edits, or post-closure logic was run."
    "Sampling method", cfg.sampling_method
    "Random seed", cfg.seed
    "Sample size N", cfg.N
    "Execution mode", ternary(cfg.use_parallel, ...
        "parallel requested with serial fallback", "serial")
    "Parameter count (curated all groups)", numel(cfg.names)
    "Total requested model evaluations", cfg.N * (numel(cfg.names) + 2)
    "Numerical failures (data loss)", numerical_count
    "Physiology warnings (data valid)", height(physiology_warnings)
    "MATLAB version", cfg.matlab_version
    "Primary metrics", strjoin(cfg.primary_metrics, ', ')
    "Secondary metrics", strjoin(cfg.secondary_metrics, ', ')
    "Recommended future calibration set", strjoin(cellstr(recommended.Parameter)', ', ')
    "Methodology", "Curated GSA on Groups A+B+C; active mask uses hard_primary plus measured secondary guard target-tier metrics."
    "Preliminary status", sprintf('N=%d Saltelli/Sobol; inspect bootstrap CI and numerical-failure rate before calibration.', cfg.N)
    };
summary = cell2table(rows, 'VariableNames', {'Topic','Details'});
end

function notes = build_notes_table()
% BUILD_NOTES_TABLE - methodological boundaries.
rows = {
    "Curated GSA", "Groups A+B+C candidates are sampled; active-mask selection is driven by ASD target-tier governance. Methodology adapted from Hafiz-Keisya unified VSD."
    "GSA vs calibration", "GSA samples the curated library; calibration optimizes only the active mask selected from Sobol ST plus target-tier governance."
    "Group B rationale", "Atrial/preload parameters are included in GSA but their sensitivity to LAP_mean, QpQs, and Q_ASD will determine if they enter the active set."
    "Group C rationale", "Ventricular E/V0 terms are included in GSA. If they show low sensitivity to primary pressure-flow targets, they remain fixed for calibration."
    "ST priority", "Total-order ST is prioritized because interactions are plausible in a closed-loop cardiovascular model."
    "S1 interpretation", "S1 is reported when estimable, but low S1 with high ST suggests interaction/nonlinear effects."
    "Sample size interpretation", "N=64 is smoke/preliminary; N=128 is screening; N=256 with acceptable failed-sample rate is more defensible for thesis-final ranking."
    };
notes = cell2table(rows, 'VariableNames', {'Topic','Note'});
end

function paths = create_gsa_figures(ST, S1, names, primary_metrics, figure_dir, timestamp)
% CREATE_GSA_FIGURES - save heatmaps and ranked ST bar charts.
paths = struct();
paths.ST_heatmap_png = fullfile(figure_dir, sprintf('zoya_asd_gsa_curated_ST_heatmap_%s.png', timestamp));
paths.ST_heatmap_pdf = replace_ext(paths.ST_heatmap_png, '.pdf');
paths.S1_heatmap_png = fullfile(figure_dir, sprintf('zoya_asd_gsa_curated_S1_heatmap_%s.png', timestamp));
paths.S1_heatmap_pdf = replace_ext(paths.S1_heatmap_png, '.pdf');

plot_heatmap(ST(:, 1:numel(primary_metrics)), names, primary_metrics, ...
    'Sobol Total-Order Index (S_T)', paths.ST_heatmap_png, paths.ST_heatmap_pdf);
plot_heatmap(S1(:, 1:numel(primary_metrics)), names, primary_metrics, ...
    'Sobol First-Order Index (S_1)', paths.S1_heatmap_png, paths.S1_heatmap_pdf);

bar_metrics = {'QpQs','Qp_Lmin','PAP_mean','SAP_mean','LAP_mean'};
paths.bar_png = strings(numel(bar_metrics), 1);
paths.bar_pdf = strings(numel(bar_metrics), 1);
for idx = 1:numel(bar_metrics)
    metric_idx = find(strcmp(primary_metrics, bar_metrics{idx}), 1, 'first');
    if isempty(metric_idx)
        continue;
    end
    png_path = fullfile(figure_dir, sprintf('zoya_asd_gsa_curated_ST_bar_%s_%s.png', ...
        bar_metrics{idx}, timestamp));
    pdf_path = replace_ext(png_path, '.pdf');
    plot_ranked_bar(ST(:, metric_idx), names, bar_metrics{idx}, png_path, pdf_path);
    paths.bar_png(idx) = string(png_path);
    paths.bar_pdf(idx) = string(pdf_path);
end
end

function plot_heatmap(values, names, metrics, title_text, png_path, pdf_path)
% PLOT_HEATMAP - save sensitivity heatmap.
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 18 12]);
imagesc(values);
colormap(parula);
colorbar;
clim([0 1]);
set(gca, 'XTick', 1:numel(metrics), 'XTickLabel', metrics, ...
    'YTick', 1:numel(names), 'YTickLabel', names, 'TickLabelInterpreter', 'none');
xlabel('Output metric');
    ylabel('Parameter (Groups A+B+C)');
    title(title_text, 'Interpreter', 'none');
    xtickangle(35);
for row = 1:size(values, 1)
    for col = 1:size(values, 2)
        if isfinite(values(row, col))
            text(col, row, sprintf('%.2f', values(row, col)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 8);
        end
    end
end
exportgraphics(fig, png_path, 'Resolution', 300);
exportgraphics(fig, pdf_path, 'ContentType', 'vector');
close(fig);
end

function plot_ranked_bar(values, names, metric_name, png_path, pdf_path)
% PLOT_RANKED_BAR - save one ranked total-order bar chart.
[sorted_values, order] = sort(values, 'descend', 'MissingPlacement', 'last');
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 18 10]);
bar(sorted_values, 'FaceColor', [0.20 0.45 0.75]);
set(gca, 'XTick', 1:numel(names), 'XTickLabel', names(order), ...
    'TickLabelInterpreter', 'none');
xtickangle(35);
ylabel('Sobol total-order index S_T');
    xlabel('Parameter (Groups A+B+C)');
title(sprintf('Ranked S_T for %s', metric_name), 'Interpreter', 'none');
ylim([0, max(1, max(sorted_values, [], 'omitnan') * 1.1)]);
grid on;
exportgraphics(fig, png_path, 'Resolution', 300);
exportgraphics(fig, pdf_path, 'ContentType', 'vector');
close(fig);
end

function write_gsa_workbook(excel_path, summary, all_params, target_tiers, ST_primary, ...
    S1_primary, ST_secondary, ST_CI_primary, ranking, recommended, ...
    numerical_failures, physiology_warnings, interpretation, notes)
% WRITE_GSA_WORKBOOK - export all GSA tables with separated failure categories.
writetable(summary, excel_path, 'Sheet', 'Summary');
writetable(all_params, excel_path, 'Sheet', 'Candidate_Parameters');
writetable(target_tiers, excel_path, 'Sheet', 'Target_Tiers');
writetable(ST_primary, excel_path, 'Sheet', 'Sobol_ST_Primary');
writetable(S1_primary, excel_path, 'Sheet', 'Sobol_S1_Primary');
writetable(ST_secondary, excel_path, 'Sheet', 'Sobol_ST_Secondary');
writetable(ST_CI_primary, excel_path, 'Sheet', 'ST_CI_Primary');
writetable(ranking, excel_path, 'Sheet', 'Parameter_Ranking');
writetable(recommended, excel_path, 'Sheet', 'Recommended_Active_Set');
writetable(numerical_failures, excel_path, 'Sheet', 'Numerical_Failures');
writetable(physiology_warnings, excel_path, 'Sheet', 'Physiology_Warnings');
writetable(ST_primary, excel_path, 'Sheet', 'ST_Heatmap_Matrix');
writetable(S1_primary, excel_path, 'Sheet', 'S1_Heatmap_Matrix');
writetable(interpretation, excel_path, 'Sheet', 'Heatmap_Interpretation');
writetable(notes, excel_path, 'Sheet', 'Notes');
end

function v = value_or_nan(s, field_name)
% VALUE_OR_NAN - read scalar numeric struct field.
v = NaN;
if isstruct(s) && isfield(s, field_name) && isnumeric(s.(field_name)) && ...
        isscalar(s.(field_name))
    v = s.(field_name);
end
end

function name = safe_field_name(name_in)
% SAFE_FIELD_NAME - convert parameter path to valid table variable name.
name = matlab.lang.makeValidName(strrep(name_in, '.', '_'));
end

function value = ternary(condition, true_value, false_value)
% TERNARY - small local display helper.
if condition
    value = true_value;
else
    value = false_value;
end
end

function output_path = make_unique_output_path(output_dir, file_name)
% MAKE_UNIQUE_OUTPUT_PATH - avoid overwriting existing outputs.
output_path = fullfile(output_dir, file_name);
if ~exist(output_path, 'file')
    return;
end
[~, base, ext] = fileparts(file_name);
counter = 1;
while exist(output_path, 'file')
    output_path = fullfile(output_dir, sprintf('%s_%02d%s', base, counter, ext));
    counter = counter + 1;
end
end

function new_path = replace_ext(path_in, new_ext)
% REPLACE_EXT - swap file extension.
[folder, base] = fileparts(path_in);
new_path = fullfile(folder, [base new_ext]);
end
