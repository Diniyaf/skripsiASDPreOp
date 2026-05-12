function metrics = compute_valenti_adult_metrics(t_ss, X_ss, params)
% COMPUTE_VALENTI_ADULT_METRICS
% -------------------------------------------------------------------------
% Computes the adult ASD validation metrics reported in Valenti Table 4.4.
%
% INPUTS:
%   t_ss   - time vector for one periodic steady-state cycle [s]
%   X_ss   - state matrix for one cycle                      [mixed]
%   params - parameter struct
%
% OUTPUT:
%   metrics - struct with Table 4.4-compatible fields
%
% NOTES:
%   PWP is represented by the pulmonary venous pressure state P_pv, matching
%   Valenti's definition of pulmonary wedge pressure as P_PUL_VEN.
% -------------------------------------------------------------------------

idx = params.idx;
n_pts = length(t_ss);

P_lv_trace = zeros(1, n_pts);
P_rv_trace = zeros(1, n_pts);
P_ra_trace = zeros(1, n_pts);

for k_pt = 1:n_pts
    t_k = t_ss(k_pt);
    P_lv_trace(k_pt) = elastance_model(t_k, 'lv', params) ...
        * (X_ss(idx.V_lv, k_pt) - params.V0_lv);
    P_rv_trace(k_pt) = elastance_model(t_k, 'rv', params) ...
        * (X_ss(idx.V_rv, k_pt) - params.V0_rv);
    P_ra_trace(k_pt) = elastance_model(t_k, 'ra', params) ...
        * (X_ss(idx.V_ra, k_pt) - params.V0_ra);
end

P_pa_trace = X_ss(idx.P_pa, :);
P_pv_trace = X_ss(idx.P_pv, :);
P_sa_trace = X_ss(idx.P_sa, :);

cycle_duration = t_ss(end) - t_ss(1);    % [s]

metrics.pRA_mean = trapz(t_ss, P_ra_trace) / cycle_duration;    % [mmHg]
metrics.pRV_max  = max(P_rv_trace);                             % [mmHg]
metrics.pRV_min  = min(P_rv_trace);                             % [mmHg]
metrics.PAP_max  = max(P_pa_trace);                             % [mmHg]
metrics.PAP_min  = min(P_pa_trace);                             % [mmHg]
metrics.PAP_mean = trapz(t_ss, P_pa_trace) / cycle_duration;    % [mmHg]
metrics.PWP_mean = trapz(t_ss, P_pv_trace) / cycle_duration;    % [mmHg]
metrics.pLV_max  = max(P_lv_trace);                             % [mmHg]
metrics.pLV_min  = min(P_lv_trace);                             % [mmHg]
metrics.SAP_max  = max(P_sa_trace);                             % [mmHg]
metrics.SAP_min  = min(P_sa_trace);                             % [mmHg]
metrics.SAP_mean = trapz(t_ss, P_sa_trace) / cycle_duration;    % [mmHg]

liters_per_milliliter = 1.0e-3;    % [L/mL]
V_lv_trace = X_ss(idx.V_lv, :);     % [mL]
V_rv_trace = X_ss(idx.V_rv, :);     % [mL]
SV_lv = max(V_lv_trace) - min(V_lv_trace);    % [mL]
SV_rv = max(V_rv_trace) - min(V_rv_trace);    % [mL]

metrics.QP = SV_rv * params.HR * liters_per_milliliter;    % [L/min]
metrics.QS = SV_lv * params.HR * liters_per_milliliter;    % [L/min]

end
