# ==============================================================================
# 9CAT SYNTHETIC EXAMPLE - Brand_Config.xlsx GENERATOR
# Depends on: 01_constants.R
# ==============================================================================

.build_9cat_settings_def <- function() {
  meta <- cat9_study_meta()
  list(
    list(section_name = "STUDY IDENTIFICATION", fields = list(
      list(name="project_name", required=TRUE,  default=meta$project_name,
           description="[REQUIRED] Project name for report titles and file naming", valid_values_text="Free text"),
      list(name="client_name",  required=TRUE,  default=meta$client_name,
           description="[REQUIRED] Client organisation name", valid_values_text="Free text"),
      list(name="study_type",   required=TRUE,  default=meta$study_type,
           description="[REQUIRED] Study design. Panel includes respondent ID for longitudinal tracking",
           valid_values_text="cross-sectional, panel", dropdown=c("cross-sectional","panel")),
      list(name="wave",         required=TRUE,  default=meta$wave,
           description="[REQUIRED] Wave number. Wave 1 = baseline; wave 2+ enables tracker integration",
           valid_values_text="Integer >= 1", integer_range=c(1,100)),
      list(name="data_file",    required=TRUE,  default=meta$data_file_name,
           description="[REQUIRED] Path to survey data file. Relative paths resolve from this config's directory",
           valid_values_text=".csv or .xlsx"),
      list(name="respondent_id_col", required=FALSE, default="Respondent_ID",
           description="[Optional] Column name for respondent ID",
           valid_values_text="Column name in data file"),
      list(name="weight_variable", required=FALSE, default="Weight",
           description="[Optional] Column name for survey weight variable. Leave blank for unweighted",
           valid_values_text="Column name in data file"),
      list(name="focal_brand",  required=TRUE,  default=meta$focal_brand,
           description="[REQUIRED] Focal brand code (must match Brands sheet in Survey_Structure)",
           valid_values_text="Brand code")
    )),
    list(section_name = "MULTI-CATEGORY ROUTING", fields = list(
      list(name="focal_assignment", required=TRUE, default="balanced",
           description="[REQUIRED] How respondents are assigned to their focal category. Only FULL categories are assigned as focal. 'balanced' = equal split across the 4 full categories",
           valid_values_text="balanced, quota, priority", dropdown=c("balanced","quota","priority")),
      list(name="focal_category_col", required=FALSE, default="Focal_Category",
           description="[Optional] Column in data containing the focal category for each respondent",
           valid_values_text="Column name in data file"),
      list(name="cross_category_awareness", required=FALSE, default="Y",
           description="[Optional] Collect brand awareness for all qualified categories, not just the focal. Set to Y: awareness-only categories contribute to cross-category brand tracking",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="cross_category_pen_light", required=FALSE, default="N",
           description="[Optional] Collect light penetration for non-focal categories",
           valid_values_text="Y or N", dropdown=c("Y","N"))
    )),
    list(section_name = "ANALYTICAL ELEMENTS (Y = include, N = exclude)", fields = list(
      list(name="element_funnel",          required=FALSE, default="Y",
           description="[Optional] Brand funnel: Awareness > Disposition > Bought > Primary brand. Full categories only",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_mental_avail",    required=FALSE, default="Y",
           description="[Optional] Mental Availability: MMS, MPen, NS, CEP x brand matrix. The analytical centrepiece. Full categories only",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_cep_turf",        required=FALSE, default="Y",
           description="[Optional] CEP TURF reach optimisation within Mental Availability",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_repertoire",      required=FALSE, default="Y",
           description="[Optional] Repertoire analysis: multi-brand buying, share of requirements. Full categories only",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_drivers_barriers",required=FALSE, default="Y",
           description="[Optional] Drivers & Barriers: derived importance x performance. Full categories only",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_dba",             required=FALSE, default="Y",
           description="[Optional] Distinctive Brand Assets: Fame x Uniqueness grid for IPK's 5 assets. All respondents across all categories",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_portfolio",       required=FALSE, default="Y",
           description="[Optional] Portfolio analysis: compare IPK's metrics across all 9 categories. Awareness-only categories show awareness column only",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_wom",             required=FALSE, default="Y",
           description="[Optional] Word-of-Mouth: received/shared x positive/negative. Full categories only",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_branded_reach",   required=FALSE, default="Y",
           description="[Optional] Branded Reach (Romaniuk): per-ad reach, branding %, branded reach, misattribution and media mix. Requires MarketingReach + ReachMedia sheets and reach.* roles in QuestionMap",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="element_audience_lens",   required=FALSE, default="Y",
           description="[Optional] Audience Lens: focal-brand performance across pre-defined audience cuts (demographic + buyer-pair). Requires the AudienceLens sheet in Survey_Structure.xlsx and AudienceLens_Use on Categories sheet",
           valid_values_text="Y or N", dropdown=c("Y","N"))
    )),
    list(section_name = "AUDIENCE LENS OPTIONS (only if element_audience_lens = Y)", fields = list(
      list(name="audience_lens_max",        required=FALSE, default=6L,
           description="[Optional] Ceiling on audiences per category (pairs count as one). Exceeding triggers a TRS refusal."),
      list(name="audience_lens_warn_base",  required=FALSE, default=75L,
           description="[Optional] Below this unweighted base size, audiences render with a 'low base' badge. Production projects with larger samples should use 100."),
      list(name="audience_lens_suppress_base", required=FALSE, default=30L,
           description="[Optional] Below this unweighted base size, audiences are suppressed entirely. Demo default 30 ensures the focal-brand buyer audience renders (IPK ~13% penetration in this synthetic fixture). Production projects with stronger focal brands should use 50."),
      list(name="audience_lens_alpha",      required=FALSE, default=0.10,
           description="[Optional] Significance level for pair / vs-total comparisons (default 90%).",
           numeric_range=c(0.001, 0.50)),
      list(name="audience_lens_gap_threshold", required=FALSE, default=0.10,
           description="[Optional] Minimum buyer-vs-non-buyer gap (proportion points) before GROW / DEFEND can fire.",
           numeric_range=c(0.0, 1.0))
    )),
    list(section_name = "DRIVERS & BARRIERS OPTIONS", fields = list(
      list(name="db_use_catdriver",      required=FALSE, default="Y",
           description="[Optional] Use catdriver module for derived importance via SHAP values",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="db_importance_method",  required=FALSE, default="differential",
           description="[Optional] Fallback when catdriver is off: buyer vs non-buyer gap",
           valid_values_text="differential", dropdown=c("differential"))
    )),
    list(section_name = "DBA OPTIONS (only if element_dba = Y)", fields = list(
      list(name="dba_scope",               required=FALSE, default="brand",
           description="[Optional] DBA measurement scope: 'brand' tests IPK's assets only",
           valid_values_text="brand, category", dropdown=c("brand","category")),
      list(name="dba_fame_threshold",      required=FALSE, default=0.50,
           description="[Optional] Fame threshold for quadrant classification",
           valid_values_text="0.00 to 1.00", numeric_range=c(0,1)),
      list(name="dba_uniqueness_threshold",required=FALSE, default=0.50,
           description="[Optional] Uniqueness threshold for quadrant classification",
           valid_values_text="0.00 to 1.00", numeric_range=c(0,1)),
      list(name="dba_attribution_type",    required=FALSE, default="open",
           description="[Optional] DBA attribution: 'open' = open-ended brand name recall",
           valid_values_text="open, closed_list", dropdown=c("open","closed_list"))
    )),
    list(section_name = "WOM OPTIONS (only if element_wom = Y)", fields = list(
      list(name="wom_timeframe", required=FALSE, default="3 months",
           description="[Optional] WOM recall timeframe. Should match target purchase timeframe",
           valid_values_text="Free text e.g. '3 months'")
    )),
    list(section_name = "SIGNIFICANCE TESTING", fields = list(
      list(name="alpha",           required=FALSE, default=0.05,
           description="[Optional] Primary significance level for cross-brand comparisons",
           valid_values_text="0.01 to 0.20", numeric_range=c(0.01,0.20)),
      list(name="alpha_secondary", required=FALSE, default="",
           description="[Optional] Secondary significance level for dual-alpha display. Leave blank to disable",
           valid_values_text="0.01 to 0.20 or blank"),
      list(name="min_base_size",   required=FALSE, default=30,
           description="[Optional] Cells below this base size are suppressed",
           valid_values_text="Integer >= 10", integer_range=c(10,500)),
      list(name="low_base_warning",required=FALSE, default=75,
           description="[Optional] Base size below which a low-base caution flag is shown (Romaniuk: n<75 is unreliable)",
           valid_values_text="Integer >= 30", integer_range=c(30,500))
    )),
    list(section_name = "COLOUR PALETTE (data elements only - chrome stays Turas navy)", fields = list(
      list(name="colour_focal",       required=FALSE, default="#C8102E",
           description="[Optional] Saturated colour for focal brand (IPK brand red)",
           valid_values_text="Hex colour e.g. #C8102E"),
      list(name="colour_focal_accent",required=FALSE, default="#8B0000",
           description="[Optional] Accent colour for focal brand secondary elements",
           valid_values_text="Hex colour"),
      list(name="colour_competitor",  required=FALSE, default="#B0B0B0",
           description="[Optional] Desaturated colour for competitor brands",
           valid_values_text="Hex colour"),
      list(name="colour_category_avg",required=FALSE, default="#808080",
           description="[Optional] Colour for category average reference lines",
           valid_values_text="Hex colour")
    )),
    list(section_name = "OUTPUT OPTIONS", fields = list(
      list(name="output_dir",   required=TRUE,  default="output",
           description="[REQUIRED] Output directory. Relative paths resolve from this config's directory",
           valid_values_text="Relative path"),
      list(name="output_html",  required=FALSE, default="Y",
           description="[Optional] Generate HTML report via report_hub",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="output_excel", required=FALSE, default="Y",
           description="[Optional] Generate Excel workbook with all element data",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="output_csv",   required=FALSE, default="Y",
           description="[Optional] Generate CSV files per element",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="tracker_ids",  required=FALSE, default="Y",
           description="[Optional] Include stable metric IDs for wave-over-wave tracking",
           valid_values_text="Y or N", dropdown=c("Y","N"))
    )),
    list(section_name = "REPORT OPTIONS", fields = list(
      list(name="report_title",       required=FALSE,
           default=sprintf("%s Brand Health", cat9_study_meta()$client_name),
           description="[Optional] Title displayed in HTML report header",
           valid_values_text="Free text"),
      list(name="report_subtitle",    required=FALSE,
           default="Wave 1 Baseline - 9 Category CBM (4 Full + 5 Awareness-Only)",
           description="[Optional] Subtitle for the HTML report header",
           valid_values_text="Free text"),
      list(name="show_about_section", required=FALSE, default="Y",
           description="[Optional] Include About & Methodology section with EBI references",
           valid_values_text="Y or N", dropdown=c("Y","N")),
      list(name="structure_file",     required=TRUE,  default="Survey_Structure.xlsx",
           description="[REQUIRED] Path to Survey_Structure.xlsx (relative to this config file)",
           valid_values_text="Relative path to .xlsx file")
    ))
  )
}

# Categories sheet — 9 rows: 4 full + 5 awareness-only
# Includes Analysis_Depth column (custom extension)
.build_9cat_categories_columns_extended <- function() {
  list(
    list(name="Category",        width=28, required=TRUE,
         description="Category name as it appears in the data and report"),
    list(name="Type",            width=18, required=TRUE,
         description="Category type. Controls question wording and penetration structure",
         dropdown=c("transaction","durable","service")),
    list(name="Analysis_Depth",  width=20, required=TRUE,
         description="[REQUIRED] 'full' = complete CBM battery (CEPs, attributes, funnel, WOM); 'awareness_only' = brand awareness only. Matches the questionnaire routing instruction.",
         dropdown=c("full","awareness_only")),
    list(name="Timeframe_Long",  width=18, required=TRUE,
         description="Longer timeframe for penetration (e.g. '12 months'). Full categories only"),
    list(name="Timeframe_Target",width=18, required=TRUE,
         description="Target analytical period (e.g. '3 months'). Full categories only"),
    list(name="Focal_Weight",    width=14, required=FALSE,
         description="Assignment weight for 'priority' routing. Must sum to 1.0 across FULL categories only. Leave blank for awareness-only categories",
         numeric_range=c(0,1)),
    list(name="AudienceLens_Use", width=42, required=FALSE,
         description="[Optional] Audience Lens opt-in. Comma-separated AudienceID values from Survey_Structure!AudienceLens, or ALL_AVAILABLE for every audience scoped to this category. Blank = no Audience Lens tab for this category.")
  )
}

.build_9cat_categories_rows <- function() {
  lapply(cat9_categories(), function(c) list(
    Category         = c$name,
    Type             = c$type,
    Analysis_Depth   = c$analysis_depth,
    Timeframe_Long   = c$timeframe_long,
    Timeframe_Target = c$timeframe_target,
    Focal_Weight     = if (c$analysis_depth == "full") 0.25 else "",
    # Full categories opt in to the demographic audiences + a per-category
    # focal-brand buyer pair (AudienceID built per-category in 03_structure.R
    # so each cat compares its own focal-brand buyers vs non-buyers).
    AudienceLens_Use = if (c$analysis_depth == "full")
      sprintf("gauteng,under_35,buyer_pair_%s", c$code) else ""
  ))
}

.build_9cat_dba_assets_rows <- function() {
  lapply(cat9_dba_assets(), function(a) list(
    AssetCode  = a$code,
    AssetLabel = a$label,
    AssetType  = a$asset_type,
    FilePath   = a$file_path
  ))
}

#' Generate Brand_Config.xlsx for the IPK 9-category example
#' @export
generate_9cat_config <- function(output_path, overwrite = TRUE) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) stop("openxlsx required")
  if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)

  wb <- openxlsx::createWorkbook()

  write_settings_sheet(wb, "Settings", .build_9cat_settings_def(),
    title    = "TURAS Brand Module - Configuration",
    subtitle = "Ina Paarman's Kitchen - 9-Category CBM (4 Full + 5 Awareness-Only)")

  write_table_sheet(wb, "Categories", .build_9cat_categories_columns_extended(),
    title    = "Category Definitions",
    subtitle = paste0("9 categories total. 4 FULL (DSS, POS, PAS, BAK) receive the complete CBM battery. ",
                      "5 AWARENESS-ONLY (SLD, STO, PES, COO, ANT) receive brand awareness questions only, ",
                      "enabling cross-category brand tracking without the full cost of a complete CBM battery."),
    example_rows   = .build_9cat_categories_rows(),
    num_blank_rows = 0)

  write_table_sheet(wb, "DBA_Assets", .build_dba_assets_columns(),
    title    = "DBA Asset Definitions (only if element_dba = Y)",
    subtitle = "5 distinctive brand assets for Ina Paarman's Kitchen. DBA is brand-level: all respondents across all 9 categories see these assets.",
    example_rows   = .build_9cat_dba_assets_rows(),
    num_blank_rows = 0)

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)
  cat(sprintf("  + Brand_Config.xlsx -> %s\n", output_path))
  invisible(output_path)
}
