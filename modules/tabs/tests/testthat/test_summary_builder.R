# ==============================================================================
# TABS MODULE - SUMMARY BUILDER TESTS (Index_Summary organisation)
# ==============================================================================
#
# Known-answer tests for summary_builder.R's organize_by_composite_groups:
#   - source questions are grouped (indented) under their emitted composite
#   - AUDIT FIX: source questions of a composite that is NOT emitted
#     (ExcludeFromSummary=Y / index_summary_show_composites=FALSE / missing
#     from composite_results) must fall through to the standard list instead
#     of silently vanishing from the client-facing Index_Summary sheet
#
# Production review 2026-08, I12(b) — test blind spot. Index_Summary values were
# asserted nowhere (the workbook tests checked only that the sheet exists, plus
# one disclosure-masking case), and five of the six functions that build it had
# no direct test at all: build_index_summary_table, extract_metric_rows,
# extract_composite_rows, insert_section_headers, format_summary_for_excel.
# The sections below are known-answer tests for each, asserting the NUMBERS that
# land in each banner column — not just the shape of the frame.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_summary_builder.R")
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

# config_utils.R resolves script_dir at source time — pre-set it (as the other
# tabs test files do) so sourcing works under testthat.
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign("script_dir", .tabs_lib_dir, envir = globalenv())

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
# disclosure_suppressed_columns() / disclosure_marker() — the sub-k gate the
# metric and composite extractors apply (production review 2026-08, C2).
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
# normalise_flag_column() + the shared yes/no vocabulary — ExcludeFromSummary is
# canonicalised at load, so the reader tests the word it actually receives.
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/data_setup.R"))
source(file.path(turas_root, "modules/tabs/lib/summary_builder.R"))

# ==============================================================================
# FIXTURES
# ==============================================================================

# One emitted composite (ENGAGE <- Q5,Q6) and one HIDDEN composite (<- Q7) that
# never made it into the metrics (ExcludeFromSummary / show_composites=FALSE /
# missing from composite_results all land here identically).
sb_composite_defs <- function() data.frame(
  CompositeCode   = c("ENGAGE", "HIDDEN"),
  SourceQuestions = c("Q5,Q6", "Q7"),
  stringsAsFactors = FALSE)

sb_metric_row <- function(code, label, is_composite = FALSE, section = "") {
  data.frame(QuestionCode = code, RowLabel = label, IsComposite = is_composite,
             Section = section, Value = 1, stringsAsFactors = FALSE)
}

sb_metrics <- function(include_engage = TRUE) {
  rows <- list(
    sb_metric_row("Q5", "Q5 Average"),
    sb_metric_row("Q6", "Q6 Average"),
    sb_metric_row("Q7", "Q7 Average"),
    sb_metric_row("Q9", "Q9 Average"))
  if (include_engage) {
    rows <- c(list(sb_metric_row("ENGAGE", "Engagement Index", TRUE)), rows)
  }
  do.call(rbind, rows)
}

# ==============================================================================
# organize_by_composite_groups
# ==============================================================================

context("summary_builder: organize_by_composite_groups")

test_that("source questions group under their emitted composite", {
  out <- organize_by_composite_groups(sb_metrics(), sb_composite_defs(), list())
  # ENGAGE row first, its sources indented directly beneath
  engage_pos <- which(out$QuestionCode == "ENGAGE")
  expect_length(engage_pos, 1)
  expect_equal(out$QuestionCode[engage_pos + 1:2], c("Q5", "Q6"))
  expect_true(all(grepl("^  ", out$RowLabel[engage_pos + 1:2])))   # indented
  # Each source appears exactly once (grouped, not duplicated in remaining)
  expect_equal(sum(out$QuestionCode == "Q5"), 1)
  expect_equal(sum(out$QuestionCode == "Q6"), 1)
})

test_that("sources of a NON-emitted composite still appear in the summary", {
  # HIDDEN is defined but not in the metrics -> Q7 must fall through to the
  # standard list (previously it vanished from Index_Summary entirely)
  out <- organize_by_composite_groups(sb_metrics(), sb_composite_defs(), list())
  expect_equal(sum(out$QuestionCode == "Q7"), 1)
  expect_false(grepl("^  ", out$RowLabel[out$QuestionCode == "Q7"]))  # not indented
  # And the untouched standalone question is still there
  expect_equal(sum(out$QuestionCode == "Q9"), 1)
})

test_that("with NO composites emitted, every source question survives", {
  # e.g. index_summary_show_composites = FALSE: composite rows absent entirely
  out <- organize_by_composite_groups(sb_metrics(include_engage = FALSE),
                                      sb_composite_defs(), list())
  expect_setequal(out$QuestionCode, c("Q5", "Q6", "Q7", "Q9"))
  expect_false(any(out$QuestionCode == "ENGAGE"))
})

test_that("no composite_defs leaves the metrics intact (sorted, none dropped)", {
  out <- organize_by_composite_groups(sb_metrics(include_engage = FALSE), NULL, list())
  expect_setequal(out$QuestionCode, c("Q5", "Q6", "Q7", "Q9"))
})

# ==============================================================================
# I12(b) FIXTURES — a banner and question results shaped like the real engine's
# ==============================================================================

# Three banner columns, named with the engine's internal "Dim::Option" keys.
SB_KEYS <- c("TOTAL::Total", "Gender::Male", "Gender::Female")
sb_banner <- function() list(internal_keys = SB_KEYS)

#' One question result carrying every row type the extractor must judge:
#' a Frequency and a Column % (NOT metrics), an Average (a metric), a
#' Top 2 Box Column % (a metric by label), and a Top 2 Box "Sig." row
#' (a letters row that must never be mistaken for the metric beside it).
sb_question <- function(code = "Q1", text = "How satisfied?",
                        type = "Single_Response",
                        total = 5.5, male = 5.4, female = 6.9,
                        female_base = 50) {
  list(
    question_code = code, question_text = text, question_type = type,
    table = data.frame(
      RowLabel = c("Satisfied", "Satisfied", "Top 2 Box", "Top 2 Box", "Mean"),
      RowType  = c("Frequency", "Column %", "Column %", "Sig.", "Average"),
      "TOTAL::Total"   = c(60, 60.0, 71.0, "B", total),
      "Gender::Male"   = c(35, 70.0, 80.0, "",  male),
      "Gender::Female" = c(25, 50.0, 62.0, "",  female),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100, weighted = 100, effective = 100),
      "Gender::Male"   = list(unweighted = 50,  weighted = 50,  effective = 50),
      "Gender::Female" = list(unweighted = female_base, weighted = female_base,
                              effective = female_base)))
}

#' One composite result: an Index row over the same three columns.
sb_composite <- function(total = 72.5, male = 75.0, female = 70.0,
                         sources = "Q1") {
  list(ENGAGE = list(
    question_table = data.frame(
      RowLabel = "Engagement Index", RowType = "Index",
      "TOTAL::Total" = total, "Gender::Male" = male, "Gender::Female" = female,
      check.names = FALSE, stringsAsFactors = FALSE),
    metadata = list(source_questions = sources)))
}

sb_comp_defs <- function(section = "Engagement", exclude = NA_character_,
                         sources = "Q1,Q2") {
  data.frame(CompositeCode = "ENGAGE", SourceQuestions = sources,
             SectionLabel = section, ExcludeFromSummary = exclude,
             stringsAsFactors = FALSE)
}

# ==============================================================================
# extract_metric_rows — WHICH rows are metrics, and do their numbers survive
# ==============================================================================

context("summary_builder: extract_metric_rows (I12b)")

test_that("only metric rows are extracted, and each keeps its own column values", {
  out <- extract_metric_rows(list(Q1 = sb_question()), sb_banner(), list())

  # The Average and the Top 2 Box Column % — and nothing else. The Frequency and
  # the plain-category Column % rows are not summary metrics.
  expect_equal(nrow(out), 2)
  expect_setequal(out$RowType, c("Average", "Column %"))

  avg <- out[out$RowType == "Average", ]
  expect_equal(avg[["TOTAL::Total"]], "5.5")
  expect_equal(avg[["Gender::Male"]], "5.4")
  expect_equal(avg[["Gender::Female"]], "6.9")

  box <- out[out$RowType == "Column %", ]
  expect_equal(box[["TOTAL::Total"]], "71")
  expect_equal(box[["Gender::Male"]], "80")
  expect_equal(box[["Gender::Female"]], "62")
})

test_that("a Top Box 'Sig.' row is never mistaken for the metric beside it", {
  # The letters row shares the Top 2 Box label; extracting it would print "B"
  # where a percentage belongs.
  out <- extract_metric_rows(list(Q1 = sb_question()), sb_banner(), list())
  expect_false(any(out$RowType == "Sig."))
  expect_false(any(unlist(out[, SB_KEYS]) == "B", na.rm = TRUE))
})

test_that("metric labels carry the question code and text; boxes keep their own", {
  out <- extract_metric_rows(list(Q1 = sb_question()), sb_banner(), list())
  # A generic "Mean" becomes the question; a box row is the question PLUS its label
  # (otherwise two box rows on one question would be indistinguishable).
  expect_equal(out$RowLabel[out$RowType == "Average"], "Q1 - How satisfied?")
  expect_equal(out$RowLabel[out$RowType == "Column %"],
               "Q1 - How satisfied? - Top 2 Box")
})

test_that("a question with no text falls back to its code, never to NA", {
  q <- sb_question(); q$question_text <- NULL
  out <- extract_metric_rows(list(Q1 = q), sb_banner(), list())
  expect_equal(out$RowLabel[out$RowType == "Average"], "Q1 - Q1")
  expect_false(any(is.na(out$RowLabel)))
})

test_that("ranking questions are skipped entirely", {
  out <- extract_metric_rows(list(Q1 = sb_question(type = "Ranking")),
                             sb_banner(), list())
  expect_equal(nrow(out), 0)
})

test_that("every metric row is tagged as a non-composite with its question code", {
  out <- extract_metric_rows(list(Q1 = sb_question()), sb_banner(), list())
  expect_true(all(out$QuestionCode == "Q1"))
  expect_true(all(out$IsComposite == FALSE))
})

test_that("no metrics anywhere returns an empty frame that still has the banner columns", {
  # The empty case flows straight into rbind downstream — a frame missing the
  # banner columns would drop them from the sheet.
  out <- extract_metric_rows(list(), sb_banner(), list())
  expect_equal(nrow(out), 0)
  expect_true(all(SB_KEYS %in% names(out)))
  expect_true(all(c("RowLabel", "RowType", "QuestionCode",
                    "IsComposite", "Section") %in% names(out)))
})

test_that("a question whose table has no metric row contributes nothing", {
  q <- sb_question()
  q$table <- q$table[q$table$RowType %in% c("Frequency", "Column %") &
                       q$table$RowLabel == "Satisfied", , drop = FALSE]
  expect_equal(nrow(extract_metric_rows(list(Q1 = q), sb_banner(), list())), 0)
})

test_that("sub-k columns are withheld from the metric rows, safe columns are not (C2)", {
  # Female base 3 under k = 10: the Crosstabs sheet withholds that column, so the
  # Index_Summary must not restate its mean three sheets away.
  out <- extract_metric_rows(list(Q1 = sb_question(female_base = 3)), sb_banner(),
                             list(min_reporting_base = 10))
  expect_true(all(out[["Gender::Female"]] == "n<10"))
  expect_equal(out[["Gender::Male"]], c("5.4", "80"))     # safe column untouched
  expect_equal(out[["TOTAL::Total"]], c("5.5", "71"))
})

test_that("with no k set nothing is withheld", {
  out <- extract_metric_rows(list(Q1 = sb_question(female_base = 3)),
                             sb_banner(), list())
  expect_equal(out[["Gender::Female"]], c("6.9", "62"))
})

# ==============================================================================
# extract_composite_rows
# ==============================================================================

context("summary_builder: extract_composite_rows (I12b)")

test_that("a composite's index value reaches every banner column", {
  out <- extract_composite_rows(sb_composite(), sb_banner(), sb_comp_defs(), list())
  expect_equal(nrow(out), 1)
  expect_equal(out[["TOTAL::Total"]], 72.5)
  expect_equal(out[["Gender::Male"]], 75.0)
  expect_equal(out[["Gender::Female"]], 70.0)
  expect_true(out$IsComposite)
  expect_equal(out$QuestionCode, "ENGAGE")
  expect_equal(out$Section, "Engagement")
})

test_that("the composite label names its source questions", {
  out <- extract_composite_rows(sb_composite(), sb_banner(), sb_comp_defs(), list())
  expect_equal(out$RowLabel, "Engagement Index (Q1, Q2)")
})

test_that("ExcludeFromSummary drops the composite, case- and space-insensitively", {
  for (token in c("Y", "y", " y ")) {
    out <- extract_composite_rows(sb_composite(), sb_banner(),
                                  sb_comp_defs(exclude = token), list())
    expect_equal(nrow(out), 0, info = token)
  }
  # Blank / NA is the documented default: keep the composite.
  for (token in c(NA_character_, "", "N")) {
    out <- extract_composite_rows(sb_composite(), sb_banner(),
                                  sb_comp_defs(exclude = token), list())
    expect_equal(nrow(out), 1, info = as.character(token))
  }
})

test_that("the reader honours the whole C3 yes-vocabulary, normalised at load", {
  # The Composites sheet was not among C3's six columns, so ExcludeFromSummary
  # was read with a bare toupper(trimws(x)) == "Y": "Yes" meant NO and the
  # composite the operator asked to hide shipped anyway, silently. The column is
  # now normalised at its single load site (composite_processor.R
  # load_composite_definitions) to exactly "Y"/"N", so the reader sees one word.
  # This asserts the reader end; the load end is in test_composite_processor.R.
  for (token in .TABS_FLAG_TRUE_TOKENS) {
    canonical <- normalise_flag_column(token, "ExcludeFromSummary",
                                       "Composite_Metrics", default = "N")
    out <- extract_composite_rows(sb_composite(), sb_banner(),
                                  sb_comp_defs(exclude = canonical), list())
    expect_equal(nrow(out), 0, info = token)
  }
  for (token in .TABS_FLAG_FALSE_TOKENS) {
    canonical <- normalise_flag_column(token, "ExcludeFromSummary",
                                       "Composite_Metrics", default = "N")
    out <- extract_composite_rows(sb_composite(), sb_banner(),
                                  sb_comp_defs(exclude = canonical), list())
    expect_equal(nrow(out), 1, info = token)
  }
})

test_that("index_summary_show_composites = FALSE returns an empty banner-shaped frame", {
  out <- extract_composite_rows(sb_composite(), sb_banner(), sb_comp_defs(),
                                list(index_summary_show_composites = FALSE))
  expect_equal(nrow(out), 0)
  expect_true(all(SB_KEYS %in% names(out)))
})

test_that("no composite_defs still emits the composite, with a bare label (M6)", {
  # comp_def is NULL here; referencing it unguarded used to crash the sheet.
  out <- extract_composite_rows(sb_composite(), sb_banner(), NULL, list())
  expect_equal(nrow(out), 1)
  expect_equal(out$RowLabel, "Engagement Index")
  expect_true(is.na(out$Section))
})

test_that("a composite withholds the sub-k columns its source question withholds (C2)", {
  out <- extract_composite_rows(
    sb_composite(), sb_banner(), sb_comp_defs(),
    list(min_reporting_base = 10),
    results_list = list(Q1 = sb_question(female_base = 3)))
  expect_equal(out[["Gender::Female"]], "n<10")
  expect_equal(out[["Gender::Male"]], 75)   # safe column keeps its number
})

# ==============================================================================
# insert_section_headers
# ==============================================================================

context("summary_builder: insert_section_headers (I12b)")

sb_sectioned <- function(sections) {
  n <- length(sections)
  df <- data.frame(
    RowLabel = LETTERS[seq_len(n)], RowType = rep("Average", n),
    QuestionCode = paste0("Q", seq_len(n)), IsComposite = rep(FALSE, n),
    Section = sections, stringsAsFactors = FALSE)
  for (k in SB_KEYS) df[[k]] <- seq_len(n)
  df
}

test_that("one header per section change, immediately above the section's first row", {
  out <- insert_section_headers(sb_sectioned(c("S1", "S1", "", "S2")), sb_banner())
  expect_equal(out$RowLabel, c("S1", "A", "B", "C", "S2", "D"))
  expect_equal(out$RowType,
               c("SectionHeader", "Average", "Average", "Average",
                 "SectionHeader", "Average"))
})

test_that("a repeated section does not get a second header", {
  out <- insert_section_headers(sb_sectioned(c("S1", "S1", "S1")), sb_banner())
  expect_equal(sum(out$RowType == "SectionHeader"), 1)
})

test_that("a section that returns after a break gets its header again", {
  # ...otherwise the second run of S1 rows sits under S2's heading.
  out <- insert_section_headers(sb_sectioned(c("S1", "S2", "S1")), sb_banner())
  expect_equal(out$RowLabel, c("S1", "A", "S2", "B", "S1", "C"))
})

test_that("header rows carry blank banner cells, never a data value", {
  out <- insert_section_headers(sb_sectioned(c("S1", "S1")), sb_banner())
  hdr <- out[out$RowType == "SectionHeader", ]
  expect_true(all(hdr[, SB_KEYS] == ""))
  expect_true(is.na(hdr$QuestionCode))
})

test_that("data rows survive a header insert with their values intact", {
  out <- insert_section_headers(sb_sectioned(c("S1", "S1")), sb_banner())
  data_rows <- out[out$RowType == "Average", ]
  expect_equal(nrow(data_rows), 2)
  # The header row's blank banner cells coerce the column to character on rbind;
  # the values themselves must still be the ones that were computed (the Excel
  # writer converts a clean numeric string back to a number when it writes).
  expect_equal(as.numeric(data_rows[["Gender::Male"]]), c(1, 2))
  expect_equal(as.numeric(data_rows[["TOTAL::Total"]]), c(1, 2))
})

test_that("no Section column, or no rows, passes straight through", {
  df <- sb_sectioned(c("S1", "S1")); df$Section <- NULL
  expect_identical(insert_section_headers(df, sb_banner()), df)
  empty <- sb_sectioned(c("S1"))[0, , drop = FALSE]
  expect_equal(nrow(insert_section_headers(empty, sb_banner())), 0)
})

# ==============================================================================
# format_summary_for_excel
# ==============================================================================

context("summary_builder: format_summary_for_excel (I12b)")

sb_to_format <- function() data.frame(
  RowLabel = c("Engagement", "Engagement Index", "  Q5 - Source five",
               "Q9 - Unrelated nine "),
  RowType = c("SectionHeader", "Index", "Average", "Average"),
  IsComposite = c(NA, TRUE, FALSE, FALSE), stringsAsFactors = FALSE)

test_that("StyleHint marks section headers, composites and plain metrics", {
  out <- format_summary_for_excel(sb_to_format(), sb_banner(), list())
  expect_equal(out$StyleHint,
               c("SectionHeader", "Composite", "Normal", "Normal"))
})

test_that("only the composite label takes the arrow prefix", {
  out <- format_summary_for_excel(sb_to_format(), sb_banner(), list())
  expect_equal(out$RowLabel[2], "→ Engagement Index")
  expect_false(any(grepl("→", out$RowLabel[-2])))
})

test_that("trailing whitespace is cleaned off a label", {
  out <- format_summary_for_excel(sb_to_format(), sb_banner(), list())
  expect_equal(out$RowLabel[4], "Q9 - Unrelated nine")
})

test_that("the source-question indent survives formatting — it is the only nesting cue", {
  # organize_by_composite_groups indents a composite's source questions by two
  # spaces, and the Index_Summary writer has no indent style: it writes the label
  # string verbatim. Trimming through the indent leaves a source question looking
  # exactly like an unrelated standalone one (production review 2026-08, I12b).
  out <- format_summary_for_excel(sb_to_format(), sb_banner(), list())
  expect_equal(out$RowLabel[3], "  Q5 - Source five")
})

test_that("an empty frame passes straight through", {
  empty <- sb_to_format()[0, , drop = FALSE]
  expect_equal(nrow(format_summary_for_excel(empty, sb_banner(), list())), 0)
})

# ==============================================================================
# build_index_summary_table — the whole sheet, end to end
# ==============================================================================

context("summary_builder: build_index_summary_table (I12b)")

sb_build <- function(config = list(), comp_defs = sb_comp_defs()) {
  build_index_summary_table(
    results_list = list(Q1 = sb_question()),
    composite_results = sb_composite(),
    banner_info = sb_banner(), config = config,
    composite_defs = comp_defs)
}

test_that("the assembled sheet carries every metric, in composite-first order", {
  out <- sb_build()
  # Section header, the composite, then its source question's two metric rows.
  expect_equal(out$RowLabel,
               c("Engagement",
                 "→ Engagement Index (Q1, Q2)",
                 "  Q1 - How satisfied?",
                 "  Q1 - How satisfied? - Top 2 Box"))
  expect_equal(out$StyleHint,
               c("SectionHeader", "Composite", "Normal", "Normal"))
})

test_that("every published number lands in the column it was computed for", {
  out <- sb_build()
  rows <- out[out$RowType != "SectionHeader", ]
  expect_equal(rows[["TOTAL::Total"]],   c("72.5", "5.5", "71"))
  expect_equal(rows[["Gender::Male"]],   c("75",   "5.4", "80"))
  expect_equal(rows[["Gender::Female"]], c("70",   "6.9", "62"))
})

test_that("index_summary_show_sections = FALSE ships the metrics with no header row", {
  out <- sb_build(config = list(index_summary_show_sections = FALSE))
  expect_false(any(out$RowType == "SectionHeader"))
  expect_equal(sum(out$RowType %in% c("Average", "Index", "Column %")), 3)
})

test_that("a run with no metrics at all returns an empty frame rather than failing", {
  out <- build_index_summary_table(list(), list(), sb_banner(), list(), NULL)
  expect_equal(nrow(out), 0)
})

test_that("with composites switched off the source question still reaches the sheet", {
  # The whole point of the earlier organise fix, asserted on the real deliverable.
  out <- build_index_summary_table(
    results_list = list(Q1 = sb_question()),
    composite_results = sb_composite(), banner_info = sb_banner(),
    config = list(index_summary_show_composites = FALSE),
    composite_defs = sb_comp_defs())
  expect_false(any(out$IsComposite %in% TRUE))
  expect_true(any(grepl("Q1 - How satisfied?", out$RowLabel, fixed = TRUE)))
  expect_true(any(out[["Gender::Male"]] == "5.4"))
})

test_that("a sub-k column is withheld across the whole assembled sheet (C2)", {
  out <- build_index_summary_table(
    results_list = list(Q1 = sb_question(female_base = 3)),
    composite_results = sb_composite(), banner_info = sb_banner(),
    config = list(min_reporting_base = 10), composite_defs = sb_comp_defs())
  vals <- out[["Gender::Female"]][out$RowType != "SectionHeader"]
  expect_true(all(vals == "n<10"))
  expect_false(any(vals %in% c("6.9", "62", "70")))
})

# ==============================================================================
# M-K — the composite's disclosure gate judges on the composite's OWN base
# ==============================================================================
#
# Production review 2026-08, M-K (PLAUSIBLE at the time; reproduced here). The
# gate used to borrow the FIRST source question's bases. Composites do share
# their sources' respondent pool, but sources can be routed differently — one
# asked of everyone, another of a sub-audience — so the borrowed base could name
# the wrong column as sub-k. Both directions are wrong: withholding a column that
# is safe, and publishing one that should have been withheld. The composite now
# carries its own per-column bases (the people with a scoreable composite value,
# the same base its finite population correction reads) and the gate uses them.

context("summary_builder: composite disclosure uses its own bases (M-K)")

sb_comp_with_bases <- function(bases) {
  out <- sb_composite()
  out$ENGAGE$bases <- bases
  out
}

sb_bases <- function(total, male, female) {
  list("TOTAL::Total"   = list(unweighted = total),
       "Gender::Male"   = list(unweighted = male),
       "Gender::Female" = list(unweighted = female))
}

test_that("the composite's own base withholds the column that is really sub-k", {
  # The composite reaches only 4 women; the borrowed source question reached 50.
  out <- extract_composite_rows(
    sb_comp_with_bases(sb_bases(100, 50, 4)), sb_banner(), sb_comp_defs(),
    list(min_reporting_base = 10),
    results_list = list(Q1 = sb_question(female_base = 50)))
  expect_equal(out[["Gender::Female"]], "n<10")
  expect_equal(out[["Gender::Male"]], 75)     # safe column untouched
})

test_that("a safe composite column is NOT withheld because a source was thin", {
  # The mirror error: the source question was routed to 3 women, the composite
  # covers 60. Borrowing the source's base withheld a column with 60 people in it.
  out <- extract_composite_rows(
    sb_comp_with_bases(sb_bases(200, 100, 60)), sb_banner(), sb_comp_defs(),
    list(min_reporting_base = 10),
    results_list = list(Q1 = sb_question(female_base = 3)))
  expect_equal(out[["Gender::Female"]], 70)   # published, as it should be
  expect_false(any(unlist(out[SB_KEYS]) == "n<10", na.rm = TRUE))
})

test_that("a composite carrying no bases still falls back to the source's", {
  # Back-compatibility: a result built before the composite carried its own.
  out <- extract_composite_rows(
    sb_composite(), sb_banner(), sb_comp_defs(),
    list(min_reporting_base = 10),
    results_list = list(Q1 = sb_question(female_base = 3)))
  expect_equal(out[["Gender::Female"]], "n<10")
})

test_that("with no threshold set nothing is withheld either way", {
  out <- extract_composite_rows(
    sb_comp_with_bases(sb_bases(100, 50, 4)), sb_banner(), sb_comp_defs(), list(),
    results_list = list(Q1 = sb_question()))
  expect_equal(out[["Gender::Female"]], 70)
})
