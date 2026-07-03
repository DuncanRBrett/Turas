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
