function [params, X0] = default_parameters()
% DEFAULT_PARAMETERS
% -----------------------------------------------------------------------
% Defines all physiological parameters and initial conditions for the
% post-ASD closure 0D lumped-parameter cardiovascular model.
%
% Returns the canonical 28-parameter set (elastance, resistances,
% compliances, inertances) plus valve switching parameters, the state
% vector index struct (idx), simulation control fields, and physiologically
% motivated initial conditions.
%
% INPUTS:
%   (none)
%
% OUTPUTS:
%   params - struct of all model parameters (see organised sections below)
%   X0     - initial state vector (14 x 1)              [mixed units]
%
% ASSUMPTIONS:
%   - Healthy adult at rest (HR = 75 bpm)
%   - Post-ASD closure: R_ASD = Inf (shunt absent)
%   - All 28 core parameters reference literature (cited inline)
%   - Valve dynamics use R_min/R_max switching (see valve_model.m)
%
% SIGN CONVENTIONS:
%   - Positive flow = physiologically forward direction
%   - Q_shunt_asd > 0 → left-to-right (LA to RA)
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter model post-ASD closure.
%   [2] Heldt T et al. (2002). Computational modeling of cardiovascular
%       response to orthostatic stress. J Appl Physiol 92:1239-1254.
%   [3] Shi Y et al. (2011). Review of zero-D and 1-D cardiovascular models.
%       Interface Focus 1:20-33.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

%% ── STATE VECTOR INDEX STRUCT ──────────────────────────────────────────
% Define once here; never modify across files. Access as X(idx.field).
% Units: volumes [mL], pressures [mmHg], flows [mL/s]

idx.V_lv = 1;    % LV volume                          [mL]
idx.V_rv = 2;    % RV volume                          [mL]
idx.V_la = 3;    % LA volume                          [mL]
idx.V_ra = 4;    % RA volume                          [mL]
idx.P_sa = 5;    % Systemic arterial pressure         [mmHg]
idx.P_sc = 6;    % Systemic capillary pressure        [mmHg]
idx.P_sv = 7;    % Systemic venous pressure           [mmHg]
idx.P_pa = 8;    % Pulmonary arterial pressure        [mmHg]
idx.P_pc = 9;    % Pulmonary capillary pressure       [mmHg]
idx.P_pv = 10;   % Pulmonary venous pressure          [mmHg]
idx.Q_sa = 11;   % Systemic arterial inertial flow    [mL/s]
idx.Q_sv = 12;   % Systemic venous inertial flow      [mL/s]
idx.Q_pa = 13;   % Pulmonary arterial inertial flow   [mL/s]
idx.Q_pv = 14;   % Pulmonary venous inertial flow     [mL/s]

params.idx    = idx;
params.n_state = 14;   % Total number of ODE state variables [dimensionless]

%% ── SIMULATION CONTROL ─────────────────────────────────────────────────

params.T_cardiac  = 0.8;   % Cardiac cycle period [s] — HR = 75 bpm
params.HR         = 75;    % Heart rate           [bpm]
params.n_cycles   = 50;    % Total cycles to simulate (warm-up + reporting)
params.n_warmup   = 40;    % Warm-up cycles before extracting results

%% ── VENTRICULAR ELASTANCE PARAMETERS ──── (Parameters 1–6 of 28) ──────
% Source: Valenti et al. (2023), Table 1; Heldt et al. (2002), Table A1

params.Emax_lv = 2.70;    % LV peak (end-systolic) elastance    [mmHg/mL]
params.Emin_lv = 0.069;   % LV minimum (diastolic) elastance    [mmHg/mL]
params.V0_lv   = 3.5385;  % LV unstressed volume                [mL]

params.Emax_rv = 0.43;    % RV peak elastance                   [mmHg/mL]
params.Emin_rv = 0.041264;% RV minimum elastance                [mmHg/mL]
params.V0_rv   = 8.4067;  % RV unstressed volume                [mL]

%% ── ATRIAL ELASTANCE PARAMETERS ──── (Parameters 7–12 of 28) ──────────
% Source: Shi et al. (2011), Table 1; assumed — needs validation

params.Emax_la = 0.38;    % LA peak elastance                   [mmHg/mL]
params.Emin_la = 0.27;    % LA minimum elastance                [mmHg/mL]
params.V0_la   = 2.3085;  % LA unstressed volume                [mL]

params.Emax_ra = 0.126;   % RA peak elastance                   [mmHg/mL]
params.Emin_ra = 0.195;   % RA minimum elastance                [mmHg/mL]
params.V0_ra   = 3.5385;  % RA unstressed volume                [mL]

%% ── SYSTEMIC VASCULAR PARAMETERS ──── (Parameters 13–20 of 30) ────────
% Source: Heldt et al. (2002), Appendix A; Shi et al. (2011), Table 2

params.R_sa = 0.5911;  % Systemic arterial resistance    [mmHg·s/mL]
params.R_sc = 0.0217;  % Systemic capillary resistance   [mmHg·s/mL]
params.R_sv = 0.3596;  % Systemic venous resistance      [mmHg·s/mL]

params.C_sa = 1.3315;  % Systemic arterial compliance    [mL/mmHg]
params.C_sc = 0.27981; % Systemic capillary compliance   [mL/mmHg]
params.C_sv = 75.0;    % Systemic venous compliance      [mL/mmHg]

params.L_sa = 2.9643e-4; % Systemic arterial inertance     [mmHg·s²/mL]
params.L_sv = 2.0643e-5; % Systemic venous inertance        [mmHg·s²/mL]

%% ── PULMONARY VASCULAR PARAMETERS ──── (Parameters 21–30 of 30) ───────
% Source: Valenti et al. (2023), Table 1; Shi et al. (2011), Table 2

params.R_pa = 0.0714;  % Pulmonary arterial resistance   [mmHg·s/mL]
params.R_pc = 0.017538;% Oxygenated pulmonary cap res.   [mmHg·s/mL]
params.R_sh = 0.35174; % Non-oxygenated pulm cap res.    [mmHg·s/mL]
params.R_pv = 0.0375;  % Pulmonary venous resistance     [mmHg·s/mL]

params.C_pa = 6.0043;  % Pulmonary arterial compliance   [mL/mmHg]
params.C_pc = 5.7803;  % Oxygenated pulmonary cap comp.  [mL/mmHg]
params.C_sh = 0.049043;% Non-oxygenated pulm cap comp.   [mL/mmHg]
params.C_pv = 11.381;  % Pulmonary venous compliance     [mL/mmHg]

params.L_pa = 2.0643e-5; % Pulmonary arterial inertance    [mmHg·s²/mL]
params.L_pv = 2.0643e-5; % Pulmonary venous inertance       [mmHg·s²/mL]

%% ── VALVE SWITCHING PARAMETERS (additional, beyond 28 core) ───────────
% R_min = open valve resistance; R_max = closed valve resistance
% Source: Shi et al. (2011); assumed — needs literature validation

params.R_mv_min = 0.0062872;  % Mitral valve open resistance      [mmHg·s/mL]
params.R_mv_max = 94168;      % Mitral valve closed resistance    [mmHg·s/mL]

params.R_ao_min = 0.0062872;  % Aortic valve open resistance      [mmHg·s/mL]
params.R_ao_max = 94168;      % Aortic valve closed resistance    [mmHg·s/mL]

params.R_tv_min = 0.0062872;  % Tricuspid valve open resistance   [mmHg·s/mL]
params.R_tv_max = 94168;      % Tricuspid valve closed resistance [mmHg·s/mL]

params.R_pv_valve_min = 0.0062872; % Pulmonary valve open res.       [mmHg·s/mL]
params.R_pv_valve_max = 94168;     % Pulmonary valve closed res.     [mmHg·s/mL]

%% ── ASD SHUNT PARAMETER ────────────────────────────────────────────────
% Post-closure condition: R_ASD = Inf → Q_shunt_asd = 0
% Source: Valenti et al. (2023), Eq. (shunt)

params.R_ASD = Inf;    % ASD shunt resistance [mmHg·s/mL]; Inf = closed

%% ── ELASTANCE TIMING PARAMETERS ────────────────────────────────────────
% Piecewise cosine activation model; atrial activation precedes ventricular
% Source: Valenti et al. (2023); Heldt et al. (2002), Section 2

T = params.T_cardiac;    % [s]

params.t_on_lv  = 0.00;  % LV activation onset [s]
params.T_sys_lv = 0.212; % LV systolic contraction (0.265 * 0.8) [s]
params.T_rel_lv = 0.32;  % LV relaxation (0.4 * 0.8)             [s]

params.t_on_rv  = 0.00;  % RV activation onset                   [s]
params.T_sys_rv = 0.24;  % RV systolic contraction (0.3 * 0.8)   [s]
params.T_rel_rv = 0.32;  % RV relaxation (0.4 * 0.8)             [s]

% Atrial activation timings
params.t_on_la  = 0.60;  % LA activation onset (0.75 * 0.8)      [s]
params.T_sys_la = 0.08;  % LA systolic contraction (0.1 * 0.8)   [s]
params.T_rel_la = 0.64;  % LA relaxation (0.8 * 0.8)             [s]

params.t_on_ra  = 0.64;  % RA activation onset (0.8 * 0.8)       [s]
params.T_sys_ra = 0.08;  % RA systolic contraction (0.1 * 0.8)   [s]
params.T_rel_ra = 0.56;  % RA relaxation (0.7 * 0.8)             [s]

%% ── INITIAL CONDITIONS ─────────────────────────────────────────────────
% Physiologically motivated near end-diastole; convergence verified in
% integrate_system.m. Sources: Heldt et al. (2002); assumed healthy adult.

X0 = zeros(params.n_state, 1);

X0(idx.V_lv) = 120.0;    % LV end-diastolic volume, ~LVEDV adult [mL]
X0(idx.V_rv) = 130.0;    % RV end-diastolic volume               [mL]
X0(idx.V_la) =  60.0;    % LA volume at start                    [mL]
X0(idx.V_ra) =  70.0;    % RA volume at start                    [mL]
X0(idx.P_sa) =  80.0;    % Approximate aortic diastolic pressure [mmHg]
X0(idx.P_sc) =  18.0;    % Systemic capillary pressure           [mmHg]
X0(idx.P_sv) =   6.0;    % Systemic venous pressure              [mmHg]
X0(idx.P_pa) =  12.0;    % Pulmonary artery diastolic pressure   [mmHg]
X0(idx.P_pc) =   7.0;    % Pulmonary capillary pressure          [mmHg]
X0(idx.P_pv) =   4.0;    % Pulmonary venous pressure             [mmHg]
X0(idx.Q_sa) =  83.3;    % Systemic arterial flow  (~5 L/min)    [mL/s]
X0(idx.Q_sv) =  83.3;    % Systemic venous flow                  [mL/s]
X0(idx.Q_pa) =  83.3;    % Pulmonary arterial flow               [mL/s]
X0(idx.Q_pv) =  83.3;    % Pulmonary venous flow                 [mL/s]

end
