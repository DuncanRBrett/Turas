# ==============================================================================
# BRAND MODULE TESTS — FUNNEL (DURABLE CATEGORY TYPE) — v2 port
# ==============================================================================
# Known-answer tests on a hand-built slot-indexed durable fixture.
# tenure_threshold = 3 (≥ 3 counts as long-tenured).
#
# Derivation (10 respondents, 3 brands, tenure_threshold = 3):
#
# Row   Aware(I/R/C)  Attitude(I/R/C)  CurrentOwner  Tenure
#  1    y y y         1 3 5            IPK            3
#  2    y y y         2 1 4            ROB            2
#  3    y - y         3 5 2            CART           4
#  4    y y y         4 2 1            ROB            1
#  5    - y -         5 3 5            (none)         NA
#  6    y y y         1 4 3            IPK            2
#  7    y - -         3 5 5            (none)         NA
#  8    y y y         2 4 2            IPK            3
#  9    y y y         5 2 1            CART           1
# 10    y y -         1 1 5            IPK            3
#
# Stage counts (n=10, weights=1):
#   Aware           IPK=9 (90%)  ROB=8 (80%)  CART=7 (70%)
#   Consideration   IPK=7 (70%)  ROB=6 (60%)  CART=5 (50%)
#   Current owner   IPK=4 (40%)  ROB=2 (20%)  CART=2 (20%)
#     IPK: R1,R6,R8,R10 (all in consideration)
#     ROB: R2,R4; CART: R3,R9
#   Long-tenured (thr=3): IPK=3 (30%)  ROB=0 (0%)  CART=1 (10%)
#     IPK owners tenures: 3,2,3,3 — ≥3: R1,R8,R10
#     ROB owners tenures: 2,1 — none
#     CART owners tenures: 4,1 — only R3
#
# With thr=2: IPK=4 (40%)  ROB=1 (10%)  CART=1 (10%)
#   IPK: all 4 owners ≥2 tenure; ROB: R2(ten=2); CART: R3(ten=4)
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
# Helpers
# ==============================================================================

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

.mm_entry <- function(role, cat, client, column_root, n_slots, qtext = "") {
  list(role = role, category = cat, client_code = client,
       variable_type = "Multi_Mention",
       column_root = column_root, per_brand = FALSE,
       columns = paste0(column_root, "_", seq_len(n_slots)),
       applicable_brands = NULL,
       question_text = qtext, option_scale = NA,
       option_map = NULL, notes = "")
}

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

.sr_entry <- function(role, cat, client, col, qtext = "") {
  list(role = role, category = cat, client_code = client,
       variable_type = "Single_Response",
       column_root = col, per_brand = FALSE,
       columns = col,
       applicable_brands = NULL,
       question_text = qtext, option_scale = NA,
       option_map = NULL, notes = "")
}


# ==============================================================================
# Durable fixture data
# ==============================================================================

.dur_data <- function() {
  aware <- list(
    c("IPK","ROB","CART"), c("IPK","ROB","CART"), c("IPK","CART"),
    c("IPK","ROB","CART"), c("ROB"),              c("IPK","ROB","CART"),
    c("IPK"),              c("IPK","ROB","CART"), c("IPK","ROB","CART"),
    c("IPK","ROB"))

  data <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .pack_mm(aware, "BRANDAWARE_DUR"))

  data$BRANDATT1_DUR_IPK  <- c(1, 2, 3, 4, 5, 1, 3, 2, 5, 1)
  data$BRANDATT1_DUR_ROB  <- c(3, 1, 5, 2, 3, 4, 5, 4, 2, 1)
  data$BRANDATT1_DUR_CART <- c(5, 4, 2, 1, 5, 3, 5, 2, 1, 5)

  # Current owner (single brand code per respondent, or NA)
  data$BRANDPENDUR1_DUR <- c("IPK","ROB","CART","ROB", NA,
                              "IPK",  NA, "IPK","CART","IPK")
  # Tenure (numeric; NA for non-owners)
  data$BRANDPENDUR2_DUR <- c(3, 2, 4, 1, NA, 2, NA, 3, 1, 3)
  data
}

.dur_brands <- function() {
  data.frame(BrandCode  = c("IPK","ROB","CART"),
             BrandLabel = c("IPK","Robertsons","Cartwright"),
             stringsAsFactors = FALSE)
}

.dur_rm <- function() {
  aw <- .mm_entry("funnel.awareness", "DUR", "BRANDAWARE",
                  "BRANDAWARE_DUR", 3, "Heard of?")
  at <- .att_entry("DUR", c("IPK","ROB","CART"))
  co <- .sr_entry("funnel.durable.current_owner", "DUR",
                  "BRANDPENDUR1", "BRANDPENDUR1_DUR", "Current owner?")
  tn <- .sr_entry("funnel.durable.tenure", "DUR",
                  "BRANDPENDUR2", "BRANDPENDUR2_DUR", "Tenure?")
  list(
    "funnel.awareness"           = aw,
    "funnel.attitude"            = at,
    "funnel.durable.current_owner" = co,
    "funnel.durable.tenure"      = tn
  )
}

.dur_cfg <- function(tenure_threshold = 3) {
  list(`category.type` = "durable", focal_brand = "IPK",
       `funnel.conversion_metric` = "ratio",
       `funnel.warn_base` = 0, `funnel.suppress_base` = 0,
       `funnel.significance_level` = 0.05,
       `funnel.tenure_threshold` = tenure_threshold)
}

.pct_for <- function(df, stage_key, brand_code) {
  row <- df[df$stage_key == stage_key & df$brand_code == brand_code, ,
            drop = FALSE]
  if (nrow(row) == 0L) NA_real_ else row$pct_weighted
}

# Expected values at threshold = 3 (hand-calculated; see header)
.expected_pct <- list(
  aware           = c(IPK = 0.9, ROB = 0.8, CART = 0.7),
  consideration   = c(IPK = 0.7, ROB = 0.6, CART = 0.5),
  current_owner_d = c(IPK = 0.4, ROB = 0.2, CART = 0.2),
  long_tenured_d  = c(IPK = 0.3, ROB = 0.0, CART = 0.1)
)


# ==============================================================================
# Tests
# ==============================================================================

test_that("Aware and Consideration match transactional hand-calc (same truth)", {
  res <- run_funnel(.dur_data(), .dur_rm(), .dur_brands(), .dur_cfg())
  for (b in names(.expected_pct$aware)) {
    expect_equal(.pct_for(res$stages, "aware", b),
                 .expected_pct$aware[[b]], tolerance = 1e-9,
                 info = sprintf("aware %s", b))
    expect_equal(.pct_for(res$stages, "consideration", b),
                 .expected_pct$consideration[[b]], tolerance = 1e-9,
                 info = sprintf("consideration %s", b))
  }
})


test_that("Current owner stage matches hand calculation (nested in consideration)", {
  res <- run_funnel(.dur_data(), .dur_rm(), .dur_brands(), .dur_cfg())
  for (b in names(.expected_pct$current_owner_d)) {
    expect_equal(.pct_for(res$stages, "current_owner_d", b),
                 .expected_pct$current_owner_d[[b]], tolerance = 1e-9,
                 info = sprintf("current_owner %s", b))
  }
})


test_that("Long-tenured stage matches hand calc with threshold = 3", {
  res <- run_funnel(.dur_data(), .dur_rm(), .dur_brands(), .dur_cfg())
  for (b in names(.expected_pct$long_tenured_d)) {
    expect_equal(.pct_for(res$stages, "long_tenured_d", b),
                 .expected_pct$long_tenured_d[[b]], tolerance = 1e-9,
                 info = sprintf("long_tenured %s", b))
  }
})


test_that("Changing tenure_threshold to 2 shifts only the long-tenured stage", {
  res <- run_funnel(.dur_data(), .dur_rm(), .dur_brands(), .dur_cfg(tenure_threshold = 2))

  # IPK owners R1,R6,R8,R10 with tenures 3,2,3,3 — all ≥2 → 4/10 = 40%
  expect_equal(.pct_for(res$stages, "long_tenured_d", "IPK"), 0.4, tolerance = 1e-9)
  # ROB owners R2,R4 with tenures 2,1 — only R2 ≥2 → 1/10 = 10%
  expect_equal(.pct_for(res$stages, "long_tenured_d", "ROB"), 0.1, tolerance = 1e-9)
  # CART owners R3,R9 with tenures 4,1 — only R3 ≥2 → 1/10 = 10%
  expect_equal(.pct_for(res$stages, "long_tenured_d", "CART"), 0.1, tolerance = 1e-9)

  # current_owner_d unchanged at threshold change
  expect_equal(.pct_for(res$stages, "current_owner_d", "IPK"), 0.4, tolerance = 1e-9)
})


test_that("Missing tenure_threshold drops Long-tenured and records a warning", {
  cfg <- .dur_cfg(tenure_threshold = NULL)
  res <- run_funnel(.dur_data(), .dur_rm(), .dur_brands(), cfg)

  expect_equal(nrow(res$stages[res$stages$stage_key == "long_tenured_d", ]), 0L)
  expect_equal(res$status, "PARTIAL")
  expect_true(any(grepl("Long-tenured", res$warnings)))
})


test_that("Stage count reflects 4-stage durable shape", {
  res <- run_funnel(.dur_data(), .dur_rm(), .dur_brands(), .dur_cfg())
  expect_equal(res$meta$stage_count, 4L)
  expect_setequal(res$meta$stage_keys,
    c("aware", "consideration", "current_owner_d", "long_tenured_d"))
})
