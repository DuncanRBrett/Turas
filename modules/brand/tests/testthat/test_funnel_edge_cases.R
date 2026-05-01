# ==============================================================================
# BRAND MODULE TESTS — FUNNEL EDGE CASES — v2 port
# ==============================================================================
# Covers the non-happy paths listed in FUNNEL_SPEC_v2 §10.2:
#   - Zero awareness (all stages 0%, conversions NA not NaN)
#   - All aware, none positive (Consideration = 0, later stages = 0)
#   - Missing optional role → stage omitted + warning, rest renders
#   - Positive-code set omits Ambivalent → Consideration = Love+Prefer only
#   - Inverted attitude scale (codes reversed) → same stage counts
#   - Weights all equal 1 → weighted == unweighted
#   - suppress_base renders "suppress" flag on stages below threshold
#   - Unknown category.type refuses with CFG_CATEGORY_TYPE_INVALID
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

.brands <- function(codes = c("IPK","ROB","CART")) {
  data.frame(BrandCode = codes, BrandLabel = codes, stringsAsFactors = FALSE)
}

.trans_rm_base <- function(omit = character(0)) {
  aw <- .mm_entry("funnel.awareness", "ECX", "BRANDAWARE",
                  "BRANDAWARE_ECX", 3)
  at <- .att_entry("ECX", c("IPK","ROB","CART"))
  pl <- .mm_entry("funnel.penetration_long", "ECX", "BRANDPEN1",
                  "BRANDPEN1_ECX", 3)
  pt <- .mm_entry("funnel.penetration_target", "ECX", "BRANDPEN2",
                  "BRANDPEN2_ECX", 3)
  rm <- list(
    "funnel.awareness"          = aw,
    "funnel.attitude"           = at,
    "funnel.penetration_long"   = pl,
    "funnel.penetration_target" = pt
  )
  rm[setdiff(names(rm), omit)]
}

.cfg <- function(...) {
  defaults <- list(`category.type` = "transactional", focal_brand = "IPK",
                   `funnel.conversion_metric` = "ratio",
                   `funnel.warn_base` = 0, `funnel.suppress_base` = 0)
  modifyList(defaults, list(...))
}

.pct <- function(df, key, b) {
  row <- df[df$stage_key == key & df$brand_code == b, , drop = FALSE]
  if (nrow(row) == 0L) NA_real_ else row$pct_weighted
}

# The same 10-respondent transactional truth used in test_funnel_transactional.R
.trans_data_ecx <- function() {
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
    .pack_mm(aware, "BRANDAWARE_ECX"),
    .pack_mm(pen1,  "BRANDPEN1_ECX"),
    .pack_mm(pen2,  "BRANDPEN2_ECX"))
  data$BRANDATT1_ECX_IPK  <- c(1, 2, 3, 4, 5, 1, 3, 2, 5, 1)
  data$BRANDATT1_ECX_ROB  <- c(3, 1, 5, 2, 3, 4, 5, 4, 2, 1)
  data$BRANDATT1_ECX_CART <- c(5, 4, 2, 1, 5, 3, 5, 2, 1, 5)
  data
}


# ==============================================================================
# Zero awareness
# ==============================================================================

test_that("Zero awareness for all brands yields 0% at every stage, NA conversions", {
  n <- 10
  # Build slot data with no awareness (all slots NA)
  data <- cbind(
    data.frame(Respondent_ID = seq_len(n), Weight = 1, stringsAsFactors = FALSE),
    data.frame(BRANDAWARE_ECX_1 = rep(NA_character_, n),
               BRANDPEN1_ECX_1  = rep(NA_character_, n),
               BRANDPEN2_ECX_1  = rep(NA_character_, n),
               stringsAsFactors = FALSE))
  for (b in c("IPK","ROB","CART")) {
    data[[paste0("BRANDATT1_ECX_", b)]] <- as.character(5L)
  }

  res <- run_funnel(data, .trans_rm_base(), .brands(), .cfg())
  for (b in c("IPK","ROB","CART")) {
    expect_equal(.pct(res$stages, "aware", b),        0, info = b)
    expect_equal(.pct(res$stages, "bought_target", b), 0, info = b)
  }
  expect_true(all(is.na(res$conversions$value)))
})


# ==============================================================================
# All aware, none positive
# ==============================================================================

test_that("All aware + none positive gives Consideration = 0 and later stages = 0", {
  n <- 10
  # All aware of all brands, all reject (code 4)
  all_brands_list <- replicate(n, c("IPK","ROB","CART"), simplify = FALSE)
  data <- cbind(
    data.frame(Respondent_ID = seq_len(n), Weight = 1, stringsAsFactors = FALSE),
    .pack_mm(all_brands_list, "BRANDAWARE_ECX"),
    .pack_mm(all_brands_list, "BRANDPEN1_ECX"),
    .pack_mm(all_brands_list, "BRANDPEN2_ECX"))
  for (b in c("IPK","ROB","CART")) {
    data[[paste0("BRANDATT1_ECX_", b)]] <- as.character(4L)  # all reject
  }

  res <- run_funnel(data, .trans_rm_base(), .brands(), .cfg())
  for (b in c("IPK","ROB","CART")) {
    expect_equal(.pct(res$stages, "aware", b),        1,   info = b)
    expect_equal(.pct(res$stages, "consideration", b), 0,  info = b)
    expect_equal(.pct(res$stages, "bought_long", b),   0,  info = b)
  }
})


# ==============================================================================
# Missing optional roles
# ==============================================================================

test_that("Frequency role absent: funnel is unaffected (4 stages, PASS status)", {
  # In v2 frequency is not a funnel stage; the role is simply not in the map.
  res <- run_funnel(.trans_data_ecx(), .trans_rm_base(), .brands(), .cfg())
  expect_equal(res$status, "PASS")
  expect_false("preferred"   %in% res$meta$stage_keys)
  expect_false("heavy_buyer" %in% res$meta$stage_keys)
  expect_equal(res$meta$stage_count, 4L)
  expect_equal(.pct(res$stages, "aware", "IPK"), 0.9, tolerance = 1e-9)
})


test_that("Dropping bought_long + bought_target yields a 2-stage funnel", {
  rm <- .trans_rm_base(omit = c("funnel.penetration_long",
                                 "funnel.penetration_target"))
  res <- run_funnel(.trans_data_ecx(), rm, .brands(), .cfg())
  expect_equal(res$meta$stage_count, 2L)
  expect_setequal(res$meta$stage_keys, c("aware", "consideration"))
})


# ==============================================================================
# Custom positive-code set (replaces legacy OptionMap omit_ambivalent test)
# ==============================================================================

test_that("Excluding code 3 from positive_attitude_codes reduces Consideration", {
  # IPK consideration with codes {1,2,3}: 7/10 = 70%
  # Removing code 3 (ambivalent): R3(att=3) and R7(att=3) drop out → 5/10 = 50%
  cfg_no_ambiv <- .cfg(`funnel.positive_attitude_codes` = c("1","2"))
  res <- run_funnel(.trans_data_ecx(), .trans_rm_base(), .brands(), cfg_no_ambiv)
  expect_equal(.pct(res$stages, "consideration", "IPK"), 0.5, tolerance = 1e-9)
})


# ==============================================================================
# Inverted attitude scale
# ==============================================================================

test_that("Inverted attitude scale (5=love..1=no_opinion) yields same stage counts", {
  data <- .trans_data_ecx()
  # Invert attitude codes in data: map 1→5, 2→4, 3→3, 4→2, 5→1
  for (b in c("IPK","ROB","CART")) {
    col <- paste0("BRANDATT1_ECX_", b)
    data[[col]] <- as.character(6L - as.integer(data[[col]]))
  }
  # Positive codes in the inverted scale are 5 (love), 4 (prefer), 3 (ambivalent)
  cfg_inv <- .cfg(`funnel.positive_attitude_codes` = c("5","4","3"))
  res <- run_funnel(data, .trans_rm_base(), .brands(), cfg_inv)

  expect_equal(.pct(res$stages, "consideration", "IPK"), 0.7, tolerance = 1e-9)
  expect_equal(.pct(res$stages, "bought_target", "IPK"), 0.5, tolerance = 1e-9)
})


# ==============================================================================
# Weight parity
# ==============================================================================

test_that("Weights all equal 1 produce weighted == unweighted", {
  res_u <- run_funnel(.trans_data_ecx(), .trans_rm_base(), .brands(), .cfg())
  res_w <- run_funnel(.trans_data_ecx(), .trans_rm_base(), .brands(), .cfg(),
                      weights = rep(1, 10L))

  expect_equal(res_u$stages$pct_weighted,  res_w$stages$pct_weighted)
  expect_equal(res_u$stages$base_weighted, res_w$stages$base_weighted)
})


# ==============================================================================
# Suppress base flag
# ==============================================================================

test_that("suppress_base = 50 marks stages with base < 50 as suppress", {
  set.seed(7)
  n <- 60
  brands <- c("IPK","ROB","CART")

  # All aware of all brands
  all_list <- replicate(n, brands, simplify = FALSE)
  # Pen1: all bought all brands
  pen1_list <- replicate(n, brands, simplify = FALSE)
  # Pen2: each brand independently ~50% chance
  set.seed(7)
  pen2_per <- lapply(brands, function(b) sample(0:1, n, replace = TRUE))
  names(pen2_per) <- brands
  pen2_list <- lapply(seq_len(n), function(i)
    brands[vapply(pen2_per, `[[`, integer(1), i) == 1L])

  data <- cbind(
    data.frame(Respondent_ID = seq_len(n), Weight = 1, stringsAsFactors = FALSE),
    .pack_mm(all_list,  "BRANDAWARE_ECX"),
    .pack_mm(pen1_list, "BRANDPEN1_ECX"),
    .pack_mm(pen2_list, "BRANDPEN2_ECX"))
  for (b in brands) {
    data[[paste0("BRANDATT1_ECX_", b)]] <- as.character(sample(1:2, n, replace = TRUE))
  }

  # Build role map using the actual slot count from the built data
  n_aw  <- sum(grepl("^BRANDAWARE_ECX_", names(data)))
  n_pl  <- sum(grepl("^BRANDPEN1_ECX_",  names(data)))
  n_pt  <- sum(grepl("^BRANDPEN2_ECX_",  names(data)))
  rm <- list(
    "funnel.awareness"          = .mm_entry("funnel.awareness",         "ECX", "BRANDAWARE", "BRANDAWARE_ECX", n_aw),
    "funnel.attitude"           = .att_entry("ECX", brands),
    "funnel.penetration_long"   = .mm_entry("funnel.penetration_long",  "ECX", "BRANDPEN1",  "BRANDPEN1_ECX",  n_pl),
    "funnel.penetration_target" = .mm_entry("funnel.penetration_target","ECX", "BRANDPEN2",  "BRANDPEN2_ECX",  n_pt)
  )

  cfg <- .cfg(`funnel.suppress_base` = 50, `funnel.warn_base` = 75)
  res <- run_funnel(data, rm, .brands(brands), cfg)

  aware_flags  <- res$stages$warning_flag[res$stages$stage_key == "aware"]
  target_flags <- res$stages$warning_flag[res$stages$stage_key == "bought_target"]
  # Aware base = 60 for all brands → between 50 and 75 → warn
  expect_true(all(aware_flags == "warn"))
  # Target period base (random ~30 per brand) → below 50 → suppress
  expect_true(any(target_flags == "suppress"))
})


# ==============================================================================
# Category type refusal
# ==============================================================================

test_that("Unknown category.type refuses with CFG_CATEGORY_TYPE_INVALID", {
  res <- brand_with_refusal_handler(
    run_funnel(.trans_data_ecx(), .trans_rm_base(), .brands(),
               .cfg(`category.type` = "mystery"))
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_CATEGORY_TYPE_INVALID")
})
