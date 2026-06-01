%% build_asd_pipeline_governance_check.m
% BUILD_ASD_PIPELINE_GOVERNANCE_CHECK
% -------------------------------------------------------------------------
% Safe verification-only export for the patient-generic ASD GSA/calibration
% governance layer. This script does not run full GSA, optimization, tuning,
% or model-equation edits.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  1.0
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(project_root);
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

output_dir = fullfile(project_root, 'results', 'tables');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
excel_path = fullfile(output_dir, sprintf('asd_pipeline_governance_check_%s.xlsx', timestamp));

ctx = run_asd_patient_case(@patient_zoya, 'zoya', 'pre_surgery', ...
    struct('scaling_mode', 'lundquist_bsa', 'runBaselineSimulation', false));

mock_gsa = build_mock_gsa(ctx.curated_library, ctx.target_tiers);
[active_selection, optMask] = build_asd_active_mask_from_gsa( ...
    mock_gsa, ctx.curated_library, ctx.target_tiers, ...
    struct('AllowGroupC', false, 'CaseProfile', ctx.caseProfile));

summary = table( ...
    ["Purpose"; "Patient"; "Scenario"; "Case profile mode"; "Optimization run"; ...
     "Full GSA run"; "Model equations changed"; "Selected mock active count"; "Output file"], ...
    ["Verification-only ASD pipeline governance check"; string(ctx.label); ...
     string(ctx.scenario); string(ctx.caseProfile.mode); "NO"; "NO"; "NO"; ...
     string(sum(optMask)); string(excel_path)], ...
    'VariableNames', {'Topic','Details'});

writetable(summary, excel_path, 'Sheet', 'Summary');
writetable(vsd_to_asd_mapping_table(), excel_path, 'Sheet', 'VSD_to_ASD_File_Mapping');
writetable(profile_table(ctx.caseProfile), excel_path, 'Sheet', 'Case_Profile');
writetable(ctx.caseProfile.clinicalAvailability, excel_path, 'Sheet', 'Clinical_Availability');
writetable(ctx.target_tiers, excel_path, 'Sheet', 'Target_Tiers');
writetable(ctx.candidate_report.groupA, excel_path, 'Sheet', 'Candidate_Group_A');
writetable(ctx.candidate_report.groupB, excel_path, 'Sheet', 'Candidate_Group_B');
writetable(ctx.candidate_report.groupC, excel_path, 'Sheet', 'Candidate_Group_C');
writetable(ctx.curated_library, excel_path, 'Sheet', 'Curated_Parameter_Library');
writetable(active_selection, excel_path, 'Sheet', 'Active_Mask_Design');
writetable(objective_bundle_design_table(), excel_path, 'Sheet', 'Objective_Bundle_Design');
writetable(ctx.caseProfile.excludedTargetReasons, excel_path, 'Sheet', 'Excluded_Targets');
writetable(ctx.caseProfile.predictionOnlyOutputs, excel_path, 'Sheet', 'Prediction_Only_Outputs');
writetable(ctx.candidate_report.warnings, excel_path, 'Sheet', 'Warnings');
writetable(notes_table(), excel_path, 'Sheet', 'Notes');

fprintf('ASD pipeline governance workbook written:\n  %s\n', excel_path);

function mock_gsa = build_mock_gsa(library, target_tiers)
% BUILD_MOCK_GSA - deterministic fake ST matrix for mask wiring only.
names = cellstr(library.Parameter);
metrics = cellstr(unique(target_tiers.ModelField(target_tiers.IncludeInGSA), 'stable'));
ST = 0.01 * ones(numel(names), numel(metrics));
priority = {'asd.Cd','R.SAR','R.SC','R.PCOX','C.PAR'};
for i = 1:numel(priority)
    row_idx = find(strcmp(names, priority{i}), 1);
    if ~isempty(row_idx)
        ST(row_idx, :) = 0.20 - 0.01 * i;
    end
end
mock_gsa = struct();
mock_gsa.sobol = struct('Parameter', {names}, 'Metric', {metrics}, ...
    'ST', ST, 'S1', 0.5 * ST);
mock_gsa.cfg = struct('source', 'mock_ST_for_governance_check_only');
end

function tbl = vsd_to_asd_mapping_table()
% VSD_TO_ASD_MAPPING_TABLE - file-level methodology mapping.
rows = {
    "main_run.m step orchestration", "run_asd_patient_case.m + Zoya wrapper scripts", "Adapted", "ASD keeps wrappers while context builder is patient-generic."
    "build_case_calibration_profile.m", "build_asd_case_calibration_profile.m", "Adapted", "ASD-specific data availability and shunt fields."
    "build_target_tiers.m", "build_asd_target_tiers.m", "Adapted", "Pressure-flow target tiers plus ASD shunt comparison."
    "calibration_param_sets.m / build_parameter_registry.m", "asd_candidate_param_sets.m + build_asd_curated_parameter_library.m", "Adapted", "ASD Groups A/B/C with Cd instead of VSD resistance in orifice mode."
    "create_optimization_mask.m", "build_asd_active_mask_from_gsa.m", "Adapted", "Adds target-tier and Group C governance."
    "objective_calibration.m", "objective_calibration_asd.m", "Adapted", "ASD pressure-flow and shunt mechanism guards."
    "run_calibration.m", "scripts/run_zoya_asd_calibration.m", "Wrapper", "Zoya wrapper should call generic context and ASD objective."
    "src/gsa/*", "scripts/run_zoya_asd_gsa_curated.m", "Adapted", "Curated A+B+C Sobol runner; no optimization."
    };
tbl = cell2table(rows, 'VariableNames', {'VSD_Component','ASD_Component','Status','Notes'});
end

function tbl = profile_table(caseProfile)
% PROFILE_TABLE - compact scalar case-profile view.
rows = {
    "Patient label", string(caseProfile.patient_label)
    "Patient id", string(caseProfile.patient_id)
    "Scenario requested", string(caseProfile.scenario_requested)
    "Scenario key", string(caseProfile.scenario_key)
    "Scenario phase", string(caseProfile.scenario_phase)
    "Mode", string(caseProfile.mode)
    "Description", string(caseProfile.description)
    "Group C calibration allowed by default", string(caseProfile.allowedCandidateGroups.GroupCCalibrationAllowedByDefault)
    };
tbl = cell2table(rows, 'VariableNames', {'Field','Value'});
end

function tbl = objective_bundle_design_table()
% OBJECTIVE_BUNDLE_DESIGN_TABLE - objective components without running optimization.
rows = {
    "Primary pressure-flow", "QpQs; Qp_Lmin; Qs_Lmin; SAP_mean; PAP_mean; LAP_mean", "Hard calibration bundle when available."
    "Secondary pressure guard", "SAP_max; SAP_min; PAP_max; PAP_min", "Guard measured waveforms without dominating primary fit."
    "ASD shunt mechanism guard", "Q_ASD_Lmin; QpQs; direction", "Penalize closed/opposite shunt in pre-closure ASD."
    "Pressure preservation guard", "SBP/DBP/PAP guards vs baseline", "Avoid improving shunt severity by destroying measured pressures."
    "Parameter plausibility", "distance from bounds and seeded baseline", "Discourage non-identifiable parameter drift."
    "Validity penalties", "solver success; steady state; finite outputs; broad physiological envelopes", "Numerical and physiological safety."
    "Excluded target handling", "LV/RV volume and EF for sparse-volume Zoya", "Prediction-only until clinical targets exist."
    };
tbl = cell2table(rows, 'VariableNames', {'Component','Fields','Purpose'});
end

function tbl = notes_table()
% NOTES_TABLE - methodological boundaries for this verification run.
rows = {
    "No optimization", "This script does not call fmincon or tune parameters."
    "No full GSA", "Only a deterministic mock ST matrix is used to verify active-mask wiring."
    "No model-equation changes", "Physics files are not edited or executed for calibration."
    "Patient generic", "Zoya enters as @patient_zoya plus label; downstream builders consume caseProfile."
    "Next step", "Run smoke curated GSA, then thesis-level N only after review."
    };
tbl = cell2table(rows, 'VariableNames', {'Topic','Note'});
end
