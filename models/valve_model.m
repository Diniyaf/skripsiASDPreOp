function Q = valve_model(P_up, P_down, R_min, R_max)
% VALVE_MODEL
% -----------------------------------------------------------------------
% Computes flow through a cardiac valve using pressure-dependent
% resistance switching (R_min when open, R_max when closed).
%
% Governing equation (smooth max formulation — numerically robust):
%   Q = max(0, P_up - P_down) / R_min
%       + min(0, P_up - P_down) / R_max
%
% This avoids hard if/else switching that creates near-discontinuities
% and forces excessively small ODE solver steps. The 'min' term allows
% a tiny controlled backflow through the closed valve (DeltaP/R_max ≈ 0).
%
% INPUTS:
%   P_up    - upstream chamber/vessel pressure              [mmHg]
%   P_down  - downstream chamber/vessel pressure            [mmHg]
%   R_min   - open-valve resistance (forward flow)          [mmHg·s/mL]
%   R_max   - closed-valve resistance (reverse flow block)  [mmHg·s/mL]
%
% OUTPUTS:
%   Q       - volumetric flow rate through valve            [mL/s]
%
% ASSUMPTIONS:
%   - Incompressible, Newtonian flow at valve orifice
%   - Valve opens instantaneously when P_up > P_down
%   - R_max >> R_min ensures negligible leakage (R_max ~ 5e4–7.5e4)
%
% SIGN CONVENTIONS:
%   - Q > 0 → forward (physiological) flow direction
%   - Q < 0 → minimal regurgitation (bounded by R_max)
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter ASD model. Valve section.
%   [2] Shi Y et al. (2011). Interface Focus 1:20-33. Eq.(4).
%   [3] VIBECODING_GUARDRAILS.md Section 8.4 (smooth max, no hard switching)
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

DeltaP = P_up - P_down;    % Pressure gradient across valve [mmHg]

% Smooth max/min formulation — no discontinuity at DeltaP = 0
Q = max(0, DeltaP) / R_min ...    % [mL/s] — forward flow component
  + min(0, DeltaP) / R_max;       % [mL/s] — reverse flow component (≈ 0)

end
