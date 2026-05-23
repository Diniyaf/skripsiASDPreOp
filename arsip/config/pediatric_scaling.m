function params_scaled = pediatric_scaling(params_ref, age_years, weight_kg, height_cm, sex)
% PEDIATRIC_SCALING
% -----------------------------------------------------------------------
% Scales baseline adult cardiovascular parameters to a pediatric patient
% using specific physiological scaling equations based on BSA and age.
%
% INPUTS:
%   params_ref - baseline adult parameter struct (from default_parameters.m)
%   age_years  - patient age                                     [years]
%   weight_kg  - patient body weight                             [kg]
%   height_cm  - patient height                                  [cm]
%   sex        - patient sex (0=female, 1=male)
%
% OUTPUTS:
%   params_scaled - updated parameter struct with pediatric-scaled values
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-03-04
% VERSION:  1.1 (Updated to new pipeline specification)
% -----------------------------------------------------------------------

%% ── INITIALIZE SCALED PARAMS ──────────────────────────────────────────
params_scaled = params_ref;

%% ── BODY SURFACE AREA (Mosteller) ──────────────────────────────────────
BSA = sqrt((height_cm * weight_kg) / 3600);   % [m^2]
BSA_ref = params_ref.BSA;                     % [m^2]

scale_factor = BSA / BSA_ref;                 % [-]

%% ── SCALING RULES ──────────────────────────────────────────────────────
% A. Vascular Geometry
params_scaled.L_aorta = params_ref.L_aorta * (height_cm / params_ref.height_cm);   % [cm]
params_scaled.r_aorta = params_ref.r_aorta * (scale_factor ^ 0.5);                 % [mm]
params_scaled.h_aorta = params_ref.h_aorta * (scale_factor ^ 0.5);                 % [mm]
params_scaled.N_capillary = params_ref.N_capillary * scale_factor;                 % [-]

% B. Hemodynamic Properties
params_scaled.P_ao_mean = params_ref.P_ao_mean * (scale_factor ^ 0.25);   % [mmHg]

age_factor = ((30 + age_years) / (30 + params_ref.age_years)) ^ 3;        % [-]
params_scaled.E_arterial = 1000 + age_factor * (params_ref.E_arterial - 1000); % [mmHg]

% C. Cardiac Parameters
HR_scaled = params_ref.HR * (scale_factor ^ -0.33);                       % [bpm]
params_scaled.HR = HR_scaled;
params_scaled.T_cardiac = 60.0 / HR_scaled;                               % [s]

params_scaled.Emax_lv = params_ref.Emax_lv * (scale_factor ^ -1);         % [mmHg/mL]
params_scaled.Emax_rv = params_ref.Emax_rv * (scale_factor ^ -1.5);       % [mmHg/mL]

params_scaled.V0_lv = params_ref.V0_lv * scale_factor;                    % [mL]
params_scaled.V0_rv = params_ref.V0_rv * scale_factor;                    % [mL]

% Because the previous linear volume scaling scaled other V0's, we keep that 
% consistency for atria too, based on scale_factor:
params_scaled.V0_la = params_ref.V0_la * scale_factor;                    % [mL]
params_scaled.V0_ra = params_ref.V0_ra * scale_factor;                    % [mL]

% Similarly for compliances and resistances that weren't specifically mentioned
% but need scaling for the model to continue working (using previous logic):
params_scaled.C_sa = params_ref.C_sa * scale_factor;
params_scaled.C_sc = params_ref.C_sc * scale_factor;
params_scaled.C_sv = params_ref.C_sv * scale_factor;
params_scaled.C_pa = params_ref.C_pa * scale_factor;
params_scaled.C_pc = params_ref.C_pc * scale_factor;
params_scaled.C_pv = params_ref.C_pv * scale_factor;

params_scaled.R_sa = params_ref.R_sa / scale_factor;
params_scaled.R_sc = params_ref.R_sc / scale_factor;
params_scaled.R_sv = params_ref.R_sv / scale_factor;
params_scaled.R_pa = params_ref.R_pa / scale_factor;
params_scaled.R_pc = params_ref.R_pc / scale_factor;
params_scaled.R_pv = params_ref.R_pv / scale_factor;

% D. Blood Volume
params_scaled.V_blood = params_ref.V_blood * (scale_factor ^ 1.32);       % [mL]

% E. Pulmonary & Ventilation
params_scaled.VT = 7 * weight_kg;                                         % [mL]
params_scaled.C_lung = params_ref.C_lung * scale_factor;                  % [mL/mmHg]
params_scaled.R_airway = params_ref.R_airway * (scale_factor ^ -0.5);     % [mmHg·s/mL]

%% ── REPORT SCALING APPLIED ─────────────────────────────────────────────
fprintf('--- Pediatric Scaling Applied ---\n');
fprintf('  Age:           %.1f years\n',    age_years);
fprintf('  Sex:           %d (0=F, 1=M)\n', sex);
fprintf('  Weight:        %.1f kg\n',       weight_kg);
fprintf('  Height:        %.1f cm\n',       height_cm);
fprintf('  BSA:           %.3f m\xB2\n',   BSA);
fprintf('  Scaling factor:%.4f\n',          scale_factor);
fprintf('  HR (scaled):   %.1f bpm\n',      params_scaled.HR);
fprintf('  T_cardiac:     %.3f s\n',        params_scaled.T_cardiac);

end
