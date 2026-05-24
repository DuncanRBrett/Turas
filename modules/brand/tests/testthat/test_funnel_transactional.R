# ==============================================================================
# BRAND MODULE TESTS — FUNNEL (TRANSACTIONAL CATEGORY TYPE) — v2 port
# ==============================================================================
# Known-answer tests on a hand-built slot-indexed 10-respondent fixture that
# encodes the same truth as the legacy funnel_transactional_10resp.csv.
#
# Hand-calculated derivation (10 respondents, 3 brands: IPK / ROB / CART):
#
# Row   Aware              Attitude            Bought_Long       Bought_Target
#       I R C              I R C               I R C             I R C
#  1    y y y              1 3 5               y y -             y y -
#  2    y y y              2 1 4               y y -             y y -
#  3    y - y              3 5 2               y - y             - - y
#  4    y y y              4 2 1               - y y             - y y
#  5    - y -              5 3 5               - y -             - - -
#  6    y y y              1 4 3               y - y             y - -
#  7    y - -              3 5 5               - - -             - - -
#  8    y y y              2 4 2               y - y             y - y
#  9    y y y              5 2 1               - y y             - - y
# 10    y y -              1 1 5               y y -             y y -
#
# Stage counts per brand (weights = 1, n = 10):
#   Aware         IPK=9 (90%)  ROB=8 (80%)  CART=7 (70%)
#   Consideration IPK=7 (70%)  ROB=6 (60%)  CART=5 (50%)
#   Bought_Long   IPK=6 (60%)  ROB=6 (60%)  CART=5 (50%)
#   Bought_Target IPK=5 (50%)  ROB=4 (40%)  CART=4 (40%)
# ==============================================================================
library(testthat)

.find_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root()

shared_lib <- file.path(ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(ROOT, "modules", "brand", "R", "03_funnel.R"))


# ==============================================================================
# Shared helpers
# ==============================================================================

# Pack a list-of-vectors into slot columns {root}_1 .. {root}_N
.pack_mm <- function(picks, root) {
  n_slots <- max(vapply(picks, length, integer(1)), 1L)
  as.data.frame(
    setNames(
      lapply(seq_len(n_slots), function(j)
        vapply(picks, function(p)
          if (j <= length(p)) p[j] else NA_character_,
          character(1))),
      paste0(root, "_", seq_len(n_slots))),
    stringsAsFactors = FALSE)
}

# Build a Multi_Mention role entry (base-keyed, no cat_code suffix)
.mm_entry <- function(role, cat, client, column_root, n_slots, qtext = "") {
  list(role = role, category = cat, client_code = client,
       variable_type = "Multi_Mention",
       column_root = column_root, per_brand = FALSE,
       columns = paste0(column_root, "_", seq_len(n_slots)),
       applicable_brands = NULL,
       question_text = qtext, option_scale = NA,
       option_map = NULL, notes = "")
}

# Build a per-brand Single_Response_Brand attitude entry
.att_entry <- function(cat, brands) {
  colroot <- paste0("BRANDATT1_", cat)
  named_cols <- setNames(paste0(colroot, "_", brands), brands)
  list(role = "funnel.attitude", category = cat, client_code = "BRANDATT1",
       variable_type = "Single_Response_Brand",
       column_root = colroot, per_brand = TRUE,
       columns = named_cols,
       applicable_brands = brands,
       question_text = "Attitude?", option_scale = NA,
       option_map = NULL, notes = "")
}


# ==============================================================================
# Transactional fixture (slot-indexed, exact truth as legacy CSV)
# ==============================================================================

.trans_data <- function() {
  aware <- list(
    c("IPK","ROB","CART"), c("IPK","ROB","CART"), c("IPK","CART"),
    c("IPK","ROB","CART"), c("ROB"),              c("IPK","ROB","CART"),
    c("IPK"),              c("IPK","ROB","CART"), c("IPK","ROB","CART"),
    c("IPK","ROB"))
  pen1 <- list(
    c("IPK","ROB"), c("IPK","ROB"), c("IPK","CART"), c("ROB","CART"),
    c("ROB"),       c("IPK","CART"), character(0),   c("IPK","CART"),
    c("ROB","CART"), c("IPK","ROB"))
  pen2 <- list(
    c("IPK","ROB"), c("IPK","ROB"), c("CART"),       c("ROB","CART"),
    character(0),   c("IPK"),       character(0),    c("IPK","CART"),
    c("CART"),      c("IPK","ROB"))

  data <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .pack_mm(aware, "BRANDAWARE_TSX"),
    .pack_mm(pen1,  "BRANDPEN1_TSX"),
    .pack_mm(pen2,  "BRANDPEN2_TSX"))
  data$BRANDATT1_TSX_IPK  <- c(1, 2, 3, 4, 5, 1, 3, 2, 5, 1)
  data$BRANDATT1_TSX_ROB  <- c(3, 1, 5, 2, 3, 4, 5, 4, 2, 1)
  data$BRANDATT1_TSX_CART <- c(5, 4, 2, 1, 5, 3, 5, 2, 1, 5)
  data
}

.trans_brands <- function() {
  data.frame(BrandCode  = c("IPK","ROB","CART"),
             BrandLabel = c("IPK","Robertsons","Cartwright"),
             stringsAsFactors = FALSE)
}

# Role map — base-keyed (cat_code = NULL in config) plus legacy output-layer
# aliases so 03d_funnel_output.R's .role_map_lookup_for_stages() finds them.
.trans_rm <- function() {
  aw <- .mm_entry("funnel.awareness", "TSX", "BRANDAWARE",
                  "BRANDAWARE_TSX", 3, "Heard of?")
  at <- .att_entry("TSX", c("IPK","ROB","CART"))
  pl <- .mm_entry("funnel.penetration_long", "TSX", "BRANDPEN1",
                  "BRANDPEN1_TSX", 2, "Bought in 12m?")
  pt <- .mm_entry("funnel.penetration_target", "TSX", "BRANDPEN2",
                  "BRANDPEN2_TSX", 2, "Bought last month?")
  list(
    "funnel.awareness"                   = aw,
    "funnel.attitude"                    = at,
    "funnel.penetration_long"            = pl,
    "funnel.penetration_target"          = pt,
    "funnel.transactional.bought_long"   = pl,  # output-layer alias
    "funnel.transactional.bought_target" = pt   # output-layer alias
  )
}

.trans_cfg <- function(...) {
  defaults <- list(`category.type` = "transactional", focal_brand = "IPK",
                   `funnel.conversion_metric` = "ratio",
                   `funnel.warn_base` = 0, `funnel.suppress_base` = 0,
                   `funnel.significance_level` = 0.05)
  modifyList(defaults, list(...))
}

# Expected values — AGGREGATE funnel (v3, 2026-05-24).
# Each stage uses its own raw survey response (per the panel explainer:
# "each stage is asked independently … the funnel narrows in aggregate,
# but it is not a respondent journey"). No cumulative AND with prior
# stages — matches what derive_funnel_stages() now does after the
# cumulative-AND was removed at 03a_funnel_derive.R:160.
#
# Per-respondent attitude codes from the fixture (Row -> I R C):
#   1: 1 3 5    6: 1 4 3
#   2: 2 1 4    7: 3 5 5
#   3: 3 5 2    8: 2 4 2
#   4: 4 2 1    9: 5 2 1
#   5: 5 3 5   10: 1 1 5
#
# Aware (raw multi-mention of brand in aware slots):
#   IPK: R1,R2,R3,R4,R6,R7,R8,R9,R10        = 9/10 = 0.9
#   ROB: R1,R2,R4,R5,R6,R8,R9,R10           = 8/10 = 0.8
#   CART: R1,R2,R3,R4,R6,R8,R9              = 7/10 = 0.7
#
# Consideration (raw attitude in top-2 codes {1, 2}; no aware filter):
#   IPK att = (1,2,3,4,5,1,3,2,5,1) → top-2 rows {1,2,6,8,10} = 5/10 = 0.5
#   ROB att = (3,1,5,2,3,4,5,4,2,1) → top-2 rows {2,4,9,10}   = 4/10 = 0.4
#   CART att = (5,4,2,1,5,3,5,2,1,5) → top-2 rows {3,4,8,9}   = 4/10 = 0.4
#   (Coincides with old cumulative result because no fixture row has
#    positive attitude without also being aware.)
#
# Bought_long (raw BRANDPEN1 multi-mention; no upstream filter):
#   IPK pen1 rows = {1,2,3,6,8,10}    = 6/10 = 0.6
#   ROB pen1 rows = {1,2,4,5,9,10}    = 6/10 = 0.6
#   CART pen1 rows = {3,4,6,8,9}      = 5/10 = 0.5
#
# Bought_target (raw BRANDPEN2 multi-mention; no upstream filter):
#   IPK pen2 rows = {1,2,6,8,10}      = 5/10 = 0.5
#   ROB pen2 rows = {1,2,4,10}        = 4/10 = 0.4
#   CART pen2 rows = {3,4,8,9}        = 4/10 = 0.4
.expected_pct <- list(
  aware         = c(IPK = 0.9, ROB = 0.8, CART = 0.7),
  consideration = c(IPK = 0.5, ROB = 0.4, CART = 0.4),
  bought_long   = c(IPK = 0.6, ROB = 0.6, CART = 0.5),
  bought_target = c(IPK = 0.5, ROB = 0.4, CART = 0.4)
)

.pct_for <- function(df, stage_key, brand_code) {
  row <- df[df$stage_key == stage_key & df$brand_code == brand_code, ,
            drop = FALSE]
  if (nrow(row) == 0L) NA_real_ else row$pct_weighted
}

.base_for <- function(df, stage_key, brand_code) {
  row <- df[df$stage_key == stage_key & df$brand_code == brand_code, ,
            drop = FALSE]
  if (nrow(row) == 0L) NA_real_ else row$base_unweighted
}


# ==============================================================================
# Tests: stage metrics
# ==============================================================================

test_that("run_funnel returns PASS or PARTIAL status on complete transactional fixture", {
  # v3 aggregate funnel: status may be PARTIAL when raw counts don't nest
  # (e.g. bought_long > consideration for a brand). That's a warning, not
  # an error — the engine reports the data as recorded.
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  expect_true(res$status %in% c("PASS", "PARTIAL"))
})


test_that("Aware stage matches hand calculation for every brand", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  for (b in names(.expected_pct$aware)) {
    expect_equal(.pct_for(res$stages, "aware", b),
                 .expected_pct$aware[[b]], tolerance = 1e-9,
                 info = sprintf("Aware pct for %s", b))
    expect_equal(.base_for(res$stages, "aware", b),
                 .expected_pct$aware[[b]] * 10,
                 info = sprintf("Aware base for %s", b))
  }
})


test_that("Consideration stage matches hand calculation", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  for (b in names(.expected_pct$consideration)) {
    expect_equal(.pct_for(res$stages, "consideration", b),
                 .expected_pct$consideration[[b]], tolerance = 1e-9,
                 info = sprintf("Consideration pct for %s", b))
  }
})


test_that("Bought_Long stage matches hand calculation", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  for (b in names(.expected_pct$bought_long)) {
    expect_equal(.pct_for(res$stages, "bought_long", b),
                 .expected_pct$bought_long[[b]], tolerance = 1e-9,
                 info = sprintf("Bought_Long pct for %s", b))
  }
})


test_that("Bought_Target stage matches hand calculation", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  for (b in names(.expected_pct$bought_target)) {
    expect_equal(.pct_for(res$stages, "bought_target", b),
                 .expected_pct$bought_target[[b]], tolerance = 1e-9,
                 info = sprintf("Bought_Target pct for %s", b))
  }
})


test_that("Preferred/heavy_buyer stages are not materialised", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  expect_false("preferred"    %in% res$stages$stage_key)
  expect_false("heavy_buyer"  %in% res$stages$stage_key)
})


# ==============================================================================
# Tests: conversions
# ==============================================================================

test_that("IPK conversion ratios match hand-calculated drops (aggregate)", {
  # Aggregate funnel — conversion ratios are aggregate ratios per the
  # panel explainer: total count at later stage / total count at earlier
  # stage. Not a per-respondent transition.
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  ipk <- res$conversions[res$conversions$brand_code == "IPK", ]

  # Aware -> Consideration = 0.5 / 0.9
  expect_equal(
    ipk$value[ipk$from_stage == "aware" & ipk$to_stage == "consideration"],
    0.5 / 0.9, tolerance = 1e-6)

  # Consideration -> Bought_Long = 0.6 / 0.5 (aggregate; raw bought_long
  # count exceeds raw consideration count because some IPK buyers have an
  # attitude code outside the top-2)
  expect_equal(
    ipk$value[ipk$from_stage == "consideration" & ipk$to_stage == "bought_long"],
    0.6 / 0.5, tolerance = 1e-6)

  # Bought_Long -> Bought_Target = 0.5 / 0.6
  expect_equal(
    ipk$value[ipk$from_stage == "bought_long" & ipk$to_stage == "bought_target"],
    0.5 / 0.6, tolerance = 1e-6)
})


test_that("absolute_gap method returns percentage-point drops", {
  cfg <- .trans_cfg(`funnel.conversion_metric` = "absolute_gap")
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), cfg)
  ipk <- res$conversions[res$conversions$brand_code == "IPK", ]
  expect_equal(
    ipk$value[ipk$from_stage == "aware" & ipk$to_stage == "consideration"],
    0.5 - 0.9, tolerance = 1e-9)
})


# ==============================================================================
# Tests: attitude decomposition
# ==============================================================================

test_that("IPK attitude decomposition sums to 100% and matches hand calc", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  ipk <- res$attitude_decomposition[res$attitude_decomposition$brand_code == "IPK", ]

  # Attitude codes for all 10 respondents: 1,2,3,4,5,1,3,2,5,1
  # Love(1): R1,R6,R10 = 3/10; Prefer(2): R2,R8 = 2/10
  # Ambiv(3): R3,R7 = 2/10; Reject(4): R4 = 1/10; NoOpinion(5): R5,R9 = 2/10
  expect_equal(ipk$pct[ipk$attitude_role == "attitude.love"],   3/10, tolerance = 1e-9)
  expect_equal(ipk$pct[ipk$attitude_role == "attitude.prefer"], 2/10, tolerance = 1e-9)
  expect_equal(ipk$pct[ipk$attitude_role == "attitude.avoid"], 1/10, tolerance = 1e-9)
  expect_equal(sum(ipk$pct), 1.0, tolerance = 1e-9)
})


# ==============================================================================
# Tests: metrics summary
# ==============================================================================

test_that("metrics_summary carries focal_by_stage with every stage", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  ms <- res$metrics_summary
  expect_equal(ms$focal_brand, "IPK")
  expect_equal(length(ms$focal_by_stage), 4L)
  expect_equal(ms$focal_by_stage$aware,        0.9, tolerance = 1e-9)
  expect_equal(ms$focal_by_stage$bought_target, 0.5, tolerance = 1e-9)
})


test_that("biggest_drop identifies IPK's weakest stage-to-stage", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  ms <- res$metrics_summary
  expect_true(!is.null(ms$biggest_drop))
  # IPK ratios (top-2 consider):
  #   aware->cons = 0.5/0.9 = 0.556 (weakest)
  #   cons->BL    = 0.5/0.5 = 1.000
  #   BL->BT      = 0.5/0.5 = 1.000
  expect_equal(ms$biggest_drop$from_stage, "aware")
  expect_equal(ms$biggest_drop$to_stage,   "consideration")
})


# ==============================================================================
# Tests: meta
# ==============================================================================

test_that("meta records category type, focal, and stage keys", {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), .trans_cfg())
  expect_equal(res$meta$category_type, "transactional")
  expect_equal(res$meta$focal_brand,   "IPK")
  expect_equal(res$meta$n_unweighted,  10L)
  expect_equal(res$meta$stage_count,   4L)
  expect_setequal(res$meta$stage_keys,
    c("aware", "consideration", "bought_long", "bought_target"))
})
