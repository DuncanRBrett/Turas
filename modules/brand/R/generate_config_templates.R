# ==============================================================================
# BRAND MODULE - CONFIG TEMPLATE GENERATORS
# ==============================================================================
# Generates professional Excel config templates for the brand module:
#   1. Brand_Config_Template.xlsx
#        Analysis settings: element toggles, routing, stats, colours, output.
#   2. Survey_Structure_Brand_Config_Template.xlsx
#        Unified data dictionary for BOTH the brand module AND the tabs module
#        from a single file. Contains all brand-specific sheets (Brands, CEPs,
#        Attributes, QuestionMap, OptionMap, Channels, PackSizes,
#        MarketingReach, ReachMedia, AudienceLens, DBA_Assets) PLUS the
#        Questions, Options, and Composite_Metrics sheets required by tabs,
#        so one Survey_Structure serves a complete project.
#
# USAGE:
#   source("modules/brand/R/generate_config_templates.R")
#   generate_brand_config_template(
#     "path/to/Brand_Config_Template.xlsx", overwrite = TRUE)
#   generate_brand_survey_structure_template(
#     "path/to/Survey_Structure_Brand_Config_Template.xlsx", overwrite = TRUE)
#   # Or both at once:
#   generate_brand_templates("path/to/output/")
#
# DEPENDENCIES:
#   - openxlsx
#   - modules/shared/template_styles.R
# ==============================================================================

BRAND_CONFIG_VERSION <- "2.0"

# --- Source shared template infrastructure ---
.find_shared_template_styles <- function() {
  candidates <- character(0)

  if (exists("find_turas_root", mode = "function")) {
    candidates <- c(candidates,
      file.path(find_turas_root(), "modules", "shared", "template_styles.R"))
  }

  this_ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(this_ofile)) {
    this_dir <- dirname(this_ofile)
    candidates <- c(candidates,
      file.path(this_dir, "..", "..", "shared", "template_styles.R"))
  }

  candidates <- c(candidates, "modules/shared/template_styles.R")

  for (path in candidates) {
    path <- normalizePath(path, mustWork = FALSE)
    if (file.exists(path)) return(path)
  }

  stop("Cannot find modules/shared/template_styles.R. Set TURAS_ROOT or source it manually.")
}

.ensure_template_styles <- function() {
  if (!exists("write_settings_sheet", mode = "function")) {
    source(.find_shared_template_styles())
  }
}


# ==============================================================================
# BRAND_CONFIG.XLSX — SETTINGS
# ==============================================================================

.build_brand_settings_def <- function() {
  list(

    # --- STUDY IDENTIFICATION ---
    list(
      section_name = "STUDY IDENTIFICATION",
      fields = list(
        list(name = "project_name", required = TRUE, default = "",
             description = "Project name used in report titles and output filenames.",
             valid_values_text = "Free text"),
        list(name = "client_name", required = TRUE, default = "",
             description = "Client organisation name shown in reports and documentation.",
             valid_values_text = "Free text"),
        list(name = "report_title", required = FALSE, default = "Brand Health Report",
             description = "Title displayed in the HTML report header.",
             valid_values_text = "Free text"),
        list(name = "report_subtitle", required = FALSE, default = "",
             description = "Subtitle line below title. Typical use: wave label or fieldwork dates (e.g. 'Wave 1 Baseline — Q1 2026').",
             valid_values_text = "Free text"),
        list(name = "study_type", required = TRUE, default = "cross-sectional",
             description = "Study design. Panel studies carry respondent IDs for longitudinal tracking.",
             valid_values_text = "cross-sectional, panel",
             dropdown = c("cross-sectional", "panel")),
        list(name = "wave", required = TRUE, default = 1,
             description = "Wave number. Wave 1 = baseline. Wave 2+ enables tracker integration for trend lines.",
             valid_values_text = "Integer >= 1",
             integer_range = c(1, 100)),
        list(name = "respondent_id_col", required = FALSE, default = "Respondent_ID",
             description = "Data column containing respondent ID. Required only if study_type = panel.",
             valid_values_text = "Column name in data file"),
        list(name = "focal_brand", required = TRUE, default = "",
             description = "Client brand code (must match a BrandCode in Survey_Structure Brands sheet). Controls highlighting, annotations, and focal-brand comparisons throughout all outputs.",
             valid_values_text = "BrandCode from Brands sheet in Survey_Structure.xlsx")
      )
    ),

    # --- DATA FILES ---
    list(
      section_name = "DATA FILES",
      fields = list(
        list(name = "data_file", required = TRUE, default = "",
             description = "Path to survey data file, relative to the location of this config file.",
             valid_values_text = ".csv or .xlsx"),
        list(name = "structure_file", required = TRUE, default = "Survey_Structure.xlsx",
             description = "Path to Survey_Structure.xlsx, relative to this config file. One structure file serves both the brand module and the tabs module.",
             valid_values_text = "Relative path to .xlsx file"),
        list(name = "weight_variable", required = FALSE, default = "",
             description = "Column name for the survey weight variable. Leave blank for unweighted analysis.",
             valid_values_text = "Column name in data file, or leave blank")
      )
    ),

    # --- MULTI-CATEGORY ROUTING ---
    list(
      section_name = "MULTI-CATEGORY ROUTING",
      fields = list(
        list(name = "focal_assignment", required = TRUE, default = "balanced",
             description = "How respondents are assigned to their focal (deep-dive) category. 'balanced' = random equal split across active categories; 'quota' = enforce minimum n per category; 'priority' = weighted over-sampling via Focal_Weight column in Categories sheet.",
             valid_values_text = "balanced, quota, priority",
             dropdown = c("balanced", "quota", "priority")),
        list(name = "focal_category_col", required = FALSE, default = "Focal_Category",
             description = "Data column containing pre-assigned focal category code (e.g. DSS). Leave blank to derive from config. Alchemer exports this via the routing hidden variable.",
             valid_values_text = "Column name in data file, or blank"),
        list(name = "cross_category_awareness", required = FALSE, default = "Y",
             description = "Collect brand awareness for ALL categories every respondent is screened into (not just their focal category). Required for the Portfolio element (BRANDAWARE_* columns).",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "cross_category_pen_light", required = FALSE, default = "Y",
             description = "Collect light penetration (12-month buyers) for non-focal categories. Used by the Portfolio element for cross-category coverage mapping.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N"))
      )
    ),

    # --- ANALYTICAL ELEMENTS ---
    list(
      section_name = "ANALYTICAL ELEMENTS  (Y = include, N = exclude)",
      fields = list(
        list(name = "element_funnel", required = FALSE, default = "Y",
             description = "Brand funnel: Awareness > Disposition > Bought (target) > Primary. Derived from BRANDAWARE, BRANDATT1, BRANDPEN2, BRANDPEN3 columns — no extra survey questions needed.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_mental_avail", required = FALSE, default = "Y",
             description = "Mental Availability (Romaniuk): MMS, MPen, Network Size, CEP x Brand matrix. Requires a CEP battery (BRANDATTR_{CAT}_{CEP} columns). The analytical centrepiece of CBM.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_cep_turf", required = FALSE, default = "Y",
             description = "CEP TURF reach optimisation within Mental Availability. Identifies the optimal subset of CEPs that maximises mental reach. Runs only when element_mental_avail = Y.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_repertoire", required = FALSE, default = "Y",
             description = "Repertoire analysis: multi-brand buying, share of requirements, switching patterns, Dirichlet norms, buyer heaviness. Requires BRANDPEN2 and BRANDPEN3 columns.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_drivers_barriers", required = FALSE, default = "Y",
             description = "Drivers & Barriers: derived importance x performance, rejection themes, optional catdriver SHAP integration. Requires CEP/attribute battery and BRANDATT1 columns.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_wom", required = FALSE, default = "Y",
             description = "Word-of-Mouth: received/shared x positive/negative balance. Requires WOM battery (WOM_POS_REC, WOM_POS_SHARE, WOM_NEG_REC, WOM_NEG_SHARE columns). Adds ~2 min to survey.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_demographics", required = FALSE, default = "Y",
             description = "Demographics panel: per-question crosstabs by buyer status and buyer heaviness. Reads DEMO_* questions from the role map. Appears as a sub-tab in each category panel.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_adhoc", required = FALSE, default = "Y",
             description = "Ad Hoc panel: any questions tagged with role prefix 'adhoc.' in the QuestionMap. Supports ALL-scope (every respondent) and CATCODE-scope (focal category only). Appears as a sub-tab.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_portfolio", required = FALSE, default = "Y",
             description = "Portfolio analysis: cross-category awareness map, category prioritisation quadrants, category TURF reach optimisation, portfolio extension scores. Requires 2+ categories and cross_category_awareness = Y.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_branded_reach", required = FALSE, default = "N",
             description = "Branded Reach: per-asset recognition and attribution (Fame x Uniqueness-style media tracking). Requires a MarketingReach sheet in Survey_Structure. Adds ~2 min per wave to survey.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_dba", required = FALSE, default = "N",
             description = "Distinctive Brand Assets (Byron Sharp): Fame x Uniqueness grid per asset. Requires DBA battery (DBA_FAME_* and DBA_UNIQUE_* columns) and a DBA_Assets sheet. Adds ~2 min to survey.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "element_audience_lens", required = FALSE, default = "N",
             description = "Audience Lens: compare pre-defined audience segments side-by-side across all metrics. Requires an AudienceLens sheet in Survey_Structure and AudienceLens_Use set on each category.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N"))
      )
    ),

    # --- TIMEFRAMES ---
    list(
      section_name = "TIMEFRAMES",
      fields = list(
        list(name = "target_timeframe_months", required = TRUE, default = 3,
             description = "Short-run purchase window in months. Maps to BRANDPEN2 (bought in last N months). Used to calculate annualised Dirichlet KPIs. Must be less than longer_timeframe_months.",
             valid_values_text = "Positive integer (typical: 3)",
             integer_range = c(1, 24)),
        list(name = "longer_timeframe_months", required = TRUE, default = 12,
             description = "Long-run purchase window in months. Maps to BRANDPEN1 (bought in last N months). Used for funnel labelling. Must be greater than target_timeframe_months.",
             valid_values_text = "Positive integer (typical: 12)",
             integer_range = c(2, 36)),
        list(name = "wom_timeframe", required = FALSE, default = "3 months",
             description = "WOM recall period shown in report labels. Should align with target_timeframe_months.",
             valid_values_text = "Free text (e.g. '3 months', '6 months')")
      )
    ),

    # --- FUNNEL OPTIONS ---
    list(
      section_name = "FUNNEL OPTIONS  (only if element_funnel = Y)",
      fields = list(
        list(name = "funnel_conversion_metric", required = FALSE, default = "ratio",
             description = "How conversion rates are expressed in the funnel. 'ratio' = each stage as % of previous stage (conditional conversion); absolute = each stage as % of total sample.",
             valid_values_text = "ratio, absolute",
             dropdown = c("ratio", "absolute")),
        list(name = "funnel_warn_base", required = FALSE, default = 75,
             description = "Base size (n) below which a low-base caution flag is shown on funnel bars. Per Romaniuk: n<75 makes per-brand estimates unreliable.",
             valid_values_text = "Integer >= 30",
             integer_range = c(30, 500)),
        list(name = "funnel_suppress_base", required = FALSE, default = 0,
             description = "Base size below which funnel cells are suppressed entirely (shown as '–'). Set to 0 to never suppress.",
             valid_values_text = "Integer >= 0",
             integer_range = c(0, 200)),
        list(name = "funnel_tenure_threshold", required = FALSE, default = "",
             description = "Attitude scale code that marks the boundary between 'non-user' and 'rejector' in the funnel. Typically the code for 'I would refuse to buy this brand'. Leave blank to derive from OptionMap.",
             valid_values_text = "Attitude option code (e.g. 4), or blank")
      )
    ),

    # --- DRIVERS & BARRIERS ---
    list(
      section_name = "DRIVERS & BARRIERS OPTIONS  (only if element_drivers_barriers = Y)",
      fields = list(
        list(name = "db_use_catdriver", required = FALSE, default = "Y",
             description = "Use the catdriver module for SHAP-derived importance scores. More statistically rigorous than the simple buyer/non-buyer differential method. Requires catdriver to be installed.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "db_importance_method", required = FALSE, default = "differential",
             description = "Importance derivation method when catdriver is disabled (db_use_catdriver = N). 'differential' = buyer minus non-buyer gap on each CEP/attribute.",
             valid_values_text = "differential",
             dropdown = c("differential"))
      )
    ),

    # --- DBA OPTIONS ---
    list(
      section_name = "DBA OPTIONS  (only if element_dba = Y)",
      fields = list(
        list(name = "dba_scope", required = FALSE, default = "brand",
             description = "DBA measurement scope. 'brand' = brand-level Fame x Uniqueness (standard); 'category' = per-category DBA grid (rare, for multi-category asset studies).",
             valid_values_text = "brand, category",
             dropdown = c("brand", "category")),
        list(name = "dba_fame_threshold", required = FALSE, default = 0.50,
             description = "Fame threshold (%) for the DBA quadrant boundary. Assets above this line are 'Famous'. Default = 50%.",
             valid_values_text = "0.00 to 1.00 (proportion)",
             numeric_range = c(0, 1)),
        list(name = "dba_uniqueness_threshold", required = FALSE, default = 0.50,
             description = "Uniqueness threshold (%) for the DBA quadrant boundary. Assets to the right are 'Unique'. Default = 50%.",
             valid_values_text = "0.00 to 1.00 (proportion)",
             numeric_range = c(0, 1)),
        list(name = "dba_attribution_type", required = FALSE, default = "open",
             description = "'open' = respondents attribute assets via open text (recommended: avoids brand priming, coded post-fieldwork). 'closed_list' = forced-choice brand list (inflates uniqueness scores artificially).",
             valid_values_text = "open, closed_list",
             dropdown = c("open", "closed_list"))
      )
    ),

    # --- PORTFOLIO OPTIONS ---
    list(
      section_name = "PORTFOLIO OPTIONS  (only if element_portfolio = Y)",
      fields = list(
        list(name = "focal_home_category", required = FALSE, default = "",
             description = "Short category code (e.g. DSS) for the focal brand's primary category. Used to anchor the Portfolio Overview tab and priority quadrant calculations. Leave blank if the focal brand competes equally across all categories.",
             valid_values_text = "CategoryCode from Categories sheet, or blank"),
        list(name = "portfolio_timeframe", required = FALSE, default = "3m",
             description = "Timeframe for portfolio category screener. '3m' uses SQ2_* columns (3-month buyers); '13m' uses SQ1_* columns (13-month buyers). Must match screener columns present in the data.",
             valid_values_text = "3m, 13m",
             dropdown = c("3m", "13m")),
        list(name = "portfolio_min_base", required = FALSE, default = 30,
             description = "Minimum base size (n category buyers) for a portfolio awareness rate to be reported. Cells below this are suppressed.",
             valid_values_text = "Integer >= 10",
             integer_range = c(10, 200)),
        list(name = "portfolio_cooccur_min_pairs", required = FALSE, default = 20,
             description = "Minimum number of respondents who buy in BOTH categories for a co-occurrence link to be drawn on the portfolio constellation chart.",
             valid_values_text = "Integer >= 5",
             integer_range = c(5, 200)),
        list(name = "portfolio_extension_baseline", required = FALSE, default = "all",
             description = "Denominator for portfolio extension scores. 'all' = all qualified respondents; 'buyers' = category buyers only.",
             valid_values_text = "all, buyers",
             dropdown = c("all", "buyers"))
      )
    ),

    # --- AUDIENCE LENS OPTIONS ---
    list(
      section_name = "AUDIENCE LENS OPTIONS  (only if element_audience_lens = Y)",
      fields = list(
        list(name = "audience_lens_max", required = FALSE, default = 6,
             description = "Maximum number of audience segments to show side-by-side in the Audience Lens panel. Minimum 2 (for a pair). Each audience requires its own column of analysis — keep <=6 for readability.",
             valid_values_text = "2 to 8",
             integer_range = c(2, 8))
      )
    ),

    # --- SIGNIFICANCE TESTING ---
    list(
      section_name = "SIGNIFICANCE TESTING",
      fields = list(
        list(name = "alpha", required = FALSE, default = 0.05,
             description = "Primary significance level for cross-brand comparisons. 0.05 = 95% confidence (standard). Shown as star annotations or letter codes in outputs.",
             valid_values_text = "0.01 to 0.20",
             numeric_range = c(0.01, 0.20)),
        list(name = "alpha_secondary", required = FALSE, default = "",
             description = "Optional second significance level. When set, the HTML report shows a toggle to switch between primary and secondary levels (e.g. set 0.10 for an additional 90% confidence view). Leave blank to disable.",
             valid_values_text = "0.01 to 0.20, or blank"),
        list(name = "min_base_size", required = FALSE, default = 30,
             description = "Minimum base size (n) for reporting. Metric cells with fewer respondents are suppressed and shown as '–'.",
             valid_values_text = "Integer >= 10",
             integer_range = c(10, 200)),
        list(name = "low_base_warning", required = FALSE, default = 75,
             description = "Base size threshold below which a low-base warning flag is shown. Per Romaniuk: n<75 makes per-brand estimates unreliable for CBM metrics.",
             valid_values_text = "Integer >= 30",
             integer_range = c(30, 500))
      )
    ),

    # --- COLOUR PALETTE ---
    list(
      section_name = "COLOUR PALETTE",
      fields = list(
        list(name = "colour_focal", required = FALSE, default = "#1A5276",
             description = "Primary colour for the focal brand in all charts. Use the client's brand primary colour. Should be saturated and distinctive.",
             valid_values_text = "Hex code (e.g. #1A5276)"),
        list(name = "colour_focal_accent", required = FALSE, default = "#2E86C1",
             description = "Lighter accent colour for focal brand secondary elements (e.g. confidence bands, secondary markers).",
             valid_values_text = "Hex code"),
        list(name = "colour_competitor", required = FALSE, default = "#B0B0B0",
             description = "Desaturated colour for all competitor brands. Grey by default: competitors recede visually so the focal brand stands out (design principle 3).",
             valid_values_text = "Hex code"),
        list(name = "colour_category_avg", required = FALSE, default = "#808080",
             description = "Colour for category average reference lines and bars. Mid-grey, typically drawn dashed to distinguish from brand bars.",
             valid_values_text = "Hex code")
      )
    ),

    # --- OUTPUT ---
    list(
      section_name = "OUTPUT OPTIONS",
      fields = list(
        list(name = "output_dir", required = TRUE, default = "output/brand",
             description = "Output directory for all generated files, relative to the project root. Created automatically if it does not exist.",
             valid_values_text = "Relative path"),
        list(name = "output_html", required = FALSE, default = "Y",
             description = "Generate the interactive HTML brand report.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "output_excel", required = FALSE, default = "Y",
             description = "Generate an Excel workbook with all element data tables.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "output_csv", required = FALSE, default = "Y",
             description = "Generate long-format CSV files per element (useful for BI tools).",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "decimal_places", required = FALSE, default = 0,
             description = "Number of decimal places for percentage metrics in the report (e.g. 0 = 45%, 1 = 45.3%). Means and indices always show 1 decimal regardless.",
             valid_values_text = "0 to 2",
             integer_range = c(0, 2)),
        list(name = "tracker_ids", required = FALSE, default = "Y",
             description = "Include stable metric IDs in output for wave-over-wave tracking. Required for tracker module integration. Has no visible effect in Wave 1.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "show_about_section", required = FALSE, default = "Y",
             description = "Include an About & Methodology section in the HTML report with academic references (Romaniuk, Sharp, EBI framework). Useful for client education.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N"))
      )
    )
  )
}


# ==============================================================================
# BRAND_CONFIG.XLSX — TABLE SHEETS
# ==============================================================================

.build_categories_columns <- function() {
  list(
    list(name = "Category", width = 30, required = TRUE,
         description = "Full category display name as shown in the report (e.g. 'Dry Seasonings & Spices'). Matches the Category column in Survey_Structure Brands/CEPs sheets."),
    list(name = "CategoryCode", width = 14, required = TRUE,
         description = "Short uppercase code used in data column names (e.g. DSS). Must match the suffix in BRANDAWARE_DSS, BRANDPEN2_DSS, etc. 2-4 characters, letters only."),
    list(name = "Active", width = 10, required = TRUE,
         description = "Y = include this category in analysis. N = skip (useful for disabling a category without deleting the row).",
         dropdown = c("Y", "N")),
    list(name = "Type", width = 16, required = TRUE,
         description = "Category type. 'transaction' = fast-moving goods bought frequently; 'durable' = infrequently replaced items; 'service' = ongoing subscriptions or services. Controls question wording and penetration structure.",
         dropdown = c("transaction", "durable", "service")),
    list(name = "Analysis_Depth", width = 18, required = FALSE,
         description = "'full' = complete CBM battery (Mental Availability, Funnel, Repertoire, etc.). 'awareness_only' = only cross-category awareness collected — no deep-dive panels. Use awareness_only for peripheral categories included only for Portfolio breadth.",
         dropdown = c("full", "awareness_only")),
    list(name = "Timeframe_Long", width = 18, required = TRUE,
         description = "Long purchase window label (e.g. '12 months'). Matches longer_timeframe_months in Settings. Used in funnel labels."),
    list(name = "Timeframe_Target", width = 18, required = TRUE,
         description = "Target purchase window label (e.g. '3 months'). Matches target_timeframe_months in Settings. Used in Dirichlet KPIs and funnel."),
    list(name = "Focal_Weight", width = 14, required = FALSE,
         description = "Routing weight for focal_assignment = 'priority'. Proportion of sample directed to this category. All active categories must sum to 1.0. Leave blank for balanced or quota routing.",
         numeric_range = c(0, 1)),
    list(name = "AudienceLens_Use", width = 20, required = FALSE,
         description = "Audience Lens opt-in for this category. 'ALL' = include all audiences defined in AudienceLens sheet; 'ALL_AVAILABLE' = same but silently skip unavailable columns; comma-separated AudienceIDs = include only those audiences. Leave blank to disable.")
  )
}

.build_categories_examples <- function() {
  list(
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         Active = "Y", Type = "transaction", Analysis_Depth = "full",
         Timeframe_Long = "12 months", Timeframe_Target = "3 months",
         Focal_Weight = 0.25, AudienceLens_Use = ""),
    list(Category = "Ready Meals", CategoryCode = "RM",
         Active = "Y", Type = "transaction", Analysis_Depth = "full",
         Timeframe_Long = "12 months", Timeframe_Target = "3 months",
         Focal_Weight = 0.25, AudienceLens_Use = ""),
    list(Category = "Pasta & Noodles", CategoryCode = "PAS",
         Active = "Y", Type = "transaction", Analysis_Depth = "full",
         Timeframe_Long = "12 months", Timeframe_Target = "3 months",
         Focal_Weight = 0.25, AudienceLens_Use = ""),
    list(Category = "Canned Tomatoes", CategoryCode = "CT",
         Active = "Y", Type = "transaction", Analysis_Depth = "awareness_only",
         Timeframe_Long = "12 months", Timeframe_Target = "3 months",
         Focal_Weight = 0.25, AudienceLens_Use = "")
  )
}

.build_dba_assets_columns <- function() {
  list(
    list(name = "AssetCode", width = 16, required = TRUE,
         description = "Unique asset code (e.g. LOGO, COLOUR, TAGLINE). Referenced by the DBA_Assets sheet in Survey_Structure."),
    list(name = "AssetLabel", width = 26, required = TRUE,
         description = "Display label for charts and tables (e.g. 'Primary Logo', 'Red Colour')."),
    list(name = "AssetType", width = 14, required = TRUE,
         description = "Type of stimulus shown to respondents.",
         dropdown = c("image", "text", "audio")),
    list(name = "FilePath", width = 45, required = FALSE,
         description = "Path to asset file (PNG/JPG for image, MP3/WAV for audio), relative to project root. Not required for 'text' type.")
  )
}

.build_dba_assets_examples <- function() {
  list(
    list(AssetCode = "LOGO", AssetLabel = "Primary Logo",
         AssetType = "image", FilePath = "assets/logo_unbranded.png"),
    list(AssetCode = "COLOUR", AssetLabel = "Brand Red",
         AssetType = "image", FilePath = "assets/colour_swatch_red.png"),
    list(AssetCode = "TAGLINE", AssetLabel = "Tagline",
         AssetType = "text", FilePath = ""),
    list(AssetCode = "CHARACTER", AssetLabel = "Brand Character",
         AssetType = "image", FilePath = "assets/character_unbranded.png")
  )
}


# ==============================================================================
# SURVEY_STRUCTURE — SHARED SHEETS (questions, options, composite metrics)
# ==============================================================================

.build_project_settings_def <- function() {
  list(
    list(
      section_name = "PROJECT",
      fields = list(
        list(name = "project_name", required = TRUE, default = "",
             description = "Project name. Must match project_name in Brand_Config.xlsx.",
             valid_values_text = "Free text"),
        list(name = "project_code", required = FALSE, default = "",
             description = "Short project identifier used in filenames and logging.",
             valid_values_text = "e.g. IPK_W1"),
        list(name = "client_name", required = TRUE, default = "",
             description = "Client organisation name. Must match client_name in Brand_Config.xlsx.",
             valid_values_text = "Free text"),
        list(name = "study_type", required = TRUE, default = "Tracker",
             description = "Study type for documentation.",
             valid_values_text = "Ad-hoc, Tracker, Panel, or Longitudinal",
             dropdown = c("Ad-hoc", "Tracker", "Panel", "Longitudinal")),
        list(name = "study_date", required = FALSE, default = "",
             description = "Fieldwork start date in YYYYMMDD format.",
             valid_values_text = "YYYYMMDD (e.g. 20260101)"),
        list(name = "contact_person", required = FALSE, default = "",
             description = "Project lead name for documentation.",
             valid_values_text = "Free text"),
        list(name = "notes", required = FALSE, default = "",
             description = "General project notes.",
             valid_values_text = "Free text")
      )
    ),
    list(
      section_name = "DATA FILE",
      fields = list(
        list(name = "data_file", required = TRUE, default = "",
             description = "Path to survey data file, relative to this Survey_Structure file.",
             valid_values_text = "e.g. data/Survey_Data.xlsx"),
        list(name = "output_folder", required = FALSE, default = "output",
             description = "Output folder for generated files.",
             valid_values_text = "Folder name"),
        list(name = "total_sample", required = FALSE, default = "",
             description = "Expected total number of respondents for documentation.",
             valid_values_text = "Positive integer")
      )
    ),
    list(
      section_name = "WEIGHTING",
      fields = list(
        list(name = "weight_column_exists", required = FALSE, default = "N",
             description = "Does the data file contain a weight column?",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "weight_columns", required = FALSE, default = "",
             description = "Comma-separated list of weight column names.",
             valid_values_text = "e.g. weight_nat"),
        list(name = "default_weight", required = FALSE, default = "",
             description = "Which weight column to use by default.",
             valid_values_text = "One of the weight_columns values"),
        list(name = "weight_description", required = FALSE, default = "",
             description = "Brief description of weighting methodology.",
             valid_values_text = "Free text")
      )
    )
  )
}

.build_unified_questions_columns <- function() {
  list(
    list(name = "QuestionCode", width = 28, required = TRUE,
         description = "Unique code matching the column name prefix in the data file (case-sensitive). For slot-indexed questions (Multi_Mention brand batteries) use the ROOT code — the role inferrer adds the _1, _2 ... slot suffix automatically. Examples: BRANDAWARE_DSS, DEMO_AGE, Q_Gender."),
    list(name = "QuestionText", width = 50, required = TRUE,
         description = "Full question wording as shown in output reports. For brand batteries use a short descriptive label (e.g. 'Brand awareness — Dry Seasonings & Spices')."),
    list(name = "Variable_Type", width = 20, required = TRUE,
         description = "Question type. Brand module uses Single_Response/Multi_Mention. Tabs module uses the full type set. See Variable Type Reference sheet for full descriptions.",
         dropdown = c("Single_Mention", "Single_Response", "Multi_Mention", "Likert",
                      "Rating", "NPS", "Ranking", "Numeric", "Open_End")),
    list(name = "Columns", width = 10, required = TRUE,
         description = "Number of data columns: 1 for most types; for Multi_Mention slot-indexed questions enter the number of slots (brands + 1 for NONE). For tabs Ranking enter the number of items ranked.",
         integer_range = c(1, 500)),
    list(name = "Category", width = 24, required = FALSE,
         description = "TABS: section/grouping label for output organisation (e.g. 'Demographics', 'Satisfaction'). BRAND: informational only — the brand module infers battery and category from the question code naming convention."),
    list(name = "Ranking_Format", width = 16, required = FALSE,
         description = "TABS ONLY — required for Ranking questions. 'Position' = each item column holds rank position number. 'Item' = each rank column holds item code.",
         dropdown = c("Position", "Item")),
    list(name = "Ranking_Positions", width = 18, required = FALSE,
         description = "TABS ONLY — for Ranking: how many items each respondent ranks (e.g. 3 for 'rank your top 3').",
         integer_range = c(1, 100)),
    list(name = "Ranking_Direction", width = 18, required = FALSE,
         description = "TABS ONLY — for Ranking: does Rank 1 mean best or worst?",
         dropdown = c("BestToWorst", "WorstToBest")),
    list(name = "Min_Value", width = 12, required = FALSE,
         description = "TABS ONLY — for Numeric questions: minimum expected value (used for validation and binning)."),
    list(name = "Max_Value", width = 12, required = FALSE,
         description = "TABS ONLY — for Numeric questions: maximum expected value."),
    list(name = "Notes", width = 30, required = FALSE,
         description = "Internal notes (not shown in output).")
  )
}

.build_unified_questions_examples <- function() {
  list(
    # --- Brand-module questions (convention-based naming) ---
    list(QuestionCode = "Focal_Category",
         QuestionText = "Assigned focal category (admin column)",
         Variable_Type = "Single_Response", Columns = 1,
         Category = "Admin",
         Notes = "Used by brand module to filter respondents to their deep-dive category"),
    list(QuestionCode = "SQ1",
         QuestionText = "Categories bought in the last 12 months (screener)",
         Variable_Type = "Multi_Mention", Columns = 10,
         Category = "Screener",
         Notes = "Slot-indexed: SQ1_1...SQ1_N. N = number of categories + 1 for NONE"),
    list(QuestionCode = "SQ2",
         QuestionText = "Categories bought in the last 3 months (screener)",
         Variable_Type = "Multi_Mention", Columns = 9,
         Category = "Screener",
         Notes = "Slot-indexed: SQ2_1...SQ2_N. Used as portfolio denominator (3m timeframe)"),
    list(QuestionCode = "BRANDAWARE_DSS",
         QuestionText = "Brands heard of — Dry Seasonings & Spices",
         Variable_Type = "Multi_Mention", Columns = 8,
         Category = "Awareness",
         Notes = "Convention: BRANDAWARE_{CAT}. Slot-indexed. Role: funnel.awareness.DSS + portfolio.awareness.DSS"),
    list(QuestionCode = "BRANDATTR_DSS_CEP01",
         QuestionText = "CEP 1 — Good for a quick weeknight meal (DSS)",
         Variable_Type = "Multi_Mention", Columns = 8,
         Category = "Mental Availability",
         Notes = "Convention: BRANDATTR_{CAT}_{CEP/ATTR code}. Role: mental_avail.cep.DSS.CEP01"),
    list(QuestionCode = "BRANDATT1_DSS_IPK",
         QuestionText = "Brand attitude — IPK (Dry Seasonings)",
         Variable_Type = "Single_Response", Columns = 1,
         Category = "Funnel",
         Notes = "Convention: BRANDATT1_{CAT}_{BRAND}. Per-brand. Role: funnel.attitude.DSS, per_brand entry"),
    list(QuestionCode = "BRANDPEN2_DSS",
         QuestionText = "Brands bought in last 3 months — Dry Seasonings",
         Variable_Type = "Multi_Mention", Columns = 8,
         Category = "Penetration",
         Notes = "Convention: BRANDPEN2_{CAT}. Role: funnel.bought_target.DSS + repertoire.pen_target.DSS"),
    list(QuestionCode = "BRANDPEN3_DSS",
         QuestionText = "Purchase frequency (bought X times) — Dry Seasonings",
         Variable_Type = "Multi_Mention", Columns = 7,
         Category = "Penetration",
         Notes = "Convention: BRANDPEN3_{CAT}. Per-brand frequency sum. Role: repertoire.freq.DSS"),
    list(QuestionCode = "WOM_POS_REC_DSS",
         QuestionText = "Received positive WOM — Dry Seasonings",
         Variable_Type = "Multi_Mention", Columns = 8,
         Category = "WOM",
         Notes = "Convention: WOM_POS_REC_{CAT}. Slot-indexed. Role: wom.pos_rec.DSS"),
    list(QuestionCode = "DEMO_AGE",
         QuestionText = "Age group (demographics)",
         Variable_Type = "Single_Response", Columns = 1,
         Category = "Demographics",
         Notes = "Convention: DEMO_{KEY}. Role: demographics.DEMO_AGE (shown in Demographics panel)"),
    list(QuestionCode = "CATBUY_DSS",
         QuestionText = "How often do you buy in Dry Seasonings?",
         Variable_Type = "Single_Response", Columns = 1,
         Category = "Category Buying",
         Notes = "Convention: CATBUY_{CAT}. Role: cat_buying.frequency.DSS. Scale via OptionMap cat_buy_scale"),
    list(QuestionCode = "CHANNEL_DSS",
         QuestionText = "Where do you usually buy Dry Seasonings? (select all)",
         Variable_Type = "Multi_Mention", Columns = 6,
         Category = "Shopper",
         Notes = "Convention: CHANNEL_{CAT}. Role: channel.purchase.DSS. Channels defined in Channels sheet"),
    list(QuestionCode = "BRANDPEN1_DSS",
         QuestionText = "Brands bought in last 12 months — Dry Seasonings",
         Variable_Type = "Multi_Mention", Columns = 8,
         Category = "Penetration",
         Notes = "Convention: BRANDPEN1_{CAT}. Role: funnel.bought_longer.DSS"),
    # --- Tabs-module examples (non-brand questions) ---
    list(QuestionCode = "Q_Gender",
         QuestionText = "What is your gender?",
         Variable_Type = "Single_Mention", Columns = 1,
         Category = "Demographics",
         Notes = "Standard tabs question — use in Crosstab_Config as banner"),
    list(QuestionCode = "Q_Satisfaction",
         QuestionText = "How satisfied are you overall? (1-5)",
         Variable_Type = "Rating", Columns = 1,
         Category = "Satisfaction",
         Notes = "Tabs Rating question — generates mean score in crosstabs"),
    list(QuestionCode = "Q_NPS",
         QuestionText = "Likelihood to recommend (0-10)",
         Variable_Type = "NPS", Columns = 1,
         Category = "Loyalty",
         Notes = "Tabs NPS — auto-calculates Promoters/Passives/Detractors")
  )
}

.build_unified_options_columns <- function() {
  list(
    list(name = "QuestionCode", width = 28, required = TRUE,
         description = "Links to Questions sheet. BRAND: for slot-indexed Multi_Mention questions use the ROOT code (e.g. BRANDAWARE_DSS, not BRANDAWARE_DSS_1). TABS: for Multi_Mention use individual column codes (Q_Media_1, Q_Media_2)."),
    list(name = "OptionText", width = 16, required = TRUE,
         description = "EXACT value stored in the data file (case-sensitive). If data has numeric codes (1, 2, 3) enter those, not the label. For brand slot columns this is typically the brand code (e.g. IPK) or NONE."),
    list(name = "DisplayText", width = 38, required = TRUE,
         description = "Human-readable label shown in outputs. OptionText '1' can display as 'Male'. This is what respondents and clients see."),
    list(name = "DisplayOrder", width = 14, required = FALSE,
         description = "Sort order in output tables (1 = first/top). Auto-ordered if blank.",
         integer_range = c(1, 500)),
    list(name = "ShowInOutput", width = 14, required = TRUE,
         description = "Y = show this option in output tables. N = hide (useful for suppressing 'None of the above' rows in some views but not others).",
         dropdown = c("Y", "N")),
    list(name = "ExcludeFromIndex", width = 18, required = FALSE,
         description = "TABS ONLY — exclude from mean/index calculations (e.g. Don't know, N/A). Y = exclude.",
         dropdown = c("Y", "")),
    list(name = "Index_Weight", width = 14, required = FALSE,
         description = "TABS ONLY — numeric weight for index calculation. Rating: scale value (1-5). Likert: custom weight (-100 to 100)."),
    list(name = "OptionValue", width = 14, required = FALSE,
         description = "TABS ONLY — alternative numeric value for calculations (overrides OptionText if present)."),
    list(name = "BoxCategory", width = 22, required = FALSE,
         description = "TABS ONLY — group options into summary rows (e.g. 'Top 2 Box', 'Satisfied', 'Promoters'). Options sharing a BoxCategory label are summed."),
    list(name = "Min", width = 10, required = FALSE,
         description = "TABS ONLY — for Numeric binning: minimum value of this bin (e.g. 18 for '18-24' age band)."),
    list(name = "Max", width = 10, required = FALSE,
         description = "TABS ONLY — for Numeric binning: maximum value of this bin (e.g. 24 for '18-24' age band).")
  )
}

.build_unified_options_examples <- function() {
  list(
    # Brand: BRANDAWARE — brand codes as option values
    list(QuestionCode = "BRANDAWARE_DSS", OptionText = "IPK",
         DisplayText = "Ina Paarman's Kitchen",
         DisplayOrder = 1, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDAWARE_DSS", OptionText = "ROB",
         DisplayText = "Robertsons",
         DisplayOrder = 2, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDAWARE_DSS", OptionText = "NONE",
         DisplayText = "None of these",
         DisplayOrder = 9, ShowInOutput = "N"),
    # Brand: BRANDATT1 attitude scale (per-brand)
    list(QuestionCode = "BRANDATT1_DSS_IPK", OptionText = "1",
         DisplayText = "I love it / it's my favourite",
         DisplayOrder = 1, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_DSS_IPK", OptionText = "2",
         DisplayText = "It's among the ones I prefer",
         DisplayOrder = 2, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_DSS_IPK", OptionText = "3",
         DisplayText = "I wouldn't usually consider it, but would if no alternative",
         DisplayOrder = 3, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_DSS_IPK", OptionText = "4",
         DisplayText = "I would refuse to buy this brand",
         DisplayOrder = 4, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_DSS_IPK", OptionText = "5",
         DisplayText = "I have no opinion about this brand",
         DisplayOrder = 5, ShowInOutput = "Y"),
    # Tabs: Gender
    list(QuestionCode = "Q_Gender", OptionText = "1",
         DisplayText = "Male", DisplayOrder = 1, ShowInOutput = "Y"),
    list(QuestionCode = "Q_Gender", OptionText = "2",
         DisplayText = "Female", DisplayOrder = 2, ShowInOutput = "Y"),
    # Tabs: Rating with Index_Weight and BoxCategory
    list(QuestionCode = "Q_Satisfaction", OptionText = "1",
         DisplayText = "Very Dissatisfied", DisplayOrder = 1,
         ShowInOutput = "Y", Index_Weight = 1, BoxCategory = "Bottom 2 Box"),
    list(QuestionCode = "Q_Satisfaction", OptionText = "3",
         DisplayText = "Neutral", DisplayOrder = 3,
         ShowInOutput = "Y", Index_Weight = 3, BoxCategory = ""),
    list(QuestionCode = "Q_Satisfaction", OptionText = "5",
         DisplayText = "Very Satisfied", DisplayOrder = 5,
         ShowInOutput = "Y", Index_Weight = 5, BoxCategory = "Top 2 Box")
  )
}

.build_composite_metrics_columns <- function() {
  list(
    list(name = "CompositeCode", width = 24, required = TRUE,
         description = "TABS ONLY — unique identifier for this composite score (e.g. COMP_SAT_OVERALL). Used as sheet name in output. Brand module ignores this sheet."),
    list(name = "CompositeLabel", width = 35, required = TRUE,
         description = "Display name shown in output (e.g. 'Overall Satisfaction Index')."),
    list(name = "CalculationType", width = 18, required = TRUE,
         description = "How to combine source questions.",
         dropdown = c("Mean", "Sum", "WeightedMean")),
    list(name = "SourceQuestions", width = 35, required = TRUE,
         description = "Comma-separated QuestionCodes to combine (e.g. Q_Sat1,Q_Sat2,Q_Sat3). Must exist in Questions sheet."),
    list(name = "Weights", width = 25, required = FALSE,
         description = "Required if CalculationType = WeightedMean. Comma-separated weights, one per source question."),
    list(name = "SectionLabel", width = 25, required = FALSE,
         description = "Groups composites in the Index Summary (e.g. 'Brand Health Metrics')."),
    list(name = "ExcludeFromSummary", width = 20, required = FALSE,
         description = "Y = hide from Index_Summary sheet.",
         dropdown = c("Y", "")),
    list(name = "Notes", width = 30, required = FALSE,
         description = "Internal notes (not shown in output).")
  )
}

.build_composite_metrics_examples <- function() {
  list(
    list(CompositeCode = "COMP_SAT_OVERALL", CompositeLabel = "Overall Satisfaction Index",
         CalculationType = "Mean", SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
         SectionLabel = "Satisfaction", Notes = "Simple mean of 3 items"),
    list(CompositeCode = "COMP_BRAND_HEALTH", CompositeLabel = "Brand Health Score",
         CalculationType = "WeightedMean", SourceQuestions = "Q_Aware,Q_Consider,Q_Prefer",
         Weights = "1,2,3", SectionLabel = "Brand",
         Notes = "Preference weighted 3x, consideration 2x")
  )
}


# ==============================================================================
# SURVEY_STRUCTURE — BRAND-SPECIFIC SHEETS
# ==============================================================================

.build_brands_columns <- function() {
  list(
    list(name = "Category", width = 30, required = TRUE,
         description = "Full category display name (e.g. 'Dry Seasonings & Spices'). Must match the Category column in Brand_Config Categories sheet."),
    list(name = "CategoryCode", width = 14, required = TRUE,
         description = "Short category code (e.g. DSS). Must match CategoryCode in Brand_Config Categories sheet. Used to filter column names."),
    list(name = "BrandCode", width = 16, required = TRUE,
         description = "Unique brand code used in data column names (e.g. IPK). Must match the suffix in BRANDAWARE_DSS_IPK, BRANDPEN2_DSS_IPK, etc. Case-sensitive."),
    list(name = "BrandLabel", width = 28, required = TRUE,
         description = "Display label for charts, tables, and legends (e.g. 'Ina Paarman\\'s Kitchen'). This is what clients see."),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order within category (1 = first on chart). Convention: focal brand = 1.",
         integer_range = c(1, 100)),
    list(name = "IsFocal", width = 12, required = TRUE,
         description = "Y = this is the focal (client) brand for this category. Exactly one Y per category. Must match focal_brand in Brand_Config Settings.",
         dropdown = c("Y", "N")),
    list(name = "Colour", width = 16, required = FALSE,
         description = "Optional hex colour (#RRGGBB) for this brand in charts and chips. Focal brand should match colour_focal in Brand_Config. Leave blank to use category defaults.")
  )
}

.build_brands_examples <- function() {
  list(
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         BrandCode = "IPK", BrandLabel = "Ina Paarman's Kitchen",
         DisplayOrder = 1, IsFocal = "Y", Colour = "#1A5276"),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         BrandCode = "ROB", BrandLabel = "Robertsons",
         DisplayOrder = 2, IsFocal = "N", Colour = ""),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         BrandCode = "KNO", BrandLabel = "Knorr",
         DisplayOrder = 3, IsFocal = "N", Colour = ""),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         BrandCode = "NONE", BrandLabel = "None of these",
         DisplayOrder = 99, IsFocal = "N", Colour = ""),
    list(Category = "Ready Meals", CategoryCode = "RM",
         BrandCode = "IPK", BrandLabel = "Ina Paarman's Kitchen",
         DisplayOrder = 1, IsFocal = "Y", Colour = "#1A5276"),
    list(Category = "Ready Meals", CategoryCode = "RM",
         BrandCode = "COMPA", BrandLabel = "Competitor A",
         DisplayOrder = 2, IsFocal = "N", Colour = "")
  )
}

.build_ceps_columns <- function() {
  list(
    list(name = "Category", width = 30, required = TRUE,
         description = "Full category display name. Must match Category in Brands sheet."),
    list(name = "CategoryCode", width = 14, required = TRUE,
         description = "Short category code (e.g. DSS)."),
    list(name = "CEPCode", width = 14, required = TRUE,
         description = "Unique CEP identifier within category (e.g. CEP01, CEP02). Must match the suffix in the question code: BRANDATTR_DSS_CEP01."),
    list(name = "CEPText", width = 55, required = TRUE,
         description = "Full CEP statement text shown in outputs. Should be simple, concrete, and situation-based (Romaniuk's distinctiveness principle): e.g. 'Good for a quick weeknight meal', not 'High quality'."),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order in Mental Availability matrix and TURF output (1 = first).",
         integer_range = c(1, 50))
  )
}

.build_ceps_examples <- function() {
  list(
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         CEPCode = "CEP01", CEPText = "Good for a quick weeknight meal",
         DisplayOrder = 1),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         CEPCode = "CEP02", CEPText = "Something the whole family enjoys",
         DisplayOrder = 2),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         CEPCode = "CEP03", CEPText = "When I want a healthy option",
         DisplayOrder = 3),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         CEPCode = "CEP04", CEPText = "Cooking a special meal for guests",
         DisplayOrder = 4),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         CEPCode = "CEP05", CEPText = "On a tight budget this week",
         DisplayOrder = 5)
  )
}

.build_attributes_columns <- function() {
  list(
    list(name = "Category", width = 30, required = TRUE,
         description = "Full category display name."),
    list(name = "CategoryCode", width = 14, required = TRUE,
         description = "Short category code."),
    list(name = "AttrCode", width = 14, required = TRUE,
         description = "Unique attribute identifier within category (e.g. ATTR01). Must match the suffix in the question code: BRANDATTR_DSS_ATTR01."),
    list(name = "AttrText", width = 55, required = TRUE,
         description = "Full attribute statement text. These are brand perception items (not entry points). Typically functional or emotional associations: e.g. 'Good value for money', 'Uses quality ingredients', 'Premium brand'."),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order in Drivers & Barriers and brand image outputs.",
         integer_range = c(1, 50))
  )
}

.build_attributes_examples <- function() {
  list(
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         AttrCode = "ATTR01", AttrText = "Good value for money",
         DisplayOrder = 1),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         AttrCode = "ATTR02", AttrText = "Uses quality ingredients",
         DisplayOrder = 2),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         AttrCode = "ATTR03", AttrText = "A brand I trust",
         DisplayOrder = 3),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         AttrCode = "ATTR04", AttrText = "Has a wide product range",
         DisplayOrder = 4)
  )
}

.build_dba_structure_columns <- function() {
  list(
    list(name = "AssetCode", width = 16, required = TRUE,
         description = "Unique asset code (must match AssetCode in Brand_Config DBA_Assets sheet)."),
    list(name = "AssetLabel", width = 26, required = TRUE,
         description = "Display label for charts."),
    list(name = "AssetType", width = 14, required = TRUE,
         description = "Stimulus type.",
         dropdown = c("image", "text", "audio")),
    list(name = "FameQuestionCode", width = 26, required = TRUE,
         description = "Question code for the Fame (recognition) question in the data (e.g. DBA_FAME_LOGO). Must match Questions sheet."),
    list(name = "UniqueQuestionCode", width = 26, required = TRUE,
         description = "Question code for the Uniqueness (attribution) question in the data (e.g. DBA_UNIQUE_LOGO). Multi_Mention of brand codes.")
  )
}

.build_dba_structure_examples <- function() {
  list(
    list(AssetCode = "LOGO", AssetLabel = "Primary Logo",
         AssetType = "image",
         FameQuestionCode = "DBA_FAME_LOGO",
         UniqueQuestionCode = "DBA_UNIQUE_LOGO"),
    list(AssetCode = "COLOUR", AssetLabel = "Brand Colour",
         AssetType = "image",
         FameQuestionCode = "DBA_FAME_COLOUR",
         UniqueQuestionCode = "DBA_UNIQUE_COLOUR"),
    list(AssetCode = "TAGLINE", AssetLabel = "Tagline",
         AssetType = "text",
         FameQuestionCode = "DBA_FAME_TAGLINE",
         UniqueQuestionCode = "DBA_UNIQUE_TAGLINE")
  )
}

.build_questionmap_columns <- function() {
  list(
    list(name = "Role", width = 38, required = TRUE,
         description = "Role name this row overrides or inserts. Must match the convention-inferred role (to override) or be a new fully-qualified role (to insert). Examples: cat_buying.frequency.DSS, adhoc.Q_BrandPerception.ALL, demographics.DEMO_PROVINCE, channel.purchase.DSS."),
    list(name = "ClientCode", width = 28, required = TRUE,
         description = "Data column name (or prefix) for this role. The resolver finds the actual columns in data. For slot-indexed: provide root (e.g. CATBUY_DSS). For per-brand: provide root (e.g. BRANDPEN2_DSS)."),
    list(name = "Variable_Type", width = 20, required = FALSE,
         description = "Override the Variable_Type inferred from the Questions sheet. Use only when the inferred type is wrong.",
         dropdown = c("Single_Response", "Multi_Mention", "Single_Mention", "Numeric", "Open_End")),
    list(name = "OptionMapScale", width = 22, required = FALSE,
         description = "Name of the scale to look up in the OptionMap sheet (e.g. cat_buy_scale, attitude_scale). Required when the coded responses need to be mapped to canonical role labels. Leave blank for standard brand code columns."),
    list(name = "Notes", width = 40, required = FALSE,
         description = "Internal documentation. Describe why this override or insert is needed.")
  )
}

.build_questionmap_examples <- function() {
  list(
    list(Role = "cat_buying.frequency.DSS",
         ClientCode = "CATBUY_DSS",
         Variable_Type = "Single_Response",
         OptionMapScale = "cat_buy_scale",
         Notes = "Category buying frequency — coded response mapped to buy-rate multiplier via cat_buy_scale OptionMap"),
    list(Role = "cat_buying.frequency.RM",
         ClientCode = "CATBUY_RM",
         Variable_Type = "Single_Response",
         OptionMapScale = "cat_buy_scale",
         Notes = "Same scale for Ready Meals category"),
    list(Role = "demographics.DEMO_PROVINCE",
         ClientCode = "DEMO_PROVINCE",
         Variable_Type = "Single_Response",
         OptionMapScale = "",
         Notes = "Province demographics — options defined in Options sheet by QuestionCode = DEMO_PROVINCE"),
    list(Role = "adhoc.Q_BrandPerception.ALL",
         ClientCode = "Q_BrandPerception",
         Variable_Type = "Single_Mention",
         OptionMapScale = "",
         Notes = "Ad hoc question shown for ALL respondents (sample-wide scope). Scope = ALL means it appears in every category panel.")
  )
}

.build_optionmap_columns <- function() {
  list(
    list(name = "Scale", width = 22, required = TRUE,
         description = "Scale name referenced by OptionMapScale in QuestionMap. All rows belonging to the same scale share this value. Examples: cat_buy_scale, attitude_scale, reach_seen_scale, packsize_scale."),
    list(name = "ClientCode", width = 18, required = TRUE,
         description = "The coded value stored in the data file for this option (e.g. 1, 2, sev_pw). Must match the values in the data exactly."),
    list(name = "Role", width = 35, required = TRUE,
         description = "Canonical role name for this option within its scale (e.g. cat_buy_scale.several_week, attitude_scale.love). Used by the engine to map codes to business logic (e.g. buy-rate multipliers)."),
    list(name = "ClientLabel", width = 35, required = TRUE,
         description = "Human-readable label shown in output for this option (e.g. 'Several times a week', 'I love it')."),
    list(name = "OrderIndex", width = 14, required = FALSE,
         description = "Sort order within the scale (1 = first). Used to determine display order and funnel direction.",
         integer_range = c(1, 50))
  )
}

.build_optionmap_examples <- function() {
  list(
    # cat_buy_scale — buying frequency mapped to annual buy-rate multiplier
    list(Scale = "cat_buy_scale", ClientCode = "sev_pw",
         Role = "cat_buy_scale.several_week",
         ClientLabel = "Several times a week", OrderIndex = 1),
    list(Scale = "cat_buy_scale", ClientCode = "once_pw",
         Role = "cat_buy_scale.once_week",
         ClientLabel = "About once a week", OrderIndex = 2),
    list(Scale = "cat_buy_scale", ClientCode = "few_pm",
         Role = "cat_buy_scale.few_month",
         ClientLabel = "A few times a month", OrderIndex = 3),
    list(Scale = "cat_buy_scale", ClientCode = "once_pm",
         Role = "cat_buy_scale.monthly_less",
         ClientLabel = "About once a month or less", OrderIndex = 4),
    list(Scale = "cat_buy_scale", ClientCode = "never",
         Role = "cat_buy_scale.never",
         ClientLabel = "I don't buy in this category", OrderIndex = 5),
    # attitude_scale — brand attitude hierarchy
    list(Scale = "attitude_scale", ClientCode = "1",
         Role = "attitude_scale.love",
         ClientLabel = "I love it / it's my favourite", OrderIndex = 1),
    list(Scale = "attitude_scale", ClientCode = "2",
         Role = "attitude_scale.prefer",
         ClientLabel = "It's among the ones I prefer", OrderIndex = 2),
    list(Scale = "attitude_scale", ClientCode = "3",
         Role = "attitude_scale.acceptable",
         ClientLabel = "I would use if no alternative", OrderIndex = 3),
    list(Scale = "attitude_scale", ClientCode = "4",
         Role = "attitude_scale.reject",
         ClientLabel = "I would refuse to buy this brand", OrderIndex = 4),
    list(Scale = "attitude_scale", ClientCode = "5",
         Role = "attitude_scale.no_opinion",
         ClientLabel = "I have no opinion about this brand", OrderIndex = 5),
    # reach_seen_scale — branded reach recognition
    list(Scale = "reach_seen_scale", ClientCode = "1",
         Role = "reach_seen_scale.recognised",
         ClientLabel = "I recognise this", OrderIndex = 1),
    list(Scale = "reach_seen_scale", ClientCode = "2",
         Role = "reach_seen_scale.not_recognised",
         ClientLabel = "I don't recognise this", OrderIndex = 2)
  )
}

.build_channels_columns <- function() {
  list(
    list(name = "Category", width = 30, required = TRUE,
         description = "Full category display name this channel list applies to."),
    list(name = "CategoryCode", width = 14, required = TRUE,
         description = "Short category code (e.g. DSS)."),
    list(name = "ChannelCode", width = 18, required = TRUE,
         description = "Unique channel code within category. Must match the brand values in the CHANNEL_{CAT} data column."),
    list(name = "ChannelLabel", width = 35, required = TRUE,
         description = "Display label for the purchase channel in outputs (e.g. 'Large supermarket', 'Online / delivery app')."),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order in Shopper Behaviour panel.",
         integer_range = c(1, 50))
  )
}

.build_channels_examples <- function() {
  list(
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         ChannelCode = "SUPERMARKET", ChannelLabel = "Large supermarket (e.g. Checkers, Pick n Pay)",
         DisplayOrder = 1),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         ChannelCode = "HYPERMARKET", ChannelLabel = "Hypermarket / wholesale (e.g. Makro)",
         DisplayOrder = 2),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         ChannelCode = "CONVENIENCE", ChannelLabel = "Convenience / corner store",
         DisplayOrder = 3),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         ChannelCode = "ONLINE", ChannelLabel = "Online / delivery app",
         DisplayOrder = 4),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         ChannelCode = "OTHER", ChannelLabel = "Other",
         DisplayOrder = 5)
  )
}

.build_packsizes_columns <- function() {
  list(
    list(name = "Category", width = 30, required = TRUE,
         description = "Full category display name this pack size list applies to."),
    list(name = "CategoryCode", width = 14, required = TRUE,
         description = "Short category code."),
    list(name = "PackCode", width = 18, required = TRUE,
         description = "Unique pack size code within category. Must match brand values in the PACK_{CAT} data column."),
    list(name = "PackLabel", width = 35, required = TRUE,
         description = "Display label shown in Shopper Behaviour panel (e.g. '10g – 50g (small/sachets)')."),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order in Shopper Behaviour panel (typically smallest to largest).",
         integer_range = c(1, 50))
  )
}

.build_packsizes_examples <- function() {
  list(
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         PackCode = "SMALL", PackLabel = "10g – 50g (small / sachets)",
         DisplayOrder = 1),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         PackCode = "MEDIUM", PackLabel = "51g – 200g (standard jar)",
         DisplayOrder = 2),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         PackCode = "LARGE", PackLabel = "201g+ (large / catering)",
         DisplayOrder = 3),
    list(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
         PackCode = "MIXED", PackLabel = "Different sizes at different times",
         DisplayOrder = 4)
  )
}

.build_marketing_reach_columns <- function() {
  list(
    list(name = "AssetCode", width = 18, required = TRUE,
         description = "Unique code for this marketing asset (e.g. TV_AD_Q1_2026, OOH_CAPE_JAN). Referenced by the Branded Reach engine."),
    list(name = "AssetLabel", width = 35, required = TRUE,
         description = "Display label for the asset in outputs (e.g. 'TV ad — January 2026')."),
    list(name = "Category", width = 24, required = TRUE,
         description = "Category this asset is associated with, or 'ALL' for brand-level assets."),
    list(name = "Brand", width = 16, required = TRUE,
         description = "BrandCode of the brand this asset belongs to."),
    list(name = "MediaType", width = 18, required = FALSE,
         description = "Media channel type for grouping in the panel (e.g. TV, OOH, Digital, Print, Radio).",
         dropdown = c("TV", "Digital", "OOH", "Print", "Radio", "Sponsorship", "Other")),
    list(name = "ImagePath", width = 40, required = FALSE,
         description = "Path to asset image for display in HTML report, relative to project root. Leave blank if not embedding.")
  )
}

.build_marketing_reach_examples <- function() {
  list(
    list(AssetCode = "TV_AD_Q1_2026", AssetLabel = "TV ad — Q1 2026",
         Category = "DSS", Brand = "IPK",
         MediaType = "TV", ImagePath = "assets/reach/tv_ad_q1_2026.png"),
    list(AssetCode = "OOH_NATIONAL_JAN", AssetLabel = "Billboard — January 2026",
         Category = "ALL", Brand = "IPK",
         MediaType = "OOH", ImagePath = ""),
    list(AssetCode = "DIGITAL_FACEBOOK_FEB", AssetLabel = "Facebook ad — February 2026",
         Category = "DSS", Brand = "IPK",
         MediaType = "Digital", ImagePath = "")
  )
}

.build_reach_media_columns <- function() {
  list(
    list(name = "MediaCode", width = 18, required = TRUE,
         description = "Unique code for this reach media channel. Must match the coded values in the reach media attribution question in the data."),
    list(name = "MediaLabel", width = 35, required = TRUE,
         description = "Display label shown in the Branded Reach panel (e.g. 'Television', 'Facebook / Instagram')."),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order within the reach media panel.",
         integer_range = c(1, 30))
  )
}

.build_reach_media_examples <- function() {
  list(
    list(MediaCode = "TV", MediaLabel = "Television", DisplayOrder = 1),
    list(MediaCode = "FACEBOOK", MediaLabel = "Facebook / Instagram", DisplayOrder = 2),
    list(MediaCode = "YOUTUBE", MediaLabel = "YouTube", DisplayOrder = 3),
    list(MediaCode = "OOH", MediaLabel = "Outdoor / billboards", DisplayOrder = 4),
    list(MediaCode = "RADIO", MediaLabel = "Radio", DisplayOrder = 5),
    list(MediaCode = "PRINT", MediaLabel = "Newspaper / magazine", DisplayOrder = 6),
    list(MediaCode = "OTHER", MediaLabel = "Other / unsure", DisplayOrder = 7)
  )
}

.build_audience_lens_columns <- function() {
  list(
    list(name = "Category", width = 18, required = TRUE,
         description = "Short category code (e.g. DSS) or 'ALL' for audiences available in every category."),
    list(name = "AudienceID", width = 20, required = TRUE,
         description = "Unique audience identifier within category (e.g. BUYER, NON_BUYER, HEAVY, FEMALE). Referenced in the Brand_Config Categories AudienceLens_Use column."),
    list(name = "AudienceLabel", width = 30, required = TRUE,
         description = "Display label shown as the audience column header in the panel (e.g. 'Buyers', 'Non-buyers', 'Heavy buyers')."),
    list(name = "PairID", width = 12, required = FALSE,
         description = "Optional. Two rows sharing a PairID are displayed as a paired comparison (e.g. Buyers vs Non-buyers). Leave blank for standalone audiences."),
    list(name = "PairRole", width = 12, required = FALSE,
         description = "Required when PairID is set. 'A' = first column (typically the primary segment); 'B' = second column.",
         dropdown = c("A", "B", "")),
    list(name = "FilterColumn", width = 24, required = TRUE,
         description = "Data column to test for this audience filter (e.g. BRANDPEN2_DSS, DEMO_GENDER, Focal_Category)."),
    list(name = "FilterOp", width = 12, required = TRUE,
         description = "Comparison operator. Type one of: == != > < >= <= in not_in. Use 'in' / 'not_in' with comma-separated FilterValue (e.g. IPK,ROB). Note: no dropdown — < and > cannot be listed in Excel inline validations."),
    list(name = "FilterValue", width = 30, required = TRUE,
         description = "Value(s) to compare against. For 'in' / 'not_in' operators: comma-separated list (e.g. IPK,ROB). For '==' operators: single value (e.g. IPK, 1, FEMALE).")
  )
}

.build_audience_lens_examples <- function() {
  list(
    list(Category = "DSS", AudienceID = "BUYER", AudienceLabel = "Buyers of IPK",
         PairID = "BUY_PAIR", PairRole = "A",
         FilterColumn = "BRANDPEN2_DSS", FilterOp = "in",
         FilterValue = "IPK"),
    list(Category = "DSS", AudienceID = "NON_BUYER", AudienceLabel = "Non-buyers of IPK",
         PairID = "BUY_PAIR", PairRole = "B",
         FilterColumn = "BRANDPEN2_DSS", FilterOp = "not_in",
         FilterValue = "IPK"),
    list(Category = "ALL", AudienceID = "FEMALE", AudienceLabel = "Women",
         PairID = "GENDER_PAIR", PairRole = "A",
         FilterColumn = "DEMO_GENDER", FilterOp = "==",
         FilterValue = "F"),
    list(Category = "ALL", AudienceID = "MALE", AudienceLabel = "Men",
         PairID = "GENDER_PAIR", PairRole = "B",
         FilterColumn = "DEMO_GENDER", FilterOp = "==",
         FilterValue = "M")
  )
}


# ==============================================================================
# REFERENCE SHEETS
# ==============================================================================

.write_variable_type_reference <- function(wb) {
  openxlsx::addWorksheet(wb, "Variable Type Reference", gridLines = FALSE)
  openxlsx::setColWidths(wb, "Variable Type Reference",
                         cols = 1:5, widths = c(20, 36, 14, 28, 36))

  openxlsx::writeData(wb, "Variable Type Reference",
                      x = "Variable Type Reference", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "Variable Type Reference", make_title_style(),
                     rows = 1, cols = 1)
  openxlsx::mergeCells(wb, "Variable Type Reference", cols = 1:5, rows = 1)

  openxlsx::writeData(wb, "Variable Type Reference",
                      x = "Reference guide for choosing the correct Variable_Type value in the Questions sheet. This sheet is not processed by any module.",
                      startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, "Variable Type Reference", make_subtitle_style(),
                     rows = 2, cols = 1)
  openxlsx::mergeCells(wb, "Variable Type Reference", cols = 1:5, rows = 2)

  headers <- c("Variable_Type", "Description", "Columns", "Key Processing", "Example Use")
  openxlsx::writeData(wb, "Variable Type Reference",
                      x = data.frame(t(headers)), startRow = 4, startCol = 1,
                      colNames = FALSE)
  openxlsx::addStyle(wb, "Variable Type Reference", make_header_style(),
                     rows = 4, cols = 1:5, gridExpand = TRUE)

  ref_data <- data.frame(
    V1 = c("Single_Mention", "Single_Response", "Multi_Mention",
           "Likert", "Rating", "NPS", "Ranking", "Numeric", "Open_End"),
    V2 = c(
      "Pick-one: respondent selects exactly one option",
      "Identical to Single_Mention — alternate name used in brand module",
      "Check-all-that-apply: respondent can select multiple options. Also used for slot-indexed brand batteries",
      "Agreement scale with custom index weights (-100 to +100)",
      "Numeric scale where the mean is meaningful (e.g. 1-5, 1-10)",
      "Net Promoter Score (0-10). Auto-calculates Promoters/Passives/Detractors",
      "Ordered preference ranking. Columns = number of ranked items",
      "Open-ended numeric response. Supports binning via Options Min/Max",
      "Free text — not processed in crosstabs or brand analysis"
    ),
    V3 = c("1", "1", ">1 (# slots)", "1", "1", "1", ">1 (# items)", "1", "1"),
    V4 = c(
      "Frequencies + column % + sig tests",
      "Same as Single_Mention",
      "Each slot has its own column (Q_1, Q_2...). Brand batteries use role-map inference",
      "Frequencies + custom-weighted NET index + NET POSITIVE row",
      "Frequencies + Mean score + optional SD",
      "Freq + NPS score (Promoters – Detractors × 100)",
      "Average rank + first-choice share + Borda count",
      "Mean, median, SD; optional binning via Options Min/Max",
      "Shown as text only; no statistical processing"
    ),
    V5 = c(
      "Gender, Yes/No, Preferred brand",
      "BRANDATT1 (attitude), DEMO_GENDER (brand module)",
      "BRANDAWARE, BRANDPEN2, WOM_POS_REC, media used",
      "Agree/Disagree brand statements",
      "Overall satisfaction 1-5, Likelihood 1-10",
      "Recommendation likelihood 0-10",
      "Rank your top 3 brands",
      "Age (numeric open), monthly spend",
      "Verbatim comments, rejection reasons"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Variable Type Reference", x = ref_data,
                      startRow = 5, startCol = 1, colNames = FALSE)
  for (r in 5:(5 + nrow(ref_data) - 1)) {
    openxlsx::addStyle(wb, "Variable Type Reference", make_locked_style(),
                       rows = r, cols = 1:5, gridExpand = TRUE)
  }
  openxlsx::setRowHeights(wb, "Variable Type Reference",
                          rows = 5:(5 + nrow(ref_data) - 1), heights = 55)
}

.write_naming_convention_reference <- function(wb) {
  sheet <- "Question Naming Guide"
  openxlsx::addWorksheet(wb, sheet, gridLines = FALSE)
  openxlsx::setColWidths(wb, sheet, cols = 1:4, widths = c(34, 22, 22, 34))

  openxlsx::writeData(wb, sheet, x = "Question Code Naming Convention Guide",
                      startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, sheet, make_title_style(), rows = 1, cols = 1)
  openxlsx::mergeCells(wb, sheet, cols = 1:4, rows = 1)

  openxlsx::writeData(wb, sheet,
    x = paste0("The brand module infers analytical roles from question code names automatically — ",
               "no Battery or Category column needed. Follow these naming patterns exactly. ",
               "This sheet is for reference only."),
    startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, sheet, make_subtitle_style(), rows = 2, cols = 1)
  openxlsx::mergeCells(wb, sheet, cols = 1:4, rows = 2)

  headers <- c("Pattern", "Example", "Inferred Role", "Notes")
  openxlsx::writeData(wb, sheet, x = data.frame(t(headers)),
                      startRow = 4, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet, make_header_style(),
                     rows = 4, cols = 1:4, gridExpand = TRUE)

  conventions <- data.frame(
    Pattern = c(
      "BRANDAWARE_{CAT}",
      "BRANDATTR_{CAT}_{ITEM}",
      "BRANDATT1_{CAT}_{BRAND}",
      "BRANDATT2_{CAT}_{BRAND}",
      "BRANDPEN1_{CAT}",
      "BRANDPEN2_{CAT}",
      "BRANDPEN3_{CAT}",
      "WOM_POS_REC_{CAT}",
      "WOM_POS_SHARE_{CAT}",
      "WOM_NEG_REC_{CAT}",
      "WOM_NEG_SHARE_{CAT}",
      "WOM_POS_COUNT_{CAT}_{BRAND}",
      "WOM_NEG_COUNT_{CAT}_{BRAND}",
      "CATBUY_{CAT}",
      "CATCOUNT_{CAT}",
      "CHANNEL_{CAT}",
      "PACK_{CAT}",
      "SQ1",
      "SQ2",
      "DEMO_{KEY}",
      "BRANDAWARE_{CAT}  (cross-cat)",
      "DBA_FAME_{ASSET}",
      "DBA_UNIQUE_{ASSET}"
    ),
    Example = c(
      "BRANDAWARE_DSS",
      "BRANDATTR_DSS_CEP01",
      "BRANDATT1_DSS_IPK",
      "BRANDATT2_DSS_IPK",
      "BRANDPEN1_DSS",
      "BRANDPEN2_DSS",
      "BRANDPEN3_DSS",
      "WOM_POS_REC_DSS",
      "WOM_POS_SHARE_DSS",
      "WOM_NEG_REC_DSS",
      "WOM_NEG_SHARE_DSS",
      "WOM_POS_COUNT_DSS_IPK",
      "WOM_NEG_COUNT_DSS_IPK",
      "CATBUY_DSS",
      "CATCOUNT_DSS",
      "CHANNEL_DSS",
      "PACK_DSS",
      "SQ1",
      "SQ2",
      "DEMO_GENDER",
      "BRANDAWARE_RM",
      "DBA_FAME_LOGO",
      "DBA_UNIQUE_LOGO"
    ),
    Role = c(
      "funnel.awareness.{CAT}",
      "mental_avail.cep.{CAT}.{ITEM}  OR  mental_avail.attr.{CAT}.{ITEM}",
      "funnel.attitude.{CAT}  (per_brand)",
      "funnel.attitude_oe.{CAT}  (per_brand)",
      "funnel.bought_longer.{CAT}",
      "funnel.bought_target.{CAT}  + repertoire.pen_target.{CAT}",
      "repertoire.freq.{CAT}",
      "wom.pos_rec.{CAT}",
      "wom.pos_share.{CAT}",
      "wom.neg_rec.{CAT}",
      "wom.neg_share.{CAT}",
      "wom.pos_count.{CAT}  (per_brand)",
      "wom.neg_count.{CAT}  (per_brand)",
      "cat_buying.frequency.{CAT}  — needs QuestionMap + OptionMap",
      "cat_buying.count.{CAT}",
      "channel.purchase.{CAT}  — needs Channels sheet",
      "cat_buying.packsize.{CAT}  — needs PackSizes sheet",
      "screener.cat_buyers_longer  (slot-indexed)",
      "screener.cat_buyers_target  (slot-indexed)",
      "demographics.{KEY}",
      "portfolio.awareness.{CAT}  (also emitted by BRANDAWARE_{CAT})",
      "dba.fame.{ASSET}",
      "dba.uniqueness.{ASSET}"
    ),
    Notes = c(
      "Multi_Mention, slot-indexed. Slots = brands + NONE",
      "Multi_Mention, slot-indexed. Item code prefix determines type: CEP## -> cep, ATTR## -> attr",
      "Single_Response, per-brand. One column per brand",
      "Open_End, per-brand. Rejection reasons",
      "Multi_Mention, slot-indexed. 12-month penetration window",
      "Multi_Mention, slot-indexed. Short-run window (target_timeframe_months)",
      "Multi_Mention, slot-indexed. Cumulative purchase count per brand",
      "Multi_Mention, slot-indexed. Received positive WOM",
      "Multi_Mention, slot-indexed. Shared (gave) positive WOM",
      "Multi_Mention, slot-indexed. Received negative WOM",
      "Multi_Mention, slot-indexed. Shared (gave) negative WOM",
      "Single_Response, per-brand. Count of positive mentions",
      "Single_Response, per-brand. Count of negative mentions",
      "Single_Response. Buying frequency. Add QuestionMap row + cat_buy_scale OptionMap",
      "Numeric. How many units/times bought",
      "Multi_Mention, slot-indexed. Requires Channels sheet",
      "Multi_Mention, slot-indexed. Requires PackSizes sheet",
      "Multi_Mention, slot-indexed. One slot per category + NONE (SQ1_1...SQ1_N)",
      "Multi_Mention, slot-indexed. One slot per category (SQ2_1...SQ2_N — no NONE)",
      "Single_Response. Shown in Demographics panel",
      "BRANDAWARE_{CAT} is dual-purposed: also feeds cross-category portfolio",
      "Single_Response / Multi_Mention. Fame = recognition question",
      "Multi_Mention of brand codes. Uniqueness = attribution"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, sheet, x = conventions, startRow = 5, startCol = 1,
                      colNames = FALSE)
  for (r in 5:(5 + nrow(conventions) - 1)) {
    openxlsx::addStyle(wb, sheet, make_locked_style(),
                       rows = r, cols = 1:4, gridExpand = TRUE)
  }
  openxlsx::setRowHeights(wb, sheet,
                          rows = 5:(5 + nrow(conventions) - 1), heights = 48)
}


# ==============================================================================
# MAIN GENERATOR: Brand_Config_Template.xlsx
# ==============================================================================

#' Generate Brand_Config_Template.xlsx
#'
#' Creates a professional, fully-documented configuration template for the
#' brand module. Three sheets: Settings (all analysis parameters), Categories
#' (one row per category), and DBA_Assets (if DBA element is used).
#'
#' @param output_path Character. Path for the output .xlsx file.
#' @param overwrite Logical. Overwrite if file exists (default: FALSE).
#'
#' @return List with status = "PASS" and output_path, or a TRS refusal.
#'
#' @examples
#' \dontrun{
#'   generate_brand_config_template(
#'     "modules/brand/templates/Brand_Config_Template.xlsx", overwrite = TRUE)
#' }
#'
#' @export
generate_brand_config_template <- function(output_path, overwrite = FALSE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(list(status = "REFUSED", code = "PKG_MISSING",
                message = "Package 'openxlsx' is required",
                how_to_fix = "install.packages('openxlsx')"))
  }

  if (file.exists(output_path) && !overwrite) {
    return(list(status = "REFUSED", code = "IO_FILE_EXISTS",
                message = sprintf("File already exists: %s", output_path),
                how_to_fix = "Set overwrite = TRUE or choose a different path"))
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  tryCatch(.ensure_template_styles(),
           error = function(e) stop(sprintf("Cannot load template styles: %s", e$message)))

  wb <- openxlsx::createWorkbook()

  write_settings_sheet(
    wb, "Settings",
    .build_brand_settings_def(),
    title = "TURAS Brand Module — Configuration",
    subtitle = "Edit the Value column only. Yellow cells are editable. Use dropdowns where provided."
  )

  write_table_sheet(
    wb, "Categories",
    .build_categories_columns(),
    title = "Category Definitions",
    subtitle = "One row per category in the study. CategoryCode must match column name suffixes in the data (e.g. DSS in BRANDAWARE_DSS). Blue rows are examples.",
    example_rows = .build_categories_examples(),
    num_blank_rows = 12
  )

  write_table_sheet(
    wb, "DBA_Assets",
    .build_dba_assets_columns(),
    title = "DBA Asset Definitions  [only needed if element_dba = Y]",
    subtitle = "One row per brand asset stimulus. Asset codes must match DBA_Assets sheet in Survey_Structure. Blue rows are examples.",
    example_rows = .build_dba_assets_examples(),
    num_blank_rows = 12
  )

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)

  cat(sprintf("\n  [OK] Brand_Config_Template.xlsx written: %s\n", output_path))
  list(status = "PASS", output_path = output_path,
       message = sprintf("Brand config template written to %s", output_path))
}


# ==============================================================================
# MAIN GENERATOR: Survey_Structure_Brand_Config_Template.xlsx  (unified)
# ==============================================================================

#' Generate Survey_Structure_Brand_Config_Template.xlsx  (unified)
#'
#' Creates a single Survey_Structure file that drives BOTH the brand module
#' AND the tabs module. Brand-specific sheets (Brands, CEPs, Attributes,
#' QuestionMap, OptionMap, Channels, PackSizes, MarketingReach, ReachMedia,
#' AudienceLens, DBA_Assets) coexist with the tabs-required sheets (Questions,
#' Options, Composite_Metrics). Tabs ignores the brand sheets; the brand
#' module ignores the Composite_Metrics sheet.
#'
#' @param output_path Character. Path for the output .xlsx file.
#' @param overwrite Logical. Overwrite if file exists (default: FALSE).
#'
#' @return List with status = "PASS" and output_path, or a TRS refusal.
#'
#' @examples
#' \dontrun{
#'   generate_brand_survey_structure_template(
#'     "modules/brand/templates/Survey_Structure_Brand_Config_Template.xlsx",
#'     overwrite = TRUE)
#' }
#'
#' @export
generate_brand_survey_structure_template <- function(output_path,
                                                     overwrite = FALSE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(list(status = "REFUSED", code = "PKG_MISSING",
                message = "Package 'openxlsx' is required",
                how_to_fix = "install.packages('openxlsx')"))
  }

  if (file.exists(output_path) && !overwrite) {
    return(list(status = "REFUSED", code = "IO_FILE_EXISTS",
                message = sprintf("File already exists: %s", output_path),
                how_to_fix = "Set overwrite = TRUE or choose a different path"))
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  tryCatch(.ensure_template_styles(),
           error = function(e) stop(sprintf("Cannot load template styles: %s", e$message)))

  wb <- openxlsx::createWorkbook()

  # ---- SHARED: Project ----
  write_settings_sheet(
    wb, "Project",
    .build_project_settings_def(),
    title = "TURAS Survey Structure — Project Settings",
    subtitle = "Shared across brand, tabs, and tracker modules. Values here must match Brand_Config.xlsx."
  )

  # ---- SHARED: Questions (unified) ----
  write_table_sheet(
    wb, "Questions",
    .build_unified_questions_columns(),
    title = "Question Definitions  [SHARED: used by brand module AND tabs module]",
    subtitle = paste0(
      "One row per question. Brand module: follow the naming convention in the Question Naming Guide sheet — ",
      "roles are inferred automatically from question code prefixes (BRANDAWARE_, BRANDATTR_, etc.). ",
      "Tabs module: use any QuestionCode and set Variable_Type. Blue rows are examples."
    ),
    example_rows = .build_unified_questions_examples(),
    num_blank_rows = 120
  )

  # ---- SHARED: Options (unified) ----
  write_table_sheet(
    wb, "Options",
    .build_unified_options_columns(),
    title = "Response Option Definitions  [SHARED: used by brand module AND tabs module]",
    subtitle = paste0(
      "Map data codes to display labels. OptionText MUST exactly match values in the data (case-sensitive). ",
      "Brand slot-indexed questions: use the ROOT QuestionCode (e.g. BRANDAWARE_DSS), not the slot column. ",
      "Blue rows are examples."
    ),
    example_rows = .build_unified_options_examples(),
    num_blank_rows = 200
  )

  # ---- SHARED: Composite_Metrics (tabs only, brand ignores) ----
  write_table_sheet(
    wb, "Composite_Metrics",
    .build_composite_metrics_columns(),
    title = "Composite Metric Definitions  [TABS MODULE ONLY — brand module ignores this sheet]",
    subtitle = "Define composite scores that combine multiple questions. Blue rows are examples.",
    example_rows = .build_composite_metrics_examples(),
    num_blank_rows = 20
  )

  # ---- BRAND: Brands ----
  write_table_sheet(
    wb, "Brands",
    .build_brands_columns(),
    title = "Brand Definitions  [BRAND MODULE]",
    subtitle = "One row per brand per category. CategoryCode must match Brand_Config Categories. Exactly one IsFocal = Y per category. Blue rows are examples.",
    example_rows = .build_brands_examples(),
    num_blank_rows = 50
  )

  # ---- BRAND: CEPs ----
  write_table_sheet(
    wb, "CEPs",
    .build_ceps_columns(),
    title = "Category Entry Point (CEP) Definitions  [BRAND MODULE]",
    subtitle = paste0(
      "Mental availability entry points per category. 10–15 CEPs recommended. ",
      "CEPCode must match the ITEM suffix in BRANDATTR_{CAT}_{ITEM} question codes. ",
      "Write simple, concrete, situation-based statements (Romaniuk). Blue rows are examples."
    ),
    example_rows = .build_ceps_examples(),
    num_blank_rows = 60
  )

  # ---- BRAND: Attributes ----
  write_table_sheet(
    wb, "Attributes",
    .build_attributes_columns(),
    title = "Brand Image Attribute Definitions  [BRAND MODULE]",
    subtitle = paste0(
      "Non-CEP perception items per category. 5–8 attributes recommended. ",
      "AttrCode must match the ITEM suffix in BRANDATTR_{CAT}_{ITEM} question codes. ",
      "These are performance/perception items, not usage occasions. Blue rows are examples."
    ),
    example_rows = .build_attributes_examples(),
    num_blank_rows = 30
  )

  # ---- BRAND: QuestionMap (role overrides / inserts — advanced, optional) ----
  write_table_sheet(
    wb, "QuestionMap",
    .build_questionmap_columns(),
    title = "Question Role Map  [BRAND MODULE — optional overrides]",
    subtitle = paste0(
      "Advanced: override or supplement the convention-inferred role map. ",
      "Most questions do NOT need a row here — roles are inferred from naming conventions automatically. ",
      "Use QuestionMap for: (1) cat_buying.frequency — needs OptionMapScale; ",
      "(2) demographics questions that do not follow DEMO_ prefix; ",
      "(3) ad hoc questions with adhoc. role prefix. Blue rows are examples."
    ),
    example_rows = .build_questionmap_examples(),
    num_blank_rows = 30
  )

  # ---- BRAND: OptionMap (scale definitions — needed for some QuestionMap rows) ----
  write_table_sheet(
    wb, "OptionMap",
    .build_optionmap_columns(),
    title = "Option Scale Definitions  [BRAND MODULE — needed with QuestionMap OptionMapScale]",
    subtitle = paste0(
      "Define reusable response scales referenced by OptionMapScale in QuestionMap. ",
      "Each scale (cat_buy_scale, attitude_scale, etc.) appears as a block of rows. ",
      "ClientCode must exactly match values in the data. Blue rows show the standard scales."
    ),
    example_rows = .build_optionmap_examples(),
    num_blank_rows = 30
  )

  # ---- BRAND: Channels ----
  write_table_sheet(
    wb, "Channels",
    .build_channels_columns(),
    title = "Purchase Channel Definitions  [BRAND MODULE — Shopper Behaviour panel]",
    subtitle = paste0(
      "Purchase channel options for the Shopper Behaviour panel. ",
      "One row per channel per category. ChannelCode must match values in CHANNEL_{CAT} data column. ",
      "Blue rows are examples."
    ),
    example_rows = .build_channels_examples(),
    num_blank_rows = 30
  )

  # ---- BRAND: PackSizes ----
  write_table_sheet(
    wb, "PackSizes",
    .build_packsizes_columns(),
    title = "Pack Size Definitions  [BRAND MODULE — Shopper Behaviour panel]",
    subtitle = paste0(
      "Pack size options for the Shopper Behaviour panel. ",
      "One row per pack size per category. PackCode must match values in PACK_{CAT} data column. ",
      "Blue rows are examples."
    ),
    example_rows = .build_packsizes_examples(),
    num_blank_rows = 20
  )

  # ---- BRAND: MarketingReach ----
  write_table_sheet(
    wb, "MarketingReach",
    .build_marketing_reach_columns(),
    title = "Marketing Asset Definitions  [BRAND MODULE — Branded Reach panel, only if element_branded_reach = Y]",
    subtitle = paste0(
      "One row per marketing asset (ad, OOH execution, etc.) to test for recognition. ",
      "AssetCode referenced by the Branded Reach engine. Leave blank if element_branded_reach = N. ",
      "Blue rows are examples."
    ),
    example_rows = .build_marketing_reach_examples(),
    num_blank_rows = 20
  )

  # ---- BRAND: ReachMedia ----
  write_table_sheet(
    wb, "ReachMedia",
    .build_reach_media_columns(),
    title = "Reach Media Channel Definitions  [BRAND MODULE — Branded Reach panel]",
    subtitle = paste0(
      "Media channels for the Branded Reach 'Where did you see this?' question. ",
      "MediaCode must match values in the reach media attribution question in the data. ",
      "Blue rows are examples."
    ),
    example_rows = .build_reach_media_examples(),
    num_blank_rows = 10
  )

  # ---- BRAND: AudienceLens ----
  write_table_sheet(
    wb, "AudienceLens",
    .build_audience_lens_columns(),
    title = "Audience Lens Definitions  [BRAND MODULE — only if element_audience_lens = Y]",
    subtitle = paste0(
      "Define audience segments for side-by-side comparison across all brand metrics. ",
      "AudienceID referenced by AudienceLens_Use in Brand_Config Categories sheet. ",
      "Paired audiences (PairID) are shown as comparative columns. Blue rows are examples."
    ),
    example_rows = .build_audience_lens_examples(),
    num_blank_rows = 20
  )

  # ---- BRAND: DBA_Assets ----
  write_table_sheet(
    wb, "DBA_Assets",
    .build_dba_structure_columns(),
    title = "DBA Asset Definitions  [BRAND MODULE — only if element_dba = Y]",
    subtitle = paste0(
      "Maps asset codes to their Fame and Uniqueness question codes in the data. ",
      "AssetCode must match Brand_Config DBA_Assets sheet. Blue rows are examples."
    ),
    example_rows = .build_dba_structure_examples(),
    num_blank_rows = 12
  )

  # ---- REFERENCE sheets ----
  .write_variable_type_reference(wb)
  .write_naming_convention_reference(wb)

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)

  cat(sprintf("\n  [OK] Survey_Structure_Brand_Config_Template.xlsx written: %s\n",
              output_path))
  list(status = "PASS", output_path = output_path,
       message = sprintf("Unified survey structure template written to %s", output_path))
}


# ==============================================================================
# CONVENIENCE: Generate both templates at once
# ==============================================================================

#' Generate both brand templates in a directory
#'
#' @param output_dir Directory to write templates into.
#' @param overwrite Logical (default: FALSE).
#'
#' @return Invisible list of paths.
#' @export
generate_brand_templates <- function(output_dir, overwrite = FALSE) {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    cat(sprintf("  Created directory: %s\n", output_dir))
  }

  config_path    <- file.path(output_dir, "Brand_Config_Template.xlsx")
  structure_path <- file.path(output_dir,
                               "Survey_Structure_Brand_Config_Template.xlsx")

  r1 <- generate_brand_config_template(config_path, overwrite = overwrite)
  r2 <- generate_brand_survey_structure_template(structure_path,
                                                  overwrite = overwrite)

  cat("\n  ==========================================\n")
  cat("  Brand module templates generated\n")
  cat("  ==========================================\n")
  cat(sprintf("  Brand_Config_Template:              %s\n", config_path))
  cat(sprintf("  Survey_Structure_Brand_Config_Template: %s\n", structure_path))
  cat("\n  Next steps:\n")
  cat("  1. Copy templates to your project folder\n")
  cat("  2. Fill in Survey_Structure: Questions, Options, Brands, CEPs\n")
  cat("  3. Fill in Brand_Config: Settings (file paths, focal brand), Categories\n")
  cat("  4. Run: result <- run_brand('path/to/Brand_Config.xlsx')\n\n")

  invisible(list(config = config_path, structure = structure_path))
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand config template generators loaded (v%s)",
                  BRAND_CONFIG_VERSION))
}
