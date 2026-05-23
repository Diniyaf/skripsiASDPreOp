function [params, X0] = patient_post_asd_parameters()
% PATIENT_POST_ASD_PARAMETERS
% -----------------------------------------------------------------------
% Patient-specific parameters for a post-transcatheter ASD closure scenario.
% 
% Clinical targets (Arvidsson et al. 2026, Table 1, post-closure cohort):
%   - Age 10, Female, 153 cm, 38 kg (BSA ~1.27 m^2)
%   - HR_target   = 77 bpm    -> T_cardiac = 0.779 s
%   - LV_EDV      ~ 102 mL   (LV_EDVi=76 ml/m^2 * BSA=1.34)
%   - LV_SV       ~  63 mL   -> CO ~ 4.56 L/min
%   - LV_EF       ~ 0.59
%   - RV_EDV      ~ 121 mL
%   - RV_EF       ~ 0.49
%   - Qp/Qs       ~ 1.0 (ASD sealed, no shunt)
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-03-17
% VERSION:  1.2 -- re-calibrated vascular & timing parameters
% -----------------------------------------------------------------------

%% -- 1. LOAD ADULT BASELINE AND APPLY SCALING ---------------------------
[params, ~] = default_parameters();

age_years  = 10;
weight_kg  = 38;
height_cm  = 153;
sex        = 0;   % Female
params     = pediatric_scaling(params, age_years, weight_kg, height_cm, sex);

%% -- 2. PATIENT-SPECIFIC HEART RATE & TIMING ----------------------------
% Override HR and recalculate ALL timing parameters proportional to T_cardiac.
% CRITICAL: cardiac cycle timings must be proportional to T_cardiac or else
% the activation window incorrectly spans more than one full cycle.
params.HR       = 77;            % [bpm]   -- clinical rest HR
T               = 60.0 / 77.0;  % [s]     -- cardiac cycle = 0.7792 s
params.T_cardiac = T;

% Ventricular timing (proportions of T from adult baseline kept constant)
params.t_on_lv  = 0.00;
params.T_sys_lv = 0.265 * T;   % [s]  systolic contraction
params.T_rel_lv = 0.40  * T;   % [s]  relaxation

params.t_on_rv  = 0.00;
params.T_sys_rv = 0.30  * T;
params.T_rel_rv = 0.40  * T;

% Atrial timing (relative to T)
% CONSTRAINT: t_on + T_sys + T_rel MUST be < T_cardiac to avoid wrap-around
params.t_on_la  = 0.75 * T;   % [s]  onset = 0.584s
params.T_sys_la = 0.10 * T;   % [s]  contraction = 0.078s
params.T_rel_la = 0.13 * T;   % [s]  relaxation = 0.101s (ends at 0.763s < T)

params.t_on_ra  = 0.80 * T;   % [s]  onset = 0.623s
params.T_sys_ra = 0.10 * T;   % [s]  contraction = 0.078s
params.T_rel_ra = 0.08 * T;   % [s]  relaxation = 0.062s (ends at 0.763s < T)

%% -- 3. VENTRICULAR ELASTANCE OVERRIDES ---------------------------------
% Calibrated to achieve LV_EF~0.59 and RV_EF~0.49 at target filling volumes.
params.Emax_lv = 2.50;    % [mmHg/mL]  LV peak elastance
params.Emin_lv = 0.06;    % [mmHg/mL]  LV diastolic elastance
params.V0_lv   = 5.0;     % [mL]       LV unstressed volume

params.Emax_rv = 0.38;    % [mmHg/mL]  RV peak elastance
params.Emin_rv = 0.038;   % [mmHg/mL]
params.V0_rv   = 10.0;    % [mL]

params.Emax_la = 0.45;    % [mmHg/mL]
params.Emin_la = 0.30;
params.Emax_ra = 0.15;
params.Emin_ra = 0.22;

%% -- 4. VASCULAR PARAMETER OVERRIDES ------------------------------------
% Let pediatric_scaling.m handle vascular parameters based on the fixed
% adult baseline. Doing this ensures systemic and pulmonary circulations
% maintain physically consistent resistance/compliance time constants.

%% -- 5. ASD SHUNT -- POST-CLOSURE ---------------------------------------
params.R_ASD      = 1e9;  % [mmHg.s/mL] effectively infinite resistance
params.is_post_op = true; % Post-op scenario: ASD closure forces zero shunt

%% -- 6. INITIAL CONDITIONS ----------------------------------------------
% Start near expected steady state to reduce warm-up time.
X0 = zeros(params.n_state, 1);
idx = params.idx;

X0(idx.V_lv) = 102.0;    % [mL]   Target LV_EDV
X0(idx.V_rv) = 121.0;    % [mL]   Target RV_EDV
X0(idx.V_la) =  35.0;    % [mL]
X0(idx.V_ra) =  45.0;    % [mL]

X0(idx.P_sa) =  90.0;    % [mmHg]  Aortic diastolic (target range 85-95)
X0(idx.P_sc) =  20.0;    % [mmHg]
X0(idx.P_sv) =  10.0;    % [mmHg]  Higher venous pressure -> more preload
X0(idx.P_pa) =  15.0;    % [mmHg]
X0(idx.P_pc) =   8.0;    % [mmHg]
X0(idx.P_pv) =   6.0;    % [mmHg]

% Target CO ~ 4.56 L/min = 76 mL/s
X0(idx.Q_sa) =  76.0;    % [mL/s]
X0(idx.Q_sv) =  76.0;    % [mL/s]
X0(idx.Q_pa) =  76.0;    % [mL/s]
X0(idx.Q_pv) =  76.0;    % [mL/s]

end
