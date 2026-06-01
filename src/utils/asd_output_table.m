function T = asd_output_table(sim, params, clinical, scenario)
% ASD_OUTPUT_TABLE
% -----------------------------------------------------------------------
% Generates a comprehensive 26-metric output table for ASD model results.
% Marks metrics with clinical targets vs prediction-only (NA).
%
% INPUTS:
%   sim      - simulation struct from integrate_system             [-]
%   params   - parameter struct (seeded or calibrated)             [-]
%   clinical - patient clinical struct (patient_zoya)              [-]
%   scenario - 'pre_surgery' or 'post_surgery'                     [-]
%
% OUTPUTS:
%   T        - table with columns: Metric, Value, Unit, Target,    [-]
%              Target_Source, Error_pct, Status
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-31
% VERSION:  1.0
% -----------------------------------------------------------------------

if nargin < 4 || isempty(scenario)
    scenario = 'pre_surgery';
end

%% Compute clinical indices
metrics = compute_clinical_indices(sim, params);

%% Reconstruct hemodynamic signals for additional metrics
try
    [P, ~] = reconstruct_hemodynamic_signals(sim.t(:), sim.V, params);
catch
    P = struct();
end

%% Resolve clinical source
src = struct();
if isstruct(clinical) && isfield(clinical, scenario)
    src = clinical.(scenario);
end

%% Build metric rows
rows = {};

% 1. Heart Rate
rows = add_row(rows, 'HR', params.HR, 'bpm', ...
    clinical.common.HR, 'clinical.common.HR', 'Resting heart rate');

% 2. Cardiac Output (systemic flow Qs)
rows = add_row(rows, 'CO_Lmin', field_or_nan(metrics, 'Qs_Lmin'), 'L/min', ...
    first_valid(src, {'Qs_Lmin', 'CO_Lmin'}, NaN), 'clinical.pre_surgery.Qs_Lmin', ...
    'Systemic cardiac output = Qs; Fick-derived');

% 3. LV Stroke Volume
lvsv = field_or_nan(metrics, 'LVSV');
if isnan(lvsv) && isfield(metrics, 'LVEDV') && isfield(metrics, 'LVESV') && ...
        isfinite(metrics.LVEDV) && isfinite(metrics.LVESV)
    lvsv = metrics.LVEDV - metrics.LVESV;
end
rows = add_row(rows, 'LV_SV_mL', lvsv, 'mL', ...
    NaN, 'NA', 'LV stroke volume = LVEDV - LVESV');

% 4. RV Stroke Volume
rvsv = field_or_nan(metrics, 'RVSV');
if isnan(rvsv) && isfield(metrics, 'RVEDV') && isfield(metrics, 'RVESV') && ...
        isfinite(metrics.RVEDV) && isfinite(metrics.RVESV)
    rvsv = metrics.RVEDV - metrics.RVESV;
end
rows = add_row(rows, 'RV_SV_mL', rvsv, 'mL', ...
    NaN, 'NA', 'RV stroke volume = RVEDV - RVESV');

% 5. LVEF
lvef_val = field_or_nan(metrics, 'LVEF');
rows = add_row(rows, 'LVEF', lvef_val, 'fraction', ...
    field_or_nan(src, 'EF'), 'clinical.pre_surgery.EF', ...
    'LV ejection fraction; NA if override_IC==false');

% 6. RVEF
rows = add_row(rows, 'RVEF', field_or_nan(metrics, 'RVEF'), 'fraction', ...
    NaN, 'NA', 'RV ejection fraction (model-derived)');

% 7. LVEDV
rows = add_row(rows, 'LVEDV_mL', field_or_nan(metrics, 'LVEDV'), 'mL', ...
    field_or_nan(src, 'LVEDV_mL'), 'clinical.pre_surgery.LVEDV_mL', ...
    'LV end-diastolic volume');

% 8. LVESV
rows = add_row(rows, 'LVESV_mL', field_or_nan(metrics, 'LVESV'), 'mL', ...
    field_or_nan(src, 'LVESV_mL'), 'clinical.pre_surgery.LVESV_mL', ...
    'LV end-systolic volume');

% 9. RVEDV
rows = add_row(rows, 'RVEDV_mL', field_or_nan(metrics, 'RVEDV'), 'mL', ...
    field_or_nan(src, 'RVEDV_mL'), 'clinical.pre_surgery.RVEDV_mL', ...
    'RV end-diastolic volume');

% 10. RVESV
rows = add_row(rows, 'RVESV_mL', field_or_nan(metrics, 'RVESV'), 'mL', ...
    field_or_nan(src, 'RVESV_mL'), 'clinical.pre_surgery.RVESV_mL', ...
    'RV end-systolic volume');

% 11. SVR
rows = add_row(rows, 'SVR_WU', field_or_nan(metrics, 'SVR'), 'Wood units', ...
    field_or_nan(src, 'SVR_WU'), 'clinical.pre_surgery.SVR_WU', ...
    'Systemic vascular resistance');

% 12. PVR
rows = add_row(rows, 'PVR_WU', field_or_nan(metrics, 'PVR'), 'Wood units', ...
    field_or_nan(src, 'PVR_WU'), 'clinical.pre_surgery.PVR_WU', ...
    'Pulmonary vascular resistance');

% 13. RVP mean
rvp = field_or_nan(metrics, 'RVP_mean');
if isnan(rvp) && isfield(P, 'P_RV')
    rvp = mean(P.P_RV, 'omitnan');
end
rows = add_row(rows, 'RVP_mean_mmHg', rvp, 'mmHg', ...
    NaN, 'NA', 'Mean RV pressure (model-derived)');

% 14. SBP
sbp = field_or_nan(src, 'SAP_sys_mmHg');
if strcmp(scenario, 'pre_surgery')
    sbp = first_valid(src, {'SAP_sys_mmHg', 'SAP_sys_RFA_mmHg'}, NaN);
end
rows = add_row(rows, 'SBP_mmHg', field_or_nan(metrics, 'SAP_max'), 'mmHg', ...
    sbp, 'clinical.pre_surgery.SAP_sys_mmHg', 'Systolic arterial pressure');

% 15. DBP
dbp = field_or_nan(src, 'SAP_dia_mmHg');
if strcmp(scenario, 'pre_surgery')
    dbp = first_valid(src, {'SAP_dia_mmHg', 'SAP_dia_RFA_mmHg'}, NaN);
end
rows = add_row(rows, 'DBP_mmHg', field_or_nan(metrics, 'SAP_min'), 'mmHg', ...
    dbp, 'clinical.pre_surgery.SAP_dia_mmHg', 'Diastolic arterial pressure');

% 16. MAP
map = field_or_nan(src, 'SAP_mean_mmHg');
if strcmp(scenario, 'pre_surgery')
    map = first_valid(src, {'SAP_mean_mmHg', 'MAP_RFA_mmHg', 'MAP_NIBP_mmHg'}, NaN);
end
rows = add_row(rows, 'MAP_mmHg', field_or_nan(metrics, 'SAP_mean'), 'mmHg', ...
    map, 'clinical.pre_surgery.SAP_mean_mmHg', 'Mean arterial pressure');

% 17. PAP systolic
rows = add_row(rows, 'PAP_sys_mmHg', field_or_nan(metrics, 'PAP_max'), 'mmHg', ...
    field_or_nan(src, 'PAP_sys_mmHg'), 'clinical.pre_surgery.PAP_sys_mmHg', ...
    'Systolic pulmonary artery pressure');

% 18. PAP diastolic
rows = add_row(rows, 'PAP_dia_mmHg', field_or_nan(metrics, 'PAP_min'), 'mmHg', ...
    field_or_nan(src, 'PAP_dia_mmHg'), 'clinical.pre_surgery.PAP_dia_mmHg', ...
    'Diastolic pulmonary artery pressure');

% 19. PAP mean
rows = add_row(rows, 'PAP_mean_mmHg', field_or_nan(metrics, 'PAP_mean'), 'mmHg', ...
    field_or_nan(src, 'PAP_mean_mmHg'), 'clinical.pre_surgery.PAP_mean_mmHg', ...
    'Mean pulmonary artery pressure');

% 20. LAP mean
rows = add_row(rows, 'LAP_mean_mmHg', field_or_nan(metrics, 'LAP_mean'), 'mmHg', ...
    field_or_nan(src, 'LAP_mean_mmHg'), 'clinical.pre_surgery.LAP_mean_mmHg', ...
    'Left atrial mean pressure / PCWP surrogate');

% 21. RAP mean
rows = add_row(rows, 'RAP_mean_mmHg', field_or_nan(metrics, 'RAP_mean'), 'mmHg', ...
    field_or_nan(src, 'RAP_mean_mmHg'), 'clinical.pre_surgery.RAP_mean_mmHg', ...
    'Right atrial mean pressure');

% 22. LA-RA pressure gradient (DeltaP_ASD)
% Compute from reconstructed signals if available, otherwise fallback
deltaP_LA_RA = NaN;
if isfield(P, 'LA') && isfield(P, 'RA')
    deltaP_LA_RA = mean(P.LA - P.RA, 'omitnan');
else
    % Fallback: mean pressures from metrics
    lap = field_or_nan(metrics, 'LAP_mean');
    rap = field_or_nan(metrics, 'RAP_mean');
    if isfinite(lap) && isfinite(rap)
        deltaP_LA_RA = lap - rap;
    end
end
rows = add_row(rows, 'DeltaP_LA_RA_mmHg', deltaP_LA_RA, 'mmHg', ...
    field_or_nan(src, 'ASD_gradient_mmHg'), 'clinical.pre_surgery.ASD_gradient_mmHg', ...
    'Mean LA-RA pressure gradient driving ASD shunt');

% 23. Qp/Qs
rows = add_row(rows, 'QpQs', field_or_nan(metrics, 'QpQs'), '[-]', ...
    field_or_nan(src, 'QpQs'), 'clinical.pre_surgery.QpQs', ...
    'Pulmonary-to-systemic flow ratio');

% 24. Q_ASD mean (mL/s, ODE-internal unit)
q_asd_mLs = field_or_nan(metrics, 'Q_ASD_Lmin');
if ~isnan(q_asd_mLs)
    q_asd_mLs_per_s = q_asd_mLs * 1000 / 60;  % L/min → mL/s
else
    q_asd_mLs_per_s = NaN;
end
rows = add_row(rows, 'Q_ASD_mean_mLs', q_asd_mLs_per_s, 'mL/s', ...
    NaN, 'NA', 'Mean ASD shunt flow (ODE unit: mL/s)');

% 25. Q_ASD (L/min)
rows = add_row(rows, 'Q_ASD_Lmin', field_or_nan(metrics, 'Q_ASD_Lmin'), 'L/min', ...
    field_or_nan(src, 'Q_shunt_Lmin'), 'clinical.pre_surgery.Q_shunt_Lmin', ...
    'Mean ASD shunt flow; derived Qp-Qs if direct measurement unavailable');

% 26. ASD direction code
dir_code = 'NA';
if isfield(metrics, 'Q_ASD_Lmin') && isfinite(metrics.Q_ASD_Lmin)
    if metrics.Q_ASD_Lmin > 0.05
        dir_code = 'L->R';       % left-to-right (expected for Zoya)
    elseif metrics.Q_ASD_Lmin < -0.05
        dir_code = 'R->L';       % right-to-left (Eisenmenger)
    else
        dir_code = 'balanced';   % net zero shunt
    end
end
rows = add_row(rows, 'ASD_direction', NaN, '[-]', ...
    NaN, 'NA', sprintf('ASD shunt direction code: %s', dir_code));

%% Build table
T = cell2table(rows, 'VariableNames', ...
    {'Metric', 'Value', 'Unit', 'Target', 'Target_Source', 'Description'});

[ModelField, Output_Tier, IncludeInGSA, IncludeInCalibration, Discussion_Role] = ...
    output_governance(T.Metric);
T.ModelField = ModelField;
T.Output_Tier = Output_Tier;
T.IncludeInGSA = IncludeInGSA;
T.IncludeInCalibration = IncludeInCalibration;
T.Discussion_Role = Discussion_Role;

Qualitative_Value = strings(height(T), 1);
direction_row = strcmp(T.Metric, 'ASD_direction');
Qualitative_Value(direction_row) = string(dir_code);
T.Qualitative_Value = Qualitative_Value;

%% Compute error % for metrics with targets
n_rows = height(T);
Error_pct = strings(n_rows, 1);
Status = strings(n_rows, 1);

for i = 1:n_rows
    target_val = T.Target(i);
    model_val = T.Value(i);
    
    if isnan(target_val)
        Error_pct(i) = "N/A";
        Status(i) = "Prediction Only";
    elseif isnan(model_val) || ~isfinite(model_val)
        Error_pct(i) = "N/A";
        Status(i) = "Model NaN";
    else
        err = abs(model_val - target_val) / max(abs(target_val), 1e-6) * 100;
        Error_pct(i) = sprintf('%.1f%%', err);
        if err < 5
            Status(i) = "OK (<5%)";
        elseif err < 15
            Status(i) = "WARNING (5-15%)";
        else
            Status(i) = "MISMATCH (>15%)";
        end
    end
end

T.Error_pct = Error_pct;
T.Status = Status;

%% Print summary
fprintf('\n=== ASD Model Output Summary ===\n');
fprintf('Patient: Zoya | Scenario: %s | HR: %.0f bpm\n', scenario, params.HR);
fprintf('%-22s %10s %8s %10s %10s %s\n', ...
    'Metric', 'Value', 'Unit', 'Target', 'Error', 'Status');
fprintf('%s\n', repmat('-', 1, 90));
for i = 1:n_rows
    val_str = value_str(T.Value(i));
    if strlength(T.Qualitative_Value(i)) > 0
        val_str = char(T.Qualitative_Value(i));
    end
    tgt_str = value_str(T.Target(i));
    fprintf('%-22s %10s %8s %10s %10s %s\n', ...
        T.Metric{i}, val_str, T.Unit{i}, tgt_str, ...
        T.Error_pct{i}, T.Status{i});
end

end

%% ========================================================================
%  LOCAL HELPERS
%% ========================================================================

function rows = add_row(rows, metric, value, unit, target, target_source, desc)
rows(end + 1, :) = {string(metric), value, string(unit), ...
    target, string(target_source), string(desc)};
end

function v = field_or_nan(s, field_name)
v = NaN;
if isstruct(s) && isfield(s, field_name) && isnumeric(s.(field_name)) && ...
        isscalar(s.(field_name)) && isfinite(s.(field_name))
    v = s.(field_name);
end
end

function v = first_valid(s, field_names, fallback)
v = fallback;
for k = 1:numel(field_names)
    fn = field_names{k};
    if isfield(s, fn) && isnumeric(s.(fn)) && isscalar(s.(fn)) && isfinite(s.(fn))
        v = s.(fn);
        return;
    end
end
end

function s = value_str(v)
if isnan(v)
    s = 'NA';
elseif abs(v) < 0.01
    s = sprintf('%.4g', v);
elseif abs(v) < 100
    s = sprintf('%.2f', v);
else
    s = sprintf('%.1f', v);
end
end

function [model_field, tier, include_gsa, include_calibration, role] = output_governance(metrics)
% OUTPUT_GOVERNANCE - tier all printed ASD outputs for thesis reporting.
n = numel(metrics);
model_field = strings(n, 1);
tier = strings(n, 1);
include_gsa = false(n, 1);
include_calibration = false(n, 1);
role = strings(n, 1);

for idx = 1:n
    metric_name = char(string(metrics(idx)));
    switch metric_name
        case 'HR'
            model_field(idx) = "HR";
            tier(idx) = "clinical_input_not_calibrated";
            role(idx) = "Clinical seed/input consistency.";
        case 'CO_Lmin'
            model_field(idx) = "Qs_Lmin";
            tier(idx) = "hard_primary";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Primary systemic-flow calibration target.";
        case {'SBP_mmHg'}
            model_field(idx) = "SAP_max";
            tier(idx) = "soft_secondary_guard";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Measured systemic waveform guard.";
        case {'DBP_mmHg'}
            model_field(idx) = "SAP_min";
            tier(idx) = "soft_secondary_guard";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Measured systemic waveform guard.";
        case {'MAP_mmHg'}
            model_field(idx) = "SAP_mean";
            tier(idx) = "hard_primary";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Primary systemic pressure-flow calibration target.";
        case {'PAP_sys_mmHg'}
            model_field(idx) = "PAP_max";
            tier(idx) = "soft_secondary_guard";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Measured pulmonary waveform guard.";
        case {'PAP_dia_mmHg'}
            model_field(idx) = "PAP_min";
            tier(idx) = "soft_secondary_guard";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Measured pulmonary waveform guard.";
        case {'PAP_mean_mmHg'}
            model_field(idx) = "PAP_mean";
            tier(idx) = "hard_primary";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Primary pulmonary pressure-load calibration target.";
        case {'LAP_mean_mmHg'}
            model_field(idx) = "LAP_mean";
            tier(idx) = "hard_primary";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Primary left-sided filling-pressure calibration target.";
        case {'QpQs'}
            model_field(idx) = "QpQs";
            tier(idx) = "hard_primary";
            include_gsa(idx) = true;
            include_calibration(idx) = true;
            role(idx) = "Primary ASD shunt-severity calibration target.";
        case {'Q_ASD_Lmin'}
            model_field(idx) = "Q_ASD_Lmin";
            tier(idx) = "soft_secondary_derived_comparison";
            include_gsa(idx) = true;
            include_calibration(idx) = false;
            role(idx) = "Derived shunt comparison from model; no direct measured shunt flow.";
        case {'Q_ASD_mean_mLs'}
            model_field(idx) = "Q_ASD_mean_mLs";
            tier(idx) = "derived_prediction_only";
            role(idx) = "ODE-unit duplicate of Q_ASD_Lmin for unit transparency.";
        case {'ASD_direction'}
            model_field(idx) = "ASD_direction";
            tier(idx) = "qualitative_validity_guard";
            role(idx) = "Qualitative shunt direction validity check.";
        case {'RAP_mean_mmHg', 'SVR_WU', 'PVR_WU', 'RVP_mean_mmHg', ...
                'DeltaP_LA_RA_mmHg'}
            model_field(idx) = string(metric_name);
            tier(idx) = "prediction_only_discussion";
            role(idx) = "Model prediction for physiological discussion; no direct fitting target.";
        case {'LV_SV_mL', 'RV_SV_mL', 'LVEF', 'RVEF', ...
                'LVEDV_mL', 'LVESV_mL', 'RVEDV_mL', 'RVESV_mL'}
            model_field(idx) = string(metric_name);
            tier(idx) = "prediction_only_missing_volume_function";
            role(idx) = "Model prediction; Patient Z pre-closure volume/function targets are missing.";
        otherwise
            model_field(idx) = string(metric_name);
            tier(idx) = "review_required";
            role(idx) = "No governance rule registered.";
    end
end
end
