function [validation_table, summary] = compare_valenti_adult_targets(metrics, target_set)
% COMPARE_VALENTI_ADULT_TARGETS
% -------------------------------------------------------------------------
% Compares simulated adult ASD metrics against Valenti Table 4.4 targets.
%
% INPUT:
%   metrics    - struct from compute_valenti_adult_metrics()
%   target_set - 'clinical' or 'model_output'
%
% OUTPUTS:
%   validation_table - Excel-ready table with target, simulated value, error
%   summary          - struct with RMSE and mean absolute percentage error
% -------------------------------------------------------------------------

if nargin < 2 || isempty(target_set)
    target_set = 'clinical';
end

targets = valenti_adult_asd_targets(target_set);
n_metrics = height(targets);

simulated_value = zeros(n_metrics, 1);
for k_metric = 1:n_metrics
    metric_name = targets.metric_name{k_metric};
    if ~isfield(metrics, metric_name)
        error('compare_valenti_adult_targets:MissingMetric', ...
            'Metric "%s" was not computed.', metric_name);
    end
    simulated_value(k_metric) = metrics.(metric_name);
end

target_value = targets.target_value;
error_absolute = simulated_value - target_value;
error_percent = (error_absolute ./ target_value) * 100.0;    % [%]

validation_table = table( ...
    targets.metric_name, target_value, simulated_value, error_absolute, ...
    error_percent, targets.unit, targets.source, targets.description, ...
    'VariableNames', {'metric_name', 'target_value', 'simulated_value', ...
    'error_absolute', 'error_percent', 'unit', 'source', 'description'});

summary.rmse_percent = sqrt(mean(error_percent .^ 2));        % [%]
summary.mape_percent = mean(abs(error_percent));              % [%]
summary.max_abs_error_percent = max(abs(error_percent));      % [%]
summary.n_metrics = n_metrics;                               % [dimensionless]
summary.target_set = target_set;

end
