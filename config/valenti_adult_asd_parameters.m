function [params, X0] = valenti_adult_asd_parameters()
% VALENTI_ADULT_ASD_PARAMETERS
% -------------------------------------------------------------------------
% Adult ASD pre-operative validation scenario based on Valenti et al. (2023).
%
% This configuration is for Phase 1 manual validation only. It starts from
% the healthy adult Table 3.3 baseline in default_parameters(), applies the
% ASD patient significant parameter changes reported in Valenti Table 4.5,
% and records a small manual tuning set to reproduce the reported Valenti
% Table 4.4 model output. No automatic optimization is performed here.
%
% OUTPUTS:
%   params - adult ASD parameter struct
%   X0     - initial state vector near the adult ASD catheter targets
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-05-10
% VERSION:  1.0 -- Phase 1 adult Valenti validation scenario
% -------------------------------------------------------------------------

[params, X0] = default_parameters();

params.is_post_op = false;       % Pre-op ASD: shunt open
params.R_ASD      = 1.25e-4;     % Valenti ASD calibrated septal resistance [mmHg*s/mL]

% Valenti Table 4.5 significant ASD patient changes. Elastance values are
% stored in local peak/passive form: Emax = E_A + E_B, Emin = E_B.
params.R_pa = 0.079;             % Pulmonary arterial resistance [mmHg*s/mL]
params.R_pv = 0.003;             % Pulmonary venous resistance [mmHg*s/mL]
params.C_pa = 3.095;             % Pulmonary arterial compliance [mL/mmHg]
params.R_sv = 0.2956;            % Systemic venous resistance [mmHg*s/mL]

% Manual Phase 1 tuning against Valenti Table 4.4 model-output benchmark.
% The active amplitudes remain anchored to Table 4.5; the passive terms and
% systemic arterial resistance are adjusted to match the adult pressure-flow
% operating point before pediatric scaling.
params.R_sa = 0.738875;           % Tuned systemic arterial resistance [mmHg*s/mL]

params.Emax_lv = 1.50 + 0.165;    % LV peak elastance [mmHg/mL]
params.Emin_lv = 0.165;           % LV passive elastance [mmHg/mL]
params.Emax_rv = 0.60 + 0.10;     % RV peak elastance [mmHg/mL]
params.Emin_rv = 0.10;            % RV passive elastance [mmHg/mL]

% Initial conditions near the adult ASD haemodynamic state. These values
% are warm-start guesses only; the solver still runs to periodic steady state.
idx = params.idx;

X0(idx.V_lv) = 115.0;    % LV volume near adult diastolic state [mL]
X0(idx.V_rv) = 145.0;    % RV volume elevated by L-to-R ASD shunt [mL]
X0(idx.V_la) =  40.0;    % LA volume [mL]
X0(idx.V_ra) =  70.0;    % RA volume [mL]

X0(idx.P_sa) =  70.0;    % Systemic arterial pressure near SAPmin [mmHg]
X0(idx.P_sc) =  28.0;    % Systemic capillary pressure [mmHg]
X0(idx.P_sv) =  37.0;    % Systemic venous stressed pressure [mmHg]
X0(idx.P_pa) =  20.0;    % Pulmonary arterial pressure near PAPmin [mmHg]
X0(idx.P_pc) =  20.0;    % Pulmonary capillary pressure [mmHg]
X0(idx.P_pv) =  17.0;    % Pulmonary venous wedge pressure [mmHg]

X0(idx.Q_sa) =  51.5;    % Qs target 3.09 L/min converted to mL/s [mL/s]
X0(idx.Q_sv) =  51.5;    % Systemic venous return [mL/s]
X0(idx.Q_pa) = 131.0;    % Qp target 7.86 L/min converted to mL/s [mL/s]
X0(idx.Q_pv) = 131.0;    % Pulmonary venous return [mL/s]

end
