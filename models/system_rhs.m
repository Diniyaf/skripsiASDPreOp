function dXdt = system_rhs(t, X, params)
% SYSTEM_RHS
% -----------------------------------------------------------------------
% Right-hand side of the 14-ODE closed-loop cardiovascular system for
% post-ASD closure simulation, following Valenti et al. (2023).
%
% STATE VECTOR LAYOUT (14 states):
%   idx.V_lv [1] — LV volume                         [mL]
%   idx.V_rv [2] — RV volume                         [mL]
%   idx.V_la [3] — LA volume                         [mL]
%   idx.V_ra [4] — RA volume                         [mL]
%   idx.P_sa [5] — Systemic arterial pressure        [mmHg]
%   idx.P_sc [6] — Systemic capillary pressure       [mmHg]
%   idx.P_sv [7] — Systemic venous pressure          [mmHg]
%   idx.P_pa [8] — Pulmonary arterial pressure       [mmHg]
%   idx.P_pc [9] — Pulmonary capillary pressure      [mmHg]
%   idx.P_pv[10] — Pulmonary venous pressure         [mmHg]
%   idx.Q_sa[11] — Systemic arterial inertial flow   [mL/s]
%   idx.Q_sv[12] — Systemic venous inertial flow     [mL/s]
%   idx.Q_pa[13] — Pulmonary arterial inertial flow  [mL/s]
%   idx.Q_pv[14] — Pulmonary venous inertial flow    [mL/s]
%
% GOVERNING EQUATIONS:
%   Chambers:      dV/dt = Q_in - Q_out
%   Vascular:      C * dP/dt = Q_in - Q_out
%   Inertial flow: L * dQ/dt = DeltaP - R*Q
%   Valve flow:    Q = max(0,DeltaP)/R_min + min(0,DeltaP)/R_max
%   ASD shunt:     Q_shunt_asd = (P_la - P_ra) / R_ASD
%
% INPUTS:
%   t      - current time                                  [s]
%   X      - state vector (14 x 1)                        [mixed]
%   params - parameter struct (see config/default_parameters.m)
%
% OUTPUTS:
%   dXdt   - time derivatives of state vector (14 x 1)    [mixed/s]
%
% ASSUMPTIONS:
%   - Closed-loop; total blood volume is conserved
%   - Capillary beds are purely resistive (no inertance)
%   - All pressure gradients: upstream minus downstream
%   - ASD post-closure: params.R_ASD = Inf → Q_shunt_asd = 0
%
% SIGN CONVENTIONS:
%   - All flows: positive = physiologically forward direction
%   - Q_shunt_asd > 0 → left-to-right (LA → RA)
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter ASD model. Eqs.(1)-(14).
%   [2] Heldt T et al. (2002). J Appl Physiol 92:1239-1254.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

idx  = params.idx;
dXdt = zeros(params.n_state, 1);

%% ── 1. EXTRACT STATE VARIABLES ─────────────────────────────────────────

V_lv = X(idx.V_lv);    % LV volume                         [mL]
V_rv = X(idx.V_rv);    % RV volume                         [mL]
V_la = X(idx.V_la);    % LA volume                         [mL]
V_ra = X(idx.V_ra);    % RA volume                         [mL]

P_sa = X(idx.P_sa);    % Systemic arterial pressure        [mmHg]
P_sc = X(idx.P_sc);    % Systemic capillary pressure       [mmHg]
P_sv = X(idx.P_sv);    % Systemic venous pressure          [mmHg]
P_pa = X(idx.P_pa);    % Pulmonary arterial pressure       [mmHg]
P_pc = X(idx.P_pc);    % Pulmonary capillary pressure      [mmHg]
P_pv = X(idx.P_pv);    % Pulmonary venous pressure         [mmHg]

Q_sa = X(idx.Q_sa);    % Systemic arterial inertial flow   [mL/s]
Q_sv = X(idx.Q_sv);    % Systemic venous inertial flow     [mL/s]
Q_pa = X(idx.Q_pa);    % Pulmonary arterial inertial flow  [mL/s]
Q_pv = X(idx.Q_pv);    % Pulmonary venous inertial flow    [mL/s]

%% ── 2. CHAMBER PRESSURES FROM ELASTANCE ────────────────────────────────

E_lv = elastance_model(t, 'lv', params);    % LV elastance [mmHg/mL]
E_rv = elastance_model(t, 'rv', params);    % RV elastance [mmHg/mL]
E_la = elastance_model(t, 'la', params);    % LA elastance [mmHg/mL]
E_ra = elastance_model(t, 'ra', params);    % RA elastance [mmHg/mL]

P_lv = E_lv * (V_lv - params.V0_lv);    % LV pressure [mmHg]
P_rv = E_rv * (V_rv - params.V0_rv);    % RV pressure [mmHg]
P_la = E_la * (V_la - params.V0_la);    % LA pressure [mmHg]
P_ra = E_ra * (V_ra - params.V0_ra);    % RA pressure [mmHg]

%% ── 3. VALVE FLOWS ──────────────────────────────────────────────────────

% Mitral valve (LA → LV): open when P_la > P_lv
Q_mv = valve_model(P_la, P_lv, params.R_mv_min, params.R_mv_max);    % [mL/s]

% Aortic valve (LV → systemic arterial): open when P_lv > P_sa
Q_ao = valve_model(P_lv, P_sa, params.R_ao_min, params.R_ao_max);    % [mL/s]

% Tricuspid valve (RA → RV): open when P_ra > P_rv
Q_tv = valve_model(P_ra, P_rv, params.R_tv_min, params.R_tv_max);    % [mL/s]

% Pulmonary valve (RV → pulmonary arterial): open when P_rv > P_pa
Q_pv_valve = valve_model(P_rv, P_pa, ...
    params.R_pv_valve_min, params.R_pv_valve_max);                    % [mL/s]

%% ── 4. ASD SHUNT FLOW ──────────────────────────────────────────────────
% Post-closure: R_ASD = Inf → Q_shunt_asd = 0

Q_shunt_asd = asd_shunt_model(P_la, P_ra, params);    % [mL/s]

%% ── 5. ALGEBRAIC CAPILLARY FLOWS ───────────────────────────────────────

[Q_sc, Q_pc] = vascular_model(P_sc, P_sv, P_pc, P_pv, params);
% Q_sc — systemic capillary flow  [mL/s]
% Q_pc — pulmonary capillary flow [mL/s]

%% ── 6. CHAMBER VOLUME ODEs ──────────────────────────────────────────────
% dV/dt = Q_in - Q_out

% LA: inflow = pulmonary venous return; outflow = mitral + ASD shunt
dXdt(idx.V_la) = Q_pv - Q_mv - Q_shunt_asd;    % [mL/s]

% LV: inflow = mitral; outflow = aortic valve
dXdt(idx.V_lv) = Q_mv - Q_ao;                   % [mL/s]

% RA: inflow = systemic venous return + ASD shunt; outflow = tricuspid
dXdt(idx.V_ra) = Q_sv - Q_tv + Q_shunt_asd;     % [mL/s]

% RV: inflow = tricuspid; outflow = pulmonary valve
dXdt(idx.V_rv) = Q_tv - Q_pv_valve;             % [mL/s]

%% ── 7. VASCULAR PRESSURE ODEs ──────────────────────────────────────────
% C * dP/dt = Q_in - Q_out

% Systemic arterial: inflow = aortic valve; outflow = inertial arterial
dXdt(idx.P_sa) = (Q_ao - Q_sa) / params.C_sa;              % [mmHg/s]

% Systemic capillary: inflow = inertial arterial; outflow = capillary resist.
dXdt(idx.P_sc) = (Q_sa - Q_sc) / params.C_sc;              % [mmHg/s]

% Systemic venous: inflow = capillary; outflow = inertial venous
dXdt(idx.P_sv) = (Q_sc - Q_sv) / params.C_sv;              % [mmHg/s]

% Pulmonary arterial: inflow = pulmonary valve; outflow = inertial pul. art.
dXdt(idx.P_pa) = (Q_pv_valve - Q_pa) / params.C_pa;        % [mmHg/s]

% Pulmonary capillary: inflow = inertial pul. art.; outflow = pul. cap. resist.
dXdt(idx.P_pc) = (Q_pa - Q_pc) / params.C_pc;    % [mmHg/s]

% Pulmonary venous: inflow = pul. cap.; outflow = inertial pul. venous
dXdt(idx.P_pv) = (Q_pc - Q_pv) / params.C_pv;              % [mmHg/s]

%% ── 8. INERTIAL FLOW ODEs ───────────────────────────────────────────────
% L * dQ/dt = DeltaP - R*Q

% Systemic arterial: P_sa → (R_sa, L_sa) → P_sc
dXdt(idx.Q_sa) = (P_sa - P_sc - params.R_sa * Q_sa) / params.L_sa;    % [mL/s²]

% Systemic venous return: P_sv → (R_sv, L_sv) → P_ra
dXdt(idx.Q_sv) = (P_sv - P_ra - params.R_sv * Q_sv) / params.L_sv;    % [mL/s²]

% Pulmonary arterial: P_pa → (R_pa, L_pa) → P_pc
dXdt(idx.Q_pa) = (P_pa - P_pc - params.R_pa * Q_pa) / params.L_pa;    % [mL/s²]

% Pulmonary venous return: P_pv → (R_pv, L_pv) → P_la
dXdt(idx.Q_pv) = (P_pv - P_la - params.R_pv * Q_pv) / params.L_pv;    % [mL/s²]

end
