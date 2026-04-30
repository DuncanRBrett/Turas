# ==============================================================================
# Tests for run_repertoire_v2 (Repertoire migration to slot-indexed BRANDPEN2)
# ==============================================================================
# Step 3f of the IPK rebuild. Verifies that run_repertoire_v2() builds
# penetration + frequency matrices from a v2 role map via
# multi_mention_brand_matrix() / slot_paired_numeric_matrix() and passes
# them through to run_repertoire() unchanged.
# ==============================================================================
library(testthat)

.find_root_rep <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_rep()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map_v2.R"))
source(file.path(ROOT, "modules", "brand", "R", "04_repertoire.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 6 respondents, 3 brands
# ------------------------------------------------------------------------------
# BRANDPEN2_DSS slots: target-window buyers
#   r1: IPK, ROB           freq IPK=2, ROB=1
#   r2: IPK                freq IPK=4
#   r3: ROB, CART          freq ROB=2, CART=3
#   r4: IPK, ROB, CART     freq IPK=1, ROB=1, CART=1
#   r5: NONE
#   r6: IPK                freq IPK=5
#
# Penetration matrix (cols: IPK, ROB, CART):
#   r1 1 1 0
#   r2 1 0 0
#   r3 0 1 1
#   r4 1 1 1
#   r5 0 0 0
#   r6 1 0 0
# Brands per buyer: r1=2, r2=1, r3=2, r4=3, r5=0, r6=1.
# Buyers (>=1 brand) = 5; rep_dist Brands_Bought=1: r2, r6 => count=2 (40%);
# Brands_Bought=2: r1, r3 => 2 (40%); Brands_Bought=3+: r4 => 1 (20%).
# Mean repertoire = (2+1+2+3+1)/5 = 1.8
#
# IPK buyers: r1, r2, r4, r6 (4); sole-IPK = r2, r6 => 2/4 = 50%
# Focal IPK overlaps:
#   ROB: r1, r4 of 4 = 50%; CART: r4 of 4 = 25%.
# ------------------------------------------------------------------------------

mk_rep_mini_data <- function() {
  data.frame(
    BRANDPEN2_DSS_1 = c("IPK","IPK","ROB", "IPK","NONE","IPK"),
    BRANDPEN2_DSS_2 = c("ROB", NA,  "CART","ROB", NA,    NA),
    BRANDPEN2_DSS_3 = c(NA,    NA,   NA,   "CART",NA,    NA),

    BRANDPEN3_DSS_1 = c(2L, 4L, 2L, 1L, NA, 5L),
    BRANDPEN3_DSS_2 = c(1L, NA, 3L, 1L, NA, NA),
    BRANDPEN3_DSS_3 = c(NA, NA, NA, 1L, NA, NA),

    Focal_Category = "DSS",
    stringsAsFactors = FALSE
  )
}

mk_rep_mini_role_map <- function(data) {
  questions <- data.frame(
    QuestionCode = c("BRANDPEN2_DSS","BRANDPEN3_DSS"),
    QuestionText = "Q",
    Variable_Type = c("Multi_Mention","Continuous_Sum"),
    Columns = 3L,
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


test_that("v2 inference creates BRANDPEN2 + BRANDPEN3 roles", {
  data <- mk_rep_mini_data()
  rm <- mk_rep_mini_role_map(data)
  expect_false(is.null(rm[["funnel.penetration_target.DSS"]]))
  expect_false(is.null(rm[["funnel.frequency.DSS"]]))
  expect_equal(rm[["funnel.penetration_target.DSS"]]$column_root,
               "BRANDPEN2_DSS")
})


test_that("run_repertoire_v2 reproduces hand-calculated penetration matrix", {
  data <- mk_rep_mini_data()
  rm <- mk_rep_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_repertoire_v2(data, rm, "DSS", brands, focal_brand = "IPK")

  expect_equal(out$status, "PASS")
  expect_equal(out$n_respondents, 6L)
  expect_equal(out$n_buyers, 5L)
  expect_equal(out$mean_repertoire, 1.8, tolerance = 0.01)
})


test_that("run_repertoire_v2 produces the sole-loyalty and overlap profiles", {
  data <- mk_rep_mini_data()
  rm <- mk_rep_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_repertoire_v2(data, rm, "DSS", brands, focal_brand = "IPK")

  sl <- out$sole_loyalty
  expect_equal(sl$Brand_Buyers_n[sl$BrandCode == "IPK"],  4L)
  expect_equal(sl$Brand_Buyers_n[sl$BrandCode == "ROB"],  3L)
  expect_equal(sl$Brand_Buyers_n[sl$BrandCode == "CART"], 2L)
  expect_equal(sl$SoleLoyalty_Pct[sl$BrandCode == "IPK"],  50)
  expect_equal(sl$SoleLoyalty_Pct[sl$BrandCode == "ROB"],   0)
  expect_equal(sl$SoleLoyalty_Pct[sl$BrandCode == "CART"],  0)

  bo <- out$brand_overlap
  expect_equal(bo$Overlap_Pct[bo$BrandCode == "ROB"],  50)
  expect_equal(bo$Overlap_Pct[bo$BrandCode == "CART"], 25)
})


test_that("run_repertoire_v2 builds the frequency matrix and SoR", {
  data <- mk_rep_mini_data()
  rm <- mk_rep_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_repertoire_v2(data, rm, "DSS", brands, focal_brand = "IPK")

  expect_false(is.null(out$share_of_requirements))
  # IPK buyers' frequencies (only buyers with at least one purchase counted):
  #   r1: IPK=2, ROB=1, CART=0 -> share IPK = 2/3
  #   r2: IPK=4, others=0      -> share IPK = 4/4 = 1
  #   r4: IPK=1, ROB=1, CART=1 -> share IPK = 1/3
  #   r6: IPK=5, others=0      -> share IPK = 5/5 = 1
  # mean = (2/3 + 1 + 1/3 + 1) / 4 = 3/4 = 75
  ipk_sor <- out$share_of_requirements$SoR_Pct[
    out$share_of_requirements$BrandCode == "IPK"]
  expect_equal(ipk_sor, 75, tolerance = 0.1)
})


test_that("missing penetration role produces a structured refusal", {
  data <- mk_rep_mini_data()
  rm <- mk_rep_mini_role_map(data)
  rm[["funnel.penetration_target.DSS"]] <- NULL
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_repertoire_v2(data, rm, "DSS", brands)
  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CFG_ROLE_MISSING")
})


test_that("missing frequency role still returns penetration + sole loyalty", {
  data <- mk_rep_mini_data()
  rm <- mk_rep_mini_role_map(data)
  rm[["funnel.frequency.DSS"]] <- NULL
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_repertoire_v2(data, rm, "DSS", brands, focal_brand = "IPK")
  expect_equal(out$status, "PASS")
  # Frequency-derived block must be NULL when the frequency role is absent.
  expect_null(out$share_of_requirements)
  # But penetration-driven metrics are still present.
  expect_equal(out$mean_repertoire, 1.8, tolerance = 0.01)
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: run_repertoire_v2 returns valid metrics for 15 brands", {
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
  cats       <- openxlsx::read.xlsx(bc_path, sheet = "Categories")

  dss        <- data[!is.na(data$Focal_Category) & data$Focal_Category == "DSS", ]
  dss_brands <- brands_all[brands_all$CategoryCode == "DSS", ]

  rm <- build_brand_role_map(
    list(questions = questions, brands = brands_all, questionmap = NULL),
    list(categories = cats),
    dss
  )

  out <- run_repertoire_v2(dss, rm, "DSS", dss_brands, focal_brand = "IPK")
  expect_equal(out$status, "PASS")
  expect_equal(out$n_respondents, nrow(dss))
  expect_gt(out$n_buyers, 0L)
  expect_equal(out$n_brands, nrow(dss_brands))

  # Sole-loyalty percentages must be in [0,100] for every brand.
  expect_true(all(out$sole_loyalty$SoleLoyalty_Pct >= 0 &
                  out$sole_loyalty$SoleLoyalty_Pct <= 100))

  # Crossover matrix has self-cells = 100 and is square brands x brands.
  cm <- out$crossover_matrix
  expect_equal(nrow(cm), nrow(dss_brands))
  expect_equal(ncol(cm), nrow(dss_brands) + 1L)  # +1 for BrandCode column
  diag_vals <- vapply(seq_len(nrow(cm)), function(i) {
    bc <- cm$BrandCode[i]
    as.numeric(cm[i, bc])
  }, numeric(1))
  expect_true(all(diag_vals == 100))

  # Duplication-of-Purchase coefficient should be a small positive number
  # for a category that follows Ehrenberg (typically 0.5 - 1.5).
  expect_false(is.null(out$dop_D_coefficient))
  expect_gt(out$dop_D_coefficient, 0)
})
