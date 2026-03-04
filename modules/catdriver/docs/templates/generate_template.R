# ==============================================================================
# Generate CatDriver Config Template (v11.0)
# ==============================================================================
# Run this script to regenerate CatDriver_Config_Template.xlsx
# All template content is defined inline below.
# ==============================================================================

library(openxlsx)

wb <- createWorkbook()

# ==============================================================================
# Styles
# ==============================================================================

headerStyle <- createStyle(
  fontName = "Calibri", fontSize = 11,
  textDecoration = "bold",
  fgFill = "#323367", fontColour = "#FFFFFF",
  halign = "left", valign = "center",
  border = "Bottom", borderColour = "#1a1a40"
)

requiredStyle <- createStyle(
  fontName = "Calibri", fontSize = 10,
  fgFill = "#FFF3CD", fontColour = "#664D03"
)

optionalStyle <- createStyle(
  fontName = "Calibri", fontSize = 10
)

bodyStyle <- createStyle(
  fontName = "Calibri", fontSize = 10,
  wrapText = TRUE, valign = "top"
)

sectionHeaderStyle <- createStyle(
  fontName = "Calibri", fontSize = 11,
  textDecoration = "bold",
  fgFill = "#E8E8F0", fontColour = "#323367",
  halign = "left"
)

guideHeaderStyle <- createStyle(
  fontName = "Calibri", fontSize = 12,
  textDecoration = "bold",
  fontColour = "#323367"
)

guideSubStyle <- createStyle(
  fontName = "Calibri", fontSize = 11,
  textDecoration = "bold",
  fontColour = "#555555"
)

codeStyle <- createStyle(
  fontName = "Consolas", fontSize = 10,
  fontColour = "#0B5345"
)

# ==============================================================================
# SHEET 1: Settings
# ==============================================================================

settings_df <- data.frame(
  Setting = c(
    # File paths (required)
    "data_file",
    "output_file",
    # Core analysis
    "analysis_name",
    "outcome_type",
    "reference_category",
    # Sample & thresholds
    "min_sample_size",
    "confidence_level",
    "missing_threshold",
    # Output control
    "detailed_output",
    # Rare level handling
    "rare_level_policy",
    "rare_level_threshold",
    "rare_cell_threshold",
    # Bootstrap
    "bootstrap_ci",
    "bootstrap_reps",
    # HTML report
    "html_report",
    "probability_lifts",
    "brand_colour",
    "accent_colour",
    "report_title",
    "researcher_logo_path",
    "client_logo_path",
    # Subgroup comparison (optional)
    "subgroup_var",
    "subgroup_min_n",
    "subgroup_include_total"
  ),
  Value = c(
    "data.csv",
    "output/catdriver_results.xlsx",
    "My Key Driver Analysis",
    "ordinal",
    "",
    "30",
    "0.95",
    "50",
    "TRUE",
    "warn_only",
    "10",
    "5",
    "FALSE",
    "200",
    "TRUE",
    "TRUE",
    "#323367",
    "#CC9900",
    "",
    "",
    "",
    # Subgroup comparison
    "",
    "30",
    "TRUE"
  ),
  Required = c(
    "YES", "YES",
    "No", "YES", "No",
    "No", "No", "No",
    "No",
    "No", "No", "No",
    "No", "No",
    "No", "No", "No", "No", "No", "No", "No",
    "No", "No", "No"
  ),
  Default = c(
    "-", "-",
    "Categorical Key Driver Analysis", "-", "First alphabetically",
    "30", "0.95", "50",
    "TRUE",
    "warn_only", "10", "5",
    "FALSE", "200",
    "TRUE", "TRUE", "#323367", "#CC9900", "(analysis_name)", "-", "-",
    "(disabled)", "30", "TRUE"
  ),
  Description = c(
    "Path to data file. Relative paths resolve from this config file's directory.",
    "Path for output Excel file. Directory created automatically if needed.",
    "Display name for this analysis (appears in reports).",
    "Type of outcome variable. REQUIRED - must be explicitly set.",
    "Reference category for outcome comparisons. Leave blank for first alphabetically.",
    "Minimum complete cases required to run analysis.",
    "Confidence level for intervals (0.95 = 95% CI).",
    "Warn if any variable has missing data above this percentage.",
    "TRUE = 6 Excel sheets (includes Odds Ratios & Diagnostics). FALSE = 4 sheets.",
    "How to handle categories with very few observations.",
    "Minimum count for a category to be considered non-rare.",
    "Minimum cell count in driver-outcome cross-tabulations.",
    "Enable bootstrap confidence intervals (adds 1-3 minutes runtime).",
    "Number of bootstrap resamples. More = more precise but slower.",
    "Generate interactive HTML report alongside Excel output.",
    "Include probability lift calculations in the HTML report.",
    "Primary brand colour for report charts (hex code).",
    "Accent colour for report highlights (hex code).",
    "Custom title for the HTML report. Leave blank to use analysis_name.",
    "Path to researcher/analyst logo image for report header. Leave blank to omit.",
    "Path to client logo image for report header. Leave blank to omit.",
    "Column name for subgroup splitting (e.g. age_group, region). Must NOT be outcome or driver. Leave blank for standard analysis.",
    "Minimum observations per subgroup. Groups below this threshold produce a warning.",
    "Include full-dataset 'Total' analysis alongside per-subgroup results."
  ),
  Valid.Values = c(
    ".csv, .xlsx, .xls, .sav, .dta",
    ".xlsx path",
    "Any text",
    "binary | ordinal | multinomial",
    "Category name from outcome variable",
    "Positive integer (recommend 30+)",
    "0.80 to 0.99",
    "0 to 100",
    "TRUE | FALSE",
    "warn_only | collapse_to_other | drop_level | error",
    "Positive integer",
    "Positive integer",
    "TRUE | FALSE",
    "Positive integer (recommend 200+)",
    "TRUE | FALSE",
    "TRUE | FALSE",
    "Hex colour (e.g. #323367)",
    "Hex colour (e.g. #CC9900)",
    "Any text",
    "Image file path (.png, .jpg)",
    "Image file path (.png, .jpg)",
    "Column name from data file",
    "Positive integer (recommend 30+)",
    "TRUE | FALSE"
  ),
  stringsAsFactors = FALSE
)

addWorksheet(wb, "Settings")
writeData(wb, "Settings", settings_df, headerStyle = headerStyle)

# Apply body style
addStyle(wb, "Settings", bodyStyle,
         rows = 2:(nrow(settings_df) + 1), cols = 1:6,
         gridExpand = TRUE, stack = TRUE)

# Highlight required rows
req_rows <- which(settings_df$Required == "YES") + 1
addStyle(wb, "Settings", requiredStyle,
         rows = req_rows, cols = 1:6,
         gridExpand = TRUE, stack = TRUE)

# Column widths
setColWidths(wb, "Settings", cols = 1, widths = 22)
setColWidths(wb, "Settings", cols = 2, widths = 35)
setColWidths(wb, "Settings", cols = 3, widths = 10)
setColWidths(wb, "Settings", cols = 4, widths = 15)
setColWidths(wb, "Settings", cols = 5, widths = 55)
setColWidths(wb, "Settings", cols = 6, widths = 35)

# ==============================================================================
# SHEET 2: Variables
# ==============================================================================

variables_df <- data.frame(
  VariableName = c("satisfaction", "grade", "campus", "course_type",
                   "employment_field", "survey_weight"),
  Type = c("Outcome", "Driver", "Driver", "Driver", "Driver", "Weight"),
  Label = c("Employment Satisfaction", "Academic Grade", "Campus Location",
            "Course Type", "Employment Field", "Survey Weight"),
  Order = c("Low;Neutral;High", "D;C;B;A", "", "", "", ""),
  Notes = c(
    "The outcome variable you want to explain (exactly 1 required)",
    "Ordinal predictor - specify Order from lowest to highest",
    "Nominal predictor - leave Order blank",
    "Nominal predictor - leave Order blank",
    "Nominal predictor - leave Order blank",
    "Optional weight variable (at most 1) - leave blank if unweighted"
  ),
  stringsAsFactors = FALSE
)

addWorksheet(wb, "Variables")
writeData(wb, "Variables", variables_df, headerStyle = headerStyle)

addStyle(wb, "Variables", bodyStyle,
         rows = 2:(nrow(variables_df) + 1), cols = 1:5,
         gridExpand = TRUE, stack = TRUE)

setColWidths(wb, "Variables", cols = 1, widths = 22)
setColWidths(wb, "Variables", cols = 2, widths = 10)
setColWidths(wb, "Variables", cols = 3, widths = 28)
setColWidths(wb, "Variables", cols = 4, widths = 22)
setColWidths(wb, "Variables", cols = 5, widths = 55)

# ==============================================================================
# SHEET 3: Driver_Settings
# ==============================================================================

driver_settings_df <- data.frame(
  driver = c("grade", "campus", "course_type", "employment_field"),
  type = c("ordinal", "categorical", "categorical", "categorical"),
  levels_order = c("D;C;B;A", "", "", ""),
  reference_level = c("D", "", "", ""),
  missing_strategy = c("missing_as_level", "missing_as_level",
                       "missing_as_level", "missing_as_level"),
  rare_level_policy = c("warn_only", "warn_only", "warn_only", "warn_only"),
  stringsAsFactors = FALSE
)

addWorksheet(wb, "Driver_Settings")
writeData(wb, "Driver_Settings", driver_settings_df, headerStyle = headerStyle)

addStyle(wb, "Driver_Settings", bodyStyle,
         rows = 2:(nrow(driver_settings_df) + 1), cols = 1:6,
         gridExpand = TRUE, stack = TRUE)

setColWidths(wb, "Driver_Settings", cols = 1, widths = 22)
setColWidths(wb, "Driver_Settings", cols = 2, widths = 14)
setColWidths(wb, "Driver_Settings", cols = 3, widths = 18)
setColWidths(wb, "Driver_Settings", cols = 4, widths = 18)
setColWidths(wb, "Driver_Settings", cols = 5, widths = 20)
setColWidths(wb, "Driver_Settings", cols = 6, widths = 20)

# ==============================================================================
# SHEET 4: Instructions
# ==============================================================================

instructions <- c(
  "CATEGORICAL KEY DRIVER ANALYSIS - CONFIGURATION GUIDE (v11.0)",
  "",
  "=== OVERVIEW ===",
  "This config file controls the Categorical Key Driver Analysis module.",
  "The module identifies which factors drive categorical outcomes using logistic regression.",
  "It produces an Excel workbook and an interactive HTML report.",
  "",
  "=== QUICK START ===",
  "1. Edit the Settings sheet: set data_file, output_file, and outcome_type",
  "2. Edit the Variables sheet: define your outcome, driver, and (optional) weight variables",
  "3. Edit the Driver_Settings sheet: set type, order, and reference level for each driver",
  "4. Save this file",
  "5. Run the analysis: Launch Turas > Click 'Categorical Key Driver' > Select this config file",
  "",
  "=== THREE REQUIRED SHEETS ===",
  "Settings         - Analysis parameters (file paths, outcome type, thresholds)",
  "Variables        - Outcome and driver variable definitions",
  "Driver_Settings  - Per-driver type, ordering, reference level, and missing strategy",
  "",
  "=== SETTINGS SHEET ===",
  "Three settings are REQUIRED (highlighted in yellow):",
  "  data_file    - Path to your data (CSV, Excel, SPSS, Stata)",
  "  output_file  - Where to save the results Excel file",
  "  outcome_type - Must be: binary, ordinal, or multinomial",
  "",
  "IMPORTANT: outcome_type must be explicitly set. 'auto' is NOT supported.",
  "  binary       - Exactly 2 categories (e.g. Yes/No, Retained/Churned)",
  "  ordinal      - 3+ ordered categories (e.g. Low/Medium/High)",
  "  multinomial  - 3+ unordered categories (e.g. Brand A/B/C/D)",
  "",
  "Paths can be relative (resolved from this config file's folder) or absolute.",
  "",
  "=== VARIABLES SHEET ===",
  "VariableName  - Exact column name in your data file (case-sensitive!)",
  "Type          - Must be: Outcome, Driver, or Weight",
  "Label         - Human-readable name for reports",
  "Order         - For ordinal variables: list categories lowest to highest, separated by semicolons",
  "                Leave blank for nominal (unordered) variables",
  "",
  "Rules:",
  "  - Exactly 1 Outcome variable required",
  "  - At least 1 Driver variable required",
  "  - At most 1 Weight variable (optional)",
  "",
  "=== DRIVER_SETTINGS SHEET ===",
  "driver           - Must match a Driver variable name from Variables sheet",
  "type             - 'categorical' (unordered) or 'ordinal' (ordered)",
  "levels_order     - Semicolon-separated level order (e.g. 'D;C;B;A'). Leave blank for unordered.",
  "reference_level  - Which level is the reference for comparisons. Leave blank for auto-selection.",
  "missing_strategy - How to handle missing values for this driver:",
  "                   'missing_as_level' (default) - treat NA as its own category",
  "                   'drop_row' - exclude rows with NA for this driver",
  "                   'error_if_missing' - refuse to run if any NAs present",
  "rare_level_policy - Per-driver override for rare category handling:",
  "                    'warn_only' (default) - warn but continue",
  "                    'collapse_to_other' - merge rare levels into an 'Other' category",
  "                    'drop_level' - remove rare levels",
  "                    'error' - refuse to run if rare levels found",
  "",
  "=== ORDER COLUMN EXAMPLES ===",
  "Satisfaction levels:  Low;Neutral;High",
  "Likert scale:         Strongly Disagree;Disagree;Neutral;Agree;Strongly Agree",
  "Letter grades:        F;D;C;B;A",
  "Numeric codes:        1;2;3;4;5",
  "",
  "=== OPTIONAL FEATURES ===",
  "Bootstrap CIs:      Set bootstrap_ci=TRUE for more robust confidence intervals.",
  "                    Recommended for non-probability samples. Adds 1-3 minutes runtime.",
  "HTML Report:        Set html_report=TRUE (default) for an interactive HTML report.",
  "Probability Lifts:  Set probability_lifts=TRUE (default) to show how each driver level",
  "                    changes the predicted probability vs the reference.",
  "Brand Colours:      Set brand_colour and accent_colour (hex codes) to customise report styling.",
  "Logos:              Set researcher_logo_path and client_logo_path for branded report headers.",
  "",
  "=== SUBGROUP COMPARISON (OPTIONAL) ===",
  "Set subgroup_var to a column name from your data to split the analysis by group.",
  "The module runs a separate model for each subgroup, then compares results across groups.",
  "",
  "SETTINGS:",
  "  subgroup_var          - Column name (e.g. 'age_group', 'region'). Leave blank to disable.",
  "  subgroup_min_n        - Minimum observations per subgroup (default: 30).",
  "  subgroup_include_total - Include full-dataset analysis alongside subgroups (default: TRUE).",
  "",
  "RULES:",
  "  - subgroup_var must NOT be the outcome variable",
  "  - subgroup_var must NOT be listed as a driver variable",
  "  - Must have at least 2 distinct non-NA levels",
  "",
  "OUTPUT:",
  "  - Per-subgroup importance rankings with driver classification:",
  "    Universal (important across all groups), Segment-Specific (only important in one group), Mixed",
  "  - Odds ratio comparison table flagging notable differences (ratio > 2x)",
  "  - Per-subgroup model fit summary (n, R-squared, AIC, convergence)",
  "  - Auto-generated management insights (e.g. 'Driver X is #1 in Group A but #5 in Group B')",
  "",
  "=== TIPS ===",
  "- Use relative paths so projects work when moved or synced via OneDrive",
  "- If Order conflicts exist between Variables and Driver_Settings, the module will refuse",
  "- Check spelling of variable names: they must exactly match your data file columns",
  "- See 04_USER_MANUAL.md for detailed guidance on variable selection and collapsing decisions",
  "- See 08_BOOTSTRAP_GUIDE.md for when and how to use bootstrap CIs"
)

instructions_df <- data.frame(
  `CONFIGURATION GUIDE` = instructions,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

addWorksheet(wb, "Instructions")
writeData(wb, "Instructions", instructions_df, headerStyle = guideHeaderStyle)
addStyle(wb, "Instructions", bodyStyle,
         rows = 2:(length(instructions) + 1), cols = 1,
         gridExpand = TRUE, stack = TRUE)
setColWidths(wb, "Instructions", cols = 1, widths = 100)

# Bold section headers
section_rows <- grep("^===", instructions) + 1
addStyle(wb, "Instructions", guideSubStyle,
         rows = section_rows, cols = 1,
         gridExpand = TRUE, stack = TRUE)

# ==============================================================================
# SHEET 5: Effect Size Guide
# ==============================================================================

effect_guide <- data.frame(
  `INTERPRETING RESULTS` = c(
    "ODDS RATIO INTERPRETATION",
    "Odds Ratio Range", "0.9 - 1.1", "0.67 - 0.9 or 1.1 - 1.5",
    "0.5 - 0.67 or 1.5 - 2.0", "0.33 - 0.5 or 2.0 - 3.0",
    "< 0.33 or > 3.0",
    "",
    "IMPORTANCE PERCENTAGE INTERPRETATION",
    "Importance %", "> 30%", "15 - 30%", "5 - 15%", "< 5%",
    "",
    "MODEL FIT (McFadden R-squared)",
    "R-squared Value", "0.4+", "0.2 - 0.4", "0.1 - 0.2", "< 0.1",
    "",
    "PROBABILITY LIFT INTERPRETATION",
    "Lift (pp)", "> +10 pp", "+5 to +10 pp", "+2 to +5 pp", "-2 to +2 pp",
    "-5 to -2 pp", "-10 to -5 pp", "< -10 pp"
  ),
  Col2 = c(
    "",
    "Effect Size", "Negligible", "Small", "Medium", "Large", "Very Large",
    "",
    "",
    "Category", "Dominant driver", "Major driver", "Moderate driver", "Minor driver",
    "",
    "",
    "Interpretation", "Excellent fit", "Good fit", "Moderate fit", "Limited fit",
    "",
    "",
    "Interpretation", "Strong positive lift", "Moderate positive lift",
    "Small positive lift", "Negligible lift",
    "Small negative lift", "Moderate negative lift", "Strong negative lift"
  ),
  Col3 = c(
    "",
    "Meaning", "No meaningful difference from reference",
    "Minor difference, may not be actionable",
    "Meaningful difference worth attention",
    "Substantial difference, high priority",
    "Major difference, investigate thoroughly",
    "",
    "",
    "Meaning",
    "Primary focus area - strongest influence",
    "Significant influence - worth prioritising",
    "Notable but secondary influence",
    "Limited impact - lower priority",
    "",
    "",
    "Notes",
    "Model explains outcome very well",
    "Strong explanatory power for social science",
    "Useful but other factors likely at play",
    "Model has limited explanatory power",
    "",
    "",
    "Notes",
    "Category strongly increases predicted probability",
    "Category meaningfully increases predicted probability",
    "Category slightly increases predicted probability",
    "No practical difference from reference",
    "Category slightly decreases predicted probability",
    "Category meaningfully decreases predicted probability",
    "Category strongly decreases predicted probability"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

addWorksheet(wb, "Effect Size Guide")
writeData(wb, "Effect Size Guide", effect_guide,
          colNames = FALSE, startRow = 1)

# Style section headers
guide_section_rows <- c(1, 9, 15, 21)
addStyle(wb, "Effect Size Guide", guideHeaderStyle,
         rows = guide_section_rows, cols = 1,
         gridExpand = TRUE, stack = TRUE)

# Style column headers within sections
guide_col_header_rows <- c(2, 10, 16, 22)
addStyle(wb, "Effect Size Guide", guideSubStyle,
         rows = guide_col_header_rows, cols = 1:3,
         gridExpand = TRUE, stack = TRUE)

# Style body
all_body_rows <- setdiff(1:nrow(effect_guide), c(guide_section_rows, guide_col_header_rows))
addStyle(wb, "Effect Size Guide", bodyStyle,
         rows = all_body_rows, cols = 1:3,
         gridExpand = TRUE, stack = TRUE)

setColWidths(wb, "Effect Size Guide", cols = 1, widths = 32)
setColWidths(wb, "Effect Size Guide", cols = 2, widths = 28)
setColWidths(wb, "Effect Size Guide", cols = 3, widths = 50)

# ==============================================================================
# Save
# ==============================================================================

output_path <- "CatDriver_Config_Template.xlsx"
saveWorkbook(wb, output_path, overwrite = TRUE)
cat("Template saved to:", normalizePath(output_path), "\n")
