# ==============================================================================
# TABS MODULE - ExcludeFromInsights: the per-question Differences opt-out
# ==============================================================================
#
# DIFFERENCES_TAB_SCOPE.md item 4. A Selection-sheet column that drops ONE
# question from the Differences tab's findings while leaving it in the crosstabs
# — the lever a study needs when several near-duplicate views of one measure
# (Own / Other / Total) each raise their own card.
#
# The declaration crosses five layers, and a break in any one is SILENT (the
# alpha_default / insight_exclude_categories class of defect: registered and
# consumed, never carried). Each link has a gate:
#
#   1. Selection-column carry-through + Y/N canonicalisation, so "Yes" acts and
#      junk refuses rather than quietly meaning "no"  (crosstabs/data_setup.R)
#        -> test_selection_flags.R, "ExcludeFromInsights is carried through..."
#           and "...refuses instead of meaning 'no'"
#   2. Orchestrator extraction, Y -> TRUE  (question_orchestrator.R)
#        -> THIS FILE (nothing else exercises the extraction)
#   3. Data-layer emission, TRUE-only      (data_layer_writer.R)
#        -> test_data_layer_writer.R, "exclude_from_insights ... is TRUE-only"
#   4. Template registration               (generate_config_templates.R)
#        -> test_config_templates.R, "Selection sheet has expected columns"
#   5. The skip itself                     (27d_diffs.js)
#        -> diffs_tests.mjs case 30; and takeout_tests.mjs pins that the
#           Group-overview KeyShare scan deliberately IGNORES the flag.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_exclude_from_insights.R")
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
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign("script_dir", .tabs_lib_dir, envir = globalenv())

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(.tabs_lib_dir, "shared_functions.R"))
source(file.path(.tabs_lib_dir, "excel_utils.R"))
source(file.path(.tabs_lib_dir, "allocation_processor.R"))
source(file.path(.tabs_lib_dir, "weighting.R"))
source(file.path(.tabs_lib_dir, "banner.R"))
source(file.path(.tabs_lib_dir, "banner_indices.R"))
# numeric_processor.R before the orchestrator: the orchestrator reads its
# NUMERIC_RATIO_COLS while routing (see test_allocation_processor.R).
source(file.path(.tabs_lib_dir, "numeric_processor.R"))
source(file.path(.tabs_lib_dir, "question_orchestrator.R"))

# ==============================================================================
# FIXTURES
# ==============================================================================

# The flag is question-type agnostic — it is read from the Selection row, not
# from the data — so the cheapest routed question serves: an Allocation, which
# test_allocation_processor.R already proves runs on this source chain.
efi_data <- function() data.frame(
  BUDGET_1 = c(50, 25, 0, 25),
  BUDGET_2 = c(30, 50, 40, 40),
  BUDGET_3 = c(20, 25, 60, 35),
  stringsAsFactors = FALSE)

efi_structure <- function() list(
  questions = data.frame(
    QuestionCode = "BUDGET", QuestionText = "Budget split",
    Variable_Type = "Allocation", Columns = 3, stringsAsFactors = FALSE),
  options = data.frame(
    QuestionCode = c("BUDGET", "BUDGET", "BUDGET"),
    OptionText   = c("Rent", "Food", "Fun"),
    DisplayText  = c("Rent", "Food", "Fun"),
    ShowInOutput = "Y", stringsAsFactors = FALSE))

efi_config <- function() list(
  decimal_places_numeric = 1, enable_significance_testing = FALSE, verbose = FALSE)

# Run one question through the orchestrator with the given Selection row.
efi_run <- function(...) {
  banner_info <- create_total_only_banner()
  prepared <- prepare_question_data("BUDGET", NA, efi_data(),
                                    efi_structure(), banner_info, rep(1, 4))
  question_row <- data.frame(QuestionCode = "BUDGET", BaseFilter = NA, ...,
                             stringsAsFactors = FALSE)
  process_single_question("BUDGET", prepared, banner_info,
                          efi_config(), FALSE, question_row)
}

# ==============================================================================
# ORCHESTRATOR EXTRACTION
# ==============================================================================

context("ExcludeFromInsights — orchestrator extraction")

test_that("a 'Y' becomes TRUE on the question result", {
  expect_true(isTRUE(efi_run(ExcludeFromInsights = "Y")$exclude_from_insights))
})

test_that("case and surrounding whitespace do not defeat it", {
  # A config read from a workbook arrives already canonicalised to "Y"/"N" by
  # the loader's gate loop, but process_single_question is also called with
  # hand-built question rows, so its own toupper(trimws()) is a second line —
  # tested here because that is the path a caller bypassing the loader takes.
  expect_true(isTRUE(efi_run(ExcludeFromInsights = " y ")$exclude_from_insights))
  expect_true(isTRUE(efi_run(ExcludeFromInsights = "Y ")$exclude_from_insights))
})

test_that("blank, NA, 'N' and an absent column all mean 'can raise findings'", {
  for (v in list("N", "n", "", "  ", NA_character_)) {
    res <- efi_run(ExcludeFromInsights = v)
    expect_false(isTRUE(res$exclude_from_insights),
                 info = paste("value:", if (is.na(v)) "NA" else sprintf("'%s'", v)))
  }
  # A config written before the column existed carries no column at all.
  res <- efi_run()
  expect_false(isTRUE(res$exclude_from_insights))
  expect_false(is.null(res$exclude_from_insights))   # FALSE, never NULL
})

test_that("the flag does not touch the question's own crosstab", {
  # The whole point: the question keeps its table and its bases, and only the
  # Differences tab looks away.
  on_tab  <- efi_run(ExcludeFromInsights = "Y")$table
  off_tab <- efi_run(ExcludeFromInsights = "N")$table
  expect_identical(on_tab, off_tab)
  expect_equal(on_tab$RowLabel, c("Rent", "Food", "Fun"))
})
