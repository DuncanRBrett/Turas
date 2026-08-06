# ==============================================================================
# TABS MODULE — QUALITATIVE ISLAND FIXTURE (drift gate)
# ==============================================================================
#
# The JS half of the qualitative gate reads a COMMITTED island JSON so that it
# exercises the record shape R actually emits (production review 2026-08, I12a —
# the main qual JS suite ran on a pre-I20 shape with no `rid` on any of its 86
# fixture records, and the rekey suite had rids but no band / suppressed / demos).
#
# A committed fixture is only worth having if it cannot go stale. This file
# rebuilds the island in memory through the real builder on every run and
# compares it to the JSON on disk, so a deliberate change to
# qual_island_builder.R fails here until the fixture is regenerated:
#
#   Rscript modules/tabs/tests/fixtures/qual_island/generate_qual_island.R
#
# It also asserts, in R, that the fixture still carries every field it exists to
# carry — a fixture that quietly lost its `rid`s would leave the JS suite testing
# the legacy path again while looking green.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_island_fixture.R")
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
  stop("Could not locate Turas root for the qualitative island fixture")
}

qif_root <- detect_turas_root()
qif_dir <- file.path(qif_root, "modules/tabs/tests/fixtures/qual_island")
qif_json <- file.path(qif_dir, "qual_island.json")

# Sourcing the generator defines qual_fixture_island() without writing anything
# (the write is guarded by sys.nframe()).
source(file.path(qif_dir, "generate_qual_island.R"))

# ==============================================================================
# The committed JSON still matches what the builder produces
# ==============================================================================

context("qual island fixture: drift gate (I12a)")

test_that("the committed island JSON is what the real builder produces today", {
  expect_true(file.exists(qif_json))
  on_disk <- jsonlite::fromJSON(qif_json, simplifyVector = FALSE)
  rebuilt <- jsonlite::fromJSON(
    jsonlite::toJSON(qual_fixture_island(qif_root), auto_unbox = TRUE,
                     null = "null", na = "null", digits = NA),
    simplifyVector = FALSE)
  # Compared as parsed JSON, not as text, so pretty-printing is not the subject.
  expect_equal(on_disk, rebuilt,
               info = paste("The island builder changed shape. Regenerate with:",
                            "Rscript modules/tabs/tests/fixtures/qual_island/generate_qual_island.R"))
})

# ==============================================================================
# The fixture still carries the fields it exists to carry
# ==============================================================================

context("qual island fixture: the production shape (I12a)")

qif_island <- jsonlite::fromJSON(qif_json, simplifyVector = FALSE)
qif_records <- unlist(lapply(qif_island$questions, function(q) q$records),
                      recursive = FALSE)

test_that("every record carries a stable rid — the whole point of the fixture", {
  rids <- vapply(qif_records, function(r) {
    if (is.null(r$rid)) NA_character_ else as.character(r$rid)
  }, character(1))
  expect_false(any(is.na(rids)))
  expect_true(all(grepl("^[0-9a-f]{16}$", rids)))
})

test_that("one respondent appears in both questions under the SAME rid", {
  # Marks on two different comments by one person must not collide, and must not
  # be given two identities either.
  q1 <- qif_island$questions[[1]]$records
  q2 <- qif_island$questions[[2]]$records
  expect_equal(q1[[1]]$rid, q2[[1]]$rid)
  expect_equal(q1[[1]]$idx, q2[[1]]$idx)
})

test_that("the split-bearing question carries bands, and the plain one does not", {
  q1 <- qif_island$questions[[1]]
  q2 <- qif_island$questions[[2]]
  expect_equal(q1$split$dim, "NPS")
  expect_equal(unlist(q1$split$bands), c("Detractor", "Passive", "Promoter"))
  expect_true(all(vapply(q1$records, function(r) !is.null(r$band), logical(1))))
  expect_null(q2$split)
  expect_true(all(vapply(q2$records, function(r) is.null(r$band), logical(1))))
})

test_that("withheld comments carry suppressed = TRUE and no text; shown ones carry text", {
  sup <- Filter(function(r) isTRUE(r$suppressed), qif_records)
  shown <- Filter(function(r) !isTRUE(r$suppressed), qif_records)
  expect_equal(length(sup), 3)      # two tier-0 under "noteworthy" scope + one hide-marked
  expect_true(all(vapply(sup, function(r) is.null(r$text), logical(1))))
  expect_true(all(vapply(shown, function(r) nzchar(r$text), logical(1))))
})

test_that("a hide-marked comment is withheld even at a shipping tier", {
  # Scope alone would ship it (tier 2 >= 1); the hide marker is what withholds it.
  hidden <- qif_island$questions[[1]]$records[[4]]
  expect_equal(hidden$tier, 2)
  expect_true(isTRUE(hidden$suppressed))
  expect_null(hidden$text)
})

test_that("every record carries both demographic dimensions", {
  expect_equal(vapply(qif_island$demographics, function(d) d$label, character(1)),
               c("Dept", "Tenure"))
  expect_true(all(vapply(qif_records, function(r) {
    !is.null(r$demos) && all(c("Dept", "Tenure") %in% names(r$demos))
  }, logical(1))))
})
