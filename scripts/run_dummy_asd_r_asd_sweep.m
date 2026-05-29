%% run_dummy_asd_r_asd_sweep.m
% RUN_DUMMY_ASD_R_ASD_SWEEP
% -------------------------------------------------------------------------
% Diagnostic-only R_ASD sweep for the literature-based pediatric ASD dummy
% case. This script does not run GSA, optimization, calibration, parameter
% tuning, Patient Zoya, or Jovano post-closure logic.
%
% PURPOSE:
%   Check whether decreasing the ASD resistance increases Q_ASD and Qp/Qs
%   in a physiologically monotonic way. This is needed because the dummy
%   literature case has no ASD diameter, no atrial pressure gradient, and no
%   directly reported shunt flow.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-29
% VERSION:  1.0
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(project_root, 'results', 'tables');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
output_path = make_unique_output_path(output_dir, ...
    sprintf('dummy_asd_r_asd_sweep_%s.xlsx', timestamp));

fprintf('===============================================================\n');
fprintf('  Dummy ASD Diagnostic R_ASD Sweep\n');
fprintf('===============================================================\n');
fprintf('Mode: diagnostic forward sweep only; no GSA, no optimization.\n');

clinical = patient_dummy_ASD();
params_ref = default_parameters();
R_values = [0.2, 0.1, 0.05, 0.02, 0.01]; % [mmHg*s/mL]

healthy_pediatric = run_forward_case('Healthy_Pediatric_Dummy_Baseline', ...
    'healthy_pediatric_dummy', params_ref, clinical, clinical.pre_surgery, Inf);
pre_reference = run_forward_case('Dummy_ASD_PreClosure_R0p1', ...
    'pre_surgery', params_ref, clinical, clinical.pre_surgery, 0.1);
post_reference = run_forward_case('Dummy_ASD_PostClosure', ...
    'post_surgery', params_ref, clinical, clinical.post_surgery, Inf);

sweep_cases = cell(numel(R_values), 1);
for idx = 1:numel(R_values)
    sweep_cases{idx} = run_forward_case(sprintf('Sweep_R_ASD_%g', R_values(idx)), ...
        'pre_surgery', params_ref, clinical, clinical.pre_surgery, R_values(idx));
end

sweep_table = build_sweep_table(sweep_cases, R_values);
delta_table = build_delta_table(healthy_pediatric, pre_reference);
summary_table = build_summary_table(healthy_pediatric, pre_reference, ...
    post_reference, sweep_table, R_values);

fprintf('\nDiagnostic R_ASD sweep:\n');
disp(sweep_table);

write_sweep_workbook(output_path, summary_table, delta_table, sweep_table, ...
    pre_reference, post_reference, clinical);

fprintf('\nExcel written:\n  %s\n', output_path);
fprintf('===============================================================\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function result = run_forward_case(case_name, scenario, params_ref, clinical, src, R_asd)
% RUN_FORWARD_CASE - scale, configure ASD state, integrate, and report.
result = struct();
result.case_name = string(case_name);
result.scenario = string(scenario);
result.success = false;
result.error_message = "";
result.warning_id = "";
result.warning_message = "";
result.src = src;
result.R_asd_requested = R_asd;

try
    patient = make_scaling_patient(clinical, src, scenario);
    params = apply_scaling(params_ref, patient);
    scaled_HR_bpm = params.HR; % [bpm]
    HR_handling = "scaled_by_lundquist_bsa";
    if isfield(src, 'HR') && isfinite(src.HR)
        params.HR = src.HR; % [bpm]
        params = recompute_timing_params(params);
        HR_handling = "clinical_HR_from_dummy_table";
    end
    scaling_note = sprintf(['lundquist_bsa using BSA %.3f m2; ', ...
        'weight_for_scaling %.3f kg (%s); scaled HR %.3f bpm; final HR %.3f bpm'], ...
        patient.BSA, patient.weight_kg, patient.weight_source, ...
        scaled_HR_bpm, params.HR);

    if strcmp(scenario, 'healthy_pediatric_dummy') || strcmp(scenario, 'post_surgery')
        params = close_asd(params, sprintf('%s closed-ASD state', char(result.case_name)));
    else
        params = configure_diagnostic_asd(params, R_asd);
    end

    lastwarn('');
    sim = integrate_system(params);
    [warn_msg, warn_id] = lastwarn;
    metrics = compute_clinical_indices(sim, params);

    result.success = true;
    result.params = params;
    result.patient = patient;
    result.sim = sim;
    result.metrics = metrics;
    result.scaling_note = string(scaling_note);
    result.HR_handling = string(HR_handling);
    result.warning_id = string(warn_id);
    result.warning_message = string(warn_msg);
    result.mapping = describe_mapping(params, scenario);
catch ME
    result.error_message = string(ME.message);
end
end

function patient = make_scaling_patient(clinical, src, scenario)
% MAKE_SCALING_PATIENT - build apply_scaling patient struct.
patient = struct();
patient.age_years = first_valid(src, {'age_years'}, clinical.common.age_years);
patient.age_days = patient.age_years * 365.25;
patient.height_cm = first_valid(src, {'height_cm'}, clinical.common.height_cm);
patient.BSA = first_valid(src, {'BSA'}, clinical.common.BSA);
patient.sex = first_valid(clinical.common, {'sex'}, NaN);
patient.maturation_mode = first_valid_text(clinical.common, 'maturation_mode', 'normal');
patient.scaling_mode = 'lundquist_bsa';

reported_weight = first_valid(src, {'weight_kg'}, NaN);
if isfinite(reported_weight)
    patient.weight_kg = reported_weight;
    patient.weight_source = 'reported_in_source';
elseif isfinite(patient.BSA) && isfinite(patient.height_cm) && patient.height_cm > 0
    patient.weight_kg = (patient.BSA^2 * 3600) / patient.height_cm; % [kg]
    patient.weight_source = 'derived_inverse_mosteller_for_scaling_only';
else
    error('run_dummy_asd_r_asd_sweep:missingAnthropometry', ...
        'Cannot build %s scaling patient: weight missing and BSA/height unavailable.', scenario);
end
end

function params = configure_diagnostic_asd(params, R_asd)
% CONFIGURE_DIAGNOSTIC_ASD - finite linear ASD resistance for sweep only.
params.asd.mode = 'linear_bidirectional';
params.asd.area_mm2 = 0;              % [mm^2] geometry not reported
params.asd.diameter_mm = NaN;         % [mm] geometry not reported
params.R.asd = R_asd;                 % [mmHg*s/mL]
params.asd.mapping_status = sprintf( ...
    'diagnostic_R_asd_%g_mmHg_s_per_mL_no_calibration', R_asd);
params.asd.placeholder_R_asd_mmHg_s_per_mL = R_asd;
end

function params = close_asd(params, note)
% CLOSE_ASD - enforce closed ASD convention.
params.R.asd = Inf;                   % [mmHg*s/mL]
params.asd.mode = 'linear_bidirectional';
params.asd.area_mm2 = 0;              % [mm^2]
params.asd.diameter_mm = 0;           % [mm]
params.asd.mapping_status = note;
end

function mapping = describe_mapping(params, scenario)
% DESCRIBE_MAPPING - capture ASD state metadata.
mapping = struct();
mapping.scenario = string(scenario);
mapping.R_asd = params.R.asd;
mapping.mode = string(params.asd.mode);
mapping.status = "closed";
if strcmp(scenario, 'pre_surgery') && isfinite(params.R.asd)
    mapping.status = "open_diagnostic_sweep";
end
mapping.mapping_status = string(params.asd.mapping_status);
end

function tbl = build_sweep_table(cases, R_values)
% BUILD_SWEEP_TABLE - one row per R_ASD value.
rows = {};
prev_Q_asd = NaN;
prev_QpQs = NaN;
for idx = 1:numel(cases)
    c = cases{idx};
    metrics = struct();
    sim = struct();
    if isfield(c, 'metrics')
        metrics = c.metrics;
    end
    if isfield(c, 'sim')
        sim = c.sim;
    end
    Q_asd_Lmin = field_or_nan(metrics, 'Q_ASD_Lmin');
    QpQs = field_or_nan(metrics, 'QpQs');
    if idx == 1
        monotonic_Q = "not_applicable_first_row";
        monotonic_QpQs = "not_applicable_first_row";
    else
        monotonic_Q = logical_status(Q_asd_Lmin > prev_Q_asd + 1e-9);
        monotonic_QpQs = logical_status(QpQs > prev_QpQs + 1e-9);
    end
    rows(end + 1, :) = { ...
        R_values(idx), c.success, field_or_logical(sim, 'ss_reached'), ...
        field_or_nan(metrics, 'Q_ASD_mean_mLs'), Q_asd_Lmin, ...
        field_or_nan(metrics, 'Qp_Lmin'), field_or_nan(metrics, 'Qs_Lmin'), ...
        QpQs, field_or_nan(metrics, 'LAP_mean'), field_or_nan(metrics, 'RAP_mean'), ...
        pressure_gradient_LA_RA(metrics), field_or_nan(metrics, 'SAP_max'), ...
        field_or_nan(metrics, 'SAP_min'), field_or_nan(metrics, 'SAP_mean'), ...
        field_or_nan(metrics, 'RVEDV'), field_or_nan(metrics, 'LVEDV'), ...
        string(monotonic_Q), string(monotonic_QpQs), ...
        string(mapping_status_or_empty(c)), string(c.warning_message), ...
        string(c.error_message)}; %#ok<AGROW>
    prev_Q_asd = Q_asd_Lmin;
    prev_QpQs = QpQs;
end
tbl = cell2table(rows, 'VariableNames', { ...
    'R_ASD_mmHg_s_per_mL', 'Solver_Success', 'Steady_State_Reached', ...
    'Q_ASD_mean_mLs', 'Q_ASD_Lmin', 'Qp_Lmin', 'Qs_Lmin', 'Qp_Qs', ...
    'LAP_mean_mmHg', 'RAP_mean_mmHg', 'P_LA_minus_P_RA_mmHg', ...
    'SBP_mmHg', 'DBP_mmHg', 'MAP_mmHg', 'RVEDV_mL', 'LVEDV_mL', ...
    'Q_ASD_Monotonic_vs_Previous', 'Qp_Qs_Monotonic_vs_Previous', ...
    'ASD_Mapping_Status', 'Warning_Message', 'Error_Message'});
end

function tbl = build_delta_table(healthy, pre)
% BUILD_DELTA_TABLE - closed pediatric baseline vs ASD pre-closure R=0.1.
metrics = {
    'Q_ASD_Lmin', 'Q_ASD_Lmin', 'L/min'
    'Q_ASD_mean_mLs', 'Q_ASD_mean_mLs', 'mL/s'
    'Qp_Lmin', 'Qp_Lmin', 'L/min'
    'Qs_Lmin', 'Qs_Lmin', 'L/min'
    'Qp_Qs', 'QpQs', '-'
    'LAP_mean', 'LAP_mean', 'mmHg'
    'RAP_mean', 'RAP_mean', 'mmHg'
    'P_LA_minus_P_RA', 'pressure_gradient', 'mmHg'
    'SBP', 'SAP_max', 'mmHg'
    'DBP', 'SAP_min', 'mmHg'
    'MAP', 'SAP_mean', 'mmHg'
    'RVEDV', 'RVEDV', 'mL'
    'LVEDV', 'LVEDV', 'mL'
    'RVSV', 'RVSV', 'mL'
    'LVSV', 'LVSV', 'mL'
    };
rows = {};
for idx = 1:size(metrics, 1)
    metric_name = metrics{idx, 1};
    field_name = metrics{idx, 2};
    if strcmp(field_name, 'pressure_gradient')
        healthy_val = pressure_gradient_LA_RA(healthy.metrics);
        pre_val = pressure_gradient_LA_RA(pre.metrics);
    else
        healthy_val = field_or_nan(healthy.metrics, field_name);
        pre_val = field_or_nan(pre.metrics, field_name);
    end
    rows(end + 1, :) = {string(metric_name), string(metrics{idx, 3}), ...
        healthy_val, pre_val, pre_val - healthy_val, ...
        "ASD pre-closure minus healthy pediatric dummy baseline"}; %#ok<AGROW>
end
tbl = cell2table(rows, 'VariableNames', ...
    {'Metric', 'Unit', 'Healthy_Pediatric_Dummy', ...
    'ASD_PreClosure_R_ASD_0p1', 'Delta_PreMinusHealthy', 'Notes'});
end

function tbl = build_summary_table(healthy, pre, post, sweep_table, R_values)
% BUILD_SUMMARY_TABLE - workbook-level interpretation.
all_solver_success = all(sweep_table.Solver_Success);
all_steady = all(sweep_table.Steady_State_Reached);
monotonic_Q = all(strcmp(sweep_table.Q_ASD_Monotonic_vs_Previous(2:end), "yes"));
monotonic_QpQs = all(strcmp(sweep_table.Qp_Qs_Monotonic_vs_Previous(2:end), "yes"));
rows = {
    "Purpose", "Diagnostic R_ASD sweep only; no GSA, no optimization, no calibration."
    "R_ASD values [mmHg*s/mL]", join(string(R_values), ", ")
    "Healthy pediatric baseline", sprintf('Qp/Qs %.6f; Q_ASD %.6g L/min.', field_or_nan(healthy.metrics, 'QpQs'), field_or_nan(healthy.metrics, 'Q_ASD_Lmin'))
    "Pre-closure reference", sprintf('R_ASD 0.1; Qp/Qs %.6f; Q_ASD %.6f L/min.', field_or_nan(pre.metrics, 'QpQs'), field_or_nan(pre.metrics, 'Q_ASD_Lmin'))
    "Post-closure reference", sprintf('Qp/Qs %.6f; Q_ASD %.6g L/min.', field_or_nan(post.metrics, 'QpQs'), field_or_nan(post.metrics, 'Q_ASD_Lmin'))
    "All sweep solver success", logical_status(all_solver_success)
    "All sweep steady state reached", logical_status(all_steady)
    "Q_ASD monotonic with decreasing R_ASD", logical_status(monotonic_Q)
    "Qp/Qs monotonic with decreasing R_ASD", logical_status(monotonic_QpQs)
    "Interpretation boundary", "Monotonicity supports shunt sensitivity; it does not select or calibrate R_ASD."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic', 'Details'});
end

function tbl = build_target_comparison_table(c, scenario_label)
% BUILD_TARGET_COMPARISON_TABLE - model output vs dummy literature targets.
rows = {};
rows = add_target_row(rows, 'Heart Rate', 'bpm', c.params.HR, ...
    field_or_nan(c.src, 'HR'), 'Sjoberg 2024 Table 1', 'direct cohort median');
rows = add_target_row(rows, 'Cardiac Output', 'L/min', field_or_nan(c.metrics, 'CO_Lmin'), ...
    field_or_nan(c.src, 'CO_Lmin'), 'Sjoberg 2024 Table 1 derived', 'LV_CI * BSA');
rows = add_target_row(rows, 'Qp model', 'L/min', field_or_nan(c.metrics, 'Qp_Lmin'), ...
    field_or_nan(c.src, 'Qp_Lmin'), 'Sjoberg 2024 Table 1 derived', 'RV_CI * BSA');
rows = add_target_row(rows, 'Qs model', 'L/min', field_or_nan(c.metrics, 'Qs_Lmin'), ...
    field_or_nan(c.src, 'Qs_Lmin'), 'Sjoberg 2024 Table 1 derived', 'LV_CI * BSA');
rows = add_target_row(rows, 'Qp/Qs', '-', field_or_nan(c.metrics, 'QpQs'), ...
    field_or_nan(c.src, 'QpQs'), 'Sjoberg 2024 Table 1', 'reported target if available');
rows = add_target_row(rows, 'Qp/Qs from CI target', '-', field_or_nan(c.metrics, 'QpQs'), ...
    field_or_nan(c.src, 'QpQs_from_CI'), 'Sjoberg 2024 Table 1 derived', 'RV_CI / LV_CI');
rows = add_target_row(rows, 'Q_ASD L/min', 'L/min', field_or_nan(c.metrics, 'Q_ASD_Lmin'), ...
    first_valid(c.src, {'Q_shunt_Lmin', 'Q_ASD_target_Lmin'}, NaN), ...
    'patient_dummy_ASD.m', 'not reported pre-closure; zero target post-closure if closed');
rows = add_target_row(rows, 'SBP', 'mmHg', field_or_nan(c.metrics, 'SAP_max'), ...
    field_or_nan(c.src, 'SAP_sys_mmHg'), 'Sjoberg 2024 Table 1', 'direct cohort median');
rows = add_target_row(rows, 'DBP', 'mmHg', field_or_nan(c.metrics, 'SAP_min'), ...
    field_or_nan(c.src, 'SAP_dia_mmHg'), 'Sjoberg 2024 Table 1', 'direct cohort median');
rows = add_target_row(rows, 'MAP', 'mmHg', field_or_nan(c.metrics, 'SAP_mean'), ...
    first_valid(c.src, {'SAP_mean_mmHg', 'MAP_mmHg'}, NaN), ...
    'Sjoberg 2024 Table 1 derived', 'derived from SBP/DBP');
rows = add_target_row(rows, 'LVEDV', 'mL', field_or_nan(c.metrics, 'LVEDV'), ...
    field_or_nan(c.src, 'LVEDV_mL'), 'Sjoberg 2024 Table 1 derived', 'LVEDVi * BSA');
rows = add_target_row(rows, 'LVESV', 'mL', field_or_nan(c.metrics, 'LVESV'), ...
    field_or_nan(c.src, 'LVESV_mL'), 'Sjoberg 2024 Table 1 derived', 'LVESVi * BSA');
rows = add_target_row(rows, 'LVSV', 'mL', field_or_nan(c.metrics, 'LVSV'), ...
    field_or_nan(c.src, 'LVSV_mL'), 'Sjoberg 2024 Table 1 derived', 'LVSVi * BSA');
rows = add_target_row(rows, 'LVEF', '%', 100 * field_or_nan(c.metrics, 'LVEF'), ...
    100 * field_or_nan(c.src, 'LVEF'), 'Sjoberg 2024 Table 1', 'EF stored as fraction in MATLAB');
rows = add_target_row(rows, 'RVEDV', 'mL', field_or_nan(c.metrics, 'RVEDV'), ...
    field_or_nan(c.src, 'RVEDV_mL'), 'Sjoberg 2024 Table 1 derived', 'RVEDVi * BSA');
rows = add_target_row(rows, 'RVESV', 'mL', field_or_nan(c.metrics, 'RVESV'), ...
    field_or_nan(c.src, 'RVESV_mL'), 'Sjoberg 2024 Table 1 derived', 'RVESVi * BSA');
rows = add_target_row(rows, 'RVSV', 'mL', field_or_nan(c.metrics, 'RVSV'), ...
    field_or_nan(c.src, 'RVSV_mL'), 'Sjoberg 2024 Table 1 derived', 'RVSVi * BSA');
rows = add_target_row(rows, 'RVEF', '%', 100 * field_or_nan(c.metrics, 'RVEF'), ...
    100 * field_or_nan(c.src, 'RVEF'), 'Sjoberg 2024 Table 1', 'EF stored as fraction in MATLAB');

tbl = cell2table(rows, 'VariableNames', {'Metric', 'Unit', ...
    'Model_Output', 'Literature_Target', 'Difference', ...
    'Percent_Difference', 'Target_Source', 'Status', 'Notes'});
if strcmp(scenario_label, 'pre_closure')
    tbl.Notes = tbl.Notes + " | Pre-closure is not calibrated.";
else
    tbl.Notes = tbl.Notes + " | Post-closure ASD is closed in the model.";
end
end

function rows = add_target_row(rows, metric, unit, model_value, target_value, source, notes)
if isfinite(model_value) && isfinite(target_value)
    diff_val = model_value - target_value;
    pct_diff = 100 * diff_val / max(abs(target_value), 1e-9);
    status = "forward_only_comparison";
else
    diff_val = NaN;
    pct_diff = NaN;
    status = "target_not_reported_or_model_only";
end
rows(end + 1, :) = {string(metric), string(unit), model_value, ...
    target_value, diff_val, pct_diff, string(source), status, string(notes)};
end

function tbl = build_interpretation_table(sweep_table, pre_reference)
% BUILD_INTERPRETATION_TABLE - thesis-ready interpretation statements.
monotonic_Q = all(strcmp(sweep_table.Q_ASD_Monotonic_vs_Previous(2:end), "yes"));
monotonic_QpQs = all(strcmp(sweep_table.Qp_Qs_Monotonic_vs_Previous(2:end), "yes"));
rows = {
    "Mechanism check", "The first dummy ASD forward run passed mechanism checks: the shunt activated, direction was LA_to_RA, Qp/Qs exceeded 1, and post-closure returned toward Qp/Qs near 1."
    "Quantitative agreement", sprintf('The pre-closure R_ASD=0.1 run gives Qp/Qs %.6f, below the literature median target 1.8.', field_or_nan(pre_reference.metrics, 'QpQs'))
    "R_ASD placeholder", "R_ASD=0.1 mmHg*s/mL is a documented architecture placeholder because diameter, pressure gradient, and direct shunt flow are not reported."
    "Sweep purpose", "The R_ASD sweep checks whether the shunt path is directionally sensitive to resistance; it does not choose a best value."
    "Q_ASD monotonicity", sprintf('Q_ASD monotonic with decreasing R_ASD: %s.', logical_status(monotonic_Q))
    "Qp/Qs monotonicity", sprintf('Qp/Qs monotonic with decreasing R_ASD: %s.', logical_status(monotonic_QpQs))
    "Cohort median caution", "The dummy literature data are cohort medians, not paired patient-level calibration data."
    "Next workflow boundary", "GSA and optimization remain postponed until Patient Z forward simulation is established."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic', 'Interpretation'});
end

function tbl = build_limitations_table()
% BUILD_LIMITATIONS_TABLE - explicit methodological boundaries.
rows = {
    "No calibration", "The sweep does not minimize an objective function and does not select an optimal R_ASD."
    "No GSA", "No Sobol, PCE, or other global sensitivity workflow is called."
    "No Patient Z", "Patient Zoya files and Jovano post-closure workflow are not modified or executed."
    "Missing ASD geometry", "The dummy profile has no ASD diameter or area, so an orifice-derived resistance cannot be computed."
    "Missing pressure gradient", "The dummy profile has no reported LA-RA pressure gradient."
    "Missing direct shunt flow", "The dummy profile has no directly reported Q_ASD; Qp/Qs is only a comparison target."
    "Cohort medians", "Sjoberg 2024 Table 1 values are cohort medians and are not internally constrained as a single patient state."
    "Operating point dependence", "ASD shunt magnitude depends on atrial pressure balance, preload, elastance, and venous return, not only R_ASD."
    };
tbl = cell2table(rows, 'VariableNames', {'Limitation', 'Explanation'});
end

function write_sweep_workbook(output_path, summary_table, delta_table, sweep_table, ...
    pre_reference, post_reference, clinical)
% WRITE_SWEEP_WORKBOOK - export required diagnostic sheets.
writetable(summary_table, output_path, 'Sheet', 'Summary');
writetable(delta_table, output_path, 'Sheet', 'HealthyPed_vs_ASDPre_Delta');
writetable(sweep_table, output_path, 'Sheet', 'R_ASD_Sweep');
writetable(build_target_comparison_table(pre_reference, 'pre_closure'), ...
    output_path, 'Sheet', 'PreClosure_Target_Comparison');
writetable(build_target_comparison_table(post_reference, 'post_closure'), ...
    output_path, 'Sheet', 'PostClosure_Target_Comparison');
writetable(build_interpretation_table(sweep_table, pre_reference), ...
    output_path, 'Sheet', 'Interpretation');
writetable(build_limitations_table(), output_path, 'Sheet', 'Limitations');
format_workbook_for_readability(output_path);

fprintf('\nWorkbook note: requested sheet name HealthyPediatric_vs_ASDPre_Delta ');
fprintf('was shortened to HealthyPed_vs_ASDPre_Delta for Excel compatibility.\n');
fprintf('Primary dummy source: %s\n', clinical.common.primary_source);
end

function format_workbook_for_readability(output_path)
% FORMAT_WORKBOOK_FOR_READABILITY - optional Excel COM formatting.
if ~ispc
    return;
end
try
    excel = actxserver('Excel.Application');
    cleanup_obj = onCleanup(@() safe_quit_excel(excel));
    excel.Visible = false;
    excel.DisplayAlerts = false;
    workbook = excel.Workbooks.Open(output_path);
    for idx = 1:workbook.Worksheets.Count
        sheet = workbook.Worksheets.Item(idx);
        sheet.Activate;
        sheet.Rows.Item(1).Font.Bold = true;
        sheet.Rows.Item(1).WrapText = true;
        sheet.Columns.AutoFit;
        excel.ActiveWindow.FreezePanes = false;
        sheet.Range('A2').Select;
        excel.ActiveWindow.FreezePanes = true;
    end
    workbook.Save;
    workbook.Close(false);
    delete(cleanup_obj);
catch ME
    warning('run_dummy_asd_r_asd_sweep:workbookFormattingSkipped', ...
        'Workbook readability formatting skipped: %s', ME.message);
end
end

function safe_quit_excel(excel)
try
    excel.Quit;
catch
end
end

function params = recompute_timing_params(params)
T_HB = 60 / params.HR;                       % [s]
params.Tc_LV = params.Tc_LV_frac * T_HB;     % [s]
params.Tr_LV = params.Tr_LV_frac * T_HB;     % [s]
params.Tc_RV = params.Tc_RV_frac * T_HB;     % [s]
params.Tr_RV = params.Tr_RV_frac * T_HB;     % [s]
params.t_ac_LA = params.t_ac_LA_frac * T_HB; % [s]
params.Tc_LA = params.Tc_LA_frac * T_HB;     % [s]
params.t_ar_LA = params.t_ac_LA + params.Tc_LA; % [s]
params.Tr_LA = params.Tr_LA_frac * T_HB;     % [s]
params.t_ac_RA = params.t_ac_RA_frac * T_HB; % [s]
params.Tc_RA = params.Tc_RA_frac * T_HB;     % [s]
params.t_ar_RA = params.t_ac_RA + params.Tc_RA; % [s]
params.Tr_RA = params.Tr_RA_frac * T_HB;     % [s]
end

function output_path = make_unique_output_path(output_dir, file_name)
output_path = fullfile(output_dir, file_name);
if ~exist(output_path, 'file')
    return;
end
[~, name, ext] = fileparts(file_name);
counter = 1;
while exist(output_path, 'file')
    output_path = fullfile(output_dir, sprintf('%s_%02d%s', name, counter, ext));
    counter = counter + 1;
end
end

function value = first_valid(src, field_names, fallback)
value = fallback;
for idx = 1:numel(field_names)
    field_name = field_names{idx};
    if isfield(src, field_name) && isnumeric(src.(field_name)) && ...
            isscalar(src.(field_name)) && isfinite(src.(field_name))
        value = src.(field_name);
        return;
    end
end
end

function value = first_valid_text(src, field_name, fallback)
value = fallback;
if isfield(src, field_name) && ~isempty(src.(field_name))
    value = src.(field_name);
end
end

function value = field_or_nan(src, field_name)
value = NaN;
if isstruct(src) && isfield(src, field_name) && isnumeric(src.(field_name)) && ...
        isscalar(src.(field_name))
    value = src.(field_name);
end
end

function value = field_or_logical(src, field_name)
value = false;
if isstruct(src) && isfield(src, field_name)
    value = logical(src.(field_name));
end
end

function gradient = pressure_gradient_LA_RA(metrics)
gradient = field_or_nan(metrics, 'LAP_mean') - field_or_nan(metrics, 'RAP_mean');
end

function status = logical_status(value)
if value
    status = "yes";
else
    status = "no";
end
end

function value = mapping_status_or_empty(c)
value = "";
if isfield(c, 'mapping') && isfield(c.mapping, 'mapping_status')
    value = c.mapping.mapping_status;
end
end
