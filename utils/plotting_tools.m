function plotting_tools(t_ss, X_ss, indices, params)
% PLOTTING_TOOLS
% -----------------------------------------------------------------------
% Generates publication-ready figures from one steady-state cardiac cycle:
%   Figure 1 — Left- and right-sided pressure traces
%   Figure 2 — Chamber volume traces
%   Figure 3 — LV and RV pressure-volume (PV) loops
%   Figure 4 — Systemic and pulmonary arterial pressures
%
% INPUTS:
%   t_ss    - time vector, one steady-state cycle              [s]
%   X_ss    - state matrix (14 x N), one cycle                [mixed]
%   indices - clinical indices struct (from compute_clinical_indices.m)
%   params  - parameter struct (see config/default_parameters.m)
%
% OUTPUTS:
%   (none) — generates figure windows; exports PDF if results/ exists
%
% ASSUMPTIONS:
%   - Figures use Arial font and [0 0 16 12] cm format (journal standard)
%   - PV loop area approximates stroke work [mmHg·mL]
%
% REFERENCES:
%   [1] VIBECODING_GUARDRAILS.md Section 11 (Plotting Standards).
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

idx = params.idx;
t_plot = t_ss - t_ss(1);    % [s] — normalised to start at 0

%% ── COMPUTE CHAMBER PRESSURES FROM ELASTANCE ───────────────────────────

n_pts = length(t_ss);
P_lv_trace = zeros(1, n_pts);    % [mmHg]
P_rv_trace = zeros(1, n_pts);    % [mmHg]
P_la_trace = zeros(1, n_pts);    % [mmHg]
P_ra_trace = zeros(1, n_pts);    % [mmHg]

for k_pt = 1 : n_pts
    t_k    = t_ss(k_pt);
    V_lv_k = X_ss(idx.V_lv, k_pt);    % [mL]
    V_rv_k = X_ss(idx.V_rv, k_pt);    % [mL]
    V_la_k = X_ss(idx.V_la, k_pt);    % [mL]
    V_ra_k = X_ss(idx.V_ra, k_pt);    % [mL]

    P_lv_trace(k_pt) = elastance_model(t_k,'lv',params) * (V_lv_k - params.V0_lv);
    P_rv_trace(k_pt) = elastance_model(t_k,'rv',params) * (V_rv_k - params.V0_rv);
    P_la_trace(k_pt) = elastance_model(t_k,'la',params) * (V_la_k - params.V0_la);
    P_ra_trace(k_pt) = elastance_model(t_k,'ra',params) * (V_ra_k - params.V0_ra);
end

V_lv_trace = X_ss(idx.V_lv, :);    % [mL]
V_rv_trace = X_ss(idx.V_rv, :);    % [mL]
V_la_trace = X_ss(idx.V_la, :);    % [mL]
V_ra_trace = X_ss(idx.V_ra, :);    % [mL]
P_sa_trace = X_ss(idx.P_sa, :);    % [mmHg]
P_pa_trace = X_ss(idx.P_pa, :);    % [mmHg]

fig_w = 16;    % Figure width  [cm]
fig_h = 12;    % Figure height [cm]
lw    = 1.5;   % Line width    [pt]
fs_ax = 10;    % Axis font size
fs_lb = 11;    % Label font size

%% ── FIGURE 1: PRESSURE TRACES ───────────────────────────────────────────

figure('Units','centimeters','Position',[2 10 fig_w fig_h], ...
       'Name','Pressure Traces — Post-ASD Closure Baseline');
subplot(2,1,1); hold on; grid on; box on;
plot(t_plot, P_lv_trace, 'b-',  'LineWidth',lw, 'DisplayName','P_{LV}');
plot(t_plot, P_la_trace, 'b--', 'LineWidth',lw, 'DisplayName','P_{LA}');
plot(t_plot, P_sa_trace, 'r-',  'LineWidth',lw, 'DisplayName','P_{Ao}');
xlabel('Time [s]','FontSize',fs_lb,'FontName','Arial');
ylabel('Pressure [mmHg]','FontSize',fs_lb,'FontName','Arial');
title('Left-Sided Pressures','FontSize',fs_lb,'FontName','Arial');
legend('FontSize',fs_ax,'Location','best'); ylim([0 150]);
set(gca,'FontSize',fs_ax,'FontName','Arial');

subplot(2,1,2); hold on; grid on; box on;
plot(t_plot, P_rv_trace, 'g-',  'LineWidth',lw, 'DisplayName','P_{RV}');
plot(t_plot, P_ra_trace, 'g--', 'LineWidth',lw, 'DisplayName','P_{RA}');
plot(t_plot, P_pa_trace, 'm-',  'LineWidth',lw, 'DisplayName','P_{PA}');
xlabel('Time [s]','FontSize',fs_lb,'FontName','Arial');
ylabel('Pressure [mmHg]','FontSize',fs_lb,'FontName','Arial');
title('Right-Sided Pressures','FontSize',fs_lb,'FontName','Arial');
legend('FontSize',fs_ax,'Location','best'); ylim([0 50]);
set(gca,'FontSize',fs_ax,'FontName','Arial');

%% ── FIGURE 2: VOLUME TRACES ─────────────────────────────────────────────

figure('Units','centimeters','Position',[20 10 fig_w fig_h], ...
       'Name','Volume Traces — Post-ASD Closure Baseline');
subplot(2,1,1); hold on; grid on; box on;
plot(t_plot, V_lv_trace, 'b-',  'LineWidth',lw, 'DisplayName','V_{LV}');
plot(t_plot, V_la_trace, 'b--', 'LineWidth',lw, 'DisplayName','V_{LA}');
xlabel('Time [s]','FontSize',fs_lb,'FontName','Arial');
ylabel('Volume [mL]','FontSize',fs_lb,'FontName','Arial');
title('Left-Sided Volumes','FontSize',fs_lb,'FontName','Arial');
legend('FontSize',fs_ax,'Location','best');
set(gca,'FontSize',fs_ax,'FontName','Arial');

subplot(2,1,2); hold on; grid on; box on;
plot(t_plot, V_rv_trace, 'g-',  'LineWidth',lw, 'DisplayName','V_{RV}');
plot(t_plot, V_ra_trace, 'g--', 'LineWidth',lw, 'DisplayName','V_{RA}');
xlabel('Time [s]','FontSize',fs_lb,'FontName','Arial');
ylabel('Volume [mL]','FontSize',fs_lb,'FontName','Arial');
title('Right-Sided Volumes','FontSize',fs_lb,'FontName','Arial');
legend('FontSize',fs_ax,'Location','best');
set(gca,'FontSize',fs_ax,'FontName','Arial');

%% ── FIGURE 3: PV LOOPS ──────────────────────────────────────────────────

figure('Units','centimeters','Position',[2 -5 fig_w fig_h], ...
       'Name','PV Loops — Post-ASD Closure Baseline');
subplot(1,2,1); hold on; grid on; box on;
plot(V_lv_trace, P_lv_trace, 'b-', 'LineWidth',lw);
xlabel('V_{LV} [mL]','FontSize',fs_lb,'FontName','Arial');
ylabel('P_{LV} [mmHg]','FontSize',fs_lb,'FontName','Arial');
title(sprintf('LV PV Loop  (EF = %.1f%%)', indices.EF_lv * 100), ...
      'FontSize',fs_lb,'FontName','Arial');
set(gca,'FontSize',fs_ax,'FontName','Arial');

subplot(1,2,2); hold on; grid on; box on;
plot(V_rv_trace, P_rv_trace, 'g-', 'LineWidth',lw);
xlabel('V_{RV} [mL]','FontSize',fs_lb,'FontName','Arial');
ylabel('P_{RV} [mmHg]','FontSize',fs_lb,'FontName','Arial');
title(sprintf('RV PV Loop  (EF = %.1f%%)', indices.EF_rv * 100), ...
      'FontSize',fs_lb,'FontName','Arial');
set(gca,'FontSize',fs_ax,'FontName','Arial');

%% ── FIGURE 4: ARTERIAL PRESSURES ────────────────────────────────────────

figure('Units','centimeters','Position',[20 -5 fig_w fig_h], ...
       'Name','Arterial Pressures — Post-ASD Closure Baseline');
hold on; grid on; box on;
plot(t_plot, P_sa_trace, 'r-', 'LineWidth',lw, 'DisplayName','Aortic (P_{Ao})');
plot(t_plot, P_pa_trace, 'm-', 'LineWidth',lw, 'DisplayName','Pulmonary (P_{PA})');
xlabel('Time [s]','FontSize',fs_lb,'FontName','Arial');
ylabel('Pressure [mmHg]','FontSize',fs_lb,'FontName','Arial');
title(sprintf('Arterial Pressures  (CO = %.2f L/min, Qp/Qs = %.3f)', ...
    indices.CO, indices.Q_ratio),'FontSize',fs_lb,'FontName','Arial');
legend('FontSize',fs_ax,'Location','best');
set(gca,'FontSize',fs_ax,'FontName','Arial');

end
