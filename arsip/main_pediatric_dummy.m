% MAIN_PEDIATRIC_DUMMY
% -------------------------------------------------------------------------
% Forward-only pediatric ASD smoke test:
%   Load adult baseline -> load dummy clinical profile -> apply scaling
%   -> run integration -> print ASD clinical metrics.
% -------------------------------------------------------------------------

clear; clc; close all;

project_root = fileparts(mfilename('fullpath'));
addpath(fullfile(project_root, 'config'));
addpath(fullfile(project_root, 'models'));
addpath(fullfile(project_root, 'solvers'));
addpath(fullfile(project_root, 'utils'));

fprintf('\n=== PEDIATRIC ASD DUMMY FORWARD SIMULATION ===\n');

[params_ref, ~] = default_parameters();
clinical = patient_dummy_pediatric_asd();

fprintf('\n--- Clinical Dummy Input ---\n');
fprintf('  Patient ID : %s\n', clinical.common.patient_id);
fprintf('  Age        : %.1f years\n', clinical.common.age_years);
fprintf('  Height     : %.1f cm\n', clinical.common.height_cm);
fprintf('  Weight     : %.1f kg\n', clinical.common.weight_kg);
fprintf('  BSA        : %.3f m^2\n', clinical.common.BSA);
fprintf('  HR target  : %.1f bpm\n', clinical.common.HR);
fprintf('  BP target  : %.0f/%.0f mmHg\n', ...
    clinical.asd_pre.SAP_sys_mmHg, clinical.asd_pre.SAP_dia_mmHg);
fprintf('  Qp/Qs target: %.2f\n', clinical.asd_pre.QpQs);

[params, X0] = apply_scaling(params_ref, clinical, 'asd_pre');

fprintf('\n--- ASD Setup ---\n');
fprintf('  Mode       : %s\n', params.asd.mode);
fprintf('  Diameter   : %.1f mm\n', params.asd.diameter_mm);
fprintf('  Area       : %.1f mm^2\n', params.asd.area_mm2);
fprintf('  R_ASD      : %.4f mmHg*s/mL\n', params.R_ASD);
fprintf('  PVR scale  : %.3f\n', params.forward_seed.pulmonary_resistance_scale);
fprintf('  C_sa scale : %.3f\n', params.forward_seed.systemic_arterial_compliance_scale);
fprintf('  is_post_op : %d\n', params.is_post_op);

fprintf('\n--- Solver ---\n');
[t_sol, ~, t_ss, X_ss] = integrate_system(params, X0);
fprintf('  Samples returned: %d full, %d steady-cycle\n', numel(t_sol), numel(t_ss));

indices = compute_clinical_indices(t_ss, X_ss, params);

fprintf('\n=== PEDIATRIC ASD DUMMY RESULT ===\n');
fprintf('  Qp/Qs simulated : %.3f (target %.2f)\n', ...
    indices.Q_ratio, clinical.asd_pre.QpQs);
fprintf('  Qp              : %.3f L/min\n', indices.Q_pulmonary);
fprintf('  Qs              : %.3f L/min\n', indices.Q_systemic);
fprintf('  ASD shunt       : %.3f L/min (%.2f mL/s)\n', ...
    indices.Q_ASD_Lmin, indices.Q_ASD_mean_mLs);
fprintf('  ASD direction   : %s\n', indices.ASD_direction);
fprintf('  SAP             : %.1f/%.1f/%.1f mmHg (target %.0f/%.0f)\n', ...
    indices.P_ao_sys, indices.P_ao_dia, indices.P_ao_mean, ...
    clinical.asd_pre.SAP_sys_mmHg, clinical.asd_pre.SAP_dia_mmHg);
fprintf('  PAP mean        : %.1f mmHg\n', indices.P_pa_mean);
fprintf('  LA/RA mean      : %.2f / %.2f mmHg\n', ...
    indices.P_LA_mean, indices.P_RA_mean);
fprintf('  LV/RV EDV       : %.1f / %.1f mL\n', ...
    indices.V_lv_ed, indices.V_rv_ed);
fprintf('  LV/RV EF        : %.1f / %.1f %%\n', ...
    indices.EF_lv * 100.0, indices.EF_rv * 100.0);

qpqs_error_pct = abs(indices.Q_ratio - clinical.asd_pre.QpQs) ...
    / clinical.asd_pre.QpQs * 100.0;
stable_ltr = strcmp(indices.ASD_direction, 'left-to-right') && ...
    indices.Q_ratio > 1.2 && qpqs_error_pct < 35.0;

fprintf('\n--- Forward Simulation Check ---\n');
if stable_ltr
    fprintf('  PASS: scaled pediatric model is stable and shows L-to-R ASD shunting.\n');
else
    fprintf('  REVIEW: run completed, but shunt magnitude/direction needs tuning.\n');
end
fprintf('  Qp/Qs relative error vs dummy target: %.1f %%\n', qpqs_error_pct);
