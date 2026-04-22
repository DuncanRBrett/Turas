# ==============================================================================
# 3CAT SYNTHETIC EXAMPLE - Brand_Config.xlsx GENERATOR
# ==============================================================================
# Generates a fully-filled Brand_Config.xlsx for the IPK 3-category synthetic
# study (DSS + PAS + SLD). Uses the shared visual-polish template infrastructure
# (write_settings_sheet / write_table_sheet from modules/shared/template_styles.R).
#
# Depends on: 01_constants.R
# ==============================================================================


# ==============================================================================
# SETTINGS DEFINITION
# ==============================================================================

.build_3cat_settings_def <- function() {

  meta <- cat3_study_meta()
  cats <- cat3_categories()

  list(
    list(
      section_name = "STUDY IDENTIFICATION",
      fields = list(
        list(name = "project_name", required = TRUE, default = meta$project_name,
             description = "[REQUIRED] Project name for report titles and file naming",
             valid_values_text = "Free text"),
        list(name = "client_name", required = TRUE, default = meta$client_name,
             description = "[REQUIRED] Client organisation name",
             valid_values_text = "Free text"),
        list(name = "study_type", required = TRUE, default = meta$study_type,
             description = "[REQUIRED] Study design. Panel studies include respondent ID for longitudinal tracking",
             valid_values_text = "cross-sectional, panel",
             dropdown = c("cross-sectional", "panel")),
        list(name = "wave", required = TRUE, default = meta$wave,
             description = "[REQUIRED] Wave number. Wave 1 = baseline; wave 2+ enables tracker integration",
             valid_values_text = "Integer >= 1",
             integer_range = c(1, 100)),
        list(name = "data_file", required = TRUE, default = meta$data_file_name,
             description = "[REQUIRED] Path to survey data file. Relative paths resolve from this config's directory",
             valid_values_text = ".csv or .xlsx"),
        list(name = "respondent_id_col", required = FALSE, default = "Respondent_ID",
             description = "[Optional] Column name for respondent ID",
             valid_values_text = "Column name in data file"),
        list(name = "weight_variable", required = FALSE, default = "Weight",
             description = "[Optional] Column name for survey weight variable. Leave blank for unweighted",
             valid_values_text = "Column name in data file"),
        list(name = "focal_brand", required = TRUE, default = meta$focal_brand,
             description = "[REQUIRED] Focal brand code (must match Brands sheet in Survey_Structure)",
             valid_values_text = "Brand code")
      )
    ),

    list(
      section_name = "MULTI-CATEGORY ROUTING",
      fields = list(
        list(name = "focal_assignment", required = TRUE, default = "balanced",
             description = "[REQUIRED] How respondents are assigned to their focal category. 'balanced' = equal split; 'quota' = fixed targets; 'priority' = weighted",
             valid_values_text = "balanced, quota, priority",
             dropdown = c("balanced", "quota", "priority")),
        list(name = "focal_category_col", required = FALSE, default = "Focal_Category",
             description = "[Optional] Column in data containing the focal category assigned to each respondent",
             valid_values_text = "Column name in data file"),
        list(name = "cross_category_awareness", required = FALSE, default = "N",
             description = "[Optional] Collect brand awareness across all qualified categories (not just focal). Multi-category study: N unless cross-category tracking needed",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "cross_category_pen_light", required = FALSE, default = "N",
             description = "[Optional] Collect light brand penetration for non-focal categories",
             valid_values_text = "Y or N", dropdown = c("Y", "N"))
      )
    ),

    list(
      section_name = "ANALYTICAL ELEMENTS (Y = include, N = exclude)",
      fields = list(
        list(name = "element_funnel", required = FALSE, default = "Y",
             description = "[Optional] Brand funnel: Awareness > Disposition > Bought > Primary brand",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "element_mental_avail", required = FALSE, default = "Y",
             description = "[Optional] Mental Availability: MMS, MPen, NS, CEP x brand matrix. The analytical centrepiece",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "element_cep_turf", required = FALSE, default = "Y",
             description = "[Optional] CEP TURF reach optimisation within Mental Availability",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "element_repertoire", required = FALSE, default = "Y",
             description = "[Optional] Repertoire analysis: multi-brand buying, share of requirements",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "element_drivers_barriers", required = FALSE, default = "Y",
             description = "[Optional] Drivers & Barriers: derived importance x performance, rejection themes",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "element_dba", required = FALSE, default = "Y",
             description = "[Optional] Distinctive Brand Assets: Fame x Uniqueness grid for IPK's 5 assets (adds ~2 min runtime)",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "element_portfolio", required = FALSE, default = "Y",
             description = "[Optional] Portfolio analysis: compare IPK's mental availability and funnel across all 3 categories",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "element_wom", required = FALSE, default = "Y",
             description = "[Optional] Word-of-Mouth: received/shared x positive/negative (adds ~2 min runtime)",
             valid_values_text = "Y or N", dropdown = c("Y", "N"))
      )
    ),

    list(
      section_name = "DRIVERS & BARRIERS OPTIONS",
      fields = list(
        list(name = "db_use_catdriver", required = FALSE, default = "Y",
             description = "[Optional] Use catdriver module for derived importance via SHAP values",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "db_importance_method", required = FALSE, default = "differential",
             description = "[Optional] Fallback when catdriver is off: buyer vs non-buyer gap",
             valid_values_text = "differential",
             dropdown = c("differential"))
      )
    ),

    list(
      section_name = "DBA OPTIONS (only if element_dba = Y)",
      fields = list(
        list(name = "dba_scope", required = FALSE, default = "brand",
             description = "[Optional] DBA measurement scope. 'brand' = IPK vs all; 'category' = all brands",
             valid_values_text = "brand, category", dropdown = c("brand", "category")),
        list(name = "dba_fame_threshold", required = FALSE, default = 0.50,
             description = "[Optional] Fame threshold for quadrant classification (Famous vs Not Famous)",
             valid_values_text = "0.00 to 1.00", numeric_range = c(0, 1)),
        list(name = "dba_uniqueness_threshold", required = FALSE, default = 0.50,
             description = "[Optional] Uniqueness threshold for quadrant classification (Unique vs Generic)",
             valid_values_text = "0.00 to 1.00", numeric_range = c(0, 1)),
        list(name = "dba_attribution_type", required = FALSE, default = "open",
             description = "[Optional] DBA attribution: 'open' = open-ended brand name; 'closed_list' = forced choice",
             valid_values_text = "open, closed_list", dropdown = c("open", "closed_list"))
      )
    ),

    list(
      section_name = "WOM OPTIONS (only if element_wom = Y)",
      fields = list(
        list(name = "wom_timeframe", required = FALSE, default = "3 months",
             description = "[Optional] WOM recall timeframe. Should match the target purchase timeframe",
             valid_values_text = "Free text e.g. '3 months'")
      )
    ),

    list(
      section_name = "SIGNIFICANCE TESTING",
      fields = list(
        list(name = "alpha", required = FALSE, default = 0.05,
             description = "[Optional] Primary significance level for cross-brand comparisons",
             valid_values_text = "0.01 to 0.20", numeric_range = c(0.01, 0.20)),
        list(name = "alpha_secondary", required = FALSE, default = "",
             description = "[Optional] Secondary significance level for dual-alpha display. Leave blank to disable",
             valid_values_text = "0.01 to 0.20 or blank"),
        list(name = "min_base_size", required = FALSE, default = 30,
             description = "[Optional] Cells below this base size are suppressed in output",
             valid_values_text = "Integer >= 10", integer_range = c(10, 500)),
        list(name = "low_base_warning", required = FALSE, default = 75,
             description = "[Optional] Base size below which a low-base caution flag is shown (Romaniuk: n<75 is shaky)",
             valid_values_text = "Integer >= 30", integer_range = c(30, 500))
      )
    ),

    list(
      section_name = "COLOUR PALETTE (data elements only - chrome stays Turas navy)",
      fields = list(
        list(name = "colour_focal", required = FALSE, default = "#C8102E",
             description = "[Optional] Saturated colour for focal brand (IPK brand red)",
             valid_values_text = "Hex colour e.g. #C8102E"),
        list(name = "colour_focal_accent", required = FALSE, default = "#8B0000",
             description = "[Optional] Accent colour for focal brand secondary elements",
             valid_values_text = "Hex colour"),
        list(name = "colour_competitor", required = FALSE, default = "#B0B0B0",
             description = "[Optional] Desaturated colour for competitor brands (design principle: grey back competitors)",
             valid_values_text = "Hex colour"),
        list(name = "colour_category_avg", required = FALSE, default = "#808080",
             description = "[Optional] Colour for category average reference lines",
             valid_values_text = "Hex colour")
      )
    ),

    list(
      section_name = "OUTPUT OPTIONS",
      fields = list(
        list(name = "output_dir", required = TRUE, default = "output",
             description = "[REQUIRED] Output directory. Relative paths resolve from this config's directory",
             valid_values_text = "Relative path"),
        list(name = "output_html", required = FALSE, default = "Y",
             description = "[Optional] Generate HTML report via report_hub",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "output_excel", required = FALSE, default = "Y",
             description = "[Optional] Generate Excel workbook with all element data",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "output_csv", required = FALSE, default = "Y",
             description = "[Optional] Generate CSV files per element in long format",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "tracker_ids", required = FALSE, default = "Y",
             description = "[Optional] Include stable metric IDs for wave-over-wave tracking",
             valid_values_text = "Y or N", dropdown = c("Y", "N"))
      )
    ),

    list(
      section_name = "REPORT OPTIONS",
      fields = list(
        list(name = "report_title", required = FALSE,
             default = sprintf("%s Brand Health", meta$client_name),
             description = "[Optional] Title displayed in HTML report header",
             valid_values_text = "Free text"),
        list(name = "report_subtitle", required = FALSE,
             default = sprintf("Wave %d Baseline - Multi-Category (DSS, PAS, SLD)", meta$wave),
             description = "[Optional] Subtitle for the HTML report header",
             valid_values_text = "Free text"),
        list(name = "show_about_section", required = FALSE, default = "Y",
             description = "[Optional] Include About & Methodology section with EBI references",
             valid_values_text = "Y or N", dropdown = c("Y", "N")),
        list(name = "structure_file", required = TRUE, default = "Survey_Structure.xlsx",
             description = "[REQUIRED] Path to Survey_Structure.xlsx (relative to this config file)",
             valid_values_text = "Relative path to .xlsx file")
      )
    )
  )
}


# ==============================================================================
# CATEGORIES SHEET  (3 rows: DSS, PAS, SLD)
# ==============================================================================

.build_3cat_categories_rows <- function() {
  lapply(cat3_categories(), function(c) list(
    Category         = c$name,
    Type             = c$type,
    Timeframe_Long   = c$timeframe_long,
    Timeframe_Target = c$timeframe_target,
    Focal_Weight     = round(1 / 3, 4)   # balanced: equal weight across 3 categories
  ))
}


# ==============================================================================
# DBA_ASSETS SHEET  (5 rows: IPK's distinctive assets)
# ==============================================================================

.build_3cat_dba_assets_rows <- function() {
  lapply(cat3_dba_assets(), function(a) list(
    AssetCode  = a$code,
    AssetLabel = a$label,
    AssetType  = a$asset_type,
    FilePath   = a$file_path
  ))
}


# ==============================================================================
# MAIN GENERATOR
# ==============================================================================

#' Generate the filled Brand_Config.xlsx for the IPK 3-category example
#'
#' @param output_path Character. Destination path for Brand_Config.xlsx.
#' @param overwrite   Logical. Overwrite if file exists (default: TRUE).
#' @return Invisibly returns the output_path.
#' @export
generate_3cat_config <- function(output_path, overwrite = TRUE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  wb <- openxlsx::createWorkbook()

  write_settings_sheet(
    wb, "Settings",
    .build_3cat_settings_def(),
    title    = "TURAS Brand Module - Configuration",
    subtitle = "Ina Paarman's Kitchen - Multi-Category CBM (Dry Seasonings & Spices, Pasta Sauces, Salad Dressings)"
  )

  write_table_sheet(
    wb, "Categories",
    .build_categories_columns(),
    title    = "Category Definitions",
    subtitle = "Three transactional categories. Respondents are assigned one focal category (balanced allocation).",
    example_rows   = .build_3cat_categories_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "DBA_Assets",
    .build_dba_assets_columns(),
    title    = "DBA Asset Definitions (only if element_dba = Y)",
    subtitle = "Five distinctive brand assets for Ina Paarman's Kitchen. Assets are brand-level: all respondents across all categories see these.",
    example_rows   = .build_3cat_dba_assets_rows(),
    num_blank_rows = 0
  )

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)
  cat(sprintf("  + Brand_Config.xlsx -> %s\n", output_path))
  invisible(output_path)
}
