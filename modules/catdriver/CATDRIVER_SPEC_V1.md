# CatDriver Specification v1.0

## Purpose
This document defines the explicit behavioral contract for the CatDriver module. Any behavior not explicitly defined here MUST produce a hard error rather than guessing.

## Supported Analysis Types

### Outcome Types
| Type | Description | Statistical Method | Config Value |
|------|-------------|-------------------|--------------|
| Binary | Exactly 2 categories | Logistic regression (`glm` binomial) | `binary` |
| Ordinal | Ordered categories (3+) | Proportional odds (`ordinal::clm` or `MASS::polr`) | `ordinal` |
| Multinomial | Unordered categories (3+) | Multinomial logistic (`nnet::multinom`) | `multinomial` |

**Requirement:** Outcome type MUST be explicitly declared in config. Auto-detection is NOT permitted.

### Driver Types
| Type | Description | Statistical Treatment | Config Value |
|------|-------------|----------------------|--------------|
| Categorical | Unordered categories | Treatment contrasts (dummy coding) | `categorical` |
| Ordinal | Ordered categories | Treatment contrasts OR polynomial (configurable) | `ordinal` |
| Continuous | Numeric scale | Linear term (allowed only as covariate) | `continuous` |

**Requirement:** Each driver MUST have explicit type in DRIVER_SETTINGS sheet. Hidden inference is NOT permitted.

## Missingness Strategies

### Outcome Variable
- Missing outcome values: **ALWAYS drop row** (no other option)
- This is mandatory - cannot model unknown outcomes

### Driver Variables (per-variable, configurable)
| Strategy | Behavior | Config Value |
|----------|----------|--------------|
| Drop row | Exclude observation from analysis | `drop_row` |
| Missing as level | Create "Missing / Not answered" category | `missing_as_level` |
| Error if missing | Refuse to run if any missing | `error_if_missing` |

**Default:** `missing_as_level` for categorical/ordinal drivers

### Continuous Covariates
| Strategy | Behavior | Config Value |
|----------|----------|--------------|
| Drop row | Exclude observation | `drop_row` |
| Impute median | Replace with median value | `impute_median` |
| Error if missing | Refuse to run | `error_if_missing` |

## Weight Handling

**Statement:** Models are weighted using analysis weights; standard errors are model-based.

- Survey weights are treated as analysis weights
- P-values indicate strength of association, not exact population inference
- No clustering or stratification information is assumed
- Output MUST state this explicitly in Executive Summary

## Reference Category Rules

Priority order:
1. Explicitly specified in config (`reference_level` column)
2. Most frequent non-missing category
3. First category in declared order

**Hard Error:** Reference category MUST NOT be "Missing / Not answered" unless explicitly permitted via `allow_missing_reference = TRUE`

## Multinomial Reporting Modes

For multinomial outcomes, config MUST specify one of:

| Mode | Config Setting | Behavior |
|------|---------------|----------|
| Per-outcome | `multinomial_mode = per_outcome` | Separate tables for each outcome vs reference |
| Target outcome | `multinomial_mode = target_outcome` + `target_outcome_level = X` | Single table for target vs all others |

**Hard Error:** Refuse to run multinomial without explicit mode specification.

## Rare Level Policy

Configurable per driver with global defaults:

| Policy | Behavior | Config Value |
|--------|----------|--------------|
| Warn only | Log warning, proceed | `warn_only` |
| Collapse to Other | Merge rare levels into "Other" | `collapse_to_other` |
| Drop level | Remove level and affected rows | `drop_level` |
| Error | Refuse to run | `error` |

**Default Thresholds:**
- Warning: Cell count < 5
- Collapse: Level N < 10

**Requirement:** All collapsing MUST be deterministic and documented in output.

## Model Estimation

### Primary Engines
- Binary: `glm()` with binomial family
- Ordinal: `ordinal::clm()` (preferred) or `MASS::polr()`
- Multinomial: `nnet::multinom()`

### Fallback Behavior
| Condition | Primary Action | Fallback |
|-----------|---------------|----------|
| Binary separation | Detect via large SE/coef | `brglm2::brglm()` Firth correction |
| Ordinal non-convergence | Detect via convergence flag | Try different optimizer, then error |
| Multinomial non-convergence | Detect via convergence flag | Reduce model or error |

**Requirement:** If fallback is used, output MUST prominently state this.

### Fit Status Output
Every run MUST report:
- Model engine used
- Convergence status (yes/no)
- Fallback used (yes/no + reason)
- Predictors dropped due to singularity

## Importance Metrics

### Method
- Binary/Ordinal: Likelihood ratio drop-in-deviance
- Multinomial: LR per predictor (overall)

### Stability Flag
If any of these conditions apply, importance is flagged "use with caution":
- Fallback estimator used
- Heavy collapsing performed (>20% of levels collapsed)
- Effective N < 10 per parameter
- Events-per-parameter < 10

## Output Workbook Schema

### Required Sheets
1. **Executive Summary** - Plain-English findings
2. **Importance Summary** - Variable importance table
3. **Factor Patterns** - Cross-tabulation with ORs
4. **Model Summary** - Fit statistics and diagnostics
5. **Odds Ratios** - Detailed coefficient table
6. **Diagnostics** - Data quality checks

### Required Columns (Importance Summary)
- Rank, Factor, Label, Importance %, Chi-Square, P-Value, Sig., Effect Size, Stability Flag

### Required Columns (Odds Ratios)
- Factor, Comparison, Reference, Odds Ratio, 95% CI, P-Value, Sig., Effect
- For multinomial: + Outcome Level

### Integrity Requirements
- No missing drawing parts
- No legacy VML unless necessary
- Must pass openpyxl read/write roundtrip

## Hard Errors (Refuse to Run)

The tool MUST stop with a clear error message if:

1. Outcome type not explicitly declared in config
2. Outcome levels in data don't match config declaration
3. Multinomial with no reporting mode specified
4. Term-to-level mapping fails for any driver level
5. Missing becomes reference (unless explicitly allowed)
6. Model fails and no fallback available
7. Driver type not specified and no DRIVER_SETTINGS sheet

## Soft Failures (Warnings in Output)

The tool MUST warn but continue if:

1. Fallback estimator used
2. Heavy collapsing performed
3. Effective N too small (< recommended)
4. Events-per-parameter too low (< 10)
5. Proportional odds assumption questionable (ordinal)
6. High multicollinearity detected (GVIF > 5)

## Config File Schema

### Settings Sheet (Required)
| Setting | Required | Type | Description |
|---------|----------|------|-------------|
| data_file | Yes | path | Path to data file |
| output_file | Yes | path | Path for output Excel |
| analysis_name | No | string | Display name for analysis |
| outcome_type | **Yes** | enum | binary/ordinal/multinomial |
| multinomial_mode | Cond. | enum | per_outcome/target_outcome (required if multinomial) |
| target_outcome_level | Cond. | string | Target level (required if target_outcome mode) |
| reference_category | No | string | Reference for outcome |
| confidence_level | No | numeric | Default 0.95 |
| min_sample_size | No | integer | Default 30 |
| rare_level_policy | No | enum | Default warn_only |
| rare_level_threshold | No | integer | Default 10 |
| allow_missing_reference | No | boolean | Default FALSE |

### Variables Sheet (Required)
| Column | Required | Description |
|--------|----------|-------------|
| VariableName | Yes | Variable name in data |
| Type | Yes | Outcome/Driver/Weight |
| Label | Yes | Display label |
| Order | No | Semicolon-separated level order |

### Driver_Settings Sheet (Required for drivers)
| Column | Required | Description |
|--------|----------|-------------|
| driver | Yes | Variable name |
| type | Yes | categorical/ordinal/continuous |
| levels_order | No | Semicolon-separated order |
| reference_level | No | Reference category |
| missing_strategy | No | drop_row/missing_as_level/error_if_missing |
| rare_level_policy | No | Override global policy |

## Version History

- v1.0 (2024-12): Initial specification
