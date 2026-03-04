function indices = compute_clinical_indices(t_ss, X_ss, params)
% COMPUTE_CLINICAL_INDICES
% -----------------------------------------------------------------------
% Computes derived haemodynamic clinical indices from one steady-state
% cardiac cycle. All internal flows are in mL/s; outputs converted to
% clinical reporting units where noted.
%
% INPUTS:
%   t_ss   - time vector for one steady-state cycle             [s]
%   X_ss   - state matrix for one cycle (14 x N)               [mixed]
%   params - parameter struct (see config/default_parameters.m)
%
% OUTPUTS:
%   indices - struct containing:
%     .V_lv_ed   - LV end-diastolic volume                     [mL]
%     .V_lv_es   - LV end-systolic volume                      [mL]
%     .SV_lv     - LV stroke volume                            [mL]
%     .EF_lv     - LV ejection fraction                        [fraction]
%     .V_rv_ed   - RV end-diastolic volume                     [mL]
%     .V_rv_es   - RV end-systolic volume                      [mL]
%     .SV_rv     - RV stroke volume                            [mL]
%     .EF_rv     - RV ejection fraction                        [fraction]
%     .CO        - cardiac output (systemic)                   [L/min]
%     .HR        - heart rate                                  [bpm]
%     .P_ao_sys  - aortic systolic pressure                    [mmHg]
%     .P_ao_dia  - aortic diastolic pressure                   [mmHg]
%     .P_ao_mean - aortic mean pressure                        [mmHg]
%     .P_pa_sys  - pulmonary artery systolic pressure          [mmHg]
%     .P_pa_dia  - pulmonary artery diastolic pressure         [mmHg]
%     .P_pa_mean - mean pulmonary artery pressure              [mmHg]
%     .Q_systemic  - systemic flow (Qs)                        [L/min]
%     .Q_pulmonary - pulmonary flow (Qp)                       [L/min]
%     .Q_ratio   - Qp/Qs ratio                                [dimensionless]
%
% NOTES:
%   EF stored as fraction (0–1); convert to % for display only.
%
% REFERENCES:
%   [1] Valenti et al. (2023). Clinical output definitions.
%   [2] VIBECODING_GUARDRAILS.md Section 6.4 (EF as fraction).
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

uc  = unit_conversion();    % Conversion factors struct
idx = params.idx;

%% ── EXTRACT VOLUME AND PRESSURE TRACES ─────────────────────────────────

V_lv_trace = X_ss(idx.V_lv, :);    % LV volume over cycle   [mL]
V_rv_trace = X_ss(idx.V_rv, :);    % RV volume over cycle   [mL]
P_sa_trace = X_ss(idx.P_sa, :);    % Aortic pressure trace  [mmHg]
P_pa_trace = X_ss(idx.P_pa, :);    % PA pressure trace      [mmHg]

%% ── VENTRICULAR VOLUMES ─────────────────────────────────────────────────

V_lv_ed = max(V_lv_trace);    % LV end-diastolic volume    [mL]
V_lv_es = min(V_lv_trace);    % LV end-systolic volume     [mL]
SV_lv   = V_lv_ed - V_lv_es; % LV stroke volume           [mL]
EF_lv   = SV_lv  / V_lv_ed;  % LV ejection fraction       [fraction]

V_rv_ed = max(V_rv_trace);    % RV end-diastolic volume    [mL]
V_rv_es = min(V_rv_trace);    % RV end-systolic volume     [mL]
SV_rv   = V_rv_ed - V_rv_es; % RV stroke volume           [mL]
EF_rv   = SV_rv  / V_rv_ed;  % RV ejection fraction       [fraction]

%% ── PRESSURES ───────────────────────────────────────────────────────────

P_ao_sys  = max(P_sa_trace);             % Aortic systolic pressure  [mmHg]
P_ao_dia  = min(P_sa_trace);             % Aortic diastolic pressure [mmHg]
P_ao_mean = trapz(t_ss, P_sa_trace) ...
           / (t_ss(end) - t_ss(1));      % Mean aortic pressure      [mmHg]

P_pa_sys  = max(P_pa_trace);             % PA systolic pressure      [mmHg]
P_pa_dia  = min(P_pa_trace);             % PA diastolic pressure     [mmHg]
P_pa_mean = trapz(t_ss, P_pa_trace) ...
           / (t_ss(end) - t_ss(1));      % Mean PA pressure          [mmHg]

%% ── CARDIAC OUTPUT AND FLOWS ────────────────────────────────────────────

HR = params.HR;    % Heart rate [bpm]

% CO [L/min] = SV [mL] * HR [bpm] * conversion
mLs_to_Lmin = uc.mLs_to_Lmin;    % [L/min per mL/s]
CO_Lmin      = SV_lv * HR * mLs_to_Lmin;    % Cardiac output [L/min]

% Systemic and pulmonary flows via stroke volumes
Q_systemic_Lmin  = SV_lv * HR * mLs_to_Lmin;    % Qs [L/min]
Q_pulmonary_Lmin = SV_rv * HR * mLs_to_Lmin;    % Qp [L/min]

Q_ratio = Q_pulmonary_Lmin / Q_systemic_Lmin;    % Qp/Qs [dimensionless]

%% ── PACKAGE OUTPUT STRUCT ───────────────────────────────────────────────

indices.V_lv_ed      = V_lv_ed;              % [mL]
indices.V_lv_es      = V_lv_es;              % [mL]
indices.SV_lv        = SV_lv;               % [mL]
indices.EF_lv        = EF_lv;               % [fraction]

indices.V_rv_ed      = V_rv_ed;              % [mL]
indices.V_rv_es      = V_rv_es;              % [mL]
indices.SV_rv        = SV_rv;               % [mL]
indices.EF_rv        = EF_rv;               % [fraction]

indices.HR           = HR;                   % [bpm]
indices.CO           = CO_Lmin;             % [L/min]
indices.P_ao_sys     = P_ao_sys;            % [mmHg]
indices.P_ao_dia     = P_ao_dia;            % [mmHg]
indices.P_ao_mean    = P_ao_mean;           % [mmHg]
indices.P_pa_sys     = P_pa_sys;            % [mmHg]
indices.P_pa_dia     = P_pa_dia;            % [mmHg]
indices.P_pa_mean    = P_pa_mean;           % [mmHg]
indices.Q_systemic   = Q_systemic_Lmin;    % [L/min]
indices.Q_pulmonary  = Q_pulmonary_Lmin;   % [L/min]
indices.Q_ratio      = Q_ratio;            % [dimensionless]

%% ── PRINT SUMMARY ───────────────────────────────────────────────────────

fprintf('\n=== CLINICAL INDICES ===\n');
fprintf('  HR          : %.1f bpm\n',       HR);
fprintf('  CO          : %.2f L/min\n',     CO_Lmin);
fprintf('  SV_lv       : %.1f mL\n',        SV_lv);
fprintf('  EF_lv       : %.1f %%\n',        EF_lv * uc.fraction_to_pct);
fprintf('  EF_rv       : %.1f %%\n',        EF_rv * uc.fraction_to_pct);
fprintf('  P_ao_sys    : %.1f mmHg\n',      P_ao_sys);
fprintf('  P_ao_dia    : %.1f mmHg\n',      P_ao_dia);
fprintf('  P_pa_mean   : %.1f mmHg\n',      P_pa_mean);
fprintf('  Qp/Qs       : %.3f\n',           Q_ratio);

end
