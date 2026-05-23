function [params, X0] = apply_scaling(params_ref, clinical, scenario)
% APPLY_SCALING
% -------------------------------------------------------------------------
% Forward-simulation scaling pipeline:
%   adult baseline -> allometric scaling -> maturation -> ASD scenario map
%   -> pressure-aware initial conditions.
% -------------------------------------------------------------------------

if nargin < 3 || isempty(scenario)
    scenario = 'asd_pre';
end

patient = clinical.common;
if ~isfield(patient, 'BSA') || isnan(patient.BSA)
    mosteller_denominator = 3600.0; % Mosteller BSA denominator [cm*kg/m^4]
    patient.BSA = sqrt(patient.height_cm * patient.weight_kg / mosteller_denominator);
end
if ~isfield(patient, 'age_days') || isnan(patient.age_days)
    days_per_year = 365.25; % Calendar conversion [days/year]
    patient.age_days = patient.age_years * days_per_year;
end

params = apply_physiological_scaling(params_ref, patient, 'zhang');

maturation_mode = 'normal';
if isfield(patient, 'maturation_mode') && ~isempty(patient.maturation_mode)
    maturation_mode = patient.maturation_mode;
end
params = apply_maturation(params, patient.age_days, maturation_mode);

if isfield(patient, 'HR') && ~isnan(patient.HR)
    params.HR = patient.HR; % Patient-measured heart rate [bpm]
    params = recompute_timing_from_current_fractions(params_ref, params);
end

[src, scenario] = resolve_asd_source(clinical, scenario);
params = configure_asd_forward(params, src, scenario);
params = apply_asd_forward_seeds(params, src);

X0 = build_asd_initial_conditions(params, src);
params.scaling.patient = patient;
params.scaling.age_days = patient.age_days;
params.scaling.maturation_mode = maturation_mode;

fprintf('[apply_scaling] Adult baseline scaled to pediatric ASD dummy\n');
fprintf('  Age          : %.1f years (%.0f days)\n', patient.age_years, patient.age_days);
fprintf('  Height/Weight: %.1f cm / %.1f kg\n', patient.height_cm, patient.weight_kg);
fprintf('  BSA          : %.3f m^2\n', patient.BSA);
fprintf('  Weight ratio : %.3f vs 70 kg adult\n', params.scaling.weight_ratio);
fprintf('  HR applied   : %.1f bpm\n', params.HR);
fprintf('  V_blood      : %.1f mL\n', params.V_blood);
fprintf('  Scenario     : %s\n', scenario);
if isfield(params, 'forward_seed')
    fprintf('  P_SVEN seed  : %.1f mmHg\n', params.forward_seed.P_SVEN_seed_mmHg);
    fprintf('  PVR scale    : %.3f\n', params.forward_seed.pulmonary_resistance_scale);
    fprintf('  C_sa scale   : %.3f\n', params.forward_seed.systemic_arterial_compliance_scale);
end

end

function params = configure_asd_forward(params, src, scenario)
closed_resistance = Inf; % Closed shunt resistance [mmHg*s/mL]

if strcmpi(scenario, 'asd_post')
    params.is_post_op = true;
    params.R_ASD = closed_resistance;
    params.R.asd = closed_resistance;
    params.asd.is_closed = true;
    params.asd.mode = 'closed';
    params.asd.area_mm2 = 0.0;
    params.asd.diameter_mm = 0.0;
    return;
end

params.is_post_op = false;
params.asd.is_closed = false;

if isfield(src, 'ASD_mode') && ~isempty(src.ASD_mode)
    params.asd.mode = lower(char(src.ASD_mode));
end
if isfield(src, 'ASD_diameter_mm') && ~isnan(src.ASD_diameter_mm)
    params.asd.diameter_mm = src.ASD_diameter_mm;
end
if isfield(src, 'ASD_area_mm2') && ~isnan(src.ASD_area_mm2)
    params.asd.area_mm2 = src.ASD_area_mm2;
elseif params.asd.diameter_mm > 0.0
    params.asd.area_mm2 = pi * (params.asd.diameter_mm / 2.0)^2;
end
if isfield(src, 'R_asd_guess') && ~isnan(src.R_asd_guess)
    params.R_ASD = src.R_asd_guess;
else
    params.R_ASD = 0.10; % Large ASD starting resistance [mmHg*s/mL]
end
params.R.asd = params.R_ASD;
end

function params = apply_asd_forward_seeds(params, src)
pulmonary_resistance_scale = first_valid(src, {'pulmonary_resistance_scale'}, 1.0);
systemic_arterial_compliance_scale = first_valid(src, ...
    {'systemic_arterial_compliance_scale'}, 1.0);

params.R_pa = params.R_pa * pulmonary_resistance_scale;
params.R_pc = params.R_pc * pulmonary_resistance_scale;
params.R_sh = params.R_sh * pulmonary_resistance_scale;
params.R_pv = params.R_pv * pulmonary_resistance_scale;

params.C_sa = params.C_sa * systemic_arterial_compliance_scale;

params.forward_seed.pulmonary_resistance_scale = pulmonary_resistance_scale;
params.forward_seed.systemic_arterial_compliance_scale = ...
    systemic_arterial_compliance_scale;
params.forward_seed.P_SVEN_seed_mmHg = first_valid(src, {'P_SVEN_seed_mmHg'}, ...
    first_valid(src, {'RAP_mean_mmHg'}, 5.0) + 5.0);
end

function X0 = build_asd_initial_conditions(params, src)
idx = params.idx;
X0 = zeros(params.n_state, 1);

P_sar = first_valid(src, {'SAP_mean_mmHg'}, 85.0);
P_sc = max(0.35 * P_sar, 15.0);
P_sven = first_valid(src, {'P_SVEN_seed_mmHg'}, ...
    first_valid(src, {'RAP_mean_mmHg'}, 5.0) + 5.0);
P_par = first_valid(src, {'PAP_mean_mmHg'}, 18.0);
P_pven = first_valid(src, {'LAP_mean_mmHg'}, 8.0);
P_pc = 0.5 * (P_par + P_pven);

P_lv_ed = first_valid(src, {'LAP_mean_mmHg'}, 8.0);
P_rv_ed = first_valid(src, {'RAP_mean_mmHg'}, 5.0);
P_la = first_valid(src, {'LAP_mean_mmHg'}, 8.0);
P_ra = first_valid(src, {'RAP_mean_mmHg'}, 5.0);

X0(idx.V_lv) = params.V0_lv + P_lv_ed / max(params.Emin_lv, 1.0e-6);
X0(idx.V_rv) = params.V0_rv + P_rv_ed / max(params.Emin_rv, 1.0e-6);
X0(idx.V_la) = params.V0_la + P_la / max(params.Emin_la, 1.0e-6);
X0(idx.V_ra) = params.V0_ra + P_ra / max(params.Emin_ra, 1.0e-6);

X0(idx.P_sa) = P_sar;
X0(idx.P_sc) = P_sc;
X0(idx.P_sv) = P_sven;
X0(idx.P_pa) = P_par;
X0(idx.P_pc) = P_pc;
X0(idx.P_pv) = P_pven;

stroke_volume_seed = max(0.22 * X0(idx.V_lv), 8.0); % Pediatric SV seed [mL]
flow_seed = stroke_volume_seed * params.HR / 60.0;  % Baseline flow [mL/s]
target_qpqs = first_valid(src, {'QpQs'}, 1.0);

X0(idx.Q_sa) = flow_seed;
X0(idx.Q_sv) = flow_seed;
X0(idx.Q_pa) = flow_seed * target_qpqs;
X0(idx.Q_pv) = flow_seed * target_qpqs;
end

function params = recompute_timing_from_current_fractions(params_ref, params)
reference_period_s = params_ref.T_cardiac; % Adult reference period [s]
params.T_cardiac = 60.0 / params.HR;       % Patient period [s]
patient_period_s = params.T_cardiac;

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

function [src, scenario] = resolve_asd_source(clinical, scenario)
if strcmpi(scenario, 'asd_post')
    src = clinical.asd_post;
    scenario = 'asd_post';
else
    src = clinical.asd_pre;
    scenario = 'asd_pre';
end
end

function value = first_valid(src, field_names, fallback)
value = fallback;
for k = 1:numel(field_names)
    field_name = field_names{k};
    if isfield(src, field_name) && ~isnan(src.(field_name))
        value = src.(field_name);
        return;
    end
end
end
