# ==============================================================================
# WEIGHTING TEST DATA GENERATORS
# ==============================================================================
# Provides functions to create synthetic survey data and config files
# for testing the weighting module.
# ==============================================================================

#' Create Simple Survey Data
#'
#' Generates a synthetic survey data frame with known demographic distributions.
#'
#' @param n Integer, number of respondents (default: 200)
#' @param seed Integer, random seed for reproducibility (default: 42)
#' @return Data frame with columns: id, Gender, Age, Region, Satisfaction
#' @export
create_simple_survey <- function(n = 200, seed = 42) {
  set.seed(seed)

  data.frame(
    id = seq_len(n),
    Gender = sample(c("Male", "Female"), n, replace = TRUE,
                    prob = c(0.55, 0.45)),  # Skewed from 50/50
    Age = sample(c("18-34", "35-54", "55+"), n, replace = TRUE,
                 prob = c(0.40, 0.35, 0.25)),  # Skewed from population
    Region = sample(c("North", "South", "East", "West"), n, replace = TRUE,
                    prob = c(0.30, 0.25, 0.25, 0.20)),
    Satisfaction = sample(1:5, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
}

#' Create Design Weight Config File
#'
#' Creates a Weight_Config.xlsx for design weight testing.
#'
#' @param data_path Character, path to survey data file
#' @param output_dir Character, directory for output files
#' @param output_file Character, optional output data file path
#' @return Character, path to created config file
#' @export
create_design_weight_config <- function(data_path, output_dir = tempdir(),
                                        output_file = NULL) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required for test config generation")
  }

  config_path <- file.path(output_dir, "test_design_config.xlsx")

  wb <- openxlsx::createWorkbook()

  # General sheet
  openxlsx::addWorksheet(wb, "General")
  general <- data.frame(
    Setting = c("project_name", "data_file", "output_file",
                "save_diagnostics", "diagnostics_file"),
    Value = c("Test Design Weights", data_path,
              if (!is.null(output_file)) output_file else "",
              "N", ""),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "General", general)

  # Weight_Specifications sheet
  openxlsx::addWorksheet(wb, "Weight_Specifications")
  specs <- data.frame(
    weight_name = "design_weight",
    method = "design",
    description = "Test design weight",
    apply_trimming = "N",
    trim_method = NA,
    trim_value = NA,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Weight_Specifications", specs)

  # Design_Targets sheet
  openxlsx::addWorksheet(wb, "Design_Targets")
  targets <- data.frame(
    weight_name = rep("design_weight", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Design_Targets", targets)

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  return(config_path)
}

#' Create Rim Weight Config File
#'
#' Creates a Weight_Config.xlsx for rim weight testing.
#'
#' @param data_path Character, path to survey data file
#' @param output_dir Character, directory for output files
#' @return Character, path to created config file
#' @export
create_rim_weight_config <- function(data_path, output_dir = tempdir()) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required for test config generation")
  }

  config_path <- file.path(output_dir, "test_rim_config.xlsx")

  wb <- openxlsx::createWorkbook()

  # General sheet
  openxlsx::addWorksheet(wb, "General")
  general <- data.frame(
    Setting = c("project_name", "data_file", "save_diagnostics"),
    Value = c("Test Rim Weights", data_path, "N"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "General", general)

  # Weight_Specifications sheet
  openxlsx::addWorksheet(wb, "Weight_Specifications")
  specs <- data.frame(
    weight_name = "rim_weight",
    method = "rim",
    description = "Test rim weight",
    apply_trimming = "N",
    trim_method = NA,
    trim_value = NA,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Weight_Specifications", specs)

  # Rim_Targets sheet
  openxlsx::addWorksheet(wb, "Rim_Targets")
  targets <- data.frame(
    weight_name = rep("rim_weight", 5),
    variable = c("Gender", "Gender", "Age", "Age", "Age"),
    category = c("Male", "Female", "18-34", "35-54", "55+"),
    target_percent = c(48, 52, 30, 40, 30),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Rim_Targets", targets)

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  return(config_path)
}

#' Create Combined Weight Config File
#'
#' Creates a config with both design and rim weights.
#'
#' @param data_path Character, path to survey data file
#' @param output_dir Character, directory for output files
#' @return Character, path to created config file
#' @export
create_combined_config <- function(data_path, output_dir = tempdir()) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required for test config generation")
  }

  config_path <- file.path(output_dir, "test_combined_config.xlsx")

  wb <- openxlsx::createWorkbook()

  # General sheet
  openxlsx::addWorksheet(wb, "General")
  general <- data.frame(
    Setting = c("project_name", "data_file", "save_diagnostics"),
    Value = c("Test Combined Weights", data_path, "N"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "General", general)

  # Weight_Specifications sheet
  openxlsx::addWorksheet(wb, "Weight_Specifications")
  specs <- data.frame(
    weight_name = c("design_weight", "rim_weight"),
    method = c("design", "rim"),
    description = c("Design weight", "Rim weight"),
    apply_trimming = c("N", "N"),
    trim_method = c(NA, NA),
    trim_value = c(NA, NA),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Weight_Specifications", specs)

  # Design_Targets sheet
  openxlsx::addWorksheet(wb, "Design_Targets")
  targets <- data.frame(
    weight_name = rep("design_weight", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Design_Targets", targets)

  # Rim_Targets sheet
  openxlsx::addWorksheet(wb, "Rim_Targets")
  rim_targets <- data.frame(
    weight_name = rep("rim_weight", 5),
    variable = c("Gender", "Gender", "Age", "Age", "Age"),
    category = c("Male", "Female", "18-34", "35-54", "55+"),
    target_percent = c(48, 52, 30, 40, 30),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Rim_Targets", rim_targets)

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  return(config_path)
}

#' Create Config with Missing Sheet
#'
#' Creates an invalid config for error testing.
#'
#' @param output_dir Character, directory for config file
#' @return Character, path to created config file
#' @export
create_bad_config_missing_sheet <- function(output_dir = tempdir()) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required for test config generation")
  }

  config_path <- file.path(output_dir, "test_bad_missing_sheet.xlsx")

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name", "data_file"),
    Value = c("Test", "nonexistent.csv"),
    stringsAsFactors = FALSE
  ))
  # Missing Weight_Specifications sheet
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  return(config_path)
}

#' Create Config with Bad Rim Targets
#'
#' Creates a config where rim targets don't sum to 100.
#'
#' @param data_path Character, path to survey data file
#' @param output_dir Character, directory for config file
#' @return Character, path to created config file
#' @export
create_bad_config_rim_sum <- function(data_path, output_dir = tempdir()) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required for test config generation")
  }

  config_path <- file.path(output_dir, "test_bad_rim_sum.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name", "data_file", "save_diagnostics"),
    Value = c("Test Bad Rim", data_path, "N"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", data.frame(
    weight_name = "bad_rim",
    method = "rim",
    description = "Bad rim weight",
    apply_trimming = "N",
    trim_method = NA,
    trim_value = NA,
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Rim_Targets")
  openxlsx::writeData(wb, "Rim_Targets", data.frame(
    weight_name = rep("bad_rim", 2),
    variable = rep("Gender", 2),
    category = c("Male", "Female"),
    target_percent = c(60, 60),  # Sums to 120, not 100
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  return(config_path)
}

#' Create Cell Weight Config File
#'
#' Creates a Weight_Config.xlsx for cell weight testing.
#'
#' @param data_path Character, path to survey data file
#' @param output_dir Character, directory for output files
#' @return Character, path to created config file
#' @export
create_cell_weight_config <- function(data_path, output_dir = tempdir()) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required for test config generation")
  }

  config_path <- file.path(output_dir, "test_cell_config.xlsx")

  wb <- openxlsx::createWorkbook()

  # General sheet
  openxlsx::addWorksheet(wb, "General")
  general <- data.frame(
    Setting = c("project_name", "data_file", "save_diagnostics"),
    Value = c("Test Cell Weights", data_path, "N"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "General", general)

  # Weight_Specifications sheet
  openxlsx::addWorksheet(wb, "Weight_Specifications")
  specs <- data.frame(
    weight_name = "cell_weight",
    method = "cell",
    description = "Test cell weight",
    apply_trimming = "N",
    trim_method = NA,
    trim_value = NA,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Weight_Specifications", specs)

  # Cell_Targets sheet (Gender x Age interlocked)
  openxlsx::addWorksheet(wb, "Cell_Targets")
  cell_targets <- data.frame(
    weight_name = rep("cell_weight", 6),
    Gender = rep(c("Male", "Female"), each = 3),
    Age = rep(c("18-34", "35-54", "55+"), 2),
    target_percent = c(14, 20, 14, 16, 20, 16),  # sums to 100
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Cell_Targets", cell_targets)

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  return(config_path)
}

#' Create Config with Notes Sheet
#'
#' Creates a Weight_Config.xlsx that includes a Notes sheet.
#'
#' @param data_path Character, path to survey data file
#' @param output_dir Character, directory for output files
#' @return Character, path to created config file
#' @export
create_config_with_notes <- function(data_path, output_dir = tempdir()) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx required for test config generation")
  }

  config_path <- file.path(output_dir, "test_notes_config.xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name", "data_file", "save_diagnostics"),
    Value = c("Test Notes", data_path, "N"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", data.frame(
    weight_name = "design_weight", method = "design",
    description = "Test", apply_trimming = "N",
    trim_method = NA, trim_value = NA,
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Design_Targets")
  openxlsx::writeData(wb, "Design_Targets", data.frame(
    weight_name = rep("design_weight", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Notes")
  openxlsx::writeData(wb, "Notes", data.frame(
    Section = c("Assumptions", "Assumptions", "Methodology", "Data Quality"),
    Note = c(
      "Population figures based on 2025 census estimates",
      "Age groups are mutually exclusive and exhaustive",
      "Design weights calculated as population/sample ratio per stratum",
      "3 records excluded due to missing age data"
    ),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  return(config_path)
}

#' Write Test Survey Data to CSV
#'
#' Helper to write survey data to a temp CSV file.
#'
#' @param data Data frame (or NULL to create default)
#' @param output_dir Character, output directory
#' @return Character, path to written CSV file
#' @export
write_test_survey_csv <- function(data = NULL, output_dir = tempdir()) {
  if (is.null(data)) {
    data <- create_simple_survey()
  }
  path <- file.path(output_dir, "test_survey_data.csv")
  write.csv(data, path, row.names = FALSE)
  return(path)
}
