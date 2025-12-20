# Continuous Key Driver Module – Upgrade Specification
Document ID: TURAS-KD-CONTINUOUS-UPGRADE-v1.0

## Purpose
Upgrade the Continuous Key Driver module to support mixed predictors (continuous, ordinal, categorical) while ensuring:
- zero silent failures
- explicit mapping coverage
- refusal-based control flow
- exactly one interpretable importance score per driver

The module must fully comply with TRS v1.0.

## Scope
### In scope
- Continuous numeric outcomes only
- Predictors: continuous, ordinal, categorical
- Grouped importance for categorical drivers
- Mapping coverage enforcement
- Refusal-based failure handling

### Out of scope
- Categorical or ordinal outcomes
- Automatic binning of continuous predictors
- Any changes to categorical key driver logic

## Governing Standard
This module MUST comply fully with the Turas Mapping & Refusal Standard (TRS v1.0).
If any conflict exists, TRS takes precedence.

## Configuration Requirements
Each driver must be explicitly declared. Inference is forbidden.

Required fields per driver:
- driver_name (unique)
- driver_type ∈ {continuous, ordinal, categorical}
- source_column (exact data column)
- aggregation_method (required only if categorical)

Missing or invalid configuration must trigger REFUSE.

## Predictor Handling Rules
### Continuous drivers
- Must produce exactly one model term
- Zero variance or aliasing triggers REFUSE

### Ordinal drivers
- Default: treated as numeric
- If categorical: must be explicit and follow categorical rules

### Categorical drivers
- Treatment contrasts only
- Polynomial contrasts forbidden
- Must have ≥2 observed levels
- All generated terms must map back to the same driver

## Mapping & Coverage Gate
After model fitting:
1. Build expected terms from config and encoding rules
2. Extract observed terms from model coefficients
3. Compare expected vs observed
4. REFUSE on any mismatch

Warnings are never sufficient.

## Importance Calculation
Exactly one importance score must be produced per driver.

- Continuous drivers: direct importance
- Categorical drivers: grouped importance

Allowed aggregation methods:
- partial_r2 (default)
- grouped_permutation
- grouped_shapley (only if SHAP enabled)

If importance cannot be computed as specified, REFUSE.

## Optional Features (SHAP, Quadrants)
Optional features must declare enablement and on-fail policy.

Defaults:
- If enabled → on_fail = refuse

If continue_with_flag:
- run_status = PARTIAL
- degraded outputs listed
- prominent console banner

## Output Contract
Outputs must include:
- one row per driver
- one importance score per driver
- method notes
- status table with run_status ∈ {PASS, PARTIAL}

No output may be produced if execution ends in REFUSE.

## Definition of Done
The module is complete when:
- mixed predictors are supported safely
- mapping coverage is enforced
- all failures are explicit refusals
- output status is always declared
- no silent degradation paths exist
