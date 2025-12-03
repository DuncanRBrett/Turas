# ==============================================================================
# TURAS REGRESSION TEST: TABS MODULE (WORKING MOCK VERSION)
# ==============================================================================
#
# This is a WORKING proof-of-concept that demonstrates the regression test
# pattern with a mock Tabs implementation. Once the Tabs module is refactored
# to expose a callable function, replace the mock with real Tabs calls.
#
# Author: TURAS Development Team
# Version: 1.0 (Working Mock)
# Date: 2025-12-02
# Status: COMPLETE - Ready to run
# ==============================================================================

library(testthat)

# Source helpers (only if not already loaded)
if (!exists("check_numeric")) {
  source("tests/regression/helpers/assertion_helpers.R")
}
if (!exists("get_example_paths")) {
  source("tests/regression/helpers/path_helpers.R")
}

# ==============================================================================
# MOCK TABS IMPLEMENTATION
# ==============================================================================
# This simulates what the Tabs module would return based on the MODULE OUTPUT
# CONTRACT documented in run_crosstabs.R
#
# When Tabs is refactored, replace this with actual Tabs function calls

#' Mock Tabs Module - Simulates Tabs output structure
#'
#' @param data_path Character. Path to data CSV
#' @param config_path Character. Path to config XLSX (ignored for now)
#' @return List. Simulated Tabs output matching MODULE OUTPUT CONTRACT
mock_tabs_module <- function(data_path, config_path = NULL) {

  # Load data
  data <- read.csv(data_path, stringsAsFactors = FALSE)

  # Calculate simple statistics to match our golden values
  # (In real Tabs, these would come from the crosstabulation engine)

  # Overall metrics
  overall_mean_satisfaction <- mean(data$satisfaction, na.rm = TRUE)
  overall_mean_recommend <- mean(data$recommend, na.rm = TRUE)

  # By gender
  male_data <- data[data$gender == "Male", ]
  female_data <- data[data$gender == "Female", ]

  mean_satisfaction_male <- mean(male_data$satisfaction, na.rm = TRUE)
  mean_satisfaction_female <- mean(female_data$satisfaction, na.rm = TRUE)

  # Significance test (simple t-test)
  sig_test <- t.test(male_data$satisfaction, female_data$satisfaction)
  sig_flag_gender <- sig_test$p.value < 0.05

  # Top 2 box (recommend 9-10)
  top2box_recommend <- sum(data$recommend >= 9, na.rm = TRUE) / nrow(data) * 100

  # Effective N (simplified - just apply average weight effect)
  if ("weight" %in% names(data)) {
    weights <- data$weight
    effective_n <- (sum(weights)^2) / sum(weights^2)

    # Weighted mean
    overall_mean_satisfaction_weighted <- weighted.mean(data$satisfaction, weights, na.rm = TRUE)
  } else {
    effective_n <- nrow(data)
    overall_mean_satisfaction_weighted <- overall_mean_satisfaction
  }

  # Build output structure matching MODULE OUTPUT CONTRACT
  output <- list(
    all_results = list(
      satisfaction = list(
        question_code = "satisfaction",
        question_text = "Overall satisfaction",
        question_type = "Rating",
        base_filter = "",
        bases = list(
          unweighted = list(Total = nrow(data), Male = nrow(male_data), Female = nrow(female_data)),
          weighted = list(Total = sum(data$weight), Male = sum(male_data$weight), Female = sum(female_data$weight)),
          effective = list(Total = effective_n, Male = NA, Female = NA)
        ),
        table = data.frame(
          RowLabel = c("Base (n=)", "Average", "Sig."),
          RowType = c("Frequency", "Average", "Sig."),
          Total = c(nrow(data), overall_mean_satisfaction, NA),
          Male = c(nrow(male_data), mean_satisfaction_male, ""),
          Female = c(nrow(female_data), mean_satisfaction_female, if(sig_flag_gender) "a" else ""),
          stringsAsFactors = FALSE
        )
      ),
      recommend = list(
        question_code = "recommend",
        question_text = "Likelihood to recommend",
        question_type = "Rating",
        base_filter = "",
        bases = list(
          unweighted = list(Total = nrow(data)),
          weighted = list(Total = sum(data$weight)),
          effective = list(Total = effective_n)
        ),
        table = data.frame(
          RowLabel = c("Base (n=)", "Average", "Top 2 Box (9-10)"),
          RowType = c("Frequency", "Average", "Column %"),
          Total = c(nrow(data), overall_mean_recommend, top2box_recommend),
          stringsAsFactors = FALSE
        )
      )
    ),
    metadata = list(
      version = "Mock 1.0",
      timestamp = Sys.time(),
      weighted = TRUE,
      weight_variable = "weight"
    ),
    summary = list(
      overall_mean_satisfaction = overall_mean_satisfaction,
      overall_mean_satisfaction_weighted = overall_mean_satisfaction_weighted,
      overall_mean_recommend = overall_mean_recommend,
      base_size_total = nrow(data),
      base_size_male = nrow(male_data),
      base_size_female = nrow(female_data),
      mean_satisfaction_male = mean_satisfaction_male,
      mean_satisfaction_female = mean_satisfaction_female,
      sig_flag_gender_satisfaction = sig_flag_gender,
      effective_n_total_weighted = effective_n,
      top2box_recommend_total = top2box_recommend
    )
  )

  return(output)
}

# ==============================================================================
# TABS OUTPUT EXTRACTOR FUNCTION
# ==============================================================================

#' Extract a specific value from Tabs output
#'
#' @param output List. The output from mock_tabs_module() (or real Tabs)
#' @param check_name Character. The name of the check to extract
#' @return The extracted value (numeric, logical, or integer)
extract_tabs_value <- function(output, check_name) {

  # Use the summary section for easy access
  # (In real Tabs, you'd navigate the all_results structure)

  if (check_name %in% names(output$summary)) {
    return(output$summary[[check_name]])
  }

  # Alternative: Extract from all_results structure
  # (Shows the pattern for real Tabs integration)

  if (check_name == "overall_mean_satisfaction_from_table") {
    satisfaction_q <- output$all_results$satisfaction
    avg_row <- satisfaction_q$table[satisfaction_q$table$RowType == "Average", ]
    return(avg_row$Total)
  }

  stop("Unknown check name: ", check_name,
       "\nAvailable checks: ", paste(names(output$summary), collapse = ", "))
}

# ==============================================================================
# REGRESSION TEST
# ==============================================================================

test_that("Tabs module: basic example produces expected outputs", {

  # 1. Load example data and config paths
  paths <- get_example_paths("tabs", "basic")

  # 2. Run Tabs module (mock version)
  output <- mock_tabs_module(
    data_path = paths$data,
    config_path = paths$config
  )

  # 3. Load golden values
  golden <- load_golden("tabs", "basic")

  # 4. Run all checks
  for (check in golden$checks) {

    # Extract actual value from output
    actual <- extract_tabs_value(output, check$name)

    # Compare based on type
    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(
        name = paste("Tabs basic:", check$description),
        actual = actual,
        expected = check$value,
        tolerance = tolerance
      )
    } else if (check$type == "logical") {
      check_logical(
        name = paste("Tabs basic:", check$description),
        actual = actual,
        expected = check$value
      )
    } else if (check$type == "integer") {
      check_integer(
        name = paste("Tabs basic:", check$description),
        actual = actual,
        expected = check$value
      )
    }
  }
})

# ==============================================================================
# NOTES FOR REAL TABS INTEGRATION
# ==============================================================================
#
# When the Tabs module is refactored to be callable:
#
# 1. Replace mock_tabs_module() with real Tabs function:
#
#    run_tabs_for_real <- function(data_path, config_path) {
#      source("modules/tabs/lib/run_crosstabs.R")
#      # Or call exported function like:
#      # output <- turas::run_tabs_analysis(data, config)
#      return(output)
#    }
#
# 2. Update extract_tabs_value() to navigate real output structure:
#
#    - Navigate output$all_results by question code
#    - Extract from table data frames
#    - Handle bases, significance flags, etc.
#
# 3. Capture real golden values:
#
#    - Run real Tabs on examples/tabs/basic/data.csv
#    - Extract actual values
#    - Update tests/regression/golden/tabs_basic.json
#
# 4. The test structure remains identical - just the implementation changes
#
# ==============================================================================
