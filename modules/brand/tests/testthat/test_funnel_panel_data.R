# ==============================================================================
# BRAND MODULE TESTS — FUNNEL PANEL DATA CONTRACT — v2 port
# ==============================================================================
# Validates build_funnel_panel_data() returns the structure the HTML panel
# renderer expects, using the same 10-respondent transactional fixture used in
# test_funnel_transactional.R (slot-indexed v2 shape).
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
source(file.path(ROOT, "modules", "brand", "R", "03c_funnel_panel_data.R"))
source(file.path(ROOT, "modules", "brand", "R", "03e_funnel_legacy_adapter.R"))


# ==============================================================================
# Shared fixture helpers
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

.trans_rm <- function() {
  aw <- .mm_entry("funnel.awareness", "TSX", "BRANDAWARE", "BRANDAWARE_TSX", 3, "Aware")
  at <- .att_entry("TSX", c("IPK","ROB","CART"))
  pl <- .mm_entry("funnel.penetration_long",   "TSX", "BRANDPEN1", "BRANDPEN1_TSX", 2, "BL")
  pt <- .mm_entry("funnel.penetration_target", "TSX", "BRANDPEN2", "BRANDPEN2_TSX", 2, "BT")
  list(
    "funnel.awareness"                   = aw,
    "funnel.attitude"                    = at,
    "funnel.penetration_long"            = pl,
    "funnel.penetration_target"          = pt,
    "funnel.transactional.bought_long"   = pl,
    "funnel.transactional.bought_target" = pt
  )
}

.run_fixture <- function() {
  run_funnel(.trans_data(), .trans_rm(), .trans_brands(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))
}


# ==============================================================================
# Contract-level tests
# ==============================================================================

test_that("panel data has every top-level section defined in FUNNEL_SPEC §6", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_setequal(names(panel),
    c("meta","cards","table","shape_chart","consideration_detail","config","about"))
})


test_that("meta captures focal brand, category type, stage count, and N", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_equal(panel$meta$focal_brand_code, "IPK")
  expect_equal(panel$meta$focal_brand_name, "IPK")
  expect_equal(panel$meta$category_type,    "transactional")
  expect_equal(panel$meta$stage_count,      4L)
  expect_equal(panel$meta$n_unweighted,     10L)
  expect_setequal(panel$meta$stage_keys,
    c("aware","consideration","bought_long","bought_target"))
  expect_equal(panel$meta$stage_labels[["aware"]],        "Aware")
  expect_equal(panel$meta$stage_labels[["bought_target"]], "Target Period")
})


test_that("meta exposes stage definitions for every stage (popover copy)", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_true(is.character(panel$meta$stage_definitions))
  expect_setequal(names(panel$meta$stage_definitions),
    c("aware","consideration","bought_long","bought_target"))
  expect_true(all(nzchar(panel$meta$stage_definitions)))
  expect_true(grepl("aware", panel$meta$stage_definitions[["aware"]],
                    ignore.case = TRUE))
})


test_that("config-level funnel.stage_definitions overrides baked defaults", {
  overrides <- list(aware = "Custom aware text")
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(),
    list(`funnel.stage_definitions` = overrides))
  expect_equal(panel$meta$stage_definitions[["aware"]], "Custom aware text")
  expect_true(nzchar(panel$meta$stage_definitions[["consideration"]]))
  expect_false(panel$meta$stage_definitions[["consideration"]] == "Custom aware text")
})


test_that("funnel cards carry focal pct, category-avg pct, and warning flag per stage", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_equal(length(panel$cards$funnel), 4L)

  aware_card <- panel$cards$funnel[[1]]
  expect_equal(aware_card$stage_key,  "aware")
  expect_equal(aware_card$focal_pct,  0.9, tolerance = 1e-9)
  # Category average (excluding focal) = mean(ROB 0.8, CART 0.7) = 0.75
  expect_equal(aware_card$cat_avg_pct, 0.75, tolerance = 1e-9)
  expect_true(aware_card$warning_flag %in% c("none","warn","suppress"))
})


test_that("relationship cards — 5 attitude positions with focal vs avg", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_equal(length(panel$cards$relationship), 5L)

  love_card <- Filter(function(c) c$attitude_role == "attitude.love",
                      panel$cards$relationship)[[1]]
  expect_equal(love_card$attitude_label, "Love")
  # IPK love = 3/10 (total base: all 10 respondents answer attitude)
  expect_equal(love_card$focal_pct, 3/10, tolerance = 1e-9)
  expect_true(is.numeric(love_card$cat_avg_pct))
})


test_that("table cells cover every (stage, brand) pair with absolute and nested pct", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_equal(length(panel$table$stage_keys), 4L)
  expect_equal(length(panel$table$brand_codes), 3L)
  expect_equal(length(panel$table$cells), 12L)

  # IPK aware: absolute = 0.9; nested = same for stage 1 (no prior stage)
  ipk_aware <- Filter(function(c)
    c$stage_key == "aware" && c$brand_code == "IPK", panel$table$cells)[[1]]
  expect_equal(ipk_aware$pct_absolute, 0.9, tolerance = 1e-9)
  expect_equal(ipk_aware$pct_nested,   0.9, tolerance = 1e-9)
  expect_equal(ipk_aware$sig_vs_focal, "focal")

  # IPK consideration: absolute = 0.7; nested = 0.7/0.9
  ipk_cons <- Filter(function(c)
    c$stage_key == "consideration" && c$brand_code == "IPK",
    panel$table$cells)[[1]]
  expect_equal(ipk_cons$pct_absolute, 0.7, tolerance = 1e-9)
  expect_equal(ipk_cons$pct_nested,   0.7 / 0.9, tolerance = 1e-9)
})


test_that("every cell carries a sig_vs_avg field", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  for (cell in panel$table$cells) {
    expect_true(cell$sig_vs_avg %in% c("higher","lower","not_sig","na"),
                info = sprintf("cell %s/%s sig_vs_avg = %s",
                               cell$stage_key, cell$brand_code, cell$sig_vs_avg))
  }
})


test_that("table includes Average-of-all-brands row with both pct modes", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_equal(length(panel$table$avg_all_brands), 4L)

  aware_avg <- panel$table$avg_all_brands[[1]]
  expect_equal(aware_avg$stage_key,    "aware")
  expect_equal(aware_avg$pct_absolute, 0.8, tolerance = 1e-9)  # mean(0.9,0.8,0.7)
  expect_equal(aware_avg$pct_nested,   0.8, tolerance = 1e-9)  # stage 1 no prior

  cons_avg <- panel$table$avg_all_brands[[2]]
  # absolute mean = mean(0.7,0.6,0.5) = 0.6; nested = 0.6 / 0.8 = 0.75
  expect_equal(cons_avg$pct_absolute, 0.6,  tolerance = 1e-9)
  expect_equal(cons_avg$pct_nested,   0.75, tolerance = 1e-9)
})


test_that("shape_chart envelope carries per-stage min and max", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  env <- panel$shape_chart$envelope
  expect_equal(length(env$stage_keys), 4L)
  # Aware: min(0.7 CART), max(0.9 IPK)
  expect_equal(env$min_values[1], 0.7, tolerance = 1e-9)
  expect_equal(env$max_values[1], 0.9, tolerance = 1e-9)
})


test_that("shape_chart series have one pct per stage per brand", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_equal(length(panel$shape_chart$focal_series$pct_values), 4L)
  expect_equal(length(panel$shape_chart$competitor_series), 2L)
  expect_equal(panel$shape_chart$focal_series$brand_code, "IPK")
  expect_equal(panel$shape_chart$focal_series$pct_values[1], 0.9, tolerance = 1e-9)
})


test_that("consideration_detail has one entry per brand with 5 attitude segments", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  brands_covered <- vapply(panel$consideration_detail$brands,
                           function(b) b$brand_code, character(1))
  expect_setequal(brands_covered, c("IPK","ROB","CART"))
  ipk_entry <- panel$consideration_detail$brands[[which(brands_covered == "IPK")]]
  expect_setequal(names(ipk_entry$segments),
    c("attitude.love","attitude.prefer","attitude.ambivalent",
      "attitude.reject","attitude.no_opinion"))
  # IPK love = 3/10
  expect_equal(ipk_entry$segments$attitude.love, 3/10, tolerance = 1e-9)
})


test_that("config block carries chip picker defaults, conversion metric, show_counts", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(),
    list(`funnel.conversion_metric` = "ratio", show_counts = TRUE))
  expect_equal(panel$config$conversion_metric, "ratio")
  expect_true(panel$config$show_counts)
  expect_true("IPK" %in% panel$config$chip_picker$default_selection)
  expect_setequal(panel$config$chip_picker$all_brands, c("IPK","ROB","CART"))
})


# ==============================================================================
# Brand colours tests
# ==============================================================================

.trans_brands_with_colours <- function() {
  data.frame(
    BrandCode  = c("IPK","ROB","CART"),
    BrandLabel = c("IPK","Robertsons","Cartwright"),
    Colour     = c("#1A5276","#C0392B",""),
    stringsAsFactors = FALSE)
}

test_that("brand_colours map contains only brands with valid hex colours set", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands_with_colours(), list())
  colours <- panel$config$brand_colours
  expect_equal(colours[["IPK"]],  "#1A5276")
  expect_equal(colours[["ROB"]],  "#C0392B")
  expect_null(colours[["CART"]])
})


test_that("brand_colours map is empty when no Colour column is present", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_equal(length(panel$config$brand_colours), 0L)
})


test_that("invalid hex values in Colour column are silently dropped with a message", {
  bl_bad <- data.frame(
    BrandCode  = c("IPK","ROB","CART"),
    BrandLabel = c("IPK","Robertsons","Cartwright"),
    Colour     = c("#1A5276","not-a-colour","#ZZZ123"),
    stringsAsFactors = FALSE)
  panel <- expect_message(
    build_funnel_panel_data(.run_fixture(), bl_bad, list()),
    regexp = "not a valid hex")
  colours <- panel$config$brand_colours
  expect_equal(colours[["IPK"]], "#1A5276")
  expect_null(colours[["ROB"]])
  expect_null(colours[["CART"]])
})


test_that("about carries canonical methodology, heavy-buyer pointer, and panel-disclosure notes", {
  panel <- build_funnel_panel_data(.run_fixture(), .trans_brands(), list())
  expect_true(nzchar(panel$about$methodology_note))
  expect_true(grepl("nested", panel$about$methodology_note, ignore.case = TRUE))
  expect_true(grepl("non-probability|panel sampling",
                    panel$about$significance_note, ignore.case = TRUE))
  expect_true(grepl("Repertoire|Frequency|heavy",
                    panel$about$heavy_buyer_note, ignore.case = TRUE))
  expect_true(grepl("IPK", panel$about$base_note))
})


test_that("REFUSED result returns empty but well-formed panel", {
  refused <- list(status = "REFUSED", code = "CFG_FOO")
  panel <- build_funnel_panel_data(refused, .trans_brands(), list())
  expect_setequal(names(panel),
    c("meta","cards","table","shape_chart","consideration_detail","config","about"))
  expect_equal(length(panel$cards), 0L)
  expect_equal(length(panel$table), 0L)
})


# ==============================================================================
# Legacy-wide adapter tests
# ==============================================================================

test_that("legacy wide adapter produces BrandCode + stage-pct columns", {
  result <- .run_fixture()
  wide <- build_funnel_legacy_wide(result, .trans_brands())
  expect_true(all(c("BrandCode","Aware_Pct","Positive_Pct",
                    "Bought_Pct","Primary_Pct",
                    "Love_Pct","Prefer_Pct","Ambivalent_Pct",
                    "Reject_Pct","NoOpinion_Pct") %in% names(wide)))
  # IPK aware = 90% (values in 0-100 range)
  expect_equal(wide$Aware_Pct[wide$BrandCode == "IPK"], 90, tolerance = 1e-9)
})


test_that("legacy conversions adapter produces 3-column conversion matrix", {
  result <- .run_fixture()
  conv <- build_funnel_legacy_conversions(result, .trans_brands())
  expect_true(all(c("BrandCode","Aware_to_Positive",
                    "Positive_to_Bought","Bought_to_Primary") %in% names(conv)))
  expect_equal(nrow(conv), 3L)
})
