# TURAS KEY DRIVER ANALYSIS - CODE REVIEW PACKAGE

**Date:** 2025-11-30
**Version:** 1.0.0
**Status:** Production
**Purpose:** External code review for bug identification and validation

---

## TABLE OF CONTENTS

1. [Overview](#overview)
2. [Statistical Methods](#statistical-methods)
3. [Complete Source Code](#complete-source-code)
4. [Test Data](#test-data)
5. [Areas for Review](#areas-for-review)
6. [Known Limitations](#known-limitations)

---

## OVERVIEW

The Key Driver Analysis module identifies which independent variables (drivers) have the greatest impact on a dependent variable (outcome) using multiple statistical methods.

### Module Architecture

The module consists of 5 R files following a numbered execution pattern:

- **00_main.R** - Entry point and workflow orchestration
- **01_config.R** - Configuration loading and validation
- **02_validation.R** - Data loading and validation
- **03_analysis.R** - Core statistical algorithms (4 methods)
- **04_output.R** - Excel workbook generation

### Statistical Methods Implemented

1. **Shapley Value Decomposition** - Game theory approach for fair R² attribution
2. **Relative Weights** - Johnson's (2000) method using eigen decomposition
3. **Standardized Coefficients** - Beta weights in standard deviation units
4. **Zero-order Correlations** - Simple Pearson correlations

### Dependencies

- `openxlsx` - Excel I/O (required)
- `shiny`, `shinyFiles` - GUI framework (required)
- `haven` - SPSS/Stata file support (optional)
- Base R `stats` - Regression and correlation functions

---

## STATISTICAL METHODS

### 1. Shapley Value Decomposition

**Purpose:** Fairly allocates R² contribution across all predictors using game theory

**Algorithm:**
1. Fit all possible subset models (2^n combinations)
2. For each variable, calculate marginal R² contribution when added to each subset
3. Weight contributions by factorial of subset size
4. Average across all orderings

**Formula:**
```
φᵢ = Σ [|S|!(n-|S|-1)! / n!] × [R²(S ∪ {i}) - R²(S)]
```

**Pros:** Most robust, accounts for variable interactions, fair attribution
**Cons:** Computationally expensive (exponential in number of variables)

### 2. Relative Weights (Johnson, 2000)

**Purpose:** Decomposes R² into orthogonal contributions

**Algorithm:**
1. Compute eigendecomposition of predictor correlation matrix: R_xx = PΛP'
2. Transform to orthogonal space: Δ = P√Λ P'
3. Calculate relative weights: RW = Σ(Δ × R_xy)²
4. Normalize to percentages

**Pros:** Always non-negative, handles multicollinearity well
**Cons:** Less intuitive than regression coefficients

### 3. Standardized Coefficients (Beta Weights)

**Purpose:** Traditional regression approach in standardized units

**Algorithm:**
```
β_standardized = β_raw × (SD_x / SD_y)
```

**Pros:** Widely understood, easy to interpret
**Cons:** Unstable with multicollinearity, can be negative

### 4. Zero-order Correlations

**Purpose:** Simple bivariate relationship strength

**Algorithm:**
```
r = cor(X, Y)
Importance = |r|
```

**Pros:** Simple, intuitive
**Cons:** Ignores other variables, confounded by multicollinearity

---

## COMPLETE SOURCE CODE

### FILE 1: modules/keydriver/R/00_main.R

**Purpose:** Main entry point and workflow orchestration
**Lines:** 150
**Key Function:** `run_keydriver_analysis()`

```r
# ==============================================================================
# TURAS KEY DRIVER ANALYSIS MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Key Driver Analysis (Relative Importance)
# Purpose: Determine which independent variables (drivers) have the greatest
#          impact on a dependent variable (outcome)
# Version: 1.0.0 (Initial Implementation)
# Date: 2025-11-18
#
# ==============================================================================

#' Run Key Driver Analysis
#'
#' Analyzes which variables drive an outcome using multiple statistical methods.
#'
#' METHODS IMPLEMENTED:
#' 1. Standardized Coefficients (Beta weights)
#' 2. Relative Weights (Johnson's method)
#' 3. Shapley Value Decomposition
#' 4. Correlation-based importance
#'
#' @param config_file Path to key driver configuration Excel file
#'   Required sheets: Settings, Variables
#'   Settings sheet should include: data_file, output_file
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA).
#'   If NULL, reads from config Settings sheet.
#' @param output_file Path for results Excel file.
#'   If NULL, reads from config Settings sheet.
#'
#' @return List containing:
#'   - importance: Data frame with importance scores from each method
#'   - model: Regression model object
#'   - correlations: Correlation matrix
#'   - config: Processed configuration
#'
#' @examples
#' \dontrun{
#' # Using config file with paths specified in Settings
#' results <- run_keydriver_analysis(
#'   config_file = "keydriver_config.xlsx"
#' )
#'
#' # Override paths from config
#' results <- run_keydriver_analysis(
#'   config_file = "keydriver_config.xlsx",
#'   data_file = "my_data.csv",
#'   output_file = "my_results.xlsx"
#' )
#'
#' # View importance rankings
#' print(results$importance)
#'
#' # View by method
#' print(results$importance[order(-results$importance$Shapley), ])
#' }
#'
#' @export
run_keydriver_analysis <- function(config_file, data_file = NULL, output_file = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS KEY DRIVER ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # STEP 1: Load Configuration
  cat("1. Loading configuration...\n")
  config <- load_keydriver_config(config_file)
  cat(sprintf("   ✓ Outcome variable: %s\n", config$outcome_var))
  cat(sprintf("   ✓ Driver variables: %d variables\n", length(config$driver_vars)))

  # Get data_file from config if not provided
  if (is.null(data_file)) {
    data_file <- config$data_file
    if (is.null(data_file) || is.na(data_file)) {
      stop("data_file not specified in function call or config Settings sheet", call. = FALSE)
    }
  }

  # Get output_file from config if not provided
  if (is.null(output_file)) {
    output_file <- config$output_file
    if (is.null(output_file) || is.na(output_file)) {
      # Default to project_root/keydriver_results.xlsx
      output_file <- file.path(config$project_root, "keydriver_results.xlsx")
    }
  }

  # STEP 2: Load and Validate Data
  cat("\n2. Loading and validating data...\n")
  data <- load_keydriver_data(data_file, config)
  cat(sprintf("   ✓ Loaded %d respondents\n", data$n_respondents))
  cat(sprintf("   ✓ Complete cases: %d\n", data$n_complete))

  # STEP 3: Calculate Correlations
  cat("\n3. Calculating correlations...\n")
  correlations <- calculate_correlations(data$data, config)
  cat("   ✓ Correlation matrix calculated\n")

  # STEP 4: Fit Regression Model
  cat("\n4. Fitting regression model...\n")
  model <- fit_keydriver_model(data$data, config)
  cat(sprintf("   ✓ Model R² = %.3f\n", summary(model)$r.squared))

  # STEP 5: Calculate Importance Scores
  cat("\n5. Calculating importance scores...\n")
  importance <- calculate_importance_scores(model, data$data, correlations, config)
  cat("   ✓ Multiple importance methods calculated\n")

  # STEP 6: Generate Output
  cat("\n6. Generating output file...\n")
  write_keydriver_output(
    importance = importance,
    model = model,
    correlations = correlations,
    config = config,
    output_file = output_file
  )
  cat(sprintf("   ✓ Results written to: %s\n", output_file))

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ANALYSIS COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Print top drivers
  cat("TOP 5 DRIVERS (by Shapley value):\n")
  top_drivers <- head(importance[order(-importance$Shapley_Value), ], 5)
  for (i in seq_len(nrow(top_drivers))) {
    cat(sprintf("  %d. %s (%.1f%%)\n",
                i,
                top_drivers$Driver[i],
                top_drivers$Shapley_Value[i]))
  }
  cat("\n")

  # Return results
  invisible(list(
    importance = importance,
    model = model,
    correlations = correlations,
    config = config
  ))
}


#' @export
keydriver <- run_keydriver_analysis  # Alias for convenience
```

---

### FILE 2: modules/keydriver/R/01_config.R

**Purpose:** Configuration loading and validation
**Lines:** 88
**Key Function:** `load_keydriver_config()`

```r
# ==============================================================================
# KEY DRIVER CONFIG LOADER
# ==============================================================================

#' Load Key Driver Configuration
#'
#' Loads and validates key driver analysis configuration.
#'
#' @param config_file Path to configuration Excel file
#' @param project_root Optional project root directory (defaults to config file directory)
#' @return List with validated configuration
#' @keywords internal
load_keydriver_config <- function(config_file, project_root = NULL) {

  if (!file.exists(config_file)) {
    stop("Configuration file not found: ", config_file, call. = FALSE)
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }

  # Load settings
  settings <- openxlsx::read.xlsx(config_file, sheet = "Settings")
  settings_list <- setNames(as.list(settings$Value), settings$Setting)

  # Extract and resolve file paths from settings
  data_file <- settings_list$data_file
  output_file <- settings_list$output_file

  # Resolve relative paths
  if (!is.null(data_file) && !is.na(data_file)) {
    if (!grepl("^(/|[A-Za-z]:)", data_file)) {
      # Relative path - resolve from project root
      data_file <- file.path(project_root, data_file)
    }
    data_file <- normalizePath(data_file, winslash = "/", mustWork = FALSE)
  }

  if (!is.null(output_file) && !is.na(output_file)) {
    if (!grepl("^(/|[A-Za-z]:)", output_file)) {
      # Relative path - resolve from project root
      output_file <- file.path(project_root, output_file)
    }
    output_file <- normalizePath(output_file, winslash = "/", mustWork = FALSE)
  }

  # Load variables definition
  variables <- openxlsx::read.xlsx(config_file, sheet = "Variables")

  # Validate variables sheet
  required_cols <- c("VariableName", "Type", "Label")
  missing_cols <- setdiff(required_cols, names(variables))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in Variables sheet: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Extract outcome and driver variables
  outcome_vars <- variables$VariableName[variables$Type == "Outcome"]
  driver_vars <- variables$VariableName[variables$Type == "Driver"]

  if (length(outcome_vars) == 0) {
    stop("No outcome variable defined. Set Type='Outcome' for one variable.",
         call. = FALSE)
  }

  if (length(outcome_vars) > 1) {
    warning("Multiple outcome variables found. Using first: ", outcome_vars[1])
    outcome_vars <- outcome_vars[1]
  }

  if (length(driver_vars) == 0) {
    stop("No driver variables defined. Set Type='Driver' for independent variables.",
         call. = FALSE)
  }

  list(
    settings = settings_list,
    outcome_var = outcome_vars,
    driver_vars = driver_vars,
    variables = variables,
    data_file = data_file,
    output_file = output_file,
    project_root = project_root
  )
}
```

---

### FILE 3: modules/keydriver/R/02_validation.R

**Purpose:** Data loading and validation
**Lines:** 88
**Key Function:** `load_keydriver_data()`

```r
# ==============================================================================
# KEY DRIVER DATA VALIDATION
# ==============================================================================

#' Load Key Driver Data
#'
#' Loads and validates data for key driver analysis.
#'
#' @param data_file Path to data file
#' @param config Configuration list
#' @return List with validated data
#' @keywords internal
load_keydriver_data <- function(data_file, config) {

  if (!file.exists(data_file)) {
    stop("Data file not found: ", data_file, call. = FALSE)
  }

  # Detect file type and load
  file_ext <- tolower(tools::file_ext(data_file))

  data <- switch(file_ext,
    "csv" = utils::read.csv(data_file, stringsAsFactors = FALSE),
    "xlsx" = openxlsx::read.xlsx(data_file),
    "sav" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required for SPSS files. Install with: install.packages('haven')",
             call. = FALSE)
      }
      haven::read_sav(data_file)
    },
    "dta" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required for Stata files. Install with: install.packages('haven')",
             call. = FALSE)
      }
      haven::read_dta(data_file)
    },
    stop("Unsupported file format: ", file_ext, call. = FALSE)
  )

  # Convert to data frame
  data <- as.data.frame(data)

  # Validate required variables exist
  all_vars <- c(config$outcome_var, config$driver_vars)
  missing_vars <- setdiff(all_vars, names(data))

  if (length(missing_vars) > 0) {
    stop("Missing variables in data: ", paste(missing_vars, collapse = ", "),
         call. = FALSE)
  }

  # Select only relevant variables
  data <- data[, all_vars, drop = FALSE]

  # Convert to numeric if needed
  for (var in all_vars) {
    if (!is.numeric(data[[var]])) {
      data[[var]] <- as.numeric(as.character(data[[var]]))
    }
  }

  # Count complete cases
  complete_cases <- complete.cases(data)
  n_complete <- sum(complete_cases)
  n_missing <- nrow(data) - n_complete

  if (n_missing > 0) {
    warning(sprintf("%d rows with missing data will be excluded (%.1f%%)",
                    n_missing, 100 * n_missing / nrow(data)))
  }

  if (n_complete < 30) {
    stop("Insufficient complete cases (", n_complete, "). Need at least 30.",
         call. = FALSE)
  }

  # Filter to complete cases
  data <- data[complete_cases, ]

  list(
    data = data,
    n_respondents = nrow(data),
    n_complete = n_complete,
    n_missing = n_missing
  )
}
```

---

### FILE 4: modules/keydriver/R/03_analysis.R

**Purpose:** Core statistical algorithms - ALL 4 METHODS
**Lines:** 231
**Key Functions:**
- `calculate_shapley_values()` - Shapley decomposition
- `calculate_relative_weights()` - Johnson's method
- `calculate_beta_weights()` - Standardized coefficients
- `calculate_correlations()` - Correlation matrix

**⚠️ THIS IS THE CRITICAL FILE FOR STATISTICAL REVIEW**

```r
# ==============================================================================
# KEY DRIVER ANALYSIS - CORE ALGORITHMS
# ==============================================================================

#' Calculate Correlations
#'
#' @keywords internal
calculate_correlations <- function(data, config) {
  all_vars <- c(config$outcome_var, config$driver_vars)
  cor(data[, all_vars], use = "complete.obs")
}


#' Fit Key Driver Regression Model
#'
#' @keywords internal
fit_keydriver_model <- function(data, config) {

  # Build formula
  formula_str <- paste(config$outcome_var, "~",
                       paste(config$driver_vars, collapse = " + "))
  model_formula <- as.formula(formula_str)

  # Fit OLS model
  model <- lm(model_formula, data = data)

  model
}


#' Calculate Multiple Importance Scores
#'
#' Implements multiple methods for relative importance.
#'
#' @keywords internal
calculate_importance_scores <- function(model, data, correlations, config) {

  driver_vars <- config$driver_vars
  n_drivers <- length(driver_vars)

  # Initialize results data frame
  importance <- data.frame(
    Driver = driver_vars,
    Label = sapply(driver_vars, function(v) {
      config$variables$Label[config$variables$VariableName == v][1]
    }),
    stringsAsFactors = FALSE
  )

  # METHOD 1: Standardized Coefficients (Beta Weights)
  importance$Beta_Weight <- calculate_beta_weights(model, data, config)

  # METHOD 2: Relative Weights (Johnson's method)
  importance$Relative_Weight <- calculate_relative_weights(model, correlations, config)

  # METHOD 3: Shapley Value Decomposition
  importance$Shapley_Value <- calculate_shapley_values(model, data, config)

  # METHOD 4: Zero-order correlations
  outcome_cors <- correlations[config$outcome_var, driver_vars]
  importance$Correlation <- abs(outcome_cors)

  # Calculate ranks for each method
  importance$Beta_Rank <- rank(-abs(importance$Beta_Weight))
  importance$RelWeight_Rank <- rank(-importance$Relative_Weight)
  importance$Shapley_Rank <- rank(-importance$Shapley_Value)
  importance$Corr_Rank <- rank(-importance$Correlation)

  # Average rank
  importance$Average_Rank <- rowMeans(importance[, c("Beta_Rank", "RelWeight_Rank",
                                                      "Shapley_Rank", "Corr_Rank")])

  # Sort by Shapley value (generally most robust)
  importance <- importance[order(-importance$Shapley_Value), ]

  importance
}


#' Calculate Standardized Coefficients
#'
#' @keywords internal
calculate_beta_weights <- function(model, data, config) {

  # Get standardized coefficients
  coefs <- coef(model)[-1]  # Remove intercept

  # Standardize
  sd_x <- sapply(config$driver_vars, function(v) sd(data[[v]], na.rm = TRUE))
  sd_y <- sd(data[[config$outcome_var]], na.rm = TRUE)

  beta_weights <- coefs * (sd_x / sd_y)

  # Return as percentage of sum of absolute betas
  sum_abs <- sum(abs(beta_weights))
  if (sum_abs == 0) {
    pct <- rep(0, length(beta_weights))
  } else {
    pct <- (abs(beta_weights) / sum_abs) * 100
  }

  unname(pct)
}


#' Calculate Relative Weights (Johnson's Method)
#'
#' Decomposes R² into non-negative contributions from each predictor.
#'
#' @keywords internal
calculate_relative_weights <- function(model, correlations, config) {

  # Extract correlation matrices
  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars

  R_xx <- correlations[driver_vars, driver_vars]
  R_xy <- correlations[driver_vars, outcome_var]

  # Eigen decomposition of predictor correlation matrix
  eigen_decomp <- eigen(R_xx)
  Lambda <- diag(sqrt(pmax(eigen_decomp$values, 0)))
  P <- eigen_decomp$vectors

  # Transform to orthogonal space
  Delta <- P %*% Lambda %*% t(P)

  # Relative weights
  rw <- rowSums((Delta %*% R_xy)^2)

  # Normalize to percentages
  sum_rw <- sum(rw)
  if (sum_rw == 0) {
    rw_pct <- rep(0, length(rw))
  } else {
    rw_pct <- (rw / sum_rw) * 100
  }

  unname(rw_pct)
}


#' Calculate Shapley Value Decomposition
#'
#' Allocates R² contribution fairly using game theory approach.
#'
#' @keywords internal
calculate_shapley_values <- function(model, data, config) {

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars
  n <- length(driver_vars)

  # Store all subset R²
  r2_values <- list()

  # Calculate R² for all possible subsets
  for (subset_size in 0:n) {
    if (subset_size == 0) {
      r2_values[["empty"]] <- 0
      next
    }

    # Get all combinations of this size
    combos <- combn(driver_vars, subset_size, simplify = FALSE)

    for (combo in combos) {
      combo_key <- paste(sort(combo), collapse = "|")

      # Fit model with this subset
      formula_str <- paste(outcome_var, "~", paste(combo, collapse = " + "))
      subset_model <- lm(as.formula(formula_str), data = data)

      r2_values[[combo_key]] <- summary(subset_model)$r.squared
    }
  }

  # Calculate Shapley values
  shapley <- numeric(n)
  names(shapley) <- driver_vars

  for (i in seq_along(driver_vars)) {
    var <- driver_vars[i]
    marginal_sum <- 0

    # Iterate over all subsets NOT containing var
    other_vars <- setdiff(driver_vars, var)

    for (subset_size in 0:(n-1)) {
      if (subset_size == 0) {
        subsets <- list(character(0))
      } else {
        subsets <- combn(other_vars, subset_size, simplify = FALSE)
      }

      for (subset in subsets) {
        # Weight for this subset size
        weight <- factorial(subset_size) * factorial(n - subset_size - 1) / factorial(n)

        # R² with var
        with_var_key <- if (length(subset) == 0) {
          var
        } else {
          paste(sort(c(subset, var)), collapse = "|")
        }

        # R² without var
        without_var_key <- if (length(subset) == 0) {
          "empty"
        } else {
          paste(sort(subset), collapse = "|")
        }

        marginal_contribution <- r2_values[[with_var_key]] - r2_values[[without_var_key]]
        marginal_sum <- marginal_sum + weight * marginal_contribution
      }
    }

    shapley[i] <- marginal_sum
  }

  # Convert to percentages
  sum_shapley <- sum(shapley)
  if (sum_shapley == 0) {
    shapley_pct <- rep(0, length(shapley))
  } else {
    shapley_pct <- (shapley / sum_shapley) * 100
  }

  unname(shapley_pct)
}
```

---

### FILE 5: modules/keydriver/R/04_output.R

**Purpose:** Excel workbook generation
**Lines:** 89
**Key Function:** `write_keydriver_output()`

```r
# ==============================================================================
# KEY DRIVER OUTPUT WRITER
# ==============================================================================

#' Write Key Driver Results to Excel
#'
#' @keywords internal
write_keydriver_output <- function(importance, model, correlations, config, output_file) {

  wb <- openxlsx::createWorkbook()

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )

  # Sheet 1: Importance Summary
  openxlsx::addWorksheet(wb, "Importance Summary")

  summary_cols <- c("Driver", "Label", "Shapley_Value", "Relative_Weight",
                    "Beta_Weight", "Correlation", "Average_Rank")
  summary_data <- importance[, summary_cols]
  names(summary_data) <- c("Driver", "Label", "Shapley (%)", "Rel. Weight (%)",
                           "Beta Weight (%)", "Correlation (r)", "Avg Rank")

  openxlsx::writeData(wb, "Importance Summary", summary_data, startRow = 1)
  openxlsx::addStyle(wb, "Importance Summary", header_style, rows = 1,
                     cols = 1:ncol(summary_data), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Importance Summary", cols = 1:ncol(summary_data),
                         widths = "auto")

  # Sheet 2: Detailed Rankings
  openxlsx::addWorksheet(wb, "Method Rankings")
  ranking_cols <- c("Driver", "Label", "Shapley_Rank", "RelWeight_Rank",
                    "Beta_Rank", "Corr_Rank", "Average_Rank")
  ranking_data <- importance[, ranking_cols]
  names(ranking_data) <- c("Driver", "Label", "Shapley Rank", "Rel. Weight Rank",
                           "Beta Rank", "Corr Rank", "Average Rank")

  openxlsx::writeData(wb, "Method Rankings", ranking_data, startRow = 1)
  openxlsx::addStyle(wb, "Method Rankings", header_style, rows = 1,
                     cols = 1:ncol(ranking_data), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Method Rankings", cols = 1:ncol(ranking_data),
                         widths = "auto")

  # Sheet 3: Model Summary
  openxlsx::addWorksheet(wb, "Model Summary")

  model_summary <- data.frame(
    Metric = c("R-Squared", "Adj R-Squared", "F-Statistic", "P-Value", "RMSE", "N"),
    Value = c(
      summary(model)$r.squared,
      summary(model)$adj.r.squared,
      summary(model)$fstatistic[1],
      pf(summary(model)$fstatistic[1],
         summary(model)$fstatistic[2],
         summary(model)$fstatistic[3],
         lower.tail = FALSE),
      sqrt(mean(residuals(model)^2)),
      nobs(model)
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Model Summary", model_summary, startRow = 1)
  openxlsx::addStyle(wb, "Model Summary", header_style, rows = 1,
                     cols = 1:2, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Model Summary", cols = 1:2, widths = "auto")

  # Sheet 4: Correlation Matrix
  openxlsx::addWorksheet(wb, "Correlations")
  cor_df <- as.data.frame(correlations)
  cor_df <- cbind(Variable = rownames(cor_df), cor_df)
  rownames(cor_df) <- NULL

  openxlsx::writeData(wb, "Correlations", cor_df, startRow = 1)
  openxlsx::addStyle(wb, "Correlations", header_style, rows = 1,
                     cols = 1:ncol(cor_df), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Correlations", cols = 1:ncol(cor_df), widths = "auto")

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
}
```

---

### FILE 6: modules/keydriver/run_keydriver_gui.R

**Purpose:** Shiny GUI launcher
**Lines:** 408
**Key Function:** `run_keydriver_gui()`

```r
# ==============================================================================
# TURAS KEY DRIVER MODULE - GUI LAUNCHER
# ==============================================================================

library(shiny)
library(shinyFiles)

#' Run Key Driver Analysis GUI
#'
#' Launches a Shiny GUI for running key driver analysis.
#'
#' @return A shinyApp object
#' @export
run_keydriver_gui <- function() {

  # Get Turas root directory
  turas_root <- getwd()
  if (basename(turas_root) != "Turas") {
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    }
  }

  # Recent projects file
  RECENT_PROJECTS_FILE <- file.path(turas_root, ".recent_keydriver_projects.rds")

  # Load recent projects
  load_recent_projects <- function() {
    if (file.exists(RECENT_PROJECTS_FILE)) {
      tryCatch(readRDS(RECENT_PROJECTS_FILE), error = function(e) list())
    } else {
      list()
    }
  }

  # Save recent projects
  save_recent_projects <- function(projects) {
    tryCatch(saveRDS(projects, RECENT_PROJECTS_FILE), error = function(e) NULL)
  }

  # Add to recent projects
  add_recent_project <- function(project_info) {
    recent <- load_recent_projects()
    # Remove duplicates
    recent <- recent[!sapply(recent, function(x) x$project_dir == project_info$project_dir)]
    # Add new at front
    recent <- c(list(project_info), recent)
    # Keep only last 5
    recent <- recent[1:min(5, length(recent))]
    save_recent_projects(recent)
  }

  # Detect config files in directory
  detect_config_files <- function(dir) {
    if (!dir.exists(dir)) return(character(0))
    files <- list.files(dir, pattern = "\\.xlsx$", full.names = FALSE, ignore.case = TRUE)
    config_patterns <- c("keydriver.*config", "key.*driver.*config", "kda.*config", "driver.*config", "config")
    detected <- character(0)
    for (pattern in config_patterns) {
      matches <- grep(pattern, files, value = TRUE, ignore.case = TRUE)
      if (length(matches) > 0) detected <- c(detected, matches)
    }
    unique(detected)
  }

  ui <- fluidPage(

    tags$head(
      tags$style(HTML("
        body {
          background-color: #f5f5f5;
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        .main-container {
          max-width: 900px;
          margin: 30px auto;
          padding: 30px;
          background-color: white;
          border-radius: 10px;
          box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
          text-align: center;
          margin-bottom: 30px;
          padding-bottom: 20px;
          border-bottom: 3px solid #ec4899;
        }
        .header h1 {
          color: #ec4899;
          margin-bottom: 5px;
        }
        .header p {
          color: #6c757d;
        }
        .step-card {
          background-color: #f8f9fa;
          border: 1px solid #dee2e6;
          border-radius: 8px;
          padding: 20px;
          margin-bottom: 20px;
        }
        .step-title {
          font-size: 18px;
          font-weight: bold;
          color: #2c3e50;
          margin-bottom: 15px;
        }
        .file-display {
          background-color: #e9ecef;
          padding: 10px 15px;
          border-radius: 5px;
          margin-top: 10px;
          word-break: break-all;
        }
        .file-display .filename {
          font-weight: bold;
          color: #2c3e50;
        }
        .file-display .filepath {
          font-size: 12px;
          color: #6c757d;
        }
        .status-success {
          color: #28a745;
          font-weight: bold;
        }
        .status-error {
          color: #dc3545;
          font-weight: bold;
        }
        .btn-keydriver {
          background-color: #ec4899;
          color: white;
          border: none;
        }
        .btn-keydriver:hover {
          background-color: #db2777;
          color: white;
        }
        .run-btn {
          width: 100%;
          padding: 15px;
          font-size: 18px;
          font-weight: bold;
        }
        .console-output {
          background-color: #1e1e1e;
          color: #d4d4d4;
          font-family: 'Consolas', 'Monaco', monospace;
          padding: 15px;
          border-radius: 5px;
          max-height: 400px;
          overflow-y: auto;
          white-space: pre-wrap;
          font-size: 13px;
        }
        .info-box {
          background-color: #d1ecf1;
          border: 1px solid #bee5eb;
          color: #0c5460;
          padding: 10px 15px;
          border-radius: 5px;
          margin-top: 10px;
          font-size: 13px;
        }
      "))
    ),

    div(class = "main-container",

      # Header
      div(class = "header",
        h1("🔑 TURAS Key Driver Analysis"),
        p("Identify key drivers of your target outcome")
      ),

      # Step 1: Project Directory
      div(class = "step-card",
        div(class = "step-title", "Step 1: Select Project Directory"),

        fluidRow(
          column(8,
            shinyDirButton("project_dir_btn",
                          "Browse for Project Folder",
                          "Select project directory",
                          class = "btn btn-keydriver",
                          icon = icon("folder-open"))
          ),
          column(4,
            uiOutput("recent_projects_ui")
          )
        ),

        uiOutput("project_display")
      ),

      # Step 2: Config File
      conditionalPanel(
        condition = "output.project_selected",
        div(class = "step-card",
          div(class = "step-title", "Step 2: Select Configuration File"),
          uiOutput("config_selector"),
          uiOutput("config_display"),
          div(class = "info-box",
            tags$strong("Note: "), "The config file's Settings sheet should specify ",
            tags$code("data_file"), " and ", tags$code("output_file"), " paths."
          )
        )
      ),

      # Run Button
      conditionalPanel(
        condition = "output.ready_to_run",
        div(class = "step-card",
          actionButton("run_analysis", "Run Key Driver Analysis",
                      class = "btn btn-keydriver run-btn",
                      icon = icon("play"))
        )
      ),

      # Console Output
      conditionalPanel(
        condition = "output.show_console",
        div(class = "step-card",
          div(class = "step-title", "Analysis Output"),
          div(class = "console-output",
            verbatimTextOutput("console_output")
          )
        )
      )
    )
  )

  server <- function(input, output, session) {

    # Reactive values
    files <- reactiveValues(
      project_dir = NULL,
      config_file = NULL
    )

    console_text <- reactiveVal("")
    is_running <- reactiveVal(FALSE)

    # Set up directory browser
    volumes <- c(Home = path.expand("~"),
                Documents = file.path(path.expand("~"), "Documents"),
                Desktop = file.path(path.expand("~"), "Desktop"))

    shinyDirChoose(input, "project_dir_btn", roots = volumes, session = session)

    # Handle project directory selection
    observeEvent(input$project_dir_btn, {
      if (!is.integer(input$project_dir_btn)) {
        dir_path <- parseDirPath(volumes, input$project_dir_btn)
        if (length(dir_path) > 0 && dir.exists(dir_path)) {
          files$project_dir <- dir_path
          files$config_file <- NULL
        }
      }
    })

    # Recent projects dropdown
    output$recent_projects_ui <- renderUI({
      recent <- load_recent_projects()
      if (length(recent) > 0) {
        choices <- setNames(
          sapply(recent, function(x) x$project_dir),
          sapply(recent, function(x) basename(x$project_dir))
        )
        selectInput("recent_project", "Recent:",
                   choices = c("Select recent..." = "", choices),
                   width = "100%")
      }
    })

    # Handle recent project selection
    observeEvent(input$recent_project, {
      if (!is.null(input$recent_project) && input$recent_project != "") {
        if (dir.exists(input$recent_project)) {
          files$project_dir <- input$recent_project
          files$config_file <- NULL
        }
      }
    })

    # Project display
    output$project_display <- renderUI({
      if (!is.null(files$project_dir)) {
        div(class = "file-display",
          div(class = "filename", basename(files$project_dir)),
          div(class = "filepath", files$project_dir),
          div(class = "status-success", "✓ Directory selected")
        )
      }
    })

    # Config file selector
    output$config_selector <- renderUI({
      req(files$project_dir)
      configs <- detect_config_files(files$project_dir)

      if (length(configs) > 0) {
        radioButtons("config_select", "Detected config files:",
                    choices = configs,
                    selected = configs[1])
      } else {
        # Manual file selection
        shinyFilesButton("config_btn", "Browse for Config File",
                        "Select configuration file",
                        class = "btn btn-keydriver",
                        multiple = FALSE)
      }
    })

    # Handle config selection
    observeEvent(input$config_select, {
      if (!is.null(input$config_select) && !is.null(files$project_dir)) {
        files$config_file <- file.path(files$project_dir, input$config_select)
      }
    })

    # Config display
    output$config_display <- renderUI({
      if (!is.null(files$config_file)) {
        div(class = "file-display",
          div(class = "filename", basename(files$config_file)),
          div(class = "filepath", files$config_file),
          if (file.exists(files$config_file)) {
            div(class = "status-success", "✓ Config file found")
          } else {
            div(class = "status-error", "✗ File not found")
          }
        )
      }
    })

    # Conditional panel outputs
    output$project_selected <- reactive({ !is.null(files$project_dir) })
    outputOptions(output, "project_selected", suspendWhenHidden = FALSE)

    output$ready_to_run <- reactive({
      !is.null(files$project_dir) &&
      !is.null(files$config_file) &&
      file.exists(files$config_file) &&
      !is_running()
    })
    outputOptions(output, "ready_to_run", suspendWhenHidden = FALSE)

    output$show_console <- reactive({ nchar(console_text()) > 0 })
    outputOptions(output, "show_console", suspendWhenHidden = FALSE)

    # Console output
    output$console_output <- renderText({ console_text() })

    # Run analysis
    observeEvent(input$run_analysis, {

      req(files$project_dir, files$config_file)

      is_running(TRUE)
      console_text("")

      # Save to recent projects
      add_recent_project(list(project_dir = files$project_dir))

      # Capture output
      output_text <- ""

      tryCatch({
        # Get Turas root
        turas_root <- getwd()
        if (basename(turas_root) != "Turas") {
          turas_root <- dirname(turas_root)
        }

        # Source module files
        output_text <- paste0(output_text, "Loading Key Driver module...\n\n")
        console_text(output_text)

        source(file.path(turas_root, "modules/keydriver/R/00_main.R"))
        source(file.path(turas_root, "modules/keydriver/R/01_config.R"))
        source(file.path(turas_root, "modules/keydriver/R/02_validation.R"))
        source(file.path(turas_root, "modules/keydriver/R/03_analysis.R"))
        source(file.path(turas_root, "modules/keydriver/R/04_output.R"))

        # Capture analysis output
        # Paths are read from config file Settings sheet
        capture <- capture.output({
          results <- run_keydriver_analysis(
            config_file = files$config_file
          )
        }, type = "output")

        output_text <- paste0(output_text, paste(capture, collapse = "\n"))
        output_text <- paste0(output_text, "\n\n✓ Analysis complete!")

      }, error = function(e) {
        output_text <<- paste0(output_text, "\n\n✗ Error: ", e$message)
      })

      console_text(output_text)
      is_running(FALSE)
    })
  }

  shinyApp(ui = ui, server = server)
}
```

---

## TEST DATA

### Test Configuration File Structure

**File:** test_data/keydriver_test_config.xlsx

**Sheet 1: Settings**
| Setting | Value |
|---------|-------|
| analysis_name | Test Key Driver Analysis |
| data_file | keydriver_test_data.csv |
| output_file | keydriver_test_results.xlsx |
| min_sample_size | 30 |

**Sheet 2: Variables**
| VariableName | Type | Label |
|--------------|------|-------|
| overall_satisfaction | Outcome | Overall Satisfaction |
| product_quality | Driver | Product Quality |
| customer_service | Driver | Customer Service |
| value_for_money | Driver | Value for Money |
| brand_reputation | Driver | Brand Reputation |
| delivery_speed | Driver | Delivery Speed |
| website_experience | Driver | Website Experience |

### Test Data File

**File:** test_data/keydriver_test_data.csv

- 100 respondents (rows)
- 8 columns (resp_id + 1 outcome + 6 drivers)
- All numeric scale 1-10
- Synthetic data with controlled correlations

---

## AREAS FOR REVIEW

### 🔴 CRITICAL - Statistical Correctness

#### 1. Shapley Value Calculation (03_analysis.R:143-231)

**Lines to verify:**
- **Lines 158-176:** Subset enumeration - Does this correctly generate all 2^n combinations?
- **Lines 189-199:** Factorial weighting - Is `factorial(s)×factorial(n-s-1)/factorial(n)` correct?
- **Lines 201-215:** Marginal contribution calculation - Are we correctly computing R²(S∪{i}) - R²(S)?
- **Lines 223-228:** Normalization - Should Shapley values sum to R² or be normalized to 100%?

**Potential issues:**
- Computational explosion: With 10+ drivers, 2^10 = 1,024 models; 15 drivers = 32,768 models
- No check for maximum number of drivers
- No progress indicator for long computations
- Are negative Shapley values possible? (They shouldn't be for R² decomposition)

#### 2. Relative Weights Calculation (03_analysis.R:106-140)

**Lines to verify:**
- **Line 122:** Eigenvalue protection - `pmax(eigen_decomp$values, 0)` handles near-zero negatives, but is this statistically valid?
- **Line 126:** Delta transformation - Does `P %*% Lambda %*% t(P)` correctly implement Johnson (2000)?
- **Line 129:** Relative weight formula - Is `rowSums((Delta %*% R_xy)^2)` the correct implementation?
- **Lines 133-137:** Should relative weights sum to R² or 100%?

**Potential issues:**
- What happens with perfect multicollinearity (singular R_xx matrix)?
- Are negative eigenvalues being masked correctly or should they error?

#### 3. Beta Weights Calculation (03_analysis.R:80-103)

**Lines to verify:**
- **Line 92:** Standardization - Is `coef × (SD_x / SD_y)` the correct formula?
- **Lines 95-100:** Taking absolute value before summing - does this lose directional information inappropriately?
- **Line 99:** Percentage calculation - is normalizing by sum of absolute betas statistically meaningful?

**Potential issues:**
- Suppressor variables (negative betas) - are these handled correctly?
- What if all betas are near zero? (Division by near-zero)

#### 4. Correlation Calculation (03_analysis.R:5-11)

**Line to verify:**
- **Line 64:** Taking absolute value `abs(outcome_cors)` - is this appropriate? (Loses directionality)

### 🟡 IMPORTANT - Data Validation

#### 1. Sample Size Requirements (02_validation.R:74-77)

```r
if (n_complete < 30) {
  stop("Insufficient complete cases...")
}
```

**Question:** Is n=30 sufficient?
- For regression with k predictors, common rule is n ≥ 10k or n ≥ 104+k
- With 6 drivers, this would require n ≥ 60 or n ≥ 110

#### 2. Missing Data Handling (02_validation.R:64-80)

**Current approach:** Complete case analysis (listwise deletion)

**Potential issues:**
- Biased estimates if data not MCAR (Missing Completely At Random)
- Reduced sample size and power
- No warning about % missing per variable
- Should consider: mean imputation, multiple imputation, or FIML?

#### 3. Type Coercion (02_validation.R:58-62)

```r
data[[var]] <- as.numeric(as.character(data[[var]]))
```

**Potential issues:**
- Silent NA introduction if non-numeric values present
- No validation that coercion succeeded
- Labeled SPSS/Stata data might lose labels

### 🟢 MODERATE - Edge Cases & Error Handling

#### 1. Perfect Multicollinearity

**Not handled:** If two drivers are perfectly correlated (r=1.0)
- `lm()` will drop one predictor silently
- Shapley calculation may fail
- Relative weights may produce singular matrix

**Recommendation:** Check condition number or VIF before analysis

#### 2. Zero Variance Predictors

**Not handled:** If a driver has SD=0
- Beta weights will have division by zero (line 92)
- Should check and error/warn before analysis

#### 3. Negative R² Values

**Possible in subsets?** With small samples or poor fits
- R² for subset models should always be ≥0, but numerical issues could occur
- No validation that stored R² values are valid

#### 4. Very Large Number of Drivers

**Current limit:** None enforced
- Shapley with 20 drivers = 2^20 = 1,048,576 models
- Should warn or error if n > 10-15 drivers

#### 5. Factor Variables in Data

**Not handled:** If data contains factors/characters
- Type coercion (line 60) might create nonsense numeric codes
- Should validate that variables are truly numeric/ordinal

### 🔵 MINOR - Code Quality

#### 1. Magic Numbers

- Line 74: `n_complete < 30` - should be configurable
- Line 122: `pmax(eigen_decomp$values, 0)` - no tolerance threshold defined

#### 2. No Logging/Debugging

- No intermediate validation of calculated values
- Can't trace which subset failed if Shapley errors

#### 3. Column Name Hardcoding

- Output sheet names hardcoded (04_output.R)
- Column names in importance data frame hardcoded

---

## KNOWN LIMITATIONS

### Statistical Assumptions Not Validated

1. **Linearity** - No check for linear relationships (residual plots, RESET test)
2. **Normality** - No check of residual normality (Shapiro-Wilk, Q-Q plot)
3. **Homoscedasticity** - No check for constant variance (Breusch-Pagan test)
4. **Independence** - Assumes independent observations (no autocorrelation test)
5. **Multicollinearity** - No VIF calculation or warning
6. **Outliers** - No outlier detection (Cook's D, leverage, studentized residuals)
7. **Influential points** - No DFFITS or DFBETAS

### Features Not Implemented

1. **Confidence intervals** - No bootstrapped CIs for importance scores
2. **Significance testing** - No p-values for importance differences
3. **Cross-validation** - No holdout validation of model
4. **Interaction effects** - Assumes purely additive model
5. **Non-linear relationships** - No polynomial or spline terms
6. **Categorical predictors** - Only handles numeric drivers
7. **Weights** - No survey weights or case weights
8. **Subgroup analysis** - No moderator or segment analysis
9. **Hierarchical models** - No grouped drivers or nested structures

### Computational Limitations

1. **Shapley complexity:** O(2^n) - impractical for >15 drivers
2. **Memory usage:** Stores all 2^n R² values in memory
3. **No parallelization:** Sequential model fitting
4. **No caching:** Recalculates all models even if data unchanged

### Output Limitations

1. **No visualizations:** No tornado charts, importance plots, or diagnostics
2. **No model equation:** Doesn't print fitted equation with coefficients
3. **No residual diagnostics:** No plots or tests in output
4. **Limited metadata:** Output doesn't record date, software version, runtime

---

## VALIDATION CHECKLIST FOR EXTERNAL REVIEWERS

### Statistical Correctness
- [ ] Shapley value formula matches Shapley (1953) or Lipovetsky & Conklin (2001)
- [ ] Relative weights implementation matches Johnson (2000) exactly
- [ ] Beta weight standardization is correct
- [ ] Percentage normalization is appropriate for all methods
- [ ] All methods should produce values ≥0 for R² decomposition

### Edge Case Handling
- [ ] Perfect multicollinearity detection
- [ ] Zero variance predictor detection
- [ ] Sample size adequacy checks (rule of thumb: n > 10k)
- [ ] Maximum driver count warning (recommend n ≤ 15)
- [ ] Missing data patterns examined

### Mathematical Correctness
- [ ] Eigenvalue truncation at zero is statistically valid
- [ ] Matrix operations are numerically stable
- [ ] Factorial calculations won't overflow for large n
- [ ] Division by zero protection is complete

### Code Bugs
- [ ] Index errors in loops (off-by-one)
- [ ] Variable name mismatches
- [ ] Data type assumptions violated
- [ ] Memory leaks or inefficient allocations

### Statistical Validity
- [ ] Methods appropriate for survey research context
- [ ] Assumptions documented and checked
- [ ] Results interpretation guidance is accurate
- [ ] Known limitations properly disclosed

---

## REFERENCES

1. **Shapley, L. S. (1953).** A value for n-person games. Contributions to the Theory of Games, 2(28), 307-317.

2. **Johnson, J. W. (2000).** A heuristic method for estimating the relative weight of predictor variables in multiple regression. Multivariate Behavioral Research, 35(1), 1-19.

3. **Lipovetsky, S., & Conklin, M. (2001).** Analysis of regression in game theory approach. Applied Stochastic Models in Business and Industry, 17(4), 319-330.

4. **Grömping, U. (2006).** Relative importance for linear regression in R: The package relaimpo. Journal of Statistical Software, 17(1), 1-27.

5. **Tonidandel, S., & LeBreton, J. M. (2011).** Relative importance analysis: A useful supplement to regression analysis. Journal of Business and Psychology, 26(1), 1-9.

---

## CONTACT & QUESTIONS

For questions about this code review package or the implementation:

- **Module Location:** `/home/user/Turas/modules/keydriver/`
- **Test Data Location:** `/home/user/Turas/test_data/`
- **Documentation:** `/home/user/Turas/modules/keydriver/README.md`
- **Review Package Created:** 2025-11-30

---

**END OF CODE REVIEW PACKAGE**
