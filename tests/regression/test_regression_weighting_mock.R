# ==============================================================================
# TURAS REGRESSION TEST: WEIGHTING MODULE (SMOKE TESTS)
# ==============================================================================
#
# Tests the Weighting module structure and basic functionality
#
# Author: TURAS Development Team
# Version: 1.0
# Date: 2025-12-25
# Status: COMPLETE - Ready to run
# ==============================================================================

library(testthat)

# ==============================================================================
# HELPER: FIND TURAS ROOT
# ==============================================================================

find_turas_root <- function() {
  current_dir <- getwd()
  max_depth <- 10
  depth <- 0

  while (current_dir != dirname(current_dir) && depth < max_depth) {
    if (file.exists(file.path(current_dir, "modules", "weighting", "run_weighting.R"))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
    depth <- depth + 1
  }

  return(NULL)
}

# ==============================================================================
# SMOKE TESTS
# ==============================================================================

test_that("Weighting module directory structure exists", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  weighting_dir <- file.path(turas_root, "modules", "weighting")

  # Check main files exist
  expect_true(file.exists(file.path(weighting_dir, "run_weighting.R")))
  expect_true(file.exists(file.path(weighting_dir, "run_weighting_gui.R")))
  expect_true(dir.exists(file.path(weighting_dir, "lib")))
  expect_true(dir.exists(file.path(weighting_dir, "docs")))
  expect_true(dir.exists(file.path(weighting_dir, "templates")))
})

test_that("Weighting library files exist", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  lib_dir <- file.path(turas_root, "modules", "weighting", "lib")

  # Check required library files
  required_libs <- c(
    "config_loader.R",
    "design_weights.R",
    "rim_weights.R",
    "trimming.R",
    "diagnostics.R",
    "output.R",
    "validation.R"
  )

  for (lib_file in required_libs) {
    lib_path <- file.path(lib_dir, lib_file)
    expect_true(file.exists(lib_path),
               info = paste("Missing library file:", lib_file))
  }
})

test_that("No hardcoded paths in weighting module", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  weighting_dir <- file.path(turas_root, "modules", "weighting")
  r_files <- list.files(weighting_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)

  hardcoded_paths <- character(0)

  for (file in r_files) {
    content <- readLines(file, warn = FALSE)

    # Check for common hardcoded path patterns
    # Allow /Users/duncan/ in comments or strings that reference user paths as examples
    hardcoded_lines <- grep("/Users/[a-zA-Z]+/|C:\\\\Users\\\\|D:\\\\|/home/[a-z]+/",
                           content, value = TRUE)

    # Filter out comments and documentation examples
    hardcoded_lines <- hardcoded_lines[!grepl("^\\s*#", hardcoded_lines)]

    if (length(hardcoded_lines) > 0) {
      hardcoded_paths <- c(hardcoded_paths,
                          paste0(basename(file), ": ", hardcoded_lines))
    }
  }

  # Should find no hardcoded paths
  expect_equal(length(hardcoded_paths), 0,
               info = paste("Hardcoded paths found:", paste(hardcoded_paths, collapse = "\n")))
})

test_that("Weighting module can be sourced without errors", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  weighting_script <- file.path(turas_root, "modules", "weighting", "run_weighting.R")

  # Source in isolated environment to avoid CLI execution
  test_env <- new.env()
  expect_error(
    sys.source(weighting_script, envir = test_env),
    NA  # No error expected
  )

  # Check key functions are defined
  expect_true(exists("run_weighting", envir = test_env, mode = "function"))
  expect_true(exists("quick_design_weight", envir = test_env, mode = "function"))
  expect_true(exists("quick_rim_weight", envir = test_env, mode = "function"))
})

test_that("Config loader functions are available", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  config_loader <- file.path(turas_root, "modules", "weighting", "lib", "config_loader.R")

  test_env <- new.env()
  source(config_loader, local = test_env)

  # Check key config functions exist
  expect_true(exists("load_weighting_config", envir = test_env, mode = "function"))
  expect_true(exists("resolve_config_path", envir = test_env, mode = "function"))
  expect_true(exists("get_weight_spec", envir = test_env, mode = "function"))
  expect_true(exists("get_design_targets", envir = test_env, mode = "function"))
  expect_true(exists("get_rim_targets", envir = test_env, mode = "function"))
})

test_that("Design weights functions are available", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  design_weights_file <- file.path(turas_root, "modules", "weighting", "lib", "design_weights.R")

  test_env <- new.env()
  source(design_weights_file, local = test_env)

  # Check key design weight functions exist
  expect_true(exists("calculate_design_weights", envir = test_env, mode = "function"))
  expect_true(exists("normalize_design_weights", envir = test_env, mode = "function"))
})

test_that("Rim weights functions are available", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  rim_weights_file <- file.path(turas_root, "modules", "weighting", "lib", "rim_weights.R")

  test_env <- new.env()
  source(rim_weights_file, local = test_env)

  # Check key rim weight functions exist
  expect_true(exists("calculate_rim_weights", envir = test_env, mode = "function"))
})

test_that("Path resolution uses relative paths correctly", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  config_loader <- file.path(turas_root, "modules", "weighting", "lib", "config_loader.R")

  test_env <- new.env()
  source(config_loader, local = test_env)

  resolve_config_path <- get("resolve_config_path", envir = test_env)

  # Test relative path resolution
  base_path <- "/path/to/project"
  relative_path <- "data/survey.csv"

  resolved <- resolve_config_path(relative_path, base_path)

  # Should resolve to absolute path
  expect_true(grepl("survey.csv$", resolved))
  expect_false(grepl("^\\./", resolved))  # Should not have leading ./
})

test_that("Documentation files exist", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  docs_dir <- file.path(turas_root, "modules", "weighting", "docs")

  # Check documentation files
  expect_true(file.exists(file.path(docs_dir, "USER_GUIDE.md")))
  expect_true(file.exists(file.path(docs_dir, "TECHNICAL_DOCS.md")))
  expect_true(file.exists(file.path(docs_dir, "TEMPLATE_REFERENCE.md")))
})

test_that("Template creation function exists", {
  turas_root <- find_turas_root()

  if (is.null(turas_root)) {
    skip("Cannot find Turas root directory")
  }

  template_script <- file.path(turas_root, "modules", "weighting", "templates", "create_template.R")

  expect_true(file.exists(template_script))

  # Read file and check function definition exists (don't execute it)
  content <- readLines(template_script, warn = FALSE)
  has_function <- any(grepl("create_weight_config_template\\s*<-\\s*function", content))

  expect_true(has_function,
             info = "create_weight_config_template function should be defined in create_template.R")
})

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n=== Weighting Module Smoke Tests Complete ===\n")
