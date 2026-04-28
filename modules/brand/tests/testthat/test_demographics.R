# ==============================================================================
# Tests for the brand demographics element (run_demographic_question + helpers)
# ==============================================================================
library(testthat)

source(file.path("..", "..", "R", "11_demographics.R"))
source(file.path("..", "..", "R", "11a_demographics_panel_data.R"))


# ------------------------------------------------------------------------------
# .demo_wilson_ci — known-answer test against textbook example.
# Wilson 95% CI for p = 0.5, n = 100 should be approximately [0.404, 0.596].
# ------------------------------------------------------------------------------

test_that("Wilson CI matches textbook value (p=0.5, n=100)", {
  ci <- .demo_wilson_ci(0.5, 100, conf_level = 0.95)
  expect_equal(ci$lower, 0.404, tolerance = 0.01)
  expect_equal(ci$upper, 0.596, tolerance = 0.01)
})

test_that("Wilson CI handles edge cases", {
  expect_equal(.demo_wilson_ci(NA, 10), list(lower = NA_real_, upper = NA_real_))
  expect_equal(.demo_wilson_ci(0.5, 0),  list(lower = NA_real_, upper = NA_real_))
  ci <- .demo_wilson_ci(1.0, 50)
  expect_lte(ci$upper, 1)
  expect_gte(ci$lower, 0)
})


# ------------------------------------------------------------------------------
# Distribution engine — known input -> verifiable percentages.
# ------------------------------------------------------------------------------

test_that("run_demographic_question computes correct totals", {
  # 4 of each option (1..5) plus 5 NAs
  values <- c(rep("1", 4), rep("2", 4), rep("3", 4), rep("4", 4), rep("5", 4),
              rep(NA_character_, 5))
  res <- run_demographic_question(
    values        = values,
    option_codes  = as.character(1:5),
    option_labels = paste0("Opt", 1:5)
  )
  expect_equal(res$status, "PASS")
  expect_equal(nrow(res$total), 5L)
  expect_equal(res$total$n,   c(4, 4, 4, 4, 4))
  expect_equal(res$total$Pct, c(20, 20, 20, 20, 20))
  # Base = non-NA respondents
  expect_equal(res$total$Base_n[1], 20L)
  expect_equal(res$n_total, 20L)
  expect_equal(res$n_respondents, 25L)
  # CIs must bracket the point estimate
  expect_true(all(res$total$CI_Lower <= res$total$Pct))
  expect_true(all(res$total$CI_Upper >= res$total$Pct))
})

test_that("run_demographic_question respects weights", {
  # 10 respondents — 5 each, but weights make first group count 3x
  values  <- c(rep("1", 5), rep("2", 5))
  weights <- c(rep(3, 5), rep(1, 5))
  res <- run_demographic_question(
    values        = values,
    option_codes  = c("1", "2"),
    option_labels = c("First", "Second"),
    weights       = weights
  )
  # Weighted: 15 / (15 + 5) = 75% for option 1
  expect_equal(res$total$Pct[1], 75)
  expect_equal(res$total$Pct[2], 25)
})

test_that("buyer_cut splits by focal-brand pen vector", {
  values      <- c(rep("1", 10), rep("2", 10))
  focal_buyer <- c(rep(1L, 10), rep(0L, 10))
  res <- run_demographic_question(
    values        = values,
    option_codes  = c("1", "2"),
    option_labels = c("A", "B"),
    focal_buyer   = focal_buyer
  )
  expect_false(is.null(res$buyer_cut))
  # Buyer rows are all option 1 -> 100% in cell 1
  expect_equal(res$buyer_cut$buyer$Pct,     c(100, 0))
  expect_equal(res$buyer_cut$non_buyer$Pct, c(0, 100))
})

test_that("tier_cut respects buyer_tiers labels", {
  values <- c(rep("1", 6), rep("2", 6))
  tiers  <- c(rep("LIGHT", 4), rep("MEDIUM", 4), rep("HEAVY", 4))
  res <- run_demographic_question(
    values        = values,
    option_codes  = c("1", "2"),
    option_labels = c("A", "B"),
    buyer_tiers   = tiers
  )
  expect_false(is.null(res$tier_cut))
  expect_equal(res$tier_cut$light$n,  c(4, 0))   # all light = option 1
  expect_equal(res$tier_cut$heavy$n,  c(0, 4))   # all heavy = option 2
  expect_equal(res$tier_cut$medium$n, c(2, 2))   # split
})

test_that("brand_cut produces brand x option matrix with CIs", {
  set.seed(1)
  n <- 100
  values <- sample(c("1", "2"), n, replace = TRUE)
  pen <- matrix(c(rep(1L, 50), rep(0L, 50),
                  rep(0L, 50), rep(1L, 50)), ncol = 2L)
  colnames(pen) <- c("BR_A", "BR_B")
  res <- run_demographic_question(
    values        = values,
    option_codes  = c("1", "2"),
    option_labels = c("A", "B"),
    pen_mat       = pen,
    brand_codes   = c("BR_A", "BR_B")
  )
  expect_false(is.null(res$brand_cut))
  expect_equal(nrow(res$brand_cut), 2L)
  expect_true(all(c("Pct_1", "Pct_2", "CI_Lower_1", "CI_Upper_1",
                     "Base_n", "BrandCode") %in% names(res$brand_cut)))
})

test_that("guards refuse invalid input", {
  res1 <- run_demographic_question(values = NULL, option_codes = "1",
                                    option_labels = "A")
  expect_equal(res1$status, "REFUSED")
  expect_equal(res1$code, "DATA_NO_INPUT")

  res2 <- run_demographic_question(values = c("1", "2"),
                                    option_codes  = c("1"),
                                    option_labels = c("A", "B"))
  expect_equal(res2$status, "REFUSED")
  expect_equal(res2$code, "CFG_LABELS_LENGTH_MISMATCH")

  res3 <- run_demographic_question(values = c("1", "2"),
                                    option_codes  = c("1", "2"),
                                    option_labels = c("A", "B"),
                                    weights = c(1))
  expect_equal(res3$status, "REFUSED")
  expect_equal(res3$code, "DATA_WEIGHTS_MISMATCH")
})


# ------------------------------------------------------------------------------
# Role + option resolution
# ------------------------------------------------------------------------------

test_that("resolve_demographic_role finds Options-sheet questions", {
  structure <- list(
    questionmap = data.frame(
      Role = "demo.AGE", ClientCode = "AGE",
      QuestionText = "Age group", QuestionTextShort = "Age",
      Variable_Type = "Single_Response",
      ColumnPattern = "{code}", OptionMapScale = "",
      stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = rep("AGE", 3),
      OptionText   = c("1", "2", "3"),
      DisplayText  = c("18-24", "25-34", "35+"),
      DisplayOrder = 1:3,
      ShowInOutput = "Y",
      stringsAsFactors = FALSE),
    optionmap = NULL
  )
  spec <- resolve_demographic_role(structure, "demo.AGE")
  expect_equal(spec$column, "AGE")
  expect_equal(spec$codes,  c("1", "2", "3"))
  expect_equal(spec$labels, c("18-24", "25-34", "35+"))
})

test_that("resolve_demographic_role falls back to OptionMap by Scale", {
  structure <- list(
    questionmap = data.frame(
      Role = "demo.LSM", ClientCode = "LSM",
      QuestionText = "LSM", QuestionTextShort = "LSM",
      Variable_Type = "Single_Response",
      ColumnPattern = "{code}", OptionMapScale = "lsm_scale",
      stringsAsFactors = FALSE),
    options = NULL,
    optionmap = data.frame(
      Scale = rep("lsm_scale", 2),
      ClientCode  = c("6", "7"),
      ClientLabel = c("LSM 6", "LSM 7"),
      OrderIndex  = 1:2,
      stringsAsFactors = FALSE)
  )
  spec <- resolve_demographic_role(structure, "demo.LSM")
  expect_equal(spec$codes, c("6", "7"))
  expect_equal(spec$labels, c("LSM 6", "LSM 7"))
})

test_that("resolve_demographic_role returns NULL when role is missing", {
  structure <- list(questionmap = data.frame(
    Role = "demo.AGE", ClientCode = "AGE",
    Variable_Type = "Single_Response",
    stringsAsFactors = FALSE), options = NULL, optionmap = NULL)
  expect_null(resolve_demographic_role(structure, "demo.GENDER"))
})


# ------------------------------------------------------------------------------
# Panel data assembly
# ------------------------------------------------------------------------------

test_that("build_demographics_panel_data wraps engine output", {
  res <- run_demographic_question(
    values        = sample(c("1","2","3"), 30, replace = TRUE),
    option_codes  = c("1","2","3"),
    option_labels = c("A","B","C")
  )
  pd <- build_demographics_panel_data(
    questions = list(list(role="demo.X", column="X",
                           question_text="X?", short_label="X",
                           variable_type="Single_Response",
                           codes=c("1","2","3"),
                           labels=c("A","B","C"),
                           result=res)),
    focal_brand = "FOC"
  )
  expect_equal(pd$meta$status, "PASS")
  expect_equal(pd$meta$n_questions, 1L)
  expect_equal(length(pd$questions[[1]]$total$rows), 3L)
})

test_that("build_demographics_panel_data drops REFUSED questions and reports them", {
  res_pass <- run_demographic_question(values=c("1","2"), option_codes=c("1","2"),
                                        option_labels=c("A","B"))
  pd <- build_demographics_panel_data(questions = list(
    list(role="demo.X", column="X", question_text="X", short_label="X",
         variable_type="Single_Response", codes=c("1","2"), labels=c("A","B"),
         result=res_pass),
    list(role="demo.Y", column="Y", question_text="Y", short_label="Y",
         variable_type="Single_Response", codes=c("1","2"), labels=c("A","B"),
         result=list(status="REFUSED", code="X", message="bad"))))
  expect_equal(pd$meta$n_questions, 1L)
  expect_equal(pd$meta$n_skipped, 1L)
  expect_equal(pd$meta$skipped_roles, "demo.Y")
})
