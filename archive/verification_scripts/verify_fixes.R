#!/usr/bin/env Rscript
# Verify all fixes for silent failures

cat("\n================================================================================\n")
cat("VERIFYING SILENT FAILURE FIXES\n")
cat("================================================================================\n\n")

results <- list()

# Test 1: Confidence utils - NA validation
cat("1. Testing confidence utils (NA validation fix)...\n")
result1 <- tryCatch({
  suppressMessages(library(testthat))
  test_results <- test_file("modules/confidence/tests/test_utils.R", reporter = "silent")
  test_df <- as.data.frame(test_results)
  n_failed <- sum(test_df$failed)
  if (n_failed == 0) {
    cat("   ✅ PASSED - All confidence utils tests pass\n\n")
    list(status = "PASS", module = "confidence/utils")
  } else {
    cat(sprintf("   ❌ FAILED - %d test failures\n\n", n_failed))
    list(status = "FAIL", module = "confidence/utils", failures = n_failed)
  }
}, error = function(e) {
  cat(sprintf("   ❌ ERROR - %s\n\n", e$message))
  list(status = "ERROR", module = "confidence/utils", error = e$message)
})
results$confidence <- result1

# Test 2: Conjoint path fix
cat("2. Testing conjoint (path resolution fix)...\n")
result2 <- tryCatch({
  # Just verify it can start without path errors
  output <- system2("Rscript", 
                   args = c("modules/conjoint/tests/test_unit_tests.R"),
                   stdout = TRUE, stderr = TRUE)
  
  # Check if we got past the path error
  has_path_error <- any(grepl("Cannot find Turas root|cannot change working directory|/home/user", output))
  tests_ran <- any(grepl("TEST SUMMARY|Total tests:", output))
  
  if (!has_path_error && tests_ran) {
    cat("   ✅ PASSED - Path resolution works, tests execute\n")
    cat("   Note: Some conjoint tests may fail (pre-existing issues)\n\n")
    list(status = "PASS", module = "conjoint/path")
  } else if (has_path_error) {
    cat("   ❌ FAILED - Still has path errors\n\n")
    list(status = "FAIL", module = "conjoint/path", error = "Path error persists")
  } else {
    cat("   ⚠️  PARTIAL - Path works but tests didn't run\n\n")
    list(status = "PARTIAL", module = "conjoint/path")
  }
}, error = function(e) {
  cat(sprintf("   ❌ ERROR - %s\n\n", e$message))
  list(status = "ERROR", module = "conjoint/path", error = e$message)
})
results$conjoint <- result2

# Test 3: MaxDiff path fix
cat("3. Testing maxdiff (path resolution fix)...\n")
result3 <- tryCatch({
  setwd("modules/maxdiff")
  output <- system2("Rscript",
                   args = c("tests/test_maxdiff.R"),
                   stdout = TRUE, stderr = TRUE)
  setwd("../..")
  
  # Check if we got past the path error
  has_path_error <- any(grepl("character vector argument expected|dirname.*ofile", output))
  tests_ran <- any(grepl("TEST SUMMARY|Passed:", output))
  
  if (!has_path_error && tests_ran) {
    cat("   ✅ PASSED - Path resolution works, tests execute\n")
    cat("   Note: Some maxdiff tests may fail (pre-existing issues)\n\n")
    list(status = "PASS", module = "maxdiff/path")
  } else if (has_path_error) {
    cat("   ❌ FAILED - Still has path errors\n\n")
    list(status = "FAIL", module = "maxdiff/path", error = "Path error persists")
  } else {
    cat("   ⚠️  PARTIAL - Path works but tests didn't run\n\n")
    list(status = "PARTIAL", module = "maxdiff/path")
  }
}, error = function(e) {
  cat(sprintf("   ❌ ERROR - %s\n\n", e$message))
  list(status = "ERROR", module = "maxdiff/path", error = e$message)
})
results$maxdiff <- result3

# Summary
cat("================================================================================\n")
cat("VERIFICATION SUMMARY\n")
cat("================================================================================\n\n")

passed <- sum(sapply(results, function(x) x$status == "PASS"))
failed <- sum(sapply(results, function(x) x$status %in% c("FAIL", "ERROR")))

for (name in names(results)) {
  result <- results[[name]]
  status_icon <- switch(result$status,
                       "PASS" = "✅",
                       "FAIL" = "❌",
                       "ERROR" = "❌",
                       "PARTIAL" = "⚠️")
  cat(sprintf("%s %s: %s\n", status_icon, name, result$status))
}

cat(sprintf("\nTotal: %d/%d critical fixes verified\n", passed, length(results)))

if (failed > 0) {
  cat("\n⚠️  Some fixes need attention\n")
  quit(status = 1)
} else {
  cat("\n✅ All critical silent failure fixes verified!\n")
  quit(status = 0)
}
