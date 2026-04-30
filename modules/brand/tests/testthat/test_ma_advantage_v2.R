# ==============================================================================
# Tests for Mental Advantage end-to-end through the v2 pipeline
# ==============================================================================
# Step 3d of the IPK rebuild — Mental Advantage. The MA analytics
# (02b_mental_advantage.R) and the panel-data shaper (02b_ma_advantage_data.R)
# both consume tensors / ma_result lists rather than raw data, so they need
# no migration. What this test file proves is that the full chain
#
#   build_cep_linkage_v2()  ->  run_mental_availability()  ->
#   build_ma_advantage_block()
#
# returns a structurally valid panel block when fed slot-indexed
# parser-shape data.
# ==============================================================================

library(testthat)

.find_root_ma_adv <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_ma_adv()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map_v2.R"))
source(file.path(ROOT, "modules", "brand", "R", "02_mental_availability.R"))
source(file.path(ROOT, "modules", "brand", "R", "02b_mental_advantage.R"))
source(file.path(ROOT, "modules", "brand", "R", "02b_ma_advantage_data.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 6 respondents, 2 CEPs, 3 brands
# ------------------------------------------------------------------------------
# Linkage tensor (resp x cep) — designed so IPK has clear defend on CEP01,
# build on CEP02; ROB has the inverse; CART is balanced/maintain.
#
#   Resp  CEP01 picks         CEP02 picks
#    1    {IPK, CART}         {ROB}
#    2    {IPK, ROB}          {ROB}
#    3    {IPK}               {ROB, CART}
#    4    {IPK}               {CART}
#    5    {ROB}               {IPK}
#    6    {NONE}              {IPK, CART}
#
# Counts (stim x brand):
#       IPK ROB CART
# CEP01  4   2   1     row=7
# CEP02  2   3   3     row=8
# col    6   5   4     grand=15
#
# expected[CEP01, IPK] = 7*6/15 = 2.8
# advantage[CEP01, IPK] = (4 - 2.8) / 6 * 100 = 20.0pp -> defend (>=5)
# expected[CEP02, IPK] = 8*6/15 = 3.2
# advantage[CEP02, IPK] = (2 - 3.2) / 6 * 100 = -20.0pp -> build (<= -5)
# ------------------------------------------------------------------------------

mk_adv_mini_data <- function() {
  data.frame(
    BRANDATTR_DSS_CEP01_1 = c("IPK",  "IPK",  "IPK",  "IPK", "ROB",  "NONE"),
    BRANDATTR_DSS_CEP01_2 = c("CART", "ROB",  NA,     NA,    NA,     NA),
    BRANDATTR_DSS_CEP02_1 = c("ROB",  "ROB",  "ROB",  "CART","IPK",  "IPK"),
    BRANDATTR_DSS_CEP02_2 = c(NA,     NA,     "CART", NA,    NA,     "CART"),
    Focal_Category = "DSS",
    stringsAsFactors = FALSE
  )
}

mk_adv_mini_role_map <- function(data) {
  questions <- data.frame(
    QuestionCode = c("BRANDATTR_DSS_CEP01", "BRANDATTR_DSS_CEP02"),
    QuestionText = "Q",
    Variable_Type = "Multi_Mention",
    Columns = 2L,
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


test_that("hand-coded fixture: build_ma_advantage_block produces correct decisions", {
  data <- mk_adv_mini_data()
  rm <- mk_adv_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK", "ROB", "CART"),
                       BrandLabel = c("IPK", "ROB", "CART"),
                       stringsAsFactors = FALSE)

  cep_link <- build_cep_linkage_v2(data, rm, "DSS", brands, item_kind = "cep")

  # Sanity: the v2 builder built the expected counts.
  cep_counts_ipk <- colSums(cep_link$linkage_tensor$IPK)
  expect_equal(unname(cep_counts_ipk["CEP01"]), 4L)
  expect_equal(unname(cep_counts_ipk["CEP02"]), 2L)

  ma_result <- run_mental_availability(
    linkage      = cep_link,
    cep_labels   = data.frame(CEPCode = c("CEP01","CEP02"),
                              CEPText = c("First stim","Second stim"),
                              stringsAsFactors = FALSE),
    focal_brand  = "IPK",
    weights      = NULL,
    run_cep_turf = FALSE)

  expect_true(ma_result$status %in% c("PASS","PARTIAL"))
  expect_false(is.null(ma_result$cep_advantage))
  expect_equal(ma_result$cep_advantage$status, "PASS")
  expect_equal(ma_result$cep_advantage$grand_total, 15)
  expect_equal(unname(ma_result$cep_advantage$advantage["CEP01","IPK"]), 20,
               tolerance = 0.01)
  expect_equal(unname(ma_result$cep_advantage$advantage["CEP02","IPK"]), -20,
               tolerance = 0.01)

  block <- build_ma_advantage_block(
    ma_result,
    brand_codes = c("IPK","ROB","CART"),
    brand_names = c("IPK","ROB","CART"),
    cep_list    = data.frame(CEPCode = c("CEP01","CEP02"),
                              CEPText = c("First stim","Second stim"),
                              stringsAsFactors = FALSE),
    focal_code  = "IPK")

  expect_false(is.null(block))
  expect_equal(block$available_stims, "ceps")
  expect_equal(block$ceps$brand_codes, c("IPK","ROB","CART"))
  expect_equal(block$ceps$codes, c("CEP01","CEP02"))
  expect_equal(length(block$ceps$cells), 6)  # 2 stim x 3 brand

  # Focal summary: IPK defends CEP01, builds CEP02 -> 1 defend, 1 build.
  fs <- block$ceps$focal_summary
  expect_equal(fs$counts$defend, 1L)
  expect_equal(fs$counts$build,  1L)
  expect_equal(fs$counts$maintain, 0L)
  expect_equal(fs$defend[[1]]$stim_code, "CEP01")
  expect_equal(fs$build[[1]]$stim_code,  "CEP02")
})


test_that("hand-coded fixture: algebraic invariant sum(actual - expected) == 0", {
  data <- mk_adv_mini_data()
  rm <- mk_adv_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK", "ROB", "CART"),
                       BrandLabel = c("IPK", "ROB", "CART"),
                       stringsAsFactors = FALSE)

  cep_link <- build_cep_linkage_v2(data, rm, "DSS", brands, item_kind = "cep")
  ma <- calculate_mental_advantage(cep_link$linkage_tensor,
                                    codes = c("CEP01","CEP02"),
                                    n_respondents = 6)

  # Sum of (actual - expected) is always exactly 0 for a chi-square table.
  expect_equal(sum(ma$actual - ma$expected), 0, tolerance = 1e-9)
  # Sum across each row equals 0 too (row totals match by construction).
  expect_equal(rowSums(ma$actual - ma$expected), c(CEP01 = 0, CEP02 = 0),
               tolerance = 1e-9)
})


# ------------------------------------------------------------------------------
# Integration: full MA pipeline against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: MA advantage block renders for CEPs + attributes", {
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
  attrs_all  <- openxlsx::read.xlsx(ss_path, sheet = "Attributes")
  cats       <- openxlsx::read.xlsx(bc_path, sheet = "Categories")

  dss        <- data[!is.na(data$Focal_Category) & data$Focal_Category == "DSS", ]
  dss_brands <- brands_all[brands_all$CategoryCode == "DSS", ]
  dss_ceps   <- ceps_all[ceps_all$CategoryCode == "DSS", ]
  dss_attrs  <- attrs_all[attrs_all$CategoryCode == "DSS", ]

  rm <- build_brand_role_map(
    list(questions = questions, brands = brands_all, questionmap = NULL),
    list(categories = cats),
    dss
  )

  cep_link <- build_cep_linkage_v2(dss, rm, "DSS", dss_brands, item_kind = "cep")
  att_link <- build_cep_linkage_v2(dss, rm, "DSS", dss_brands, item_kind = "attr")

  ma_result <- run_mental_availability(
    linkage           = cep_link,
    cep_labels        = data.frame(CEPCode = dss_ceps$CEPCode,
                                    CEPText = dss_ceps$CEPText,
                                    stringsAsFactors = FALSE),
    focal_brand       = "IPK",
    weights           = NULL,
    run_cep_turf      = FALSE,
    attribute_linkage = att_link,
    attribute_labels  = data.frame(AttrCode = dss_attrs$AttrCode,
                                    AttrText = dss_attrs$AttrText,
                                    stringsAsFactors = FALSE)
  )

  expect_true(ma_result$status %in% c("PASS","PARTIAL"))
  expect_false(is.null(ma_result$cep_advantage))
  expect_false(is.null(ma_result$attribute_advantage))

  # Both advantage matrices should obey the algebraic invariant.
  expect_equal(sum(ma_result$cep_advantage$actual -
                    ma_result$cep_advantage$expected), 0, tolerance = 1e-6)
  expect_equal(sum(ma_result$attribute_advantage$actual -
                    ma_result$attribute_advantage$expected), 0, tolerance = 1e-6)

  # Build the panel block.
  block <- build_ma_advantage_block(
    ma_result,
    brand_codes    = dss_brands$BrandCode,
    brand_names    = dss_brands$BrandLabel,
    cep_list       = data.frame(CEPCode = dss_ceps$CEPCode,
                                CEPText = dss_ceps$CEPText,
                                stringsAsFactors = FALSE),
    attribute_list = data.frame(AttrCode = dss_attrs$AttrCode,
                                AttrText = dss_attrs$AttrText,
                                stringsAsFactors = FALSE),
    focal_code     = "IPK")

  expect_false(is.null(block))
  expect_equal(block$available_stims, c("ceps","attributes"))
  expect_equal(block$default_stim, "ceps")
  expect_equal(block$threshold_pp, MA_DEFAULT_THRESHOLD_PP)

  # CEPs block: 15 codes, 15 brands, 225 cells.
  expect_equal(length(block$ceps$codes), nrow(dss_ceps))
  expect_equal(length(block$ceps$brand_codes), nrow(dss_brands))
  expect_equal(length(block$ceps$cells),
               nrow(dss_ceps) * nrow(dss_brands))
  # Every cell carries the contract fields.
  c1 <- block$ceps$cells[[1]]
  expect_true(all(c("stim_code","brand_code","ma","expected","actual",
                    "std_residual","is_sig","decision",
                    "pct_total","pct_aware") %in% names(c1)))

  # Attributes block: 15 codes, 15 brands, 225 cells.
  expect_equal(length(block$attributes$codes), nrow(dss_attrs))
  expect_equal(length(block$attributes$cells),
               nrow(dss_attrs) * nrow(dss_brands))

  # Focal summary classifies every CEP for IPK into exactly one bucket.
  fs <- block$ceps$focal_summary
  total_cls <- fs$counts$defend + fs$counts$build + fs$counts$maintain
  na_cells <- sum(vapply(
    Filter(function(c) c$brand_code == "IPK", block$ceps$cells),
    function(c) is.na(c$ma), logical(1)))
  expect_equal(total_cls + na_cells, nrow(dss_ceps))

  # The synthetic fixture deliberately balances CEP linkage across brands so
  # every cell stays within ~4pp of expected — at the default +/-5pp threshold
  # focal IPK lands entirely in "maintain", which is the correct, defensible
  # outcome. Re-run the focal-summary classifier with a 1pp threshold to
  # exercise the defend / build branches.
  block_sensitive <- build_ma_advantage_block(
    list(cep_advantage = local({
           a <- ma_result$cep_advantage
           a$threshold_pp <- 1
           a$decision[] <- ifelse(is.na(a$advantage), "na",
                                   ifelse(a$advantage >=  1, "defend",
                                          ifelse(a$advantage <= -1, "build",
                                                 "maintain")))
           a
         }),
         attribute_advantage    = NULL,
         cep_brand_matrix       = ma_result$cep_brand_matrix,
         attribute_brand_matrix = NULL),
    brand_codes    = dss_brands$BrandCode,
    brand_names    = dss_brands$BrandLabel,
    cep_list       = data.frame(CEPCode = dss_ceps$CEPCode,
                                CEPText = dss_ceps$CEPText,
                                stringsAsFactors = FALSE),
    focal_code     = "IPK")
  fs1 <- block_sensitive$ceps$focal_summary
  expect_gt(fs1$counts$defend + fs1$counts$build, 0L)
})
