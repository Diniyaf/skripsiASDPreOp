function audit = compute_blood_volume_audit(params, X0)
% COMPUTE_BLOOD_VOLUME_AUDIT
% -------------------------------------------------------------------------
% Calculates the blood-volume bookkeeping used by the current 0D model.
%
% The model stores params.V_blood as the reference total blood volume for
% scaling, while the ODE state contains chamber volumes plus stressed
% vascular volumes C*P. Vascular unstressed volumes are not explicit states.
% -------------------------------------------------------------------------

idx = params.idx;

chamber_volume = X0(idx.V_lv) + X0(idx.V_rv) + ...
    X0(idx.V_la) + X0(idx.V_ra);    % [mL]

vascular_stressed_volume = ...
    params.C_sa * X0(idx.P_sa) + ...
    params.C_sc * X0(idx.P_sc) + ...
    params.C_sv * X0(idx.P_sv) + ...
    params.C_pa * X0(idx.P_pa) + ...
    (params.C_pc + params.C_sh) * X0(idx.P_pc) + ...
    params.C_pv * X0(idx.P_pv);    % [mL]

chamber_unstressed_volume = params.V0_lv + params.V0_rv + ...
    params.V0_la + params.V0_ra;    % [mL]

audit.reference_total_blood_volume = params.V_blood;       % [mL]
audit.initial_chamber_volume = chamber_volume;              % [mL]
audit.initial_vascular_stressed_volume = vascular_stressed_volume; % [mL]
audit.initial_dynamic_volume = chamber_volume + vascular_stressed_volume; % [mL]
audit.chamber_unstressed_volume = chamber_unstressed_volume; % [mL]
audit.vascular_unstressed_volume_modeled = 0.0;             % [mL]
audit.implicit_volume_gap_to_reference = ...
    params.V_blood - audit.initial_dynamic_volume;           % [mL]

end
