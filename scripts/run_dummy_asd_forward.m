%% run_dummy_asd_forward.m
% RUN_DUMMY_ASD_FORWARD
% -------------------------------------------------------------------------
% Forward-only plausibility runner for the literature-based pediatric ASD
% dummy case. This script intentionally does not run GSA, optimization,
% calibration, parameter tuning, Patient Zoya, or post-closure Jovano logic.
%
% WORKFLOW:
%   1. Simulate adult healthy closed-ASD reference from default parameters.
%   2. Simulate pediatric healthy closed-ASD reference using dummy
%      pre-closure anthropometry.
%   3. Simulate dummy ASD pre-closure using literature cohort medians.
%   4. Simulate dummy ASD post-closure with ASD closed.
%   5. Print key physiological checks and export timestamped Excel tables.
%
% METHODOLOGICAL LIMITATION:
%   The dummy pre-closure profile does not report ASD diameter, ASD area,
%   ASD pressure gradient, or directly measured shunt flow. Therefore, the
%   pre-closure run uses a clearly marked finite R.asd architecture-smoke
%   placeholder to activate the existing ASD LA-RA coupling. Qp/Qs remains a
%   comparison target and is not used to tune or calibrate this placeholder.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-28
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
    sprintf('dummy_asd_forward_%s.xlsx', timestamp));

fprintf('===============================================================\n');
fprintf('  Literature-Based ASD Dummy Forward Simulation\n');
fprintf('===============================================================\n');
fprintf('Mode: forward-only plausibility check; no GSA, no optimization.\n');

clinical = patient_dummy_ASD();
params_ref = default_parameters();

healthy_adult = run_forward_case('Healthy_Adult_ref', 'healthy_baseline', ...
    params_ref, clinical, struct());
pediatric_healthy = run_forward_case('Healthy_Pediatric_Dummy_Baseline', ...
    'healthy_pediatric_dummy', params_ref, clinical, clinical.pre_surgery);
pre = run_forward_case('Dummy_ASD_PreClosure', 'pre_surgery', ...
    params_ref, clinical, clinical.pre_surgery);
post = run_forward_case('Dummy_ASD_PostClosure', 'post_surgery', ...
    params_ref, clinical, clinical.post_surgery);

cases = {healthy_adult, pediatric_healthy, pre, post};
checks = build_plausibility_checks(healthy_adult, pediatric_healthy, pre, post);

fprintf('\nKey forward outputs:\n');
print_case_summary(cases);

fprintf('\nPlausibility checks:\n');
disp(checks(:, {'Check_Name', 'Status', 'Value_Text', 'Expected', 'Notes'}));

write_forward_workbook(output_path, clinical, cases, checks);

fprintf('\nExcel written:\n  %s\n', output_path);
fprintf('===============================================================\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function result = run_forward_case(case_name, scenario, params_ref, clinical, src)
% RUN_FORWARD_CASE - prepare params, integrate, and compute indices.
result = struct();
result.case_name = case_name;
result.scenario = scenario;
result.success = false;
result.error_message = "";
result.warning_id = "";
result.warning_message = "";
result.src = src;

try
    if strcmp(scenario, 'healthy_baseline')
        params = recompute_timing_params(params_ref);
        params = close_asd(params, 'healthy closed adult reference');
        patient = make_empty_patient();
        scaling_note = "adult reference; no pediatric scaling";
        HR_handling = "adult_reference";
    else
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

        if strcmp(scenario, 'pre_surgery')
            params = configure_dummy_preclosure_asd(params, src);
        elseif strcmp(scenario, 'healthy_pediatric_dummy')
            params = close_asd(params, ...
                'healthy pediatric dummy baseline closed; pre-closure anthropometry only');
        else
            params = close_asd(params, 'post-closure dummy ASD closed');
        end
    end

    lastwarn('');
    sim = integrate_system(params);
    [warn_msg, warn_id] = lastwarn;
    metrics = compute_clinical_indices(sim, params);

    result.success = true;
    result.params = params;
    result.patient = patient;
    if strcmp(scenario, 'healthy_pediatric_dummy')
        result.src = struct('BSA', patient.BSA, ...
            'scenario_label', 'healthy_pediatric_dummy');
    end
    result.sim = sim;
    result.metrics = metrics;
    result.scaling_note = string(scaling_note);
    result.HR_handling = string(HR_handling);
    result.mapping = describe_asd_mapping(params, scenario, src);
    result.local_validity = local_validity_flags(sim, metrics, params);
    result.warning_id = string(warn_id);
    result.warning_message = string(warn_msg);
catch ME
    result.error_message = string(ME.message);
end
end

function patient = make_empty_patient()
patient = struct();
patient.age_years = NaN;
patient.age_days = NaN;
patient.weight_kg = NaN;
patient.height_cm = NaN;
patient.sex = NaN;
patient.BSA = NaN;
patient.scaling_mode = 'adult_ref';
patient.weight_source = 'not_applicable';
end

function patient = make_scaling_patient(clinical, src, scenario)
% MAKE_SCALING_PATIENT - scenario-specific patient struct for apply_scaling.
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
    % Mosteller inverse is a model-only helper because apply_scaling needs
    % body mass for blood-volume reconciliation. It is not stored as a
    % reported clinical weight and is not used as a calibration target.
    patient.weight_kg = (patient.BSA^2 * 3600) / patient.height_cm;
    patient.weight_source = 'derived_inverse_mosteller_for_scaling_only';
else
    error('run_dummy_asd_forward:missingAnthropometry', ...
        'Cannot build %s scaling patient: weight missing and BSA/height unavailable.', scenario);
end
end

function params = configure_dummy_preclosure_asd(params, src)
% CONFIGURE_DUMMY_PRECLOSURE_ASD - open ASD for architecture smoke test.
fallback_R_asd = 0.10; % [mmHg*s/mL] finite smoke-test placeholder, not calibrated

params.asd.mode = lower(char(first_valid_text(src, 'ASD_mode', 'linear_bidirectional')));
params.asd.diameter_mm = first_valid(src, {'ASD_diameter_mm'}, NaN);
params.asd.area_mm2 = first_valid(src, {'ASD_area_mm2'}, NaN);
if ~isfinite(params.asd.area_mm2) && isfinite(params.asd.diameter_mm)
    params.asd.area_mm2 = pi * (params.asd.diameter_mm / 2)^2; % [mm^2]
end

has_gradient = isfield(src, 'ASD_gradient_mmHg') && isfinite(src.ASD_gradient_mmHg);
has_flow = isfield(src, 'Q_shunt_Lmin') && isfinite(src.Q_shunt_Lmin);
has_geometry = isfinite(params.asd.area_mm2) && params.asd.area_mm2 > 0;

if has_gradient && has_flow && abs(src.Q_shunt_Lmin) > 1e-9
    q_shunt_mLs = abs(src.Q_shunt_Lmin) * params.conv.Lmin_to_mLs; % [mL/s]
    params.R.asd = abs(src.ASD_gradient_mmHg) / max(q_shunt_mLs, 1e-9);
    params.asd.mapping_status = 'clinical_gradient_and_flow_resistance';
elseif has_geometry
    params.asd.mode = 'orifice_bidirectional';
    params.R.asd = Inf;
    params.asd.mapping_status = 'orifice_geometry_from_reported_area_or_diameter';
else
    params.asd.mode = 'linear_bidirectional';
    params.R.asd = fallback_R_asd;
    params.asd.area_mm2 = 0;
    params.asd.diameter_mm = NaN;
    params.asd.mapping_status = ...
        'finite_R_asd_architecture_placeholder_no_reported_geometry_or_gradient';
    params.asd.placeholder_R_asd_mmHg_s_per_mL = fallback_R_asd;
end
end

function params = close_asd(params, note)
% CLOSE_ASD - enforce closed ASD convention.
params.R.asd = Inf;                   % [mmHg*s/mL]
params.asd.mode = 'linear_bidirectional';
params.asd.area_mm2 = 0;              % [mm^2]
params.asd.diameter_mm = 0;           % [mm]
params.asd.mapping_status = char(note);
end

function mapping = describe_asd_mapping(params, scenario, src)
% DESCRIBE_ASD_MAPPING - record shunt configuration for outputs.
mapping = struct();
mapping.scenario = string(scenario);
mapping.status = "closed";
if strcmp(scenario, 'pre_surgery') && isfinite(params.R.asd)
    mapping.status = "open_placeholder";
elseif strcmp(scenario, 'pre_surgery') && isfield(params.asd, 'area_mm2') && params.asd.area_mm2 > 0
    mapping.status = "open_orifice";
end
mapping.mode = string(params.asd.mode);
mapping.R_asd = params.R.asd;
mapping.area_mm2 = params.asd.area_mm2;
mapping.diameter_mm = params.asd.diameter_mm;
mapping.mapping_status = string(params.asd.mapping_status);
if any(strcmp(scenario, {'pre_surgery', 'post_surgery'}))
    mapping.QpQs_target = first_valid(src, {'QpQs'}, NaN);
    mapping.QpQs_from_CI = first_valid(src, {'QpQs_from_CI'}, NaN);
else
    mapping.QpQs_target = NaN;
    mapping.QpQs_from_CI = NaN;
end
end

function validity = local_validity_flags(sim, metrics, params)
% LOCAL_VALIDITY_FLAGS - ASD-safe numerical validity summary.
validity = struct();
validity.solver_success = isfield(sim, 't') && ~isempty(sim.t) && ...
    isfield(sim, 'V') && all(isfinite(sim.V(:)));
validity.steady_state_reached = isfield(sim, 'ss_reached') && sim.ss_reached;
validity.closed_asd_ok = isinf(params.R.asd) && ...
    abs(field_or_nan(metrics, 'Q_ASD_mean_mLs')) < 1e-6;
validity.qpqs_finite = isfinite(field_or_nan(metrics, 'QpQs'));
validity.qasd_finite = isfinite(field_or_nan(metrics, 'Q_ASD_mean_mLs'));
end

function checks = build_plausibility_checks(healthy, pediatric_healthy, pre, post)
% BUILD_PLAUSIBILITY_CHECKS - explicit pass/fail/observe rows.
rows = {};
rows = add_check(rows, 'Healthy_QpQs_near_1', ...
    abs(field_or_nan(healthy.metrics, 'QpQs') - 1) <= 0.05, ...
    sprintf('%.6f', field_or_nan(healthy.metrics, 'QpQs')), ...
    'abs(Qp/Qs - 1) <= 0.05', 'Healthy closed circuit.');
rows = add_check(rows, 'Healthy_Q_ASD_near_0', ...
    abs(field_or_nan(healthy.metrics, 'Q_ASD_mean_mLs')) <= 1e-6, ...
    sprintf('%.6g mL/s', field_or_nan(healthy.metrics, 'Q_ASD_mean_mLs')), ...
    'Q_ASD approximately 0', 'Default healthy baseline should be closed.');
rows = add_check(rows, 'PediatricHealthy_QpQs_near_1', ...
    abs(field_or_nan(pediatric_healthy.metrics, 'QpQs') - 1) <= 0.05, ...
    sprintf('%.6f', field_or_nan(pediatric_healthy.metrics, 'QpQs')), ...
    'abs(Qp/Qs - 1) <= 0.05', ...
    'Dummy-size pediatric healthy baseline should remain a closed circuit.');
rows = add_check(rows, 'PediatricHealthy_Q_ASD_near_0', ...
    abs(field_or_nan(pediatric_healthy.metrics, 'Q_ASD_mean_mLs')) <= 1e-6, ...
    sprintf('%.6g mL/s', field_or_nan(pediatric_healthy.metrics, 'Q_ASD_mean_mLs')), ...
    'Q_ASD approximately 0', ...
    'Uses dummy pre-closure anthropometry but no ASD disease shunt.');
rows = add_check(rows, 'PreClosure_Q_ASD_nonzero', ...
    abs(field_or_nan(pre.metrics, 'Q_ASD_mean_mLs')) > 1e-3, ...
    sprintf('%.6f mL/s', field_or_nan(pre.metrics, 'Q_ASD_mean_mLs')), ...
    'abs(Q_ASD) > 1e-3 mL/s', 'Forward-only ASD pathway activation.');
rows = add_check(rows, 'PreClosure_direction_LA_to_RA', ...
    any(strcmp(field_or_string(pre.metrics, 'ASD_direction'), ["left_to_right", "LA_to_RA"])), ...
    field_or_string(pre.metrics, 'ASD_direction'), ...
    'LA_to_RA / left_to_right', 'Positive Q_ASD means LA -> RA.');
rows = add_check(rows, 'PreClosure_QpQs_above_1', ...
    field_or_nan(pre.metrics, 'QpQs') > 1.0, ...
    sprintf('%.6f', field_or_nan(pre.metrics, 'QpQs')), ...
    'Qp/Qs > 1', 'Exact literature target is not required in forward-only phase.');
rows = add_check(rows, 'PreClosure_RV_flow_or_SV_exceeds_LV', ...
    field_or_nan(pre.metrics, 'Qp_Lmin') > field_or_nan(pre.metrics, 'Qs_Lmin') || ...
    field_or_nan(pre.metrics, 'RVSV') > field_or_nan(pre.metrics, 'LVSV'), ...
    sprintf('Qp-Qs %.6f L/min; RVSV-LVSV %.6f mL', ...
        field_or_nan(pre.metrics, 'Qp_Lmin') - field_or_nan(pre.metrics, 'Qs_Lmin'), ...
        field_or_nan(pre.metrics, 'RVSV') - field_or_nan(pre.metrics, 'LVSV')), ...
    'Qp > Qs or RVSV > LVSV', 'Expected RV-side volume/flow loading in ASD.');
rows = add_check(rows, 'PostClosure_Q_ASD_near_0', ...
    abs(field_or_nan(post.metrics, 'Q_ASD_mean_mLs')) <= 1e-6, ...
    sprintf('%.6g mL/s', field_or_nan(post.metrics, 'Q_ASD_mean_mLs')), ...
    'Q_ASD approximately 0', 'Post-closure ASD forced closed.');
rows = add_check(rows, 'PostClosure_QpQs_near_1', ...
    abs(field_or_nan(post.metrics, 'QpQs') - 1) <= 0.05, ...
    sprintf('%.6f', field_or_nan(post.metrics, 'QpQs')), ...
    'abs(Qp/Qs - 1) <= 0.05', 'Closed circuit should return Qp/Qs toward 1.');
rows = add_check(rows, 'RV_indexed_load_decreases_pre_to_post', ...
    indexed_metric(post, 'RVEDV') < indexed_metric(pre, 'RVEDV') || ...
    indexed_metric(post, 'RVSV') < indexed_metric(pre, 'RVSV'), ...
    sprintf('Delta RVEDVi %.6f mL/m2; Delta RVSVi %.6f mL/m2', ...
        indexed_metric(post, 'RVEDV') - indexed_metric(pre, 'RVEDV'), ...
        indexed_metric(post, 'RVSV') - indexed_metric(pre, 'RVSV')), ...
    'post RVEDVi or RVSVi lower than pre', ...
    'Indexed comparison is used because post-closure cohort is older/larger.');
rows = add_check(rows, 'LV_filling_or_output_improves_pre_to_post', ...
    field_or_nan(post.metrics, 'LVEDV') > field_or_nan(pre.metrics, 'LVEDV') || ...
    field_or_nan(post.metrics, 'CO_Lmin') > field_or_nan(pre.metrics, 'CO_Lmin'), ...
    sprintf('Delta LVEDV %.6f mL; Delta CO %.6f L/min', ...
        field_or_nan(post.metrics, 'LVEDV') - field_or_nan(pre.metrics, 'LVEDV'), ...
        field_or_nan(post.metrics, 'CO_Lmin') - field_or_nan(pre.metrics, 'CO_Lmin')), ...
    'post LVEDV or CO higher than pre', ...
    'Expected trend after ASD closure, not an optimization target.');

checks = cell2table(rows, 'VariableNames', ...
    {'Check_Name', 'Passed', 'Status', 'Value_Text', 'Expected', 'Notes'});
end

function rows = add_check(rows, name, passed, value_text, expected, notes)
if passed
    status = "PASS";
else
    status = "OBSERVE";
end
rows(end + 1, :) = {string(name), logical(passed), status, ...
    string(value_text), string(expected), string(notes)};
end

function write_forward_workbook(output_path, clinical, cases, checks)
% WRITE_FORWARD_WORKBOOK - export timestamped Excel-ready workbook.
adult_healthy = cases{1};
pediatric_healthy = cases{2};
pre = cases{3};
post = cases{4};

writetable(build_workbook_summary_table(cases, checks), output_path, ...
    'Sheet', 'Summary');
writetable(build_standard_metric_table(adult_healthy, 'forward_output'), ...
    output_path, 'Sheet', 'Forward_Output_Healthy_Adult');
writetable(build_standard_metric_table(pediatric_healthy, 'forward_output'), ...
    output_path, 'Sheet', 'Forward_Output_Healthy_Ped');
writetable(build_standard_metric_table(pre, 'forward_output'), ...
    output_path, 'Sheet', 'Forward_Output_PreClosure');
writetable(build_standard_metric_table(post, 'forward_output'), ...
    output_path, 'Sheet', 'Forward_Output_PostClosure');
writetable(build_case_target_comparison(pre, 'pre_closure'), ...
    output_path, 'Sheet', 'PreClosure_Target_Comparison');
writetable(build_case_target_comparison(post, 'post_closure'), ...
    output_path, 'Sheet', 'PostClosure_Target_Comparison');
writetable(build_all_parameters_table(cases), output_path, ...
    'Sheet', 'Parameter_Values_Used');
writetable(build_range_check_table(cases), output_path, 'Sheet', 'Range_Check');
writetable(build_interpretation_table(cases), output_path, 'Sheet', 'Interpretation');
writetable(build_notes_table(cases, checks, clinical), output_path, 'Sheet', 'Notes');
format_workbook_for_readability(output_path);
end

function tbl = build_workbook_summary_table(cases, checks)
% BUILD_WORKBOOK_SUMMARY_TABLE - plain-language workbook change log.
pre = cases{3};
post = cases{4};
rows = {
    "Workbook purpose", "Cleaned dummy ASD forward workbook export only; no model equations, parameters, R_ASD tuning, GSA, or optimization changed."
    "Metric order", "All vertical output and comparison sheets use the same primary metric order requested in the task."
    "Target_Range", "Added to forward output sheets, pre/post target comparison sheets, and Range_Check."
    "Range_Status", "Added to forward output sheets, pre/post target comparison sheets, and Range_Check."
    "Healthy adult baseline role", sprintf('Global integrity check: Qp/Qs %.6f, Q_ASD %.6g mL/s.', field_or_nan(cases{1}.metrics, 'QpQs'), field_or_nan(cases{1}.metrics, 'Q_ASD_mean_mLs'))
    "Healthy pediatric baseline role", sprintf('Dummy-size closed-shunt comparator: Qp/Qs %.6f, Q_ASD %.6g mL/s.', field_or_nan(cases{2}.metrics, 'QpQs'), field_or_nan(cases{2}.metrics, 'Q_ASD_mean_mLs'))
    "Dummy pre-closure behavior", sprintf('Forward-only open ASD: Qp/Qs %.6f, Q_ASD %.6f L/min, direction %s.', field_or_nan(pre.metrics, 'QpQs'), field_or_nan(pre.metrics, 'Q_ASD_Lmin'), char(field_or_string(pre.metrics, 'ASD_direction')))
    "Dummy post-closure behavior", sprintf('Closed ASD: Qp/Qs %.6f, Q_ASD %.6g mL/s.', field_or_nan(post.metrics, 'QpQs'), field_or_nan(post.metrics, 'Q_ASD_mean_mLs'))
    "Plausibility checks", sprintf('%d of %d checks passed; OBSERVE rows are documentation flags, not calibration failures.', sum(checks.Passed), height(checks))
    "Sheet naming note", "Forward_Output_Healthy_Ped is used because Excel sheet names have a 31-character limit."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic', 'Details'});
end

function tbl = build_standard_metric_table(c, context)
% BUILD_STANDARD_METRIC_TABLE - one ordered table for output/comparison sheets.
rows = {};
specs = metric_specs();
for idx = 1:numel(specs)
    spec = specs(idx);
    [model_value, model_num] = metric_model_value(c, spec);
    [target_value, target_num, target_type, target_source, notes] = ...
        metric_target_value(c, spec, context);
    target_range = metric_target_range(c, spec, target_value, target_type);
    range_status = evaluate_range_status(model_num, target_range, spec.Name, ...
        target_value, target_type, c.scenario);
    [difference, percent_difference] = compare_model_to_target(model_num, target_num);
    literature_target_text = target_value_to_text(target_value, target_type);

    rows(end + 1, :) = {idx, string(c.case_name), string(c.scenario), ...
        string(spec.Name), string(spec.Unit), value_to_text(model_value), ...
        literature_target_text, difference, percent_difference, ...
        string(target_range), string(range_status), string(target_type), ...
        string(target_source), string(notes)}; %#ok<AGROW>
end

tbl = cell2table(rows, 'VariableNames', {'Metric_Order', 'Case_Name', ...
    'Scenario', 'Metric', 'Unit', 'Model_Output', 'Literature_Target', ...
    'Difference', 'Percent_Difference', 'Target_Range', 'Range_Status', ...
    'Target_Type', 'Target_Source', 'Notes'});
end

function txt = target_value_to_text(value, target_type)
if is_missing_value(value)
    if strcmp(target_type, 'Not reported')
        txt = "Not reported";
    elseif any(strcmp(target_type, ["Adult normal range", "Pediatric normal range"]))
        txt = "Range-based target";
    elseif strcmp(target_type, 'Model prediction only')
        txt = "Model prediction only";
    else
        txt = "Not applicable";
    end
else
    txt = value_to_text(value);
end
end

function specs = metric_specs()
% METRIC_SPECS - canonical metric order for dummy ASD workbook exports.
raw = {
    'Heart Rate', 'bpm'
    'Cardiac Output', 'L/min'
    'LV Stroke Volume', 'mL'
    'RV Stroke Volume', 'mL'
    'LVEF', '%'
    'RVEF', '%'
    'LVEDV', 'mL'
    'LVESV', 'mL'
    'RVEDV', 'mL'
    'RVESV', 'mL'
    'SVR', 'WU'
    'PVR', 'WU'
    'SBP', 'mmHg'
    'DBP', 'mmHg'
    'MAP', 'mmHg'
    'PAP_sys', 'mmHg'
    'PAP_dia', 'mmHg'
    'PAP_mean', 'mmHg'
    'LVESP', 'mmHg'
    'LVEDP', 'mmHg'
    'RVESP', 'mmHg'
    'RVEDP', 'mmHg'
    'LAP_mean', 'mmHg'
    'RAP_mean', 'mmHg'
    'PWP_mean', 'mmHg'
    'Qp_Qs', '-'
    'Q_ASD mean', 'mL/s'
    'Q_ASD direction', '-'
    'Q_ASD L/min', 'L/min'
    'R_ASD', 'mmHg*s/mL'
    'ASD status', '-'
    'Qp model', 'L/min'
    'Qs model', 'L/min'
    'Qp/Qs from CI target', '-'
    'Cardiac index', 'L/min/m^2'
    'solver success', '-'
    'steady state', '-'
    'warning', '-'
    };
for idx = size(raw, 1):-1:1
    specs(idx).Name = raw{idx, 1};
    specs(idx).Unit = raw{idx, 2};
end
end

function [value, num_value] = metric_model_value(c, spec)
% METRIC_MODEL_VALUE - value used in ordered workbook rows.
metric = char(spec.Name);
switch metric
    case 'Heart Rate'
        value = c.params.HR;
    case 'Cardiac Output'
        value = field_or_nan(c.metrics, 'CO_Lmin');
    case 'LV Stroke Volume'
        value = field_or_nan(c.metrics, 'LVSV');
    case 'RV Stroke Volume'
        value = field_or_nan(c.metrics, 'RVSV');
    case 'LVEF'
        value = 100 * field_or_nan(c.metrics, 'LVEF');
    case 'RVEF'
        value = 100 * field_or_nan(c.metrics, 'RVEF');
    case 'LVEDV'
        value = field_or_nan(c.metrics, 'LVEDV');
    case 'LVESV'
        value = field_or_nan(c.metrics, 'LVESV');
    case 'RVEDV'
        value = field_or_nan(c.metrics, 'RVEDV');
    case 'RVESV'
        value = field_or_nan(c.metrics, 'RVESV');
    case 'SVR'
        value = field_or_nan(c.metrics, 'SVR');
    case 'PVR'
        value = field_or_nan(c.metrics, 'PVR');
    case 'SBP'
        value = field_or_nan(c.metrics, 'SAP_max');
    case 'DBP'
        value = field_or_nan(c.metrics, 'SAP_min');
    case 'MAP'
        value = field_or_nan(c.metrics, 'SAP_mean');
    case 'PAP_sys'
        value = field_or_nan(c.metrics, 'PAP_max');
    case 'PAP_dia'
        value = field_or_nan(c.metrics, 'PAP_min');
    case 'PAP_mean'
        value = field_or_nan(c.metrics, 'PAP_mean');
    case 'LVESP'
        value = field_or_nan(c.metrics, 'LVP_max');
    case 'LVEDP'
        value = field_or_nan(c.metrics, 'LVEDP');
    case 'RVESP'
        value = field_or_nan(c.metrics, 'RVP_max');
    case 'RVEDP'
        value = field_or_nan(c.metrics, 'RVEDP');
    case 'LAP_mean'
        value = field_or_nan(c.metrics, 'LAP_mean');
    case 'RAP_mean'
        value = field_or_nan(c.metrics, 'RAP_mean');
    case 'PWP_mean'
        value = field_or_nan(c.metrics, 'PWP_mean');
    case 'Qp_Qs'
        value = field_or_nan(c.metrics, 'QpQs');
    case 'Q_ASD mean'
        value = field_or_nan(c.metrics, 'Q_ASD_mean_mLs');
    case 'Q_ASD direction'
        value = field_or_string(c.metrics, 'ASD_direction');
    case 'Q_ASD L/min'
        value = field_or_nan(c.metrics, 'Q_ASD_Lmin');
    case 'R_ASD'
        value = c.mapping.R_asd;
    case 'ASD status'
        value = c.mapping.status;
    case 'Qp model'
        value = field_or_nan(c.metrics, 'Qp_Lmin');
    case 'Qs model'
        value = field_or_nan(c.metrics, 'Qs_Lmin');
    case 'Qp/Qs from CI target'
        value = field_or_nan(c.metrics, 'QpQs');
    case 'Cardiac index'
        value = cardiac_index(c);
    case 'solver success'
        value = c.success;
    case 'steady state'
        value = field_or_logical(c.sim, 'ss_reached');
    case 'warning'
        value = c.warning_message;
    otherwise
        value = NaN;
end
[num_value, ~] = split_value(value);
end

function [value, num_value, target_type, target_source, notes] = ...
    metric_target_value(c, spec, context)
% METRIC_TARGET_VALUE - scenario-aware literature/normal target metadata.
metric = char(spec.Name);
value = NaN;
target_type = "Not reported";
target_source = "Not reported";
notes = "";

if strcmp(c.scenario, 'healthy_baseline')
    target_type = "Adult normal range";
    target_source = "Adult baseline literature/reference table";
    notes = "Healthy adult range used for range status.";
elseif strcmp(c.scenario, 'healthy_pediatric_dummy')
    target_type = "Pediatric normal range";
    target_source = "Pediatric reference range table";
    notes = "Healthy pediatric dummy baseline uses pre-closure anthropometry with ASD closed.";
elseif strcmp(c.scenario, 'pre_surgery')
    notes = "Disease pre-closure ASD is forward-only; healthy-range mismatch is not calibration failure.";
elseif strcmp(c.scenario, 'post_surgery')
    target_type = "Pediatric normal range";
    target_source = "Pediatric reference range table";
    notes = "Post-closure scenario is closed ASD; pediatric normal range is used as context.";
end

if any(strcmp(c.scenario, {'pre_surgery', 'post_surgery'}))
    [lit_value, lit_type, lit_source, lit_note] = literature_target_for_metric(c, metric);
    if ~is_missing_value(lit_value)
        value = lit_value;
        num_value = numeric_or_nan(value);
        target_type = lit_type;
        target_source = lit_source;
        notes = lit_note;
        return;
    end
end

if strcmp(metric, 'solver success')
    value = true;
    target_type = "Numerical quality target";
    target_source = "Runner validity check";
    notes = "Expected true for all forward simulations.";
elseif strcmp(metric, 'steady state')
    value = true;
    target_type = "Numerical quality target";
    target_source = "integrate_system steady-state flag";
    notes = "Expected true before interpreting clinical metrics.";
elseif strcmp(metric, 'warning')
    value = "";
    target_type = "Runtime warning target";
    target_source = "MATLAB lastwarn";
    notes = "Blank warning is expected; any warning should be reviewed.";
elseif any(strcmp(metric, {'Q_ASD direction', 'ASD status'}))
    value = qualitative_target_for_metric(c, metric);
    target_type = "Qualitative model-state target";
    target_source = "Scenario definition";
elseif strcmp(metric, 'R_ASD')
    value = c.mapping.R_asd;
    target_type = "Model setting only";
    target_source = "ASD runner mapping";
    notes = string(c.mapping.mapping_status);
elseif strcmp(metric, 'Qp/Qs from CI target')
    value = c.mapping.QpQs_from_CI;
    if ~isfinite(value)
        value = NaN;
    else
        target_type = "Literature dummy target";
        target_source = "Sjoberg 2024 Table 1 derived from CI medians";
        notes = "Cohort medians are not internally constrained.";
    end
end

num_value = numeric_or_nan(value);

if is_missing_value(value) && any(strcmp(c.scenario, {'pre_surgery', 'post_surgery'}))
    target_type = "Not reported";
    target_source = "Not reported";
end

if strcmp(context, 'range_check') && is_missing_value(value)
    notes = "Range-only row; literature target unavailable unless stated.";
end
end

function [value, target_type, target_source, notes] = literature_target_for_metric(c, metric)
% LITERATURE_TARGET_FOR_METRIC - reported/derived dummy targets.
value = NaN;
target_type = "Not reported";
target_source = "Not reported";
notes = "Not reported in patient_dummy_ASD.m.";

switch metric
    case 'Heart Rate'
        value = field_or_nan(c.src, 'HR');
        target_source = "Sjoberg 2024 Table 1";
        notes = "Directly reported cohort median.";
    case 'Cardiac Output'
        value = field_or_nan(c.src, 'CO_Lmin');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived as LV cardiac index times BSA.";
    case 'LV Stroke Volume'
        value = field_or_nan(c.src, 'LVSV_mL');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived as LV SVi times BSA.";
    case 'RV Stroke Volume'
        value = field_or_nan(c.src, 'RVSV_mL');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived as RV SVi times BSA.";
    case 'LVEF'
        value = 100 * field_or_nan(c.src, 'LVEF');
        target_source = "Sjoberg 2024 Table 1";
        notes = "Reported EF percent, stored in profile as fraction.";
    case 'RVEF'
        value = 100 * field_or_nan(c.src, 'RVEF');
        target_source = "Sjoberg 2024 Table 1";
        notes = "Reported EF percent, stored in profile as fraction.";
    case 'LVEDV'
        value = field_or_nan(c.src, 'LVEDV_mL');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived as LV EDVi times BSA.";
    case 'LVESV'
        value = field_or_nan(c.src, 'LVESV_mL');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived as LV ESVi times BSA.";
    case 'RVEDV'
        value = field_or_nan(c.src, 'RVEDV_mL');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived as RV EDVi times BSA.";
        if strcmp(c.scenario, 'post_surgery') && isfield(c.src, 'RVEDVi_source_limitation')
            notes = string(c.src.RVEDVi_source_limitation);
        end
    case 'RVESV'
        value = field_or_nan(c.src, 'RVESV_mL');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived as RV ESVi times BSA.";
    case 'SBP'
        value = field_or_nan(c.src, 'SAP_sys_mmHg');
        target_source = "Sjoberg 2024 Table 1";
        notes = "Directly reported cohort median.";
    case 'DBP'
        value = field_or_nan(c.src, 'SAP_dia_mmHg');
        target_source = "Sjoberg 2024 Table 1";
        notes = "Directly reported cohort median.";
    case 'MAP'
        value = first_valid(c.src, {'SAP_mean_mmHg', 'MAP_mmHg'}, NaN);
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived from reported SBP and DBP.";
    case 'Qp_Qs'
        value = field_or_nan(c.src, 'QpQs');
        target_source = "Sjoberg 2024 Table 1";
        notes = "Reported Qp/Qs is a comparison target, not forced.";
    case 'Q_ASD L/min'
        value = first_valid(c.src, {'Q_shunt_Lmin', 'Q_ASD_target_Lmin'}, NaN);
        target_source = "patient_dummy_ASD.m";
        notes = "Direct shunt flow is not reported pre-closure; post-closure target is closed-shunt zero.";
    case 'Q_ASD mean'
        q_lmin = first_valid(c.src, {'Q_shunt_Lmin', 'Q_ASD_target_Lmin'}, NaN);
        if isfinite(q_lmin)
            value = q_lmin * 1000 / 60; % [mL/s]
        end
        target_source = "patient_dummy_ASD.m";
        notes = "Converted from L/min target when available.";
    case 'Qp model'
        value = field_or_nan(c.src, 'Qp_Lmin');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived from RV cardiac index times BSA.";
    case 'Qs model'
        value = field_or_nan(c.src, 'Qs_Lmin');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived from LV cardiac index times BSA.";
    case 'Qp/Qs from CI target'
        value = field_or_nan(c.src, 'QpQs_from_CI');
        target_source = "Sjoberg 2024 Table 1 derived";
        notes = "Derived from RV_CI/LV_CI cohort medians.";
    case 'Cardiac index'
        value = field_or_nan(c.src, 'LV_CI_Lmin_m2');
        target_source = "Sjoberg 2024 Table 1";
        notes = "LV cardiac index cohort median.";
    otherwise
        value = NaN;
end

if ~is_missing_value(value)
    target_type = "Literature dummy target";
end
end

function target = qualitative_target_for_metric(c, metric)
target = "";
if strcmp(metric, 'Q_ASD direction')
    if strcmp(c.scenario, 'pre_surgery')
        target = "LA_to_RA expected";
    else
        target = "none";
    end
elseif strcmp(metric, 'ASD status')
    if strcmp(c.scenario, 'pre_surgery')
        target = "open ASD";
    else
        target = "closed";
    end
end
end

function target_range = metric_target_range(c, spec, target_value, target_type)
% METRIC_TARGET_RANGE - range string shown in workbook.
metric = char(spec.Name);
target_range = "--";
if any(strcmp(metric, {'solver success', 'steady state', 'warning', ...
        'Q_ASD direction', 'ASD status', 'R_ASD', 'Qp model', ...
        'Qs model', 'Qp/Qs from CI target', 'Cardiac index'}))
    return;
end

if strcmp(c.scenario, 'healthy_baseline')
    target_range = normal_range_for_metric(metric, 'adult');
elseif strcmp(c.scenario, 'healthy_pediatric_dummy') || strcmp(c.scenario, 'post_surgery')
    target_range = normal_range_for_metric(metric, 'pediatric');
elseif strcmp(c.scenario, 'pre_surgery')
    if ~is_missing_value(target_value)
        target_range = "Literature target available";
    else
        target_range = "Not reported";
    end
end

if is_missing_value(target_value) && strcmp(target_type, 'Not reported') && ...
        strcmp(c.scenario, 'pre_surgery')
    target_range = "Not reported";
end
end

function range_text = normal_range_for_metric(metric, population)
% NORMAL_RANGE_FOR_METRIC - user-provided normal target ranges.
range_text = "--";
is_adult = strcmp(population, 'adult');
switch metric
    case 'Heart Rate'
        range_text = ternary_text(is_adult, "61-87", "73-142");
    case 'Cardiac Output'
        range_text = ternary_text(is_adult, "4-8", "2.2-4.85");
    case 'LV Stroke Volume'
        range_text = ternary_text(is_adult, "60-100", "15-25");
    case 'RV Stroke Volume'
        range_text = "--";
    case 'LVEF'
        range_text = ternary_text(is_adult, "52-72", "55-73");
    case 'RVEF'
        range_text = ternary_text(is_adult, "50-66", "45-78");
    case 'LVEDV'
        range_text = ternary_text(is_adult, "87-137", "25-41");
    case 'LVESV'
        range_text = ternary_text(is_adult, "31-51", "10-16");
    case 'RVEDV'
        range_text = ternary_text(is_adult, "64.6-160.5", "30.73-65.68");
    case 'RVESV'
        range_text = ternary_text(is_adult, "18.5-81.2", "7-29");
    case 'SVR'
        range_text = ternary_text(is_adult, "9.1-31.5", "13.8-33");
    case 'PVR'
        range_text = ternary_text(is_adult, "0.3-2", "<6");
    case 'SBP'
        range_text = ternary_text(is_adult, "128-156", "90-103");
    case 'DBP'
        range_text = ternary_text(is_adult, "80-96", "47-59");
    case 'MAP'
        range_text = ternary_text(is_adult, "70-100", "61-74");
    case 'PAP_sys'
        range_text = ternary_text(is_adult, "15-30", "<32.9");
    case 'PAP_dia'
        range_text = ternary_text(is_adult, "4-12", "<14.95");
    case 'PAP_mean'
        range_text = ternary_text(is_adult, "8-20", "<21");
    case 'LVESP'
        range_text = ternary_text(is_adult, "90-140", "--");
    case 'LVEDP'
        range_text = ternary_text(is_adult, "3-12", "--");
    case 'RVESP'
        range_text = ternary_text(is_adult, "20-30", "<35");
    case 'RVEDP'
        range_text = ternary_text(is_adult, "<8", "--");
    case 'LAP_mean'
        range_text = ternary_text(is_adult, "2-12", "2-10");
    case 'RAP_mean'
        range_text = ternary_text(is_adult, "2-6", "3-6");
    case 'PWP_mean'
        range_text = ternary_text(is_adult, "<15", "<12");
    case 'Qp_Qs'
        range_text = "1.0 (normal)";
end
end

function status = evaluate_range_status(model_num, target_range, metric, target_value, ...
    target_type, scenario)
% EVALUATE_RANGE_STATUS - parse range strings and return standardized status.
range_text = strtrim(char(target_range));
if isempty(range_text) || strcmp(range_text, '--')
    if any(strcmp(metric, {'Q_ASD direction', 'ASD status', 'solver success', ...
            'steady state', 'warning', 'R_ASD'}))
        status = "TARGET_IS_QUALITATIVE";
    else
        status = "NOT_APPLICABLE";
    end
    return;
end
if strcmpi(range_text, 'Not reported')
    if strcmp(target_type, 'Not reported')
        status = "NOT_REPORTED";
    else
        status = "MODEL_PREDICTION_ONLY";
    end
    return;
end
if contains(range_text, 'Literature target available')
    status = "NOT_APPLICABLE";
    return;
end
if any(strcmp(metric, {'Q_ASD direction', 'ASD status', 'solver success', ...
        'steady state', 'warning'}))
    status = "TARGET_IS_QUALITATIVE";
    return;
end
if ~isfinite(model_num)
    if is_missing_value(target_value)
        status = "NOT_REPORTED";
    else
        status = "MODEL_PREDICTION_ONLY";
    end
    return;
end
if strcmp(range_text, '1.0 (normal)')
    if abs(model_num - 1) <= 0.05
        status = "TARGET_IS_NORMAL_QPQS";
    elseif model_num < 1
        status = "OUT_OF_RANGE_LOW";
    else
        status = "OUT_OF_RANGE_HIGH";
    end
    return;
end
if startsWith(range_text, '<')
    upper = str2double(strtrim(extractAfter(string(range_text), 1)));
    if model_num < upper
        status = "WITHIN_RANGE";
    else
        status = "OUT_OF_RANGE_HIGH";
    end
    return;
end
if startsWith(range_text, '>')
    lower = str2double(strtrim(extractAfter(string(range_text), 1)));
    if model_num > lower
        status = "WITHIN_RANGE";
    else
        status = "OUT_OF_RANGE_LOW";
    end
    return;
end
parts = split(string(range_text), '-');
if numel(parts) == 2
    lower = str2double(parts(1));
    upper = str2double(parts(2));
    if model_num < lower
        status = "OUT_OF_RANGE_LOW";
    elseif model_num > upper
        status = "OUT_OF_RANGE_HIGH";
    else
        status = "WITHIN_RANGE";
    end
else
    status = "TARGET_IS_QUALITATIVE";
end

if strcmp(scenario, 'pre_surgery') && startsWith(status, "OUT_OF_RANGE")
    % The status is retained for transparency, but disease pre-closure rows
    % must not be interpreted as healthy-baseline failures.
    status = string(status);
end
end

function [difference, percent_difference] = compare_model_to_target(model_num, target_num)
if isfinite(model_num) && isfinite(target_num)
    difference = model_num - target_num;
    percent_difference = 100 * difference / max(abs(target_num), 1e-9);
else
    difference = NaN;
    percent_difference = NaN;
end
end

function value = numeric_or_nan(raw_value)
[value, ~] = split_value(raw_value);
end

function txt = ternary_text(condition, true_text, false_text)
if condition
    txt = true_text;
else
    txt = false_text;
end
end

function tbl = build_all_parameters_table(cases)
tbl = build_parameters_table(cases{1});
for idx = 2:numel(cases)
    tbl = [tbl; build_parameters_table(cases{idx})]; %#ok<AGROW>
end
end

function tbl = build_range_check_table(cases)
tbl = build_standard_metric_table(cases{1}, 'range_check');
for idx = 2:numel(cases)
    tbl = [tbl; build_standard_metric_table(cases{idx}, 'range_check')]; %#ok<AGROW>
end
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
    warning('run_dummy_asd_forward:workbookFormattingSkipped', ...
        'Workbook readability formatting skipped: %s', ME.message);
end
end

function safe_quit_excel(excel)
try
    excel.Quit;
catch
end
end

function tbl = build_parameters_table(c)
% BUILD_PARAMETERS_TABLE - key model parameters used by one forward run.
rows = {};
scenario = string(c.case_name);
if ~c.success || ~isfield(c, 'params')
    rows = add_parameter_row(rows, scenario, 'run_status', '-', false, ...
        'runner_status', c.error_message);
    tbl = cell2table(rows, 'VariableNames', parameter_table_header());
    return;
end

params = c.params;
patient = c.patient;
is_adult_ref = strcmp(c.scenario, 'healthy_baseline');

BSA_value = field_or_nan(patient, 'BSA');
weight_value = field_or_nan(patient, 'weight_kg');
if is_adult_ref
    BSA_value = 1.73;     % [m^2] adult reference stated in default_parameters.m
    weight_value = 70.0;  % [kg] adult reference used by scaling laws
end

rows = add_parameter_row(rows, scenario, 'HR', 'bpm', params.HR, ...
    source_for_runtime_parameter(c, 'HR'), 'Final heart rate used by elastance timing.');
rows = add_parameter_row(rows, scenario, 'T_HB', 's', 60 / params.HR, ...
    'derived_from_HR', 'Cardiac cycle period used for last-cycle extraction.');
rows = add_parameter_row(rows, scenario, 'BSA', 'm^2', BSA_value, ...
    source_for_runtime_parameter(c, 'BSA'), 'Body size basis for this scenario.');
rows = add_parameter_row(rows, scenario, 'weight_used_by_model', 'kg', weight_value, ...
    source_for_runtime_parameter(c, 'weight'), weight_note(c));
rows = add_parameter_row(rows, scenario, 'blood_volume', 'mL', ...
    nested_field_value(params, {'scaling', 'BV_patient'}), ...
    source_for_runtime_parameter(c, 'blood_volume'), ...
    'Used by apply_scaling vascular V0 reconciliation when pediatric scaling is active.');
rows = add_parameter_row(rows, scenario, 'R_ASD', 'mmHg*s/mL', params.R.asd, ...
    source_for_runtime_parameter(c, 'R_ASD'), c.mapping.mapping_status);
rows = add_parameter_row(rows, scenario, 'ASD_mode', '-', params.asd.mode, ...
    'model_mapping', 'ASD shunt equation mode used by asd_shunt_model.m.');
rows = add_parameter_row(rows, scenario, 'ASD_status', '-', c.mapping.status, ...
    'model_mapping', 'Open/closed status used for interpretation.');
rows = add_parameter_row(rows, scenario, 'ASD_diameter', 'mm', params.asd.diameter_mm, ...
    source_for_runtime_parameter(c, 'ASD_geometry'), 'NaN means not reported; zero means closed convention.');
rows = add_parameter_row(rows, scenario, 'ASD_area', 'mm^2', params.asd.area_mm2, ...
    source_for_runtime_parameter(c, 'ASD_geometry'), 'NaN means not reported; zero means closed convention.');

rows = add_parameter_row(rows, scenario, 'Left atrial active elastance', ...
    'mmHg/mL', params.E.LA.EA, source_for_runtime_parameter(c, 'scaled'), 'params.E.LA.EA');
rows = add_parameter_row(rows, scenario, 'Left atrial passive elastance', ...
    'mmHg/mL', params.E.LA.EB, source_for_runtime_parameter(c, 'scaled'), 'params.E.LA.EB');
rows = add_parameter_row(rows, scenario, 'Left atrial unstressed volume', ...
    'mL', params.V0.LA, source_for_runtime_parameter(c, 'scaled'), 'params.V0.LA');
rows = add_parameter_row(rows, scenario, 'Left ventricular active elastance', ...
    'mmHg/mL', params.E.LV.EA, source_for_runtime_parameter(c, 'scaled'), 'params.E.LV.EA');
rows = add_parameter_row(rows, scenario, 'Left ventricular passive elastance', ...
    'mmHg/mL', params.E.LV.EB, source_for_runtime_parameter(c, 'scaled'), 'params.E.LV.EB');
rows = add_parameter_row(rows, scenario, 'Left ventricular unstressed volume', ...
    'mL', params.V0.LV, source_for_runtime_parameter(c, 'scaled'), 'params.V0.LV');
rows = add_parameter_row(rows, scenario, 'Right atrial active elastance', ...
    'mmHg/mL', params.E.RA.EA, source_for_runtime_parameter(c, 'scaled'), 'params.E.RA.EA');
rows = add_parameter_row(rows, scenario, 'Right atrial passive elastance', ...
    'mmHg/mL', params.E.RA.EB, source_for_runtime_parameter(c, 'scaled'), 'params.E.RA.EB');
rows = add_parameter_row(rows, scenario, 'Right atrial unstressed volume', ...
    'mL', params.V0.RA, source_for_runtime_parameter(c, 'scaled'), 'params.V0.RA');
rows = add_parameter_row(rows, scenario, 'Right ventricular active elastance', ...
    'mmHg/mL', params.E.RV.EA, source_for_runtime_parameter(c, 'scaled'), 'params.E.RV.EA');
rows = add_parameter_row(rows, scenario, 'Right ventricular passive elastance', ...
    'mmHg/mL', params.E.RV.EB, source_for_runtime_parameter(c, 'scaled'), 'params.E.RV.EB');
rows = add_parameter_row(rows, scenario, 'Right ventricular unstressed volume', ...
    'mL', params.V0.RV, source_for_runtime_parameter(c, 'scaled'), 'params.V0.RV');

rows = add_parameter_row(rows, scenario, 'Systemic arterial resistance', ...
    'mmHg*s/mL', params.R.SAR, source_for_runtime_parameter(c, 'scaled'), 'params.R.SAR');
rows = add_parameter_row(rows, scenario, 'Systemic arterial capacitance', ...
    'mL/mmHg', params.C.SAR, source_for_runtime_parameter(c, 'scaled'), 'params.C.SAR');
rows = add_parameter_row(rows, scenario, 'Systemic arterial inductance', ...
    'mmHg*s^2/mL', params.L.SAR, source_for_runtime_parameter(c, 'scaled'), 'params.L.SAR');
rows = add_parameter_row(rows, scenario, 'Systemic capillary resistance', ...
    'mmHg*s/mL', params.R.SC, source_for_runtime_parameter(c, 'scaled'), 'params.R.SC');
rows = add_parameter_row(rows, scenario, 'Systemic capillary capacitance', ...
    'mL/mmHg', params.C.SC, source_for_runtime_parameter(c, 'scaled'), 'params.C.SC');
rows = add_parameter_row(rows, scenario, 'Systemic venous resistance', ...
    'mmHg*s/mL', params.R.SVEN, source_for_runtime_parameter(c, 'scaled'), 'params.R.SVEN');
rows = add_parameter_row(rows, scenario, 'Systemic venous capacitance', ...
    'mL/mmHg', params.C.SVEN, source_for_runtime_parameter(c, 'scaled'), 'params.C.SVEN');
rows = add_parameter_row(rows, scenario, 'Systemic venous inductance', ...
    'mmHg*s^2/mL', params.L.SVEN, source_for_runtime_parameter(c, 'scaled'), 'params.L.SVEN');
rows = add_parameter_row(rows, scenario, 'Pulmonary arterial resistance', ...
    'mmHg*s/mL', params.R.PAR, source_for_runtime_parameter(c, 'scaled'), 'params.R.PAR');
rows = add_parameter_row(rows, scenario, 'Pulmonary arterial capacitance', ...
    'mL/mmHg', params.C.PAR, source_for_runtime_parameter(c, 'scaled'), 'params.C.PAR');
rows = add_parameter_row(rows, scenario, 'Pulmonary arterial inductance', ...
    'mmHg*s^2/mL', params.L.PAR, source_for_runtime_parameter(c, 'scaled'), 'params.L.PAR');
rows = add_parameter_row(rows, scenario, 'Oxygenated pulmonary capillary resistance', ...
    'mmHg*s/mL', params.R.PCOX, source_for_runtime_parameter(c, 'scaled'), 'params.R.PCOX');
rows = add_parameter_row(rows, scenario, 'Oxygenated pulmonary capillary capacitance', ...
    'mL/mmHg', params.C.PCOX, source_for_runtime_parameter(c, 'scaled'), 'params.C.PCOX');
rows = add_parameter_row(rows, scenario, 'Non-oxygenated pulmonary capillary resistance', ...
    'mmHg*s/mL', params.R.PCNO, source_for_runtime_parameter(c, 'scaled'), 'params.R.PCNO');
rows = add_parameter_row(rows, scenario, 'Non-oxygenated pulmonary capillary capacitance', ...
    'mL/mmHg', params.C.PCNO, source_for_runtime_parameter(c, 'scaled'), 'params.C.PCNO');
rows = add_parameter_row(rows, scenario, 'Pulmonary venous resistance', ...
    'mmHg*s/mL', params.R.PVEN, source_for_runtime_parameter(c, 'scaled'), 'params.R.PVEN');
rows = add_parameter_row(rows, scenario, 'Pulmonary venous capacitance', ...
    'mL/mmHg', params.C.PVEN, source_for_runtime_parameter(c, 'scaled'), 'params.C.PVEN');
rows = add_parameter_row(rows, scenario, 'Pulmonary venous inductance', ...
    'mmHg*s^2/mL', params.L.PVEN, source_for_runtime_parameter(c, 'scaled'), 'params.L.PVEN');
rows = add_parameter_row(rows, scenario, 'Minimal valve resistance', ...
    'mmHg*s/mL', params.Rvalve.open, source_for_runtime_parameter(c, 'scaled'), 'params.Rvalve.open');
rows = add_parameter_row(rows, scenario, 'Maximal valve resistance', ...
    'mmHg*s/mL', params.Rvalve.closed, source_for_runtime_parameter(c, 'scaled'), 'params.Rvalve.closed');

tbl = cell2table(rows, 'VariableNames', parameter_table_header());
end

function header = parameter_table_header()
header = {'Scenario', 'Parameter_Name', 'Unit', 'Value', 'Value_Text', ...
    'Source_Class', 'Notes'};
end

function rows = add_parameter_row(rows, scenario, name, unit, value, source_class, notes)
[num_value, text_value] = split_value(value);
rows(end + 1, :) = {string(scenario), string(name), string(unit), ...
    num_value, text_value, string(source_class), string(notes)};
end

function value = nested_field_value(src, path_names)
% NESTED_FIELD_VALUE - read nested scalar fields safely; missing -> NaN.
value = NaN;
cursor = src;
for idx = 1:numel(path_names)
    field_name = path_names{idx};
    if ~isstruct(cursor) || ~isfield(cursor, field_name)
        return;
    end
    cursor = cursor.(field_name);
end
if isnumeric(cursor) && isscalar(cursor)
    value = cursor;
elseif islogical(cursor) || ischar(cursor) || isstring(cursor)
    value = cursor;
end
end

function source_class = source_for_runtime_parameter(c, parameter_kind)
% SOURCE_FOR_RUNTIME_PARAMETER - workbook provenance label for one parameter.
if strcmp(c.scenario, 'healthy_baseline')
    if any(strcmp(parameter_kind, {'BSA', 'weight'}))
        source_class = "adult_reference_assumption";
    elseif strcmp(parameter_kind, 'R_ASD')
        source_class = "closed_asd_convention";
    elseif strcmp(parameter_kind, 'ASD_geometry')
        source_class = "closed_asd_convention";
    else
        source_class = "adult_baseline";
    end
    return;
end

switch parameter_kind
    case 'HR'
        if strcmp(c.HR_handling, 'clinical_HR_from_dummy_table')
            source_class = "clinical_mapping";
        else
            source_class = "scaling";
        end
    case 'BSA'
        source_class = "clinical_mapping";
    case 'weight'
        if isfield(c.patient, 'weight_source') && ...
                strcmp(c.patient.weight_source, 'derived_inverse_mosteller_for_scaling_only')
            source_class = "derived_model_input";
        else
            source_class = "clinical_mapping";
        end
    case 'blood_volume'
        source_class = "scaling";
    case 'R_ASD'
        if strcmp(c.scenario, 'pre_surgery') && isfinite(c.params.R.asd)
            source_class = "placeholder";
        else
            source_class = "closed_asd_convention";
        end
    case 'ASD_geometry'
        if strcmp(c.scenario, 'pre_surgery')
            source_class = "missing_not_reported";
        else
            source_class = "closed_asd_convention";
        end
    otherwise
        source_class = "scaling";
end
end

function note = weight_note(c)
if strcmp(c.scenario, 'healthy_baseline')
    note = "Adult reference weight used only as documentation of the scaling basis; adult ODE run does not consume weight.";
elseif isfield(c.patient, 'weight_source')
    note = string(c.patient.weight_source);
else
    note = "weight source unavailable";
end
end

function tbl = build_case_target_comparison(c, scenario_label)
% BUILD_CASE_TARGET_COMPARISON - thesis-readable model-vs-literature table.
scenario_label; %#ok<VUNUS>
tbl = build_standard_metric_table(c, 'target_comparison');
end

function tf = is_missing_value(value)
tf = false;
if isnumeric(value) && isscalar(value) && isnan(value)
    tf = true;
elseif (ischar(value) || isstring(value)) && strlength(string(value)) == 0
    tf = true;
end
end

function tbl = build_interpretation_table(cases)
% BUILD_INTERPRETATION_TABLE - plain-language interpretation for workbook.
adult_healthy = cases{1};
pediatric_healthy = cases{2};
pre = cases{3};
post = cases{4};

rows = {
    "Healthy adult baseline remains stable", ...
    "Adult_ref is retained as a global integrity check for the closed healthy circuit.", ...
    sprintf('Qp/Qs %.6f; Q_ASD %.6g mL/s', field_or_nan(adult_healthy.metrics, 'QpQs'), field_or_nan(adult_healthy.metrics, 'Q_ASD_mean_mLs')), ...
    "Methods: baseline sanity check before disease runs."
    "Pediatric healthy dummy baseline is closed-shunt", ...
    "The dummy-size pediatric reference uses pre-closure anthropometry but keeps ASD inactive.", ...
    sprintf('Qp/Qs %.6f; Q_ASD %.6g mL/s', field_or_nan(pediatric_healthy.metrics, 'QpQs'), field_or_nan(pediatric_healthy.metrics, 'Q_ASD_mean_mLs')), ...
    "Results: direct comparator for dummy ASD pre-closure."
    "Dummy pre-closure ASD activates LA_to_RA shunt", ...
    "The finite R_ASD placeholder opens the LA-RA pathway without fitting parameters.", ...
    sprintf('Q_ASD %.6f L/min; direction %s', field_or_nan(pre.metrics, 'Q_ASD_Lmin'), char(field_or_string(pre.metrics, 'ASD_direction'))), ...
    "Results: architecture behaves like left-to-right ASD physiology."
    "Qp/Qs increases above 1", ...
    "Pulmonary flow exceeds systemic flow when the atrial shunt is open.", ...
    sprintf('pre Qp/Qs %.6f; target Qp/Qs %.6f', field_or_nan(pre.metrics, 'QpQs'), field_or_nan(pre.src, 'QpQs')), ...
    "Discussion: mismatch magnitude is not calibration failure."
    "Qp/Qs target is not matched exactly", ...
    "No GSA, optimization, or parameter tuning is performed in this forward-only stage.", ...
    "R_ASD is a documented placeholder because ASD diameter/gradient/direct shunt flow are missing.", ...
    "Discussion: exact matching is postponed to Patient Z calibration."
    "Dummy post-closure closes ASD", ...
    "Post-closure sets R_ASD to Inf, so Q_ASD returns to zero and Qp/Qs approaches 1.", ...
    sprintf('post Qp/Qs %.6f; Q_ASD %.6g mL/s', field_or_nan(post.metrics, 'QpQs'), field_or_nan(post.metrics, 'Q_ASD_mean_mLs')), ...
    "Results: closure branch of the architecture is working."
    "Volume trends are plausibility trends", ...
    "RV/LV changes should not be interpreted as patient-specific validation because the source case is cohort medians.", ...
    sprintf('Delta indexed RVEDV %.6f mL/m2; Delta LVEDV %.6f mL', indexed_metric(post, 'RVEDV') - indexed_metric(pre, 'RVEDV'), field_or_nan(post.metrics, 'LVEDV') - field_or_nan(pre.metrics, 'LVEDV')), ...
    "Discussion: useful for directionality, not exact fitting."
    "Dummy case is not for GSA or optimization", ...
    "The source values are cohort medians, not paired individual measurements.", ...
    "Runner does not call GSA or optimizer functions.", ...
    "Methods: use only as intermediate forward-simulation plausibility check."
    };

tbl = cell2table(rows, 'VariableNames', ...
    {'Finding', 'Interpretation', 'Evidence', 'Thesis_Use'});
end

function tbl = build_notes_table(cases, checks, clinical)
rows = {
    "Methodological statement", "The literature-based ASD dummy case is used as an intermediate forward-simulation plausibility check between healthy baseline validation and patient-specific Patient Z simulation. Because the values are cohort medians rather than individual paired measurements, the case is not used for GSA or calibration. Instead, it is used to test whether the ASD shunt architecture produces physiologically plausible trends such as Q_ASD activation, Qp/Qs elevation before closure, and near-normal Qp/Qs after closure."
    "No GSA/optimization", "This runner calls default_parameters, apply_scaling, integrate_system, and compute_clinical_indices only."
    "Excel cleanup scope", "This export revision changes workbook layout, metric ordering, target ranges, target sources, and range statuses only."
    "Metric order", "The vertical metric order is Heart Rate through warning, matching the requested primary order."
    "Target ranges", "Adult_ref uses adult normal ranges; healthy pediatric and post-closure use pediatric normal ranges; pre-closure disease rows do not apply healthy pediatric failure language."
    "Range status values", "Range_Status uses WITHIN_RANGE, OUT_OF_RANGE_LOW, OUT_OF_RANGE_HIGH, NOT_REPORTED, NOT_APPLICABLE, MODEL_PREDICTION_ONLY, TARGET_IS_QUALITATIVE, or TARGET_IS_NORMAL_QPQS."
    "Healthy adult role", "Adult_ref remains in the workbook as a global closed-circuit integrity check."
    "Healthy pediatric role", "Healthy_Pediatric_Dummy_Baseline uses dummy pre-closure anthropometry with ASD closed."
    "ASD pre-closure mapping", cases{3}.mapping.mapping_status
    "ASD post-closure mapping", cases{4}.mapping.mapping_status
    "Primary source", clinical.common.primary_source
    "Plausibility checks", sprintf('%d of %d checks passed in this forward-only run.', sum(checks.Passed), height(checks))
    "Interpretation", "Qp/Qs mismatch is not failure in this phase because no patient-specific calibration is performed."
    "Next step", "If architecture behavior is acceptable, implement a dedicated Patient Zoya forward-only runner before GSA/optimization."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic', 'Note'});
end

function print_case_summary(cases)
fprintf('%-28s %9s %11s %12s %16s %12s %12s %12s %8s\n', ...
    'Case', 'Qp/Qs', 'Q_ASD L/min', 'Direction', 'R_ASD', ...
    'LVSV', 'RVSV', 'PAP_mean', 'SS');
for idx = 1:numel(cases)
    c = cases{idx};
    fprintf('%-28s %9.4f %11.4f %12s %16s %12.3f %12.3f %12.3f %8s\n', ...
        c.case_name, ...
        field_or_nan(c.metrics, 'QpQs'), ...
        field_or_nan(c.metrics, 'Q_ASD_Lmin'), ...
        char(field_or_string(c.metrics, 'ASD_direction')), ...
        char(value_to_text(c.mapping.R_asd)), ...
        field_or_nan(c.metrics, 'LVSV'), ...
        field_or_nan(c.metrics, 'RVSV'), ...
        field_or_nan(c.metrics, 'PAP_mean'), ...
        char(logical_to_text(field_or_logical(c.sim, 'ss_reached'))));
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

function value = field_or_string(src, field_name)
value = "";
if isstruct(src) && isfield(src, field_name)
    value = string(src.(field_name));
end
end

function value = field_or_logical(src, field_name)
value = false;
if isstruct(src) && isfield(src, field_name)
    value = logical(src.(field_name));
end
end

function [num_value, text_value] = split_value(value)
num_value = NaN;
text_value = "";
if isnumeric(value) && isscalar(value)
    if isfinite(value)
        num_value = value;
        text_value = string(sprintf('%.10g', value));
    elseif isinf(value)
        text_value = "Inf";
    else
        text_value = "NaN";
    end
elseif islogical(value)
    text_value = logical_to_text(value);
elseif isstring(value) || ischar(value)
    text_value = string(value);
end
end

function txt = value_to_text(value)
if isnumeric(value) && isscalar(value)
    if isfinite(value)
        txt = string(sprintf('%.10g', value));
    elseif isinf(value)
        txt = "Inf";
    else
        txt = "NaN";
    end
elseif islogical(value)
    txt = logical_to_text(value);
elseif isstring(value) || ischar(value)
    txt = string(value);
else
    txt = "";
end
end

function txt = logical_to_text(value)
if value
    txt = "true";
else
    txt = "false";
end
end

function CI = cardiac_index(c)
CI = NaN;
BSA = first_valid(c.src, {'BSA'}, NaN);
if ~isfinite(BSA) && isfield(c, 'patient')
    BSA = first_valid(c.patient, {'BSA'}, NaN);
end
if ~isfinite(BSA) && strcmp(c.scenario, 'healthy_baseline')
    BSA = 1.73; % [m^2] adult reference BSA documented in default_parameters.m
end
if isfinite(BSA) && BSA > 0
    CI = field_or_nan(c.metrics, 'CO_Lmin') / BSA;
end
end

function value = indexed_metric(c, metric_name)
value = NaN;
BSA = first_valid(c.src, {'BSA'}, NaN);
if ~isfinite(BSA) && isfield(c, 'patient')
    BSA = first_valid(c.patient, {'BSA'}, NaN);
end
if isfinite(BSA) && BSA > 0
    value = field_or_nan(c.metrics, metric_name) / BSA;
end
end
