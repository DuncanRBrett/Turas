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
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))
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

# Rating whose box-category rows carry a real Frequency (as the live crosstab
# does), plus a NET POSITIVE difference row. Exercises the "Counts" toggle: box
# rows must emit n; the NET POSITIVE row (a pp gap, not a count) must not — even
# though this fixture deliberately gives it a Frequency to prove the guard fires.
make_dl_q_boxcounts <- function() {
  list(
    question_code = "Q4", question_text = "Rate the reliever",
    question_type = "Rating", category = "Service",
    table = data.frame(
      RowLabel  = c("Poor (1 - 5)", "Poor (1 - 5)",
                    "Good (9 - 10)", "Good (9 - 10)",
                    "NET POSITIVE (Good - Poor)", "NET POSITIVE (Good - Poor)",
                    "Mean"),
      RowType   = c("Frequency", "Column %",
                    "Frequency", "Column %",
                    "Frequency", "Column %",
                    "Average"),
      RowSource = c("boxcategory", "boxcategory",
                    "boxcategory", "boxcategory",
                    "net_positive", "net_positive",
                    "summary"),
      "TOTAL::Total"   = c("12", "20.0", "48", "80.0", "99", "60.0", "7.6"),
      "Gender::Male"   = c("6", "20.0", "24", "80.0", "99", "60.0", "7.7"),
      "Gender::Female" = c("6", "20.0", "24", "80.0", "99", "60.0", "7.5"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 60, weighted = 60, effective = 60),
      "Gender::Male"   = list(unweighted = 30, weighted = 30, effective = 30),
      "Gender::Female" = list(unweighted = 30, weighted = 30, effective = 30))
  )
}

# Composite index (Q_Engage / Q_Value style): question_type "Composite", a single
# Index row, RowSource "composite". Maps to type "single" but must receive the
# index scale_max + thresholds so it appears + colours on the dashboard like the
# rated items it summarises.
make_dl_q_composite <- function() {
  list(
    question_code = "Q_Engage", question_text = "Engagement",
    question_type = "Composite", category = "Overall ratings",
    table = data.frame(
      RowLabel  = c("Engagement"),
      RowType   = c("Index"),
      RowSource = c("composite"),
      "TOTAL::Total"   = c("4.1"),
      "Gender::Male"   = c("4.2"),
      "Gender::Female" = c("4.0"),
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

test_that("Patterns levers: headline + banner exclusion emitted as arrays, omitted when unset", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(patterns_headline = "Q78, Q79",
                   patterns_exclude_banners = "Interviewer"))
  expect_equal(as.character(dl$project$takeout_headline), c("Q78", "Q79"))
  expect_equal(as.character(dl$project$patterns_exclude_banners), "Interviewer")
  # one-element value must SERIALISE as a JSON array under auto_unbox — the JS
  # contract expects arrays (a bare string would substring-match question codes)
  expect_identical(
    as.character(jsonlite::toJSON(dl$project$patterns_exclude_banners, auto_unbox = TRUE)),
    '["Interviewer"]')
  # unset -> keys absent entirely (byte-identical island for existing reports)
  dl0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_null(dl0$project$takeout_headline)
  expect_null(dl0$project$patterns_exclude_banners)
})

test_that("heatmap_colour reaches the island only when the config sets it (I11)", {
  # The setting was whitelisted, templated and documented — and read by nothing,
  # so it was a silent no-op. It is now carried to the report, but ONLY when set:
  # an island from a config that never mentions it must stay byte-identical, and
  # the tint must stay on the brand colour for every existing report.
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(heatmap_colour = "#B02020"))
  expect_identical(dl$project$heatmap_colour, "#B02020")

  dl0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_null(dl0$project$heatmap_colour)
  expect_false("heatmap_colour" %in% names(dl0$project))

  for (v in list("", "   ", NA)) {
    dlb <- build_data_layer(make_dl_results(), make_dl_banner_info(),
      make_dl_config(heatmap_colour = v))
    expect_null(dlb$project$heatmap_colour, info = format(v))
  }
})

test_that("study slides reach the island, or are absent entirely", {
  # The AddedSlides sheet was loaded and then dropped — nothing read
  # config_obj$qualitative_slides, so a filled-in sheet changed no report. It is
  # carried now, but a config without the sheet must still emit no key at all.
  slides <- list(
    list(title = "Qual phase", content = "Six groups.",
         image_data = "data:image/png;base64,AAAA", image_w = 640L, image_h = 360L),
    list(title = "Method note", content = "Fieldwork in July.")
  )
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(qualitative_slides = slides))
  expect_length(dl$project$slides, 2)
  expect_equal(dl$project$slides[[1]]$title, "Qual phase")
  expect_equal(dl$project$slides[[1]]$image, "data:image/png;base64,AAAA")
  expect_equal(dl$project$slides[[1]]$w, 640L)
  expect_equal(dl$project$slides[[1]]$h, 360L)
  # a text slide carries no image keys at all
  expect_null(dl$project$slides[[2]]$image)
  expect_null(dl$project$slides[[2]]$w)

  dl0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_false("slides" %in% names(dl0$project))
  # an empty sheet, or rows with nothing on them, is the same as no sheet
  for (v in list(list(), NULL, list(list(title = "", content = "")))) {
    dlb <- build_data_layer(make_dl_results(), make_dl_banner_info(),
      make_dl_config(qualitative_slides = v))
    expect_false("slides" %in% names(dlb$project))
  }
})

test_that("study slides survive the JSON round trip as an array of objects", {
  # A single slide must not collapse to a bare object: the renderer indexes into
  # project.slides, and a pinned slide stores that index.
  slides <- list(list(title = "Only one", content = "Solo."))
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(qualitative_slides = slides))
  json <- jsonlite::toJSON(dl$project$slides, auto_unbox = TRUE)
  expect_true(grepl('^\\[\\{', as.character(json)))
  back <- jsonlite::fromJSON(as.character(json), simplifyDataFrame = FALSE)
  expect_length(back, 1)
  expect_equal(back[[1]]$title, "Only one")
})

test_that("the exec-summary cover reaches the island only when the study opts in", {
  # The cover changes what a client sees when they open a SAVED copy, so it is a
  # per-project decision. A config that never mentions html_report_v2_cover must
  # emit no cover key at all — every report built before the setting existed then
  # keeps landing exactly where it always did, saved or not.
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(html_report_v2_cover = TRUE))
  expect_true(dl$project$cover)

  dl0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_null(dl0$project$cover)
  expect_false("cover" %in% names(dl0$project))

  # anything that is not a literal TRUE leaves the island untouched — a blank or
  # unreadable cell must never switch a client-facing default on
  for (v in list(FALSE, "", "   ", NA, NULL)) {
    dlb <- build_data_layer(make_dl_results(), make_dl_banner_info(),
      make_dl_config(html_report_v2_cover = v))
    expect_false("cover" %in% names(dlb$project), info = format(v))
  }
})

test_that("the cover's findings count rides the island only when the study set it", {
  # An opted-in cover with no count emits the same island it did before the
  # setting existed, so the renderer's default of 5 stands untouched.
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(html_report_v2_cover = TRUE))
  expect_true(dl$project$cover)
  expect_false("cover_findings" %in% names(dl$project))

  # NB make_dl_config is a plain list, whereas in production config_obj is the
  # OUTPUT of build_config_object — so the values here are the parsed ones (a
  # number, or 0 for ALL), which is exactly what the writer receives live.
  dl12 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(html_report_v2_cover = TRUE, html_report_v2_cover_findings = 12))
  expect_equal(dl12$project$cover_findings, 12)

  # 0 is the ALL sentinel and must survive to the island, since the renderer
  # reads 0 as "no limit" — a dropped 0 would silently mean five again.
  dla <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(html_report_v2_cover = TRUE, html_report_v2_cover_findings = 0))
  expect_equal(dla$project$cover_findings, 0)

  # a count without the cover opt-in carries nothing at all
  dlx <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(html_report_v2_cover_findings = 12))
  expect_false("cover" %in% names(dlx$project))
  expect_false("cover_findings" %in% names(dlx$project))
})

test_that("a raw Settings cell reaches the island through the WHOLE chain", {
  # The unit tests above each prove one hop. This one runs the operator's actual
  # cell through build_config_object and then the writer, because a setting can
  # be registered, parsed and emitted correctly at every step and still not join
  # up — which is how the AddedSlides sheet stayed dead for a year.
  skip_if_not(exists("build_config_object", mode = "function"))
  chain <- function(cell) {
    cfg <- build_config_object(list(html_report_v2 = "TRUE",
      html_report_v2_cover = "TRUE", html_report_v2_cover_findings = cell))
    build_data_layer(make_dl_results(), make_dl_banner_info(),
      modifyList(make_dl_config(), cfg))$project
  }
  expect_equal(chain("12")$cover_findings, 12)
  expect_equal(chain("ALL")$cover_findings, 0)
  expect_true(chain("")$cover)
  expect_false("cover_findings" %in% names(chain("")))
})

test_that("sampling_note is carried trimmed, omitted when blank/NA", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(sampling_note = "  Substitution was allowed. "))
  expect_identical(dl$project$sampling_note, "Substitution was allowed.")
  dl0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_null(dl0$project$sampling_note)
  dlb <- build_data_layer(make_dl_results(), make_dl_banner_info(),
    make_dl_config(sampling_note = "   "))
  expect_null(dlb$project$sampling_note)
})

test_that("key_share (the Patterns favourable-share declaration) is carried; blank when undeclared", {
  q <- make_dl_q_single()
  q$key_share <- "Always"
  wq <- build_dl_question(q, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_identical(wq$key_share, "Always")
  uq <- build_dl_question(make_dl_q_single(), make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_identical(uq$key_share, "")
})

test_that("filter_label / base_filter (the question's own audience) reach the data layer", {
  # A routed question publishes a base smaller than the sample; the label is
  # the only thing that says why, so it has to travel with the question.
  q <- make_dl_q_single()
  q$filter_label <- "Filter = Allows signwriting in your shop"
  q$base_filter <- "Q37 ==\"Yes\""
  wq <- build_dl_question(q, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_identical(wq$filter_label, "Filter = Allows signwriting in your shop")
  expect_identical(wq$base_filter, "Q37 ==\"Yes\"")

  # Routing done in the questionnaire: a label with no filter expression.
  ql <- make_dl_q_single()
  ql$filter_label <- "Filter = Allows signwriting in your shop"
  ql$base_filter <- NA
  wl <- build_dl_question(ql, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_identical(wl$filter_label, "Filter = Allows signwriting in your shop")
  expect_null(wl$base_filter)

  # Asked of everyone (and blank/whitespace cells): neither key is emitted, so
  # a config without the columns produces byte-identical output.
  uq <- build_dl_question(make_dl_q_single(), make_dl_banner_info(),
                          make_dl_config(), low_base = 30)
  expect_null(uq$filter_label)
  expect_null(uq$base_filter)
  qb <- make_dl_q_single()
  qb$filter_label <- "   "
  qb$base_filter <- ""
  wb <- build_dl_question(qb, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_null(wb$filter_label)
  expect_null(wb$base_filter)
})

test_that("source / formula (the question's provenance) reach the data layer", {
  # A column derived before the config ever sees it arrives at the engine as a
  # finished column — the analyst's declaration is the only thing that can say
  # it was worked out rather than asked, so it has to travel with the question.
  q <- make_dl_q_single()
  q$source <- "PrepaidElectricity amount question"
  q$formula <- "mean monthly spend among priced buyers"
  wq <- build_dl_question(q, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_identical(wq$source, "PrepaidElectricity amount question")
  expect_identical(wq$formula, "mean monthly spend among priced buyers")

  # A question that was simply asked: a source, no formula. The report reads the
  # missing formula as "asked", so it must stay absent rather than become "".
  qa <- make_dl_q_single()
  qa$source <- "survey question"
  qa$formula <- NA
  wa <- build_dl_question(qa, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_identical(wa$source, "survey question")
  expect_null(wa$formula)

  # Declared neither (and blank/whitespace cells): neither key is emitted, so a
  # config without the columns produces byte-identical output.
  uq <- build_dl_question(make_dl_q_single(), make_dl_banner_info(),
                          make_dl_config(), low_base = 30)
  expect_null(uq$source)
  expect_null(uq$formula)
  qb <- make_dl_q_single()
  qb$source <- "   "
  qb$formula <- ""
  wb <- build_dl_question(qb, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_null(wb$source)
  expect_null(wb$formula)
})

test_that("area_summary (the area's overall-question marker) is TRUE-only, absent otherwise", {
  q <- make_dl_q_scale()
  q$area_summary <- TRUE
  wq <- build_dl_question(q, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_true(isTRUE(wq$area_summary))
  uq <- build_dl_question(make_dl_q_scale(), make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_null(uq$area_summary)
})

# ------------------------------------------------------------------------------
# Finite population correction: per-column population emission
# ------------------------------------------------------------------------------

test_that("no population configured -> columns carry no population field", {
  cols <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$columns
  expect_true(all(vapply(cols, function(c) is.null(c$population), logical(1))))
})

test_that("Total takes population_size; subgroups take the frame match", {
  frame <- data.frame(
    banner = c(NA, NA), group = c("Male", "Female"),
    population = c(120, 80), stringsAsFactors = FALSE)
  cfg <- make_dl_config(population_size = 300, population_frame = frame)
  cols <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$columns
  expect_equal(cols[[1]]$population, 300)   # Total <- population_size
  expect_equal(cols[[2]]$population, 120)   # Male
  expect_equal(cols[[3]]$population, 80)    # Female
})

test_that("an unmatched subgroup is left uncorrected (no population field)", {
  frame <- data.frame(
    banner = NA, group = "Male", population = 120, stringsAsFactors = FALSE)
  cfg <- make_dl_config(population_frame = frame)   # no population_size
  cols <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$columns
  expect_null(cols[[1]]$population)          # Total: no population_size
  expect_equal(cols[[2]]$population, 120)    # Male matched
  expect_null(cols[[3]]$population)          # Female unmatched
})

test_that("an unmatched Population row is reported on the console (no silent skip)", {
  frame <- data.frame(banner = c(NA, NA), group = c("Male", "Typo Group"),
                      population = c(120, 50), stringsAsFactors = FALSE)
  cfg <- make_dl_config(population_frame = frame)
  cols <- NULL
  out <- capture.output(
    cols <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$columns
  )
  joined <- paste(out, collapse = "\n")
  expect_match(joined, "matched 1 of 2")          # one of two rows matched
  expect_match(joined, "Typo Group")              # the unmatched row is named
  expect_equal(cols[[2]]$population, 120)          # Male still corrected
  expect_null(cols[[3]]$population)                # Female left standard
})

test_that("a fully-matched Population frame reports no unmatched rows", {
  frame <- data.frame(banner = c(NA, NA), group = c("Male", "Female"),
                      population = c(120, 80), stringsAsFactors = FALSE)
  cfg <- make_dl_config(population_frame = frame)
  out <- capture.output(
    build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)
  )
  joined <- paste(out, collapse = "\n")
  expect_match(joined, "matched 2 of 2")
  expect_false(grepl("matched NO report column", joined))
})

test_that(".resolve_column_population: unscoped, case-insensitive match", {
  frame <- data.frame(banner = NA_character_, group = "Masters",
                      population = 27, stringsAsFactors = FALSE)
  expect_equal(.resolve_column_population("masters", NA, frame), 27)
  expect_null(.resolve_column_population("Honours", NA, frame))
  expect_null(.resolve_column_population("Masters", NA, NULL))
})

test_that(".resolve_column_population: a banner-scoped row beats an unscoped one", {
  frame <- data.frame(
    banner = c("Study level", NA), group = c("Masters", "Masters"),
    population = c(27, 999), stringsAsFactors = FALSE)
  expect_equal(.resolve_column_population("Masters", "Study level", frame), 27)
  # falls back to the unscoped row when the banner doesn't match
  expect_equal(.resolve_column_population("Masters", "Other banner", frame), 999)
})

test_that(".resolve_column_population: a scoped-only row doesn't match a different banner", {
  frame <- data.frame(banner = "Study level", group = "Masters",
                      population = 27, stringsAsFactors = FALSE)
  expect_null(.resolve_column_population("Masters", "Campus", frame))
})

test_that("project carries population_size only when usably configured", {
  p0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$project
  expect_null(p0$population_size)
  p1 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(population_size = 500))$project
  expect_equal(p1$population_size, 500)
  # degenerate values (<= 1) are rejected
  p2 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(population_size = 1))$project
  expect_null(p2$population_size)
})

test_that("project carries the disclosure threshold only when engaged (>1)", {
  # off by default -> field omitted, so an existing report is byte-identical
  p0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$project
  expect_null(p0$min_reporting_base)
  # engaged -> carried for the renderer's disclosure control
  p1 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(min_reporting_base = 10))$project
  expect_equal(p1$min_reporting_base, 10)
  # k = 1 is "off" and must not be carried
  p2 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(min_reporting_base = 1))$project
  expect_null(p2$min_reporting_base)
})

test_that("project surfaces weighting metadata only when weighted", {
  # unweighted default -> no weighting fields at all (byte-identical)
  p0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$project
  expect_null(p0$weighted)
  expect_null(p0$weight_label)
  expect_null(p0$weight_variable)
  expect_null(p0$show_unweighted_n)
  expect_null(p0$show_effective_n)

  # weighted -> flag + label + variable + base-row visibility for the renderer
  p1 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(apply_weighting = TRUE,
                                        weight_label = "Weighted",
                                        weight_variable = "weight",
                                        show_unweighted_n = TRUE,
                                        show_effective_n = TRUE))$project
  expect_true(p1$weighted)
  expect_equal(p1$weight_label, "Weighted")
  expect_equal(p1$weight_variable, "weight")
  expect_true(p1$show_unweighted_n)
  expect_true(p1$show_effective_n)
  # weighted base row defaults on when the key is absent
  expect_true(p1$show_weighted_base)

  # weighted but no optional label/variable -> those omitted, flag still carried
  p2 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(apply_weighting = TRUE))$project
  expect_true(p2$weighted)
  expect_null(p2$weight_label)
  expect_null(p2$weight_variable)
  expect_false(p2$show_effective_n)

  # the weighted base row can be dropped for simpler client tables
  p3 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(apply_weighting = TRUE,
                                        show_weighted_base = FALSE))$project
  expect_false(p3$show_weighted_base)
})

test_that("project carries wave_order only for sub-annual trackers (G2)", {
  # not set -> omitted, so annual trackers key off the parsed year (unchanged)
  p0 <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())$project
  expect_null(p0$wave_order)
  # twice-yearly -> the fractional order key rides into the report
  p1 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(wave_order = 2025.5))$project
  expect_equal(p1$wave_order, 2025.5)
  # blank / non-numeric -> omitted
  p2 <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(wave_order = ""))$project
  expect_null(p2$wave_order)
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

test_that("a study's own report-construction note reaches report_meta", {
  # Turas describes a stock Turas report accurately; a study with stages around
  # it (a derived engine ahead, a preparation layer, pages that compute in the
  # browser) says so itself, in Comments _REPORT_CONSTRUCTION.
  cfg <- make_dl_config(
    company_name = "The Research Lamppost",
    report_construction = paste(
      "Figures are computed in R, then a preparation layer adds composite",
      "columns, and the section pages recompute in the browser."))
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_match(p$report_meta$construction, "preparation layer adds composite")
})

test_that("a config that declares no construction note carries an empty one", {
  # the About card falls back to its standard sentence on an empty string, so a
  # report that says nothing must render exactly as it did before this existed
  cfg <- make_dl_config(company_name = "The Research Lamppost")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_equal(p$report_meta$construction, "")
})

test_that("a construction note of literal 'NA' is treated as blank", {
  cfg <- make_dl_config(company_name = "The Research Lamppost",
                        report_construction = "NA")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  expect_equal(p$report_meta$construction, "")
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

test_that("a Composite index lands on the dashboard (scale_max + thresholds, type single)", {
  cfg <- make_dl_config(dashboard_scale_index = 5, dashboard_green_index = 4,
                        dashboard_amber_index = 3)
  dl <- build_data_layer(list(QE = make_dl_q_composite()), make_dl_banner_info(), cfg)
  q <- Filter(function(q) q$code == "Q_Engage", dl$questions)[[1]]
  expect_equal(q$type, "single")     # composites map to "single"...
  expect_equal(q$scale_max, 5)       # ...but still get the index scale (was NA -> off dashboard)
  expect_equal(q$gauge_green, 4)
  expect_equal(q$gauge_amber, 3)
  # carries the mean row the renderer's indexQuestions() also requires
  expect_true(any(vapply(q$rows, function(r) identical(r$kind, "mean"), logical(1))))
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

test_that("box-category rows carry counts; NET POSITIVE rows do not (Counts toggle)", {
  dl <- build_data_layer(list(Q4 = make_dl_q_boxcounts()), make_dl_banner_info(),
                         make_dl_config())
  q <- Filter(function(q) q$code == "Q4", dl$questions)[[1]]
  by_label <- function(lab) Filter(function(r) r$label == lab, q$rows)[[1]]

  # Box categories are "net" kind but carry their real Frequency so the renderer's
  # "Counts" toggle shows n= (the classic-report behaviour Duncan expects).
  good <- by_label("Good (9 - 10)")
  expect_equal(good$kind, "net")
  expect_equal(good$n[[1]], 48)
  expect_equal(by_label("Poor (1 - 5)")$n[[1]], 12)

  # A NET POSITIVE row is a percentage-point difference, not a count — n stays
  # null even though this fixture planted a Frequency on it.
  np <- by_label("NET POSITIVE (Good - Poor)")
  expect_equal(np$kind, "net")
  expect_true(is.na(np$n[[1]]))
})

test_that("project carries the configured chart palette + series colours", {
  skip_if_not(exists("get_palette_colours", mode = "function"))
  cfg <- make_dl_config(chart_palette_preset = "warm", chart_bar_colour = "#112233",
                        chart_series_colour_1 = "#445566", chart_series_colour_2 = "Optional")
  p <- build_data_layer(make_dl_results(), make_dl_banner_info(), cfg)$project
  # The resolved warm preset travels so the renderer can colour categories
  # semantically (negative = red, positive = green) like the classic report.
  expect_equal(p$chart_palette$negative, "#b85450")
  expect_equal(p$chart_palette$positive, "#4a7c6f")
  expect_equal(p$chart_bar_colour, "#112233")
  # Only well-formed hex series colours travel; the "Optional" placeholder drops.
  expect_equal(p$chart_series, list("#445566"))
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

# ==============================================================================
# AI insights (build_dl_ai + dl$ai)
# ==============================================================================

context("data_layer_writer: AI insights")

# Write a synthetic AI sidecar next to a temp config path and return the config.
write_ai_sidecar_fixture <- function(cfg_path, sidecar) {
  path <- paste0(tools::file_path_sans_ext(cfg_path), "_ai_insights.json")
  writeLines(jsonlite::toJSON(sidecar, auto_unbox = TRUE, pretty = TRUE, null = "null"),
             path)
  path
}

make_ai_sidecar <- function(enabled = TRUE, exec_verified = FALSE) {
  list(
    config = list(enabled = enabled, provider = "anthropic", model = "claude-opus-4-8"),
    questions = list(
      Q1 = list(ai_callout = list(has_insight = TRUE,
                                  narrative = "Two-thirds reported no lost hours.",
                                  confidence = "high", data_limitations = "")),
      Q2 = list(ai_callout = list(has_insight = FALSE, narrative = "", confidence = "low")),
      Q3 = list(ai_callout = list(has_insight = TRUE, narrative = "Small-base signal.",
                                  confidence = "low", data_limitations = "n=12 base"))),
    executive_summary = list(narrative = "Finding one.\n\nFinding two.",
                             verified = exec_verified))
}

test_that(".dl_ai_model_display prettifies known IDs and passes others through", {
  expect_equal(.dl_ai_model_display(list(model = "claude-sonnet-4-6", provider = "anthropic")),
               "Claude Sonnet 4.6 (Anthropic)")
  expect_equal(.dl_ai_model_display(list(model = "claude-opus-4-8", provider = "anthropic")),
               "Claude Opus 4.8 (Anthropic)")
  expect_equal(.dl_ai_model_display(list(model = "gpt-4.1", provider = "openai")),
               "gpt-4.1 (OpenAI)")
})

test_that("build_dl_ai surfaces only noteworthy callouts + the exec summary", {
  cfg_path <- tempfile(fileext = ".xlsx")
  side_path <- write_ai_sidecar_fixture(cfg_path, make_ai_sidecar())
  on.exit(unlink(side_path))

  ai <- build_dl_ai(list(enable_ai_insights = TRUE, config_file_path = cfg_path))
  expect_false(is.null(ai))
  expect_equal(ai$model, "Claude Opus 4.8 (Anthropic)")
  expect_equal(sort(names(ai$callouts)), c("Q1", "Q3"))     # Q2 has_insight FALSE → dropped
  expect_equal(ai$callouts$Q1$text, "Two-thirds reported no lost hours.")
  expect_null(ai$callouts$Q1$caveat)                        # high confidence → no caveat
  expect_equal(ai$callouts$Q3$caveat, "n=12 base")          # low confidence → caveat kept
  expect_false(ai$execSummary$verified)
  expect_match(ai$execSummary$text, "Finding one")
})

test_that("build_dl_ai returns NULL when disabled, sidecar missing, or sidecar disabled", {
  cfg_path <- tempfile(fileext = ".xlsx")
  side_path <- write_ai_sidecar_fixture(cfg_path, make_ai_sidecar(enabled = TRUE))
  on.exit(unlink(side_path))

  expect_null(build_dl_ai(list(enable_ai_insights = FALSE, config_file_path = cfg_path)))
  expect_null(build_dl_ai(list(enable_ai_insights = TRUE, config_file_path = tempfile())))

  disabled_path <- write_ai_sidecar_fixture(tempfile(fileext = ".xlsx"),
                                            make_ai_sidecar(enabled = FALSE))
  on.exit(unlink(disabled_path), add = TRUE)
  expect_null(build_dl_ai(list(enable_ai_insights = TRUE,
                               config_file_path = sub("_ai_insights\\.json$", ".xlsx", disabled_path))))
})

test_that("dl$ai is attached when ai is supplied and omitted otherwise", {
  ai <- list(model = "Claude Opus 4.8 (Anthropic)",
             callouts = list(Q1 = list(text = "x", confidence = "high")))
  dl_with <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                              make_dl_config(), ai = ai)
  expect_equal(dl_with$ai$model, "Claude Opus 4.8 (Anthropic)")
  expect_equal(dl_with$ai$callouts$Q1$text, "x")

  dl_without <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  expect_false("ai" %in% names(dl_without))                 # AI-free reports unchanged
})

# ==============================================================================
# Weighted base serialisation (D1/E1) — the renderer needs the weighted + effective
# base to recompute proportions/significance correctly, not the unweighted base.
# ==============================================================================

test_that("weighted reports serialise the weighted + effective base; unweighted omit them", {
  q <- make_dl_q_single()
  q$bases <- list(
    "TOTAL::Total"   = list(unweighted = 100, weighted = 120, effective = 90),
    "Gender::Male"   = list(unweighted = 50,  weighted = 70,  effective = 44),
    "Gender::Female" = list(unweighted = 50,  weighted = 50,  effective = 48))
  bi <- make_dl_banner_info()

  # Weighted: nWeighted + nEff ride alongside the unweighted n (which still drives display).
  wq <- build_dl_question(q, bi, make_dl_config(apply_weighting = TRUE), low_base = 30)
  expect_equal(wq$bases[[1]]$n, 100)
  expect_equal(wq$bases[[1]]$nWeighted, 120)
  expect_equal(wq$bases[[1]]$nEff, 90)
  expect_equal(wq$bases[[2]]$nWeighted, 70)
  expect_equal(wq$bases[[2]]$nEff, 44)

  # Unweighted (default): byte-identical — no nWeighted/nEff keys at all.
  uq <- build_dl_question(q, bi, make_dl_config(apply_weighting = FALSE), low_base = 30)
  expect_equal(uq$bases[[1]]$n, 100)
  expect_null(uq$bases[[1]]$nWeighted)
  expect_null(uq$bases[[1]]$nEff)
})

# ==============================================================================
# ROWS KEYED BY (RowLabel, RowSource) — a box NET sharing an option's label
# must keep BOTH rows (audit fix: unique labels dropped the NET row)
# ==============================================================================

context("data_layer_writer: label collisions (option vs box NET)")

# 5-point-style scale where the BoxCategory NET is named "Satisfied" — the same
# label as one of its member options. Classic Excel shows both rows.
make_dl_q_label_collision <- function() {
  list(
    question_code = "Q9", question_text = "How satisfied are you?",
    question_type = "Likert", category = "Satisfaction",
    table = data.frame(
      RowLabel  = c("Very satisfied", "Very satisfied",
                    "Satisfied", "Satisfied",
                    "Dissatisfied", "Dissatisfied",
                    "Satisfied", "Satisfied"),          # the NET, same label
      RowType   = c("Frequency", "Column %",
                    "Frequency", "Column %",
                    "Frequency", "Column %",
                    "Frequency", "Column %"),
      RowSource = c("individual", "individual",
                    "individual", "individual",
                    "individual", "individual",
                    "boxcategory", "boxcategory"),
      "TOTAL::Total"   = c("25", "25.0", "30", "30.0", "45", "45.0", "55", "55.0"),
      "Gender::Male"   = c("15", "30.0", "15", "30.0", "20", "40.0", "30", "60.0"),
      "Gender::Female" = c("10", "20.0", "15", "30.0", "25", "50.0", "25", "50.0"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100, weighted = 100, effective = 100),
      "Gender::Male"   = list(unweighted = 50,  weighted = 50,  effective = 50),
      "Gender::Female" = list(unweighted = 50,  weighted = 50,  effective = 50))
  )
}

test_that("an option row and a box NET sharing a label BOTH survive", {
  q <- build_dl_question(make_dl_q_label_collision(), make_dl_banner_info(),
                         make_dl_config(), low_base = 30)
  sat_rows <- Filter(function(r) identical(r$label, "Satisfied"), q$rows)
  expect_length(sat_rows, 2)
  kinds <- vapply(sat_rows, function(r) r$kind, character(1))
  expect_setequal(kinds, c("category", "net"))
  # Each row carries ITS OWN values: option 30% / NET 55% on Total
  opt <- Find(function(r) identical(r$kind, "category"), sat_rows)
  net <- Find(function(r) identical(r$kind, "net"), sat_rows)
  expect_equal(opt$pct[[1]], 30)
  expect_equal(net$pct[[1]], 55)
  expect_equal(opt$n[[1]], 30)     # frequencies stay per-row too
  expect_equal(net$n[[1]], 55)
  # Row order preserved: the NET (appended after the options) comes last
  labels <- vapply(q$rows, function(r) r$label, character(1))
  expect_equal(labels, c("Very satisfied", "Satisfied", "Dissatisfied", "Satisfied"))
  expect_equal(vapply(q$rows, function(r) r$kind, character(1)),
               c("category", "category", "category", "net"))
})

test_that("a table without RowSource still keys by label alone (unchanged)", {
  q_def <- make_dl_q_label_collision()
  q_def$table$RowSource <- NULL
  q <- build_dl_question(q_def, make_dl_banner_info(), make_dl_config(), low_base = 30)
  # Without RowSource the two "Satisfied" parents can't be told apart — the
  # legacy single-row behaviour is preserved (first values win)
  sat_rows <- Filter(function(r) identical(r$label, "Satisfied"), q$rows)
  expect_length(sat_rows, 1)
  expect_equal(sat_rows[[1]]$pct[[1]], 30)
})


test_that("a question with a malformed table is skipped BY NAME on the console (I15)", {
  # The Excel workbook still carries such a question, so an unnamed skip ships
  # an HTML report that silently disagrees with it.
  good <- make_dl_q_single()
  broken <- list(question_code = "Q_BROKEN", question_text = "Broken",
                 question_type = "Single_Response", table = NULL, bases = NULL)
  out <- capture.output(
    dl <- build_data_layer(list(Q1 = good, Q_BROKEN = broken),
                           make_dl_banner_info(), make_dl_config())
  )
  expect_true(any(grepl("Q_BROKEN", out)))
  expect_true(any(grepl("omitted from the v2 report", out)))
  expect_equal(length(dl$questions), 1L)
})


# ==============================================================================
# REPORTED STATISTIC (review 2026-08, CRITICAL C1)
# ==============================================================================
# A config that turns the column percentage off (show_percent_column = N) puts
# ROW percentages or raw FREQUENCIES into the same `pct` slot. The island
# carried nothing naming the quantity, so the v2 renderer labelled all of them
# "%" and a counts-only run shipped "142%", "80% B". `stat` now names it — and
# is emitted ONLY when it is not the column percentage, so every ordinary
# config produces a byte-identical island.

# Counts-only: Frequency + Sig. rows, no Column % anywhere.
make_dl_q_counts_only <- function() {
  list(
    question_code = "Q_CNT", question_text = "Are you aware?",
    question_type = "Single_Choice", category = "Awareness",
    table = data.frame(
      RowLabel  = c("Yes", "Yes", "No", "No"),
      RowType   = c("Frequency", "Sig.", "Frequency", "Sig."),
      RowSource = rep("individual", 4),
      "TOTAL::Total"   = c("142", "", "58", ""),
      "Gender::Male"   = c("80", "B", "20", ""),
      "Gender::Female" = c("62", "", "38", "A"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 200),
      "Gender::Male"   = list(unweighted = 100),
      "Gender::Female" = list(unweighted = 100)))
}

test_that("a counts-only question names its statistic on the island", {
  q <- build_dl_question(make_dl_q_counts_only(), make_dl_banner_info(),
                         make_dl_config(), low_base = 30)
  expect_equal(q$stat, "Frequency")
  # the values ARE the raw counts — the point of the flag
  expect_equal(unlist(q$rows[[1]]$pct), c(142, 80, 62))
})

test_that("a row-%-only question names its statistic on the island", {
  qdef <- make_dl_q_counts_only()
  qdef$table$RowType <- c("Row %", "Sig.", "Row %", "Sig.")
  q <- build_dl_question(qdef, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_equal(q$stat, "Row %")
})

test_that("an ordinary column-% question emits NO stat key (byte-identical)", {
  q <- build_dl_question(make_dl_q_single(), make_dl_banner_info(),
                         make_dl_config(), low_base = 30)
  expect_false("stat" %in% names(q))
  expect_false(any(vapply(q$rows, function(r) "stat" %in% names(r), logical(1))))
})

test_that("a Frequency-only row among column %s carries its own stat", {
  # The fall-through substitutes Frequency for a row with no Column % — that
  # row's 37 people rendered as "37%" beside a real 37.0% (C1).
  qdef <- list(
    question_code = "Q_MIX", question_text = "Mixed", category = "Awareness",
    question_type = "Single_Choice",
    table = data.frame(
      RowLabel  = c("Yes", "Yes", "Other"),
      RowType   = c("Frequency", "Column %", "Frequency"),
      RowSource = rep("individual", 3),
      "TOTAL::Total"   = c("74", "37.0", "37"),
      "Gender::Male"   = c("40", "40.0", "20"),
      "Gender::Female" = c("34", "34.0", "17"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 200),
      "Gender::Male"   = list(unweighted = 100),
      "Gender::Female" = list(unweighted = 100)))
  q <- build_dl_question(qdef, make_dl_banner_info(), make_dl_config(), low_base = 30)
  expect_false("stat" %in% names(q))                 # question is column %
  expect_false("stat" %in% names(q$rows[[1]]))       # "Yes" is a column %
  expect_equal(q$rows[[2]]$stat, "Frequency")        # "Other" is a headcount
  expect_equal(unlist(q$rows[[2]]$pct), c(37, 20, 17))
})

# ==============================================================================
# MEDIAN AND MODE MUST REACH THE V2 REPORT
# ==============================================================================
# numeric_processor honours show_numeric_median / show_numeric_mode and writes
# those rows to the workbook, but the data layer's mean_types whitelist omitted
# them — so the "mean" branch hit `next` and the rows vanished on the way into
# the interactive report. The Excel and the v2 report disagreed silently.

make_dl_q_numeric_full <- function() {
  list(
    question_code = "Q3b", question_text = "Transactions a month",
    question_type = "Numeric", category = "Service",
    table = data.frame(
      RowLabel  = c("Mean", "Median", "Mode", "Standard Deviation"),
      RowType   = c("Average", "Median", "Mode", "StdDev"),
      RowSource = c("summary", "summary", "summary", "summary"),
      "TOTAL::Total"   = c("2.5", "1.6", "1.0", "3.0"),
      "Gender::Male"   = c("2.2", "1.5", "1.0", "2.8"),
      "Gender::Female" = c("2.8", "1.7", "1.0", "3.1"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 390, weighted = 390, effective = 390),
      "Gender::Male"   = list(unweighted = 168, weighted = 168, effective = 168),
      "Gender::Female" = list(unweighted = 222, weighted = 222, effective = 222))
  )
}

test_that("Median and Mode rows survive into the data layer", {
  q <- build_dl_question(make_dl_q_numeric_full(), make_dl_banner_info(),
                         make_dl_config(), low_base = 30)
  labels <- vapply(q$rows, function(r) r$label, character(1))
  expect_true("Mean" %in% labels)
  expect_true("Median" %in% labels)
  expect_true("Mode" %in% labels)
  expect_true("Standard Deviation" %in% labels)

  med <- q$rows[[which(labels == "Median")]]
  expect_equal(med$kind, "mean")
  expect_equal(med$pct[[1]], 1.6)
})

test_that("adding Median/Mode does not change the headline metric type", {
  # metric_type keys off Average/Mean/Index/Score only — a Median row must not
  # claim it, or a plain numeric question would land on the index dashboard
  # alongside genuine ratings. Compared against the Mean+StdDev fixture rather
  # than a hard-coded value, so this asserts the INVARIANT: the extra rows
  # change nothing about how the question is classified.
  with_med <- build_dl_question(make_dl_q_numeric_full(), make_dl_banner_info(),
                                make_dl_config(), low_base = 30)
  baseline <- build_dl_question(make_dl_q_numeric(), make_dl_banner_info(),
                                make_dl_config(), low_base = 30)
  expect_identical(with_med$scale_max, baseline$scale_max)
  expect_identical(with_med$type, baseline$type)
})

# ==============================================================================
# ALLOCATION: ONE MEAN BLOCK PER OPTION (review 2026-08-21, I-5)
# ==============================================================================
# An Allocation question emits one "Average" row per option, each tagged
# RowSource="summary" and each followed by its own Sig. row. mean_sig_for's
# "exactly one sig row per summary block" guard then saw N sig rows and carried
# NONE, so a multi-option allocation showed significance letters in the Excel
# workbook and none in the v2 report — the Excel/report disagreement the D1 work
# removed for numeric questions. VAS 2026's wallet questions are 6-option
# allocations, so this is the shape that matters.

make_allocation_table <- function(option_labels) {
  keys <- c("TOTAL::Total", "Gender::Male", "Gender::Female")
  rows <- list()
  for (i in seq_along(option_labels)) {
    mean_row <- data.frame(RowLabel = option_labels[i], RowType = "Average",
                           RowSource = "summary", stringsAsFactors = FALSE)
    # Distinct means and letters per option, so a test cannot pass by accident
    # on a table where every block looks alike.
    mean_row[[keys[1]]] <- 30 + i
    mean_row[[keys[2]]] <- 32 + i
    mean_row[[keys[3]]] <- 28 + i
    sig_row <- data.frame(RowLabel = NA_character_, RowType = "Sig.",
                          RowSource = NA_character_, stringsAsFactors = FALSE)
    sig_row[[keys[1]]] <- "-"
    sig_row[[keys[2]]] <- if (i %% 2 == 1) "B" else ""     # odd options: Male > Female
    sig_row[[keys[3]]] <- if (i %% 2 == 0) "A" else ""     # even options: Female > Male
    rows[[length(rows) + 1L]] <- mean_row
    rows[[length(rows) + 1L]] <- sig_row
  }
  normalize_question_table(do.call(rbind, rows))
}

allocation_dl <- function(option_labels) {
  build_dl_question(
    list(code = "QWALLET", title = "Wallet share", table = make_allocation_table(option_labels)),
    make_dl_banner_info(), list(), 30
  )
}

test_that("a single-option allocation carries its significance letters", {
  q <- allocation_dl("Groceries")
  expect_equal(length(q$rows), 1)
  expect_equal(unlist(q$rows[[1]]$sig), c("", "B", ""))
})

test_that("a multi-option allocation carries EVERY option's letters, not none", {
  q <- allocation_dl(c("Groceries", "Transport", "Airtime"))
  expect_equal(length(q$rows), 3)

  # The regression: all three used to come back empty.
  expect_equal(unlist(q$rows[[1]]$sig), c("", "B", ""))
  expect_equal(unlist(q$rows[[2]]$sig), c("", "", "A"))
  expect_equal(unlist(q$rows[[3]]$sig), c("", "B", ""))

  # Each option keeps its OWN letters — the whole point is that the blocks are
  # told apart rather than one block's letters being copied to all of them.
  expect_false(identical(unlist(q$rows[[1]]$sig), unlist(q$rows[[2]]$sig)))
})

test_that("each allocation option keeps its own values alongside its own letters", {
  # A mean-kind row carries its values in pct[] (the shared numeric channel),
  # with mstat naming the statistic — so the values and the letters must line up
  # per option, not just the letters.
  q <- allocation_dl(c("Groceries", "Transport"))
  expect_equal(unlist(q$rows[[1]]$pct), c(31, 33, 29))
  expect_equal(unlist(q$rows[[2]]$pct), c(32, 34, 30))
})

test_that("a six-option allocation (the VAS 2026 wallet shape) loses nothing", {
  labels <- c("Groceries", "Transport", "Airtime", "Electricity", "School fees", "Savings")
  q <- allocation_dl(labels)
  expect_equal(length(q$rows), 6)
  expect_equal(vapply(q$rows, function(r) r$label, character(1)), labels)
  carried <- vapply(q$rows, function(r) any(nzchar(unlist(r$sig))), logical(1))
  expect_true(all(carried))
})
