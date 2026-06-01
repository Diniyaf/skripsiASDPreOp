function caseProfile = build_asd_case_calibration_profile(clinical, scenario, params0)
% BUILD_ASD_CASE_CALIBRATION_PROFILE
% -----------------------------------------------------------------------
% Build a patient-generic ASD calibration profile from available clinical data.
%
% This helper mirrors the Hafiz-Keisya VSD case-profile pattern: clinical
% availability is evaluated once, then target tiers, candidate parameters,
% GSA masks, and calibration runners consume the same profile instead of
% hardcoding patient-specific assumptions.
%
% INPUTS:
%   clinical    - ASD clinical data struct from config/patient_*.m       [-]
%   scenario    - requested scenario string                              [-]
%   params0     - seeded ASD parameter struct, optional                  [-]
%
% OUTPUTS:
%   caseProfile - struct with data availability and calibration policy    [-]
%
% ASSUMPTIONS:
%   - pre_surgery and pre_closure are equivalent ASD pre-closure phases.
%   - post_surgery and post_closure are equivalent ASD post-closure phases.
%   - Missing clinical fields are not targets.
%
% REFERENCES:
%   [1] C:/Users/Diniya/unified-vsd-temp/src/calibration/build_case_calibration_profile.m
%   [2] C:/Users/Diniya/unified-vsd-temp/src/calibration/build_target_tiers.m
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  1.0
% -----------------------------------------------------------------------

if nargin < 2 || isempty(scenario)
    scenario = 'pre_surgery';
end
if nargin < 3
    params0 = struct();
end
if nargin < 1 || isempty(clinical)
    error('build_asd_case_calibration_profile:missingClinical', ...
        'A clinical struct is required.');
end

[src, scenario_key, phase_label] = select_scenario_source(clinical, scenario);
patient_label = resolve_patient_label(clinical);
patient_id = resolve_patient_id(clinical, patient_label);

availability = build_availability_table(clinical, src);
flags = build_data_flags(src, availability);
target_policy = build_target_policy(flags, phase_label);
allowed_groups = build_allowed_groups(flags, phase_label);

caseProfile = struct();
caseProfile.is_asd_case_profile = true;
caseProfile.model_family = 'ASD';
caseProfile.patient_label = string(patient_label);
caseProfile.patient_id = string(patient_id);
caseProfile.scenario_requested = string(scenario);
caseProfile.scenario_key = string(scenario_key);
caseProfile.scenario_phase = string(phase_label);
caseProfile.mode = string(classify_mode(flags, phase_label));
caseProfile.description = string(describe_mode(caseProfile.mode));
caseProfile.availableClinicalFields = availability(availability.Available, :);
caseProfile.missingClinicalFields = availability(~availability.Available, :);
caseProfile.clinicalAvailability = availability;
caseProfile.dataFlags = flags;
caseProfile.targetPolicy = target_policy;
caseProfile.allowedCandidateGroups = allowed_groups;
caseProfile.excludedTargetReasons = build_excluded_target_reasons(flags);
caseProfile.predictionOnlyOutputs = build_prediction_only_outputs(flags);
caseProfile.notes = build_notes(patient_label, flags, phase_label, params0);
caseProfile.clinical = clinical;
caseProfile.params0_snapshot_available = isstruct(params0) && ~isempty(fieldnames(params0));

end

function [src, scenario_key, phase_label] = select_scenario_source(clinical, scenario)
% SELECT_SCENARIO_SOURCE - resolve ASD scenario aliases.
scenario_text = lower(strtrim(char(scenario)));
switch scenario_text
    case {'pre_surgery', 'pre_closure'}
        phase_label = 'pre_closure';
        candidates = {'pre_closure', 'pre_surgery'};
    case {'post_surgery', 'post_closure'}
        phase_label = 'post_closure';
        candidates = {'post_closure', 'post_surgery'};
    otherwise
        error('build_asd_case_calibration_profile:unknownScenario', ...
            'scenario must be pre_surgery, pre_closure, post_surgery, or post_closure.');
end

for i = 1:numel(candidates)
    if isfield(clinical, candidates{i})
        src = clinical.(candidates{i});
        scenario_key = candidates{i};
        return;
    end
end

error('build_asd_case_calibration_profile:missingScenario', ...
    'No clinical scenario field found for %s.', scenario_text);
end

function label = resolve_patient_label(clinical)
% RESOLVE_PATIENT_LABEL - choose a readable case label.
label = 'ASD_patient';
if isfield(clinical, 'metadata') && isfield(clinical.metadata, 'patient_name') && ...
        ~isempty(clinical.metadata.patient_name)
    label = char(string(clinical.metadata.patient_name));
elseif isfield(clinical, 'common') && isfield(clinical.common, 'patient_name') && ...
        ~isempty(clinical.common.patient_name)
    label = char(string(clinical.common.patient_name));
end
end

function patient_id = resolve_patient_id(clinical, fallback)
% RESOLVE_PATIENT_ID - choose a stable identifier when present.
patient_id = fallback;
if isfield(clinical, 'metadata') && isfield(clinical.metadata, 'patient_id') && ...
        ~isempty(clinical.metadata.patient_id)
    patient_id = char(string(clinical.metadata.patient_id));
elseif isfield(clinical, 'common') && isfield(clinical.common, 'patient_id') && ...
        ~isempty(clinical.common.patient_id)
    patient_id = char(string(clinical.common.patient_id));
end
end

function availability = build_availability_table(clinical, src)
% BUILD_AVAILABILITY_TABLE - one row per clinically relevant ASD field.
rows = {};
rows = add_field(rows, 'common.age_years', clinical.common, 'age_years', 'years', 'scaling_input', ...
    'Patient age used by pediatric scaling and reporting.');
rows = add_field(rows, 'common.sex', clinical.common, 'sex', '-', 'demographic_input', ...
    'Sex is reported; current model does not calibrate it.');
rows = add_field(rows, 'common.height_cm', clinical.common, 'height_cm', 'cm', 'scaling_input', ...
    'Height used by BSA/body-size scaling.');
rows = add_field(rows, 'common.weight_kg', clinical.common, 'weight_kg', 'kg', 'scaling_input', ...
    'Weight used by pediatric scaling.');
rows = add_field(rows, 'common.BSA', clinical.common, 'BSA', 'm^2', 'scaling_input', ...
    'BSA used by pediatric scaling.');
rows = add_field(rows, 'common.HR', clinical.common, 'HR', 'bpm', 'clinical_override', ...
    'HR overrides scaled prior during clinical seeding when finite.');

scenario_fields = {
    'ASD_diameter_mm', 'mm', 'parameter_seed', 'ASD geometry seed.'
    'ASD_area_mm2', 'mm^2', 'parameter_seed', 'ASD geometry seed or diameter-derived area.'
    'ASD_gradient_mmHg', 'mmHg', 'missing_or_shunt_resistance_seed', 'Needed with direct Q_ASD to compute linear R_ASD.'
    'Q_shunt_Lmin', 'L/min', 'direct_shunt_target_if_available', 'Direct ASD shunt flow; usually missing.'
    'Qp_Lmin', 'L/min', 'primary_target', 'Pulmonary flow.'
    'Qs_Lmin', 'L/min', 'primary_target', 'Systemic flow.'
    'QpQs', '-', 'primary_target', 'Pulmonary-to-systemic flow ratio.'
    'SAP_sys_mmHg', 'mmHg', 'secondary_guard', 'Systemic systolic pressure.'
    'SAP_dia_mmHg', 'mmHg', 'secondary_guard', 'Systemic diastolic pressure.'
    'SAP_mean_mmHg', 'mmHg', 'primary_target', 'Mean systemic arterial pressure.'
    'PAP_sys_mmHg', 'mmHg', 'secondary_guard', 'Pulmonary systolic pressure.'
    'PAP_dia_mmHg', 'mmHg', 'secondary_guard', 'Pulmonary diastolic pressure.'
    'PAP_mean_mmHg', 'mmHg', 'primary_target', 'Mean pulmonary arterial pressure.'
    'LAP_mean_mmHg', 'mmHg', 'primary_target', 'Left atrial filling pressure.'
    'RAP_mean_mmHg', 'mmHg', 'prediction_only_if_missing', 'Right atrial pressure.'
    'PVR_WU', 'WU', 'prediction_only_if_missing', 'Pulmonary vascular resistance.'
    'SVR_WU', 'WU', 'prediction_only_if_missing', 'Systemic vascular resistance.'
    'LVEDV_mL', 'mL', 'volume_function_target_if_available', 'LV end-diastolic volume.'
    'LVESV_mL', 'mL', 'volume_function_target_if_available', 'LV end-systolic volume.'
    'RVEDV_mL', 'mL', 'volume_function_target_if_available', 'RV end-diastolic volume.'
    'RVESV_mL', 'mL', 'volume_function_target_if_available', 'RV end-systolic volume.'
    'LVEF', '-', 'volume_function_target_if_available', 'LV ejection fraction.'
    'EF', '-', 'volume_function_target_if_available', 'LV ejection fraction alternate field.'
    'RVEF', '-', 'volume_function_target_if_available', 'RV ejection fraction.'
    'CO_Lmin', 'L/min', 'primary_target_if_used_as_Qs', 'Systemic cardiac output if Qs is unavailable.'
    };

for i = 1:size(scenario_fields, 1)
rows = add_field(rows, scenario_fields{i, 1}, src, scenario_fields{i, 1}, ...
        scenario_fields{i, 2}, scenario_fields{i, 3}, scenario_fields{i, 4});
end

availability = cell2table(rows, 'VariableNames', ...
    {'Field','Available','Value','Unit','Use','Notes'});
end

function rows = add_field(rows, display_name, src, field_name, unit, use, notes)
% ADD_FIELD - append availability row with scalar/string support.
[available, value_text] = read_value_text(src, field_name);
rows(end + 1, :) = {string(display_name), available, string(value_text), ...
    string(unit), string(use), string(notes)};
end

function [available, value_text] = read_value_text(src, field_name)
% READ_VALUE_TEXT - compact value rendering for availability tables.
available = false;
value_text = "NaN";
if ~isstruct(src) || ~isfield(src, field_name)
    return;
end
value = src.(field_name);
if isnumeric(value)
    available = any(isfinite(value(:)));
    if isscalar(value)
        value_text = string(sprintf('%.12g', value));
    else
        value_text = "[" + strjoin(cellstr(string(value(:)')), ", ") + "]";
    end
elseif ischar(value) || isstring(value)
    available = strlength(string(value)) > 0;
    value_text = string(value);
elseif islogical(value)
    available = true;
    value_text = string(value);
else
    value_text = string(class(value));
end
end

function flags = build_data_flags(src, availability)
% BUILD_DATA_FLAGS - booleans used by downstream governance.
flags = struct();
flags.has_qp = has_numeric(src, 'Qp_Lmin');
flags.has_qs = has_numeric(src, 'Qs_Lmin') || has_numeric(src, 'CO_Lmin');
flags.has_qpqs = has_numeric(src, 'QpQs');
flags.has_map = has_numeric(src, 'SAP_mean_mmHg');
flags.has_pap_mean = has_numeric(src, 'PAP_mean_mmHg');
flags.has_lap = has_numeric(src, 'LAP_mean_mmHg');
flags.has_pressure_flow_targets = flags.has_qp && flags.has_qs && ...
    flags.has_qpqs && flags.has_map && flags.has_pap_mean && flags.has_lap;
flags.has_secondary_systemic_pressure = has_numeric(src, 'SAP_sys_mmHg') && ...
    has_numeric(src, 'SAP_dia_mmHg');
flags.has_secondary_pulmonary_pressure = has_numeric(src, 'PAP_sys_mmHg') && ...
    has_numeric(src, 'PAP_dia_mmHg');
flags.has_asd_geometry = has_numeric(src, 'ASD_diameter_mm') || has_numeric(src, 'ASD_area_mm2');
flags.has_asd_gradient = has_numeric(src, 'ASD_gradient_mmHg');
flags.has_direct_qasd = has_numeric(src, 'Q_shunt_Lmin');
flags.has_rap = has_numeric(src, 'RAP_mean_mmHg');
flags.has_pvr = has_numeric(src, 'PVR_WU');
flags.has_svr = has_numeric(src, 'SVR_WU');
flags.has_lv_volumes = has_numeric(src, 'LVEDV_mL') && has_numeric(src, 'LVESV_mL');
flags.has_rv_volumes = has_numeric(src, 'RVEDV_mL') && has_numeric(src, 'RVESV_mL');
flags.has_lv_function = has_numeric(src, 'LVEF') || has_numeric(src, 'EF');
flags.has_rv_function = has_numeric(src, 'RVEF');
flags.has_ventricular_volume_function_targets = flags.has_lv_volumes || ...
    flags.has_rv_volumes || flags.has_lv_function || flags.has_rv_function;
flags.sparse_volume = ~flags.has_ventricular_volume_function_targets;
flags.missing_direct_shunt_flow = ~flags.has_direct_qasd;
flags.missing_asd_gradient = ~flags.has_asd_gradient;
flags.missing_resistance_targets = ~flags.has_pvr || ~flags.has_svr;
flags.availability_row_count = height(availability);
flags.available_row_count = sum(availability.Available);
end

function tf = has_numeric(src, field_name)
% HAS_NUMERIC - true for finite scalar/vector numeric field.
tf = isstruct(src) && isfield(src, field_name) && isnumeric(src.(field_name)) && ...
    any(isfinite(src.(field_name)(:)));
end

function target_policy = build_target_policy(flags, phase_label)
% BUILD_TARGET_POLICY - target tier names used by build_asd_target_tiers.
target_policy = struct();
target_policy.hard_primary = {'QpQs','Qp_Lmin','Qs_Lmin','SAP_mean','PAP_mean','LAP_mean'};
target_policy.soft_secondary_guard = {'SAP_max','SAP_min','PAP_max','PAP_min'};
target_policy.derived_comparison = {'Q_ASD_Lmin','Q_ASD_mean_mLs','DeltaP_LA_RA'};
target_policy.prediction_only = {'RAP_mean','SVR','PVR','LVEDV','LVESV','RVEDV','RVESV','LVEF','RVEF'};
target_policy.expected_asd_direction = 'LA_to_RA';
target_policy.expected_preclosure_qpqs_gt_one = strcmp(phase_label, 'pre_closure');
target_policy.can_fit_direct_qasd = flags.has_direct_qasd && flags.has_asd_gradient;
end

function allowed = build_allowed_groups(flags, phase_label)
% BUILD_ALLOWED_GROUPS - patient-specific calibration-group policy.
allowed = struct();
allowed.GroupA = true;
allowed.GroupB = true;
allowed.GroupC = true;
allowed.GroupCCalibrationAllowedByDefault = flags.has_ventricular_volume_function_targets && ...
    strcmp(phase_label, 'pre_closure');
allowed.GroupCReason = 'Ventricular Group C requires LV/RV volume or EF targets for default calibration.';
if allowed.GroupCCalibrationAllowedByDefault
    allowed.GroupCReason = 'Ventricular volume/function targets are available; Group C can be reviewed for calibration.';
end
end

function mode = classify_mode(flags, phase_label)
% CLASSIFY_MODE - compact calibration case label.
if strcmp(phase_label, 'pre_closure') && flags.has_pressure_flow_targets && flags.sparse_volume
    mode = 'pressure_flow_preclosure_sparse_volume';
elseif strcmp(phase_label, 'pre_closure') && flags.has_pressure_flow_targets
    mode = 'pressure_flow_preclosure_with_volume_targets';
elseif strcmp(phase_label, 'post_closure')
    mode = 'postclosure_profile_pending';
else
    mode = 'asd_profile_review_required';
end
end

function text = describe_mode(mode)
% DESCRIBE_MODE - thesis-readable case-profile description.
switch char(mode)
    case 'pressure_flow_preclosure_sparse_volume'
        text = ['Pre-closure ASD case with pressure-flow targets but missing ', ...
            'LV/RV volume and EF targets.'];
    case 'pressure_flow_preclosure_with_volume_targets'
        text = 'Pre-closure ASD case with pressure-flow and chamber-volume/function targets.';
    case 'postclosure_profile_pending'
        text = 'Post-closure ASD case; not active for current pre-closure workflow.';
    otherwise
        text = 'ASD case requires manual review before GSA/calibration.';
end
end

function tbl = build_excluded_target_reasons(flags)
% BUILD_EXCLUDED_TARGET_REASONS - table of target exclusions.
rows = {};
if ~flags.has_ventricular_volume_function_targets
    rows = add_reason(rows, 'LV/RV volumes and EF', ...
        'missing_preclosure_volume_function_data', ...
        'Do not fit ventricular E/V0 without LVEDV, LVESV, RVEDV, RVESV, LVEF, or RVEF targets.');
end
if ~flags.has_rap
    rows = add_reason(rows, 'RAP_mean', 'missing_clinical_RAP', ...
        'Report RAP_mean as model prediction only.');
end
if ~flags.has_pvr
    rows = add_reason(rows, 'PVR', 'missing_clinical_PVR', ...
        'Report PVR as model prediction only.');
end
if ~flags.has_svr
    rows = add_reason(rows, 'SVR', 'missing_clinical_SVR', ...
        'Report SVR as model prediction only.');
end
if ~flags.has_direct_qasd
    rows = add_reason(rows, 'Q_ASD_Lmin', 'no_direct_shunt_flow', ...
        'Use Qp-Qs as derived comparison only; do not fit as direct Q_ASD.');
end
tbl = cell2table(rows, 'VariableNames', {'Target','Reason_Code','Explanation'});
end

function rows = add_reason(rows, target, reason_code, explanation)
% ADD_REASON - append exclusion row.
rows(end + 1, :) = {string(target), string(reason_code), string(explanation)};
end

function tbl = build_prediction_only_outputs(flags)
% BUILD_PREDICTION_ONLY_OUTPUTS - outputs kept for reporting/discussion.
rows = {
    "RAP_mean", ~flags.has_rap, "Clinical RAP missing; use as model prediction."
    "SVR", ~flags.has_svr, "Clinical SVR missing; use as model prediction."
    "PVR", ~flags.has_pvr, "Clinical PVR missing; use as model prediction."
    "LVEDV/LVESV/LVEF", ~flags.has_lv_volumes && ~flags.has_lv_function, "LV volume/function targets missing."
    "RVEDV/RVESV/RVEF", ~flags.has_rv_volumes && ~flags.has_rv_function, "RV volume/function targets missing."
    };
tbl = cell2table(rows, 'VariableNames', {'Output','Prediction_Only','Reason'});
end

function tbl = build_notes(patient_label, flags, phase_label, params0)
% BUILD_NOTES - compact methodological notes for workbook/docs.
asd_mode = 'not_available';
if isstruct(params0) && isfield(params0, 'asd') && isfield(params0.asd, 'mode')
    asd_mode = params0.asd.mode;
end
rows = {
    "Patient label", string(patient_label)
    "Scenario phase", string(phase_label)
    "Case classification", string(classify_mode(flags, phase_label))
    "ASD mode in params0", string(asd_mode)
    "Direct Q_ASD", ternary_text(flags.has_direct_qasd, "available", "missing; use Qp-Qs only as derived comparison")
    "ASD gradient", ternary_text(flags.has_asd_gradient, "available", "missing; cannot compute R_ASD from DeltaP/Q")
    "Volume/function targets", ternary_text(flags.has_ventricular_volume_function_targets, "available", "missing; Group C monitor-only by default")
    };
tbl = cell2table(rows, 'VariableNames', {'Topic','Note'});
end

function text = ternary_text(tf, yes_text, no_text)
% TERNARY_TEXT - readable conditional text.
if tf
    text = string(yes_text);
else
    text = string(no_text);
end
end
