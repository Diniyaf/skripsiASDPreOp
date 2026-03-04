function [params, X0] = patient_post_asd_parameters()
% PATIENT_POST_ASD_PARAMETERS
% -----------------------------------------------------------------------
% Patient-specific parameters for a post-transcatheter ASD closure scenario.
% 
% Clinical targets:
%   - Age 10, Female, 153 cm, 38 kg (BSA = 1.34 m^2)
%   - HR = 77 bpm
%   - Target LV_EDV ~ 102 mL, LV_EF ~ 0.59
%   - Target RV_EDV ~ 121 mL, RV_EF ~ 0.49
%   - Target CO ~ 4.56 L/min
%   - Qp/Qs ~ 1.0 (ASD sealed)
%
% INPUTS:
%   (none)
%
% OUTPUTS:
%   params - patient-specific parameter struct
%   X0     - initial state vector (14 x 1)
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-03-04
% VERSION:  1.0
% -----------------------------------------------------------------------

%% ── 1. LOAD ADULT BASELINE ─────────────────────────────────────────────
[params, X0_adult] = default_parameters();

%% ── 2. PEDIATRIC SCALING ───────────────────────────────────────────────
age_years = 10;
weight_kg = 38;
height_cm = 153;
params = pediatric_scaling(params, age_years, weight_kg, height_cm);

%% ── 3. PATIENT-SPECIFIC OVERRIDES ──────────────────────────────────────
params.HR = 77;                    % [bpm] Resting heart rate from specs
params.T_cardiac = 60.0 / 77.0;    % [s]

% We want to ensure effectively no shunt but avoid Inf:
params.R_ASD = 1e9;                % [mmHg.s/mL]

% Tuning to meet exact volume targets (LV EDV 102, RV EDV 121)
% The pediatric scaling gives us a good base, but we will fine-tune the 
% V0 and Emax values to specifically hit the target cohort means.
% Let's adjust unstressed volumes to hit the targets.
% (These may be further tuned in execution based on main.m outputs)

% Ventricular capacities:
params.V0_lv = 5.0;     % [mL]  
params.V0_rv = 10.0;    % [mL]

% Base elastance values
params.Emax_lv = 1.5;   % [mmHg/mL]
params.Emin_lv = 0.05;  % 
params.Emax_rv = 0.25;  % [mmHg/mL]
params.Emin_rv = 0.035; %

%% ── 4. INITIAL CONDITIONS ──────────────────────────────────────────────
X0 = zeros(params.n_state, 1);
idx = params.idx;

% Start close to target end-diastolic volumes to reduce warm-up time
X0(idx.V_lv) = 102.0;    % [mL] Target LV_EDV
X0(idx.V_rv) = 121.0;    % [mL] Target RV_EDV
X0(idx.V_la) =  35.0;    % [mL] Scaled LA
X0(idx.V_ra) =  45.0;    % [mL] Scaled RA
X0(idx.P_sa) =  80.0;    % [mmHg]
X0(idx.P_sc) =  18.0;    % [mmHg]
X0(idx.P_sv) =   6.0;    % [mmHg]
X0(idx.P_pa) =  15.0;    % [mmHg]
X0(idx.P_pc) =   7.0;    % [mmHg]
X0(idx.P_pv) =   5.0;    % [mmHg]
X0(idx.Q_sa) =  75.0;    % [mL/s] (~4.5 L/min)
X0(idx.Q_sv) =  75.0;    % [mL/s]
X0(idx.Q_pa) =  75.0;    % [mL/s]
X0(idx.Q_pv) =  75.0;    % [mL/s]

end
