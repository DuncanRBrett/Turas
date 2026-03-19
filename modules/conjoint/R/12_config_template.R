# ==============================================================================
# CONJOINT CONFIG TEMPLATE GENERATOR
# ==============================================================================
#
# Module: Conjoint Analysis - Configuration Template
# Purpose: Generate branded, formatted Excel config templates
# Version: 3.1.0
# Date: 2026-03-19
#
# Generates a professional Excel configuration template with:
#   - Branded styling consistent with Turas platform (tabs benchmark)
#   - 5-column layout: Setting | Value | Required? | Description | Valid Values
#   - Dropdown validation for option fields
#   - Numeric validation for numeric fields
#   - Section grouping with colour-coded headers
#   - Help text and descriptions for every setting
#   - Custom_Slides and Custom_Images sheets for HTML features
#   - Gridlines disabled for professional appearance
#   - Frozen panes for navigation
#
# ==============================================================================


# ==============================================================================
# BRAND COLOUR PALETTE (Turas Platform Standard)
# ==============================================================================

.TPL_NAVY      <- "#323367"
.TPL_GOLD      <- "#CC9900"
.TPL_WHITE     <- "#FFFFFF"
.TPL_LIGHT_BG  <- "#F8F9FA"
.TPL_SECTION   <- "#E8EAF6"
.TPL_REQUIRED  <- "#FFF3E0"
.TPL_OPTIONAL  <- "#F1F8E9"
.TPL_INPUT     <- "#FFFDE7"
.TPL_LOCKED    <- "#ECEFF1"
.TPL_HEADER_FG <- "#FFFFFF"
.TPL_BORDER    <- "#B0BEC5"
.TPL_RED       <- "#D32F2F"
.TPL_GREEN     <- "#388E3C"
.TPL_HELP_FG   <- "#546E7A"
.TPL_EXAMPLE   <- "#E3F2FD"


# ==============================================================================
# STYLE FACTORY FUNCTIONS
# ==============================================================================

.make_tpl_header_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 11, fontColour = .TPL_HEADER_FG,
    fgFill = .TPL_NAVY, halign = "left", valign = "center",
    textDecoration = "bold", border = "TopBottomLeftRight",
    borderColour = .TPL_NAVY, wrapText = TRUE
  )
}

.make_tpl_section_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 11, fontColour = .TPL_NAVY,
    fgFill = .TPL_SECTION, halign = "left", valign = "center",
    textDecoration = "bold", border = "TopBottomLeftRight",
    borderColour = .TPL_BORDER
  )
}

.make_tpl_required_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = .TPL_REQUIRED, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER
  )
}

.make_tpl_optional_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = .TPL_OPTIONAL, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER
  )
}

.make_tpl_input_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = .TPL_INPUT, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER
  )
}

.make_tpl_help_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 9, fontColour = .TPL_HELP_FG,
    fgFill = .TPL_LIGHT_BG, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
    wrapText = TRUE, textDecoration = "italic"
  )
}

.make_tpl_locked_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 9, fontColour = .TPL_HELP_FG,
    fgFill = .TPL_LOCKED, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
    wrapText = TRUE
  )
}

.make_tpl_title_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 14, fontColour = .TPL_NAVY,
    textDecoration = "bold", halign = "left", valign = "center"
  )
}

.make_tpl_subtitle_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 10, fontColour = .TPL_HELP_FG,
    halign = "left", valign = "center", textDecoration = "italic"
  )
}

.make_tpl_required_label_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 10, fontColour = .TPL_RED,
    textDecoration = "bold", halign = "center", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
    fgFill = .TPL_REQUIRED
  )
}

.make_tpl_optional_label_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 10, fontColour = .TPL_GREEN,
    halign = "center", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
    fgFill = .TPL_OPTIONAL
  )
}

.make_tpl_example_style <- function() {
  openxlsx::createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = .TPL_EXAMPLE, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER
  )
}


# ==============================================================================
# SETTINGS DEFINITION
# ==============================================================================

.get_conjoint_settings_definition <- function() {

  settings <- data.frame(
    section = character(), setting = character(), default = character(),
    description = character(), required = logical(), options = character(),
    valid_values = character(),
    stringsAsFactors = FALSE
  )

  add <- function(sec, set, def, desc, req = FALSE, opts = "", valid = "") {
    settings[nrow(settings) + 1, ] <<- list(sec, set, def, desc, req, opts, valid)
  }

  # --- FILE PATHS & OUTPUT ---
  add("FILE PATHS & OUTPUT", "data_file", "", "Path to data file (CSV, XLSX, SAV, DTA). Relative to config directory.", TRUE, "", "File path ending in .csv, .xlsx, .sav, or .dta")
  add("FILE PATHS & OUTPUT", "output_file", "conjoint_results.xlsx", "Output Excel file path. Relative to config directory.", FALSE, "", "File path ending in .xlsx")
  add("FILE PATHS & OUTPUT", "data_source", "generic", "Data source format", FALSE, "generic,alchemer", "generic or alchemer")
  add("FILE PATHS & OUTPUT", "analysis_type", "choice", "Analysis type: choice-based (CBC) or rating-based", TRUE, "choice,rating", "choice or rating")
  add("FILE PATHS & OUTPUT", "choice_type", "single", "Choice task type", FALSE, "single,single_with_none,best_worst", "single, single_with_none, or best_worst")

  # --- COLUMN MAPPING ---
  add("COLUMN MAPPING", "respondent_id_column", "resp_id", "Column name for respondent identifier", FALSE, "", "Column name (case-sensitive)")
  add("COLUMN MAPPING", "choice_set_column", "choice_set_id", "Column name for choice set identifier", FALSE, "", "Column name (case-sensitive)")
  add("COLUMN MAPPING", "chosen_column", "chosen", "Column name for chosen indicator (0/1)", FALSE, "", "Column name (case-sensitive)")
  add("COLUMN MAPPING", "alternative_id_column", "alternative_id", "Column name for alternative identifier", FALSE, "", "Column name (case-sensitive)")
  add("COLUMN MAPPING", "rating_variable", "", "Column name for rating scores (rating-based only)", FALSE, "", "Column name (case-sensitive)")

  # --- ESTIMATION METHOD ---
  add("ESTIMATION METHOD", "estimation_method", "auto", "Primary estimation method", TRUE, "auto,mlogit,clogit,hb,latent_class,best_worst", "auto, mlogit, clogit, hb, latent_class, best_worst")
  add("ESTIMATION METHOD", "confidence_level", "0.95", "Confidence level for intervals", FALSE, "", "Decimal between 0.80 and 0.99")
  add("ESTIMATION METHOD", "zero_center_utilities", "TRUE", "Zero-center utilities within each attribute", FALSE, "TRUE,FALSE", "TRUE or FALSE")
  add("ESTIMATION METHOD", "base_level_method", "first", "Which level serves as baseline (utility = 0)", FALSE, "first,last", "first or last")

  # --- HIERARCHICAL BAYES SETTINGS ---
  add("HIERARCHICAL BAYES SETTINGS", "hb_iterations", "10000", "Total MCMC iterations (recommend 10000-50000)", FALSE, "", "Integer >= 1000")
  add("HIERARCHICAL BAYES SETTINGS", "hb_burnin", "5000", "Burn-in iterations to discard (must be < hb_iterations)", FALSE, "", "Integer >= 0, < hb_iterations")
  add("HIERARCHICAL BAYES SETTINGS", "hb_thin", "1", "Thinning interval (1 = keep all draws, 2 = every other)", FALSE, "", "Integer >= 1")
  add("HIERARCHICAL BAYES SETTINGS", "hb_ncomp", "1", "Number of mixture components (1 for standard HB)", FALSE, "", "Integer >= 1")
  add("HIERARCHICAL BAYES SETTINGS", "hb_prior_variance", "2", "Prior variance for beta coefficients", FALSE, "", "Positive number (default 2)")

  # --- LATENT CLASS SETTINGS ---
  add("LATENT CLASS SETTINGS", "latent_class_min", "2", "Minimum number of classes to test", FALSE, "", "Integer >= 2")
  add("LATENT CLASS SETTINGS", "latent_class_max", "5", "Maximum number of classes to test", FALSE, "", "Integer >= latent_class_min")
  add("LATENT CLASS SETTINGS", "latent_class_criterion", "bic", "Information criterion for optimal class selection", FALSE, "bic,aic", "bic or aic")

  # --- INTERACTIONS ---
  add("INTERACTIONS", "interaction_terms", "", "Comma-separated interaction pairs (e.g. Brand:Price, Size:Colour)", FALSE, "", "Format: Attr1:Attr2, Attr3:Attr4")
  add("INTERACTIONS", "auto_detect_interactions", "FALSE", "Automatically detect significant interactions", FALSE, "TRUE,FALSE", "TRUE or FALSE")

  # --- WILLINGNESS TO PAY ---
  add("WILLINGNESS TO PAY", "wtp_price_attribute", "", "Name of the price attribute (leave blank to skip WTP)", FALSE, "", "Attribute name from Attributes sheet")
  add("WILLINGNESS TO PAY", "wtp_method", "marginal", "WTP calculation method", FALSE, "marginal,simulation", "marginal or simulation")
  add("WILLINGNESS TO PAY", "currency_symbol", "$", "Currency symbol for WTP display (e.g. $, R, EUR, GBP)", FALSE, "", "Any currency symbol or abbreviation")

  # --- MARKET SIMULATOR ---
  add("MARKET SIMULATOR", "generate_market_simulator", "TRUE", "Generate interactive Excel market simulator sheet", FALSE, "TRUE,FALSE", "TRUE or FALSE")
  add("MARKET SIMULATOR", "simulation_method", "logit", "Market share prediction method", FALSE, "logit,first_choice,rfc", "logit, first_choice, or rfc")
  add("MARKET SIMULATOR", "rfc_draws", "1000", "Number of random draws for RFC simulation", FALSE, "", "Integer >= 100")

  # --- HTML REPORT ---
  add("HTML REPORT", "generate_html_report", "FALSE", "Generate interactive HTML analysis report", FALSE, "TRUE,FALSE", "TRUE or FALSE")
  add("HTML REPORT", "generate_html_simulator", "FALSE", "Generate standalone HTML market simulator", FALSE, "TRUE,FALSE", "TRUE or FALSE")
  add("HTML REPORT", "brand_colour", "#323367", "Primary brand hex colour for HTML output", FALSE, "", "Hex colour (e.g. #323367)")
  add("HTML REPORT", "accent_colour", "#CC9900", "Accent hex colour for HTML output", FALSE, "", "Hex colour (e.g. #CC9900)")
  add("HTML REPORT", "project_name", "Conjoint Analysis", "Project name displayed in report header", FALSE, "", "Free text")
  add("HTML REPORT", "client_name", "", "Client name displayed in header and About page", FALSE, "", "Free text")
  add("HTML REPORT", "company_name", "The Research LampPost", "Company name for report header", FALSE, "", "Free text")

  # --- HTML REPORT INSIGHTS ---
  add("HTML REPORT INSIGHTS", "insight_overview", "", "Pre-populated insight text for Overview tab", FALSE, "", "Free text or markdown")
  add("HTML REPORT INSIGHTS", "insight_utilities", "", "Pre-populated insight text for Utilities tab", FALSE, "", "Free text or markdown")
  add("HTML REPORT INSIGHTS", "insight_diagnostics", "", "Pre-populated insight text for Diagnostics tab", FALSE, "", "Free text or markdown")
  add("HTML REPORT INSIGHTS", "insight_simulator", "", "Pre-populated insight text for Simulator tab", FALSE, "", "Free text or markdown")
  add("HTML REPORT INSIGHTS", "insight_wtp", "", "Pre-populated insight text for WTP tab", FALSE, "", "Free text or markdown")

  # --- REVENUE SIMULATOR ---
  add("REVENUE SIMULATOR", "default_customers", "1000", "Default hypothetical customer count for revenue simulation", FALSE, "", "Positive integer (e.g. 1000, 5000, 10000)")

  # --- CUSTOM CONTENT ---
  add("CUSTOM CONTENT", "include_custom_slides", "FALSE", "Include custom slides in HTML report (see Custom_Slides sheet)", FALSE, "TRUE,FALSE", "TRUE or FALSE")
  add("CUSTOM CONTENT", "include_custom_images", "FALSE", "Include custom images in HTML report (see Custom_Images sheet)", FALSE, "TRUE,FALSE", "TRUE or FALSE")

  # --- ANALYST & ABOUT ---
  add("ANALYST & ABOUT", "analyst_name", "", "Analyst name for About page", FALSE, "", "Free text")
  add("ANALYST & ABOUT", "analyst_email", "", "Analyst email for About page", FALSE, "", "Email address")
  add("ANALYST & ABOUT", "analyst_phone", "", "Analyst phone for About page", FALSE, "", "Phone number")
  add("ANALYST & ABOUT", "closing_notes", "", "Closing notes (editable in HTML report)", FALSE, "", "Free text")
  add("ANALYST & ABOUT", "researcher_logo_base64", "", "Base64-encoded logo image for report header", FALSE, "", "Base64 string")

  # --- NONE OPTION ---
  add("NONE OPTION", "none_as_baseline", "FALSE", "Use None option as baseline in estimation", FALSE, "TRUE,FALSE", "TRUE or FALSE")
  add("NONE OPTION", "none_label", "None", "Label for the None/no-choice option", FALSE, "", "Free text")

  # --- OPTIMIZER ---
  add("OPTIMIZER", "optimizer_method", "exhaustive", "Product optimization search method", FALSE, "exhaustive,greedy", "exhaustive or greedy")
  add("OPTIMIZER", "optimizer_max_products", "5", "Maximum products in optimizer scenarios", FALSE, "", "Integer 1-12")

  # --- ALCHEMER IMPORT ---
  add("ALCHEMER IMPORT", "clean_alchemer_levels", "TRUE", "Auto-clean Alchemer level names", FALSE, "TRUE,FALSE", "TRUE or FALSE")
  add("ALCHEMER IMPORT", "alchemer_response_id_column", "ResponseID", "Alchemer response ID column", FALSE, "", "Column name")
  add("ALCHEMER IMPORT", "alchemer_set_number_column", "SetNumber", "Alchemer set number column", FALSE, "", "Column name")
  add("ALCHEMER IMPORT", "alchemer_card_number_column", "CardNumber", "Alchemer card number column", FALSE, "", "Column name")
  add("ALCHEMER IMPORT", "alchemer_score_column", "Score", "Alchemer score column", FALSE, "", "Column name")

  settings
}


# ==============================================================================
# TEMPLATE GENERATOR
# ==============================================================================

#' Generate Conjoint Configuration Template
#'
#' Creates a branded, formatted Excel configuration template matching the
#' Turas platform standard (tabs module benchmark). Features 5-column layout,
#' colour-coded sections, dropdown validation, and help text for every setting.
#'
#' @param output_path Path for the output Excel template file
#' @param include_examples Logical, include example attribute data (default TRUE)
#' @param method_template Optional preset: "standard_cbc", "cbc_hb", "cbc_latent_class", "best_worst"
#' @param verbose Logical, print progress (default TRUE)
#' @return Invisible path to created file
#'
#' @examples
#' \dontrun{
#'   generate_conjoint_config_template("my_conjoint_config.xlsx")
#'   generate_conjoint_config_template("hb_config.xlsx", method_template = "cbc_hb")
#' }
#'
#' @export
generate_conjoint_config_template <- function(output_path = "Conjoint_Config_Template.xlsx",
                                               include_examples = TRUE,
                                               method_template = NULL,
                                               verbose = TRUE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    conjoint_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'openxlsx' is required to generate config templates.",
      why_it_matters = "Template generation requires openxlsx for creating formatted Excel files.",
      how_to_fix = "Install: install.packages('openxlsx')"
    )
  }

  if (verbose) cat("Generating conjoint configuration template...\n")

  wb <- openxlsx::createWorkbook()

  # Styles
  title_style    <- .make_tpl_title_style()
  subtitle_style <- .make_tpl_subtitle_style()
  header_style   <- .make_tpl_header_style()
  section_style  <- .make_tpl_section_style()
  req_style      <- .make_tpl_required_style()
  opt_style      <- .make_tpl_optional_style()
  input_style    <- .make_tpl_input_style()
  help_style     <- .make_tpl_help_style()
  locked_style   <- .make_tpl_locked_style()
  req_label      <- .make_tpl_required_label_style()
  opt_label      <- .make_tpl_optional_label_style()
  example_style  <- .make_tpl_example_style()

  # =========================================================================
  # SETTINGS SHEET (5-column layout matching tabs benchmark)
  # =========================================================================

  openxlsx::addWorksheet(wb, "Settings", gridLines = FALSE)

  # Row 1: Title (merged across all 5 columns)
  openxlsx::writeData(wb, "Settings", "TURAS Conjoint Analysis Configuration", startRow = 1, startCol = 1)
  openxlsx::mergeCells(wb, "Settings", cols = 1:5, rows = 1)
  openxlsx::addStyle(wb, "Settings", title_style, rows = 1, cols = 1)

  # Row 2: Subtitle
  openxlsx::writeData(wb, "Settings", "Generated by Turas Analytics Platform v3.1. Edit values in the Value column only.", startRow = 2, startCol = 1)
  openxlsx::mergeCells(wb, "Settings", cols = 1:5, rows = 2)
  openxlsx::addStyle(wb, "Settings", subtitle_style, rows = 2, cols = 1)

  # Row 3: Legend
  legend_data <- data.frame(
    a = "Colour Legend:",
    b = "Required",
    c = "Optional",
    d = "User Input",
    e = "Read-Only"
  )
  openxlsx::writeData(wb, "Settings", legend_data, startRow = 3, colNames = FALSE)
  openxlsx::addStyle(wb, "Settings", openxlsx::createStyle(fontName = "Calibri", fontSize = 9, textDecoration = "bold"), rows = 3, cols = 1)
  openxlsx::addStyle(wb, "Settings", req_label, rows = 3, cols = 2)
  openxlsx::addStyle(wb, "Settings", opt_label, rows = 3, cols = 3)
  openxlsx::addStyle(wb, "Settings", input_style, rows = 3, cols = 4)
  openxlsx::addStyle(wb, "Settings", locked_style, rows = 3, cols = 5)

  # Row 4: Empty spacer
  # Row 5: Header row
  header_row <- 5
  headers <- data.frame(
    Setting = "Setting",
    Value = "Value",
    Required = "Required?",
    Description = "Description",
    Valid_Values = "Valid Values / Notes"
  )
  openxlsx::writeData(wb, "Settings", headers, startRow = header_row, colNames = FALSE)
  openxlsx::addStyle(wb, "Settings", header_style, rows = header_row, cols = 1:5, gridExpand = TRUE)

  # Get settings definition
  settings_def <- .get_conjoint_settings_definition()

  # Apply method template overrides
  if (!is.null(method_template)) {
    overrides <- .get_method_template_overrides(method_template)
    for (setting_name in names(overrides)) {
      idx <- which(settings_def$setting == setting_name)
      if (length(idx) == 1) {
        settings_def$default[idx] <- overrides[[setting_name]]
      }
    }
    if (verbose) cat(sprintf("  Applied method template: %s\n", method_template))
  }

  current_row <- header_row + 1
  current_section <- ""

  for (i in seq_len(nrow(settings_def))) {
    s <- settings_def[i, ]

    # Section header (merged across all 5 columns)
    if (s$section != current_section) {
      current_section <- s$section
      openxlsx::writeData(wb, "Settings",
                           data.frame(a = current_section, b = NA, c = NA, d = NA, e = NA),
                           startRow = current_row, colNames = FALSE)
      openxlsx::addStyle(wb, "Settings", section_style, rows = current_row, cols = 1:5, gridExpand = TRUE)
      openxlsx::mergeCells(wb, "Settings", cols = 1:5, rows = current_row)
      current_row <- current_row + 1
    }

    # Setting row (5 columns)
    row_style <- if (s$required) req_style else opt_style
    req_text <- if (s$required) "REQUIRED" else "Optional"

    openxlsx::writeData(wb, "Settings",
                         data.frame(a = s$setting, b = s$default, c = req_text, d = s$description, e = s$valid_values),
                         startRow = current_row, colNames = FALSE)

    # Col 1: Setting name (colour-coded by required/optional)
    openxlsx::addStyle(wb, "Settings", row_style, rows = current_row, cols = 1)
    # Col 2: Value (bright yellow input)
    openxlsx::addStyle(wb, "Settings", input_style, rows = current_row, cols = 2)
    # Col 3: Required label (bold red / green)
    if (s$required) {
      openxlsx::addStyle(wb, "Settings", req_label, rows = current_row, cols = 3)
    } else {
      openxlsx::addStyle(wb, "Settings", opt_label, rows = current_row, cols = 3)
    }
    # Col 4: Description (help style)
    openxlsx::addStyle(wb, "Settings", help_style, rows = current_row, cols = 4)
    # Col 5: Valid values (locked/read-only)
    openxlsx::addStyle(wb, "Settings", locked_style, rows = current_row, cols = 5)

    # Add dropdown validation for option fields
    if (nchar(s$options) > 0) {
      opts <- trimws(strsplit(s$options, ",")[[1]])
      openxlsx::dataValidation(
        wb, "Settings",
        col = 2, rows = current_row,
        type = "list",
        value = paste0('"', paste(opts, collapse = ","), '"'),
        allowBlank = !s$required,
        showInputMsg = TRUE,
        showErrorMsg = TRUE
      )
    }

    # Add numeric validation for specific fields
    if (s$setting == "confidence_level") {
      openxlsx::dataValidation(wb, "Settings", col = 2, rows = current_row,
                                type = "decimal", operator = "between",
                                value = c(0.80, 0.99), allowBlank = TRUE,
                                showInputMsg = TRUE, showErrorMsg = TRUE)
    } else if (s$setting %in% c("hb_iterations", "hb_burnin")) {
      openxlsx::dataValidation(wb, "Settings", col = 2, rows = current_row,
                                type = "whole", operator = "greaterThanOrEqual",
                                value = 0, allowBlank = TRUE,
                                showInputMsg = TRUE, showErrorMsg = TRUE)
    }

    current_row <- current_row + 1
  }

  # Column widths (matching tabs benchmark)
  openxlsx::setColWidths(wb, "Settings", cols = 1, widths = 38)
  openxlsx::setColWidths(wb, "Settings", cols = 2, widths = 28)
  openxlsx::setColWidths(wb, "Settings", cols = 3, widths = 12)
  openxlsx::setColWidths(wb, "Settings", cols = 4, widths = 55)
  openxlsx::setColWidths(wb, "Settings", cols = 5, widths = 35)

  # Freeze pane at header row
  openxlsx::freezePane(wb, "Settings", firstRow = FALSE, firstCol = FALSE,
                        firstActiveRow = header_row + 1)


  # =========================================================================
  # ATTRIBUTES SHEET
  # =========================================================================

  openxlsx::addWorksheet(wb, "Attributes", gridLines = FALSE)

  # Title
  openxlsx::writeData(wb, "Attributes", "Conjoint Attribute Definitions", startRow = 1, startCol = 1)
  openxlsx::mergeCells(wb, "Attributes", cols = 1:3, rows = 1)
  openxlsx::addStyle(wb, "Attributes", title_style, rows = 1, cols = 1)

  # Subtitle
  openxlsx::writeData(wb, "Attributes", "Define each attribute and its levels. Separate level names with commas.", startRow = 2, startCol = 1)
  openxlsx::mergeCells(wb, "Attributes", cols = 1:3, rows = 2)
  openxlsx::addStyle(wb, "Attributes", subtitle_style, rows = 2, cols = 1)

  # Row 3: Help row
  help_row_data <- data.frame(
    a = "[REQUIRED] Attribute display name",
    b = "[REQUIRED] Number of levels",
    c = "[REQUIRED] Comma-separated level names (order matters: first = baseline)"
  )
  openxlsx::writeData(wb, "Attributes", help_row_data, startRow = 3, colNames = FALSE)
  openxlsx::addStyle(wb, "Attributes", help_style, rows = 3, cols = 1:3, gridExpand = TRUE)
  openxlsx::setRowHeights(wb, "Attributes", rows = 3, heights = 35)

  # Header at row 4
  attr_header <- data.frame(
    AttributeName = "AttributeName",
    NumLevels = "NumLevels",
    LevelNames = "LevelNames"
  )
  openxlsx::writeData(wb, "Attributes", attr_header, startRow = 4, colNames = FALSE)
  openxlsx::addStyle(wb, "Attributes", header_style, rows = 4, cols = 1:3, gridExpand = TRUE)

  # Example data rows (light blue background)
  if (include_examples) {
    examples <- data.frame(
      AttributeName = c("Brand", "Price", "Screen Size", "Battery Life", "Camera Quality"),
      NumLevels = c(4, 4, 3, 3, 3),
      LevelNames = c(
        "Apple, Samsung, Google, OnePlus",
        "$299, $399, $499, $599",
        "5.5 inch, 6.1 inch, 6.7 inch",
        "12 hours, 18 hours, 24 hours",
        "Basic, Good, Excellent"
      ),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Attributes", examples, startRow = 5, colNames = FALSE)

    for (r in 5:(5 + nrow(examples) - 1)) {
      openxlsx::addStyle(wb, "Attributes", example_style, rows = r, cols = 1:3, gridExpand = TRUE)
    }

    # Blank input rows after examples
    for (r in (5 + nrow(examples)):(5 + nrow(examples) + 9)) {
      openxlsx::addStyle(wb, "Attributes", input_style, rows = r, cols = 1:3, gridExpand = TRUE)
    }
  }

  openxlsx::setColWidths(wb, "Attributes", cols = 1, widths = 25)
  openxlsx::setColWidths(wb, "Attributes", cols = 2, widths = 12)
  openxlsx::setColWidths(wb, "Attributes", cols = 3, widths = 55)
  openxlsx::freezePane(wb, "Attributes", firstRow = FALSE, firstCol = FALSE,
                        firstActiveRow = 5)


  # =========================================================================
  # CUSTOM_SLIDES SHEET
  # =========================================================================

  openxlsx::addWorksheet(wb, "Custom_Slides", gridLines = FALSE)

  openxlsx::writeData(wb, "Custom_Slides", "Custom Slides for HTML Report", startRow = 1, startCol = 1)
  openxlsx::mergeCells(wb, "Custom_Slides", cols = 1:4, rows = 1)
  openxlsx::addStyle(wb, "Custom_Slides", title_style, rows = 1, cols = 1)

  openxlsx::writeData(wb, "Custom_Slides",
                       "Add custom slides that appear in the HTML report Slides panel. Content supports Markdown formatting.",
                       startRow = 2, startCol = 1)
  openxlsx::mergeCells(wb, "Custom_Slides", cols = 1:4, rows = 2)
  openxlsx::addStyle(wb, "Custom_Slides", subtitle_style, rows = 2, cols = 1)

  slides_header <- data.frame(
    a = "Slide Title", b = "Content (Markdown)", c = "Image Path (Optional)", d = "Position"
  )
  openxlsx::writeData(wb, "Custom_Slides", slides_header, startRow = 4, colNames = FALSE)
  openxlsx::addStyle(wb, "Custom_Slides", header_style, rows = 4, cols = 1:4, gridExpand = TRUE)

  # Example slide
  if (include_examples) {
    openxlsx::writeData(wb, "Custom_Slides",
                         data.frame(a = "Executive Summary", b = "## Key Findings\n- Brand is the primary driver\n- Price sensitivity is moderate", c = "", d = "1"),
                         startRow = 5, colNames = FALSE)
    openxlsx::addStyle(wb, "Custom_Slides", example_style, rows = 5, cols = 1:4, gridExpand = TRUE)
  }

  # Blank rows
  for (r in 6:15) {
    openxlsx::addStyle(wb, "Custom_Slides", input_style, rows = r, cols = 1:4, gridExpand = TRUE)
  }

  openxlsx::setColWidths(wb, "Custom_Slides", cols = 1, widths = 25)
  openxlsx::setColWidths(wb, "Custom_Slides", cols = 2, widths = 60)
  openxlsx::setColWidths(wb, "Custom_Slides", cols = 3, widths = 30)
  openxlsx::setColWidths(wb, "Custom_Slides", cols = 4, widths = 10)


  # =========================================================================
  # CUSTOM_IMAGES SHEET
  # =========================================================================

  openxlsx::addWorksheet(wb, "Custom_Images", gridLines = FALSE)

  openxlsx::writeData(wb, "Custom_Images", "Custom Images for HTML Report", startRow = 1, startCol = 1)
  openxlsx::mergeCells(wb, "Custom_Images", cols = 1:4, rows = 1)
  openxlsx::addStyle(wb, "Custom_Images", title_style, rows = 1, cols = 1)

  openxlsx::writeData(wb, "Custom_Images",
                       "Add images to embed in the HTML report. Images are base64-encoded for self-contained output.",
                       startRow = 2, startCol = 1)
  openxlsx::mergeCells(wb, "Custom_Images", cols = 1:4, rows = 2)
  openxlsx::addStyle(wb, "Custom_Images", subtitle_style, rows = 2, cols = 1)

  images_header <- data.frame(
    a = "Image Path", b = "Caption", c = "Panel Placement", d = "Position"
  )
  openxlsx::writeData(wb, "Custom_Images", images_header, startRow = 4, colNames = FALSE)
  openxlsx::addStyle(wb, "Custom_Images", header_style, rows = 4, cols = 1:4, gridExpand = TRUE)

  # Help row
  images_help <- data.frame(
    a = "[REQUIRED] Path to image file (PNG, JPG)",
    b = "[Optional] Caption below image",
    c = "[Optional] overview, utilities, diagnostics, about",
    d = "[Optional] Display order (1, 2, 3...)"
  )
  openxlsx::writeData(wb, "Custom_Images", images_help, startRow = 5, colNames = FALSE)
  openxlsx::addStyle(wb, "Custom_Images", help_style, rows = 5, cols = 1:4, gridExpand = TRUE)

  # Blank rows
  for (r in 6:15) {
    openxlsx::addStyle(wb, "Custom_Images", input_style, rows = r, cols = 1:4, gridExpand = TRUE)
  }

  # Panel placement dropdown
  for (r in 6:15) {
    openxlsx::dataValidation(wb, "Custom_Images", col = 3, rows = r,
                              type = "list",
                              value = '"overview,utilities,diagnostics,simulator,wtp,about"',
                              allowBlank = TRUE, showInputMsg = TRUE, showErrorMsg = TRUE)
  }

  openxlsx::setColWidths(wb, "Custom_Images", cols = 1, widths = 35)
  openxlsx::setColWidths(wb, "Custom_Images", cols = 2, widths = 35)
  openxlsx::setColWidths(wb, "Custom_Images", cols = 3, widths = 20)
  openxlsx::setColWidths(wb, "Custom_Images", cols = 4, widths = 10)


  # =========================================================================
  # DESIGN SHEET (optional placeholder)
  # =========================================================================

  openxlsx::addWorksheet(wb, "Design", gridLines = FALSE)

  openxlsx::writeData(wb, "Design", "Experimental Design Matrix (Optional)", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "Design", title_style, rows = 1, cols = 1)
  openxlsx::writeData(wb, "Design",
                       "If you have a pre-defined experimental design, paste it here. Otherwise leave blank — Turas will infer the design from your data.",
                       startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, "Design", subtitle_style, rows = 2, cols = 1)


  # =========================================================================
  # INSTRUCTIONS SHEET
  # =========================================================================

  openxlsx::addWorksheet(wb, "Instructions", gridLines = FALSE)

  instructions <- c(
    "TURAS Conjoint Analysis — Configuration Guide",
    "",
    "QUICK START",
    "1. Fill in the Settings sheet — required fields are marked in orange",
    "2. Define your attributes in the Attributes sheet",
    "3. Set data_file to point to your CBC data file",
    "4. Run the analysis using run_conjoint_analysis(config_file = 'this_file.xlsx')",
    "",
    "ESTIMATION METHODS",
    "auto     — Tries mlogit first, falls back to clogit (recommended for most studies)",
    "mlogit   — Multinomial logit via the mlogit package (industry standard)",
    "clogit   — Conditional logit via survival::clogit (robust fallback)",
    "hb       — Hierarchical Bayes for individual-level utilities (requires bayesm)",
    "latent_class — Discover preference-based segments (requires bayesm)",
    "best_worst   — Best-worst scaling / MaxDiff estimation",
    "",
    "DATA FORMAT",
    "Your data should be in long format with one row per alternative per choice set:",
    "  resp_id | choice_set_id | alternative_id | Brand | Price | Size | chosen",
    "  1       | 1             | 1              | Apple | $299  | 6.1  | 0",
    "  1       | 1             | 2              | Samsung | $399 | 5.5 | 1",
    "  1       | 1             | 3              | Google | $499  | 6.7 | 0",
    "",
    "CUSTOM CONTENT",
    "Use the Custom_Slides and Custom_Images sheets to add content to the HTML report.",
    "Slides support Markdown formatting. Images are base64-encoded for portability.",
    "",
    "SUPPORT",
    "For help, see docs/USER_MANUAL.md or contact your analyst."
  )

  for (i in seq_along(instructions)) {
    openxlsx::writeData(wb, "Instructions", instructions[i], startRow = i, startCol = 1)
    if (i == 1) {
      openxlsx::addStyle(wb, "Instructions", title_style, rows = i, cols = 1)
    } else if (instructions[i] %in% c("QUICK START", "ESTIMATION METHODS", "DATA FORMAT", "CUSTOM CONTENT", "SUPPORT")) {
      openxlsx::addStyle(wb, "Instructions", openxlsx::createStyle(
        fontName = "Calibri", fontSize = 11, fontColour = .TPL_NAVY, textDecoration = "bold"
      ), rows = i, cols = 1)
    }
  }
  openxlsx::setColWidths(wb, "Instructions", cols = 1, widths = 80)


  # =========================================================================
  # SAVE
  # =========================================================================

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  if (verbose) {
    cat(sprintf("  ✓ Template saved to: %s\n", output_path))
    cat("  Sheets: Settings, Attributes, Custom_Slides, Custom_Images, Design, Instructions\n")
  }

  invisible(output_path)
}


# ==============================================================================
# METHOD TEMPLATE PRESETS
# ==============================================================================

.get_method_template_overrides <- function(template) {

  templates <- list(
    standard_cbc = list(
      analysis_type = "choice",
      choice_type = "single",
      estimation_method = "auto",
      generate_html_report = "TRUE",
      simulation_method = "logit"
    ),
    cbc_hb = list(
      analysis_type = "choice",
      choice_type = "single",
      estimation_method = "hb",
      hb_iterations = "20000",
      hb_burnin = "10000",
      hb_thin = "1",
      hb_ncomp = "1",
      generate_html_report = "TRUE",
      simulation_method = "logit"
    ),
    cbc_latent_class = list(
      analysis_type = "choice",
      choice_type = "single",
      estimation_method = "latent_class",
      latent_class_min = "2",
      latent_class_max = "6",
      latent_class_criterion = "bic",
      generate_html_report = "TRUE",
      simulation_method = "logit"
    ),
    best_worst = list(
      analysis_type = "choice",
      choice_type = "best_worst",
      estimation_method = "auto",
      generate_html_report = "TRUE",
      simulation_method = "logit"
    )
  )

  template <- tolower(trimws(template))
  if (!template %in% names(templates)) {
    message(sprintf("[TRS INFO] CONJ_TEMPLATE: Unknown method template '%s'. Available: %s",
                    template, paste(names(templates), collapse = ", ")))
    return(list())
  }

  templates[[template]]
}
