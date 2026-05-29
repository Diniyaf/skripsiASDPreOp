function patient = reference_reyna()
% REFERENCE_REYNA
% -------------------------------------------------------------------------
% Returns the original Hafiz/Keisya pediatric reference child used for
% healthy baseline scaling comparisons.
%
% This is not an ASD disease profile. It contains only anthropometry and
% maturation metadata needed by apply_scaling.m. It is preserved so the
% original pediatric baseline outputs remain reproducible beside the Zoya
% patient-specific baseline.
%
% OUTPUTS:
%   patient - pediatric scaling reference struct                  [-]
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-28
% VERSION:  1.0
% -------------------------------------------------------------------------

patient = struct();
patient.label = 'Reyna_ReferenceChild';          % [-] reference label
patient.age_years = 3.17;                        % [years]
patient.age_days = patient.age_years * 365.25;   % [days]
patient.weight_kg = 14.0;                        % [kg]
patient.height_cm = 98.0;                        % [cm]
patient.BSA = sqrt(patient.weight_kg * patient.height_cm / 3600); % [m^2]
patient.sex = 'F';                               % [-]
patient.maturation_mode = 'normal';              % [-]
patient.source = 'Original Hafiz/Keisya pediatric reference child.';

end
