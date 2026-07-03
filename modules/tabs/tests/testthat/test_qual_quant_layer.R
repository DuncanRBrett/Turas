# ==============================================================================
# TABS MODULE — QUALITATIVE QUANT LAYER TESTS (themes -> AGG/MICRO via the engine)
# ==============================================================================
#
# End-to-end known-answer tests: drive the REAL crosstab engine through
# qual_build_quant_layer and assert that theme prevalence + significance are
# identical to a closed question. The fixture is hand-computable (Price = 90% in
# group A vs 20% in group B). Also covers the demographic-block dial (Total-only)
# and small-base suppression (thin cells get no significance letter).
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_quant_layer.R")
# ==============================================================================

library(testthat)

# ------------------------------------------------------------------------------
# Bootstrap the full processing chain (run_crosstabs.R has an unguarded main, so
# its significance functions are extracted by source-line, mirroring the e2e test).
# Module files self-source sub-files from the working dir, so we cd into lib for
# the bootstrap and restore afterwards. Everything lands in globalenv.
# ------------------------------------------------------------------------------

local({
  detect_root <- function() {
    for (c in c(getwd(), "../..", "../../..", "../../../..")) {
      r <- tryCatch(normalizePath(c, mustWork = FALSE), error = function(e) "")
      if (nzchar(r) && dir.exists(file.path(r, "modules/tabs/lib"))) return(r)
    }
    stop("Cannot locate Turas root for qual_quant_layer test")
  }
  repo <- detect_root()
  lib <- file.path(repo, "modules/tabs/lib")
  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(lib)
  assign(".tabs_lib_dir", lib, envir = globalenv())
  source(file.path(repo, "modules/shared/lib/trs_refusal.R"), local = FALSE)
  base_files <- c("00_guard.R", "validation_utils.R", "path_utils.R", "type_utils.R",
                  "logging_utils.R", "shared_functions.R", "config_utils.R", "excel_utils.R",
                  "filter_utils.R", "data_loader.R", "banner.R", "banner_indices.R",
                  "cell_calculator.R", "weighting.R", "score_utils.R")
  for (f in base_files) source(f, local = FALSE)
  consts <- list(TOTAL_COLUMN = "Total", SIG_ROW_TYPE = "Sig.", SIG2_ROW_TYPE = "Sig.2",
                 BASE_ROW_LABEL = "Base (n=)", UNWEIGHTED_BASE_LABEL = "Base (unweighted)",
                 WEIGHTED_BASE_LABEL = "Base (weighted)", EFFECTIVE_BASE_LABEL = "Effective base",
                 FREQUENCY_ROW_TYPE = "Frequency", COLUMN_PCT_ROW_TYPE = "Column %",
                 ROW_PCT_ROW_TYPE = "Row %", AVERAGE_ROW_TYPE = "Average",
                 INDEX_ROW_TYPE = "Index", SCORE_ROW_TYPE = "Score", MINIMUM_BASE_SIZE = 30,
                 VERY_SMALL_BASE_SIZE = 10, DEFAULT_ALPHA = 0.05, DEFAULT_MIN_BASE = 30,
                 CHECKPOINT_FREQUENCY = 10, MAX_DECIMAL_PLACES = 6)
  for (nm in names(consts)) assign(nm, consts[[nm]], envir = globalenv())
  rc <- readLines("run_crosstabs.R")
  s <- grep("^run_significance_tests_for_row <- function", rc)
  e <- grep("^add_significance_row <- function", rc)
  nx <- grep("^(#' Write question table|write_question_table_fast)", rc)
  nx <- nx[nx > e[1]][1] - 1
  eval(parse(text = rc[s[1]:nx]), envir = globalenv())
  ws <- grep("^write_question_table_fast <- function", rc)
  me <- grep("^# MAIN EXECUTION", rc)
  eval(parse(text = rc[ws[1]:(me[1] - 2)]), envir = globalenv())
  for (f in c("config_loader.R", "validation.R", "standard_processor.R", "numeric_processor.R",
              "question_dispatcher.R", "question_orchestrator.R", "composite_processor.R",
              "crosstabs/crosstabs_config.R", "html_report/01_data_transformer.R",
              "data_layer_writer.R", "microdata_writer.R", "qual_quant_layer.R")) {
    source(f, local = FALSE)
  }
})

# ---- Fixture + extraction helpers --------------------------------------------

# Build a themed-question fixture: nA in group A, nB in group B; `priceA`/`priceB`
# mention "Price" (the rest "Service"). Everyone answers + mentions exactly one theme.
make_qual_fixture <- function(nA, nB, priceA, priceB) {
  n <- nA + nB
  group_of <- function(i) if (i <= nA) "A" else "B"
  price_ids <- c(seq_len(priceA), nA + seq_len(priceB))
  theme_of <- function(i) if (i %in% price_ids) "Price" else "Service"
  master <- list(
    n = n, ids = as.character(seq_len(n)),
    id_to_idx = stats::setNames(seq_len(n) - 1L, as.character(seq_len(n))),
    respondents = lapply(seq_len(n), function(i)
      list(idx = i - 1L, id = as.character(i), demos = list(Group = group_of(i)))),
    banner_dims = list(list(label = "Group", values = c("A", "B"))))
  question <- list(code = "QUAL_Q1", title = "Why?", type = "themed",
                   roles = list(themes = list(list(col = NA, label = "Price"),
                                              list(col = NA, label = "Service"))),
                   records = lapply(seq_len(n), function(i)
                     list(id = as.character(i), themeVals = stats::setNames(list(1L), theme_of(i)))))
  list(questions = list(question), master = master)
}

col_index <- function(agg, label) which(vapply(agg$columns, function(c) identical(c$label, label), logical(1)))
find_row <- function(q, label) Filter(function(r) identical(r$label, label), q$rows)[[1]]
cell_pct <- function(q, agg, rlabel, clabel) unlist(find_row(q, rlabel)$pct)[col_index(agg, clabel)]
cell_sig <- function(q, agg, rlabel, clabel) {
  s <- find_row(q, rlabel)$sig[[col_index(agg, clabel)]]
  if (is.null(s)) "" else s
}

# ==============================================================================
# KNOWN-ANSWER: prevalence + significance identical to a closed question
# ==============================================================================

test_that("theme prevalence and significance ride the existing engine exactly", {
  fx <- make_qual_fixture(nA = 50, nB = 50, priceA = 45, priceB = 10)
  ql <- qual_build_quant_layer(fx$questions, fx$master, list(significance_min_base = 5))
  q <- ql$agg$questions[[1]]

  # Columns: Total, A, B
  expect_equal(vapply(ql$agg$columns, function(c) c$label, character(1)), c("Total", "A", "B"))

  # Prevalence (hand-computed): Price 45/50=90% in A, 10/50=20% in B, 55/100=55% Total
  expect_equal(cell_pct(q, ql$agg, "Price", "Total"), 55)
  expect_equal(cell_pct(q, ql$agg, "Price", "A"), 90)
  expect_equal(cell_pct(q, ql$agg, "Price", "B"), 20)

  # Significance: A is significantly higher than B on Price (letter "B" on A's cell),
  # and B significantly higher than A on Service — the same lettering a closed Q gets.
  expect_match(cell_sig(q, ql$agg, "Price", "A"), "B")
  expect_equal(cell_sig(q, ql$agg, "Price", "B"), "")
  expect_match(cell_sig(q, ql$agg, "Service", "B"), "A")
})

test_that("MICRO carries theme-index answers + the banner var for the cut", {
  fx <- make_qual_fixture(50, 50, 45, 10)
  ql <- qual_build_quant_layer(fx$questions, fx$master, list(significance_min_base = 5))
  expect_equal(length(ql$micro$answers[["QUAL_Q1"]]), 100L)
  expect_equal(ql$micro$answers[["QUAL_Q1"]][[1]], 0L)     # respondent 1 mentioned Price (theme idx 0)
  expect_true("QDEMO_GROUP" %in% names(ql$micro$banner_vars))
})

# ==============================================================================
# CONFIDENTIALITY DIAL — demographic block yields a Total-only crosstab
# ==============================================================================

test_that("demographic_cuts = block produces a Total-only banner (no cuts)", {
  fx <- make_qual_fixture(50, 50, 45, 10)
  ql <- qual_build_quant_layer(fx$questions, fx$master, list(demographic_cuts = "block"))
  expect_equal(vapply(ql$agg$columns, function(c) c$label, character(1)), "Total")
  q <- ql$agg$questions[[1]]
  expect_equal(cell_pct(q, ql$agg, "Price", "Total"), 55)   # numbers still correct
})

# ==============================================================================
# SMALL-BASE HONESTY — thin cells are not lettered
# ==============================================================================

test_that("thin bases get no significance letter (no over-claiming)", {
  fx <- make_qual_fixture(nA = 10, nB = 10, priceA = 9, priceB = 2)   # base 10/group
  ql <- qual_build_quant_layer(fx$questions, fx$master, list(significance_min_base = 5))
  q <- ql$agg$questions[[1]]
  expect_equal(cell_pct(q, ql$agg, "Price", "A"), 90)        # same prevalence
  expect_equal(cell_sig(q, ql$agg, "Price", "A"), "")        # but no letter on a base of 10
})

# ==============================================================================
# NO THEMED QUESTIONS — raw-only workbook produces no quant layer
# ==============================================================================

test_that("a workbook with no themed questions yields a null quant layer", {
  raw <- list(list(code = "QUAL_RAW", title = "Comments", type = "raw",
                   roles = list(themes = list()), records = list()))
  master <- list(n = 0L, ids = character(0), id_to_idx = stats::setNames(integer(0), character(0)),
                 respondents = list(), banner_dims = list())
  ql <- qual_build_quant_layer(raw, master, list())
  expect_null(ql$agg)
  expect_null(ql$micro)
})

# ==============================================================================
# PREFIX-SHARING CODES — QUAL_CULTURE must not swallow QUAL_CULTURE_STAFF's
# theme options (audit fix: the orchestrator's option match is now anchored)
# ==============================================================================

test_that("prefix-sharing question codes cannot cross-contaminate theme options", {
  n <- 20
  master <- list(
    n = n, ids = as.character(seq_len(n)),
    id_to_idx = stats::setNames(seq_len(n) - 1L, as.character(seq_len(n))),
    respondents = lapply(seq_len(n), function(i)
      list(idx = i - 1L, id = as.character(i), demos = list())),
    banner_dims = list())
  mk_q <- function(code, title, themes, theme_of) list(
    code = code, title = title, type = "themed",
    roles = list(themes = lapply(themes, function(t) list(col = NA, label = t))),
    records = lapply(seq_len(n), function(i)
      list(id = as.character(i), themeVals = stats::setNames(list(1L), theme_of(i)))))
  culture <- mk_q("QUAL_CULTURE", "Culture", c("Communication", "Trust"),
                  function(i) if (i <= 10) "Communication" else "Trust")
  staff   <- mk_q("QUAL_CULTURE_STAFF", "Culture Staff", c("Communication", "Workload"),
                  function(i) if (i <= 5) "Communication" else "Workload")
  ql <- qual_build_quant_layer(list(culture, staff), master,
                               list(demographic_cuts = "block"))
  qc <- Find(function(q) q$code == "QUAL_CULTURE", ql$agg$questions)
  qs <- Find(function(q) q$code == "QUAL_CULTURE_STAFF", ql$agg$questions)
  cat_labels <- function(q) vapply(
    Filter(function(r) identical(r$kind, "category"), q$rows),
    function(r) r$label, character(1))
  # No leak: each question shows ONLY its own themes, once each —
  # no phantom "Workload" row on Culture, no duplicated "Communication"
  expect_setequal(cat_labels(qc), c("Communication", "Trust"))
  expect_equal(anyDuplicated(cat_labels(qc)), 0L)
  expect_setequal(cat_labels(qs), c("Communication", "Workload"))
  # Known answers per question (base 20 commenters each)
  expect_equal(cell_pct(qc, ql$agg, "Communication", "Total"), 50)   # 10/20
  expect_equal(cell_pct(qc, ql$agg, "Trust", "Total"), 50)           # 10/20
  expect_equal(cell_pct(qs, ql$agg, "Communication", "Total"), 25)   # 5/20
  expect_equal(cell_pct(qs, ql$agg, "Workload", "Total"), 75)        # 15/20
})
