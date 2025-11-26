# Part 1: Core Technical Specification - Turas Conjoint Analysis Module

## Overview

This specification defines a world-class conjoint analysis module for Turas that:
- Supports multiple estimation methods (mlogit, clogit, hierarchical Bayes)
- Produces statistically sophisticated, client-ready Excel outputs
- Includes an interactive market simulator
- Is designed for market researchers (non-statisticians)

## 1. Package Architecture & Dependencies

### Primary Dependencies

```r
Required:
- mlogit (>= 1.1-0)      # Primary estimation engine
- survival (>= 3.0)       # Fallback for clogit
- openxlsx (>= 4.2)      # Excel I/O
- data.table (>= 1.14)   # Fast data manipulation

Optional (for advanced features):
- ChoiceModelR           # Hierarchical Bayes
- maxLik                 # Alternative optimization
```

### Estimation Method Hierarchy

1. **Primary:** `mlogit::mlogit()` - most robust, handles complex data structures
2. **Fallback:** `survival::clogit()` - when mlogit fails (simpler datasets)
3. **Advanced:** `ChoiceModelR` - only if user explicitly requests HB and data quality permits

## 2. Core Function Specifications

### 2.1 Main Entry Point

```r
run_conjoint_analysis <- function(
  config_file,
  data_file = NULL,
  output_file = NULL,
  estimation_method = c("auto", "mlogit", "clogit", "hb"),
  baseline_handling = c("first_level_zero", "all_levels_explicit"),
  market_simulator = TRUE,
  verbose = TRUE
)
```

**Logic:**
- `estimation_method = "auto"`: Try mlogit → clogit → error
- Validate inputs before any processing
- Return structured results list + write Excel
- Include model diagnostics in output

### 2.2 Data Validation (Enhanced)

```r
validate_conjoint_data <- function(data, config) {
  
  # CRITICAL CHECKS (stop if fail):
  # 1. Each choice set has exactly 1 chosen=1
  # 2. All respondents see same # of choice sets
  # 3. Attribute levels in data match config
  # 4. No missing values in: resp_id, choice_set_id, chosen, attributes
  
  # WARNINGS (continue with caution):
  # 5. Unbalanced choice set sizes
  # 6. Low response counts per level
  # 7. Some cards never chosen
  # 8. Respondent dropout patterns
  
  # Return list with:
  # - is_valid (TRUE/FALSE)
  # - errors (character vector)
  # - warnings (character vector)
  # - diagnostics (list of descriptive stats)
}
```

### 2.3 Estimation Engine

```r
estimate_choice_model <- function(
  data,
  config,
  method = "auto",
  baseline_handling = "first_level_zero"
) {
  
  # Method selection logic:
  if (method == "auto") {
    # Try mlogit first
    result <- try_mlogit(data, config, baseline_handling)
    
    if (inherits(result, "try-error")) {
      warning("mlogit failed, falling back to clogit")
      result <- try_clogit(data, config, baseline_handling)
    }
    
    if (inherits(result, "try-error")) {
      stop("All estimation methods failed. Check data quality.")
    }
  }
  
  # Return standardized object:
  structure(list(
    method = "mlogit",  # or "clogit", "hb"
    model = model_obj,
    coefficients = coefs,
    vcov = vcov_matrix,
    loglik = c(null = ll_null, fitted = ll_fitted),
    n_obs = nrow(data),
    n_respondents = length(unique(data$resp_id)),
    n_choice_sets = length(unique(data$choice_set_id)),
    convergence = list(converged = TRUE, message = "")
  ), class = "turas_conjoint_model")
}
```

### 2.4 Utility Calculation (Improved)

```r
calculate_utilities <- function(
  model,
  config,
  baseline_handling = "first_level_zero",
  confidence_level = 0.95
) {
  
  # For each attribute:
  # 1. Extract coefficients for all levels
  # 2. Apply baseline handling
  # 3. Zero-center utilities (CRITICAL: within attribute)
  # 4. Calculate confidence intervals
  # 5. Flag non-significant levels
  
  # Return data.frame with:
  # - Attribute
  # - Level  
  # - Utility (zero-centered)
  # - SE (standard error)
  # - CI_lower, CI_upper
  # - p_value
  # - is_significant (at confidence_level)
  # - is_baseline (TRUE/FALSE)
}
```

**Zero-centering formula (CRITICAL):**
```r
# Within each attribute:
utility_centered = utility_raw - mean(utility_raw_for_attribute)

# This ensures utilities sum to 0 within attribute
# Standard in conjoint analysis
```

### 2.5 Attribute Importance (Enhanced)

```r
calculate_importance <- function(utilities, method = "range") {
  
  # Standard method: range within attribute
  # Range = max(utility) - min(utility) for each attribute
  # Importance = Range_i / sum(Range_all) * 100
  
  # IMPROVEMENTS over ChatGPT:
  # 1. Also calculate importance using utility variance
  # 2. Flag attributes with low discrimination (small range)
  # 3. Provide confidence intervals on importance
  
  # Return data.frame:
  # - Attribute
  # - Range
  # - Importance_pct (range method)
  # - Importance_variance (alternative)
  # - CI_lower, CI_upper (bootstrapped)
  # - discrimination_index (0-1 scale)
}
```

### 2.6 Model Diagnostics (NEW - better than ChatGPT)

```r
calculate_diagnostics <- function(model, data, config) {
  
  list(
    # Fit statistics
    mcfadden_r2 = 1 - (model$loglik["fitted"] / model$loglik["null"]),
    adj_mcfadden_r2 = 1 - ((model$loglik["fitted"] - n_params) / model$loglik["null"]),
    aic = AIC(model),
    bic = BIC(model),
    
    # Prediction accuracy
    hit_rate = calculate_hit_rate(model, data),
    hit_rate_by_set_size = hit_rate_by_size(model, data),
    
    # NEW: Additional diagnostics
    likelihood_ratio_test = lrtest_vs_null(model),
    
    # Attribute-level diagnostics
    attribute_significance = test_attribute_significance(model, config),
    
    # Data quality indicators
    choice_distribution = table(data$chosen),
    cards_per_respondent = mean(table(data$resp_id)),
    
    # Convergence info
    convergence = model$convergence
  )
}
```

## 3. Key Improvements Over ChatGPT Approach

### Statistical Improvements

1. **Confidence Intervals**: Add CIs for utilities and importance (bootstrap or Delta method)
2. **Significance Testing**: Flag non-significant attribute levels
3. **Model Comparison**: When multiple methods used, provide comparison table
4. **Robust Standard Errors**: Option for clustered SEs (by respondent)

### Methodological Improvements

1. **Baseline Handling**: Support both approaches, default to first_level_zero
2. **Missing Data**: Explicit handling strategy (currently fails silently)
3. **Validation**: Comprehensive pre-estimation checks
4. **Diagnostics**: More complete model evaluation

### Practical Improvements

1. **Error Messages**: Clear, actionable messages for non-statisticians
2. **Warnings**: Don't fail on warnings, but flag potential issues
3. **Documentation**: Each output includes interpretation guide
4. **Reproducibility**: Save estimation details for replication

## 4. Data Structure Specifications

### Input Data (Alchemer format)

```r
Required columns:
- resp_id (or respondent_id)        # integer
- choice_set_id                      # integer
- chosen                             # integer (0/1)
- [attribute_columns]                # factor or character

Optional:
- alternative_id                     # integer (1, 2, 3...)
- weight                            # numeric (respondent weight)

Structure:
- One row per alternative per choice set
- chosen=1 for exactly one alternative per choice set
- All respondents see same choice set structure
```

### Config File Structure (Enhanced)

```xlsx
Sheet: Settings
- analysis_type: "choice"
- estimation_method: "auto" | "mlogit" | "clogit" | "hb"
- baseline_handling: "first_level_zero" | "all_levels_explicit"
- confidence_level: 0.95
- choice_set_column: "choice_set_id"
- chosen_column: "chosen"
- respondent_id_column: "resp_id"
- data_file: "path/to/data.csv"
- output_file: "path/to/results.xlsx"
- generate_market_simulator: TRUE
- include_diagnostics: TRUE

Sheet: Attributes
- AttributeName: character
- NumLevels: integer
- LevelNames: comma-separated string
- DataType: "categorical" (for now, future: "continuous")
```

## 5. Module Structure

```r
Module: conjoint/
├── R/
│   ├── 00_main.R           # Main entry point
│   ├── 01_config.R         # Config loading & validation  
│   ├── 02_data.R           # Data loading & validation
│   ├── 03_estimation.R     # Model estimation (multiple methods)
│   ├── 04_utilities.R      # Utility calculation & importance
│   ├── 05_validation.R     # Model validation & diagnostics
│   ├── 06_simulation.R     # Market simulation capabilities
│   ├── 07_output.R         # Output generation
│   └── 99_helpers.R        # Utility functions
├── inst/
│   └── templates/
│       └── market_simulator_template.xlsx
├── tests/
│   └── test_data/
└── docs/
    └── user_guide.md
```

## 6. Implementation Priority

### MUST HAVE (Phase 1)
1. Support Alchemer CBC data format (one row per alternative)
2. Conditional logit estimation using mlogit (primary) + survival (fallback)
3. Part-worth utilities with zero-centering within attributes
4. Relative importance calculation (range method)
5. Model fit statistics (McFadden R², hit rate, AIC/BIC)
6. Excel output with formatted tables and charts
7. Comprehensive error messages and validation
8. Handle missing data gracefully
9. Support for 2-12 attributes, 2-10 levels per attribute

### SHOULD HAVE (Phase 2)
1. Confidence intervals for utilities
2. Individual-level utility estimation (HB)
3. Market simulator export functionality
4. Multiple estimation methods (user selectable)
5. Diagnostic plots
6. Cross-validation / holdout validation
7. Comparison with prohibited pairs handling

### COULD HAVE (Phase 3)
1. Interactive Shiny interface for market simulation
2. What-if scenario analysis
3. Segmentation analysis
4. Price sensitivity curves
5. Optimal product configuration finder

## 7. Testing Requirements

### Unit Tests
- Test each function independently
- Verify zero-centering of utilities
- Test baseline handling (both approaches)
- Validate confidence interval calculations
- Test error handling

### Integration Tests
- Test with real Alchemer data (DE_noodle dataset)
- Validate against ChatGPT/statsmodels results (tolerance: 5%)
- Test edge cases (minimal data, maximum complexity)
- Test data quality warnings

### Validation Tests
- Compare mlogit vs. clogit results
- Verify market share predictions
- Test simulator formulas
- Validate Excel output completeness

## 8. Performance Targets

```r
Dataset Size          | Estimation Time | Output Time | Total
---------------------|-----------------|-------------|-------
Small (n=100)        | <5 sec         | <2 sec      | <10 sec
Medium (n=500)       | <15 sec        | <5 sec      | <20 sec
Large (n=2000)       | <60 sec        | <10 sec     | <90 sec
Very Large (n=5000)  | <180 sec       | <20 sec     | <200 sec
```

## 9. Error Handling Standards

### Error Message Format

```r
"[MODULE] Error: [SPECIFIC PROBLEM]
 → [ACTIONABLE SOLUTION]
 → [WHERE TO LOOK]"

# Good example:
"[DATA] Error: Choice set 15 has 2 alternatives marked as chosen
 → Each choice set must have exactly ONE chosen alternative (chosen=1)
 → Check rows 145-148 in your data file"

# Bad example:
"Error in validate_data: invalid structure"
```

### Error Recovery Strategy

1. Try primary method (mlogit)
2. If fails, log reason and try fallback (clogit)
3. If both fail, provide diagnostic information
4. Suggest data fixes when possible
5. Never fail silently

## 10. Dependencies Management

### Required Package Versions

```r
install.packages(c(
  "mlogit",      # >= 1.1-0
  "survival",    # >= 3.0
  "openxlsx",    # >= 4.2
  "data.table"   # >= 1.14
))

# Optional for advanced features:
install.packages(c(
  "ChoiceModelR",  # For HB
  "maxLik"         # Alternative optimization
))
```

### Version Checking

```r
check_dependencies <- function() {
  required <- list(
    mlogit = "1.1-0",
    survival = "3.0",
    openxlsx = "4.2",
    data.table = "1.14"
  )
  
  for (pkg in names(required)) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf(
        "Required package '%s' not installed. Install with: install.packages('%s')",
        pkg, pkg
      ))
    }
    
    installed_version <- packageVersion(pkg)
    required_version <- required[[pkg]]
    
    if (installed_version < required_version) {
      warning(sprintf(
        "Package '%s' version %s detected. Version %s or higher recommended.",
        pkg, installed_version, required_version
      ))
    }
  }
}
```

## 11. Key Design Decisions

### Decision 1: Baseline Handling
- **Default:** first_level_zero (matches statsmodels, more interpretable)
- **Alternative:** all_levels_explicit (for detailed comparisons)
- **Implementation:** User-configurable via config file

### Decision 2: Estimation Method Priority
- **Primary:** mlogit (more robust, better for market research)
- **Fallback:** clogit (simpler, works when mlogit fails)
- **Advanced:** HB via ChoiceModelR (optional, resource-intensive)
- **Implementation:** "auto" mode tries methods in order

### Decision 3: Output Focus
- **Primary:** Excel with market simulator (client-ready)
- **Secondary:** R objects for technical users
- **Export:** CSV for external analysis
- **Implementation:** All three formats generated

### Decision 4: Error Philosophy
- **Errors:** Stop execution, provide clear fix
- **Warnings:** Continue execution, flag potential issues
- **Info:** Log helpful context, don't interrupt
- **Implementation:** Tiered messaging system

## 12. Success Criteria

The implementation is successful if it:

1. ✅ Produces results matching statsmodels within 5% tolerance
2. ✅ Handles all Alchemer CBC data formats correctly
3. ✅ Generates Excel output with working market simulator
4. ✅ Provides clear error messages for common mistakes
5. ✅ Runs within performance targets
6. ✅ Passes all unit and integration tests
7. ✅ Works for non-statistician users (market researchers)
8. ✅ Produces publication-quality outputs

---

**See Part 2 for Configuration, Testing & Validation details**
**See Part 3 for Excel Output & Market Simulator specifications**
