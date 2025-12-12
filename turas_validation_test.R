# ==============================================================================
# TURAS CONJOINT MODULE - VALIDATION TEST SCRIPT
# ==============================================================================
# Run this script after implementation to validate results
# ==============================================================================

# Expected results from statsmodels analysis (ChatGPT)
# Use these as benchmarks for validation

EXPECTED_RESULTS <- list(
  
  # DE Noodle dataset - expected importance ranges
  DE_noodle = list(
    importance = list(
      NutriScore = c(min = 45, max = 65),
      Price = c(min = 8, max = 22),
      MSG = c(min = 5, max = 18),
      PotassiumChloride = c(min = 4, max = 15),
      `I+G` = c(min = 0.1, max = 12),  # Can be small but NOT zero
      Salt = c(min = 0.5, max = 10)
    ),
    # Approximate utility directions (sign matters)
    utility_signs = list(
      Price = c(Low = "+", Mid = "+", High = "-"),
      MSG = c(Absent = "+", Present = "-"),
      PotassiumChloride = c(Absent = "+", Present = "-"),
      `I+G` = c(Absent = "+", Present = "-"),
      Salt = c(Normal = "-", Reduced = "+"),
      NutriScore = c(A = "+", B = "+", C = "-", D = "-", E = "-")
    )
  )
)


#' Validate Conjoint Results
#'
#' Compares computed results against expected benchmarks.
#'
#' @param results Results list from run_conjoint_analysis()
#' @param dataset_name Name of dataset for benchmark lookup
#' @return List with validation results and any issues found
validate_results <- function(results, dataset_name = "DE_noodle") {
  
  issues <- character(0)
  warnings <- character(0)
  
  expected <- EXPECTED_RESULTS[[dataset_name]]
  if (is.null(expected)) {
    return(list(valid = NA, message = "No benchmark data for this dataset"))
  }
  
  # --- Test 1: Check for zero importance ---
  cat("\n=== Test 1: Zero Importance Check ===\n")
  
  importance <- results$importance
  zero_importance <- importance$Attribute[importance$Importance < 0.1]
  
  if (length(zero_importance) > 0) {
    issues <- c(issues, sprintf(
      "CRITICAL: Zero importance for: %s", 
      paste(zero_importance, collapse = ", ")
    ))
    cat("  ✗ FAIL: Found attributes with ~0%% importance\n")
  } else {
    cat("  ✓ PASS: All attributes have non-zero importance\n")
  }
  
  # --- Test 2: Importance ranges ---
  cat("\n=== Test 2: Importance Range Validation ===\n")
  
  for (attr in names(expected$importance)) {
    range <- expected$importance[[attr]]
    actual <- importance$Importance[importance$Attribute == attr]
    
    if (length(actual) == 0) {
      warnings <- c(warnings, sprintf("Attribute '%s' not found in results", attr))
      next
    }
    
    if (actual < range["min"] || actual > range["max"]) {
      warnings <- c(warnings, sprintf(
        "%s importance %.1f%% outside expected range [%.0f%%, %.0f%%]",
        attr, actual, range["min"], range["max"]
      ))
      cat(sprintf("  ? %s: %.1f%% (expected %.0f-%.0f%%)\n", 
                  attr, actual, range["min"], range["max"]))
    } else {
      cat(sprintf("  ✓ %s: %.1f%% (within range)\n", attr, actual))
    }
  }
  
  # --- Test 3: Utility sign check ---
  cat("\n=== Test 3: Utility Direction Check ===\n")
  
  utilities <- results$utilities
  sign_issues <- 0
  
  for (attr in names(expected$utility_signs)) {
    signs <- expected$utility_signs[[attr]]
    
    for (level in names(signs)) {
      expected_sign <- signs[[level]]
      actual_util <- utilities$Utility[utilities$Attribute == attr & 
                                        utilities$Level == level]
      
      if (length(actual_util) == 0) next
      
      actual_sign <- if (actual_util > 0.05) "+" else if (actual_util < -0.05) "-" else "~0"
      
      if (expected_sign == "+" && actual_util < -0.05) {
        sign_issues <- sign_issues + 1
        cat(sprintf("  ? %s/%s: expected positive, got %.3f\n", 
                    attr, level, actual_util))
      } else if (expected_sign == "-" && actual_util > 0.05) {
        sign_issues <- sign_issues + 1
        cat(sprintf("  ? %s/%s: expected negative, got %.3f\n",
                    attr, level, actual_util))
      }
    }
  }
  
  if (sign_issues == 0) {
    cat("  ✓ PASS: All utility signs as expected\n")
  } else {
    warnings <- c(warnings, sprintf("%d utility signs differ from expected", sign_issues))
  }
  
  # --- Test 4: Zero-centering check ---
  cat("\n=== Test 4: Zero-Centering Check ===\n")
  
  attr_sums <- aggregate(Utility ~ Attribute, data = utilities, FUN = sum)
  centering_issues <- attr_sums$Attribute[abs(attr_sums$Utility) > 0.01]
  
  if (length(centering_issues) > 0) {
    issues <- c(issues, sprintf(
      "Utilities not zero-centered for: %s",
      paste(centering_issues, collapse = ", ")
    ))
    cat("  ✗ FAIL: Some attributes not properly zero-centered\n")
  } else {
    cat("  ✓ PASS: All utilities properly zero-centered\n")
  }
  
  # --- Test 5: Model fit ---
  cat("\n=== Test 5: Model Fit Statistics ===\n")
  
  fit <- results$fit
  
  if (!is.null(fit$mcfadden_r2)) {
    if (fit$mcfadden_r2 < 0.05) {
      issues <- c(issues, "McFadden R² very low (<0.05)")
      cat(sprintf("  ✗ McFadden R²: %.4f (very low)\n", fit$mcfadden_r2))
    } else if (fit$mcfadden_r2 < 0.1) {
      warnings <- c(warnings, "McFadden R² low (<0.10)")
      cat(sprintf("  ? McFadden R²: %.4f (low but acceptable)\n", fit$mcfadden_r2))
    } else {
      cat(sprintf("  ✓ McFadden R²: %.4f (good)\n", fit$mcfadden_r2))
    }
  }
  
  if (!is.null(fit$hit_rate)) {
    # Random choice with 3 alternatives = 33%
    if (fit$hit_rate < 0.4) {
      warnings <- c(warnings, "Hit rate below 40%")
      cat(sprintf("  ? Hit Rate: %.1f%% (low)\n", fit$hit_rate * 100))
    } else {
      cat(sprintf("  ✓ Hit Rate: %.1f%%\n", fit$hit_rate * 100))
    }
  }
  
  # --- Summary ---
  cat("\n=== VALIDATION SUMMARY ===\n")
  
  if (length(issues) == 0 && length(warnings) == 0) {
    cat("✓ ALL TESTS PASSED\n")
    valid <- TRUE
  } else if (length(issues) == 0) {
    cat(sprintf("✓ PASSED with %d warning(s):\n", length(warnings)))
    for (w in warnings) cat(sprintf("  - %s\n", w))
    valid <- TRUE
  } else {
    cat(sprintf("✗ FAILED with %d critical issue(s):\n", length(issues)))
    for (i in issues) cat(sprintf("  - %s\n", i))
    if (length(warnings) > 0) {
      cat(sprintf("  Plus %d warning(s)\n", length(warnings)))
    }
    valid <- FALSE
  }
  
  list(
    valid = valid,
    issues = issues,
    warnings = warnings
  )
}


#' Run Full Validation Suite
#'
#' Tests the complete conjoint module workflow.
#'
#' @param config_file Path to config file
#' @param data_file Path to data file (Alchemer export)
run_validation_suite <- function(config_file = NULL, data_file = NULL) {
  
  cat("\n")
  cat(rep("=", 70), "\n", sep = "")
  cat("TURAS CONJOINT MODULE - VALIDATION SUITE\n")
  cat(rep("=", 70), "\n", sep = "")
  
  # Use defaults if not specified
  if (is.null(data_file)) {
    data_file <- "DE_noodle_conjoint_raw.xlsx"
  }
  
  # --- Step 1: Test Alchemer Import ---
  cat("\n>>> Step 1: Testing Alchemer Import\n")
  
  import_result <- tryCatch({
    df <- import_alchemer_conjoint(data_file)
    list(
      success = TRUE,
      data = df,
      n_rows = nrow(df),
      n_respondents = length(unique(df$resp_id)),
      n_choice_sets = length(unique(df$choice_set_id)),
      attributes = setdiff(names(df), c("resp_id", "choice_set_id", "alternative_id", "chosen"))
    )
  }, error = function(e) {
    list(success = FALSE, error = e$message)
  })
  
  if (!import_result$success) {
    cat(sprintf("✗ IMPORT FAILED: %s\n", import_result$error))
    return(invisible(NULL))
  }
  
  cat(sprintf("✓ Imported: %d rows, %d respondents, %d choice sets\n",
              import_result$n_rows, 
              import_result$n_respondents,
              import_result$n_choice_sets))
  cat(sprintf("  Attributes: %s\n", paste(import_result$attributes, collapse = ", ")))
  
  # --- Step 2: Build config from data ---
  cat("\n>>> Step 2: Building Configuration\n")
  
  # Auto-detect attribute levels from data
  config <- list(
    settings = list(
      analysis_type = "choice",
      choice_set_column = "choice_set_id",
      chosen_column = "chosen",
      respondent_id_column = "resp_id",
      alternative_id_column = "alternative_id"
    ),
    attributes = data.frame(
      AttributeName = import_result$attributes,
      NumLevels = sapply(import_result$attributes, function(a) {
        length(unique(import_result$data[[a]]))
      }),
      stringsAsFactors = FALSE
    )
  )
  
  # Add levels list
  config$attributes$levels_list <- lapply(import_result$attributes, function(a) {
    sort(unique(import_result$data[[a]]))
  })
  
  cat(sprintf("✓ Config built with %d attributes\n", nrow(config$attributes)))
  
  # --- Step 3: Run Analysis ---
  cat("\n>>> Step 3: Running Analysis\n")

  analysis_result <- tryCatch({
    # Build proper data_list structure
    data_list <- list(
      data = import_result$data,
      n_respondents = import_result$n_respondents,
      n_choice_sets = import_result$n_choice_sets,
      n_profiles = nrow(import_result$data)
    )

    # Add required config fields
    config$analysis_type <- "choice"
    config$estimation_method <- "auto"
    config$respondent_id_column <- "resp_id"
    config$choice_set_column <- "choice_set_id"
    config$chosen_column <- "chosen"
    config$alternative_id_column <- "alternative_id"

    # Use the main estimation function (handles mlogit/clogit fallback)
    estimate_choice_model(data_list, config)
  }, error = function(e) {
    list(success = FALSE, error = e$message)
  })
  
  if (is.null(analysis_result$coefficients)) {
    cat(sprintf("✗ ANALYSIS FAILED: %s\n", analysis_result$error %||% "Unknown error"))
    return(invisible(NULL))
  }

  cat(sprintf("✓ Analysis complete using %s\n", analysis_result$method %||% "unknown"))

  # --- Step 4: Calculate Utilities ---
  cat("\n>>> Step 4: Calculating Utilities\n")

  utilities_result <- tryCatch({
    calculate_utilities(analysis_result, config)
  }, error = function(e) {
    list(success = FALSE, error = e$message)
  })

  if (is.null(utilities_result$utilities)) {
    cat(sprintf("✗ UTILITIES CALCULATION FAILED: %s\n", utilities_result$error %||% "Unknown error"))
    return(invisible(NULL))
  }

  analysis_result$utilities <- utilities_result$utilities
  cat("✓ Utilities calculated\n")

  # --- Step 5: Calculate Importance ---
  cat("\n>>> Step 5: Calculating Importance\n")

  importance <- calculate_attribute_importance(utilities_result$utilities, config)
  analysis_result$importance <- importance

  cat("✓ Importance calculated\n")

  # Add fit statistics for validation
  if (!is.null(analysis_result$loglik)) {
    ll_null <- analysis_result$loglik["null"]
    ll_fitted <- analysis_result$loglik["fitted"]
    mcfadden_r2 <- 1 - (ll_fitted / ll_null)

    analysis_result$fit <- list(
      mcfadden_r2 = mcfadden_r2,
      log_likelihood = ll_fitted,
      aic = analysis_result$aic,
      bic = analysis_result$bic
    )
  }

  # --- Step 6: Validate Results ---
  cat("\n>>> Step 6: Validating Results\n")

  validation <- validate_results(analysis_result, "DE_noodle")
  
  # --- Final Report ---
  cat("\n")
  cat(rep("=", 70), "\n", sep = "")
  if (validation$valid) {
    cat("VALIDATION COMPLETE - MODULE IS WORKING CORRECTLY\n")
  } else {
    cat("VALIDATION COMPLETE - ISSUES FOUND (see above)\n")
  }
  cat(rep("=", 70), "\n", sep = "")
  
  invisible(analysis_result)
}


# Null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x
