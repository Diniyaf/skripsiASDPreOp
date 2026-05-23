function test_baseline()
% TEST_BASELINE
% -----------------------------------------------------------------------
% Runs the baseline cardiovascular simulation and asserts that all key
% haemodynamic indices fall within documented physiological reference
% ranges for a healthy adult at rest.
%
% This test MUST PASS before any patient-specific or disease model is run.
% If any assertion fails, the simulation outputs are invalid.
%
% VALIDATION CRITERIA (healthy adult at rest):
%   100 ≤ P_ao_sys  ≤ 140  [mmHg]  — Source: ESC guidelines 2023
%    60 ≤ P_ao_dia  ≤  90  [mmHg]  — Source: ESC guidelines 2023
%    10 ≤ P_pa_mean ≤  20  [mmHg]  — Source: Hoeper et al. (2013)
%  0.55 ≤ EF_lv     ≤ 0.75 [frac]  — Source: Lang et al. ASE (2015)
%   4.0 ≤ CO        ≤  8.0 [L/min] — Source: Guyton & Hall textbook
%   |Qp/Qs - 1| < 0.05    [−]      — Post-closure: shunts absent
%
% ADDITIONAL CHECKS:
%   Mass conservation: net volume change < 1e-3 mL over steady-state cycle
%
% INPUTS:   (none)
% OUTPUTS:  (none) — prints PASS/FAIL, throws error on first failure
%
% REFERENCES:
%   [1] ESC/ESH Guidelines for Hypertension (2023). Eur Heart J.
%   [2] Hoeper MM et al. (2013). J Am Coll Cardiol 62:D42-50.
%   [3] Lang RM et al. (2015). J Am Soc Echocardiogr 28:1-39.
%   [4] Guyton AC, Hall JE. Textbook of Medical Physiology, 14th Ed.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

fprintf('=== test_baseline: running baseline validation ===\n\n');

%% ── SETUP PATHS ─────────────────────────────────────────────────────────

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'models'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'solvers'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'utils'));

%% ── LOAD AND RUN ────────────────────────────────────────────────────────

[params, X0] = default_parameters();       % Baseline 28-parameter set
[~, ~, t_ss, X_ss] = integrate_system(params, X0);
indices = compute_clinical_indices(t_ss, X_ss, params);

%% ── ASSERTION BLOCK ─────────────────────────────────────────────────────
% OOR = Out Of Range. All thresholds from cited references above.

n_passed = 0;
n_failed = 0;
fail_msgs = {};

% Check 1: Aortic systolic pressure
[n_passed, n_failed, fail_msgs] = update_counts( ...
    indices.P_ao_sys, 100, 140, n_passed, n_failed, fail_msgs, ...
    'P_ao_sys', '[mmHg]');

% Check 2: Aortic diastolic pressure
[n_passed, n_failed, fail_msgs] = update_counts( ...
    indices.P_ao_dia, 60, 90, n_passed, n_failed, fail_msgs, ...
    'P_ao_dia', '[mmHg]');

% Check 3: Mean pulmonary artery pressure
[n_passed, n_failed, fail_msgs] = update_counts( ...
    indices.P_pa_mean, 10, 20, n_passed, n_failed, fail_msgs, ...
    'P_pa_mean', '[mmHg]');

% Check 4: LV ejection fraction
[n_passed, n_failed, fail_msgs] = update_counts( ...
    indices.EF_lv, 0.55, 0.75, n_passed, n_failed, fail_msgs, ...
    'EF_lv', '[fraction]');

% Check 5: Cardiac output
[n_passed, n_failed, fail_msgs] = update_counts( ...
    indices.CO_systemic, 4.0, 8.0, n_passed, n_failed, fail_msgs, ...
    'CO', '[L/min]');

% Check 6: Qp/Qs ratio (post-closure: should = 1.0 ± 0.05)
Q_ratio_error = abs(indices.Q_ratio - 1.0);    % [dimensionless]
if Q_ratio_error < 0.05
    fprintf('  [PASS] Qp/Qs = %.4f  (|ratio-1| = %.4f < 0.05)\n', ...
        indices.Q_ratio, Q_ratio_error);
    n_passed = n_passed + 1;
else
    msg = sprintf('Qp/Qs = %.4f  (|ratio-1| = %.4f >= 0.05)', ...
        indices.Q_ratio, Q_ratio_error);
    fprintf('  [FAIL] %s\n', msg);
    fail_msgs{end+1} = msg;    %#ok<AGROW>
    n_failed = n_failed + 1;
end

% Check 7: Mass conservation (net volume change < 1e-3 mL per cycle)
idx       = params.idx;
vol_cols  = [idx.V_lv, idx.V_rv, idx.V_la, idx.V_ra];    % volume state indices
V_total   = sum(X_ss(vol_cols, :), 1);                    % [mL] total cardiac volume

% Vascular volume = C * P for each compartment
P_sa_tr   = X_ss(idx.P_sa, :);  P_sc_tr = X_ss(idx.P_sc, :);
P_sv_tr   = X_ss(idx.P_sv, :);  P_pa_tr = X_ss(idx.P_pa, :);
P_pc_tr   = X_ss(idx.P_pc, :);  P_pv_tr = X_ss(idx.P_pv, :);

C_pc_eq   = params.C_pc + params.C_sh;    % Pulmonary capillary equivalent compliance [mL/mmHg]
V_vasc    = params.C_sa * P_sa_tr + params.C_sc * P_sc_tr + ...
            params.C_sv * P_sv_tr + params.C_pa * P_pa_tr + ...
            C_pc_eq * P_pc_tr + params.C_pv * P_pv_tr;    % [mL]

V_blood_total = V_total + V_vasc;                             % [mL]
mass_drift    = max(V_blood_total) - min(V_blood_total);      % [mL]

mass_tol = 1e-3;    % [mL] — acceptable drift threshold
if mass_drift < mass_tol
    fprintf('  [PASS] Mass conservation: drift = %.2e mL < %.0e mL\n', ...
        mass_drift, mass_tol);
    n_passed = n_passed + 1;
else
    msg = sprintf('Mass drift = %.4e mL >= %.0e mL tolerance', ...
        mass_drift, mass_tol);
    fprintf('  [FAIL] %s\n', msg);
    fail_msgs{end+1} = msg;    %#ok<AGROW>
    n_failed = n_failed + 1;
end

%% ── SUMMARY ─────────────────────────────────────────────────────────────

fprintf('\n--- test_baseline results: %d/%d passed ---\n', ...
    n_passed, n_passed + n_failed);

if n_failed > 0
    fprintf('FAILED assertions:\n');
    for k_f = 1 : length(fail_msgs)
        fprintf('  -> %s\n', fail_msgs{k_f});
    end
    error('test_baseline: %d assertion(s) failed. Simulation outputs invalid.', n_failed);
else
    fprintf('All assertions PASSED. Baseline validated.\n');
end

end

% ── LOCAL HELPER ─────────────────────────────────────────────────────────
function [np, nf, msgs] = update_counts(val, lo, hi, np, nf, msgs, name, unit)
% UPDATE_COUNTS — check value in [lo, hi] and update pass/fail tallies
    if val >= lo && val <= hi
        fprintf('  [PASS] %s = %.3f %s  (range [%.1f, %.1f])\n', ...
            name, val, unit, lo, hi);
        np = np + 1;
    else
        msg = sprintf('%s = %.3f %s  OOR [%.1f, %.1f]', name, val, unit, lo, hi);
        fprintf('  [FAIL] %s\n', msg);
        msgs{end+1} = msg;    %#ok<AGROW>
        nf = nf + 1;
    end
end
