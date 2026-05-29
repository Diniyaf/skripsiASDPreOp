%% build_asd_target_tier_report.m
% BUILD_ASD_TARGET_TIER_REPORT
% -------------------------------------------------------------------------
% Exports Patient Zoya ASD pre-closure target-tier governance before GSA.
%
% This script does not run ODE simulation, GSA, optimization, calibration,
% or post-closure/Jovano logic.
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
    sprintf('asd_target_tiers_%s.xlsx', timestamp));

clinical = patient_zoya();
scenario = 'pre_surgery';
target_tiers = build_asd_target_tiers(clinical, scenario);

summary = build_summary_table(scenario, target_tiers);
hard_primary = target_tiers(strcmp(target_tiers.Tier, 'hard_primary'), :);
soft_secondary = target_tiers(startsWith(target_tiers.Tier, 'soft_secondary'), :);
prediction_only = target_tiers(strcmp(target_tiers.Tier, 'prediction_only'), :);
excluded = target_tiers(startsWith(target_tiers.Tier, 'excluded'), :);
notes = build_notes_table();

writetable(summary, excel_path, 'Sheet', 'Summary');
writetable(hard_primary, excel_path, 'Sheet', 'Hard_Primary_Targets');
writetable(soft_secondary, excel_path, 'Sheet', 'Soft_Secondary_Targets');
writetable(prediction_only, excel_path, 'Sheet', 'Prediction_Only_Targets');
writetable(excluded, excel_path, 'Sheet', 'Excluded_Targets');
writetable(notes, excel_path, 'Sheet', 'Notes');

fprintf('ASD target-tier report written:\n  %s\n', excel_path);
disp(summary);

%% ========================================================================
%  LOCAL FUNCTIONS
%% ========================================================================

function tbl = build_summary_table(scenario, target_tiers)
% BUILD_SUMMARY_TABLE - compact target-tier report.
rows = {
    "Purpose", "Target-tier governance before ASD Group A GSA; no tuning or optimization."
    "Scenario", scenario
    "Hard primary targets", string(strjoin(cellstr(target_tiers.ModelField(strcmp(target_tiers.Tier, 'hard_primary'))'), ', '))
    "Soft secondary targets", string(strjoin(cellstr(target_tiers.ModelField(startsWith(target_tiers.Tier, 'soft_secondary'))'), ', '))
    "Prediction-only targets", string(strjoin(cellstr(target_tiers.ModelField(strcmp(target_tiers.Tier, 'prediction_only'))'), ', '))
    "Excluded targets", string(strjoin(cellstr(target_tiers.ModelField(startsWith(target_tiers.Tier, 'excluded'))'), ', '))
    };
tbl = cell2table(rows, 'VariableNames', {'Topic','Details'});
end

function tbl = build_notes_table()
% BUILD_NOTES_TABLE - methodological notes.
rows = {
    "Primary evidence", "Patient Z pre-closure provides pressure-flow targets: Qp, Qs, Qp/Qs, MAP, PAP, and LAP."
    "Derived shunt flow", "Q_ASD_Lmin target is derived as Qp_Lmin - Qs_Lmin and is comparison-only."
    "Prediction-only", "RAP_mean, SVR, and PVR can be reported but are not direct fitting targets because clinical values are missing."
    "Excluded", "LV/RV volumes and EF are excluded from primary calibration because pre-closure targets are missing."
    "No optimization", "This report does not change parameter values or run calibration."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic','Note'});
end

function output_path = make_unique_output_path(output_dir, file_name)
% MAKE_UNIQUE_OUTPUT_PATH - avoid overwriting existing workbooks.
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
