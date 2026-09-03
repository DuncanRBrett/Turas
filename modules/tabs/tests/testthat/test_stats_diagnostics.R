# ==============================================================================
# TABS MODULE. STATS DIAGNOSTICS TESTS
# ==============================================================================
#
# Pins the diagnostic payload assembly and the curated island shaper that feed
# BOTH the Excel stats pack (turas_write_stats_pack) and the in-report
# "Statistical diagnostics" panel (project$diagnostics), so the two deliverables
# can never drift.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_stats_diagnostics.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

# stats_diagnostics.R is standalone function defs; it uses %||% at call time only.
if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
# type_utils supplies safe_logical(), which the Declaration's chi-square note
# reads the enable_chi_square toggle through. The same reader the engine uses.
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/stats_diagnostics.R"))

# ---- build_tabs_diagnostics: payload assembly from mock run objects ----------

test_that("build_tabs_diagnostics assembles a complete payload", {
  config_result <- list(
    config_obj = list(
      data_file = "sacap.xlsx", analyst_name = "Duncan", research_house = "TRL",
      apply_weighting = TRUE, weight_variable = "w_final",
      enable_significance_testing = TRUE, alpha = 0.05, min_base = 30,
      bonferroni_correction = TRUE, html_report_v2 = TRUE),
    output_path = "out.xlsx")
  data_result <- list(survey_data = data.frame(a = 1:1363, b = 1:1363), effective_n = 1217)
  analysis_result <- list(all_results = vector("list", 40),
                          skipped_questions = list("Q1", "Q2"), partial_questions = list("Q3"))
  workbook_result <- list(project_name = "SACAP",
                          run_result = list(status = "PASS", events = list()))

  p <- build_tabs_diagnostics(config_result, data_result, analysis_result,
                              workbook_result, Sys.time() - 3, "10.2")

  expect_equal(p$module, "TABS")
  expect_equal(p$project_name, "SACAP")
  expect_equal(p$turas_version, "10.2")
  expect_equal(p$data_receipt$n_rows, 1363L)
  expect_equal(p$data_receipt$n_cols, 2L)
  expect_equal(p$data_used$questions_analysed, 40L)
  expect_equal(p$data_used$questions_skipped, 2L)
  expect_equal(p$assumptions[["Weighting"]], "Yes, w_final")
  expect_equal(p$assumptions[["Significance Testing"]], "Enabled")
  expect_equal(p$assumptions[["Effective N"]], "1,217")
  expect_equal(p$status, "PASS")
})

# ---- diagnostics_for_island: curated island shaping --------------------------

mk_payload <- function(status = "PASS", events = list()) {
  list(
    module = "TABS", project_name = "SACAP", analyst_name = "Duncan", research_house = "TRL",
    run_timestamp = as.POSIXct("2026-07-06 09:30:00", tz = "UTC"), turas_version = "10.2",
    r_version = "R 4.5", status = status, duration_seconds = 3.7,
    data_receipt = list(file_name = "sacap.xlsx", n_rows = 1363, n_cols = 240),
    data_used = list(n_respondents = 1363, n_excluded = 0L, questions_analysed = 40,
                     questions_skipped = 2, questions_partial = 1),
    assumptions = list("Weighting" = "Yes, w_final", "Alpha (p-value threshold)" = "0.050"),
    run_result = list(status = status, events = events), packages = c("openxlsx", "readxl"))
}

test_that("diagnostics_for_island shapes the curated sections (no config echo)", {
  isl <- diagnostics_for_island(mk_payload())
  expect_equal(isl$status, "PASS")
  titles <- vapply(isl$sections, function(s) s$title, "")
  expect_equal(titles, c("Declaration", "Data received & used",
                         "Assumptions & parameters", "Reproducibility"))
  expect_false("Configuration" %in% titles)   # curated. Config echo stays in Excel

  # rows are ordered [label, value] pairs
  decl <- isl$sections[[1]]$rows
  expect_true(any(vapply(decl, function(r) r[[1]] == "Project" && r[[2]] == "SACAP", logical(1))))

  # data-used carries the formatted "rows × columns"
  dru <- isl$sections[[2]]$rows
  expect_true(any(vapply(dru, function(r) r[[1]] == "Rows × columns" &&
                                          grepl("1,363", r[[2]], fixed = TRUE), logical(1))))

  # assumptions passed through, display-ready, in order
  expect_equal(isl$sections[[3]]$rows[[1]], c("Weighting", "Yes, w_final"))
})

test_that("diagnostics_for_island summarises TRS warnings", {
  clean <- diagnostics_for_island(mk_payload())
  expect_equal(length(clean$warnings$events), 0)
  expect_match(clean$warnings$summary, "ran cleanly")

  evs <- list(list(level = "PARTIAL", code = "CALC_X", title = "Skipped", problem = "Low base"))
  warned <- diagnostics_for_island(mk_payload(status = "PARTIAL", events = evs))
  expect_equal(warned$status, "PARTIAL")
  expect_equal(length(warned$warnings$events), 1)
  ev <- warned$warnings$events[[1]]
  expect_equal(ev$level, "PARTIAL")
  expect_equal(ev$code, "CALC_X")
  expect_equal(ev$message, "Low base")   # PARTIAL carries $problem, mapped to message
})

test_that("diagnostics_for_island guards a NULL / non-list payload", {
  expect_null(diagnostics_for_island(NULL))
  expect_null(diagnostics_for_island("nope"))
})

test_that("diagnostics_for_island renders missing values as a dash, never NA", {
  bare <- diagnostics_for_island(list(module = "TABS", status = "PASS"))
  decl <- bare$sections[[1]]$rows
  proj <- Filter(function(r) r[[1]] == "Project", decl)[[1]]
  expect_equal(proj[[2]], "–")   # an en dash placeholder, not NA/empty
})


# ---- FPC declaration lines (cross-engine stats batch, D2) --------------------
#
# When a universe is configured the pack has to SAY the correction was applied,
# because a reader comparing this report to an uncorrected one otherwise has no
# way to know why the letters differ. Read from the real config keys. The
# lesson of review finding I4, where a contractual Declaration line printed a
# hard-coded value instead of the configured one.

# FPC_MIN_COVERAGE lives in modules/shared/lib/fpc.R, which the tabs guard
# sources; this test file loads stats_diagnostics.R on its own.
if (!exists("FPC_MIN_COVERAGE")) {
  source(file.path(turas_root, "modules/shared/lib/fpc.R"))
}

fpc_payload <- function(...) {
  extra <- list(...)
  config_obj <- modifyList(list(
    data_file = "census.xlsx", apply_weighting = FALSE,
    enable_significance_testing = TRUE, alpha = 0.05,
    significance_min_base = 30, bonferroni_correction = TRUE), extra)
  build_tabs_diagnostics(
    list(config_obj = config_obj, output_path = "out.xlsx"),
    list(survey_data = data.frame(a = 1:200, b = 1:200), effective_n = 200),
    list(all_results = vector("list", 3), skipped_questions = list(),
         partial_questions = list()),
    list(project_name = "Parity", run_result = list(status = "PASS", events = list())),
    Sys.time() - 1, "10.2")
}

test_that("no population configured leaves the Declaration untouched", {
  a <- fpc_payload()$assumptions
  expect_null(a[["Universe size"]])
  expect_null(a[["Coverage of universe"]])
  expect_null(a[["Subgroup universes"]])
  expect_null(a[["Finite population correction"]])
})

test_that("a configured universe is declared, with its coverage", {
  a <- fpc_payload(population_size = 5000)$assumptions
  expect_equal(a[["Universe size"]], "5,000")
  expect_equal(a[["Coverage of universe"]], "4.0%")     # 200 of 5,000
  expect_true(grepl("finite-population-corrected effective bases",
                    a[["Finite population correction"]], fixed = TRUE))
  # The floor is stated from the shared constant, not typed into the sentence.
  expect_true(grepl("5%", a[["Finite population correction"]], fixed = TRUE))
  # And the census rule is spelled out, since it is why a column can go blank.
  expect_true(grepl("without\\s+significance letters",
                    a[["Finite population correction"]]))
})

test_that("subgroup universes are counted from the Population frame", {
  frame <- data.frame(banner = c("Cohort", "Cohort", NA),
                      group = c("Alpha", "Beta", "Gamma"),
                      population = c(40, 150, 5000), stringsAsFactors = FALSE)
  a <- fpc_payload(population_frame = frame)$assumptions
  expect_equal(a[["Subgroup universes"]], "3 declared on the Population sheet")
  # A Population sheet alone (no study total) still declares the correction.
  expect_false(is.null(a[["Finite population correction"]]))
  expect_null(a[["Universe size"]])

  # Both together: the parity fixture's shape.
  b <- fpc_payload(population_size = 5000, population_frame = frame)$assumptions
  expect_equal(b[["Universe size"]], "5,000")
  expect_equal(b[["Subgroup universes"]], "3 declared on the Population sheet")
})


# ---- Method notes for the 2026-08 statistical-semantics changes (I1, I6) -----
#
# Both are behaviour changes to published significance letters, so the
# contractual Declaration has to say what was tested. Each is stated only when
# the run actually contains that statistic: a study with neither gets exactly
# the Declaration it got before.

method_payload <- function(question_types = character(0), ...) {
  extra <- list(...)
  config_obj <- modifyList(list(
    data_file = "study.xlsx", apply_weighting = FALSE,
    enable_significance_testing = TRUE, alpha = 0.05,
    significance_min_base = 30, bonferroni_correction = TRUE), extra)
  structure_stub <- if (length(question_types)) {
    list(questions = data.frame(
      QuestionCode = paste0("Q", seq_along(question_types)),
      Variable_Type = question_types, stringsAsFactors = FALSE))
  } else NULL
  build_tabs_diagnostics(
    list(config_obj = config_obj, output_path = "out.xlsx"),
    list(survey_data = data.frame(a = 1:200), effective_n = 200,
         survey_structure = structure_stub),
    list(all_results = vector("list", 3), skipped_questions = list(),
         partial_questions = list()),
    list(project_name = "Method", run_result = list(status = "PASS", events = list())),
    Sys.time() - 1, "10.2")
}

test_that("a study with no NPS and no chi-square declares neither note", {
  a <- method_payload(c("Rating", "Single_Response"))$assumptions
  expect_null(a[["NPS significance"]])
  expect_null(a[["Chi-square test"]])
})

test_that("an NPS question declares what its letters test", {
  a <- method_payload(c("Rating", "NPS"))$assumptions
  note <- a[["NPS significance"]]
  expect_false(is.null(note))
  expect_true(grepl("+100 promoter", note, fixed = TRUE))
  expect_true(grepl("-100 detractor", note, fixed = TRUE))
  expect_true(grepl("Standard Deviation row", note, fixed = TRUE))
  # The point of the note: it is NOT a test of the 0-10 ratings.
  expect_true(grepl("not 'do the", note, fixed = TRUE))
})

test_that("chi-square declares its inputs, and says more when weighted", {
  unweighted <- method_payload(c("Rating"), enable_chi_square = "Y")$assumptions
  note <- unweighted[["Chi-square test"]]
  expect_false(is.null(note))
  expect_true(grepl("without the rounding applied for display", note, fixed = TRUE))
  expect_false(grepl("Kish effective base", note, fixed = TRUE))

  weighted <- method_payload(c("Rating"), enable_chi_square = TRUE,
                             apply_weighting = TRUE,
                             weight_variable = "w")$assumptions
  wnote <- weighted[["Chi-square test"]]
  expect_true(grepl("Kish effective base", wnote, fixed = TRUE))
  expect_true(grepl("scale of the weights", wnote, fixed = TRUE))
})

test_that("chi-square off means no chi-square note at all", {
  expect_null(method_payload(c("Rating"))$assumptions[["Chi-square test"]])
  expect_null(method_payload(c("Rating"),
                             enable_chi_square = "N")$assumptions[["Chi-square test"]])
})
