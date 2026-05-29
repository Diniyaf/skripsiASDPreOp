%% build_asd_candidate_parameter_set_report.m
% BUILD_ASD_CANDIDATE_PARAMETER_SET_REPORT
% -------------------------------------------------------------------------
% Builds a timestamped workbook documenting ASD-specific candidate
% calibration parameter sets for Patient Zoya pre-closure.
%
% WORKFLOW:
%   latest params0_ASD_pre MAT report
%   -> asd_candidate_param_sets()
%   -> Excel documentation workbook
%
% This script does not run ODE simulation, GSA, optimisation, calibration,
% or post-closure/Jovano logic.
%
% OUTPUTS:
%   results/tables/asd_candidate_parameter_set_YYYYMMDD_HHMMSS.xlsx
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-29
% VERSION:  1.0
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

output_dir = fullfile(project_root, 'results', 'tables');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
excel_path = make_unique_output_path(output_dir, ...
    sprintf('asd_candidate_parameter_set_%s.xlsx', timestamp));

[params0_ASD_pre, clinical, scenario, source_mat] = load_latest_seeded_params(output_dir);
report = asd_candidate_param_sets(params0_ASD_pre, clinical, scenario);

writetable(report.summary, excel_path, 'Sheet', 'Summary');
writetable(report.groupA, excel_path, 'Sheet', 'Candidate_Group_A_Primary');
writetable(report.groupB, excel_path, 'Sheet', 'Candidate_Group_B_Secondary');
writetable(report.groupC, excel_path, 'Sheet', 'Candidate_Group_C_Fixed');
writetable(report.boundsRationale, excel_path, 'Sheet', 'Bounds_Rationale');
writetable(report.futureGSATargets, excel_path, 'Sheet', 'Future_GSA_Targets');
writetable(report.excludedParameters, excel_path, 'Sheet', 'Excluded_Parameters');
writetable(report.warnings, excel_path, 'Sheet', 'Warnings');
writetable(report.notes, excel_path, 'Sheet', 'Notes');

fprintf('===============================================================\n');
fprintf('  ASD Candidate Parameter Set Report\n');
fprintf('===============================================================\n');
fprintf('Mode: candidate definition only; no GSA, no optimization.\n');
fprintf('Source MAT:\n  %s\n', source_mat);
fprintf('Excel written:\n  %s\n', excel_path);
fprintf('\nGroup A primary candidates:\n');
disp(report.groupA(:, {'Parameter','Initial_Value','Lower_Bound','Upper_Bound'}));
fprintf('\nGroup B secondary candidates:\n');
disp(report.groupB(:, {'Parameter','Initial_Value','Lower_Bound','Upper_Bound'}));
fprintf('\nGroup C fixed/exploratory parameters:\n');
disp(report.groupC(:, {'Parameter','Initial_Value','Lower_Bound','Upper_Bound'}));
fprintf('\nWarnings:\n');
disp(report.warnings);
fprintf('===============================================================\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function [params0, clinical, scenario, source_mat] = load_latest_seeded_params(output_dir)
% LOAD_LATEST_SEEDED_PARAMS - prefer latest baseline MAT with params0_ASD_pre.
files = dir(fullfile(output_dir, 'zoya_asd_preclosure_baseline_*.mat'));
if isempty(files)
    files = dir(fullfile(output_dir, 'params0_ASD_pre_*.mat'));
end
if isempty(files)
    error('build_asd_candidate_parameter_set_report:noSeededParams', ...
        'No params0_ASD_pre MAT file found in results/tables.');
end
[~, idx] = max([files.datenum]);
source_mat = fullfile(files(idx).folder, files(idx).name);
data = load(source_mat);

if ~isfield(data, 'params0_ASD_pre')
    error('build_asd_candidate_parameter_set_report:missingParams', ...
        'Selected MAT file does not contain params0_ASD_pre: %s', source_mat);
end
params0 = data.params0_ASD_pre;

if isfield(data, 'clinical')
    clinical = data.clinical;
else
    clinical = patient_zoya();
end
if isfield(data, 'scenario')
    scenario = data.scenario;
else
    scenario = 'pre_surgery';
end
end

function output_path = make_unique_output_path(output_dir, file_name)
% MAKE_UNIQUE_OUTPUT_PATH - avoid overwriting existing reports.
output_path = fullfile(output_dir, file_name);
if ~exist(output_path, 'file')
    return;
end
[~, base, ext] = fileparts(file_name);
counter = 1;
while exist(output_path, 'file')
    output_path = fullfile(output_dir, sprintf('%s_%02d%s', base, counter, ext));
    counter = counter + 1;
end
end
