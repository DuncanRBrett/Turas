# ==============================================================================
# TABS MODULE — READER REPORT TESTS (derivation + bundler)
# ==============================================================================
#
# Drives the Reader report generator end to end:
#   - derive_reader_model(): items ranked, headline picked, trend deltas from a
#     prior-wave island, graceful degradation with no tracking
#   - generate_reader_report(): a self-contained *_Reader.html, no external URLs,
#     the data-reader island present, and the crosstab deep-link filename embedded
#
# The data layer is built by the REAL build_data_layer(), so the derivation is
# tested against the true dl shape (not a hand-mocked one).
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_reader_report.R")
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

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))

.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))
source(file.path(turas_root, "modules/tabs/lib/reader_report/derive_reader_model.R"))
source(file.path(turas_root, "modules/tabs/lib/reader_report/build_reader_report.R"))

suppressWarnings(suppressMessages(library(jsonlite)))

# ==============================================================================
# FIXTURES
# ==============================================================================

make_banner <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("-", "A", "B"),
    column_to_banner = c("TOTAL::Total" = "TOTAL",
                         "Gender::Male" = "Gender", "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total",
                       "Gender::Male" = "Male", "Gender::Female" = "Female"),
    banner_headers = data.frame(
      label = c("Total", "Gender"), start_col = c(1, 2), end_col = c(1, 3),
      stringsAsFactors = FALSE),
    banner_info = list(Gender = list(
      internal_keys = c("Gender::Male", "Gender::Female"),
      columns = c("Male", "Female"), letters = c("A", "B"),
      question = data.frame(QuestionCode = "Gender", QuestionText = "Gender",
                            stringsAsFactors = FALSE))))
}

# A Likert scale question with a chosen Total Index value. Male base is small
# (n=20) so the low-base flag is exercised.
make_scale_q <- function(code, text, category, total_index,
                          male_index = total_index, female_index = total_index) {
  list(
    question_code = code, question_text = text,
    question_type = "Likert", category = category,
    table = data.frame(
      RowLabel  = c("Satisfied", "Satisfied", "Satisfied",
                    "Neutral", "Neutral", "Neutral",
                    "Dissatisfied", "Dissatisfied", "Dissatisfied", "Index"),
      RowType   = c("Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig.", "Index"),
      RowSource = c(rep("individual", 9), "summary"),
      "TOTAL::Total"   = c("50", "50.0", "", "30", "30.0", "", "20", "20.0", "",
                           as.character(total_index)),
      "Gender::Male"   = c("30", "60.0", "", "10", "20.0", "", "10", "20.0", "",
                           as.character(male_index)),
      "Gender::Female" = c("20", "40.0", "", "20", "40.0", "", "10", "20.0", "",
                           as.character(female_index)),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100, weighted = 100, effective = 100),
      "Gender::Male"   = list(unweighted = 20,  weighted = 20,  effective = 20),
      "Gender::Female" = list(unweighted = 80,  weighted = 80,  effective = 80)))
}

make_results <- function() {
  list(
    Q1 = make_scale_q("Q1", "I know what is expected of me", "Engagement", 4.5),
    Q2 = make_scale_q("Q2", "I get recognition for good work", "Engagement", 3.4),
    Q3 = make_scale_q("Q3", "My opinions seem to count", "Engagement", 3.8),
    Q4 = make_scale_q("Q4", "Overall satisfaction with the company", "Satisfaction", 3.9))
}

make_config <- function(...) {
  modifyList(list(
    project_title = "Climate Test", client_name = "Acme", wave = "2025",
    brand_colour = "#0d8a8a", accent_colour = "#CC9900",
    alpha = 0.05, significance_min_base = 30, low_base_threshold = 30,
    sampling_method = "Census", apply_weighting = FALSE), list(...))
}

# A synthetic tracking island (parsed shape, as fromJSON(simplifyVector=FALSE)
# would yield): one earlier wave whose questions carry a match_key + a mean, so
# derive_reader_model can compute a 2-wave delta by normalised title.
make_prev <- function() {
  q <- function(title, mean) list(match_key = title, title = title,
                                   base = 100, stats = list(mean = mean))
  list(schema_version = 1, kind = "tracking_microdata", waves = list(
    list(wave = "2023", year = 2023, current = FALSE, segments = list(), questions = list(
      q("I know what is expected of me", 4.6),
      q("I get recognition for good work", 3.9),
      q("My opinions seem to count", 4.2),
      q("Overall satisfaction with the company", 4.1))),
    list(wave = "2025", year = 2025, current = TRUE, segments = list(), questions = list())))
}

# ==============================================================================
# 1. derivation
# ==============================================================================

context("reader_report: derive_reader_model")

test_that("derives ranked scale items with values from the data layer", {
  dl <- build_data_layer(make_results(), make_banner(), make_config())
  m <- derive_reader_model(dl, config_obj = make_config(), crosstab_file = "study_report.html")

  expect_equal(m$schema_version, 1L)
  expect_true(length(m$items) >= 3)                       # the Engagement battery
  vals <- vapply(m$items, function(x) x$value, numeric(1))
  expect_false(any(is.na(vals)))
  expect_true(all(diff(vals) >= 0))                       # ranked ascending (weakest first)
  # weakest is the recognition item (3.4), strongest is role-clarity (4.5)
  expect_equal(m$items[[1]]$short, "I get recognition for good work")
  expect_true(m$items[[length(m$items)]]$value >= m$items[[1]]$value)
})

test_that("picks headline cards and links them to the crosstab", {
  dl <- build_data_layer(make_results(), make_banner(), make_config())
  m <- derive_reader_model(dl, config_obj = make_config(), crosstab_file = "study_report.html")
  expect_true(length(m$headline) >= 1)
  codes <- vapply(m$headline, function(h) h$q, character(1))
  expect_true("Q4" %in% codes)                            # the Satisfaction question
  expect_true(all(vapply(m$headline, function(h) identical(h$tab, "crosstabs"), logical(1))))
})

test_that("no tracking island -> trend unavailable, items carry no delta", {
  dl <- build_data_layer(make_results(), make_banner(), make_config())
  m <- derive_reader_model(dl, prev = NULL, config_obj = make_config())
  expect_false(isTRUE(m$trend$available))
  expect_true(all(vapply(m$items, function(x) is.null(x$delta) || is.na(x$delta), logical(1))))
  expect_equal(length(m$splitHeld), 0)
})

test_that("a prior wave yields 2-wave deltas and the held/slipped split", {
  dl <- build_data_layer(make_results(), make_banner(), make_config())
  m <- derive_reader_model(dl, prev = make_prev(), config_obj = make_config())
  expect_true(isTRUE(m$trend$available))
  expect_equal(m$trend$refYear, 2023)
  # recognition fell 3.9 -> 3.4 = -0.5; role clarity 4.6 -> 4.5 = -0.1
  drecog <- Filter(function(x) x$short == "I get recognition for good work", m$items)[[1]]
  expect_equal(drecog$delta, -0.5, tolerance = 1e-6)
  expect_true(length(m$splitSlipped) >= 1)
  expect_equal(m$splitSlipped[[1]]$short, "I get recognition for good work")  # steepest fall
})

test_that("a Values battery produces the lives-most / lives-least split", {
  res <- c(make_results(), list(
    V1 = make_scale_q("Q18", "Integrity", "Values", 3.9),
    V2 = make_scale_q("Q19", "Results-oriented", "Values", 4.2),
    V3 = make_scale_q("Q20", "Person-centred", "Values", 3.6)))
  dl <- build_data_layer(res, make_banner(), make_config())
  m <- derive_reader_model(dl, config_obj = make_config())
  expect_true(isTRUE(m$values$available))
  expect_true(length(m$values$livesMost) >= 1)
  expect_true(length(m$values$livesLeast) >= 1)
  # highest-scoring value sorts into livesMost
  expect_equal(m$values$livesMost[[1]]$value, max(
    vapply(c(m$values$livesMost, m$values$livesLeast), function(x) x$value, numeric(1))))
})

test_that("derives the people sub-group read, verdict, leverage and glossary", {
  dl <- build_data_layer(make_results(), make_banner(), make_config())
  m <- derive_reader_model(dl, prev = make_prev(), config_obj = make_config())

  # people: the primary banner group (Gender) yields a lowest cut vs an anchor
  expect_true(isTRUE(m$people$available))
  expect_equal(m$people$groupName, "Gender")
  expect_true(m$people$lowest$base %in% c(20, 80))
  # Male base (20) is below the threshold (30) -> that cut is directional and
  # its figures land in the low-base register
  expect_true(length(m$register) >= 1)

  # verdict + ranked leverage tied to the weakest / fastest-falling items
  expect_true(!is.null(m$verdict$body) && nzchar(m$verdict$body))
  expect_true(length(m$verdict$leverage) >= 1)
  expect_equal(m$verdict$leverage[[1]]$n, 1)

  # glossary present
  expect_true(length(m$glossary) >= 4)
  expect_true(any(vapply(m$glossary, function(g) g$term == "Directional", logical(1))))

  # practitioner panels (design + significance) for the depth toggle
  expect_true(length(m$practitioner) >= 1)
  expect_true(any(vapply(m$practitioner, function(p) p$after == "standing", logical(1))))
})

# ==============================================================================
# 2. bundler (end-to-end write)
# ==============================================================================

context("reader_report: generate_reader_report")

test_that("writes a self-contained Reader file that links to the crosstab", {
  out <- file.path(tempdir(), "study_Reader.html")
  if (file.exists(out)) unlink(out)
  dl <- build_data_layer(make_results(), make_banner(), make_config())

  res <- generate_reader_report(dl, prev_json = serialize_reader_model(list()),
                                qual_json = NULL, crosstab_file = "study_report.html",
                                config_obj = make_config(), output_path = out)

  expect_equal(res$status, "PASS")
  expect_true(file.exists(out))
  expect_true(res$file_size_mb > 0)

  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("data-reader", html, fixed = TRUE))            # island present
  expect_true(grepl("Climate Test", html, fixed = TRUE))          # title
  expect_true(grepl("study_report.html", html, fixed = TRUE))     # deep-link target
  expect_false(grepl('(src|href)="https?://', html))              # self-contained / offline
  expect_false(grepl("\\{\\{[A-Z_]+\\}\\}", html))                # every token filled
  unlink(out)
})

test_that("the trend flows through to the written report", {
  out <- file.path(tempdir(), "study_Reader_trend.html")
  if (file.exists(out)) unlink(out)
  dl <- build_data_layer(make_results(), make_banner(), make_config())

  res <- generate_reader_report(dl, prev_json = serialize_reader_model(make_prev()),
                                crosstab_file = "study_report.html",
                                config_obj = make_config(), output_path = out)
  expect_equal(res$status, "PASS")
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("\"available\":true", html, fixed = TRUE))    # trend in the island
  unlink(out)
})

test_that("refuses an empty data layer", {
  res <- generate_reader_report(list(), crosstab_file = "x.html",
                                config_obj = make_config(),
                                output_path = file.path(tempdir(), "x.html"))
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_LAYER_EMPTY")
})
