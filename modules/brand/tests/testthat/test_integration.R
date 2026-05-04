# ==============================================================================
# BRAND MODULE TESTS - INTEGRATION
# ==============================================================================
# End-to-end tests that exercise the full run_brand() pipeline with
# synthetic data, config files, and survey structure.

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

# Source all shared infrastructure
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# Source TURF engine
source(file.path(TURAS_ROOT, "modules", "shared", "lib", "turf_engine.R"))

# Source template styles
source(file.path(TURAS_ROOT, "modules", "shared", "template_styles.R"))

# Source all brand module files
brand_r_dir <- file.path(TURAS_ROOT, "modules", "brand", "R")
assign("brand_script_dir_override", brand_r_dir, envir = globalenv())

brand_files <- c("00_guard.R", "01_config.R", "02_mental_availability.R",
                 "03_funnel.R", "04_repertoire.R", "05_wom.R",
                 "generate_config_templates.R", "00_main.R")
for (f in brand_files) {
  fpath <- file.path(brand_r_dir, f)
  if (file.exists(fpath)) {
    tryCatch(source(fpath, local = FALSE), error = function(e) {
      message(sprintf("Warning: could not source %s: %s", f, e$message))
    })
  }
}


# --- Integration fixture generator ---
# Creates a complete test environment: config files + synthetic survey data

.create_integration_fixtures <- function(tmp_dir = tempdir(),
                                          n_resp = 200, seed = 42) {
  set.seed(seed)

  config_path <- file.path(tmp_dir, "Brand_Config.xlsx")
  structure_path <- file.path(tmp_dir, "Survey_Structure.xlsx")
  data_path <- file.path(tmp_dir, "survey_data.csv")

  brands <- c("IPK", "ROB", "KNO")
  ceps <- paste0("CEP", sprintf("%02d", 1:5))
  categories <- c("Dry Seasonings & Spices")

  # --- Generate survey data ---
  data <- data.frame(
    Respondent_ID = seq_len(n_resp),
    stringsAsFactors = FALSE
  )

  for (brand in brands) {
    size <- switch(brand, IPK = 0.7, ROB = 0.5, KNO = 0.3, 0.4)

    # Awareness
    data[[paste0("AWARE_DSS_", brand)]] <- rbinom(n_resp, 1, size)

    # CEP matrix (multi-mention: 1/0 per CEP per brand)
    for (cep in ceps) {
      prob <- size * runif(1, 0.15, 0.40)
      data[[paste0(cep, "_", brand)]] <- rbinom(n_resp, 1, prob)
    }

    # Attitude (1-5 among aware)
    att <- rep(NA_integer_, n_resp)
    aware <- data[[paste0("AWARE_DSS_", brand)]]
    for (r in which(aware == 1)) {
      att[r] <- sample(1:5, 1, prob = c(size * 0.3, 0.25, 0.2, 0.05, 0.2))
    }
    data[[paste0("ATT_DSS_", brand)]] <- att

    # Penetration (among aware + positive)
    pen <- rep(0L, n_resp)
    for (r in seq_len(n_resp)) {
      if (aware[r] == 1 && !is.na(att[r]) && att[r] <= 3) {
        pen[r] <- rbinom(1, 1, size * 0.5)
      }
    }
    data[[paste0("PEN_DSS_", brand)]] <- pen

    # WOM
    data[[paste0("WOM_POS_REC_", brand)]] <- rbinom(n_resp, 1, 0.12)
    data[[paste0("WOM_NEG_REC_", brand)]] <- rbinom(n_resp, 1, 0.04)
    data[[paste0("WOM_POS_SHARE_", brand)]] <- rbinom(n_resp, 1, 0.08)
    data[[paste0("WOM_NEG_SHARE_", brand)]] <- rbinom(n_resp, 1, 0.02)
  }

  write.csv(data, data_path, row.names = FALSE)

  # --- Create Brand_Config.xlsx ---
  wb_cfg <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb_cfg, "Settings")
  settings <- data.frame(
    Setting = c("project_name", "client_name", "study_type", "wave",
                "data_file", "focal_brand", "focal_assignment",
                "element_funnel", "element_mental_avail", "element_cep_turf",
                "element_repertoire", "element_drivers_barriers",
                "element_dba", "element_portfolio", "element_wom",
                "output_dir", "structure_file",
                "alpha", "min_base_size", "low_base_warning"),
    Value = c("Integration Test", "Test Client", "cross-sectional", "1",
              "survey_data.csv", "IPK", "balanced",
              "Y", "Y", "Y", "Y", "N", "N", "N", "Y",
              "output", "Survey_Structure.xlsx",
              "0.05", "30", "75"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_cfg, "Settings", settings)

  openxlsx::addWorksheet(wb_cfg, "Categories")
  cats <- data.frame(
    Category = "Dry Seasonings & Spices",
    CategoryCode = "DSS",
    Active = "Y",
    Type = "transactional",
    Analysis_Depth = "full",
    Timeframe_Long = "12 months",
    Timeframe_Target = "3 months",
    Focal_Weight = 1.0,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_cfg, "Categories", cats)
  openxlsx::addWorksheet(wb_cfg, "DBA_Assets")
  openxlsx::saveWorkbook(wb_cfg, config_path, overwrite = TRUE)

  # --- Create Survey_Structure.xlsx ---
  wb_ss <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb_ss, "Project")
  openxlsx::writeData(wb_ss, "Project", data.frame(
    Setting = c("project_name", "data_file", "client_name", "focal_brand"),
    Value = c("Integration Test", data_path, "Test Client", "IPK"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb_ss, "Questions")
  questions <- data.frame(
    QuestionCode = c("AWARE_DSS", paste0("CEP0", 1:5),
                     "ATT_DSS", "PEN_DSS",
                     "WOM_POS_REC", "WOM_NEG_REC",
                     "WOM_POS_SHARE", "WOM_NEG_SHARE"),
    QuestionText = c("Brands heard of",
                     paste("CEP", 1:5),
                     "Brand attitude", "Brands bought",
                     "Received positive WOM", "Received negative WOM",
                     "Shared positive WOM", "Shared negative WOM"),
    Variable_Type = c("Multi_Mention", rep("Multi_Mention", 5),
                      "Single_Mention", "Multi_Mention",
                      rep("Multi_Mention", 4)),
    Category = c(rep("Dry Seasonings & Spices", 8), rep("ALL", 4)),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "Questions", questions)

  openxlsx::addWorksheet(wb_ss, "Options")
  openxlsx::writeData(wb_ss, "Options", data.frame(
    QuestionCode = rep("ATT_DSS", 5),
    OptionText = as.character(1:5),
    DisplayText = c("Love", "Prefer", "Ambivalent", "Reject", "No opinion"),
    DisplayOrder = 1:5, ShowInOutput = rep("Y", 5),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb_ss, "Brands")
  openxlsx::writeData(wb_ss, "Brands", data.frame(
    Category = rep("Dry Seasonings & Spices", 3),
    BrandCode = c("IPK", "ROB", "KNO"),
    BrandLabel = c("IPK", "Robertsons", "Knorr"),
    DisplayOrder = 1:3,
    IsFocal = c("Y", "N", "N"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb_ss, "CEPs")
  openxlsx::writeData(wb_ss, "CEPs", data.frame(
    Category = rep("Dry Seasonings & Spices", 5),
    CEPCode = ceps,
    CEPText = paste("When I", c("want great flavour", "cook for family",
                                 "want healthy food", "cook on budget",
                                 "entertain guests")),
    DisplayOrder = 1:5,
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb_ss, "Attributes")
  openxlsx::writeData(wb_ss, "Attributes", data.frame(
    Category = "Dry Seasonings & Spices",
    AttrCode = "ATTR01", AttrText = "Good value",
    DisplayOrder = 1, stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb_ss, "DBA_Assets")

  # QuestionMap (role-registry architecture; see ROLE_REGISTRY.md)
  openxlsx::addWorksheet(wb_ss, "QuestionMap")
  openxlsx::writeData(wb_ss, "QuestionMap", data.frame(
    Role = c("funnel.awareness", "funnel.attitude",
             "funnel.transactional.bought_target",
             "system.respondent.id"),
    ClientCode = c("AWARE_DSS", "ATT_DSS", "PEN_DSS", "Respondent_ID"),
    QuestionText = c("Which brands?", "Attitude?",
                     "Bought in last month?", "Respondent identifier"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention", "Single_Response",
                      "Multi_Mention", "Single_Response"),
    ColumnPattern = c("{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}_{brand_code}", "{code}"),
    OptionMapScale = c("", "attitude_scale", "", ""),
    Notes = NA_character_,
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb_ss, "OptionMap")
  openxlsx::writeData(wb_ss, "OptionMap", data.frame(
    Scale = rep("attitude_scale", 5),
    ClientCode = as.character(1:5),
    Role = c("attitude.love", "attitude.prefer", "attitude.ambivalent",
             "attitude.reject", "attitude.no_opinion"),
    ClientLabel = c("Love", "Prefer", "Ambivalent", "Reject", "No opinion"),
    OrderIndex = 1:5,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb_ss, structure_path, overwrite = TRUE)

  list(config_path = config_path, structure_path = structure_path,
       data_path = data_path, tmp_dir = tmp_dir)
}


# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("run_brand completes successfully with synthetic data", {
  tmp_dir <- file.path(tempdir(), "brand_integration_1")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  fixtures <- .create_integration_fixtures(tmp_dir)

  result <- run_brand(fixtures$config_path, verbose = FALSE)

  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_true(is.list(result$config))
  expect_true(is.list(result$results))
  expect_true(is.numeric(result$elapsed_seconds))
})


test_that("run_brand includes Repertoire results", {
  tmp_dir <- file.path(tempdir(), "brand_integration_rep")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  fixtures <- .create_integration_fixtures(tmp_dir)
  result <- run_brand(fixtures$config_path, verbose = FALSE)

  cat_results <- result$results$categories[["Dry Seasonings & Spices"]]
  expect_true(!is.null(cat_results$repertoire))

  rep <- cat_results$repertoire
  expect_true(rep$status %in% c("PASS", "REFUSED"))
})

test_that("run_brand includes WOM results (per-category)", {
  tmp_dir <- file.path(tempdir(), "brand_integration_wom")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  fixtures <- .create_integration_fixtures(tmp_dir)
  result <- run_brand(fixtures$config_path, verbose = FALSE)

  # WOM is per-category (each category has its own brand list and respondent group)
  cat_results <- result$results$categories[["Dry Seasonings & Spices"]]
  expect_true(!is.null(cat_results$wom))
  wom <- cat_results$wom
  expect_true(wom$status %in% c("PASS", "PARTIAL", "REFUSED"))
  if (wom$status != "REFUSED") {
    expect_true(is.data.frame(wom$wom_metrics))
    expect_equal(nrow(wom$wom_metrics), 3)  # 3 brands
  }
})

test_that("run_brand refuses non-existent config file", {
  result <- tryCatch(
    run_brand("/nonexistent/Brand_Config.xlsx", verbose = FALSE),
    error = function(e) list(status = "REFUSED")
  )
  expect_equal(result$status, "REFUSED")
})

test_that("run_brand config is loaded correctly", {
  tmp_dir <- file.path(tempdir(), "brand_integration_config")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  fixtures <- .create_integration_fixtures(tmp_dir)
  result <- run_brand(fixtures$config_path, verbose = FALSE)

  expect_equal(result$config$project_name, "Integration Test")
  expect_equal(result$config$focal_brand, "IPK")
  expect_true(result$config$element_funnel)
  expect_true(result$config$element_mental_avail)
  expect_false(result$config$element_dba)
})

test_that("run_brand structure is loaded correctly", {
  tmp_dir <- file.path(tempdir(), "brand_integration_struct")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  fixtures <- .create_integration_fixtures(tmp_dir)
  result <- run_brand(fixtures$config_path, verbose = FALSE)

  expect_true(is.data.frame(result$structure$brands))
  expect_true(is.data.frame(result$structure$ceps))
  expect_equal(nrow(result$structure$brands), 3)
  expect_equal(nrow(result$structure$ceps), 5)
})

test_that("run_brand completes in reasonable time", {
  skip_on_cran()

  tmp_dir <- file.path(tempdir(), "brand_integration_perf")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  fixtures <- .create_integration_fixtures(tmp_dir, n_resp = 500)
  result <- run_brand(fixtures$config_path, verbose = FALSE)

  expect_true(result$elapsed_seconds < 30)
})
