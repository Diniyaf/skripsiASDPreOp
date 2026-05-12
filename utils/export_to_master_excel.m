function manifest = export_to_master_excel(payload)
% EXPORT_TO_MASTER_EXCEL
% -------------------------------------------------------------------------
% Appends simulation, validation, GSA, and optimization summaries to one
% master Excel workbook, while saving timestamped run backups.
%
% This utility is intentionally documentation-facing: it does not change
% model equations, solver behavior, or physiological assumptions.
%
% INPUT
%   payload - struct with optional fields:
%       .scenario              e.g., 'Pre-Op ASD'
%       .stage                 e.g., 'baseline_simulation', 'gsa'
%       .run_id                unique run identifier; auto-generated if empty
%       .description           short run description
%       .status                e.g., 'complete', 'draft', 'failed'
%       .master_file           optional master workbook path
%       .run_root              optional run-backup root folder
%
%     Data fields may be MATLAB tables or structs:
%       .clinical_input
%       .baseline_parameters   or .params
%       .parameter_override
%       .simulation_output     or .indices
%       .validation_error
%       .gsa_result
%       .selected_parameters
%       .optimization_result
%       .before_after_compare
%       .method_notes
%
% OUTPUT
%   manifest - struct with run_id, workbook path, run folder, updated sheets,
%              CSV backup paths, and technical backup paths.
%
% EXAMPLE
%   payload.scenario = 'Pre-Op ASD';
%   payload.stage = 'baseline_simulation';
%   payload.description = 'Adult Valenti parameter verification';
%   payload.params = params;
%   payload.indices = indices;
%   manifest = export_to_master_excel(payload);
%
% MASTER WORKBOOK
%   Default path:
%       results/master/ASD_Pre_Model_Master.xlsx
%
% BACKUP FOLDER
%   Default path:
%       results/runs/<run_id>_<timestamp>/
%
% NOTES
%   - Sheets are created automatically with fixed headers if absent.
%   - Existing rows are preserved; new rows are appended.
%   - Complex values are serialized into traceable text in details_json.
%   - Numeric scalar cells remain numeric where MATLAB supports it.
%
% AUTHOR:   Cardiovascular Simulation Team
% DATE:     2026-05-09
% VERSION:  1.0
% -------------------------------------------------------------------------

if nargin < 1 || isempty(payload)
    error('export_to_master_excel:MissingPayload', ...
        'Provide a payload struct with run metadata and result tables/structs.');
end

if ~isstruct(payload)
    error('export_to_master_excel:InvalidPayload', ...
        'payload must be a MATLAB struct.');
end

project_root = fileparts(fileparts(mfilename('fullpath')));

default_master_dir  = fullfile(project_root, 'results', 'master');
default_master_name = 'ASD_Pre_Model_Master.xlsx';
default_run_root    = fullfile(project_root, 'results', 'runs');

timestamp_text_format = 'yyyy-MM-dd HH:mm:ss';       % Local timestamp for Excel
timestamp_file_format = 'yyyyMMdd_HHmmss';           % Filesystem-safe timestamp
[timestamp_text, timestamp_tag] = current_timestamp(timestamp_text_format, ...
    timestamp_file_format);

scenario    = get_payload_text(payload, 'scenario', 'unspecified');
stage       = get_payload_text(payload, 'stage', ...
    get_payload_text(payload, 'result_type', 'simulation'));
description = get_payload_text(payload, 'description', '');
status      = get_payload_text(payload, 'status', 'complete');

if isfield(payload, 'run_id') && ~isempty(payload.run_id)
    run_id = to_text(payload.run_id);
else
    run_id = sprintf('%s_%s_%s', safe_token(stage), safe_token(scenario), ...
        timestamp_tag);
end

if isfield(payload, 'master_file') && ~isempty(payload.master_file)
    master_file = resolve_project_path(project_root, to_text(payload.master_file));
else
    master_file = fullfile(default_master_dir, default_master_name);
end

if isfield(payload, 'run_root') && ~isempty(payload.run_root)
    run_root = resolve_project_path(project_root, to_text(payload.run_root));
else
    run_root = default_run_root;
end

safe_run_id = safe_token(run_id);
run_folder  = fullfile(run_root, sprintf('%s_%s', safe_run_id, timestamp_tag));
csv_folder  = fullfile(run_folder, 'csv');
json_file   = fullfile(run_folder, 'run_manifest.json');
mat_file    = fullfile(run_folder, 'run_payload.mat');

ensure_folder(fileparts(master_file));
ensure_folder(run_folder);
ensure_folder(csv_folder);

schema = master_schema();
ensure_master_workbook(master_file, schema);
ensure_data_dictionary(master_file, schema);

meta.run_id      = run_id;
meta.timestamp   = timestamp_text;
meta.scenario    = scenario;
meta.stage       = stage;
meta.description = description;
meta.status      = status;

run_tables = struct();
run_tables.run_log = build_run_log_table(meta, master_file, run_folder, ...
    mat_file, json_file, csv_folder);

data_keys = { ...
    'clinical_input', ...
    'baseline_parameters', ...
    'parameter_override', ...
    'simulation_output', ...
    'validation_error', ...
    'valenti_adult_validation', ...
    'gsa_result', ...
    'selected_parameters', ...
    'optimization_result', ...
    'before_after_compare', ...
    'method_notes'};

for k_key = 1:numel(data_keys)
    key = data_keys{k_key};
    [has_value, raw_value] = get_payload_data(payload, key);
    if has_value
        sheet_schema = find_schema(schema, key);
        T_payload = normalize_payload_table(raw_value, sheet_schema, meta);
        if height(T_payload) > 0
            run_tables.(key) = T_payload;
        end
    end
end

manifest = struct();
manifest.run_id         = run_id;
manifest.timestamp      = timestamp_text;
manifest.scenario       = scenario;
manifest.stage          = stage;
manifest.master_file    = master_file;
manifest.run_folder     = run_folder;
manifest.csv_folder     = csv_folder;
manifest.json_file      = json_file;
manifest.mat_file       = mat_file;
manifest.sheets_updated = {};
manifest.row_counts     = struct();
manifest.csv_files      = struct();

table_keys = fieldnames(run_tables);
for k_table = 1:numel(table_keys)
    key = table_keys{k_table};
    sheet_schema = find_schema(schema, key);
    T_export = run_tables.(key);

    append_table_to_sheet(master_file, sheet_schema.sheet, ...
        sheet_schema.headers, T_export);

    csv_file = fullfile(csv_folder, [sheet_schema.sheet '.csv']);
    writetable(T_export, csv_file);

    manifest.sheets_updated{end + 1, 1} = sheet_schema.sheet;
    manifest.row_counts.(key) = height(T_export);
    manifest.csv_files.(key) = csv_file;
end

write_json_file(json_file, manifest);
save(mat_file, 'payload', 'run_tables', 'manifest');

fprintf('\n=== MASTER EXCEL EXPORT COMPLETE ===\n');
fprintf('  run_id      : %s\n', run_id);
fprintf('  master file : %s\n', master_file);
fprintf('  run folder  : %s\n', run_folder);
fprintf('  sheets      : %s\n', strjoin(manifest.sheets_updated.', ', '));

end

% -------------------------------------------------------------------------
% Schema and workbook setup
% -------------------------------------------------------------------------
function schema = master_schema()

schema = struct('key', {}, 'sheet', {}, 'headers', {}, ...
    'name_col', {}, 'value_col', {});

schema(end + 1) = make_schema('run_log', '00_Run_Log', { ...
    'run_id', 'timestamp', 'stage', 'scenario', 'status', 'description', ...
    'master_file', 'run_folder', 'mat_file', 'json_file', 'csv_folder', ...
    'details_json'}, '', '');

schema(end + 1) = make_schema('clinical_input', '01_Clinical_Input', { ...
    'run_id', 'timestamp', 'scenario', 'variable_name', 'value', 'unit', ...
    'description', 'source', 'details_json'}, 'variable_name', 'value');

schema(end + 1) = make_schema('baseline_parameters', ...
    '02_Baseline_Parameters', { ...
    'run_id', 'timestamp', 'scenario', 'parameter_name', 'value', 'unit', ...
    'description', 'source', 'details_json'}, 'parameter_name', 'value');

schema(end + 1) = make_schema('parameter_override', ...
    '03_Parameter_Override', { ...
    'run_id', 'timestamp', 'scenario', 'parameter_name', 'baseline_value', ...
    'override_value', 'unit', 'percent_change', 'description', 'source', ...
    'details_json'}, 'parameter_name', 'override_value');

schema(end + 1) = make_schema('simulation_output', ...
    '04_Simulation_Output', { ...
    'run_id', 'timestamp', 'scenario', 'metric_name', 'value', 'unit', ...
    'description', 'source', 'details_json'}, 'metric_name', 'value');

schema(end + 1) = make_schema('validation_error', ...
    '05_Validation_Error', { ...
    'run_id', 'timestamp', 'scenario', 'metric_name', 'target_value', ...
    'simulated_value', 'error_absolute', 'error_percent', 'unit', ...
    'description', 'source', 'details_json'}, 'metric_name', ...
    'simulated_value');

schema(end + 1) = make_schema('valenti_adult_validation', ...
    'Valenti_Adult_Validation', { ...
    'run_id', 'timestamp', 'scenario', 'metric_name', 'target_value', ...
    'simulated_value', 'error_absolute', 'error_percent', 'unit', ...
    'source', 'description', 'details_json'}, 'metric_name', ...
    'simulated_value');

schema(end + 1) = make_schema('gsa_result', '06_GSA_Result', { ...
    'run_id', 'timestamp', 'scenario', 'parameter_name', 'output_name', ...
    'sensitivity_index', 'index_value', 'rank', 'unit', 'description', ...
    'source', 'details_json'}, 'parameter_name', 'index_value');

schema(end + 1) = make_schema('selected_parameters', ...
    '07_Selected_Parameters', { ...
    'run_id', 'timestamp', 'scenario', 'parameter_name', 'selection_rank', ...
    'selection_reason', 'initial_value', 'lower_bound', 'upper_bound', ...
    'unit', 'description', 'source', 'details_json'}, 'parameter_name', ...
    'initial_value');

schema(end + 1) = make_schema('optimization_result', ...
    '08_Optimization_Result', { ...
    'run_id', 'timestamp', 'scenario', 'parameter_name', 'initial_value', ...
    'lower_bound', 'upper_bound', 'final_value', 'percent_change', ...
    'objective_name', 'objective_before', 'objective_after', ...
    'error_before', 'error_after', 'unit', 'description', 'source', ...
    'details_json'}, 'parameter_name', 'final_value');

schema(end + 1) = make_schema('before_after_compare', ...
    '09_Before_After_Compare', { ...
    'run_id', 'timestamp', 'scenario', 'metric_name', 'before_value', ...
    'after_value', 'target_value', 'error_before', 'error_after', 'unit', ...
    'description', 'source', 'details_json'}, 'metric_name', ...
    'after_value');

schema(end + 1) = make_schema('method_notes', '10_Method_Notes', { ...
    'run_id', 'timestamp', 'scenario', 'stage', 'note_type', 'note_text', ...
    'reference', 'details_json'}, '', '');

schema(end + 1) = make_schema('data_dictionary', '11_Data_Dictionary', { ...
    'sheet_name', 'column_name', 'unit', 'description'}, '', '');

end

function s = make_schema(key, sheet, headers, name_col, value_col)
s.key = key;
s.sheet = sheet;
s.headers = headers;
s.name_col = name_col;
s.value_col = value_col;
end

function ensure_master_workbook(master_file, schema)
for k_schema = 1:numel(schema)
    ensure_sheet(master_file, schema(k_schema).sheet, schema(k_schema).headers);
end
end

function ensure_sheet(master_file, sheet_name, headers)
if ~isfile(master_file) || ~sheet_exists(master_file, sheet_name)
    writecell(headers, master_file, 'Sheet', sheet_name, 'Range', 'A1');
    return;
end

existing_headers = read_sheet_headers(master_file, sheet_name, numel(headers));
if isempty(existing_headers)
    writecell(headers, master_file, 'Sheet', sheet_name, 'Range', 'A1');
    return;
end

if ~isequal(existing_headers, headers)
    error('export_to_master_excel:HeaderMismatch', ...
        ['Sheet "%s" already exists but its headers differ from the ', ...
        'expected master schema. To prevent misaligned append rows, ', ...
        'restore the expected headers or export to a new master file.'], ...
        sheet_name);
end
end

function ensure_data_dictionary(master_file, schema)
dictionary_schema = find_schema(schema, 'data_dictionary');
row_count = sheet_row_count(master_file, dictionary_schema.sheet);
header_only_row_count = 1;    % Header row only

if row_count > header_only_row_count
    return;
end

T_dictionary = build_data_dictionary(schema);
append_table_to_sheet(master_file, dictionary_schema.sheet, ...
    dictionary_schema.headers, T_dictionary);
end

function T = build_data_dictionary(schema)
rows = {};
for k_schema = 1:numel(schema)
    sheet_name = schema(k_schema).sheet;
    headers = schema(k_schema).headers;
    for k_header = 1:numel(headers)
        col_name = headers{k_header};
        rows(end + 1, :) = {sheet_name, col_name, ...
            column_unit(col_name), column_description(col_name)}; %#ok<AGROW>
    end
end

T = cell2table(rows, 'VariableNames', ...
    {'sheet_name', 'column_name', 'unit', 'description'});
end

% -------------------------------------------------------------------------
% Payload normalization
% -------------------------------------------------------------------------
function [has_value, value] = get_payload_data(payload, key)
aliases = field_aliases(key);
has_value = false;
value = [];

for k_alias = 1:numel(aliases)
    alias = aliases{k_alias};
    if isfield(payload, alias) && ~isempty(payload.(alias))
        has_value = true;
        value = payload.(alias);
        return;
    end
end
end

function aliases = field_aliases(key)
switch key
    case 'baseline_parameters'
        aliases = {'baseline_parameters', 'params'};
    case 'simulation_output'
        aliases = {'simulation_output', 'indices'};
    otherwise
        aliases = {key};
end
end

function T_out = normalize_payload_table(raw_value, sheet_schema, meta)
if isempty(raw_value)
    T_out = empty_aligned_table(sheet_schema.headers);
    return;
end

if strcmp(sheet_schema.key, 'method_notes')
    T_raw = method_notes_to_table(raw_value, meta);
elseif istable(raw_value)
    T_raw = raw_value;
elseif isstruct(raw_value)
    T_raw = struct_to_sheet_table(raw_value, sheet_schema);
else
    error('export_to_master_excel:UnsupportedPayloadValue', ...
        'Payload field for sheet "%s" must be a table or struct.', ...
        sheet_schema.sheet);
end

T_raw = add_standard_metadata(T_raw, sheet_schema, meta);
T_out = align_table_to_headers(T_raw, sheet_schema.headers);
T_out = compute_derived_columns(T_out, sheet_schema.key);
end

function T = struct_to_sheet_table(S, sheet_schema)
[names, values] = flatten_struct(S, '');
name_col = sheet_schema.name_col;
value_col = sheet_schema.value_col;

if isempty(name_col) || isempty(value_col)
    T = table();
    return;
end

row_count = numel(names);
rows = cell(row_count, 5);
for k_row = 1:row_count
    field_name = names{k_row};
    rows{k_row, 1} = field_name;
    rows{k_row, 2} = normalize_scalar(values{k_row});
    rows{k_row, 3} = lookup_unit(field_name);
    rows{k_row, 4} = lookup_description(field_name);
    rows{k_row, 5} = 'payload struct';
end

T = cell2table(rows, 'VariableNames', ...
    {name_col, value_col, 'unit', 'description', 'source'});
end

function T = method_notes_to_table(raw_value, meta)
if istable(raw_value)
    T = raw_value;
    return;
end

if isstruct(raw_value)
    T = struct_to_table_rows(raw_value);
    return;
end

if ischar(raw_value) || isstring(raw_value)
    notes = cellstr(raw_value);
elseif iscell(raw_value)
    notes = raw_value(:);
else
    error('export_to_master_excel:UnsupportedMethodNotes', ...
        'method_notes must be text, a cell array, struct, or table.');
end

row_count = numel(notes);
rows = cell(row_count, 4);
for k_row = 1:row_count
    rows{k_row, 1} = meta.stage;
    rows{k_row, 2} = 'method';
    rows{k_row, 3} = to_text(notes{k_row});
    rows{k_row, 4} = '';
end

T = cell2table(rows, 'VariableNames', ...
    {'stage', 'note_type', 'note_text', 'reference'});
end

function T = struct_to_table_rows(S)
field_names = fieldnames(S);
if isempty(field_names)
    T = table();
    return;
end

row_count = numel(field_names);
rows = cell(row_count, 4);
for k_row = 1:row_count
    name = field_names{k_row};
    rows{k_row, 1} = '';
    rows{k_row, 2} = name;
    rows{k_row, 3} = normalize_scalar(S.(name));
    rows{k_row, 4} = '';
end

T = cell2table(rows, 'VariableNames', ...
    {'stage', 'note_type', 'note_text', 'reference'});
end

function T = add_standard_metadata(T, sheet_schema, meta)
row_count = height(T);

if row_count == 0
    return;
end

if any(strcmp(sheet_schema.headers, 'run_id')) && ~ismember('run_id', T.Properties.VariableNames)
    T.run_id = repmat({meta.run_id}, row_count, 1);
end

if any(strcmp(sheet_schema.headers, 'timestamp')) && ~ismember('timestamp', T.Properties.VariableNames)
    T.timestamp = repmat({meta.timestamp}, row_count, 1);
end

if any(strcmp(sheet_schema.headers, 'scenario')) && ~ismember('scenario', T.Properties.VariableNames)
    T.scenario = repmat({meta.scenario}, row_count, 1);
end

if any(strcmp(sheet_schema.headers, 'stage')) && ~ismember('stage', T.Properties.VariableNames)
    T.stage = repmat({meta.stage}, row_count, 1);
end

if any(strcmp(sheet_schema.headers, 'source')) && ~ismember('source', T.Properties.VariableNames)
    T.source = repmat({''}, row_count, 1);
end

if any(strcmp(sheet_schema.headers, 'description')) && ~ismember('description', T.Properties.VariableNames)
    T.description = repmat({''}, row_count, 1);
end
end

function T_out = align_table_to_headers(T_in, headers)
row_count = height(T_in);
T_out = empty_aligned_table(headers, row_count);
input_vars = T_in.Properties.VariableNames;
extra_vars = setdiff(input_vars, headers, 'stable');

for k_header = 1:numel(headers)
    header = headers{k_header};
    if ismember(header, input_vars)
        for k_row = 1:row_count
            T_out.(header){k_row} = normalize_scalar(get_table_value(T_in, ...
                header, k_row));
        end
    else
        for k_row = 1:row_count
            T_out.(header){k_row} = '';
        end
    end
end

if ismember('details_json', headers)
    for k_row = 1:row_count
        detail_struct = struct();
        for k_extra = 1:numel(extra_vars)
            extra_name = extra_vars{k_extra};
            detail_struct.(extra_name) = normalize_scalar(get_table_value(T_in, ...
                extra_name, k_row));
        end
        if ~isempty(extra_vars)
            T_out.details_json{k_row} = jsonencode_safe(detail_struct);
        end
    end
end
end

function T_out = compute_derived_columns(T_out, key)
fraction_to_percent = 100.0;    % [% per fraction]

switch key
    case 'parameter_override'
        if has_headers(T_out, {'baseline_value', 'override_value', 'percent_change'})
            T_out = fill_percent_change(T_out, 'baseline_value', ...
                'override_value', 'percent_change', fraction_to_percent);
        end
    case 'optimization_result'
        if has_headers(T_out, {'initial_value', 'final_value', 'percent_change'})
            T_out = fill_percent_change(T_out, 'initial_value', ...
                'final_value', 'percent_change', fraction_to_percent);
        end
    case 'validation_error'
        if has_headers(T_out, {'target_value', 'simulated_value', ...
                'error_absolute', 'error_percent'})
            T_out = fill_validation_error(T_out, fraction_to_percent);
        end
    case 'valenti_adult_validation'
        if has_headers(T_out, {'target_value', 'simulated_value', ...
                'error_absolute', 'error_percent'})
            T_out = fill_validation_error(T_out, fraction_to_percent);
        end
end
end

function T = fill_percent_change(T, baseline_col, final_col, output_col, ...
    fraction_to_percent)
for k_row = 1:height(T)
    if ~is_blank_cell(T.(output_col){k_row})
        continue;
    end

    baseline_value = to_numeric_scalar(T.(baseline_col){k_row});
    final_value    = to_numeric_scalar(T.(final_col){k_row});

    if isfinite(baseline_value) && isfinite(final_value) && baseline_value ~= 0
        T.(output_col){k_row} = ((final_value - baseline_value) ...
            / baseline_value) * fraction_to_percent;
    end
end
end

function T = fill_validation_error(T, fraction_to_percent)
for k_row = 1:height(T)
    target_value    = to_numeric_scalar(T.target_value{k_row});
    simulated_value = to_numeric_scalar(T.simulated_value{k_row});

    if ~(isfinite(target_value) && isfinite(simulated_value))
        continue;
    end

    error_absolute = simulated_value - target_value;
    if is_blank_cell(T.error_absolute{k_row})
        T.error_absolute{k_row} = error_absolute;
    end

    if is_blank_cell(T.error_percent{k_row}) && target_value ~= 0
        T.error_percent{k_row} = (error_absolute / target_value) ...
            * fraction_to_percent;
    end
end
end

function T = empty_aligned_table(headers, row_count)
if nargin < 2
    row_count = 0;
end

cells = cell(row_count, numel(headers));
T = cell2table(cells, 'VariableNames', headers);
end

% -------------------------------------------------------------------------
% Append and backup
% -------------------------------------------------------------------------
function append_table_to_sheet(master_file, sheet_name, headers, T)
if isempty(T) || height(T) == 0
    return;
end

T = align_table_to_headers(T, headers);

try
    writetable(T, master_file, 'Sheet', sheet_name, 'WriteMode', 'append', ...
        'WriteVariableNames', false);
catch
    next_row = sheet_row_count(master_file, sheet_name) + 1;
    range_start = sprintf('A%d', next_row);
    writecell(table_to_cell_matrix(T), master_file, 'Sheet', sheet_name, ...
        'Range', range_start);
end
end

function C = table_to_cell_matrix(T)
C = table2cell(T);
for k_cell = 1:numel(C)
    C{k_cell} = normalize_scalar(C{k_cell});
end
end

function T = build_run_log_table(meta, master_file, run_folder, mat_file, ...
    json_file, csv_folder)
rows = { ...
    meta.run_id, meta.timestamp, meta.stage, meta.scenario, meta.status, ...
    meta.description, master_file, run_folder, mat_file, json_file, ...
    csv_folder, ''};

T = cell2table(rows, 'VariableNames', { ...
    'run_id', 'timestamp', 'stage', 'scenario', 'status', 'description', ...
    'master_file', 'run_folder', 'mat_file', 'json_file', 'csv_folder', ...
    'details_json'});
end

% -------------------------------------------------------------------------
% Struct flattening and value conversion
% -------------------------------------------------------------------------
function [names, values] = flatten_struct(S, prefix)
names = {};
values = {};
field_names = fieldnames(S);

for k_field = 1:numel(field_names)
    field_name = field_names{k_field};
    value = S.(field_name);

    if isempty(prefix)
        full_name = field_name;
    else
        full_name = [prefix '.' field_name];
    end

    if isstruct(value) && isscalar(value)
        [child_names, child_values] = flatten_struct(value, full_name);
        names = [names; child_names]; %#ok<AGROW>
        values = [values; child_values]; %#ok<AGROW>
    else
        names{end + 1, 1} = full_name; %#ok<AGROW>
        values{end + 1, 1} = value; %#ok<AGROW>
    end
end
end

function value = normalize_scalar(value)
if iscell(value)
    if isempty(value)
        value = '';
        return;
    elseif numel(value) == 1
        value = normalize_scalar(value{1});
        return;
    else
        value = jsonencode_safe(value);
        return;
    end
end

if ischar(value)
    return;
end

if isstring(value)
    if isscalar(value)
        value = char(value);
    else
        value = strjoin(cellstr(value(:).'), '; ');
    end
    return;
end

if isnumeric(value) || islogical(value)
    if isempty(value)
        value = '';
    elseif isscalar(value)
        % Keep numeric and logical scalars Excel-friendly.
    else
        value = mat2str(value);
    end
    return;
end

if isa(value, 'datetime') || isa(value, 'duration') || isa(value, 'categorical')
    value = char(value);
    return;
end

value = jsonencode_safe(value);
end

function value = get_table_value(T, var_name, row_idx)
column = T.(var_name);
if iscell(column)
    value = column{row_idx};
elseif isstring(column) || iscategorical(column)
    value = column(row_idx);
else
    value = column(row_idx, :);
end
end

function value = to_numeric_scalar(value)
value = normalize_scalar(value);
if isnumeric(value) && isscalar(value)
    return;
end

if islogical(value) && isscalar(value)
    value = double(value);
    return;
end

if ischar(value)
    value = str2double(value);
    return;
end

value = NaN;
end

function tf = is_blank_cell(value)
if isempty(value)
    tf = true;
elseif ischar(value)
    tf = isempty(strtrim(value));
elseif isstring(value)
    tf = strlength(value) == 0;
else
    tf = false;
end
end

function text = to_text(value)
value = normalize_scalar(value);
if ischar(value)
    text = value;
elseif isnumeric(value) || islogical(value)
    text = num2str(value);
else
    text = jsonencode_safe(value);
end
end

function text = get_payload_text(payload, field_name, default_text)
if isfield(payload, field_name) && ~isempty(payload.(field_name))
    text = to_text(payload.(field_name));
else
    text = default_text;
end
end

function text = jsonencode_safe(value)
try
    text = jsonencode(value);
catch
    text = evalc('disp(value)');
    text = strtrim(text);
end
end

% -------------------------------------------------------------------------
% Units and descriptions
% -------------------------------------------------------------------------
function unit = lookup_unit(field_name)
field_key = lower(field_name);
if starts_with(field_key, 'idx.')
    unit = 'state index';
    return;
end

name = lower(last_token(field_name));

switch name
    case {'height_cm', 'l_aorta'}
        unit = 'cm';
    case {'weight_kg'}
        unit = 'kg';
    case {'bsa'}
        unit = 'm^2';
    case {'age_years'}
        unit = 'years';
    case {'r_aorta', 'h_aorta'}
        unit = 'mm';
    case {'n_capillary', 'n_state', 'n_cycles', 'n_warmup'}
        unit = 'dimensionless';
    case {'t_cardiac', 't_on_lv', 't_sys_lv', 't_rel_lv', ...
            't_on_rv', 't_sys_rv', 't_rel_rv', 't_on_la', ...
            't_sys_la', 't_rel_la', 't_on_ra', 't_sys_ra', 't_rel_ra'}
        unit = 's';
    case {'hr'}
        unit = 'bpm';
    case {'v_blood', 'v_lv_ed', 'v_lv_es', 'sv_lv', 'v_rv_ed', ...
            'v_rv_es', 'sv_rv'}
        unit = 'mL';
    case {'ef_lv', 'ef_rv'}
        unit = 'fraction';
    case {'co_systemic', 'q_systemic', 'q_pulmonary'}
        unit = 'L/min';
    case {'p_ao_mean', 'p_ao_sys', 'p_ao_dia', 'p_pa_mean', ...
            'p_pa_sys', 'p_pa_dia', 'rap', 'lap', 'lap_mean', ...
            'rap_mean', 'lap_minus_rap', 'dp_mean', 'dp_peak', 'dp_min'}
        unit = 'mmHg';
    case {'q_ratio'}
        unit = 'dimensionless';
    case {'svr', 'pvr'}
        unit = 'mmHg*s/mL';
    case {'q_shunt_mean', 'q_shunt_peak', 'q_shunt_min'}
        unit = 'mL/s';
    otherwise
        unit = pattern_unit(name);
end
end

function unit = pattern_unit(name)
if starts_with(name, 'emax_') || starts_with(name, 'emin_')
    unit = 'mmHg/mL';
elseif starts_with(name, 'v0_')
    unit = 'mL';
elseif starts_with(name, 'r_')
    unit = 'mmHg*s/mL';
elseif starts_with(name, 'c_')
    unit = 'mL/mmHg';
elseif starts_with(name, 'l_')
    unit = 'mmHg*s^2/mL';
elseif starts_with(name, 'p_')
    unit = 'mmHg';
elseif starts_with(name, 'v_')
    unit = 'mL';
elseif starts_with(name, 'q_')
    unit = 'mL/s';
elseif starts_with(name, 'idx.')
    unit = 'state index';
else
    unit = 'not specified by caller';
end
end

function description = lookup_description(field_name)
field_key = lower(field_name);
if starts_with(field_key, 'idx.')
    description = sprintf('State vector index for "%s".', field_name);
    return;
end

name = lower(last_token(field_name));

switch name
    case 'v_lv_ed'
        description = 'Left ventricular end-diastolic volume.';
    case 'v_lv_es'
        description = 'Left ventricular end-systolic volume.';
    case 'sv_lv'
        description = 'Left ventricular stroke volume.';
    case 'ef_lv'
        description = 'Left ventricular ejection fraction stored as fraction.';
    case 'v_rv_ed'
        description = 'Right ventricular end-diastolic volume.';
    case 'v_rv_es'
        description = 'Right ventricular end-systolic volume.';
    case 'sv_rv'
        description = 'Right ventricular stroke volume.';
    case 'ef_rv'
        description = 'Right ventricular ejection fraction stored as fraction.';
    case 'co_systemic'
        description = 'Systemic cardiac output computed from LV stroke volume.';
    case 'q_systemic'
        description = 'Systemic flow Qs.';
    case 'q_pulmonary'
        description = 'Pulmonary flow Qp.';
    case 'q_ratio'
        description = 'Pulmonary-to-systemic flow ratio, Qp/Qs.';
    case 'svr'
        description = 'Systemic vascular resistance.';
    case 'pvr'
        description = 'Pulmonary vascular resistance.';
    otherwise
        description = sprintf('Exported field "%s"; verify definition in source function.', ...
            field_name);
end
end

function unit = column_unit(column_name)
switch column_name
    case {'timestamp'}
        unit = 'local time';
    case {'value', 'baseline_value', 'override_value', 'target_value', ...
            'simulated_value', 'before_value', 'after_value', ...
            'initial_value', 'lower_bound', 'upper_bound', 'final_value', ...
            'objective_before', 'objective_after', 'error_before', ...
            'error_after', 'index_value'}
        unit = 'see unit column';
    case {'percent_change', 'error_percent'}
        unit = 'percent';
    otherwise
        unit = '';
end
end

function description = column_description(column_name)
switch column_name
    case 'run_id'
        description = 'Unique identifier linking all rows from one run.';
    case 'timestamp'
        description = 'Local timestamp when the export was created.';
    case 'scenario'
        description = 'Model scenario, for example Pre-Op ASD or Post-Op ASD.';
    case 'stage'
        description = 'Workflow stage: baseline simulation, GSA, optimization, validation, plotting, or saving.';
    case 'status'
        description = 'Run status recorded by caller.';
    case 'description'
        description = 'Human-readable explanation of the row or run.';
    case 'unit'
        description = 'Physical or reporting unit for numeric values.';
    case 'source'
        description = 'Data source, function name, manuscript table, or caller note.';
    case 'details_json'
        description = 'Serialized extra columns or complex values preserved for traceability.';
    case 'parameter_name'
        description = 'Model parameter name as used in params.';
    case 'metric_name'
        description = 'Output metric name as used in the simulation or validation result.';
    case 'variable_name'
        description = 'Clinical input variable name.';
    case 'value'
        description = 'Recorded scalar value; unit is given in the unit column.';
    case 'target_value'
        description = 'Clinical or literature target used for validation.';
    case 'simulated_value'
        description = 'Model-predicted value compared against the target.';
    case 'error_absolute'
        description = 'Simulated value minus target value.';
    case 'error_percent'
        description = 'Absolute error divided by target value, reported in percent.';
    case 'sensitivity_index'
        description = 'Sensitivity index type, for example S1, ST, or rank metric.';
    case 'rank'
        description = 'Ranking order supplied by the caller.';
    case 'selection_reason'
        description = 'Rationale for selecting a parameter for calibration.';
    case 'objective_name'
        description = 'Objective function name or loss definition.';
    case 'note_text'
        description = 'Methodological note for thesis traceability.';
    case 'reference'
        description = 'Literature, code, or data reference supporting the note.';
    otherwise
        description = ['Column used by the master workbook export schema: ', ...
            column_name, '.'];
end
end

% -------------------------------------------------------------------------
% File and Excel helpers
% -------------------------------------------------------------------------
function tf = sheet_exists(workbook_file, sheet_name)
tf = false;
if ~isfile(workbook_file)
    return;
end

try
    sheets = sheetnames(workbook_file);
catch
    try
        [~, sheets] = xlsfinfo(workbook_file);
    catch
        sheets = {};
    end
end

if isstring(sheets)
    sheets = cellstr(sheets);
end

tf = any(strcmp(sheets, sheet_name));
end

function headers = read_sheet_headers(workbook_file, sheet_name, n_headers)
end_col = excel_column_name(n_headers);
range_text = sprintf('A1:%s1', end_col);

try
    raw = readcell(workbook_file, 'Sheet', sheet_name, 'Range', range_text);
catch
    headers = {};
    return;
end

if isempty(raw)
    headers = {};
    return;
end

headers = raw(1, :);
for k_header = 1:numel(headers)
    headers{k_header} = to_text(headers{k_header});
end
end

function row_count = sheet_row_count(workbook_file, sheet_name)
try
    raw = readcell(workbook_file, 'Sheet', sheet_name);
catch
    row_count = 0;
    return;
end

if isempty(raw)
    row_count = 0;
else
    row_count = size(raw, 1);
end
end

function col_name = excel_column_name(col_idx)
alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
letters_in_alphabet = numel(alphabet);    % Excel base-26 alphabet length
col_name = '';

while col_idx > 0
    remainder = mod(col_idx - 1, letters_in_alphabet);
    col_name = [alphabet(remainder + 1), col_name]; %#ok<AGROW>
    col_idx = floor((col_idx - 1) / letters_in_alphabet);
end
end

function ensure_folder(folder_path)
if ~exist(folder_path, 'dir')
    mkdir(folder_path);
end
end

function resolved_path = resolve_project_path(project_root, input_path)
if is_absolute_path(input_path)
    resolved_path = input_path;
else
    resolved_path = fullfile(project_root, input_path);
end
end

function tf = is_absolute_path(path_text)
if ispc
    has_drive_letter = numel(path_text) >= 2 && path_text(2) == ':';
    has_unc_prefix = numel(path_text) >= 2 && strcmp(path_text(1:2), '\\');
    tf = has_drive_letter || has_unc_prefix;
else
    tf = ~isempty(path_text) && path_text(1) == '/';
end
end

function [timestamp_text, timestamp_tag] = current_timestamp(text_format, ...
    file_format)
now_dt = datetime('now', 'Format', text_format);
timestamp_text = char(now_dt);
now_dt.Format = file_format;
timestamp_tag = char(now_dt);
end

function write_json_file(json_file, value)
json_text = jsonencode_safe(value);
fid = fopen(json_file, 'w');
if fid < 0
    error('export_to_master_excel:JsonWriteFailed', ...
        'Could not open JSON file for writing: %s', json_file);
end

cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', json_text);
delete(cleanup);
end

% -------------------------------------------------------------------------
% Small general helpers
% -------------------------------------------------------------------------
function s = find_schema(schema, key)
matches = strcmp({schema.key}, key);
if ~any(matches)
    error('export_to_master_excel:UnknownSchema', ...
        'No master workbook schema found for key "%s".', key);
end
s = schema(find(matches, 1, 'first'));
end

function tf = has_headers(T, headers)
tf = all(ismember(headers, T.Properties.VariableNames));
end

function token = safe_token(text)
token = to_text(text);
token = regexprep(token, '[^A-Za-z0-9_]+', '_');
token = regexprep(token, '_+', '_');
token = regexprep(token, '^_|_$', '');
if isempty(token)
    token = 'run';
end
end

function token = last_token(field_name)
parts = strsplit(field_name, '.');
token = parts{end};
end

function tf = starts_with(text, prefix)
tf = numel(text) >= numel(prefix) && strcmp(text(1:numel(prefix)), prefix);
end
