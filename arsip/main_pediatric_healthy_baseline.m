% MAIN_PEDIATRIC_HEALTHY_BASELINE
% -------------------------------------------------------------------------
% Intermediate validation runner:
%   adult baseline -> 8-year-old allometric scaling -> ASD fully closed
%   -> forward integration -> pediatric healthy validation report -> Excel.
%
% This script intentionally performs forward simulation only. It does not
% call GSA, PCE, Sobol analysis, optimization, or calibration.
% -------------------------------------------------------------------------

clear; clc; close all;

project_root = fileparts(mfilename('fullpath'));
addpath(fullfile(project_root, 'config'));
addpath(fullfile(project_root, 'models'));
addpath(fullfile(project_root, 'solvers'));
addpath(fullfile(project_root, 'utils'));

scenario_name = 'Healthy_Pediatric_8yo';
stage_name = 'healthy_validation';
timestamp_tag = char(datetime('now', 'Format', 'yyyyMMdd_HHmm'));
run_id = ['ped_healthy_8yo_', timestamp_tag];

fprintf('\n=== PEDIATRIC HEALTHY BASELINE VALIDATION ===\n');
fprintf('  scenario_name : %s\n', scenario_name);
fprintf('  stage_name    : %s\n', stage_name);
fprintf('  run_id        : %s\n', run_id);

[params_ref, ~] = default_parameters();
clinical_asd = patient_dummy_pediatric_asd();
clinical = make_healthy_closed_profile(clinical_asd);

fprintf('\n--- Clinical Dummy Input ---\n');
fprintf('  Patient ID : %s\n', clinical.common.patient_id);
fprintf('  Age        : %.1f years\n', clinical.common.age_years);
fprintf('  Height     : %.1f cm\n', clinical.common.height_cm);
fprintf('  Weight     : %.1f kg\n', clinical.common.weight_kg);
fprintf('  BSA        : %.3f m^2\n', clinical.common.BSA);
fprintf('  HR target  : %.1f bpm\n', clinical.common.HR);
fprintf('  BP target  : %.0f/%.0f mmHg\n', ...
    clinical.asd_pre.SAP_sys_mmHg, clinical.asd_pre.SAP_dia_mmHg);
fprintf('  Qp/Qs target: %.2f (ASD closed)\n', clinical.asd_pre.QpQs);

[params, X0] = apply_scaling(params_ref, clinical, 'asd_pre');

% The validation point is a healthy child: the defect is fully closed after
% scaling and before integration.
params.is_post_op = true;
params.R_ASD = Inf;
params.R.asd = Inf;
params.asd.is_closed = true;
params.asd.mode = 'closed';
params.asd.area_mm2 = 0.0;
params.asd.diameter_mm = 0.0;

fprintf('\n--- Healthy Closure Setup ---\n');
fprintf('  ASD closed  : %d\n', params.asd.is_closed);
fprintf('  R_ASD       : Inf mmHg*s/mL\n');
fprintf('  PVR scale   : %.3f\n', params.forward_seed.pulmonary_resistance_scale);
fprintf('  C_sa scale  : %.3f\n', params.forward_seed.systemic_arterial_compliance_scale);
fprintf('  P_SVEN seed : %.1f mmHg\n', params.forward_seed.P_SVEN_seed_mmHg);

fprintf('\n--- Solver ---\n');
[t_sol, ~, t_ss, X_ss] = integrate_system(params, X0);
fprintf('  Samples returned: %d full, %d steady-cycle\n', numel(t_sol), numel(t_ss));

indices = compute_clinical_indices(t_ss, X_ss, params);
targets = pediatric_targets(clinical.common.BSA);
validation_table = build_validation_table(indices, targets);
comprehensive_table = build_comprehensive_report_table(indices, targets);

fprintf('\n=== PEDIATRIC VALIDATION REPORT ===\n');
print_validation_row('Qp/Qs', indices.Q_ratio, targets.QpQs.value, ...
    targets.QpQs.range, '-');
print_validation_row('Heart rate', indices.HR, targets.HR.value, ...
    targets.HR.range, 'bpm');
print_validation_row('Systolic BP', indices.P_ao_sys, targets.SAP_sys.value, ...
    targets.SAP_sys.range, 'mmHg');
print_validation_row('Diastolic BP', indices.P_ao_dia, targets.SAP_dia.value, ...
    targets.SAP_dia.range, 'mmHg');
print_validation_row('Cardiac output', indices.CO_systemic, targets.CO.value, ...
    targets.CO.range, 'L/min');
print_validation_row('Cardiac index', indices.CO_systemic / clinical.common.BSA, ...
    targets.CI.value, targets.CI.range, 'L/min/m^2');
print_validation_row('Mean PAP', indices.P_pa_mean, targets.PAP_mean.value, ...
    targets.PAP_mean.range, 'mmHg');
print_validation_row('ASD shunt', indices.Q_ASD_Lmin, targets.Q_ASD.value, ...
    targets.Q_ASD.range, 'L/min');

fprintf('\n=== COMPREHENSIVE PHYSIOLOGICAL OUTPUT ===\n');
disp(comprehensive_table);

fprintf('\n--- Healthy Baseline Summary ---\n');
fprintf('  Qp/Qs          : %.3f\n', indices.Q_ratio);
fprintf('  ASD shunt      : %.3f L/min (%s)\n', ...
    indices.Q_ASD_Lmin, indices.ASD_direction);
fprintf('  SAP            : %.1f/%.1f mmHg\n', ...
    indices.P_ao_sys, indices.P_ao_dia);
fprintf('  CO / CI        : %.2f L/min / %.2f L/min/m^2\n', ...
    indices.CO_systemic, indices.CO_systemic / clinical.common.BSA);
fprintf('  Mean PAP       : %.1f mmHg\n', indices.P_pa_mean);
fprintf('  LV/RV EF       : %.1f / %.1f %%\n', ...
    indices.EF_lv * 100.0, indices.EF_rv * 100.0);

all_pass = all(strcmp(validation_table.status, 'PASS'));
if all_pass
    fprintf('  Overall        : PASS - healthy pediatric baseline is stable.\n');
else
    fprintf('  Overall        : REVIEW - at least one metric is outside range.\n');
end

payload = struct();
payload.scenario = scenario_name;
payload.stage = stage_name;
payload.run_id = run_id;
payload.description = 'Healthy 8-year-old pediatric scaling validation with ASD fully closed.';
payload.status = ternary_text(all_pass, 'complete', 'review');
payload.clinical_input = build_clinical_input_table(clinical, targets);
payload.params = params;
payload.parameter_override = build_override_table(params, clinical);
payload.indices = build_simulation_output_table(indices);
payload.validation_error = [ ...
    basic_to_validation_export(validation_table); ...
    comprehensive_to_validation_table(comprehensive_table)];
payload.method_notes = { ...
    'Healthy pediatric validation uses the same 8-year-old dummy demographics as the ASD profile.'; ...
    'ASD is forced completely closed before integration: is_post_op=true, R_ASD=Inf, params.R.asd=Inf.'; ...
    'No GSA, Sobol/PCE, optimization, or calibration is executed in this script.'; ...
    'Qp/Qs=1.0 is expected because closed-loop pulmonary and systemic flows are equal when no shunt is present.'; ...
    'CO is interpreted with cardiac index because pediatric cardiac output is body-size dependent.'};

try
    manifest = export_to_master_excel(payload);
    format_manifest = apply_validation_error_red_format(manifest.master_file, run_id);
    fprintf('\n--- Excel Export Confirmation ---\n');
    fprintf('  Master workbook : %s\n', manifest.master_file);
    fprintf('  Run folder      : %s\n', manifest.run_folder);
    fprintf('  Sheets updated  : %s\n', strjoin(manifest.sheets_updated.', ', '));
    fprintf('  Red rows (>5%%)  : %d\n', format_manifest.red_row_count);
catch export_error
    manifest = struct();
    manifest.export_status = 'failed';
    manifest.error_identifier = export_error.identifier;
    manifest.error_message = export_error.message;
    fprintf('\n--- Excel Export Warning ---\n');
    fprintf('  Export skipped because the master workbook could not be written.\n');
    fprintf('  MATLAB message: %s\n', export_error.message);
    fprintf('  Close ASD_Pre_Model_Master.xlsx and rerun this script to log the rows.\n');
end

assignin('base', 'ped_healthy_indices', indices);
assignin('base', 'ped_healthy_validation_table', validation_table);
assignin('base', 'ped_healthy_comprehensive_table', comprehensive_table);
assignin('base', 'ped_healthy_manifest', manifest);

function clinical = make_healthy_closed_profile(clinical)
clinical.common.patient_id = 'healthy_pediatric_8yo';
clinical.common.patient_name = 'Healthy pediatric 8yo scaling validation';

clinical.asd_pre.ASD_mode = 'closed';
clinical.asd_pre.ASD_diameter_mm = 0.0;
clinical.asd_pre.ASD_area_mm2 = 0.0;
clinical.asd_pre.R_asd_guess = Inf;
clinical.asd_pre.QpQs = 1.0;
clinical.asd_pre.Q_shunt_Lmin = 0.0;

clinical.asd_pre.P_SVEN_seed_mmHg = 38.0;
clinical.asd_pre.pulmonary_resistance_scale = 0.50;
clinical.asd_pre.systemic_arterial_compliance_scale = 1.50;
end

function targets = pediatric_targets(BSA)
targets.QpQs = make_target(1.0, [0.99, 1.01], '-', ...
    'No shunt: pulmonary and systemic flow should match.');
targets.HR = make_target(83.0, [60.0, 100.0], 'bpm', ...
    'Older-child resting HR normal range; dummy target is 83 bpm.');
targets.SAP_sys = make_target(102.0, [95.0, 115.0], 'mmHg', ...
    '8-year-old systolic BP literature-compatible range.');
targets.SAP_dia = make_target(67.0, [55.0, 75.0], 'mmHg', ...
    '8-year-old diastolic BP literature-compatible range.');
targets.CO = make_target(4.0, [3.0, 4.5], 'L/min', ...
    'Approximate pediatric CO; interpreted with BSA-normalized CI.');
targets.CI = make_target(4.0 / BSA, [2.5, 4.0], 'L/min/m^2', ...
    'Normal cardiac index range.');
targets.PAP_mean = make_target(15.0, [9.0, 16.0], 'mmHg', ...
    'Normal mean pulmonary artery pressure.');
targets.PAP_sys = make_target(25.0, [15.0, 30.0], 'mmHg', ...
    'Normal pulmonary artery systolic pressure.');
targets.PAP_dia = make_target(9.0, [4.0, 14.0], 'mmHg', ...
    'Normal pulmonary artery diastolic pressure.');
targets.LAP = make_target(8.0, [2.0, 12.0], 'mmHg', ...
    'Normal mean left atrial pressure.');
targets.SVRi = make_target(NaN, [15.0, 30.0], 'WU*m^2', ...
    'Normal pediatric indexed systemic vascular resistance.');
targets.PVRi = make_target(NaN, [2.0, 4.0], 'WU*m^2', ...
    'Normal pediatric indexed pulmonary vascular resistance.');
targets.LVEDVi = make_target(NaN, [55.0, 104.0], 'mL/m^2', ...
    'CMR LVEDVi reference limits for children ages 8-17.');
targets.LVESVi = make_target(NaN, [15.0, 40.0], 'mL/m^2', ...
    'CMR LVESVi reference limits for children ages 8-17.');
targets.RVEDVi = make_target(NaN, [58.0, 108.0], 'mL/m^2', ...
    'CMR RVEDVi reference limits for children ages 8-17.');
targets.RVESVi = make_target(NaN, [17.0, 46.0], 'mL/m^2', ...
    'CMR RVESVi reference limits for children ages 8-17.');
targets.SVi_lv = make_target(NaN, [34.0, 72.0], 'mL/m^2', ...
    'CMR LV stroke volume index reference limits for children ages 8-17.');
targets.EF_lv = make_target(NaN, [51.0, 76.0], '%', ...
    'CMR LVEF reference limits for children ages 8-17.');
targets.EF_rv = make_target(NaN, [54.0, 71.0], '%', ...
    'CMR RVEF reference limits for children ages 8-17.');
targets.Q_ASD = make_target(0.0, [-0.01, 0.01], 'L/min', ...
    'No residual ASD flow when closure is forced.');
end

function target = make_target(value, range, unit, description)
target.value = value;
target.range = range;
target.unit = unit;
target.description = description;
end

function print_validation_row(label, simulated, target, range, unit)
is_pass = simulated >= range(1) && simulated <= range(2);
status = ternary_text(is_pass, 'PASS', 'ERROR');
fprintf('  [%s] %-15s simulated=%7.3f target=%7.3f range=[%.3f, %.3f] %s\n', ...
    status, label, simulated, target, range(1), range(2), unit);
end

function T = build_comprehensive_report_table(indices, targets)
rows = [ ...
    report_row('Pressures', 'SAP_max', indices.SAP_max, 'mmHg', targets.SAP_sys); ...
    report_row('Pressures', 'SAP_min', indices.SAP_min, 'mmHg', targets.SAP_dia); ...
    report_row('Pressures', 'MAP', indices.MAP, 'mmHg', make_target(78.7, [68.3, 88.3], 'mmHg', 'Derived MAP from target 102/67')); ...
    report_row('Pressures', 'PAP_max', indices.PAP_max, 'mmHg', targets.PAP_sys); ...
    report_row('Pressures', 'PAP_min', indices.PAP_min, 'mmHg', targets.PAP_dia); ...
    report_row('Pressures', 'PAP_mean', indices.PAP_mean, 'mmHg', targets.PAP_mean); ...
    report_row('Pressures', 'LAP_mean_LVEDP_est', indices.LVEDP_est, 'mmHg', targets.LAP); ...
    report_row('Pressures', 'RAP_mean', indices.RAP, 'mmHg', make_target(NaN, [0, 8], 'mmHg', 'Normal mean right atrial pressure')); ...
    report_na_row('Pressures', 'DeltaP_LAP_minus_RAP', indices.transseptal_gradient_mean, 'mmHg'); ...
    report_row('Flows', 'Qp', indices.Qp, 'L/min', targets.CO); ...
    report_row('Flows', 'Qs', indices.Qs, 'L/min', targets.CO); ...
    report_row('Flows', 'Qp_Qs', indices.Q_ratio, '-', targets.QpQs); ...
    report_row('Flows', 'CO_from_LV', indices.CO_systemic, 'L/min', targets.CO); ...
    report_row('Flows', 'CI_from_LV', indices.CI_systemic, 'L/min/m^2', targets.CI); ...
    report_na_row('Resistances', 'SVR', indices.SVR_WU, 'WU'); ...
    report_na_row('Resistances', 'PVR', indices.PVR_WU, 'WU'); ...
    report_row('Resistances', 'SVRi', indices.SVRi_WU_m2, 'WU*m^2', targets.SVRi); ...
    report_row('Resistances', 'PVRi', indices.PVRi_WU_m2, 'WU*m^2', targets.PVRi); ...
    report_na_row('Volumes', 'LVEDV', indices.V_lv_ed, 'mL'); ...
    report_na_row('Volumes', 'LVESV', indices.V_lv_es, 'mL'); ...
    report_row('Volumes', 'LVEDVi', indices.LVEDVi, 'mL/m^2', targets.LVEDVi); ...
    report_row('Volumes', 'LVESVi', indices.LVESVi, 'mL/m^2', targets.LVESVi); ...
    report_na_row('Volumes', 'RVEDV', indices.V_rv_ed, 'mL'); ...
    report_na_row('Volumes', 'RVESV', indices.V_rv_es, 'mL'); ...
    report_row('Volumes', 'RVEDVi', indices.RVEDVi, 'mL/m^2', targets.RVEDVi); ...
    report_row('Volumes', 'RVESVi', indices.RVESVi, 'mL/m^2', targets.RVESVi); ...
    report_na_row('Pump', 'SV_LV', indices.SV_lv, 'mL'); ...
    report_row('Pump', 'SVi_LV', indices.SVi_lv, 'mL/m^2', targets.SVi_lv); ...
    report_na_row('Pump', 'SV_RV', indices.SV_rv, 'mL'); ...
    report_row('Pump', 'LV_EF', indices.EF_lv * 100.0, '%', targets.EF_lv); ...
    report_row('Pump', 'RV_EF', indices.EF_rv * 100.0, '%', targets.EF_rv)];

T = cell2table(rows, 'VariableNames', ...
    {'category', 'metric', 'simulated_value', 'unit', 'literature_target', 'error_percent'});
end

function row = report_row(category, metric, simulated_value, unit, target)
row = {category, metric, simulated_value, unit, target_text(target), ...
    compute_error_percent(simulated_value, target)};
end

function row = report_na_row(category, metric, simulated_value, unit)
row = {category, metric, simulated_value, unit, 'N/A', NaN};
end

function text = target_text(target)
if isnan(target.value)
    text = sprintf('[%.3g, %.3g]', target.range(1), target.range(2));
else
    text = sprintf('%.3g; range [%.3g, %.3g]', target.value, ...
        target.range(1), target.range(2));
end
end

function error_percent = compute_error_percent(value, target)
if isfinite(target.value) && target.value ~= 0.0
    error_percent = abs((value - target.value) / target.value) * 100.0;
elseif value >= target.range(1) && value <= target.range(2)
    error_percent = 0.0;
elseif value < target.range(1) && target.range(1) ~= 0.0
    error_percent = abs((value - target.range(1)) / target.range(1)) * 100.0;
elseif value > target.range(2) && target.range(2) ~= 0.0
    error_percent = abs((value - target.range(2)) / target.range(2)) * 100.0;
else
    error_percent = NaN;
end
end

function T = comprehensive_to_validation_table(comprehensive_table)
row_count = height(comprehensive_table);
metric_name = strings(row_count, 1);
target_value = nan(row_count, 1);
simulated_value = comprehensive_table.simulated_value;
error_absolute = nan(row_count, 1);
unit = comprehensive_table.unit;
description = strings(row_count, 1);
source = repmat("comprehensive pediatric physiology report", row_count, 1);
category = comprehensive_table.category;
literature_target = comprehensive_table.literature_target;
status = repmat({''}, row_count, 1);

for k = 1:row_count
    metric_name(k) = sprintf("comprehensive.%s.%s", ...
        string(comprehensive_table.category{k}), string(comprehensive_table.metric{k}));
    if isfinite(comprehensive_table.error_percent(k))
        status{k} = sprintf('%.2f%%', comprehensive_table.error_percent(k));
    else
        status{k} = 'N/A';
    end
    description(k) = sprintf("error_percent=%s; literature_target=%s", ...
        string(status{k}), string(comprehensive_table.literature_target{k}));
end

T = table(cellstr(metric_name), target_value, simulated_value, ...
    error_absolute, comprehensive_table.error_percent, unit, cellstr(description), cellstr(source), ...
    category, literature_target, status, ...
    'VariableNames', {'metric_name', 'target_value', 'simulated_value', ...
    'error_absolute', 'error_percent', 'unit', 'description', 'source', ...
    'category', 'literature_target', 'status'});
end

function T = basic_to_validation_export(validation_table)
T = validation_table(:, {'metric_name', 'target_value', 'simulated_value', ...
    'error_absolute', 'error_percent', 'unit', 'description', 'source'});
T.category = repmat({'Summary'}, height(T), 1);
T.literature_target = repmat({'see target_value and details_json'}, height(T), 1);
T.status = validation_table.status;
end

function T = build_validation_table(indices, targets)
metric_names = {'QpQs'; 'HR'; 'SAP_sys'; 'SAP_dia'; 'CO_systemic'; ...
    'cardiac_index'; 'PAP_mean'; 'Q_ASD'};
simulated = [indices.Q_ratio; indices.HR; indices.P_ao_sys; ...
    indices.P_ao_dia; indices.CO_systemic; indices.CI_systemic; ...
    indices.P_pa_mean; indices.Q_ASD_Lmin];
target_values = [targets.QpQs.value; targets.HR.value; targets.SAP_sys.value; ...
    targets.SAP_dia.value; targets.CO.value; targets.CI.value; ...
    targets.PAP_mean.value; targets.Q_ASD.value];
lower_bounds = [targets.QpQs.range(1); targets.HR.range(1); ...
    targets.SAP_sys.range(1); targets.SAP_dia.range(1); targets.CO.range(1); ...
    targets.CI.range(1); targets.PAP_mean.range(1); targets.Q_ASD.range(1)];
upper_bounds = [targets.QpQs.range(2); targets.HR.range(2); ...
    targets.SAP_sys.range(2); targets.SAP_dia.range(2); targets.CO.range(2); ...
    targets.CI.range(2); targets.PAP_mean.range(2); targets.Q_ASD.range(2)];
units = {targets.QpQs.unit; targets.HR.unit; targets.SAP_sys.unit; ...
    targets.SAP_dia.unit; targets.CO.unit; targets.CI.unit; ...
    targets.PAP_mean.unit; targets.Q_ASD.unit};
descriptions = {targets.QpQs.description; targets.HR.description; ...
    targets.SAP_sys.description; targets.SAP_dia.description; ...
    targets.CO.description; targets.CI.description; ...
    targets.PAP_mean.description; targets.Q_ASD.description};
source = repmat({'pediatric healthy validation target'}, numel(metric_names), 1);

error_absolute = simulated - target_values;
error_percent = nan(size(simulated));
for k = 1:numel(simulated)
    if target_values(k) ~= 0.0
        error_percent(k) = error_absolute(k) / target_values(k) * 100.0;
    end
end

status = repmat({'ERROR'}, numel(metric_names), 1);
for k = 1:numel(simulated)
    if simulated(k) >= lower_bounds(k) && simulated(k) <= upper_bounds(k)
        status{k} = 'PASS';
    end
end

T = table(metric_names, target_values, simulated, error_absolute, ...
    error_percent, lower_bounds, upper_bounds, units, status, descriptions, ...
    source, 'VariableNames', {'metric_name', 'target_value', ...
    'simulated_value', 'error_absolute', 'error_percent', 'range_min', ...
    'range_max', 'unit', 'status', 'description', 'source'});
end

function T = build_clinical_input_table(clinical, targets)
rows = { ...
    'age_years', clinical.common.age_years, 'years', 'Dummy age', 'patient_dummy_pediatric_asd'; ...
    'height_cm', clinical.common.height_cm, 'cm', 'Dummy height', 'patient_dummy_pediatric_asd'; ...
    'weight_kg', clinical.common.weight_kg, 'kg', 'Dummy weight', 'patient_dummy_pediatric_asd'; ...
    'BSA', clinical.common.BSA, 'm^2', 'Mosteller body surface area', 'computed'; ...
    'HR_target', targets.HR.value, 'bpm', targets.HR.description, 'AHA older-child range'; ...
    'SAP_target', targets.SAP_sys.value, 'mmHg', targets.SAP_sys.description, 'NHLBI/AAP pediatric BP table'; ...
    'DAP_target', targets.SAP_dia.value, 'mmHg', targets.SAP_dia.description, 'NHLBI/AAP pediatric BP table'; ...
    'QpQs_target', targets.QpQs.value, '-', targets.QpQs.description, 'closed-loop no-shunt physiology'; ...
    'CO_target', targets.CO.value, 'L/min', targets.CO.description, 'cardiac-index interpreted'; ...
    'PAP_mean_target', targets.PAP_mean.value, 'mmHg', targets.PAP_mean.description, 'normal hemodynamic table'};

T = cell2table(rows, 'VariableNames', ...
    {'variable_name', 'value', 'unit', 'description', 'source'});
end

function T = build_simulation_output_table(indices)
rows = { ...
    'QpQs', indices.Q_ratio, '-', 'Pulmonary-to-systemic flow ratio', 'compute_clinical_indices'; ...
    'HR', indices.HR, 'bpm', 'Heart rate', 'params'; ...
    'SAP_max', indices.SAP_max, 'mmHg', 'Systemic arterial systolic pressure', 'compute_clinical_indices'; ...
    'SAP_min', indices.SAP_min, 'mmHg', 'Systemic arterial diastolic pressure', 'compute_clinical_indices'; ...
    'MAP', indices.MAP, 'mmHg', 'Systemic arterial mean pressure', 'compute_clinical_indices'; ...
    'PAP_max', indices.PAP_max, 'mmHg', 'Pulmonary arterial systolic pressure', 'compute_clinical_indices'; ...
    'PAP_min', indices.PAP_min, 'mmHg', 'Pulmonary arterial diastolic pressure', 'compute_clinical_indices'; ...
    'CO_systemic', indices.CO_systemic, 'L/min', 'Systemic cardiac output', 'compute_clinical_indices'; ...
    'cardiac_index', indices.CI_systemic, 'L/min/m^2', 'BSA-normalized systemic cardiac output', 'computed'; ...
    'Qp', indices.Qp, 'L/min', 'Pulmonary flow', 'compute_clinical_indices'; ...
    'Qs', indices.Qs, 'L/min', 'Systemic flow', 'compute_clinical_indices'; ...
    'PAP_mean', indices.PAP_mean, 'mmHg', 'Mean pulmonary artery pressure', 'compute_clinical_indices'; ...
    'LAP_mean_LVEDP_est', indices.LVEDP_est, 'mmHg', 'Mean LA pressure used as LVEDP estimate', 'compute_clinical_indices'; ...
    'DeltaP_LAP_minus_RAP', indices.transseptal_gradient_mean, 'mmHg', 'Mean trans-septal pressure gradient', 'compute_clinical_indices'; ...
    'SVRi', indices.SVRi_WU_m2, 'WU*m^2', 'Indexed systemic vascular resistance', 'compute_clinical_indices'; ...
    'PVRi', indices.PVRi_WU_m2, 'WU*m^2', 'Indexed pulmonary vascular resistance', 'compute_clinical_indices'; ...
    'LVEDV', indices.V_lv_ed, 'mL', 'LV end-diastolic volume', 'compute_clinical_indices'; ...
    'LVESV', indices.V_lv_es, 'mL', 'LV end-systolic volume', 'compute_clinical_indices'; ...
    'RVEDV', indices.V_rv_ed, 'mL', 'RV end-diastolic volume', 'compute_clinical_indices'; ...
    'RVESV', indices.V_rv_es, 'mL', 'RV end-systolic volume', 'compute_clinical_indices'; ...
    'LVEDVi', indices.LVEDVi, 'mL/m^2', 'Indexed LV end-diastolic volume', 'compute_clinical_indices'; ...
    'RVEDVi', indices.RVEDVi, 'mL/m^2', 'Indexed RV end-diastolic volume', 'compute_clinical_indices'; ...
    'SV_LV', indices.SV_lv, 'mL', 'LV stroke volume', 'compute_clinical_indices'; ...
    'Q_ASD_Lmin', indices.Q_ASD_Lmin, 'L/min', 'Mean ASD shunt flow', 'compute_clinical_indices'; ...
    'ASD_direction', indices.ASD_direction, '-', 'Mean ASD shunt direction', 'compute_clinical_indices'; ...
    'EF_lv', indices.EF_lv, 'fraction', 'Left ventricular ejection fraction', 'compute_clinical_indices'; ...
    'EF_rv', indices.EF_rv, 'fraction', 'Right ventricular ejection fraction', 'compute_clinical_indices'};

T = cell2table(rows, 'VariableNames', ...
    {'metric_name', 'value', 'unit', 'description', 'source'});
end

function T = build_override_table(params, clinical)
rows = { ...
    'is_post_op', 0, 1, '-', NaN, 'Force healthy closed-ASD physiology', 'main_pediatric_healthy_baseline'; ...
    'R_ASD', clinical.asd_pre.R_asd_guess, Inf, 'mmHg*s/mL', NaN, 'Close ASD shunt branch', 'main_pediatric_healthy_baseline'; ...
    'params.R.asd', clinical.asd_pre.R_asd_guess, Inf, 'mmHg*s/mL', NaN, 'Nested resistance mirror for closure', 'main_pediatric_healthy_baseline'; ...
    'params.asd.area_mm2', clinical.asd_pre.ASD_area_mm2, 0.0, 'mm^2', NaN, 'Remove ASD area for healthy baseline', 'main_pediatric_healthy_baseline'; ...
    'P_SVEN_seed_mmHg', NaN, params.forward_seed.P_SVEN_seed_mmHg, 'mmHg', NaN, 'Healthy preload operating-point seed', 'main_pediatric_healthy_baseline'; ...
    'pulmonary_resistance_scale', NaN, params.forward_seed.pulmonary_resistance_scale, '-', NaN, 'Healthy pulmonary pressure operating-point seed', 'main_pediatric_healthy_baseline'; ...
    'systemic_arterial_compliance_scale', NaN, params.forward_seed.systemic_arterial_compliance_scale, '-', NaN, 'Pediatric pulse-pressure operating-point seed', 'main_pediatric_healthy_baseline'};

T = cell2table(rows, 'VariableNames', {'parameter_name', ...
    'baseline_value', 'override_value', 'unit', 'percent_change', ...
    'description', 'source'});
end

function text = ternary_text(condition, true_text, false_text)
if condition
    text = true_text;
else
    text = false_text;
end
end

function format_manifest = apply_validation_error_red_format(master_file, run_id)
% Highlight 05_Validation_Error rows for this run when abs(error_percent)>5.
format_manifest = struct('red_row_count', 0, 'status', 'skipped');

if ~ispc || ~exist('actxserver', 'file')
    format_manifest.status = 'activex_unavailable';
    return;
end

excel = [];
workbook = [];
try
    excel = actxserver('Excel.Application');
    excel.DisplayAlerts = false;
    workbook = excel.Workbooks.Open(master_file);
    sheet = workbook.Worksheets.Item('05_Validation_Error');
    used_range = sheet.UsedRange;
    raw = used_range.Value;

    if ~iscell(raw)
        raw = {raw};
    end

    red_fill = 13421823;   % Light red fill [Excel BGR color]
    red_font = 192;        % Dark red font [Excel BGR color]
    white_fill = 16777215; % White fill [Excel BGR color]
    black_font = 0;        % Black font [Excel BGR color]
    threshold_percent = 5.0; % Formatting threshold [%]

    for r = 2:size(raw, 1)
        row_run_id = raw{r, 1};
        row_error_percent = raw{r, 8};
        if ischar(row_run_id) || isstring(row_run_id)
            if strcmp(char(row_run_id), run_id)
                err = to_numeric(row_error_percent);
                row_range = sheet.Range(sprintf('A%d:L%d', r, r));
                if isfinite(err) && abs(err) > threshold_percent
                    row_range.Interior.Color = red_fill;
                    row_range.Font.Color = red_font;
                    format_manifest.red_row_count = format_manifest.red_row_count + 1;
                else
                    row_range.Interior.Color = white_fill;
                    row_range.Font.Color = black_font;
                end
            end
        end
    end

    workbook.Save();
    workbook.Close(false);
    excel.Quit();
    format_manifest.status = 'complete';
catch
    if ~isempty(workbook)
        workbook.Close(false);
    end
    if ~isempty(excel)
        excel.Quit();
    end
    format_manifest.status = 'failed';
end
end

function value = to_numeric(value)
if isnumeric(value) && isscalar(value)
    return;
end
if ischar(value) || isstring(value)
    value = str2double(char(value));
else
    value = NaN;
end
end
