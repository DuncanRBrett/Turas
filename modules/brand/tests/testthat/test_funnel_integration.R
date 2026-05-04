# ==============================================================================
# BRAND MODULE TESTS — FUNNEL INTEGRATION (end-to-end) — v2 port
# ==============================================================================
# Exercises run_brand() against a hand-calculated transactional fixture using
# v2-format config files (Questions sheet, CategoryCode in Categories). Also
# directly tests run_funnel() for weight parity and sig-tester closure
# integration (no run_brand() round-trip needed for those checks).
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
source(file.path(ROOT, "modules", "brand", "R", "00_main.R"))
source(file.path(ROOT, "modules", "brand", "R", "99_output.R"))


# ==============================================================================
# Shared fixture helpers (manual role map — for direct run_funnel() tests)
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
    "funnel.transactional.bought_long"   = pl,
    "funnel.transactional.bought_target" = pt
  )
}

.trans_cfg <- function(...) {
  defaults <- list(`category.type` = "transactional", focal_brand = "IPK",
                   `funnel.conversion_metric` = "ratio",
                   `funnel.warn_base` = 0, `funnel.suppress_base` = 0,
                   `funnel.significance_level` = 0.05)
  modifyList(defaults, list(...))
}


# ==============================================================================
# v2-format fixture builders (for run_brand() end-to-end tests)
# ==============================================================================

.write_v2_data <- function(path) {
  write.csv(.trans_data(), path, row.names = FALSE)
}

.write_v2_brand_config <- function(config_path, data_file, structure_file,
                                   output_dir) {
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("project_name", "client_name", "study_type", "wave",
                "data_file", "respondent_id_col", "focal_brand",
                "element_funnel", "element_mental_avail", "element_cep_turf",
                "element_repertoire", "element_drivers_barriers",
                "element_dba", "element_portfolio", "element_wom",
                "element_branded_reach", "element_demographics",
                "element_adhoc", "element_audience_lens",
                "alpha", "min_base_size", "low_base_warning",
                "output_dir", "output_html", "output_excel", "output_csv",
                "structure_file"),
    Value = c("Integration Test", "Test", "cross-sectional", "1",
              data_file, "Respondent_ID", "IPK",
              "Y", "N", "N", "N", "N", "N", "N", "N", "N", "N", "N", "N",
              "0.05", "0", "75",
              output_dir, "N", "N", "N",
              structure_file),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Categories")
  openxlsx::writeData(wb, "Categories", data.frame(
    Category     = "FMCG Test",
    CategoryCode = "TSX",
    Active       = "Y",
    Type         = "transactional",
    Analysis_Depth   = "full",
    Timeframe_Long   = "12 months",
    Timeframe_Target = "last month",
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "DBA_Assets")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
}

.write_v2_survey_structure <- function(structure_path) {
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", data.frame(
    QuestionCode  = c("BRANDAWARE_TSX",
                      "BRANDATT1_TSX_IPK", "BRANDATT1_TSX_ROB",
                      "BRANDATT1_TSX_CART",
                      "BRANDPEN1_TSX", "BRANDPEN2_TSX"),
    QuestionText  = c("Brand awareness",
                      "Attitude — IPK", "Attitude — ROB",
                      "Attitude — CART",
                      "Penetration 12m", "Penetration target"),
    Variable_Type = c("Multi_Mention",
                      "Single_Response", "Single_Response",
                      "Single_Response",
                      "Multi_Mention", "Multi_Mention"),
    Columns       = c(3L, 1L, 1L, 1L, 2L, 2L),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Brands")
  openxlsx::writeData(wb, "Brands", data.frame(
    Category     = rep("FMCG Test", 3),
    CategoryCode = rep("TSX", 3),
    BrandCode    = c("IPK","ROB","CART"),
    BrandLabel   = c("IPK","Robertsons","Cartwright"),
    DisplayOrder = 1:3,
    IsFocal      = c("Y","N","N"),
    stringsAsFactors = FALSE
  ))

  for (sheet in c("CEPs", "Attributes", "DBA_Assets")) {
    openxlsx::addWorksheet(wb, sheet)
  }

  openxlsx::addWorksheet(wb, "Project")
  openxlsx::writeData(wb, "Project", data.frame(
    Setting = c("project_name", "client_name"),
    Value   = c("Integration Test", "Test"),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, structure_path, overwrite = TRUE)
}

.build_v2_fixtures <- function(tmp_dir) {
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  data_file      <- "data.csv"
  structure_file <- "Survey_Structure.xlsx"
  config_path    <- file.path(tmp_dir, "Brand_Config.xlsx")
  data_path      <- file.path(tmp_dir, data_file)
  structure_path <- file.path(tmp_dir, structure_file)
  output_dir     <- file.path(tmp_dir, "output")

  .write_v2_data(data_path)
  .write_v2_survey_structure(structure_path)
  .write_v2_brand_config(config_path, data_file, structure_file, "output")

  list(config_path = config_path, data_path = data_path,
       structure_path = structure_path, output_dir = output_dir,
       tmp_dir = tmp_dir)
}


# ==============================================================================
# End-to-end: run_brand against the v2 transactional fixture
# ==============================================================================

test_that("run_brand runs end-to-end against the v2 transactional fixture", {
  tmp_dir <- file.path(tempdir(), "funnel_int_core")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_v2_fixtures(tmp_dir)

  result <- run_brand(fx$config_path, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))

  cat_result <- result$results$categories[["FMCG Test"]]
  expect_false(is.null(cat_result$funnel))
  expect_equal(cat_result$funnel$status, "PASS")
})


test_that("run_brand produces the hand-calculated stage percentages", {
  tmp_dir <- file.path(tempdir(), "funnel_int_vals")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_v2_fixtures(tmp_dir)

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


# ==============================================================================
# Weight parity (direct run_funnel — no run_brand round-trip needed)
# ==============================================================================

test_that("All-equal weights produce identical stage percentages to unweighted", {
  data <- .trans_data()
  rm   <- .trans_rm()
  bl   <- .trans_brands()
  cfg  <- .trans_cfg()

  res_u <- run_funnel(data, rm, bl, cfg)
  res_w <- run_funnel(data, rm, bl, cfg, weights = rep(1, nrow(data)))

  expect_equal(sort(res_u$stages$pct_weighted),
               sort(res_w$stages$pct_weighted),
               tolerance = 1e-9)
  expect_equal(sort(res_u$stages$base_weighted),
               sort(res_w$stages$base_weighted),
               tolerance = 1e-9)
})


# ==============================================================================
# Sig-tester closure integration (direct run_funnel)
# ==============================================================================

test_that("Sig-tester closure returns the expected structure", {
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

  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(),
                    .trans_cfg(), sig_tester = sig_tester)

  expect_true(is.data.frame(res$sig_results))
  expect_true(nrow(res$sig_results) > 0)
  expect_true(all(c("stage_key", "brand_code", "comparison",
                    "direction", "p_value", "significant") %in%
                  names(res$sig_results)))
  expect_true(all(res$sig_results$comparison %in%
                    c("focal_vs_competitor", "focal_vs_cat_avg",
                      "brand_vs_cat_avg")))
  brand_vs_avg <- res$sig_results[
    res$sig_results$comparison == "brand_vs_cat_avg", , drop = FALSE]
  expect_true(nrow(brand_vs_avg) > 0)
  expect_setequal(unique(brand_vs_avg$brand_code),
                  c("IPK","ROB","CART"))
})


# ==============================================================================
# generate_brand_csv outputs (end-to-end via run_brand)
# ==============================================================================

test_that("generate_brand_csv produces funnel Excel + long CSV files", {
  tmp_dir <- file.path(tempdir(), "funnel_int_outputs")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  fx <- .build_v2_fixtures(tmp_dir)

  result <- run_brand(fx$config_path, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))

  out_dir <- file.path(tmp_dir, "exports")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  generate_brand_csv(result, out_dir, result$config)

  xlsx_files <- list.files(out_dir, pattern = "^funnel_.*\\.xlsx$",
                           recursive = TRUE)
  csv_files <- list.files(out_dir, pattern = "^funnel_.*_long\\.csv$",
                          recursive = TRUE)
  expect_true(length(xlsx_files) >= 1,
              info = paste("Expected funnel_*.xlsx in", out_dir))
  expect_true(length(csv_files) >= 1,
              info = paste("Expected funnel_*_long.csv in", out_dir))
})
