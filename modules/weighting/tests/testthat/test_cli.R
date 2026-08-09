# ==============================================================================
# TESTS: Command Line Interface
# ==============================================================================
# These tests launch run_weighting.R in a real subprocess, the way the README
# documents it:
#
#   Rscript run_weighting.R path/to/Weight_Config.xlsx
#
# Sourcing the file in-process cannot cover this: setup.R sets
# TURAS_LAUNCHER_ACTIVE, so run_cli() never fires, and the shared infrastructure
# is already loaded by then. A subprocess is the only way to prove that the CLI
# entry point resolves its own dependencies.
# ==============================================================================

#' Skip when the subprocess cannot be launched
#' @keywords internal
skip_if_no_rscript <- function() {
  testthat::skip_if_not(file.exists(file.path(R.home("bin"), "Rscript")),
                        "Rscript binary not found")
  testthat::skip_if_not_installed("withr")
}

#' Run run_weighting.R in a subprocess and capture output plus exit status
#'
#' Uses --vanilla so the child skips the project .Rprofile (and the renv
#' bootstrap it triggers), then hands it this session's library paths so it sees
#' exactly the packages the test session sees. Working directory is the Turas
#' root, which is one of the two documented invocation points.
#'
#' @param args Character vector of command line arguments
#' @return List with `status` (integer exit code) and `output` (single string)
#' @keywords internal
run_cli_subprocess <- function(args = character()) {
  rscript <- file.path(R.home("bin"), "Rscript")
  script <- file.path(TURAS_ROOT, "modules", "weighting", "run_weighting.R")

  out <- withr::with_dir(
    TURAS_ROOT,
    withr::with_envvar(
      c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)),
      suppressWarnings(
        system2(
          rscript,
          args = c("--vanilla", shQuote(script), shQuote(args)),
          stdout = TRUE,
          stderr = TRUE
        )
      )
    )
  )

  status <- attr(out, "status")
  list(
    status = if (is.null(status)) 0L else as.integer(status),
    output = paste(out, collapse = "\n")
  )
}

test_that("CLI prints usage and exits 1 when no config file is given", {
  skip_if_no_rscript()

  result <- run_cli_subprocess()

  expect_equal(result$status, 1L)
  expect_match(result$output, "Usage: Rscript run_weighting.R", fixed = TRUE)
})

test_that("CLI refuses cleanly for a missing config instead of crashing", {
  skip_if_no_rscript()

  # Regression guard: run_cli() wraps run_weighting() in with_refusal_handler(),
  # which lives in the shared infrastructure that run_weighting() itself loads.
  # Without an explicit load in run_cli(), every CLI invocation died with
  # 'could not find function "with_refusal_handler"' before doing any work.
  missing_config <- file.path(tempdir(), "no_such_weight_config.xlsx")
  expect_false(file.exists(missing_config))

  result <- run_cli_subprocess(missing_config)

  expect_false(grepl("could not find function", result$output, fixed = TRUE))
  expect_match(result$output, "[REFUSE]", fixed = TRUE)
  expect_equal(result$status, 1L)
})

test_that("CLI runs a real config end to end and exits 0", {
  skip_if_no_rscript()
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("readxl")
  skip_if_not_installed("survey")

  work_dir <- file.path(tempdir(), "weighting_cli_test")
  dir.create(work_dir, showWarnings = FALSE)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  data_path <- write_test_survey_csv(create_simple_survey(n = 200),
                                     output_dir = work_dir)
  output_path <- file.path(work_dir, "weighted.xlsx")
  config_path <- create_design_weight_config(data_path,
                                             output_dir = work_dir,
                                             output_file = output_path)

  result <- run_cli_subprocess(config_path)

  expect_false(grepl("could not find function", result$output, fixed = TRUE))
  expect_equal(result$status, 0L)
  expect_true(file.exists(output_path))
})
