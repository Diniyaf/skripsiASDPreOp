function [Q_sc, Q_pc, R_pc_eq, C_pc_eq] = vascular_model(P_sc, P_sv, P_pc, P_pv, params)
% VASCULAR_MODEL
% -----------------------------------------------------------------------
% Computes algebraic (non-inertial) vascular flows in the systemic
% capillary and pulmonary capillary segments.
%
% These flows are determined instantaneously from pressure gradients
% and segment resistances (no inertance in capillary beds):
%
%   Q_sc = (P_sc - P_sv) / R_sc    [systemic capillary to venous]
%   R_pc_eq = (R_pc * R_sh) / (R_pc + R_sh)
%   C_pc_eq = C_pc + C_sh
%   Q_pc    = (P_pc - P_pv) / R_pc_eq
%
% INPUTS:
%   P_sc   - systemic capillary pressure                   [mmHg]
%   P_sv   - systemic venous pressure                      [mmHg]
%   P_pc   - pulmonary capillary pressure                  [mmHg]
%   P_pv   - pulmonary venous pressure                     [mmHg]
%   params - parameter struct (contains R_sc, R_pc)
%
% OUTPUTS:
%   Q_sc   - systemic capillary flow (→ systemic venous)   [mL/s]
%   Q_pc   - pulmonary capillary flow (→ pulmonary venous) [mL/s]
%
% ASSUMPTIONS:
%   - Capillary beds are purely resistive (no inertance)
%   - Linear (Ohmic) pressure-flow relationship assumed
%   - R_sc represents total peripheral resistance in systemic bed
%   - Q_pc is composed of a parallel network of R_pc and R_sh
%
% SIGN CONVENTIONS:
%   - Q_sc > 0 → flow from systemic capillary to systemic venous
%   - Q_pc > 0 → flow from pulmonary capillary to pulmonary venous
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter ASD model.
%   [2] Heldt T et al. (2002). J Appl Physiol 92:1239-1254.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

R_sc = params.R_sc;    % Systemic capillary resistance [mmHg*s/mL]
R_pc = params.R_pc;    % Pulmonary capillary resistance [mmHg*s/mL]
R_sh = params.R_sh;    % Non-oxygenated shunt resistance [mmHg*s/mL]
C_pc = params.C_pc;    % Oxygenated pulmonary capillary compliance [mL/mmHg]
C_sh = params.C_sh;    % Non-oxygenated shunt compliance [mL/mmHg]

R_pc_denominator = R_pc + R_sh;    % Parallel resistance denominator [mmHg*s/mL]
if R_pc_denominator <= 0
    error('vascular_model:InvalidPulmonaryResistance', ...
        'R_pc + R_sh must be positive for the pulmonary parallel branch.');
end

R_pc_eq = (R_pc * R_sh) / R_pc_denominator;    % Equivalent resistance [mmHg*s/mL]
C_pc_eq = C_pc + C_sh;                         % Equivalent compliance [mL/mmHg]

DeltaP_sc = P_sc - P_sv;    % Systemic capillary pressure gradient  [mmHg]
DeltaP_pc = P_pc - P_pv;    % Pulmonary capillary pressure gradient [mmHg]

Q_sc = DeltaP_sc / R_sc;    % Systemic capillary flow   [mL/s]
Q_pc = DeltaP_pc / R_pc_eq; % Pulmonary capillary equivalent flow [mL/s]

end
