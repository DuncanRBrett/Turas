# D11: the three wording fixes of Session D had no test.
#
# F8, F9 and F17 were each corrected on 21 September 2026 and each could be
# reverted with the whole suite green. The independent review of 22 September
# proved it for F17, whose paragraph ships in every final report: with the old
# false sentence restored the full segment suite still passed 1355 of 1355.
# That is the shape of F13 of the September review, where four fixes survived
# a revert unnoticed.
#
# These tests pin the three. Each was watched failing against a reverted fix
# rather than against absent code, because the fixes were already in.


# ------------------------------------------------------------------------------
# F17: the Variable Importance intro promised a share of the total distinction
# that the F-statistic basis does not deliver.
# ------------------------------------------------------------------------------

test_that("the importance intro ranks the variables and does not promise a share", {
  html <- as.character(build_seg_importance_section(
    tables = list(), charts = list(),
    html_data = list(variable_importance = NULL)))

  # The claim that was withdrawn. "25%" was the worked example it used.
  expect_false(grepl("total distinction", html, fixed = TRUE))
  expect_false(grepl("contributes one quarter", html, fixed = TRUE))
  # What it says instead.
  expect_true(grepl("rank the variables against each other", html, fixed = TRUE))
  expect_true(grepl("order of strength", html, fixed = TRUE))
})

test_that("the percentages the intro describes really do sum to 100", {
  # The intro says they "sum to 100 by construction". They are built as
  # f_statistic / sum(f_statistic) * 100 in the transformer, so this is the
  # arithmetic behind the sentence above rather than a restatement of it.
  profile_data <- data.frame(
    Variable = c("a", "b", "c", "d"),
    F_statistic = c(90.5, 40.25, 20, 9.75),
    p_value = c(1e-9, 1e-5, 1e-3, 0.04),
    stringsAsFactors = FALSE
  )
  vi <- .extract_variable_importance(profile_data)

  expect_false(is.null(vi))
  expect_true("importance_pct" %in% names(vi))
  expect_lt(abs(sum(vi$importance_pct) - 100), 0.11)
  # And they rank: the largest F statistic carries the largest percentage.
  expect_equal(vi$variable[which.max(vi$importance_pct)], "a")
})


# ------------------------------------------------------------------------------
# F9: a mini-batch run was told to raise nstart, which it does not take.
# ------------------------------------------------------------------------------

test_that("the convergence lever names a setting the algorithm actually takes", {
  mb <- seg_convergence_lever(TRUE)
  expect_true(grepl("batch_size", mb, fixed = TRUE))
  expect_true(grepl("seed", mb, fixed = TRUE))
  # The point of F9: mini-batch must not be told to raise nstart.
  expect_false(grepl("increasing nstart", mb, fixed = TRUE))

  std <- seg_convergence_lever(FALSE)
  expect_true(grepl("nstart", std, fixed = TRUE))
  expect_false(grepl("batch_size", std, fixed = TRUE))

  expect_false(identical(mb, std))
})

test_that("mini-batch really does ignore nstart, which is why F9 was a finding", {
  # The warning's old advice was wrong because the mini-batch path takes no
  # nstart argument at all. Read from the function's own formals rather than
  # asserted.
  expect_true(exists("run_minibatch_kmeans", mode = "function"))
  expect_false("nstart" %in% names(formals(run_minibatch_kmeans)))
})


# ------------------------------------------------------------------------------
# F8: the GUI's console block does not also reach the launching terminal,
# because the capture sink is not split.
# ------------------------------------------------------------------------------

test_that("the console block is written with cat, so a sink captures it", {
  outcome <- segment_gui_outcome(structure(
    list(run_status = "REFUSE", refused = TRUE, code = "DATA_MISSING_VARS",
         title = "Clustering Variables Not Found",
         problem = "Variables q7, q8 are not in the data file.",
         how_to_fix = "Check the spelling", message = "full refusal text"),
    class = "turas_refusal_result"))

  # The GUI's own capture: sink to a file, unsplit, exactly as run_segment_gui
  # opens it. What the block prints has to land in the file.
  # Close only the sink this test opens. `sink.number() > 0` also closed the
  # test runner's own log sink (tools/run_all_tests.R), which then crashed the
  # rest of the file with "invalid connection" (review 2026-09-24).
  f <- tempfile()
  sinks_before <- sink.number()
  sink(f, type = "output")
  on.exit({ if (sink.number() > sinks_before) sink(type = "output") }, add = TRUE)
  segment_gui_console_block(outcome)
  sink(type = "output")

  captured <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_true(grepl("DATA_MISSING_VARS", captured, fixed = TRUE))
})

test_that("the GUI's capture sink is not split, which is what the comment claims", {
  # F8 was a comment that said the block also reached the terminal behind the
  # app. It does not, because this sink has no split. Adding split = TRUE
  # would make the comment true and double every line for anyone who launched
  # from a terminal, so this test guards the decision rather than the prose.
  gui <- file.path(Sys.getenv("TURAS_ROOT"), "modules", "segment",
                   "run_segment_gui.R")
  skip_if_not(file.exists(gui), "run_segment_gui.R not found")
  src <- readLines(gui, warn = FALSE)

  opens <- grep("^\\s*sink\\(output_capture_file", src)
  expect_length(opens, 1L)
  expect_false(grepl("split", src[opens], fixed = TRUE))
})
