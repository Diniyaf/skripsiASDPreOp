%% run_zoya_asd_gsa_groupA.m
% RUN_ZOYA_ASD_GSA_GROUPA
% -------------------------------------------------------------------------
% Compatibility wrapper for the older Group-A-named GSA entry point.
%
% The active ASD GSA runner is now:
%   scripts/run_zoya_asd_gsa_curated.m
%
% That runner samples the curated ASD Groups A+B+C parameter library and
% builds the active calibration mask from Sobol ST plus ASD target-tier
% governance. This wrapper is retained so older notes or commands do not
% break, but new thesis workflow documentation should call the curated
% runner directly.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  3.0  (compatibility wrapper)
% -------------------------------------------------------------------------

run(fullfile(fileparts(mfilename('fullpath')), 'run_zoya_asd_gsa_curated.m'));
