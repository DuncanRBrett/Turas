# ==============================================================================
# Module Smoke Tests
# ==============================================================================
# Verifies that all core modules can be loaded without errors
# This catches configuration issues, missing dependencies, and syntax errors
# ==============================================================================

# Find Turas root
find_test_turas_root <- function() {
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        dir.exists(file.path(current_dir, "modules", "shared"))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }
  stop("Cannot locate Turas root directory")
}

turas_root <- find_test_turas_root()

# ==============================================================================
# Shared Utilities Smoke Tests
# ==============================================================================

test_that("Shared utilities directory exists", {
  shared_lib <- file.path(turas_root, "modules", "shared", "lib")
  expect_true(dir.exists(shared_lib))
})

test_that("All shared utility files exist", {
  shared_lib <- file.path(turas_root, "modules", "shared", "lib")

  expected_files <- c(
    "config_utils.R",
    "formatting_utils.R",
    "weights_utils.R",
    "validation_utils.R",
    "data_utils.R",
    "logging_utils.R"
  )

  for (f in expected_files) {
    expect_true(
      file.exists(file.path(shared_lib, f)),
      info = paste("Missing:", f)
    )
  }
})

test_that("config_utils.R loads without error", {
  expect_no_error(
    source(file.path(turas_root, "modules", "shared", "lib", "config_utils.R"))
  )
  expect_true(exists("find_turas_root", mode = "function"))
})

test_that("formatting_utils.R loads without error", {
  expect_no_error(
    source(file.path(turas_root, "modules", "shared", "lib", "formatting_utils.R"))
  )
  expect_true(exists("format_number", mode = "function"))
})

test_that("weights_utils.R loads without error", {
  expect_no_error(
    source(file.path(turas_root, "modules", "shared", "lib", "weights_utils.R"))
  )
  expect_true(exists("calculate_weight_efficiency", mode = "function"))
})

test_that("validation_utils.R loads without error", {
  expect_no_error(
    source(file.path(turas_root, "modules", "shared", "lib", "validation_utils.R"))
  )
  expect_true(exists("validate_data_frame", mode = "function"))
})

# ==============================================================================
# Module Directory Structure Tests
# ==============================================================================

test_that("All expected modules exist", {
  modules_dir <- file.path(turas_root, "modules")

  expected_modules <- c(
    "tabs",
    "tracker",
    "maxdiff",
    "keydriver",
    "catdriver",
    "conjoint",
    "confidence",
    "segment",
    "pricing",
    "AlchemerParser",
    "shared"
  )

  for (m in expected_modules) {
    expect_true(
      dir.exists(file.path(modules_dir, m)),
      info = paste("Missing module:", m)
    )
  }
})

test_that("All modules have README.md", {
  modules_dir <- file.path(turas_root, "modules")

  # Only check user-facing modules (not shared)
  user_modules <- c(
    "tabs", "tracker", "maxdiff", "keydriver", "catdriver",
    "conjoint", "confidence", "segment", "pricing", "AlchemerParser"
  )

  for (m in user_modules) {
    readme_path <- file.path(modules_dir, m, "README.md")
    expect_true(
      file.exists(readme_path),
      info = paste("Missing README.md in:", m)
    )
  }
})

# ==============================================================================
# Core Documentation Tests
# ==============================================================================

test_that("Core documentation files exist", {
  expected_docs <- c(
    "CONTRIBUTING.md",
    "CHANGELOG.md"
  )

  for (doc in expected_docs) {
    expect_true(
      file.exists(file.path(turas_root, doc)),
      info = paste("Missing:", doc)
    )
  }
})

test_that("ADR directory exists with documents", {
  adr_dir <- file.path(turas_root, "docs", "adr")
  expect_true(dir.exists(adr_dir))

  adr_files <- list.files(adr_dir, pattern = "\\.md$")
  expect_gte(length(adr_files), 3)  # At least 3 ADRs
})

# ==============================================================================
# Launch File Tests
# ==============================================================================
test_that("Main launch file exists", {
  expect_true(file.exists(file.path(turas_root, "launch_turas.R")))
})

# ==============================================================================
# Summary
# ==============================================================================

cat("\n=== Module Smoke Tests Complete ===\n")
cat(sprintf("Turas root: %s\n", turas_root))
cat(sprintf("Modules found: %d\n", length(list.dirs(file.path(turas_root, "modules"), recursive = FALSE))))
