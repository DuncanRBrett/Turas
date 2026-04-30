# ==============================================================================
# Tests for run_drivers_barriers_v2 (Drivers & Barriers migration)
# ==============================================================================
# Step 3g of the IPK rebuild. Verifies that run_drivers_barriers_v2() builds
# the CEP linkage tensor, CEP x brand matrix, and focal-brand buyer flag
# from a v2 role map, then runs the existing analytical pipeline
# (differential importance, IxP quadrants, competitive advantage)
# unchanged.
# ==============================================================================
library(testthat)

.find_root_db <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_db()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map_v2.R"))
source(file.path(ROOT, "modules", "brand", "R", "02_mental_availability.R"))
source(file.path(ROOT, "modules", "brand", "R", "06_drivers_barriers.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 8 respondents, 2 CEPs, 3 brands
# ------------------------------------------------------------------------------
# BRANDPEN2_DSS slots — target-window buyers (the buyer flag):
#   r1: IPK            r5: IPK, ROB
#   r2: IPK, CART      r6: ROB, CART
#   r3: IPK, ROB       r7: NONE
#   r4: NONE           r8: ROB
# Buyers of IPK: r1, r2, r3, r5  (4 of 8)
# Non-buyers of IPK: r4, r6, r7, r8 (4 of 8)
#
# BRANDATTR_DSS_CEP01 — link CEP01 to brand X:
#   r1: IPK            r5: IPK
#   r2: IPK, ROB       r6: ROB
#   r3: IPK            r7: NONE
#   r4: NONE           r8: NONE
# IPK buyers linking CEP01 to IPK: r1,r2,r3,r5 -> 4 of 4 = 100%
# IPK non-buyers linking CEP01 to IPK: 0 of 4 = 0%
# Differential = 100 - 0 = 100pp
#
# BRANDATTR_DSS_CEP02 — link CEP02 to brand X:
#   r1: ROB            r5: CART
#   r2: ROB            r6: CART
#   r3: ROB            r7: NONE
#   r4: NONE           r8: NONE
# IPK buyers linking CEP02 to IPK: 0 of 4 = 0
# IPK non-buyers linking CEP02 to IPK: 0 of 4 = 0
# Differential = 0
# ------------------------------------------------------------------------------

mk_db_mini_data <- function() {
  data.frame(
    BRANDPEN2_DSS_1 = c("IPK","IPK","IPK","NONE","IPK","ROB","NONE","ROB"),
    BRANDPEN2_DSS_2 = c(NA,   "CART","ROB",NA,   "ROB","CART",NA,    NA),

    BRANDATTR_DSS_CEP01_1 = c("IPK","IPK","IPK","NONE","IPK","ROB","NONE","NONE"),
    BRANDATTR_DSS_CEP01_2 = c(NA,   "ROB",NA,   NA,    NA,   NA,   NA,    NA),

    BRANDATTR_DSS_CEP02_1 = c("ROB","ROB","ROB","NONE","CART","CART","NONE","NONE"),

    Focal_Category = "DSS",
    stringsAsFactors = FALSE
  )
}

mk_db_mini_role_map <- function(data) {
  questions <- data.frame(
    QuestionCode = c("BRANDPEN2_DSS",
                     "BRANDATTR_DSS_CEP01",
                     "BRANDATTR_DSS_CEP02"),
    QuestionText = "Q",
    Variable_Type = "Multi_Mention",
    Columns = c(2L, 2L, 1L),
    stringsAsFactors = FALSE
  )
  brands <- data.frame(
    Category = "DSS", CategoryCode = "DSS",
    BrandCode = c("IPK","ROB","CART"),
    BrandLabel = c("IPK","ROB","CART"),
    DisplayOrder = 1:3, IsFocal = c("Y","N","N"),
    stringsAsFactors = FALSE
  )
  bc <- list(categories = data.frame(
    CategoryCode = "DSS", Active = "Y", stringsAsFactors = FALSE
  ))
  build_brand_role_map(
    list(questions = questions, brands = brands, questionmap = NULL),
    bc, data)
}


test_that("run_drivers_barriers_v2 reproduces hand-calculated CEP01 differential", {
  data <- mk_db_mini_data()
  rm <- mk_db_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_drivers_barriers_v2(data, rm, "DSS", brands,
                                  focal_brand = "IPK")

  expect_equal(out$status, "PASS")
  expect_equal(out$metrics_summary$n_buyers,    4L)
  expect_equal(out$metrics_summary$n_nonbuyers, 4L)
  expect_equal(out$metrics_summary$n_ceps,      2L)
  expect_equal(out$metrics_summary$focal_brand, "IPK")

  imp <- out$importance
  cep01 <- imp[imp$Code == "CEP01", , drop = FALSE]
  expect_equal(cep01$Buyer_Pct,    100)
  expect_equal(cep01$NonBuyer_Pct, 0)
  expect_equal(cep01$Differential, 100)

  cep02 <- imp[imp$Code == "CEP02", , drop = FALSE]
  expect_equal(cep02$Differential, 0)
})


test_that("run_drivers_barriers_v2 produces IxP quadrants and competitive advantage", {
  data <- mk_db_mini_data()
  rm <- mk_db_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_drivers_barriers_v2(data, rm, "DSS", brands,
                                  focal_brand = "IPK")
  expect_false(is.null(out$ixp_quadrants))
  expect_true("Quadrant" %in% names(out$ixp_quadrants))
  expect_false(is.null(out$competitive_advantage))
  expect_true(all(c("Code","Focal_Pct","Leader_Brand","Leader_Pct",
                    "Gap_pp","Focal_Leads") %in%
                  names(out$competitive_advantage)))
})


test_that("missing focal_brand or pen role refuses with structured error", {
  data <- mk_db_mini_data()
  rm <- mk_db_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out_no_focal <- run_drivers_barriers_v2(data, rm, "DSS", brands,
                                           focal_brand = NULL)
  expect_equal(out_no_focal$status, "REFUSED")
  expect_equal(out_no_focal$code, "CFG_FOCAL_MISSING")

  rm2 <- rm
  rm2[["funnel.penetration_target.DSS"]] <- NULL
  out_no_pen <- run_drivers_barriers_v2(data, rm2, "DSS", brands,
                                         focal_brand = "IPK")
  expect_equal(out_no_pen$status, "REFUSED")
  expect_equal(out_no_pen$code, "CFG_ROLE_MISSING")
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: run_drivers_barriers_v2 returns valid IxP quadrants", {
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
  ceps_all   <- openxlsx::read.xlsx(ss_path, sheet = "CEPs")
  cats       <- openxlsx::read.xlsx(bc_path, sheet = "Categories")

  dss        <- data[!is.na(data$Focal_Category) & data$Focal_Category == "DSS", ]
  dss_brands <- brands_all[brands_all$CategoryCode == "DSS", ]
  dss_ceps   <- ceps_all[ceps_all$CategoryCode == "DSS", ]

  rm <- build_brand_role_map(
    list(questions = questions, brands = brands_all, questionmap = NULL),
    list(categories = cats),
    dss
  )

  out <- run_drivers_barriers_v2(
    dss, rm, "DSS", dss_brands, focal_brand = "IPK",
    cep_labels = data.frame(CEPCode = dss_ceps$CEPCode,
                            CEPText = dss_ceps$CEPText,
                            stringsAsFactors = FALSE))
  expect_equal(out$status, "PASS")

  expect_equal(nrow(out$importance), 15L)
  expect_true(all(c("Code","Buyer_Pct","NonBuyer_Pct","Differential") %in%
                  names(out$importance)))

  # Every row must end up in one of the four IxP quadrants.
  expect_true(all(out$ixp_quadrants$Quadrant %in%
                  c("Maintain","Strengthen","Monitor","Deprioritise")))

  # Competitive advantage block well-formed.
  ca <- out$competitive_advantage
  expect_equal(nrow(ca), 15L)
  expect_true(all(ca$Focal_Pct >= 0 & ca$Focal_Pct <= 100))
  expect_true(all(ca$Leader_Pct >= 0 & ca$Leader_Pct <= 100))
  expect_true(all(ca$Leader_Brand %in% dss_brands$BrandCode))
})
