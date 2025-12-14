# ==============================================================================
# TEST SCRIPT: Variable Type Bug Fixes
# ==============================================================================
# Tests the fix for:
# 1. ResponseID: "System" -> "Open_End"
# 2. Single-choice questions: "Single_Mention" -> "Single_Response"
# ==============================================================================

source("modules/AlchemerParser/run_alchemerparser.R")

cat("\n")
cat("==============================================================================\n")
cat("  TESTING ALCHEMERPARSER VARIABLE TYPE FIXES\n")
cat("==============================================================================\n\n")

# Store test results
test_results <- list()
all_passed <- TRUE

# ==============================================================================
# Helper Functions
# ==============================================================================

test_project <- function(project_name, project_dir, expected_questions = NULL) {
  cat(sprintf("\n--- Testing: %s ---\n", project_name))

  if (!dir.exists(project_dir)) {
    cat(sprintf("⚠️  SKIPPED: Directory not found: %s\n", project_dir))
    return(list(
      project = project_name,
      status = "SKIPPED",
      reason = "Directory not found"
    ))
  }

  # Run parser
  result <- tryCatch({
    run_alchemerparser(
      project_dir = project_dir,
      verbose = FALSE
    )
  }, error = function(e) {
    cat(sprintf("❌ ERROR: %s\n", e$message))
    return(NULL)
  })

  if (is.null(result)) {
    return(list(
      project = project_name,
      status = "FAILED",
      reason = "Parser error"
    ))
  }

  # Initialize checks
  checks <- list()

  # Check 1: ResponseID should be Open_End
  if ("ResponseID" %in% names(result$questions)) {
    rid_type <- result$questions$ResponseID$variable_type
    checks$responseid <- list(
      name = "ResponseID type",
      expected = "Open_End",
      actual = rid_type,
      passed = (rid_type == "Open_End")
    )
  }

  # Check 2: Count Single_Response questions
  single_response_count <- 0
  for (q_num in names(result$questions)) {
    q <- result$questions[[q_num]]
    if (!q$is_grid && q$variable_type == "Single_Response") {
      single_response_count <- single_response_count + 1
    }
  }
  checks$single_response <- list(
    name = "Single_Response count",
    actual = single_response_count,
    passed = (single_response_count > 0)  # Should have at least some
  )

  # Check 3: No invalid variable types
  invalid_types <- c("System", "Single_Mention")
  found_invalid <- character(0)

  for (q_num in names(result$questions)) {
    q <- result$questions[[q_num]]

    if (q$is_grid && !is.null(q$sub_questions)) {
      # Check sub-questions
      for (sub_q in q$sub_questions) {
        if (sub_q$variable_type %in% invalid_types) {
          found_invalid <- c(found_invalid, sprintf("%s/%s:%s",
                                                     q_num, sub_q$suffix,
                                                     sub_q$variable_type))
        }
      }
    } else {
      # Check main question
      if (q$variable_type %in% invalid_types) {
        found_invalid <- c(found_invalid, sprintf("%s:%s", q_num, q$variable_type))
      }
    }
  }

  checks$no_invalid <- list(
    name = "No invalid types",
    expected = "0 invalid types",
    actual = if (length(found_invalid) == 0) "0 invalid types" else paste(found_invalid, collapse=", "),
    passed = (length(found_invalid) == 0)
  )

  # Check 4: Question count (if expected provided)
  if (!is.null(expected_questions)) {
    checks$question_count <- list(
      name = "Question count",
      expected = expected_questions,
      actual = result$summary$n_questions,
      passed = (result$summary$n_questions == expected_questions)
    )
  }

  # Check 5: No validation flags (or just warnings/review)
  error_flags <- sum(sapply(result$validation_flags, function(f) f$severity == "ERROR"))
  checks$no_errors <- list(
    name = "No error flags",
    expected = "0 errors",
    actual = sprintf("%d errors", error_flags),
    passed = (error_flags == 0)
  )

  # Print results
  all_checks_passed <- TRUE
  for (check in checks) {
    status_icon <- if (check$passed) "✅" else "❌"
    cat(sprintf("  %s %s\n", status_icon, check$name))
    if (!is.null(check$expected)) {
      cat(sprintf("      Expected: %s\n", check$expected))
      cat(sprintf("      Actual:   %s\n", check$actual))
    } else {
      cat(sprintf("      Result: %s\n", check$actual))
    }

    if (!check$passed) {
      all_checks_passed <- FALSE
    }
  }

  overall_status <- if (all_checks_passed) "PASSED" else "FAILED"
  status_icon <- if (all_checks_passed) "✅" else "❌"
  cat(sprintf("\n  %s Overall: %s\n", status_icon, overall_status))

  return(list(
    project = project_name,
    status = overall_status,
    checks = checks,
    summary = result$summary
  ))
}

# ==============================================================================
# Test 1: HV2025 (Regression Test)
# ==============================================================================

test_results$hv2025 <- test_project(
  "HV2025 (Helderberg Village)",
  "/mnt/w/2025/01_Setup/",
  expected_questions = 67
)

if (test_results$hv2025$status == "FAILED") {
  all_passed <- FALSE
}

# ==============================================================================
# Test 2: CCPB CSAT2025 (Regression Test)
# ==============================================================================

test_results$ccpb <- test_project(
  "CCPB CSAT2025",
  "/mnt/w/CCPB CSAT2025/01_Setup/",
  expected_questions = 124
)

if (test_results$ccpb$status == "FAILED") {
  all_passed <- FALSE
}

# ==============================================================================
# Test 3: New Data (Bug Discovery Dataset)
# ==============================================================================
# NOTE: Update this path with your actual new data location

cat("\n--- Testing: New Data (where bug was found) ---\n")
cat("⚠️  MANUAL TEST REQUIRED\n")
cat("    Please run the parser on your new data manually:\n")
cat("    \n")
cat("    result <- run_alchemerparser(\n")
cat("      project_dir = \"/path/to/your/new/data/\",\n")
cat("      verbose = TRUE\n")
cat("    )\n")
cat("    \n")
cat("    Then verify:\n")
cat("    1. ResponseID is classified as 'Open_End'\n")
cat("    2. Single-choice questions are 'Single_Response'\n")
cat("    3. No 'System' or 'Single_Mention' types appear\n")

# ==============================================================================
# Summary Report
# ==============================================================================

cat("\n")
cat("==============================================================================\n")
cat("  TEST SUMMARY\n")
cat("==============================================================================\n\n")

for (test_name in names(test_results)) {
  result <- test_results[[test_name]]
  status_icon <- switch(result$status,
                       "PASSED" = "✅",
                       "FAILED" = "❌",
                       "SKIPPED" = "⚠️")

  cat(sprintf("%s %s: %s\n", status_icon, result$project, result$status))

  if (result$status == "PASSED" && !is.null(result$summary)) {
    cat(sprintf("    Questions: %d | Columns: %d | Flags: %d\n",
                result$summary$n_questions,
                result$summary$n_columns,
                result$summary$n_flags))
  }
}

cat("\n")

if (all_passed && all(sapply(test_results, function(r) r$status != "SKIPPED"))) {
  cat("✅ ALL TESTS PASSED - Safe to merge to main\n")
} else if (any(sapply(test_results, function(r) r$status == "FAILED"))) {
  cat("❌ SOME TESTS FAILED - Do not merge until issues are resolved\n")
} else {
  cat("⚠️  SOME TESTS SKIPPED - Review results before merging\n")
}

cat("\n")
cat("==============================================================================\n\n")

# Return test results invisibly
invisible(test_results)
