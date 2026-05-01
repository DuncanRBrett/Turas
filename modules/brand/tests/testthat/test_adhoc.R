# ==============================================================================
# Tests for run_adhoc + resolve_adhoc_role (Ad Hoc placeholder — Step 3l)
# ==============================================================================
# IPK Wave 1 has no ADHOC_* columns, so v2's primary contract is the
# placeholder path: when no adhoc.* roles resolve in scope, return a
# structured PASS-empty payload the panel-data renderer can surface as
# "Data not yet collected for Ad Hoc".
#
# Live path: hand-built role map + 6-respondent fixture exercises the
# scope filter (ALL vs CATCODE), the resolver's option lookup, and the
# delegation to run_adhoc_question() unchanged.
# ==============================================================================
library(testthat)

.find_root_ah <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_ah()

source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "11_demographics.R"))
source(file.path(ROOT, "modules", "brand", "R", "12_adhoc.R"))


# ------------------------------------------------------------------------------
# Placeholder contract — empty role map / wrong-scope role
# ------------------------------------------------------------------------------

test_that("run_adhoc returns PASS-placeholder when role map has no adhoc roles", {
  out <- run_adhoc(
    role_map     = list(),
    structure    = list(),
    data         = data.frame(x = 1:5),
    scope_filter = "ALL"
  )

  expect_equal(out$status, "PASS")
  expect_true(isTRUE(out$placeholder))
  expect_equal(length(out$questions), 0L)
  expect_equal(out$note, ADHOC_PLACEHOLDER_NOTE)
  expect_equal(out$n_roles, 0L)
  expect_equal(out$scope, "ALL")
  expect_equal(out$n_total, 5L)
})


test_that("run_adhoc returns placeholder when no roles match the scope filter", {
  rm <- list(
    "adhoc.nps.DSS" = list(
      role = "adhoc.nps.DSS", column_root = "ADHOC_NPS_DSS",
      variable_type = "Numeric", option_scale = NA_character_,
      question_text = "NPS"
    )
  )
  out <- run_adhoc(rm, structure = list(),
                       data = data.frame(ADHOC_NPS_DSS = 1:5),
                       scope_filter = "ALL")  # role is DSS-scoped, not ALL
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$n_roles, 0L)
  expect_equal(out$scope, "ALL")
})


test_that("run_adhoc returns placeholder when data frame is empty", {
  rm <- list(
    "adhoc.nps.ALL" = list(
      role = "adhoc.nps.ALL", column_root = "ADHOC_NPS",
      variable_type = "Numeric", option_scale = NA_character_,
      question_text = "NPS"
    )
  )
  out <- run_adhoc(rm, structure = list(),
                       data = data.frame(ADHOC_NPS = numeric(0)),
                       scope_filter = "ALL")
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$n_total, 0L)
})


# ------------------------------------------------------------------------------
# resolve_adhoc_role — guard rails
# ------------------------------------------------------------------------------

test_that("resolve_adhoc_role returns NULL for unknown role", {
  expect_null(resolve_adhoc_role(list(), "adhoc.foo.ALL", list()))
  expect_null(resolve_adhoc_role(NULL,   "adhoc.foo.ALL", list()))
  expect_null(resolve_adhoc_role(list(), NA_character_,    list()))
})


test_that("resolve_adhoc_role returns NULL when data column is missing", {
  rm <- list(
    "adhoc.nps.ALL" = list(
      role = "adhoc.nps.ALL", column_root = "ADHOC_NPS",
      variable_type = "Numeric", option_scale = NA_character_,
      question_text = "NPS"
    )
  )
  data <- data.frame(unrelated = 1:5)
  expect_null(resolve_adhoc_role(rm, "adhoc.nps.ALL", list(), data))
})


test_that("resolve_adhoc_role returns spec for numeric role without options", {
  rm <- list(
    "adhoc.nps.ALL" = list(
      role = "adhoc.nps.ALL", column_root = "ADHOC_NPS",
      variable_type = "Numeric", option_scale = NA_character_,
      question_text = "NPS likelihood"
    )
  )
  spec <- resolve_adhoc_role(rm, "adhoc.nps.ALL", list(),
                                  data.frame(ADHOC_NPS = 1:5))
  expect_false(is.null(spec))
  expect_equal(spec$role,          "adhoc.nps.ALL")
  expect_equal(spec$column,        "ADHOC_NPS")
  expect_equal(spec$variable_type, "Numeric")
  expect_equal(spec$scope,         "ALL")
  expect_null(spec$codes)
})


# ------------------------------------------------------------------------------
# Live path: hand-coded mini fixture, scope filter both branches
# ------------------------------------------------------------------------------
# 6 respondents, two adhoc questions:
#   ADHOC_NPS  (sample-wide, Numeric)            — values 1..6
#   ADHOC_FUTURE_DSS (DSS-scoped, Single_Response with codes 1/2/3)
#
# Hand-calc for ALL scope NPS — engine bins to quartiles when n>5 unique
# values, so we expect status PASS with the question record present and
# a 4-row total table. We assert the wrapper plumbing, not engine maths.

mk_ah_data <- function() {
  data.frame(
    ADHOC_NPS         = c(1, 3, 5, 7, 9, 10),
    ADHOC_FUTURE_DSS  = c(1, 1, 2, 2, 3, 1),
    Focal_Category    = c("DSS","DSS","DSS","POS","POS","POS"),
    stringsAsFactors  = FALSE
  )
}

# DSS role uses Numeric here so the test does not depend on an Options sheet
# — the engine bins values automatically. Single_Response handling is tested
# implicitly via the 14_demographics_v2 suite, which shares the option lookup.
mk_ah_role_map <- function() {
  questions <- data.frame(
    QuestionCode  = c("ADHOC_NPS", "ADHOC_FUTURE_DSS"),
    QuestionText  = c("NPS", "Future intent DSS"),
    Variable_Type = c("Numeric", "Numeric"),
    Columns       = c(1L, 1L),
    stringsAsFactors = FALSE
  )
  brands <- data.frame(
    Category = "DSS", CategoryCode = "DSS",
    BrandCode = c("IPK", "ROB"), BrandLabel = c("IPK", "ROB"),
    DisplayOrder = 1:2, IsFocal = c("Y","N"),
    stringsAsFactors = FALSE
  )
  bc <- list(categories = data.frame(
    CategoryCode = c("DSS", "POS"), Active = c("Y", "Y"),
    stringsAsFactors = FALSE
  ))
  build_brand_role_map(
    list(questions = questions, brands = brands, questionmap = NULL),
    bc, data = mk_ah_data())
}


test_that("ALL-scope dispatch resolves only ALL roles", {
  rm <- mk_ah_role_map()
  expect_true("adhoc.nps.ALL"        %in% names(rm))
  expect_true("adhoc.future.DSS"     %in% names(rm))

  out <- run_adhoc(rm, structure = list(), data = mk_ah_data(),
                       scope_filter = "ALL")
  expect_equal(out$status, "PASS")
  expect_false(out$placeholder)
  expect_equal(out$n_roles,  1L)
  expect_equal(out$scope,    "ALL")
  expect_true("adhoc.nps.ALL" %in% names(out$questions))
  rec <- out$questions[["adhoc.nps.ALL"]]
  expect_equal(rec$column,        "ADHOC_NPS")
  expect_equal(rec$variable_type, "Numeric")
  expect_equal(rec$scope,         "ALL")
  expect_equal(rec$result$status, "PASS")
})


test_that("DSS-scope dispatch resolves only DSS roles", {
  rm <- mk_ah_role_map()
  out <- run_adhoc(rm, structure = list(), data = mk_ah_data(),
                       scope_filter = "DSS")
  expect_equal(out$status, "PASS")
  expect_false(out$placeholder)
  expect_equal(out$n_roles, 1L)
  expect_equal(out$scope,   "DSS")
  expect_true("adhoc.future.DSS" %in% names(out$questions))
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture (placeholder expected)
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: run_adhoc returns the placeholder payload (no ADHOC_*)", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  ss_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                       "ipk_wave1", "Survey_Structure.xlsx")
  bc_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                       "ipk_wave1", "Brand_Config.xlsx")
  skip_if_not(all(file.exists(c(data_path, ss_path, bc_path))),
              "IPK Wave 1 fixture not built")

  data       <- openxlsx::read.xlsx(data_path)
  questions  <- openxlsx::read.xlsx(ss_path, sheet = "Questions")
  brands     <- openxlsx::read.xlsx(ss_path, sheet = "Brands")
  bc_cats    <- openxlsx::read.xlsx(bc_path, sheet = "Categories")

  rm <- build_brand_role_map(
    list(questions = questions, brands = brands, questionmap = NULL),
    list(categories = bc_cats), data)

  expect_equal(length(grep("^adhoc\\.", names(rm))), 0L)

  out <- run_adhoc(rm, structure = list(), data = data,
                       scope_filter = "ALL")
  expect_equal(out$status, "PASS")
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$note, ADHOC_PLACEHOLDER_NOTE)
  expect_equal(out$n_total, nrow(data))
})
