function params = apply_physiological_scaling(params_ref, patient, scaling_mode)
% APPLY_PHYSIOLOGICAL_SCALING
% -------------------------------------------------------------------------
% Applies size-dependent pediatric scaling to the adult flat-struct model.
% This adapts Hafiz's Zhang-style weight exponents to this repository's
% parameter names without constructing initial conditions.
% -------------------------------------------------------------------------

if nargin < 3 || isempty(scaling_mode)
    scaling_mode = 'zhang';
end

scaling_mode = lower(char(scaling_mode));
switch scaling_mode
    case 'zhang'
        params = apply_zhang_scaling_flat(params_ref, patient);
    otherwise
        error('apply_physiological_scaling:UnknownMode', ...
            'Unsupported scaling mode: %s', scaling_mode);
end

params.scaling.mode = scaling_mode;

end

function params = apply_zhang_scaling_flat(params_ref, patient)
% Weight-based allometric scaling for a 0D pediatric forward simulation.

reference_weight_kg = 70.0; % Adult reference body mass [kg]
weight_ratio = patient.weight_kg / reference_weight_kg; % [-]

if isfield(patient, 'BSA') && ~isnan(patient.BSA)
    BSA_patient = patient.BSA;
else
    mosteller_denominator = 3600.0; % Mosteller BSA denominator [cm*kg/m^4]
    BSA_patient = sqrt(patient.height_cm * patient.weight_kg / mosteller_denominator);
end

params = params_ref;
params.scaling.reference_weight_kg = reference_weight_kg;
params.scaling.weight_ratio = weight_ratio;
params.scaling.BSA_ref = params_ref.BSA;
params.scaling.BSA_patient = BSA_patient;
params.scaling.patient = patient;

exponent.HR = -0.30;
exponent.E_left = -0.50;
exponent.E_right = -0.75;
exponent.V0 = 0.80;
exponent.R_systemic = -0.475;
exponent.R_pulmonary = -0.70;
exponent.C = 1.00;
exponent.R_valve_open = -0.90;

params.HR = params_ref.HR * weight_ratio ^ exponent.HR;
params.T_cardiac = 60.0 / params.HR; % Cardiac period [s]

left_elastance_scale = weight_ratio ^ exponent.E_left;
right_elastance_scale = weight_ratio ^ exponent.E_right;
params.Emax_lv = params_ref.Emax_lv * left_elastance_scale;
params.Emin_lv = params_ref.Emin_lv * left_elastance_scale;
params.Emax_la = params_ref.Emax_la * left_elastance_scale;
params.Emin_la = params_ref.Emin_la * left_elastance_scale;
params.Emax_rv = params_ref.Emax_rv * right_elastance_scale;
params.Emin_rv = params_ref.Emin_rv * right_elastance_scale;
params.Emax_ra = params_ref.Emax_ra * right_elastance_scale;
params.Emin_ra = params_ref.Emin_ra * right_elastance_scale;

volume_scale = weight_ratio ^ exponent.V0;
params.V0_lv = params_ref.V0_lv * volume_scale;
params.V0_rv = params_ref.V0_rv * volume_scale;
params.V0_la = params_ref.V0_la * volume_scale;
params.V0_ra = params_ref.V0_ra * volume_scale;

systemic_resistance_scale = weight_ratio ^ exponent.R_systemic;
pulmonary_resistance_scale = weight_ratio ^ exponent.R_pulmonary;
params.R_sa = params_ref.R_sa * systemic_resistance_scale;
params.R_sc = params_ref.R_sc * systemic_resistance_scale;
params.R_sv = params_ref.R_sv * systemic_resistance_scale;
params.R_pa = params_ref.R_pa * pulmonary_resistance_scale;
params.R_pc = params_ref.R_pc * pulmonary_resistance_scale;
params.R_sh = params_ref.R_sh * pulmonary_resistance_scale;
params.R_pv = params_ref.R_pv * pulmonary_resistance_scale;

compliance_scale = weight_ratio ^ exponent.C;
params.C_sa = params_ref.C_sa * compliance_scale;
params.C_sc = params_ref.C_sc * compliance_scale;
params.C_sv = params_ref.C_sv * compliance_scale;
params.C_pa = params_ref.C_pa * compliance_scale;
params.C_pc = params_ref.C_pc * compliance_scale;
params.C_sh = params_ref.C_sh * compliance_scale;
params.C_pv = params_ref.C_pv * compliance_scale;

valve_scale = weight_ratio ^ exponent.R_valve_open;
params.R_mv_min = params_ref.R_mv_min * valve_scale;
params.R_ao_min = params_ref.R_ao_min * valve_scale;
params.R_tv_min = params_ref.R_tv_min * valve_scale;
params.R_pv_valve_min = params_ref.R_pv_valve_min * valve_scale;

params.V_blood = patient.weight_kg * blood_volume_per_kg(patient.age_years);
params = recompute_flat_timing(params_ref, params);
params.scaling.zhang_exponents = exponent;

end

function params = recompute_flat_timing(params_ref, params)
reference_period_s = params_ref.T_cardiac; % Adult reference period [s]
patient_period_s = params.T_cardiac;       % Patient period [s]

params.t_on_lv  = (params_ref.t_on_lv  / reference_period_s) * patient_period_s;
params.T_sys_lv = (params_ref.T_sys_lv / reference_period_s) * patient_period_s;
params.T_rel_lv = (params_ref.T_rel_lv / reference_period_s) * patient_period_s;

params.t_on_rv  = (params_ref.t_on_rv  / reference_period_s) * patient_period_s;
params.T_sys_rv = (params_ref.T_sys_rv / reference_period_s) * patient_period_s;
params.T_rel_rv = (params_ref.T_rel_rv / reference_period_s) * patient_period_s;

params.t_on_la  = (params_ref.t_on_la  / reference_period_s) * patient_period_s;
params.T_sys_la = (params_ref.T_sys_la / reference_period_s) * patient_period_s;
params.T_rel_la = min((params_ref.T_rel_la / reference_period_s) * patient_period_s, ...
    max(patient_period_s - params.t_on_la - params.T_sys_la, 0.05 * patient_period_s));

params.t_on_ra  = (params_ref.t_on_ra  / reference_period_s) * patient_period_s;
params.T_sys_ra = (params_ref.T_sys_ra / reference_period_s) * patient_period_s;
params.T_rel_ra = min((params_ref.T_rel_ra / reference_period_s) * patient_period_s, ...
    max(patient_period_s - params.t_on_ra - params.T_sys_ra, 0.05 * patient_period_s));
end

function BV_per_kg = blood_volume_per_kg(age_years)
if age_years < 1.0
    BV_per_kg = 82.0; % Infant blood volume estimate [mL/kg]
else
    BV_per_kg = 70.0; % Child/adult blood volume estimate [mL/kg]
end
end
