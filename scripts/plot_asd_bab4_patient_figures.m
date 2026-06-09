% PLOT_ASD_BAB4_PATIENT_FIGURES
% -------------------------------------------------------------------------
% Generate thesis-ready Chapter 4 visualizations for ASD pre-closure
% patients using one patient-generic workflow.
%
% This script is presentation-only. It does not change model equations,
% parameters, calibration decisions, GSA files, or patient data. It rebuilds:
%   1) a healthy pediatric reference for each patient body size
%   2) a calibrated/post-seed state from the saved calibration artefact
%
% Physiological reading guide:
%   - PV loops: chamber loading, stroke work, and RV volume burden.
%   - LA/RA pressure traces: the ASD shunt is driven by P_LA - P_RA.
%   - Q_ASD trace: positive flow means LA_to_RA left-to-right atrial shunt.
%   - Q_PVv and Q_AV: pulmonary valve outflow and aortic valve outflow.
%   - PAP/SAP summaries: pressure-waveform plausibility and clinical target
%     agreement for systolic, diastolic, and mean pressures.
%
% Visual validation logic:
%   The healthy pediatric reference is a closed-ASD, body-size-matched
%   baseline. The calibrated trace is the patient ASD operating point.
%   Comparing them helps identify whether the disease/calibrated state
%   shows expected ASD physiology: Q_ASD activation, Qp/Qs elevation,
%   RV loading tendency, and pressure-flow changes without numerical collapse.
%
% OUTPUTS:
%   results/figures/<patientID>/<patientID>_baseline_vs_calibrated_*.png
%   results/figures/asd_bab4_plot_manifest_<timestamp>.csv
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-08
% VERSION:  1.0
% -------------------------------------------------------------------------

clearvars;
clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
original_path = path;
cleanup_path = onCleanup(@() path(original_path));

restoredefaultpath;
addpath(project_root);
addpath(fullfile(project_root, 'config'));
addpath(fullfile(project_root, 'scripts'));
addpath(genpath(fullfile(project_root, 'src')));

opts = default_plot_options(project_root);
cases = default_patient_cases();

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
manifest_rows = {};

fprintf('===============================================================\n');
fprintf('  ASD Chapter 4 Patient Figure Export\n');
fprintf('===============================================================\n');
fprintf('Output root: %s\n', opts.figure_root);
fprintf('Calibrated parameter policy: %s\n\n', opts.calibrated_policy);

for case_idx = 1:numel(cases)
    patientID = lower(char(cases(case_idx).patientID));
    patient_fn = cases(case_idx).params_fn;
    scenario = char(cases(case_idx).scenario);

    fprintf('--- %s (%s) ---\n', upper_first(patientID), scenario);
    patient_dir = fullfile(opts.figure_root, patientID);
    if ~exist(patient_dir, 'dir'), mkdir(patient_dir); end

    try
        [healthy_state, calibrated_state, source_info] = ...
            build_patient_plot_states(patient_fn, patientID, scenario, opts);

        plot_files = strings(5, 1);
        plot_files(1) = plot_pv_loop_overlay( ...
            healthy_state, calibrated_state, patientID, patient_dir);
        plot_files(2) = plot_atrial_pressure_overlay( ...
            healthy_state, calibrated_state, patientID, patient_dir);
        plot_files(3) = plot_qasd_overlay( ...
            healthy_state, calibrated_state, patientID, patient_dir);
        plot_files(4) = plot_flow_overlay( ...
            healthy_state, calibrated_state, patientID, patient_dir);
        plot_files(5) = plot_pressure_summary( ...
            healthy_state, calibrated_state, patientID, patient_dir);

        for file_idx = 1:numel(plot_files)
            manifest_rows(end + 1, :) = { ...
                string(patientID), string(scenario), string(source_info.calibration_mat), ...
                string(source_info.calibrated_source), string(source_info.rollback), ...
                string(plot_files(file_idx)), "OK", ""}; %#ok<SAGROW>
        end

        fprintf('  Wrote %d figures to %s\n\n', numel(plot_files), patient_dir);
    catch ME
        warning('plot_asd_bab4:patientFailed', ...
            'Figure export failed for %s: %s', patientID, ME.message);
        manifest_rows(end + 1, :) = { ...
            string(patientID), string(scenario), "", "", "", "", ...
            "FAILED", string(ME.message)}; %#ok<SAGROW>
    end
end

manifest = cell2table(manifest_rows, 'VariableNames', { ...
    'PatientID', 'Scenario', 'Calibration_MAT', 'Calibrated_Source', ...
    'Rollback_In_Source_Run', 'Figure_File', 'Status', 'Notes'});
manifest_path = fullfile(opts.figure_root, ...
    sprintf('asd_bab4_plot_manifest_%s.csv', timestamp));
writetable(manifest, manifest_path);

fprintf('Manifest written:\n  %s\n', manifest_path);
fprintf('Done.\n');

function cases = default_patient_cases()
% DEFAULT_PATIENT_CASES - patient registry; add future patients here only.
cases = struct( ...
    'patientID', {'zoya', 'indira', 'aluna'}, ...
    'params_fn', {@patient_zoya, @patient_indira, @patient_aluna}, ...
    'scenario', {'pre_surgery', 'pre_surgery', 'pre_surgery'});
end

function opts = default_plot_options(project_root)
% DEFAULT_PLOT_OPTIONS - plotting and simulation controls.
opts = struct();
opts.project_root = project_root;
opts.figure_root = fullfile(project_root, 'results', 'figures');
opts.calibration_root = fullfile(project_root, 'results', 'calibration');
opts.scaling_mode = 'lundquist_bsa';

% The policy is generic:
%   accepted_or_best_if_rollback uses accepted_params unless rollback happened.
%   If rollback happened, it plots best_candidate and labels it in manifest.
% This prevents sparse cases from silently showing "accepted baseline" as if
% it were the Stage C candidate.
opts.calibrated_policy = 'accepted_or_best_if_rollback';

% For visual overlay, the healthy pediatric reference is closed-ASD and uses
% the same clinical HR as the patient context. This isolates disease/shunt
% effects from trivial cycle-length differences in overlay plots.
opts.use_clinical_hr_for_healthy = true;

% Keep production steady-state settings unless the user explicitly overrides
% them from MATLAB before running the script with environment variables.
opts.nCyclesSteady = read_numeric_env('ASD_BAB4_NCYCLES', NaN);
opts.ss_tol_P = read_numeric_env('ASD_BAB4_SS_TOL_P', NaN);
opts.ss_tol_V = read_numeric_env('ASD_BAB4_SS_TOL_V', NaN);
end

function [healthy_state, calibrated_state, source_info] = ...
    build_patient_plot_states(patient_fn, patientID, scenario, opts)
% BUILD_PATIENT_PLOT_STATES - run healthy pediatric and calibrated states.
ctx_options = struct('scaling_mode', opts.scaling_mode, ...
    'runBaselineSimulation', false);
ctx = run_asd_patient_case(patient_fn, patientID, scenario, ctx_options);

params_healthy = make_healthy_pediatric_params(ctx.params_scaled, ...
    ctx.params0, opts);
params_healthy = apply_plot_solver_overrides(params_healthy, opts);

[calib_pkg, calib_path] = load_latest_calibration_pkg(patientID, opts);
[params_calibrated, calibrated_source] = select_calibrated_params( ...
    calib_pkg, opts.calibrated_policy);
params_calibrated = apply_plot_solver_overrides(params_calibrated, opts);

fprintf('  Healthy pediatric: closed ASD, HR %.1f bpm\n', params_healthy.HR);
fprintf('  Calibrated source: %s\n', calibrated_source);
fprintf('  Calibration MAT: %s\n', calib_path);

sim_healthy = integrate_system(params_healthy);
sim_calibrated = integrate_system(params_calibrated);

healthy_state = build_plot_state('Healthy pediatric closed ASD', ...
    sim_healthy, params_healthy, ctx.clinical, scenario);
calibrated_state = build_plot_state(calibrated_source, ...
    sim_calibrated, params_calibrated, ctx.clinical, scenario);

source_info = struct();
source_info.calibration_mat = calib_path;
source_info.calibrated_source = calibrated_source;
source_info.rollback = field_text(calib_pkg, 'rollback');
end

function params = make_healthy_pediatric_params(params_scaled, params_seeded, opts)
% MAKE_HEALTHY_PEDIATRIC_PARAMS - body-size matched, closed-ASD reference.
params = params_scaled;
if opts.use_clinical_hr_for_healthy
    params.HR = params_seeded.HR;
    params = recompute_timing_params(params);
end

params.R.asd = Inf;                 % [mmHg*s/mL] closed ASD convention.
params.asd.mode = 'linear_bidirectional';
params.asd.area_mm2 = 0;            % [mm^2] no atrial defect.
params.asd.diameter_mm = 0;         % [mm] no atrial defect.
params.asd.mapping_status = 'healthy_pediatric_closed_asd_for_plot';
params.asd.location = 'none';
end

function params = recompute_timing_params(params)
% RECOMPUTE_TIMING_PARAMS - update activation timings after HR override.
T_HB = 60 / params.HR;                       % [s]
params.Tc_LV   = params.Tc_LV_frac   * T_HB; % [s]
params.Tr_LV   = params.Tr_LV_frac   * T_HB; % [s]
params.Tc_RV   = params.Tc_RV_frac   * T_HB; % [s]
params.Tr_RV   = params.Tr_RV_frac   * T_HB; % [s]
params.t_ac_LA = params.t_ac_LA_frac * T_HB; % [s]
params.Tc_LA   = params.Tc_LA_frac   * T_HB; % [s]
params.t_ar_LA = params.t_ac_LA + params.Tc_LA; % [s]
params.Tr_LA   = params.Tr_LA_frac   * T_HB; % [s]
params.t_ac_RA = params.t_ac_RA_frac * T_HB; % [s]
params.Tc_RA   = params.Tc_RA_frac   * T_HB; % [s]
params.t_ar_RA = params.t_ac_RA + params.Tc_RA; % [s]
params.Tr_RA   = params.Tr_RA_frac   * T_HB; % [s]
end

function params = apply_plot_solver_overrides(params, opts)
% APPLY_PLOT_SOLVER_OVERRIDES - optional runtime controls for plotting.
if isfinite(opts.nCyclesSteady)
    params.sim.nCyclesSteady = opts.nCyclesSteady;
end
if isfinite(opts.ss_tol_P)
    params.sim.ss_tol_P = opts.ss_tol_P;
end
if isfinite(opts.ss_tol_V)
    params.sim.ss_tol_V = opts.ss_tol_V;
end
end

function [pkg, mat_path] = load_latest_calibration_pkg(patientID, opts)
% LOAD_LATEST_CALIBRATION_PKG - find newest patient calibration MAT file.
pattern = fullfile(opts.calibration_root, ...
    sprintf('%s_asd_calib_*', patientID), ...
    sprintf('%s_asd_calibration_*.mat', patientID));
files = dir(pattern);
if isempty(files)
    error('plot_asd_bab4:missingCalibration', ...
        'No calibration MAT found for patient %s with pattern %s', ...
        patientID, pattern);
end
[~, order] = sort([files.datenum], 'descend');
mat_path = fullfile(files(order(1)).folder, files(order(1)).name);
data = load(mat_path, 'pkg');
if ~isfield(data, 'pkg')
    error('plot_asd_bab4:missingPkg', ...
        'Calibration MAT does not contain pkg: %s', mat_path);
end
pkg = data.pkg;
end

function [params, source_label] = select_calibrated_params(pkg, policy)
% SELECT_CALIBRATED_PARAMS - choose accepted or best candidate for plotting.
policy = lower(char(string(policy)));
rollback = isfield(pkg, 'rollback') && logical(pkg.rollback);

switch policy
    case 'accepted'
        params = pkg.accepted_params;
        source_label = char(string(pkg.accepted_label));
    case 'best_candidate'
        params = pkg.best_candidate.params;
        source_label = char(string(pkg.best_candidate.label));
    case 'accepted_or_best_if_rollback'
        if rollback && isfield(pkg, 'best_candidate') && ...
                isfield(pkg.best_candidate, 'params')
            params = pkg.best_candidate.params;
            source_label = char(string(pkg.best_candidate.label) + ...
                "_after_source_run_rollback");
        else
            params = pkg.accepted_params;
            source_label = char(string(pkg.accepted_label));
        end
    otherwise
        error('plot_asd_bab4:unknownPolicy', ...
            'Unknown calibrated parameter policy: %s', policy);
end
end

function state = build_plot_state(label, sim, params, clinical, scenario)
% BUILD_PLOT_STATE - reconstruct last-cycle time series and summary metrics.
[t_cycle, V_cycle, P, Q] = reconstruct_last_cycle(sim, params);

state = struct();
state.label = char(string(label));
state.sim = sim;
state.params = params;
state.metrics = compute_clinical_indices(sim, params);
state.t = t_cycle;
state.V = V_cycle;
state.P = P;
state.Q = Q;
state.clinical = clinical;
state.scenario = scenario;
end

function [t_cycle, V_cycle, P, Q] = reconstruct_last_cycle(sim, params)
% RECONSTRUCT_LAST_CYCLE - extract one beat and rebuild P/Q signals.
t = sim.t(:);                                 % [s]
T_HB = 60 / params.HR;                        % [s]
mask = t >= (t(end) - T_HB - 1e-9);
t_cycle = t(mask) - t(find(mask, 1, 'first')); % [s]
V_cycle = sim.V(mask, :);                     % [state units]
[P, Q] = reconstruct_hemodynamic_signals(t(mask), V_cycle, params);
end

function out_path = plot_pv_loop_overlay(healthy, calibrated, patientID, out_dir)
% PLOT_PV_LOOP_OVERLAY - LV/RV pressure-volume loops for load comparison.
% Observe: RV loop enlargement can indicate ASD-related pulmonary/RV load.
fig = make_figure(18, 8);
colors = plot_colors();

subplot(1, 2, 1);
plot(healthy.V(:, healthy.params.idx.V_LV), healthy.P.LV, '--', ...
    'Color', colors.healthy, 'LineWidth', 1.5); hold on;
plot(calibrated.V(:, calibrated.params.idx.V_LV), calibrated.P.LV, '-', ...
    'Color', colors.calibrated, 'LineWidth', 1.7);
xlabel('LV volume [mL]');
ylabel('LV pressure [mmHg]');
title('LV PV loop');
legend({'Healthy pediatric', 'Calibrated/post-seed'}, 'Location', 'best');
grid on; box on;

subplot(1, 2, 2);
plot(healthy.V(:, healthy.params.idx.V_RV), healthy.P.RV, '--', ...
    'Color', colors.healthy, 'LineWidth', 1.5); hold on;
plot(calibrated.V(:, calibrated.params.idx.V_RV), calibrated.P.RV, '-', ...
    'Color', colors.calibrated, 'LineWidth', 1.7);
xlabel('RV volume [mL]');
ylabel('RV pressure [mmHg]');
title('RV PV loop');
legend({'Healthy pediatric', 'Calibrated/post-seed'}, 'Location', 'best');
grid on; box on;

sgtitle(sprintf('%s: healthy pediatric vs calibrated PV loops', ...
    upper_first(patientID)), 'Interpreter', 'none', 'FontSize', 13, ...
    'FontWeight', 'bold');
out_path = save_png(fig, out_dir, patientID, 'baseline_vs_calibrated', ...
    'pv_loop');
end

function out_path = plot_atrial_pressure_overlay(healthy, calibrated, ...
    patientID, out_dir)
% PLOT_ATRIAL_PRESSURE_OVERLAY - LA/RA pressures that drive ASD shunting.
% Observe: P_LA - P_RA controls LA_to_RA shunt tendency in the ASD model.
fig = make_figure(18, 10);
colors = plot_colors();

subplot(2, 1, 1);
plot(healthy.t, healthy.P.LA, '--', 'Color', colors.healthy_la, ...
    'LineWidth', 1.4); hold on;
plot(healthy.t, healthy.P.RA, '--', 'Color', colors.healthy_ra, ...
    'LineWidth', 1.4);
plot(calibrated.t, calibrated.P.LA, '-', 'Color', colors.calibrated_la, ...
    'LineWidth', 1.6);
plot(calibrated.t, calibrated.P.RA, '-', 'Color', colors.calibrated_ra, ...
    'LineWidth', 1.6);
xlabel('Time in last cardiac cycle [s]');
ylabel('Pressure [mmHg]');
title('Atrial pressure traces');
legend({'Healthy LA', 'Healthy RA', 'Calibrated LA', 'Calibrated RA'}, ...
    'Location', 'best');
grid on; box on;

subplot(2, 1, 2);
plot(healthy.t, healthy.P.LA - healthy.P.RA, '--', ...
    'Color', colors.healthy, 'LineWidth', 1.4); hold on;
plot(calibrated.t, calibrated.P.LA - calibrated.P.RA, '-', ...
    'Color', colors.calibrated, 'LineWidth', 1.6);
yline(0, 'k:');
xlabel('Time in last cardiac cycle [s]');
ylabel('P_LA - P_RA [mmHg]');
title('Atrial pressure gradient');
legend({'Healthy pediatric', 'Calibrated/post-seed'}, 'Location', 'best');
grid on; box on;

sgtitle(sprintf('%s: atrial pressures and ASD driving gradient', ...
    upper_first(patientID)), 'Interpreter', 'none', 'FontSize', 13, ...
    'FontWeight', 'bold');
out_path = save_png(fig, out_dir, patientID, 'baseline_vs_calibrated', ...
    'atrial_pressure_traces');
end

function out_path = plot_qasd_overlay(healthy, calibrated, patientID, out_dir)
% PLOT_QASD_OVERLAY - ASD shunt flow trace.
% Observe: healthy should remain near zero; positive calibrated Q_ASD means
% LA_to_RA flow by this model's sign convention.
fig = make_figure(18, 8);
colors = plot_colors();
subplot(2, 1, 1);
plot(healthy.t, healthy.Q.ASD, '--', 'Color', colors.healthy, ...
    'LineWidth', 1.4); hold on;
plot(calibrated.t, calibrated.Q.ASD, '-', 'Color', colors.calibrated, ...
    'LineWidth', 1.7);
yline(0, 'k:');
xlabel('Time in last cardiac cycle [s]');
ylabel('Q_ASD [mL/s]');
title('ASD shunt flow trace');
legend({'Healthy pediatric', 'Calibrated/post-seed'}, 'Location', 'best');
grid on; box on;

subplot(2, 1, 2);
bar_data = [healthy.metrics.Q_ASD_Lmin, calibrated.metrics.Q_ASD_Lmin];
qasd_categories = categorical({'Healthy', 'Calibrated'}, ...
    {'Healthy', 'Calibrated'}, 'Ordinal', true);
bar(qasd_categories, bar_data, ...
    'FaceColor', 'flat');
ylabel('Mean Q_ASD [L/min]');
title(sprintf('Mean Q_ASD: healthy %.3g L/min, calibrated %.3g L/min', ...
    bar_data(1), bar_data(2)));
grid on; box on;

sgtitle(sprintf('%s: ASD shunt activation', upper_first(patientID)), ...
    'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');
out_path = save_png(fig, out_dir, patientID, 'baseline_vs_calibrated', ...
    'q_asd_trace');
end

function out_path = plot_flow_overlay(healthy, calibrated, patientID, out_dir)
% PLOT_FLOW_OVERLAY - pulmonary/systemic outlet flows and Qp/Qs summary.
% Observe: ASD physiology usually raises pulmonary flow relative to systemic
% flow. Q_PVv and Q_AV show pulsatile RV and LV outflow timing.
fig = make_figure(20, 12);
colors = plot_colors();

subplot(2, 1, 1);
plot(healthy.t, healthy.Q.PVv, '--', 'Color', colors.healthy_pul, ...
    'LineWidth', 1.3); hold on;
plot(healthy.t, healthy.Q.AV, '--', 'Color', colors.healthy_sys, ...
    'LineWidth', 1.3);
plot(calibrated.t, calibrated.Q.PVv, '-', 'Color', colors.calibrated_pul, ...
    'LineWidth', 1.6);
plot(calibrated.t, calibrated.Q.AV, '-', 'Color', colors.calibrated_sys, ...
    'LineWidth', 1.6);
yline(0, 'k:');
xlabel('Time in last cardiac cycle [s]');
ylabel('Flow [mL/s]');
title('Pulmonary valve and aortic valve outflow traces');
legend({'Healthy Q_PVv', 'Healthy Q_AV', ...
    'Calibrated Q_PVv', 'Calibrated Q_AV'}, 'Location', 'best');
grid on; box on;

subplot(2, 1, 2);
flow_metrics = {'Qp_Lmin', 'Qs_Lmin', 'Q_ASD_Lmin', 'Qpv_Lmin', 'Qao_Lmin'};
flow_labels = {'Qp', 'Qs', 'Q_ASD', 'Q_PVv', 'Q_AV'};
healthy_vals = metric_vector(healthy.metrics, flow_metrics);
cal_vals = metric_vector(calibrated.metrics, flow_metrics);
flow_categories = categorical(flow_labels, flow_labels, 'Ordinal', true);
bar(flow_categories, [healthy_vals(:), cal_vals(:)]);
ylabel('Flow [L/min]');
title(sprintf('Qp/Qs: healthy %.2f, calibrated %.2f', ...
    healthy.metrics.QpQs, calibrated.metrics.QpQs));
legend({'Healthy pediatric', 'Calibrated/post-seed'}, 'Location', 'best');
grid on; box on;

sgtitle(sprintf('%s: pulmonary-systemic flow comparison', ...
    upper_first(patientID)), 'Interpreter', 'none', 'FontSize', 13, ...
    'FontWeight', 'bold');
out_path = save_png(fig, out_dir, patientID, 'baseline_vs_calibrated', ...
    'flow_traces');
end

function out_path = plot_pressure_summary(healthy, calibrated, patientID, out_dir)
% PLOT_PRESSURE_SUMMARY - PAP/SAP systolic, diastolic, and mean pressures.
% Observe: mean pressures are primary pressure-flow anchors; systolic and
% diastolic pressures are waveform plausibility guards.
fig = make_figure(20, 12);
colors = plot_colors();

subplot(2, 1, 1);
plot(healthy.t, healthy.P.SAR, '--', 'Color', colors.healthy_sys, ...
    'LineWidth', 1.3); hold on;
plot(healthy.t, healthy.P.PAR, '--', 'Color', colors.healthy_pul, ...
    'LineWidth', 1.3);
plot(calibrated.t, calibrated.P.SAR, '-', 'Color', colors.calibrated_sys, ...
    'LineWidth', 1.6);
plot(calibrated.t, calibrated.P.PAR, '-', 'Color', colors.calibrated_pul, ...
    'LineWidth', 1.6);
xlabel('Time in last cardiac cycle [s]');
ylabel('Pressure [mmHg]');
title('Systemic arterial and pulmonary arterial pressure traces');
legend({'Healthy SAP', 'Healthy PAP', 'Calibrated SAP', ...
    'Calibrated PAP'}, 'Location', 'best');
grid on; box on;

subplot(2, 1, 2);
metric_names = {'SAP_max', 'SAP_min', 'SAP_mean', ...
    'PAP_max', 'PAP_min', 'PAP_mean'};
metric_labels = {'SBP', 'DBP', 'MAP', 'PAP_sys', 'PAP_dia', 'PAP_mean'};
healthy_vals = metric_vector(healthy.metrics, metric_names);
cal_vals = metric_vector(calibrated.metrics, metric_names);
clinical_vals = clinical_pressure_targets(calibrated.clinical, ...
    calibrated.scenario, metric_names);

cats = categorical(metric_labels, metric_labels, 'Ordinal', true);
bar(cats, [healthy_vals(:), cal_vals(:)]);
hold on;
plot(cats, clinical_vals, 'ko', 'MarkerFaceColor', 'y', ...
    'MarkerSize', 6, 'DisplayName', 'Clinical target');
ylabel('Pressure [mmHg]');
title('Pressure extrema and mean summary');
legend({'Healthy pediatric', 'Calibrated/post-seed', ...
    'Clinical target'}, 'Location', 'best');
grid on; box on;

sgtitle(sprintf('%s: systemic and pulmonary pressure comparison', ...
    upper_first(patientID)), 'Interpreter', 'none', 'FontSize', 13, ...
    'FontWeight', 'bold');
out_path = save_png(fig, out_dir, patientID, 'baseline_vs_calibrated', ...
    'pressure_summary');
end

function values = metric_vector(metrics, names)
% METRIC_VECTOR - get numeric metric values with NaN fallback.
values = nan(1, numel(names));
for i = 1:numel(names)
    if isfield(metrics, names{i}) && isnumeric(metrics.(names{i}))
        values(i) = metrics.(names{i});
    end
end
end

function values = clinical_pressure_targets(clinical, scenario, metric_names)
% CLINICAL_PRESSURE_TARGETS - scenario clinical pressure targets if present.
src = select_clinical_source(clinical, scenario);
map = containers.Map( ...
    {'SAP_max', 'SAP_min', 'SAP_mean', 'PAP_max', 'PAP_min', 'PAP_mean'}, ...
    {'SAP_sys_mmHg', 'SAP_dia_mmHg', 'SAP_mean_mmHg', ...
     'PAP_sys_mmHg', 'PAP_dia_mmHg', 'PAP_mean_mmHg'});
values = nan(1, numel(metric_names));
for i = 1:numel(metric_names)
    if isKey(map, metric_names{i})
        fld = map(metric_names{i});
        if isfield(src, fld) && isnumeric(src.(fld)) && isfinite(src.(fld))
            values(i) = src.(fld);
        end
    end
end
end

function src = select_clinical_source(clinical, scenario)
% SELECT_CLINICAL_SOURCE - normalize pre/post scenario naming.
scenario = lower(char(string(scenario)));
if isfield(clinical, scenario)
    src = clinical.(scenario);
    return;
end

if any(strcmp(scenario, {'pre_surgery', 'pre_closure', 'pre'}))
    candidates = {'pre_closure', 'pre_surgery', 'pre'};
elseif any(strcmp(scenario, {'post_surgery', 'post_closure', 'post'}))
    candidates = {'post_closure', 'post_surgery', 'post'};
else
    candidates = {scenario};
end

src = struct();
for i = 1:numel(candidates)
    if isfield(clinical, candidates{i})
        src = clinical.(candidates{i});
        return;
    end
end
end

function fig = make_figure(width_cm, height_cm)
% MAKE_FIGURE - standard hidden figure for reproducible PNG export.
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 width_cm height_cm]);
set(fig, 'DefaultAxesFontName', 'Arial');
set(fig, 'DefaultTextFontName', 'Arial');
set(fig, 'DefaultAxesFontSize', 9);
set(fig, 'DefaultTextFontSize', 10);
set(fig, 'DefaultLegendFontSize', 8);
end

function colors = plot_colors()
% PLOT_COLORS - consistent color semantics across patients and figures.
colors = struct();
colors.healthy = [0.25 0.25 0.25];
colors.calibrated = [0.80 0.18 0.14];
colors.healthy_la = [0.30 0.45 0.90];
colors.healthy_ra = [0.35 0.55 0.45];
colors.calibrated_la = [0.85 0.20 0.20];
colors.calibrated_ra = [0.90 0.45 0.10];
colors.healthy_pul = [0.20 0.45 0.80];
colors.healthy_sys = [0.20 0.60 0.50];
colors.calibrated_pul = [0.80 0.25 0.25];
colors.calibrated_sys = [0.85 0.50 0.10];
end

function out_path = save_png(fig, out_dir, patientID, state_tag, metric_tag)
% SAVE_PNG - standardized Chapter 4 figure naming.
out_path = fullfile(out_dir, sprintf('%s_%s_%s.png', ...
    lower(patientID), state_tag, metric_tag));
exportgraphics(fig, out_path, 'Resolution', 300);
close(fig);
end

function value = read_numeric_env(name, default_value)
% READ_NUMERIC_ENV - optional numeric override through environment variable.
raw_value = getenv(name);
if isempty(raw_value)
    value = default_value;
    return;
end
parsed = str2double(raw_value);
if isnan(parsed)
    value = default_value;
else
    value = parsed;
end
end

function txt = field_text(s, name)
% FIELD_TEXT - convert a scalar field to text for the manifest.
if isstruct(s) && isfield(s, name)
    val = s.(name);
    txt = string(val);
else
    txt = "";
end
end

function out = upper_first(txt)
% UPPER_FIRST - compact display helper.
txt = char(string(txt));
if isempty(txt)
    out = txt;
else
    out = [upper(txt(1)), txt(2:end)];
end
end
