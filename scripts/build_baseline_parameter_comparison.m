%% build_baseline_parameter_comparison.m
% BUILD_BASELINE_PARAMETER_COMPARISON
% -------------------------------------------------------------------------
% Builds a timestamped workbook/CSV export comparing all healthy baseline
% configurations:
%   1. Adult_ref
%   2. Zhang_ReynaReferenceChild
%   3. Lundquist_ReynaReferenceChild
%   4. Zhang_Zoya
%   5. Lundquist_Zoya
%
% This script is healthy-baseline only. Zoya ASD disease fields are not
% used, and the model remains closed-shunt/no-disease for every case.
%
% OUTPUTS:
%   results/tables/baseline_parameter_comparison_<timestamp>.xlsx
%   results/tables/baseline_parameter_comparison_<timestamp>_parameters_long.csv
%   results/tables/baseline_parameter_comparison_<timestamp>_clinical_output.csv
%   results/tables/baseline_parameter_comparison_<timestamp>_range_check.csv
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-28
% VERSION:  2.0
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
addpath(fullfile(project_root, 'tests', 'helpers'));

output_dir = fullfile(project_root, 'results', 'tables');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
base_name = ['baseline_parameter_comparison_' timestamp];
xlsx_file = fullfile(output_dir, [base_name '.xlsx']);
parameters_csv = fullfile(output_dir, [base_name '_parameters_long.csv']);
clinical_csv = fullfile(output_dir, [base_name '_clinical_output.csv']);
range_csv = fullfile(output_dir, [base_name '_range_check.csv']);

baseline_output = run_healthy_baseline_set(1);

parameter_tables = build_case_parameter_tables(baseline_output);
parameters_long = build_long_parameter_table(parameter_tables);
clinical_output = build_clinical_output_table(baseline_output);
range_check = build_range_check_table(baseline_output, clinical_output);
summary = build_summary_table(timestamp, xlsx_file, parameters_csv, ...
    clinical_csv, range_csv);
notes = build_notes_table();

writetable(summary, xlsx_file, 'Sheet', 'Summary');
writetable(baseline_output.case_table, xlsx_file, 'Sheet', 'Patient_Anthropometry');
writetable(baseline_output.scaling_table, xlsx_file, 'Sheet', 'Scaling_Factors');
writetable(parameter_tables.Adult_ref, xlsx_file, 'Sheet', 'Adult_ref');
writetable(parameter_tables.Zhang_ReynaReferenceChild, xlsx_file, ...
    'Sheet', 'Zhang_OriginalReferenceChild');
writetable(parameter_tables.Lundquist_ReynaReferenceChild, xlsx_file, ...
    'Sheet', 'Lundquist_OriginalRefChild');
writetable(parameter_tables.Zhang_Zoya, xlsx_file, 'Sheet', 'Zhang_Zoya');
writetable(parameter_tables.Lundquist_Zoya, xlsx_file, 'Sheet', 'Lundquist_Zoya');
writetable(clinical_output, xlsx_file, 'Sheet', 'Clinical_Output_Comparison');
writetable(range_check, xlsx_file, 'Sheet', 'Range_Check');
writetable(notes, xlsx_file, 'Sheet', 'Notes');

writetable(parameters_long, parameters_csv);
writetable(clinical_output, clinical_csv);
writetable(range_check, range_csv);

fprintf('Wrote workbook:\n  %s\n', xlsx_file);
fprintf('Wrote CSV exports:\n  %s\n  %s\n  %s\n', ...
    parameters_csv, clinical_csv, range_csv);
fprintf('\nClosed-shunt proof:\n');
disp(baseline_output.shunt_table);

% BUILD_CASE_PARAMETER_TABLES - flatten one parameter table per case.
function parameter_tables = build_case_parameter_tables(baseline_output)
parameter_tables = struct();
case_defs = baseline_output.case_defs;
for case_idx = 1:numel(case_defs)
    case_name = case_defs(case_idx).name;
    result = baseline_output.results{1, case_idx};
    parameter_tables.(case_name) = parameter_table_for_case(result.params, ...
        case_name, case_defs(case_idx));
end
end

function table_out = parameter_table_for_case(params, case_name, case_def)
rows = flatten_params(params, 'params');
n_rows = numel(rows);

Case_Name = strings(n_rows, 1);
Scaling_Mode = strings(n_rows, 1);
Patient_Label = strings(n_rows, 1);
Parameter_Name = strings(n_rows, 1);
Parameter_Group = strings(n_rows, 1);
Unit = strings(n_rows, 1);
Value = strings(n_rows, 1);
Source = strings(n_rows, 1);
Notes = strings(n_rows, 1);

for row_idx = 1:n_rows
    name = rows(row_idx).name;
    Case_Name(row_idx) = string(case_name);
    Scaling_Mode(row_idx) = string(case_def.scaling_mode);
    Patient_Label(row_idx) = string(case_def.patient_label);
    Parameter_Name(row_idx) = string(name);
    Parameter_Group(row_idx) = parameter_group(name);
    Unit(row_idx) = parameter_unit(name);
    Value(row_idx) = string(rows(row_idx).value);
    Source(row_idx) = source_note(name, case_name, case_def);
    Notes(row_idx) = parameter_note(name, case_name);
end

table_out = table(Case_Name, Scaling_Mode, Patient_Label, Parameter_Name, ...
    Parameter_Group, Unit, Value, Source, Notes);
end

function parameters_long = build_long_parameter_table(parameter_tables)
case_names = fieldnames(parameter_tables);
parameters_long = table();
for case_idx = 1:numel(case_names)
    parameters_long = [parameters_long; parameter_tables.(case_names{case_idx})]; %#ok<AGROW>
end
end

function clinical_output = build_clinical_output_table(baseline_output)
clinical_output = baseline_output.wide_table;

case_defs = baseline_output.case_defs;
extra_metric = [
    "Q_ASD_mean_mLs"
    "Q_ASD_Lmin"
    "ASD_direction_code"
    ];
extra_unit = [
    "mL/s"
    "L/min"
    "-"];

extra_rows = table(extra_metric, extra_unit, ...
    'VariableNames', {'Metric', 'Unit'});
for case_idx = 1:numel(case_defs)
    result = baseline_output.results{1, case_idx};
    metrics = result.metrics;
    direction_code = direction_to_code(field_or_string(metrics, 'ASD_direction'));
    extra_rows.(case_defs(case_idx).name) = [
        field_or_nan(metrics, 'Q_ASD_mean_mLs')
        field_or_nan(metrics, 'Q_ASD_Lmin')
        direction_code
        ];
end

clinical_output = [clinical_output; extra_rows];
end

function range_check = build_range_check_table(baseline_output, clinical_output)
rows = {};
case_names = baseline_output.wide_table.Properties.VariableNames(3:end);

for case_idx = 1:numel(case_names)
    case_name = case_names{case_idx};
    rows = add_check_row(rows, clinical_output, case_name, ...
        'Qp_Qs', '-', 0.95, 1.05, ...
        'Closed healthy circulation expectation.', ...
        'Applies to all healthy no-shunt baseline cases.');
    rows = add_check_row(rows, clinical_output, case_name, ...
        'Q_ASD_mean_mLs', 'mL/s', -1e-6, 1e-6, ...
        'Closed ASD baseline numerical tolerance.', ...
        'Applies to all healthy no-shunt baseline cases.');

    if strcmp(case_name, 'Adult_ref')
        rows = add_check_row(rows, clinical_output, case_name, ...
            'Heart Rate', 'bpm', 65, 85, ...
            'tests/test_baseline.m adult healthy reference range.', ...
            'Adult-only range.');
        rows = add_check_row(rows, clinical_output, case_name, ...
            'SBP', 'mmHg', 100, 140, ...
            'tests/test_baseline.m adult healthy reference range.', ...
            'Adult-only range.');
        rows = add_check_row(rows, clinical_output, case_name, ...
            'DBP', 'mmHg', 60, 90, ...
            'tests/test_baseline.m adult healthy reference range.', ...
            'Adult-only range.');
        rows = add_check_row(rows, clinical_output, case_name, ...
            'MAP', 'mmHg', 70, 100, ...
            'tests/test_baseline.m adult healthy reference range.', ...
            'Adult-only range.');
        rows = add_check_row(rows, clinical_output, case_name, ...
            'LVEF', '%', 55, 75, ...
            'tests/test_baseline.m adult healthy reference range.', ...
            'Adult-only range.');
        rows = add_check_row(rows, clinical_output, case_name, ...
            'PAP_mean', 'mmHg', 10, 20, ...
            'tests/test_baseline.m adult healthy reference range.', ...
            'Adult-only range.');
        rows = add_check_row(rows, clinical_output, case_name, ...
            'RAP_mean', 'mmHg', 0, 8, ...
            'tests/test_baseline.m adult healthy reference range.', ...
            'Adult-only range.');
    else
        rows(end + 1, :) = {case_name, 'Pediatric normal range', NaN, '-', ...
            NaN, NaN, 'N/A', 'Not encoded', ...
            'Age-specific pediatric normal ranges are not asserted in this export.'}; %#ok<AGROW>
    end
end

range_check = cell2table(rows, 'VariableNames', { ...
    'Case_Name', 'Metric', 'Value', 'Unit', 'Lower_Bound', 'Upper_Bound', ...
    'Check_Status', 'Range_Source', 'Note'});
end

function rows = add_check_row(rows, clinical_output, case_name, metric, unit, lo, hi, source, note)
value = value_for_metric(clinical_output, case_name, metric);
if isnan(value)
    status = 'N/A';
elseif value >= lo && value <= hi
    status = 'PASS';
else
    status = 'OUT_OF_RANGE';
end
rows(end + 1, :) = {case_name, metric, value, unit, lo, hi, status, source, note}; %#ok<AGROW>
end

function value = value_for_metric(clinical_output, case_name, metric)
mask = strcmp(clinical_output.Metric, metric);
if any(mask) && ismember(case_name, clinical_output.Properties.VariableNames)
    value = clinical_output.(case_name)(find(mask, 1, 'first'));
else
    value = NaN;
end
end

function summary = build_summary_table(timestamp, xlsx_file, parameters_csv, clinical_csv, range_csv)
Item = [
    "Generated timestamp"
    "Workbook"
    "Parameter CSV"
    "Clinical output CSV"
    "Range check CSV"
    "Workflow phase"
    "Healthy baseline state"
    "Original reference child"
    "Zoya reference patient"
    "ASD disease fields"
    "GSA/optimization"
    ];

Value = [
    string(timestamp)
    string(xlsx_file)
    string(parameters_csv)
    string(clinical_csv)
    string(range_csv)
    "Healthy baseline validation only."
    "Closed shunt/no disease: params.R.asd = Inf; Q_ASD expected approximately zero."
    "Preserved in config/reference_reyna.m and reported beside Zoya."
    "Loaded from config/patient_zoya.m clinical.common only."
    "Ignored: ASD_diameter_mm, ASD_area_mm2, QpQs=3.79, and all scenario fields."
    "Not run."
    ];

summary = table(Item, Value);
end

function notes = build_notes_table()
Item = [
    "Sheet name note"
    "HR handling"
    "Pediatric range checks"
    "Disease model boundary"
    ];

Value = [
    "Excel sheet name limit is 31 characters; Lundquist_OriginalReferenceChild is exported as Lundquist_OriginalRefChild."
    "Original reference child uses scaled HR. Zoya uses scaling first, then clinical.common.HR=90 as explicit clinical override; scaled HR remains reported."
    "Only closed-shunt checks are asserted for pediatric cases; age-specific pediatric normal ranges require a separate cited validation table."
    "No ASD disease simulation, GSA, optimization, or post-closure modeling is performed by this script."
    ];

notes = table(Item, Value);
end

% FLATTEN_PARAMS - convert nested parameter struct into name/value rows.
function rows = flatten_params(value, prefix)
rows = struct('name', {}, 'value', {});
rows = flatten_value(rows, value, prefix);
end

function rows = flatten_value(rows, value, prefix)
if isstruct(value)
    fields = fieldnames(value);
    for k = 1:numel(fields)
        child_name = [prefix '.' fields{k}];
        rows = flatten_value(rows, value.(fields{k}), child_name);
    end
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        rows(end + 1).name = prefix; %#ok<AGROW>
        rows(end).value = scalar_to_string(value);
    elseif strcmp(prefix, 'params.ic.V') && numel(value) == 14
        state_names = {'V_RA','V_RV','V_LA','V_LV','V_SAR','Q_SAR','V_SC', ...
            'V_SVEN','Q_SVEN','V_PAR','Q_PAR','P_PC','V_PVEN','Q_PVEN'};
        flat_value = value(:);
        for k = 1:numel(flat_value)
            rows(end + 1).name = [prefix '.' state_names{k}]; %#ok<AGROW>
            rows(end).value = scalar_to_string(flat_value(k));
        end
    else
        flat_value = value(:);
        for k = 1:numel(flat_value)
            rows(end + 1).name = sprintf('%s(%d)', prefix, k); %#ok<AGROW>
            rows(end).value = scalar_to_string(flat_value(k));
        end
    end
elseif ischar(value) || isstring(value)
    rows(end + 1).name = prefix; %#ok<AGROW>
    rows(end).value = char(string(value));
else
    rows(end + 1).name = prefix; %#ok<AGROW>
    rows(end).value = ['<' class(value) '>'];
end
end

function text = scalar_to_string(value)
if islogical(value)
    text = char(string(value));
elseif isnumeric(value) && isnan(value)
    text = 'NaN';
elseif isnumeric(value) && isinf(value)
    if value > 0
        text = 'Inf';
    else
        text = '-Inf';
    end
else
    text = sprintf('%.15g', value);
end
end

function group = parameter_group(name)
if startsWith(name, 'params.idx.')
    group = "State index";
elseif startsWith(name, 'params.sim.')
    group = "Solver control";
elseif startsWith(name, 'params.conv.')
    group = "Unit conversion";
elseif startsWith(name, 'params.asd.') || strcmp(name, 'params.R.asd') || contains(name, 'epsilon_asd')
    group = "Closed ASD shunt setting";
elseif startsWith(name, 'params.vsd.') || strcmp(name, 'params.R.vsd') || contains(name, 'epsilon_vsd')
    group = "Legacy closed VSD setting";
elseif startsWith(name, 'params.V0.')
    group = "Unstressed volume";
elseif startsWith(name, 'params.C.')
    group = "Compliance";
elseif startsWith(name, 'params.E.')
    group = "Elastance";
elseif startsWith(name, 'params.Rvalve.')
    group = "Valve resistance";
elseif startsWith(name, 'params.R.')
    group = "Resistance";
elseif startsWith(name, 'params.L.')
    group = "Inertance";
elseif startsWith(name, 'params.ic.V.')
    group = "Initial condition";
elseif startsWith(name, 'params.scaling.')
    group = "Scaling metadata";
elseif startsWith(name, 'params.baseline.')
    group = "Baseline metadata";
elseif contains(name, 'Tc_') || contains(name, 'Tr_') || contains(name, 't_ac_') || contains(name, 't_ar_')
    group = "Timing";
elseif startsWith(name, 'params.calibration.')
    group = "Calibration control";
elseif startsWith(name, 'params.maturation.')
    group = "Maturation metadata";
else
    group = "General";
end
end

function unit = parameter_unit(name)
if strcmp(name, 'params.HR') || contains(name, 'HR_bpm')
    unit = "bpm";
elseif contains(name, 'rtol') || contains(name, 'atol') || contains(name, 'ss_rtol') || ...
        contains(name, 'mode') || contains(name, 'sex') || startsWith(name, 'params.idx.') || ...
        startsWith(name, 'params.scaling.') || startsWith(name, 'params.baseline.') || ...
        startsWith(name, 'params.calibration.')
    unit = "-";
elseif contains(name, 'nCycles')
    unit = "cardiac cycles";
elseif contains(name, 'batch_size')
    unit = "cardiac cycles/batch";
elseif contains(name, 'epsilon') || contains(name, 'gradient_mmHg') || ...
        contains(name, 'ss_tol_P')
    unit = "mmHg";
elseif contains(name, 'ss_tol_V')
    unit = "mL";
elseif contains(name, 'area_mm2')
    unit = "mm^2";
elseif contains(name, 'diameter_mm')
    unit = "mm";
elseif contains(name, 'rho_blood')
    unit = "kg/m^3";
elseif startsWith(name, 'params.V0.') || contains(name, '.V_RA') || contains(name, '.V_RV') || ...
        contains(name, '.V_LA') || contains(name, '.V_LV') || contains(name, '.V_SAR') || ...
        contains(name, '.V_SC') || contains(name, '.V_SVEN') || contains(name, '.V_PAR') || ...
        contains(name, '.V_PVEN')
    unit = "mL";
elseif contains(name, '.Q_')
    unit = "mL/s";
elseif contains(name, '.P_PC')
    unit = "mmHg";
elseif startsWith(name, 'params.C.')
    unit = "mL/mmHg";
elseif startsWith(name, 'params.E.')
    unit = "mmHg/mL";
elseif startsWith(name, 'params.R.') || startsWith(name, 'params.Rvalve.')
    unit = "mmHg*s/mL";
elseif startsWith(name, 'params.L.')
    unit = "mmHg*s^2/mL";
elseif endsWith(name, '_frac')
    unit = "fraction of cardiac cycle";
elseif contains(name, 'Tc_') || contains(name, 'Tr_') || contains(name, 't_ac_') || contains(name, 't_ar_')
    unit = "s";
elseif contains(name, 'BSA')
    unit = "m^2";
elseif contains(name, 'weight_kg')
    unit = "kg";
elseif contains(name, 'height_cm')
    unit = "cm";
elseif contains(name, 'age_years')
    unit = "years";
elseif contains(name, 'age_days')
    unit = "days";
else
    unit = "-";
end
end

function source = source_note(name, case_name, case_def)
if strcmp(case_name, 'Adult_ref')
    if is_adult_computed_timing(name)
        source = "Computed from config/default_parameters.m HR and timing fractions.";
    else
        source = "config/default_parameters.m active adult reference parameter struct.";
    end
elseif strcmp(name, 'params.HR') && contains(case_name, 'Zoya')
    source = "Scaled by apply_scaling.m, then overridden by config/patient_zoya.m clinical.common.HR.";
else
    source = pediatric_source_note(name, case_def);
end
end

function yes = is_adult_computed_timing(name)
yes = (contains(name, 'params.Tc_') || contains(name, 'params.Tr_') || ...
    contains(name, 'params.t_ac_') || contains(name, 'params.t_ar_')) && ...
    ~endsWith(name, '_frac');
end

function source = pediatric_source_note(name, case_def)
if contains(case_def.name, 'Zhang')
    scaling_label = "Zhang weight allometry";
else
    scaling_label = "Lundquist BSA allometry";
end
patient_source = string(case_def.patient_label);

if startsWith(name, 'params.ic.V.')
    source = sprintf("src/utils/build_initial_conditions.m after %s; patient=%s.", ...
        scaling_label, patient_source);
elseif strcmp(name, 'params.V0.SVEN') || contains(name, 'V0_SVEN')
    source = sprintf("src/utils/apply_scaling.m vascular V0 reconciliation after %s; patient=%s.", ...
        scaling_label, patient_source);
elseif startsWith(name, 'params.scaling.')
    source = sprintf("src/utils/apply_scaling.m and apply_physiological_scaling.m metadata for %s; patient=%s.", ...
        scaling_label, patient_source);
elseif is_scaled_physiology(name)
    source = sprintf("config/default_parameters.m transformed by apply_physiological_scaling.m using %s; patient=%s.", ...
        scaling_label, patient_source);
else
    source = sprintf("Inherited from config/default_parameters.m unless overwritten by apply_scaling.m; patient=%s.", ...
        patient_source);
end
end

function yes = is_scaled_physiology(name)
yes = strcmp(name, 'params.HR') || startsWith(name, 'params.E.') || ...
    startsWith(name, 'params.C.') || startsWith(name, 'params.R.') || ...
    startsWith(name, 'params.L.') || startsWith(name, 'params.V0.') || ...
    startsWith(name, 'params.Rvalve.open') || ...
    contains(name, 'params.Tc_') || contains(name, 'params.Tr_') || ...
    contains(name, 'params.t_ac_') || contains(name, 'params.t_ar_');
end

function note = parameter_note(name, case_name)
if startsWith(name, 'params.scaling.patient.')
    note = "Input demographic metadata used for pediatric scaling, not a solved hemodynamic output.";
elseif startsWith(name, 'params.idx.')
    note = "State vector index; included for reproducibility but not a physiological parameter.";
elseif startsWith(name, 'params.ic.V.')
    note = "Initial condition used by the ODE solver before warm-up to steady state.";
elseif startsWith(name, 'params.asd.') || strcmp(name, 'params.R.asd')
    note = "Healthy baseline keeps ASD absent/closed; disease fields are intentionally ignored.";
elseif startsWith(name, 'params.vsd.') || strcmp(name, 'params.R.vsd')
    note = "Legacy VSD metadata retained for old utilities; active ASD RHS does not use LV-RV coupling.";
elseif strcmp(name, 'params.HR') && contains(case_name, 'Zoya')
    note = "Final HR uses Zoya clinical.common.HR after scaling; scaled HR is separately reported in Scaling_Factors.";
else
    note = "";
end
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

function code = direction_to_code(direction)
if strcmp(direction, 'LA_to_RA')
    code = 1;
elseif strcmp(direction, 'RA_to_LA')
    code = -1;
else
    code = 0;
end
end
