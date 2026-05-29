%% test_baseline_reproducibility.m
% TEST_BASELINE_REPRODUCIBILITY
% -------------------------------------------------------------------------
% Re-runs the active healthy baseline set multiple times to verify that the
% forward simulations are deterministic/reproducible before opening the ASD shunt.
%
% BASELINE FREEZE:
%   Adult_ref plus Zhang/Lundquist versions of the original Hafiz/Keisya
%   reference child and Zoya reference patient are established healthy
%   closed-circuit baselines. In this state, the septal shunt is closed and
%   Qp/Qs is expected to remain approximately 1.0 before ASD disease
%   simulation.
%
% OUTPUT:
%   results/tables/baseline_reproducibility_test.xlsx
%
% SHEETS:
%   Reproducibility_Summary  - max difference across repeated runs
%   All_Runs                 - every run/case/metric value
%   Run1_Baseline_Output     - adult/Zhang/Lundquist table from run 1
%   Sources_Assumptions      - source and interpretation notes
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-27
% VERSION:  1.1
% -------------------------------------------------------------------------

clear; clc;

test_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(test_dir);
add_active_project_paths(project_root);

n_runs = 3;  % [-] repeated forward runs for deterministic reproducibility

fprintf('===============================================================\n');
fprintf('  Healthy Baseline Reproducibility Test\n');
fprintf('===============================================================\n');
fprintf('Repeated runs per case: %d\n', n_runs);

baseline_output = run_healthy_baseline_set(n_runs);
fprintf('Cases:\n');
disp(baseline_output.case_table(:, {'Case_Name', 'Patient_Label', ...
    'Scaling_Mode', 'HR_Handling', 'Scaled_HR_bpm', 'Clinical_HR_bpm', ...
    'Final_HR_bpm'}));
fprintf('\n');

output_dir = fullfile(project_root, 'results', 'tables');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
output_file = fullfile(output_dir, ['baseline_reproducibility_test_' timestamp '.xlsx']);

writetable(baseline_output.reproducibility_table, output_file, ...
    'Sheet', 'Reproducibility_Summary');
writetable(baseline_output.long_table, output_file, ...
    'Sheet', 'All_Runs');
writetable(baseline_output.wide_table, output_file, ...
    'Sheet', 'Run1_Baseline_Output');
writetable(baseline_output.case_table, output_file, ...
    'Sheet', 'Case_Metadata');
writetable(baseline_output.scaling_table, output_file, ...
    'Sheet', 'Scaling_Factors');
writetable(baseline_output.shunt_table, output_file, ...
    'Sheet', 'Closed_Shunt_Check');
writetable(baseline_output.assumptions_table, output_file, ...
    'Sheet', 'Sources_Assumptions');

print_reproducibility_summary(baseline_output.reproducibility_table);

fprintf('\nExcel written:\n  %s\n', output_file);
fprintf('===============================================================\n');

% ADD_ACTIVE_PROJECT_PATHS - add active code folders only.
function add_active_project_paths(project_root)
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
addpath(fullfile(project_root, 'tests', 'helpers'));
end

% PRINT_REPRODUCIBILITY_SUMMARY - compact terminal summary.
function print_reproducibility_summary(summary_table)
max_abs_diff = max(summary_table.Max_Abs_Diff);
max_rel_diff_percent = max(summary_table.Max_Rel_Diff_Percent);
n_fail = sum(~summary_table.Within_Tolerance);

fprintf('Summary:\n');
fprintf('  Max absolute difference across all repeated runs : %.12g\n', max_abs_diff);
fprintf('  Max relative difference across all repeated runs : %.12g %%\n', max_rel_diff_percent);
fprintf('  Rows outside reproducibility tolerance           : %d\n', n_fail);

if n_fail > 0
    fprintf('\nRows requiring inspection:\n');
    bad_rows = summary_table(~summary_table.Within_Tolerance, :);
    disp(bad_rows(:, {'Case_Name', 'Metric', 'Unit', 'Max_Abs_Diff', 'Abs_Tolerance'}));
end
end
