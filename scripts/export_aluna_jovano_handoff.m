%% export_aluna_jovano_handoff.m
% EXPORT_ALUNA_JOVANO_HANDOFF
% -------------------------------------------------------------------------
% Build a reproducible handoff package from Diniya's Patient Aluna
% pre-closure ASD calibration run for Jovano's post-closure workflow.
%
% This script does not run simulation, GSA, optimization, or post-closure
% logic. It packages the latest Aluna calibration artefacts and documents
% that the best Stage C pressure-fit candidate was rolled back by the
% current hard SVR validity gate.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-07
% VERSION:  1.0
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(project_root);

source_run_dir = fullfile(project_root, 'results', 'calibration', ...
    'aluna_asd_calib_20260607_181140');
source_mat = fullfile(source_run_dir, 'aluna_asd_calibration_20260607_181140.mat');
if ~exist(source_mat, 'file')
    error('export_aluna_jovano_handoff:missingSource', ...
        'Aluna calibration MAT not found: %s', source_mat);
end

S = load(source_mat, 'pkg');
pkg = S.pkg;

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
handoff_dir = fullfile(project_root, 'results', 'calibration', ...
    sprintf('aluna_jovano_handoff_%s', timestamp));
if ~exist(handoff_dir, 'dir')
    mkdir(handoff_dir);
end

%% Build handoff seed
seed_aluna = struct();
seed_aluna.patient = 'Aluna';
seed_aluna.scenario = 'pre_surgery';
seed_aluna.closure_state = 'pre_closure_open_ASD';
seed_aluna.current_accepted_label = safe_pkg_field(pkg, 'accepted_label', '');
seed_aluna.current_accepted_params = safe_pkg_field(pkg, 'accepted_params', struct());
seed_aluna.current_accepted_metrics = safe_pkg_field(pkg, 'accepted_metrics', struct());
seed_aluna.current_accepted_rmse = safe_pkg_field(pkg, 'accepted_rmse', NaN);
seed_aluna.baseline_rmse = safe_pkg_field(pkg, 'baseline_rmse', NaN);
seed_aluna.best_candidate = safe_pkg_field(pkg, 'best_candidate', struct());
seed_aluna.best_rejected_candidate = safe_pkg_field(pkg, 'best_rejected_candidate', struct());
seed_aluna.rollback = safe_pkg_field(pkg, 'rollback', false);
seed_aluna.rollback_reason = safe_pkg_field(pkg, 'rollback_reason', '');
seed_aluna.source = 'Aluna Stage C pressure-fit candidate was rolled back by current derived-SVR hard gate.';
seed_aluna.source_mat = source_mat;
seed_aluna.export_timestamp = timestamp;
seed_aluna.export_date = char(datetime('today', 'Format', 'yyyy-MM-dd'));
seed_aluna.target_tiers = safe_pkg_field(pkg, 'target_tiers', table());
seed_aluna.caseProfile = safe_pkg_field(pkg, 'caseProfile', struct());
seed_aluna.sign_convention = 'Q_ASD > 0 means LA_to_RA left-to-right atrial shunt.';
seed_aluna.mapping_warning = ['Diniya and Jovano use different state vectors, ', ...
    'parameter namespaces, and elastance parameterizations. Use this package ', ...
    'as a context handoff, not as blind direct-copy instructions.'];

timestamped_seed = fullfile(handoff_dir, ...
    sprintf('aluna_pre_to_post_seed_%s.mat', timestamp));
save(timestamped_seed, 'seed_aluna');

%% Export tables and README
current_metrics = seed_aluna.current_accepted_metrics;
best_metrics = struct();
if isstruct(seed_aluna.best_candidate) && isfield(seed_aluna.best_candidate, 'metrics')
    best_metrics = seed_aluna.best_candidate.metrics;
end
metrics_table = build_metrics_comparison_table(current_metrics, best_metrics);

params_for_mapping = seed_aluna.current_accepted_params;
if isstruct(seed_aluna.best_candidate) && isfield(seed_aluna.best_candidate, 'params')
    params_for_mapping = seed_aluna.best_candidate.params;
end
mapping_table = build_parameter_mapping_table(params_for_mapping);
context_table = build_context_table(pkg);

metrics_csv = fullfile(handoff_dir, sprintf('aluna_pre_metrics_%s.csv', timestamp));
mapping_csv = fullfile(handoff_dir, sprintf('diniya_to_jovano_parameter_mapping_aluna_%s.csv', timestamp));
context_csv = fullfile(handoff_dir, sprintf('aluna_calibration_context_%s.csv', timestamp));
readme_path = fullfile(handoff_dir, sprintf('README_aluna_jovano_handoff_%s.md', timestamp));

writetable(metrics_table, metrics_csv);
writetable(mapping_table, mapping_csv);
writetable(context_table, context_csv);
write_handoff_readme(readme_path, seed_aluna, timestamped_seed, metrics_csv, ...
    mapping_csv, context_csv, source_mat, source_run_dir, handoff_dir, project_root);
copy_source_artifacts(source_run_dir, source_mat, handoff_dir);

fprintf('Aluna-Jovano handoff exported.\n');
fprintf('  Handoff folder: %s\n', handoff_dir);
fprintf('  Timestamped seed: %s\n', timestamped_seed);
fprintf('  Metrics CSV: %s\n', metrics_csv);
fprintf('  Mapping CSV: %s\n', mapping_csv);
fprintf('  Context CSV: %s\n', context_csv);
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

function T = build_metrics_comparison_table(accepted_metrics, best_metrics)
% BUILD_METRICS_COMPARISON_TABLE - accepted baseline vs best Stage C metrics.
names = unique([fieldnames_or_empty(accepted_metrics); fieldnames_or_empty(best_metrics)], 'stable');
metric = strings(0, 1);
accepted_value = strings(0, 1);
best_value = strings(0, 1);
unit = strings(0, 1);
notes = strings(0, 1);
for i = 1:numel(names)
    name = names{i};
    a_val = get_scalar_metric(accepted_metrics, name);
    b_val = get_scalar_metric(best_metrics, name);
    if ~isfinite(a_val) && ~isfinite(b_val)
        continue;
    end
    metric(end + 1, 1) = string(name); %#ok<AGROW>
    accepted_value(end + 1, 1) = string(format_value(a_val)); %#ok<AGROW>
    best_value(end + 1, 1) = string(format_value(b_val)); %#ok<AGROW>
    unit(end + 1, 1) = string(infer_metric_unit(name)); %#ok<AGROW>
    notes(end + 1, 1) = "Accepted column follows current rollback decision; best column is Stage C pressure-fit candidate."; %#ok<AGROW>
end
T = table(metric, accepted_value, best_value, unit, notes, ...
    'VariableNames', {'Metric','Accepted_Value','Best_StageC_Value','Unit','Notes'});
end

function names = fieldnames_or_empty(data)
% FIELDNAMES_OR_EMPTY - safe fieldnames for optional structs.
if isstruct(data)
    names = fieldnames(data);
else
    names = {};
end
end

function value = get_scalar_metric(metrics, name)
% GET_SCALAR_METRIC - scalar numeric metric or NaN.
value = NaN;
if isstruct(metrics) && isfield(metrics, name)
    raw = metrics.(name);
    if isnumeric(raw) && isscalar(raw)
        value = raw;
    end
end
end

function T = build_context_table(pkg)
% BUILD_CONTEXT_TABLE - compact calibration decision context for Jovano.
items = [
    "Patient"
    "Scenario"
    "Accepted label"
    "Rollback"
    "Rollback reason"
    "Baseline RMSE"
    "Stage A RMSE"
    "Best Stage C RMSE"
    "Accepted RMSE"
    "Primary targets"
    "Secondary guards"
    "Interpretation"
    "Recommended transfer status"
    ];

primary_targets = target_list(pkg, 'hard_primary');
secondary_targets = target_list(pkg, 'soft_secondary_guard');

values = [
    "Aluna"
    string(safe_pkg_field(pkg, 'scenario', 'pre_surgery'))
    string(safe_pkg_field(pkg, 'accepted_label', ''))
    string(iif(safe_pkg_field(pkg, 'rollback', false), 'YES', 'NO'))
    string(safe_pkg_field(pkg, 'rollback_reason', ''))
    string(format_value(safe_pkg_field(pkg, 'baseline_rmse', NaN)))
    string(format_value(pkg.stageA.rmse))
    string(format_value(pkg.best_candidate.rmse))
    string(format_value(safe_pkg_field(pkg, 'accepted_rmse', NaN)))
    string(primary_targets)
    string(secondary_targets)
    "Best Stage C improves pressure targets but current hard validity gate rejects derived SVR."
    "Context/diagnostic handoff; not a final direct parameter-copy seed."
    ];
T = table(items, values, 'VariableNames', {'Item','Value'});
end

function text = target_list(pkg, tier)
% TARGET_LIST - comma-separated target tier fields.
text = "";
if ~isfield(pkg, 'target_tiers') || isempty(pkg.target_tiers)
    return;
end
T = pkg.target_tiers;
mask = strcmp(T.Tier, tier) | startsWith(T.Tier, tier);
if any(mask)
    text = strjoin(cellstr(string(T.ModelField(mask))), ', ');
end
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
        'Diniya uses E(t)=EA*e(t)+EB; Jovano uses E(t)=Emin+(Emax-Emin)*e(t).');
    rows = add_row(rows, sprintf('E.%s.EB', ch), format_value(EB), ...
        'mmHg/mL', sprintf('Emin_%s', jov), format_value(EB), ...
        'Emin = EB', 'adapter_formula_only', ...
        'Do not map Diniya EA directly to Jovano Emax.');
    rows = add_row(rows, sprintf('V0.%s', ch), format_value(V0), ...
        'mL', sprintf('V0_%s', jov), format_value(V0), ...
        'direct concept, different state vector', 'conceptual_mapping', ...
        'Unstressed volume has matching physiological meaning; re-check with Jovano states.');
end

vascular_map = {
    'R.SAR',  'R_sa',  'mmHg*s/mL', 'systemic arterial resistance';
    'R.SC',   'R_sc',  'mmHg*s/mL', 'systemic capillary resistance';
    'R.SVEN', 'R_sv',  'mmHg*s/mL', 'systemic venous resistance';
    'C.SAR',  'C_sa',  'mL/mmHg',   'systemic arterial compliance';
    'C.SC',   'C_sc',  'mL/mmHg',   'systemic capillary compliance';
    'C.SVEN', 'C_sv',  'mL/mmHg',   'systemic venous compliance';
    'R.PAR',  'R_pa',  'mmHg*s/mL', 'pulmonary arterial resistance';
    'R.PCOX', 'R_pc',  'mmHg*s/mL', 'oxygenated pulmonary capillary resistance';
    'R.PCNO', 'R_sh',  'mmHg*s/mL', 'non-oxygenated pulmonary capillary resistance';
    'R.PVEN', 'R_pv',  'mmHg*s/mL', 'pulmonary venous resistance';
    'C.PAR',  'C_pa',  'mL/mmHg',   'pulmonary arterial compliance';
    'C.PCOX', 'C_pc',  'mL/mmHg',   'oxygenated pulmonary capillary compliance';
    'C.PCNO', 'C_sh',  'mL/mmHg',   'non-oxygenated pulmonary capillary compliance';
    'C.PVEN', 'C_pv',  'mL/mmHg',   'pulmonary venous compliance';
    };

for i = 1:size(vascular_map, 1)
    diniya_field = vascular_map{i, 1};
    value = get_param(params, diniya_field);
    rows = add_row(rows, diniya_field, format_value(value), vascular_map{i, 3}, ...
        vascular_map{i, 2}, format_value(value), 'nearest named compartment', ...
        'conceptual_mapping', vascular_map{i, 4});
end

rows = add_row(rows, 'asd.Cd', format_value(get_param(params, 'asd.Cd')), ...
    '-', 'R_ASD', 'close ASD for post-closure', ...
    'not equivalent', 'do_not_direct_copy', ...
    'Aluna pre-closure uses orifice mode. Jovano post-closure should use its closed-ASD convention.');
rows = add_row(rows, 'asd.area_mm2', format_value(get_param(params, 'asd.area_mm2')), ...
    'mm^2', 'R_ASD', 'close ASD for post-closure', ...
    'not equivalent', 'do_not_direct_copy', ...
    'Area documents the pre-closure defect; do not use as post-closure shunt opening.');
rows = add_row(rows, 'R.asd', format_value(get_param(params, 'R.asd')), ...
    'mmHg*s/mL', 'R_ASD', 'close ASD for post-closure', ...
    'mode-dependent', 'do_not_direct_copy', ...
    'In Diniya orifice mode R.asd is inactive.');

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

function write_handoff_readme(readme_path, seed, seed_path, metrics_csv, ...
    mapping_csv, context_csv, source_mat, source_run_dir, handoff_dir, project_root)
% WRITE_HANDOFF_README - relative-path README for GitHub handoff.
fid = fopen(readme_path, 'w');
if fid < 0
    error('export_aluna_jovano_handoff:readmeOpenFailed', ...
        'Could not write README: %s', readme_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Aluna Pre-to-Post ASD Handoff Package\n\n');
fprintf(fid, 'Generated: `%s`\n\n', seed.export_timestamp);
fprintf(fid, '## Purpose\n\n');
fprintf(fid, ['This package transfers Diniya''s Patient Aluna pre-closure ASD ', ...
    'calibration context to Jovano as a documented reference. It is not a ', ...
    'blind parameter-copy instruction because the two codebases use different ', ...
    'state vectors, parameter namespaces, and elastance equations.\n\n']);
fprintf(fid, '## Current Calibration Status\n\n');
fprintf(fid, '- Patient: Aluna\n');
fprintf(fid, '- Scenario: pre_surgery / pre_closure\n');
fprintf(fid, '- Accepted label under current gates: `%s`\n', seed.current_accepted_label);
fprintf(fid, '- Rollback: `%s`\n', iif(seed.rollback, 'YES', 'NO'));
fprintf(fid, '- Rollback reason: `%s`\n', seed.rollback_reason);
fprintf(fid, '- Baseline RMSE: %.6f\n', seed.baseline_rmse);
fprintf(fid, '- Accepted RMSE after rollback: %.6f\n', seed.current_accepted_rmse);
if isstruct(seed.best_candidate) && isfield(seed.best_candidate, 'rmse')
    fprintf(fid, '- Best Stage C pressure-fit RMSE: %.6f\n', seed.best_candidate.rmse);
end
fprintf(fid, '\n');
fprintf(fid, 'The best Stage C candidate improved the two available primary pressure targets ');
fprintf(fid, 'substantially, but the current hard validity gate rejected it because model-derived ');
fprintf(fid, 'SVR exceeded the generic threshold. For Aluna, SVR is not directly reported and ');
fprintf(fid, 'depends on model-predicted Qs and RAP, so this package should be interpreted as ');
fprintf(fid, 'diagnostic/exploratory handoff until the data-aware SVR/PVR gate policy is finalized.\n\n');

fprintf(fid, '## Core Files\n\n');
fprintf(fid, '- Seed MAT: `%s`\n', repo_relative_path(seed_path, project_root));
fprintf(fid, '- Metrics comparison CSV: `%s`\n', repo_relative_path(metrics_csv, project_root));
fprintf(fid, '- Calibration context CSV: `%s`\n', repo_relative_path(context_csv, project_root));
fprintf(fid, '- Parameter mapping CSV: `%s`\n', repo_relative_path(mapping_csv, project_root));
fprintf(fid, '- Source calibration MAT: `%s`\n', repo_relative_path(source_mat, project_root));
fprintf(fid, '- Source run folder: `%s`\n\n', repo_relative_path(source_run_dir, project_root));

fprintf(fid, '## Required Reading for Jovano\n\n');
fprintf(fid, '- `docs/diniya_jovano_handoff_strategy.md`\n');
fprintf(fid, '- `docs/diniya_jovano_parameter_mapping.md`\n');
fprintf(fid, '- `docs/diniya_vs_jovano_codebase_comparison.md`\n');
fprintf(fid, '- `docs/diniya_vs_jovano_deep_calibration_comparison.md`\n\n');

fprintf(fid, '## Critical Mapping Note: EA/EB vs Emax/Emin\n\n');
fprintf(fid, ['Diniya uses `E(t) = EA * e(t) + EB`, so `EB` is the ', ...
    'minimum/passive elastance and `EA` is the activation amplitude above ', ...
    'that baseline. Jovano uses `E(t) = Emin + (Emax - Emin) * e(t)`. ', ...
    'Therefore the adapter formula is `Emin = EB` and `Emax = EA + EB`. ', ...
    'Do not map Diniya `EA` directly to Jovano `Emax`.\n\n']);

fprintf(fid, '## Closure Guidance\n\n');
fprintf(fid, ['For Jovano post-closure, ASD should remain closed using Jovano''s ', ...
    'own convention, for example `R_ASD = 1e9` or equivalent. Diniya''s ', ...
    '`asd.Cd`, `asd.area_mm2`, and orifice-mode fields document the ', ...
    'pre-closure mechanism and should not be directly copied into a ', ...
    'closed-shunt post-closure model.\n\n']);

fprintf(fid, '## Package Folder\n\n');
fprintf(fid, '`%s`\n', repo_relative_path(handoff_dir, project_root));
end

function copy_source_artifacts(source_run_dir, source_mat, handoff_dir)
% COPY_SOURCE_ARTIFACTS - copy reproducibility artefacts into handoff folder.
copyfile(source_mat, handoff_dir);
patterns = {
    'aluna_asd_baseline_*.csv'
    'aluna_asd_calibrated_*.csv'
    'aluna_asd_best_candidate_*.csv'
    'aluna_asd_best_candidate_parameters_*.csv'
    'aluna_asd_best_rejected_candidate_*.csv'
    'aluna_asd_best_rejected_candidate_parameters_*.csv'
    'aluna_asd_rollback_decision_*.csv'
    'aluna_asd_validation_gates_*.csv'
    'aluna_asd_clinical_fit_gate_*.csv'
    'console_*.log'
    'README_aluna_asd_calibration_run_*.md'
    'README_calibration_run.md'
    };
for i = 1:numel(patterns)
    files = dir(fullfile(source_run_dir, patterns{i}));
    for j = 1:numel(files)
        copyfile(fullfile(files(j).folder, files(j).name), handoff_dir);
    end
end
fig_src = fullfile(source_run_dir, 'figures');
if exist(fig_src, 'dir')
    fig_dst = fullfile(handoff_dir, 'figures');
    if ~exist(fig_dst, 'dir'), mkdir(fig_dst); end
    copyfile(fullfile(fig_src, '*.pdf'), fig_dst);
end
end

function rel = repo_relative_path(path_value, project_root)
% REPO_RELATIVE_PATH - path formatting for GitHub/repo portability.
path_value = char(string(path_value));
project_root = char(string(project_root));
rel = strrep(path_value, [project_root filesep], '');
rel = strrep(rel, '\', '/');
end

function text = infer_metric_unit(name)
% INFER_METRIC_UNIT - simple metric unit labels.
if contains(name, {'Lmin','CO'}, 'IgnoreCase', true)
    text = 'L/min';
elseif contains(name, {'mean','min','max','PAP','SAP','RAP','LAP','DeltaP'}, 'IgnoreCase', true)
    text = 'mmHg';
elseif contains(name, {'EDV','ESV','SV'}, 'IgnoreCase', true)
    text = 'mL';
elseif contains(name, {'EF'}, 'IgnoreCase', true)
    text = 'fraction';
elseif contains(name, {'SVR','PVR'}, 'IgnoreCase', true)
    text = 'Wood units';
else
    text = '-';
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
else
    text = char(string(value));
end
end

function s = iif(cond, t, f)
% IIF - inline if for text construction.
if cond
    s = t;
else
    s = f;
end
end
