# ==============================================================================
# TABS MODULE — QUALITATIVE SELF-CONTAINED ASSEMBLY TESTS
# ==============================================================================
#
# Known-answer tests for qual_assemble.R: respondent union by ID, banner curation
# (frequency-gated), first-non-NA-wins demographic fill, and the no-demographics
# (SACS-style, Total-only) case. Fixtures are literal classified-question lists
# matching the reader's output shape.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_assemble.R")
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
  stop("Could not locate Turas root for sourcing qual_assemble.R")
}

source(file.path(detect_turas_root(), "modules/tabs/lib/qual_assemble.R"))

# ---- Fixture builders (shape mirrors qual_classify_sheet output) -------------

mk_demos <- function(...) {                    # roles$demos: list of list(col, label)
  lapply(c(...), function(l) list(col = NA_integer_, label = l))
}
mk_q <- function(demo_labels, records) {
  list(roles = list(demos = mk_demos(demo_labels)), records = records)
}
mk_rec <- function(id, demos = list()) list(id = id, demos = demos)

by_idx <- function(master, idx) {
  for (r in master$respondents) if (identical(r$idx, idx)) return(r)
  NULL
}
dim_values <- function(master, label) {
  for (d in master$banner_dims) if (identical(d$label, label)) return(d$values)
  NULL
}

# ==============================================================================
# Multi-sheet union + frequency-curated banners
# ==============================================================================

# Campus appears in all 3 sheets, Channel in 2, OrdersChannel in 1 (a per-question
# grid). With 3 sheets the threshold is ceil(0.5 * 3) = 2, so Campus + Channel are
# banners and OrdersChannel is dropped.
questions_multi <- list(
  mk_q(c("Campus", "Channel"), list(
    mk_rec("1", list(Campus = "JHB", Channel = "A")),
    mk_rec("2", list(Campus = "CPT", Channel = "B")))),
  mk_q(c("Campus", "Channel"), list(
    mk_rec("2", list(Campus = "CPT", Channel = "B")),
    mk_rec("3", list(Campus = "JHB", Channel = "A")))),
  mk_q(c("Campus", "OrdersChannel"), list(
    mk_rec("1", list(Campus = "JHB", OrdersChannel = "X")),
    mk_rec("3", list(Campus = "JHB", OrdersChannel = "Y")),
    mk_rec("4", list(Campus = "JHB", OrdersChannel = "Z"))))
)

test_that("respondents are unioned by ID with a stable 0-based index", {
  master <- qual_build_respondent_master(questions_multi)
  expect_equal(master$n, 4L)                              # ids 1,2,3,4 unioned
  expect_equal(master$ids, c("1", "2", "3", "4"))         # numeric-aware sort
  expect_equal(by_idx(master, 0L)$id, "1")
  expect_equal(by_idx(master, 3L)$id, "4")
})

test_that("banner curation keeps workbook-wide cuts, drops per-question grids", {
  master <- qual_build_respondent_master(questions_multi)
  labels <- vapply(master$banner_dims, function(d) d$label, character(1))
  expect_equal(labels, c("Campus", "Channel"))            # OrdersChannel (1 sheet) dropped
  expect_equal(dim_values(master, "Campus"), c("CPT", "JHB"))
  expect_equal(dim_values(master, "Channel"), c("A", "B"))
})

test_that("demographic fill is cross-sheet and first-non-NA-wins; absent cut stays NA", {
  master <- qual_build_respondent_master(questions_multi)
  r1 <- by_idx(master, 0L)                                # id 1: Channel only in sheet 1
  expect_equal(r1$demos$Campus, "JHB")
  expect_equal(r1$demos$Channel, "A")                     # carried from sheet 1, not lost in sheet 3
  r4 <- by_idx(master, 3L)                                # id 4: only in sheet 3 (no Channel column)
  expect_equal(r4$demos$Campus, "JHB")
  expect_true(is.na(r4$demos$Channel))
})

# ==============================================================================
# Single-question workbook: every demographic qualifies (threshold = 1)
# ==============================================================================

test_that("a one-question workbook keeps all its demographics as banners", {
  one <- list(mk_q(c("Region"), list(
    mk_rec("1", list(Region = "North")), mk_rec("2", list(Region = "South")))))
  master <- qual_build_respondent_master(one)
  expect_equal(vapply(master$banner_dims, function(d) d$label, character(1)), "Region")
  expect_equal(dim_values(master, "Region"), c("North", "South"))
})

# ==============================================================================
# SACS-style: no demographics anywhere -> Total-only (no banner dimensions)
# ==============================================================================

test_that("a no-demographics workbook yields an empty banner (Total-only)", {
  anon <- list(
    mk_q(character(0), list(mk_rec("6"), mk_rec("8"))),
    mk_q(character(0), list(mk_rec("8"), mk_rec("9")))
  )
  master <- qual_build_respondent_master(anon)
  expect_equal(master$n, 3L)                              # 6, 8, 9 unioned
  expect_equal(length(master$banner_dims), 0L)
  expect_length(by_idx(master, 0L)$demos, 0L)
})
