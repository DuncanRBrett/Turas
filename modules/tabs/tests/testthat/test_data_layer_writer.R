# ==============================================================================
# TABS MODULE - DATA-LAYER WRITER TESTS (data-centric report v2)
# ==============================================================================
#
# Tests the data-agg JSON writer (modules/tabs/lib/data_layer_writer.R):
#   - build_data_layer() shape + the long->wide pivot
#   - row kinds (category / net / mean) and their cell arrays
#   - columns[] / banner_groups[] / project / categories
#   - write_data_layer() on-disk JSON honours d2.validate's hard contract
#   - config wiring: html_report_v2 / sampling_method / wave
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_data_layer_writer.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

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

# html_report module sources 01_data_transformer.R (the row helpers the writer reuses)
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))

# ==============================================================================
# FIXTURES
# ==============================================================================

make_dl_banner_info <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("-", "A", "B"),                       # Total has no letter
    column_to_banner = c("TOTAL::Total" = "TOTAL",
                         "Gender::Male" = "Gender",
                         "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total",
                       "Gender::Male" = "Male",
                       "Gender::Female" = "Female"),
    banner_headers = data.frame(
      label = c("Total", "Gender"), start_col = c(1, 2), end_col = c(1, 3),
      stringsAsFactors = FALSE),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns = c("Male", "Female"), letters = c("A", "B"),
        question = data.frame(QuestionCode = "Gender", QuestionText = "Gender",
                              stringsAsFactors = FALSE)))
  )
}

# Single-choice question (2 individual categories)
make_dl_q_single <- function() {
  list(
    question_code = "Q1", question_text = "Are you aware?",
    question_type = "Single_Choice", category = "Awareness",
    table = data.frame(
      RowLabel  = c("Yes", "Yes", "Yes", "No", "No", "No"),
      RowType   = c("Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig."),
      RowSource = rep("individual", 6),
      "TOTAL::Total"   = c("60", "60.0", "", "40", "40.0", ""),
      "Gender::Male"   = c("35", "70.0", "B", "15", "30.0", ""),
      "Gender::Female" = c("25", "50.0", "", "25", "50.0", "A"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100, weighted = 100, effective = 100),
      "Gender::Male"   = list(unweighted = 50,  weighted = 50,  effective = 50),
      "Gender::Female" = list(unweighted = 50,  weighted = 50,  effective = 50))
  )
}

# Scale question with a NET (boxcategory) and an Index (summary/mean) row
make_dl_q_scale <- function() {
  list(
    question_code = "Q2", question_text = "How satisfied are you?",
    question_type = "Likert", category = "Satisfaction",
    table = data.frame(
      RowLabel  = c("Satisfied", "Satisfied", "Satisfied",
                    "Neutral", "Neutral", "Neutral",
                    "Dissatisfied", "Dissatisfied", "Dissatisfied",
                    "Top 2 Box", "Top 2 Box", "Index"),
      RowType   = c("Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig.",
                    "Column %", "Sig.", "Index"),
      RowSource = c(rep("individual", 9), "boxcategory", "boxcategory", "summary"),
      "TOTAL::Total"   = c("50", "50.0", "", "30", "30.0", "", "20", "20.0", "",
                           "50.0", "", "65.0"),
      "Gender::Male"   = c("30", "60.0", "B", "10", "20.0", "", "10", "20.0", "",
                           "60.0", "B", "70.0"),
      "Gender::Female" = c("20", "40.0", "", "20", "40.0", "A", "10", "20.0", "",
                           "40.0", "", "60.0"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100, weighted = 100, effective = 100),
      "Gender::Male"   = list(unweighted = 50,  weighted = 50,  effective = 50),
      "Gender::Female" = list(unweighted = 20,  weighted = 20,  effective = 20))  # low base
  )
}

# Numeric open-count: a Mean (Average) + Standard Deviation summary, no
# category / NET rows. Mirrors numeric_processor's output — RowType "Average"
# sets metric_type, so without the type gate this would wrongly receive a
# scale_max and land on the index dashboard alongside genuine ratings.
make_dl_q_numeric <- function() {
  list(
    question_code = "Q3", question_text = "How many hours did you lose?",
    question_type = "Numeric", category = "Service",
    table = data.frame(
      RowLabel  = c("Mean", "Standard Deviation"),
      RowType   = c("Average", "StdDev"),
      RowSource = c("summary", "summary"),
      "TOTAL::Total"   = c("9.0", "2.1"),
      "Gender::Male"   = c("8.5", "2.0"),
      "Gender::Female" = c("9.4", "2.2"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100, weighted = 100, effective = 100),
      "Gender::Male"   = list(unweighted = 50,  weighted = 50,  effective = 50),
      "Gender::Female" = list(unweighted = 50,  weighted = 50,  effective = 50))
  )
}

make_dl_results <- function() list(Q1 = make_dl_q_single(), Q2 = make_dl_q_scale())

make_dl_config <- function(...) {
  base <- list(
    project_title = "Test Survey", client_name = "Acme", wave = "Wave 1",
    brand_colour = "#323367", accent_colour = "#CC9900",
    alpha = 0.05, significance_min_base = 30,
    sampling_method = "Not_Specified", apply_weighting = FALSE)
  modifyList(base, list(...))
}

# ==============================================================================
# 1. build_data_layer — top-level shape
# ==============================================================================

context("data_layer_writer: top-level shape")

test_that("emits the data-agg top-level keys", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_setequal(names(dl),
    c("schema_version", "project", "columns", "banner_groups", "categories", "questions"))
  expect_identical(dl$schema_version, 2L)
  expect_length(dl$questions, 2)
})

test_that("columns are Total-first with correct groups and letters", {
  cols <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$columns
  expect_length(cols, 3)
  expect_equal(cols[[1]]$key, "TOTAL::Total")
  expect_equal(cols[[1]]$group, "total")
  expect_equal(cols[[1]]$letter, "")          # Total never lettered
  expect_equal(cols[[2]]$group, "Gender")
  expect_equal(cols[[2]]$letter, "A")
  expect_equal(cols[[3]]$letter, "B")
  expect_equal(cols[[2]]$label, "Male")
})

test_that("banner_groups and categories are derived from the data", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_length(dl$banner_groups, 1)
  expect_equal(dl$banner_groups[[1]]$id, "Gender")
  expect_setequal(unlist(dl$categories), c("Awareness", "Satisfaction"))
})

# ==============================================================================
# 2. project block
# ==============================================================================

context("data_layer_writer: project")

test_that("project carries the renderer's fields with sampling vocabulary", {
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$project
  expect_equal(p$name, "Test Survey")
  expect_equal(p$client, "Acme")
  expect_equal(p$wave, "Wave 1")
  expect_equal(p$low_base_threshold, 30)
  expect_equal(p$sampling_method, "Not_Specified")
  expect_equal(p$tracking$enabled, FALSE)
  # Not_Specified -> non-probability wording
  expect_match(p$sig_note, "stability intervals")
})

test_that("a probability design switches to confidence-interval wording", {
  cfg <- make_dl_config(sampling_method = "Random")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_match(p$sig_note, "confidence intervals")
})

test_that("report_meta carries the config's analyst / contact / closing fields", {
  cfg <- make_dl_config(
    analyst_name = "Jess Taylor", analyst_email = "jess@researchlamppost.co.za",
    analyst_phone = "+27 11 123 4567", company_name = "The Research Lamppost",
    fieldwork_dates = "May 2026", closing_notes = "Confidential.",
    verbatim_filename = "v.xlsx")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_equal(p$report_meta$analyst, "Jess Taylor")
  expect_equal(p$report_meta$email, "jess@researchlamppost.co.za")
  expect_equal(p$report_meta$phone, "+27 11 123 4567")
  expect_equal(p$report_meta$company, "The Research Lamppost")
  expect_equal(p$report_meta$fieldwork, "May 2026")
  expect_equal(p$report_meta$closing, "Confidential.")
})

test_that("report_meta is omitted entirely when no analyst metadata is configured", {
  # default config has no analyst / company / closing keys
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$project
  expect_null(p$report_meta)
})

test_that("config fields surfaced as the literal string 'NA' are treated as blank", {
  # the config loader returns an empty cell as the string "NA" (not a real NA);
  # those must not leak a bare "NA" into the header or About panel
  cfg <- make_dl_config(
    analyst_name = "Jess Taylor", analyst_phone = "NA",
    company_name = "The Research Lamppost", closing_notes = "NA",
    fieldwork_dates = " NA ")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_equal(p$report_meta$analyst, "Jess Taylor")
  expect_equal(p$report_meta$company, "The Research Lamppost")
  expect_equal(p$report_meta$phone, "")        # literal "NA" -> blank
  expect_equal(p$report_meta$closing, "")       # literal "NA" -> blank
  expect_equal(p$report_meta$fieldwork, "")     # whitespace-padded "NA" -> blank
})

test_that("a header field of literal 'NA' falls back rather than showing 'NA'", {
  # client_name "NA" must not render as the header subtitle
  cfg <- make_dl_config(client_name = "NA", wave = "NA")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_equal(p$client, "")
  expect_equal(p$wave, "")
})

test_that("report_meta carries the config Background & Executive summary", {
  cfg <- make_dl_config(
    background_text = "60 stores were interviewed by phone.",
    executive_summary = "Service rated lower this wave.")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_equal(p$report_meta$background, "60 stores were interviewed by phone.")
  expect_equal(p$report_meta$exec_summary, "Service rated lower this wave.")
})

# ------------------------------------------------------------------------------
# per-question comments (config Comments sheet → AGG.comments)
# ------------------------------------------------------------------------------
context("data_layer_writer: comments")

test_that("per-question comments are emitted keyed by code, with banner null", {
  cfg <- make_dl_config(comments = list(
    Q1 = list(list(banner = NA, text = "Half the stores are satisfied.")),
    Q2 = list(list(banner = "Male", text = "Men rate this higher."),
              list(banner = NA, text = "General note for Q2."))))
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)
  expect_false(is.null(dl$comments))
  expect_equal(dl$comments$Q1[[1]]$text, "Half the stores are satisfied.")
  expect_true(is.na(dl$comments$Q1[[1]]$banner))          # general → JSON null
  expect_equal(dl$comments$Q2[[1]]$banner, "Male")        # banner-specific kept
  expect_equal(length(dl$comments$Q2), 2L)
})

test_that("comments key is omitted entirely when none are configured", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_false("comments" %in% names(dl))                 # existing reports unchanged
})

test_that("blank / literal-'NA' comment text is dropped", {
  cfg <- make_dl_config(comments = list(
    Q1 = list(list(banner = NA, text = "NA"), list(banner = NA, text = "  ")),
    Q2 = list(list(banner = NA, text = "Real insight."))))
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)
  expect_null(dl$comments$Q1)                             # all entries blank → dropped
  expect_equal(dl$comments$Q2[[1]]$text, "Real insight.")
})

# ------------------------------------------------------------------------------
# category + question ordering (Selection sheet CategoryOrder → classic order)
# ------------------------------------------------------------------------------
context("data_layer_writer: ordering")

test_that("categories + questions order by CategoryOrder then appearance", {
  ar <- list(
    Q1 = list(category = "Service",  category_order = 2),
    Q2 = list(category = "Overall",  category_order = 1),
    Q3 = list(category = "Service",  category_order = 2),
    Q4 = list(category = "Overall",  category_order = 1),
    Q5 = list(category = "",         category_order = NA))
  expect_equal(.dl_category_seq(ar), c("Overall", "Service"))
  # grouped: Overall (Q2,Q4) → Service (Q1,Q3) → uncategorised (Q5) last
  expect_equal(.dl_ordered_codes(ar), c("Q2", "Q4", "Q1", "Q3", "Q5"))
})

test_that("no CategoryOrder falls back to first-appearance, still grouped", {
  ar <- list(Q1 = list(category = "B"), Q2 = list(category = "A"),
             Q3 = list(category = "B"), Q4 = list(category = "A"))
  expect_equal(.dl_category_seq(ar), c("B", "A"))         # appearance order
  expect_equal(.dl_ordered_codes(ar), c("Q1", "Q3", "Q2", "Q4"))   # B's together, then A's
})

test_that("build_data_layer emits questions in category order (Overall first)", {
  r <- make_dl_results()                                  # Q1=Awareness, Q2=Satisfaction
  r$Q1$category_order <- 2
  r$Q2$category_order <- 1
  dl <- build_data_layer(r, make_dl_banner_info(), make_dl_config())
  expect_equal(dl$questions[[1]]$category, "Satisfaction")   # order 1 leads
  expect_equal(unlist(dl$categories), c("Satisfaction", "Awareness"))
})

# ==============================================================================
# 3. question pivot — kinds, cell arrays, type mapping
# ==============================================================================

context("data_layer_writer: question pivot")

test_that("single-choice question pivots to category rows", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  q1 <- Filter(function(q) q$code == "Q1", dl$questions)[[1]]
  expect_equal(q1$type, "single")
  expect_equal(q1$category, "Awareness")
  expect_equal(length(q1$bases), 3)
  expect_equal(q1$bases[[1]]$n, 100)
  expect_false(q1$bases[[1]]$low)
  expect_length(q1$rows, 2)
  yes <- q1$rows[[1]]
  expect_equal(yes$kind, "category")
  expect_equal(yes$label, "Yes")
  expect_equal(unlist(yes$pct), c(60, 70, 50))      # Column % across Total/Male/Female
  expect_equal(unlist(yes$n),   c(60, 35, 25))      # Frequency counts
  expect_equal(unlist(yes$sig), c("", "B", ""))
})

test_that("scale question emits category, net and mean rows correctly", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  q2 <- Filter(function(q) q$code == "Q2", dl$questions)[[1]]
  expect_equal(q2$type, "scale")
  kinds <- vapply(q2$rows, function(r) r$kind, character(1))
  labels <- vapply(q2$rows, function(r) r$label, character(1))
  expect_equal(kinds, c("category", "category", "category", "net", "mean"))
  expect_equal(labels[4], "Top 2 Box")
  expect_equal(labels[5], "Index")

  net <- q2$rows[[4]]
  expect_equal(unlist(net$pct), c(50, 60, 40))
  expect_true(all(vapply(net$n, is.na, logical(1))))   # net n[] all null
  expect_equal(unlist(net$sig), c("", "B", ""))

  mean_row <- q2$rows[[5]]
  expect_equal(unlist(mean_row$pct), c(65, 70, 60))    # the Index value carried in pct
  expect_true(all(vapply(mean_row$n, is.na, logical(1))))
  expect_equal(unlist(mean_row$sig), c("", "", ""))    # mean rows untested
})

test_that("low base is flagged from the unweighted base", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  q2 <- Filter(function(q) q$code == "Q2", dl$questions)[[1]]
  expect_equal(q2$bases[[3]]$n, 20)
  expect_true(q2$bases[[3]]$low)                       # 20 < 30
  expect_false(q2$bases[[1]]$low)                      # 100 >= 30
})

test_that("every row's pct/n/sig array matches the column count", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  ncol <- length(dl$columns)
  for (q in dl$questions) {
    expect_equal(length(q$bases), ncol)
    for (r in q$rows) {
      expect_equal(length(r$pct), ncol)
      expect_equal(length(r$n), ncol)
      expect_equal(length(r$sig), ncol)
    }
  }
})

test_that("question type mapping covers the tabs vocabulary", {
  expect_equal(map_question_type("Single_Choice"), "single")
  expect_equal(map_question_type("Multi_Mention"), "multi")
  expect_equal(map_question_type("Likert"), "scale")
  # Numeric open-counts are NOT ratings: they map to their own "numeric" type so
  # the v2 index dashboard can exclude them (they have no scale maximum).
  expect_equal(map_question_type("Numeric"), "numeric")
  expect_equal(map_question_type("NPS"), "nps")
  expect_equal(map_question_type("Ranking"), "single")
  expect_equal(map_question_type(NULL), "single")
})

test_that("scale_max is emitted from the configured scale (dashboard colouring)", {
  cfg <- make_dl_config(dashboard_scale_mean = 10, dashboard_scale_index = 10)
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)
  q2 <- Filter(function(q) q$code == "Q2", dl$questions)[[1]]   # has an Index row
  expect_equal(q2$scale_max, 10)
  q1 <- Filter(function(q) q$code == "Q1", dl$questions)[[1]]   # no summary row
  expect_true(is.na(q1$scale_max))   # -> null in JSON; renderer falls back
})

test_that("numeric questions are kept off the index dashboard (type + null scale_max)", {
  cfg <- make_dl_config(dashboard_scale_mean = 10)
  dl <- build_data_layer(list(Q3 = make_dl_q_numeric()), make_dl_banner_info(), cfg)
  q <- Filter(function(q) q$code == "Q3", dl$questions)[[1]]

  # Mapped to its own type, not "scale" — the renderer's indexQuestions() filter
  # keys on this to skip it.
  expect_equal(q$type, "numeric")
  # No scale maximum: an open count has no "% of scale" reading. NA -> null.
  expect_true(is.na(q$scale_max))
  expect_true(is.na(q$gauge_green))
  expect_true(is.na(q$gauge_amber))
  # It DOES still carry a Mean row — i.e. the old "any mean row" dashboard
  # filter would have wrongly included it; the type gate is what now excludes it.
  expect_true(any(vapply(q$rows, function(r) identical(r$kind, "mean"), logical(1))))
})

# ==============================================================================
# 4. write_data_layer — on-disk JSON honours the renderer contract
# ==============================================================================

context("data_layer_writer: write + JSON contract")

test_that("writes valid JSON that passes d2.validate's hard contract", {
  skip_if_not_installed("jsonlite")
  out <- file.path(tempdir(), "test_report_data.json")
  if (file.exists(out)) unlink(out)

  res <- write_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config(), out)
  expect_equal(res$status, "PASS")
  expect_true(file.exists(out))
  expect_equal(res$n_questions, 2)

  # Parse the bytes the renderer would read; mirror d2.validate's hard checks
  parsed <- jsonlite::fromJSON(out, simplifyVector = FALSE)
  expect_true(length(parsed$questions) > 0)            # DATA_NO_QUESTIONS
  expect_true(length(parsed$columns) > 0)              # DATA_NO_COLUMNS
  expect_identical(parsed$schema_version, 2L)

  # Arrays must survive serialisation as arrays (not unboxed scalars)
  q1 <- parsed$questions[[1]]
  expect_equal(length(q1$rows[[1]]$pct), length(parsed$columns))
  expect_true(is.list(q1$rows[[1]]$pct))

  # null cells (net/mean n[]) serialise as JSON null
  q2 <- parsed$questions[[2]]
  net_n <- q2$rows[[4]]$n
  expect_true(all(vapply(net_n, is.null, logical(1))))

  unlink(out)
})

test_that("refuses empty inputs with a TRS refusal", {
  res <- write_data_layer(list(), make_dl_banner_info(), make_dl_config(),
                          file.path(tempdir(), "x.json"))
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_NO_QUESTIONS")
})

# ==============================================================================
# 5. config wiring
# ==============================================================================

context("data_layer_writer: config wiring")

test_that("build_config_object recognises the v2 settings", {
  cfg <- build_config_object(list())
  expect_false(cfg$html_report_v2)                     # default off
  expect_equal(cfg$sampling_method, "Not_Specified")   # cautious default
  expect_equal(cfg$wave, "")

  cfg2 <- build_config_object(list(html_report_v2 = "Y",
                                   sampling_method = "Random", wave = "2026"))
  expect_true(cfg2$html_report_v2)
  expect_equal(cfg2$sampling_method, "Random")
  expect_equal(cfg2$wave, "2026")
})
