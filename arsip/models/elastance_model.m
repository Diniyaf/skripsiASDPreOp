function E = elastance_model(t, chamber, params)
% ELASTANCE_MODEL
% -----------------------------------------------------------------------
% Computes the time-varying elastance E(t) for a cardiac chamber using
% the piecewise cosine activation model (double-hill approximation).
%
% Governing equation:
%   E(t) = Emin + (Emax - Emin) * e_n(t_rel)
%
%   where e_n is the normalized activation function:
%     e_n = 0.5*(1 - cos(pi*t_rel/T_sys))        if 0 <= t_rel < T_sys
%     e_n = 0.5*(1 + cos(pi*(t_rel-T_sys)/T_rel)) if T_sys <= t_rel < T_sys+T_rel
%     e_n = 0                                      otherwise
%
% INPUTS:
%   t        - current simulation time                     [s]
%   chamber  - string: 'lv', 'rv', 'la', or 'ra'          [-]
%   params   - parameter struct (see config/default_parameters.m)
%
% OUTPUTS:
%   E        - instantaneous chamber elastance             [mmHg/mL]
%
% ASSUMPTIONS:
%   - Atria contract ~0.18 s before ventricular systole (atrial kick)
%   - All chambers use identical piecewise cosine activation shape
%   - t_on defines onset of activation within each cardiac cycle
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter model post-ASD. Eq.(2).
%   [2] Heldt T et al. (2002). J Appl Physiol 92:1239-1254. Appendix.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

switch lower(chamber)
    case 'lv'
        Emax  = params.Emax_lv;    % [mmHg/mL]
        Emin  = params.Emin_lv;    % [mmHg/mL]
        t_on  = params.t_on_lv;    % [s]
        T_sys = params.T_sys_lv;   % [s]
        T_rel = params.T_rel_lv;   % [s]
    case 'rv'
        Emax  = params.Emax_rv;    % [mmHg/mL]
        Emin  = params.Emin_rv;    % [mmHg/mL]
        t_on  = params.t_on_rv;    % [s]
        T_sys = params.T_sys_rv;   % [s]
        T_rel = params.T_rel_rv;   % [s]
    case 'la'
        Emax  = params.Emax_la;    % [mmHg/mL]
        Emin  = params.Emin_la;    % [mmHg/mL]
        t_on  = params.t_on_la;    % [s]
        T_sys = params.T_sys_la;   % [s]
        T_rel = params.T_rel_la;   % [s]
    case 'ra'
        Emax  = params.Emax_ra;    % [mmHg/mL]
        Emin  = params.Emin_ra;    % [mmHg/mL]
        t_on  = params.t_on_ra;    % [s]
        T_sys = params.T_sys_ra;   % [s]
        T_rel = params.T_rel_ra;   % [s]
    otherwise
        error('elastance_model: unknown chamber "%s". Use lv, rv, la, or ra.', chamber);
end

% Normalised time within current activation period
t_rel = mod(t - t_on, params.T_cardiac);    % [s] — phase within cycle

% Normalised activation e_n in [0, 1]
e_n = compute_activation(t_rel, T_sys, T_rel);    % [dimensionless]

% Time-varying elastance
E = Emin + (Emax - Emin) * e_n;    % [mmHg/mL]

end

% ── LOCAL FUNCTION ──────────────────────────────────────────────────────
function e_n = compute_activation(t_rel, T_sys, T_rel)
% COMPUTE_ACTIVATION — piecewise cosine; inputs [s], output [dimensionless]
if t_rel < T_sys
    e_n = 0.5 * (1 - cos(pi * t_rel / T_sys));
elseif t_rel < (T_sys + T_rel)
    e_n = 0.5 * (1 + cos(pi * (t_rel - T_sys) / T_rel));
else
    e_n = 0;
end
end
