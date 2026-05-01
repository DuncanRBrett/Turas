# ==============================================================================
# BRAND MODULE TESTS — FUNNEL (SERVICE CATEGORY TYPE) — v2 port
# ==============================================================================
# Known-answer tests on a hand-built slot-indexed service fixture. The service
# fixture mirrors the durable fixture row-for-row (same awareness + attitude)
# but uses service-specific roles: current_customer + tenure.
# prior_brand is declared in the role map but is NOT a funnel stage.
#
# Derivation (10 respondents, 3 brands, tenure_threshold = 3):
#
# Row   Aware(I/R/C)  Attitude(I/R/C)  CurrentCustomer  Tenure
#  1    y y y         1 3 5            IPK              3
#  2    y y y         2 1 4            ROB              2
#  3    y - y         3 5 2            CART             4
#  4    y y y         4 2 1            ROB              1
#  5    - y -         5 3 5            (none)           NA
#  6    y y y         1 4 3            IPK              2
#  7    y - -         3 5 5            (none)           NA
#  8    y y y         2 4 2            IPK              3
#  9    y y y         5 2 1            CART             1
# 10    y y -         1 1 5            IPK              3
#
# Stage counts (n=10, weights=1):
#   Aware              IPK=9 (90%)  ROB=8 (80%)  CART=7 (70%)
#   Consideration      IPK=7 (70%)  ROB=6 (60%)  CART=5 (50%)
#   Current_customer_s IPK=4 (40%)  ROB=2 (20%)  CART=2 (20%)
#   Long_tenured_s     IPK=3 (30%)  ROB=0 (0%)   CART=1 (10%)
#     IPK owners R1,R6,R8,R10: tenures 3,2,3,3 — ≥3: R1,R8,R10
#     ROB owners R2,R4: tenures 2,1 — none ≥3
#     CART owners R3,R9: tenures 4,1 — only R3
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

# Single-response per-category entry (current_customer, tenure, prior_brand)
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
# Service fixture data
# ==============================================================================

.svc_data <- function() {
  # Same awareness + attitude as transactional fixture
  aware <- list(
    c("IPK","ROB","CART"), c("IPK","ROB","CART"), c("IPK","CART"),
    c("IPK","ROB","CART"), c("ROB"),              c("IPK","ROB","CART"),
    c("IPK"),              c("IPK","ROB","CART"), c("IPK","ROB","CART"),
    c("IPK","ROB"))

  data <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .pack_mm(aware, "BRANDAWARE_SVC"))

  data$BRANDATT1_SVC_IPK  <- c(1, 2, 3, 4, 5, 1, 3, 2, 5, 1)
  data$BRANDATT1_SVC_ROB  <- c(3, 1, 5, 2, 3, 4, 5, 4, 2, 1)
  data$BRANDATT1_SVC_CART <- c(5, 4, 2, 1, 5, 3, 5, 2, 1, 5)

  # Current customer (single brand code per respondent, or NA)
  data$BRANDPENSERV1_SVC <- c("IPK","ROB","CART","ROB", NA,
                               "IPK",  NA, "IPK","CART","IPK")
  # Tenure (numeric; NA for non-customers)
  data$BRANDPENSERV2_SVC <- c(3, 2, 4, 1, NA, 2, NA, 3, 1, 3)
  # Prior brand (not a funnel stage; present in role map only)
  data$BRANDPENSERV3_SVC <- c("ROB","IPK", NA,"CART", NA,"CART", NA, NA,"IPK", NA)
  data
}

.svc_brands <- function() {
  data.frame(BrandCode  = c("IPK","ROB","CART"),
             BrandLabel = c("IPK","Robertsons","Cartwright"),
             stringsAsFactors = FALSE)
}

.svc_rm <- function() {
  aw <- .mm_entry("funnel.awareness", "SVC", "BRANDAWARE",
                  "BRANDAWARE_SVC", 3, "Heard of?")
  at <- .att_entry("SVC", c("IPK","ROB","CART"))
  cc <- .sr_entry("funnel.service.current_customer", "SVC",
                  "BRANDPENSERV1", "BRANDPENSERV1_SVC", "Current customer?")
  tn <- .sr_entry("funnel.service.tenure", "SVC",
                  "BRANDPENSERV2", "BRANDPENSERV2_SVC", "Tenure?")
  pb <- .sr_entry("funnel.service.prior_brand", "SVC",
                  "BRANDPENSERV3", "BRANDPENSERV3_SVC", "Prior brand?")
  list(
    "funnel.awareness"              = aw,
    "funnel.attitude"               = at,
    "funnel.service.current_customer" = cc,
    "funnel.service.tenure"         = tn,
    "funnel.service.prior_brand"    = pb
  )
}

.svc_cfg <- function(tenure_threshold = 3) {
  list(`category.type` = "service", focal_brand = "IPK",
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

# Expected values (hand-calculated; see header)
.expected_pct <- list(
  aware               = c(IPK = 0.9, ROB = 0.8, CART = 0.7),
  consideration       = c(IPK = 0.7, ROB = 0.6, CART = 0.5),
  current_customer_s  = c(IPK = 0.4, ROB = 0.2, CART = 0.2),
  long_tenured_s      = c(IPK = 0.3, ROB = 0.0, CART = 0.1)
)


# ==============================================================================
# Tests
# ==============================================================================

test_that("Stage count is 4 and prior_brand is NOT a stage", {
  res <- run_funnel(.svc_data(), .svc_rm(), .svc_brands(), .svc_cfg())
  expect_equal(res$meta$stage_count, 4L)
  expect_false("prior_brand" %in% res$meta$stage_keys)
  expect_false("funnel.service.prior_brand" %in% res$meta$stage_keys)
  expect_setequal(res$meta$stage_keys,
    c("aware", "consideration", "current_customer_s", "long_tenured_s"))
})


test_that("All four service stages match hand-calculated expectations", {
  res <- run_funnel(.svc_data(), .svc_rm(), .svc_brands(), .svc_cfg())
  for (stage in names(.expected_pct)) {
    for (b in names(.expected_pct[[stage]])) {
      expect_equal(.pct_for(res$stages, stage, b),
                   .expected_pct[[stage]][[b]], tolerance = 1e-9,
                   info = sprintf("%s %s", stage, b))
    }
  }
})


test_that("prior_brand role is in the role map but derive_funnel_stages ignores it", {
  rm <- .svc_rm()
  expect_true("funnel.service.prior_brand" %in% names(rm))

  derived <- derive_funnel_stages(.svc_data(), rm,
                                  category_type = "service",
                                  brand_list = .svc_brands(),
                                  tenure_threshold = 3)
  expect_false("prior_brand" %in% names(derived$stages))
})


test_that("Service run_funnel status is PASS when all roles present", {
  res <- run_funnel(.svc_data(), .svc_rm(), .svc_brands(), .svc_cfg())
  expect_equal(res$status, "PASS")
})
