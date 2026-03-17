% MAIN
% -----------------------------------------------------------------------
% Entry point for the post-ASD closure 0D cardiovascular simulation.
% This file contains NO physics. It only:
%   1. Loads parameters and initial conditions
%   2. Calls the solver (integrate_system.m)
%   3. Computes derived clinical indices (compute_clinical_indices.m)
%   4. Generates plots (plotting_tools.m)
%
% USAGE:
%   >> main
%
% SCENARIO:
%   Post-ASD closure — params.R_ASD = Inf (no shunt flow)
%   Edit config/default_parameters.m to change scenario.
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter ASD model.
%   [2] Heldt T et al. (2002). J Appl Physiol 92:1239-1254.
%   See docs/theory_notes.md for governing equations.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

clear; clc; close all;

%% ── 1. ADD PATHS ────────────────────────────────────────────────────────

addpath(fullfile(pwd, 'config'));
addpath(fullfile(pwd, 'models'));
addpath(fullfile(pwd, 'solvers'));
addpath(fullfile(pwd, 'utils'));
addpath(fullfile(pwd, 'tests'));

%% ── 2. LOAD PARAMETERS AND INITIAL CONDITIONS ───────────────────────────

[params, X0] = patient_post_asd_parameters();    % Load patient-specific parameters

% ─ Scenario override: uncomment to set open-ASD condition ─
% params.R_ASD = 5.0;    % [mmHg·s/mL] — finite resistance for open ASD

fprintf('Running post-ASD closure simulation for pediatric patient...\n');
fprintf('  R_ASD = %s [mmHg·s/mL]\n', num2str(params.R_ASD));
fprintf('  Cycles: %d total, %d warm-up\n', params.n_cycles, params.n_warmup);

%% ── 3. INTEGRATE SYSTEM ─────────────────────────────────────────────────

[t_sol, X_sol, t_ss, X_ss] = integrate_system(params, X0);

%% ── 4. COMPUTE CLINICAL INDICES ──────────────────────────────────────────

indices = compute_clinical_indices(t_ss, X_ss, params);

%% ── 5. CLINICAL VALIDATION TARGETS (DUMMY PATIENT DATA) ─────────────────

% Define dummy patient data (absolute volumes)
dummy.LV_EDV = 102.0;   % [mL]
dummy.LV_ESV = 39.0;    % [mL]
dummy.LV_SV  = 63.0;    % [mL]
dummy.LV_EF  = 0.59;    % [fraction]
dummy.RV_EDV = 121.0;   % [mL]
dummy.RV_ESV = 55.0;    % [mL]
dummy.RV_SV  = 66.0;    % [mL]
dummy.RV_EF  = 0.49;    % [fraction]
dummy.CO     = 4.56;    % [L/min]
dummy.Qp_Qs  = 1.04;    % [dimensionless]

fprintf('\n=== SIMULATED vs DUMMY PATIENT DATA ===\n');
fprintf('Metric       | Dummy Data   | Simulated\n');
fprintf('-----------------------------------------\n');
fprintf('LV EDV       | %6.1f mL    | %6.1f mL\n', dummy.LV_EDV, indices.V_lv_ed);
fprintf('LV ESV       | %6.1f mL    | %6.1f mL\n', dummy.LV_ESV, indices.V_lv_es);
fprintf('LV SV        | %6.1f mL    | %6.1f mL\n', dummy.LV_SV, indices.SV_lv);
fprintf('LV EF        | %6.1f %%    | %6.1f %%\n', dummy.LV_EF * 100, indices.EF_lv * 100);
fprintf('RV EDV       | %6.1f mL    | %6.1f mL\n', dummy.RV_EDV, indices.V_rv_ed);
fprintf('RV ESV       | %6.1f mL    | %6.1f mL\n', dummy.RV_ESV, indices.V_rv_es);
fprintf('RV SV        | %6.1f mL    | %6.1f mL\n', dummy.RV_SV, indices.SV_rv);
fprintf('RV EF        | %6.1f %%    | %6.1f %%\n', dummy.RV_EF * 100, indices.EF_rv * 100);
fprintf('CO           | %6.2f L/min | %6.2f L/min\n', dummy.CO, indices.CO_systemic);
fprintf('Qp/Qs        | %6.3f        | %6.3f\n', dummy.Qp_Qs, indices.Q_ratio);

%% ── 6. GENERATE FIGURES ──────────────────────────────────────────────────

plotting_tools(t_ss, X_ss, indices, params);

fprintf('\nSimulation complete.\n');
