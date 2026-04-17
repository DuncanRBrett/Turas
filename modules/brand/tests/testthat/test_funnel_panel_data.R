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
  expect_equal(panel$meta$stage_count, 5)
  expect_equal(panel$meta$n_unweighted, 10)
  expect_setequal(panel$meta$stage_keys,
    c("aware","consideration","bought_long","bought_target","preferred"))
  expect_equal(panel$meta$stage_labels[["aware"]], "Aware")
  expect_equal(panel$meta$stage_labels[["preferred"]], "Preferred")
})


test_that("cards carry focal pct, category-avg pct, and warning flag per stage", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())
  expect_equal(length(panel$cards), 5)

  aware_card <- panel$cards[[1]]
  expect_equal(aware_card$stage_key, "aware")
  expect_equal(aware_card$focal_pct, 0.9, tolerance = 1e-9)
  # Category average (excluding focal) = mean(ROB 0.8, CART 0.7) = 0.75
  expect_equal(aware_card$cat_avg_pct, 0.75, tolerance = 1e-9)
  expect_true(aware_card$warning_flag %in% c("none","warn","suppress"))
})


test_that("table cells cover every (stage, brand) pair", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_equal(length(panel$table$stage_keys), 5)
  expect_equal(length(panel$table$brand_codes), 3)
  # 5 stages x 3 brands = 15 cells
  expect_equal(length(panel$table$cells), 15)

  # Spot-check: IPK aware cell pct = 0.9
  ipk_aware <- Filter(function(c)
    c$stage_key == "aware" && c$brand_code == "IPK", panel$table$cells)[[1]]
  expect_equal(ipk_aware$pct, 0.9, tolerance = 1e-9)
  expect_equal(ipk_aware$sig_vs_focal, "focal")
})


test_that("shape_chart series have one pct per stage per brand", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_equal(length(panel$shape_chart$focal_series$pct_values), 5)
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
  # IPK love = 3/9 from fixture (R1, R6, R10 are Love among 9 aware respondents)
  expect_equal(ipk_entry$segments$attitude.love, 3/9, tolerance = 1e-9)
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


test_that("about carries canonical methodology, ties, and panel-disclosure notes", {
  result <- .run_fixture()
  panel <- build_funnel_panel_data(result, .brand_list(), list())

  expect_true(nzchar(panel$about$methodology_note))
  expect_true(grepl("nested", panel$about$methodology_note, ignore.case = TRUE))
  expect_true(grepl("non-probability|panel sampling",
                    panel$about$significance_note, ignore.case = TRUE))
  expect_true(grepl("ties", panel$about$ties_note, ignore.case = TRUE))
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
