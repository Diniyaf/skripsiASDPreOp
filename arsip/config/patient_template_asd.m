function clinical = patient_template_asd()
% PATIENT_TEMPLATE_ASD
% -------------------------------------------------------------------------
% ASD-specific clinical input schema for forward simulation and later
% validation. Unknown measurements should remain NaN so downstream reporting
% can distinguish missing data from true zero values.
%
% Units: pressure [mmHg], volume [mL], flow [L/min], resistance
% [mmHg*s/mL], height [cm], weight [kg], BSA [m^2].
% -------------------------------------------------------------------------

clinical = struct();

clinical.common.age_years       = NaN;     % Patient age [years]
clinical.common.age_days        = NaN;     % Patient age [days]
clinical.common.weight_kg       = NaN;     % Body weight [kg]
clinical.common.height_cm       = NaN;     % Body height [cm]
clinical.common.sex             = 'U';     % 'F', 'M', or 'U'
clinical.common.BSA             = NaN;     % Mosteller BSA [m^2]
clinical.common.HR              = NaN;     % Heart rate [bpm]
clinical.common.patient_id      = '';      % Non-identifying patient label
clinical.common.patient_name    = '';      % Run label
clinical.common.maturation_mode = 'normal';% 'normal' | 'none'

pre = struct();
pre.ASD_mode        = 'linear_bidirectional'; % ASD shunt model [-]
pre.ASD_diameter_mm = NaN;     % ASD diameter [mm]
pre.ASD_area_mm2    = NaN;     % ASD area [mm^2]
pre.R_asd_guess     = NaN;     % Initial ASD resistance [mmHg*s/mL]
pre.QpQs            = NaN;     % Target pulmonary/systemic flow ratio [-]
pre.Q_shunt_Lmin    = NaN;     % Net LA-to-RA shunt flow [L/min]

pre.SAP_sys_mmHg    = NaN;     % Systolic systemic pressure [mmHg]
pre.SAP_dia_mmHg    = NaN;     % Diastolic systemic pressure [mmHg]
pre.SAP_mean_mmHg   = NaN;     % Mean systemic pressure [mmHg]
pre.PAP_sys_mmHg    = NaN;     % Systolic PA pressure [mmHg]
pre.PAP_dia_mmHg    = NaN;     % Diastolic PA pressure [mmHg]
pre.PAP_mean_mmHg   = NaN;     % Mean PA pressure [mmHg]
pre.RAP_mean_mmHg   = NaN;     % Mean right atrial pressure [mmHg]
pre.LAP_mean_mmHg   = NaN;     % Mean left atrial pressure [mmHg]
pre.CO_Lmin         = NaN;     % Systemic cardiac output [L/min]
pre.P_SVEN_seed_mmHg = NaN;   % Systemic venous stressed-pressure seed [mmHg]
pre.pulmonary_resistance_scale = NaN; % ASD forward PVR seed multiplier [-]
pre.systemic_arterial_compliance_scale = NaN; % SAP pulse-pressure seed [-]

pre.LVEDV_mL        = NaN;     % LV end-diastolic volume [mL]
pre.LVESV_mL        = NaN;     % LV end-systolic volume [mL]
pre.RVEDV_mL        = NaN;     % RV end-diastolic volume [mL]
pre.RVESV_mL        = NaN;     % RV end-systolic volume [mL]
pre.LVEF            = NaN;     % LV ejection fraction [-]
pre.RVEF            = NaN;     % RV ejection fraction [-]
pre.BV_total_mL     = NaN;     % Total blood volume [mL]

clinical.asd_pre = pre;

post = pre;
post.ASD_mode        = 'closed';
post.R_asd_guess     = Inf;
post.QpQs            = 1.0;
post.Q_shunt_Lmin    = 0.0;
post.ASD_diameter_mm = 0.0;
post.ASD_area_mm2    = 0.0;

clinical.asd_post = post;

end
