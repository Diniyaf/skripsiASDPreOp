function params = pediatric_scaling(params, age_years, weight_kg, height_cm)
% PEDIATRIC_SCALING
% -----------------------------------------------------------------------
% Scales baseline adult cardiovascular parameters to a pediatric patient
% using allometric scaling based on body surface area (BSA).
%
% INPUTS:
%   params     - baseline adult parameter struct (from default_parameters.m)
%   age_years  - patient age                                     [years]
%   weight_kg  - patient body weight                             [kg]
%   height_cm  - patient height                                  [cm]
%
% OUTPUTS:
%   params     - updated parameter struct with pediatric-scaled values
%
% ASSUMPTIONS:
%   - Linear scaling of volumes and compliances with BSA
%   - Resistance scales inversely with BSA (higher PVR in small patients)
%   - Heart rate scaled via Bazett-approximation for children
%   - Reference adult BSA = 1.73 m² (DuBois formula, 70 kg / 170 cm adult)
%
% REFERENCES:
%   [1] DuBois D, DuBois EF (1916). Arch Intern Med 17:863-871. (BSA formula)
%   [2] Senzaki H et al. (2000). Circulation 101:2764-2769. (pediatric CO)
%   [3] Rudolph AM (1974). Congenital Disease of the Heart. (pediatric PVR)
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

%% ── BODY SURFACE AREA ──────────────────────────────────────────────────
% DuBois formula: BSA = 0.007184 * W^0.425 * H^0.725
% Source: DuBois & DuBois (1916)

BSA = 0.007184 * (weight_kg^0.425) * (height_cm^0.725);   % [m²]
BSA_adult_ref = 1.73;                                        % [m²] reference

scaling_ratio = BSA / BSA_adult_ref;    % [dimensionless] — volume/compliance scale

%% ── HEART RATE SCALING ─────────────────────────────────────────────────
% Approximation: HR reduces with age from infant (~120 bpm) to adult (~75 bpm)
% Source: Rudolph (1974), assumed — needs literature validation

HR_adult_ref = 75.0;     % Reference adult heart rate [bpm]
HR_age_factor = 1.0 + max(0, (10 - age_years)) * 0.04;   % [dimensionless]
HR_scaled = HR_adult_ref * HR_age_factor;                  % [bpm]

params.HR        = HR_scaled;                         % [bpm]
params.T_cardiac = 60.0 / HR_scaled;                 % [s]

%% ── VOLUME SCALING (linear with BSA) ──────────────────────────────────

params.V0_lv = params.V0_lv * scaling_ratio;    % [mL]
params.V0_rv = params.V0_rv * scaling_ratio;    % [mL]
params.V0_la = params.V0_la * scaling_ratio;    % [mL]
params.V0_ra = params.V0_ra * scaling_ratio;    % [mL]

%% ── COMPLIANCE SCALING (linear with BSA) ──────────────────────────────

params.C_sa = params.C_sa * scaling_ratio;    % [mL/mmHg]
params.C_sc = params.C_sc * scaling_ratio;    % [mL/mmHg]
params.C_sv = params.C_sv * scaling_ratio;    % [mL/mmHg]
params.C_pa = params.C_pa * scaling_ratio;    % [mL/mmHg]
params.C_pc = params.C_pc * scaling_ratio;    % [mL/mmHg]
params.C_pv = params.C_pv * scaling_ratio;    % [mL/mmHg]

%% ── RESISTANCE SCALING (inversely proportional to BSA) ────────────────
% Smaller patients → higher vascular resistance per unit flow

params.R_sa = params.R_sa / scaling_ratio;    % [mmHg·s/mL]
params.R_sc = params.R_sc / scaling_ratio;    % [mmHg·s/mL]
params.R_sv = params.R_sv / scaling_ratio;    % [mmHg·s/mL]
params.R_pa = params.R_pa / scaling_ratio;    % [mmHg·s/mL]
params.R_pc = params.R_pc / scaling_ratio;    % [mmHg·s/mL]
params.R_pv = params.R_pv / scaling_ratio;    % [mmHg·s/mL]

%% ── REPORT SCALING APPLIED ─────────────────────────────────────────────

fprintf('--- Pediatric Scaling Applied ---\n');
fprintf('  Age:           %.1f years\n',    age_years);
fprintf('  Weight:        %.1f kg\n',       weight_kg);
fprintf('  Height:        %.1f cm\n',       height_cm);
fprintf('  BSA:           %.3f m\xB2\n',   BSA);
fprintf('  Scaling ratio: %.4f\n',          scaling_ratio);
fprintf('  HR (scaled):   %.1f bpm\n',      HR_scaled);
fprintf('  T_cardiac:     %.3f s\n',        params.T_cardiac);

end
