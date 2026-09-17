# ==============================================================================
# TABS MODULE. COMMENT-EXTRACTS MIGRATION (the proposal rule)
# ==============================================================================
#
# scripts/migrate_comment_extracts.R proposes one extracts row per comment that
# could be quoted beside a theme it does not address. The rule is the whole of the
# script's judgement, and the property it must have is that an unpruned row
# behaves exactly as the report does today.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_migrate_comment_extracts.R")
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
  stop("Could not locate Turas root for the extracts migration tests")
}

mig_root <- detect_turas_root()
source(file.path(mig_root, "modules/tabs/lib/qual_workbook_reader.R"))
source(file.path(mig_root, "scripts/migrate_comment_extracts.R"))   # defines the rule only

mig_sheet <- function() {
  rows <- list(
    c("Why?", NA, NA, NA, NA, NA),
    c("ID", "Noteworthy", "Comment", "Overall Sentiment", "Pay", "Workload"),
    c("1", NA, "about pay and workload", "3", "3", "3"),        # two themes: migrate
    c("2", NA, "only about pay", "3", "3", NA),                 # one theme: leave alone
    c("3", "hide", "-", "3", "3", "3"),                         # hide: no text ships
    c("4", "p", "priority, both themes", "1", "1", "1"),        # tier is irrelevant
    c("5", NA, "-", "2", "1", "1"),                             # a dash is not a comment
    c("6", NA, "", "2", "1", "1")                               # nor is a blank
  )
  width <- max(vapply(rows, length, integer(1)))
  qual_classify_sheet(lapply(rows, function(r) {
    cells <- qual_norm_cells(r); length(cells) <- width
    cells[is.na(cells)] <- ""; cells
  }), "Engagement")
}

test_that("only a comment that ships text AND carries two or more themes is proposed", {
  plan <- migrate_propose_rows(mig_sheet())
  expect_equal(plan$sheet, "Engagement Extracts")
  expect_equal(plan$base, "Engagement")
  ids <- vapply(plan$rows, function(r) r$id, character(1))
  expect_equal(sort(ids), c("1", "4"))
})

test_that("a proposed row carries EVERY coded theme, which is what makes it a no-op", {
  # This is the safety property: unpruned, the row quotes the comment's current text
  # beside every theme it is coded on, which is exactly what the report does today.
  plan <- migrate_propose_rows(mig_sheet())
  row <- Filter(function(r) identical(r$id, "1"), plan$rows)[[1]]
  expect_equal(row$themes, "Pay; Workload")
  expect_equal(row$text, "about pay and workload")
  claim <- qual_parse_theme_claim(row$themes)
  expect_equal(claim$kind, "named")
  expect_equal(claim$labels, c("Pay", "Workload"))
})

test_that("the proposal round-trips through the reader with no problems", {
  q <- mig_sheet()
  plan <- migrate_propose_rows(q)
  entries <- lapply(seq_along(plan$rows), function(i) {
    r <- plan$rows[[i]]
    list(row = i + 1L, id = r$id, claim = qual_parse_theme_claim(r$themes),
         raw_theme = r$themes, text = r$text, lead = FALSE)
  })
  res <- qual_attach_extracts(q, entries, plan$sheet)
  expect_equal(res$problems, character(0))
  expect_equal(res$n_attached, 2L)
  rec <- Filter(function(r) identical(r$id, "1"), res$question$records)[[1]]
  expect_equal(names(rec$extracts), c("Pay", "Workload"))
  expect_true(all(vapply(rec$extracts, identical, logical(1), "about pay and workload")))
})

test_that("a question with no themes proposes nothing", {
  raw <- qual_classify_sheet(list(
    qual_norm_cells(c("ID", "Noteworthy", "Comment")),
    qual_norm_cells(c("1", NA, "a plain open end"))), "Suggestions")
  expect_equal(raw$type, "raw")
  expect_length(migrate_propose_rows(raw)$rows, 0L)
})
