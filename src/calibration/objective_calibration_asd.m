function J = objective_calibration_asd(x, params0, calib, param_names, lb_vec, ub_vec, ...
    apply_overrides_fn, integrate_fn, compute_metrics_fn)
% OBJECTIVE_CALIBRATION_ASD
% -----------------------------------------------------------------------
% ASD-specific, VSD-aligned calibration objective scaffold.
%
% Multi-term objective:
%   J = J_primary
%     + lambda_secondary * J_secondary
%     + J_shunt_guard
%     + J_pressure_guard
%     + J_parameter_drift
%     + J_plausibility
%     + J_boundary
%     + J_validity
%     + J_steady_state
%
% INPUTS:
%   x                  - active calibration parameter values             [-]
%   params0            - seeded ASD parameter struct                     [-]
%   calib              - calibration config with target tiers/profile    [-]
%   param_names        - dot-notation parameter names                    [-]
%   lb_vec, ub_vec     - lower/upper bounds aligned to x                 [-]
%   apply_overrides_fn - simulation override function handle             [-]
%   integrate_fn       - ODE integration function handle                 [-]
%   compute_metrics_fn - clinical-index function handle                  [-]
%
% OUTPUTS:
%   J                  - scalar objective value                          [-]
%
% ASSUMPTIONS:
%   - Qp/Qs, Qp, Qs, SAP_mean, PAP_mean, and LAP_mean are the primary
%     pressure-flow bundle when available in target tiers.
%   - Secondary pressures are guard terms, not independent hard targets.
%   - ASD mechanism checks are penalties only; they do not replace clinical
%     target fitting.
%
% SIGN CONVENTIONS:
%   - Positive Q_ASD_Lmin means LA-to-RA shunt flow.
%
% REFERENCES:
%   [1] C:/Users/Diniya/unified-vsd-temp/src/calibration/objective_calibration.m
%   [2] src/calibration/build_asd_target_tiers.m
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  1.0
% -----------------------------------------------------------------------

INVALID_PENALTY = 1e6;
SS_FAIL_PENALTY = 1e5;

[params, ok] = apply_parameter_vector(params0, param_names, x);
if ~ok
    J = INVALID_PENALTY;
    return;
end

params = apply_overrides_fn(params, calib.simOverrides);

try
    sim = integrate_fn(params);
    solver_success = isfield(sim, 't') && ~isempty(sim.t) && ...
        isfield(sim, 'V') && all(isfinite(sim.V(:)));
catch
    J = INVALID_PENALTY;
    return;
end

if ~solver_success
    J = INVALID_PENALTY;
    return;
end

metrics = compute_metrics_fn(sim, params);
if ~isstruct(metrics)
    J = INVALID_PENALTY;
    return;
end

[J_primary, n_primary] = target_bundle_penalty(metrics, calib, ...
    'targets', 'targetFields', optional_scalar(calib, 'primaryTarget', 0.05));
if n_primary == 0
    J = INVALID_PENALTY;
    return;
end

[J_secondary, ~] = target_bundle_penalty(metrics, calib, ...
    'secondaryTargets', 'secondaryTargetFields', ...
    optional_scalar(calib, 'secondaryTarget', ...
    optional_scalar(calib, 'secondaryTargetTolerance', 0.15)));

J_shunt_guard = asd_shunt_mechanism_guard(metrics, calib);
J_pressure_guard = pressure_preservation_guard(metrics, calib);
J_parameter_drift = parameter_drift_penalty(x, calib);
J_plausibility = near_boundary_penalty(x, lb_vec, ub_vec);
J_boundary = outside_boundary_penalty(x, lb_vec, ub_vec);
J_validity = physiological_validity_penalty(metrics);

J_ss = 0;
if ~isfield(sim, 'ss_reached') || ~sim.ss_reached
    J_ss = SS_FAIL_PENALTY;
end

J = J_primary ...
    + optional_scalar(calib, 'secondaryLambda', 0.35) * J_secondary ...
    + optional_scalar(calib, 'shuntGuardLambda', 1.0) * J_shunt_guard ...
    + optional_scalar(calib, 'pressureGuardLambda', 0.5) * J_pressure_guard ...
    + optional_scalar(calib, 'parameterDriftLambda', 0.10) * J_parameter_drift ...
    + optional_scalar(calib, 'plausibilityLambda', 0.5) * J_plausibility ...
    + optional_scalar(calib, 'boundaryLambda', 20.0) * J_boundary ...
    + J_validity ...
    + J_ss;

if ~isfinite(J)
    J = INVALID_PENALTY;
end

end

function [params, ok] = apply_parameter_vector(params0, param_names, x)
% APPLY_PARAMETER_VECTOR - write dot-notation parameters into struct.
params = params0;
ok = true;
for idx = 1:numel(param_names)
    parts = strsplit(param_names{idx}, '.');
    switch numel(parts)
        case 2
            params.(parts{1}).(parts{2}) = x(idx);
        case 3
            params.(parts{1}).(parts{2}).(parts{3}) = x(idx);
        otherwise
            ok = false;
            return;
    end
end
end

function [J_bundle, n_used] = target_bundle_penalty(metrics, calib, target_struct_name, fields_name, tolerance)
% TARGET_BUNDLE_PENALTY - normalized squared clinical target error.
J_bundle = 0;
n_used = 0;
if ~isfield(calib, target_struct_name) || ~isfield(calib, fields_name)
    return;
end
targets = calib.(target_struct_name);
fields = calib.(fields_name);
for idx = 1:numel(fields)
    fn = fields{idx};
    if isfield(metrics, fn) && isfield(targets, fn) && ...
            isfinite(metrics.(fn)) && isfinite(targets.(fn)) && abs(targets.(fn)) > 1e-9
        err_rel = abs(metrics.(fn) - targets.(fn)) / abs(targets.(fn));
        J_bundle = J_bundle + (err_rel / tolerance)^2;
        n_used = n_used + 1;
    end
end
end

function J_guard = asd_shunt_mechanism_guard(metrics, calib)
% ASD_SHUNT_MECHANISM_GUARD - penalize violated pre-closure ASD mechanism.
J_guard = 0;
if ~is_preclosure(calib)
    return;
end
if isfield(metrics, 'Q_ASD_Lmin') && isfinite(metrics.Q_ASD_Lmin)
    if metrics.Q_ASD_Lmin <= 0
        J_guard = J_guard + 25 * (1 + abs(metrics.Q_ASD_Lmin));
    end
elseif isfield(metrics, 'Q_shunt_Lmin') && isfinite(metrics.Q_shunt_Lmin)
    if metrics.Q_shunt_Lmin <= 0
        J_guard = J_guard + 25 * (1 + abs(metrics.Q_shunt_Lmin));
    end
end
if isfield(metrics, 'QpQs') && isfinite(metrics.QpQs) && metrics.QpQs <= 1
    J_guard = J_guard + 25 * (1 + abs(1 - metrics.QpQs));
end
end

function tf = is_preclosure(calib)
% IS_PRECLOSURE - read phase from caseProfile when available.
tf = true;
if isfield(calib, 'caseProfile') && isstruct(calib.caseProfile) && ...
        isfield(calib.caseProfile, 'scenario_phase')
    tf = strcmp(char(calib.caseProfile.scenario_phase), 'pre_closure');
end
end

function J_guard = pressure_preservation_guard(metrics, calib)
% PRESSURE_PRESERVATION_GUARD - avoid worsening already-close measured pressures.
J_guard = 0;
if ~isfield(calib, 'guardBaselineMetrics') || ~isstruct(calib.guardBaselineMetrics)
    return;
end
if ~isfield(calib, 'secondaryTargets') || ~isfield(calib, 'secondaryTargetFields')
    return;
end
baseline = calib.guardBaselineMetrics;
tolerance_pct = optional_scalar(calib, 'maxGuardWorseningPct', 5.0);
for idx = 1:numel(calib.secondaryTargetFields)
    fn = calib.secondaryTargetFields{idx};
    if ~isfield(metrics, fn) || ~isfield(baseline, fn) || ...
            ~isfield(calib.secondaryTargets, fn)
        continue;
    end
    target = calib.secondaryTargets.(fn);
    if ~isfinite(metrics.(fn)) || ~isfinite(baseline.(fn)) || ...
            ~isfinite(target) || abs(target) <= 1e-9
        continue;
    end
    base_err_pct = abs(baseline.(fn) - target) / abs(target) * 100;
    new_err_pct = abs(metrics.(fn) - target) / abs(target) * 100;
    if base_err_pct <= 15 && new_err_pct > base_err_pct + tolerance_pct
        J_guard = J_guard + ((new_err_pct - base_err_pct) / 10)^2;
    end
end
end

function penalty = parameter_drift_penalty(x, calib)
% PARAMETER_DRIFT_PENALTY - discourage unnecessary movement from seed.
penalty = 0;
if ~isfield(calib, 'x0Reference') || isempty(calib.x0Reference)
    return;
end
x0 = calib.x0Reference(:);
x = x(:);
n = min(numel(x), numel(x0));
valid = isfinite(x(1:n)) & isfinite(x0(1:n)) & x0(1:n) > 0;
if any(valid)
    ratio = x(valid) ./ x0(valid);
    penalty = sum(log(max(ratio, 1e-9)).^2);
end
end

function penalty = near_boundary_penalty(x, lb_vec, ub_vec)
% NEAR_BOUNDARY_PENALTY - discourage parking near parameter bounds.
penalty = 0;
for idx = 1:numel(x)
    span = max(ub_vec(idx) - lb_vec(idx), 1e-9);
    dist_lower = (x(idx) - lb_vec(idx)) / span;
    dist_upper = (ub_vec(idx) - x(idx)) / span;
    penalty = penalty + max(0, 0.10 - dist_lower)^2 + ...
        max(0, 0.10 - dist_upper)^2;
end
end

function penalty = outside_boundary_penalty(x, lb_vec, ub_vec)
% OUTSIDE_BOUNDARY_PENALTY - hard penalty if optimizer steps outside bounds.
penalty = 0;
for idx = 1:numel(x)
    if x(idx) < lb_vec(idx)
        penalty = penalty + ((lb_vec(idx) - x(idx)) / max(abs(lb_vec(idx)), 1e-6))^2;
    elseif x(idx) > ub_vec(idx)
        penalty = penalty + ((x(idx) - ub_vec(idx)) / max(abs(ub_vec(idx)), 1e-6))^2;
    end
end
end

function penalty = physiological_validity_penalty(metrics)
% PHYSIOLOGICAL_VALIDITY_PENALTY - broad ASD safety envelope.
penalty = 0;
checks = {'QpQs','LVEF','RVEF','SVR','PVR','RAP_mean','LAP_mean','PAP_mean','SAP_mean'};
for idx = 1:numel(checks)
    fn = checks{idx};
    if ~isfield(metrics, fn) || ~isfinite(metrics.(fn))
        continue;
    end
    val = metrics.(fn);
    switch fn
        case 'QpQs'
            if val < 0.5 || val > 8.0, penalty = penalty + 100; end
        case {'LVEF','RVEF'}
            if val < 0.05 || val > 0.95, penalty = penalty + 50; end
        case 'SVR'
            if val < 0.5 || val > 60, penalty = penalty + 20; end
        case 'PVR'
            if val < 0.05 || val > 25, penalty = penalty + 20; end
        case {'RAP_mean','LAP_mean'}
            if val < -5 || val > 30, penalty = penalty + 20; end
        case 'PAP_mean'
            if val < 2 || val > 80, penalty = penalty + 20; end
        case 'SAP_mean'
            if val < 30 || val > 160, penalty = penalty + 20; end
    end
end
end

function value = optional_scalar(s, field_name, default_value)
% OPTIONAL_SCALAR - scalar config reader with fallback.
value = default_value;
if isstruct(s) && isfield(s, field_name) && isscalar(s.(field_name)) && ...
        isfinite(s.(field_name))
    value = s.(field_name);
end
end
