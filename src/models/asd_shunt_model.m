function Q_ASD = asd_shunt_model(P_LA, P_RA, params)
% ASD_SHUNT_MODEL
% -----------------------------------------------------------------------
% Computes atrial septal defect shunt flow between the left and right atria.
%
% The default ASD state in default_parameters.m is closed
% (params.R.asd = Inf, params.asd.area_mm2 = 0). Disease simulations open
% the defect by assigning a finite resistance or orifice area.
%
% INPUTS:
%   P_LA   - left atrial pressure                         [mmHg]
%   P_RA   - right atrial pressure                        [mmHg]
%   params - parameter struct with params.R.asd/params.asd [-]
%
% OUTPUTS:
%   Q_ASD  - ASD shunt flow                               [mL/s]
%
% ASSUMPTIONS:
%   - Atrial pressures are spatially lumped per chamber.
%   - Linear mode represents a reduced-order pressure-flow resistance.
%   - Orifice mode uses a quasi-steady incompressible orifice law.
%
% SIGN CONVENTIONS:
%   - Q_ASD > 0 means left-to-right atrial shunt: LA -> RA.
%   - Q_ASD < 0 means right-to-left atrial shunt: RA -> LA.
%
% REFERENCES:
%   [1] Valenti (2023). Thesis. Lumped shunt/orifice simplification.
%
% AUTHOR:   Unified ASD Model
% DATE:     2026-05-28
% VERSION:  1.0
% -----------------------------------------------------------------------

dP = P_LA - P_RA;              % [mmHg] upstream-minus-downstream for LA -> RA
mode = lower(params.asd.mode); % [-]

switch mode
    case 'linear_bidirectional'
        Q_ASD = dP ./ max(params.R.asd, 1e-6);

    case 'linear_left_to_right_only'
        gate = 0.5 + 0.5 * tanh(dP ./ params.epsilon_asd);
        Q_ASD = gate .* dP ./ max(params.R.asd, 1e-6);

    case 'orifice_bidirectional'
        if params.asd.area_mm2 <= 0
            Q_ASD = zeros(size(dP));
            return;
        end

        A_m2 = params.asd.area_mm2 * 1e-6;                  % [m^2]
        dP_Pa = abs(dP) * params.conv.mmHg_to_Pa;           % [Pa]
        q_mag_m3s = params.asd.Cd * A_m2 .* ...
            sqrt(2 * dP_Pa / params.asd.rho_blood);         % [m^3/s]
        q_mag_mLs = q_mag_m3s * params.conv.m3_to_mL;       % [mL/s]
        signed_gate = dP ./ sqrt(dP.^2 + params.epsilon_asd^2);
        Q_ASD = q_mag_mLs .* signed_gate;                   % [mL/s]

    otherwise
        error('asd_shunt_model:unknownMode', ...
            'Unsupported ASD mode: %s', params.asd.mode);
end

end
