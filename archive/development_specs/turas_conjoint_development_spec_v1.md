# Turas Conjoint & MaxDiff Analysis Module
## Development Specification v1.0

---

## 1. Executive Summary

### 1.1 Purpose
Build a durable, config-driven R module for conducting MaxDiff and conjoint analysis that:
- Operates without R coding for each project
- Uses Excel-based configuration for ease of use
- Provides robust validation and quality checks
- Handles data primarily from Alchemer surveys
- Outputs professional, client-ready results to Excel
- Supports diverse industry clients and study types

### 1.2 Design Philosophy
- **Config-driven, not code-driven**: All project-specific settings in Excel config files
- **Template-based workflow**: Copy template → customize → run
- **Validation-first**: Catch data issues before analysis
- **Multi-package validation**: Cross-check results for reliability
- **Modular architecture**: Easy to maintain and extend

### 1.3 Primary Use Case
Business analyst with intermediate R knowledge needs to deliver professional conjoint/MaxDiff analysis services to clients across various industries without writing custom code for each project.

---

## 2. System Architecture

### 2.1 Directory Structure
```
turas_analysis_module/
├── R/
│   ├── import.R              # Data import functions
│   ├── validate.R            # Data quality validation
│   ├── transform.R           # Data transformation (wide/long)
│   ├── estimate_conjoint.R   # Conjoint estimation
│   ├── estimate_maxdiff.R    # MaxDiff estimation
│   ├── simulate.R            # Market simulation
│   ├── export.R              # Excel output generation
│   ├── utils.R               # Helper functions
│   └── main.R                # Main orchestration
├── templates/
│   ├── config_maxdiff_features.xlsx
│   ├── config_maxdiff_messaging.xlsx
│   ├── config_conjoint_basic.xlsx
│   ├── config_conjoint_price.xlsx
│   └── README.md
├── validation_rules/
│   └── default_rules.R
├── tests/
│   └── test_data/
├── docs/
│   └── user_guide.md
└── run_analysis.R            # Main entry point (never changes)
```

### 2.2 Workflow
```
User copies template → Edits config.xlsx → Adds data.xlsx 
    → Runs run_analysis.R → Reviews validation_report.html 
    → Gets results.xlsx
```

---

## 3. Configuration System

### 3.1 Config.xlsx Structure

All project settings controlled via Excel workbook with multiple sheets:

#### Sheet 1: "Project"
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| project_name | Unique project identifier | Client_ProductLaunch_2025 | Yes |
| study_type | Analysis type | maxdiff, conjoint | Yes |
| analyst_name | Person running analysis | Duncan | No |
| date | Analysis date | 2025-11-18 | Auto |
| client_name | Client organization | Acme Corp | No |
| notes | Project description | Feature prioritization for new app | No |

#### Sheet 2: "Data"
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| data_file | Input filename | data.xlsx | Yes |
| data_sheet | Sheet name in data file | Responses | Yes |
| format_type | Data source format | alchemer_wide, custom | Yes |
| respondent_id_column | Column name for IDs | ResponseID | Yes |
| starting_row | First data row | 2 | Yes |
| design_specification | How design is specified | explicit, embedded, none | Yes |
| design_matrix_file | Separate design file | design.xlsx | If explicit |
| design_matrix_sheet | Sheet name | Design | If explicit |
| has_holdout_tasks | Include holdout validation | TRUE, FALSE | No |
| holdout_task_numbers | Which tasks are holdout | 9,10 | If has_holdout |

#### Sheet 3a: "Attributes" (for Conjoint)
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| attribute_name | Attribute label | Price | Yes |
| attribute_type | Data type | categorical, continuous, ordinal | Yes |
| levels | Comma-separated levels | 10,15,20,25,30 | Yes |
| reference_level | Base level for coding | 10 | For categorical |
| include | Include in analysis | TRUE, FALSE | Yes |
| interaction_with | Attribute for interaction | Brand | No |

#### Sheet 3b: "Items" (for MaxDiff)
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| item_id | Unique identifier | F001 | Yes |
| item_name | Item text | Fast delivery | Yes |
| item_category | Optional grouping | Service | No |
| include | Include in analysis | TRUE, FALSE | Yes |

#### Sheet 4: "Model"
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| model_type | Estimation method | hierarchical_bayes, mnl, mixed_logit | Yes |
| primary_package | R package to use | bayesm, mlogit | Yes |
| iterations | MCMC iterations | 50000 | For HB |
| burnin | Burn-in iterations | 25000 | For HB |
| keep_every | Thinning interval | 5 | For HB |
| run_mnl_comparison | Validation check | TRUE, FALSE | No |
| convergence_diagnostics | Run diagnostics | TRUE, FALSE | Yes |
| include_none_option | "None" alternative | TRUE, FALSE | For conjoint |

#### Sheet 5: "MaxDiff_Options" (if study_type = maxdiff)
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| items_per_task | Items shown per task | 4 | Yes |
| total_tasks | Tasks per respondent | 10 | Yes |
| analysis_type | Best only or best-worst | best_worst, best_only | Yes |
| scaling_method | Score scaling | zero_centered, ratio, logit | Yes |
| anchor_item | Fixed reference item | None | No |

#### Sheet 6: "Analysis"
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| utility_estimation | Calculate utilities | TRUE | Yes |
| importance_scores | Calculate importance | TRUE | Yes |
| market_simulation | Run simulator | TRUE, FALSE | No |
| simulation_source | Where scenarios defined | config_sheet, separate_file | If TRUE |
| wtp_calculation | Willingness to pay | TRUE, FALSE | For conjoint |
| wtp_relative_to | Price attribute name | Price | If wtp=TRUE |
| holdout_validation | Validate on holdout | TRUE, FALSE | No |
| segmentation | Latent class analysis | FALSE | Phase 2 |
| calculate_reach | TURF analysis | FALSE | Phase 2 |

#### Sheet 7: "Simulation_Scenarios" (optional, for conjoint)
Defines product profiles for market simulation

| scenario_name | Price | Brand | Features | Warranty | [other attributes...] |
|---------------|-------|-------|----------|----------|---------------------|
| Current_Product | 20 | BrandA | Standard | 2yr | ... |
| Competitor_1 | 18 | BrandB | Standard | 1yr | ... |
| New_Concept | 22 | BrandA | Premium | 3yr | ... |

#### Sheet 8: "Output"
| Column | Description | Example | Required |
|--------|-------------|---------|----------|
| output_file | Results filename | results.xlsx | Yes |
| output_directory | Where to save | output/ | Yes |
| include_charts | Generate charts | TRUE, FALSE | No |
| chart_format | Chart type | png, pdf | If charts=TRUE |
| include_individual_utilities | Individual-level results | FALSE | No |
| report_type | Report detail level | executive, technical, both | Yes |
| decimal_places | Rounding | 2 | No |
| include_validation_sheet | Add validation tab | TRUE | Yes |

#### Sheet 9: "Validation_Rules"
Defines quality checks to perform

| rule_name | check_type | threshold | action |
|-----------|------------|-----------|--------|
| min_respondents | count | 100 | warning |
| min_respondents_critical | count | 50 | error |
| completion_rate | percentage | 80 | warning |
| response_time_min_seconds | seconds | 120 | flag_respondent |
| response_time_max_seconds | seconds | 3600 | flag_respondent |
| straightlining_threshold | percentage | 90 | flag_respondent |
| design_balance_overall | chi_square_p | 0.05 | error |
| design_balance_ratio | ratio | 3 | warning |
| level_min_appearance | count | 10 | error |
| attribute_correlation_max | correlation | 0.3 | warning |
| utility_sign_agreement | percentage | 100 | error |
| importance_concentration | percentage | 60 | warning |
| none_option_frequency | percentage | 50 | flag |

#### Sheet 10: "Documentation"
Reference sheet with allowed values and descriptions (not read by code, just for user)

---

## 4. Data Import Module

### 4.1 Requirements

**Function**: `import_data(config)`

**Responsibilities:**
- Read data from Excel or CSV files
- Handle multiple format types (Alchemer, Qualtrics, custom)
- Parse column naming patterns
- Handle encoding issues (UTF-8, Latin-1)
- Strip Excel formatting artifacts
- Return standardized data frame

**Inputs:**
- config: List containing config$data settings

**Outputs:**
- data: Standardized data frame with columns:
  - respondent_id
  - task_id
  - alternative_id (for conjoint) or item_id (for MaxDiff)
  - choice (binary or categorical)
  - attribute columns (for conjoint)
  - best_choice, worst_choice (for MaxDiff)
  - Any covariate columns

### 4.2 Format Parsers

#### 4.2.1 Alchemer Wide Format Parser
```
Expected column pattern examples:
- Q5_Task1_Alt1_Price
- Q5_Task1_Alt1_Brand  
- Q5_Task1_Choice

Parser should:
- Use regex to extract: task number, alternative number, attribute name
- Pivot to long format
- Match choices to alternatives
- Handle missing/partial responses
```

#### 4.2.2 Custom Format Parser
```
User specifies in config:
- task_column_pattern: "Task(\\d+)"
- alternative_column_pattern: "Alt(\\d+)"  
- attribute_names: manual list
- choice_column_pattern: "Choice(\\d+)"

Parser applies patterns flexibly
```

### 4.3 Design Matrix Import

**Function**: `import_design_matrix(config)`

**Two modes:**

**Mode 1: Explicit design matrix**
- Read separate file with exact profiles shown
- Columns: respondent_id, task_id, alternative_id, [attribute columns]
- Must match response data dimensions

**Mode 2: Embedded in response data**
- Design encoded in same file as responses
- Parse from attribute columns

**Mode 3: None (assumed balanced)**
- Generate orthogonal design programmatically
- WARNING: Only use if confirmed balanced

**Output:** Design data frame matching response structure

### 4.4 Error Handling

**Must detect and handle:**
- File not found
- Sheet not found
- Column name mismatches
- Data type mismatches (expected numeric, got text)
- Encoding issues (display sample of problem characters)
- Date auto-conversion artifacts
- Merged cells
- Hidden rows/columns containing data
- Inconsistent row lengths

**Return detailed error messages:**
```
ERROR in import_data():
  File: data.xlsx
  Issue: Column 'ResponseID' not found in sheet 'Responses'
  Available columns: [list first 10]
  Action: Check config$data$respondent_id_column setting
```

---

## 5. Data Validation Module

### 5.1 Requirements

**Function**: `validate_data(data, design, config)`

**Purpose:** Catch data quality issues before analysis runs

**Outputs:**
- validation_results: List with pass/fail for each check
- validation_report.html: Human-readable report
- flagged_respondents.csv: List of problematic respondents

### 5.2 Validation Checks

#### 5.2.1 Sample Size Checks
```r
check_sample_size <- function(data, rules) {
  n_respondents <- length(unique(data$respondent_id))
  
  if (n_respondents < rules$min_respondents_critical) {
    return(list(status = "ERROR", 
                message = paste("Only", n_respondents, "respondents")))
  }
  
  if (n_respondents < rules$min_respondents) {
    return(list(status = "WARNING",
                message = paste("Low sample:", n_respondents)))
  }
  
  return(list(status = "PASS"))
}
```

#### 5.2.2 Response Quality Checks
```
For each respondent, check:
- Completion rate (% of tasks completed)
- Response time (if available)
- Straightlining (chose same alternative X% of time)
- Variance (any variation in choices)
- None-option overuse (if applicable)
- Prior ownership/usage data compatibility

Flag respondents exceeding thresholds
```

#### 5.2.3 Design Balance Checks

**Overall level frequency:**
```r
check_design_balance <- function(design, rules) {
  # Count appearances of each level
  for (attribute in attributes) {
    level_counts <- table(design[[attribute]])
    
    # Chi-square test for balance
    chi_test <- chisq.test(level_counts)
    
    if (chi_test$p.value < rules$design_balance_pvalue) {
      # Check ratio of max/min
      ratio <- max(level_counts) / min(level_counts)
      
      if (ratio > rules$design_balance_ratio) {
        return(list(status = "ERROR",
                    attribute = attribute,
                    ratio = ratio,
                    counts = level_counts))
      }
    }
  }
}
```

**Within-respondent balance:**
```r
# Each respondent should see balanced exposure
for (resp_id in unique(respondent_ids)) {
  resp_design <- filter(design, respondent_id == resp_id)
  # Check variance in level appearances
  # Flag if CV > threshold
}
```

**Attribute correlation check:**
```r
# Check if attributes are confounded
for (attr1 in attributes) {
  for (attr2 in attributes) {
    if (attr1 != attr2) {
      correlation <- cor(as.numeric(factor(design[[attr1]])),
                        as.numeric(factor(design[[attr2]])))
      if (abs(correlation) > rules$max_correlation) {
        # FLAG: attr1 and attr2 are confounded
      }
    }
  }
}
```

#### 5.2.4 Data Structure Checks
```
- Each respondent has expected number of tasks
- Each task has expected number of alternatives
- Exactly one choice per task (or handle "none")
- No missing values in required fields
- All attribute levels in data match config
- All respondent IDs in response data exist in design matrix
```

#### 5.2.5 Holdout Task Validation
```
If config$data$has_holdout_tasks:
- Confirm holdout tasks are not included in estimation data
- Check holdout tasks have same structure
- Verify sufficient holdout sample size
```

### 5.3 Validation Report Output

**Generate HTML report with sections:**
1. Executive Summary (PASS/WARNING/ERROR counts)
2. Sample Characteristics
   - N respondents
   - N tasks per respondent
   - N alternatives per task
   - Completion rate
3. Design Balance
   - Level frequency tables
   - Balance test results
   - Correlation matrix
4. Response Quality
   - Distribution of response times
   - Straightlining detection
   - Flagged respondents table
5. Data Structure
   - Missing data patterns
   - Unexpected values
6. Recommendations
   - List of actions needed
   - Whether safe to proceed

**Severity levels:**
- ✓ PASS: No issues
- ⚠ WARNING: Proceed with caution, document in client report
- ✗ ERROR: Must fix before analysis

### 5.4 Stopping Rules

```r
validate_and_proceed <- function(validation_results) {
  if (validation_results$error_count > 0) {
    cat("\n=== VALIDATION FAILED ===\n")
    cat("Critical errors detected. Analysis cannot proceed.\n")
    cat("Review validation_report.html for details.\n\n")
    stop("Fix data issues and re-run.")
  }
  
  if (validation_results$warning_count > 0) {
    cat("\n=== VALIDATION WARNINGS ===\n")
    cat(validation_results$warning_count, "warnings detected.\n")
    cat("Review validation_report.html\n")
    cat("\nProceed anyway? (yes/no): ")
    
    response <- readline()
    if (tolower(response) != "yes") {
      stop("Analysis cancelled by user.")
    }
  }
  
  cat("✓ Validation passed. Proceeding with analysis...\n\n")
}
```

---

## 6. Data Transformation Module

### 6.1 Requirements

**Function**: `transform_to_long(data, design, config)`

**Purpose:** Convert imported data to format required by estimation packages

### 6.2 Transformations

#### 6.2.1 Wide to Long Conversion
```
Input (wide):
  resp_id | Task1_Alt1_Price | Task1_Alt1_Brand | Task1_Alt2_Price | Task1_Alt2_Brand | Task1_Choice
  001     | 20               | A                | 15               | B                | 2

Output (long):
  resp_id | task | alt | Price | Brand | choice
  001     | 1    | 1   | 20    | A     | 0
  001     | 1    | 2   | 15    | B     | 1
```

#### 6.2.2 MaxDiff Transformation
```
Convert best/worst to paired comparisons or choice format

Input:
  resp_id | task | items_shown | best | worst
  001     | 1    | A,B,C,D     | B    | D

Output (depends on estimation method):
  resp_id | task | item | choice_type | selected
  001     | 1    | A    | best        | 0
  001     | 1    | B    | best        | 1
  001     | 1    | C    | best        | 0
  001     | 1    | D    | best        | 0
  001     | 1    | A    | worst       | 0
  001     | 1    | B    | worst       | 0
  001     | 1    | C    | worst       | 0
  001     | 1    | D    | worst       | 1
```

#### 6.2.3 Attribute Coding

**Categorical variables:**
- Effects coding (reference level = -1) [DEFAULT]
- Dummy coding (reference level = 0)
- Orthogonal coding

**Continuous variables:**
- Mean-centered [DEFAULT]
- Standardized (z-score)
- Log-transformed
- As-is

**Ordinal variables:**
- Linear coding (1, 2, 3...)
- Custom scores from config

### 6.3 Data Format for Estimation

**Output data structure for mlogit:**
```r
data_mlogit <- dfidx(data_long, 
                      idx = c("resp_id", "task"),
                      choice = "choice",
                      varying = attribute_columns)
```

**Output data structure for bayesm:**
```r
# List format required by bayesm
lgtdata <- list()
for (resp in unique(respondent_ids)) {
  resp_data <- filter(data_long, resp_id == resp)
  
  lgtdata[[resp]] <- list(
    y = resp_data$choice,  # Choices
    X = as.matrix(resp_data[, attribute_columns])  # Design matrix
  )
}
```

---

## 7. Estimation Module - Conjoint

### 7.1 Model Types

#### 7.1.1 Multinomial Logit (MNL)

**Package:** mlogit

**Function:** `estimate_mnl(data, config)`

**Purpose:** 
- Fast aggregate-level estimation
- Validation check against HB results
- Sufficient for some client needs

**Implementation:**
```r
estimate_mnl <- function(data, config) {
  # Prepare data
  data_mlogit <- prepare_for_mlogit(data)
  
  # Build formula from config attributes
  formula <- build_formula(config$attributes)
  
  # Estimate model
  model <- mlogit(formula, data = data_mlogit)
  
  # Extract results
  results <- list(
    coefficients = coef(model),
    standard_errors = sqrt(diag(vcov(model))),
    loglikelihood = logLik(model),
    aic = AIC(model),
    bic = BIC(model),
    fitted_model = model
  )
  
  return(results)
}
```

**Outputs:**
- Aggregate part-worth utilities
- Standard errors
- Model fit statistics
- Predicted choice probabilities

#### 7.1.2 Hierarchical Bayes (HB)

**Package:** bayesm (primary), RSGHB (backup)

**Function:** `estimate_hb(data, config)`

**Purpose:**
- Individual-level utilities
- Industry-standard approach
- More realistic heterogeneity modeling

**Implementation:**
```r
estimate_hb <- function(data, config) {
  # Prepare data in bayesm format
  lgtdata <- prepare_for_bayesm(data, config)
  
  # Set up prior
  Prior <- list(
    ncomp = 1  # Number of mixture components
  )
  
  # MCMC settings from config
  Mcmc <- list(
    R = config$model$iterations,
    keep = config$model$keep_every
  )
  
  # Estimate
  cat("Running Hierarchical Bayes estimation...\n")
  cat("Iterations:", config$model$iterations, "\n")
  cat("This may take several minutes.\n\n")
  
  out <- rhierMnlRwMixture(
    Data = list(lgtdata = lgtdata, p = ncol(lgtdata[[1]]$X)),
    Prior = Prior,
    Mcmc = Mcmc
  )
  
  # Extract individual-level utilities (post burn-in)
  burnin <- config$model$burnin / config$model$keep_every
  betadraw <- out$betadraw[, , -(1:burnin)]
  
  # Calculate posterior means for each individual
  individual_utilities <- apply(betadraw, c(1,2), mean)
  
  # Calculate aggregate (population mean)
  aggregate_utilities <- colMeans(individual_utilities)
  
  results <- list(
    aggregate_utilities = aggregate_utilities,
    individual_utilities = individual_utilities,
    posterior_draws = betadraw,
    convergence_diagnostics = calculate_convergence(betadraw),
    fitted_model = out
  )
  
  return(results)
}
```

**Convergence Diagnostics:**
```r
calculate_convergence <- function(draws) {
  # Geweke diagnostic
  geweke <- coda::geweke.diag(as.mcmc(draws))
  
  # Effective sample size
  ess <- coda::effectiveSize(as.mcmc(draws))
  
  # Trace plot data
  trace_data <- prepare_trace_plots(draws)
  
  list(
    geweke_z = geweke$z,
    effective_sample_size = ess,
    trace_data = trace_data,
    passed = all(abs(geweke$z) < 2) & all(ess > 1000)
  )
}
```

#### 7.1.3 Mixed Logit (Phase 2)

**Package:** gmnl

**Purpose:** Random parameters without full HB machinery

### 7.2 Cross-Validation Strategy

**Function:** `run_with_validation(data, config)`

```r
run_with_validation <- function(data, config) {
  results <- list()
  
  # Always run MNL for comparison
  cat("Step 1/2: Running MNL model...\n")
  results$mnl <- estimate_mnl(data, config)
  
  # Run primary model
  if (config$model$model_type == "hierarchical_bayes") {
    cat("Step 2/2: Running Hierarchical Bayes model...\n")
    results$hb <- estimate_hb(data, config)
    
    # Compare results
    results$comparison <- compare_mnl_hb(results$mnl, results$hb, config)
    
    # Flag if signs disagree
    if (results$comparison$sign_disagreement) {
      warning("MNL and HB utility signs disagree. Review results carefully.")
    }
  }
  
  return(results)
}
```

**Comparison checks:**
```r
compare_mnl_hb <- function(mnl_results, hb_results, config) {
  mnl_coef <- mnl_results$coefficients
  hb_coef <- hb_results$aggregate_utilities
  
  # Check sign agreement
  signs_agree <- sign(mnl_coef) == sign(hb_coef)
  
  # Check magnitude correlation
  magnitude_cor <- cor(abs(mnl_coef), abs(hb_coef))
  
  list(
    sign_disagreement = !all(signs_agree),
    disagreement_attributes = names(mnl_coef)[!signs_agree],
    magnitude_correlation = magnitude_cor,
    passed = all(signs_agree) & magnitude_cor > 0.7
  )
}
```

### 7.3 Utility Calculations

**Function:** `calculate_utilities(estimation_results, config)`

**Part-worth utilities:**
- Raw coefficients from estimation
- By attribute level

**Attribute importance:**
```r
calculate_importance <- function(utilities, config) {
  importance <- list()
  
  for (attr in config$attributes$attribute_name) {
    # Get levels for this attribute
    levels <- get_levels(attr, config)
    level_utils <- utilities[levels]
    
    # Range method
    importance[[attr]] <- max(level_utils) - min(level_utils)
  }
  
  # Normalize to percentages
  total <- sum(unlist(importance))
  importance_pct <- lapply(importance, function(x) 100 * x / total)
  
  return(importance_pct)
}
```

**Willingness to Pay (if requested):**
```r
calculate_wtp <- function(utilities, price_attribute, config) {
  price_coef <- utilities[[price_attribute]]
  
  wtp <- list()
  for (attr in names(utilities)) {
    if (attr != price_attribute) {
      # WTP = utility / |price coefficient|
      wtp[[attr]] <- utilities[[attr]] / abs(price_coef)
    }
  }
  
  return(wtp)
}
```

### 7.4 Holdout Validation

**Function:** `validate_on_holdout(model, holdout_data, config)`

```r
validate_on_holdout <- function(model, holdout_data, config) {
  # Predict choices on holdout tasks
  predictions <- predict(model, newdata = holdout_data)
  
  # Calculate hit rate
  predicted_choices <- apply(predictions, 1, which.max)
  actual_choices <- holdout_data$choice
  
  hit_rate <- mean(predicted_choices == actual_choices)
  
  # First choice hit rate (selected alternative predicted as #1)
  first_choice_correct <- sum(predicted_choices == actual_choices & 
                               actual_choices == 1) / sum(actual_choices == 1)
  
  list(
    hit_rate = hit_rate,
    first_choice_hit_rate = first_choice_correct,
    n_holdout_tasks = nrow(holdout_data),
    passed = hit_rate > 0.3  # Typical threshold
  )
}
```

---

## 8. Estimation Module - MaxDiff

### 8.1 Model Estimation

**Function:** `estimate_maxdiff(data, config)`

**Approach:** MaxDiff is multinomial logit with items as "attributes"

```r
estimate_maxdiff <- function(data, config) {
  # Transform best/worst to choice format
  choice_data <- transform_maxdiff_to_choices(data, config)
  
  if (config$model$model_type == "hierarchical_bayes") {
    results <- estimate_maxdiff_hb(choice_data, config)
  } else {
    results <- estimate_maxdiff_mnl(choice_data, config)
  }
  
  # Convert utilities to preference scores
  results$preference_scores <- calculate_preference_scores(
    results$utilities, 
    config$maxdiff$scaling_method
  )
  
  return(results)
}
```

### 8.2 Preference Score Calculation

**Zero-centered scaling (default):**
```r
# Force mean = 0, sum = 0
scores <- utilities - mean(utilities)
```

**Ratio scaling:**
```r
# Transform to 0-100 scale
scores <- 100 * (utilities - min(utilities)) / (max(utilities) - min(utilities))
```

**Logit scaling:**
```r
# Probability-based scores
scores <- exp(utilities) / sum(exp(utilities)) * 100
```

### 8.3 Output Format

**Ranked list with scores:**
```
Rank | Item | Preference Score | Std Error | 95% CI
-----|------|------------------|-----------|--------
1    | Fast delivery | 45.2 | 2.1 | [41.1, 49.3]
2    | Low price | 32.8 | 1.9 | [29.1, 36.5]
3    | High quality | 28.4 | 1.8 | [24.9, 31.9]
...
```

---

## 9. Market Simulation Module

### 9.1 Requirements

**Function:** `run_market_simulation(utilities, scenarios, config)`

**Purpose:** Predict market share for product configurations

### 9.2 Simulation Logic

```r
run_market_simulation <- function(utilities, scenarios, config) {
  # For each scenario (product configuration)
  # Calculate utility for each individual
  # Apply choice rule (logit)
  # Aggregate to market shares
  
  results <- list()
  
  for (scenario_name in scenarios$scenario_name) {
    scenario_profile <- scenarios[scenarios$scenario_name == scenario_name, ]
    
    # Calculate utility for each respondent
    individual_utils <- calculate_scenario_utility(
      scenario_profile, 
      utilities$individual_utilities,
      config
    )
    
    results[[scenario_name]] <- list(
      mean_utility = mean(individual_utils),
      sd_utility = sd(individual_utils),
      profile = scenario_profile
    )
  }
  
  # Calculate share of preference
  shares <- calculate_shares(results)
  
  return(list(
    scenario_results = results,
    predicted_shares = shares
  ))
}
```

**Share calculation (logit rule):**
```r
calculate_shares <- function(scenario_results) {
  # Get utilities for all scenarios
  utils <- sapply(scenario_results, function(x) x$mean_utility)
  
  # Logit choice probabilities
  exp_utils <- exp(utils)
  shares <- exp_utils / sum(exp_utils)
  
  # Convert to percentages
  shares_pct <- 100 * shares
  
  return(shares_pct)
}
```

### 9.3 Sensitivity Analysis

**Function:** `run_sensitivity_analysis(utilities, base_scenario, attribute, config)`

```r
# Vary one attribute while holding others constant
# Show how share changes with price, features, etc.

run_sensitivity_analysis <- function(utilities, base_scenario, attribute, config) {
  levels <- get_attribute_levels(attribute, config)
  
  results <- list()
  for (level in levels) {
    modified_scenario <- base_scenario
    modified_scenario[[attribute]] <- level
    
    share <- calculate_single_scenario_share(modified_scenario, utilities)
    results[[level]] <- share
  }
  
  return(data.frame(
    level = levels,
    predicted_share = unlist(results)
  ))
}
```

---

## 10. Excel Export Module

### 10.1 Requirements

**Function:** `export_results(results, config)`

**Purpose:** Create professional, formatted Excel workbook with all outputs

### 10.2 Excel Workbook Structure

#### Sheet 1: "Summary"
Executive-level overview
- Project name, date, analyst
- Sample size, model type
- Key findings (top 3 attributes by importance)
- Model fit statistics
- Validation checks passed/failed

#### Sheet 2: "Utilities"
**For Conjoint:**
| Attribute | Level | Utility | Std Error | Importance (%) |
|-----------|-------|---------|-----------|----------------|
| Price | $10 | 0.85 | 0.12 | 35% |
| Price | $15 | 0.42 | 0.10 | |
| Price | $20 | 0.00 | -- | (reference) |
| Brand | A | 0.35 | 0.09 | 22% |
| Brand | B | -0.15 | 0.11 | |
...

**For MaxDiff:**
| Rank | Item | Preference Score | Std Error | 95% CI |
|------|------|------------------|-----------|--------|
| 1 | Fast delivery | 45.2 | 2.1 | [41.1, 49.3] |
...

#### Sheet 3: "Importance"
Attribute importance chart data
| Attribute | Importance (%) |
|-----------|----------------|
| Price | 35.2 |
| Brand | 24.8 |
| Features | 22.5 |
| Warranty | 17.5 |

#### Sheet 4: "Market_Simulation"
Scenario comparison results
| Scenario | Product Profile | Predicted Share (%) | Mean Utility |
|----------|-----------------|---------------------|--------------|
| Current | Price=$20, Brand=A, ... | 28.5 | 1.24 |
| Competitor_1 | Price=$18, Brand=B, ... | 32.1 | 1.45 |
| New_Concept | Price=$22, Brand=A, ... | 39.4 | 1.82 |

#### Sheet 5: "WTP" (if calculated)
Willingness to pay estimates
| Attribute | Level | WTP vs Reference | 95% CI |
|-----------|-------|------------------|--------|
| Brand | A vs B | $3.50 | [$2.10, $4.90] |
| Features | Premium vs Basic | $5.25 | [$3.80, $6.70] |

#### Sheet 6: "Validation"
Copy of validation checks
- All checks performed
- Pass/warning/error status
- Details of any issues

#### Sheet 7: "Model_Diagnostics"
Technical details
- Convergence statistics (for HB)
- Holdout validation results
- MNL vs HB comparison
- Effective sample sizes

#### Sheet 8: "Individual_Utilities" (optional)
If config$output$include_individual_utilities = TRUE
| Respondent_ID | Attr1_Level1 | Attr1_Level2 | ... |
|---------------|--------------|--------------|-----|
| 001 | 0.92 | 0.45 | ... |
| 002 | 1.15 | 0.38 | ... |

**Warning in output:** "Individual-level results are for internal use only. Ensure proper data privacy protocols."

#### Sheet 9: "Analysis_Log"
Complete record of analysis
```
Project: Client_ProductLaunch_2025
Date: 2025-11-18 14:35:22
Analyst: Duncan
Model: Hierarchical Bayes (bayesm)
Iterations: 50000
Burn-in: 25000
Sample size: 342 respondents
Validation: PASSED (2 warnings)
Run time: 8.4 minutes
```

### 10.3 Formatting

**Use openxlsx for rich formatting:**
```r
library(openxlsx)

export_results <- function(results, config) {
  wb <- createWorkbook()
  
  # Add sheets
  addWorksheet(wb, "Summary")
  addWorksheet(wb, "Utilities")
  # ... etc
  
  # Format headers
  headerStyle <- createStyle(
    fontSize = 12,
    fontColour = "#FFFFFF",
    halign = "center",
    fgFill = "#4F81BD",
    border = "TopBottom",
    borderColour = "#4F81BD",
    textDecoration = "bold"
  )
  
  # Write and format Summary sheet
  writeData(wb, "Summary", summary_data, headerStyle = headerStyle)
  
  # Add conditional formatting for validation checks
  conditionalFormatting(
    wb, "Validation",
    cols = 3,
    rows = 2:100,
    rule = "PASS",
    style = createStyle(fontColour = "#006100", bgFill = "#C6EFCE")
  )
  
  # Save
  output_path <- file.path(config$output$output_directory, 
                           config$output$output_file)
  saveWorkbook(wb, output_path, overwrite = TRUE)
  
  cat("✓ Results exported to:", output_path, "\n")
}
```

### 10.4 Chart Generation (if requested)

**Generate PNG/PDF charts:**
- Attribute importance (horizontal bar chart)
- Utility plots by attribute
- Market share comparison (bar chart)
- Sensitivity analysis (line chart)

**Embed in Excel or save separately based on config**

---

## 11. Main Orchestration Script

### 11.1 run_analysis.R

**This script never changes. User only edits config.xlsx**

```r
#!/usr/bin/env Rscript

# Turas Analysis Module - Main Entry Point
# Version 1.0
# Do not modify this file - configure via config.xlsx

# Load module functions
source("R/utils.R")
source("R/import.R")
source("R/validate.R")
source("R/transform.R")
source("R/estimate_conjoint.R")
source("R/estimate_maxdiff.R")
source("R/simulate.R")
source("R/export.R")

# Main function
main <- function() {
  cat("\n")
  cat("╔════════════════════════════════════════╗\n")
  cat("║  Turas Conjoint & MaxDiff Analysis    ║\n")
  cat("║  Version 1.0                          ║\n")
  cat("╚════════════════════════════════════════╝\n")
  cat("\n")
  
  # Step 1: Read configuration
  cat("→ Reading configuration...\n")
  config <- read_config("config.xlsx")
  cat("  Project:", config$project$project_name, "\n")
  cat("  Study type:", config$study_type, "\n")
  cat("  Model:", config$model$model_type, "\n\n")
  
  # Step 2: Import data
  cat("→ Importing data...\n")
  data <- import_data(config)
  cat("  Loaded", nrow(data), "responses\n")
  cat("  From", length(unique(data$respondent_id)), "respondents\n\n")
  
  # Step 3: Import design matrix (if applicable)
  if (config$data$design_specification == "explicit") {
    cat("→ Importing design matrix...\n")
    design <- import_design_matrix(config)
    cat("  Loaded design for", length(unique(design$respondent_id)), 
        "respondents\n\n")
  } else {
    design <- extract_design_from_data(data, config)
  }
  
  # Step 4: Validate data
  cat("→ Validating data quality...\n")
  validation_results <- validate_data(data, design, config)
  
  # Generate validation report
  generate_validation_report(validation_results, config)
  cat("  Validation report: output/validation_report.html\n\n")
  
  # Check if should proceed
  validate_and_proceed(validation_results)
  
  # Step 5: Transform data
  cat("→ Transforming data...\n")
  data_long <- transform_to_long(data, design, config)
  cat("  Prepared", nrow(data_long), "choice observations\n\n")
  
  # Step 6: Run estimation
  cat("→ Running estimation...\n")
  
  if (config$study_type == "maxdiff") {
    results <- estimate_maxdiff(data_long, config)
  } else if (config$study_type == "conjoint") {
    results <- estimate_conjoint(data_long, config)
  }
  
  cat("  ✓ Estimation complete\n\n")
  
  # Step 7: Calculate utilities and importance
  cat("→ Calculating utilities...\n")
  utilities <- calculate_utilities(results, config)
  importance <- calculate_importance(utilities, config)
  
  if (config$analysis$wtp_calculation) {
    wtp <- calculate_wtp(utilities, config$analysis$wtp_relative_to, config)
  }
  cat("  ✓ Utilities calculated\n\n")
  
  # Step 8: Market simulation (if requested)
  if (config$analysis$market_simulation) {
    cat("→ Running market simulation...\n")
    simulation <- run_market_simulation(utilities, config)
    cat("  ✓ Simulation complete\n\n")
  }
  
  # Step 9: Holdout validation (if applicable)
  if (config$analysis$holdout_validation) {
    cat("→ Validating on holdout tasks...\n")
    holdout_results <- validate_on_holdout(results, data_long, config)
    cat("  Hit rate:", round(100 * holdout_results$hit_rate, 1), "%\n\n")
  }
  
  # Step 10: Export results
  cat("→ Exporting results...\n")
  
  export_package <- list(
    config = config,
    validation = validation_results,
    results = results,
    utilities = utilities,
    importance = importance,
    simulation = if(exists("simulation")) simulation else NULL,
    wtp = if(exists("wtp")) wtp else NULL,
    holdout = if(exists("holdout_results")) holdout_results else NULL
  )
  
  export_results(export_package, config)
  
  cat("\n")
  cat("╔════════════════════════════════════════╗\n")
  cat("║  Analysis Complete!                    ║\n")
  cat("╚════════════════════════════════════════╝\n")
  cat("\n")
  cat("Results: output/", config$output$output_file, "\n", sep="")
  cat("Validation: output/validation_report.html\n")
  cat("\n")
}

# Run
tryCatch({
  main()
}, error = function(e) {
  cat("\n✗ ERROR:", conditionMessage(e), "\n\n")
  quit(status = 1)
})
```

---

## 12. Error Handling & Logging

### 12.1 Comprehensive Error Messages

All functions should provide actionable error messages:

```r
# BAD
stop("Error in data import")

# GOOD
stop(paste(
  "ERROR in import_data():",
  "  File:", config$data$data_file,
  "  Sheet:", config$data$data_sheet,
  "  Issue: Column 'ResponseID' not found",
  "  Available columns:", paste(colnames(raw_data), collapse=", "),
  "  Action: Check config$data$respondent_id_column setting",
  sep="\n"
))
```

### 12.2 Logging

**Create analysis_log.txt with every run:**

```r
log_analysis <- function(config, results, runtime) {
  log_file <- file.path(config$output$output_directory, "analysis_log.txt")
  
  log_content <- sprintf(
    "═══════════════════════════════════════════════
Turas Analysis Module - Run Log
═══════════════════════════════════════════════

PROJECT INFORMATION
  Name: %s
  Client: %s
  Analyst: %s
  Date: %s
  
DATA
  File: %s
  Study type: %s
  Respondents: %d
  Tasks per respondent: %d
  
MODEL
  Type: %s
  Package: %s
  Iterations: %s
  
VALIDATION
  Status: %s
  Errors: %d
  Warnings: %d
  
RESULTS
  Convergence: %s
  Holdout hit rate: %s
  
SYSTEM
  R version: %s
  Run time: %.1f minutes
  
═══════════════════════════════════════════════
",
    config$project$project_name,
    config$project$client_name,
    config$project$analyst_name,
    Sys.time(),
    config$data$data_file,
    config$study_type,
    results$n_respondents,
    results$n_tasks,
    config$model$model_type,
    config$model$primary_package,
    config$model$iterations,
    results$validation_status,
    results$validation_errors,
    results$validation_warnings,
    results$convergence_status,
    if(!is.null(results$holdout_hit_rate)) 
      sprintf("%.1f%%", 100*results$holdout_hit_rate) else "N/A",
    R.version.string,
    runtime
  )
  
  writeLines(log_content, log_file)
}
```

### 12.3 Progress Indicators

**For long-running HB estimation:**

```r
library(progress)

# In estimate_hb function
pb <- progress_bar$new(
  format = "  [:bar] :percent eta: :eta",
  total = config$model$iterations,
  clear = FALSE
)

# Hook into bayesm if possible, or estimate based on iteration count
```

---

## 13. Testing Strategy

### 13.1 Test Data

**Create test datasets in tests/test_data/:**

1. **test_conjoint_balanced.xlsx**
   - Small (50 respondents, 8 tasks, 3 alternatives)
   - Perfectly balanced design
   - Known utility structure
   - Should produce expected signs and magnitudes

2. **test_conjoint_unbalanced.xlsx**
   - Same as above but with known imbalance
   - Should trigger validation warnings

3. **test_maxdiff_basic.xlsx**
   - 30 respondents, 10 tasks, 4 items per task
   - Best/worst format

4. **test_alchemer_export.xlsx**
   - Real Alchemer format with typical quirks

### 13.2 Unit Tests

**Use testthat package:**

```r
# tests/test_import.R
library(testthat)

test_that("import_data handles Alchemer format", {
  config <- read_config("tests/configs/test_config.xlsx")
  data <- import_data(config)
  
  expect_equal(length(unique(data$respondent_id)), 50)
  expect_true("task_id" %in% colnames(data))
  expect_true(all(!is.na(data$choice)))
})

test_that("import_data detects missing columns", {
  config <- read_config("tests/configs/bad_config.xlsx")
  expect_error(import_data(config), "Column.*not found")
})
```

### 13.3 Integration Tests

**Full end-to-end tests:**

```r
# tests/test_full_workflow.R

test_that("Full conjoint workflow completes", {
  # Copy test files to temp directory
  temp_dir <- tempdir()
  file.copy("tests/test_data/test_conjoint_balanced.xlsx", 
            file.path(temp_dir, "data.xlsx"))
  file.copy("tests/configs/test_config_conjoint.xlsx",
            file.path(temp_dir, "config.xlsx"))
  
  # Run analysis
  setwd(temp_dir)
  source("run_analysis.R")
  
  # Check outputs exist
  expect_true(file.exists("output/results.xlsx"))
  expect_true(file.exists("output/validation_report.html"))
  expect_true(file.exists("output/analysis_log.txt"))
  
  # Check results content
  results <- read_excel("output/results.xlsx", sheet = "Utilities")
  expect_equal(nrow(results), 10)  # Expected number of utility estimates
})
```

### 13.4 Validation Tests

**Test validation logic:**

```r
test_that("Validation catches design imbalance", {
  data <- read_test_data("test_conjoint_unbalanced.xlsx")
  config <- read_config("tests/configs/test_config.xlsx")
  design <- extract_design_from_data(data, config)
  
  validation <- validate_data(data, design, config)
  
  expect_gt(validation$warning_count, 0)
  expect_true(any(grepl("balance", validation$warnings)))
})
```

---

## 14. Documentation

### 14.1 User Guide (docs/user_guide.md)

**Sections:**
1. Quick Start
   - Installation
   - Running your first analysis
2. Project Setup
   - Creating config.xlsx
   - Preparing your data
3. Configuration Reference
   - Detailed explanation of all config options
4. Interpreting Results
   - Understanding utilities
   - Reading importance scores
   - Using market simulation
5. Troubleshooting
   - Common errors and solutions
6. Advanced Topics
   - Custom attribute coding
   - Segmentation analysis
   - Interaction effects

### 14.2 Code Documentation

**All functions should have roxygen2-style documentation:**

```r
#' Import conjoint or MaxDiff data
#'
#' Reads data from Excel or CSV files based on configuration settings.
#' Handles multiple format types including Alchemer, Qualtrics, and custom formats.
#'
#' @param config List containing configuration settings from config.xlsx
#' @return Data frame with standardized column structure
#' @examples
#' config <- read_config("config.xlsx")
#' data <- import_data(config)
#' @export
import_data <- function(config) {
  # ...
}
```

### 14.3 Template README

**In templates/README.md:**

```markdown
# Turas Analysis Templates

## Available Templates

### MaxDiff Templates
- `config_maxdiff_features.xlsx` - Feature prioritization studies
- `config_maxdiff_messaging.xlsx` - Message testing

### Conjoint Templates  
- `config_conjoint_basic.xlsx` - Basic CBC with 3-4 attributes
- `config_conjoint_price.xlsx` - Price optimization focus

## How to Use

1. Copy appropriate template to your project directory
2. Rename to `config.xlsx`
3. Edit settings for your study
4. Add your data file
5. Run `Rscript run_analysis.R`

## Customizing Templates

See docs/user_guide.md for detailed explanation of all configuration options.
```

---

## 15. Dependencies & Installation

### 15.1 Required R Packages

**Core packages:**
```r
# Estimation
mlogit          # MNL models
bayesm          # Hierarchical Bayes
gmnl            # Mixed logit (Phase 2)

# Data handling
readxl          # Excel import
openxlsx        # Excel export with formatting
dplyr           # Data manipulation
tidyr           # Data reshaping
dfidx           # Data indexing for mlogit

# Validation & diagnostics
coda            # MCMC diagnostics

# Utilities
progress        # Progress bars
logger          # Logging
```

**Optional packages:**
```r
ggplot2         # Chart generation
knitr           # Report generation
rmarkdown       # HTML reports
```

### 15.2 Installation Script

**Create install_dependencies.R:**

```r
# Turas Module - Dependency Installation

required_packages <- c(
  "mlogit",
  "bayesm",
  "readxl",
  "openxlsx",
  "dplyr",
  "tidyr",
  "dfidx",
  "coda",
  "progress"
)

optional_packages <- c(
  "ggplot2",
  "knitr",
  "rmarkdown"
)

cat("Installing required packages...\n")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
  }
  cat("✓", pkg, "\n")
}

cat("\nInstalling optional packages...\n")
for (pkg in optional_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
  }
  cat("✓", pkg, "\n")
}

cat("\n✓ All dependencies installed successfully!\n")
```

### 15.3 System Requirements

```
R version: >= 4.0.0
RAM: 8GB minimum, 16GB recommended for large studies
Disk space: 1GB for module + data
OS: Windows, macOS, or Linux
```

---

## 16. Phase 1 vs. Phase 2 Features

### 16.1 Phase 1 (MVP) - Build First

**Core functionality:**
- ✅ Excel-based configuration
- ✅ Excel/CSV data import
- ✅ Alchemer format parser
- ✅ Comprehensive data validation
- ✅ Design balance checking
- ✅ MNL estimation (mlogit)
- ✅ HB estimation (bayesm)
- ✅ MaxDiff estimation
- ✅ Cross-validation (MNL vs HB)
- ✅ Utility calculations
- ✅ Importance scores
- ✅ Basic market simulation
- ✅ WTP calculation
- ✅ Holdout validation
- ✅ Excel output with formatting
- ✅ Validation HTML reports
- ✅ Analysis logging

**Timeline:** 4-6 weeks for experienced R developers

### 16.2 Phase 2 - Add Later

**Advanced features:**
- Latent class/segmentation analysis (gmnl or poLCA)
- Interaction effects modeling
- Custom attribute constraints in simulation
- Sensitivity analysis automation
- Chart generation (ggplot2)
- Automated PowerPoint reports
- Shiny dashboard for interactive simulation
- TURF analysis (portfolio optimization)
- Longitudinal/tracking study support
- Alternative HB packages (RSGHB) integration
- Custom prior specification
- Parallel processing for faster estimation

**Timeline:** Add features as needed, 1-2 weeks each

---

## 17. Delivery & Handoff

### 17.1 Deliverables

**To development team:**
1. This specification document
2. Sample config.xlsx templates (all sheets populated)
3. Sample test data files (balanced, unbalanced, Alchemer format)
4. Expected output examples

**From development team:**
1. Complete R module code
2. All template files
3. Test suite with passing tests
4. User guide
5. Installation instructions
6. Example project demonstrating full workflow

### 17.2 Acceptance Criteria

**Module is complete when:**
1. All Phase 1 features implemented and tested
2. Can process provided test datasets successfully
3. Produces expected validation reports
4. Exports properly formatted Excel results
5. Handles all specified error conditions gracefully
6. Passes all integration tests
7. Documentation complete and clear
8. Can be run by non-developer following user guide

### 17.3 Training & Knowledge Transfer

**Developer should provide:**
- Walkthrough of code architecture
- Explanation of key functions
- How to debug common issues
- How to add new features
- Best practices for maintenance

---

## 18. Open Questions for Development Team

**To be answered before starting development:**

1. **Design matrix handling:** Should we require explicit design matrix upload, or attempt to reconstruct from response data? Recommendation: Require explicit for reliability.

2. **Package fallback:** If bayesm fails to converge, automatically try RSGHB, or fail and ask user to adjust settings? Recommendation: Fail with clear message initially.

3. **Individual utilities privacy:** Always generate but optionally export, or skip generation entirely if not requested? Recommendation: Always generate, control export.

4. **Validation strictness:** Should validation errors completely prevent analysis, or allow override with strong warning? Recommendation: Prevent for critical errors, allow override for warnings.

5. **Chart integration:** Embed charts in Excel or generate separate files? Recommendation: Separate PNG files initially, Excel embedding in Phase 2.

6. **Config validation:** Should we validate config.xlsx structure before starting analysis? Recommendation: Yes, fail fast with clear errors.

7. **Memory management:** For very large studies (>1000 respondents), should we implement chunking/streaming? Recommendation: Phase 2 optimization.

8. **Parallelization:** Should HB estimation use multiple cores automatically? Recommendation: Phase 2, single-core for Phase 1.

---

## 19. Success Metrics

**How to know the module is working:**

1. **Reliability:** Can process 95%+ of real client datasets without crashes
2. **Validation accuracy:** Catches known data issues 100% of the time
3. **Cross-validation:** MNL and HB results agree on utility signs >95% of time
4. **Speed:** HB estimation completes in <10 minutes for typical study (300 respondents, 10 tasks)
5. **Usability:** Non-R-expert can run analysis after reading user guide
6. **Reproducibility:** Same inputs always produce same outputs (within MCMC sampling error)

---

## 20. Contact & Questions

**For development questions:**
- Duncan (project owner)
- [Contact details]

**For technical R package questions:**
- bayesm: [reference documentation]
- mlogit: [reference documentation]

---

**END OF SPECIFICATION**

This specification provides complete technical requirements for Phase 1 development. Developers should clarify open questions before starting, then implement systematically with testing at each stage.
