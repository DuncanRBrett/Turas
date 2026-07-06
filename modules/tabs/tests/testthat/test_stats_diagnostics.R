# ==============================================================================
# TABS MODULE — STATS DIAGNOSTICS TESTS
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
  expect_equal(p$assumptions[["Weighting"]], "Yes — w_final")
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
    assumptions = list("Weighting" = "Yes — w_final", "Alpha (p-value threshold)" = "0.050"),
    run_result = list(status = status, events = events), packages = c("openxlsx", "readxl"))
}

test_that("diagnostics_for_island shapes the curated sections (no config echo)", {
  isl <- diagnostics_for_island(mk_payload())
  expect_equal(isl$status, "PASS")
  titles <- vapply(isl$sections, function(s) s$title, "")
  expect_equal(titles, c("Declaration", "Data received & used",
                         "Assumptions & parameters", "Reproducibility"))
  expect_false("Configuration" %in% titles)   # curated — config echo stays in Excel

  # rows are ordered [label, value] pairs
  decl <- isl$sections[[1]]$rows
  expect_true(any(vapply(decl, function(r) r[[1]] == "Project" && r[[2]] == "SACAP", logical(1))))

  # data-used carries the formatted "rows × columns"
  dru <- isl$sections[[2]]$rows
  expect_true(any(vapply(dru, function(r) r[[1]] == "Rows × columns" &&
                                          grepl("1,363", r[[2]], fixed = TRUE), logical(1))))

  # assumptions passed through, display-ready, in order
  expect_equal(isl$sections[[3]]$rows[[1]], c("Weighting", "Yes — w_final"))
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

test_that("diagnostics_for_island renders missing values as an em dash, never NA", {
  bare <- diagnostics_for_island(list(module = "TABS", status = "PASS"))
  decl <- bare$sections[[1]]$rows
  proj <- Filter(function(r) r[[1]] == "Project", decl)[[1]]
  expect_equal(proj[[2]], "—")   # em dash placeholder, not NA/empty
})
