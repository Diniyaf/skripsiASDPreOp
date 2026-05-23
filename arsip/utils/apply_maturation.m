function params = apply_maturation(params, age_days, maturation_mode)
% APPLY_MATURATION
% -------------------------------------------------------------------------
% Applies age-dependent vascular maturation after size scaling. For an
% 8-year-old patient this is nearly neutral, but the explicit step keeps
% the pipeline traceable for future younger pediatric cases.
% -------------------------------------------------------------------------

if nargin < 3 || isempty(maturation_mode)
    maturation_mode = 'normal';
end

maturation_mode = lower(char(maturation_mode));
age_days = max(age_days, 0.0); % Patient age [days]

switch maturation_mode
    case 'none'
        pvr_factor = 1.0;
        svr_factor = 1.0;
        pvr_reference_age_days = age_days;
    case 'normal'
        pvr_reference_age_days = age_days;
        pvr_factor = 1.0 + 2.5 * exp(-pvr_reference_age_days / 21.0);
        svr_factor = 0.70 + 0.30 * (1.0 - exp(-age_days / 90.0));
    otherwise
        error('apply_maturation:UnknownMode', ...
            'Unsupported maturation mode: %s', maturation_mode);
end

params.R_pa = params.R_pa * pvr_factor;
params.R_pc = params.R_pc * pvr_factor;
params.R_sh = params.R_sh * pvr_factor;
params.R_pv = params.R_pv * pvr_factor;

sqrt_pvr_factor = sqrt(pvr_factor);
params.C_pa = params.C_pa / sqrt_pvr_factor;
params.C_pc = params.C_pc / sqrt_pvr_factor;
params.C_sh = params.C_sh / sqrt_pvr_factor;
params.C_pv = params.C_pv / sqrt_pvr_factor;

params.R_sa = params.R_sa * svr_factor;
params.R_sc = params.R_sc * svr_factor;
params.R_sv = params.R_sv * svr_factor;

params.C_sa = params.C_sa / max(svr_factor, 1.0e-6);
params.C_sc = params.C_sc / max(svr_factor, 1.0e-6);
params.C_sv = params.C_sv / max(svr_factor, 1.0e-6);

params.maturation.mode = maturation_mode;
params.maturation.age_days = age_days;
params.maturation.pvr_factor = pvr_factor;
params.maturation.svr_factor = svr_factor;
params.maturation.pvr_reference_age_days = pvr_reference_age_days;

end
