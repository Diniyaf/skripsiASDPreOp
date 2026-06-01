function ctx = run_asd_patient_case(patient_fn, label, scenario, options)
% RUN_ASD_PATIENT_CASE
% -----------------------------------------------------------------------
% Patient-generic ASD workflow context builder.
%
% This function prepares the reusable ASD pipeline context without running
% full GSA or optimization by default. Patient-specific scripts such as
% scripts/run_zoya_asd_gsa_curated.m can call this function as a wrapper.
%
% INPUTS:
%   patient_fn - function handle returning clinical struct              [-]
%   label      - patient label for output naming                         [-]
%   scenario   - scenario string                                         [-]
%   options    - optional struct:
%                .scaling_mode default lundquist_bsa                    [-]
%                .runBaselineSimulation default false                   [-]
%
% OUTPUTS:
%   ctx        - struct containing clinical, params0, caseProfile,
%                target tiers, candidate set, and curated library        [-]
%
% ASSUMPTIONS:
%   - The caller decides whether to run GSA or calibration after inspecting
%     this context.
%   - No post-closure/Jovano data are loaded unless caller passes such a
%     patient function and scenario explicitly.
%
% REFERENCES:
%   [1] C:/Users/Diniya/unified-vsd-temp/main_run.m
%   [2] src/calibration/build_asd_case_calibration_profile.m
%
% AUTHOR:   Diniya / Codex
% DATE:     2026-06-01
% VERSION:  1.0
% -----------------------------------------------------------------------

if nargin < 1 || isempty(patient_fn)
    error('run_asd_patient_case:missingPatientFunction', ...
        'patient_fn must be a function handle, e.g. @patient_zoya.');
end
if nargin < 2 || isempty(label)
    label = func2str(patient_fn);
end
label = char(string(label));
if nargin < 3 || isempty(scenario)
    scenario = 'pre_surgery';
end
if nargin < 4 || isempty(options)
    options = struct();
end

options = merge_defaults(options, default_options());

clinical = patient_fn();
params_ref = default_parameters();

scaling_label = sprintf('%s_ReferencePatient', label);
patient = clinical_to_scaling_patient(clinical, scaling_label);
patient.scaling_mode = options.scaling_mode;

params_scaled = apply_scaling(params_ref, patient);
params0 = params_from_clinical(params_scaled, clinical, scenario, ...
    params_scaled, struct());

caseProfile = build_asd_case_calibration_profile(clinical, scenario, params0);
caseProfile.patient_label = string(label);
caseProfile.patient_id = string(label);

target_tiers = build_asd_target_tiers(clinical, scenario, caseProfile);
candidate_report = asd_candidate_param_sets(params0, caseProfile, scenario);
curated_library = build_asd_curated_parameter_library(candidate_report);

ctx = struct();
ctx.patient_fn = patient_fn;
ctx.label = char(label);
ctx.scenario = char(scenario);
ctx.options = options;
ctx.clinical = clinical;
ctx.params_ref = params_ref;
ctx.patient = patient;
ctx.params_scaled = params_scaled;
ctx.params0 = params0;
ctx.caseProfile = caseProfile;
ctx.target_tiers = target_tiers;
ctx.candidate_report = candidate_report;
ctx.curated_library = curated_library;

if options.runBaselineSimulation
    sim = integrate_system(params0);
    metrics = compute_clinical_indices(sim, params0);
    ctx.baseline_sim = sim;
    ctx.baseline_metrics = metrics;
end

end

function options = default_options()
% DEFAULT_OPTIONS - safe defaults for context building only.
options = struct();
options.scaling_mode = 'lundquist_bsa';
options.runBaselineSimulation = false;
end

function out = merge_defaults(in, defaults)
% MERGE_DEFAULTS - fill missing option fields.
out = defaults;
names = fieldnames(in);
for i = 1:numel(names)
    out.(names{i}) = in.(names{i});
end
end
