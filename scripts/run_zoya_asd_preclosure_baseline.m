%% run_zoya_asd_preclosure_baseline.m
% RUN_ZOYA_ASD_PRECLOSURE_BASELINE
% -------------------------------------------------------------------------
% Safe forward-only Patient Zoya ASD pre-closure baseline simulation.
%
% WORKFLOW:
%   1. Load Patient Zoya clinical profile.
%   2. Build adult healthy reference parameters.
%   3. Apply pediatric scaling using Zoya common anthropometry/BSA.
%   4. Apply ASD clinical seeding to produce params0_ASD_pre.
%   5. Verify the ASD open mechanism before integration.
%   6. Run ODE integration and compute clinical indices.
%   7. Compare model outputs against available pre-closure targets.
%
% This script does not run GSA, optimization, calibration, or post-closure
% Jovano logic.
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
excel_path = make_unique_output_path(output_dir, ...
    sprintf('zoya_asd_preclosure_baseline_%s.xlsx', timestamp));
mat_path = make_unique_output_path(output_dir, ...
    sprintf('zoya_asd_preclosure_baseline_%s.mat', timestamp));

fprintf('===============================================================\n');
fprintf('  Patient Zoya ASD Pre-Closure Baseline Simulation\n');
fprintf('===============================================================\n');
fprintf('Mode: forward baseline only; no GSA, no optimization.\n');

scenario = 'pre_surgery'; % ASD pre_closure compatibility scenario
clinical = patient_zoya();
params_ref = default_parameters();

patient = clinical_to_scaling_patient(clinical, 'Zoya_ReferencePatient');
patient.scaling_mode = 'lundquist_bsa';

params_scaled = apply_scaling(params_ref, patient);
params0_ASD_pre = params_from_clinical(params_scaled, clinical, scenario, ...
    params_scaled, struct());

open_check = verify_asd_open_mechanism(params0_ASD_pre);
fprintf('\nASD open-mechanism check:\n');
disp(open_check(:, {'Check_Name', 'Status', 'Details'}));
if ~all(open_check.Passed)
    error('run_zoya_asd_preclosure_baseline:asdNotOpen', ...
        'ASD open seed is not valid. Baseline simulation stopped before integration.');
end

lastwarn('');
sim_pre = integrate_system(params0_ASD_pre);
[warn_msg, warn_id] = lastwarn;
metrics_pre = compute_clinical_indices(sim_pre, params0_ASD_pre);

target_comparison = build_target_comparison_table(metrics_pre, params0_ASD_pre, ...
    clinical, scenario, warn_id, warn_msg, sim_pre);
summary_table = build_summary_table(params0_ASD_pre, sim_pre, metrics_pre, ...
    clinical, scenario, open_check, warn_id, warn_msg);

fprintf('\nBaseline output summary:\n');
disp(summary_table);
fprintf('\nClinical target comparison:\n');
disp(target_comparison(:, {'Metric', 'Unit', 'Model_Output', ...
    'Clinical_Target', 'Difference', 'Percent_Difference', 'Status'}));

write_baseline_workbook(excel_path, summary_table, open_check, ...
    target_comparison, params0_ASD_pre, metrics_pre, sim_pre, clinical, scenario);
save(mat_path, 'params0_ASD_pre', 'params_scaled', 'params_ref', 'clinical', ...
    'patient', 'scenario', 'sim_pre', 'metrics_pre', 'open_check', ...
    'target_comparison', 'summary_table');

fprintf('\nExcel written:\n  %s\n', excel_path);
fprintf('MAT saved:\n  %s\n', mat_path);
fprintf('===============================================================\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function open_check = verify_asd_open_mechanism(params)
% VERIFY_ASD_OPEN_MECHANISM - assert ASD path can carry LA->RA flow.
mode = lower(char(params.asd.mode));
q_test_pos_mLs = asd_shunt_model(15, 10, params); % [mL/s]
q_test_neg_mLs = asd_shunt_model(10, 15, params); % [mL/s]

rows = {};
rows = add_check(rows, 'ASD_mode_supported', ...
    any(strcmp(mode, {'linear_bidirectional', 'linear_left_to_right_only', ...
    'orifice_bidirectional'})), sprintf('mode=%s', mode));
rows = add_check(rows, 'R_asd_handling_valid', ...
    (~contains(mode, 'linear') || isfinite(params.R.asd)) || ...
    strcmp(mode, 'orifice_bidirectional'), ...
    sprintf('R.asd=%s; orifice mode ignores R.asd in flow calculation.', ...
    value_text(params.R.asd)));
rows = add_check(rows, 'ASD_area_used_if_orifice', ...
    ~strcmp(mode, 'orifice_bidirectional') || ...
    (isfinite(params.asd.area_mm2) && params.asd.area_mm2 > 0), ...
    sprintf('area=%.12f mm^2', params.asd.area_mm2));
rows = add_check(rows, 'ASD_Cd_finite_if_orifice', ...
    ~strcmp(mode, 'orifice_bidirectional') || ...
    (isfield(params.asd, 'Cd') && isfinite(params.asd.Cd) && params.asd.Cd > 0), ...
    sprintf('Cd=%s', value_text(params.asd.Cd)));
rows = add_check(rows, 'Positive_direction_LA_to_RA', ...
    q_test_pos_mLs > 0 && q_test_neg_mLs < 0, ...
    sprintf('Q_ASD(PLA=15,PRA=10)=%.6f mL/s; reverse=%.6f mL/s', ...
    q_test_pos_mLs, q_test_neg_mLs));
rows = add_check(rows, 'ASD_open_seed_valid', ...
    abs(q_test_pos_mLs) > 1e-6, ...
    'Positive LA-RA pressure difference produces nonzero ASD flow.');

open_check = cell2table(rows, 'VariableNames', ...
    {'Check_Name', 'Passed', 'Status', 'Details'});
end

function rows = add_check(rows, name, passed, details)
% ADD_CHECK - append check row.
if passed
    status = "PASS";
else
    status = "FAIL";
end
rows(end + 1, :) = {string(name), logical(passed), status, string(details)};
end

function summary = build_summary_table(params, sim, metrics, clinical, scenario, ...
    open_check, warn_id, warn_msg)
% BUILD_SUMMARY_TABLE - compact run status and key outputs.
src = clinical.(scenario);
rows = {
    "Workflow", "adult_ref -> pediatric scaling -> ASD clinical seeding -> baseline ODE simulation"
    "No GSA/optimization", "No GSA, optimization, calibration, or post-closure logic was run."
    "ASD open mechanism", sprintf('%d/%d checks passed.', sum(open_check.Passed), height(open_check))
    "ASD mode", params.asd.mode
    "ASD area", sprintf('%.9f mm^2', params.asd.area_mm2)
    "ASD Cd", value_text(params.asd.Cd)
    "R.asd", value_text(params.R.asd)
    "Solver success", string(isfield(sim, 't') && ~isempty(sim.t) && all(isfinite(sim.V(:))))
    "Steady state reached", string(field_or_logical(sim, 'ss_reached'))
    "Warning", sprintf('%s %s', string(warn_id), string(warn_msg))
    "Q_ASD", sprintf('%.6f L/min (%s)', field_or_nan(metrics, 'Q_ASD_Lmin'), string(metrics.Q_ASD_direction))
    "Qp/Qs model vs target", sprintf('%.6f vs %.6f', field_or_nan(metrics, 'QpQs'), field_or_nan(src, 'QpQs'))
    "Qp model vs target", sprintf('%.6f vs %.6f L/min', field_or_nan(metrics, 'Qp_Lmin'), field_or_nan(src, 'Qp_Lmin'))
    "Qs model vs target", sprintf('%.6f vs %.6f L/min', field_or_nan(metrics, 'Qs_Lmin'), field_or_nan(src, 'Qs_Lmin'))
    "LAP model vs target", sprintf('%.6f vs %.6f mmHg', field_or_nan(metrics, 'LAP_mean'), field_or_nan(src, 'LAP_mean_mmHg'))
    "PAP mean model vs target", sprintf('%.6f vs %.6f mmHg', field_or_nan(metrics, 'PAP_mean'), field_or_nan(src, 'PAP_mean_mmHg'))
    "SAP mean model vs target", sprintf('%.6f vs %.6f mmHg', field_or_nan(metrics, 'SAP_mean'), field_or_nan(src, 'SAP_mean_mmHg'))
    };
summary = cell2table(rows, 'VariableNames', {'Topic', 'Details'});
end

function tbl = build_target_comparison_table(metrics, params, clinical, scenario, ...
    warn_id, warn_msg, sim)
% BUILD_TARGET_COMPARISON_TABLE - model-vs-clinical targets.
src = clinical.(scenario);
rows = {};
rows = add_metric(rows, 'Heart Rate', 'bpm', params.HR, clinical.common.HR, ...
    'clinical.common.HR', 'clinical override seed');
rows = add_metric(rows, 'Q_ASD', 'L/min', field_or_nan(metrics, 'Q_ASD_Lmin'), ...
    derived_qasd_target(src), 'derived Qp-Qs', ...
    'Derived from available Qp_Lmin-Qs_Lmin; direct Q_shunt_Lmin remains missing.');
rows = add_metric(rows, 'Q_ASD direction', '-', metrics.Q_ASD_direction, ...
    'LA_to_RA', 'ASD convention', 'Positive model Q_ASD should be LA_to_RA.');
rows = add_metric(rows, 'Qp model', 'L/min', field_or_nan(metrics, 'Qp_Lmin'), ...
    field_or_nan(src, 'Qp_Lmin'), 'patient_zoya.pre_surgery.Qp_Lmin', ...
    'Pulmonary flow target.');
rows = add_metric(rows, 'Qs model', 'L/min', field_or_nan(metrics, 'Qs_Lmin'), ...
    field_or_nan(src, 'Qs_Lmin'), 'patient_zoya.pre_surgery.Qs_Lmin', ...
    'Systemic flow target.');
rows = add_metric(rows, 'Qp/Qs', '-', field_or_nan(metrics, 'QpQs'), ...
    field_or_nan(src, 'QpQs'), 'patient_zoya.pre_surgery.QpQs', ...
    'Stored as target, not forced.');
rows = add_metric(rows, 'SBP', 'mmHg', field_or_nan(metrics, 'SAP_max'), ...
    field_or_nan(src, 'SAP_sys_mmHg'), 'RFA/cath selected generic systemic pressure', '');
rows = add_metric(rows, 'DBP', 'mmHg', field_or_nan(metrics, 'SAP_min'), ...
    field_or_nan(src, 'SAP_dia_mmHg'), 'RFA/cath selected generic systemic pressure', '');
rows = add_metric(rows, 'MAP', 'mmHg', field_or_nan(metrics, 'SAP_mean'), ...
    field_or_nan(src, 'SAP_mean_mmHg'), 'RFA/cath selected generic systemic pressure', '');
rows = add_metric(rows, 'PAP_sys', 'mmHg', field_or_nan(metrics, 'PAP_max'), ...
    field_or_nan(src, 'PAP_sys_mmHg'), 'patient_zoya.pre_surgery.PAP_sys_mmHg', '');
rows = add_metric(rows, 'PAP_dia', 'mmHg', field_or_nan(metrics, 'PAP_min'), ...
    field_or_nan(src, 'PAP_dia_mmHg'), 'patient_zoya.pre_surgery.PAP_dia_mmHg', '');
rows = add_metric(rows, 'PAP_mean', 'mmHg', field_or_nan(metrics, 'PAP_mean'), ...
    field_or_nan(src, 'PAP_mean_mmHg'), 'patient_zoya.pre_surgery.PAP_mean_mmHg', '');
rows = add_metric(rows, 'LAP_mean', 'mmHg', field_or_nan(metrics, 'LAP_mean'), ...
    field_or_nan(src, 'LAP_mean_mmHg'), 'patient_zoya.pre_surgery.LAP_mean_mmHg', '');
rows = add_metric(rows, 'RAP_mean', 'mmHg', field_or_nan(metrics, 'RAP_mean'), ...
    field_or_nan(src, 'RAP_mean_mmHg'), 'patient_zoya.pre_surgery.RAP_mean_mmHg', ...
    'Clinical RAP missing; model prediction only.');
rows = add_metric(rows, 'PVR', 'WU', field_or_nan(metrics, 'PVR'), ...
    field_or_nan(src, 'PVR_WU'), 'patient_zoya.pre_surgery.PVR_WU', ...
    'Clinical PVR missing; model prediction only.');
rows = add_metric(rows, 'SVR', 'WU', field_or_nan(metrics, 'SVR'), ...
    field_or_nan(src, 'SVR_WU'), 'patient_zoya.pre_surgery.SVR_WU', ...
    'Clinical SVR missing; model prediction only.');
rows = add_metric(rows, 'LVEDV', 'mL', field_or_nan(metrics, 'LVEDV'), ...
    field_or_nan(src, 'LVEDV_mL'), 'patient_zoya.pre_surgery.LVEDV_mL', ...
    'Clinical volume missing; model prediction only.');
rows = add_metric(rows, 'RVEDV', 'mL', field_or_nan(metrics, 'RVEDV'), ...
    field_or_nan(src, 'RVEDV_mL'), 'patient_zoya.pre_surgery.RVEDV_mL', ...
    'Clinical volume missing; model prediction only.');
rows = add_metric(rows, 'Solver success', '-', ...
    string(isfield(sim, 't') && ~isempty(sim.t) && all(isfinite(sim.V(:)))), ...
    'true', 'numerical quality', '');
rows = add_metric(rows, 'Steady state', '-', string(field_or_logical(sim, 'ss_reached')), ...
    'true', 'numerical quality', '');
rows = add_metric(rows, 'Warning', '-', sprintf('%s %s', string(warn_id), string(warn_msg)), ...
    '', 'MATLAB lastwarn', '');

tbl = cell2table(rows, 'VariableNames', {'Metric', 'Unit', ...
    'Model_Output', 'Clinical_Target', 'Difference', ...
    'Percent_Difference', 'Target_Source', 'Status', 'Notes'});
end

function rows = add_metric(rows, metric, unit, model_value, target_value, source, notes)
% ADD_METRIC - append numeric or text comparison row.
[model_text, model_num] = split_value(model_value);
[target_text, target_num] = split_value(target_value);
diff_val = NaN;
pct_diff = NaN;
if isfinite(model_num) && isfinite(target_num)
    diff_val = model_num - target_num;
    pct_diff = 100 * diff_val / max(abs(target_num), 1e-9);
    status = "TARGET_AVAILABLE";
elseif isfinite(model_num) && ~isfinite(target_num)
    status = "MODEL_PREDICTION_ONLY";
elseif ~isfinite(model_num) && isfinite(target_num)
    status = "TARGET_ONLY_OR_MODEL_UNAVAILABLE";
else
    status = "QUALITATIVE_OR_NOT_REPORTED";
end
rows(end + 1, :) = {string(metric), string(unit), model_text, target_text, ...
    diff_val, pct_diff, string(source), status, string(notes)};
end

function write_baseline_workbook(excel_path, summary_table, open_check, ...
    target_comparison, params, metrics, sim, clinical, scenario)
% WRITE_BASELINE_WORKBOOK - export timestamped baseline report.
writetable(summary_table, excel_path, 'Sheet', 'Summary');
writetable(open_check, excel_path, 'Sheet', 'ASD_Open_Mechanism');
writetable(target_comparison, excel_path, 'Sheet', 'Clinical_Target_Comparison');
writetable(build_key_output_table(metrics, params, sim), excel_path, ...
    'Sheet', 'Forward_Output');
writetable(build_parameter_table(params), excel_path, 'Sheet', 'Parameters_Used');
writetable(build_notes_table(clinical, scenario), excel_path, 'Sheet', 'Notes');
format_workbook_for_readability(excel_path);
end

function tbl = build_key_output_table(metrics, params, sim)
% BUILD_KEY_OUTPUT_TABLE - ordered model output table.
rows = {
    "Heart Rate", "bpm", params.HR
    "Cardiac Output", "L/min", field_or_nan(metrics, 'CO_Lmin')
    "Q_ASD", "L/min", field_or_nan(metrics, 'Q_ASD_Lmin')
    "Q_ASD mean", "mL/s", field_or_nan(metrics, 'Q_ASD_mean_mLs')
    "Q_ASD direction", "-", string(metrics.Q_ASD_direction)
    "Qp model", "L/min", field_or_nan(metrics, 'Qp_Lmin')
    "Qs model", "L/min", field_or_nan(metrics, 'Qs_Lmin')
    "Qp_Qs", "-", field_or_nan(metrics, 'QpQs')
    "LAP_mean", "mmHg", field_or_nan(metrics, 'LAP_mean')
    "RAP_mean", "mmHg", field_or_nan(metrics, 'RAP_mean')
    "P_LA_minus_P_RA", "mmHg", field_or_nan(metrics, 'LAP_mean') - field_or_nan(metrics, 'RAP_mean')
    "SBP", "mmHg", field_or_nan(metrics, 'SAP_max')
    "DBP", "mmHg", field_or_nan(metrics, 'SAP_min')
    "MAP", "mmHg", field_or_nan(metrics, 'SAP_mean')
    "PAP_sys", "mmHg", field_or_nan(metrics, 'PAP_max')
    "PAP_dia", "mmHg", field_or_nan(metrics, 'PAP_min')
    "PAP_mean", "mmHg", field_or_nan(metrics, 'PAP_mean')
    "LVEDV", "mL", field_or_nan(metrics, 'LVEDV')
    "LVESV", "mL", field_or_nan(metrics, 'LVESV')
    "RVEDV", "mL", field_or_nan(metrics, 'RVEDV')
    "RVESV", "mL", field_or_nan(metrics, 'RVESV')
    "LVEF", "-", field_or_nan(metrics, 'LVEF')
    "RVEF", "-", field_or_nan(metrics, 'RVEF')
    "SVR", "WU", field_or_nan(metrics, 'SVR')
    "PVR", "WU", field_or_nan(metrics, 'PVR')
    "solver success", "-", string(isfield(sim, 't') && ~isempty(sim.t) && all(isfinite(sim.V(:))))
    "steady state", "-", string(field_or_logical(sim, 'ss_reached'))
    };
tbl = cell2table(rows, 'VariableNames', {'Metric', 'Unit', 'Model_Output'});
end

function tbl = build_parameter_table(params)
% BUILD_PARAMETER_TABLE - relevant seeded parameters used by simulation.
rows = {
    "HR", "bpm", value_text(params.HR), "clinical common HR override"
    "T_HB", "s", value_text(60 / params.HR), "computed from final HR"
    "R.asd", "mmHg*s/mL", value_text(params.R.asd), "ignored in orifice mode"
    "asd.mode", "-", params.asd.mode, "flow model"
    "asd.diameter_mm", "mm", value_text(params.asd.diameter_mm), "clinical seed"
    "asd.area_mm2", "mm^2", value_text(params.asd.area_mm2), "clinical/derived geometry"
    "asd.Cd", "-", value_text(params.asd.Cd), "default uncalibrated coefficient"
    "C.SAR", "mL/mmHg", value_text(params.C.SAR), "seeded from Qs/HR over systemic pulse pressure"
    "C.PAR", "mL/mmHg", value_text(params.C.PAR), "seeded from Qp/HR over pulmonary pulse pressure"
    "R.SAR", "mmHg*s/mL", value_text(params.R.SAR), "scaled pediatric resistance"
    "R.PAR", "mmHg*s/mL", value_text(params.R.PAR), "scaled pediatric resistance"
    "V0.SVEN", "mL", value_text(params.V0.SVEN), "blood-volume reconciliation"
    };
tbl = cell2table(rows, 'VariableNames', {'Parameter', 'Unit', 'Value', 'Notes'});
end

function tbl = build_notes_table(clinical, scenario)
% BUILD_NOTES_TABLE - methodological boundaries.
src = clinical.(scenario);
rows = {
    "Scope", "Forward baseline simulation only. No GSA, optimization, or calibration."
    "ASD open mechanism", "orifice_bidirectional uses ASD area and Cd; R.asd=Inf does not close the shunt in this mode."
    "Direction convention", "Positive Q_ASD means LA_to_RA."
    "Pressure source", string(src.SAP_pressure_source)
    "Qp/Qs target", "Clinical Qp/Qs is a comparison target, not forced."
    "Direct Q_ASD", "Direct Q_shunt_Lmin is missing; Qp-Qs is reported as a derived comparison only."
    "Next step", "If forward output is physiologically plausible, review before GSA/optimization."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic', 'Note'});
end

function value = derived_qasd_target(src)
% DERIVED_QASD_TARGET - optional Qp-Qs derived target [L/min].
if isfield(src, 'Qp_Lmin') && isfinite(src.Qp_Lmin) && ...
        isfield(src, 'Qs_Lmin') && isfinite(src.Qs_Lmin)
    value = src.Qp_Lmin - src.Qs_Lmin;
else
    value = NaN;
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

function [text_value, num_value] = split_value(value)
num_value = NaN;
if isnumeric(value) && isscalar(value)
    num_value = value;
    text_value = value_text(value);
elseif islogical(value)
    text_value = string(value);
elseif isstring(value) || ischar(value)
    text_value = string(value);
else
    text_value = "";
end
end

function txt = value_text(value)
if isnumeric(value) && isscalar(value)
    if isfinite(value)
        txt = string(sprintf('%.10g', value));
    elseif isinf(value)
        txt = "Inf";
    else
        txt = "NaN";
    end
elseif isstring(value) || ischar(value)
    txt = string(value);
elseif islogical(value)
    txt = string(value);
else
    txt = "";
end
end

function format_workbook_for_readability(excel_path)
% FORMAT_WORKBOOK_FOR_READABILITY - optional Excel COM formatting.
if ~ispc
    return;
end
try
    excel = actxserver('Excel.Application');
    cleanup_obj = onCleanup(@() safe_quit_excel(excel));
    excel.Visible = false;
    excel.DisplayAlerts = false;
    workbook = excel.Workbooks.Open(excel_path);
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
    warning('run_zoya_asd_preclosure_baseline:formatSkipped', ...
        'Workbook readability formatting skipped: %s', ME.message);
end
end

function safe_quit_excel(excel)
try
    excel.Quit;
catch
end
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
