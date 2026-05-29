function patient = clinical_to_scaling_patient(clinical, label)
% CLINICAL_TO_SCALING_PATIENT
% -------------------------------------------------------------------------
% Converts clinical.common demographics into an apply_scaling.m patient struct.
%
% This helper intentionally reads only clinical.common. Scenario-specific
% ASD disease fields such as ASD_diameter_mm, QpQs, and Q_shunt_Lmin are
% never accessed here, so healthy baseline validation remains closed-shunt.
%
% INPUTS:
%   clinical - patient clinical struct with clinical.common              [-]
%   label    - patient label for reporting                               [-]
%
% OUTPUTS:
%   patient  - scaling patient struct for apply_scaling.m                 [-]
%
% ASSUMPTIONS:
%   - BSA is used from clinical.common when finite; otherwise Mosteller BSA
%     is computed from height and weight.
%   - clinical.common.HR is stored as HR_clinical_bpm for an explicit
%     optional clinical HR override by the caller.
%
% REFERENCES:
%   [1] docs/clinical_data_dictionary.md. Clinical common field mapping.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-05-28
% VERSION:  1.0
% -------------------------------------------------------------------------

if nargin < 2 || isempty(label)
    label = 'Clinical_ReferencePatient';
end

if ~isfield(clinical, 'common')
    error('clinical_to_scaling_patient:missingCommon', ...
        'clinical.common is required for healthy baseline scaling.');
end

common = clinical.common;
patient = struct();
patient.label = char(label);                         % [-]
patient.age_years = required_numeric(common, 'age_years');   % [years]
patient.age_days = patient.age_years * 365.25;       % [days]
patient.weight_kg = required_numeric(common, 'weight_kg');   % [kg]
patient.height_cm = required_numeric(common, 'height_cm');   % [cm]

if isfield(common, 'BSA') && isfinite(common.BSA)
    patient.BSA = common.BSA;                        % [m^2]
else
    patient.BSA = sqrt(patient.weight_kg * patient.height_cm / 3600); % [m^2]
end

if isfield(common, 'sex') && ~isempty(common.sex)
    patient.sex = common.sex;                        % [-]
else
    patient.sex = NaN;                               % [-]
end

if isfield(common, 'HR') && isfinite(common.HR)
    patient.HR_clinical_bpm = common.HR;             % [bpm]
end

if isfield(common, 'maturation_mode') && ~isempty(common.maturation_mode)
    patient.maturation_mode = common.maturation_mode; % [-]
else
    patient.maturation_mode = 'normal';              % [-]
end

patient.source = 'config/patient_zoya.m clinical.common only.';

end

function value = required_numeric(common, field_name)
% REQUIRED_NUMERIC - read a finite numeric clinical.common field.
if ~isfield(common, field_name) || ~isfinite(common.(field_name))
    error('clinical_to_scaling_patient:missingField', ...
        'clinical.common.%s must be finite for healthy baseline scaling.', field_name);
end
value = common.(field_name);
end
