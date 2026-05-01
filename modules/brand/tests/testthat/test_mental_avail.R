# ==============================================================================
# Tests for build_cep_linkage (mental availability migration)
# ==============================================================================
# Verifies that the v2 linkage builder reads slot-indexed BRANDATTR data
# via the role registry + data-access layer and produces the same list
# shape as the legacy build_cep_linkage(), so downstream metrics work
# unchanged.
# ==============================================================================
library(testthat)

.find_root_ma <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_ma()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "02_mental_availability.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 4 respondents, 2 CEPs, 3 brands
# ------------------------------------------------------------------------------
# Resp 1: CEP01 -> {IPK, ROB};            CEP02 -> {IPK}
# Resp 2: CEP01 -> {IPK, CART};           CEP02 -> {NONE}
# Resp 3: CEP01 -> {ROB};                 CEP02 -> {ROB, CART}
# Resp 4: CEP01 -> {NONE};                CEP02 -> {IPK, ROB, CART}
#
# Linkage tensor (resp x cep):
#  IPK:  CEP01 CEP02     ROB:  CEP01 CEP02     CART:  CEP01 CEP02
#  R1   1     1          R1    1     0         R1     0     0
#  R2   1     0          R2    0     0         R2     1     0
#  R3   0     0          R3    1     1         R3     0     1
#  R4   0     1          R4    0     1         R4     0     1
#
# respondent_cep_matrix (any brand picked):
#  R1   1     1
#  R2   1     0
#  R3   1     1
#  R4   0     1
# ------------------------------------------------------------------------------

mk_ma_mini_data <- function() {
  data.frame(
    BRANDATTR_DSS_CEP01_1 = c("IPK",  "IPK",  "ROB",  "NONE"),
    BRANDATTR_DSS_CEP01_2 = c("ROB",  "CART", NA,     NA),
    BRANDATTR_DSS_CEP01_3 = c(NA,     NA,     NA,     NA),
    BRANDATTR_DSS_CEP02_1 = c("IPK",  "NONE", "ROB",  "IPK"),
    BRANDATTR_DSS_CEP02_2 = c(NA,     NA,     "CART", "ROB"),
    BRANDATTR_DSS_CEP02_3 = c(NA,     NA,     NA,     "CART"),
    Focal_Category = "DSS",
    stringsAsFactors = FALSE
  )
}

mk_ma_mini_role_map <- function(data) {
  questions <- data.frame(
    QuestionCode = c("BRANDATTR_DSS_CEP01", "BRANDATTR_DSS_CEP02"),
    QuestionText = "Q",
    Variable_Type = "Multi_Mention",
    Columns = 3L,
    stringsAsFactors = FALSE
  )
  brands <- data.frame(
    Category = "DSS", CategoryCode = "DSS",
    BrandCode = c("IPK", "ROB", "CART"),
    BrandLabel = c("IPK", "ROB", "CART"),
    DisplayOrder = 1:3, IsFocal = c("Y", "N", "N"),
    stringsAsFactors = FALSE
  )
  bc <- list(categories = data.frame(
    CategoryCode = "DSS", Active = "Y", stringsAsFactors = FALSE
  ))
  build_brand_role_map(
    list(questions = questions, brands = brands, questionmap = NULL),
    bc, data)
}

test_that("build_cep_linkage produces hand-calculated linkage tensor", {
  data <- mk_ma_mini_data()
  rm <- mk_ma_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK", "ROB", "CART"),
                       BrandLabel = c("IPK", "ROB", "CART"),
                       stringsAsFactors = FALSE)

  res <- build_cep_linkage(data, rm, "DSS", brands, item_kind = "cep")

  expect_equal(res$cep_codes, c("CEP01", "CEP02"))
  expect_equal(res$brand_codes, c("IPK", "ROB", "CART"))
  expect_equal(res$n_respondents, 4L)

  # IPK linkage matrix
  expect_equal(res$linkage_tensor$IPK[, "CEP01"], c(1L, 1L, 0L, 0L))
  expect_equal(res$linkage_tensor$IPK[, "CEP02"], c(1L, 0L, 0L, 1L))

  # ROB linkage matrix
  expect_equal(res$linkage_tensor$ROB[, "CEP01"], c(1L, 0L, 1L, 0L))
  expect_equal(res$linkage_tensor$ROB[, "CEP02"], c(0L, 0L, 1L, 1L))

  # CART linkage matrix
  expect_equal(res$linkage_tensor$CART[, "CEP01"], c(0L, 1L, 0L, 0L))
  expect_equal(res$linkage_tensor$CART[, "CEP02"], c(0L, 0L, 1L, 1L))

  # Respondent x CEP matrix (any brand picked)
  expect_equal(res$respondent_cep_matrix[, "CEP01"], c(1L, 1L, 1L, 0L))
  expect_equal(res$respondent_cep_matrix[, "CEP02"], c(1L, 0L, 1L, 1L))
})

test_that("downstream MA metrics consume v2 linkage unchanged", {
  data <- mk_ma_mini_data()
  rm <- mk_ma_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK", "ROB", "CART"),
                       BrandLabel = c("IPK", "ROB", "CART"),
                       stringsAsFactors = FALSE)

  res <- build_cep_linkage(data, rm, "DSS", brands, item_kind = "cep")

  # IPK total links across 2 CEPs:
  #   CEP01: IPK linked by resp 1 + 2 = 2
  #   CEP02: IPK linked by resp 1 + 4 = 2  -> 4 total
  # ROB:    CEP01 (r1+r3)=2, CEP02 (r3+r4)=2 -> 4 total
  # CART:   CEP01 (r2)=1, CEP02 (r3+r4)=2 -> 3 total
  mms <- calculate_mms(res$linkage_tensor)
  expect_equal(mms$Total_Links[mms$BrandCode == "IPK"],  4)
  expect_equal(mms$Total_Links[mms$BrandCode == "ROB"],  4)
  expect_equal(mms$Total_Links[mms$BrandCode == "CART"], 3)

  # MPen for IPK: 3 of 4 respondents linked at least one CEP -> 0.75
  mpen <- calculate_mpen(res$linkage_tensor)
  ipk_pen <- mpen$MPen[mpen$BrandCode == "IPK"]
  expect_equal(ipk_pen, 0.75)
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("build_cep_linkage runs against IPK Wave 1 (15 CEPs x 15 brands)", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  ss_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                       "ipk_wave1", "Survey_Structure.xlsx")
  bc_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                       "ipk_wave1", "Brand_Config.xlsx")
  skip_if_not(all(file.exists(c(data_path, ss_path, bc_path))),
              "IPK Wave 1 fixture not built")

  data <- openxlsx::read.xlsx(data_path)
  questions <- openxlsx::read.xlsx(ss_path, sheet = "Questions")
  brands_all <- openxlsx::read.xlsx(ss_path, sheet = "Brands")
  cats <- openxlsx::read.xlsx(bc_path, sheet = "Categories")

  dss <- data[!is.na(data$Focal_Category) & data$Focal_Category == "DSS", ]
  dss_brands <- brands_all[brands_all$CategoryCode == "DSS", ]

  rm <- build_brand_role_map(
    list(questions = questions, brands = brands_all, questionmap = NULL),
    list(categories = cats),
    dss
  )

  # CEP linkage
  cep_link <- build_cep_linkage(dss, rm, "DSS", dss_brands,
                                   item_kind = "cep")
  expect_equal(length(cep_link$cep_codes), 15L)
  expect_equal(length(cep_link$brand_codes), 15L)
  # Each brand's matrix has shape [n_resp x 15]
  expect_equal(dim(cep_link$linkage_tensor$IPK), c(nrow(dss), 15L))
  # IPK should have non-zero linkage on most CEPs (focal brand, high awareness)
  ipk_cep_pcts <- colMeans(cep_link$linkage_tensor$IPK)
  expect_gt(mean(ipk_cep_pcts), 0.05)

  # Attribute linkage
  att_link <- build_cep_linkage(dss, rm, "DSS", dss_brands,
                                   item_kind = "attr")
  expect_equal(length(att_link$cep_codes), 15L)  # 15 attributes in fixture
  expect_true(all(grepl("^ATT", att_link$cep_codes)))

  # Downstream metrics work
  mms <- calculate_mms(cep_link$linkage_tensor)
  expect_equal(nrow(mms), 15L)
  expect_true(all(mms$MMS >= 0 & mms$MMS <= 1))
  # Sum of rounded MMS values is ~1.0 (rounding error tolerance ±0.001)
  expect_equal(sum(mms$MMS), 1.0, tolerance = 0.001)
})
