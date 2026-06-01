function test_calib_syntax()
% Quick syntax check for calibration pipeline
root = fileparts(fileparts(mfilename('fullpath')));
restoredefaultpath;
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'tests'));
addpath(genpath(fullfile(root, 'src')));

% Remove arsip from path to prevent shadowing
path_entries = strsplit(path, pathsep);
for i = 1:numel(path_entries)
    if contains(path_entries{i}, 'arsip')
        rmpath(path_entries{i});
    end
end

fprintf('Loading params0_ASD_pre...\n');
ctx = run_asd_patient_case(@patient_zoya, 'zoya', 'pre_surgery', ...
    struct('scaling_mode', 'lundquist_bsa'));
params0 = ctx.params0;
caseProfile = ctx.caseProfile;

fprintf('Building target tiers and curated candidate params...\n');
target_tiers = ctx.target_tiers;
curated_library = ctx.curated_library;

gsa_data = struct();
gsa_data.sobol.Parameter = cellstr(curated_library.Parameter);
gsa_data.sobol.Metric = cellstr(unique(target_tiers.ModelField(target_tiers.IncludeInGSA), 'stable'));
gsa_data.sobol.ST = 0.01 * ones(height(curated_library), numel(gsa_data.sobol.Metric));
gsa_data.sobol.S1 = gsa_data.sobol.ST;

priority_names = {'asd.Cd', 'R.SC', 'R.PCOX', 'C.PAR', 'R.SAR'};
for i = 1:numel(priority_names)
    row_idx = find(strcmp(cellstr(curated_library.Parameter), priority_names{i}), 1);
    if ~isempty(row_idx)
        gsa_data.sobol.ST(row_idx, :) = 0.20 - 0.01 * i;
        gsa_data.sobol.S1(row_idx, :) = 0.08 - 0.005 * i;
    end
end

[active_selection, opt_mask] = build_asd_active_mask_from_gsa( ...
    gsa_data, curated_library, target_tiers, struct('AllowGroupC', false, ...
    'CaseProfile', caseProfile));

names_s1 = cellstr(curated_library.Parameter(opt_mask));
x0 = curated_library.Initial_Value(opt_mask);
lb = curated_library.Lower_Bound(opt_mask);
ub = curated_library.Upper_Bound(opt_mask);

fprintf('Stage 1 (%d params): %s\n', numel(names_s1), strjoin(names_s1, ', '));
fprintf('  x0=[%s]\n', sprintf('%.4g ', x0));
fprintf('  lb=[%s]\n', sprintf('%.4g ', lb));
fprintf('  ub=[%s]\n', sprintf('%.4g ', ub));

calib.names_s1 = names_s1;
calib.x0_s1 = x0;
calib.lb_s1 = lb;
calib.ub_s1 = ub;
calib.active_selection = active_selection;

calib.simOverrides.nCyclesSteady = 40;
calib.simOverrides.ss_tol_P = 0.5;
calib.simOverrides.ss_tol_V = 0.5;
hard_rows = strcmp(target_tiers.Tier, 'hard_primary');
calib.targets = table_to_target_struct(target_tiers(hard_rows, :));
calib.targetFields = fieldnames(calib.targets);
secondary_rows = strcmp(target_tiers.Tier, 'soft_secondary_guard');
calib.secondaryTargets = table_to_target_struct(target_tiers(secondary_rows, :));
calib.secondaryTargetFields = fieldnames(calib.secondaryTargets);
calib.secondaryLambda = 0.35;
calib.caseProfile = caseProfile;
calib.primaryTarget = 0.05;
calib.plausibilityLambda = 0.5;
calib.boundaryLambda = 20;

fprintf('Testing objective function at x0...\n');
calib.x0Reference = x0(:);
J0 = objective_calibration_asd(x0, params0, calib, names_s1, lb, ub, ...
    @apply_sim_overrides_test, @integrate_system, @compute_clinical_indices);
fprintf('  J0 = %.6f\n', J0);
fprintf('ALL CHECKS PASSED.\n');
end

function p2 = apply_sim_overrides_test(p1, ov)
p2 = p1;
if isfield(ov, 'nCyclesSteady'), p2.sim.nCyclesSteady = ov.nCyclesSteady; end
if isfield(ov, 'ss_tol_P'),      p2.sim.ss_tol_P = ov.ss_tol_P; end
if isfield(ov, 'ss_tol_V'),      p2.sim.ss_tol_V = ov.ss_tol_V; end
end

function targets = table_to_target_struct(rows)
targets = struct();
for i = 1:height(rows)
    field_name = char(rows.ModelField(i));
    clinical_target = rows.ClinicalTarget(i);
    if isfinite(clinical_target)
        targets.(field_name) = clinical_target;
    end
end
end
