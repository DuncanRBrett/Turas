# ==============================================================================
# Tests for run_audience_lens (Audience Lens migration to slot-indexed
# data access + role map v2)
# ==============================================================================
# Step 3m of the IPK rebuild. Verifies that run_audience_lens() and
# compute_al_metrics_for_subset() reproduce hand-calculated KPI values
# off the v2 data-access layer (multi_mention_brand_matrix,
# slot_paired_numeric_matrix, respondent_picked) using a v2 role map built
# by build_brand_role_map().
#
# Hand-coded mini-fixture: 8 respondents x 3 brands (IPK / ROB / CART) for
# category DSS, with hand-calculated targets for every metric on the total
# and on a buyer/non-buyer pair audience.
# ==============================================================================
library(testthat)

.find_root_al2 <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_al2()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "13_audience_lens.R"))
source(file.path(ROOT, "modules", "brand", "R", "13a_al_audiences.R"))
source(file.path(ROOT, "modules", "brand", "R", "13b_al_metrics.R"))
source(file.path(ROOT, "modules", "brand", "R", "13c_al_classify.R"))


# ------------------------------------------------------------------------------
# Mini-fixture builders
# ------------------------------------------------------------------------------

mk_al_mini_data <- function() {
  data.frame(
    # BRANDAWARE_DSS — slot-indexed Multi_Mention
    BRANDAWARE_DSS_1 = c("IPK","IPK","IPK","ROB","IPK", NA,  "ROB","IPK"),
    BRANDAWARE_DSS_2 = c("ROB", NA,  "ROB", NA,  "CART", NA, "CART","ROB"),
    BRANDAWARE_DSS_3 = c(NA,    NA,  "CART", NA,  NA,    NA,  NA,    NA),

    # BRANDATT1_DSS_<brand> — per-brand Single_Response
    BRANDATT1_DSS_IPK  = c(1L, 2L, 3L, 4L, 1L, NA, 5L, 2L),
    BRANDATT1_DSS_ROB  = c(2L, 3L, 1L, 1L, 4L, NA, 2L, 3L),
    BRANDATT1_DSS_CART = c(3L, 4L, 2L, 5L, 1L, NA, 1L, 4L),

    # BRANDPEN2_DSS — slot-indexed buyer codes
    BRANDPEN2_DSS_1 = c("IPK","IPK","ROB", NA,  "IPK", NA,  "CART","IPK"),
    BRANDPEN2_DSS_2 = c("ROB", NA,   NA,   NA,  "CART", NA,  NA,    NA),

    # BRANDPEN3_DSS — slot-paired counts (slot N maps to brand at BRANDPEN2 slot N)
    BRANDPEN3_DSS_1 = c(2,    4,    2,    NA,  1,    NA,  2,     1),
    BRANDPEN3_DSS_2 = c(1,    NA,   NA,   NA,  3,    NA,  NA,    NA),

    # CEP01 — slot-indexed Multi_Mention (which brands link to this CEP)
    BRANDATTR_DSS_CEP01_1 = c("IPK","IPK","ROB", NA,  "IPK", NA, "CART","IPK"),
    BRANDATTR_DSS_CEP01_2 = c("ROB", NA,  NA,    NA,  NA,    NA,  NA,   "ROB"),

    # CEP02 — slot-indexed
    BRANDATTR_DSS_CEP02_1 = c("IPK", NA,  "CART","ROB","CART", NA,  "ROB","IPK"),
    BRANDATTR_DSS_CEP02_2 = c(NA,    NA,   NA,   NA,    NA,   NA,   NA,   NA),

    # WOM mention sets
    WOM_POS_REC_DSS_1   = c("IPK", NA,  "ROB", NA,  "IPK", NA,  "CART","IPK"),
    WOM_NEG_REC_DSS_1   = c(NA,    NA,  "IPK", NA,  NA,    NA,  NA,    "ROB"),
    WOM_POS_SHARE_DSS_1 = c("IPK", NA,   NA,   NA,   NA,   NA,   NA,   "IPK"),
    WOM_NEG_SHARE_DSS_1 = c(NA,    NA,   NA,   NA,   NA,   NA,   NA,    NA),

    # Audience filter helper (1 if respondent bought IPK in target window)
    IS_IPK_BUYER = c(1L, 1L, 0L, 0L, 1L, 0L, 0L, 1L),

    Focal_Category = "DSS",
    stringsAsFactors = FALSE
  )
}

mk_al_mini_role_map <- function(data) {
  questions <- data.frame(
    QuestionCode = c(
      "BRANDAWARE_DSS",
      "BRANDATT1_DSS_IPK", "BRANDATT1_DSS_ROB", "BRANDATT1_DSS_CART",
      "BRANDPEN2_DSS",
      "BRANDPEN3_DSS",
      "BRANDATTR_DSS_CEP01", "BRANDATTR_DSS_CEP02",
      "WOM_POS_REC_DSS",  "WOM_NEG_REC_DSS",
      "WOM_POS_SHARE_DSS","WOM_NEG_SHARE_DSS"
    ),
    QuestionText = "Q",
    Variable_Type = c(
      "Multi_Mention",
      "Single_Response","Single_Response","Single_Response",
      "Multi_Mention",
      "Continuous_Sum",
      "Multi_Mention","Multi_Mention",
      "Multi_Mention","Multi_Mention",
      "Multi_Mention","Multi_Mention"
    ),
    Columns = NA_integer_,
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

mk_al_mini_brands <- function() {
  data.frame(
    BrandCode  = c("IPK","ROB","CART"),
    BrandLabel = c("IPK","ROB","CART"),
    stringsAsFactors = FALSE
  )
}

mk_al_mini_audiences <- function() {
  list(
    list(id = "ipk_buyer",     label = "IPK Buyer",    category = "DSS",
         pair_id = "ipk_buyer_pair", pair_role = "A",
         filter_col = "IS_IPK_BUYER", filter_op = "==", filter_value = "1"),
    list(id = "ipk_non_buyer", label = "IPK Non-buyer", category = "DSS",
         pair_id = "ipk_buyer_pair", pair_role = "B",
         filter_col = "IS_IPK_BUYER", filter_op = "==", filter_value = "0")
  )
}


# ------------------------------------------------------------------------------
# Hand-calculated targets (derived in test_audience_lens design notes)
# ------------------------------------------------------------------------------
# TOTAL (n=8, weights=1):
#   awareness     5/8   = 0.625
#   consideration 4/7   ~ 0.5714  (NA on r6 excluded from base)
#   brand_love    2/7   ~ 0.2857
#   p3m_usage     4/8   = 0.500
#   mpen          4/8   = 0.500
#   network_size  6/8   = 0.750
#   mms           6/14  ~ 0.4286
#   som           6/16  = 0.375
#   net_heard    (3-1)/8 = 0.250
#   net_said      2/8   = 0.250
#   loyalty_scr   8/12  ~ 0.6667
#   purchase_freq 8/4   = 2.000
#   purchase_dist 0.25  (% heavy buyers, top tercile bucket = freq 4)
#
# IPK Buyer audience (r1,r2,r5,r8 — n=4):
#   awareness     4/4   = 1.000
#   consideration 4/4   = 1.000
#   brand_love    2/4   = 0.500
#   p3m_usage     4/4   = 1.000
#   mpen          4/4   = 1.000
#   network_size  6/4   = 1.500
#   mms           6/9   ~ 0.6667
#   som           6/8   = 0.750
#   net_heard     3/4   = 0.750
#   net_said      2/4   = 0.500
#   loyalty_scr   8/12  ~ 0.6667 (same as total — buyer set IS the buyer set)
#   purchase_freq 2.000 (same)
#   purchase_dist 0.250 (same)
#
# IPK Non-buyer audience (r3,r4,r6,r7 — n=4):
#   awareness     1/4   = 0.250
#   consideration 0/3   = 0.000  (NA on r6 excluded)
#   brand_love    0/3   = 0.000
#   p3m_usage     0/4   = 0.000
#   mpen          0/4   = 0.000
#   network_size  0/4   = 0.000
#   mms           0/5   = 0.000
#   som           0/8   = 0.000
#   net_heard    (0-1)/4 = -0.250
#   net_said      0/4   = 0.000
#   loyalty_scr   NA            (no focal-brand buyers in subset)
#   purchase_freq NA
#   purchase_dist NA
# ------------------------------------------------------------------------------


test_that("v2 inference creates every audience-lens role required for DSS", {
  data <- mk_al_mini_data()
  rm <- mk_al_mini_role_map(data)
  expect_false(is.null(rm[["funnel.awareness.DSS"]]))
  expect_false(is.null(rm[["funnel.attitude.DSS"]]))
  expect_false(is.null(rm[["funnel.penetration_target.DSS"]]))
  expect_false(is.null(rm[["funnel.frequency.DSS"]]))
  expect_false(is.null(rm[["mental_avail.cep.DSS.CEP01"]]))
  expect_false(is.null(rm[["mental_avail.cep.DSS.CEP02"]]))
  expect_false(is.null(rm[["wom.pos_rec.DSS"]]))
  expect_false(is.null(rm[["wom.neg_rec.DSS"]]))
  expect_false(is.null(rm[["wom.pos_share.DSS"]]))
  expect_false(is.null(rm[["wom.neg_share.DSS"]]))
})


test_that("compute_al_metrics_for_subset reproduces total-set hand calcs", {
  data <- mk_al_mini_data()
  rm   <- mk_al_mini_role_map(data)
  brands <- mk_al_mini_brands()

  m <- compute_al_metrics_for_subset(
    data = data, role_map = rm, weights = rep(1, 8),
    keep_idx = rep(TRUE, 8),
    cat_brands = brands, cat_code = "DSS",
    focal_brand = "IPK", structure = list(),
    config = list())

  expect_equal(m$awareness$value,     5/8,       tolerance = 1e-6)
  expect_equal(m$awareness$n_base,    8L)
  expect_equal(m$consideration$value, 4/7,       tolerance = 1e-6)
  expect_equal(m$consideration$n_base, 7L)
  expect_equal(m$brand_love$value,    2/7,       tolerance = 1e-6)
  expect_equal(m$p3m_usage$value,     0.5,       tolerance = 1e-6)
  expect_equal(m$mpen$value,          0.5,       tolerance = 1e-6)
  expect_equal(m$network_size$value,  0.75,      tolerance = 1e-6)
  expect_equal(m$mms$value,           6/14,      tolerance = 1e-6)
  expect_equal(m$som$value,           6/16,      tolerance = 1e-6)
  expect_equal(m$net_heard$value,     0.25,      tolerance = 1e-6)
  expect_equal(m$net_said$value,      0.25,      tolerance = 1e-6)
  expect_equal(m$loyalty_scr$value,   8/12,      tolerance = 1e-6)
  expect_true(m$loyalty_scr$n_buyer_base)
  expect_equal(m$purchase_frequency$value, 2.0,  tolerance = 1e-6)
  expect_equal(m$purchase_distribution$value, 0.25, tolerance = 1e-6)
})


test_that("compute_al_metrics_for_subset reproduces IPK-Buyer audience values", {
  data <- mk_al_mini_data()
  rm   <- mk_al_mini_role_map(data)
  brands <- mk_al_mini_brands()
  buyer_idx <- data$IS_IPK_BUYER == 1L

  m <- compute_al_metrics_for_subset(
    data = data, role_map = rm, weights = rep(1, 8),
    keep_idx = buyer_idx,
    cat_brands = brands, cat_code = "DSS",
    focal_brand = "IPK", structure = list(),
    config = list())

  expect_equal(m$awareness$value,     1.0,       tolerance = 1e-6)
  expect_equal(m$consideration$value, 1.0,       tolerance = 1e-6)
  expect_equal(m$brand_love$value,    0.5,       tolerance = 1e-6)
  expect_equal(m$p3m_usage$value,     1.0,       tolerance = 1e-6)
  expect_equal(m$mpen$value,          1.0,       tolerance = 1e-6)
  expect_equal(m$network_size$value,  1.5,       tolerance = 1e-6)
  expect_equal(m$mms$value,           6/9,       tolerance = 1e-6)
  expect_equal(m$som$value,           0.75,      tolerance = 1e-6)
  expect_equal(m$net_heard$value,     0.75,      tolerance = 1e-6)
  expect_equal(m$net_said$value,      0.5,       tolerance = 1e-6)
  expect_equal(m$loyalty_scr$value,   8/12,      tolerance = 1e-6)
  expect_equal(m$purchase_frequency$value, 2.0,  tolerance = 1e-6)
})


test_that("compute_al_metrics_for_subset reproduces IPK-Non-buyer audience values", {
  data <- mk_al_mini_data()
  rm   <- mk_al_mini_role_map(data)
  brands <- mk_al_mini_brands()
  nonbuyer_idx <- data$IS_IPK_BUYER == 0L

  m <- compute_al_metrics_for_subset(
    data = data, role_map = rm, weights = rep(1, 8),
    keep_idx = nonbuyer_idx,
    cat_brands = brands, cat_code = "DSS",
    focal_brand = "IPK", structure = list(),
    config = list())

  expect_equal(m$awareness$value,     0.25,  tolerance = 1e-6)
  expect_equal(m$consideration$value, 0.0,   tolerance = 1e-6)
  expect_equal(m$consideration$n_base, 3L)  # NA on r6 excluded
  expect_equal(m$brand_love$value,    0.0,   tolerance = 1e-6)
  expect_equal(m$p3m_usage$value,     0.0,   tolerance = 1e-6)
  expect_equal(m$mpen$value,          0.0,   tolerance = 1e-6)
  expect_equal(m$network_size$value,  0.0,   tolerance = 1e-6)
  expect_equal(m$mms$value,           0.0,   tolerance = 1e-6)
  expect_equal(m$som$value,           0.0,   tolerance = 1e-6)
  expect_equal(m$net_heard$value,    -0.25,  tolerance = 1e-6)
  expect_equal(m$net_said$value,      0.0,   tolerance = 1e-6)
  # No focal-brand buyers in subset -> loyalty / freq / dist are NA
  expect_true(is.na(m$loyalty_scr$value))
  expect_true(m$loyalty_scr$n_buyer_base)
  expect_true(is.na(m$purchase_frequency$value))
  expect_true(is.na(m$purchase_distribution$value))
})


test_that("run_audience_lens wires up audiences + classifier end-to-end", {
  data <- mk_al_mini_data()
  rm   <- mk_al_mini_role_map(data)
  brands <- mk_al_mini_brands()
  audiences <- mk_al_mini_audiences()

  out <- run_audience_lens(
    data = data, role_map = rm, cat_code = "DSS", cat_name = "Dishwash",
    cat_brands = brands, focal_brand = "IPK", audiences = audiences,
    structure = list(),
    config = list(audience_lens_alpha = 0.10,
                   audience_lens_gap_threshold = 0.10,
                   audience_lens_warn_base = 100L,
                   audience_lens_suppress_base = 1L),
    weights = NULL)

  expect_equal(out$status, "PASS")
  expect_equal(out$meta$engine, "v2")
  expect_equal(out$meta$n_total, 8L)
  expect_equal(out$meta$n_audiences, 2L)
  expect_equal(out$meta$n_rendered, 2L)
  expect_equal(length(out$audiences), 2L)
  expect_equal(length(out$pair_cards), 1L)

  pair <- out$pair_cards[[1]]
  expect_equal(pair$pair_id, "ipk_buyer_pair")
  expect_equal(pair$n_a, 4L)
  expect_equal(pair$n_b, 4L)

  rows <- pair$rows
  # Awareness pair row: A=1.0, B=0.25, total=0.625, gap=+0.75. Sig power
  # at n=4 vs 4 is too low to clear alpha=0.10 (Fisher p~0.143) — that
  # check belongs in test_audience_lens_classifier, not here. We assert
  # the value/delta wiring is correct.
  aw_row <- rows[rows$metric_id == "awareness", ]
  expect_equal(aw_row$value_a, 1.0)
  expect_equal(aw_row$value_b, 0.25)
  expect_equal(aw_row$value_total, 5/8)
  expect_equal(aw_row$delta_ab, 0.75)
  expect_false(is.na(aw_row$sig_p))  # a p-value was computed

  # Loyalty SCR row: buyer-base metric -> B side forced NA, no chip
  scr_row <- rows[rows$metric_id == "loyalty_scr", ]
  expect_true(scr_row$buyer_base)
  expect_true(is.na(scr_row$value_b))
  expect_true(is.na(scr_row$chip))
})


test_that("missing role map produces a structured refusal", {
  data <- mk_al_mini_data()
  brands <- mk_al_mini_brands()
  out <- run_audience_lens(
    data = data, role_map = list(), cat_code = "DSS", cat_name = "Dishwash",
    cat_brands = brands, focal_brand = "IPK",
    audiences = mk_al_mini_audiences(),
    structure = list(), config = list(), weights = NULL)
  expect_equal(out$status, "REFUSED")
  expect_equal(out$code, "CFG_ROLE_MAP_EMPTY")
})


test_that("empty audience list returns PASS with engine=v2 marker", {
  data <- mk_al_mini_data()
  rm   <- mk_al_mini_role_map(data)
  brands <- mk_al_mini_brands()
  out <- run_audience_lens(
    data = data, role_map = rm, cat_code = "DSS", cat_name = "Dishwash",
    cat_brands = brands, focal_brand = "IPK",
    audiences = list(),
    structure = list(), config = list(), weights = NULL)
  expect_equal(out$status, "PASS")
  expect_equal(out$meta$engine, "v2")
  expect_equal(out$meta$n_audiences, 0L)
})


test_that("all-suppressed audiences return PARTIAL with the right code", {
  data <- mk_al_mini_data()
  rm   <- mk_al_mini_role_map(data)
  brands <- mk_al_mini_brands()
  out <- run_audience_lens(
    data = data, role_map = rm, cat_code = "DSS", cat_name = "Dishwash",
    cat_brands = brands, focal_brand = "IPK",
    audiences = mk_al_mini_audiences(),
    structure = list(),
    config = list(audience_lens_suppress_base = 100L),  # well above n=4
    weights = NULL)
  expect_equal(out$status, "PARTIAL")
  expect_equal(out$code, "DATA_ALL_AUDIENCES_SUPPRESSED")
  expect_equal(out$meta$engine, "v2")
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture (no AudienceLens sheet declared
# yet in the fixture — verify graceful behaviour on the empty-audiences path).
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: run_audience_lens returns PASS with no audiences", {
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

  # Total-set metrics on the real fixture must compute without error and
  # return values in plausible ranges for every percentage-style metric.
  m <- compute_al_metrics_for_subset(
    data = dss, role_map = rm, weights = rep(1, nrow(dss)),
    keep_idx = rep(TRUE, nrow(dss)),
    cat_brands = dss_brands, cat_code = "DSS",
    focal_brand = "IPK", structure = list(),
    config = list())

  expect_true(!is.na(m$awareness$value) &&
                m$awareness$value >= 0 && m$awareness$value <= 1)
  expect_true(!is.na(m$p3m_usage$value) &&
                m$p3m_usage$value >= 0 && m$p3m_usage$value <= 1)
  expect_true(!is.na(m$mpen$value) &&
                m$mpen$value >= 0 && m$mpen$value <= 1)
  expect_true(!is.na(m$mms$value) &&
                m$mms$value >= 0 && m$mms$value <= 1)
  expect_true(!is.na(m$loyalty_scr$value) &&
                m$loyalty_scr$value >= 0 && m$loyalty_scr$value <= 1)

  # Top-level orchestrator: with no AudienceLens sheet, audience list is
  # empty -> PASS with engine=v2 and zero audiences rendered.
  out <- run_audience_lens(
    data = dss, role_map = rm, cat_code = "DSS", cat_name = "Dishwash",
    cat_brands = dss_brands, focal_brand = "IPK", audiences = list(),
    structure = list(), config = list(), weights = NULL)
  expect_equal(out$status, "PASS")
  expect_equal(out$meta$engine, "v2")
  expect_equal(out$meta$n_audiences, 0L)
})
