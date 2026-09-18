# ==============================================================================
# KEYDRIVER - THE SUIDERLAND WORKED EXAMPLE, END TO END
# ==============================================================================
# The only test in this module that runs the whole pipeline. Everything else
# checks a part in isolation, which is how a call that dies while writing the
# workbook, and three features that never produced a number, all survived with
# green tests around them.
#
# The example's outcome is built from known standardised effects, so this
# asserts the answer, not just that something came back.
# ==============================================================================

example_script <- file.path(project_root, "examples", "keydriver",
                            "create_keydriver_example.R")
skip_if(!file.exists(example_script), "example generator not present")
# Loaded rather than skipped (review F17).
kd_ensure_module_loaded("all")
expect_true(exists("run_keydriver_analysis_impl", mode = "function"))

old_opt <- getOption("turas.example.no_run")
options(turas.example.no_run = TRUE)
source(example_script, local = FALSE)
options(turas.example.no_run = old_opt)

kd_example_dir <- file.path(tempdir(), "suiderland_keydriver")
unlink(kd_example_dir, recursive = TRUE)
invisible(capture.output(
  kd_ex <- build_keydriver_example(out_dir = kd_example_dir, verbose = FALSE)))

kd_run <- function(cfg) {
  invisible(capture.output(
    r <- suppressWarnings(run_keydriver_analysis_impl(cfg))))
  r
}

test_that("the example builds both configs and the data file (A11)", {
  expect_true(file.exists(kd_ex$data_file))
  expect_true(file.exists(kd_ex$config))
  expect_true(file.exists(kd_ex$config_mixed))
  expect_equal(nrow(kd_ex$data), 900)
  expect_true(all(c("overall_satisfaction", "weight", "age_band", "customer_tier",
                    "contact_channel", names(KD_EXAMPLE_TRUTH)) %in% names(kd_ex$data)))
})

test_that("the continuous config runs clean and recovers the known order", {
  r <- kd_run(kd_ex$config)
  expect_equal(r$run_status, "PASS")

  imp <- r$importance
  expect_true(is.data.frame(imp))
  truth <- names(KD_EXAMPLE_TRUTH)

  # Two independent measures, one known answer. Relative weights could not have
  # done this before C1: two drivers always split 50/50 and the rest followed
  # the wrong decomposition.
  expect_equal(imp$Driver[order(-imp$Relative_Weight)], truth)
  expect_equal(imp$Driver[order(-imp$Shapley_Value)], truth)

  # The strongest driver is unmistakably strongest, not marginally so.
  rw <- imp$Relative_Weight[match(truth, imp$Driver)]
  expect_gt(rw[1], 2 * rw[2])
  expect_equal(which.min(rw), 5L)
})

test_that("both segment variables are analysed, not just the first (C2)", {
  r <- kd_run(kd_ex$config)
  # The Segments sheet names two variables and groups four age bands into two.
  # The call site read segment_variable[1] and ignored segment_values entirely.
  expect_setequal(names(r$segment_comparisons), c("age_band", "customer_tier"))
  age <- r$segment_comparisons$age_band$comparison_matrix
  expect_true(is.data.frame(age))
  pct <- setdiff(grep("_Pct$", names(age), value = TRUE), "Mean_Pct")
  expect_setequal(pct, c("Younger_Pct", "Older_Pct"))
})

test_that("the run records what it actually did", {
  r <- kd_run(kd_ex$config)
  # Provenance names the engine that ran, not a constant (H3).
  expect_match(.kd_primary_method(list(importance = r$importance)), "shapley")
  # Dominance was asked for and fitted weighted (H5). The pipeline stores the
  # inner result, not the {status, message, result} wrapper.
  expect_true(is.list(r$dominance))
  expect_true(isTRUE(r$dominance$weighted))
  expect_equal(r$dominance$weight_variable, "weight")
  # The shares reconstruct the WEIGHTED model R-squared, which is the identity
  # the sqrt(w) transform used to miss.
  w <- kd_ex$data$weight
  f <- stats::as.formula(paste("overall_satisfaction ~",
                               paste(names(KD_EXAMPLE_TRUTH), collapse = " + ")))
  weighted_r2 <- summary(stats::lm(f, data = kd_ex$data, weights = w))$r.squared
  expect_equal(sum(r$dominance$general_dominance), weighted_r2, tolerance = 1e-6)
  expect_equal(length(r$dominance$drivers_omitted), 0)
})

test_that("the mixed config degrades honestly rather than inventing numbers", {
  r <- kd_run(kd_ex$config_mixed)
  # A bootstrap cannot resample a factor and a correlation is not defined for
  # one. Both refuse by name and the run says so.
  expect_equal(r$run_status, "PARTIAL")
  reasons <- paste(unlist(r$status$degraded_reasons %||% character(0)), collapse = " ")
  expect_match(reasons, "contact_channel")

  # And the continuous drivers still come back in the right order.
  imp <- r$importance
  cont <- imp[imp$Driver %in% names(KD_EXAMPLE_TRUTH), ]
  expect_equal(cont$Driver[order(-cont$Relative_Weight)], names(KD_EXAMPLE_TRUTH))
  # The categorical driver is present and scored, not silently dropped.
  expect_true("contact_channel" %in% imp$Driver)
  expect_false(is.na(imp$Beta_Weight[imp$Driver == "contact_channel"]))
})

test_that("the pipeline writes its workbook", {
  # This is the test that would have caught a helper called with a variable
  # that does not exist in the writer's scope, which no unit test could see.
  r <- kd_run(kd_ex$config)
  out <- file.path(kd_example_dir, "Output", "Suiderland_KeyDriver_Results.xlsx")
  expect_true(file.exists(out))
  sheets <- openxlsx::getSheetNames(out)
  expect_true("Run_Status" %in% sheets)
  status <- openxlsx::read.xlsx(out, sheet = "Run_Status", skipEmptyRows = FALSE)
  method <- status[[2]][status[[1]] == "primary_method"]
  expect_length(method, 1)
  expect_match(method, "shapley")
  expect_false(grepl("partial_r2", method, fixed = TRUE))
})
