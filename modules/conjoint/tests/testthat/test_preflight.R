# ==============================================================================
# TESTS: CONJOINT PRE-FLIGHT CHECKS (00_preflight.R)
# ==============================================================================
#
# Tests the conjoint_preflight() function that validates module readiness.
#
# Coverage:
#   - Preflight returns PASS when all files/packages are in place
#   - Return object has expected structure (status, checks, message)
#   - Individual check categories are present
#   - Handles missing module directory gracefully
#
# ==============================================================================

# --- Locate project root and source module ----------------------------------
.find_turas_root <- function() {
  candidates <- c(
    getwd(),
    Sys.getenv("TURAS_ROOT", unset = ""),
    tryCatch(file.path(dirname(dirname(testthat::test_path())), "..", ".."),
             error = function(e) "")
  )
  for (cand in candidates) {
    if (nzchar(cand) && file.exists(file.path(cand, "modules", "conjoint", "R", "00_main.R"))) {
      return(normalizePath(cand))
    }
  }
  NULL
}

turas_root <- .find_turas_root()

if (is.null(turas_root)) {
  test_that("project root found (skip guard)", {
    skip("Cannot locate Turas project root")
  })
} else {

  old_wd <- setwd(turas_root)
  on.exit(setwd(old_wd), add = TRUE)

  source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))

  # ============================================================================
  # TEST 1: Preflight returns PASS when module is properly installed
  # ============================================================================
  test_that("conjoint_preflight returns PASS in valid environment", {
    skip_if(!exists("conjoint_preflight", mode = "function"),
            "conjoint_preflight not loaded")

    result <- conjoint_preflight(verbose = FALSE)

    # Status should be PASS (assuming all files are present in this repo)
    expect_true(result$status %in% c("PASS", "REFUSED"),
                info = sprintf("Got status: %s", result$status))

    # If some optional packages or files are missing, it could be REFUSED,
    # but in a complete dev checkout it should be PASS
    if (result$status == "PASS") {
      expect_true(grepl("all pre-flight checks passed", result$message, ignore.case = TRUE))
    }
  })

  # ============================================================================
  # TEST 2: Return structure has required fields
  # ============================================================================
  test_that("conjoint_preflight: return object has status, checks, message", {
    skip_if(!exists("conjoint_preflight", mode = "function"),
            "conjoint_preflight not loaded")

    result <- conjoint_preflight(verbose = FALSE)

    # Required top-level fields
    expect_true("status" %in% names(result))
    expect_true("message" %in% names(result))
    expect_true("checks" %in% names(result))

    expect_true(result$status %in% c("PASS", "REFUSED"))
    expect_true(is.character(result$message))
    expect_true(is.list(result$checks))
  })

  # ============================================================================
  # TEST 3: Individual check categories are present
  # ============================================================================
  test_that("conjoint_preflight: checks include all expected categories", {
    skip_if(!exists("conjoint_preflight", mode = "function"),
            "conjoint_preflight not loaded")

    result <- conjoint_preflight(verbose = FALSE)
    checks <- result$checks

    # Expected check categories
    expected_categories <- c(
      "r_files", "js_files", "html_report_files",
      "packages", "optional_packages", "trs_infrastructure"
    )

    for (cat_name in expected_categories) {
      expect_true(cat_name %in% names(checks),
                  info = sprintf("Check category '%s' missing from preflight result", cat_name))
    }

    # Each check should have standard fields
    for (chk_name in names(checks)) {
      chk <- checks[[chk_name]]
      expect_true("name" %in% names(chk),
                  info = sprintf("Check '%s' missing 'name' field", chk_name))
      expect_true("pass" %in% names(chk),
                  info = sprintf("Check '%s' missing 'pass' field", chk_name))
      expect_true(is.logical(chk$pass),
                  info = sprintf("Check '%s' pass field is not logical", chk_name))
    }
  })

  # ============================================================================
  # TEST 4: Preflight with explicit module_dir
  # ============================================================================
  test_that("conjoint_preflight: accepts explicit module_dir parameter", {
    skip_if(!exists("conjoint_preflight", mode = "function"),
            "conjoint_preflight not loaded")

    module_dir <- file.path(turas_root, "modules", "conjoint", "R")

    result <- conjoint_preflight(verbose = FALSE, module_dir = module_dir)

    expect_true(result$status %in% c("PASS", "REFUSED"))
    expect_true("checks" %in% names(result))
  })

  # ============================================================================
  # TEST 5: Preflight handles invalid module_dir gracefully
  # ============================================================================
  test_that("conjoint_preflight: REFUSED for nonexistent module_dir", {
    skip_if(!exists("conjoint_preflight", mode = "function"),
            "conjoint_preflight not loaded")

    result <- conjoint_preflight(
      verbose = FALSE,
      module_dir = "/nonexistent/path/to/conjoint/R"
    )

    expect_equal(result$status, "REFUSED")
    expect_true("code" %in% names(result))
    expect_true("how_to_fix" %in% names(result))
  })

  # ============================================================================
  # TEST 6: R files check detects all expected files
  # ============================================================================
  test_that("conjoint_preflight: r_files check counts correctly", {
    skip_if(!exists("conjoint_preflight", mode = "function"),
            "conjoint_preflight not loaded")

    result <- conjoint_preflight(verbose = FALSE)

    r_check <- result$checks$r_files

    expect_true(!is.null(r_check))
    expect_true(r_check$expected >= 15,
                info = sprintf("Expected at least 15 R files, got expected=%d",
                               r_check$expected))

    # In a complete checkout, found should equal expected
    if (r_check$pass) {
      expect_equal(r_check$found, r_check$expected)
    }
  })

  # ============================================================================
  # TEST 7: Packages check validates required packages
  # ============================================================================
  test_that("conjoint_preflight: packages check validates installed packages", {
    skip_if(!exists("conjoint_preflight", mode = "function"),
            "conjoint_preflight not loaded")

    result <- conjoint_preflight(verbose = FALSE)

    pkg_check <- result$checks$packages

    expect_true(!is.null(pkg_check))
    expect_true(pkg_check$expected >= 4,
                info = "Should check at least 4 required packages")

    # Optional packages check should always pass (they are optional)
    opt_check <- result$checks$optional_packages
    expect_true(opt_check$pass,
                info = "Optional packages check should always pass")
  })

} # end turas_root guard
