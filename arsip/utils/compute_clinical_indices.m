function indices = compute_clinical_indices(t_ss, X_ss, params)
% COMPUTE_CLINICAL_INDICES
% -------------------------------------------------------------------------
% Computes standard clinical hemodynamic indices from one steady-state
% cardiac cycle. Pressures are reported in mmHg, volumes in mL, flows in
% L/min, and indexed pediatric values use BSA when available in params.
% -------------------------------------------------------------------------

uc = unit_conversion();
idx = params.idx;
BSA = resolve_bsa(params); % [m^2]

cycle_duration_s = t_ss(end) - t_ss(1); % [s]

% Steady-state sanity check using LV pressure and volume.
P_lv_start = elastance_model(t_ss(1), 'lv', params) ...
    * (X_ss(idx.V_lv, 1) - params.V0_lv);
P_lv_end = elastance_model(t_ss(end), 'lv', params) ...
    * (X_ss(idx.V_lv, end) - params.V0_lv);
delta_P_lv = abs(P_lv_start - P_lv_end);
delta_V_lv = abs(X_ss(idx.V_lv, 1) - X_ss(idx.V_lv, end));
if delta_P_lv > 0.1 || delta_V_lv > 0.1
    warning('compute_clinical_indices:SteadyStateWarning', ...
        'Steady-state criteria not strictly met. delta_P_LV=%.3f, delta_V_LV=%.3f', ...
        delta_P_lv, delta_V_lv);
end

V_lv_trace = X_ss(idx.V_lv, :); % [mL]
V_rv_trace = X_ss(idx.V_rv, :); % [mL]
P_sa_trace = X_ss(idx.P_sa, :); % [mmHg]
P_pa_trace = X_ss(idx.P_pa, :); % [mmHg]

n_pts = numel(t_ss);
P_ra_trace = zeros(1, n_pts);
P_la_trace = zeros(1, n_pts);
Q_asd_trace = zeros(1, n_pts);
DeltaP_asd_trace = zeros(1, n_pts);

for k_pt = 1:n_pts
    t_k = t_ss(k_pt);
    P_ra_trace(k_pt) = elastance_model(t_k, 'ra', params) ...
        * (X_ss(idx.V_ra, k_pt) - params.V0_ra);
    P_la_trace(k_pt) = elastance_model(t_k, 'la', params) ...
        * (X_ss(idx.V_la, k_pt) - params.V0_la);
    DeltaP_asd_trace(k_pt) = P_la_trace(k_pt) - P_ra_trace(k_pt);
    Q_asd_trace(k_pt) = asd_shunt_model(P_la_trace(k_pt), ...
        P_ra_trace(k_pt), params);
end

% Volumes and pump function.
V_lv_ed = max(V_lv_trace);   % [mL]
V_lv_es = min(V_lv_trace);   % [mL]
SV_lv = V_lv_ed - V_lv_es;   % [mL]
EF_lv = SV_lv / V_lv_ed;     % [fraction]

V_rv_ed = max(V_rv_trace);   % [mL]
V_rv_es = min(V_rv_trace);   % [mL]
SV_rv = V_rv_ed - V_rv_es;   % [mL]
EF_rv = SV_rv / V_rv_ed;     % [fraction]

LVEDVi = V_lv_ed / BSA;      % [mL/m^2]
LVESVi = V_lv_es / BSA;      % [mL/m^2]
RVEDVi = V_rv_ed / BSA;      % [mL/m^2]
RVESVi = V_rv_es / BSA;      % [mL/m^2]
SVi_lv = SV_lv / BSA;        % [mL/m^2]
SVi_rv = SV_rv / BSA;        % [mL/m^2]

% Pressures.
P_ao_sys = max(P_sa_trace);  % [mmHg]
P_ao_dia = min(P_sa_trace);  % [mmHg]
P_ao_mean = trapz(t_ss, P_sa_trace) / cycle_duration_s; % [mmHg]

P_pa_sys = max(P_pa_trace);  % [mmHg]
P_pa_dia = min(P_pa_trace);  % [mmHg]
P_pa_mean = trapz(t_ss, P_pa_trace) / cycle_duration_s; % [mmHg]

RAP = trapz(t_ss, P_ra_trace) / cycle_duration_s;       % [mmHg]
LAP = trapz(t_ss, P_la_trace) / cycle_duration_s;       % [mmHg]
DeltaP_asd_mean = trapz(t_ss, DeltaP_asd_trace) / cycle_duration_s;
DeltaP_asd_max = max(DeltaP_asd_trace);
DeltaP_asd_min = min(DeltaP_asd_trace);

% Flows.
HR = params.HR;                              % [bpm]
CO_systemic = SV_lv * HR / 1000.0;           % [L/min]
CI_systemic = CO_systemic / BSA;             % [L/min/m^2]
Q_systemic_Lmin = CO_systemic;               % Qs [L/min]
Q_pulmonary_Lmin = SV_rv * HR / 1000.0;      % Qp [L/min]
Q_systemic_mLs = SV_lv * HR / 60.0;          % [mL/s]
Q_pulmonary_mLs = SV_rv * HR / 60.0;         % [mL/s]
Q_ratio = Q_pulmonary_Lmin / Q_systemic_Lmin;

Q_asd_mean_mLs = trapz(t_ss, Q_asd_trace) / cycle_duration_s; % [mL/s]
Q_asd_Lmin = Q_asd_mean_mLs * uc.mLs_to_Lmin;                 % [L/min]
if Q_asd_mean_mLs > 1.0e-3
    ASD_direction = 'left-to-right';
elseif Q_asd_mean_mLs < -1.0e-3
    ASD_direction = 'right-to-left';
else
    ASD_direction = 'closed_or_zero';
end

% Resistances. WU = mmHg/(L/min); indexed value = WU*m^2.
SVR = (P_ao_mean - RAP) / Q_systemic_mLs;        % [mmHg*s/mL]
PVR = (P_pa_mean - LAP) / Q_pulmonary_mLs;       % [mmHg*s/mL]
SVR_WU = (P_ao_mean - RAP) / Q_systemic_Lmin;    % [WU]
PVR_WU = (P_pa_mean - LAP) / Q_pulmonary_Lmin;   % [WU]
SVRi_WU_m2 = SVR_WU * BSA;                       % [WU*m^2]
PVRi_WU_m2 = PVR_WU * BSA;                       % [WU*m^2]

indices = struct();
indices.BSA = BSA;

indices.V_lv_ed = V_lv_ed;
indices.V_lv_es = V_lv_es;
indices.SV_lv = SV_lv;
indices.EF_lv = EF_lv;
indices.LVEDVi = LVEDVi;
indices.LVESVi = LVESVi;
indices.SVi_lv = SVi_lv;

indices.V_rv_ed = V_rv_ed;
indices.V_rv_es = V_rv_es;
indices.SV_rv = SV_rv;
indices.EF_rv = EF_rv;
indices.RVEDVi = RVEDVi;
indices.RVESVi = RVESVi;
indices.SVi_rv = SVi_rv;

indices.HR = HR;
indices.CO_systemic = CO_systemic;
indices.CI_systemic = CI_systemic;
indices.Q_systemic = Q_systemic_Lmin;
indices.Q_pulmonary = Q_pulmonary_Lmin;
indices.Qs = Q_systemic_Lmin;
indices.Qp = Q_pulmonary_Lmin;
indices.Q_ratio = Q_ratio;

indices.P_ao_sys = P_ao_sys;
indices.P_ao_dia = P_ao_dia;
indices.P_ao_mean = P_ao_mean;
indices.SAP_max = P_ao_sys;
indices.SAP_min = P_ao_dia;
indices.MAP = P_ao_mean;
indices.P_pa_sys = P_pa_sys;
indices.P_pa_dia = P_pa_dia;
indices.P_pa_mean = P_pa_mean;
indices.PAP_max = P_pa_sys;
indices.PAP_min = P_pa_dia;
indices.PAP_mean = P_pa_mean;
indices.RAP = RAP;
indices.LAP = LAP;
indices.P_LA_mean = LAP;
indices.P_RA_mean = RAP;
indices.LVEDP_est = LAP;
indices.transseptal_gradient_mean = DeltaP_asd_mean;
indices.transseptal_gradient_max = DeltaP_asd_max;
indices.transseptal_gradient_min = DeltaP_asd_min;

indices.SVR = SVR;
indices.PVR = PVR;
indices.SVR_WU = SVR_WU;
indices.PVR_WU = PVR_WU;
indices.SVRi_WU_m2 = SVRi_WU_m2;
indices.PVRi_WU_m2 = PVRi_WU_m2;

indices.Q_ASD_mean_mLs = Q_asd_mean_mLs;
indices.Q_ASD_Lmin = Q_asd_Lmin;
indices.ASD_direction = ASD_direction;

fprintf('\n=== CLINICAL INDICES ===\n');
fprintf('  HR          : %.1f bpm\n', HR);
fprintf('  CO_systemic : %.2f L/min\n', CO_systemic);
fprintf('  CI_systemic : %.2f L/min/m^2\n', CI_systemic);
fprintf('  SV_lv       : %.1f mL\n', SV_lv);
fprintf('  LVEDVi      : %.1f mL/m^2\n', LVEDVi);
fprintf('  RVEDVi      : %.1f mL/m^2\n', RVEDVi);
fprintf('  EF_lv       : %.1f %%\n', EF_lv * uc.fraction_to_pct);
fprintf('  EF_rv       : %.1f %%\n', EF_rv * uc.fraction_to_pct);
fprintf('  P_ao_sys    : %.1f mmHg\n', P_ao_sys);
fprintf('  P_ao_dia    : %.1f mmHg\n', P_ao_dia);
fprintf('  P_pa_mean   : %.1f mmHg\n', P_pa_mean);
fprintf('  SVR         : %.3f mmHg*s/mL\n', SVR);
fprintf('  PVR         : %.3f mmHg*s/mL\n', PVR);
fprintf('  SVRi        : %.2f WU*m^2\n', SVRi_WU_m2);
fprintf('  PVRi        : %.2f WU*m^2\n', PVRi_WU_m2);
fprintf('  Qp/Qs       : %.3f\n', Q_ratio);
fprintf('  Q_ASD       : %.3f L/min (%s)\n', Q_asd_Lmin, ASD_direction);
fprintf('  LAP/RAP     : %.2f / %.2f mmHg\n', LAP, RAP);
fprintf('  LAP-RAP     : %.2f mmHg\n', DeltaP_asd_mean);

end

function BSA = resolve_bsa(params)
BSA = NaN;
if isfield(params, 'scaling') && isfield(params.scaling, 'patient') ...
        && isfield(params.scaling.patient, 'BSA')
    BSA = params.scaling.patient.BSA;
elseif isfield(params, 'scaling') && isfield(params.scaling, 'BSA_patient')
    BSA = params.scaling.BSA_patient;
elseif isfield(params, 'BSA')
    BSA = params.BSA;
end

if isempty(BSA) || ~isfinite(BSA) || BSA <= 0.0
    BSA = 1.0;
end
end
