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

[params, X0] = default_parameters();    % Load 28-parameter baseline set

% ─ Scenario override: uncomment to set open-ASD condition ─
% params.R_ASD = 5.0;    % [mmHg·s/mL] — finite resistance for open ASD

% ─ Scenario override: uncomment to apply pediatric scaling ─
% params = pediatric_scaling(params, 8, 25, 125);    % age=8y, 25kg, 125cm

fprintf('Running post-ASD closure simulation...\n');
fprintf('  R_ASD = %s [mmHg·s/mL]\n', num2str(params.R_ASD));
fprintf('  Cycles: %d total, %d warm-up\n', params.n_cycles, params.n_warmup);

%% ── 3. INTEGRATE SYSTEM ─────────────────────────────────────────────────

[t_sol, X_sol, t_ss, X_ss] = integrate_system(params, X0);

%% ── 4. COMPUTE CLINICAL INDICES ──────────────────────────────────────────

indices = compute_clinical_indices(t_ss, X_ss, params);

%% ── 5. GENERATE FIGURES ──────────────────────────────────────────────────

plotting_tools(t_ss, X_ss, indices, params);

fprintf('\nSimulation complete.\n');
