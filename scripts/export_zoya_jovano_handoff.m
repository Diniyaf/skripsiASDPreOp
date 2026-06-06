%% export_zoya_jovano_handoff.m
% EXPORT_ZOYA_JOVANO_HANDOFF
% -------------------------------------------------------------------------
% Build a reproducible handoff package from Diniya's accepted Zoya
% pre-closure ASD operating point for Jovano's post-closure workflow.
%
% This script does not run simulation, GSA, optimization, or post-closure
% logic. It only loads the accepted calibration package, exports a complete
% seed struct, and writes documentation tables that make parameter meaning
% and non-equivalent mappings explicit.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-06
% VERSION:  1.0
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(project_root);

source_mat = fullfile(project_root, 'results', 'calibration', ...
    'zoya_asd_calib_20260602_011418', ...
    'zoya_asd_calibration_20260602_011418.mat');
if ~exist(source_mat, 'file')
    error('export_zoya_jovano_handoff:missingSource', ...
        'Accepted Zoya calibration MAT not found: %s', source_mat);
end

S = load(source_mat, 'pkg');
pkg = S.pkg;
params = pkg.accepted_params;
metrics = pkg.accepted_metrics;

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
handoff_dir = fullfile(project_root, 'results', 'calibration', ...
    sprintf('zoya_jovano_handoff_%s', timestamp));
if ~exist(handoff_dir, 'dir')
    mkdir(handoff_dir);
end

%% Build complete seed struct
seed_zoya = struct();
seed_zoya.patient = 'Zoya';
seed_zoya.scenario = 'pre_surgery';
seed_zoya.closure_state = 'pre_closure_open_ASD';
seed_zoya.params = params;
seed_zoya.metrics = metrics;
seed_zoya.ic = get_initial_condition_vector(params);
seed_zoya.accepted_rmse = safe_pkg_field(pkg, 'accepted_rmse', NaN);
seed_zoya.baseline_rmse = safe_pkg_field(pkg, 'baseline_rmse', NaN);
seed_zoya.accepted_label = safe_pkg_field(pkg, 'accepted_label', 'accepted_candidate');
seed_zoya.source = 'Zoya v4 accepted pre-closure ASD operating point (atrial expansion)';
seed_zoya.source_mat = source_mat;
seed_zoya.export_timestamp = timestamp;
seed_zoya.export_date = char(datetime('today', 'Format', 'yyyy-MM-dd'));
seed_zoya.target_tiers = safe_pkg_field(pkg, 'target_tiers', table());
seed_zoya.caseProfile = safe_pkg_field(pkg, 'caseProfile', struct());
seed_zoya.sign_convention = 'Q_ASD > 0 means LA_to_RA left-to-right atrial shunt.';
seed_zoya.mapping_warning = ['Diniya and Jovano use different state vectors, ', ...
    'parameter namespaces, and elastance parameterizations. Use the mapping ', ...
    'table as an adapter guide, not as blind direct-copy instructions.'];

canonical_seed = fullfile(project_root, 'results', 'calibration', ...
    'zoya_pre_to_post_seed.mat');
timestamped_seed = fullfile(handoff_dir, ...
    sprintf('zoya_pre_to_post_seed_%s.mat', timestamp));
save(canonical_seed, 'seed_zoya');
save(timestamped_seed, 'seed_zoya');

%% Export tables and README
metrics_table = build_metrics_table(metrics);
mapping_table = build_parameter_mapping_table(params);

metrics_csv = fullfile(handoff_dir, sprintf('zoya_pre_metrics_%s.csv', timestamp));
mapping_csv = fullfile(handoff_dir, sprintf('diniya_to_jovano_parameter_mapping_%s.csv', timestamp));
readme_path = fullfile(handoff_dir, sprintf('README_zoya_jovano_handoff_%s.md', timestamp));

writetable(metrics_table, metrics_csv);
writetable(mapping_table, mapping_csv);
write_handoff_readme(readme_path, seed_zoya, metrics_csv, mapping_csv, timestamped_seed);
copy_source_artifacts(source_mat, handoff_dir);

fprintf('Zoya-Jovano handoff exported.\n');
fprintf('  Canonical seed: %s\n', canonical_seed);
fprintf('  Handoff folder: %s\n', handoff_dir);
fprintf('  Timestamped seed: %s\n', timestamped_seed);
fprintf('  Metrics CSV: %s\n', metrics_csv);
fprintf('  Mapping CSV: %s\n', mapping_csv);
fprintf('  README: %s\n', readme_path);

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function value = safe_pkg_field(pkg, field_name, fallback)
% SAFE_PKG_FIELD - read package field with fallback.
if isstruct(pkg) && isfield(pkg, field_name)
    value = pkg.(field_name);
else
    value = fallback;
end
end

function ic = get_initial_condition_vector(params)
% GET_INITIAL_CONDITION_VECTOR - return Diniya state vector seed when present.
ic = [];
if isfield(params, 'ic')
    if isstruct(params.ic) && isfield(params.ic, 'V')
        ic = params.ic.V(:);
    elseif isnumeric(params.ic)
        ic = params.ic(:);
    end
end
end

function T = build_metrics_table(metrics)
% BUILD_METRICS_TABLE - one row per scalar metric in accepted output.
names = fieldnames(metrics);
metric = strings(0, 1);
value = strings(0, 1);
unit = strings(0, 1);
notes = strings(0, 1);

for i = 1:numel(names)
    raw_value = metrics.(names{i});
    if ~(isnumeric(raw_value) && isscalar(raw_value))
        continue;
    end
    metric(end + 1, 1) = string(names{i}); %#ok<AGROW>
    value(end + 1, 1) = string(format_value(raw_value)); %#ok<AGROW>
    unit(end + 1, 1) = string(infer_metric_unit(names{i})); %#ok<AGROW>
    notes(end + 1, 1) = "Accepted Diniya pre-closure model output"; %#ok<AGROW>
end

T = table(metric, value, unit, notes, ...
    'VariableNames', {'Metric','Value','Unit','Notes'});
end

function T = build_parameter_mapping_table(params)
% BUILD_PARAMETER_MAPPING_TABLE - Diniya-to-Jovano adapter guidance.
rows = {};

chambers = {'LV','RV','LA','RA'};
lower_names = {'lv','rv','la','ra'};
for i = 1:numel(chambers)
    ch = chambers{i};
    jov = lower_names{i};
    EA = get_param(params, sprintf('E.%s.EA', ch));
    EB = get_param(params, sprintf('E.%s.EB', ch));
    V0 = get_param(params, sprintf('V0.%s', ch));

    rows = add_row(rows, sprintf('E.%s.EA + E.%s.EB', ch, ch), ...
        format_value(EA + EB), 'mmHg/mL', sprintf('Emax_%s', jov), ...
        format_value(EA + EB), 'Emax = EA + EB', 'adapter_formula_only', ...
        sprintf('Diniya uses E(t)=EA*e(t)+EB. Jovano uses E(t)=Emin+(Emax-Emin)*e(t). EA=%s, EB=%s.', ...
        format_value(EA), format_value(EB)));
    rows = add_row(rows, sprintf('E.%s.EB', ch), format_value(EB), ...
        'mmHg/mL', sprintf('Emin_%s', jov), format_value(EB), ...
        'Emin = EB', 'adapter_formula_only', ...
        'Do not map EA directly to Emax; EA is the active amplitude above baseline.');
    rows = add_row(rows, sprintf('V0.%s', ch), format_value(V0), ...
        'mL', sprintf('V0_%s', jov), format_value(V0), ...
        'direct concept, different state vector', 'conceptual_mapping', ...
        'Unstressed volume has matching physiological meaning, but Jovano should re-check post-closure volume targets.');
end

vascular_map = {
    'R.SAR',  'R_sa',  'mmHg*s/mL', 'systemic arterial resistance';
    'R.SC',   'R_sc',  'mmHg*s/mL', 'systemic capillary resistance';
    'R.SVEN', 'R_sv',  'mmHg*s/mL', 'systemic venous resistance';
    'C.SAR',  'C_sa',  'mL/mmHg',   'systemic arterial compliance';
    'C.SC',   'C_sc',  'mL/mmHg',   'systemic capillary compliance';
    'C.SVEN', 'C_sv',  'mL/mmHg',   'systemic venous compliance';
    'L.SAR',  'L_sa',  'mmHg*s^2/mL', 'systemic arterial inertance';
    'L.SVEN', 'L_sv',  'mmHg*s^2/mL', 'systemic venous inertance';
    'R.PAR',  'R_pa',  'mmHg*s/mL', 'pulmonary arterial resistance';
    'R.PCOX', 'R_pc',  'mmHg*s/mL', 'oxygenated pulmonary capillary resistance';
    'R.PCNO', 'R_sh',  'mmHg*s/mL', 'non-oxygenated pulmonary capillary resistance';
    'R.PVEN', 'R_pv',  'mmHg*s/mL', 'pulmonary venous resistance';
    'C.PAR',  'C_pa',  'mL/mmHg',   'pulmonary arterial compliance';
    'C.PCOX', 'C_pc',  'mL/mmHg',   'oxygenated pulmonary capillary compliance';
    'C.PCNO', 'C_sh',  'mL/mmHg',   'non-oxygenated pulmonary capillary compliance';
    'C.PVEN', 'C_pv',  'mL/mmHg',   'pulmonary venous compliance';
    'L.PAR',  'L_pa',  'mmHg*s^2/mL', 'pulmonary arterial inertance';
    'L.PVEN', 'L_pv',  'mmHg*s^2/mL', 'pulmonary venous inertance';
    };

for i = 1:size(vascular_map, 1)
    diniya_field = vascular_map{i, 1};
    value = get_param(params, diniya_field);
    rows = add_row(rows, diniya_field, format_value(value), vascular_map{i, 3}, ...
        vascular_map{i, 2}, format_value(value), 'nearest named compartment', ...
        'conceptual_mapping', vascular_map{i, 4});
end

rows = add_row(rows, 'Rvalve.open', format_value(get_param(params, 'Rvalve.open')), ...
    'mmHg*s/mL', 'R_*_min', format_value(get_param(params, 'Rvalve.open')), ...
    'shared open valve resistance', 'conceptual_mapping', ...
    'Jovano has separate valve min fields; use only if maintaining Diniya valve convention.');
rows = add_row(rows, 'Rvalve.closed', format_value(get_param(params, 'Rvalve.closed')), ...
    'mmHg*s/mL', 'R_*_max', format_value(get_param(params, 'Rvalve.closed')), ...
    'shared closed valve resistance', 'conceptual_mapping', ...
    'Jovano has separate valve max fields; use only if maintaining Diniya valve convention.');

rows = add_row(rows, 'asd.Cd', format_value(get_param(params, 'asd.Cd')), ...
    '-', 'R_ASD', '1e9 or Inf for post-closure', ...
    'not equivalent', 'do_not_direct_copy', ...
    'Diniya pre-closure orifice mode uses Cd and area; Jovano post-closure should close ASD with R_ASD=1e9/Inf.');
rows = add_row(rows, 'asd.area_mm2', format_value(get_param(params, 'asd.area_mm2')), ...
    'mm^2', 'R_ASD', '1e9 or Inf for post-closure', ...
    'not equivalent', 'do_not_direct_copy', ...
    'Area documents the pre-closure defect. It should not be used after closure except for traceability.');
rows = add_row(rows, 'R.asd', format_value(get_param(params, 'R.asd')), ...
    'mmHg*s/mL', 'R_ASD', '1e9 or Inf for post-closure', ...
    'mode-dependent', 'do_not_direct_copy', ...
    'In Diniya orifice mode R.asd is inactive. Jovano linear post-closure uses R_ASD as the closure knob.');
rows = add_row(rows, 'params.ic.V', 'see seed_zoya.ic', ...
    'mixed', 'X0', 'not direct index mapping', ...
    'different state vector', 'reference_only', ...
    'Diniya state vector is volume-based Valenti layout; Jovano mixes chamber volumes, vascular pressures, and flows.');

T = cell2table(rows, 'VariableNames', {'Diniya_Field','Diniya_Value', ...
    'Unit','Jovano_Field','Jovano_Adapter_Value','Mapping_Rule', ...
    'Transfer_Status','Notes'});
end

function rows = add_row(rows, diniya_field, diniya_value, unit, jovano_field, ...
    jovano_value, mapping_rule, transfer_status, notes)
% ADD_ROW - append one mapping row.
rows(end + 1, :) = {string(diniya_field), string(diniya_value), ...
    string(unit), string(jovano_field), string(jovano_value), ...
    string(mapping_rule), string(transfer_status), string(notes)};
end

function value = get_param(params, dotted_name)
% GET_PARAM - read nested struct value using dotted path.
parts = strsplit(dotted_name, '.');
value = params;
for i = 1:numel(parts)
    if isstruct(value) && isfield(value, parts{i})
        value = value.(parts{i});
    else
        value = NaN;
        return;
    end
end
if ~(isnumeric(value) && isscalar(value))
    value = NaN;
end
end

function text = format_value(value)
% FORMAT_VALUE - stable text formatting for numeric/nonfinite values.
if isnumeric(value) && isscalar(value)
    if isinf(value)
        text = 'Inf';
    elseif isnan(value)
        text = 'NaN';
    else
        text = sprintf('%.10g', value);
    end
elseif ischar(value) || isstring(value)
    text = char(string(value));
else
    text = 'not_scalar';
end
end

function unit = infer_metric_unit(metric_name)
% INFER_METRIC_UNIT - lightweight metric unit labelling.
name = lower(char(metric_name));
if contains(name, 'lmin')
    unit = 'L/min';
elseif contains(name, 'mmhg') || contains(name, 'mean') || contains(name, 'max') || contains(name, 'min')
    unit = 'mmHg';
elseif contains(name, 'edv') || contains(name, 'esv') || contains(name, 'sv_ml')
    unit = 'mL';
elseif contains(name, 'ef') || contains(name, 'qpqs')
    unit = '-';
elseif strcmp(name, 'hr')
    unit = 'bpm';
else
    unit = 'see model output table';
end
end

function write_handoff_readme(readme_path, seed_zoya, metrics_csv, mapping_csv, seed_file)
% WRITE_HANDOFF_README - human-readable handoff note for Jovano.
fid = fopen(readme_path, 'w');
if fid < 0
    error('export_zoya_jovano_handoff:cannotWriteReadme', ...
        'Cannot write README: %s', readme_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Zoya Pre-to-Post ASD Handoff Package\n\n');
fprintf(fid, 'Generated: %s\n\n', seed_zoya.export_timestamp);
fprintf(fid, '## Purpose\n\n');
fprintf(fid, ['This package transfers Diniya''s accepted Zoya pre-closure ASD ', ...
    'operating point to Jovano as a documented reference. It is not a ', ...
    'blind parameter-copy instruction because the two codebases use ', ...
    'different state vectors, parameter namespaces, and elastance equations.\n\n']);
fprintf(fid, '## Core Files\n\n');
fprintf(fid, '- Seed MAT: `%s`\n', seed_file);
fprintf(fid, '- Metrics CSV: `%s`\n', metrics_csv);
fprintf(fid, '- Parameter mapping CSV: `%s`\n\n', mapping_csv);
fprintf(fid, '## Accepted Pre-Closure Summary\n\n');
fprintf(fid, '- Patient: Zoya\n');
fprintf(fid, '- Scenario: pre_surgery / pre_closure\n');
fprintf(fid, '- Accepted label: `%s`\n', char(seed_zoya.accepted_label));
fprintf(fid, '- Accepted RMSE: %.6f\n', seed_zoya.accepted_rmse);
fprintf(fid, '- Baseline RMSE: %.6f\n', seed_zoya.baseline_rmse);
fprintf(fid, '- Source MAT: `%s`\n\n', seed_zoya.source_mat);
fprintf(fid, '## Critical Mapping Note: EA/EB vs Emax/Emin\n\n');
fprintf(fid, ['Diniya uses `E(t) = EA * e(t) + EB`, so `EB` is the ', ...
    'minimum/passive elastance and `EA` is the activation amplitude above ', ...
    'that baseline. Jovano uses `E(t) = Emin + (Emax - Emin) * e(t)`. ', ...
    'Therefore the adapter formula is `Emin = EB` and `Emax = EA + EB`. ', ...
    'Do not map Diniya `EA` directly to Jovano `Emax`.\n\n']);
fprintf(fid, '## Closure Guidance\n\n');
fprintf(fid, ['For Jovano post-closure, ASD should remain closed using Jovano''s ', ...
    'own convention, e.g. `R_ASD = 1e9` or equivalent. Diniya''s `asd.Cd`, ', ...
    '`asd.area_mm2`, and orifice-mode fields document the pre-closure ', ...
    'mechanism and should not be directly copied into a closed-shunt ', ...
    'post-closure model.\n\n']);
fprintf(fid, '## Time-Gap Interpretation\n\n');
fprintf(fid, ['Pre-closure and post-closure data are not the same physiologic ', ...
    'state separated only by closing ASD. Post-closure data may include ', ...
    'recovery and remodeling. Use Diniya''s seed as the accepted pre-closure ', ...
    'operating point and Jovano''s calibrated model as the chronic ', ...
    'post-closure operating point.\n']);
end

function copy_source_artifacts(source_mat, handoff_dir)
% COPY_SOURCE_ARTIFACTS - copy key accepted-run artifacts when present.
source_dir = fileparts(source_mat);
patterns = {
    'zoya_asd_calibration_*.mat'
    'zoya_asd_baseline_*.csv'
    'zoya_asd_calibrated_*.csv'
    'zoya_asd_best_candidate_*.csv'
    'zoya_asd_best_candidate_parameters_*.csv'
    'zoya_asd_rollback_decision_*.csv'
    'console_*.log'
    };

for i = 1:numel(patterns)
    files = dir(fullfile(source_dir, patterns{i}));
    for j = 1:numel(files)
        src = fullfile(files(j).folder, files(j).name);
        dst = fullfile(handoff_dir, files(j).name);
        if ~exist(dst, 'file')
            copyfile(src, dst);
        end
    end
end
end
