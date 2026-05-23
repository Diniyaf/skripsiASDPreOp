function Q_shunt_asd = asd_shunt_model(P_la, P_ra, params)
% ASD_SHUNT_MODEL
% -------------------------------------------------------------------------
% Computes inter-atrial shunt flow. Positive flow is LA to RA, matching the
% clinical left-to-right ASD convention used throughout this repository.
% -------------------------------------------------------------------------

if is_asd_closed(params)
    Q_shunt_asd = 0.0; % Post-closure toggle: no shunt flow [mL/s]
    return;
end

DeltaP_la_ra = P_la - P_ra; % LA-to-RA pressure gradient [mmHg]
mode = resolve_asd_mode(params);

switch mode
    case 'linear_bidirectional'
        R_asd = resolve_asd_resistance(params);
        Q_shunt_asd = DeltaP_la_ra / R_asd; % [mL/s]

    case 'linear_left_to_right_only'
        R_asd = resolve_asd_resistance(params);
        DeltaP_forward = smooth_positive_part(DeltaP_la_ra, params.epsilon_asd);
        Q_shunt_asd = DeltaP_forward / R_asd; % [mL/s]

    case 'orifice_bidirectional'
        Q_shunt_asd = orifice_flow_signed(DeltaP_la_ra, params); % [mL/s]

    otherwise
        error('asd_shunt_model:UnknownMode', ...
            'Unsupported ASD shunt mode: %s', mode);
end

end

function tf = is_asd_closed(params)
if isfield(params, 'is_post_op') && params.is_post_op
    tf = true;
    return;
end
if isfield(params, 'R_ASD') && isfinite(params.R_ASD)
    tf = false;
    return;
end
if isfield(params, 'R') && isfield(params.R, 'asd') && isfinite(params.R.asd)
    tf = false;
    return;
end
if isfield(params, 'asd') && isfield(params.asd, 'is_closed') && params.asd.is_closed
    tf = true;
    return;
end
if isfield(params, 'R_ASD') && isinf(params.R_ASD)
    tf = true;
    return;
end
tf = false;
end

function mode = resolve_asd_mode(params)
mode = 'linear_bidirectional';
if isfield(params, 'asd') && isfield(params.asd, 'mode') && ~isempty(params.asd.mode)
    mode = lower(char(params.asd.mode));
end
if strcmp(mode, 'closed')
    mode = 'linear_bidirectional';
end
end

function R_asd = resolve_asd_resistance(params)
if isfield(params, 'R_ASD') && isfinite(params.R_ASD)
    R_asd = params.R_ASD;
elseif isfield(params, 'R') && isfield(params.R, 'asd') && isfinite(params.R.asd)
    R_asd = params.R.asd;
elseif isfield(params, 'R_ASD')
    R_asd = params.R_ASD;
elseif isfield(params, 'R') && isfield(params.R, 'asd')
    R_asd = params.R.asd;
else
    error('asd_shunt_model:MissingResistance', ...
        'params.R.asd or params.R_ASD is required.');
end

minimum_resistance = 1.0e-6; % Numerical lower bound [mmHg*s/mL]
R_asd = max(R_asd, minimum_resistance);
end

function Q_mLs = orifice_flow_signed(DeltaP_mmHg, params)
mmHg_to_Pa = 133.322; % Pressure conversion [Pa/mmHg]
m3_to_mL = 1.0e6;     % Volume conversion [mL/m^3]
mm2_to_m2 = 1.0e-6;   % Area conversion [m^2/mm^2]

area_mm2 = params.asd.area_mm2;
if area_mm2 <= 0.0
    diameter_mm = params.asd.diameter_mm;
    area_mm2 = pi * (diameter_mm / 2.0)^2;
end

epsilon_pressure = params.epsilon_asd; % Numerical smoothing [mmHg]
DeltaP_abs = sqrt(DeltaP_mmHg.^2 + epsilon_pressure.^2);
signed_gate = DeltaP_mmHg ./ DeltaP_abs;

DeltaP_Pa = DeltaP_abs * mmHg_to_Pa;
area_m2 = area_mm2 * mm2_to_m2;
Q_m3s = params.asd.Cd * area_m2 .* sqrt(2.0 * DeltaP_Pa / params.asd.rho_blood);
Q_mLs = signed_gate .* Q_m3s * m3_to_mL;
end

function y = smooth_positive_part(x, epsilon_pressure)
% Numerical smoothing for ODE stability while preserving one-way flow.
y = 0.5 * (x + sqrt(x.^2 + epsilon_pressure.^2));
end
