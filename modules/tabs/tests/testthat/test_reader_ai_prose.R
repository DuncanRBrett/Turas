# ==============================================================================
# TABS MODULE — READER REPORT AI PROSE TESTS (mocked provider)
# ==============================================================================
#
# The AI prose path is opt-in and calls a live model, so these tests stub the
# provider (call_insight_model) and assert the STRUCTURE around it:
#   - reader_ai_facts() sends AGGREGATES ONLY (no verbatims, no microdata)
#   - a valid response merges in and flags the report as AI-drafted
#   - an invented number is caught (deterministic_number_check) and the prose
#     falls back to the on-device narrative
#   - disabled / no-response -> deterministic narrative unchanged
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_reader_ai_prose.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  h <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(h) && dir.exists(file.path(h, "modules"))) return(normalizePath(h, mustWork = FALSE))
  for (c in c(getwd(), "../..", "../../..", "../../../..")) {
    r <- tryCatch(normalizePath(c, mustWork = FALSE), error = function(e) "")
    if (nzchar(r) && dir.exists(file.path(r, "modules"))) return(r)
  }
  stop("Cannot detect TURAS root")
}
turas_root <- detect_turas_root()

for (f in c("modules/shared/lib/trs_refusal.R", "modules/tabs/lib/00_guard.R",
  "modules/tabs/lib/validation_utils.R", "modules/tabs/lib/path_utils.R",
  "modules/tabs/lib/type_utils.R", "modules/tabs/lib/logging_utils.R",
  "modules/tabs/lib/config_utils.R", "modules/tabs/lib/excel_utils.R",
  "modules/tabs/lib/filter_utils.R", "modules/tabs/lib/data_loader.R",
  "modules/tabs/lib/banner.R", "modules/tabs/lib/banner_indices.R",
  "modules/tabs/lib/crosstabs/crosstabs_config.R")) source(file.path(turas_root, f))
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
for (f in c("modules/tabs/lib/html_report/99_html_report_main.R",
  "modules/tabs/lib/score_utils.R", "modules/tabs/lib/data_layer_writer.R",
  "modules/tabs/lib/reader_report/derive_reader_model.R",
  # real number check + model alias, so the verification path is genuine
  "modules/shared/lib/ai/ai_utils.R", "modules/shared/lib/ai/ai_verify.R",
  "modules/tabs/lib/reader_report/reader_ai_prose.R")) source(file.path(turas_root, f))
suppressWarnings(suppressMessages(library(jsonlite)))

# ---- stub the provider (no live call) ----------------------------------------
# The reader_ai_prose functions live in globalenv (source(local=FALSE)), so the
# stubs THEY call must also be in globalenv — a plain top-level assignment would
# land in testthat's test env, invisible to globalenv functions. We also force
# the on-demand AI-layer loader to TRUE so it never re-sources the real provider
# (which, with a live key in the env, would make live calls). The stub reads the
# response from globalenv, so tests set it there.
assign(".STUB_AI_RESPONSE", NULL, envir = globalenv())
assign("call_insight_model",
       function(prompt, schema, ai_config) get(".STUB_AI_RESPONSE", envir = globalenv()),
       envir = globalenv())
assign("get_model_display_name",
       function(ai_config) "Claude Opus 4.8 (Anthropic)", envir = globalenv())
assign(".reader_ensure_ai_layer", function() TRUE, envir = globalenv())

# ---- minimal fixture ---------------------------------------------------------
mk_banner <- function() list(
  columns = c("Total", "Male", "Female"),
  internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
  letters = c("-", "A", "B"),
  column_to_banner = c("TOTAL::Total" = "TOTAL", "Gender::Male" = "Gender", "Gender::Female" = "Gender"),
  key_to_display = c("TOTAL::Total" = "Total", "Gender::Male" = "Male", "Gender::Female" = "Female"),
  banner_headers = data.frame(label = c("Total", "Gender"), start_col = c(1, 2), end_col = c(1, 3), stringsAsFactors = FALSE),
  banner_info = list(Gender = list(internal_keys = c("Gender::Male", "Gender::Female"),
    columns = c("Male", "Female"), letters = c("A", "B"),
    question = data.frame(QuestionCode = "Gender", QuestionText = "Gender", stringsAsFactors = FALSE))))

mk_q <- function(code, text, idx) list(
  question_code = code, question_text = text, question_type = "Likert", category = "Engagement",
  table = data.frame(
    RowLabel = c("Satisfied", "Satisfied", "Neutral", "Neutral", "Dissatisfied", "Dissatisfied", "Index"),
    RowType = c("Frequency", "Column %", "Frequency", "Column %", "Frequency", "Column %", "Index"),
    RowSource = c(rep("individual", 6), "summary"),
    "TOTAL::Total" = c("50", "50.0", "30", "30.0", "20", "20.0", as.character(idx)),
    "Gender::Male" = c("30", "60.0", "10", "20.0", "10", "20.0", as.character(idx)),
    "Gender::Female" = c("20", "40.0", "20", "40.0", "10", "20.0", as.character(idx)),
    check.names = FALSE, stringsAsFactors = FALSE),
  bases = list("TOTAL::Total" = list(unweighted = 100, weighted = 100, effective = 100),
    "Gender::Male" = list(unweighted = 20, weighted = 20, effective = 20),
    "Gender::Female" = list(unweighted = 80, weighted = 80, effective = 80)))

mk_cfg <- function(...) modifyList(list(project_title = "Test", client_name = "Acme", wave = "2025",
  brand_colour = "#0d8a8a", accent_colour = "#CC9900", alpha = 0.05, significance_min_base = 30,
  low_base_threshold = 30, sampling_method = "Census", apply_weighting = FALSE), list(...))

mk_model <- function() {
  dl <- build_data_layer(list(Q1 = mk_q("Q1", "Role clarity", 4.5),
                              Q2 = mk_q("Q2", "Recognition", 3.4)), mk_banner(), mk_cfg())
  derive_reader_model(dl, config_obj = mk_cfg(), crosstab_file = "x_report.html")
}

# valid response: cites only numbers present in the facts (base 20 is real; the
# 4.50 / 3.40 indices are <=10 so skipped by the check by design)
GOOD <- list(title = "A quiet slip", subtitle = "Strong base, one soft spot.",
  claims = list(list(lead = "Start here.", body = "The strongest item sits at 4.50.")),
  verdict = "The work is at the weak end, and the smallest group is just 20 people.",
  leverage = list(list(lead = "Lift recognition.", body = "It sits at 3.40, the lowest item.")),
  limits = list(list(lead = "Small cells.", body = "Sub-groups are leads, not verdicts.")))
# same, but cites a number that is NOT in the facts (999)
BAD <- modifyList(GOOD, list(verdict = "A remarkable 999 respondents drove the result."))

# ==============================================================================

context("reader_ai_prose: privacy of the payload")

test_that("the facts payload is aggregates-only — no verbatims or microdata", {
  facts <- reader_ai_facts(mk_model())
  expect_true(!is.null(facts$headline) && length(facts$headline) >= 1)
  expect_true(!is.null(facts$items) && length(facts$items) >= 1)
  # no per-respondent / verbatim keys anywhere in the payload
  flat <- paste(names(unlist(facts)), collapse = " ")
  expect_false(grepl("record|verbatim|text|respondent|answers|micro", flat, ignore.case = TRUE))
})

context("reader_ai_prose: apply")

test_that("a valid response merges in and flags the report as AI-drafted", {
  skip_if_not_installed("ellmer")
  assign(".STUB_AI_RESPONSE", GOOD, envir = globalenv())
  m <- reader_apply_ai_prose(mk_model(), mk_cfg(reader_ai_prose = TRUE))
  expect_equal(m$disclosure$mode, "ai")
  expect_match(m$disclosure$model, "Opus")
  expect_equal(m$prose$title, "A quiet slip")
  expect_equal(m$prose$claims[[1]]$lead, "Start here.")
  expect_true(nzchar(m$verdict$body))
  expect_equal(m$verdict$leverage[[1]]$n, 1)
})

test_that("an invented number is rejected -> deterministic narrative stands", {
  skip_if_not_installed("ellmer")
  assign(".STUB_AI_RESPONSE", BAD, envir = globalenv())
  m <- reader_apply_ai_prose(mk_model(), mk_cfg(reader_ai_prose = TRUE))
  expect_equal(m$disclosure$mode, "deterministic")   # fell back
  expect_false(grepl("999", m$verdict$body %||% "", fixed = TRUE))
})

context("reader_ai_prose: years are not treated as invented numbers")

test_that("the year pool fills the span between the years the study names", {
  facts <- list(project = list(name = "SACS 2025", wave = "2025"),
                trend = list(sinceYear = 2023))
  expect_equal(.reader_year_pool(facts), c(2023, 2024, 2025))
  # untracked study with no year anywhere -> empty pool, not an error
  expect_length(.reader_year_pool(list(project = list(name = "Acme Study"))), 0)
})

test_that("a digit range is two numbers, not a negative (2023-2025 != -2025)", {
  chk <- deterministic_number_check("Every item fell between 2023-2025.", c(2023, 2024, 2025))
  expect_true(chk$pass)
  chk2 <- deterministic_number_check("Scores sit in the 3.9-4.5 band.", c(3.9, 4.5))
  expect_true(chk2$pass)
  # a genuine negative is still checked as a negative
  chk3 <- deterministic_number_check("A change of -0.48 since 2023.", c(-0.48, 2023))
  expect_true(chk3$pass)
})

test_that("prose naming the wave year survives the number check", {
  skip_if_not_installed("ellmer")
  yearly <- modifyList(GOOD, list(subtitle = "The 2025 read: strong base, one soft spot."))
  assign(".STUB_AI_RESPONSE", yearly, envir = globalenv())
  m <- reader_apply_ai_prose(mk_model(), mk_cfg(reader_ai_prose = TRUE))
  expect_equal(m$disclosure$mode, "ai")
  expect_match(m$prose$subtitle, "2025")
})

test_that("disabled or no response leaves the deterministic narrative unchanged", {
  det <- mk_model()
  # disabled
  m1 <- reader_apply_ai_prose(det, mk_cfg(reader_ai_prose = FALSE))
  expect_equal(m1$disclosure$mode, "deterministic")
  # enabled but the model returns nothing
  assign(".STUB_AI_RESPONSE", NULL, envir = globalenv())
  m2 <- reader_apply_ai_prose(det, mk_cfg(reader_ai_prose = TRUE))
  expect_equal(m2$disclosure$mode, "deterministic")
})

# ==============================================================================
# WP1 — failure visibility: a degraded AI run must be marked, not hidden (§3.7)
# ==============================================================================

context("reader_ai_prose: failure visibility (WP1)")

test_that("AI requested but degraded stamps a banner token on the disclosure", {
  # the provider returns nothing -> the AI path falls back to the on-device prose
  assign(".STUB_AI_RESPONSE", NULL, envir = globalenv())
  m <- reader_apply_ai_prose(mk_model(), mk_cfg(reader_ai_prose = TRUE))
  expect_equal(m$disclosure$mode, "deterministic")           # fell back
  expect_equal(m$disclosure$requested_mode, "ai")            # but AI was requested
  expect_true(nzchar(m$disclosure$fallback_reason %||% ""))  # banner reason present
})

test_that("a deterministic run carries no failure-banner token", {
  m <- reader_apply_ai_prose(mk_model(), mk_cfg(reader_ai_prose = FALSE))
  expect_equal(m$disclosure$requested_mode, "deterministic")
  expect_null(m$disclosure$fallback_reason)
})

test_that("a successful AI run records requested_mode = ai and no fallback", {
  skip_if_not_installed("ellmer")
  assign(".STUB_AI_RESPONSE", GOOD, envir = globalenv())
  m <- reader_apply_ai_prose(mk_model(), mk_cfg(reader_ai_prose = TRUE))
  expect_equal(m$disclosure$mode, "ai")
  expect_equal(m$disclosure$requested_mode, "ai")
  expect_null(m$disclosure$fallback_reason)
})

# ==============================================================================
# WP2 — fact-sheet v2: fact ids + derived numbers + design facts, and a checker
# that accepts legitimately derived figures but still rejects alien ones (§3.2/§3.6)
# ==============================================================================

context("reader_ai_prose: fact-sheet v2 (WP2)")

test_that("the facts payload carries stable ids, a derived pool and design facts", {
  facts <- reader_ai_facts(mk_model())
  # stable ids on every headline / item fact
  expect_true(all(vapply(facts$headline, function(h) nzchar(h$id %||% ""), logical(1))))
  expect_true(all(vapply(facts$items, function(i) nzchar(i$id %||% ""), logical(1))))
  # derived-numbers pool
  expect_false(is.null(facts$derived))
  expect_equal(facts$derived$nItems, 2L)
  expect_equal(facts$derived$spread, 1.1)          # strongest 4.50 - weakest 3.40
  # percent-of-scale is a derived figure on each fact (4.5 on a 10-pt scale = 45)
  expect_true(45 %in% vapply(facts$items, function(i) i$pctOfScale %||% NA_real_, numeric(1)))
  # design facts ground the limits prose
  expect_false(is.null(facts$design))
  expect_equal(facts$design$censusOrSample, "Census")
  # still aggregates only — no microdata / verbatim keys anywhere
  flat <- paste(names(unlist(facts)), collapse = " ")
  expect_false(grepl("record|verbatim|text|respondent|answers|micro", flat, ignore.case = TRUE))
})

test_that("a derived figure the model cites is accepted by the number check", {
  facts <- reader_ai_facts(mk_model())
  pool <- extract_all_numbers(facts); pool <- pool[!is.na(pool)]
  expect_true(45 %in% pool)   # percent-of-scale entered the allow-pool
  chk <- deterministic_number_check("The strongest item reaches 45% of the scale ceiling.", pool)
  expect_true(chk$pass)
})

test_that("a rounded or formatted variant of a source figure is accepted", {
  # rounding: prose rounds a derived 76.3 down to 76
  expect_true(deterministic_number_check("Net agreement sits at 76%.", c(76.3))$pass)
  # formatted variants: a signed net (+63) and a percentage (76%)
  expect_true(deterministic_number_check("A net positive of +63 and 76% agreement.", c(63, 76))$pass)
})

test_that("an alien figure is still rejected", {
  expect_false(deterministic_number_check("A surprising 512 respondents drove it.", c(63, 76))$pass)
})

test_that("a response citing a derived figure survives end-to-end", {
  skip_if_not_installed("ellmer")
  deriv <- modifyList(GOOD, list(
    verdict = "The strongest item reaches 45% of the scale ceiling; the smallest group is just 20 people."))
  assign(".STUB_AI_RESPONSE", deriv, envir = globalenv())
  m <- reader_apply_ai_prose(mk_model(), mk_cfg(reader_ai_prose = TRUE))
  expect_equal(m$disclosure$mode, "ai")   # 45 (percent-of-scale) is a legitimate derived figure
})
