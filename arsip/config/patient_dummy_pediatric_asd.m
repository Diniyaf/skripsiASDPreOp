function clinical = patient_dummy_pediatric_asd()
% PATIENT_DUMMY_PEDIATRIC_ASD
% -------------------------------------------------------------------------
% Representative pediatric ASD dummy profile for forward-simulation smoke
% testing. Demographics are grounded in the reported median/IQR-style cohort
% summary from Sjoberg et al. (2024), so this file is appropriate for a
% dummy patient, not for individual-patient calibration.
% -------------------------------------------------------------------------

clinical = patient_template_asd();

clinical.common.patient_id      = 'dummy_pediatric_asd_8y';
clinical.common.patient_name    = 'Sjoberg 2024 median-style ASD dummy';
clinical.common.age_years       = 8.0;      % [years]
clinical.common.age_days        = 8.0 * 365.25; % [days]
clinical.common.height_cm       = 137.0;    % [cm]
clinical.common.weight_kg       = 32.0;     % [kg]
clinical.common.sex             = 'U';      % Unknown/pooled cohort sex [-]
clinical.common.BSA             = sqrt(137.0 * 32.0 / 3600.0); % Mosteller [m^2]
clinical.common.HR              = 83.0;     % [bpm]
clinical.common.maturation_mode = 'normal';

pre = clinical.asd_pre;
pre.ASD_mode        = 'linear_bidirectional';
pre.ASD_diameter_mm = 16.0;     % Large secundum-like ASD starting guess [mm]
pre.ASD_area_mm2    = pi * (pre.ASD_diameter_mm / 2.0)^2; % [mm^2]
pre.R_asd_guess     = 0.001;    % Initial large-defect resistance [mmHg*s/mL]
pre.QpQs            = 1.80;     % Target clinical Qp/Qs [-]

pre.SAP_sys_mmHg    = 102.0;    % Target systemic systolic pressure [mmHg]
pre.SAP_dia_mmHg    = 67.0;     % Target systemic diastolic pressure [mmHg]
pre.SAP_mean_mmHg   = pre.SAP_dia_mmHg + ...
    (pre.SAP_sys_mmHg - pre.SAP_dia_mmHg) / 3.0; % Mean arterial pressure [mmHg]

pre.PAP_sys_mmHg    = 32.0;     % Mildly elevated PA systolic seed [mmHg]
pre.PAP_dia_mmHg    = 14.0;     % Mildly elevated PA diastolic seed [mmHg]
pre.PAP_mean_mmHg   = 20.0;     % Mild pulmonary pressure seed [mmHg]
pre.RAP_mean_mmHg   = 5.0;      % Typical pediatric RA seed [mmHg]
pre.LAP_mean_mmHg   = 8.0;      % LA seed supporting L-to-R gradient [mmHg]
pre.CO_Lmin         = NaN;      % Leave unknown for forward simulation
pre.P_SVEN_seed_mmHg = 36.0;    % Stressed venous preload seed [mmHg]
pre.pulmonary_resistance_scale = 0.08; % Low/normal PVR seed for ASD flow [-]
pre.systemic_arterial_compliance_scale = 1.50; % Pediatric pulse-pressure seed [-]

clinical.asd_pre = pre;

end
