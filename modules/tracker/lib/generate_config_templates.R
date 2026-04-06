# ==============================================================================
# GENERATE_CONFIG_TEMPLATES.R - TURAS Tracker Module
# ==============================================================================
# Creates professional, hardened Excel config templates with:
#   - Data validation (dropdown lists) for all option fields
#   - Visual formatting (branded colours, section grouping)
#   - Help text descriptors for every field
#   - Required/Optional markers
#   - Protected non-editable areas (headers, descriptors)
#   - Every permutation and option documented
#
# USAGE:
#   source("modules/tracker/lib/generate_config_templates.R")
#   generate_tracking_config_template("path/to/output/Tracking_Config.xlsx")
#   generate_question_mapping_template("path/to/output/Question_Mapping.xlsx")
#   # Or generate both:
#   generate_all_tracker_templates("path/to/output/")
#
# DEPENDENCIES:
#   - modules/shared/template_styles.R (write_settings_sheet, write_table_sheet)
#
# ==============================================================================

library(openxlsx)

# Source shared template infrastructure
.tracker_gen_root <- tryCatch(
  dirname(dirname(dirname(sys.frame(1)$ofile))),
  error = function(e) getwd()
)
if (!nzchar(.tracker_gen_root) || .tracker_gen_root == ".") {
  .tracker_gen_root <- getwd()
}
source(file.path(.tracker_gen_root, "shared", "template_styles.R"))


# ==============================================================================
# TRACKING CONFIG TEMPLATE
# ==============================================================================

#' Generate Tracking Config Template
#'
#' Creates a professional Excel config template for the TURAS Tracker module
#' with four sheets: Settings, Waves, TrackedQuestions, and Banner.
#'
#' @param output_path Full path for the output .xlsx file
#' @return Invisible path to the created file
#' @export
generate_tracking_config_template <- function(output_path) {
  cat(sprintf("  Generating tracking config template: %s\n", output_path))

  wb <- createWorkbook()

  # ============================================================================
  # SHEET 1: Settings
  # ============================================================================

  settings_def <- list(

    # --- PROJECT section ---
    list(
      section_name = "PROJECT",
      fields = list(
        list(
          name = "project_name",
          required = TRUE,
          default = "",
          description = "Name of the tracking study project",
          valid_values_text = "Free text (e.g., Brand Health Tracker 2025)"
        ),
        list(
          name = "output_file",
          required = FALSE,
          default = "",
          description = "Output filename (auto-generated if blank)",
          valid_values_text = "Filename without path (e.g., tracker_results.xlsx)"
        ),
        list(
          name = "output_dir",
          required = FALSE,
          default = "",
          description = "Output directory (defaults to config file directory)",
          valid_values_text = "Relative or absolute directory path"
        ),
        list(
          name = "question_mapping_file",
          required = FALSE,
          default = "",
          description = "Path to question mapping file (auto-detected if blank)",
          valid_values_text = "Filename, relative path, or absolute path (e.g., Question_Mapping.xlsx)"
        )
      )
    ),

    # --- REPORTS section ---
    list(
      section_name = "REPORTS",
      fields = list(
        list(
          name = "report_types",
          required = FALSE,
          default = "detailed",
          description = "Comma-separated list of report types to generate",
          valid_values_text = "detailed, wave_history, dashboard, sig_matrix, tracking_crosstab",
          dropdown = c("detailed", "wave_history", "dashboard", "sig_matrix",
                       "tracking_crosstab",
                       "detailed,wave_history", "detailed,dashboard",
                       "detailed,wave_history,dashboard,sig_matrix",
                       "detailed,wave_history,dashboard,sig_matrix,tracking_crosstab")
        ),
        list(
          name = "html_report",
          required = FALSE,
          default = "N",
          description = "Generate interactive HTML report alongside Excel",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "dashboard_hero_metrics",
          required = FALSE,
          default = "",
          description = "Comma-separated QuestionCodes to highlight as hero metrics on the HTML dashboard summary",
          valid_values_text = "QuestionCodes from TrackedQuestions (e.g., Q01_NPS,Q02_CSAT)"
        )
      )
    ),

    # --- FORMATTING section ---
    list(
      section_name = "FORMATTING",
      fields = list(
        list(
          name = "decimal_places_ratings",
          required = FALSE,
          default = 1,
          description = "Decimal places for rating/mean scores",
          valid_values_text = "Integer 0-3",
          integer_range = c(0, 3)
        ),
        list(
          name = "decimal_places_nps",
          required = FALSE,
          default = 2,
          description = "Decimal places for NPS scores",
          valid_values_text = "Integer 0-3",
          integer_range = c(0, 3)
        ),
        list(
          name = "decimal_places_percentages",
          required = FALSE,
          default = 0,
          description = "Decimal places for percentage values",
          valid_values_text = "Integer 0-3",
          integer_range = c(0, 3)
        ),
        list(
          name = "decimal_separator",
          required = FALSE,
          default = ".",
          description = "Character used as decimal separator in output",
          valid_values_text = ". or ,",
          dropdown = c(".", ",")
        )
      )
    ),

    # --- STATISTICS section ---
    list(
      section_name = "STATISTICS",
      fields = list(
        list(
          name = "alpha",
          required = FALSE,
          default = 0.05,
          description = "Significance level for hypothesis tests",
          valid_values_text = "Numeric 0.01-0.10",
          numeric_range = c(0.01, 0.10)
        ),
        list(
          name = "confidence_level",
          required = FALSE,
          default = "0.95",
          description = "Confidence level for interval estimation",
          valid_values_text = "0.90, 0.95, or 0.99",
          dropdown = c("0.90", "0.95", "0.99")
        ),
        list(
          name = "minimum_base",
          required = FALSE,
          default = 30,
          description = "Minimum sample size for reporting (suppress below this)",
          valid_values_text = "Integer 10-500",
          integer_range = c(10, 500)
        ),
        list(
          name = "show_significance",
          required = FALSE,
          default = "Y",
          description = "Show significance indicators in output",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "baseline_wave",
          required = FALSE,
          default = "",
          description = "WaveID to use as baseline for significance testing (defaults to first wave)",
          valid_values_text = "A WaveID from the Waves sheet (e.g., W1)"
        ),
        list(
          name = "show_sample_sizes",
          required = FALSE,
          default = "Y",
          description = "Display sample sizes (n=) in report output",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        )
      )
    ),

    # --- WEIGHTING section ---
    list(
      section_name = "WEIGHTING",
      fields = list(
        list(
          name = "weight_variable",
          required = FALSE,
          default = "",
          description = "Column name containing survey weights (leave blank for unweighted)",
          valid_values_text = "Column name in wave data files (e.g., wgt)"
        )
      )
    ),

    # --- BRANDING section ---
    list(
      section_name = "BRANDING",
      fields = list(
        list(
          name = "brand_colour",
          required = FALSE,
          default = "#323367",
          description = "Primary brand colour for report headers and charts",
          valid_values_text = "Hex colour code (e.g., #323367)"
        ),
        list(
          name = "accent_colour",
          required = FALSE,
          default = "#CC9900",
          description = "Accent colour for highlights and secondary elements",
          valid_values_text = "Hex colour code (e.g., #CC9900)"
        ),
        list(
          name = "company_name",
          required = FALSE,
          default = "",
          description = "Research company name for report branding",
          valid_values_text = "Free text"
        ),
        list(
          name = "client_name",
          required = FALSE,
          default = "",
          description = "Client name for report title page",
          valid_values_text = "Free text"
        ),
        list(
          name = "researcher_logo_path",
          required = FALSE,
          default = "",
          description = "Path to researcher company logo image file",
          valid_values_text = "Relative or absolute path to PNG/JPG file"
        ),
        list(
          name = "analyst_name",
          required = FALSE,
          default = "",
          description = "Analyst name for report footer",
          valid_values_text = "Free text"
        ),
        list(
          name = "analyst_email",
          required = FALSE,
          default = "",
          description = "Analyst email for report footer",
          valid_values_text = "Email address"
        ),
        list(
          name = "analyst_phone",
          required = FALSE,
          default = "",
          description = "Analyst phone number for report footer",
          valid_values_text = "Phone number"
        )
      )
    ),

    # --- DEFAULT TRACKING SPECS section ---
    list(
      section_name = "DEFAULT TRACKING SPECS",
      fields = list(
        list(
          name = "default_rating_specs",
          required = FALSE,
          default = "",
          description = "Default TrackingSpecs for Rating/Likert questions (used when TrackingSpecs is blank)",
          valid_values_text = "Comma-separated: mean, top_box, top2_box, top3_box, bottom_box, bottom2_box, distribution, range:X-Y"
        ),
        list(
          name = "default_nps_specs",
          required = FALSE,
          default = "",
          description = "Default TrackingSpecs for NPS questions (used when TrackingSpecs is blank)",
          valid_values_text = "Comma-separated: nps_score, promoters_pct, passives_pct, detractors_pct, full"
        ),
        list(
          name = "default_single_response_specs",
          required = FALSE,
          default = "",
          description = "Default TrackingSpecs for Single_Response questions (used when TrackingSpecs is blank)",
          valid_values_text = "Comma-separated: all, top3, category:X"
        ),
        list(
          name = "default_multi_mention_specs",
          required = FALSE,
          default = "",
          description = "Default TrackingSpecs for Multi_Mention questions (used when TrackingSpecs is blank)",
          valid_values_text = "Comma-separated: auto, any, count_mean, count_distribution, option:X, category:X"
        ),
        list(
          name = "default_composite_specs",
          required = FALSE,
          default = "",
          description = "Default TrackingSpecs for Composite/Index questions (used when TrackingSpecs is blank)",
          valid_values_text = "Comma-separated: mean, top_box, top2_box, top3_box, distribution, range:X-Y"
        )
      )
    ),

    # --- HEATMAP THRESHOLDS section ---
    list(
      section_name = "HEATMAP THRESHOLDS",
      fields = list(
        list(
          name = "heatmap_pct_green",
          required = FALSE,
          default = 70,
          description = "Percentage threshold for green (good) heatmap colouring",
          valid_values_text = "Numeric 0-100",
          integer_range = c(0, 100)
        ),
        list(
          name = "heatmap_pct_amber",
          required = FALSE,
          default = 50,
          description = "Percentage threshold for amber (caution) heatmap colouring",
          valid_values_text = "Numeric 0-100",
          integer_range = c(0, 100)
        ),
        list(
          name = "heatmap_mean5_green",
          required = FALSE,
          default = "4.0",
          description = "Mean score (5-point scale) threshold for green heatmap colouring",
          valid_values_text = "Numeric 1.0-5.0"
        ),
        list(
          name = "heatmap_mean5_amber",
          required = FALSE,
          default = "3.0",
          description = "Mean score (5-point scale) threshold for amber heatmap colouring",
          valid_values_text = "Numeric 1.0-5.0"
        ),
        list(
          name = "heatmap_mean10_green",
          required = FALSE,
          default = "7.0",
          description = "Mean score (10-point scale) threshold for green heatmap colouring",
          valid_values_text = "Numeric 1.0-10.0"
        ),
        list(
          name = "heatmap_mean10_amber",
          required = FALSE,
          default = "5.0",
          description = "Mean score (10-point scale) threshold for amber heatmap colouring",
          valid_values_text = "Numeric 1.0-10.0"
        ),
        list(
          name = "heatmap_nps_green",
          required = FALSE,
          default = 30,
          description = "NPS threshold for green heatmap colouring",
          valid_values_text = "Integer -100 to 100",
          integer_range = c(-100, 100)
        ),
        list(
          name = "heatmap_nps_amber",
          required = FALSE,
          default = 0,
          description = "NPS threshold for amber heatmap colouring",
          valid_values_text = "Integer -100 to 100",
          integer_range = c(-100, 100)
        ),
        list(
          name = "heatmap_response_green",
          required = FALSE,
          default = 50,
          description = "Response percentage threshold for green heatmap colouring (pct_response metrics)",
          valid_values_text = "Numeric 0-100",
          integer_range = c(0, 100)
        ),
        list(
          name = "heatmap_response_amber",
          required = FALSE,
          default = 25,
          description = "Response percentage threshold for amber heatmap colouring (pct_response metrics)",
          valid_values_text = "Numeric 0-100",
          integer_range = c(0, 100)
        )
      )
    ),

    # --- CHARTS section ---
    list(
      section_name = "CHARTS",
      fields = list(
        list(
          name = "segment_palette_preset",
          required = FALSE,
          default = "default",
          description = "Colour palette preset for banner segment charts in HTML reports",
          valid_values_text = "default, muted, vibrant, or monochrome",
          dropdown = c("default", "muted", "vibrant", "monochrome")
        )
      )
    ),

    # --- OTHER section ---
    list(
      section_name = "OTHER",
      fields = list(
        list(
          name = "verbatim_filename",
          required = FALSE,
          default = "",
          description = "Filename for separate verbatim/open-end export",
          valid_values_text = "Filename (e.g., verbatims.xlsx)"
        ),
        list(
          name = "closing_notes",
          required = FALSE,
          default = "",
          description = "Notes to include in report appendix or footer",
          valid_values_text = "Free text"
        ),
        list(
          name = "annotations",
          required = FALSE,
          default = "",
          description = "Pre-configured chart annotations as JSON array (e.g., [{\"metricId\":\"Q01\",\"waveId\":\"W2\",\"text\":\"Campaign launched\"}])",
          valid_values_text = "JSON array string or leave blank"
        ),
        list(
          name = "Generate_Stats_Pack",
          required = FALSE,
          default = "Y",
          description = "Generate a diagnostic stats pack workbook alongside main output. The stats pack provides a full audit trail of data received, methods used, assumptions, and reproducibility — designed for advanced partners and research statisticians. Output file is named {output}_stats_pack.xlsx.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        )
      )
    ),

    # --- STUDY IDENTIFICATION section ---
    list(
      section_name = "STUDY IDENTIFICATION",
      fields = list(
        list(
          name = "Project_Name",
          required = FALSE,
          default = "",
          description = "Project name — appears in the stats pack Declaration sheet for identification and sign-off purposes. Leave blank if not using stats pack.",
          valid_values_text = "Free text"
        ),
        list(
          name = "Analyst_Name",
          required = FALSE,
          default = "",
          description = "Analyst name — appears in the stats pack Declaration sheet.",
          valid_values_text = "Free text"
        ),
        list(
          name = "Research_House",
          required = FALSE,
          default = "",
          description = "Research organisation name — appears in the stats pack Declaration sheet. Use your company or white-label partner name.",
          valid_values_text = "Free text"
        )
      )
    )
  )

  write_settings_sheet(
    wb, "Settings", settings_def,
    title = "TURAS Tracker - Configuration Settings",
    subtitle = "Fill in the Value column. Required fields are marked in orange. Hover over cells for guidance."
  )

  # ============================================================================
  # SHEET 2: Waves
  # ============================================================================

  waves_columns <- list(
    list(
      name = "WaveID", width = 15, required = TRUE,
      description = "Unique short identifier for each wave (used in column headers and references)"
    ),
    list(
      name = "WaveName", width = 22, required = TRUE,
      description = "Descriptive name for display in reports and charts"
    ),
    list(
      name = "DataFile", width = 35, required = TRUE,
      description = "Path to wave data file (relative to config file location or absolute)"
    ),
    list(
      name = "FieldworkStart", width = 16, required = FALSE,
      description = "Fieldwork start date (YYYY-MM-DD format)"
    ),
    list(
      name = "FieldworkEnd", width = 16, required = FALSE,
      description = "Fieldwork end date (YYYY-MM-DD format)"
    ),
    list(
      name = "WeightVar", width = 18, required = FALSE,
      description = "Wave-specific weight column name (overrides global weight_variable)"
    ),
    list(
      name = "StructureFile", width = 30, required = FALSE,
      description = "Path to wave-specific survey structure file (if different per wave)"
    ),
    list(
      name = "ConfigFile", width = 30, required = FALSE,
      description = "Path to wave-specific config overrides file"
    )
  )

  waves_examples <- list(
    list(
      WaveID = "W1", WaveName = "Wave 1 - Oct 2024",
      DataFile = "data/wave1_data.csv",
      FieldworkStart = "2024-10-01", FieldworkEnd = "2024-10-15",
      WeightVar = "wgt", StructureFile = "", ConfigFile = ""
    ),
    list(
      WaveID = "W2", WaveName = "Wave 2 - Jan 2025",
      DataFile = "data/wave2_data.csv",
      FieldworkStart = "2025-01-05", FieldworkEnd = "2025-01-20",
      WeightVar = "wgt", StructureFile = "", ConfigFile = ""
    ),
    list(
      WaveID = "W3", WaveName = "Wave 3 - Apr 2025",
      DataFile = "data/wave3_data.csv",
      FieldworkStart = "2025-04-01", FieldworkEnd = "2025-04-15",
      WeightVar = "wgt", StructureFile = "", ConfigFile = ""
    )
  )

  write_table_sheet(
    wb, "Waves", waves_columns,
    title = "TURAS Tracker - Wave Definitions",
    subtitle = "Define each wave of your tracking study. Waves should be listed in chronological order.",
    example_rows = waves_examples,
    num_blank_rows = 20
  )

  # ============================================================================
  # SHEET 3: TrackedQuestions
  # ============================================================================

  tracked_questions_columns <- list(
    list(
      name = "QuestionCode", width = 22, required = TRUE,
      description = "Unique code identifying this tracked metric across waves"
    ),
    list(
      name = "QuestionText", width = 40, required = FALSE,
      description = "Full question text for report labels and tooltips"
    ),
    list(
      name = "QuestionType", width = 20, required = FALSE,
      description = "Type of question determining calculation method",
      dropdown = c("Rating", "NPS", "Single_Response", "Multi_Mention", "Composite")
    ),
    list(
      name = "MetricLabel", width = 25, required = FALSE,
      description = "Short label for the primary metric (e.g., '% Aware', 'Mean Score')"
    ),
    list(
      name = "Section", width = 22, required = FALSE,
      description = "Report section grouping (questions in same section appear together)"
    ),
    list(
      name = "SortOrder", width = 12, required = FALSE,
      description = "Display order within the report (1 = first)",
      integer_range = c(1, 999)
    ),
    list(
      name = "TrackingSpecs", width = 40, required = FALSE,
      description = "Comma-separated metrics to calculate: mean, top_box, top2_box, top3_box, bottom_box, bottom2_box, bottom3_box, distribution, nps_score, promoters_pct, passives_pct, detractors_pct, full, all, auto, count_mean, count_distribution, range:X-Y, box:CATEGORY, category:X, option:X. Append =Label for custom display names (e.g., range:4-5=Agree)"
    )
  )

  tracked_questions_examples <- list(
    list(
      QuestionCode = "Q01_Awareness", QuestionText = "Brand Awareness",
      QuestionType = "Single_Response", MetricLabel = "% Aware",
      Section = "Brand Health", SortOrder = 1, TrackingSpecs = "all"
    ),
    list(
      QuestionCode = "Q02_Satisfaction", QuestionText = "Overall Satisfaction (1-10)",
      QuestionType = "Rating", MetricLabel = "Mean Score",
      Section = "Satisfaction", SortOrder = 2, TrackingSpecs = "mean,top2_box"
    ),
    list(
      QuestionCode = "Q03_NPS", QuestionText = "Net Promoter Score",
      QuestionType = "NPS", MetricLabel = "NPS Score",
      Section = "Loyalty", SortOrder = 3,
      TrackingSpecs = "nps_score,promoters_pct,detractors_pct"
    ),
    list(
      QuestionCode = "Q04_Purchase", QuestionText = "Purchase Intent",
      QuestionType = "Single_Response", MetricLabel = "% Likely",
      Section = "Intent", SortOrder = 4, TrackingSpecs = "category:Very Likely"
    ),
    list(
      QuestionCode = "Q05_Features", QuestionText = "Features Used",
      QuestionType = "Multi_Mention", MetricLabel = "% Mentioning",
      Section = "Usage", SortOrder = 5, TrackingSpecs = "auto"
    ),
    list(
      QuestionCode = "Q06_Agreement", QuestionText = "Service Agreement (1-5)",
      QuestionType = "Rating", MetricLabel = "% Agree",
      Section = "Satisfaction", SortOrder = 6,
      TrackingSpecs = "mean,box:Agree=Top Box,bottom_box"
    ),
    list(
      QuestionCode = "Q07_CX_Index", QuestionText = "Customer Experience Index",
      QuestionType = "Composite", MetricLabel = "CX Score",
      Section = "Summary Indices", SortOrder = 7, TrackingSpecs = "mean,top2_box"
    )
  )

  write_table_sheet(
    wb, "TrackedQuestions", tracked_questions_columns,
    title = "TURAS Tracker - Tracked Questions",
    subtitle = "Define the questions/metrics to track across waves. Each row is one tracked metric.",
    example_rows = tracked_questions_examples,
    num_blank_rows = 50
  )

  # ============================================================================
  # SHEET 4: Banner
  # ============================================================================

  banner_columns <- list(
    list(
      name = "BreakVariable", width = 22, required = TRUE,
      description = "Canonical variable name for this banner break (e.g., Total, Region)"
    ),
    list(
      name = "BreakLabel", width = 25, required = TRUE,
      description = "Display label for this banner break in report headers"
    ),
    list(
      name = "W1", width = 18, required = FALSE,
      description = "Column name in Wave 1 data for this break variable"
    ),
    list(
      name = "W2", width = 18, required = FALSE,
      description = "Column name in Wave 2 data for this break variable"
    ),
    list(
      name = "W3", width = 18, required = FALSE,
      description = "Column name in Wave 3 data for this break variable"
    ),
    list(
      name = "W4", width = 18, required = FALSE,
      description = "Column name in Wave 4 data for this break variable"
    )
  )

  banner_examples <- list(
    list(
      BreakVariable = "Total", BreakLabel = "All Respondents",
      W1 = "Total", W2 = "Total", W3 = "Total", W4 = "Total"
    ),
    list(
      BreakVariable = "Region", BreakLabel = "Region",
      W1 = "Q_Region", W2 = "Q_Region", W3 = "DEM_Region", W4 = "DEM_Region"
    ),
    list(
      BreakVariable = "AgeGroup", BreakLabel = "Age Group",
      W1 = "Q_Age", W2 = "Q_Age", W3 = "DEM_Age", W4 = "DEM_Age"
    ),
    list(
      BreakVariable = "Gender", BreakLabel = "Gender",
      W1 = "Q_Gender", W2 = "Q_Gender", W3 = "DEM_Gender", W4 = "DEM_Gender"
    )
  )

  write_table_sheet(
    wb, "Banner", banner_columns,
    title = "TURAS Tracker - Banner Definitions",
    subtitle = "Define banner break variables for subgroup analysis. Column names can differ across waves. Add more wave columns (W5, W6, ...) as needed.",
    example_rows = banner_examples,
    num_blank_rows = 20
  )

  # ============================================================================
  # Save workbook
  # ============================================================================

  saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(sprintf("  Created: %s\n", output_path))
  cat(sprintf("    Sheets: Settings, Waves, TrackedQuestions, Banner\n"))

  invisible(output_path)
}


# ==============================================================================
# QUESTION MAPPING TEMPLATE
# ==============================================================================

#' Generate Question Mapping Template
#'
#' Creates a professional Excel template for mapping question codes across
#' waves when variable names differ between data files.
#'
#' @param output_path Full path for the output .xlsx file
#' @return Invisible path to the created file
#' @export
generate_question_mapping_template <- function(output_path) {
  cat(sprintf("  Generating question mapping template: %s\n", output_path))

  wb <- createWorkbook()

  # ============================================================================
  # SHEET 1: QuestionMap
  # ============================================================================

  question_map_columns <- list(
    list(
      name = "QuestionCode", width = 22, required = TRUE,
      description = "Canonical question code used across the tracking study (must match TrackedQuestions)"
    ),
    list(
      name = "QuestionText", width = 40, required = FALSE,
      description = "Full question wording for documentation and report labels"
    ),
    list(
      name = "QuestionType", width = 20, required = FALSE,
      description = "Type of question for calculation method selection",
      dropdown = c("Rating", "NPS", "Single_Response", "Multi_Mention", "Composite")
    ),
    list(
      name = "W1", width = 18, required = FALSE,
      description = "Column name in Wave 1 data file for this question"
    ),
    list(
      name = "W2", width = 18, required = FALSE,
      description = "Column name in Wave 2 data file for this question"
    ),
    list(
      name = "W3", width = 18, required = FALSE,
      description = "Column name in Wave 3 data file for this question"
    ),
    list(
      name = "W4", width = 18, required = FALSE,
      description = "Column name in Wave 4 data file for this question"
    ),
    list(
      name = "ResponseScale", width = 25, required = FALSE,
      description = "Scale description for documentation (e.g., '1=Very Dissatisfied to 5=Very Satisfied')"
    ),
    list(
      name = "ScalePoints", width = 14, required = FALSE,
      description = "Number of scale points for rating questions (e.g., 5, 7, 10)",
      integer_range = c(2, 100)
    ),
    list(
      name = "SourceQuestions", width = 30, required = FALSE,
      description = "For Composite type: semicolon-separated list of source question codes that form the index"
    ),
    list(
      name = "TrackingSpecs", width = 40, required = FALSE,
      description = "Comma-separated metrics (legacy location; prefer TrackedQuestions sheet). Specs: mean, top_box, top2_box, top3_box, bottom_box, bottom2_box, bottom3_box, distribution, nps_score, promoters_pct, passives_pct, detractors_pct, full, all, auto, count_mean, count_distribution, range:X-Y, box:CATEGORY, category:X, option:X"
    )
  )

  question_map_examples <- list(
    list(
      QuestionCode = "Q01_Awareness", QuestionText = "Brand Awareness",
      QuestionType = "Single_Response",
      W1 = "Q10", W2 = "Q12", W3 = "Q15", W4 = "Q15",
      ResponseScale = "Yes / No / Not sure", ScalePoints = "",
      SourceQuestions = "", TrackingSpecs = "all"
    ),
    list(
      QuestionCode = "Q02_Satisfaction", QuestionText = "Overall Satisfaction (1-10)",
      QuestionType = "Rating",
      W1 = "Q20", W2 = "Q22", W3 = "Q25", W4 = "Q25",
      ResponseScale = "1=Very Dissatisfied to 10=Very Satisfied", ScalePoints = 10,
      SourceQuestions = "", TrackingSpecs = "mean,top2_box"
    ),
    list(
      QuestionCode = "Q03_NPS", QuestionText = "How likely to recommend? (0-10)",
      QuestionType = "NPS",
      W1 = "Q30", W2 = "Q32", W3 = "Q35", W4 = "Q35",
      ResponseScale = "0=Not at all likely to 10=Extremely likely", ScalePoints = 11,
      SourceQuestions = "", TrackingSpecs = "nps_score,promoters_pct,detractors_pct"
    ),
    list(
      QuestionCode = "Q04_Purchase", QuestionText = "How likely to purchase?",
      QuestionType = "Single_Response",
      W1 = "Q40", W2 = "Q42", W3 = "Q45", W4 = "Q45",
      ResponseScale = "Definitely / Probably / Might / Probably Not / Definitely Not", ScalePoints = 5,
      SourceQuestions = "", TrackingSpecs = "category:Definitely"
    ),
    list(
      QuestionCode = "Q05_Features", QuestionText = "Which features have you used?",
      QuestionType = "Multi_Mention",
      W1 = "Q50", W2 = "Q52", W3 = "Q55", W4 = "Q55",
      ResponseScale = "Select all that apply", ScalePoints = "",
      SourceQuestions = "Q50_1;Q50_2;Q50_3", TrackingSpecs = "auto"
    ),
    list(
      QuestionCode = "Q06_Agreement", QuestionText = "Service meets expectations (1-5)",
      QuestionType = "Rating",
      W1 = "Q60", W2 = "Q62", W3 = "Q65", W4 = "Q65",
      ResponseScale = "1=Strongly Disagree to 5=Strongly Agree", ScalePoints = 5,
      SourceQuestions = "", TrackingSpecs = "mean,box:Agree=Top Box"
    ),
    list(
      QuestionCode = "Q07_CX_Index", QuestionText = "Customer Experience Index",
      QuestionType = "Composite",
      W1 = "", W2 = "", W3 = "", W4 = "",
      ResponseScale = "Calculated index", ScalePoints = "",
      SourceQuestions = "Q02_Satisfaction;Q06_Agreement", TrackingSpecs = "mean"
    )
  )

  write_table_sheet(
    wb, "QuestionMap", question_map_columns,
    title = "TURAS Tracker - Question Mapping",
    subtitle = "Map canonical question codes to actual column names in each wave's data file. Add more wave columns (W5, W6, ...) as needed.",
    example_rows = question_map_examples,
    num_blank_rows = 50
  )

  # ============================================================================
  # Save workbook
  # ============================================================================

  saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(sprintf("  Created: %s\n", output_path))
  cat(sprintf("    Sheets: QuestionMap\n"))

  invisible(output_path)
}


# ==============================================================================
# GENERATE ALL TRACKER TEMPLATES
# ==============================================================================

#' Generate All Tracker Config Templates
#'
#' Creates both Tracking_Config and Question_Mapping templates in a directory.
#'
#' @param output_dir Directory to create templates in
#' @param config_filename Filename for config template (default: "Tracking_Config.xlsx")
#' @param mapping_filename Filename for mapping template (default: "Question_Mapping.xlsx")
#' @return Invisible list of created file paths
#' @export
generate_all_tracker_templates <- function(output_dir,
                                           config_filename = "Tracking_Config.xlsx",
                                           mapping_filename = "Question_Mapping.xlsx") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    cat(sprintf("  Created directory: %s\n", output_dir))
  }

  config_path <- file.path(output_dir, config_filename)
  mapping_path <- file.path(output_dir, mapping_filename)

  generate_tracking_config_template(config_path)
  generate_question_mapping_template(mapping_path)

  cat("\n  ========================================\n")
  cat("  All tracker templates generated successfully!\n")
  cat("  ========================================\n")
  cat(sprintf("  Config:  %s\n", config_path))
  cat(sprintf("  Mapping: %s\n", mapping_path))
  cat("\n  Next steps:\n")
  cat("  1. Open Tracking_Config.xlsx and fill in project settings, waves, and tracked questions\n")
  cat("  2. Open Question_Mapping.xlsx if variable names differ across waves\n")
  cat("  3. Place your wave data files in the paths specified in the Waves sheet\n")
  cat("  4. Run your tracking analysis!\n\n")

  invisible(list(config = config_path, mapping = mapping_path))
}
