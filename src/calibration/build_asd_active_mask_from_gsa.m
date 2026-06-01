function [selection, optMask] = build_asd_active_mask_from_gsa(gsa_data, parameter_library, target_tiers, opts)
% BUILD_ASD_ACTIVE_MASK_FROM_GSA
% -----------------------------------------------------------------------
% Build an ASD calibration active mask from Sobol ST and target tiers.
%
% This mirrors the unified VSD pattern: GSA ranks the curated candidate
% library, target-tier governance determines which outputs are allowed to
% drive the mask, and calibration optimizes only the selected subset.
%
% INPUTS:
%   gsa_data          - MAT-loaded GSA struct with .sobol and .cfg       [-]
%   parameter_library - table from build_asd_curated_parameter_library   [-]
%   target_tiers      - table from build_asd_target_tiers                [-]
%   opts              - optional struct:
%                       .Threshold              default 0.10             [-]
%                       .MinActive              default 4                [-]
%                       .MaxActive              default 8                [-]
%                       .AllowGroupC            default from caseProfile [-]
%                       .UseSecondaryGuards     default true             [-]
%                       .CaseProfile            optional ASD profile     [-]
%
% OUTPUTS:
%   selection         - table with ST summaries and calibration status   [-]
%   optMask           - logical mask aligned to parameter_library rows   [-]
%
% ASSUMPTIONS:
%   - Group C ventricular parameters are monitored by default because
%     Patient Z pre-closure lacks ventricular volume/function targets.
%   - Group C can be explicitly enabled for exploratory calibration via
%     opts.AllowGroupC, but it is not selected automatically.
%
% REFERENCES:
%   [1] src/utils/create_optimization_mask.m
%   [2] src/calibration/build_asd_target_tiers.m
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  1.0
% -----------------------------------------------------------------------

if nargin < 4 || isempty(opts)
    opts = struct();
end

threshold = option_or_default(opts, 'Threshold', 0.10);
min_active = option_or_default(opts, 'MinActive', 4);
max_active = option_or_default(opts, 'MaxActive', 8);
allow_group_c = resolve_allow_group_c(opts);
use_secondary = logical(option_or_default(opts, 'UseSecondaryGuards', true));

names = cellstr(parameter_library.Parameter);
gsa_names = cellstr(gsa_data.sobol.Parameter);
metric_names = cellstr(gsa_data.sobol.Metric);

primary_rows = strcmp(target_tiers.Tier, 'hard_primary') & target_tiers.IncludeInGSA;
primary_metrics = unique(cellstr(target_tiers.ModelField(primary_rows)), 'stable');

if use_secondary
    screen_rows = target_tiers.IncludeInGSA & ...
        (strcmp(target_tiers.Tier, 'hard_primary') | startsWith(target_tiers.Tier, 'soft_secondary'));
else
    screen_rows = primary_rows;
end
screen_metrics = unique(cellstr(target_tiers.ModelField(screen_rows)), 'stable');

ST_primary = extract_st_matrix(gsa_data.sobol.ST, names, gsa_names, primary_metrics, metric_names);
ST_screen = extract_st_matrix(gsa_data.sobol.ST, names, gsa_names, screen_metrics, metric_names);

max_primary = max(ST_primary, [], 2, 'omitnan');
mean_primary = mean(ST_primary, 2, 'omitnan');
max_screen = max(ST_screen, [], 2, 'omitnan');
mean_screen = mean(ST_screen, 2, 'omitnan');

max_primary(~isfinite(max_primary)) = 0;
mean_primary(~isfinite(mean_primary)) = 0;
max_screen(~isfinite(max_screen)) = 0;
mean_screen(~isfinite(mean_screen)) = 0;

is_group_c = startsWith(string(parameter_library.Group), "C_");
eligible = ~is_group_c | allow_group_c;

raw_mask = create_optimization_mask(ST_screen, threshold, names, struct());
optMask = raw_mask & eligible;

if sum(optMask) < min_active
    score = max_screen;
    score(~eligible) = -Inf;
    [~, order] = sort(score, 'descend');
    for idx = reshape(order, 1, [])
        if ~isfinite(score(idx))
            continue;
        end
        optMask(idx) = true;
        if sum(optMask) >= min_active
            break;
        end
    end
end

if sum(optMask) > max_active
    score = max_screen;
    selected_idx = find(optMask);
    [~, local_order] = sort(score(selected_idx), 'descend');
    keep = selected_idx(local_order(1:max_active));
    optMask(:) = false;
    optMask(keep) = true;
end

status = strings(numel(names), 1);
rationale = strings(numel(names), 1);
sensitive_primary = strings(numel(names), 1);
sensitive_screen = strings(numel(names), 1);

for idx = 1:numel(names)
    sensitive_primary(idx) = sensitive_text(primary_metrics, ST_primary(idx, :), threshold);
    sensitive_screen(idx) = sensitive_text(screen_metrics, ST_screen(idx, :), threshold);

    if optMask(idx)
        if startsWith(string(parameter_library.Group(idx)), "A_")
            status(idx) = "select_stage_A";
        elseif startsWith(string(parameter_library.Group(idx)), "B_")
            status(idx) = "select_stage_B_preload";
        else
            status(idx) = "select_exploratory_group_C";
        end
        rationale(idx) = "Selected by Sobol ST threshold/top-score rule under ASD target-tier governance.";
    elseif is_group_c(idx) && ~allow_group_c && max_screen(idx) >= threshold
        status(idx) = "monitor_group_C_not_calibrated";
        rationale(idx) = "Sensitive, but ventricular Group C remains fixed by default because LV/RV volume and EF targets are missing.";
    elseif max_screen(idx) >= threshold
        status(idx) = "monitor_only_cap";
        rationale(idx) = "Sensitive, but not selected because active set is capped for identifiability.";
    else
        status(idx) = "not_selected";
        rationale(idx) = "Below ST threshold for the selected ASD target-tier metrics.";
    end
end

selection = table( ...
    string(names(:)), string(parameter_library.Group), string(parameter_library.DefaultCalibrationRole), ...
    mean_primary, max_primary, mean_screen, max_screen, sensitive_primary, ...
    sensitive_screen, optMask(:), status, rationale, ...
    'VariableNames', {'Parameter','Group','DefaultCalibrationRole', ...
    'Mean_ST_Primary','Max_ST_Primary','Mean_ST_PrimarySecondary', ...
    'Max_ST_PrimarySecondary','Sensitive_Primary_Targets', ...
    'Sensitive_PrimarySecondary_Targets','Mask_Selected', ...
    'Suggested_Status','Rationale'});

selection = sortrows(selection, {'Mask_Selected','Max_ST_PrimarySecondary'}, {'descend','descend'});

end

function allow_group_c = resolve_allow_group_c(opts)
% RESOLVE_ALLOW_GROUP_C - profile-aware Group C default.
if isfield(opts, 'AllowGroupC') && ~isempty(opts.AllowGroupC)
    allow_group_c = logical(opts.AllowGroupC);
    return;
end
allow_group_c = false;
if isfield(opts, 'CaseProfile') && isstruct(opts.CaseProfile) && ...
        isfield(opts.CaseProfile, 'allowedCandidateGroups') && ...
        isfield(opts.CaseProfile.allowedCandidateGroups, 'GroupCCalibrationAllowedByDefault')
    allow_group_c = logical(opts.CaseProfile.allowedCandidateGroups.GroupCCalibrationAllowedByDefault);
end
end

function value = option_or_default(opts, name, default_value)
% OPTION_OR_DEFAULT - read option field with fallback.
value = default_value;
if isstruct(opts) && isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
end
end

function ST_out = extract_st_matrix(ST, names, gsa_names, selected_metrics, metric_names)
% EXTRACT_ST_MATRIX - map GSA ST values to library parameters and metrics.
ST_out = zeros(numel(names), numel(selected_metrics));
for row_idx = 1:numel(names)
    gsa_param_idx = find(strcmp(gsa_names, names{row_idx}), 1);
    if isempty(gsa_param_idx)
        continue;
    end
    for metric_idx = 1:numel(selected_metrics)
        gsa_metric_idx = find(strcmp(metric_names, selected_metrics{metric_idx}), 1);
        if isempty(gsa_metric_idx)
            continue;
        end
        ST_out(row_idx, metric_idx) = ST(gsa_param_idx, gsa_metric_idx);
    end
end
ST_out(~isfinite(ST_out)) = 0;
ST_out(ST_out < 0) = 0;
end

function text = sensitive_text(metrics, values, threshold)
% SENSITIVE_TEXT - summarize metrics above threshold.
if isempty(metrics)
    text = "none";
    return;
end
mask = values >= threshold;
if ~any(mask)
    text = "none >= threshold";
    return;
end
labels = cell(1, sum(mask));
hit_idx = find(mask);
for idx = 1:numel(hit_idx)
    k = hit_idx(idx);
    labels{idx} = sprintf('%s=%.3f', metrics{k}, values(k));
end
text = string(strjoin(labels, '; '));
end
