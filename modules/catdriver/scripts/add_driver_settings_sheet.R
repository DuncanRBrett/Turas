#!/usr/bin/env Rscript
# ==============================================================================
# Add Driver_Settings Sheet to Example Config
# ==============================================================================
#
# This script adds the required Driver_Settings sheet to the example config
# file and the test config file.
#
# Usage: Rscript add_driver_settings_sheet.R
#
# ==============================================================================

library(openxlsx)

# ------------------------------------------------------------------------------
# Function to add Driver_Settings sheet to a workbook
# ------------------------------------------------------------------------------

add_driver_settings <- function(config_path, drivers_info) {
  cat("Processing:", config_path, "\n")

  if (!file.exists(config_path)) {
    cat("  ERROR: File not found\n")
    return(FALSE)
  }

  # Load existing workbook
  wb <- loadWorkbook(config_path)
  existing_sheets <- names(wb)

  cat("  Existing sheets:", paste(existing_sheets, collapse = ", "), "\n")

  # Check if Driver_Settings already exists
  if ("Driver_Settings" %in% existing_sheets) {
    cat("  Driver_Settings sheet already exists - checking if empty\n")
    existing_data <- read.xlsx(wb, sheet = "Driver_Settings")
    if (nrow(existing_data) > 0) {
      cat("  Driver_Settings already has data - skipping\n")
      return(TRUE)
    }
    # Remove empty sheet and recreate
    removeWorksheet(wb, "Driver_Settings")
  }

  # Create Driver_Settings data frame
  driver_settings <- data.frame(
    driver = drivers_info$driver,
    type = drivers_info$type,
    levels_order = drivers_info$levels_order,
    reference_level = drivers_info$reference_level,
    missing_strategy = drivers_info$missing_strategy,
    rare_level_policy = drivers_info$rare_level_policy,
    stringsAsFactors = FALSE
  )

  # Add the sheet
  addWorksheet(wb, "Driver_Settings")
  writeData(wb, "Driver_Settings", driver_settings)

  # Style the header
  headerStyle <- createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    textDecoration = "bold",
    halign = "center"
  )
  addStyle(wb, "Driver_Settings", headerStyle, rows = 1, cols = 1:ncol(driver_settings))

  # Auto-width columns
  setColWidths(wb, "Driver_Settings", cols = 1:ncol(driver_settings), widths = "auto")

  # Save
  saveWorkbook(wb, config_path, overwrite = TRUE)
  cat("  SUCCESS: Added Driver_Settings sheet with", nrow(driver_settings), "drivers\n")

  return(TRUE)
}

# ------------------------------------------------------------------------------
# Process example config
# ------------------------------------------------------------------------------

cat("\n=== Adding Driver_Settings to Example Config ===\n\n")

# First, read the Variables sheet to get driver names
example_config_path <- "examples/basic/catdriver_config.xlsx"

if (file.exists(example_config_path)) {
  wb <- loadWorkbook(example_config_path)

  # Read Variables sheet to get driver names
  if ("Variables" %in% names(wb)) {
    vars_df <- read.xlsx(wb, sheet = "Variables")

    # Get drivers (role == "driver" or similar)
    if ("role" %in% tolower(names(vars_df))) {
      role_col <- names(vars_df)[tolower(names(vars_df)) == "role"]
      drivers <- vars_df$variable[tolower(vars_df[[role_col]]) == "driver"]
    } else if ("Role" %in% names(vars_df)) {
      drivers <- vars_df$Variable[tolower(vars_df$Role) == "driver"]
    } else {
      # Assume all non-outcome variables are drivers
      if ("Variable" %in% names(vars_df)) {
        drivers <- vars_df$Variable[2:nrow(vars_df)]  # Skip first (outcome)
      } else {
        drivers <- vars_df$variable[2:nrow(vars_df)]
      }
    }

    cat("Found drivers:", paste(drivers, collapse = ", "), "\n")

    # Create driver settings - default to categorical
    drivers_info <- data.frame(
      driver = drivers,
      type = rep("categorical", length(drivers)),
      levels_order = rep("", length(drivers)),
      reference_level = rep("", length(drivers)),
      missing_strategy = rep("missing_as_level", length(drivers)),
      rare_level_policy = rep("warn_only", length(drivers)),
      stringsAsFactors = FALSE
    )

    add_driver_settings(example_config_path, drivers_info)
  } else {
    cat("ERROR: Variables sheet not found in example config\n")
  }
} else {
  cat("Example config not found at:", example_config_path, "\n")
}

# ------------------------------------------------------------------------------
# Process test config (binary)
# ------------------------------------------------------------------------------

cat("\n=== Adding Driver_Settings to Test Config (Binary) ===\n\n")

test_config_path <- "tests/test_data/test_config_binary.xlsx"

if (file.exists(test_config_path)) {
  wb <- loadWorkbook(test_config_path)

  if ("Variables" %in% names(wb)) {
    vars_df <- read.xlsx(wb, sheet = "Variables")

    # Get variable and role columns (case-insensitive)
    var_col <- names(vars_df)[tolower(names(vars_df)) %in% c("variable", "name")]
    role_col <- names(vars_df)[tolower(names(vars_df)) == "role"]

    if (length(var_col) > 0 && length(role_col) > 0) {
      drivers <- vars_df[[var_col[1]]][tolower(vars_df[[role_col[1]]]) == "driver"]
    } else if (length(var_col) > 0) {
      # Assume all but first are drivers
      drivers <- vars_df[[var_col[1]]][2:nrow(vars_df)]
    } else {
      drivers <- c("age_group", "income", "region")  # Default test drivers
    }

    cat("Found drivers:", paste(drivers, collapse = ", "), "\n")

    drivers_info <- data.frame(
      driver = drivers,
      type = rep("categorical", length(drivers)),
      levels_order = rep("", length(drivers)),
      reference_level = rep("", length(drivers)),
      missing_strategy = rep("missing_as_level", length(drivers)),
      rare_level_policy = rep("warn_only", length(drivers)),
      stringsAsFactors = FALSE
    )

    add_driver_settings(test_config_path, drivers_info)
  }
} else {
  cat("Test config not found at:", test_config_path, "\n")
}

cat("\n=== Done ===\n")
