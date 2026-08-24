# ==============================================================================
# TABS MODULE - EMPTY SUBGROUP TESTS
# ==============================================================================
#
# A base filter that matches nobody is a fact about the study, not a broken
# config: a "bought for someone else" measure in a category nobody buys for
# others, or a routed question no one reached. Before this, such a question
# reached create_banner_row_indices with a zero-row frame, which refuses
# (validate_data_frame, min_rows = 1) — and that refusal abandoned every
# remaining question in the run.
#
# prepare_question_data must instead return an explained skip so the caller
# records it and carries on.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_empty_subgroup.R")
#
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
# shared_functions.R sources its siblings relative to `script_dir`, which it
# only computes when the variable is absent — set it so it resolves under testthat
assign("script_dir", file.path(turas_root, "modules/tabs/lib"), envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/shared_functions.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))
source(file.path(turas_root, "modules/tabs/lib/question_orchestrator.R"))

# ------------------------------------------------------------------------------
# Fixtures: 20 respondents. Nobody has BoughtForOther == "Yes", so any measure
# based on that subgroup is empty — the shape of the real VAS case.
# ------------------------------------------------------------------------------

make_data <- function() {
  data.frame(
    Gender = rep(c("Male", "Female"), each = 10),
    BoughtForOther = rep("No", 20),
    SpendForOther = rep(0, 20),
    SpendForSelf = c(rep(100, 10), rep(200, 10)),
    stringsAsFactors = FALSE
  )
}

make_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode = c("SpendForOther", "SpendForSelf"),
      QuestionText = c("Spend for someone else", "Spend for self"),
      Variable_Type = c("Numeric", "Numeric"),
      Columns = c(1, 1),
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = character(0), OptionText = character(0),
      DisplayOrder = numeric(0), stringsAsFactors = FALSE
    )
  )
}

make_banner <- function() {
  create_banner_structure(
    selection_df = data.frame(
      QuestionCode = "Gender", Include = "N", UseBanner = "Y",
      BannerBoxCategory = "N", BannerLabel = "Gender", DisplayOrder = 1,
      stringsAsFactors = FALSE
    ),
    survey_structure = list(
      questions = data.frame(
        QuestionCode = "Gender", QuestionText = "Gender",
        Variable_Type = "Single_Response", Columns = 1, stringsAsFactors = FALSE
      ),
      options = data.frame(
        QuestionCode = c("Gender", "Gender"),
        OptionText = c("Male", "Female"),
        DisplayText = c("Male", "Female"),
        ShowInOutput = c("Y", "Y"),
        DisplayOrder = c(1, 2), stringsAsFactors = FALSE
      )
    )
  )
}

# ------------------------------------------------------------------------------

test_that("a base filter matching nobody yields an explained skip, not a refusal", {
  data <- make_data()
  banner <- make_banner()
  weights <- rep(1, nrow(data))

  result <- prepare_question_data(
    question_code = "SpendForOther",
    base_filter = 'BoughtForOther == "Yes"',
    survey_data = data,
    survey_structure = make_structure(),
    banner_info = banner,
    master_weights = weights
  )

  expect_true(isTRUE(result$skip))
  expect_equal(result$question_code, "SpendForOther")
  expect_match(result$reason, "matches no respondents")
  # the reason must name the filter, so the console says WHICH filter emptied it
  expect_match(result$reason, "BoughtForOther", fixed = TRUE)
})

test_that("the empty subgroup does not abort — a normal question still prepares", {
  data <- make_data()
  banner <- make_banner()
  weights <- rep(1, nrow(data))
  structure <- make_structure()

  # the empty one first, exactly as it fell in the live run
  empty <- prepare_question_data("SpendForOther", 'BoughtForOther == "Yes"',
                                 data, structure, banner, weights)
  expect_true(isTRUE(empty$skip))

  # and the next question must still prepare normally
  ok <- prepare_question_data("SpendForSelf", NA_character_,
                              data, structure, banner, weights)
  expect_false(isTRUE(ok$skip))
  expect_equal(nrow(ok$filtered_data), 20)
  expect_true(length(ok$banner_row_indices) > 0)
})

test_that("a filter that keeps only one respondent still processes normally", {
  # n = 1 must NOT be treated as empty: validate_data_frame allows min_rows = 1,
  # and a base of one is a low base to warn about, not a question to drop.
  data <- make_data()
  data$BoughtForOther[1] <- "Yes"
  banner <- make_banner()
  weights <- rep(1, nrow(data))

  result <- prepare_question_data("SpendForOther", 'BoughtForOther == "Yes"',
                                  data, make_structure(), banner, weights)

  expect_false(isTRUE(result$skip))
  expect_equal(nrow(result$filtered_data), 1)
})

test_that("an unfiltered question is untouched by the empty-subgroup path", {
  data <- make_data()
  banner <- make_banner()
  result <- prepare_question_data("SpendForSelf", "",
                                  data, make_structure(), banner, rep(1, nrow(data)))
  expect_false(isTRUE(result$skip))
  expect_equal(nrow(result$filtered_data), 20)
})

# ==============================================================================
# RESUMING FROM A CHECKPOINT MUST NOT LOSE WHAT WAS ALREADY PROCESSED
# ==============================================================================
# setup_checkpointing() restores both the processed CODES and their RESULTS, but
# only the codes were passed on: the restored results were dropped, so a run
# resumed after a crash shipped without every question processed before it —
# silently, and still reporting PASS. On a live VAS run that lost the first 100
# questions (all of Demographics, VAS wallet and the prepaid sections).

test_that("process_all_questions seeds its results from the checkpoint", {
  fn <- formals(process_all_questions)
  expect_true("results_so_far" %in% names(fn))

  # and the body must SEED all_results with it, not start empty
  body_txt <- paste(deparse(body(process_all_questions)), collapse = "\n")
  expect_match(body_txt, "all_results <- results_so_far", fixed = TRUE)
  expect_false(grepl("all_results <- list()", body_txt, fixed = TRUE))
})

test_that("the runner hands the restored results down the chain", {
  runner <- file.path(turas_root, "modules/tabs/lib/crosstabs/analysis_runner.R")
  txt <- paste(readLines(runner, warn = FALSE), collapse = "\n")
  # process_questions must accept and forward them
  expect_match(txt, "results_so_far = list()", fixed = TRUE)
  expect_match(txt, "results_so_far = results_so_far", fixed = TRUE)
  # and the top-level call must pass what setup_checkpointing restored
  expect_match(txt, "checkpoint_state$all_results", fixed = TRUE)
})

# ------------------------------------------------------------------------------
# AN EMPTY SUBGROUP IS NOT A PARTIAL RESULT
# ------------------------------------------------------------------------------
# Duncan, 23 Aug 2026, on three BillVehicle_Oth_* questions in the VAS run:
# "we should not get a partial - these options had no responses and so is not a
# mistake". Nobody pays a vehicle licence on someone else's behalf, so the
# subgroup is empty and there is nothing to tabulate. That is a finding, and it
# is still listed in the diagnostics - but at INFO, and the run stays PASS.
#
# The skip is tagged with a KIND at source. Everything downstream branches on
# that tag, never on the wording of the reason, so rewording cannot silently
# turn the status back into PARTIAL.

test_that("an empty subgroup skip is tagged empty_base", {
  data <- make_data()
  result <- prepare_question_data(
    "SpendForOther", 'BoughtForOther == "Yes"',
    data, make_structure(), make_banner(), rep(1, nrow(data))
  )

  expect_true(isTRUE(result$skip))
  expect_identical(result$kind, "empty_base")
})

test_that("the run status ignores empty-base skips but still counts real ones", {
  orch <- file.path(turas_root, "modules/tabs/lib/question_orchestrator.R")
  txt <- paste(readLines(orch, warn = FALSE), collapse = "\n")

  # the status is computed from the skips that are NOT empty_base
  expect_match(txt, 'identical(s$kind, "empty_base")', fixed = TRUE)
  expect_match(txt, "has_skipped <- length(degrading_skips) > 0", fixed = TRUE)
  # and the old unconditional form is gone
  expect_false(grepl("has_skipped <- length(skipped_questions) > 0",
                     txt, fixed = TRUE))

  # the skip entry carries the kind down to the logger
  expect_match(txt, "kind = skip_kind", fixed = TRUE)
})

test_that("an empty-base skip logs at INFO, every other skip stays PARTIAL", {
  wb <- file.path(turas_root, "modules/tabs/lib/crosstabs/workbook_builder.R")
  txt <- paste(readLines(wb, warn = FALSE), collapse = "\n")

  expect_match(txt, "turas_run_state_info", fixed = TRUE)
  expect_match(txt, "TABS_EMPTY_BASE_%s", fixed = TRUE)
  # the PARTIAL path survives for the other kinds
  expect_match(txt, "TABS_SKIP_%s", fixed = TRUE)
  expect_match(txt, 'identical(skip_info$kind, "empty_base")', fixed = TRUE)
})

test_that("the console disclosure lists empty subgroups apart from faults", {
  runner <- file.path(turas_root, "modules/tabs/lib/crosstabs/analysis_runner.R")
  txt <- paste(readLines(runner, warn = FALSE), collapse = "\n")

  # they must not be printed under ACTION REQUIRED as things to go and fix
  expect_match(txt, "NO RESPONDENTS TO TABULATE", fixed = TRUE)
  expect_match(txt, "degrading_skips", fixed = TRUE)
})
