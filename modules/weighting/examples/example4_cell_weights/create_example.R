# ==============================================================================
# EXAMPLE 4: CREATE CELL WEIGHT EXAMPLE DATA AND CONFIG
# ==============================================================================
# Generates synthetic consumer panel data with skewed Gender x Age distribution,
# plus a Weight_Config.xlsx configured for cell (interlocked) weighting.
# ==============================================================================

create_cell_weight_example <- function() {

  example_dir <- dirname(sys.frame(1)$ofile)
  if (is.null(example_dir) || !nzchar(example_dir)) {
    example_dir <- "modules/weighting/examples/example4_cell_weights"
  }

  # Create directories
  dir.create(file.path(example_dir, "data"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(example_dir, "output"), recursive = TRUE, showWarnings = FALSE)

  # --- Generate survey data with skewed Gender x Age ---
  set.seed(2026)
  n <- 300

  # Skewed sample: young males under-represented, older females over-represented
  gender_probs <- c(Male = 0.42, Female = 0.58)
  age_probs_male <- c("18-34" = 0.15, "35-54" = 0.45, "55+" = 0.40)
  age_probs_female <- c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25)

  genders <- sample(c("Male", "Female"), n, replace = TRUE, prob = gender_probs)
  ages <- character(n)
  for (i in seq_len(n)) {
    if (genders[i] == "Male") {
      ages[i] <- sample(c("18-34", "35-54", "55+"), 1, prob = age_probs_male)
    } else {
      ages[i] <- sample(c("18-34", "35-54", "55+"), 1, prob = age_probs_female)
    }
  }

  data <- data.frame(
    id = seq_len(n),
    Gender = genders,
    Age = ages,
    Satisfaction = sample(1:10, n, replace = TRUE),
    NPS = sample(0:10, n, replace = TRUE),
    stringsAsFactors = FALSE
  )

  data_path <- file.path(example_dir, "data", "consumer_panel.csv")
  write.csv(data, data_path, row.names = FALSE)
  message("Data written: ", data_path)

  # --- Create Weight_Config.xlsx ---
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required to create config")
  }

  wb <- openxlsx::createWorkbook()
  headerStyle <- openxlsx::createStyle(
    fontColour = "#FFFFFF", fgFill = "#4472C4",
    halign = "center", textDecoration = "bold"
  )

  # General
  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name", "data_file", "output_file",
                "save_diagnostics", "diagnostics_file",
                "html_report", "html_report_file"),
    Value = c("Cell Weight Example", "data/consumer_panel.csv",
              "output/consumer_panel_weighted.csv",
              "Y", "output/diagnostics.xlsx",
              "Y", "output/weighting_report.html"),
    stringsAsFactors = FALSE
  ))
  openxlsx::addStyle(wb, "General", headerStyle, rows = 1, cols = 1:2, gridExpand = TRUE)

  # Weight_Specifications
  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", data.frame(
    weight_name = "cell_weight",
    method = "cell",
    description = "Gender x Age interlocked weights",
    apply_trimming = "N",
    trim_method = NA,
    trim_value = NA,
    stringsAsFactors = FALSE
  ))
  openxlsx::addStyle(wb, "Weight_Specifications", headerStyle, rows = 1, cols = 1:6, gridExpand = TRUE)

  # Cell_Targets (population proportions from census)
  openxlsx::addWorksheet(wb, "Cell_Targets")
  openxlsx::writeData(wb, "Cell_Targets", data.frame(
    weight_name = rep("cell_weight", 6),
    Gender = rep(c("Male", "Female"), each = 3),
    Age = rep(c("18-34", "35-54", "55+"), 2),
    target_percent = c(14.5, 19.4, 14.6, 15.5, 20.6, 15.4),
    stringsAsFactors = FALSE
  ))
  openxlsx::addStyle(wb, "Cell_Targets", headerStyle, rows = 1, cols = 1:4, gridExpand = TRUE)

  # Notes
  openxlsx::addWorksheet(wb, "Notes")
  openxlsx::writeData(wb, "Notes", data.frame(
    Section = c("Assumptions", "Methodology"),
    Note = c(
      "Population targets from 2025 census cross-tabulations",
      "Cell weighting chosen because young males are specifically under-represented"
    ),
    stringsAsFactors = FALSE
  ))
  openxlsx::addStyle(wb, "Notes", headerStyle, rows = 1, cols = 1:2, gridExpand = TRUE)

  config_path <- file.path(example_dir, "Weight_Config.xlsx")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  message("Config written: ", config_path)

  message("\nExample 4 ready! Run with:")
  message('  result <- run_weighting("', config_path, '")')

  invisible(list(data_path = data_path, config_path = config_path))
}

# Auto-run when sourced
create_cell_weight_example()
