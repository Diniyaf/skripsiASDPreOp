%% run_aluna_asd_calibration.m
% RUN_ALUNA_ASD_CALIBRATION
% -------------------------------------------------------------------------
% Thin patient-specific wrapper for Patient Aluna ASD pre-closure
% calibration. The calibration logic lives in scripts/run_asd_calibration.m
% so that validation, rollback, plots, artefact export, and pre-to-post seed
% export remain patient-generic for future cases.
%
% Patient Aluna is a sparse pressure-only ASD case. Current clinical targets
% are systemic and pulmonary artery pressures only; flow, Qp/Qs, LAP/RAP,
% direct Q_ASD, and ventricular volume/function remain prediction-only.
%
% Recommended run for thesis-facing pressure-only calibration:
%   setenv('ASD_CALIB_ALLOW_GROUPC', '0');
%   run('scripts/run_aluna_asd_calibration.m');
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-07
% VERSION:  1.0
% -------------------------------------------------------------------------

clear; clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
restoredefaultpath;
addpath(project_root);
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
addpath(fullfile(project_root, 'scripts'));

options = struct();
options.scaling_mode = 'lundquist_bsa';
options.st_threshold = 0.10;
options.stage_a_success_rmse = 0.10;
options.export_seed = true;
options.export_latest_seed = false;  % keep timestamped seed in run folder
options.export_plots = true;
options.export_readme = true;

run_asd_calibration(@patient_aluna, 'aluna', 'pre_surgery', options);
