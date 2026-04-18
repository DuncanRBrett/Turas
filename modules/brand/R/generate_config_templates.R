# ==============================================================================
# BRAND MODULE - CONFIG TEMPLATE GENERATORS
# ==============================================================================
# Generates professional Excel config templates for the brand module:
#   1. Brand_Config.xlsx   - Analysis settings (what to run, how to run it)
#   2. Survey_Structure.xlsx - Data dictionary (what's in the data)
#
# Both files follow the established Turas config template pattern with
# branded headers, colour-coded sections, help text, dropdown validation,
# and inline documentation.
#
# USAGE:
#   source("modules/brand/R/generate_config_templates.R")
#   generate_brand_config_template("output/Brand_Config.xlsx")
#   generate_brand_survey_structure_template("output/Survey_Structure.xlsx")
#
# DEPENDENCIES:
#   - openxlsx
#   - modules/shared/template_styles.R
# ==============================================================================

BRAND_CONFIG_VERSION <- "1.0"

# --- Source shared template infrastructure ---
.find_shared_template_styles <- function() {
  candidates <- character(0)

  if (exists("find_turas_root", mode = "function")) {
    candidates <- c(candidates,
      file.path(find_turas_root(), "modules", "shared", "template_styles.R"))
  }

  if (!is.null(tryCatch(sys.frame(1)$ofile, error = function(e) NULL))) {
    this_dir <- dirname(sys.frame(1)$ofile)
    candidates <- c(candidates,
      file.path(this_dir, "..", "..", "shared", "template_styles.R"))
  }

  candidates <- c(candidates, "modules/shared/template_styles.R")

  for (path in candidates) {
    path <- normalizePath(path, mustWork = FALSE)
    if (file.exists(path)) return(path)
  }

  stop("Cannot find shared/template_styles.R. Source it manually or set TURAS_ROOT.")
}


# ==============================================================================
# BRAND_CONFIG.XLSX - SETTINGS DEFINITIONS
# ==============================================================================

.build_brand_settings_def <- function() {
  list(
    # --- STUDY ---
    list(
      section_name = "STUDY IDENTIFICATION",
      fields = list(
        list(
          name = "project_name",
          required = TRUE,
          default = "",
          description = "[REQUIRED] Project name for report titles and file naming",
          valid_values_text = "Free text"
        ),
        list(
          name = "client_name",
          required = TRUE,
          default = "",
          description = "[REQUIRED] Client organisation name",
          valid_values_text = "Free text"
        ),
        list(
          name = "study_type",
          required = TRUE,
          default = "cross-sectional",
          description = "[REQUIRED] Study design. Panel studies include respondent ID for longitudinal tracking",
          valid_values_text = "cross-sectional, panel",
          dropdown = c("cross-sectional", "panel")
        ),
        list(
          name = "wave",
          required = TRUE,
          default = 1,
          description = "[REQUIRED] Wave number. Wave 1 = baseline; wave 2+ enables tracker integration",
          valid_values_text = "Integer >= 1",
          integer_range = c(1, 100)
        ),
        list(
          name = "data_file",
          required = TRUE,
          default = "",
          description = "[REQUIRED] Path to survey data file, relative to project root",
          valid_values_text = ".csv or .xlsx"
        ),
        list(
          name = "respondent_id_col",
          required = FALSE,
          default = "Respondent_ID",
          description = "[Optional] Column name for respondent ID. Required for panel studies",
          valid_values_text = "Column name in data file"
        ),
        list(
          name = "weight_variable",
          required = FALSE,
          default = "",
          description = "[Optional] Column name for survey weight variable. Leave blank for unweighted",
          valid_values_text = "Column name in data file"
        ),
        list(
          name = "focal_brand",
          required = TRUE,
          default = "",
          description = "[REQUIRED] The client's brand. Controls colour highlighting, annotations, and focal-brand comparisons",
          valid_values_text = "Brand code from Brands sheet in Survey_Structure.xlsx"
        )
      )
    ),

    # --- ROUTING ---
    list(
      section_name = "MULTI-CATEGORY ROUTING",
      fields = list(
        list(
          name = "focal_assignment",
          required = TRUE,
          default = "balanced",
          description = "[REQUIRED] How respondents are assigned to their focal category. 'balanced' = random equal split; 'quota' = minimum n per category; 'priority' = weighted over-sampling",
          valid_values_text = "balanced, quota, priority",
          dropdown = c("balanced", "quota", "priority")
        ),
        list(
          name = "focal_category_col",
          required = FALSE,
          default = "",
          description = "[Optional] Column in data file containing pre-assigned focal category. If blank, derives from config",
          valid_values_text = "Column name in data file"
        ),
        list(
          name = "cross_category_awareness",
          required = FALSE,
          default = "Y",
          description = "[Optional] Collect brand awareness for all qualified categories (not just focal). Required for Portfolio element",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "cross_category_pen_light",
          required = FALSE,
          default = "Y",
          description = "[Optional] Collect light brand penetration for non-focal categories. Required for Portfolio element",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        )
      )
    ),

    # --- ELEMENTS ---
    list(
      section_name = "ANALYTICAL ELEMENTS (Y = include, N = exclude)",
      fields = list(
        list(
          name = "element_funnel",
          required = FALSE,
          default = "Y",
          description = "[Optional] Brand funnel: awareness > disposition > bought > primary. Derived from core CBM data",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "element_mental_avail",
          required = FALSE,
          default = "Y",
          description = "[Optional] Mental Availability: MMS, MPen, NS, CEP x brand matrix. The analytical centrepiece",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "element_cep_turf",
          required = FALSE,
          default = "Y",
          description = "[Optional] CEP TURF reach optimisation within Mental Availability. Which CEP combination maximises mental reach?",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "element_repertoire",
          required = FALSE,
          default = "Y",
          description = "[Optional] Repertoire analysis: multi-brand buying, share of requirements, switching patterns",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "element_drivers_barriers",
          required = FALSE,
          default = "Y",
          description = "[Optional] Drivers & Barriers: derived importance x performance, rejection themes. Optional catdriver integration",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "element_dba",
          required = FALSE,
          default = "N",
          description = "[Optional] Distinctive Brand Assets: Fame x Uniqueness grid. Requires DBA battery in survey (+2 min)",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "element_portfolio",
          required = FALSE,
          default = "Y",
          description = "[Optional] Portfolio analysis: cross-category map, priority quadrants, category TURF. Requires 2+ categories",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "element_wom",
          required = FALSE,
          default = "Y",
          description = "[Optional] Word-of-Mouth: received/shared x positive/negative balance. Requires WOM battery (+2 min)",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        )
      )
    ),

    # --- DRIVERS & BARRIERS ---
    list(
      section_name = "DRIVERS & BARRIERS OPTIONS",
      fields = list(
        list(
          name = "db_use_catdriver",
          required = FALSE,
          default = "Y",
          description = "[Optional] Use catdriver module for derived importance (SHAP values). More rigorous than simple buyer/non-buyer differential",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "db_importance_method",
          required = FALSE,
          default = "differential",
          description = "[Optional] Importance derivation method when catdriver is not used",
          valid_values_text = "differential (buyer vs non-buyer gap)",
          dropdown = c("differential")
        )
      )
    ),

    # --- DBA ---
    list(
      section_name = "DBA OPTIONS (only if element_dba = Y)",
      fields = list(
        list(
          name = "dba_scope",
          required = FALSE,
          default = "brand",
          description = "[Optional] DBA measurement scope. 'brand' = brand-level (default); 'category' = per-category (rare)",
          valid_values_text = "brand, category",
          dropdown = c("brand", "category")
        ),
        list(
          name = "dba_fame_threshold",
          required = FALSE,
          default = 0.50,
          description = "[Optional] Fame threshold for DBA quadrant classification. Default 50%",
          valid_values_text = "0.00 to 1.00",
          numeric_range = c(0, 1)
        ),
        list(
          name = "dba_uniqueness_threshold",
          required = FALSE,
          default = 0.50,
          description = "[Optional] Uniqueness threshold for DBA quadrant classification. Default 50%",
          valid_values_text = "0.00 to 1.00",
          numeric_range = c(0, 1)
        ),
        list(
          name = "dba_attribution_type",
          required = FALSE,
          default = "open",
          description = "[Optional] DBA attribution question type. 'open' = open-ended text (recommended, coded post-fieldwork); 'closed_list' = forced-choice brand list (inflates uniqueness)",
          valid_values_text = "open, closed_list",
          dropdown = c("open", "closed_list")
        )
      )
    ),

    # --- WOM ---
    list(
      section_name = "WOM OPTIONS (only if element_wom = Y)",
      fields = list(
        list(
          name = "wom_timeframe",
          required = FALSE,
          default = "3 months",
          description = "[Optional] WOM recall timeframe. Should match category target timeframe",
          valid_values_text = "Free text (e.g., '3 months', '6 months')"
        )
      )
    ),

    # --- SIGNIFICANCE TESTING ---
    list(
      section_name = "SIGNIFICANCE TESTING",
      fields = list(
        list(
          name = "alpha",
          required = FALSE,
          default = 0.05,
          description = "[Optional] Primary significance level for cross-brand comparisons",
          valid_values_text = "0.01 to 0.20",
          numeric_range = c(0.01, 0.20)
        ),
        list(
          name = "alpha_secondary",
          required = FALSE,
          default = "",
          description = "[Optional] Secondary significance level for dual-alpha display (e.g. 0.10). Leave blank to disable",
          valid_values_text = "0.01 to 0.20 or blank",
          numeric_range = c(0.01, 0.20)
        ),
        list(
          name = "min_base_size",
          required = FALSE,
          default = 30,
          description = "[Optional] Minimum base size for reporting. Cells below this are suppressed",
          valid_values_text = "Integer >= 10",
          integer_range = c(10, 500)
        ),
        list(
          name = "low_base_warning",
          required = FALSE,
          default = 75,
          description = "[Optional] Base size below which a low-base warning is shown. Per Romaniuk: n<75 is shaky for per-brand metrics",
          valid_values_text = "Integer >= 30",
          integer_range = c(30, 500)
        )
      )
    ),

    # --- COLOUR ---
    list(
      section_name = "COLOUR PALETTE",
      fields = list(
        list(
          name = "colour_focal",
          required = FALSE,
          default = "#1A5276",
          description = "[Optional] Primary colour for focal brand in charts. Saturated. Should be brand primary colour",
          valid_values_text = "Hex colour (e.g. #1A5276)"
        ),
        list(
          name = "colour_focal_accent",
          required = FALSE,
          default = "#2E86C1",
          description = "[Optional] Accent colour for focal brand secondary elements",
          valid_values_text = "Hex colour"
        ),
        list(
          name = "colour_competitor",
          required = FALSE,
          default = "#B0B0B0",
          description = "[Optional] Desaturated colour for competitor brands. Grey by default (design principle 3)",
          valid_values_text = "Hex colour"
        ),
        list(
          name = "colour_category_avg",
          required = FALSE,
          default = "#808080",
          description = "[Optional] Colour for category average reference lines. Mid-grey, dashed",
          valid_values_text = "Hex colour"
        )
      )
    ),

    # --- OUTPUT ---
    list(
      section_name = "OUTPUT OPTIONS",
      fields = list(
        list(
          name = "output_dir",
          required = TRUE,
          default = "output/brand",
          description = "[REQUIRED] Output directory, relative to project root. Created if it does not exist",
          valid_values_text = "Relative path"
        ),
        list(
          name = "output_html",
          required = FALSE,
          default = "Y",
          description = "[Optional] Generate HTML report via report_hub",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "output_excel",
          required = FALSE,
          default = "Y",
          description = "[Optional] Generate Excel workbook with all element data",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "output_csv",
          required = FALSE,
          default = "Y",
          description = "[Optional] Generate CSV files (long-format) per element",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "tracker_ids",
          required = FALSE,
          default = "Y",
          description = "[Optional] Include stable metric IDs for wave-over-wave tracking. Required for tracker module integration",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        )
      )
    ),

    # --- REPORT ---
    list(
      section_name = "REPORT OPTIONS",
      fields = list(
        list(
          name = "report_title",
          required = FALSE,
          default = "Brand Health Report",
          description = "[Optional] Title displayed in HTML report header",
          valid_values_text = "Free text"
        ),
        list(
          name = "report_subtitle",
          required = FALSE,
          default = "",
          description = "[Optional] Subtitle (e.g. 'Wave 1 Baseline', 'Q1 2026')",
          valid_values_text = "Free text"
        ),
        list(
          name = "show_about_section",
          required = FALSE,
          default = "Y",
          description = "[Optional] Include About & Methodology section with academic references (Romaniuk, Sharp, EBI)",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "structure_file",
          required = TRUE,
          default = "",
          description = "[REQUIRED] Path to Survey_Structure.xlsx, relative to project root",
          valid_values_text = "Relative path to .xlsx file"
        )
      )
    )
  )
}


# ==============================================================================
# BRAND_CONFIG.XLSX - TABLE SHEET DEFINITIONS
# ==============================================================================

.build_categories_columns <- function() {
  list(
    list(name = "Category", width = 28, required = TRUE,
         description = "Category name as it appears in the data and report"),
    list(name = "Type", width = 18, required = TRUE,
         description = "Category type. Controls question wording and penetration structure",
         dropdown = c("transaction", "durable", "service")),
    list(name = "Timeframe_Long", width = 18, required = TRUE,
         description = "Longer timeframe for penetration (e.g. '12 months'). TRANS only"),
    list(name = "Timeframe_Target", width = 18, required = TRUE,
         description = "Target analytical period (e.g. '3 months'). Used in all time-bound metrics"),
    list(name = "Focal_Weight", width = 14, required = FALSE,
         description = "Assignment weight for 'priority' routing. Must sum to 1.0 across categories. Ignored if focal_assignment = 'balanced'",
         numeric_range = c(0, 1))
  )
}

.build_categories_examples <- function() {
  list(
    list(Category = "Frozen Vegetables", Type = "transaction",
         Timeframe_Long = "12 months", Timeframe_Target = "3 months",
         Focal_Weight = 0.25),
    list(Category = "Ready Meals", Type = "transaction",
         Timeframe_Long = "12 months", Timeframe_Target = "3 months",
         Focal_Weight = 0.25),
    list(Category = "Sauces", Type = "transaction",
         Timeframe_Long = "12 months", Timeframe_Target = "3 months",
         Focal_Weight = 0.25)
  )
}

.build_dba_assets_columns <- function() {
  list(
    list(name = "AssetCode", width = 16, required = TRUE,
         description = "Unique code for this asset (e.g. LOGO, COLOUR, TAGLINE)"),
    list(name = "AssetLabel", width = 24, required = TRUE,
         description = "Display label for charts and tables"),
    list(name = "AssetType", width = 14, required = TRUE,
         description = "Type of stimulus shown to respondents",
         dropdown = c("image", "text", "audio")),
    list(name = "FilePath", width = 40, required = FALSE,
         description = "Path to asset file (image/audio). Relative to project root. Not needed for 'text' type")
  )
}

.build_dba_assets_examples <- function() {
  list(
    list(AssetCode = "LOGO", AssetLabel = "Brand Logo",
         AssetType = "image", FilePath = "assets/logo_unbranded.png"),
    list(AssetCode = "COLOUR", AssetLabel = "Primary Colour",
         AssetType = "image", FilePath = "assets/colour_swatch.png"),
    list(AssetCode = "TAGLINE", AssetLabel = "Tagline",
         AssetType = "text", FilePath = "")
  )
}


# ==============================================================================
# SURVEY_STRUCTURE.XLSX - TABLE SHEET DEFINITIONS
# ==============================================================================

.build_project_settings_def <- function() {
  list(
    list(
      section_name = "PROJECT",
      fields = list(
        list(name = "project_name", required = TRUE, default = "",
             description = "[REQUIRED] Project name (must match Brand_Config.xlsx)",
             valid_values_text = "Free text"),
        list(name = "data_file", required = TRUE, default = "",
             description = "[REQUIRED] Path to data file (must match Brand_Config.xlsx)",
             valid_values_text = ".csv or .xlsx"),
        list(name = "client_name", required = TRUE, default = "",
             description = "[REQUIRED] Client organisation name",
             valid_values_text = "Free text"),
        list(name = "focal_brand", required = TRUE, default = "",
             description = "[REQUIRED] Focal brand code (must match Brands sheet)",
             valid_values_text = "Brand code")
      )
    )
  )
}

.build_questions_columns <- function() {
  list(
    list(name = "QuestionCode", width = 24, required = TRUE,
         description = "Unique question code matching column prefix in data file"),
    list(name = "QuestionText", width = 50, required = TRUE,
         description = "Full question wording for reference"),
    list(name = "VariableType", width = 18, required = TRUE,
         description = "Data type: how responses are coded in the data",
         dropdown = c("Multi_Mention", "Single_Mention", "Rating", "Open_End", "Numeric")),
    list(name = "Battery", width = 18, required = TRUE,
         description = "CBM battery this question belongs to",
         dropdown = c("awareness", "cep_matrix", "attribute", "attitude",
                      "attitude_oe", "cat_buying", "penetration", "wom", "dba")),
    list(name = "Category", width = 22, required = TRUE,
         description = "Category this question applies to. Use 'ALL' for brand-level questions (WOM, DBA)")
  )
}

.build_questions_examples <- function() {
  list(
    list(QuestionCode = "BRANDAWARE_FV",
         QuestionText = "Which brands have you heard of?",
         VariableType = "Multi_Mention", Battery = "awareness",
         Category = "Frozen Vegetables"),
    list(QuestionCode = "BRANDATTR_FV_01",
         QuestionText = "Good for a quick weeknight meal",
         VariableType = "Multi_Mention", Battery = "cep_matrix",
         Category = "Frozen Vegetables"),
    list(QuestionCode = "BRANDATTR_FV_16",
         QuestionText = "Good value for money",
         VariableType = "Multi_Mention", Battery = "attribute",
         Category = "Frozen Vegetables"),
    list(QuestionCode = "BRANDATT1_FV",
         QuestionText = "Brand attitude",
         VariableType = "Single_Mention", Battery = "attitude",
         Category = "Frozen Vegetables"),
    list(QuestionCode = "WOM_POS_REC",
         QuestionText = "Received positive WOM",
         VariableType = "Multi_Mention", Battery = "wom",
         Category = "ALL")
  )
}

.build_options_columns <- function() {
  list(
    list(name = "QuestionCode", width = 24, required = TRUE,
         description = "Question code this option belongs to (must match Questions sheet)"),
    list(name = "OptionText", width = 14, required = TRUE,
         description = "Value as coded in the data (e.g. 1, 2, 3)"),
    list(name = "DisplayText", width = 50, required = TRUE,
         description = "Human-readable label for output (e.g. 'I love it / it is my favourite')"),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order for display in charts and tables",
         integer_range = c(1, 100)),
    list(name = "ShowInOutput", width = 14, required = FALSE,
         description = "Include in output? Y/N. Use N to suppress (e.g. 'Not applicable')",
         dropdown = c("Y", "N"))
  )
}

.build_options_examples <- function() {
  list(
    list(QuestionCode = "BRANDATT1_FV", OptionText = "1",
         DisplayText = "I love it / it's my favourite",
         DisplayOrder = 1, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_FV", OptionText = "2",
         DisplayText = "It's among the ones I prefer",
         DisplayOrder = 2, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_FV", OptionText = "3",
         DisplayText = "I wouldn't usually consider it, but I would if no other option",
         DisplayOrder = 3, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_FV", OptionText = "4",
         DisplayText = "I would refuse to buy this brand",
         DisplayOrder = 4, ShowInOutput = "Y"),
    list(QuestionCode = "BRANDATT1_FV", OptionText = "5",
         DisplayText = "I have no opinion about this brand",
         DisplayOrder = 5, ShowInOutput = "Y")
  )
}

.build_brands_columns <- function() {
  list(
    list(name = "Category", width = 24, required = TRUE,
         description = "Category this brand belongs to (must match Categories sheet in Brand_Config)"),
    list(name = "BrandCode", width = 18, required = TRUE,
         description = "Unique brand code matching column names/values in data file"),
    list(name = "BrandLabel", width = 24, required = TRUE,
         description = "Display label for charts and tables"),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order within category",
         integer_range = c(1, 100)),
    list(name = "IsFocal", width = 12, required = TRUE,
         description = "Is this the focal (client) brand? Exactly one per category should be Y",
         dropdown = c("Y", "N")),
    list(name = "Colour", width = 14, required = FALSE,
         description = "Optional hex colour (#RRGGBB) for this brand in all charts and chips. Leave blank to use defaults.")
  )
}

.build_brands_examples <- function() {
  list(
    list(Category = "Frozen Vegetables", BrandCode = "IPK",
         BrandLabel = "IPK", DisplayOrder = 1, IsFocal = "Y",
         Colour = "#1A5276"),
    list(Category = "Frozen Vegetables", BrandCode = "MCCAIN",
         BrandLabel = "McCain", DisplayOrder = 2, IsFocal = "N",
         Colour = ""),
    list(Category = "Frozen Vegetables", BrandCode = "FINDUS",
         BrandLabel = "Findus", DisplayOrder = 3, IsFocal = "N",
         Colour = ""),
    list(Category = "Ready Meals", BrandCode = "IPK",
         BrandLabel = "IPK", DisplayOrder = 1, IsFocal = "Y",
         Colour = "#1A5276"),
    list(Category = "Ready Meals", BrandCode = "COMPA",
         BrandLabel = "Competitor A", DisplayOrder = 2, IsFocal = "N",
         Colour = "")
  )
}

.build_ceps_columns <- function() {
  list(
    list(name = "Category", width = 24, required = TRUE,
         description = "Category this CEP belongs to"),
    list(name = "CEPCode", width = 14, required = TRUE,
         description = "Unique CEP code within category (e.g. CEP01, CEP02)"),
    list(name = "CEPText", width = 50, required = TRUE,
         description = "Full CEP statement text. Should be simple, concrete, situation-based (Romaniuk)"),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order for output",
         integer_range = c(1, 50))
  )
}

.build_ceps_examples <- function() {
  list(
    list(Category = "Frozen Vegetables", CEPCode = "CEP01",
         CEPText = "Good for a quick weeknight meal", DisplayOrder = 1),
    list(Category = "Frozen Vegetables", CEPCode = "CEP02",
         CEPText = "Something the whole family enjoys", DisplayOrder = 2),
    list(Category = "Frozen Vegetables", CEPCode = "CEP03",
         CEPText = "When I want a healthy option", DisplayOrder = 3)
  )
}

.build_attributes_columns <- function() {
  list(
    list(name = "Category", width = 24, required = TRUE,
         description = "Category this attribute belongs to"),
    list(name = "AttrCode", width = 14, required = TRUE,
         description = "Unique attribute code within category (e.g. ATTR01)"),
    list(name = "AttrText", width = 50, required = TRUE,
         description = "Full attribute statement text. These are perception items, not CEPs"),
    list(name = "DisplayOrder", width = 14, required = TRUE,
         description = "Sort order for output",
         integer_range = c(1, 50))
  )
}

.build_attributes_examples <- function() {
  list(
    list(Category = "Frozen Vegetables", AttrCode = "ATTR01",
         AttrText = "Good value for money", DisplayOrder = 1),
    list(Category = "Frozen Vegetables", AttrCode = "ATTR02",
         AttrText = "High quality ingredients", DisplayOrder = 2)
  )
}

.build_dba_structure_columns <- function() {
  list(
    list(name = "AssetCode", width = 16, required = TRUE,
         description = "Unique asset code (must match DBA_Assets sheet in Brand_Config)"),
    list(name = "AssetLabel", width = 24, required = TRUE,
         description = "Display label"),
    list(name = "AssetType", width = 14, required = TRUE,
         description = "Stimulus type",
         dropdown = c("image", "text", "audio")),
    list(name = "FameQuestionCode", width = 24, required = TRUE,
         description = "Question code for fame (recognition) question in data"),
    list(name = "UniqueQuestionCode", width = 24, required = TRUE,
         description = "Question code for uniqueness (attribution) question in data")
  )
}

.build_dba_structure_examples <- function() {
  list(
    list(AssetCode = "LOGO", AssetLabel = "Brand Logo",
         AssetType = "image",
         FameQuestionCode = "DBA_FAME_LOGO",
         UniqueQuestionCode = "DBA_UNIQUE_LOGO"),
    list(AssetCode = "COLOUR", AssetLabel = "Primary Colour",
         AssetType = "image",
         FameQuestionCode = "DBA_FAME_COLOUR",
         UniqueQuestionCode = "DBA_UNIQUE_COLOUR")
  )
}


# ==============================================================================
# MAIN GENERATOR: Brand_Config.xlsx
# ==============================================================================

#' Generate Brand_Config.xlsx template
#'
#' Creates a professional, documented Excel configuration template for the
#' brand module. Includes Settings sheet (analysis parameters), Categories
#' sheet (per-category settings), and DBA_Assets sheet (if DBA is enabled).
#'
#' The generated template includes:
#' - Branded headers and colour-coded sections
#' - Help text for every setting
#' - Dropdown validation on option fields
#' - Example data rows
#' - Inline documentation sufficient for an operator to configure without
#'   external documentation
#'
#' @param output_path Character. Path for the output Excel file.
#' @param overwrite Logical. Overwrite if file exists (default: FALSE).
#'
#' @return List with status = "PASS" and output_path, or a TRS refusal.
#'
#' @examples
#' \dontrun{
#'   generate_brand_config_template("output/Brand_Config.xlsx")
#' }
#'
#' @export
generate_brand_config_template <- function(output_path, overwrite = FALSE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING",
      message = "Package 'openxlsx' is required for template generation",
      how_to_fix = "Install with: install.packages('openxlsx')"
    ))
  }

  if (file.exists(output_path) && !overwrite) {
    return(list(
      status = "REFUSED",
      code = "IO_FILE_EXISTS",
      message = sprintf("File already exists: %s", output_path),
      how_to_fix = "Set overwrite = TRUE or choose a different path"
    ))
  }

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Source shared styles
  tryCatch({
    if (!exists("write_settings_sheet", mode = "function")) {
      source(.find_shared_template_styles())
    }
  }, error = function(e) {
    stop(sprintf("Cannot load template styles: %s", e$message))
  })

  wb <- openxlsx::createWorkbook()

  # Sheet 1: Settings
  write_settings_sheet(
    wb, "Settings",
    .build_brand_settings_def(),
    title = "TURAS Brand Module - Configuration",
    subtitle = "Edit the Value column only. See Description and Valid Values for guidance."
  )

  # Sheet 2: Categories
  write_table_sheet(
    wb, "Categories",
    .build_categories_columns(),
    title = "Category Definitions",
    subtitle = "One row per category in the study. Replace example rows with your categories.",
    example_rows = .build_categories_examples(),
    num_blank_rows = 10
  )

  # Sheet 3: DBA_Assets
  write_table_sheet(
    wb, "DBA_Assets",
    .build_dba_assets_columns(),
    title = "DBA Asset Definitions (only if element_dba = Y)",
    subtitle = "One row per brand asset to test. Replace examples with your assets.",
    example_rows = .build_dba_assets_examples(),
    num_blank_rows = 15
  )

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)

  cat(sprintf("\n  Brand_Config.xlsx generated: %s\n", output_path))

  list(
    status = "PASS",
    output_path = output_path,
    message = sprintf("Brand config template generated at %s", output_path)
  )
}


# ==============================================================================
# MAIN GENERATOR: Survey_Structure.xlsx (brand extension)
# ==============================================================================

#' Generate Survey_Structure.xlsx template for brand module
#'
#' Creates the data dictionary Excel template that maps survey questions
#' to CBM batteries, defines brands/CEPs/attributes per category, and
#' provides the shared structure consumed by brand, tabs, and tracker modules.
#'
#' @param output_path Character. Path for the output Excel file.
#' @param overwrite Logical. Overwrite if file exists (default: FALSE).
#'
#' @return List with status = "PASS" and output_path, or a TRS refusal.
#'
#' @examples
#' \dontrun{
#'   generate_brand_survey_structure_template("output/Survey_Structure.xlsx")
#' }
#'
#' @export
generate_brand_survey_structure_template <- function(output_path,
                                                     overwrite = FALSE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING",
      message = "Package 'openxlsx' is required for template generation",
      how_to_fix = "Install with: install.packages('openxlsx')"
    ))
  }

  if (file.exists(output_path) && !overwrite) {
    return(list(
      status = "REFUSED",
      code = "IO_FILE_EXISTS",
      message = sprintf("File already exists: %s", output_path),
      how_to_fix = "Set overwrite = TRUE or choose a different path"
    ))
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  tryCatch({
    if (!exists("write_settings_sheet", mode = "function")) {
      source(.find_shared_template_styles())
    }
  }, error = function(e) {
    stop(sprintf("Cannot load template styles: %s", e$message))
  })

  wb <- openxlsx::createWorkbook()

  # Sheet 1: Project
  write_settings_sheet(
    wb, "Project",
    .build_project_settings_def(),
    title = "TURAS Survey Structure - Project Settings",
    subtitle = "Shared across brand, tabs, and tracker modules. Values must match Brand_Config.xlsx."
  )

  # Sheet 2: Questions
  write_table_sheet(
    wb, "Questions",
    .build_questions_columns(),
    title = "Question Definitions",
    subtitle = "Map every survey question to its CBM battery and category. Replace examples with your questions.",
    example_rows = .build_questions_examples(),
    num_blank_rows = 80
  )

  # Sheet 3: Options
  write_table_sheet(
    wb, "Options",
    .build_options_columns(),
    title = "Response Option Definitions",
    subtitle = "Map data codes to display labels for categorical questions. Replace examples.",
    example_rows = .build_options_examples(),
    num_blank_rows = 80
  )

  # Sheet 4: Brands
  write_table_sheet(
    wb, "Brands",
    .build_brands_columns(),
    title = "Brand Definitions",
    subtitle = "One row per brand per category. The focal brand must have IsFocal = Y (exactly one per category).",
    example_rows = .build_brands_examples(),
    num_blank_rows = 40
  )

  # Sheet 5: CEPs
  write_table_sheet(
    wb, "CEPs",
    .build_ceps_columns(),
    title = "Category Entry Point Definitions",
    subtitle = "CEP statements per category. 10-15 CEPs recommended. Simple, concrete, situation-based wording (Romaniuk).",
    example_rows = .build_ceps_examples(),
    num_blank_rows = 40
  )

  # Sheet 6: Attributes
  write_table_sheet(
    wb, "Attributes",
    .build_attributes_columns(),
    title = "Brand Image Attribute Definitions",
    subtitle = "Non-CEP attribute statements per category. 5-7 recommended. Perception items, not entry points.",
    example_rows = .build_attributes_examples(),
    num_blank_rows = 20
  )

  # Sheet 7: DBA_Assets
  write_table_sheet(
    wb, "DBA_Assets",
    .build_dba_structure_columns(),
    title = "DBA Asset Definitions (only if element_dba = Y in Brand_Config)",
    subtitle = "Maps asset codes to fame and uniqueness question codes in the data.",
    example_rows = .build_dba_structure_examples(),
    num_blank_rows = 15
  )

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)

  cat(sprintf("\n  Survey_Structure.xlsx generated: %s\n", output_path))

  list(
    status = "PASS",
    output_path = output_path,
    message = sprintf("Survey structure template generated at %s", output_path)
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand config template generators loaded (v%s)",
                  BRAND_CONFIG_VERSION))
}
