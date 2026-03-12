# ==============================================================================
# CONJOINT CONFIG TEMPLATE GENERATOR
# ==============================================================================
#
# Module: Conjoint Analysis - Configuration Template
# Purpose: Generate branded, formatted Excel config templates
# Version: 3.0.0
# Date: 2026-03-09
#
# Generates a professional Excel configuration template with:
#   - Branded styling consistent with Turas platform
#   - Dropdown validation for option fields
#   - Help text and descriptions for every setting
#   - Section grouping for easy navigation
#   - Support for all Phase 3 features (HB, LC, WTP, HTML)
#
# ==============================================================================


# ==============================================================================
# BRAND COLOUR PALETTE (Consistent with Turas platform)
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


# ==============================================================================
# SETTINGS DEFINITION
# ==============================================================================

#' Get All Conjoint Config Settings
#'
#' Returns a data frame defining all settings with their defaults,
#' descriptions, sections, and whether they are required.
#'
#' @return Data frame with columns: section, setting, default, description, required, options
#' @keywords internal
.get_conjoint_settings_definition <- function() {

  settings <- data.frame(
    section = character(),
    setting = character(),
    default = character(),
    description = character(),
    required = logical(),
    options = character(),   # comma-separated options for dropdowns, or "" for free text
    stringsAsFactors = FALSE
  )

  add <- function(sec, set, def, desc, req = FALSE, opts = "") {
    settings[nrow(settings) + 1, ] <<- list(sec, set, def, desc, req, opts)
  }

  # --- DATA & FORMAT ---
  add("DATA & FORMAT", "data_file", "", "Path to data file (CSV, XLSX, SAV, DTA). Relative to config directory.", TRUE)
  add("DATA & FORMAT", "output_file", "conjoint_results.xlsx", "Output Excel file path. Relative to config directory.", FALSE)
  add("DATA & FORMAT", "data_source", "generic", "Data source format", FALSE, "generic,alchemer")
  add("DATA & FORMAT", "analysis_type", "choice", "Analysis type", TRUE, "choice,rating")
  add("DATA & FORMAT", "choice_type", "single", "Choice task type", FALSE, "single,single_with_none,best_worst")

  # --- COLUMN MAPPING ---
  add("COLUMN MAPPING", "respondent_id_column", "resp_id", "Column name for respondent identifier", FALSE)
  add("COLUMN MAPPING", "choice_set_column", "choice_set_id", "Column name for choice set identifier", FALSE)
  add("COLUMN MAPPING", "chosen_column", "chosen", "Column name for chosen indicator (0/1)", FALSE)
  add("COLUMN MAPPING", "alternative_id_column", "alternative_id", "Column name for alternative identifier", FALSE)

  # --- ESTIMATION ---
  add("ESTIMATION", "estimation_method", "auto", "Estimation method", TRUE, "auto,mlogit,clogit,hb,latent_class")
  add("ESTIMATION", "confidence_level", "0.95", "Confidence level for intervals (0.80-0.99)", FALSE)
  add("ESTIMATION", "baseline_handling", "first_level_zero", "How to handle baseline level", FALSE, "first_level_zero,all_levels_explicit")
  add("ESTIMATION", "base_level_method", "first", "Coding method for base level", FALSE, "first,last,effects")
  add("ESTIMATION", "zero_center_utilities", "TRUE", "Zero-center utilities within each attribute", FALSE, "TRUE,FALSE")

  # --- HIERARCHICAL BAYES ---
  add("HIERARCHICAL BAYES", "hb_iterations", "10000", "Total MCMC iterations (recommend 10000+)", FALSE)
  add("HIERARCHICAL BAYES", "hb_burnin", "5000", "Burn-in iterations to discard (must be < hb_iterations)", FALSE)
  add("HIERARCHICAL BAYES", "hb_thin", "1", "Thinning interval (1 = keep all draws)", FALSE)
  add("HIERARCHICAL BAYES", "hb_ncomp", "1", "Number of mixture components (1 for standard HB)", FALSE)
  add("HIERARCHICAL BAYES", "hb_prior_variance", "2", "Prior variance for coefficients", FALSE)

  # --- LATENT CLASS ---
  add("LATENT CLASS", "latent_class_min", "2", "Minimum number of classes to test", FALSE)
  add("LATENT CLASS", "latent_class_max", "5", "Maximum number of classes to test", FALSE)
  add("LATENT CLASS", "latent_class_criterion", "bic", "Criterion for optimal class selection", FALSE, "bic,aic")

  # --- SIMULATION ---
  add("SIMULATION", "simulation_method", "logit", "Market share prediction method", FALSE, "logit,first_choice,rfc")
  add("SIMULATION", "rfc_draws", "1000", "Number of random draws for RFC simulation", FALSE)

  # --- WILLINGNESS TO PAY ---
  add("WILLINGNESS TO PAY", "wtp_price_attribute", "", "Name of the price attribute (leave blank to skip WTP)", FALSE)
  add("WILLINGNESS TO PAY", "wtp_method", "marginal", "WTP calculation method", FALSE, "marginal,simulation,sos")

  # --- OUTPUT ---
  add("OUTPUT", "generate_market_simulator", "TRUE", "Generate interactive Excel market simulator sheet", FALSE, "TRUE,FALSE")
  add("OUTPUT", "include_diagnostics", "TRUE", "Include model diagnostics in output", FALSE, "TRUE,FALSE")
  add("OUTPUT", "generate_html_report", "FALSE", "Generate HTML analysis report", FALSE, "TRUE,FALSE")
  add("OUTPUT", "generate_html_simulator", "FALSE", "Generate standalone HTML market simulator", FALSE, "TRUE,FALSE")

  # --- BRANDING ---
  add("BRANDING", "project_name", "Conjoint Analysis", "Project name displayed in report header", FALSE)
  add("BRANDING", "brand_colour", "#323367", "Primary brand hex colour for HTML output (e.g. #1e40af)", FALSE)
  add("BRANDING", "accent_colour", "#CC9900", "Accent hex colour for HTML output (e.g. #f59e0b)", FALSE)

  # --- HTML REPORT INSIGHTS ---
  add("HTML REPORT", "insight_overview", "", "Pre-populated insight text for Overview tab", FALSE)
  add("HTML REPORT", "insight_utilities", "", "Pre-populated insight text for Utilities tab", FALSE)
  add("HTML REPORT", "insight_diagnostics", "", "Pre-populated insight text for Diagnostics tab", FALSE)
  add("HTML REPORT", "insight_simulator", "", "Pre-populated insight text for Simulator tab", FALSE)
  add("HTML REPORT", "insight_wtp", "", "Pre-populated insight text for WTP tab", FALSE)

  # --- ABOUT PAGE ---
  add("ABOUT PAGE", "analyst_name", "", "Analyst name for About page", FALSE)
  add("ABOUT PAGE", "analyst_email", "", "Analyst email for About page", FALSE)
  add("ABOUT PAGE", "analyst_phone", "", "Analyst phone for About page", FALSE)
  add("ABOUT PAGE", "client_name", "", "Client name displayed in header and About page", FALSE)
  add("ABOUT PAGE", "company_name", "The Research LampPost", "Company name for header", FALSE)
  add("ABOUT PAGE", "closing_notes", "", "Closing notes (editable in HTML report)", FALSE)
  add("ABOUT PAGE", "researcher_logo_base64", "", "Base64-encoded logo for report header", FALSE)

  # --- NONE OPTION ---
  add("NONE OPTION", "none_as_baseline", "FALSE", "Use None option as baseline", FALSE, "TRUE,FALSE")
  add("NONE OPTION", "none_label", "None", "Label for the None/no-choice option", FALSE)

  # --- OPTIMIZER ---
  add("OPTIMIZER", "optimizer_method", "exhaustive", "Product optimization search method", FALSE, "exhaustive,genetic")
  add("OPTIMIZER", "optimizer_max_products", "5", "Maximum products in optimizer scenarios", FALSE)

  # --- ALCHEMER ---
  add("ALCHEMER", "clean_alchemer_levels", "TRUE", "Auto-clean Alchemer level names", FALSE, "TRUE,FALSE")
  add("ALCHEMER", "alchemer_response_id_column", "ResponseID", "Alchemer response ID column", FALSE)
  add("ALCHEMER", "alchemer_set_number_column", "SetNumber", "Alchemer set number column", FALSE)
  add("ALCHEMER", "alchemer_card_number_column", "CardNumber", "Alchemer card number column", FALSE)
  add("ALCHEMER", "alchemer_score_column", "Score", "Alchemer score column", FALSE)

  settings
}


# ==============================================================================
# TEMPLATE GENERATOR
# ==============================================================================

#' Generate Conjoint Configuration Template
#'
#' Creates a branded, formatted Excel configuration template with
#' dropdown validation, help text, and section grouping. Supports
#' all conjoint analysis features including HB, latent class, WTP,
#' and HTML output.
#'
#' @param output_path Path for the output Excel template file
#' @param include_examples Logical, include example attribute data (default TRUE)
#' @param verbose Logical, print progress (default TRUE)
#' @return Invisible path to created file
#'
#' @examples
#' \dontrun{
#'   generate_conjoint_config_template("my_conjoint_config.xlsx")
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
  title_style   <- .make_tpl_title_style()
  subtitle_style <- .make_tpl_subtitle_style()
  header_style  <- .make_tpl_header_style()
  section_style <- .make_tpl_section_style()
  req_style     <- .make_tpl_required_style()
  opt_style     <- .make_tpl_optional_style()
  input_style   <- .make_tpl_input_style()
  help_style    <- .make_tpl_help_style()

  # =========================================================================
  # SETTINGS SHEET
  # =========================================================================

  openxlsx::addWorksheet(wb, "Settings")

  # Title rows
  openxlsx::writeData(wb, "Settings", "TURAS Conjoint Analysis Configuration", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "Settings", title_style, rows = 1, cols = 1)
  openxlsx::writeData(wb, "Settings", "Generated by Turas Analytics Platform. Edit values in the Value column.", startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, "Settings", subtitle_style, rows = 2, cols = 1)

  # Header row at row 4
  header_row <- 4
  openxlsx::writeData(wb, "Settings",
                       data.frame(Setting = "Setting", Value = "Value", Description = "Description"),
                       startRow = header_row, colNames = FALSE)
  openxlsx::addStyle(wb, "Settings", header_style, rows = header_row, cols = 1:3, gridExpand = TRUE)

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

    # Section header
    if (s$section != current_section) {
      current_section <- s$section
      openxlsx::writeData(wb, "Settings",
                           data.frame(a = current_section, b = NA, c = NA),
                           startRow = current_row, colNames = FALSE)
      openxlsx::addStyle(wb, "Settings", section_style, rows = current_row, cols = 1:3, gridExpand = TRUE)
      current_row <- current_row + 1
    }

    # Setting row
    row_style <- if (s$required) req_style else opt_style
    openxlsx::writeData(wb, "Settings",
                         data.frame(a = s$setting, b = s$default, c = s$description),
                         startRow = current_row, colNames = FALSE)
    openxlsx::addStyle(wb, "Settings", row_style, rows = current_row, cols = 1, gridExpand = TRUE)
    openxlsx::addStyle(wb, "Settings", input_style, rows = current_row, cols = 2, gridExpand = TRUE)
    openxlsx::addStyle(wb, "Settings", help_style, rows = current_row, cols = 3, gridExpand = TRUE)

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

    current_row <- current_row + 1
  }

  # Column widths
  openxlsx::setColWidths(wb, "Settings", cols = 1, widths = 32)
  openxlsx::setColWidths(wb, "Settings", cols = 2, widths = 25)
  openxlsx::setColWidths(wb, "Settings", cols = 3, widths = 60)

  # Freeze header row
  openxlsx::freezePane(wb, "Settings", firstRow = FALSE, firstCol = FALSE,
                        firstActiveRow = header_row + 1)

  # =========================================================================
  # ATTRIBUTES SHEET
  # =========================================================================

  openxlsx::addWorksheet(wb, "Attributes")

  # Title
  openxlsx::writeData(wb, "Attributes", "Conjoint Attribute Definitions", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "Attributes", title_style, rows = 1, cols = 1)
  openxlsx::writeData(wb, "Attributes", "Define each attribute and its levels. Levels are comma-separated.", startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, "Attributes", subtitle_style, rows = 2, cols = 1)

  # Header at row 4
  attr_header <- data.frame(
    AttributeName = "AttributeName",
    NumLevels = "NumLevels",
    LevelNames = "LevelNames"
  )
  openxlsx::writeData(wb, "Attributes", attr_header, startRow = 4, colNames = FALSE)
  openxlsx::addStyle(wb, "Attributes", header_style, rows = 4, cols = 1:3, gridExpand = TRUE)

  # Example data
  if (include_examples) {
    examples <- data.frame(
      AttributeName = c("Brand", "Price", "Size", "Colour"),
      NumLevels = c(3, 4, 3, 3),
      LevelNames = c(
        "Brand A, Brand B, Brand C",
        "R50, R100, R150, R200",
        "Small, Medium, Large",
        "Red, Blue, Green"
      ),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Attributes", examples, startRow = 5, colNames = FALSE)

    for (r in 5:8) {
      openxlsx::addStyle(wb, "Attributes", opt_style, rows = r, cols = 1, gridExpand = TRUE)
      openxlsx::addStyle(wb, "Attributes", input_style, rows = r, cols = 2, gridExpand = TRUE)
      openxlsx::addStyle(wb, "Attributes", input_style, rows = r, cols = 3, gridExpand = TRUE)
    }
  }

  openxlsx::setColWidths(wb, "Attributes", cols = 1, widths = 25)
  openxlsx::setColWidths(wb, "Attributes", cols = 2, widths = 12)
  openxlsx::setColWidths(wb, "Attributes", cols = 3, widths = 50)
  openxlsx::freezePane(wb, "Attributes", firstRow = FALSE, firstCol = FALSE,
                        firstActiveRow = 5)

  # =========================================================================
  # DESIGN SHEET (optional placeholder)
  # =========================================================================

  openxlsx::addWorksheet(wb, "Design")

  openxlsx::writeData(wb, "Design", "Experimental Design Matrix (Optional)", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "Design", title_style, rows = 1, cols = 1)
  openxlsx::writeData(wb, "Design",
                       "If you have a pre-defined experimental design, paste it here. Otherwise leave blank.",
                       startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, "Design", subtitle_style, rows = 2, cols = 1)

  # =========================================================================
  # SAVE
  # =========================================================================

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  if (verbose) {
    cat(sprintf("  ✓ Template saved to: %s\n", output_path))
    cat("  ℹ Edit the Settings and Attributes sheets, then run your analysis.\n")
  }

  invisible(output_path)
}


# ==============================================================================
# METHOD TEMPLATE PRESETS
# ==============================================================================

#' Get Method Template Overrides
#'
#' Returns default values for a pre-configured analysis template.
#'
#' @param template Character: "standard_cbc", "cbc_hb", "cbc_latent_class", "best_worst"
#' @return Named list of setting overrides
#' @keywords internal
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
    cat(sprintf("  [WARNING] Unknown method template '%s'. Available: %s\n",
                template, paste(names(templates), collapse = ", ")))
    return(list())
  }

  templates[[template]]
}
