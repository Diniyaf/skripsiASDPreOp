function target_tiers = build_asd_target_tiers(clinical, scenario, caseProfile)
% BUILD_ASD_TARGET_TIERS
% -----------------------------------------------------------------------
% Build patient-generic ASD target-tier governance from a case profile.
%
% The table includes the 26-output ASD reporting panel plus Qp_Lmin, which
% is a primary calibration target even when the printed table reports Qs as
% cardiac output.
%
% INPUTS:
%   clinical     - ASD clinical profile                                  [-]
%   scenario     - scenario string, default pre_surgery                  [-]
%   caseProfile  - optional struct from build_asd_case_calibration_profile[-]
%
% OUTPUTS:
%   target_tiers - table with target tier and inclusion metadata          [-]
%
% ASSUMPTIONS:
%   - Missing values are never silently promoted to calibration targets.
%   - Q_ASD_Lmin from Qp-Qs is a derived comparison unless direct shunt
%     flow is reported.
%
% REFERENCES:
%   [1] src/calibration/build_asd_case_calibration_profile.m
%   [2] C:/Users/Diniya/unified-vsd-temp/src/calibration/build_target_tiers.m
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  2.0
% -----------------------------------------------------------------------

if nargin < 2 || isempty(scenario)
    scenario = 'pre_surgery';
end
if nargin < 1 || isempty(clinical)
    error('build_asd_target_tiers:missingClinical', ...
        'A clinical struct is required.');
end
if nargin < 3 || isempty(caseProfile) || ~is_asd_case_profile(caseProfile)
    caseProfile = build_asd_case_calibration_profile(clinical, scenario, struct());
end

src = clinical.(char(caseProfile.scenario_key));
patient_label = char(caseProfile.patient_label);
source_prefix = sprintf('%s %s', patient_label, char(caseProfile.scenario_phase));

rows = {};
rows = add_row(rows, 'HR', 'HR', 'common.HR', ...
    'clinical_input_not_calibrated', false, false, read_common(clinical, 'HR'), 'bpm', ...
    source_prefix, 'Heart rate is an input/override, not a calibrated target.', ...
    'Report for consistency only.');

rows = add_row(rows, 'CO_Lmin / Qs_Lmin', 'Qs_Lmin', 'Qs_Lmin', ...
    tier_if_available(src, {'Qs_Lmin','CO_Lmin'}, 'hard_primary', 'prediction_only'), ...
    has_any(src, {'Qs_Lmin','CO_Lmin'}), has_any(src, {'Qs_Lmin','CO_Lmin'}), ...
    first_numeric(src, {'Qs_Lmin','CO_Lmin'}), 'L/min', source_prefix, ...
    'Systemic-flow target when Qs or CO is reported.', ...
    'Printed as CO_Lmin in asd_output_table; internally used as Qs_Lmin.');

rows = add_row(rows, 'Qp_Lmin', 'Qp_Lmin', 'Qp_Lmin', ...
    tier_if_available(src, {'Qp_Lmin'}, 'hard_primary', 'prediction_only'), ...
    has_any(src, {'Qp_Lmin'}), has_any(src, {'Qp_Lmin'}), ...
    first_numeric(src, {'Qp_Lmin'}), 'L/min', source_prefix, ...
    'Pulmonary-flow target when reported.', 'Use L/min consistently.');

rows = add_prediction(rows, 'LV_SV_mL', 'LVSV', 'missing', 'mL', ...
    'LV stroke volume is model-derived unless LV volume data are available.');
rows = add_prediction(rows, 'RV_SV_mL', 'RVSV', 'missing', 'mL', ...
    'RV stroke volume is model-derived unless RV volume data are available.');

rows = add_volume_function(rows, src, 'LVEF', 'LVEF', {'LVEF','EF'}, '-', source_prefix);
rows = add_volume_function(rows, src, 'RVEF', 'RVEF', {'RVEF'}, '-', source_prefix);
rows = add_volume_function(rows, src, 'LVEDV_mL', 'LVEDV', {'LVEDV_mL'}, 'mL', source_prefix);
rows = add_volume_function(rows, src, 'LVESV_mL', 'LVESV', {'LVESV_mL'}, 'mL', source_prefix);
rows = add_volume_function(rows, src, 'RVEDV_mL', 'RVEDV', {'RVEDV_mL'}, 'mL', source_prefix);
rows = add_volume_function(rows, src, 'RVESV_mL', 'RVESV', {'RVESV_mL'}, 'mL', source_prefix);

rows = add_prediction_or_available(rows, src, 'SVR_WU', 'SVR', {'SVR_WU'}, 'WU', ...
    source_prefix, 'SVR is used only when directly available.');
rows = add_prediction_or_available(rows, src, 'PVR_WU', 'PVR', {'PVR_WU'}, 'WU', ...
    source_prefix, 'PVR is used only when directly available.');
rows = add_prediction(rows, 'RVP_mean_mmHg', 'RVP_mean', 'missing', 'mmHg', ...
    'Mean RV pressure is not a direct target in the current ASD profile.');

rows = add_pressure_guard(rows, src, 'SBP_mmHg', 'SAP_max', 'SAP_sys_mmHg', ...
    'soft_secondary_guard', 'mmHg', selected_systemic_source(src), ...
    'Systemic systolic pressure guard.');
rows = add_pressure_guard(rows, src, 'DBP_mmHg', 'SAP_min', 'SAP_dia_mmHg', ...
    'soft_secondary_guard', 'mmHg', selected_systemic_source(src), ...
    'Systemic diastolic pressure guard.');
rows = add_pressure_guard(rows, src, 'MAP_mmHg', 'SAP_mean', 'SAP_mean_mmHg', ...
    'hard_primary', 'mmHg', selected_systemic_source(src), ...
    'Mean systemic pressure target.');
rows = add_pressure_guard(rows, src, 'PAP_sys_mmHg', 'PAP_max', 'PAP_sys_mmHg', ...
    'soft_secondary_guard', 'mmHg', source_prefix, ...
    'Pulmonary systolic pressure guard.');
rows = add_pressure_guard(rows, src, 'PAP_dia_mmHg', 'PAP_min', 'PAP_dia_mmHg', ...
    'soft_secondary_guard', 'mmHg', source_prefix, ...
    'Pulmonary diastolic pressure guard.');
rows = add_pressure_guard(rows, src, 'PAP_mean_mmHg', 'PAP_mean', 'PAP_mean_mmHg', ...
    'hard_primary', 'mmHg', source_prefix, ...
    'Mean pulmonary pressure target.');
rows = add_pressure_guard(rows, src, 'LAP_mean_mmHg', 'LAP_mean', 'LAP_mean_mmHg', ...
    'hard_primary', 'mmHg', source_prefix, ...
    'Left atrial filling-pressure target.');
rows = add_prediction_or_available(rows, src, 'RAP_mean_mmHg', 'RAP_mean', ...
    {'RAP_mean_mmHg'}, 'mmHg', source_prefix, ...
    'RAP is prediction-only when missing.');

rows = add_row(rows, 'DeltaP_LA_RA_mmHg', 'DeltaP_LA_RA', 'ASD_gradient_mmHg', ...
    'derived_prediction_only', false, false, first_numeric(src, {'ASD_gradient_mmHg'}), ...
    'mmHg', source_prefix, 'Atrial pressure gradient is a mechanism output.', ...
    'Use for mechanism discussion unless a direct gradient is available and selected.');

rows = add_row(rows, 'QpQs', 'QpQs', 'QpQs', ...
    tier_if_available(src, {'QpQs'}, 'hard_primary', 'prediction_only'), ...
    has_any(src, {'QpQs'}), has_any(src, {'QpQs'}), first_numeric(src, {'QpQs'}), ...
    '-', source_prefix, 'Primary ASD shunt-severity metric.', ...
    'Qp/Qs is a target, not a parameter.');

q_asd_lmin = derived_qasd(src);
direct_qasd = first_numeric(src, {'Q_shunt_Lmin'});
has_direct_qasd = isfinite(direct_qasd);
q_asd_target = direct_qasd;
q_asd_source = 'direct Q_shunt_Lmin';
q_asd_tier = 'soft_secondary_direct_shunt';
include_qasd_cal = true;
if ~has_direct_qasd
    q_asd_target = q_asd_lmin;
    q_asd_source = 'derived from Qp_Lmin - Qs_Lmin';
    q_asd_tier = 'soft_secondary_derived_comparison';
    include_qasd_cal = false;
end
rows = add_row(rows, 'Q_ASD_mean_mLs', 'Q_ASD_mean_mLs', q_asd_source, ...
    'derived_prediction_only', false, false, q_asd_target * 1000 / 60, ...
    'mL/s', q_asd_source, 'ODE-unit ASD shunt flow.', ...
    'Report for unit transparency; avoid direct fitting unless directly measured.');
rows = add_row(rows, 'Q_ASD_Lmin', 'Q_ASD_Lmin', q_asd_source, ...
    q_asd_tier, true, include_qasd_cal, q_asd_target, 'L/min', q_asd_source, ...
    'ASD shunt-flow comparison.', ...
    'Derived Qp-Qs should not be treated as independent direct shunt flow.');
rows = add_row(rows, 'ASD_direction', 'ASD_direction', 'qualitative_expected_L_to_R', ...
    'qualitative_validity_guard', false, false, NaN, '-', source_prefix, ...
    'Expected pre-closure left-to-right ASD direction when supported by case profile.', ...
    'Qualitative validity guard, not numeric calibration target.');

target_tiers = cell2table(rows, 'VariableNames', ...
    {'Metric','ModelField','ClinicalField','Tier','IncludeInGSA', ...
    'IncludeInCalibrationLater','ClinicalTarget','Unit','Source', ...
    'Reason','Notes'});

target_tiers.IncludeInGSA = target_tiers.IncludeInGSA & ...
    (isfinite(target_tiers.ClinicalTarget) | contains(target_tiers.Tier, 'qualitative'));
target_tiers.IncludeInCalibrationLater = target_tiers.IncludeInCalibrationLater & ...
    isfinite(target_tiers.ClinicalTarget);

end

function tf = is_asd_case_profile(s)
% IS_ASD_CASE_PROFILE - identify profile structs without relying on class.
tf = isstruct(s) && isfield(s, 'is_asd_case_profile') && isequal(s.is_asd_case_profile, true);
end

function rows = add_prediction(rows, metric, model_field, clinical_field, unit, notes)
% ADD_PREDICTION - append model-prediction-only row.
rows = add_row(rows, metric, model_field, clinical_field, 'prediction_only_discussion', ...
    false, false, NaN, unit, 'not reported', 'Model prediction output.', notes);
end

function rows = add_prediction_or_available(rows, src, metric, model_field, fields, unit, source, notes)
% ADD_PREDICTION_OR_AVAILABLE - target only when a direct clinical value exists.
available = has_any(src, fields);
if available
    tier = 'validation_available_not_primary';
else
    tier = 'prediction_only';
end
rows = add_row(rows, metric, model_field, strjoin(fields, '|'), tier, false, false, ...
    first_numeric(src, fields), unit, source, ...
    'Not part of primary ASD pressure-flow calibration.', notes);
end

function rows = add_volume_function(rows, src, metric, model_field, fields, unit, source)
% ADD_VOLUME_FUNCTION - keep volume/EF out unless case profile supports it later.
available = has_any(src, fields);
if available
    tier = 'validation_available_volume_function';
    reason = 'Clinical volume/function value is available but not in Zoya primary pressure-flow tier.';
else
    tier = 'excluded_missing_volume_function';
    reason = 'Clinical volume/function target is missing.';
end
rows = add_row(rows, metric, model_field, strjoin(fields, '|'), tier, false, false, ...
    first_numeric(src, fields), unit, source, reason, ...
    'Do not fit ventricular chamber parameters unless caseProfile allows this target class.');
end

function rows = add_pressure_guard(rows, src, metric, model_field, field_name, tier, unit, source, reason)
% ADD_PRESSURE_GUARD - append pressure target/guard row when available.
available = has_any(src, {field_name});
rows = add_row(rows, metric, model_field, field_name, ...
    tier_if_available(src, {field_name}, tier, 'prediction_only'), ...
    available, available && (strcmp(tier, 'hard_primary') || strcmp(tier, 'soft_secondary_guard')), ...
    first_numeric(src, {field_name}), unit, source, reason, ...
    'Missing values remain excluded.');
end

function rows = add_row(rows, metric, model_field, clinical_field, tier, ...
    include_gsa, include_calibration, target, unit, source, reason, notes)
% ADD_ROW - append one target governance row.
rows(end + 1, :) = {string(metric), string(model_field), string(clinical_field), ...
    string(tier), logical(include_gsa), logical(include_calibration), target, ...
    string(unit), string(source), string(reason), string(notes)};
end

function tier = tier_if_available(src, fields, available_tier, missing_tier)
% TIER_IF_AVAILABLE - choose target tier from data availability.
if has_any(src, fields)
    tier = available_tier;
else
    tier = missing_tier;
end
end

function tf = has_any(src, fields)
% HAS_ANY - true if any field has finite numeric content.
tf = false;
for i = 1:numel(fields)
    if isfield(src, fields{i}) && isnumeric(src.(fields{i})) && any(isfinite(src.(fields{i})(:)))
        tf = true;
        return;
    end
end
end

function value = first_numeric(src, fields)
% FIRST_NUMERIC - first finite scalar/vector numeric value.
value = NaN;
for i = 1:numel(fields)
    if isfield(src, fields{i}) && isnumeric(src.(fields{i})) && any(isfinite(src.(fields{i})(:)))
        data = src.(fields{i});
        value = data(find(isfinite(data), 1, 'first'));
        return;
    end
end
end

function value = read_common(clinical, field_name)
% READ_COMMON - read scalar numeric common clinical field or return NaN.
value = NaN;
if isstruct(clinical) && isfield(clinical, 'common') && ...
        isfield(clinical.common, field_name) && isnumeric(clinical.common.(field_name)) && ...
        isscalar(clinical.common.(field_name)) && isfinite(clinical.common.(field_name))
    value = clinical.common.(field_name);
end
end

function value = derived_qasd(src)
% DERIVED_QASD - derive Q_ASD comparison from Qp-Qs [L/min].
value = NaN;
if has_any(src, {'Qp_Lmin'}) && (has_any(src, {'Qs_Lmin'}) || has_any(src, {'CO_Lmin'}))
    value = first_numeric(src, {'Qp_Lmin'}) - first_numeric(src, {'Qs_Lmin','CO_Lmin'});
end
end

function source = selected_systemic_source(src)
% SELECTED_SYSTEMIC_SOURCE - text label for selected systemic pressure.
if isfield(src, 'SAP_pressure_source') && ~isempty(src.SAP_pressure_source)
    source = char(string(src.SAP_pressure_source));
else
    source = 'investigator-selected systemic pressure';
end
end
