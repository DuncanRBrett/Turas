# ==============================================================================
# CREATE CATDRIVER CONFIG TEMPLATE
# ==============================================================================
#
# Generates an Excel configuration template with all required sheets and settings
# for categorical key driver analysis v2.0.
#
# Usage: Rscript create_config_template.R [output_path]
#
# ==============================================================================

library(openxlsx)

#' Create Catdriver Configuration Template
#'
#' Generates a complete Excel configuration template with all sheets and settings.
#'
#' @param output_file Path for the output Excel file
#' @param include_sample_data Whether to include sample data examples
#' @return Invisible path to created file
#' @export
create_catdriver_config_template <- function(output_file = "catdriver_config_template.xlsx",
                                              include_sample_data = TRUE) {

  wb <- createWorkbook()

  # Define styles
  header_style <- createStyle(
    textDecoration = "bold",
    fgFill = "#4472C4",
    fontColour = "white",
    halign = "left",
    valign = "center"
  )

  required_style <- createStyle(
    fgFill = "#FFF2CC"  # Light yellow for required fields
  )

  note_style <- createStyle(
    fontColour = "#666666",
    fontSize = 10,
    wrapText = TRUE
  )

  # ===========================================================================
  # SETTINGS SHEET
  # ===========================================================================

  addWorksheet(wb, "Settings")

  settings_data <- data.frame(
    Setting = c(
      # FILE PATHS (Required)
      "data_file",
      "output_file",

      # ANALYSIS IDENTITY
      "analysis_name",

      # OUTCOME TYPE (Required - no auto)
      "outcome_type",

      # MULTINOMIAL SETTINGS
      "multinomial_mode",
      "target_outcome_level",

      # REFERENCE CATEGORY
      "reference_category",
      "allow_missing_reference",

      # RARE LEVEL HANDLING
      "rare_level_policy",
      "rare_level_threshold",
      "rare_cell_threshold",

      # QUALITY THRESHOLDS
      "min_sample_size",
      "confidence_level",
      "missing_threshold",

      # OUTPUT OPTIONS
      "detailed_output"
    ),
    Value = c(
      # FILE PATHS
      "data.csv",
      "catdriver_results.xlsx",

      # ANALYSIS IDENTITY
      "My Key Driver Analysis",

      # OUTCOME TYPE
      "binary",  # Must be: binary, ordinal, multinomial

      # MULTINOMIAL SETTINGS
      "",  # baseline_category, all_pairwise, one_vs_all
      "",  # Required if multinomial_mode = one_vs_all

      # REFERENCE CATEGORY
      "",  # Leave blank to use first level
      "FALSE",

      # RARE LEVEL HANDLING
      "warn_only",  # warn_only, collapse_to_other, drop_level, error
      "10",  # Minimum observations per level
      "5",   # Minimum observations per cross-tab cell

      # QUALITY THRESHOLDS
      "30",
      "0.95",
      "50",

      # OUTPUT OPTIONS
      "TRUE"
    ),
    Required = c(
      "Yes", "Yes",
      "No",
      "Yes",  # outcome_type is required
      "Conditional",  # Required if outcome_type = multinomial
      "Conditional",  # Required if multinomial_mode = one_vs_all
      "No", "No",
      "No", "No", "No",
      "No", "No", "No",
      "No"
    ),
    Description = c(
      # FILE PATHS
      "Path to input data file (CSV or Excel). Relative to config file location.",
      "Path for output Excel file. Will be created/overwritten.",

      # ANALYSIS IDENTITY
      "Name displayed in output reports.",

      # OUTCOME TYPE
      "REQUIRED. Must be: binary (2 categories), ordinal (ordered categories), or multinomial (unordered categories). Auto-detection is disabled.",

      # MULTINOMIAL SETTINGS
      "For multinomial only: baseline_category (compare all to reference), all_pairwise (all pairs), one_vs_all (each vs rest).",
      "For one_vs_all mode: which outcome level to treat as 'success'.",

      # REFERENCE CATEGORY
      "Reference level for outcome variable. Leave blank to use first level.",
      "Allow analysis if reference level has missing data? (TRUE/FALSE)",

      # RARE LEVEL HANDLING
      "Policy for rare driver levels: warn_only (proceed with warning), collapse_to_other (merge into 'Other'), drop_level (remove), error (stop).",
      "Minimum observations per driver level to avoid rare level policy.",
      "Minimum observations per outcome x driver cell to avoid sparse cell warnings.",

      # QUALITY THRESHOLDS
      "Minimum total sample size to proceed.",
      "Confidence level for intervals (0-1, e.g., 0.95 = 95%).",
      "Maximum % missing data allowed per variable (0-100).",

      # OUTPUT OPTIONS
      "Include detailed tabs in output (TRUE/FALSE)."
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Settings", settings_data, headerStyle = header_style)

  # Style required settings
  required_rows <- which(settings_data$Required == "Yes") + 1  # +1 for header
  for (row in required_rows) {
    addStyle(wb, "Settings", required_style, rows = row, cols = 1:2)
  }

  setColWidths(wb, "Settings", cols = 1:4, widths = c(25, 30, 12, 60))

  # ===========================================================================
  # VARIABLES SHEET
  # ===========================================================================

  addWorksheet(wb, "Variables")

  if (include_sample_data) {
    variables_data <- data.frame(
      VariableName = c(
        "satisfaction_level",
        "age_group",
        "tenure_years",
        "department",
        "work_type"
      ),
      Type = c(
        "Outcome",
        "Driver",
        "Driver",
        "Driver",
        "Driver"
      ),
      Label = c(
        "Overall Satisfaction",
        "Age Group",
        "Years of Tenure",
        "Department",
        "Work Arrangement"
      ),
      Order = c(
        "Dissatisfied;Neutral;Satisfied",  # Ordinal outcome order
        "18-25;26-35;36-45;46-55;56+",
        "0-1;2-5;6-10;10+",
        "",  # Nominal, no order
        ""
      ),
      stringsAsFactors = FALSE
    )
  } else {
    variables_data <- data.frame(
      VariableName = c("outcome_var", "driver1", "driver2"),
      Type = c("Outcome", "Driver", "Driver"),
      Label = c("Outcome Label", "Driver 1 Label", "Driver 2 Label"),
      Order = c("Low;Medium;High", "", ""),
      stringsAsFactors = FALSE
    )
  }

  writeData(wb, "Variables", variables_data, headerStyle = header_style)
  setColWidths(wb, "Variables", cols = 1:4, widths = c(25, 12, 25, 40))

  # Add notes below data
  notes_row <- nrow(variables_data) + 3
  writeData(wb, "Variables",
            data.frame(Notes = c(
              "NOTES:",
              "- VariableName: Must match column names in your data file exactly",
              "- Type: Must be 'Outcome' (exactly 1), 'Driver' (1+), or 'Weight' (0-1)",
              "- Label: Human-readable name for reports",
              "- Order: Semicolon-separated category order (e.g., 'Low;Medium;High')",
              "  For ordinal outcomes: Order defines LOW to HIGH",
              "  For drivers: Order is optional but recommended for ordinal drivers"
            )),
            startRow = notes_row, colNames = FALSE)
  addStyle(wb, "Variables", note_style, rows = notes_row:(notes_row + 6), cols = 1)

  # ===========================================================================
  # DRIVER_SETTINGS SHEET (NEW IN V2.0 - REQUIRED)
  # ===========================================================================

  addWorksheet(wb, "Driver_Settings")

  if (include_sample_data) {
    driver_settings_data <- data.frame(
      driver = c(
        "age_group",
        "tenure_years",
        "department",
        "work_type"
      ),
      type = c(
        "ordinal",      # Ordered categories
        "ordinal",      # Ordered categories
        "nominal",      # Unordered categories
        "nominal"       # Unordered categories
      ),
      levels_order = c(
        "18-25;26-35;36-45;46-55;56+",
        "0-1;2-5;6-10;10+",
        "",  # Nominal, no order needed
        ""
      ),
      reference_level = c(
        "26-35",        # Middle age group as reference
        "2-5",          # Mid-tenure as reference
        "Operations",   # Specific reference
        ""              # Use first level (auto)
      ),
      missing_strategy = c(
        "drop_row",          # Drop rows with missing age
        "missing_as_level",  # Create 'Missing' level for tenure
        "missing_as_level",
        "error_if_missing"   # Fail if work_type has any missing
      ),
      rare_level_policy = c(
        "",              # Use global policy
        "collapse_to_other",  # Collapse rare tenure levels
        "warn_only",
        ""
      ),
      stringsAsFactors = FALSE
    )
  } else {
    driver_settings_data <- data.frame(
      driver = c("driver1", "driver2"),
      type = c("ordinal", "nominal"),
      levels_order = c("Level1;Level2;Level3", ""),
      reference_level = c("Level1", ""),
      missing_strategy = c("drop_row", "missing_as_level"),
      rare_level_policy = c("", ""),
      stringsAsFactors = FALSE
    )
  }

  writeData(wb, "Driver_Settings", driver_settings_data, headerStyle = header_style)
  setColWidths(wb, "Driver_Settings", cols = 1:6, widths = c(20, 12, 35, 18, 20, 20))

  # Add notes below data
  notes_row <- nrow(driver_settings_data) + 3
  writeData(wb, "Driver_Settings",
            data.frame(Notes = c(
              "DRIVER_SETTINGS - REQUIRED SHEET (V2.0)",
              "",
              "This sheet specifies per-driver handling options. Each driver variable in Variables sheet must have a row here.",
              "",
              "COLUMNS:",
              "- driver: Variable name (must match VariableName in Variables sheet)",
              "- type: 'ordinal' (ordered categories) or 'nominal' (unordered categories)",
              "",
              "- levels_order: Semicolon-separated category order, LOW to HIGH",
              "  Required for ordinal drivers; ignored for nominal",
              "",
              "- reference_level: Which level to use as reference (baseline)",
              "  Leave blank to use first level in levels_order",
              "",
              "- missing_strategy: How to handle missing values for this driver",
              "  'drop_row' = Remove rows with missing values (default)",
              "  'missing_as_level' = Create a 'Missing' category",
              "  'error_if_missing' = Fail if any missing values exist",
              "",
              "- rare_level_policy: Override global policy for this driver",
              "  'warn_only' = Proceed with warning",
              "  'collapse_to_other' = Merge rare levels into 'Other'",
              "  'drop_level' = Remove rare levels from analysis",
              "  'error' = Fail if rare levels exist",
              "  Leave blank to use global policy from Settings sheet"
            )),
            startRow = notes_row, colNames = FALSE)
  addStyle(wb, "Driver_Settings", note_style, rows = notes_row:(notes_row + 23), cols = 1)

  # ===========================================================================
  # INSTRUCTIONS SHEET
  # ===========================================================================

  addWorksheet(wb, "Instructions")

  instructions <- data.frame(
    Section = c(
      "CATDRIVER CONFIGURATION TEMPLATE v2.0",
      "",
      "REQUIRED SHEETS:",
      "1. Settings",
      "2. Variables",
      "3. Driver_Settings",
      "",
      "QUICK START:",
      "1. Copy this template",
      "2. Update data_file path in Settings",
      "3. Set outcome_type explicitly (binary, ordinal, or multinomial)",
      "4. List your variables in Variables sheet",
      "5. Configure each driver in Driver_Settings",
      "6. Run analysis",
      "",
      "KEY CHANGES IN V2.0:",
      "- outcome_type is REQUIRED (no auto-detection)",
      "- Driver_Settings sheet is REQUIRED",
      "- Per-driver missing data strategies",
      "- Explicit rare level handling policies",
      "- multinomial_mode required for multinomial outcomes",
      "",
      "OUTCOME TYPES:",
      "binary: 2-category outcome (e.g., Yes/No, Pass/Fail)",
      "ordinal: Ordered categories (e.g., Low/Medium/High, 1-5 scale)",
      "multinomial: Unordered categories (e.g., Red/Blue/Green)",
      "",
      "MULTINOMIAL MODES:",
      "baseline_category: Compare all levels to one reference (default)",
      "all_pairwise: Compare every pair of levels",
      "one_vs_all: Compare each level vs. all others combined",
      "",
      "SUPPORT:",
      "See CATDRIVER_SPEC_V1.md for detailed behavioral specification"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Instructions", instructions, colNames = FALSE)
  setColWidths(wb, "Instructions", cols = 1, widths = 80)

  # Bold the section headers
  bold_style <- createStyle(textDecoration = "bold")
  header_rows <- c(1, 3, 8, 16, 23, 28, 33)
  for (row in header_rows) {
    addStyle(wb, "Instructions", bold_style, rows = row, cols = 1)
  }

  # ===========================================================================
  # SAVE WORKBOOK
  # ===========================================================================

  saveWorkbook(wb, output_file, overwrite = TRUE)

  message("Created config template: ", output_file)
  message("\nSheets created:")
  message("  - Settings: Analysis parameters (", nrow(settings_data), " settings)")
  message("  - Variables: Variable definitions")
  message("  - Driver_Settings: Per-driver configuration (REQUIRED)")
  message("  - Instructions: Usage guide")

  invisible(output_file)
}


# ==============================================================================
# COMMAND LINE EXECUTION
# ==============================================================================

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  output_file <- if (length(args) > 0) args[1] else "catdriver_config_template.xlsx"

  create_catdriver_config_template(output_file)
}
