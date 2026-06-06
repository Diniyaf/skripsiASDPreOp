%% demo_pre_to_post_handoff.m
% DEMO_PRE_TO_POST_HANDOFF
% -------------------------------------------------------------------------
% Demonstrates how Jovano can interpret Diniya's accepted Zoya pre-closure
% calibrated operating point.
%
% FLOW:
%   1. Load Diniya's pre-closure seed (params + metrics).
%   2. Close the ASD using Diniya's closed-shunt convention.
%   3. Run an acute closed-ASD simulation in Diniya's code.
%   4. Compare acute closed-ASD outputs against Diniya's pre-closure metrics.
%
% Jovano: this script does NOT replace your pipeline. It demonstrates the
% handoff mechanism and the expected direction of change. Use the exported
% parameter mapping table before adapting anything to Jovano's codebase.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-06
% VERSION:  1.1
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(project_root);
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

%% ========================================================================
%  1. LOAD Diniya's pre-closure seed
%% ========================================================================
seed_file = fullfile(project_root, 'results', 'calibration', ...
    'zoya_pre_to_post_seed.mat');
if ~exist(seed_file, 'file')
    error('demo_pre_to_post_handoff:missingSeed', ...
        'Seed file not found: %s. Run scripts/export_zoya_jovano_handoff.m first.', ...
        seed_file);
end

data = load(seed_file, 'seed_zoya');
params_pre = data.seed_zoya.params;
metrics_pre = data.seed_zoya.metrics;

source_text = get_seed_text(data.seed_zoya, 'source', ...
    get_seed_text(data.seed_zoya, 'source_mat', 'source not recorded'));
rmse_value = get_seed_numeric(data.seed_zoya, 'accepted_rmse', ...
    get_seed_numeric(data.seed_zoya, 'rmse', NaN));

fprintf('=== Diniya Pre-Closure Seed ===\n');
fprintf('Source: %s\n', source_text);
if isfinite(rmse_value)
    fprintf('RMSE: %.4f\n', rmse_value);
else
    fprintf('RMSE: not recorded in seed\n');
end
fprintf('Patient: Zoya\n\n');

%% ========================================================================
%  2. DISPLAY Pre-Closure Metrics
%% ========================================================================
fprintf('=== Pre-Closure Hemodynamics ===\n');
fprintf('  Qp/Qs  = %.2f\n', metrics_pre.QpQs);
fprintf('  Qp     = %.2f L/min\n', metrics_pre.Qp_Lmin);
fprintf('  Qs     = %.2f L/min\n', metrics_pre.Qs_Lmin);
fprintf('  Q_ASD  = %.2f L/min\n', metrics_pre.Q_ASD_Lmin);
fprintf('  LAP    = %.1f mmHg\n', metrics_pre.LAP_mean);
fprintf('  RAP    = %.1f mmHg\n', metrics_pre.RAP_mean);
fprintf('  PAP    = %.1f mmHg\n', metrics_pre.PAP_mean);
fprintf('  MAP    = %.1f mmHg\n', metrics_pre.SAP_mean);
fprintf('  RVEDV  = %.1f mL\n', metrics_pre.RVEDV_mL);
fprintf('  LVEDV  = %.1f mL\n', metrics_pre.LVEDV_mL);

%% ========================================================================
%  3. CLOSE ASD - acute closed-shunt test in Diniya model
%% ========================================================================
params_post = params_pre;
params_post.R.asd = Inf;       % [mmHg*s/mL] closed linear fallback
if isfield(params_post, 'asd')
    params_post.asd.area_mm2 = 0;  % [mm^2] closed orifice convention
    params_post.asd.Cd = 0;        % [-] no orifice flow after closure
end

fprintf('\n=== ASD CLOSED IN DINIYA MODEL ===\n');
fprintf('R.asd = Inf (pre value: %s)\n', format_numeric(params_pre.R.asd));
if isfield(params_pre, 'asd') && isfield(params_pre.asd, 'mode')
    fprintf('Pre-closure Diniya ASD mode: %s\n', params_pre.asd.mode);
end
fprintf('This is an acute closure test, not chronic post-closure remodeling.\n');

%% ========================================================================
%  4. SIMULATE Acute Closed-ASD State
%% ========================================================================
% Jovano: replace integrate_system + compute_clinical_indices with your
% own model's equivalent functions if you port this logic.
fprintf('\n=== Running Acute Closed-ASD Simulation ===\n');

try
    sim_post = integrate_system(params_post);
    metrics_post = compute_clinical_indices(sim_post, params_post);
catch ME
    fprintf('Simulation failed: %s\n', ME.message);
    fprintf('Jovano: adapt this section to your model rather than using it directly.\n');
    return;
end

%% ========================================================================
%  5. COMPARE Pre vs Acute Closed-ASD Outputs
%% ========================================================================
fprintf('\n=== Pre vs Acute Closed-ASD Comparison ===\n');
fprintf('  %-12s %10s %10s %s\n', 'Metric', 'Pre', 'Closed', 'Direction');
fprintf('  %s\n', repmat('-', 1, 64));

compare('Qp/Qs',    metrics_pre.QpQs,       metrics_post.QpQs,       'down toward 1.0');
compare('Q_ASD(L)', metrics_pre.Q_ASD_Lmin, metrics_post.Q_ASD_Lmin, 'down toward 0');
compare('LAP',      metrics_pre.LAP_mean,   metrics_post.LAP_mean,   'decrease or normalize');
compare('PAP',      metrics_pre.PAP_mean,   metrics_post.PAP_mean,   'decrease or normalize');
compare('RVEDV',    metrics_pre.RVEDV_mL,   metrics_post.RVEDV_mL,   'decrease with RV unloading');
compare('LVEDV',    metrics_pre.LVEDV_mL,   metrics_post.LVEDV_mL,   'increase or move toward post target');
compare('MAP',      metrics_pre.SAP_mean,   metrics_post.SAP_mean,   'stable');

fprintf('\n=== DONE ===\n');
fprintf('Jovano: if Qp/Qs approaches 1.0, Q_ASD approaches 0, and RV load falls, the closure direction is correct.\n');
fprintf('Then compare absolute values with your independently calibrated chronic post-closure model.\n');

%% ========================================================================
%  LOCAL HELPERS
%% ========================================================================
function compare(name, pre_val, post_val, expected)
% COMPARE - print pre/post directional change for one scalar metric.
if isnan(pre_val) || isnan(post_val)
    fprintf('  %-12s %10s %10s %s\n', name, 'N/A', 'N/A', expected);
    return;
end
pct_change = (post_val - pre_val) / max(abs(pre_val), 1e-9) * 100;
if pct_change > 0
    direction = 'up';
elseif pct_change < 0
    direction = 'down';
else
    direction = 'same';
end
fprintf('  %-12s %10.2f %10.2f %s (%+.0f%%) expect: %s\n', ...
    name, pre_val, post_val, direction, pct_change, expected);
end

function value = get_seed_text(seed, field_name, fallback)
% GET_SEED_TEXT - read optional text field from seed struct.
value = fallback;
if isstruct(seed) && isfield(seed, field_name) && ~isempty(seed.(field_name))
    value = char(string(seed.(field_name)));
end
end

function value = get_seed_numeric(seed, field_name, fallback)
% GET_SEED_NUMERIC - read optional scalar numeric field from seed struct.
value = fallback;
if isstruct(seed) && isfield(seed, field_name) && ...
        isnumeric(seed.(field_name)) && isscalar(seed.(field_name))
    value = seed.(field_name);
end
end

function text = format_numeric(value)
% FORMAT_NUMERIC - compact scalar formatting for logs.
if isnumeric(value) && isscalar(value)
    if isinf(value)
        text = 'Inf';
    elseif isnan(value)
        text = 'NaN';
    else
        text = sprintf('%.4g', value);
    end
else
    text = 'not numeric';
end
end
