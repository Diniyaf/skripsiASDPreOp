# Scaling & Post-Processing Specification (Guardrails-Compliant)

## 1. Scaling Module

### 1.1 Purpose

Generate physiologically consistent baseline parameters (`params_scaled`) from patient-specific inputs before simulation, GSA, and calibration.

---

### 1.2 Inputs

```matlab
height_cm     % [cm]
weight_kg     % [kg]
age_years     % [years]
sex           % [0=female, 1=male]
```

Reference parameters (from config):

```matlab
params_ref    % struct (adult baseline)
```

---

### 1.3 Derived Variables

```matlab
BSA = sqrt((height_cm * weight_kg) / 3600);   % [m^2]  (Mosteller)
BSA_ref = params_ref.BSA;                     % [m^2]

scale_factor = BSA / BSA_ref;                 % [-]
```

---

### 1.4 Scaling Rules

All scaling MUST preserve physiological meaning and unit consistency.

---

#### A. Vascular Geometry

```matlab
params_scaled.L_aorta = params_ref.L_aorta * (height_cm / params_ref.height_cm);   % [cm]

params_scaled.r_aorta = params_ref.r_aorta * (scale_factor ^ 0.5);                 % [mm]
params_scaled.h_aorta = params_ref.h_aorta * (scale_factor ^ 0.5);                 % [mm]

params_scaled.N_capillary = params_ref.N_capillary * scale_factor;                 % [-]
```

---

#### B. Hemodynamic Properties

```matlab
params_scaled.P_ao_mean = params_ref.P_ao_mean * (scale_factor ^ 0.25);   % [mmHg]

age_factor = ((30 + age_years) / (30 + params_ref.age_years)) ^ 3;        % [-]

params_scaled.E_arterial = ...
    1000 + age_factor * (params_ref.E_arterial - 1000);                  % [mmHg]
```

---

#### C. Cardiac Parameters

```matlab
params_scaled.HR = params_ref.HR * (scale_factor ^ -0.33);               % [bpm]

params_scaled.Emax_lv = params_ref.Emax_lv * (scale_factor ^ -1);        % [mmHg/mL]
params_scaled.Emax_rv = params_ref.Emax_rv * (scale_factor ^ -1.5);      % [mmHg/mL]

params_scaled.V0_lv = params_ref.V0_lv * scale_factor;                  % [mL]
params_scaled.V0_rv = params_ref.V0_rv * scale_factor;                  % [mL]
```

---

#### D. Blood Volume

```matlab
params_scaled.V_blood = params_ref.V_blood * (scale_factor ^ 1.32);      % [mL]
```

---

#### E. Pulmonary & Ventilation

```matlab
params_scaled.VT = 7 * weight_kg;                                       % [mL]

params_scaled.C_lung = params_ref.C_lung * scale_factor;                % [mL/mmHg]

params_scaled.R_airway = ...
    params_ref.R_airway * (scale_factor ^ -0.5);                         % [mmHg·s/mL]
```

---

### 1.5 Output

```matlab
params_scaled   % struct with full parameter set
```

Requirements:

* All parameters stored in `params_scaled`
* No global variables
* All units consistent with internal system:

  * Pressure → [mmHg]
  * Volume → [mL]
  * Flow → [mL/s]
  * Resistance → [mmHg·s/mL]

---

## 2. Simulation Interface

Simulation is performed using:

```matlab
[t_sol, X_sol] = integrate_system(params_scaled);
```

State variables must follow index struct:

```matlab
P_lv = X_sol(:, idx.P_lv);   % [mmHg]
V_lv = X_sol(:, idx.V_lv);   % [mL]
Q_lv_ao = X_sol(:, idx.Q_lv_ao); % [mL/s]
```

---

## 3. Post-Processing Module (Clinical Indices)

### 3.1 Purpose

Convert raw simulation outputs into clinically interpretable metrics for:

* validation
* GSA
* calibration objective function

---

### 3.2 Inputs

```matlab
t_sol        % [s]
X_sol        % state matrix
params       % struct
idx          % state index struct
```

---

### 3.3 Steady-State Requirement

Only use final cardiac cycles.

Criteria:

```matlab
max_delta_P < 0.1   % [mmHg]
max_delta_V < 0.1   % [mL]
```

---

### 3.4 Extract Signals

```matlab
P_lv = X_sol(:, idx.P_lv);   % [mmHg]
P_ao = X_sol(:, idx.P_ao);   % [mmHg]
P_pa = X_sol(:, idx.P_pa);   % [mmHg]

V_lv = X_sol(:, idx.V_lv);   % [mL]

Q_lv_ao = X_sol(:, idx.Q_lv_ao);   % [mL/s]
Q_rv_pa = X_sol(:, idx.Q_rv_pa);   % [mL/s]
```

---

### 3.5 Clinical Indices

#### A. Pressure

```matlab
P_ao_sys = max(P_ao);        % [mmHg]
P_ao_dia = min(P_ao);        % [mmHg]
P_ao_mean = mean(P_ao);      % [mmHg]

P_pa_mean = mean(P_pa);      % [mmHg]
```

---

#### B. Flow

```matlab
Q_systemic_mLs = mean(Q_lv_ao);              % [mL/s]
Q_pulmonary_mLs = mean(Q_rv_pa);             % [mL/s]

mLs_to_Lmin = 60 / 1000;                     % [L/min per mL/s]

CO_systemic = Q_systemic_mLs * mLs_to_Lmin;  % [L/min]
Qp = Q_pulmonary_mLs * mLs_to_Lmin;          % [L/min]
Qs = CO_systemic;                            % [L/min]

Q_ratio = Qp / Qs;                           % [-]
```

---

#### C. Volume

```matlab
V_lv_ed = max(V_lv);                         % [mL]
V_lv_es = min(V_lv);                         % [mL]

SV_lv = V_lv_ed - V_lv_es;                   % [mL]
EF_lv = SV_lv / V_lv_ed;                     % [fraction]
```

---

#### D. Derived Hemodynamics

```matlab
RAP = mean(X_sol(:, idx.P_ra));              % [mmHg]
LAP = mean(X_sol(:, idx.P_la));              % [mmHg]

SVR = (P_ao_mean - RAP) / Q_systemic_mLs;    % [mmHg·s/mL]
PVR = (P_pa_mean - LAP) / Q_pulmonary_mLs;   % [mmHg·s/mL]
```

---

### 3.6 Output

```matlab
clinical_indices.P_ao_sys     % [mmHg]
clinical_indices.P_ao_dia     % [mmHg]
clinical_indices.P_ao_mean    % [mmHg]

clinical_indices.CO_systemic  % [L/min]
clinical_indices.Q_ratio      % [-]

clinical_indices.SV_lv        % [mL]
clinical_indices.EF_lv        % [fraction]

clinical_indices.SVR          % [mmHg·s/mL]
clinical_indices.PVR          % [mmHg·s/mL]
```

---

## 4. Integration with GSA & Calibration

### 4.1 GSA (Sobol)

* Input:

```matlab
params_scaled
```

* Output used:

```matlab
clinical_indices
```

* Sensitivity computed on:
* CO_systemic
* Q_ratio
* P_pa_mean
* EF_lv

---

### 4.2 Calibration (L-BFGS-B)

Objective function:

```matlab
J = Σ w_i * (model_i - clinical_i)^2
```

Where:

* `model_i` → output from `clinical_indices`
* `clinical_i` → measured data
* `w_i` → weighting factors

---

### 4.3 Pipeline

```text
Scaling → params_scaled
        ↓
Simulation → integrate_system
        ↓
Post-processing → clinical_indices
        ↓
Sobol GSA (parameter selection)
        ↓
L-BFGS-B Calibration
        ↓
Post-calibration simulation
        ↓
Sobol GSA (validation)
```

---

## 5. Validation Constraints (Baseline)

Model must satisfy:

```matlab
100 ≤ P_ao_sys ≤ 140      % [mmHg]
60 ≤ P_ao_dia ≤ 90        % [mmHg]
4 ≤ CO_systemic ≤ 8       % [L/min]
0.55 ≤ EF_lv ≤ 0.75       % [-]
abs(Q_ratio - 1.0) < 0.05
```

---

## 6. Guardrails Compliance

* No global variables
* All parameters in `params` struct
* All variables include unit comments
* No magic numbers
* Naming follows anatomical convention
* Separation:

  * scaling (pre-processing)
  * simulation (physics)
  * post-processing (clinical metrics)

```
```
