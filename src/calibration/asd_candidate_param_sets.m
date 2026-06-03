function report = asd_candidate_param_sets(params0_ASD_pre, clinical_or_profile, scenario)
% ASD_CANDIDATE_PARAM_SETS
% -----------------------------------------------------------------------
% Defines ASD-specific candidate calibration parameter sets without
% running GSA, optimisation, or modifying the model.
%
% INPUTS:
%   params0_ASD_pre - ASD pre-closure seeded parameters                 [-]
%   clinical_or_profile - clinical struct or ASD caseProfile            [-]
%   scenario        - scenario string, default 'pre_surgery'            [-]
%
% OUTPUTS:
%   report          - struct of candidate tables and documentation      [-]
%
% ASSUMPTIONS:
%   - ASD shunt candidates are mode-aware: orifice mode uses params.asd.Cd,
%     while linear mode uses params.R.asd.
%   - Candidate parameters are proposed for future GSA only; they are not
%     tuned or applied by this function.
%
% SIGN CONVENTIONS:
%   - Q_ASD > 0 means left-to-right atrial shunt: LA -> RA.
%
% REFERENCES:
%   [1] src/models/asd_shunt_model.m - ASD orifice flow law.
%   [2] src/calibration/calibration_param_sets.m - VSD staged pattern.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-29
% VERSION:  1.0
% -----------------------------------------------------------------------

if nargin < 3 || isempty(scenario)
    scenario = 'pre_surgery';
end
if nargin < 2 || isempty(clinical_or_profile)
    clinical_or_profile = struct();
end

[clinical, case_profile, scenario] = resolve_case_inputs( ...
    clinical_or_profile, scenario, params0_ASD_pre);

[group_a, excluded, warnings] = group_a_primary(params0_ASD_pre, case_profile);
[group_b, excluded, warnings] = group_b_secondary(params0_ASD_pre, excluded, warnings, case_profile);
[group_c, excluded, warnings] = group_c_fixed(params0_ASD_pre, excluded, warnings, case_profile);

excluded = append_manual_exclusions(excluded, params0_ASD_pre);
warnings = append_method_warnings(warnings, params0_ASD_pre, clinical, scenario, case_profile);

report = struct();
report.caseProfile = case_profile;
report.summary = build_summary(params0_ASD_pre, scenario, case_profile);
report.groupA = group_a;
report.groupB = group_b;
report.groupC = group_c;
report.boundsRationale = build_bounds_rationale();
report.futureGSATargets = build_future_gsa_targets(clinical, scenario, case_profile);
report.excludedParameters = excluded;
report.warnings = warnings;
report.notes = build_notes(params0_ASD_pre);
end

function [clinical, case_profile, scenario] = resolve_case_inputs(input, scenario, params)
% RESOLVE_CASE_INPUTS - keep old clinical signature and new caseProfile signature.
if isstruct(input) && isfield(input, 'is_asd_case_profile') && isequal(input.is_asd_case_profile, true)
    case_profile = input;
    clinical = case_profile.clinical;
    scenario = char(case_profile.scenario_key);
else
    clinical = input;
    case_profile = build_asd_case_calibration_profile(clinical, scenario, params);
end
end

function [tbl, excluded, warnings] = group_a_primary(params, case_profile)
% GROUP_A_PRIMARY - vascular and shunt candidates with direct target support.
rows = {};
excluded = empty_excluded();
warnings = empty_warnings();
case_label = char(case_profile.patient_label);
% Shunt parameter: mode-aware (orifice → asd.Cd, linear → R.asd)
shunt_mode = lower(char(params.asd.mode));
if strcmp(shunt_mode, 'orifice_bidirectional')
    rows = add_candidate(rows, params, 'asd.Cd', 'A_Primary_Vascular_Shunt', ...
        'primary_candidate', 'physical_Cd', 'Q_ASD; Qp; Qs; Qp/Qs; LAP/RAP relation', ...
        'ASD diameter available; orifice mode active.', ...
        'In orifice mode, discharge coefficient is the active shunt knob.', ...
        'Use as shunt candidate for GSA.');
elseif any(strcmp(shunt_mode, {'linear_bidirectional', 'linear_left_to_right_only'}))
    rows = add_candidate(rows, params, 'R.asd', 'A_Primary_Vascular_Shunt', ...
        'primary_candidate', 'resistances_kung2013', 'Q_ASD; Qp; Qs; Qp/Qs; LAP/RAP relation', ...
        'ASD gradient and flow available; linear shunt mode active.', ...
        'In linear mode, R.asd is the active shunt resistance knob.', ...
        'Use as shunt candidate for GSA.');
end
for name = {'R.SAR','R.SC','R.SVEN','C.SAR','R.PAR','R.PCOX','R.PCNO','R.PVEN','C.PAR'}
    param_name = name{1};
    [rows, excluded, warnings] = add_candidate_checked(rows, excluded, warnings, params, ...
        param_name, 'A_Primary_Vascular_Shunt', 'primary_candidate', ...
        policy_for(param_name), expected_outputs_for(param_name), ...
        sprintf('%s has systemic/pulmonary pressure-flow targets if available in caseProfile.', case_label), ...
        vascular_rationale_for(param_name), ...
        sprintf('Bounds from VSD build_parameter_registry: %s.', policy_for(param_name)));
end
tbl = rows_to_candidate_table(rows);
end

function [tbl, excluded, warnings] = group_b_secondary(params, excluded, warnings, case_profile)
% GROUP_B_SECONDARY - atrial and preload candidates for pressure-gradient checks.
rows = {};
atrial_support = 'LAP target may be available; RAP/atrial volumes may be missing and must be checked in caseProfile.';
if isfield(case_profile.dataFlags, 'has_lap') && case_profile.dataFlags.has_lap && ...
        isfield(case_profile.dataFlags, 'has_rap') && case_profile.dataFlags.has_rap
    atrial_support = 'LAP and RAP targets are available; atrial pressure-gradient support is stronger.';
end
for name = {'E.LA.EA','E.LA.EB','E.RA.EA','E.RA.EB'}
    param_name = name{1};
    [rows, excluded, warnings] = add_candidate_checked(rows, excluded, warnings, params, ...
        param_name, 'B_Secondary_Atrial_Preload', 'secondary_candidate', ...
        policy_for(param_name), 'P_LA-P_RA; Q_ASD; Qp/Qs; LAP_mean; RAP_mean', ...
        atrial_support, ...
        'ASD flow depends on the atrial pressure gradient and atrial stiffness.', ...
        'Not automatically optimised unless GSA justifies it.');
end
for name = {'V0.LA','V0.RA','V0.SVEN','V0.PVEN'}
    param_name = name{1};
    [rows, excluded, warnings] = add_candidate_checked(rows, excluded, warnings, params, ...
        param_name, 'B_Secondary_Atrial_Preload', 'secondary_candidate', ...
        policy_for(param_name), 'preload; LAP_mean; RAP_mean; Q_ASD; Qp/Qs', ...
        'No atrial volume data; preload handles must remain tightly bounded.', ...
        'Unstressed volume can shift filling pressure and therefore shunt drive.', ...
        'Treat as secondary because direct preload/atrial-volume evidence is absent.');
end
for name = {'C.SVEN','C.PVEN'}
    param_name = name{1};
    [rows, excluded, warnings] = add_candidate_checked(rows, excluded, warnings, params, ...
        param_name, 'B_Secondary_Atrial_Preload', 'secondary_candidate', ...
        policy_for(param_name), 'venous reservoir pressure; LAP/RAP; Q_ASD; Qp/Qs', ...
        'Venous compliance is represented in the model but not directly measured.', ...
        'Venous reservoir compliance can alter atrial filling and shunt gradient.', ...
        'Secondary only; use after primary vascular/shunt sensitivity is reviewed.');
end
tbl = rows_to_candidate_table(rows);
end

function [tbl, excluded, warnings] = group_c_fixed(params, excluded, warnings, case_profile)
% GROUP_C_FIXED - ventricular parameters held fixed unless later approved.
rows = {};
if isfield(case_profile.dataFlags, 'has_ventricular_volume_function_targets') && ...
        case_profile.dataFlags.has_ventricular_volume_function_targets
    status = 'exploratory_candidate_volume_supported';
    support = 'Ventricular volume/function targets are available; review identifiability before calibration.';
    notes = 'Not automatic; include only if target-tier governance and GSA support it.';
else
    status = 'fixed_by_default_exploratory_only';
    support = 'Ventricular volume/function targets are missing.';
    notes = 'Do not include in main pre-closure optimisation without explicit approval.';
end
for name = {'E.LV.EA','E.LV.EB','E.RV.EA','E.RV.EB'}
    param_name = name{1};
    [rows, excluded, warnings] = add_candidate_checked(rows, excluded, warnings, params, ...
        param_name, 'C_Fixed_Exploratory_Ventricular', status, ...
        policy_for(param_name), 'LV/RV pressure-volume behavior; SV; EF; CO', ...
        support, ...
        'Ventricular elastance is poorly identifiable without LV/RV volume and EF targets.', ...
        notes);
end
for name = {'V0.LV','V0.RV'}
    param_name = name{1};
    [rows, excluded, warnings] = add_candidate_checked(rows, excluded, warnings, params, ...
        param_name, 'C_Fixed_Exploratory_Ventricular', status, ...
        policy_for(param_name), 'LV/RV preload; EDV/ESV; SV; EF', ...
        support, ...
        'Ventricular V0 is not identifiable without chamber-volume targets.', ...
        notes);
end
tbl = rows_to_candidate_table(rows);
end

function [rows, excluded, warnings] = add_candidate_checked(rows, excluded, warnings, ...
    params, name, group, status, bound_policy, outputs, support, rationale, notes)
% ADD_CANDIDATE_CHECKED - include finite positive values, otherwise warn.
[ok, value] = get_param_value(params, name);
if ~ok || ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    reason = 'Missing, zero, Inf, NaN, or non-positive current value.';
    excluded = add_excluded(excluded, name, 'not_automatic_candidate', value, reason, notes);
    warnings = add_warning(warnings, name, 'candidate_not_included', reason);
    return;
end
rows = add_candidate(rows, params, name, group, status, bound_policy, ...
    outputs, support, rationale, notes);
end

function rows = add_candidate(rows, params, name, group, status, bound_policy, ...
    outputs, support, rationale, notes)
% ADD_CANDIDATE - append one finite candidate row.
[~, value] = get_param_value(params, name);
[lb, ub, bound_type] = bounds_for(value, bound_policy);
rows(end + 1, :) = {string(name), string(group), string(status), value, ...
    lb, ub, string(bound_type), string(outputs), string(support), ...
    string(rationale), string(notes)};
end

function [lb, ub, bound_type] = bounds_for(value, policy)
% BOUNDS_FOR - bound policy for VSD-adapted calibration registry.
% References: build_parameter_registry.m (Hafiz-Keisya unified VSD)
switch policy
    case 'physical_Cd'
        lb = 0.20;
        ub = 1.20;
        bound_type = 'physical_orifice_discharge_coefficient_range';
    case 'resistances_kung2013'
        lb = 0.40 * value;
        ub = 2.50 * value;
        bound_type = 'Kung_2013_resistance_prior';
    case 'venous_resistance'
        lb = 0.40 * value;
        ub = 3.00 * value;
        bound_type = 'Kung_2013_venous_resistance_wider_RC_coupled';
    case 'arterial_compliance_windkessel_sys'
        lb = 0.75 * value;
        ub = 1.35 * value;
        bound_type = 'Windkessel_SV_over_pp_systemic_arterial_compliance';
    case 'arterial_compliance_windkessel_pul'
        lb = 0.70 * value;
        ub = 1.45 * value;
        bound_type = 'Windkessel_SV_over_pp_pulmonary_arterial_compliance';
    case 'venous_compliance_rc_coupled'
        lb = 0.50 * value;
        ub = 1.80 * value;
        bound_type = 'Kung_2013_RC_coupled_venous_compliance';
    case 'ventricular_elastance_lv'
        lb = 0.60 * value;
        ub = 2.20 * value;
        bound_type = 'Zhang_2019_LV_elastance_prior';
    case 'ventricular_elastance_lv_eb'
        lb = 0.60 * value;
        ub = 2.50 * value;
        bound_type = 'Zhang_2019_LV_EB_elastance_prior';
    case 'ventricular_elastance_rv'
        lb = 0.55 * value;
        ub = 2.60 * value;
        bound_type = 'Zhang_2019_RV_elastance_prior';
    case 'ventricular_elastance_rv_eb'
        lb = 0.60 * value;
        ub = 2.50 * value;
        bound_type = 'Zhang_2019_RV_EB_elastance_prior';
    case 'atrial_elastance_wide'
        lb = 0.20 * value;
        ub = 2.50 * value;
        bound_type = 'Zhang_2019_atrial_elastance_wide_prior';
    case 'atrial_elastance_eb'
        lb = 0.60 * value;
        ub = 2.50 * value;
        bound_type = 'Zhang_2019_atrial_EB_elastance_prior';
    case 'unstressed_volume_chamber'
        lb = 0.70 * value;
        ub = 1.35 * value;
        bound_type = 'blood_volume_preload_consistency_prior';
    case 'unstressed_volume_LV'
        lb = 0.75 * value;
        ub = 1.40 * value;
        bound_type = 'blood_volume_preload_consistency_LV_prior';
    case 'unstressed_volume_RV'
        lb = 0.70 * value;
        ub = 1.35 * value;
        bound_type = 'blood_volume_preload_consistency_RV_prior';
    case 'multiplicative_0p8_1p2'
        lb = 0.80 * value;
        ub = 1.20 * value;
        bound_type = '0.8x_to_1.2x_legacy_heuristic';
    otherwise  % 'multiplicative_0p5_2p0' legacy
        lb = 0.50 * value;
        ub = 2.00 * value;
        bound_type = '0.5x_to_2.0x_legacy_heuristic';
end
end

function policy = policy_for(name)
% POLICY_FOR - map parameter name to VSD-adapted bound policy.
% References: build_parameter_registry.m (Hafiz-Keisya unified VSD)
if startsWith(name, 'R.SVEN') || startsWith(name, 'R.PVEN')
    policy = 'venous_resistance';
elseif startsWith(name, 'R.')
    policy = 'resistances_kung2013';
elseif strcmp(name, 'C.SAR')
    policy = 'arterial_compliance_windkessel_sys';
elseif strcmp(name, 'C.PAR')
    policy = 'arterial_compliance_windkessel_pul';
elseif startsWith(name, 'C.SVEN') || startsWith(name, 'C.PVEN')
    policy = 'venous_compliance_rc_coupled';
elseif strcmp(name, 'E.LV.EA')
    policy = 'ventricular_elastance_lv';
elseif strcmp(name, 'E.LV.EB')
    policy = 'ventricular_elastance_lv_eb';
elseif strcmp(name, 'E.RV.EA')
    policy = 'ventricular_elastance_rv';
elseif strcmp(name, 'E.RV.EB')
    policy = 'ventricular_elastance_rv_eb';
elseif any(strcmp(name, {'E.LA.EA','E.RA.EA'}))
    policy = 'atrial_elastance_wide';
elseif any(strcmp(name, {'E.LA.EB','E.RA.EB'}))
    policy = 'atrial_elastance_eb';
elseif strcmp(name, 'V0.LV')
    policy = 'unstressed_volume_LV';
elseif strcmp(name, 'V0.RV')
    policy = 'unstressed_volume_RV';
elseif startsWith(name, 'V0.')
    policy = 'unstressed_volume_chamber';
elseif strcmp(name, 'asd.Cd')
    policy = 'physical_Cd';
else
    policy = 'multiplicative_0p5_2p0';
end
end

function text = expected_outputs_for(name)
% EXPECTED_OUTPUTS_FOR - map vascular candidate to expected observables.
if startsWith(name, 'R.S') || strcmp(name, 'C.SAR')
    text = 'MAP; SBP; DBP; Qs; systemic pressure-flow balance';
elseif startsWith(name, 'R.P') || strcmp(name, 'C.PAR')
    text = 'PAP_sys; PAP_dia; PAP_mean; Qp; Qp/Qs; pulmonary pressure-flow balance';
else
    text = 'hemodynamic outputs';
end
end

function text = vascular_rationale_for(name)
% VASCULAR_RATIONALE_FOR - short physiology statement for each vascular class.
if startsWith(name, 'R.S')
    text = 'Systemic resistance controls systemic afterload and Qs/MAP balance.';
elseif strcmp(name, 'C.SAR')
    text = 'Systemic arterial compliance controls pulse pressure and systemic waveform shape.';
elseif startsWith(name, 'R.P')
    text = 'Pulmonary resistance controls pulmonary pressure-flow balance and Qp response.';
elseif strcmp(name, 'C.PAR')
    text = 'Pulmonary arterial compliance controls PAP pulsatility and pulmonary reservoir behavior.';
else
    text = 'Candidate affects pressure-flow balance.';
end
end

function tbl = rows_to_candidate_table(rows)
% ROWS_TO_CANDIDATE_TABLE - table schema shared by candidate groups.
vars = {'Parameter','Group','Status','Initial_Value','Lower_Bound', ...
    'Upper_Bound','Bound_Type','Expected_Affected_Outputs', ...
    'Data_Support','Physiological_Rationale','Notes'};
if isempty(rows)
    tbl = cell2table(cell(0, numel(vars)), 'VariableNames', vars);
else
    tbl = cell2table(rows, 'VariableNames', vars);
end
end

function tbl = build_summary(params, scenario, case_profile)
% BUILD_SUMMARY - high-level methodological summary.
case_label = char(case_profile.patient_label);
rows = {
    "Purpose", "Define ASD candidate parameter sets before GSA; no simulation, tuning, GSA, or optimisation."
    "Patient", string(case_label)
    "Scenario", scenario
    "Case profile mode", string(case_profile.mode)
    "ASD mode", string(params.asd.mode)
    "Active shunt candidate", mode_aware_shunt_label(params)
    "R.asd status", mode_aware_rasd_note(params)
    "Fixed geometry", geometry_note(params)
    "Primary group", "Group A: shunt Cd plus systemic/pulmonary vascular R/C candidates."
    "Secondary group", "Group B: atrial elastance and venous/preload candidates."
    "Fixed exploratory group", "Group C: ventricular E/V0 fixed by default because volume/function data are missing."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic','Details'});
end

function tbl = build_bounds_rationale()
% BUILD_BOUNDS_RATIONALE - document preliminary bound policies.
rows = {
    "asd.Cd", "0.2 to 1.2", "Physical orifice discharge coefficient interval.", "Used only when orifice mode is active."
    "R.asd", "0.4x to 2.5x current value", "Linear ASD resistance prior around gradient/flow seed.", "Used only when linear shunt mode is active."
    "Resistances", "0.5x to 2.0x current value", "Conservative screen around seeded pediatric operating point.", "Applies to Group A vascular resistances."
    "Compliances", "0.5x to 2.0x current value", "Allows pressure waveform and reservoir sensitivity without broad free search.", "Applies to Group A and secondary venous compliances."
    "Atrial elastance", "0.5x to 2.0x current value", "ASD shunt is sensitive to atrial pressure gradient.", "Secondary because atrial volume data are absent."
    "Atrial/ventricular V0", "0.8x to 1.2x current value", "Tighter preload bound because V0 is poorly identifiable.", "Ventricular V0 fixed/exploratory only."
    "Invalid current values", "not included", "Zero, Inf, NaN, or missing values are not automatic candidates.", "Reported in Warnings/Excluded_Parameters."
    };
tbl = cell2table(rows, 'VariableNames', {'Parameter_Class','Preliminary_Bounds', ...
    'Rationale','Notes'});
end

function tbl = build_future_gsa_targets(clinical, scenario, case_profile)
% BUILD_FUTURE_GSA_TARGETS - target outputs available for later GSA.
src = struct();
if nargin >= 3 && isfield(case_profile, 'scenario_key') && ...
        isstruct(clinical) && isfield(clinical, char(case_profile.scenario_key))
    src = clinical.(char(case_profile.scenario_key));
elseif isstruct(clinical) && isfield(clinical, scenario)
    src = clinical.(scenario);
end
rows = {};
rows = add_target(rows, 'Qp/Qs', 'primary', 'QpQs', src, 'QpQs', ...
    'Primary shunt-severity target; not forced as parameter.');
rows = add_target(rows, 'Qp', 'primary', 'Qp_Lmin', src, 'Qp_Lmin', ...
    'Pulmonary flow target supports Qp/Qs interpretation.');
rows = add_target(rows, 'Qs', 'primary', 'Qs_Lmin', src, 'Qs_Lmin', ...
    'Systemic flow target; MAP is already close and should be preserved.');
rows = add_target(rows, 'PAP_mean', 'primary', 'PAP_mean_mmHg', src, ...
    'PAP_mean_mmHg', 'Pulmonary pressure-load target.');
rows = add_target(rows, 'MAP', 'primary', 'SAP_mean_mmHg', src, ...
    'SAP_mean_mmHg', 'Investigator-selected RFA/cath systemic mean pressure.');
rows = add_target(rows, 'LAP_mean', 'primary', 'LAP_mean_mmHg', src, ...
    'LAP_mean_mmHg', 'Available filling-pressure target; LVEDP unavailable.');
rows = add_target(rows, 'PAP_sys', 'secondary', 'PAP_sys_mmHg', src, ...
    'PAP_sys_mmHg', 'Pulmonary waveform target.');
rows = add_target(rows, 'PAP_dia', 'secondary', 'PAP_dia_mmHg', src, ...
    'PAP_dia_mmHg', 'Pulmonary waveform target.');
rows = add_target(rows, 'SBP', 'secondary', 'SAP_sys_mmHg', src, ...
    'SAP_sys_mmHg', 'Systemic waveform target.');
rows = add_target(rows, 'DBP', 'secondary', 'SAP_dia_mmHg', src, ...
    'SAP_dia_mmHg', 'Systemic waveform target.');
qasd_priority = 'secondary';
qasd_notes = 'Derived comparison only unless direct shunt flow is explicitly marked.';
if has_direct_qasd(src)
    qasd_priority = 'secondary_direct_shunt';
    qasd_notes = 'Direct shunt flow is explicitly marked; may be reviewed as secondary calibration evidence.';
end
rows = add_target(rows, 'Q_ASD', qasd_priority, 'Q_ASD_source', src, ...
    'Qp_Lmin', qasd_notes);
rap_available = isfield(src, 'RAP_mean_mmHg') && isnumeric(src.RAP_mean_mmHg) && ...
    isscalar(src.RAP_mean_mmHg) && isfinite(src.RAP_mean_mmHg);
rap_priority = 'model_prediction_only';
rap_notes = 'Clinical RAP missing; do not use as direct target.';
if rap_available
    rap_priority = 'primary';
    rap_notes = 'Clinical RAP available; target-tier governance treats it as a measured atrial-pressure target.';
end
rows = add_target(rows, 'RAP_mean', rap_priority, 'RAP_mean_mmHg', ...
    src, 'RAP_mean_mmHg', rap_notes);
excluded_primary = {'LVEDV','LVESV','RVEDV','RVESV','LVEF','RVEF'};
for idx = 1:numel(excluded_primary)
    rows = add_missing_volume_target(rows, excluded_primary{idx});
end
tbl = cell2table(rows, 'VariableNames', {'Metric','Priority','Clinical_Field', ...
    'Available','Data_Support','Notes'});
end

function rows = add_missing_volume_target(rows, metric)
% ADD_MISSING_VOLUME_TARGET - mark unavailable volume/function targets.
rows(end + 1, :) = {string(metric), "excluded_primary", "missing", ...
    "NO", "Volume/function data missing for this ASD pre-closure profile.", ...
    "Do not use as primary target before new evidence is available."};
end

function rows = add_target(rows, metric, priority, label, src, field_name, notes)
% ADD_TARGET - append target availability row.
available = isfield(src, field_name) && isnumeric(src.(field_name)) && ...
    isscalar(src.(field_name)) && isfinite(src.(field_name));
if strcmp(metric, 'Q_ASD')
    available = isfield(src, 'Qp_Lmin') && isfield(src, 'Qs_Lmin') && ...
        isfinite(src.Qp_Lmin) && isfinite(src.Qs_Lmin);
end
rows(end + 1, :) = {string(metric), string(priority), string(label), ...
    string(yes_no(available)), string(target_support_text(src, field_name, available)), ...
    string(notes)};
end

function text = target_support_text(src, field_name, available)
% TARGET_SUPPORT_TEXT - compact target value note.
if ~available
    text = 'Not available or not finite.';
    return;
end
if strcmp(field_name, 'Qp_Lmin') && isfield(src, 'Qs_Lmin') && isfinite(src.Qs_Lmin)
    text = sprintf('%s=%.9g; Qs_Lmin=%.9g when needed.', field_name, src.(field_name), src.Qs_Lmin);
else
    text = sprintf('%s=%.9g.', field_name, src.(field_name));
end
end

function tbl = append_manual_exclusions(tbl, params)
% APPEND_MANUAL_EXCLUSIONS - fixed/not-used parameters to document.
% Mode-aware: exclude the INACTIVE shunt parameter, keep the active one.
shunt_mode = lower(char(params.asd.mode));
if strcmp(shunt_mode, 'orifice_bidirectional')
    tbl = add_excluded(tbl, 'R.asd', 'excluded_in_orifice_mode', ...
        safe_get(params, 'R.asd'), 'R.asd is not used in orifice_bidirectional ASD flow.', ...
        'Only consider if the model is explicitly switched to linear resistance mode.');
else
    tbl = add_excluded(tbl, 'asd.Cd', 'excluded_in_linear_mode', ...
        safe_get(params, 'asd.Cd'), 'asd.Cd is not used in linear ASD shunt mode.', ...
        'Only consider if the model is explicitly switched to orifice mode.');
end
tbl = add_excluded(tbl, 'R.vsd', 'legacy_vsd_inactive', ...
    safe_get(params, 'R.vsd'), 'VSD coupling is not part of active ASD physiology.', ...
    'Do not use as an ASD pre-closure candidate.');
tbl = add_excluded(tbl, 'asd.area_mm2', 'fixed_clinical_geometry', ...
    safe_get(params, 'asd.area_mm2'), 'ASD area is derived from reported diameter and kept fixed.', ...
    'Do not optimise geometry before a separate measurement-uncertainty decision.');
tbl = add_excluded(tbl, 'asd.diameter_mm', 'fixed_clinical_geometry', ...
    safe_get(params, 'asd.diameter_mm'), 'ASD diameter is clinical input, not a calibration knob.', ...
    'Use in geometry documentation, not GSA parameter set.');
for name = {'C.PCOX','C.PCNO'}
    tbl = add_excluded(tbl, name{1}, 'not_in_initial_group_A', safe_get(params, name{1}), ...
        'Pulmonary capillary compliance is present but not selected for the first candidate set.', ...
        'May be reconsidered only if pulmonary waveform/volume sensitivity requires it.');
end
end

function tbl = append_method_warnings(tbl, params, clinical, scenario, case_profile)
% APPEND_METHOD_WARNINGS - key methodological cautions.
supported_modes = {'orifice_bidirectional','linear_bidirectional','linear_left_to_right_only'};
if ~any(strcmpi(params.asd.mode, supported_modes))
    tbl = add_warning(tbl, 'asd.mode', 'mode_review_needed', ...
        'Current ASD mode is unsupported by the ASD candidate parameter library.');
end
if isfield(case_profile.dataFlags, 'has_ventricular_volume_function_targets') && ...
        ~case_profile.dataFlags.has_ventricular_volume_function_targets
    tbl = add_warning(tbl, 'ventricular_volume_targets', 'identifiability_limit', ...
        'LV/RV volume and EF targets are missing, so ventricular E/V0 remain fixed/exploratory.');
end
if isfield(case_profile, 'dataFlags') && isfield(case_profile.dataFlags, 'has_rap') && ...
        case_profile.dataFlags.has_rap
    tbl = add_warning(tbl, 'RAP_mean', 'primary_target_available', ...
        'Clinical RAP is available; treat as a measured atrial-pressure target in target-tier governance.');
else
    tbl = add_warning(tbl, 'RAP_mean', 'model_prediction_only', ...
        'Clinical RAP is missing; RAP_mean should not be a direct calibration target.');
end
if isstruct(clinical) && isfield(clinical, scenario)
    src = clinical.(scenario);
    if ~(isfield(src, 'ASD_gradient_mmHg') && isfinite(src.ASD_gradient_mmHg))
        tbl = add_warning(tbl, 'ASD_gradient_mmHg', 'missing_direct_shunt_resistance_data', ...
            'ASD pressure gradient is missing; R_ASD cannot be computed from DeltaP/Q.');
    end
end
end

function tbl = build_notes(params)
% BUILD_NOTES - thesis-facing method notes.
rows = {
    "No execution", "This helper defines candidate metadata only; it does not run GSA, optimisation, calibration, or ODE simulation."
    "ASD shunt parameter", mode_aware_shunt_note(params)
    "Geometry", "ASD diameter and area are measured/derived clinical geometry and are held fixed for the first candidate definition."
    "Group A", sprintf('Primary set for future GSA: vascular pressure-flow parameters plus %s.', mode_aware_shunt_name(params))
    "Group B", "Secondary set: atrial/preload candidates that may affect P_LA-P_RA and Q_ASD."
    "Group C", "Ventricular parameters are fixed/exploratory only because chamber-volume and EF targets are missing."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic','Note'});
end

function [ok, value] = get_param_value(params, name)
% GET_PARAM_VALUE - dot-notation reader with missing-field guard.
ok = true;
value = params;
parts = strsplit(name, '.');
for idx = 1:numel(parts)
    if ~isstruct(value) || ~isfield(value, parts{idx})
        ok = false;
        value = NaN;
        return;
    end
    value = value.(parts{idx});
end
end

function value = safe_get(params, name)
% SAFE_GET - return value or NaN for report rows.
[ok, value] = get_param_value(params, name);
if ~ok
    value = NaN;
end
end

function tbl = empty_excluded()
% EMPTY_EXCLUDED - initialise exclusion table.
tbl = cell2table(cell(0, 5), 'VariableNames', ...
    {'Parameter','Status','Current_Value','Reason','Notes'});
end

function tbl = empty_warnings()
% EMPTY_WARNINGS - initialise warning table.
tbl = cell2table(cell(0, 3), 'VariableNames', ...
    {'Parameter','Warning_Type','Details'});
end

function tbl = add_excluded(tbl, name, status, value, reason, notes)
% ADD_EXCLUDED - append one exclusion row.
row = cell2table({string(name), string(status), value, string(reason), ...
    string(notes)}, 'VariableNames', tbl.Properties.VariableNames);
tbl = [tbl; row];
end

function tbl = add_warning(tbl, name, warning_type, details)
% ADD_WARNING - append one warning row.
row = cell2table({string(name), string(warning_type), string(details)}, ...
    'VariableNames', tbl.Properties.VariableNames);
tbl = [tbl; row];
end

function text = yes_no(tf)
% YES_NO - readable boolean status.
if tf
    text = 'YES';
else
    text = 'NO';
end
end

function tf = has_direct_qasd(src)
% HAS_DIRECT_QASD - true only for independent direct shunt-flow reports.
tf = false;
if ~isstruct(src) || ~isfield(src, 'Q_shunt_Lmin') || ...
        ~isnumeric(src.Q_shunt_Lmin) || ~isfinite(src.Q_shunt_Lmin)
    return;
end
if isfield(src, 'Q_shunt_is_direct') && islogical(src.Q_shunt_is_direct)
    tf = src.Q_shunt_is_direct;
    return;
end
if isfield(src, 'Q_shunt_source')
    source_text = lower(char(string(src.Q_shunt_source)));
    tf = contains(source_text, 'direct') && ~contains(source_text, 'derived');
end
end

function name = mode_aware_shunt_name(params)
% MODE_AWARE_SHUNT_NAME - active shunt calibration candidate.
if strcmpi(params.asd.mode, 'orifice_bidirectional')
    name = 'asd.Cd';
else
    name = 'R.asd';
end
end

function note = mode_aware_shunt_note(params)
% MODE_AWARE_SHUNT_NOTE - mode-aware shunt note for candidate reports.
if strcmpi(params.asd.mode, 'orifice_bidirectional')
    note = sprintf('Current mode is %s; therefore asd.Cd is the active shunt candidate and R.asd is inactive.', params.asd.mode);
else
    note = sprintf('Current mode is %s; therefore R.asd is the active shunt candidate and asd.Cd is inactive.', params.asd.mode);
end
end

function text = value_text(value)
% VALUE_TEXT - compact scalar value text.
if isnumeric(value) && isscalar(value)
    if isinf(value)
        text = 'Inf';
    elseif isnan(value)
        text = 'NaN';
    else
    text = sprintf('%.9g', value);
    end
end
end

function label = mode_aware_shunt_label(params)
% MODE_AWARE_SHUNT_LABEL - return the active shunt parameter name for display.
mode = lower(char(params.asd.mode));
if strcmp(mode, 'orifice_bidirectional')
    label = sprintf('asd.Cd (orifice mode, current Cd=%.3g)', params.asd.Cd);
else
    label = sprintf('R.asd (linear mode, current R=%.3g mmHg*s/mL)', params.R.asd);
end
end

function note = mode_aware_rasd_note(params)
% MODE_AWARE_RASD_NOTE - describe R.asd status based on active mode.
mode = lower(char(params.asd.mode));
if strcmp(mode, 'orifice_bidirectional')
    if isinf(params.R.asd)
        note = 'R.asd=Inf; not used by orifice_bidirectional ASD flow.';
    else
        note = sprintf('R.asd=%.3g; not active (orifice mode uses asd.Cd).', params.R.asd);
    end
else
    note = sprintf('R.asd=%.3g mmHg*s/mL; active shunt resistance (linear mode).', params.R.asd);
end
end

function note = geometry_note(params)
% GEOMETRY_NOTE - compact ASD geometry note, tolerant of missing data.
if isfinite(params.asd.diameter_mm)
    note = sprintf('ASD diameter %.6g mm; ASD area %.12g mm^2.', ...
        params.asd.diameter_mm, params.asd.area_mm2);
else
    note = 'ASD diameter missing; shunt uses linear R.asd from gradient/flow.';
end
end
