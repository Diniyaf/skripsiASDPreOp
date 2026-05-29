function output = run_healthy_baseline_set(n_runs)
% RUN_HEALTHY_BASELINE_SET
% -------------------------------------------------------------------------
% Runs the active healthy closed-shunt baseline set:
% adult reference, original Hafiz/Keisya pediatric reference child, and
% Zoya pediatric reference patient.
%
% INPUTS:
%   n_runs - number of repeated forward runs for reproducibility testing [-]
%
% OUTPUTS:
%   output - struct with:
%       .wide_table              one-row-per-metric baseline table
%       .long_table              one-row-per-run/case/metric table
%       .reproducibility_table   max run-to-run difference summary
%       .case_table              case demographics and HR handling
%       .scaling_table           scaling factors and HR values
%       .shunt_table             closed-shunt proof values
%       .assumptions_table       source and interpretation notes
%
% ASSUMPTIONS:
%   - Healthy baseline keeps the septal shunt absent/effectively closed
%     through default_parameters.m, with params.R.asd = Inf.
%   - Zoya ASD disease fields are intentionally ignored here; only
%     patient_zoya().common is used for healthy baseline scaling.
%   - This helper does not implement ASD disease simulation, GSA, or
%     optimization.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-28
% VERSION:  2.0
% -------------------------------------------------------------------------

if nargin < 1 || isempty(n_runs)
    n_runs = 1;
end
n_runs = max(1, round(n_runs));

metric_specs = get_metric_specs();
case_defs = get_case_definitions();
results = cell(n_runs, numel(case_defs));

long_rows = {};
for run_idx = 1:n_runs
    params_ref = default_parameters();
    for case_idx = 1:numel(case_defs)
        result = run_one_case(params_ref, case_defs(case_idx));
        results{run_idx, case_idx} = result;
        for metric_idx = 1:numel(metric_specs)
            value = extract_metric_value(result, metric_specs(metric_idx));
            long_rows(end + 1, :) = { ...
                run_idx, ...
                case_defs(case_idx).name, ...
                case_defs(case_idx).patient_label, ...
                case_defs(case_idx).scaling_mode, ...
                result.HR_handling, ...
                result.scaled_HR_bpm, ...
                result.final_HR_bpm, ...
                metric_specs(metric_idx).name, ...
                metric_specs(metric_idx).unit, ...
                value, ...
                result.ss_reached, ...
                metric_specs(metric_idx).source}; %#ok<AGROW>
        end
    end
end

long_table = cell2table(long_rows, 'VariableNames', { ...
    'Run_Index', 'Case_Name', 'Patient_Label', 'Scaling_Mode', ...
    'HR_Handling', 'Scaled_HR_bpm', 'Final_HR_bpm', ...
    'Metric', 'Unit', 'Value', 'Steady_State_Reached', 'Metric_Source'});

run1_results = results(1, :);

output = struct();
output.case_defs = case_defs;
output.results = results;
output.long_table = long_table;
output.wide_table = build_wide_table(long_table, metric_specs, case_defs, 1);
output.reproducibility_table = build_reproducibility_table(long_table, metric_specs, case_defs);
output.case_table = build_case_table(run1_results, case_defs);
output.scaling_table = build_scaling_table(run1_results, case_defs);
output.shunt_table = build_shunt_table(run1_results, case_defs);
output.assumptions_table = build_assumptions_table(n_runs);
end

% RUN_ONE_CASE - prepare params, integrate, compute metrics.
function result = run_one_case(params_ref, case_def)
if strcmp(case_def.scaling_mode, 'adult_ref')
    params = recompute_timing_params(params_ref);
    scaled_HR_bpm = params.HR;                   % [bpm]
    final_HR_bpm = params.HR;                    % [bpm]
    HR_handling = 'adult_reference';
else
    patient = case_def.patient;
    patient.scaling_mode = case_def.scaling_mode;
    evalc('params = apply_scaling(params_ref, patient);');

    scaled_HR_bpm = params.HR;                   % [bpm]
    final_HR_bpm = params.HR;                    % [bpm]
    HR_handling = ['scaled_by_' case_def.scaling_mode];

    if case_def.use_clinical_HR && isfield(patient, 'HR_clinical_bpm') && ...
            isfinite(patient.HR_clinical_bpm)
        final_HR_bpm = patient.HR_clinical_bpm;  % [bpm]
        params.HR = final_HR_bpm;
        params = recompute_timing_params(params);
        HR_handling = 'clinical_override_after_scaling';
    end
end

params.baseline.case_name = case_def.name;
params.baseline.patient_label = case_def.patient_label;
params.baseline.scaling_mode = case_def.scaling_mode;
params.baseline.HR_handling = HR_handling;
params.baseline.scaled_HR_bpm = scaled_HR_bpm;
params.baseline.final_HR_bpm = final_HR_bpm;
params.baseline.ASD_disease_fields_used = false;

sim = integrate_system(params);
metrics = compute_clinical_indices(sim, params);

result = struct();
result.params = params;
result.metrics = metrics;
result.ss_reached = sim.ss_reached;
result.HR_handling = HR_handling;
result.scaled_HR_bpm = scaled_HR_bpm;
result.final_HR_bpm = final_HR_bpm;
end

% RECOMPUTE_TIMING_PARAMS - compute absolute timing fields from current HR.
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

function case_defs = get_case_definitions()
reyna_patient = reference_reyna();
zoya_clinical = patient_zoya();
zoya_patient = clinical_to_scaling_patient(zoya_clinical, 'Zoya_ReferencePatient');

case_defs = repmat(empty_case_def(), 1, 5);
case_defs(1) = make_case_def('Adult_ref', 'adult_ref', ...
    'Adult_Reference', struct(), false);
case_defs(2) = make_case_def('Zhang_ReynaReferenceChild', 'zhang', ...
    reyna_patient.label, reyna_patient, false);
case_defs(3) = make_case_def('Lundquist_ReynaReferenceChild', 'lundquist_bsa', ...
    reyna_patient.label, reyna_patient, false);
case_defs(4) = make_case_def('Zhang_Zoya', 'zhang', ...
    zoya_patient.label, zoya_patient, true);
case_defs(5) = make_case_def('Lundquist_Zoya', 'lundquist_bsa', ...
    zoya_patient.label, zoya_patient, true);
end

function case_def = empty_case_def()
case_def = struct('name', '', 'scaling_mode', '', 'patient_label', '', ...
    'patient', struct(), 'use_clinical_HR', false);
end

function case_def = make_case_def(name, scaling_mode, patient_label, patient, use_clinical_HR)
case_def = struct();
case_def.name = name;
case_def.scaling_mode = scaling_mode;
case_def.patient_label = patient_label;
case_def.patient = patient;
case_def.use_clinical_HR = use_clinical_HR;
end

function metric_specs = get_metric_specs()
names = { ...
    'Heart Rate'
    'Cardiac Output'
    'LV Stroke Volume'
    'RV Stroke Volume'
    'LVEF'
    'RVEF'
    'LVEDV'
    'LVESV'
    'RVEDV'
    'RVESV'
    'SVR'
    'PVR'
    'SBP'
    'DBP'
    'MAP'
    'PAP_sys'
    'PAP_dia'
    'PAP_mean'
    'LVESP'
    'LVEDP'
    'RVESP'
    'RVEDP'
    'LAP_mean'
    'RAP_mean'
    'PWP_mean'
    'Qp_Qs'};

units = { ...
    'bpm'
    'L/min'
    'mL'
    'mL'
    '%'
    '%'
    'mL'
    'mL'
    'mL'
    'mL'
    'WU'
    'WU'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    'mmHg'
    '-'};

fields = { ...
    'params.HR'
    'metrics.CO_Lmin'
    'metrics.LVSV'
    'metrics.RVSV'
    'metrics.LVEF'
    'metrics.RVEF'
    'metrics.LVEDV'
    'metrics.LVESV'
    'metrics.RVEDV'
    'metrics.RVESV'
    'metrics.SVR'
    'metrics.PVR'
    'metrics.SAP_max'
    'metrics.SAP_min'
    'metrics.SAP_mean'
    'metrics.PAP_max'
    'metrics.PAP_min'
    'metrics.PAP_mean'
    'metrics.LVP_max'
    'metrics.LVEDP'
    'metrics.RVP_max'
    'metrics.RVEDP'
    'metrics.LAP_mean'
    'metrics.RAP_mean'
    'metrics.PWP_mean'
    'metrics.QpQs'};

scales = [1 1 1 1 100 100 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1];
sources = repmat({'compute_clinical_indices.m current active definition'}, numel(names), 1);
sources{1} = 'params.HR after scaling and optional clinical HR override';

metric_specs = struct('name', names(:), 'unit', units(:), 'field', fields(:), ...
    'scale', num2cell(scales(:)), 'source', sources(:));
end

function value = extract_metric_value(result, spec)
parts = strsplit(spec.field, '.');
if strcmp(parts{1}, 'params')
    current = result.params;
else
    current = result.metrics;
end
for idx = 2:numel(parts)
    current = current.(parts{idx});
end
value = current * spec.scale;
end

function wide_table = build_wide_table(long_table, metric_specs, case_defs, run_idx)
Metric = string({metric_specs.name})';
Unit = string({metric_specs.unit})';
wide_table = table(Metric, Unit);

for case_idx = 1:numel(case_defs)
    case_name = case_defs(case_idx).name;
    wide_table.(case_name) = values_for_case(long_table, case_name, run_idx);
end
end

function values = values_for_case(long_table, case_name, run_idx)
mask = long_table.Run_Index == run_idx & strcmp(long_table.Case_Name, case_name);
values = long_table.Value(mask);
end

function reproducibility_table = build_reproducibility_table(long_table, metric_specs, case_defs)
rows = {};
for case_idx = 1:numel(case_defs)
    case_name = case_defs(case_idx).name;
    for metric_idx = 1:numel(metric_specs)
        metric_name = metric_specs(metric_idx).name;
        mask = strcmp(long_table.Case_Name, case_name) & strcmp(long_table.Metric, metric_name);
        values = long_table.Value(mask);
        baseline_value = values(1);
        diffs = values - baseline_value;
        max_abs_diff = max(abs(diffs));
        max_rel_diff_percent = 100 * max_abs_diff / max(abs(baseline_value), 1e-12);
        abs_tolerance = reproducibility_tolerance(metric_specs(metric_idx).unit);
        within_tolerance = max_abs_diff <= abs_tolerance;
        rows(end + 1, :) = { ...
            case_name, metric_name, metric_specs(metric_idx).unit, ...
            baseline_value, max_abs_diff, max_rel_diff_percent, ...
            abs_tolerance, within_tolerance}; %#ok<AGROW>
    end
end

reproducibility_table = cell2table(rows, 'VariableNames', { ...
    'Case_Name', 'Metric', 'Unit', 'Run1_Value', 'Max_Abs_Diff', ...
    'Max_Rel_Diff_Percent', 'Abs_Tolerance', 'Within_Tolerance'});
end

function tolerance = reproducibility_tolerance(unit)
switch char(unit)
    case {'L/min', 'mL', 'WU', 'mmHg', '%'}
        tolerance = 1e-6;
    case {'bpm', '-'}
        tolerance = 1e-8;
    otherwise
        tolerance = 1e-6;
end
end

function case_table = build_case_table(run1_results, case_defs)
rows = {};
for case_idx = 1:numel(case_defs)
    case_def = case_defs(case_idx);
    patient = case_def.patient;
    rows(end + 1, :) = { ...
        case_def.name, ...
        case_def.scaling_mode, ...
        case_def.patient_label, ...
        field_or_nan(patient, 'age_years'), ...
        field_or_nan(patient, 'weight_kg'), ...
        field_or_nan(patient, 'height_cm'), ...
        field_or_nan(patient, 'BSA'), ...
        field_or_string(patient, 'sex'), ...
        run1_results{case_idx}.HR_handling, ...
        run1_results{case_idx}.scaled_HR_bpm, ...
        field_or_nan(patient, 'HR_clinical_bpm'), ...
        run1_results{case_idx}.final_HR_bpm, ...
        false, ...
        true}; %#ok<AGROW>
end

case_table = cell2table(rows, 'VariableNames', { ...
    'Case_Name', 'Scaling_Mode', 'Patient_Label', 'Age_Years', ...
    'Weight_kg', 'Height_cm', 'BSA_m2', 'Sex', 'HR_Handling', ...
    'Scaled_HR_bpm', 'Clinical_HR_bpm', 'Final_HR_bpm', ...
    'ASD_Disease_Fields_Used', 'Healthy_Closed_Shunt'});
end

function scaling_table = build_scaling_table(run1_results, case_defs)
rows = {};
for case_idx = 1:numel(case_defs)
    result = run1_results{case_idx};
    params = result.params;
    scaling = struct();
    if isfield(params, 'scaling')
        scaling = params.scaling;
    end
    rows(end + 1, :) = { ...
        case_defs(case_idx).name, ...
        case_defs(case_idx).scaling_mode, ...
        case_defs(case_idx).patient_label, ...
        field_or_nan(scaling, 'BSA_ref'), ...
        field_or_nan(scaling, 'BSA_patient'), ...
        field_or_nan(scaling, 's'), ...
        field_or_nan(scaling, 'W_ref'), ...
        field_or_nan(scaling, 'w'), ...
        result.scaled_HR_bpm, ...
        field_or_nan(case_defs(case_idx).patient, 'HR_clinical_bpm'), ...
        result.final_HR_bpm, ...
        result.HR_handling}; %#ok<AGROW>
end

scaling_table = cell2table(rows, 'VariableNames', { ...
    'Case_Name', 'Scaling_Mode', 'Patient_Label', 'BSA_ref_m2', ...
    'BSA_patient_m2', 'BSA_scale_factor', 'Weight_ref_kg', ...
    'Weight_scale_factor', 'Scaled_HR_bpm', 'Clinical_HR_bpm', ...
    'Final_HR_bpm', 'HR_Handling'});
end

function shunt_table = build_shunt_table(run1_results, case_defs)
rows = {};
for case_idx = 1:numel(case_defs)
    metrics = run1_results{case_idx}.metrics;
    rows(end + 1, :) = { ...
        case_defs(case_idx).name, ...
        metrics.QpQs, ...
        field_or_nan(metrics, 'Q_ASD_mean_mLs'), ...
        field_or_nan(metrics, 'Q_ASD_Lmin'), ...
        field_or_string(metrics, 'ASD_direction'), ...
        abs(metrics.QpQs - 1.0) <= 0.05, ...
        abs(field_or_nan(metrics, 'Q_ASD_mean_mLs')) <= 1e-6}; %#ok<AGROW>
end

shunt_table = cell2table(rows, 'VariableNames', { ...
    'Case_Name', 'Qp_Qs', 'Q_ASD_mean_mLs', 'Q_ASD_Lmin', ...
    'ASD_Direction', 'Qp_Qs_Closed_Range', 'Q_ASD_Closed_Range'});
end

function assumptions_table = build_assumptions_table(n_runs)
Item = [
    "Purpose"
    "Number of repeated runs"
    "Adult baseline"
    "Original pediatric reference child"
    "Zoya pediatric reference patient"
    "Zoya ASD disease fields"
    "Zhang columns"
    "Lundquist columns"
    "Important caveat"
    "Folder policy"
    ];

Value = [
    "Check deterministic reproducibility of current active healthy closed-shunt baseline outputs."
    string(n_runs)
    "default_parameters.m plus adult timing fields computed from T_HB = 60 / HR."
    "config/reference_reyna.m: age_years=3.17, weight_kg=14.0, height_cm=98.0, BSA=sqrt(weight*height/3600)=0.6173419726 m^2."
    "config/patient_zoya.m clinical.common only: age_years=7.07, weight_kg=18.2, height_cm=119, BSA=0.788, HR=90."
    "Intentionally ignored during healthy baseline validation: ASD_diameter_mm, ASD_area_mm2, QpQs=3.79, and other scenario fields."
    "default_parameters.m transformed by apply_scaling.m with scaling_mode='zhang'."
    "default_parameters.m transformed by apply_scaling.m with scaling_mode='lundquist_bsa'."
    "LVEDP/RVEDP are reported at ventricular cycle onset after phase-aligned integration output."
    "Active workflow only; arsip/ is historical reference and is not used."
    ];

Source = [
    "User request, 2026-05-28."
    "tests/test_baseline_reproducibility.m."
    "config/default_parameters.m; tests/helpers/run_healthy_baseline_set.m."
    "config/reference_reyna.m."
    "config/patient_zoya.m; src/utils/clinical_to_scaling_patient.m."
    "src/utils/clinical_to_scaling_patient.m reads only clinical.common."
    "src/utils/apply_scaling.m; src/utils/apply_physiological_scaling.m."
    "src/utils/apply_scaling.m; src/utils/apply_physiological_scaling.m."
    "src/solvers/integrate_system.m; src/utils/compute_clinical_indices.m."
    "User instruction, 2026-05-27."
    ];

assumptions_table = table(Item, Value, Source);
end

function value = field_or_nan(src, field_name)
if isstruct(src) && isfield(src, field_name) && isnumeric(src.(field_name)) && ...
        isscalar(src.(field_name)) && isfinite(src.(field_name))
    value = src.(field_name);
else
    value = NaN;
end
end

function value = field_or_string(src, field_name)
if isstruct(src) && isfield(src, field_name)
    value = string(src.(field_name));
else
    value = "";
end
end
