function Q = valve_model(P_up, P_down, R_min, R_max, smoothing_pressure)
% VALVE_MODEL
% -------------------------------------------------------------------------
% Computes non-regurgitant flow through a cardiac valve using a smoothed
% ideal-diode approximation.
%
% Governing equation:
%   Q = positive_part_smooth(P_up - P_down) / R_min
%
%   positive_part_smooth(x) = 0.5 * (x + sqrt(x^2 + eps_p^2))
%
% The former R_max reverse-flow branch is intentionally not used in the
% flow law. This guarantees Q >= 0, preventing fictitious backward leakage,
% while the square-root smoothing keeps the derivative continuous near
% valve opening/closure for ode15s.
%
% INPUTS:
%   P_up               - upstream chamber/vessel pressure      [mmHg]
%   P_down             - downstream chamber/vessel pressure    [mmHg]
%   R_min              - open-valve resistance                 [mmHg*s/mL]
%   R_max              - retained for Table 3.3 traceability   [mmHg*s/mL]
%   smoothing_pressure - smoothing width near DeltaP = 0       [mmHg]
%
% OUTPUT:
%   Q                  - non-negative valve flow rate          [mL/s]
%
% SIGN CONVENTION:
%   Q > 0 means forward physiological flow. Reverse valve flow is not
%   permitted by this ideal-diode formulation.
%
% REFERENCES:
%   [1] Valenti et al. (2023). Table 3.3 valve resistances.
%   [2] Shi Y et al. (2011). Lumped valve pressure-flow analogies.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-05-10
% VERSION:  2.0 -- non-regurgitant smoothed diode
% -------------------------------------------------------------------------

if nargin < 5 || isempty(smoothing_pressure)
    smoothing_pressure = 1.0e-6;    % Default smoothing width [mmHg]
end

if R_min <= 0
    error('valve_model:InvalidOpenResistance', ...
        'Open-valve resistance R_min must be positive.');
end

if nargin >= 4 && ~isempty(R_max) && R_max <= R_min
    warning('valve_model:ClosedResistanceNotUsed', ...
        ['R_max is retained for traceability only, but should remain ', ...
        'larger than R_min in the parameter table.']);
end

DeltaP = P_up - P_down;    % Pressure gradient across valve [mmHg]

positive_DeltaP = 0.5 * (DeltaP + sqrt(DeltaP.^2 + smoothing_pressure.^2));

Q = positive_DeltaP / R_min;    % Non-regurgitant valve flow [mL/s]

end
