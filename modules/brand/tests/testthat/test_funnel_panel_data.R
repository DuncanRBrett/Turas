# ==============================================================================
# BRAND MODULE TESTS - FUNNEL PANEL DATA CONTRACT (FUNNEL_SPEC_v2 §6)
# ==============================================================================
# Validates that build_funnel_panel_data() returns the structure the HTML
# panel renderer expects, sourced from a run_funnel() result on the same
# hand-calculated transactional fixture used in test_funnel_transactional.R.
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    dir <- dirname(dir)
  }
  getwd()
}

TURAS_ROOT <- .find_turas_root_for_test()

shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard_role_map.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03_funnel.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03c_funnel_panel_data.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03e_funnel_legacy_adapter.R"))


# --- Shared fixture helpers (mirrors test_funnel_transactional.R) ------------

.brand_list <- function() {
  data.frame(BrandCode = c("IPK", "ROB", "CART"),
             BrandLabel = c("IPK", "Robertsons", "Cartwright"),
             stringsAsFactors = FALSE)
}

.optionmap_attitude <- function() {
  data.frame(Scale = rep("attitude_scale", 5),
             ClientCode = as.character(1:5),
             Role = c("attitude.love","attitude.prefer",
                      "attitude.ambivalent","attitude.reject",
                      "attitude.no_opinion"),
             ClientLabel = c("L","P","A","R","N"),
             OrderIndex = 1:5,
             stringsAsFactors = FALSE)
}

.structure_transactional <- function() {
  qm <- data.frame(
    Role = c("funnel.awareness","funnel.attitude",
             "funnel.transactional.bought_long",
             "funnel.transactional.bought_target",
             "funnel.transactional.frequency",
             "system.respondent.id","system.respondent.weight"),
    ClientCode = c("BRANDAWARE","QBRANDATT1",
                   "BRANDPENTRANS1","BRANDPENTRANS2","BRANDPENTRANS3",
                   "Respondent_ID","Weight"),
    QuestionText = c("Aware","Att","BL","BT","FR","RID","W"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention","Single_Response",
                      "Multi_Mention","Multi_Mention","Numeric",
                      "Single_Response","Numeric"),
    ColumnPattern = c("{code}_{brand_code}","{code}_{brand_code}",
                      "{code}_{brand_code}","{code}_{brand_code}",
                      "{code}_{brand_code}","{code}","{code}"),
    OptionMapScale = c("","attitude_scale","","","","",""),
    Notes = NA_character_, stringsAsFactors = FALSE)
  list(questionmap = qm, optionmap = .optionmap_attitude(),
       brands = .brand_list(), ceps = data.frame(), dba_assets = data.frame())
}

.fixture_transactional <- function() {
  read.csv(file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                     "funnel_transactional_10resp.csv"),
           stringsAsFactors = FALSE)
}

.run_fixture <- function() {
  data <- .fixture_transactional()
  rm <- load_role_map(.structure_transactional())
  run_funnel(data, rm, .brand_list(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))
}


# --- Contract-level tests ----------------------------------------------------

test_that("panel data has every top-level section defined in FUNNEL_SPEC §6", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())
  expect_setequal(names(panel),
    c("meta", "cards", "table", "shape_chart", "consideration_detail",
      "config", "about"))
})


test_that("meta captures focal brand, category type, stage count, and N", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())
  expect_equal(panel$meta$focal_brand_code, "IPK")
  expect_equal(panel$meta$focal_brand_name, "IPK")
  expect_equal(panel$meta$category_type, "transactional")
  expect_equal(panel$meta$stage_count, 4)
  expect_equal(panel$meta$n_unweighted, 10)
  expect_setequal(panel$meta$stage_keys,
    c("aware","consideration","bought_long","bought_target"))
  expect_equal(panel$meta$stage_labels[["aware"]], "Aware")
  expect_equal(panel$meta$stage_labels[["bought_target"]], "Target Period")
})


test_that("meta exposes stage definitions for every stage (popover copy)", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_true(is.character(panel$meta$stage_definitions))
  expect_setequal(names(panel$meta$stage_definitions),
    c("aware","consideration","bought_long","bought_target"))
  expect_true(all(nzchar(panel$meta$stage_definitions)))
  # Spot-check a canonical definition
  expect_true(grepl("aware", panel$meta$stage_definitions[["aware"]],
                    ignore.case = TRUE))
})


test_that("config-level funnel.stage_definitions overrides baked defaults", {
  result <- .run_fixture()
  overrides <- list(aware = "Custom aware text")
  panel <- build_funnel_panel_data(result, .brand_list(),
    list(`funnel.stage_definitions` = overrides))

  expect_equal(panel$meta$stage_definitions[["aware"]],
               "Custom aware text")
  # Non-overridden keys fall back to defaults
  expect_true(nzchar(panel$meta$stage_definitions[["consideration"]]))
  expect_false(panel$meta$stage_definitions[["consideration"]] ==
               "Custom aware text")
})


test_that("funnel cards carry focal pct, category-avg pct, and warning flag per stage", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())
  expect_equal(length(panel$cards$funnel), 4)

  aware_card <- panel$cards$funnel[[1]]
  expect_equal(aware_card$stage_key, "aware")
  expect_equal(aware_card$focal_pct, 0.9, tolerance = 1e-9)
  # Category average (excluding focal) = mean(ROB 0.8, CART 0.7) = 0.75
  expect_equal(aware_card$cat_avg_pct, 0.75, tolerance = 1e-9)
  expect_true(aware_card$warning_flag %in% c("none","warn","suppress"))
})


test_that("relationship cards — 5 attitude positions with focal vs avg", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())
  expect_equal(length(panel$cards$relationship), 5)

  love_card <- Filter(function(c) c$attitude_role == "attitude.love",
                      panel$cards$relationship)[[1]]
  expect_equal(love_card$attitude_label, "Love")
  # IPK love = 3/10 from fixture (total base: all 10 respondents answer attitude)
  expect_equal(love_card$focal_pct, 3/10, tolerance = 1e-9)
  expect_true(is.numeric(love_card$cat_avg_pct))
})


test_that("table cells cover every (stage, brand) pair with absolute and nested pct", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_equal(length(panel$table$stage_keys), 4)
  expect_equal(length(panel$table$brand_codes), 3)
  # 4 stages x 3 brands = 12 cells
  expect_equal(length(panel$table$cells), 12)

  # IPK aware cell: absolute = 0.9; nested = same for stage 1 (no prev)
  ipk_aware <- Filter(function(c)
    c$stage_key == "aware" && c$brand_code == "IPK", panel$table$cells)[[1]]
  expect_equal(ipk_aware$pct_absolute, 0.9, tolerance = 1e-9)
  expect_equal(ipk_aware$pct_nested,   0.9, tolerance = 1e-9)
  expect_equal(ipk_aware$sig_vs_focal, "focal")

  # IPK consideration: absolute = 0.7; nested = 0.7/0.9 = 0.7778
  ipk_cons <- Filter(function(c)
    c$stage_key == "consideration" && c$brand_code == "IPK",
    panel$table$cells)[[1]]
  expect_equal(ipk_cons$pct_absolute, 0.7, tolerance = 1e-9)
  expect_equal(ipk_cons$pct_nested,   0.7 / 0.9, tolerance = 1e-9)
})


test_that("every cell carries a sig_vs_avg field for the in-cell \u25B2/\u25BC flag", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  for (cell in panel$table$cells) {
    expect_true(cell$sig_vs_avg %in%
                c("higher", "lower", "not_sig", "na"),
                info = sprintf("cell %s/%s sig_vs_avg = %s",
                               cell$stage_key, cell$brand_code,
                               cell$sig_vs_avg))
  }
})


test_that("table includes an Average-of-all-brands row with both pct modes", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_equal(length(panel$table$avg_all_brands), 4)
  aware_avg <- panel$table$avg_all_brands[[1]]
  expect_equal(aware_avg$stage_key, "aware")
  # mean(0.9, 0.8, 0.7) = 0.8
  expect_equal(aware_avg$pct_absolute, 0.8, tolerance = 1e-9)
  expect_equal(aware_avg$pct_nested,   0.8, tolerance = 1e-9)  # stage 1

  cons_avg <- panel$table$avg_all_brands[[2]]
  # absolute mean = mean(0.7, 0.6, 0.5) = 0.6; nested = 0.6 / 0.8 = 0.75
  expect_equal(cons_avg$pct_absolute, 0.6, tolerance = 1e-9)
  expect_equal(cons_avg$pct_nested,   0.75, tolerance = 1e-9)
})


test_that("shape_chart envelope carries per-stage min and max", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  env <- panel$shape_chart$envelope
  expect_equal(length(env$stage_keys), 4)
  # Aware: min(0.7 CART), max(0.9 IPK)
  expect_equal(env$min_values[1], 0.7, tolerance = 1e-9)
  expect_equal(env$max_values[1], 0.9, tolerance = 1e-9)
})


test_that("shape_chart series have one pct per stage per brand", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_equal(length(panel$shape_chart$focal_series$pct_values), 4)
  expect_equal(length(panel$shape_chart$competitor_series), 2)
  expect_equal(panel$shape_chart$focal_series$brand_code, "IPK")
  # Focal Aware = 0.9 (matches test_funnel_transactional.R)
  expect_equal(panel$shape_chart$focal_series$pct_values[1],
               0.9, tolerance = 1e-9)
})


test_that("consideration_detail has one entry per brand with 5 attitude segments", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  brands_covered <- vapply(panel$consideration_detail$brands,
                           function(b) b$brand_code, character(1))
  expect_setequal(brands_covered, c("IPK", "ROB", "CART"))
  ipk_entry <- panel$consideration_detail$brands[[which(brands_covered == "IPK")]]
  expect_setequal(names(ipk_entry$segments),
    c("attitude.love","attitude.prefer","attitude.ambivalent",
      "attitude.reject","attitude.no_opinion"))
  # IPK love = 3/10 from fixture (total base: all 10 respondents answer attitude)
  expect_equal(ipk_entry$segments$attitude.love, 3/10, tolerance = 1e-9)
})


test_that("config block carries chip picker defaults, conversion metric, show_counts", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(),
    list(`funnel.conversion_metric` = "ratio", show_counts = TRUE))

  expect_equal(panel$config$conversion_metric, "ratio")
  expect_true(panel$config$show_counts)
  expect_true("IPK" %in% panel$config$chip_picker$default_selection)
  expect_setequal(panel$config$chip_picker$all_brands,
                  c("IPK", "ROB", "CART"))
})


# --- Brand colours tests -------------------------------------------------------

.brand_list_with_colours <- function() {
  data.frame(
    BrandCode  = c("IPK", "ROB", "CART"),
    BrandLabel = c("IPK", "Robertsons", "Cartwright"),
    Colour     = c("#1A5276", "#C0392B", ""),   # CART left blank intentionally
    stringsAsFactors = FALSE
  )
}

test_that("brand_colours map contains only brands with valid hex colours set", {
  result <- .run_fixture()
  panel  <- build_funnel_panel_data(result, .brand_list_with_colours(), list())

  colours <- panel$config$brand_colours
  # IPK and ROB have colours; CART's blank entry must be absent
  expect_equal(colours[["IPK"]],  "#1A5276")
  expect_equal(colours[["ROB"]],  "#C0392B")
  expect_null(colours[["CART"]])
})


test_that("brand_colours map is empty when no Colour column is present", {
  result <- .run_fixture()
  panel  <- build_funnel_panel_data(result, .brand_list(), list())

  expect_equal(length(panel$config$brand_colours), 0L)
})


test_that("invalid hex values in Colour column are silently dropped with a warning", {
  result  <- .run_fixture()
  bl_bad  <- data.frame(
    BrandCode  = c("IPK", "ROB", "CART"),
    BrandLabel = c("IPK", "Robertsons", "Cartwright"),
    Colour     = c("#1A5276", "not-a-colour", "#ZZZ123"),
    stringsAsFactors = FALSE
  )

  panel <- expect_warning(
    build_funnel_panel_data(result, bl_bad, list()),
    regexp = "not a valid hex"
  )
  colours <- panel$config$brand_colours
  expect_equal(colours[["IPK"]], "#1A5276")
  expect_null(colours[["ROB"]])
  expect_null(colours[["CART"]])
})


test_that("about carries canonical methodology, heavy-buyer pointer, and panel-disclosure notes", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_true(nzchar(panel$about$methodology_note))
  expect_true(grepl("nested", panel$about$methodology_note, ignore.case = TRUE))
  expect_true(grepl("non-probability|panel sampling",
                    panel$about$significance_note, ignore.case = TRUE))
  expect_true(grepl("Repertoire|Frequency|heavy",
                    panel$about$heavy_buyer_note, ignore.case = TRUE))
  expect_true(grepl("IPK", panel$about$base_note))
})


test_that("REFUSED result returns an empty but well-formed panel", {
  refused <- list(status = "REFUSED", code = "CFG_FOO")
  panel <- build_funnel_panel_data(refused, .brand_list(), list())
  expect_setequal(names(panel),
    c("meta", "cards", "table", "shape_chart", "consideration_detail",
      "config", "about"))
  expect_equal(length(panel$cards), 0)
  expect_equal(length(panel$table), 0)
})


# --- Legacy-wide adapter tests ----------------------------------------------

test_that("legacy wide adapter produces BrandCode + stage-pct columns", {
  result <- .run_fixture()
  wide <- build_funnel_legacy_wide(result, .brand_list())
  expect_true(all(c("BrandCode","Aware_Pct","Positive_Pct",
                    "Bought_Pct","Primary_Pct",
                    "Love_Pct","Prefer_Pct","Ambivalent_Pct",
                    "Reject_Pct","NoOpinion_Pct")
                  %in% names(wide)))
  # IPK aware = 90% (values in 0-100 range, not 0-1)
  expect_equal(wide$Aware_Pct[wide$BrandCode == "IPK"], 90,
               tolerance = 1e-9)
})


test_that("legacy conversions adapter produces 3-column conversion matrix", {
  result <- .run_fixture()
  conv <- build_funnel_legacy_conversions(result, .brand_list())
  expect_true(all(c("BrandCode", "Aware_to_Positive",
                    "Positive_to_Bought", "Bought_to_Primary")
                  %in% names(conv)))
  expect_equal(nrow(conv), 3)
})
