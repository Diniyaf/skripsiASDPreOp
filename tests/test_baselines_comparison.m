%% test_baselines_comparison.m
% TEST_BASELINES_COMPARISON
% -------------------------------------------------------------------------
% Runs the current active healthy baseline set once and prints the requested
% adult/Zhang/Lundquist comparison table in the terminal.
%
% BASELINE FREEZE:
%   Adult_ref plus Zhang/Lundquist versions of the original Hafiz/Keisya
%   reference child and Zoya reference patient are established healthy
%   closed-circuit baselines. In this state, the septal shunt is closed and
%   Qp/Qs is expected to remain approximately 1.0 before ASD disease
%   simulation.
%
% This script is a forward-simulation smoke test. For repeated-run
% reproducibility and Excel export, use tests/test_baseline_reproducibility.m.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-27
% VERSION:  1.2
% -------------------------------------------------------------------------

clear; clc;

test_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(test_dir);
add_active_project_paths(project_root);

fprintf('===============================================================\n');
fprintf('  Healthy Baseline Comparison\n');
fprintf('===============================================================\n');

baseline_output = run_healthy_baseline_set(1);

fprintf('Reference configurations:\n');
print_case_metadata(baseline_output.case_table);

fprintf('\nScaling and HR handling:\n');
print_scaling_metadata(baseline_output.scaling_table);

fprintf('\nNOTE: Zoya ASD disease fields are intentionally ignored in healthy baseline validation.\n');
fprintf('      Healthy baseline remains closed-shunt/no-disease for all five cases.\n\n');

print_comparison_table(baseline_output.wide_table);

steady_flags = steady_state_flags(baseline_output.long_table);
fprintf('\nClosed-shunt proof:\n');
disp(baseline_output.shunt_table);

fprintf('\nSteady-state flags:\n');
disp(steady_flags);
fprintf('===============================================================\n');

% ADD_ACTIVE_PROJECT_PATHS - add active code folders only.
function add_active_project_paths(project_root)
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
addpath(fullfile(project_root, 'tests', 'helpers'));
end

% PRINT_CASE_METADATA - show reference patient demographics for each case.
function print_case_metadata(case_table)
disp(case_table(:, {'Case_Name', 'Patient_Label', 'Scaling_Mode', ...
    'Age_Years', 'Weight_kg', 'Height_cm', 'BSA_m2'}));
end

% PRINT_SCALING_METADATA - show scaled HR and clinical override status.
function print_scaling_metadata(scaling_table)
disp(scaling_table(:, {'Case_Name', 'Scaling_Mode', 'Patient_Label', ...
    'BSA_scale_factor', 'Weight_scale_factor', 'Scaled_HR_bpm', ...
    'Clinical_HR_bpm', 'Final_HR_bpm', 'HR_Handling'}));
end

% PRINT_COMPARISON_TABLE - fixed-width terminal table for thesis audit.
function print_comparison_table(comparison)
case_vars = comparison.Properties.VariableNames(3:end);
col_width = 31;

fprintf('%-20s %-8s', 'Variable', 'Unit');
for col_idx = 1:numel(case_vars)
    fprintf([' %' num2str(col_width) 's'], case_vars{col_idx});
end
fprintf('\n');

fprintf('%-20s %-8s', repmat('-', 1, 20), repmat('-', 1, 8));
for col_idx = 1:numel(case_vars)
    fprintf([' %' num2str(col_width) 's'], repmat('-', 1, col_width));
end
fprintf('\n');

for row_idx = 1:height(comparison)
    fprintf('%-20s %-8s', ...
        char(comparison.Metric(row_idx)), char(comparison.Unit(row_idx)));
    for col_idx = 1:numel(case_vars)
        fprintf([' %' num2str(col_width) '.6f'], ...
            comparison.(case_vars{col_idx})(row_idx));
    end
    fprintf('\n');
end
end

% STEADY_STATE_FLAGS - summarize one logical flag per baseline case.
function flags = steady_state_flags(long_table)
case_names = unique(long_table.Case_Name, 'stable');
n_cases = numel(case_names);
Case_Name = strings(n_cases, 1);
Steady_State_Reached = false(n_cases, 1);
for idx = 1:n_cases
    case_name = case_names{idx};
    mask = long_table.Run_Index == 1 & strcmp(long_table.Case_Name, case_name);
    Case_Name(idx) = string(case_name);
    Steady_State_Reached(idx) = all(long_table.Steady_State_Reached(mask));
end
flags = table(Case_Name, Steady_State_Reached);
end
