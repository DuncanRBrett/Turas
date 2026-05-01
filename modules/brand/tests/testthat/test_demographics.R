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
