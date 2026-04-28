# ==============================================================================
# Tests for the brand ad hoc element (run_adhoc_question + helpers)
# ==============================================================================
library(testthat)

source(file.path("..", "..", "R", "11_demographics.R"))
source(file.path("..", "..", "R", "11a_demographics_panel_data.R"))
source(file.path("..", "..", "R", "12_adhoc.R"))
source(file.path("..", "..", "R", "12a_adhoc_panel_data.R"))


# ------------------------------------------------------------------------------
# Single_Response ad hoc — uses supplied option list
# ------------------------------------------------------------------------------

test_that("run_adhoc_question handles Single_Response with option list", {
  res <- run_adhoc_question(
    values        = c(rep("1", 6), rep("2", 4)),
    option_codes  = c("1", "2"),
    option_labels = c("Yes", "No"),
    variable_type = "Single_Response"
  )
  expect_equal(res$status, "PASS")
  expect_equal(res$total$Pct, c(60, 40))
  expect_equal(res$variable_type, "Single_Response")
})

test_that("run_adhoc_question buckets numeric values into quartiles", {
  set.seed(7)
  vals <- c(0:10, 1:10)  # 21 values, range 0-10
  res <- run_adhoc_question(
    values        = vals,
    option_codes  = NULL,
    option_labels = NULL,
    variable_type = "Numeric"
  )
  expect_equal(res$status, "PASS")
  expect_true(nrow(res$total) <= 4L)  # quartile bins (or fewer with ties)
  expect_true(all(res$total$n > 0L))  # all bins populated
  expect_false(is.null(res$bin_edges))
})

test_that("run_adhoc_question keeps small numeric universes as discrete codes", {
  res <- run_adhoc_question(
    values        = c(rep(1, 5), rep(2, 5)),
    option_codes  = NULL,
    option_labels = NULL,
    variable_type = "Numeric"
  )
  expect_equal(res$status, "PASS")
  expect_equal(nrow(res$total), 2L)
  expect_equal(res$total$Pct, c(50, 50))
})

test_that("run_adhoc_question refuses missing options on non-numeric types", {
  res <- run_adhoc_question(
    values        = c("1", "2"),
    option_codes  = NULL,
    option_labels = NULL,
    variable_type = "Single_Response"
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_NO_OPTIONS")
})

test_that("run_adhoc_question produces brand_cut when pen matrix is supplied", {
  pen <- matrix(c(rep(1L, 50), rep(0L, 50),
                  rep(0L, 50), rep(1L, 50)), ncol = 2L)
  colnames(pen) <- c("BR_A", "BR_B")
  res <- run_adhoc_question(
    values        = c(rep("Y", 50), rep("N", 50)),
    option_codes  = c("Y", "N"),
    option_labels = c("Yes", "No"),
    pen_mat       = pen,
    brand_codes   = c("BR_A", "BR_B")
  )
  expect_equal(res$status, "PASS")
  expect_false(is.null(res$brand_cut))
  expect_equal(nrow(res$brand_cut), 2L)
})


# ------------------------------------------------------------------------------
# Role + scope resolution
# ------------------------------------------------------------------------------

test_that("resolve_adhoc_role parses ALL scope", {
  structure <- list(
    questionmap = data.frame(
      Role = "adhoc.nps.ALL", ClientCode = "ADHOC_NPS",
      QuestionText = "NPS", QuestionTextShort = "NPS",
      Variable_Type = "Numeric",
      ColumnPattern = "{code}", OptionMapScale = "",
      stringsAsFactors = FALSE),
    options = NULL, optionmap = NULL
  )
  spec <- resolve_adhoc_role(structure, "adhoc.nps.ALL")
  expect_equal(spec$column, "ADHOC_NPS")
  expect_equal(spec$scope, "ALL")
  expect_equal(spec$variable_type, "Numeric")
})

test_that("resolve_adhoc_role parses category scope", {
  structure <- list(
    questionmap = data.frame(
      Role = "adhoc.future_intent.DSS", ClientCode = "ADHOC_FUTURE_DSS",
      QuestionText = "Future intent", QuestionTextShort = "Future intent",
      Variable_Type = "Single_Response",
      ColumnPattern = "{code}", OptionMapScale = "future_intent_scale",
      stringsAsFactors = FALSE),
    options = NULL,
    optionmap = data.frame(
      Scale = rep("future_intent_scale", 2),
      ClientCode  = c("1", "2"),
      ClientLabel = c("Definitely", "Probably"),
      OrderIndex  = 1:2,
      stringsAsFactors = FALSE)
  )
  spec <- resolve_adhoc_role(structure, "adhoc.future_intent.DSS")
  expect_equal(spec$scope, "DSS")
  expect_equal(spec$codes, c("1", "2"))
})


# ------------------------------------------------------------------------------
# Panel data assembly
# ------------------------------------------------------------------------------

test_that("build_adhoc_panel_data groups by scope (ALL first)", {
  res <- run_adhoc_question(values = c("1","2","1"),
                             option_codes = c("1","2"),
                             option_labels = c("A","B"))
  pd <- build_adhoc_panel_data(questions = list(
    list(role="adhoc.x.DSS", column="X", scope="DSS",
         question_text="X?", short_label="X",
         variable_type="Single_Response",
         codes=c("1","2"), labels=c("A","B"),
         brand_codes=character(0), brand_labels=character(0),
         n_scope_base = 3L, result=res),
    list(role="adhoc.y.ALL", column="Y", scope="ALL",
         question_text="Y?", short_label="Y",
         variable_type="Single_Response",
         codes=c("1","2"), labels=c("A","B"),
         brand_codes=character(0), brand_labels=character(0),
         n_scope_base = 3L, result=res)
  ))
  expect_equal(pd$meta$status, "PASS")
  expect_equal(length(pd$scopes), 2L)
  # ALL must always come first
  expect_equal(pd$scopes[[1]]$scope_code, "ALL")
  expect_equal(pd$scopes[[2]]$scope_code, "DSS")
})
