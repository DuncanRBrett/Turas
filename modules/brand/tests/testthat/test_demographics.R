# ==============================================================================
# Tests for resolve_demographic_role / demographic_question_from_role
# ==============================================================================
# Step 3k of the IPK rebuild. The analytical engine
# (run_demographic_question) is data-shape-agnostic and unchanged. What v2
# adds is a role-map-driven resolver so the orchestrator can stop walking
# the legacy QuestionMap sheet.
# ==============================================================================
library(testthat)

.find_root_dem <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_dem()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "11_demographics.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 6 respondents, 1 demographic question (AGE)
# ------------------------------------------------------------------------------

mk_dem_mini_data <- function() {
  data.frame(DEMO_AGE = c(1, 1, 2, 2, 3, 3),
             stringsAsFactors = FALSE)
}

mk_dem_mini_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode = "DEMO_AGE",
      QuestionText = "Age band",
      Variable_Type = "Single_Response",
      Columns = 1L,
      stringsAsFactors = FALSE
    ),
    brands = NULL,
    questionmap = NULL,
    options = data.frame(
      QuestionCode = "DEMO_AGE",
      OptionText   = c("1","2","3"),
      DisplayText  = c("18-34","35-54","55+"),
      DisplayOrder = 1:3,
      ShowInOutput = "Y",
      stringsAsFactors = FALSE
    )
  )
}

mk_dem_mini_role_map <- function(data, structure) {
  bc <- list(categories = data.frame(
    CategoryCode = "DSS", Active = "Y", stringsAsFactors = FALSE
  ))
  build_brand_role_map(structure, bc, data)
}


test_that("v2 inference creates a demographics.age role with column DEMO_AGE", {
  data <- mk_dem_mini_data()
  structure <- mk_dem_mini_structure()
  rm <- mk_dem_mini_role_map(data, structure)
  expect_false(is.null(rm[["demographics.age"]]))
  expect_equal(rm[["demographics.age"]]$column_root, "DEMO_AGE")
})


test_that("resolve_demographic_role returns codes + labels from Options sheet", {
  data <- mk_dem_mini_data()
  structure <- mk_dem_mini_structure()
  rm <- mk_dem_mini_role_map(data, structure)

  spec <- resolve_demographic_role(rm, "demographics.age", structure)
  expect_false(is.null(spec))
  expect_equal(spec$column, "DEMO_AGE")
  expect_equal(spec$codes,  c("1","2","3"))
  expect_equal(spec$labels, c("18-34","35-54","55+"))
})


test_that("demographic_question_from_role returns the panel-record shape", {
  data <- mk_dem_mini_data()
  structure <- mk_dem_mini_structure()
  rm <- mk_dem_mini_role_map(data, structure)

  q <- demographic_question_from_role(data, rm, "demographics.age",
                                          structure)
  expect_false(is.null(q))
  expect_equal(q$role,   "demographics.age")
  expect_equal(q$column, "DEMO_AGE")
  expect_false(q$is_synthetic)
  expect_equal(q$result$status, "PASS")

  # Hand-calc: 2/6 = 33.3% in each age band.
  expect_equal(q$result$total$Pct,  c(33.3, 33.3, 33.3))
  expect_equal(q$result$total$n,    c(2L, 2L, 2L))
  expect_equal(q$result$n_total,    6L)
})


test_that("missing role / missing column / missing options return NULL", {
  data <- mk_dem_mini_data()
  structure <- mk_dem_mini_structure()
  rm <- mk_dem_mini_role_map(data, structure)

  # Role not in map
  expect_null(resolve_demographic_role(rm, "demographics.gender", structure))
  # Role exists but column not in data
  rm2 <- rm
  rm2[["demographics.age"]]$column_root <- "DEMO_GENDER"
  expect_null(demographic_question_from_role(data, rm2, "demographics.age",
                                                 structure))
  # Role exists but Options sheet has no rows for this question
  structure_no_opts <- structure
  structure_no_opts$options <- structure$options[
    structure$options$QuestionCode == "OTHER", ]
  expect_null(resolve_demographic_role(rm, "demographics.age",
                                           structure_no_opts))
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: every DEMO_* role resolves and runs end-to-end", {
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
  brands_all <- openxlsx::read.xlsx(ss_path, sheet = "Brands")
  options    <- openxlsx::read.xlsx(ss_path, sheet = "Options")
  cats       <- openxlsx::read.xlsx(bc_path, sheet = "Categories")

  structure <- list(
    questions = questions, brands = brands_all,
    options = options, questionmap = NULL
  )
  rm <- build_brand_role_map(structure, list(categories = cats), data)

  # Every DEMO_* column in the questions sheet should produce a role.
  demo_qcs <- questions$QuestionCode[grepl("^DEMO_", questions$QuestionCode)]
  expect_gt(length(demo_qcs), 0L)
  expected_roles <- paste0("demographics.", tolower(sub("^DEMO_", "", demo_qcs)))
  for (role in expected_roles) {
    expect_false(is.null(rm[[role]]),
                 info = sprintf("missing role %s", role))
  }

  # End-to-end: every DEMO_* role produces a PASS question record with
  # percentages summing to ~100 across its options.
  for (role in expected_roles) {
    q <- demographic_question_from_role(data, rm, role, structure)
    expect_false(is.null(q),
                 info = sprintf("question record NULL for role %s", role))
    expect_equal(q$result$status, "PASS",
                 info = sprintf("REFUSED for role %s", role))
    expect_equal(sum(q$result$total$Pct, na.rm = TRUE), 100,
                 tolerance = 0.5,
                 info = sprintf("pct sum != 100 for role %s", role))
  }
})


# ==============================================================================
# .demo_brand_nonbuyer_cut — buyer-vs-non-buyer demographic profile
# ==============================================================================
# Hand-computed fixture:
#   6 respondents, 1 demographic question with 2 options ("A", "B"), 2 brands.
#
#  resp | demo  pen[,X]  pen[,Y]
#   1   |  A     1        1
#   2   |  A     1        0
#   3   |  B     1        0
#   4   |  A     0        1
#   5   |  B     0        0
#   6   |  B     0        0
#
#  Brand X buyers      = {1, 2, 3}      -> A: 2/3, B: 1/3   (66.7 / 33.3)
#  Brand X non-buyers  = {4, 5, 6}      -> A: 1/3, B: 2/3   (33.3 / 66.7)
#  Brand Y buyers      = {1, 4}         -> A: 2/2, B: 0/2   (100  /  0  )
#  Brand Y non-buyers  = {2, 3, 5, 6}   -> A: 1/4, B: 3/4   (25   / 75  )
#
# Gap (buyer - non-buyer) per option lets us tell at-a-glance which brand is
# over/under-weighted on which option: Brand X over-weights A by +33pp;
# Brand Y over-weights A by +75pp; both are A-skewed brands, Y more sharply.

mk_bnbc_fixture <- function() {
  list(
    values       = c("A", "A", "B", "A", "B", "B"),
    codes        = c("A", "B"),
    pen_mat      = matrix(c(1, 1, 1, 0, 0, 0,
                            1, 0, 0, 1, 0, 0),
                          nrow = 6, ncol = 2,
                          dimnames = list(NULL, c("X", "Y"))),
    brand_codes  = c("X", "Y"),
    brand_labels = c("Brand X", "Brand Y"),
    w            = rep(1, 6),
    conf_level   = 0.95
  )
}


test_that(".demo_brand_nonbuyer_cut produces hand-calculated distributions", {
  fx <- mk_bnbc_fixture()
  out <- .demo_brand_nonbuyer_cut(
    fx$values, fx$codes, fx$pen_mat,
    fx$brand_codes, fx$brand_labels, fx$w, fx$conf_level)

  expect_equal(nrow(out), 2L)
  expect_equal(out$BrandCode, c("X", "Y"))
  expect_equal(out$Base_n,    c(3L, 4L))
  expect_equal(round(out$Pct_A, 1), c(33.3, 25.0))
  expect_equal(round(out$Pct_B, 1), c(66.7, 75.0))
})


test_that(".demo_brand_cut and .demo_brand_nonbuyer_cut are complementary", {
  # When every respondent is either a buyer OR a non-buyer of brand B
  # (no NA in pen_mat[,B]), buyer base + non-buyer base = total rows.
  fx <- mk_bnbc_fixture()
  buyers    <- .demo_brand_cut(fx$values, fx$codes, fx$pen_mat,
                                fx$brand_codes, fx$brand_labels,
                                fx$w, fx$conf_level)
  nonbuyers <- .demo_brand_nonbuyer_cut(fx$values, fx$codes, fx$pen_mat,
                                         fx$brand_codes, fx$brand_labels,
                                         fx$w, fx$conf_level)
  expect_equal(buyers$Base_n + nonbuyers$Base_n,
               rep(length(fx$values), length(fx$brand_codes)))
})


test_that(".demo_brand_nonbuyer_cut excludes NA pen rows from the base", {
  # NA pen entries are routing skips — neither buyer nor non-buyer.
  fx <- mk_bnbc_fixture()
  fx$pen_mat[5, "X"] <- NA  # respondent 5 not asked about X
  fx$pen_mat[5, "Y"] <- NA
  out <- .demo_brand_nonbuyer_cut(
    fx$values, fx$codes, fx$pen_mat,
    fx$brand_codes, fx$brand_labels, fx$w, fx$conf_level)
  # Brand X non-buyers were {4, 5, 6}; now {4, 6} = 2 respondents.
  # Brand Y non-buyers were {2, 3, 5, 6}; now {2, 3, 6} = 3 respondents.
  expect_equal(out$Base_n, c(2L, 3L))
})


test_that(".demo_brand_nonbuyer_cut returns NULL on invalid inputs", {
  expect_null(.demo_brand_nonbuyer_cut("A", "A", NULL,
                                        "X", "X", 1, 0.95))
  expect_null(.demo_brand_nonbuyer_cut(c("A","B"), c("A","B"),
                                        matrix(0, 2, 1), c("X","Y"),
                                        c("X","Y"), c(1,1), 0.95))
})


test_that("run_demographic_question returns brand_nonbuyer_cut alongside brand_cut", {
  fx <- mk_bnbc_fixture()
  res <- run_demographic_question(
    values        = fx$values,
    option_codes  = fx$codes,
    option_labels = fx$codes,
    pen_mat       = fx$pen_mat,
    brand_codes   = fx$brand_codes,
    brand_labels  = fx$brand_labels)
  expect_equal(res$status, "PASS")
  expect_false(is.null(res$brand_cut))
  expect_false(is.null(res$brand_nonbuyer_cut))
  expect_equal(nrow(res$brand_cut), nrow(res$brand_nonbuyer_cut))
  expect_equal(res$brand_cut$BrandCode, res$brand_nonbuyer_cut$BrandCode)
})


test_that(".demo_resolve_question_text humanises role tails when QuestionText is NA", {
  # Direct unit tests for the fallback rule. Used to be %||% which only
  # caught NULL, not NA; the result was literal "NA" rendering in panel chips.
  expect_equal(.demo_resolve_question_text(NA_character_,
                                            "demographics.age", "AGE"),
               "Age")
  expect_equal(.demo_resolve_question_text(NA_character_,
                                            "demographics.region", "Region"),
               "Region")
  # Multi-word roles via snake_case
  expect_equal(.demo_resolve_question_text(NA_character_,
                                            "demographics.household_income",
                                            "HHI"),
               "Household Income")
  # Explicit QuestionText wins when present and non-blank
  expect_equal(.demo_resolve_question_text("Age band (years)",
                                            "demographics.age", "AGE"),
               "Age band (years)")
  # Blank QuestionText falls through to humanised
  expect_equal(.demo_resolve_question_text("",
                                            "demographics.age", "AGE"),
               "Age")
  expect_equal(.demo_resolve_question_text("   ",
                                            "demographics.age", "AGE"),
               "Age")
})


test_that("resolve_demographic_role returns humanised question_text when Questions sheet has no row", {
  # Simulate the IPK 2026 case: QuestionMap wires demographics.region to
  # column "Region" with no matching Questions sheet row.
  rm <- list(`demographics.region` = list(
    column_root   = "Region",
    question_text = NA_character_,
    option_scale  = "",
    variable_type = "Single_Response"
  ))
  structure <- list(options = data.frame(
    QuestionCode = c("Region", "Region"),
    OptionText   = c("Gauteng Metro", "Cape Town Metro"),
    DisplayText  = c("Gauteng Metro", "Cape Town Metro"),
    DisplayOrder = 1:2,
    ShowInOutput = "Y",
    stringsAsFactors = FALSE
  ))
  spec <- resolve_demographic_role(rm, "demographics.region", structure)
  expect_false(is.null(spec))
  expect_equal(spec$question_text, "Region")
  expect_equal(spec$short_label,   "Region")
})


test_that(".demo_brand_buyer_penetration: pct in each cell is the brand's penetration within that demographic option", {
  # 8 respondents, 2 options ("A","B"), 2 brands (X, Y).
  #
  #  resp | demo  pen[,X]  pen[,Y]
  #   1   |  A     1        1
  #   2   |  A     1        0
  #   3   |  A     0        1
  #   4   |  A     0        0
  #   5   |  B     1        1
  #   6   |  B     1        0
  #   7   |  B     0        0
  #   8   |  B     0        0
  #
  # Option A has 4 respondents.  Of those, 2 buy X (= 50%), 2 buy Y (= 50%).
  # Option B has 4 respondents.  Of those, 2 buy X (= 50%), 1 buys Y (= 25%).
  values <- c("A","A","A","A","B","B","B","B")
  codes  <- c("A","B")
  pen    <- matrix(c(1,1,0,0,1,1,0,0,
                     1,0,1,0,1,0,0,0),
                   nrow = 8, ncol = 2,
                   dimnames = list(NULL, c("X","Y")))
  w <- rep(1, 8)

  out <- .demo_brand_buyer_penetration(values, codes, pen,
                                        c("X","Y"), c("X","Y"),
                                        w, conf_level = 0.95)

  expect_equal(nrow(out), 2L)
  expect_equal(out$BrandCode, c("X","Y"))
  expect_equal(round(out$Pct_A, 1), c(50, 50))
  expect_equal(round(out$Pct_B, 1), c(50, 25))
  # Base_n for each option (demographic size) is reported on every brand row.
  expect_equal(out$Base_n_A, c(4L, 4L))
  expect_equal(out$Base_n_B, c(4L, 4L))
})


test_that(".demo_brand_buyer_penetration: NA pen excluded from numerator AND denominator", {
  # NA pen = routing skip. Cell base must drop those respondents so the
  # buyer + non-buyer complement still sums to 100% within the known base.
  values <- c("A","A","A","A")
  pen    <- matrix(c(1, 0, NA, 1), nrow = 4, ncol = 1,
                   dimnames = list(NULL, "X"))
  w <- rep(1, 4)
  out <- .demo_brand_buyer_penetration(values, "A", pen, "X", "X",
                                        w, conf_level = 0.95)
  # Known base for X in option A = 3 (resp 3 dropped). Buyers = 2.  Pct = 66.7%.
  expect_equal(round(out$Pct_A, 1), 66.7)
  expect_equal(out$Base_n_A, 3L)
})


test_that(".demo_brand_total_penetration: returns each brand's cat-wide penetration", {
  values <- c("A","A","A","A","B","B","B","B")
  pen    <- matrix(c(1,1,0,0,1,1,0,0,
                     1,0,1,0,1,0,0,0),
                   nrow = 8, ncol = 2,
                   dimnames = list(NULL, c("X","Y")))
  w <- rep(1, 8)
  out <- .demo_brand_total_penetration(pen, c("X","Y"), c("X","Y"), w)
  # Brand X: 4 of 8 buy = 50%.
  # Brand Y: 3 of 8 buy = 37.5%.
  expect_equal(out$BrandCode, c("X","Y"))
  expect_equal(round(out$Pct_Total, 1), c(50.0, 37.5))
  expect_equal(out$Base_n, c(8L, 8L))
})


test_that(".demo_brand_total_penetration: NA pen excluded from base", {
  pen <- matrix(c(1, 0, NA, 1), nrow = 4, ncol = 1,
                dimnames = list(NULL, "X"))
  w <- rep(1, 4)
  out <- .demo_brand_total_penetration(pen, "X", "X", w)
  expect_equal(round(out$Pct_Total, 1), 66.7)
  expect_equal(out$Base_n, 3L)
})


test_that("run_demographic_question returns brand_penetration_long + brand_total_penetration", {
  values <- c("A","A","A","A","B","B","B","B")
  pen    <- matrix(c(1,1,0,0,1,1,0,0,
                     1,0,1,0,1,0,0,0),
                   nrow = 8, ncol = 2,
                   dimnames = list(NULL, c("X","Y")))
  res <- run_demographic_question(
    values        = values,
    option_codes  = c("A","B"),
    option_labels = c("A","B"),
    pen_mat       = pen,
    brand_codes   = c("X","Y"),
    brand_labels  = c("X","Y"))
  expect_equal(res$status, "PASS")
  expect_false(is.null(res$brand_penetration_long))
  expect_false(is.null(res$brand_total_penetration))
  expect_equal(res$brand_penetration_long$BrandCode, c("X","Y"))
  expect_equal(round(res$brand_penetration_long$Pct_A, 1), c(50, 50))
  expect_equal(round(res$brand_penetration_long$Pct_B, 1), c(50, 25))
  expect_equal(round(res$brand_total_penetration$Pct_Total, 1), c(50.0, 37.5))
})


test_that("brand_penetration_long preserves Pct_<code> column names with spaces", {
  values <- c("Gauteng Metro", "Gauteng Metro", "W. Cape", "W. Cape")
  pen    <- matrix(c(1, 0, 1, 0), nrow = 4, ncol = 1,
                   dimnames = list(NULL, "BR"))
  out <- .demo_brand_buyer_penetration(values, c("Gauteng Metro", "W. Cape"),
                                        pen, "BR", "BR", rep(1, 4),
                                        conf_level = 0.95)
  expect_true("Pct_Gauteng Metro" %in% names(out))
  expect_true("Pct_W. Cape"       %in% names(out))
})


test_that("brand_cut preserves Pct_<code> column names even when codes contain spaces or punctuation", {
  # Regression: as.data.frame() default name-fixer turned "Pct_Gauteng Metro"
  # into "Pct_Gauteng.Metro", which then silently broke the panel builder's
  # paste0("Pct_", codes) lookup. IPK 2026 demographics (Region, Income)
  # have option codes with spaces and hyphens and need this preserved.
  values <- c("Gauteng Metro", "Gauteng Metro", "W. Cape",
              "Gauteng Metro", "W. Cape", "W. Cape")
  codes  <- c("Gauteng Metro", "W. Cape")
  pen    <- matrix(c(1, 1, 1, 0, 0, 0), nrow = 6, ncol = 1,
                   dimnames = list(NULL, "BR"))
  res <- run_demographic_question(
    values        = values,
    option_codes  = codes,
    option_labels = codes,
    pen_mat       = pen,
    brand_codes   = "BR",
    brand_labels  = "BR")
  expect_true("Pct_Gauteng Metro" %in% names(res$brand_cut))
  expect_true("Pct_W. Cape"      %in% names(res$brand_cut))
  # And the values must be retrievable via the literal column name.
  expect_equal(res$brand_cut[["Pct_Gauteng Metro"]], 66.7,  tolerance = 0.1)
  expect_equal(res$brand_nonbuyer_cut[["Pct_W. Cape"]], 66.7, tolerance = 0.1)
})
