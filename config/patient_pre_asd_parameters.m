function [params, X0] = patient_pre_asd_parameters()
% PATIENT_PRE_ASD_PARAMETERS
% -----------------------------------------------------------------------
% Patient-specific parameters for a pediatric ASD PRE-OPERATIVE scenario.
%
% This config follows the exact same three-step pipeline as the post-op
% equivalent (patient_post_asd_parameters.m):
%   1. Load adult baseline   → default_parameters()
%   2. Apply allometric scaling → pediatric_scaling()
%   3. Override / tune patient-specific values
%
% KEY DIFFERENCE FROM POST-OP CONFIG:
%   params.R_ASD = 5.0 [mmHg·s/mL]   ← finite (shunt OPEN)
%   vs.
%   params.R_ASD = 1e9 [mmHg·s/mL]   ← effectively infinite (shunt CLOSED)
%
% No physics files (system_rhs.m, asd_shunt_model.m, etc.) are modified.
% The finite R_ASD is passed through to asd_shunt_model() which already
% handles both Inf and finite values.
%
% CLINICAL REFERENCE CONTEXT (Arvidsson et al. 2026, Table 1, PRE-closure):
%   - Age 10, Female, 153 cm, 38 kg (BSA ~1.27 m^2)
%   - HR_target   ~ 90 bpm      (pre-op tachycardia / age-normal)
%   - RV_EDVi     > LV_EDVi     (classic RV volume overload)
%   - Qp/Qs       ~ 1.5–2.5     (haemodynamically significant shunt)
%   - PAP_mean    ~ 15–25 mmHg  (mildly elevated; PAH not yet present)
%
% STATUS:  PLACEHOLDER — not yet calibrated or validated.
%          All overrides in Section 3 are physiologically motivated
%          starting guesses. Formal calibration comes in a later step.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-03-20
% VERSION:  0.1 — initial pre-op scaffold (pre-calibration)
% -----------------------------------------------------------------------


%% ══════════════════════════════════════════════════════════════════════
%% SECTION 1 — BASELINE PARAMETERS + ALLOMETRIC SCALING
%% ══════════════════════════════════════════════════════════════════════
% Reuse the canonical adult baseline (28-parameter set) and scale it to
% the pediatric patient using BSA-based allometric rules.
% DO NOT change these lines — they are the shared foundation for ALL
% patient configs. Consistent use ensures scaling is explicit and auditable.

[params, ~] = default_parameters();           % Adult baseline

age_years  = 10;      % [years]
weight_kg  = 38;      % [kg]
height_cm  = 153;     % [cm]
sex        = 0;       % 0 = Female, 1 = Male

params = pediatric_scaling(params, age_years, weight_kg, height_cm, sex);
% After this call, params contains allometrically scaled values for:
%   HR, T_cardiac, Emax_lv, Emax_rv, V0_*, C_*, R_*, L_*
% These are the BASELINE for all overrides below.


%% ══════════════════════════════════════════════════════════════════════
%% SECTION 2 — PATIENT-SPECIFIC HEART RATE & TIMING
%% ══════════════════════════════════════════════════════════════════════
% Pre-op children with ASD often have a mildly elevated resting HR due to
% compensatory response to volume overload and reduced effective SV.
% Using a clinical target of 90 bpm (vs. 77 bpm post-op).
%
% IMPORTANT: ALL timing parameters (T_sys_*, T_rel_*, t_on_*) are derived
% as PROPORTIONS of T_cardiac. This is mandatory — fixed-second timings
% cause activation-window wrap-around and violate model assumptions.

params.HR        = 90;            % [bpm]   Pre-op target HR (vs. 77 post-op)
T                = 60.0 / 90.0;  % [s]     Cardiac cycle = 0.6667 s
params.T_cardiac = T;

% Ventricular timing (proportional to T; same fractions as post-op config)
params.t_on_lv  = 0.00;
params.T_sys_lv = 0.265 * T;    % [s]  LV systolic contraction
params.T_rel_lv = 0.40  * T;    % [s]  LV relaxation

params.t_on_rv  = 0.00;
params.T_sys_rv = 0.30  * T;    % [s]  RV systolic contraction
params.T_rel_rv = 0.40  * T;    % [s]  RV relaxation

% Atrial timing (relative to T)
% CONSTRAINT: t_on + T_sys + T_rel MUST be < T_cardiac to avoid wrap-around
params.t_on_la  = 0.75 * T;    % [s]  LA onset  = 0.500 s
params.T_sys_la = 0.10 * T;    % [s]  LA contraction = 0.067 s
params.T_rel_la = 0.13 * T;    % [s]  LA relaxation  = 0.087 s (ends 0.653 s < T)

params.t_on_ra  = 0.80 * T;    % [s]  RA onset  = 0.533 s
params.T_sys_ra = 0.10 * T;    % [s]  RA contraction = 0.067 s
params.T_rel_ra = 0.08 * T;    % [s]  RA relaxation  = 0.053 s (ends 0.653 s < T)


%% ══════════════════════════════════════════════════════════════════════
%% SECTION 3 — MANUAL OVERRIDES / PATIENT-SPECIFIC TUNING
%% ══════════════════════════════════════════════════════════════════════
% These values deviate from the scaled baseline to reflect known
% pre-operative ASD haemodynamics. They are PHYSIOLOGICALLY MOTIVATED
% starting guesses, not yet calibrated to measured echo/cath data.
%
% Each override is annotated with the physiological rationale and the
% direction of expected change vs. the post-op config.

% ── 3a. Ventricular Elastance ──────────────────────────────────────────
%
% LV:  After pediatric_scaling(), Emax_lv_scaled ≈ 2.70 / 0.7346 ≈ 3.68
%      mmHg/mL. The previous override of 2.50 fought the scaling and
%      depressed LV EF below 50% (LV_ESV too high). Setting 3.50 gives
%      a small deliberate reduction below the scaled value to reflect the
%      pre-op LV operating at slightly higher fill volume (volume overload
%      from increased pulmonary return), while preserving EF ≥ 50%.
%      (2026-03-21 FIX: 2.50 → 3.50 to correct LV EF FAIL)
params.Emax_lv = 3.50;    % [mmHg/mL]  pre-op LV; slight reduction from scaled ~3.68
params.Emin_lv = 0.06;    % [mmHg/mL]
params.V0_lv   = 5.0;     % [mL]

% RV:  Reduced Emax to reflect RV volume-overload adaptation.
%      Pre-op RV is dilated (eccentric remodelling), reducing effective
%      peak elastance. However, 0.30 was too low — it drove RV_EF to 33%
%      and RV_ESV to 96 mL (both OOR). A volume-overloaded pre-op RV
%      still contracts enough to maintain EF ≥ 40%.
%      Scaled baseline: 0.43 / 0.7346^1.5 ≈ 0.665; 0.40 is well below
%      that, correctly reflecting RV dilation without over-weakening it.
%      (2026-03-21 FIX: 0.30 → 0.40 to correct RV_EF / RV_ESV OOR)
params.Emax_rv = 0.40;    % [mmHg/mL]  volume-overloaded RV; below normal but EF-capable
params.Emin_rv = 0.035;   % [mmHg/mL]  slightly below post-op
params.V0_rv   = 12.0;    % [mL]       larger unstressed volume (RV dilation)

% Atria:  LA may be mildly enlarged pre-op (volume overload from shunt).
%         RA is dilated from receiving excess shunt return.
%
% ORDERING RULE (applies to ALL chambers):
%   elastance_model uses:  E(t) = Emin + (Emax - Emin) * e_n(t),  e_n in [0,1]
%   Therefore Emax MUST be > Emin so that activation RAISES chamber pressure.
%   If Emax < Emin, contraction LOWERS E(t) -> pressure drops during systole
%   (inverted physics -> collapses the LA-RA gradient -> near-zero shunt).

params.Emax_la = 0.40;    % [mmHg/mL]  LA peak (systolic) elastance  [Emax > Emin: OK]
params.Emin_la = 0.28;    % [mmHg/mL]  LA diastolic elastance

% MINIMAL FIX (2026-03-21): Emax_ra was 0.12 < Emin_ra 0.20 in the
% original pre-op and default configs — this inverted the RA contraction,
% causing RA pressure to DROP during atrial kick instead of rising.
% The collapsed RA pressure gradient was the reason R_ASD sweeps had
% near-zero effect on Qp/Qs (gradient-limited, not resistance-limited).
% Fix: set Emax_ra > Emin_ra, consistent with LA and both ventricles.
params.Emax_ra = 0.25;    % [mmHg/mL]  RA peak (systolic) elastance  [Emax > Emin: FIXED]
params.Emin_ra = 0.12;    % [mmHg/mL]  RA diastolic elastance (RA dilated -> softer diastole)

% ── 3b. Vascular Parameters ────────────────────────────────────────────
% Pulmonary vascular resistance (PVR): kept at scaled baseline for now.
% In uncomplicated childhood ASD (no PAH), PVR is not significantly
% elevated. Mildly reduced R_pa can be considered in calibration if
% Qp/Qs is too low.
%
% NOTE: Systemic and pulmonary R/C parameters inherit from Section 1
% (pediatric_scaling). No additional overrides applied at this stage.


%% ══════════════════════════════════════════════════════════════════════
%% SECTION 4 — ASD SHUNT RESISTANCE (THE KEY PRE-OP SWITCH)
%% ══════════════════════════════════════════════════════════════════════
% PRE-OPERATIVE CONDITION: R_ASD is FINITE → shunt flow is ACTIVE.
%
% Q_shunt_asd = (P_la - P_ra) / R_ASD    [mL/s]
%   Positive Q_shunt_asd → left-to-right (LA→RA), the typical direction.
%
% R_ASD = 5.0 mmHg·s/mL is a physiologically plausible PLACEHOLDER.
%   - A larger defect (lower R_ASD) produces a larger Qp/Qs ratio.
%   - A smaller defect (higher R_ASD) produces a smaller Qp/Qs ratio.
%   - Typical haemodynamically significant ASDs → Qp/Qs ~ 1.5–2.5.
%   - Calibration will refine R_ASD to match the patient's measured Qp/Qs.
%
% ⚠ Do NOT set R_ASD = Inf here — that is the post-op condition.
% ⚠ Do NOT set R_ASD = 0 — that is a numerical short circuit.

% R_ASD physics: Q_shunt = (LAP - RAP) / R_ASD.
% With LAP-RAP ≈ 3-4 mmHg, to achieve Q_shunt ~35 mL/s (≈2.1 L/min)
% needed for Qp/Qs ~1.5–2.5, R_ASD must be ~0.10 mmHg·s/mL.
% This corresponds physically to a large ASD (secundum, ≥15 mm ostium).
% R_ASD = 1.0 modelled only a small defect (Q_shunt ~ 3 mL/s → Qp/Qs ~1.04).
% (2026-03-21 FIX: 1.0 → 0.10 to achieve haemodynamically significant shunt)
params.R_ASD = 0.10;    % [mmHg·s/mL]  large-defect ASD; PLACEHOLDER — calibrate in Step 2

%% ══════════════════════════════════════════════════════════════════════
%% SECTION 5 — INITIAL CONDITIONS
%% ══════════════════════════════════════════════════════════════════════
% Starting conditions are set near the expected pre-op steady state to
% reduce ODE warm-up time. Values reflect:
%   - RV volume overload (larger RV_EDV, smaller LV_EDV than post-op)
%   - Mildly elevated pulmonary artery pressure
%   - Elevated pulmonary flow (Qp > Qs due to active shunt)
%   - LA volume: modestly elevated from increased pulmonary venous return
%   - RA volume: elevated from receiving shunt flow
%
% These are ESTIMATES. The solver warm-up (params.n_warmup cycles) will
% drive the system to its true periodic attractor regardless of X0.

X0 = zeros(params.n_state, 1);
idx = params.idx;

% ── Cardiac chamber volumes ─────────────────────────────────────────────
X0(idx.V_lv) =  90.0;    % [mL]  LV EDV — slightly smaller than post-op
%                                 (pre-op LV may be normal or mildly reduced;
%                                  shunt reduces net systemic output)
X0(idx.V_rv) = 150.0;    % [mL]  RV EDV — larger than post-op (volume overload)
X0(idx.V_la) =  50.0;    % [mL]  LA — enlarged (excess pulm return from large shunt)
%                                 Increased from 40→50 mL to widen LAP-RAP gradient,
%                                 supporting adequate shunt driving pressure.
X0(idx.V_ra) =  55.0;    % [mL]  RA — enlarged (receives shunt flow)

% ── Vascular pressures ─────────────────────────────────────────────────
X0(idx.P_sa) =  85.0;    % [mmHg]  Systemic arterial — slightly lower (smaller
%                                    effective CO at rest, more HR compensation)
X0(idx.P_sc) =  20.0;    % [mmHg]  Systemic capillary
X0(idx.P_sv) =  10.0;    % [mmHg]  Systemic venous

X0(idx.P_pa) =  20.0;    % [mmHg]  Pulmonary artery — mildly elevated pre-op
%                                   (target range: 15–25 mmHg mean)
X0(idx.P_pc) =  10.0;    % [mmHg]  Pulmonary capillary — modestly elevated
X0(idx.P_pv) =   8.0;    % [mmHg]  Pulmonary venous

% ── Inertial flows ─────────────────────────────────────────────────────
% CO_systemic (Qs) estimated at ~3.8 L/min = 63 mL/s
%   (Lower than post-op due to shunting away from systemic side)
% CO_pulmonary (Qp) estimated at ~7.5 L/min = 125 mL/s
%   (Qp/Qs ~ 2.0 with R_ASD = 5.0; to be confirmed by simulation)
X0(idx.Q_sa) =  63.0;    % [mL/s]  Systemic arterial inertial flow
X0(idx.Q_sv) =  63.0;    % [mL/s]  Systemic venous inertial flow
X0(idx.Q_pa) = 125.0;    % [mL/s]  Pulmonary arterial inertial flow (Qp > Qs)
X0(idx.Q_pv) = 125.0;    % [mL/s]  Pulmonary venous inertial flow

end
