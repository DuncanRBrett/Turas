# ==============================================================================
# Tests for run_wom_v2 (WOM migration to slot-indexed + per-brand counts)
# ==============================================================================
# Step 3e of the IPK rebuild. Verifies that the v2 WOM pipeline reads
# the four Multi_Mention mention sets via multi_mention_brand_matrix() and
# the two per-brand count families via single_response_brand_matrix(), and
# returns the same list shape as legacy run_wom().
# ==============================================================================
library(testthat)

.find_root_wom <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_wom()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map_v2.R"))
source(file.path(ROOT, "modules", "brand", "R", "05_wom.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 5 respondents, 3 brands
# ------------------------------------------------------------------------------
# WOM_POS_REC_DSS_*  — heard positive
#   r1: IPK, ROB | r2: IPK | r3: ROB, CART | r4: NONE | r5: IPK, ROB, CART
#   IPK heard pos: r1,r2,r5 -> 3/5 = 60%
#   ROB heard pos: r1,r3,r5 -> 3/5 = 60%
#   CART heard pos: r3,r5  -> 2/5 = 40%
#
# WOM_NEG_REC_DSS_* — heard negative
#   r1: ROB | r2: NONE | r3: NONE | r4: IPK, CART | r5: NONE
#   IPK heard neg: r4 -> 1/5 = 20%
#   ROB heard neg: r1 -> 1/5 = 20%
#   CART heard neg: r4 -> 1/5 = 20%
#
# WOM_POS_SHARE_DSS_* — said positive
#   r1: IPK | r2: NONE | r3: NONE | r4: NONE | r5: IPK, ROB
#   IPK said pos: r1,r5 -> 2/5 = 40%
#   ROB said pos: r5    -> 1/5 = 20%
#   CART said pos: 0    -> 0%
#
# WOM_NEG_SHARE_DSS_* — said negative
#   r1: NONE | r2: NONE | r3: ROB | r4: NONE | r5: NONE
#   IPK said neg: 0
#   ROB said neg: r3 -> 1/5 = 20%
#   CART said neg: 0
#
# WOM_POS_COUNT_DSS_{BRAND} — sharing frequency among sharers
#   IPK: r1=2, r5=4 -> mean 3.0; others NA / 0
#   ROB: r5=1            -> mean 1.0
#   CART: all 0          -> mean 0
#
# WOM_NEG_COUNT_DSS_{BRAND}:
#   ROB: r3=2 -> mean 2.0; others 0
# ------------------------------------------------------------------------------

mk_wom_mini_data <- function() {
  data.frame(
    WOM_POS_REC_DSS_1 = c("IPK", "IPK", "ROB", "NONE", "IPK"),
    WOM_POS_REC_DSS_2 = c("ROB", NA,    "CART", NA,    "ROB"),
    WOM_POS_REC_DSS_3 = c(NA,    NA,    NA,     NA,    "CART"),

    WOM_NEG_REC_DSS_1 = c("ROB", "NONE","NONE","IPK", "NONE"),
    WOM_NEG_REC_DSS_2 = c(NA,    NA,    NA,    "CART",NA),

    WOM_POS_SHARE_DSS_1 = c("IPK","NONE","NONE","NONE","IPK"),
    WOM_POS_SHARE_DSS_2 = c(NA,   NA,    NA,    NA,    "ROB"),

    WOM_NEG_SHARE_DSS_1 = c("NONE","NONE","ROB","NONE","NONE"),

    WOM_POS_COUNT_DSS_IPK  = c(2L,   NA,   NA,   NA,   4L),
    WOM_POS_COUNT_DSS_ROB  = c(NA,   NA,   NA,   NA,   1L),
    WOM_POS_COUNT_DSS_CART = c(NA,   NA,   NA,   NA,   NA),

    WOM_NEG_COUNT_DSS_IPK  = c(NA,   NA,   NA,   NA,   NA),
    WOM_NEG_COUNT_DSS_ROB  = c(NA,   NA,   2L,   NA,   NA),
    WOM_NEG_COUNT_DSS_CART = c(NA,   NA,   NA,   NA,   NA),

    Focal_Category = "DSS",
    stringsAsFactors = FALSE
  )
}

mk_wom_mini_role_map <- function(data) {
  questions <- data.frame(
    QuestionCode = c("WOM_POS_REC_DSS",   "WOM_NEG_REC_DSS",
                     "WOM_POS_SHARE_DSS", "WOM_NEG_SHARE_DSS",
                     "WOM_POS_COUNT_DSS_IPK",  "WOM_POS_COUNT_DSS_ROB",
                     "WOM_POS_COUNT_DSS_CART",
                     "WOM_NEG_COUNT_DSS_IPK",  "WOM_NEG_COUNT_DSS_ROB",
                     "WOM_NEG_COUNT_DSS_CART"),
    QuestionText = "Q",
    Variable_Type = c(rep("Multi_Mention", 4), rep("Single_Response", 6)),
    Columns = c(3L, 2L, 2L, 1L, rep(1L, 6)),
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


test_that("v2 role map infers all six WOM roles for the mini fixture", {
  data <- mk_wom_mini_data()
  rm <- mk_wom_mini_role_map(data)
  expect_false(is.null(rm[["wom.pos_rec.DSS"]]))
  expect_false(is.null(rm[["wom.neg_rec.DSS"]]))
  expect_false(is.null(rm[["wom.pos_share.DSS"]]))
  expect_false(is.null(rm[["wom.neg_share.DSS"]]))
  expect_false(is.null(rm[["wom.pos_count.DSS"]]))
  expect_false(is.null(rm[["wom.neg_count.DSS"]]))
  # Compound per-brand entry should list all three brands as applicable
  expect_setequal(rm[["wom.pos_count.DSS"]]$applicable_brands,
                  c("IPK","ROB","CART"))
})


test_that("run_wom_v2 reproduces hand-calculated mention percentages", {
  data <- mk_wom_mini_data()
  rm <- mk_wom_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_wom_v2(data, rm, "DSS", brands, focal_brand = "IPK")

  expect_equal(out$status, "PASS")
  expect_equal(out$n_respondents, 5L)
  expect_equal(out$n_brands, 3L)

  wm <- out$wom_metrics
  # Heard positive
  expect_equal(wm$ReceivedPos_Pct[wm$BrandCode == "IPK"],  60)
  expect_equal(wm$ReceivedPos_Pct[wm$BrandCode == "ROB"],  60)
  expect_equal(wm$ReceivedPos_Pct[wm$BrandCode == "CART"], 40)
  # Heard negative
  expect_equal(wm$ReceivedNeg_Pct[wm$BrandCode == "IPK"],  20)
  expect_equal(wm$ReceivedNeg_Pct[wm$BrandCode == "ROB"],  20)
  expect_equal(wm$ReceivedNeg_Pct[wm$BrandCode == "CART"], 20)
  # Said positive
  expect_equal(wm$SharedPos_Pct[wm$BrandCode == "IPK"],  40)
  expect_equal(wm$SharedPos_Pct[wm$BrandCode == "ROB"],  20)
  expect_equal(wm$SharedPos_Pct[wm$BrandCode == "CART"],  0)
  # Said negative
  expect_equal(wm$SharedNeg_Pct[wm$BrandCode == "ROB"], 20)
  expect_equal(wm$SharedNeg_Pct[wm$BrandCode == "IPK"],  0)
})


test_that("run_wom_v2 computes frequency means among sharers only", {
  data <- mk_wom_mini_data()
  rm <- mk_wom_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_wom_v2(data, rm, "DSS", brands)
  wm <- out$wom_metrics
  expect_equal(wm$SharedPosFreq_Mean[wm$BrandCode == "IPK"], 3)   # mean(2,4)
  expect_equal(wm$SharedPosFreq_Mean[wm$BrandCode == "ROB"], 1)
  expect_equal(wm$SharedPosFreq_Mean[wm$BrandCode == "CART"], 0)
  expect_equal(wm$SharedNegFreq_Mean[wm$BrandCode == "ROB"], 2)
  expect_equal(wm$SharedNegFreq_Mean[wm$BrandCode == "IPK"], 0)
})


test_that("run_wom_v2 returns the contract net_balance / amplification / summary", {
  data <- mk_wom_mini_data()
  rm <- mk_wom_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_wom_v2(data, rm, "DSS", brands, focal_brand = "IPK")

  nb <- out$net_balance
  expect_equal(nb$Net_Received[nb$BrandCode == "IPK"],  40)  # 60 - 20
  expect_equal(nb$Net_Shared  [nb$BrandCode == "IPK"],  40)  # 40 - 0
  expect_equal(nb$Net_Received[nb$BrandCode == "CART"], 20)  # 40 - 20

  amp <- out$amplification
  # IPK amplification = 40 / 60 = 0.67
  expect_equal(amp$Amplification_Ratio[amp$BrandCode == "IPK"], 0.67,
               tolerance = 0.01)

  ms <- out$metrics_summary
  expect_equal(ms$focal_brand, "IPK")
  expect_equal(ms$focal_net_received, 40)
  expect_equal(ms$most_positive_brand, "IPK")
  expect_false(ms$any_net_negative)
})


test_that("run_wom_v2 honours weights when computing percentages and means", {
  data <- mk_wom_mini_data()
  rm <- mk_wom_mini_role_map(data)
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  # Triple-weight respondent 5 (the only multi-share IPK respondent).
  w <- c(1, 1, 1, 1, 3)
  out <- run_wom_v2(data, rm, "DSS", brands, weights = w)
  # Weighted heard pos for IPK: r1+r2+3*r5 = 1+1+3 = 5; total weight = 7;
  # 5/7 ~= 71.4%
  expect_equal(out$wom_metrics$ReceivedPos_Pct[
    out$wom_metrics$BrandCode == "IPK"], 71.4, tolerance = 0.1)
  # Weighted IPK pos-count mean: 2*1 + 4*3 = 14; weight sum = 4; mean = 3.5
  expect_equal(out$wom_metrics$SharedPosFreq_Mean[
    out$wom_metrics$BrandCode == "IPK"], 3.5, tolerance = 0.01)
})


test_that("missing roles degrade to zero columns rather than refusing", {
  data <- mk_wom_mini_data()
  rm <- mk_wom_mini_role_map(data)
  rm[["wom.neg_rec.DSS"]]   <- NULL
  rm[["wom.neg_count.DSS"]] <- NULL
  brands <- data.frame(BrandCode = c("IPK","ROB","CART"),
                       BrandLabel = c("IPK","ROB","CART"),
                       stringsAsFactors = FALSE)
  out <- run_wom_v2(data, rm, "DSS", brands)
  expect_equal(out$status, "PASS")
  expect_true(all(out$wom_metrics$ReceivedNeg_Pct == 0))
  expect_true(all(out$wom_metrics$SharedNegFreq_Mean == 0))
  # Positives still computed correctly.
  expect_equal(out$wom_metrics$ReceivedPos_Pct[
    out$wom_metrics$BrandCode == "IPK"], 60)
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: run_wom_v2 returns valid metrics for 15 brands", {
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

  expect_false(is.null(rm[["wom.pos_rec.DSS"]]))
  expect_false(is.null(rm[["wom.pos_count.DSS"]]))

  out <- run_wom_v2(dss, rm, "DSS", dss_brands, focal_brand = "IPK")
  expect_equal(out$status, "PASS")
  expect_equal(out$n_brands, nrow(dss_brands))
  expect_equal(out$n_respondents, nrow(dss))

  # All percentages must be in [0,100].
  wm <- out$wom_metrics
  for (col in c("ReceivedPos_Pct","ReceivedNeg_Pct",
                "SharedPos_Pct","SharedNeg_Pct")) {
    expect_true(all(wm[[col]] >= 0 & wm[[col]] <= 100),
                info = col)
  }

  # IPK is focal, intended to dominate the fixture: it should have a
  # non-trivial positive net balance.
  ipk_net <- out$net_balance$Net_Received[
    out$net_balance$BrandCode == "IPK"]
  expect_gt(ipk_net, 0)

  # Frequency means must be non-negative.
  expect_true(all(wm$SharedPosFreq_Mean >= 0))
  expect_true(all(wm$SharedNegFreq_Mean >= 0))
})
