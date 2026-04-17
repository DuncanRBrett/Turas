# ==============================================================================
# BRAND MODULE TESTS - FUNNEL INTEGRATION (end-to-end)
# ==============================================================================
# Exercises run_brand() against a hand-calculated transactional fixture with
# a real QuestionMap + OptionMap in Survey_Structure.xlsx. Verifies:
#  - end-to-end funnel element populates with the expected stage percentages
#  - weighted parity (weights = 1 matches unweighted)
#  - sig-tester closure adapted from tabs::weighted_z_test_proportions
#    returns the expected shape and populates sig_results on run_funnel().
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
TURAS_ROOT <- .find_turas_root_for_test()

shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_main.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "99_output.R"))


# --- Fixture builder: Brand_Config.xlsx + Survey_Structure.xlsx + data CSV ---

.build_integration_fixtures <- function(tmp_dir) {
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  data_path <- file.path(tmp_dir, "data.csv")
  file.copy(
    from = file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                     "funnel_transactional_10resp.csv"),
    to = data_path, overwrite = TRUE)

  config_path <- file.path(tmp_dir, "Brand_Config.xlsx")
  structure_path <- file.path(tmp_dir, "Survey_Structure.xlsx")

  .write_brand_config(config_path, data_path, structure_path, tmp_dir)
  .write_survey_structure(structure_path)

  list(config_path = config_path, structure_path = structure_path,
       data_path = data_path, tmp_dir = tmp_dir)
}


.write_brand_config <- function(config_path, data_path, structure_path,
                                tmp_dir) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  settings <- data.frame(
    Setting = c("project_name", "client_name", "study_type", "wave",
                "data_file", "respondent_id_col", "focal_brand",
                "focal_assignment",
                "element_funnel", "element_mental_avail", "element_cep_turf",
                "element_repertoire", "element_drivers_barriers",
                "element_dba", "element_portfolio", "element_wom",
                "alpha", "min_base_size", "low_base_warning",
                "colour_focal", "colour_focal_accent",
                "colour_competitor", "colour_category_avg",
                "output_dir", "output_html", "output_excel", "output_csv",
                "structure_file", "show_about_section",
                "dba_fame_threshold", "dba_uniqueness_threshold"),
    Value = c("Integration Test", "Test", "cross-sectional", "1",
              basename(data_path), "Respondent_ID", "IPK",
              "balanced",
              "Y", "N", "N",
              "N", "N",
              "N", "N", "N",
              "0.05", "0", "75",
              "#1A5276", "#2E86C1", "#B0B0B0", "#808080",
              tmp_dir, "N", "N", "N",
              basename(structure_path), "Y",
              "0.5", "0.5"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", settings)

  openxlsx::addWorksheet(wb, "Categories")
  openxlsx::writeData(wb, "Categories", data.frame(
    Category = "FMCG Test",
    Type = "transaction",
    Timeframe_Target = "last month",
    stringsAsFactors = FALSE))

  openxlsx::addWorksheet(wb, "DBA_Assets")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
}


.write_survey_structure <- function(structure_path) {
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Brands")
  openxlsx::writeData(wb, "Brands", data.frame(
    Category = rep("FMCG Test", 3),
    BrandCode = c("IPK", "ROB", "CART"),
    BrandLabel = c("IPK", "Robertsons", "Cartwright"),
    DisplayOrder = 1:3,
    IsFocal = c("Y", "N", "N"),
    stringsAsFactors = FALSE))

  openxlsx::addWorksheet(wb, "CEPs")
  openxlsx::addWorksheet(wb, "Attributes")
  openxlsx::addWorksheet(wb, "DBA_Assets")

  openxlsx::addWorksheet(wb, "QuestionMap")
  openxlsx::writeData(wb, "QuestionMap", data.frame(
    Role = c("funnel.awareness", "funnel.attitude",
             "funnel.transactional.bought_long",
             "funnel.transactional.bought_target",
             "funnel.transactional.frequency",
             "system.respondent.id"),
    ClientCode = c("BRANDAWARE", "QBRANDATT1",
                   "BRANDPENTRANS1", "BRANDPENTRANS2", "BRANDPENTRANS3",
                   "Respondent_ID"),
    QuestionText = c("Which brands have you heard of?",
                     "Attitude toward each brand",
                     "Bought in last 12 months?",
                     "Bought in target timeframe?",
                     "Purchase frequency", "ID"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention", "Single_Response",
                      "Multi_Mention", "Multi_Mention", "Numeric",
                      "Single_Response"),
    ColumnPattern = c("{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}_{brand_code}", "{code}"),
    OptionMapScale = c("", "attitude_scale", "", "", "", ""),
    Notes = NA_character_,
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "OptionMap")
  openxlsx::writeData(wb, "OptionMap", data.frame(
    Scale = rep("attitude_scale", 5),
    ClientCode = as.character(1:5),
    Role = c("attitude.love", "attitude.prefer",
             "attitude.ambivalent", "attitude.reject",
             "attitude.no_opinion"),
    ClientLabel = c("Love", "Prefer", "Ambivalent", "Reject", "No opinion"),
    OrderIndex = 1:5,
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Project")
  openxlsx::writeData(wb, "Project", data.frame(
    Setting = c("project_name", "client_name"),
    Value = c("Integration Test", "Test"), stringsAsFactors = FALSE))

  openxlsx::saveWorkbook(wb, structure_path, overwrite = TRUE)
}


# --- End-to-end: run_brand against the hand-calc fixture ---------------------

test_that("run_brand runs end-to-end against the transactional fixture", {
  tmp_dir <- file.path(tempdir(), "funnel_integration_core")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_integration_fixtures(tmp_dir)

  result <- run_brand(fx$config_path, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))

  cat_result <- result$results$categories[["FMCG Test"]]
  expect_false(is.null(cat_result$funnel))
  expect_equal(cat_result$funnel$status, "PASS")
})


test_that("run_brand produces the hand-calculated stage percentages", {
  tmp_dir <- file.path(tempdir(), "funnel_integration_values")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_integration_fixtures(tmp_dir)

  result <- run_brand(fx$config_path, verbose = FALSE)
  stages <- result$results$categories[["FMCG Test"]]$funnel$stages

  ipk_aware <- stages$pct_weighted[stages$brand_code == "IPK" &
                                     stages$stage_key == "aware"]
  expect_equal(ipk_aware, 0.9, tolerance = 1e-9)

  ipk_target <- stages$pct_weighted[stages$brand_code == "IPK" &
                                      stages$stage_key == "bought_target"]
  expect_equal(ipk_target, 0.5, tolerance = 1e-9)

  cart_target <- stages$pct_weighted[stages$brand_code == "CART" &
                                       stages$stage_key == "bought_target"]
  expect_equal(cart_target, 0.4, tolerance = 1e-9)
})


# --- Weight parity -----------------------------------------------------------

test_that("All-equal weights produce identical stage percentages to unweighted", {
  tmp_dir <- file.path(tempdir(), "funnel_integration_weighted")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_integration_fixtures(tmp_dir)

  # Unweighted run
  res_u <- run_brand(fx$config_path, verbose = FALSE)
  stages_u <- res_u$results$categories[["FMCG Test"]]$funnel$stages

  # Call run_funnel directly with weights = rep(1, n) on the same config
  data <- read.csv(fx$data_path, stringsAsFactors = FALSE)
  structure <- load_brand_survey_structure(fx$structure_path)
  brands <- structure$brands
  role_map <- load_role_map(structure)
  cfg <- list(`category.type` = "transactional", focal_brand = "IPK",
              `funnel.warn_base` = 0, `funnel.suppress_base` = 0,
              `funnel.conversion_metric` = "ratio")
  res_w <- run_funnel(data, role_map, brands, cfg,
                     weights = rep(1, nrow(data)))

  # pct_weighted vectors should match exactly (both are weights=1 calcs)
  expect_equal(sort(stages_u$pct_weighted), sort(res_w$stages$pct_weighted),
               tolerance = 1e-9)
})


# --- Sig-tester closure integration -----------------------------------------

test_that("Sig-tester closure wrapping tabs returns the expected structure", {
  tmp_dir <- file.path(tempdir(), "funnel_integration_sigtest")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_integration_fixtures(tmp_dir)

  # Build a closure adapting tabs' weighted_z_test_proportions to the
  # sig_tester interface run_funnel expects. tabs uses (x = count, n = base)
  # with is_weighted = FALSE; brand passes the same.
  sig_tester <- function(x1, n1, x2, n2, alpha = 0.05) {
    if (is.na(n1) || is.na(n2) || n1 == 0 || n2 == 0) {
      return(list(p_value = NA_real_, significant = FALSE, direction = "na"))
    }
    r <- weighted_z_test_proportions(
      count1 = x1, base1 = n1, count2 = x2, base2 = n2,
      is_weighted = FALSE, min_base = 1, alpha = alpha)
    direction <- if (isTRUE(r$significant)) {
      if (isTRUE(r$higher)) "higher" else "lower"
    } else "not_sig"
    list(p_value = r$p_value, significant = isTRUE(r$significant),
         direction = direction)
  }

  data <- read.csv(fx$data_path, stringsAsFactors = FALSE)
  structure <- load_brand_survey_structure(fx$structure_path)
  role_map <- load_role_map(structure)
  cfg <- list(`category.type` = "transactional", focal_brand = "IPK",
              `funnel.warn_base` = 0, `funnel.suppress_base` = 0,
              `funnel.conversion_metric` = "ratio",
              `funnel.significance_level` = 0.05)

  res <- run_funnel(data, role_map, structure$brands, cfg,
                   sig_tester = sig_tester)

  expect_true(is.data.frame(res$sig_results))
  expect_true(nrow(res$sig_results) > 0)
  expect_true(all(c("stage_key", "brand_code", "comparison",
                    "direction", "p_value", "significant")
                  %in% names(res$sig_results)))
  expect_true(all(res$sig_results$comparison %in%
                    c("focal_vs_competitor", "focal_vs_cat_avg",
                      "brand_vs_cat_avg")))
  # Per-cell sig_vs_avg is emitted for every brand, not only focal.
  brand_vs_avg <- res$sig_results[res$sig_results$comparison ==
                                    "brand_vs_cat_avg", , drop = FALSE]
  expect_true(nrow(brand_vs_avg) > 0)
  expect_setequal(unique(brand_vs_avg$brand_code),
                  as.character(structure$brands$BrandCode))
})


test_that("generate_brand_csv produces the dedicated funnel Excel + long CSV", {
  tmp_dir <- file.path(tempdir(), "funnel_integration_outputs")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_integration_fixtures(tmp_dir)

  result <- run_brand(fx$config_path, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))

  out_dir <- file.path(tmp_dir, "outputs")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  # The combined brand CSV entry point also triggers the dedicated
  # funnel workbook + long CSV via 99_output.R's funnel branch.
  generate_brand_csv(result, out_dir, result$config)

  xlsx_files <- list.files(out_dir, pattern = "^funnel_.*\\.xlsx$",
                           recursive = TRUE)
  csv_files <- list.files(out_dir, pattern = "^funnel_.*_long\\.csv$",
                          recursive = TRUE)
  expect_true(length(xlsx_files) >= 1,
              info = paste("Expected a funnel_<cat>.xlsx in", out_dir))
  expect_true(length(csv_files) >= 1,
              info = paste("Expected a funnel_<cat>_long.csv in", out_dir))
})
