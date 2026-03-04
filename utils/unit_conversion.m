function factors = unit_conversion()
% UNIT_CONVERSION
% -----------------------------------------------------------------------
% Returns a struct of named unit conversion factors used across the model.
% All conversions are performed ONLY in this file or in clearly marked
% reporting blocks — never silently inside physics functions.
%
% INPUTS:
%   (none)
%
% OUTPUTS:
%   factors - struct of named conversion factors (see fields below)
%
% USAGE EXAMPLE:
%   uc = unit_conversion();
%   CO_Lmin = Q_systemic_mLs * uc.mLs_to_Lmin;
%   R_wood  = R_mmHgs_mL     * uc.mmHgs_mL_to_Wood;
%
% ASSUMPTIONS:
%   - Conversions do not lose numerical precision at physiological scales
%
% REFERENCES:
%   [1] SI base units; standard clinical conversion factors.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

%% ── FLOW CONVERSIONS ───────────────────────────────────────────────────

factors.mLs_to_Lmin  = 60.0 / 1000.0;  % [L/min per mL/s]: 60 s/min ÷ 1000 mL/L
factors.Lmin_to_mLs  = 1000.0 / 60.0;  % [mL/s per L/min]

%% ── RESISTANCE CONVERSIONS ─────────────────────────────────────────────
% 1 Wood unit = 80 mmHg·s/mL (by definition, dyne·s·cm⁻⁵ to Wood)
% Source: standard clinical haemodynamics reference

factors.mmHgs_mL_to_Wood = 1.0 / 80.0;   % [Wood per mmHg·s/mL]
factors.Wood_to_mmHgs_mL = 80.0;          % [mmHg·s/mL per Wood unit]

%% ── PRESSURE CONVERSIONS ───────────────────────────────────────────────

factors.mmHg_to_Pa  = 133.322;    % [Pa per mmHg]   — exact NIST value
factors.Pa_to_mmHg  = 1.0 / 133.322;    % [mmHg per Pa]

%% ── EJECTION FRACTION CONVERSIONS ─────────────────────────────────────

factors.fraction_to_pct = 100.0;    % multiply EF_fraction to get EF_%
factors.pct_to_fraction = 0.01;     % divide EF_% to get EF_fraction

%% ── AREA / VOLUME CONVERSIONS ──────────────────────────────────────────

factors.mm2_to_m2 = 1.0e-6;    % [m² per mm²]
factors.m2_to_mm2 = 1.0e6;     % [mm² per m²]
factors.m3s_to_mLs = 1.0e6;    % [mL/s per m³/s]
factors.mLs_to_m3s = 1.0e-6;   % [m³/s per mL/s]

end
