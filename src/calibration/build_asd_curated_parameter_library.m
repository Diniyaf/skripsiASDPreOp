function library = build_asd_curated_parameter_library(candidate_report)
% BUILD_ASD_CURATED_PARAMETER_LIBRARY
% -----------------------------------------------------------------------
% Combine ASD Group A/B/C candidate tables into one curated GSA library.
%
% The candidate report is produced by asd_candidate_param_sets(). This
% helper makes the library reusable by GSA and calibration runners so the
% active set is not redefined ad hoc in scripts.
%
% INPUTS:
%   candidate_report - struct from asd_candidate_param_sets             [-]
%
% OUTPUTS:
%   library          - curated finite candidate parameter table          [-]
%
% ASSUMPTIONS:
%   - Group A/B/C membership is defined physiologically upstream.
%   - Finite positive nominal values and finite bounds are required for
%     automatic GSA sampling.
%
% REFERENCES:
%   [1] src/calibration/asd_candidate_param_sets.m
%   [2] Hafiz-Keisya unified VSD active-mask pattern.
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  1.0
% -----------------------------------------------------------------------

tables = {};
if isfield(candidate_report, 'groupA') && height(candidate_report.groupA) > 0
    tables{end + 1} = candidate_report.groupA;
end
if isfield(candidate_report, 'groupB') && height(candidate_report.groupB) > 0
    tables{end + 1} = candidate_report.groupB;
end
if isfield(candidate_report, 'groupC') && height(candidate_report.groupC) > 0
    tables{end + 1} = candidate_report.groupC;
end

if isempty(tables)
    error('build_asd_curated_parameter_library:noCandidates', ...
        'No ASD candidate parameter groups were available.');
end

library = vertcat(tables{:});

valid = isfinite(library.Initial_Value) & ...
    isfinite(library.Lower_Bound) & ...
    isfinite(library.Upper_Bound) & ...
    library.Initial_Value > 0 & ...
    library.Lower_Bound > 0 & ...
    library.Upper_Bound > library.Lower_Bound;

if ~all(valid)
    bad = library.Parameter(~valid);
    warning('build_asd_curated_parameter_library:excludingInvalidCandidates', ...
        'Excluding %d invalid ASD candidate(s): %s', ...
        sum(~valid), strjoin(cellstr(bad), ', '));
    library = library(valid, :);
end

include_gsa = true(height(library), 1);
default_calibration_role = strings(height(library), 1);

for row_idx = 1:height(library)
    group_name = string(library.Group(row_idx));
    if startsWith(group_name, "A_")
        default_calibration_role(row_idx) = "primary_candidate";
    elseif startsWith(group_name, "B_")
        default_calibration_role(row_idx) = "secondary_candidate_requires_GSA_support";
    elseif startsWith(group_name, "C_")
        default_calibration_role(row_idx) = "monitor_only_unless_explicitly_enabled";
    else
        default_calibration_role(row_idx) = "review_required";
    end
end

library.IncludeInCuratedGSA = include_gsa;
library.DefaultCalibrationRole = default_calibration_role;

end
