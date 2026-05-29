%% run_zoya_asd_clinical_seeding.m
% RUN_ZOYA_ASD_CLINICAL_SEEDING
% -------------------------------------------------------------------------
% Seeding-only ASD pre-closure runner for Patient Zoya.
%
% WORKFLOW:
%   adult healthy baseline parameters
%   -> pediatric scaling from clinical.common
%   -> ASD clinical seeding through params_from_clinical
%   -> Excel/MAT report
%
% This script intentionally does not run ODE baseline simulation, GSA,
% optimization, calibration, or post-closure/Jovano logic.
%
% OUTPUTS:
%   params0_ASD_pre - parameter struct after ASD clinical seeding        [-]
%   results/tables/asd_clinical_seeding_YYYYMMDD_HHMMSS.xlsx
%   results/tables/params0_ASD_pre_YYYYMMDD_HHMMSS.mat
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
    sprintf('asd_clinical_seeding_%s.xlsx', timestamp));
mat_path = make_unique_output_path(output_dir, ...
    sprintf('params0_ASD_pre_%s.mat', timestamp));

fprintf('===============================================================\n');
fprintf('  Patient Zoya ASD Clinical Seeding\n');
fprintf('===============================================================\n');
fprintf('Mode: seeding-only; no baseline simulation, GSA, or optimization.\n');

scenario = 'pre_surgery'; % ASD pre_closure compatibility scenario
clinical = patient_zoya();
params_ref = default_parameters();

patient = clinical_to_scaling_patient(clinical, 'Zoya_ReferencePatient');
patient.scaling_mode = 'lundquist_bsa';

params_scaled = apply_scaling(params_ref, patient);
case_profile = struct();
params0_ASD_pre = params_from_clinical(params_scaled, clinical, scenario, ...
    params_scaled, case_profile);

verification = build_verification_status(params_scaled, params0_ASD_pre, ...
    clinical, scenario);
write_seeding_workbook(excel_path, params_ref, params_scaled, ...
    params0_ASD_pre, clinical, patient, scenario, verification);
save(mat_path, 'params0_ASD_pre', 'params_scaled', 'params_ref', ...
    'clinical', 'patient', 'scenario', 'verification');

fprintf('\nSeeding verification:\n');
disp(verification(:, {'Check_Name', 'Status', 'Details'}));
fprintf('\nExcel written:\n  %s\n', excel_path);
fprintf('MAT params0_ASD_pre saved:\n  %s\n', mat_path);
fprintf('===============================================================\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function verification = build_verification_status(params_scaled, params0, clinical, scenario)
% BUILD_VERIFICATION_STATUS - seeding-only guardrail checks.
src = clinical.(scenario);
rows = {};
rows = add_check(rows, 'Patient_Z_pre_closure_loaded', true, ...
    'patient_zoya() loaded and scenario pre_surgery selected.');
rows = add_check(rows, 'ASD_diameter_stored', ...
    isfield(params0.asd, 'diameter_mm') && isfinite(params0.asd.diameter_mm), ...
    sprintf('ASD diameter = %s mm.', value_text(params0.asd.diameter_mm)));
rows = add_check(rows, 'ASD_area_stored_or_derived', ...
    isfield(params0.asd, 'area_mm2') && isfinite(params0.asd.area_mm2) && ...
    params0.asd.area_mm2 > 0, ...
    sprintf('ASD area = %s mm^2.', value_text(params0.asd.area_mm2)));
rows = add_check(rows, 'R_ASD_not_computed_without_gradient_and_flow', ...
    contains(params0.clinical_override.ASD_R_seed_status, ...
    'not_computed') || contains(params0.clinical_override.ASD_R_seed_status, ...
    'placeholder'), params0.clinical_override.ASD_R_seed_status);
rows = add_check(rows, 'HR_override_works', ...
    abs(params0.HR - clinical.common.HR) < 1e-9, ...
    sprintf('scaled HR %.6g bpm -> final HR %.6g bpm (%s).', ...
    params_scaled.HR, params0.HR, params0.clinical_override.HR_source));
rows = add_check(rows, 'Missing_PVR_SVR_safe', ...
    ~isfinite(field_or_nan(src, 'PVR_WU')) && ...
    ~isfinite(field_or_nan(src, 'SVR_WU')) && ...
    strcmp(params0.clinical_override.PVR_seed_status, ...
    'missing_keep_pediatric_scaled_resistance') && ...
    strcmp(params0.clinical_override.SVR_seed_status, ...
    'missing_keep_pediatric_scaled_resistance'), ...
    'PVR/SVR missing; scaled pediatric resistances retained.');
rows = add_check(rows, 'Missing_ASD_gradient_safe', ...
    ~isfinite(field_or_nan(src, 'ASD_gradient_mmHg')), ...
    'ASD_gradient_mmHg missing; no DeltaP/Q resistance calculation.');
rows = add_check(rows, 'Missing_volumes_no_chamber_tuning', ...
    contains(params0.clinical_override.chamber_tuning, 'disabled'), ...
    params0.clinical_override.chamber_tuning);
rows = add_check(rows, 'Initial_conditions_rebuilt', ...
    isfield(params0, 'ic') && isfield(params0.ic, 'V') && ...
    numel(params0.ic.V) == 14 && all(isfinite(params0.ic.V)), ...
    sprintf('IC length %d; all finite = %d.', numel(params0.ic.V), ...
    all(isfinite(params0.ic.V))));
rows = add_check(rows, 'Healthy_baseline_params_not_mutated', ...
    isinf(params_scaled.R.asd), ...
    'params_scaled remains closed-ASD; seeding output is params0_ASD_pre.');

verification = cell2table(rows, 'VariableNames', ...
    {'Check_Name', 'Passed', 'Status', 'Details'});
end

function rows = add_check(rows, name, passed, details)
% ADD_CHECK - append pass/fail status row.
if passed
    status = "PASS";
else
    status = "REVIEW";
end
rows(end + 1, :) = {string(name), logical(passed), status, string(details)};
end

function write_seeding_workbook(excel_path, params_ref, params_scaled, ...
    params0, clinical, patient, scenario, verification)
% WRITE_SEEDING_WORKBOOK - export seeding audit workbook.
writetable(build_summary_table(params_scaled, params0, clinical, scenario), ...
    excel_path, 'Sheet', 'Summary');
writetable(build_scenario_table(clinical, patient, scenario), ...
    excel_path, 'Sheet', 'Scenario_Selected');
writetable(build_data_availability_table(clinical, scenario), ...
    excel_path, 'Sheet', 'Clinical_Data_Availability');
writetable(build_hr_table(params_scaled, params0), ...
    excel_path, 'Sheet', 'HR_Override');
writetable(build_asd_geometry_table(clinical, params0, scenario), ...
    excel_path, 'Sheet', 'ASD_Geometry_Seed');
writetable(build_resistance_table(params_scaled, params0, clinical, scenario), ...
    excel_path, 'Sheet', 'Resistance_Seeding');
writetable(build_compliance_table(params_scaled, params0, clinical, scenario), ...
    excel_path, 'Sheet', 'Compliance_Seeding');
writetable(build_chamber_table(params_scaled, params0, clinical, scenario), ...
    excel_path, 'Sheet', 'Chamber_Tuning_Status');
writetable(build_parameter_delta_table(params_scaled, params0), ...
    excel_path, 'Sheet', 'Parameters_Before_After_Seeding');
writetable(build_initial_condition_table(params0), ...
    excel_path, 'Sheet', 'Initial_Condition_Status');
writetable(build_notes_table(params_ref, params_scaled, params0, verification), ...
    excel_path, 'Sheet', 'Notes');
format_workbook_for_readability(excel_path);
end

function tbl = build_summary_table(params_scaled, params0, clinical, scenario)
% BUILD_SUMMARY_TABLE - high-level seeding report.
src = clinical.(scenario);
rows = {
    "Purpose", "ASD clinical seeding only: adult baseline -> pediatric scaling -> params0_ASD_pre."
    "No downstream analysis", "No ODE baseline simulation, GSA, optimization, calibration, or post-closure workflow was run."
    "Patient", "Zoya pre-closure, loaded from config/patient_zoya.m."
    "Scenario requested", scenario
    "Scenario interpreted as", params0.clinical_override.scenario_phase
    "HR handling", sprintf('scaled %.6g bpm -> final %.6g bpm; source=%s', ...
        params_scaled.HR, params0.HR, params0.clinical_override.HR_source)
    "ASD geometry", sprintf('diameter=%s mm; area=%s mm^2; mode=%s', ...
        value_text(params0.asd.diameter_mm), value_text(params0.asd.area_mm2), ...
        params0.asd.mode)
    "ASD resistance", sprintf('R.asd=%s mmHg*s/mL; status=%s', ...
        value_text(params0.R.asd), params0.clinical_override.ASD_R_seed_status)
    "Qp/Qs", sprintf('target=%s; stored as target, not forced as model parameter', ...
        value_text(field_or_nan(src, 'QpQs')))
    "PVR/SVR", sprintf('PVR=%s; SVR=%s; missing values leave scaled resistances unchanged.', ...
        value_text(field_or_nan(src, 'PVR_WU')), value_text(field_or_nan(src, 'SVR_WU')))
    "Chamber tuning", params0.clinical_override.chamber_tuning
    };
tbl = cell2table(rows, 'VariableNames', {'Topic', 'Details'});
end

function tbl = build_scenario_table(clinical, patient, scenario)
% BUILD_SCENARIO_TABLE - selected case and anthropometry.
src = clinical.(scenario);
rows = {
    "Scenario_Input", scenario, "pre_surgery is treated as ASD pre_closure."
    "Patient_Label", patient.label, "Scaling patient label."
    "Age_years", patient.age_years, "clinical.common.age_years."
    "Weight_kg", patient.weight_kg, "clinical.common.weight_kg."
    "Height_cm", patient.height_cm, "clinical.common.height_cm."
    "BSA_m2", patient.BSA, "clinical.common.BSA."
    "Sex", patient.sex, "clinical.common.sex."
    "Scaling_Mode", patient.scaling_mode, "Clinical seeding starts after pediatric scaling."
    "Scenario_QpQs_Target", field_or_nan(src, 'QpQs'), "Validation target only."
    };
tbl = cell2table(rows, 'VariableNames', {'Field', 'Value', 'Notes'});
end

function tbl = build_data_availability_table(clinical, scenario)
% BUILD_DATA_AVAILABILITY_TABLE - selected clinical fields and usage.
src = clinical.(scenario);
common = clinical.common;
rows = {};
rows = add_availability(rows, 'common.age_years', common, 'age_years', 'parameter seed', 'Pediatric scaling.');
rows = add_availability(rows, 'common.weight_kg', common, 'weight_kg', 'parameter seed', 'Pediatric scaling and blood volume.');
rows = add_availability(rows, 'common.height_cm', common, 'height_cm', 'parameter seed', 'Pediatric scaling/BSA context.');
rows = add_availability(rows, 'common.sex', common, 'sex', 'parameter seed/reporting', 'Perempuan/female; stored for reporting/sex-specific scaling if needed.');
rows = add_availability(rows, 'common.BSA', common, 'BSA', 'parameter seed', 'BSA scaling anchor.');
rows = add_availability(rows, 'common.HR', common, 'HR', 'parameter seed', 'Clinical HR override.');
rows = add_availability(rows, 'pre.ASD_diameter_range_mm', src, 'ASD_diameter_range_mm', 'clinical context', 'Reported ASD diameter range.');
rows = add_availability(rows, 'pre.ASD_diameter_mm', src, 'ASD_diameter_mm', 'parameter seed', 'Compute ASD area.');
rows = add_availability(rows, 'pre.ASD_location', src, 'ASD_location', 'parameter seed/reporting', 'Stored in params.asd.location.');
rows = add_availability(rows, 'pre.ASD_area_mm2', src, 'ASD_area_mm2', 'parameter seed', 'Derived from mean ASD diameter in patient_zoya.m.');
rows = add_availability(rows, 'pre.ASD_gradient_mmHg', src, 'ASD_gradient_mmHg', 'missing', 'Needed with direct shunt flow to compute R_ASD.');
rows = add_availability(rows, 'pre.Q_shunt_Lmin', src, 'Q_shunt_Lmin', 'missing', 'Needed with gradient to compute R_ASD.');
rows = add_availability(rows, 'pre.QpQs', src, 'QpQs', 'validation target', 'Stored as target, not forced.');
rows = add_availability(rows, 'pre.PAP_sys_mmHg', src, 'PAP_sys_mmHg', 'validation target if available', 'Not used to tune chamber parameters.');
rows = add_availability(rows, 'pre.PAP_dia_mmHg', src, 'PAP_dia_mmHg', 'validation target if available', 'Required with Qp/HR for pulmonary compliance.');
rows = add_availability(rows, 'pre.PAP_mean_mmHg', src, 'PAP_mean_mmHg', 'validation target if available', 'Initial-condition pressure anchor if available.');
rows = add_availability(rows, 'pre.PVR_WU', src, 'PVR_WU', 'parameter seed if available', 'Missing keeps scaled pulmonary resistance.');
rows = add_availability(rows, 'pre.SAP_sys_NIBP_mmHg', src, 'SAP_sys_NIBP_mmHg', 'alternative pressure source', 'Not selected for generic systemic pressure in this phase.');
rows = add_availability(rows, 'pre.SAP_dia_NIBP_mmHg', src, 'SAP_dia_NIBP_mmHg', 'alternative pressure source', 'Not selected for generic systemic pressure in this phase.');
rows = add_availability(rows, 'pre.SAP_sys_RFA_mmHg', src, 'SAP_sys_RFA_mmHg', 'selected pressure source', 'Preferred RFA/cath systolic pressure.');
rows = add_availability(rows, 'pre.SAP_dia_RFA_mmHg', src, 'SAP_dia_RFA_mmHg', 'selected pressure source', 'Preferred RFA/cath diastolic pressure.');
rows = add_availability(rows, 'pre.SAP_sys_DAo_mmHg', src, 'SAP_sys_DAo_mmHg', 'missing', 'Descending aorta pressure unavailable.');
rows = add_availability(rows, 'pre.SAP_dia_DAo_mmHg', src, 'SAP_dia_DAo_mmHg', 'missing', 'Descending aorta pressure unavailable.');
rows = add_availability(rows, 'pre.MAP_NIBP_mmHg', src, 'MAP_NIBP_mmHg', 'alternative pressure source', 'Not selected for generic MAP in this phase.');
rows = add_availability(rows, 'pre.MAP_RFA_mmHg', src, 'MAP_RFA_mmHg', 'selected pressure source', 'Preferred RFA/cath MAP.');
rows = add_availability(rows, 'pre.SAP_sys_mmHg', src, 'SAP_sys_mmHg', 'validation target if available', 'Required with Qs/HR for systemic compliance.');
rows = add_availability(rows, 'pre.SAP_dia_mmHg', src, 'SAP_dia_mmHg', 'validation target if available', 'Required with Qs/HR for systemic compliance.');
rows = add_availability(rows, 'pre.SAP_mean_mmHg', src, 'SAP_mean_mmHg', 'validation target if available', 'Initial-condition pressure anchor if available.');
rows = add_availability(rows, 'pre.SVR_WU', src, 'SVR_WU', 'parameter seed if available', 'Missing keeps scaled systemic resistance.');
rows = add_availability(rows, 'pre.LAP_mean_mmHg', src, 'LAP_mean_mmHg', 'validation target if available', 'No R_ASD calculation without direct shunt flow.');
rows = add_availability(rows, 'pre.RAP_mean_mmHg', src, 'RAP_mean_mmHg', 'validation target if available', 'No R_ASD calculation without direct shunt flow.');
rows = add_availability(rows, 'pre.LVEDV_mL', src, 'LVEDV_mL', 'missing', 'Missing disables chamber tuning.');
rows = add_availability(rows, 'pre.LVESV_mL', src, 'LVESV_mL', 'missing', 'Missing disables chamber tuning.');
rows = add_availability(rows, 'pre.RVEDV_mL', src, 'RVEDV_mL', 'missing', 'Missing disables chamber tuning.');
rows = add_availability(rows, 'pre.RVESV_mL', src, 'RVESV_mL', 'missing', 'Missing disables chamber tuning.');
rows = add_availability(rows, 'pre.CO_Lmin', src, 'CO_Lmin', 'validation target if available', 'Can support compliance seeding if paired with pulse pressure.');
rows = add_availability(rows, 'pre.Qp_Lmin', src, 'Qp_Lmin', 'parameter seed', 'Pulmonary flow supports pulmonary compliance seed.');
rows = add_availability(rows, 'pre.Qs_Lmin', src, 'Qs_Lmin', 'parameter seed', 'Systemic flow supports systemic compliance seed and IC flow seed.');
tbl = cell2table(rows, 'VariableNames', ...
    {'Field_Name', 'Available', 'Value', 'Use_In_This_Phase', 'Notes'});
end

function rows = add_availability(rows, label, src, field_name, use_text, notes)
% ADD_AVAILABILITY - append one clinical field availability row.
[value, available] = field_value_for_report(src, field_name);
rows(end + 1, :) = {string(label), logical(available), value, ...
    string(use_text), string(notes)};
end

function tbl = build_hr_table(params_scaled, params0)
rows = {
    "Scaled_HR_bpm", params_scaled.HR, "from pediatric allometric scaling", "before clinical seeding"
    "Final_HR_bpm", params0.HR, params0.clinical_override.HR_source, "after clinical seeding"
    "T_HB_s", 60 / params0.HR, "computed from final HR", "cardiac-cycle timing basis"
    "Tc_LV_s", params0.Tc_LV, "recomputed after HR override", "ventricular activation timing"
    "Tc_RV_s", params0.Tc_RV, "recomputed after HR override", "ventricular activation timing"
    "Tc_LA_s", params0.Tc_LA, "recomputed after HR override", "atrial activation timing"
    "Tc_RA_s", params0.Tc_RA, "recomputed after HR override", "atrial activation timing"
    };
tbl = cell2table(rows, 'VariableNames', ...
    {'Metric', 'Value', 'Source', 'Notes'});
end

function tbl = build_asd_geometry_table(clinical, params0, scenario)
src = clinical.(scenario);
rows = {
    "ASD_diameter_mm", field_or_nan(src, 'ASD_diameter_mm'), params0.asd.diameter_mm, "direct if available", "Stored in params.asd.diameter_mm."
    "ASD_area_mm2", field_or_nan(src, 'ASD_area_mm2'), params0.asd.area_mm2, params0.clinical_override.ASD_area_source, "Computed as pi*(diameter/2)^2 when direct area is missing."
    "ASD_location", value_text(field_value_raw(src, 'ASD_location')), string(params0.asd.location), "direct if available", "Stored in params.asd.location."
    "ASD_mode", NaN, string(params0.asd.mode), "model mapping", "orifice mode is used when geometry exists but DeltaP/Q are missing."
    "ASD_mapping_status", NaN, string(params0.asd.mapping_status), "model mapping", "Documents seed vs calibrated status."
    };
tbl = cell2table(rows, 'VariableNames', ...
    {'Metric', 'Clinical_Value', 'Seeded_Value', 'Source', 'Notes'});
end

function tbl = build_resistance_table(params_scaled, params0, clinical, scenario)
src = clinical.(scenario);
rows = {
    "R_ASD", "mmHg*s/mL", value_text(params_scaled.R.asd), value_text(params0.R.asd), params0.clinical_override.ASD_R_seed_status, "Computed only from DeltaP/Q if both exist; otherwise not calibrated."
    "SVR_WU", "WU", "NaN", value_text(field_or_nan(src, 'SVR_WU')), params0.clinical_override.SVR_seed_status, "Clinical target availability."
    "R.SAR", "mmHg*s/mL", value_text(params_scaled.R.SAR), value_text(params0.R.SAR), params0.clinical_override.SVR_seed_status, "Systemic arterial resistance block."
    "R.SC", "mmHg*s/mL", value_text(params_scaled.R.SC), value_text(params0.R.SC), params0.clinical_override.SVR_seed_status, "Systemic capillary resistance block."
    "R.SVEN", "mmHg*s/mL", value_text(params_scaled.R.SVEN), value_text(params0.R.SVEN), params0.clinical_override.SVR_seed_status, "Systemic venous resistance block."
    "PVR_WU", "WU", "NaN", value_text(field_or_nan(src, 'PVR_WU')), params0.clinical_override.PVR_seed_status, "Clinical target availability."
    "R.PAR", "mmHg*s/mL", value_text(params_scaled.R.PAR), value_text(params0.R.PAR), params0.clinical_override.PVR_seed_status, "Pulmonary arterial resistance block."
    "R.PCOX", "mmHg*s/mL", value_text(params_scaled.R.PCOX), value_text(params0.R.PCOX), params0.clinical_override.PVR_seed_status, "Pulmonary capillary resistance block."
    "R.PCNO", "mmHg*s/mL", value_text(params_scaled.R.PCNO), value_text(params0.R.PCNO), params0.clinical_override.PVR_seed_status, "Pulmonary capillary resistance block."
    "R.PVEN", "mmHg*s/mL", value_text(params_scaled.R.PVEN), value_text(params0.R.PVEN), params0.clinical_override.PVR_seed_status, "Pulmonary venous resistance block."
    };
tbl = cell2table(rows, 'VariableNames', ...
    {'Metric', 'Unit', 'Before_Seeding_Text', 'After_Seeding_Text', 'Status', 'Notes'});
end

function tbl = build_compliance_table(params_scaled, params0, clinical, scenario)
src = clinical.(scenario);
rows = {
    "C.SAR", "mL/mmHg", params_scaled.C.SAR, params0.C.SAR, params0.clinical_override.C_SAR_seed_status, "Requires systemic SV or CO/HR and systemic pulse pressure."
    "C.PAR", "mL/mmHg", params_scaled.C.PAR, params0.C.PAR, params0.clinical_override.C_PAR_seed_status, "Requires pulmonary SV or Qp/HR and pulmonary pulse pressure."
    "Systemic_Pulse_Pressure", "mmHg", NaN, pulse_pressure(src, 'SAP_sys_mmHg', 'SAP_dia_mmHg'), "input availability", "SBP-DBP."
    "Pulmonary_Pulse_Pressure", "mmHg", NaN, pulse_pressure(src, 'PAP_sys_mmHg', 'PAP_dia_mmHg'), "input availability", "PAPsys-PAPdia."
    "Qs_Lmin", "L/min", NaN, field_or_nan(src, 'Qs_Lmin'), "input availability", "Supports systemic SV = Qs/HR."
    "Qp_Lmin", "L/min", NaN, field_or_nan(src, 'Qp_Lmin'), "input availability", "Supports pulmonary SV = Qp/HR."
    "CO_Lmin", "L/min", NaN, field_or_nan(src, 'CO_Lmin'), "input availability", "Left NaN because Qs_Lmin is recorded separately."
    "QpQs", "-", NaN, field_or_nan(src, 'QpQs'), "target only", "Can infer Qp only if Qs/CO also exists."
    };
tbl = cell2table(rows, 'VariableNames', ...
    {'Metric', 'Unit', 'Before_Seeding', 'After_Seeding', 'Status', 'Notes'});
end

function tbl = build_chamber_table(params_scaled, params0, clinical, scenario)
src = clinical.(scenario);
rows = {
    "LV volumes available", all_finite_fields(src, {'LVEDV_mL', 'LVESV_mL'}), "Required for LV chamber tuning."
    "RV volumes available", all_finite_fields(src, {'RVEDV_mL', 'RVESV_mL'}), "Required for RV chamber tuning."
    "override_IC", logical_field(src, 'override_IC'), "Must be true before chamber tuning can run."
    "Chamber tuning status", params0.clinical_override.chamber_tuning, "Patient Z pre-closure keeps chamber parameters from pediatric scaling."
    "E.LV.EA before/after", sprintf('%s -> %s', value_text(params_scaled.E.LV.EA), value_text(params0.E.LV.EA)), "LV active elastance."
    "E.RV.EA before/after", sprintf('%s -> %s', value_text(params_scaled.E.RV.EA), value_text(params0.E.RV.EA)), "RV active elastance."
    "V0.LV before/after", sprintf('%s -> %s', value_text(params_scaled.V0.LV), value_text(params0.V0.LV)), "LV unstressed volume."
    "V0.RV before/after", sprintf('%s -> %s', value_text(params_scaled.V0.RV), value_text(params0.V0.RV)), "RV unstressed volume."
    };
tbl = cell2table(rows, 'VariableNames', {'Item', 'Value', 'Notes'});
end

function tbl = build_parameter_delta_table(params_scaled, params0)
% BUILD_PARAMETER_DELTA_TABLE - key parameter before/after comparison.
rows = {};
rows = add_param_delta(rows, 'HR', 'bpm', params_scaled.HR, params0.HR, 'clinical HR override');
rows = add_param_delta(rows, 'T_HB', 's', 60 / params_scaled.HR, 60 / params0.HR, 'timing recomputed from HR');
rows = add_param_delta(rows, 'R.asd', 'mmHg*s/mL', params_scaled.R.asd, params0.R.asd, params0.clinical_override.ASD_R_seed_status);
rows = add_param_delta(rows, 'asd.diameter_mm', 'mm', params_scaled.asd.diameter_mm, params0.asd.diameter_mm, 'ASD geometry seed');
rows = add_param_delta(rows, 'asd.area_mm2', 'mm^2', params_scaled.asd.area_mm2, params0.asd.area_mm2, 'ASD geometry seed');
rows = add_param_delta(rows, 'asd.Cd', '-', params_scaled.asd.Cd, params0.asd.Cd, 'default coefficient; not calibrated');
rows = add_param_delta(rows, 'R.SAR', 'mmHg*s/mL', params_scaled.R.SAR, params0.R.SAR, params0.clinical_override.SVR_seed_status);
rows = add_param_delta(rows, 'R.SC', 'mmHg*s/mL', params_scaled.R.SC, params0.R.SC, params0.clinical_override.SVR_seed_status);
rows = add_param_delta(rows, 'R.SVEN', 'mmHg*s/mL', params_scaled.R.SVEN, params0.R.SVEN, params0.clinical_override.SVR_seed_status);
rows = add_param_delta(rows, 'R.PAR', 'mmHg*s/mL', params_scaled.R.PAR, params0.R.PAR, params0.clinical_override.PVR_seed_status);
rows = add_param_delta(rows, 'R.PCOX', 'mmHg*s/mL', params_scaled.R.PCOX, params0.R.PCOX, params0.clinical_override.PVR_seed_status);
rows = add_param_delta(rows, 'R.PCNO', 'mmHg*s/mL', params_scaled.R.PCNO, params0.R.PCNO, params0.clinical_override.PVR_seed_status);
rows = add_param_delta(rows, 'R.PVEN', 'mmHg*s/mL', params_scaled.R.PVEN, params0.R.PVEN, params0.clinical_override.PVR_seed_status);
rows = add_param_delta(rows, 'C.SAR', 'mL/mmHg', params_scaled.C.SAR, params0.C.SAR, params0.clinical_override.C_SAR_seed_status);
rows = add_param_delta(rows, 'C.PAR', 'mL/mmHg', params_scaled.C.PAR, params0.C.PAR, params0.clinical_override.C_PAR_seed_status);
rows = add_param_delta(rows, 'V0.SVEN', 'mL', params_scaled.V0.SVEN, params0.V0.SVEN, 'blood-volume/preload reconciliation after seeding');
rows = add_param_delta(rows, 'E.LV.EA', 'mmHg/mL', params_scaled.E.LV.EA, params0.E.LV.EA, 'chamber tuning disabled');
rows = add_param_delta(rows, 'E.RV.EA', 'mmHg/mL', params_scaled.E.RV.EA, params0.E.RV.EA, 'chamber tuning disabled');
rows = add_param_delta(rows, 'V0.LV', 'mL', params_scaled.V0.LV, params0.V0.LV, 'chamber tuning disabled');
rows = add_param_delta(rows, 'V0.RV', 'mL', params_scaled.V0.RV, params0.V0.RV, 'chamber tuning disabled');
tbl = cell2table(rows, 'VariableNames', ...
    {'Parameter', 'Unit', 'Before_Seeding', 'After_Seeding', ...
    'Percent_Change', 'Source_Of_Change', 'Notes'});
end

function rows = add_param_delta(rows, name, unit, before, after, notes)
% ADD_PARAM_DELTA - append one before/after parameter row.
pct = NaN;
if isfinite(before) && isfinite(after) && abs(before) > 1e-12
    pct = 100 * (after - before) / abs(before);
end
source = "unchanged";
if ~(isequaln(before, after))
    source = "clinical_seeding_or_reconciliation";
end
rows(end + 1, :) = {string(name), string(unit), value_text(before), ...
    value_text(after), pct, ...
    source, string(notes)};
end

function tbl = build_initial_condition_table(params0)
sidx = params0.idx;
ic = params0.ic.V(:);
vol_idx = [sidx.V_RA sidx.V_RV sidx.V_LA sidx.V_LV ...
    sidx.V_SAR sidx.V_SC sidx.V_SVEN sidx.V_PAR sidx.V_PVEN];
rows = {
    "IC_length", numel(ic), "Expected 14-state vector."
    "All_finite", all(isfinite(ic)), "Must be true before baseline simulation."
    "BV_from_IC_mL", sum(ic(vol_idx)), "Sum of model volume states."
    "BV_target_mL", params0.scaling.BV_patient, "From patient weight and age blood-volume rule."
    "BV_difference_mL", sum(ic(vol_idx)) - params0.scaling.BV_patient, "IC volume minus target blood volume."
    "V_RA_mL", ic(sidx.V_RA), "Initial right atrial volume."
    "V_RV_mL", ic(sidx.V_RV), "Initial right ventricular volume."
    "V_LA_mL", ic(sidx.V_LA), "Initial left atrial volume."
    "V_LV_mL", ic(sidx.V_LV), "Initial left ventricular volume."
    "V_SVEN_mL", ic(sidx.V_SVEN), "Systemic venous volume absorbs blood-volume residual when needed."
    };
tbl = cell2table(rows, 'VariableNames', {'Metric', 'Value', 'Notes'});
end

function tbl = build_notes_table(params_ref, params_scaled, params0, verification)
rows = {
    "Clinical seeding definition", "Clinical seeding maps available patient measurements into parameters before any disease baseline simulation."
    "HK workflow mirror", "This mirrors adult baseline -> pediatric scaling -> params_from_clinical -> baseline disease simulation; this script stops after params_from_clinical."
    "ASD-specific change", "The defect is LA-RA. Positive Q_ASD means LA_to_RA. VSD LV-RV fields are closed and inactive."
    "Qp/Qs handling", "Qp/Qs is stored as a target for later validation/calibration; it is not forced into model flows."
    "R_ASD handling", "R_ASD cannot be computed directly without ASD pressure gradient and direct Q_ASD."
    "Geometry handling", "Patient Zoya diameter is converted to area and used in ASD geometry fields."
    "Cd handling", "Default orifice Cd is a model seed, not calibrated in this phase."
    "Chamber handling", "No LV/RV chamber tuning is performed because Patient Z pre-closure volumes and EF are missing."
    "Baseline preservation", sprintf('params_ref R.asd=%s; params_scaled R.asd=%s; params0 R.asd=%s.', ...
        value_text(params_ref.R.asd), value_text(params_scaled.R.asd), value_text(params0.R.asd))
    "Verification summary", sprintf('%d of %d seeding checks passed.', ...
        sum(verification.Passed), height(verification))
    "Next criterion", "Proceed to baseline ASD pre-closure simulation only after this seeding report is reviewed."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic', 'Note'});
end

function format_workbook_for_readability(excel_path)
% FORMAT_WORKBOOK_FOR_READABILITY - optional Excel COM readability pass.
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
    warning('run_zoya_asd_clinical_seeding:formatSkipped', ...
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

function value = field_or_nan(src, field_name)
value = NaN;
if isstruct(src) && isfield(src, field_name) && isnumeric(src.(field_name)) && ...
        isscalar(src.(field_name))
    value = src.(field_name);
end
end

function [value, available] = field_value_for_report(src, field_name)
% FIELD_VALUE_FOR_REPORT - report scalar/vector/text clinical fields.
available = false;
value = "NaN";
if ~isstruct(src) || ~isfield(src, field_name)
    return;
end
raw_value = src.(field_name);
if isnumeric(raw_value)
    if isempty(raw_value) || all(isnan(raw_value(:)))
        return;
    end
    available = true;
    if isscalar(raw_value)
        value = value_text(raw_value);
    else
        parts = arrayfun(@(x) char(value_text(x)), raw_value(:)', ...
            'UniformOutput', false);
        value = "[" + strjoin(parts, ", ") + "]";
    end
elseif ischar(raw_value) || isstring(raw_value)
    raw_text = string(raw_value);
    available = strlength(raw_text) > 0;
    value = raw_text;
elseif islogical(raw_value) && isscalar(raw_value)
    available = true;
    value = string(raw_value);
end
end

function value = field_value_raw(src, field_name)
% FIELD_VALUE_RAW - return optional raw field for mixed text/numeric tables.
value = NaN;
if isstruct(src) && isfield(src, field_name)
    value = src.(field_name);
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
elseif islogical(value)
    txt = string(value);
elseif isstring(value) || ischar(value)
    txt = string(value);
else
    txt = "";
end
end

function value = pulse_pressure(src, sys_field, dia_field)
sys_value = field_or_nan(src, sys_field);
dia_value = field_or_nan(src, dia_field);
if isfinite(sys_value) && isfinite(dia_value)
    value = sys_value - dia_value;
else
    value = NaN;
end
end

function tf = all_finite_fields(src, field_names)
tf = true;
for idx = 1:numel(field_names)
    if ~isfinite(field_or_nan(src, field_names{idx}))
        tf = false;
        return;
    end
end
end

function value = logical_field(src, field_name)
value = false;
if isstruct(src) && isfield(src, field_name)
    value = logical(src.(field_name));
end
end
