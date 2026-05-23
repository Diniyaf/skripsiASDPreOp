% MAIN_VALENTI_ADULT_VALIDATION
% -------------------------------------------------------------------------
% Phase 1 adult validation runner for the Valenti et al. (2023) ASD case.
%
% Workflow:
%   1. Load adult Valenti ASD parameters
%   2. Audit Table 3.3 parameter matching and model blood-volume bookkeeping
%   3. Simulate to periodic steady state using ode15s
%   4. Compare outputs against Valenti Table 4.4 clinical targets
%   5. Append validation rows to the master Excel workbook
%
% No L-BFGS-B or automatic optimization is used in this script.
% -------------------------------------------------------------------------

clear; clc; close all;

addpath(fullfile(pwd, 'config'));
addpath(fullfile(pwd, 'models'));
addpath(fullfile(pwd, 'solvers'));
addpath(fullfile(pwd, 'utils'));

fprintf('=== PHASE 1: VALENTI ADULT ASD VALIDATION ===\n');

[params, X0] = valenti_adult_asd_parameters();

parameter_audit = valenti_table33_parameter_audit(default_parameters_only());
volume_audit = compute_blood_volume_audit(params, X0);

fprintf('\n--- Blood Volume Audit ---\n');
fprintf('  params.V_blood reference      : %.1f mL\n', ...
    volume_audit.reference_total_blood_volume);
fprintf('  Initial chamber volume        : %.1f mL\n', ...
    volume_audit.initial_chamber_volume);
fprintf('  Initial vascular stressed vol.: %.1f mL\n', ...
    volume_audit.initial_vascular_stressed_volume);
fprintf('  Initial dynamic state volume  : %.1f mL\n', ...
    volume_audit.initial_dynamic_volume);
fprintf('  Chamber unstressed volume     : %.1f mL\n', ...
    volume_audit.chamber_unstressed_volume);
fprintf('  Vascular unstressed volume    : %.1f mL (not explicit in state vector)\n', ...
    volume_audit.vascular_unstressed_volume_modeled);
fprintf('  Implicit gap to 5 L reference : %.1f mL\n', ...
    volume_audit.implicit_volume_gap_to_reference);

fprintf('\n--- Solver ---\n');
fprintf('  Solver: ode15s\n');
fprintf('  RelTol: 1e-6\n');
fprintf('  AbsTol: 1e-8\n');

[~, ~, t_ss, X_ss] = integrate_system(params, X0);

metrics = compute_valenti_adult_metrics(t_ss, X_ss, params);
[validation_model_table, validation_model_summary] = ...
    compare_valenti_adult_targets(metrics, 'model_output');
[validation_clinical_table, validation_clinical_summary] = ...
    compare_valenti_adult_targets(metrics, 'clinical');
validation_table = [validation_model_table; validation_clinical_table];

fprintf('\n--- Valenti Table 4.4 Model-Output Reproduction ---\n');
disp(validation_model_table(:, {'metric_name', 'target_value', 'simulated_value', ...
    'error_percent', 'unit'}));
fprintf('  RMSE percentage : %.2f %%\n', validation_model_summary.rmse_percent);
fprintf('  MAPE percentage : %.2f %%\n', validation_model_summary.mape_percent);
fprintf('  Max abs error   : %.2f %%\n', ...
    validation_model_summary.max_abs_error_percent);

fprintf('\n--- Valenti Table 4.4 Clinical-Value Error ---\n');
disp(validation_clinical_table(:, {'metric_name', 'target_value', ...
    'simulated_value', 'error_percent', 'unit'}));
fprintf('  RMSE percentage : %.2f %%\n', ...
    validation_clinical_summary.rmse_percent);
fprintf('  MAPE percentage : %.2f %%\n', ...
    validation_clinical_summary.mape_percent);
fprintf('  Max abs error   : %.2f %%\n', ...
    validation_clinical_summary.max_abs_error_percent);

payload.scenario = 'Valenti Adult ASD Pre-Op';
payload.stage = 'adult_baseline_validation';
payload.description = 'Manual Phase 1 validation against Valenti Table 4.4; no optimizer.';
payload.params = params;
payload.valenti_adult_validation = validation_table;
payload.method_notes = { ...
    'Pulmonary capillary branch uses R_eq=(R_pc*R_sh)/(R_pc+R_sh) and C_eq=C_pc+C_sh.'; ...
    'Valve model uses non-regurgitant square-root smoothed diode flow.'; ...
    'ASD sign convention is positive for left-to-right LA-to-RA shunt.'; ...
    sprintf('Valenti Table 4.4 model-output RMSE percentage = %.2f%%.', ...
    validation_model_summary.rmse_percent); ...
    sprintf('Valenti Table 4.4 clinical-value RMSE percentage = %.2f%%.', ...
    validation_clinical_summary.rmse_percent)};

manifest = export_to_master_excel(payload);

fprintf('\nExported validation to: %s\n', manifest.master_file);
fprintf('Run folder: %s\n', manifest.run_folder);

% Keep key outputs in the MATLAB workspace if run interactively.
assignin('base', 'valenti_parameter_audit', parameter_audit);
assignin('base', 'valenti_volume_audit', volume_audit);
assignin('base', 'valenti_validation_table', validation_table);
assignin('base', 'valenti_model_validation_summary', validation_model_summary);
assignin('base', 'valenti_clinical_validation_summary', validation_clinical_summary);
assignin('base', 'valenti_manifest', manifest);

function params = default_parameters_only()
    [params, ~] = default_parameters();
end
