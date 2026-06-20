# ==============================================================================
# TABS MODULE - MICRODATA WRITER TESTS (data-centric report v2, TR.MICRO)
# ==============================================================================
#
# Known-answer tests for the anonymised microdata writer
# (modules/tabs/lib/microdata_writer.R) and the index_scores it pairs with:
#   - answers map each respondent to the SAME display-row index the processors
#     use (single, multi, rating, hidden categories, no-answer)
#   - per-respondent scores reproduce the mean source (rating value / NPS bucket)
#   - banner_vars map respondents to their banner column index
#   - weights are carried (all-1 when unweighted)
#   - index_scores (rating value; NPS ±100 buckets) for the engine's mean path
#
# The engine recompute that consumes these is gated separately in the prototype
# node suite (run_tests_v2.mjs: weighted + scores known answers).
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_microdata_writer.R")
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
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))
source(file.path(turas_root, "modules/tabs/lib/microdata_writer.R"))

# ==============================================================================
# FIXTURE — a tiny survey covering single, multi, rating, hidden-rating, NPS
# ==============================================================================

mw_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode  = c("Q1", "Q2", "Q3", "QN", "G"),
      QuestionText  = c("Aware?", "Rate", "Pick", "Recommend", "Gender"),
      Variable_Type = c("Single_Choice", "Rating", "Multi_Mention", "NPS", "Single_Choice"),
      Columns       = c(1, 1, 2, 1, 1),
      stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = c("Q1", "Q1", "Q2", "Q2", "Q2", "Q3", "Q3", "Q3",
                       "QN", "QN", "QN", "QN", "G", "G"),
      OptionText   = c("Yes", "No", "1", "2", "3", "A", "B", "C",
                       "0", "7", "9", "10", "M", "F"),
      DisplayText  = c("Yes", "No", "1", "2", "3", "A", "B", "C",
                       "0", "7", "9", "10", "Male", "Female"),
      OptionValue  = c(NA, NA, 1, 2, 3, NA, NA, NA, 0, 7, 9, 10, NA, NA),
      stringsAsFactors = FALSE))
}

mw_data <- function() {
  data.frame(
    Q1   = c("Yes", "Yes", "No", "Yes", NA),     # resp 5 did not answer
    Q2   = c("3", "1", "2", "3", "2"),           # scores 3,1,2,3,2
    Q3_1 = c("A", "B", "A", "C", "A"),
    Q3_2 = c("B", NA, "C", NA, NA),              # multi: resp1 {A,B}, resp3 {A,C}
    QN   = c("10", "0", "9", "7", "0"),          # NPS: 100,-100,100,0,-100
    G    = c("M", "M", "F", "F", "M"),
    stringsAsFactors = FALSE)
}

mw_banner_info <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "G::M", "G::F"),
    letters = c("-", "A", "B"),
    column_to_banner = c("TOTAL::Total" = "TOTAL", "G::M" = "G", "G::F" = "G"),
    key_to_display = c("TOTAL::Total" = "Total", "G::M" = "Male", "G::F" = "Female"),
    banner_headers = data.frame(label = c("Total", "Gender"), start_col = c(1, 2),
                                end_col = c(1, 3), stringsAsFactors = FALSE),
    banner_info = list(G = list(internal_keys = c("G::M", "G::F"),
      columns = c("Male", "Female"), letters = c("A", "B"),
      question = data.frame(QuestionCode = "G", QuestionText = "Gender",
                            stringsAsFactors = FALSE))))
}

# Minimal published tables so build_data_layer produces real rows (values are
# only used as the row scaffold; the microdata recompute is gated in node).
mw_q <- function(code, text, vtype, labels, rowsource = "individual", mean_label = NULL) {
  rt <- character(0); rl <- character(0); rs <- character(0)
  for (l in labels) { rl <- c(rl, l, l); rt <- c(rt, "Frequency", "Column %"); rs <- c(rs, rowsource, rowsource) }
  if (!is.null(mean_label)) { rl <- c(rl, mean_label); rt <- c(rt, "Average"); rs <- c(rs, "summary") }
  tab <- data.frame(RowLabel = rl, RowType = rt, RowSource = rs,
                    "TOTAL::Total" = rep("1", length(rl)),
                    "G::M" = rep("1", length(rl)), "G::F" = rep("1", length(rl)),
                    check.names = FALSE, stringsAsFactors = FALSE)
  list(question_code = code, question_text = text, question_type = vtype,
       category = "c", table = tab,
       bases = list("TOTAL::Total" = list(unweighted = 5),
                    "G::M" = list(unweighted = 3), "G::F" = list(unweighted = 2)))
}

mw_results <- function() list(
  Q1 = mw_q("Q1", "Aware?", "Single_Choice", c("Yes", "No")),
  Q2 = mw_q("Q2", "Rate", "Rating", c("1", "2", "3"), mean_label = "Mean"),
  Q3 = mw_q("Q3", "Pick", "Multi_Mention", c("A", "B", "C")),
  QN = mw_q("QN", "Recommend", "NPS", c("0", "7", "9", "10"), mean_label = "NPS Score"))

mw_config <- function(...) modifyList(list(project_title = "MW", alpha = 0.05,
  significance_min_base = 1, sampling_method = "Not_Specified", apply_weighting = FALSE), list(...))

mw_build <- function(config = mw_config()) {
  dl <- build_data_layer(mw_results(), mw_banner_info(), config, mw_structure())
  micro <- build_microdata(dl, mw_data(), mw_structure(), mw_banner_info(), config)
  list(dl = dl, micro = micro)
}

# ==============================================================================
# 1. answers — single / multi / no-answer
# ==============================================================================

context("microdata_writer: answers mapping")

test_that("single-choice answers map to the category row index", {
  m <- mw_build()$micro
  # Q1 rows: Yes(idx0), No(idx1). data: Yes,Yes,No,Yes,NA
  expect_equal(as.integer(m$answers$Q1), c(0L, 0L, 1L, 0L, NA_integer_))
})

test_that("multi-mention answers expand to the set of selected indices", {
  m <- mw_build()$micro
  # Q3 rows A(0) B(1) C(2). resp1 {A,B}=c(0,1); resp2 {B}; resp3 {A,C}; resp4 {C}; resp5 {A}
  a <- m$answers$Q3
  expect_setequal(as.integer(a[[1]]), c(0L, 1L))
  expect_equal(as.integer(a[[2]]), 1L)
  expect_setequal(as.integer(a[[3]]), c(0L, 2L))
  expect_equal(as.integer(a[[4]]), 2L)
  expect_equal(as.integer(a[[5]]), 0L)
})

test_that("every agg question has an answers array of length n (validate contract)", {
  b <- mw_build()
  n <- nrow(mw_data())
  for (q in b$dl$questions) {
    expect_false(is.null(b$micro$answers[[q$code]]),
                 info = paste("missing answers for", q$code))
    expect_equal(length(b$micro$answers[[q$code]]), n)
  }
})

# ==============================================================================
# 2. scores — rating value / NPS buckets, and index_scores
# ==============================================================================

context("microdata_writer: mean scores + index_scores")

test_that("rating scores are the option values per respondent", {
  m <- mw_build()$micro
  # Q2 data 3,1,2,3,2 -> OptionValue 3,1,2,3,2
  expect_equal(as.numeric(m$scores$Q2), c(3, 1, 2, 3, 2))
})

test_that("NPS scores use the ±100 bucket mapping", {
  m <- mw_build()$micro
  # QN data 10,0,9,7,0 -> +100,-100,+100,0,-100
  expect_equal(as.numeric(m$scores$QN), c(100, -100, 100, 0, -100))
})

test_that("rating questions carry index_scores keyed by display label", {
  dl <- mw_build()$dl
  q2 <- Find(function(q) q$code == "Q2", dl$questions)
  expect_equal(q2$index_scores[["1"]], 1)
  expect_equal(q2$index_scores[["3"]], 3)
})

test_that("NPS index_scores apply the ±100 bucket per option", {
  dl <- mw_build()$dl
  qn <- Find(function(q) q$code == "QN", dl$questions)
  expect_equal(qn$index_scores[["0"]], -100)
  expect_equal(qn$index_scores[["7"]], 0)
  expect_equal(qn$index_scores[["10"]], 100)
})

# ==============================================================================
# 3. banner_vars + weights
# ==============================================================================

context("microdata_writer: banner_vars + weights")

test_that("banner_vars map respondents to their banner column index", {
  m <- mw_build()$micro
  # Gender banner_code "G"; AGG cols: Total(0) Male(1) Female(2).
  # data G = M,M,F,F,M -> 1,1,2,2,1
  expect_equal(as.integer(m$banner_vars$G), c(1L, 1L, 2L, 2L, 1L))
})

test_that("weights are all 1 for an unweighted run", {
  m <- mw_build()$micro
  expect_equal(as.numeric(m$weights), rep(1, 5))
})

test_that("weights are carried from the weight variable when weighting is on", {
  data_w <- cbind(mw_data(), wt = c(2, 1, 1, 1, 1.5))
  config <- mw_config(apply_weighting = TRUE, weight_variable = "wt")
  dl <- build_data_layer(mw_results(), mw_banner_info(), config, mw_structure())
  m <- build_microdata(dl, data_w, mw_structure(), mw_banner_info(), config)
  expect_equal(as.numeric(m$weights), c(2, 1, 1, 1, 1.5))
})

# ==============================================================================
# 4. edge cases + anonymity
# ==============================================================================

context("microdata_writer: edge cases")

test_that("build_microdata returns NULL with no respondents", {
  expect_null(build_microdata(mw_build()$dl, mw_data()[0, ], mw_structure(),
                              mw_banner_info(), mw_config()))
})

test_that("the payload carries only indices/weights — no raw answers or ids", {
  micro <- mw_build()$micro
  json <- serialize_microdata(micro)
  expect_false(grepl("Yes|Male|Recommend", json))   # no raw labels / titles
  expect_true(grepl("\"answers\"", json) && grepl("\"weights\"", json))
})

test_that("serialize_microdata renders answers as length-n arrays (n=1 safe)", {
  one <- list(n = 1, answers = list(Q1 = I(c(2L))), banner_vars = list(), weights = I(c(1)))
  expect_match(serialize_microdata(one), "\"Q1\":\\[2\\]")
})

# ==============================================================================
# 5. project block: logos + tracking flag (data_layer_writer)
# ==============================================================================

context("data_layer_writer: logos + tracking flag")

test_that("encode_logo_data_uri embeds an SVG as a data URI, NULL when absent", {
  skip_if_not_installed("base64enc")
  svg <- tempfile(fileext = ".svg")
  writeLines('<svg xmlns="http://www.w3.org/2000/svg"></svg>', svg)
  on.exit(unlink(svg), add = TRUE)
  expect_match(encode_logo_data_uri(svg), "^data:image/svg\\+xml;base64,")
  expect_null(encode_logo_data_uri(NULL))
  expect_null(encode_logo_data_uri("/no/such/logo.png"))
})

test_that("build_dl_project sets tracking.enabled only when asked", {
  expect_false(build_dl_project(mw_config())$tracking$enabled)
  expect_true(build_dl_project(mw_config(), tracking_enabled = TRUE)$tracking$enabled)
})

test_that("build_dl_project inlines a researcher logo when a path resolves", {
  skip_if_not_installed("base64enc")
  svg <- tempfile(fileext = ".svg")
  writeLines('<svg xmlns="http://www.w3.org/2000/svg"></svg>', svg)
  on.exit(unlink(svg), add = TRUE)
  proj <- build_dl_project(mw_config(researcher_logo_path = svg))
  expect_match(proj$researcher_logo, "^data:image/svg")
  expect_null(build_dl_project(mw_config())$researcher_logo)   # omitted when none
})

# ==============================================================================
# 6. box-category NET recompute: box membership + net_diffs
# ==============================================================================

context("microdata_writer: box-category NETs")

test_that("micro_box_membership maps each respondent to their box row index", {
  dl_q <- list(code = "QB", rows = list(
    list(kind = "net", label = "Low"),     # row 0
    list(kind = "net", label = "High"),    # row 1
    list(kind = "mean", label = "Mean")))
  structure <- list(options = data.frame(
    QuestionCode = c("QB", "QB", "QB", "QB"),
    OptionText   = c("1", "2", "4", "5"),
    BoxCategory  = c("Low", "Low", "High", "High"),
    stringsAsFactors = FALSE))
  survey_data <- data.frame(QB = c("1", "5", "2", "4", NA), stringsAsFactors = FALSE)
  # 1->Low(0), 5->High(1), 2->Low(0), 4->High(1), NA->NA
  expect_equal(micro_box_membership(dl_q, survey_data, structure, 5),
               c(0L, 1L, 0L, 1L, NA_integer_))
})

test_that("micro_box_membership returns NULL without box NET rows or BoxCategory", {
  dl_q_nonet <- list(code = "QB", rows = list(list(kind = "category", label = "1")))
  structure <- list(options = data.frame(QuestionCode = "QB", OptionText = "1",
    BoxCategory = "Low", stringsAsFactors = FALSE))
  expect_null(micro_box_membership(dl_q_nonet, data.frame(QB = "1"), structure, 1))
})

test_that("derive_net_diffs picks top (last non-DK box) minus bottom (first box)", {
  rows <- list(
    list(kind = "net", label = "Do not trust"),    # 0 = bottom
    list(kind = "net", label = "Some trust"),       # 1
    list(kind = "net", label = "Fully trust"),      # 2 = top
    list(kind = "net", label = "NET POSITIVE (Fully trust - Do not trust)"),  # 3
    list(kind = "mean", label = "Mean"))
  expect_equal(derive_net_diffs(rows), list("3" = list(plus = 2, minus = 0)))
})

test_that("derive_net_diffs excludes a Don't-know box from the top", {
  rows <- list(
    list(kind = "net", label = "Poor (1 - 5)"),     # 0 = bottom
    list(kind = "net", label = "Good (9 - 10)"),    # 1 = top (last non-DK)
    list(kind = "net", label = "Don't know"),        # 2 = DK, excluded
    list(kind = "net", label = "NET POSITIVE (Good - Poor)"))  # 3
  expect_equal(derive_net_diffs(rows), list("3" = list(plus = 1, minus = 0)))
})

test_that("derive_net_diffs returns NULL without a NET POSITIVE row", {
  rows <- list(list(kind = "net", label = "Poor"), list(kind = "net", label = "Good"),
               list(kind = "mean", label = "Mean"))
  expect_null(derive_net_diffs(rows))
})

test_that("derive_net_diffs orders by SCORE (favourable box = plus) when given box_scores", {
  # Best-first display: "Agree" appears before "Disagree" but is the favourable
  # (higher-score) box. plus must be Agree, minus Disagree — i.e. Agree - Disagree
  # — regardless of the display order (SACS Q05 regression).
  rows <- list(
    list(kind = "net", label = "Agree"),       # 0 (favourable, displayed first)
    list(kind = "net", label = "Disagree"),    # 1 (unfavourable)
    list(kind = "net", label = "NET POSITIVE (Agree - Disagree)"))  # 2
  expect_equal(derive_net_diffs(rows, c(Agree = 4.5, Disagree = 1.5)),
               list("2" = list(plus = 0, minus = 1)))
  # without scores it falls back to row order (last non-DK box = plus) — unchanged
  expect_equal(derive_net_diffs(rows), list("2" = list(plus = 1, minus = 0)))
})

test_that("box_category_scores averages OptionValue per box", {
  qo <- data.frame(
    OptionValue = c(5, 4, 2, 1),
    BoxCategory = c("Agree", "Agree", "Disagree", "Disagree"),
    stringsAsFactors = FALSE)
  s <- box_category_scores(qo)
  expect_equal(unname(s[["Agree"]]), 4.5)
  expect_equal(unname(s[["Disagree"]]), 1.5)
})
