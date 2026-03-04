function Q_shunt_asd = asd_shunt_model(P_la, P_ra, params)
% ASD_SHUNT_MODEL
% -----------------------------------------------------------------------
% Computes the inter-atrial shunt flow through an atrial septal defect.
%
% Governing equation:
%   Q_shunt_asd = (P_la - P_ra) / R_ASD
%
% For post-ASD closure simulation:
%   R_ASD = Inf  →  Q_shunt_asd = 0  (no shunt flow)
%
% INPUTS:
%   P_la    - left atrial pressure                         [mmHg]
%   P_ra    - right atrial pressure                        [mmHg]
%   params  - parameter struct; must contain params.R_ASD  [mmHg·s/mL]
%
% OUTPUTS:
%   Q_shunt_asd - shunt flow rate                          [mL/s]
%
% ASSUMPTIONS:
%   - Linear (Ohmic) resistance model; valid for small defects
%   - Large-defect ASD may require Bernoulli-based model (not implemented)
%   - Both L-to-R and R-to-L shunts are represented by the sign of Q
%
% SIGN CONVENTIONS:
%   - Q_shunt_asd > 0 → left-to-right shunt (LA → RA)
%   - Q_shunt_asd < 0 → right-to-left shunt (RA → LA)
%   - Post-closure (R_ASD = Inf): Q_shunt_asd = 0 always
%
% REFERENCES:
%   [1] Valenti et al. (2023). Lumped-parameter ASD model. Eq.(shunt).
%   [2] Sanders SP et al. Clinical ASD haemodynamics review.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-02-25
% VERSION:  1.0
% -----------------------------------------------------------------------

R_ASD = params.R_ASD;    % ASD shunt resistance [mmHg·s/mL]; Inf = closed

if isinf(R_ASD)
    Q_shunt_asd = 0;     % Post-closure: no shunt flow [mL/s]
else
    DeltaP_la_ra    = P_la - P_ra;           % LA-to-RA pressure gradient [mmHg]
    Q_shunt_asd     = DeltaP_la_ra / R_ASD;  % Shunt flow [mL/s]
end

end
