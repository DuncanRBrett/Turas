# Turas MaxDiff Module - Technical Reference

**Version:** 10.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Module Structure](#2-module-structure)
3. [Core Functions API](#3-core-functions-api)
4. [Data Structures](#4-data-structures)
5. [Statistical Methods](#5-statistical-methods)
6. [Stan Model Specification](#6-stan-model-specification)
7. [Validation Rules](#7-validation-rules)
8. [Error Handling](#8-error-handling)
9. [Extending the Module](#9-extending-the-module)
10. [Performance Considerations](#10-performance-considerations)

---

## 1. Architecture Overview

### 1.1 Design Principles

The MaxDiff module follows these architectural principles:

1. **Separation of Concerns**: Each R file handles one aspect of the workflow
2. **Excel-Driven Configuration**: All settings via Excel workbook, no code changes needed
3. **Graceful Degradation**: Optional features (HB, segments) fail gracefully
4. **Reproducibility**: Seed-based random number generation throughout
5. **Defensive Coding**: Comprehensive validation at all entry points

### 1.2 Dependency Graph

```
00_main.R (Entry Point)
    │
    ├── utils.R (Utilities)
    ├── 01_config.R (Configuration)
    │       └── Validates → 02_validation.R
    │
    ├── [DESIGN MODE]
    │       └── 04_design.R
    │
    └── [ANALYSIS MODE]
            ├── 03_data.R (Load & Reshape)
            ├── 05_counts.R (Count Scores)
            ├── 06_logit.R (Aggregate Logit)
            ├── 07_hb.R (Hierarchical Bayes)
            │       └── stan/maxdiff_hb.stan
            ├── 08_segments.R (Segment Analysis)
            ├── 09_output.R (Excel Output)
            └── 10_charts.R (Visualisations)
```

### 1.3 Package Dependencies

| Package | Version | Purpose | Required |
|---------|---------|---------|----------|
| openxlsx | ≥4.2.5 | Excel read/write | Yes |
| survival | ≥3.5.0 | Conditional logit | Yes* |
| ggplot2 | ≥3.4.0 | Visualisations | Yes* |
| cmdstanr | ≥0.6.0 | HB estimation | No |
| AlgDesign | ≥1.2.1 | Optimal designs | No |

*Fallback methods available if not installed

---

## 2. Module Structure

### 2.1 File Organisation

```
modules/maxdiff/
├── R/
│   ├── 00_main.R          # Entry point, workflow orchestration
│   ├── 01_config.R        # Configuration loading and parsing
│   ├── 02_validation.R    # Data and design validation
│   ├── 03_data.R          # Data loading and long-format reshaping
│   ├── 04_design.R        # Experimental design generation
│   ├── 05_counts.R        # Count-based scoring
│   ├── 06_logit.R         # Aggregate conditional logit
│   ├── 07_hb.R            # Hierarchical Bayes estimation
│   ├── 08_segments.R      # Segment-level analysis
│   ├── 09_output.R        # Excel output generation
│   ├── 10_charts.R        # ggplot2 visualisations
│   └── utils.R            # Shared utility functions
├── stan/
│   └── maxdiff_hb.stan    # Stan model for HB estimation
├── tests/
│   └── test_maxdiff.R     # Unit tests
├── examples/
│   └── basic/
│       └── create_example_files.R
├── docs/
│   ├── USER_MANUAL.md
│   └── TECHNICAL_REFERENCE.md
├── run_maxdiff_gui.R      # Shiny GUI launcher
└── README.md
```

### 2.2 Source Loading Order

The `00_main.R` entry point sources files in this order:

1. `utils.R` - Utility functions used by all modules
2. `01_config.R` - Configuration parsing
3. `02_validation.R` - Validation functions
4. `03_data.R` - Data handling
5. `04_design.R` - Design generation
6. `05_counts.R` - Count scoring
7. `06_logit.R` - Logit estimation
8. `07_hb.R` - HB estimation
9. `08_segments.R` - Segment analysis
10. `09_output.R` - Output generation
11. `10_charts.R` - Chart generation

---

## 3. Core Functions API

### 3.1 Entry Points

#### `run_maxdiff(config_path, project_root, verbose)`

Main entry point for the module.

```r
run_maxdiff(
  config_path,              # Character: Path to config Excel file
  project_root = NULL,      # Character: Project root (default: config directory)
  verbose = TRUE            # Logical: Print progress messages
)
```

**Returns:** List with:
- `mode`: "DESIGN" or "ANALYSIS"
- `config`: Parsed configuration object
- `output_path`: Path to output file
- `elapsed_seconds`: Execution time
- Mode-specific results (design/analysis objects)

#### `run_maxdiff_gui()`

Launches Shiny GUI interface.

```r
run_maxdiff_gui()
```

### 3.2 Configuration Functions

#### `load_maxdiff_config(config_path, project_root)`

Loads and validates complete configuration.

```r
config <- load_maxdiff_config(
  config_path,              # Character: Path to config file
  project_root = NULL       # Character: Base path for relative paths
)
```

**Returns:** `maxdiff_config` S3 object with:
- `project_settings`: Named list
- `items`: Data frame
- `design_settings`: Named list (or NULL)
- `survey_mapping`: Data frame (or NULL)
- `segment_settings`: Data frame (or NULL)
- `output_settings`: Named list
- `mode`: "DESIGN" or "ANALYSIS"
- `project_root`: Resolved path
- `config_path`: Original config path

### 3.3 Design Functions

#### `generate_maxdiff_design(items, design_settings, seed, verbose)`

Generates experimental design.

```r
design_result <- generate_maxdiff_design(
  items,                    # Data frame: Item definitions
  design_settings,          # List: Design parameters
  seed = 12345,             # Integer: Random seed
  verbose = TRUE
)
```

**Returns:** List with:
- `design`: Data frame (Version, Task_Number, Item1_ID, ...)
- `summary`: Design quality metrics
- `diagnostics`: Detailed balance statistics

#### `validate_design(design, items, verbose)`

Validates design quality.

```r
validation <- validate_design(
  design,                   # Data frame: Design matrix
  items,                    # Data frame: Item definitions
  verbose = TRUE
)
```

**Returns:** List with:
- `valid`: Logical
- `issues`: Character vector of problems
- `warnings`: Character vector of warnings
- `metrics`: Design quality metrics

### 3.4 Data Functions

#### `load_survey_data(file_path, sheet, verbose)`

Loads survey response data.

```r
data <- load_survey_data(
  file_path,                # Character: Path to data file
  sheet = 1,                # Integer/Character: Sheet name or number
  verbose = TRUE
)
```

#### `build_maxdiff_long(data, survey_mapping, design, config, verbose)`

Reshapes data to long format for analysis.

```r
long_data <- build_maxdiff_long(
  data,                     # Data frame: Raw survey data
  survey_mapping,           # Data frame: Column mappings
  design,                   # Data frame: Design matrix
  config,                   # List: Full configuration
  verbose = TRUE
)
```

**Returns:** Data frame with columns:
- `resp_id`: Respondent identifier
- `task`: Task number
- `item_id`: Item identifier
- `shown`: 1 if item was shown in task
- `chosen_best`: 1 if chosen as best
- `chosen_worst`: 1 if chosen as worst
- `weight`: Respondent weight

### 3.5 Scoring Functions

#### `compute_maxdiff_counts(long_data, items, weighted, verbose)`

Computes count-based scores.

```r
counts <- compute_maxdiff_counts(
  long_data,                # Data frame: Long format data
  items,                    # Data frame: Item definitions
  weighted = TRUE,          # Logical: Use weights
  verbose = TRUE
)
```

**Returns:** Data frame with:
- `Item_ID`, `Item_Label`
- `Times_Shown`, `Times_Best`, `Times_Worst`
- `Best_Pct`, `Worst_Pct`, `Net_Score`, `BW_Score`

#### `fit_aggregate_logit(long_data, items, weighted, verbose)`

Fits aggregate conditional logit model.

```r
logit_results <- fit_aggregate_logit(
  long_data,                # Data frame: Long format data
  items,                    # Data frame: Item definitions
  weighted = TRUE,          # Logical: Use weights
  verbose = TRUE
)
```

**Returns:** List with:
- `utilities`: Data frame (Item_ID, Logit_Utility, Logit_SE)
- `model`: Fitted clogit model object
- `fit_stats`: Log-likelihood, AIC, BIC, pseudo-R²

#### `fit_hb_model(long_data, items, config, verbose)`

Fits Hierarchical Bayes model via Stan.

```r
hb_results <- fit_hb_model(
  long_data,                # Data frame: Long format data
  items,                    # Data frame: Item definitions
  config,                   # List: Full configuration (for HB settings)
  verbose = TRUE
)
```

**Returns:** List with:
- `population_utilities`: Data frame (Item_ID, HB_Utility_Mean, HB_Utility_SD)
- `individual_utilities`: Matrix (respondents × items)
- `diagnostics`: Rhat, ESS, divergences
- `stanfit`: cmdstanr fit object

### 3.6 Segment Functions

#### `compute_segment_scores(long_data, raw_data, segment_settings, items, output_settings, verbose)`

Computes segment-level scores.

```r
segment_results <- compute_segment_scores(
  long_data,                # Data frame: Long format data
  raw_data,                 # Data frame: Original data (for segment vars)
  segment_settings,         # Data frame: Segment definitions
  items,                    # Data frame: Item definitions
  output_settings,          # List: Output settings
  verbose = TRUE
)
```

**Returns:** List with one element per segment:
- `segment_id`: Segment identifier
- `scores`: Data frame of scores per segment level
- `n_per_level`: Sample sizes
- `comparison_tests`: Statistical tests

### 3.7 Output Functions

#### `generate_maxdiff_output(results, config, verbose)`

Generates Excel output workbook.

```r
output_path <- generate_maxdiff_output(
  results,                  # List: All analysis results
  config,                   # List: Configuration
  verbose = TRUE
)
```

**Returns:** Character path to output file.

#### `generate_maxdiff_charts(results, config, verbose)`

Generates PNG chart files.

```r
chart_paths <- generate_maxdiff_charts(
  results,                  # List: Analysis results
  config,                   # List: Configuration
  verbose = TRUE
)
```

**Returns:** Character vector of chart file paths.

---

## 4. Data Structures

### 4.1 Configuration Object

```r
config <- list(
  project_settings = list(
    Project_Name = "Study_2025",
    Mode = "ANALYSIS",
    Raw_Data_File = "/path/to/data.xlsx",
    Design_File = "/path/to/design.xlsx",
    Output_Folder = "/path/to/output/",
    Weight_Variable = "weight",
    Respondent_ID_Variable = "RespID",
    Filter_Expression = NULL,
    Seed = 12345
  ),

  items = data.frame(
    Item_ID = c("ITEM_01", "ITEM_02", ...),
    Item_Label = c("Label 1", "Label 2", ...),
    Item_Group = c("Group A", "Group A", ...),
    Include = c(1, 1, ...),
    Anchor_Item = c(0, 0, ..., 1),
    Display_Order = c(1, 2, ...)
  ),

  design_settings = list(
    Items_Per_Task = 4,
    Tasks_Per_Respondent = 12,
    Num_Versions = 3,
    Design_Type = "BALANCED",
    ...
  ),

  survey_mapping = data.frame(
    Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE", ...),
    Field_Name = c("Version", "Q1_Best", "Q1_Worst", ...),
    Task_Number = c(NA, 1, 1, ...)
  ),

  segment_settings = data.frame(
    Segment_ID = c("GENDER", "AGE"),
    Segment_Label = c("Gender", "Age Group"),
    Variable_Name = c("Gender", "Age"),
    Segment_Def = c("", "cut(Age, c(0,30,50,100))"),
    Include_in_Output = c(1, 1)
  ),

  output_settings = list(
    Generate_Count_Scores = TRUE,
    Generate_Aggregate_Logit = TRUE,
    Generate_HB_Model = TRUE,
    HB_Iterations = 5000,
    HB_Warmup = 2000,
    HB_Chains = 4,
    Score_Rescale_Method = "0_100",
    ...
  ),

  mode = "ANALYSIS",
  project_root = "/path/to/project",
  config_path = "/path/to/config.xlsx"
)

class(config) <- c("maxdiff_config", "list")
```

### 4.2 Long Format Data

The analysis functions expect data in long format:

```r
long_data <- data.frame(
  resp_id = c("R001", "R001", "R001", "R001", ...),
  task = c(1, 1, 1, 1, 2, 2, 2, 2, ...),
  item_id = c("ITEM_01", "ITEM_02", "ITEM_03", "ITEM_04", ...),
  shown = c(1, 1, 1, 1, ...),
  chosen_best = c(1, 0, 0, 0, ...),
  chosen_worst = c(0, 0, 1, 0, ...),
  weight = c(1.2, 1.2, 1.2, 1.2, ...)
)
```

### 4.3 Design Matrix

```r
design <- data.frame(
  Version = c(1, 1, 1, 2, 2, 2, ...),
  Task_Number = c(1, 2, 3, 1, 2, 3, ...),
  Item1_ID = c("ITEM_01", "ITEM_02", ...),
  Item2_ID = c("ITEM_04", "ITEM_03", ...),
  Item3_ID = c("ITEM_07", "ITEM_06", ...),
  Item4_ID = c("ITEM_09", "ITEM_10", ...)
)
```

---

## 5. Statistical Methods

### 5.1 Count-Based Scores

#### Best Percentage
$$\text{Best\%}_i = \frac{\sum_{n,t} w_n \cdot \mathbb{1}[\text{best}_{n,t} = i]}{\sum_{n,t} w_n \cdot \mathbb{1}[i \in S_{n,t}]} \times 100$$

#### Worst Percentage
$$\text{Worst\%}_i = \frac{\sum_{n,t} w_n \cdot \mathbb{1}[\text{worst}_{n,t} = i]}{\sum_{n,t} w_n \cdot \mathbb{1}[i \in S_{n,t}]} \times 100$$

#### Net Score
$$\text{Net}_i = \text{Best\%}_i - \text{Worst\%}_i$$

#### Best-Worst Score
$$\text{BW}_i = \frac{\sum(\text{best}_i) - \sum(\text{worst}_i)}{\sum(\text{shown}_i)}$$

### 5.2 Aggregate Logit Model

The conditional logit model assumes:

$$P(\text{item } i \text{ chosen as Best} | S) = \frac{\exp(\beta_i)}{\sum_{j \in S} \exp(\beta_j)}$$

$$P(\text{item } i \text{ chosen as Worst} | S) = \frac{\exp(-\beta_i)}{\sum_{j \in S} \exp(-\beta_j)}$$

Where:
- $S$ is the set of items shown in the task
- $\beta_i$ is the utility parameter for item $i$

**Implementation:** Uses `survival::clogit()` with stratification by respondent-task.

**Identification:** One item (anchor) is fixed at $\beta = 0$.

### 5.3 Hierarchical Bayes Model

#### Likelihood

$$P(\text{choice}_{n,t} | \beta_n, S_{n,t}) = \frac{\exp(\pm\beta_{n,i})}{\sum_{j \in S} \exp(\pm\beta_{n,j})}$$

Where $+$ for best choices, $-$ for worst choices.

#### Prior Structure

$$\beta_n \sim \text{MVN}(\mu, \Sigma)$$
$$\mu \sim \text{Normal}(0, 2^2 I)$$
$$\Sigma = \text{diag}(\sigma) \cdot \Omega \cdot \text{diag}(\sigma)$$
$$\sigma_j \sim \text{Student-t}(3, 0, 1)$$
$$\Omega \sim \text{LKJ}(2)$$

#### Non-Centered Parameterisation

For improved MCMC sampling:

$$\beta_n = \mu + L \cdot z_n$$

Where:
- $L$ is the Cholesky factor of $\Sigma$
- $z_n \sim \text{Normal}(0, I)$

### 5.4 Score Rescaling

| Method | Formula |
|--------|---------|
| RAW | $u_i$ (no change) |
| 0_100 | $100 \times \frac{u_i - \min(u)}{\max(u) - \min(u)}$ |
| PROBABILITY | $\frac{\exp(u_i)}{\sum_j \exp(u_j)}$ |

---

## 6. Stan Model Specification

### 6.1 Model Code

Located in `stan/maxdiff_hb.stan`:

```stan
data {
  int<lower=1> N;              // Number of choice observations
  int<lower=1> R;              // Number of respondents
  int<lower=2> J;              // Number of items
  int<lower=2> K;              // Items per task
  array[N] int<lower=1,upper=R> resp;     // Respondent index
  array[N] int<lower=1,upper=J> choice;   // Chosen item index (1-K position)
  array[N, K] int<lower=1,upper=J> shown; // Items shown in task
  array[N] int<lower=0,upper=1> is_best;  // 1=best choice, 0=worst
}

parameters {
  vector[J-1] mu_raw;          // Population mean (J-1 for anchor)
  vector<lower=0>[J-1] sigma;  // Population SD per item
  cholesky_factor_corr[J-1] L; // Cholesky factor of correlation matrix
  matrix[R, J-1] z;            // Standard normal deviates
}

transformed parameters {
  matrix[R, J] beta;           // Individual-level utilities

  // Non-centered parameterisation
  for (r in 1:R) {
    beta[r, 1:(J-1)] = mu_raw' + (diag_pre_multiply(sigma, L) * z[r]')';
  }
  beta[, J] = rep_vector(0.0, R);  // Anchor item fixed at 0
}

model {
  // Priors
  mu_raw ~ normal(0, 2);
  sigma ~ student_t(3, 0, 1);
  L ~ lkj_corr_cholesky(2);
  to_vector(z) ~ std_normal();

  // Likelihood
  for (n in 1:N) {
    vector[K] utils;
    for (k in 1:K) {
      utils[k] = is_best[n] ? beta[resp[n], shown[n,k]]
                           : -beta[resp[n], shown[n,k]];
    }
    target += utils[choice[n]] - log_sum_exp(utils);
  }
}

generated quantities {
  vector[J] mu;
  mu[1:(J-1)] = mu_raw;
  mu[J] = 0;
}
```

### 6.2 Data Preparation for Stan

```r
stan_data <- list(
  N = nrow(choice_obs),
  R = n_respondents,
  J = n_items,
  K = items_per_task,
  resp = choice_obs$resp_idx,
  choice = choice_obs$choice_position,
  shown = shown_matrix,
  is_best = choice_obs$is_best
)
```

### 6.3 MCMC Settings

Default settings in OUTPUT_SETTINGS:

| Parameter | Default | Description |
|-----------|---------|-------------|
| HB_Iterations | 5000 | Post-warmup iterations |
| HB_Warmup | 2000 | Warmup iterations |
| HB_Chains | 4 | Parallel chains |

### 6.4 Convergence Diagnostics

The module checks:

| Diagnostic | Threshold | Action |
|------------|-----------|--------|
| Rhat | < 1.05 | Warning if exceeded |
| ESS_bulk | > 400 | Warning if low |
| ESS_tail | > 400 | Warning if low |
| Divergences | 0 | Warning if any |

---

## 7. Validation Rules

### 7.1 Configuration Validation

| Rule | Check | Error Level |
|------|-------|-------------|
| Required sheets | PROJECT_SETTINGS, ITEMS exist | Fatal |
| Mode-specific sheets | DESIGN_SETTINGS for DESIGN, SURVEY_MAPPING for ANALYSIS | Fatal |
| Valid mode | Mode in ("DESIGN", "ANALYSIS") | Fatal |
| Item_ID unique | No duplicate Item_IDs | Fatal |
| Min items | At least 2 included items | Fatal |
| Max anchor | At most 1 anchor item | Fatal |
| File exists | Raw_Data_File, Design_File exist | Fatal |
| Valid expressions | Filter_Expression, Segment_Def parseable | Fatal |

### 7.2 Design Validation

| Rule | Check | Error Level |
|------|-------|-------------|
| Item coverage | All items appear at least once | Warning |
| Pair coverage | All pairs appear at least once | Warning |
| Balance | CV of frequencies < 0.2 | Warning |
| D-efficiency | Score > 0.80 | Warning |
| Items per task | Matches design_settings | Fatal |

### 7.3 Data Validation

| Rule | Check | Error Level |
|------|-------|-------------|
| Required columns | All mapped columns exist | Fatal |
| Respondent ID | No missing IDs | Fatal |
| Version match | All versions in design | Fatal |
| Valid choices | Best/worst are valid Item_IDs or positions | Fatal |
| Choice in shown | Chosen items were displayed | Fatal |
| No same choice | Best ≠ worst in same task | Warning |
| Weights positive | All weights > 0 | Warning |

---

## 8. Error Handling

### 8.1 Error Hierarchy

```
tryCatch(
  {
    # Main operation
  },
  error = function(e) {
    # Log error with context
    # Return graceful failure or re-throw
  },
  warning = function(w) {
    # Log warning
    # Continue execution
  }
)
```

### 8.2 Error Message Format

All error messages follow this format:

```
{Component} error: {Brief description}
  Context: {Relevant details}
  Expected: {What was expected}
  Got: {What was received}
  Suggestion: {How to fix}
```

Example:
```
Configuration error: Invalid Item_ID in ITEMS sheet
  Context: Row 5
  Expected: Non-empty unique identifier
  Got: NA
  Suggestion: Ensure all items have unique Item_ID values
```

### 8.3 Fallback Mechanisms

| Component | Primary | Fallback |
|-----------|---------|----------|
| Logit model | survival::clogit | Simple frequency-based logit |
| HB model | cmdstanr | Empirical Bayes approximation |
| Optimal design | AlgDesign::optFederov | BALANCED design |
| Charts | ggplot2 | Skip chart generation |

---

## 9. Extending the Module

### 9.1 Adding a New Scoring Method

1. Create function in appropriate file:

```r
# In R/05_counts.R or new file

#' My Custom Score
#'
#' @param long_data Long format data
#' @param items Items data frame
#' @return Data frame with scores
compute_my_score <- function(long_data, items, ...) {
  # Implementation
}
```

2. Call from `run_maxdiff_analysis_mode()` in `00_main.R`

3. Add to output in `09_output.R`

### 9.2 Adding a New Configuration Sheet

1. Add sheet parser in `01_config.R`:

```r
parse_my_sheet <- function(df) {
  # Validation and parsing
}
```

2. Load in `load_maxdiff_config()`:

```r
if ("MY_SHEET" %in% available_sheets) {
  my_settings <- parse_my_sheet(load_config_sheet(config_path, "MY_SHEET"))
}
```

3. Add to config object and validation

### 9.3 Adding New Chart Types

1. Add function in `10_charts.R`:

```r
create_my_chart <- function(results, config) {
  ggplot(...) + ...
}
```

2. Call from `generate_maxdiff_charts()`

### 9.4 Custom Validation Rules

Add to `02_validation.R`:

```r
validate_my_rule <- function(data, config) {
  issues <- character()

  # Check condition
  if (!my_condition) {
    issues <- c(issues, "Description of issue")
  }

  list(valid = length(issues) == 0, issues = issues)
}
```

---

## 10. Performance Considerations

### 10.1 Memory Usage

| Component | Memory Driver | Optimisation |
|-----------|---------------|--------------|
| Long data | N × Tasks × Items | Sparse representation possible |
| HB individual utils | Respondents × Items × Iterations | Summarise during sampling |
| Design generation | Versions × Tasks × Iterations | Stream to disk |

### 10.2 Computation Time

Typical times for 1000 respondents, 10 items, 12 tasks:

| Component | Time | Notes |
|-----------|------|-------|
| Config loading | <1s | |
| Data reshaping | 2-5s | |
| Count scores | <1s | |
| Aggregate logit | 5-10s | |
| HB model | 5-30min | Depends on iterations |
| Output generation | 5-10s | |
| Charts | 5-15s | |

### 10.3 HB Performance Tips

1. **Reduce iterations** for exploratory analysis
2. **Use fewer chains** (2 instead of 4) for speed
3. **Parallel chains** require `cmdstanr` parallel backend
4. **Warmup ratio**: 2000 warmup / 5000 sampling is typical

### 10.4 Large Dataset Handling

For datasets > 10,000 respondents:

1. Consider aggregate logit only (skip HB)
2. Use sampling for HB (random subset)
3. Process segments sequentially
4. Increase memory limits: `options(java.parameters = "-Xmx8g")`

---

## Appendix A: Complete Function Index

| File | Function | Description |
|------|----------|-------------|
| 00_main.R | `run_maxdiff()` | Main entry point |
| 00_main.R | `run_maxdiff_design_mode()` | Design workflow |
| 00_main.R | `run_maxdiff_analysis_mode()` | Analysis workflow |
| 01_config.R | `load_maxdiff_config()` | Load configuration |
| 01_config.R | `parse_project_settings()` | Parse PROJECT_SETTINGS |
| 01_config.R | `parse_items_sheet()` | Parse ITEMS |
| 01_config.R | `parse_design_settings()` | Parse DESIGN_SETTINGS |
| 01_config.R | `parse_survey_mapping()` | Parse SURVEY_MAPPING |
| 01_config.R | `parse_segment_settings()` | Parse SEGMENT_SETTINGS |
| 01_config.R | `parse_output_settings()` | Parse OUTPUT_SETTINGS |
| 02_validation.R | `validate_design()` | Validate design quality |
| 02_validation.R | `validate_survey_data()` | Validate survey data |
| 03_data.R | `load_survey_data()` | Load Excel data |
| 03_data.R | `load_design_file()` | Load design file |
| 03_data.R | `build_maxdiff_long()` | Reshape to long format |
| 04_design.R | `generate_maxdiff_design()` | Generate design |
| 05_counts.R | `compute_maxdiff_counts()` | Count-based scores |
| 06_logit.R | `fit_aggregate_logit()` | Aggregate logit |
| 06_logit.R | `fit_simple_logit()` | Fallback logit |
| 07_hb.R | `fit_hb_model()` | HB via Stan |
| 07_hb.R | `fit_approximate_hb()` | Empirical Bayes fallback |
| 08_segments.R | `compute_segment_scores()` | Segment analysis |
| 09_output.R | `generate_maxdiff_output()` | Excel output |
| 10_charts.R | `generate_maxdiff_charts()` | All charts |
| utils.R | `validate_file_path()` | Path validation |
| utils.R | `safe_integer()` | Safe type conversion |
| utils.R | `parse_yes_no()` | Boolean parsing |

---

## Appendix B: Configuration Schema

Complete JSON schema for configuration validation available on request.

---

*End of Technical Reference*
