function J = asd_calibration_objective(varargin)
% ASD_CALIBRATION_OBJECTIVE
% -----------------------------------------------------------------------
% Backward-compatible wrapper for objective_calibration_asd().
%
% New ASD calibration code should call objective_calibration_asd directly.
% This wrapper preserves older Zoya scripts/tests while the workflow is
% being refactored toward a patient-generic VSD-aligned pipeline.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  3.0
% -----------------------------------------------------------------------

J = objective_calibration_asd(varargin{:});

end
