function params = params_from_clinical(params, clinical, scenario, reference_params, case_profile)
% PARAMS_FROM_CLINICAL
% -----------------------------------------------------------------------
% Maps scenario-specific clinical data into ASD model parameters and
% rebuilds the initial-condition vector. Vascular V0 (especially V0.SVEN)
% is reconciled for blood-volume/preload consistency without mutating
% chamber V0.
%
% ASSUMPTIONS:
%   - ASD pre_surgery and pre_closure are treated as the same phase.
%   - Qp/Qs is stored as a clinical target, not forced as a parameter.
%   - R_ASD is seeded from DeltaP/Q only when both are directly available.
%   - Missing Patient Zoya PVR/SVR/volumes do not trigger inferred tuning.
%
% SIGN CONVENTIONS:
%   - Positive Q_ASD means left-to-right atrial shunt: LA -> RA.
%
% AUTHOR:   Unified ASD Model
% DATE:     2026-05-29
% VERSION:  3.0
% -----------------------------------------------------------------------

R_VSD_CLOSED = 1e6;
common = clinical.common;
k = params.conv.WU_to_R;
Lmin_to_mLs = params.conv.Lmin_to_mLs;

[src, scenario_key, phase_label] = select_scenario_source(clinical, scenario);

if nargin < 4 || isempty(reference_params)
    reference_params = params;
end
if nargin < 5
    case_profile = struct();
end

if ~isfield(params, 'clinical_override') || ~isstruct(params.clinical_override)
    params.clinical_override = struct();
end
params.clinical_override.model_family = 'ASD';
params.clinical_override.scenario_requested = char(scenario);
params.clinical_override.scenario_source_field = scenario_key;
params.clinical_override.scenario_phase = phase_label;

scaled_HR_bpm = params.HR; % [bpm]
[HR_bpm, HR_source] = resolve_hr_override(common, src, scaled_HR_bpm);
if isfinite(HR_bpm)
    params.HR = HR_bpm; % [bpm]
    params = recompute_timing(params);
end
params.clinical_override.HR_scaled_bpm = scaled_HR_bpm; % [bpm]
params.clinical_override.HR_final_bpm = params.HR;      % [bpm]
params.clinical_override.HR_source = HR_source;

rv_edv_consistency_only = is_metric_consistency_only(case_profile, 'RVEDV');
if rv_edv_consistency_only
    params.clinical_override.RVEDV_consistency_only = true;
    params.clinical_override.RVEDV_observed_mL = field_or_nan(src, 'RVEDV_mL');
    params.clinical_override.RVEDV_flow_consistent_seed_mL = ...
        flow_consistent_rvedv_seed(src, params.HR);
else
    params.clinical_override.RVEDV_consistency_only = false;
end

if isfield(src, 'SVR_WU') && ~isnan(src.SVR_WU)
    [SVR_target_WU, SVR_diag] = select_resistance_target(src, 'SVR');
    SVR_mech = SVR_target_WU * k;
    SVR_ref = params.R.SAR + params.R.SC + params.R.SVEN;
    ratio = SVR_mech / max(SVR_ref, 1e-6);
    params.R.SAR = params.R.SAR * ratio;
    params.R.SC = params.R.SC * ratio;
    params.R.SVEN = params.R.SVEN * ratio;
    params.clinical_override.SVR_seed_WU = SVR_target_WU;
    params.clinical_override.SVR_target_diag = SVR_diag;
    params.clinical_override.SVR_seed_status = 'seeded_from_available_clinical_SVR';
else
    params.clinical_override.SVR_seed_status = ...
        'missing_keep_pediatric_scaled_resistance';
end

if isfield(src, 'PVR_WU') && ~isnan(src.PVR_WU)
    [PVR_target_WU, PVR_diag] = select_resistance_target(src, 'PVR');
    PVR_mech = PVR_target_WU * k;
    R_cap_ref = 1 / max(1 / params.R.PCOX + 1 / params.R.PCNO, 1e-9);
    PVR_ref = params.R.PAR + R_cap_ref + params.R.PVEN;
    ratio = PVR_mech / max(PVR_ref, 1e-6);
    params.R.PAR = params.R.PAR * ratio;
    params.R.PCOX = params.R.PCOX * ratio;
    params.R.PCNO = params.R.PCNO * ratio;
    params.R.PVEN = params.R.PVEN * ratio;
    params.clinical_override.PVR_seed_WU = PVR_target_WU;
    params.clinical_override.PVR_target_diag = PVR_diag;
    params.clinical_override.PVR_seed_status = 'seeded_from_available_clinical_PVR';
else
    params.clinical_override.PVR_seed_status = ...
        'missing_keep_pediatric_scaled_resistance';
end

pre_C_SAR = params.C.SAR; % [mL/mmHg]
pre_C_PAR = params.C.PAR; % [mL/mmHg]
params = seed_arterial_compliance_from_clinical(params, src, phase_label, case_profile);
if ~isfield(params.clinical_override, 'C_SAR_seed_source')
    params.clinical_override.C_SAR_seed_status = ...
        'skipped_missing_systemic_SV_or_pulse_pressure';
else
    params.clinical_override.C_SAR_before_seed_mL_per_mmHg = pre_C_SAR;
    params.clinical_override.C_SAR_seed_status = 'seeded_from_SV_over_systemic_pulse_pressure';
end
if ~isfield(params.clinical_override, 'C_PAR_seed_source')
    params.clinical_override.C_PAR_seed_status = ...
        'skipped_missing_pulmonary_SV_or_pulse_pressure';
else
    params.clinical_override.C_PAR_before_seed_mL_per_mmHg = pre_C_PAR;
    params.clinical_override.C_PAR_seed_status = 'seeded_from_SV_over_pulmonary_pulse_pressure';
end

params = close_legacy_vsd(params, R_VSD_CLOSED);
params = configure_asd(params, src, phase_label, Lmin_to_mLs);

if isfield(src, 'override_IC') && isequal(src.override_IC, true)
    params = apply_chamber_tuning_from_clinical(params, src, case_profile);
else
    params.clinical_override.chamber_tuning = ...
        'disabled_override_false_or_missing_patient_z_volumes';
end

params = enforce_vascular_rc_coupling(params, reference_params, case_profile);
patient = params.scaling.patient;
params = reconcile_vascular_v0(params, patient, clinical, scenario_key);
params.ic.V = build_initial_conditions(params, patient, clinical, scenario_key);

end

function [src, scenario_key, phase_label] = select_scenario_source(clinical, scenario)
% SELECT_SCENARIO_SOURCE - resolve ASD scenario aliases to clinical fields.
scenario_text = lower(strtrim(char(scenario)));
switch scenario_text
    case {'pre_surgery', 'pre_closure'}
        phase_label = 'pre_closure';
        candidates = {'pre_closure', 'pre_surgery'};
    case {'post_surgery', 'post_closure'}
        phase_label = 'post_closure';
        candidates = {'post_closure', 'post_surgery'};
    otherwise
        error('params_from_clinical:unknownScenario', ...
            ['scenario must be ''pre_surgery'', ''pre_closure'', ', ...
            '''post_surgery'', or ''post_closure''.']);
end

for idx = 1:numel(candidates)
    candidate = candidates{idx};
    if isfield(clinical, candidate)
        src = clinical.(candidate);
        scenario_key = candidate;
        return;
    end
end

error('params_from_clinical:missingScenarioData', ...
    'Clinical struct has no data for %s.', phase_label);
end

function [HR_bpm, HR_source] = resolve_hr_override(common, src, scaled_HR_bpm)
% RESOLVE_HR_OVERRIDE - prefer scenario HR, then common HR, then scaled HR.
HR_bpm = scaled_HR_bpm;
HR_source = 'scaled_baseline';
if isfield(common, 'HR') && isnumeric(common.HR) && isscalar(common.HR) && ...
        isfinite(common.HR)
    HR_bpm = common.HR;
    HR_source = 'clinical_common_HR';
end
if isfield(src, 'HR') && isnumeric(src.HR) && isscalar(src.HR) && ...
        isfinite(src.HR)
    HR_bpm = src.HR;
    HR_source = 'clinical_scenario_HR';
end
end

function params = seed_arterial_compliance_from_clinical(params, src, scenario, case_profile)
% SEED_ARTERIAL_COMPLIANCE_FROM_CLINICAL - anchor proximal arterial C terms to SV/PP.
%
% REFERENCES:
%   [1] Stergiopulos et al. (1994). Pulse pressure method for arterial compliance.
%   [2] Westerhof et al. (2009). The arterial Windkessel.
%   [3] Thenappan et al. (2016). Pulmonary arterial compliance review.

HR_bpm = params.HR;
if isfield(src, 'HR') && ~isnan(src.HR)
    HR_bpm = src.HR;
end
if ~isfinite(HR_bpm) || HR_bpm <= 0
    return;
end

if nargin < 4
    case_profile = struct();
end

SV_sys = resolve_systemic_stroke_volume(src, HR_bpm);
PP_sys = resolve_pulse_pressure(src, {'SAP_sys_mmHg','SAP_max'}, {'SAP_dia_mmHg','SAP_min'});
if isfinite(SV_sys) && isfinite(PP_sys) && PP_sys > 1e-6
    params.C.SAR = max(SV_sys / PP_sys, 0.05);
    params.clinical_override.C_SAR_seed_mL_per_mmHg = params.C.SAR;
    params.clinical_override.C_SAR_seed_source = 'stroke_volume_over_systemic_pulse_pressure';
end

SV_pul = resolve_pulmonary_stroke_volume(src, HR_bpm, case_profile);
PP_pul = resolve_pulse_pressure(src, {'PAP_sys_mmHg','PAP_max'}, {'PAP_dia_mmHg','PAP_min'});
if isfinite(SV_pul) && isfinite(PP_pul) && PP_pul > 1e-6
    params.C.PAR = max(SV_pul / PP_pul, 0.05);
    params.clinical_override.C_PAR_seed_mL_per_mmHg = params.C.PAR;
    params.clinical_override.C_PAR_seed_source = 'stroke_volume_over_pulmonary_pulse_pressure';
end

if strcmp(scenario, 'pre_surgery')
    params.clinical_override.arterial_compliance_seed_mode = 'pre_surgery_svpp';
else
    params.clinical_override.arterial_compliance_seed_mode = 'post_surgery_svpp';
end
end

function SV_sys = resolve_systemic_stroke_volume(src, HR_bpm)
SV_sys = NaN;
if isfield(src, 'CO_Lmin') && isfinite(src.CO_Lmin)
    SV_sys = src.CO_Lmin * 1000 / HR_bpm;
    return;
end
if isfield(src, 'Qs_Lmin') && isfinite(src.Qs_Lmin)
    SV_sys = src.Qs_Lmin * 1000 / HR_bpm;
    return;
end
if isfield(src, 'LVEDV_mL') && isfield(src, 'LVESV_mL') && ...
        all(isfinite([src.LVEDV_mL src.LVESV_mL]))
    SV_sys = src.LVEDV_mL - src.LVESV_mL;
    return;
end
end

function SV_pul = resolve_pulmonary_stroke_volume(src, HR_bpm, case_profile)
SV_pul = NaN;
if nargin < 3
    case_profile = struct();
end
if is_metric_consistency_only(case_profile, 'RVEDV') && ...
        isfield(src, 'CO_Lmin') && isfinite(src.CO_Lmin) && ...
        isfield(src, 'QpQs') && isfinite(src.QpQs)
    Qpul_Lmin = src.CO_Lmin * src.QpQs;
    SV_pul = Qpul_Lmin * 1000 / HR_bpm;
        return;
end
if isfield(src, 'Qp_Lmin') && isfinite(src.Qp_Lmin)
    SV_pul = src.Qp_Lmin * 1000 / HR_bpm;
    return;
end
if isfield(src, 'RVEDV_mL') && isfield(src, 'RVESV_mL') && ...
        all(isfinite([src.RVEDV_mL src.RVESV_mL]))
    SV_pul = src.RVEDV_mL - src.RVESV_mL;
    return;
end
if isfield(src, 'CO_Lmin') && isfinite(src.CO_Lmin) && ...
        isfield(src, 'QpQs') && isfinite(src.QpQs)
    Qpul_Lmin = src.CO_Lmin * src.QpQs;
    SV_pul = Qpul_Lmin * 1000 / HR_bpm;
end
end

function pulse_pressure = resolve_pulse_pressure(src, sys_fields, dia_fields)
sys_value = first_valid(src, sys_fields, NaN);
dia_value = first_valid(src, dia_fields, NaN);
if isfinite(sys_value) && isfinite(dia_value)
    pulse_pressure = sys_value - dia_value;
else
    pulse_pressure = NaN;
end
end

function params = configure_asd(params, src, phase_label, Lmin_to_mLs)
% CONFIGURE_ASD - seed ASD geometry/resistance without calibration.
params.asd.mode = lower(char(first_valid_text(src, 'ASD_mode', ...
    params.asd.mode)));
params.asd.diameter_mm = first_valid(src, {'ASD_diameter_mm'}, NaN);
params.asd.area_mm2 = first_valid(src, {'ASD_area_mm2'}, NaN);
params.asd.location = first_valid_text(src, 'ASD_location', '');

if ~isfinite(params.asd.area_mm2) && isfinite(params.asd.diameter_mm)
    params.asd.area_mm2 = pi * (params.asd.diameter_mm / 2)^2; % [mm^2]
    params.clinical_override.ASD_area_source = ...
        'derived_from_reported_ASD_diameter';
elseif isfinite(params.asd.area_mm2)
    params.clinical_override.ASD_area_source = ...
        first_valid_text(src, 'ASD_area_source', 'direct_reported_ASD_area');
else
    params.clinical_override.ASD_area_source = 'not_reported';
end

if isfield(src, 'QpQs') && isfinite(src.QpQs)
    params.clinical_targets.asd.QpQs = src.QpQs; % [-]
    params.clinical_override.QpQs_status = 'stored_as_target_not_forced';
else
    params.clinical_override.QpQs_status = 'not_reported';
end

switch phase_label
    case 'pre_closure'
        has_gradient = isfield(src, 'ASD_gradient_mmHg') && ...
            isfinite(src.ASD_gradient_mmHg);
        has_flow = isfield(src, 'Q_shunt_Lmin') && ...
            isfinite(src.Q_shunt_Lmin) && abs(src.Q_shunt_Lmin) > 1e-9;
        has_geometry = isfinite(params.asd.area_mm2) && params.asd.area_mm2 > 0;

        if has_gradient && has_flow
            q_shunt_mLs = abs(src.Q_shunt_Lmin) * Lmin_to_mLs; % [mL/s]
            params.R.asd = abs(src.ASD_gradient_mmHg) / max(q_shunt_mLs, 1e-9);
            params.asd.mode = 'linear_bidirectional';
            params.asd.mapping_status = ...
                'clinical_R_ASD_from_reported_gradient_and_direct_Q_ASD';
            params.clinical_override.ASD_R_seed_status = ...
                'seeded_from_ASD_gradient_over_direct_shunt_flow';
        elseif has_geometry
            params.R.asd = Inf; % [mmHg*s/mL] not used in orifice mode
            params.asd.mode = 'orifice_bidirectional';
            params.asd.mapping_status = ...
                'ASD_geometry_from_diameter_default_Cd_no_gradient_or_Q_ASD';
            params.clinical_override.ASD_R_seed_status = ...
                'not_computed_gradient_or_direct_shunt_flow_missing';
            params.clinical_override.ASD_Cd_status = ...
                'default_uncalibrated_orifice_Cd_used_with_reported_geometry';
        else
            fallback_R_asd = 0.10; % [mmHg*s/mL] diagnostic placeholder only
            params.R.asd = fallback_R_asd;
            params.asd.mode = 'linear_bidirectional';
            params.asd.area_mm2 = 0;
            params.asd.diameter_mm = NaN;
            params.asd.placeholder_R_asd_mmHg_s_per_mL = fallback_R_asd;
            params.asd.mapping_status = ...
                'finite_R_ASD_placeholder_no_geometry_gradient_or_Q_ASD';
            params.clinical_override.ASD_R_seed_status = ...
                'placeholder_not_calibrated_no_geometry_gradient_or_Q_ASD';
        end

    case 'post_closure'
        params.R.asd = Inf;
        params.asd.mode = 'linear_bidirectional';
        params.asd.area_mm2 = 0;
        params.asd.diameter_mm = 0;
        params.asd.mapping_status = 'post_closure_closed_ASD';
        params.clinical_override.ASD_R_seed_status = ...
            'closed_post_closure_R_ASD_infinite';
end

params.clinical_override.ASD_diameter_mm = params.asd.diameter_mm; % [mm]
params.clinical_override.ASD_area_mm2 = params.asd.area_mm2;       % [mm^2]
params.clinical_override.ASD_mode = params.asd.mode;
params.clinical_override.ASD_mapping_status = params.asd.mapping_status;
end

function params = close_legacy_vsd(params, R_VSD_CLOSED)
% CLOSE_LEGACY_VSD - keep deferred VSD fields inactive in ASD runs.
params.R.vsd = R_VSD_CLOSED;          % [mmHg*s/mL]
params.vsd.mode = 'linear_bidirectional';
params.vsd.area_mm2 = 0;              % [mm^2]
params.vsd.diameter_mm = 0;           % [mm]
params.clinical_override.legacy_VSD_status = ...
    'closed_and_not_used_by_active_ASD_system_rhs';
end

% RECONCILE_VASCULAR_V0 — reconcile vascular V0 with BV target [mL]
function params = reconcile_vascular_v0(params, patient, clinical, scenario)
if nargin < 3
    clinical = [];
end
if nargin < 4 || isempty(scenario)
    scenario = 'pre_surgery';
end

[src, scenario] = resolve_clinical_source(clinical, scenario);
BV_patient = resolve_total_blood_volume(patient, src);

P_nom_SAR = first_valid(src, {'SAP_mean_mmHg', 'MAP_mmHg'}, 65);
P_nom_SC = max(0.5 * P_nom_SAR, 15);
P_nom_SVEN = first_valid(src, {'RAP_mean_mmHg'}, 2);
P_nom_PAR = first_valid(src, {'PAP_mean_mmHg'}, 15);
P_nom_PVEN = first_valid(src, {'LAP_mean_mmHg', 'LVEDP_mmHg'}, 6);
P_nom_LV_ED = first_valid(src, {'LVEDP_mmHg', 'LAP_mean_mmHg'}, 8);
P_nom_RV_ED = first_valid(src, {'RVEDP_mmHg', 'RAP_mean_mmHg'}, 4);
P_nom_LA_ED = first_valid(src, {'LAP_mean_mmHg'}, 6);
P_nom_RA_ED = first_valid(src, {'RAP_mean_mmHg'}, 4);

V_RA = params.V0.RA + P_nom_RA_ED / max(params.E.RA.EB, 1e-6);
V_RV = params.V0.RV + P_nom_RV_ED / max(params.E.RV.EB, 1e-6);
V_LA = params.V0.LA + P_nom_LA_ED / max(params.E.LA.EB, 1e-6);
V_LV = params.V0.LV + P_nom_LV_ED / max(params.E.LV.EB, 1e-6);
V_SAR = params.V0.SAR + P_nom_SAR * params.C.SAR;
V_SC = params.V0.SC + P_nom_SC * params.C.SC;
V_PAR = params.V0.PAR + P_nom_PAR * params.C.PAR;
V_PVEN = params.V0.PVEN + P_nom_PVEN * params.C.PVEN;

V_other = V_RA + V_RV + V_LA + V_LV + V_SAR + V_SC + V_PAR + V_PVEN;
V0_sven_required = BV_patient - V_other - P_nom_SVEN * params.C.SVEN;

V0_sven_min = max(0.01 * BV_patient, 1.0);
V0_sven_max = 0.85 * BV_patient;
V0_sven_applied = min(max(V0_sven_required, V0_sven_min), V0_sven_max);
params.V0.SVEN = V0_sven_applied;

params.scaling.BV_patient = BV_patient;
params.scaling.V0_SVEN_required = V0_sven_required;
params.scaling.V0_SVEN_applied = V0_sven_applied;
params.scaling.V0_SVEN_bounds = [V0_sven_min V0_sven_max];
params.scaling.V0_SVEN_scenario = scenario;
params.scaling.V0_SVEN_reconciled = true;
end

function [target_WU, diag] = select_resistance_target(src, resistance_name)
doc_value = NaN;
derived_value = NaN;

switch upper(resistance_name)
    case 'SVR'
        if isfield(src, 'SVR_WU')
            doc_value = src.SVR_WU;
        end
        if isfield(src, 'SAP_mean_mmHg') && isfield(src, 'RAP_mean_mmHg') && ...
                isfield(src, 'CO_Lmin') && all(~isnan([src.SAP_mean_mmHg src.RAP_mean_mmHg src.CO_Lmin]))
            derived_value = (src.SAP_mean_mmHg - src.RAP_mean_mmHg) / max(src.CO_Lmin, 1e-6);
        end
    case 'PVR'
        if isfield(src, 'PVR_WU')
            doc_value = src.PVR_WU;
        end
        if isfield(src, 'PAP_mean_mmHg') && isfield(src, 'LAP_mean_mmHg') && ...
                isfield(src, 'CO_Lmin') && isfield(src, 'QpQs') && ...
                all(~isnan([src.PAP_mean_mmHg src.LAP_mean_mmHg src.CO_Lmin src.QpQs]))
            Qpul_Lmin = src.CO_Lmin * src.QpQs;
            derived_value = (src.PAP_mean_mmHg - src.LAP_mean_mmHg) / max(Qpul_Lmin, 1e-6);
        end
    otherwise
        error('select_resistance_target:unknownResistance', ...
            'Unknown resistance selector: %s', resistance_name);
end

target_WU = first_non_nan(doc_value, derived_value, 1.0);
source_name = 'fallback';
if ~isnan(doc_value)
    source_name = 'documented';
end
if isnan(doc_value) && ~isnan(derived_value)
    source_name = 'derived';
end

if strcmpi(resistance_name, 'SVR') && ~isnan(doc_value) && ~isnan(derived_value)
    relative_gap = abs(doc_value - derived_value) / max(abs(derived_value), 1e-6);
    if relative_gap > 0.20
        target_WU = derived_value;
        source_name = 'derived_due_to_gap';
    end
end

diag = struct();
diag.resistance_name = upper(resistance_name);
diag.documented_WU = doc_value;
diag.derived_WU = derived_value;
diag.selected_WU = target_WU;
diag.source = source_name;
end

function BV_patient = resolve_total_blood_volume(patient, src)
if isfield(src, 'BV_total_mL') && ~isnan(src.BV_total_mL)
    BV_patient = src.BV_total_mL;
else
    BV_patient = patient.weight_kg * blood_volume_per_kg(patient.age_years);
end
end

function BV_per_kg = blood_volume_per_kg(age_years)
if age_years < 1
    BV_per_kg = 82;
else
    BV_per_kg = 70;
end
end

function [src, scenario] = resolve_clinical_source(clinical, scenario)
src = struct();
if isempty(clinical) || ~isstruct(clinical)
    return;
end
if isfield(clinical, scenario)
    src = clinical.(scenario);
elseif any(strcmp(scenario, {'pre_surgery', 'pre_closure'}))
    if isfield(clinical, 'pre_closure')
        src = clinical.pre_closure;
        scenario = 'pre_closure';
    elseif isfield(clinical, 'pre_surgery')
        src = clinical.pre_surgery;
        scenario = 'pre_surgery';
    end
elseif any(strcmp(scenario, {'post_surgery', 'post_closure'}))
    if isfield(clinical, 'post_closure')
        src = clinical.post_closure;
        scenario = 'post_closure';
    elseif isfield(clinical, 'post_surgery')
        src = clinical.post_surgery;
        scenario = 'post_surgery';
    end
end
end

function params = apply_chamber_tuning_from_clinical(params, src, case_profile)
if nargin < 3
    case_profile = struct();
end
P_lv_ed = first_valid(src, {'LVEDP_mmHg', 'LAP_mean_mmHg'}, 8);
P_lv_es = first_valid(src, {'SAP_sys_mmHg', 'SAP_mean_mmHg', 'MAP_mmHg'}, 80);
P_rv_ed = first_valid(src, {'RVEDP_mmHg', 'RAP_mean_mmHg'}, 5);
P_rv_es = first_valid(src, {'PAP_sys_mmHg', 'PAP_mean_mmHg'}, 25);

f_min_LV = 0.03;
f_min_RV = 0.04;
LAP_fill = first_valid(src, {'LAP_mean_mmHg', 'LVEDP_mmHg'}, P_lv_ed);
RAP_fill = first_valid(src, {'RAP_mean_mmHg', 'RVEDP_mmHg'}, P_rv_ed);

A_LV = LAP_fill / max(f_min_LV * P_lv_es, 1e-6);
A_RV = RAP_fill / max(f_min_RV * P_rv_es, 1e-6);

if all_finite_fields(src, {'LVEDV_mL','LVESV_mL'})
    denom_LV = 1 - A_LV;
    V0_cand_LV = (src.LVEDV_mL - A_LV * src.LVESV_mL) / denom_LV;
    if isfinite(V0_cand_LV) && V0_cand_LV > 0 && V0_cand_LV < src.LVESV_mL
        params.V0.LV = max(V0_cand_LV, 0.5);
    end
    Emax_LV = P_lv_es / max(src.LVESV_mL - params.V0.LV, 0.1);
    params.E.LV.EB = max(f_min_LV * Emax_LV, 0.01);
    params.E.LV.EA = max(Emax_LV - params.E.LV.EB, 0.1);
    params.clinical_override.LV_tuning_source = 'echo_lvedv_lvesv';
end

rv_edv_for_tuning = field_or_nan(src, 'RVEDV_mL');
rv_tuning_source = 'echo_rvedv_rvesv';
if is_metric_consistency_only(case_profile, 'RVEDV')
    flow_seed = flow_consistent_rvedv_seed(src, params.HR);
    if isfinite(flow_seed)
        rv_edv_for_tuning = flow_seed;
        rv_tuning_source = 'flow_consistent_qp_plus_rvesv';
    else
        rv_edv_for_tuning = NaN;
    end
end

if isfinite(rv_edv_for_tuning) && all_finite_fields(src, {'RVESV_mL'}) && ...
        rv_edv_for_tuning > src.RVESV_mL
    denom_RV = 1 - A_RV;
    V0_cand_RV = (rv_edv_for_tuning - A_RV * src.RVESV_mL) / denom_RV;
    if isfinite(V0_cand_RV) && V0_cand_RV > 0 && V0_cand_RV < src.RVESV_mL
        params.V0.RV = max(V0_cand_RV, 0.5);
    end
    Emax_RV = P_rv_es / max(src.RVESV_mL - params.V0.RV, 0.1);
    params.E.RV.EB = max(f_min_RV * Emax_RV, 0.01);
    params.E.RV.EA = max(Emax_RV - params.E.RV.EB, 0.1);
    params.clinical_override.RV_tuning_source = rv_tuning_source;
end

params.clinical_override.chamber_tuning = 'tier_aware_volume_elastance';

SV_sys = resolve_systemic_stroke_volume(src, params.HR);
PP_sys = resolve_pulse_pressure(src, {'SAP_sys_mmHg'}, {'SAP_dia_mmHg'});
if isfinite(SV_sys) && isfinite(PP_sys) && PP_sys > 1e-6
    params.C.SAR = max(SV_sys / PP_sys, 0.05);
end

SV_pul = resolve_pulmonary_stroke_volume(src, params.HR, case_profile);
PP_pul = resolve_pulse_pressure(src, {'PAP_sys_mmHg'}, {'PAP_dia_mmHg'});
if isfinite(SV_pul) && isfinite(PP_pul) && PP_pul > 1e-6
    params.C.PAR = max(SV_pul / PP_pul, 0.05);
end
end

function params = recompute_timing(params)
T_HB = 60 / params.HR;
params.Tc_LV   = params.Tc_LV_frac   * T_HB;
params.Tr_LV   = params.Tr_LV_frac   * T_HB;
params.Tc_RV   = params.Tc_RV_frac   * T_HB;
params.Tr_RV   = params.Tr_RV_frac   * T_HB;
params.t_ac_LA = params.t_ac_LA_frac * T_HB;
params.Tc_LA   = params.Tc_LA_frac   * T_HB;
params.t_ar_LA = params.t_ac_LA + params.Tc_LA;
params.Tr_LA   = params.Tr_LA_frac   * T_HB;
params.t_ac_RA = params.t_ac_RA_frac * T_HB;
params.Tc_RA   = params.Tc_RA_frac   * T_HB;
params.t_ar_RA = params.t_ac_RA + params.Tc_RA;
params.Tr_RA   = params.Tr_RA_frac   * T_HB;
end

function tf = is_metric_consistency_only(case_profile, metric_name)
tf = false;
if ~isstruct(case_profile) || ~isfield(case_profile, 'targetTiers') || ...
        ~isstruct(case_profile.targetTiers) || ...
        ~isfield(case_profile.targetTiers, 'consistency_only')
    return;
end
tf = ismember(metric_name, case_profile.targetTiers.consistency_only(:)');
end

function seed_mL = flow_consistent_rvedv_seed(src, HR_bpm)
seed_mL = NaN;
if ~isfinite(HR_bpm) || HR_bpm <= 0 || ...
        ~isfield(src, 'CO_Lmin') || ~isfinite(src.CO_Lmin) || ...
        ~isfield(src, 'QpQs') || ~isfinite(src.QpQs) || ...
        ~isfield(src, 'RVESV_mL') || ~isfinite(src.RVESV_mL)
    return;
end
SV_Qp_mL = src.CO_Lmin * src.QpQs * 1000 / HR_bpm;
seed_mL = src.RVESV_mL + SV_Qp_mL;
end

function tf = all_finite_fields(src, field_names)
tf = true;
for idx = 1:numel(field_names)
    fn = field_names{idx};
    if ~isfield(src, fn) || ~isnumeric(src.(fn)) || ~isscalar(src.(fn)) || ...
            ~isfinite(src.(fn))
        tf = false;
        return;
    end
end
end

function value = field_or_nan(s, field_name)
if isstruct(s) && isfield(s, field_name) && isnumeric(s.(field_name)) && ...
        isscalar(s.(field_name)) && isfinite(s.(field_name))
    value = s.(field_name);
else
    value = NaN;
end
end

function value = first_valid(src, field_names, fallback)
value = fallback;
for k = 1:numel(field_names)
    fn = field_names{k};
    if isfield(src, fn) && isnumeric(src.(fn)) && isscalar(src.(fn)) && ...
            isfinite(src.(fn))
        value = src.(fn);
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

function value = first_non_nan(varargin)
value = NaN;
for k = 1:nargin
    candidate = varargin{k};
    if ~isnan(candidate)
        value = candidate;
        return;
    end
end
end
