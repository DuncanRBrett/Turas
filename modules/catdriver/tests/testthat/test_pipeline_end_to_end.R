# ==============================================================================
# CATDRIVER - THE WHOLE PIPELINE, ONCE, ON A REAL CONFIG WORKBOOK
# ==============================================================================
# Before this file the suite had no test that ran run_categorical_keydriver()
# at all. Every test called a function directly, which is how a module can be
# green on 800 expectations while its subgroup comparison has been dead for
# years and its weighted bootstrap has never once produced an interval.
#
# This builds the module's own demo (data plus config workbooks) in a temporary
# directory, never in the repository, and runs the binary subgroup config the
# way the GUI does. It takes about a minute. That is the price of knowing the
# pipeline works.
# ==============================================================================

.cd_demo_dir <- function() {
  dir <- file.path(tempdir(), paste0("cd_demo_", as.integer(Sys.time())))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  assign("demo_output_dir", dir, envir = env)
  suppressMessages(suppressWarnings(
    sys.source(file.path(turas_root, "modules/catdriver/examples/demo/generate_demo.R"),
               envir = env)
  ))
  dir
}

.cd_with_captured_stats_pack <- function(expr) {
  captured <- NULL
  had_writer <- exists("turas_write_stats_pack", envir = globalenv(), inherits = FALSE)
  original <- if (had_writer) get("turas_write_stats_pack", envir = globalenv()) else NULL
  assign("turas_write_stats_pack", function(payload, path) { captured <<- payload; path },
         envir = globalenv())
  on.exit({
    if (had_writer) {
      assign("turas_write_stats_pack", original, envir = globalenv())
    } else {
      rm("turas_write_stats_pack", envir = globalenv())
    }
  }, add = TRUE)
  result <- force(expr)
  list(result = result, stats_pack = captured)
}

test_that("a weighted subgroup study runs end to end and every Session A fix is in the result", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("nnet")
  skip_if(!exists("run_categorical_keydriver", mode = "function"),
          "catdriver pipeline not loaded")

  demo_dir <- .cd_demo_dir()
  on.exit(unlink(demo_dir, recursive = TRUE), add = TRUE)
  cfg <- file.path(demo_dir, "demo_config_binary_subgroup.xlsx")
  expect_true(file.exists(cfg))

  # The GUI sets this before running; without it the HTML step cannot find its
  # own builders and prints an error box.
  had_lib <- exists(".catdriver_lib_dir", envir = globalenv(), inherits = FALSE)
  old_lib <- if (had_lib) get(".catdriver_lib_dir", envir = globalenv()) else NULL
  assign(".catdriver_lib_dir", file.path(turas_root, "modules", "catdriver", "lib"),
         envir = globalenv())
  on.exit({
    if (had_lib) assign(".catdriver_lib_dir", old_lib, envir = globalenv())
    else rm(".catdriver_lib_dir", envir = globalenv())
  }, add = TRUE)

  run <- .cd_with_captured_stats_pack(
    suppressMessages(utils::capture.output(
      res <- with_refusal_handler(run_categorical_keydriver(cfg)),
      type = "output"
    ))
  )
  results <- res

  # --- the run itself ---------------------------------------------------------
  expect_false(is_refusal(results))
  expect_equal(results$run_status, "PARTIAL")     # one subgroup legitimately fails
  expect_true(length(results$degraded_reasons) > 0)

  # --- C2: the subgroup comparison exists -------------------------------------
  cmp <- results$subgroup_comparison
  expect_false(is.null(cmp))
  expect_gt(nrow(cmp$importance_matrix), 0)
  expect_gt(nrow(cmp$or_comparison), 0)
  expect_gt(nrow(cmp$model_fit), 1)
  expect_true("classification" %in% names(cmp$importance_matrix))
  expect_true(any(is.finite(cmp$or_comparison$Total_or)))

  # a subgroup that failed is named, not swallowed
  expect_true(any(grepl("Subgroup '61\\\\+' failed|Subgroup .61", results$degraded_reasons)))

  # --- H2: the weighting stamp travels ----------------------------------------
  wd <- results$weight_diagnostics
  expect_false(is.null(wd))
  expect_true(nzchar(wd$inference_stamp))
  expect_true(grepl("NOT applied", wd$inference_stamp))
  expect_true(wd$effective_n > 0 && wd$effective_n <= wd$n_weights)
  # the per-respondent weight vector must not ride along into the report layer
  expect_null(wd$normalisation$weights)

  # --- A7: provenance ---------------------------------------------------------
  expect_true("method" %in% names(results$importance))
  expect_true(all(nzchar(results$importance$method)))

  pack <- run$stats_pack
  expect_false(is.null(pack))
  expect_true(grepl("LR chi-square share", pack$assumptions$`Importance Method`))
  expect_true(grepl("frequency weights", pack$assumptions$Weighting))
  expect_true(pack$data_used$weighted)
  expect_gt(pack$data_used$n_excluded, 0)
  expect_equal(pack$data_used$questions_analysed, length(results$importance$variable))

  # --- M4: the lift table names the level it describes ------------------------
  if (!is.null(results$probability_lift)) {
    expect_true("outcome_level" %in% names(results$probability_lift))
    expect_true(all(nzchar(results$probability_lift$outcome_level)))
  }
})

test_that("the same study with bootstrap intervals turned on produces them", {
  skip_if_not_installed("openxlsx")
  skip_if(!exists("run_categorical_keydriver", mode = "function"),
          "catdriver pipeline not loaded")

  demo_dir <- .cd_demo_dir()
  on.exit(unlink(demo_dir, recursive = TRUE), add = TRUE)
  cfg <- file.path(demo_dir, "demo_config_binary.xlsx")

  had_lib <- exists(".catdriver_lib_dir", envir = globalenv(), inherits = FALSE)
  old_lib <- if (had_lib) get(".catdriver_lib_dir", envir = globalenv()) else NULL
  assign(".catdriver_lib_dir", file.path(turas_root, "modules", "catdriver", "lib"),
         envir = globalenv())
  on.exit({
    if (had_lib) assign(".catdriver_lib_dir", old_lib, envir = globalenv())
    else rm(".catdriver_lib_dir", envir = globalenv())
  }, add = TRUE)

  run <- .cd_with_captured_stats_pack(
    suppressMessages(utils::capture.output(
      res <- with_refusal_handler(run_categorical_keydriver(
        cfg, config_overrides = list(bootstrap_ci = TRUE, bootstrap_reps = 30)
      )),
      type = "output"
    ))
  )

  expect_false(is_refusal(res))
  # H5: a weighted binary study used to lose every bootstrap interval in silence
  expect_false(is.null(res$bootstrap_results))
  expect_gt(res$bootstrap_results$n_successful, 0)
  expect_true("boot_ci_lower" %in% names(res$odds_ratios))
  expect_true(any(is.finite(res$odds_ratios$boot_ci_lower)))
  expect_true(any(is.finite(res$odds_ratios$sign_stability)))
  expect_true(nzchar(res$bootstrap_results$caveat))
})
