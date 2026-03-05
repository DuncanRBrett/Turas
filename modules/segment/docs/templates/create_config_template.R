# ==============================================================================
# CREATE SEGMENT CONFIG TEMPLATE v11.0
# ==============================================================================
# Generates the comprehensive Segment_Config_Template.xlsx with two sheets:
#   - Settings: All config parameters with defaults
#   - Instructions: Parameter guidance
#
# Uses the actual parameter names from 01_config.R for full compatibility.
# ==============================================================================

library(openxlsx)

wb <- createWorkbook()

# ==============================================================================
# STYLES
# ==============================================================================

# Header style - bold white text on dark blue
header_style <- createStyle(
  fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
  fgFill = "#323367", halign = "left", textDecoration = "bold",
  border = "Bottom", borderColour = "#000000", borderStyle = "thin"
)

# Section header - bold text on light gray
section_style <- createStyle(
  fontName = "Arial", fontSize = 11, fontColour = "#000000",
  fgFill = "#D9D9D9", textDecoration = "bold",
  border = "TopBottom", borderColour = "#AAAAAA", borderStyle = "thin"
)

# Normal cell
normal_style <- createStyle(
  fontName = "Arial", fontSize = 10, halign = "left",
  wrapText = FALSE
)

# Value cell (editable) - light yellow background
value_style <- createStyle(
  fontName = "Arial", fontSize = 10, halign = "left",
  fgFill = "#FFFDE7",
  border = "Bottom", borderColour = "#E0E0E0", borderStyle = "thin"
)

# Required value cell - light red background
required_style <- createStyle(
  fontName = "Arial", fontSize = 10, halign = "left",
  fgFill = "#FFEBEE",
  border = "Bottom", borderColour = "#E0E0E0", borderStyle = "thin"
)

# Instructions header
instr_header_style <- createStyle(
  fontName = "Arial", fontSize = 11, fontColour = "#FFFFFF",
  fgFill = "#323367", halign = "left", textDecoration = "bold"
)

# Instructions section
instr_section_style <- createStyle(
  fontName = "Arial", fontSize = 10, fgFill = "#D9D9D9",
  textDecoration = "bold"
)

# Instructions body
instr_body_style <- createStyle(
  fontName = "Arial", fontSize = 10, wrapText = TRUE, valign = "top"
)

# ==============================================================================
# SETTINGS SHEET
# ==============================================================================
# Uses "Setting" and "Value" columns as per user request,
# but the sheet is named "Config" for compatibility with the config loader.
# ==============================================================================

addWorksheet(wb, "Config")

# Build the data frame with sections as separator rows
# Section rows have the section name in Setting and blank Value.
settings <- data.frame(
  Setting = character(),
  Value = character(),
  stringsAsFactors = FALSE
)

add_section <- function(df, section_name) {
  rbind(df, data.frame(Setting = section_name, Value = "", stringsAsFactors = FALSE))
}

add_param <- function(df, name, value) {
  rbind(df, data.frame(Setting = name, Value = as.character(value), stringsAsFactors = FALSE))
}

# --- Core Settings ---
settings <- add_section(settings, "CORE SETTINGS")
settings <- add_param(settings, "data_file", "")
settings <- add_param(settings, "data_sheet", "")
settings <- add_param(settings, "id_variable", "respondent_id")
settings <- add_param(settings, "clustering_vars", "")
settings <- add_param(settings, "profile_vars", "")
settings <- add_param(settings, "demographic_vars", "")

# --- Algorithm Settings ---
settings <- add_section(settings, "ALGORITHM SETTINGS")
settings <- add_param(settings, "method", "kmeans")
settings <- add_param(settings, "k_fixed", "")
settings <- add_param(settings, "k_min", "3")
settings <- add_param(settings, "k_max", "6")
settings <- add_param(settings, "nstart", "25")
settings <- add_param(settings, "seed", "123")
settings <- add_param(settings, "linkage_method", "ward.D2")
settings <- add_param(settings, "gmm_model_type", "VVV")

# --- Data Handling ---
settings <- add_section(settings, "DATA HANDLING")
settings <- add_param(settings, "standardize", "TRUE")
settings <- add_param(settings, "missing_data", "median_imputation")
settings <- add_param(settings, "missing_threshold", "30")
settings <- add_param(settings, "min_segment_size_pct", "10")

# --- Outlier Detection ---
settings <- add_section(settings, "OUTLIER DETECTION")
settings <- add_param(settings, "outlier_detection", "TRUE")
settings <- add_param(settings, "outlier_method", "mahalanobis")
settings <- add_param(settings, "outlier_handling", "flag")
settings <- add_param(settings, "outlier_threshold", "3.0")
settings <- add_param(settings, "outlier_alpha", "0.001")
settings <- add_param(settings, "outlier_min_vars", "1")

# --- Variable Selection ---
settings <- add_section(settings, "VARIABLE SELECTION")
settings <- add_param(settings, "variable_selection", "FALSE")
settings <- add_param(settings, "variable_selection_method", "variance_correlation")
settings <- add_param(settings, "max_clustering_vars", "10")
settings <- add_param(settings, "varsel_min_variance", "0.1")
settings <- add_param(settings, "varsel_max_correlation", "0.8")

# --- Validation ---
settings <- add_section(settings, "VALIDATION")
settings <- add_param(settings, "k_selection_metrics", "silhouette,elbow")

# --- Enhanced Features ---
settings <- add_section(settings, "ENHANCED FEATURES")
settings <- add_param(settings, "generate_rules", "TRUE")
settings <- add_param(settings, "generate_action_cards", "TRUE")
settings <- add_param(settings, "run_stability_check", "FALSE")
settings <- add_param(settings, "rules_max_depth", "4")
settings <- add_param(settings, "stability_n_runs", "10")
settings <- add_param(settings, "segment_names", "auto")
settings <- add_param(settings, "auto_name_style", "simple")
settings <- add_param(settings, "golden_questions_n", "3")
settings <- add_param(settings, "scale_max", "10")
settings <- add_param(settings, "use_lca", "FALSE")
settings <- add_param(settings, "question_labels_file", "")

# --- Output Settings ---
settings <- add_section(settings, "OUTPUT SETTINGS")
settings <- add_param(settings, "output_folder", "output")
settings <- add_param(settings, "output_prefix", "seg_")
settings <- add_param(settings, "create_dated_folder", "TRUE")
settings <- add_param(settings, "save_model", "TRUE")

# --- HTML Report ---
settings <- add_section(settings, "HTML REPORT")
settings <- add_param(settings, "html_report", "TRUE")
settings <- add_param(settings, "brand_colour", "#323367")
settings <- add_param(settings, "accent_colour", "#CC9900")
settings <- add_param(settings, "report_title", "Segmentation Analysis")
settings <- add_param(settings, "html_show_exec_summary", "TRUE")
settings <- add_param(settings, "html_show_overview", "TRUE")
settings <- add_param(settings, "html_show_validation", "TRUE")
settings <- add_param(settings, "html_show_importance", "TRUE")
settings <- add_param(settings, "html_show_profiles", "TRUE")
settings <- add_param(settings, "html_show_demographics", "TRUE")
settings <- add_param(settings, "html_show_rules", "TRUE")
settings <- add_param(settings, "html_show_cards", "TRUE")
settings <- add_param(settings, "html_show_stability", "TRUE")
settings <- add_param(settings, "html_show_membership", "TRUE")
settings <- add_param(settings, "html_show_guide", "TRUE")

# --- Metadata ---
settings <- add_section(settings, "METADATA")
settings <- add_param(settings, "project_name", "")
settings <- add_param(settings, "analyst_name", "")
settings <- add_param(settings, "description", "")

# Write to sheet
writeData(wb, "Config", settings, startRow = 1, startCol = 1, headerStyle = header_style)

# Identify section rows (rows where Setting is all uppercase and Value is blank)
section_rows <- which(settings$Setting == toupper(settings$Setting) & nchar(settings$Value) == 0)
# Adjust for header row offset (+1)
section_rows_excel <- section_rows + 1

# Identify required parameter rows (data_file, id_variable, clustering_vars)
required_params <- c("data_file", "id_variable", "clustering_vars")
required_rows <- which(settings$Setting %in% required_params) + 1

# Apply styles
# Section headers
for (r in section_rows_excel) {
  addStyle(wb, "Config", section_style, rows = r, cols = 1:2, gridExpand = TRUE)
}

# Normal parameter rows (all non-section, non-header)
param_rows <- setdiff(2:(nrow(settings) + 1), c(1, section_rows_excel))
for (r in param_rows) {
  addStyle(wb, "Config", normal_style, rows = r, cols = 1)
  if (r %in% required_rows) {
    addStyle(wb, "Config", required_style, rows = r, cols = 2)
  } else {
    addStyle(wb, "Config", value_style, rows = r, cols = 2)
  }
}

# Set column widths
setColWidths(wb, "Config", cols = 1, widths = 35)
setColWidths(wb, "Config", cols = 2, widths = 45)

# Freeze header row
freezePane(wb, "Config", firstRow = TRUE)


# ==============================================================================
# INSTRUCTIONS SHEET
# ==============================================================================

addWorksheet(wb, "Instructions")

instructions <- data.frame(
  Parameter = c(
    "TURAS SEGMENTATION CONFIG TEMPLATE v11.0",
    "",
    "HOW TO USE THIS TEMPLATE",
    "1. Copy this file and rename it for your project",
    "2. Fill in the REQUIRED fields (highlighted in red) on the Config sheet",
    "3. Adjust optional settings as needed (yellow background)",
    "4. Section headers (gray rows) are for organisation only - do not edit them",
    "5. Leave k_fixed blank for exploration mode, or set a number for final mode",
    "",
    "CORE SETTINGS",
    "data_file",
    "data_sheet",
    "id_variable",
    "clustering_vars",
    "profile_vars",
    "demographic_vars",
    "",
    "ALGORITHM SETTINGS",
    "method",
    "k_fixed",
    "k_min",
    "k_max",
    "nstart",
    "seed",
    "linkage_method",
    "gmm_model_type",
    "",
    "DATA HANDLING",
    "standardize",
    "missing_data",
    "missing_threshold",
    "min_segment_size_pct",
    "",
    "OUTLIER DETECTION",
    "outlier_detection",
    "outlier_method",
    "outlier_handling",
    "outlier_threshold",
    "outlier_alpha",
    "outlier_min_vars",
    "",
    "VARIABLE SELECTION",
    "variable_selection",
    "variable_selection_method",
    "max_clustering_vars",
    "varsel_min_variance",
    "varsel_max_correlation",
    "",
    "VALIDATION",
    "k_selection_metrics",
    "",
    "ENHANCED FEATURES",
    "generate_rules",
    "generate_action_cards",
    "run_stability_check",
    "rules_max_depth",
    "stability_n_runs",
    "segment_names",
    "auto_name_style",
    "golden_questions_n",
    "scale_max",
    "use_lca",
    "question_labels_file",
    "",
    "OUTPUT SETTINGS",
    "output_folder",
    "output_prefix",
    "create_dated_folder",
    "save_model",
    "",
    "HTML REPORT",
    "html_report",
    "brand_colour",
    "accent_colour",
    "report_title",
    "html_show_exec_summary",
    "html_show_overview",
    "html_show_validation",
    "html_show_importance",
    "html_show_profiles",
    "html_show_demographics",
    "html_show_rules",
    "html_show_cards",
    "html_show_stability",
    "html_show_membership",
    "html_show_guide",
    "",
    "METADATA",
    "project_name",
    "analyst_name",
    "description"
  ),
  Description = c(
    "The Research LampPost (Pty) Ltd",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    # CORE SETTINGS section header
    "",
    # data_file
    "REQUIRED. Path to your data file (.csv, .xlsx, .xls, .sav, .dta). Can be absolute or relative to the working directory.",
    # data_sheet
    "Sheet name if data_file is Excel. Default: first sheet. Leave blank for CSV files.",
    # id_variable
    "REQUIRED. Column name for the unique respondent identifier. Must exist in the data.",
    # clustering_vars
    "REQUIRED. Comma-separated list of numeric variables to use for clustering. Should be attitudinal or needs-based variables. Minimum 2, recommended 5-15. Example: Q02,Q03,Q04,Q05,Q06",
    # profile_vars
    "Optional. Comma-separated list of variables for profiling segments (not used in clustering). If blank, all non-clustering variables are used.",
    # demographic_vars
    "Optional. Comma-separated list of demographic variables for cross-tabulation in the HTML report. Example: age_group,gender,region",
    "",
    # ALGORITHM SETTINGS section header
    "",
    # method
    "Clustering algorithm: kmeans (default, fast and reliable), hclust (hierarchical, good for non-spherical clusters), gmm (Gaussian mixture, flexible shapes).",
    # k_fixed
    "Leave BLANK for exploration mode (tests k_min to k_max). Set to an integer (2-10) for final mode with a fixed number of segments.",
    # k_min
    "Minimum number of segments to test in exploration mode. Range: 2-10. Default: 3.",
    # k_max
    "Maximum number of segments to test in exploration mode. Range: 2-15. Must be greater than k_min. Default: 6.",
    # nstart
    "Number of random starting positions for k-means. Higher = more stable results but slower. Range: 1-200. Default: 25.",
    # seed
    "Random seed for reproducibility. Any positive integer. Use the same seed to get identical results. Default: 123.",
    # linkage_method
    "Linkage method for hierarchical clustering (hclust only). Options: ward.D2 (default, recommended), complete, average, single.",
    # gmm_model_type
    "Model type for Gaussian mixture models (gmm only). Options: VVV (variable volume/shape/orientation, most flexible), EEE (equal), VVI, etc. Default: VVV.",
    "",
    # DATA HANDLING section header
    "",
    # standardize
    "Whether to z-score standardize variables before clustering. TRUE (default, recommended) ensures equal weighting. FALSE keeps original scales.",
    # missing_data
    "How to handle missing values. Options: listwise_deletion (remove rows with any NA), mean_imputation, median_imputation, refuse (error if any NA). Default: listwise_deletion.",
    # missing_threshold
    "Maximum percentage of missing values allowed per variable (0-100). Variables exceeding this are flagged. Default: 15.",
    # min_segment_size_pct
    "Minimum acceptable segment size as percentage of total sample (0-50). Warns if any segment is smaller. Default: 10.",
    "",
    # OUTLIER DETECTION section header
    "",
    # outlier_detection
    "Enable outlier detection before clustering. TRUE/FALSE. Default: FALSE.",
    # outlier_method
    "Detection method: zscore (univariate, flag if |z| > threshold) or mahalanobis (multivariate distance). Default: zscore.",
    # outlier_handling
    "What to do with detected outliers: none (detect only), flag (mark in output), remove (exclude from clustering). Default: flag.",
    # outlier_threshold
    "Z-score threshold for outlier detection (zscore method only). Range: 1.0-5.0. Default: 3.0.",
    # outlier_alpha
    "Significance level for Mahalanobis distance (mahalanobis method only). Range: 0.0001-0.1. Default: 0.001.",
    # outlier_min_vars
    "Minimum number of variables a case must be outlier on (zscore method). Must not exceed the number of clustering variables. Default: 1.",
    "",
    # VARIABLE SELECTION section header
    "",
    # variable_selection
    "Enable automatic variable reduction from a large candidate set. TRUE/FALSE. Default: FALSE.",
    # variable_selection_method
    "Selection algorithm: variance_correlation (remove low variance + high correlation), factor_analysis (use factor loadings), both (two-stage). Default: variance_correlation.",
    # max_clustering_vars
    "Target number of variables to retain after selection. Range: 2-20. Default: 10.",
    # varsel_min_variance
    "Minimum variance threshold to keep a variable (on standardized data). Range: 0.01-1.0. Default: 0.1.",
    # varsel_max_correlation
    "Maximum pairwise correlation before one variable is removed. Range: 0.5-0.95. Default: 0.8.",
    "",
    # VALIDATION section header
    "",
    # k_selection_metrics
    "Comma-separated metrics for choosing optimal k in exploration mode. Options: silhouette, elbow, gap. Default: silhouette,elbow.",
    "",
    # ENHANCED FEATURES section header
    "",
    # generate_rules
    "Generate classification rules (decision tree) for assigning new cases to segments. TRUE/FALSE. Default: FALSE.",
    # generate_action_cards
    "Generate summary action cards for each segment with key characteristics and recommendations. TRUE/FALSE. Default: FALSE.",
    # run_stability_check
    "Run bootstrap stability analysis to assess segment robustness. TRUE/FALSE. Default: FALSE. Can be slow for large datasets.",
    # rules_max_depth
    "Maximum depth of the decision tree for classification rules. Range: 1-5. Default: 3.",
    # stability_n_runs
    "Number of bootstrap iterations for stability analysis. Range: 3-20. Default: 5. Higher = more reliable but slower.",
    # segment_names
    "Custom segment names (comma-separated) or 'auto' for automatic naming. Must match k_fixed count if set. Example: Budget,Premium,Loyal. Default: auto.",
    # auto_name_style
    "Style for auto-generated segment names: descriptive (detailed), persona (character-based), simple (Segment 1, 2, ...). Default: descriptive.",
    # golden_questions_n
    "Number of top discriminating questions to identify per segment. Range: 1-10. Default: 3.",
    # scale_max
    "Maximum value of the rating scale used in the data (for profile chart labelling). Range: 1-100. Default: 10.",
    # use_lca
    "Use Latent Class Analysis instead of standard clustering. TRUE/FALSE. Default: FALSE. Experimental feature.",
    # question_labels_file
    "Path to an Excel file with variable labels (two columns: variable, label). Used for readable chart and report labels. Leave blank if not needed.",
    "",
    # OUTPUT SETTINGS section header
    "",
    # output_folder
    "Folder path for saving output files. Created automatically if it does not exist. Default: output.",
    # output_prefix
    "Prefix for all output filenames. Default: seg_. Example: seg_exploration_report.xlsx.",
    # create_dated_folder
    "Create a timestamped subfolder inside output_folder for each run. TRUE/FALSE. Default: TRUE.",
    # save_model
    "Save the clustering model as an RDS file for scoring new data later. TRUE/FALSE. Default: TRUE.",
    "",
    # HTML REPORT section header
    "",
    # html_report
    "Generate an interactive HTML report with charts and tables. TRUE/FALSE. Default: FALSE.",
    # brand_colour
    "Primary brand colour for the HTML report (hex code). Default: #323367.",
    # accent_colour
    "Accent colour for highlights in the HTML report (hex code). Default: #CC9900.",
    # report_title
    "Title displayed at the top of the HTML report. Default: Segmentation Report.",
    # html_show_exec_summary
    "Show the executive summary section in the HTML report. TRUE/FALSE. Default: TRUE.",
    # html_show_overview
    "Show the analysis overview section. TRUE/FALSE. Default: TRUE.",
    # html_show_validation
    "Show cluster validation metrics section. TRUE/FALSE. Default: TRUE.",
    # html_show_importance
    "Show variable importance section. TRUE/FALSE. Default: TRUE.",
    # html_show_profiles
    "Show segment profile charts and tables. TRUE/FALSE. Default: TRUE.",
    # html_show_demographics
    "Show demographic cross-tabulation section. TRUE/FALSE. Default: TRUE.",
    # html_show_rules
    "Show classification rules section (requires generate_rules = TRUE). TRUE/FALSE. Default: TRUE.",
    # html_show_cards
    "Show segment action cards section (requires generate_action_cards = TRUE). TRUE/FALSE. Default: TRUE.",
    # html_show_stability
    "Show stability analysis section (requires run_stability_check = TRUE). TRUE/FALSE. Default: TRUE.",
    # html_show_membership
    "Show segment membership details section. TRUE/FALSE. Default: TRUE.",
    # html_show_guide
    "Show the interpretation guide section with methodology notes. TRUE/FALSE. Default: TRUE.",
    "",
    # METADATA section header
    "",
    # project_name
    "Project name for report headers and file metadata. Default: Segmentation Analysis.",
    # analyst_name
    "Analyst name for report attribution. Default: Analyst.",
    # description
    "Free-text description of the analysis for documentation purposes."
  ),
  stringsAsFactors = FALSE
)

writeData(wb, "Instructions", instructions, startRow = 1, startCol = 1, headerStyle = instr_header_style)

# Identify section header rows on Instructions sheet
instr_section_names <- c(
  "CORE SETTINGS", "ALGORITHM SETTINGS", "DATA HANDLING",
  "OUTLIER DETECTION", "VARIABLE SELECTION", "VALIDATION",
  "ENHANCED FEATURES", "OUTPUT SETTINGS", "HTML REPORT", "METADATA"
)
for (i in seq_len(nrow(instructions))) {
  r <- i + 1  # +1 for header
  if (instructions$Parameter[i] %in% instr_section_names) {
    addStyle(wb, "Instructions", instr_section_style, rows = r, cols = 1:2, gridExpand = TRUE)
  } else if (i <= 9) {
    # Title and how-to rows
    if (i == 1) {
      addStyle(wb, "Instructions",
               createStyle(fontName = "Arial", fontSize = 10, textDecoration = "bold",
                           wrapText = TRUE),
               rows = r, cols = 1:2, gridExpand = TRUE)
    } else {
      addStyle(wb, "Instructions",
               createStyle(fontName = "Arial", fontSize = 10, wrapText = TRUE),
               rows = r, cols = 1:2, gridExpand = TRUE)
    }
  } else if (instructions$Parameter[i] != "") {
    addStyle(wb, "Instructions", instr_body_style, rows = r, cols = 1:2, gridExpand = TRUE)
  }
}

# Title row special formatting
addStyle(wb, "Instructions",
         createStyle(fontName = "Arial", fontSize = 14, textDecoration = "bold",
                     fontColour = "#323367"),
         rows = 2, cols = 1)

# Set column widths
setColWidths(wb, "Instructions", cols = 1, widths = 35)
setColWidths(wb, "Instructions", cols = 2, widths = 85)

# Freeze header
freezePane(wb, "Instructions", firstRow = TRUE)

# ==============================================================================
# SAVE
# ==============================================================================

output_path <- "modules/segment/docs/templates/Segment_Config_Template.xlsx"
saveWorkbook(wb, output_path, overwrite = TRUE)

cat(sprintf("Template created successfully: %s\n", output_path))
cat(sprintf("  Config sheet: %d parameters across %d sections\n",
            nrow(settings) - length(section_rows), length(section_rows)))
cat(sprintf("  Instructions sheet: %d entries\n", nrow(instructions)))
