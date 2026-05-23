function diag = diagnose_atrial_pressures(t_ss, X_ss, params)
% DIAGNOSE_ATRIAL_PRESSURES
% -----------------------------------------------------------------------
% Exposes atrial pressure traces and ASD shunt diagnostics for one
% steady-state cycle. Used to audit LA-RA pressure gradient quality
% and understand shunt flow magnitude.
%
% INPUTS:
%   t_ss   - time vector for one steady-state cycle      [s]
%   X_ss   - state matrix (14 x N) for that cycle        [mixed]
%   params - parameter struct
%
% OUTPUTS:
%   diag   - struct with atrial pressure and shunt diagnostics
%
% USAGE (from main_pre_asd.m, after integrate_system):
%   diag = diagnose_atrial_pressures(t_ss, X_ss, params);
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-03-21
% VERSION:  1.0 — initial diagnostic scaffold
% -----------------------------------------------------------------------

idx   = params.idx;
n_pts = length(t_ss);

%% ── 1. RECONSTRUCT ATRIAL PRESSURE TRACES ──────────────────────────────
% P_la and P_ra are not ODE state variables: they are derived from
% volume and time-varying elastance. Recompute them explicitly here.

P_la_trace = zeros(1, n_pts);
P_ra_trace = zeros(1, n_pts);
Q_shunt_trace = zeros(1, n_pts);

for k = 1 : n_pts
    t_k   = t_ss(k);
    V_la  = X_ss(idx.V_la, k);
    V_ra  = X_ss(idx.V_ra, k);

    E_la  = elastance_model(t_k, 'la', params);
    E_ra  = elastance_model(t_k, 'ra', params);

    P_la_trace(k) = E_la * (V_la - params.V0_la);    % [mmHg]
    P_ra_trace(k) = E_ra * (V_ra - params.V0_ra);    % [mmHg]

    Q_shunt_trace(k) = asd_shunt_model(P_la_trace(k), P_ra_trace(k), params);
end

dT = t_ss(end) - t_ss(1);    % [s] — cycle duration

%% ── 2. SUMMARY STATISTICS ───────────────────────────────────────────────

LAP_mean       = trapz(t_ss, P_la_trace) / dT;          % [mmHg]
RAP_mean       = trapz(t_ss, P_ra_trace) / dT;          % [mmHg]
LAP_minus_RAP  = LAP_mean - RAP_mean;                   % [mmHg]

Q_shunt_mean   = trapz(t_ss, Q_shunt_trace) / dT;       % [mL/s]
Q_shunt_peak   = max(Q_shunt_trace);                     % [mL/s]
Q_shunt_min    = min(Q_shunt_trace);                     % [mL/s]

P_la_sys       = max(P_la_trace);    % LA peak pressure      [mmHg]
P_la_dia       = min(P_la_trace);    % LA minimum pressure   [mmHg]
P_ra_sys       = max(P_ra_trace);    % RA peak pressure      [mmHg]
P_ra_dia       = min(P_ra_trace);    % RA minimum pressure   [mmHg]

dP_trace       = P_la_trace - P_ra_trace;    % P_LA - P_RA over cycle
dP_mean        = trapz(t_ss, dP_trace) / dT;
dP_peak        = max(dP_trace);
dP_min         = min(dP_trace);    % Negative = R-to-L reversal

%% ── 3. ELASTANCE AUDIT ──────────────────────────────────────────────────
% Emax must be > Emin for contraction to RAISE chamber pressure.
% If Emax < Emin, the term (Emax-Emin)*e_n is negative → pressure DROPS
% during systole (inverted contraction).

fprintf('\n=== ATRIAL PRESSURE DIAGNOSTICS ===\n');
fprintf('  R_ASD          = %.3f mmHg.s/mL\n', params.R_ASD);
fprintf('\n--- Elastance Parameter Audit ---\n');

% LA check
flag_la = '';
if params.Emax_la <= params.Emin_la
    flag_la = ' *** BUG: Emax <= Emin (RA CONTRACTION INVERTED) ***';
end
fprintf('  LA: Emin=%.4f  Emax=%.4f  [Emax>Emin: %s]%s\n', ...
    params.Emin_la, params.Emax_la, ...
    tf_str(params.Emax_la > params.Emin_la), flag_la);

% RA check
flag_ra = '';
if params.Emax_ra <= params.Emin_ra
    flag_ra = ' *** BUG: Emax <= Emin (RA CONTRACTION INVERTED) ***';
end
fprintf('  RA: Emin=%.4f  Emax=%.4f  [Emax>Emin: %s]%s\n', ...
    params.Emin_ra, params.Emax_ra, ...
    tf_str(params.Emax_ra > params.Emin_ra), flag_ra);

fprintf('\n--- Atrial Pressure Summary (one steady-state cycle) ---\n');
fprintf('  LAP_mean       = %6.2f mmHg\n',  LAP_mean);
fprintf('  LAP_sys (peak) = %6.2f mmHg\n',  P_la_sys);
fprintf('  LAP_dia (min)  = %6.2f mmHg\n',  P_la_dia);
fprintf('\n');
fprintf('  RAP_mean       = %6.2f mmHg\n',  RAP_mean);
fprintf('  RAP_sys (peak) = %6.2f mmHg\n',  P_ra_sys);
fprintf('  RAP_dia (min)  = %6.2f mmHg\n',  P_ra_dia);
fprintf('\n');
fprintf('  LAP - RAP (mean) = %6.2f mmHg   <- driving gradient\n', LAP_minus_RAP);
fprintf('  dP peak (max)    = %6.2f mmHg\n', dP_peak);
fprintf('  dP min           = %6.2f mmHg   (<0 = R-to-L reversal)\n', dP_min);

fprintf('\n--- ASD Shunt Flow (Q_shunt_asd) ---\n');
fprintf('  Q_shunt_mean   = %7.3f mL/s\n',  Q_shunt_mean);
fprintf('  Q_shunt_peak   = %7.3f mL/s\n',  Q_shunt_peak);
fprintf('  Q_shunt_min    = %7.3f mL/s\n',  Q_shunt_min);
if Q_shunt_min < 0
    fprintf('  NOTE: Negative shunt flow detected (R-to-L reversal during part of cycle).\n');
end

fprintf('\n--- Interpretation ---\n');
if abs(LAP_minus_RAP) < 1.0
    fprintf('  WARNING: Mean LAP-RAP = %.2f mmHg — very small driving gradient.\n', LAP_minus_RAP);
    fprintf('           Shunt is pressure-gradient-limited, not resistance-limited.\n');
    fprintf('           R_ASD sweeps will not meaningfully change Qp/Qs.\n');
    fprintf('           --> Investigate atrial elastance ordering (Emax vs Emin).\n');
else
    fprintf('  OK: Mean LAP-RAP = %.2f mmHg — adequate driving gradient present.\n', LAP_minus_RAP);
end

%% ── 4. PACKAGE OUTPUT STRUCT ────────────────────────────────────────────

diag.LAP_mean      = LAP_mean;
diag.RAP_mean      = RAP_mean;
diag.LAP_minus_RAP = LAP_minus_RAP;
diag.dP_mean       = dP_mean;
diag.dP_peak       = dP_peak;
diag.dP_min        = dP_min;
diag.Q_shunt_mean  = Q_shunt_mean;
diag.Q_shunt_peak  = Q_shunt_peak;
diag.Q_shunt_min   = Q_shunt_min;
diag.P_la_trace    = P_la_trace;
diag.P_ra_trace    = P_ra_trace;
diag.Q_shunt_trace = Q_shunt_trace;

end

% ── LOCAL HELPER ─────────────────────────────────────────────────────────
function s = tf_str(val)
    if val; s = 'YES'; else; s = 'NO'; end
end
