function [Q_sc, Q_pc] = vascular_model(P_sc, P_sv, P_pc, P_pv, params)
% VASCULAR_MODEL
% -----------------------------------------------------------------------
% Computes algebraic (non-inertial) vascular flows in the systemic
% capillary and pulmonary capillary segments.
%
% These flows are determined instantaneously from pressure gradients
% and segment resistances (no inertance in capillary beds):
%
%   Q_sc = (P_sc - P_sv) / R_sc    [systemic capillary to venous]
%   Q_ox = (P_pc - P_pv) / R_pc    [oxygenated pulmonary capillary to venous]
%   Q_sh = (P_pc - P_pv) / R_sh    [non-oxygenated pulmonary capillary to venous]
%   Q_pc = Q_ox + Q_sh             [total pulmonary capillary to venous]
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

R_sc = params.R_sc;    % Systemic capillary resistance  [mmHg·s/mL]
R_pc = params.R_pc;    % Pulmonary capillary resistance [mmHg·s/mL]
R_sh = params.R_sh;    % Non-oxygenated shunt resistance [mmHg·s/mL]

DeltaP_sc = P_sc - P_sv;    % Systemic capillary pressure gradient  [mmHg]
DeltaP_pc = P_pc - P_pv;    % Pulmonary capillary pressure gradient [mmHg]

Q_sc = DeltaP_sc / R_sc;    % Systemic capillary flow   [mL/s]
Q_ox = DeltaP_pc / R_pc;    % Oxygenated pulmonary cap flow [mL/s]
Q_sh = DeltaP_pc / R_sh;    % Non-oxygenated pulmonary shunt flow [mL/s]
Q_pc = Q_ox + Q_sh;         % Total pulmonary capillary flow [mL/s]

end
