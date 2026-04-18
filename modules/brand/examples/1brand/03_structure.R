# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - Survey_Structure.xlsx GENERATOR
# ==============================================================================
# Generates a fully-filled Survey_Structure.xlsx for the IPK Dry Seasonings
# & Spices single-category synthetic study. Uses the shared visual-polish
# template infrastructure (write_settings_sheet / write_table_sheet).
#
# Depends on: 01_constants.R (brand/CEP/attribute/DBA definitions).
# ==============================================================================


# ==============================================================================
# PROJECT SHEET (shared metadata)
# ==============================================================================

.build_1brand_project_settings_def <- function() {
  meta <- ipk_study_meta()
  list(
    list(
      section_name = "PROJECT IDENTIFICATION",
      fields = list(
        list(name = "project_name", required = TRUE, default = meta$project_name,
             description = "[REQUIRED] Must match Brand_Config.xlsx",
             valid_values_text = "Free text"),
        list(name = "data_file", required = TRUE, default = meta$data_file_name,
             description = "[REQUIRED] Must match Brand_Config.xlsx",
             valid_values_text = ".csv or .xlsx"),
        list(name = "client_name", required = TRUE, default = meta$client_name,
             description = "[REQUIRED] Client organisation name",
             valid_values_text = "Free text"),
        list(name = "focal_brand", required = TRUE, default = meta$focal_brand,
             description = "[REQUIRED] Focal brand code (must match Brands sheet below)",
             valid_values_text = "Brand code")
      )
    )
  )
}


# ==============================================================================
# QUESTIONS SHEET (all CBM questions for the category + brand-level batteries)
# ==============================================================================

.build_1brand_questions_rows <- function() {

  cat_name <- ipk_category()$name
  cat_def  <- ipk_category()

  # ---- Category-level questions ----
  cat_qs <- list(
    list(QuestionCode = sprintf("CATBUY_%s", cat_def$code),
         QuestionText = sprintf("How often do you buy %s?", tolower(cat_name)),
         VariableType = "Single_Mention", Battery = "cat_buying", Category = cat_name),
    list(QuestionCode = sprintf("BRANDAWARE_%s", cat_def$code),
         QuestionText = sprintf("Which of these brands of %s have you heard of?", tolower(cat_name)),
         VariableType = "Multi_Mention", Battery = "awareness", Category = cat_name),
    list(QuestionCode = sprintf("BRANDATT1_%s", cat_def$code),
         QuestionText = "Which of these statements best describes how you feel about this brand?",
         VariableType = "Single_Mention", Battery = "attitude", Category = cat_name),
    list(QuestionCode = sprintf("BRANDATT2_%s", cat_def$code),
         QuestionText = "Why would you refuse to buy this brand? (open-ended)",
         VariableType = "Open_End", Battery = "attitude_oe", Category = cat_name),
    list(QuestionCode = sprintf("BRANDPEN1_%s", cat_def$code),
         QuestionText = sprintf("Which of these brands have you bought in the last %s?", cat_def$timeframe_long),
         VariableType = "Multi_Mention", Battery = "penetration", Category = cat_name),
    list(QuestionCode = sprintf("BRANDPEN2_%s", cat_def$code),
         QuestionText = sprintf("Which of these brands have you bought in the last %s?", cat_def$timeframe_target),
         VariableType = "Multi_Mention", Battery = "penetration", Category = cat_name),
    list(QuestionCode = sprintf("BRANDPEN3_%s", cat_def$code),
         QuestionText = "How frequently do you buy each brand when purchasing in this category?",
         VariableType = "Rating", Battery = "penetration", Category = cat_name)
  )

  # ---- CEPs (one question per CEP) ----
  cep_qs <- lapply(ipk_ceps(), function(c) list(
    QuestionCode = c$code,
    QuestionText = c$text,
    VariableType = "Multi_Mention",
    Battery      = "cep_matrix",
    Category     = cat_name
  ))

  # ---- Attributes (one question per attribute) ----
  attr_qs <- lapply(ipk_attributes(), function(a) list(
    QuestionCode = a$code,
    QuestionText = a$text,
    VariableType = "Multi_Mention",
    Battery      = "attribute",
    Category     = cat_name
  ))

  # ---- WOM battery (brand-level, Category = ALL) ----
  wom_qs <- list(
    list(QuestionCode = "WOM_POS_REC",   QuestionText = "Which brands have you heard someone speak POSITIVELY about?",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_POS_FREQ",  QuestionText = "How often have you heard positive word-of-mouth?",
         VariableType = "Rating",        Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_REC",   QuestionText = "Which brands have you heard someone speak NEGATIVELY about?",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_FREQ",  QuestionText = "How often have you heard negative word-of-mouth?",
         VariableType = "Rating",        Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_POS_SHARE", QuestionText = "Which brands have you spoken POSITIVELY about to others?",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_SHARE", QuestionText = "Which brands have you spoken NEGATIVELY about to others?",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL")
  )

  # ---- DBA battery (brand-level, one fame + one uniqueness question per asset) ----
  dba_qs <- unlist(lapply(ipk_dba_assets(), function(a) list(
    list(QuestionCode = sprintf("DBA_FAME_%s",   a$code),
         QuestionText = sprintf("Have you seen this before? (%s)", a$label),
         VariableType = "Single_Mention", Battery = "dba", Category = "ALL"),
    list(QuestionCode = sprintf("DBA_UNIQUE_%s", a$code),
         QuestionText = sprintf("Which brand does this belong to? (%s)", a$label),
         VariableType = "Open_End",       Battery = "dba", Category = "ALL")
  )), recursive = FALSE)

  c(cat_qs, cep_qs, attr_qs, wom_qs, dba_qs)
}


# ==============================================================================
# OPTIONS SHEET (response options for categorical questions)
# ==============================================================================

.build_1brand_options_rows <- function() {

  cat_code <- ipk_category()$code

  # Attitude scale (Romaniuk 5-level) — note options 1..3 = positive disposition
  attitude <- list(
    list(code = sprintf("BRANDATT1_%s", cat_code), val = "1",
         text = "I love it / it's my favourite",                                order = 1),
    list(code = sprintf("BRANDATT1_%s", cat_code), val = "2",
         text = "It's among the ones I prefer",                                 order = 2),
    list(code = sprintf("BRANDATT1_%s", cat_code), val = "3",
         text = "I wouldn't usually consider it, but I would if no other option", order = 3),
    list(code = sprintf("BRANDATT1_%s", cat_code), val = "4",
         text = "I would refuse to buy this brand",                             order = 4),
    list(code = sprintf("BRANDATT1_%s", cat_code), val = "5",
         text = "I have no opinion about this brand",                           order = 5)
  )

  # Category buying frequency
  cat_buy <- list(
    list(code = sprintf("CATBUY_%s", cat_code), val = "1", text = "Several times a week", order = 1),
    list(code = sprintf("CATBUY_%s", cat_code), val = "2", text = "About once a week",    order = 2),
    list(code = sprintf("CATBUY_%s", cat_code), val = "3", text = "A few times a month",  order = 3),
    list(code = sprintf("CATBUY_%s", cat_code), val = "4", text = "Monthly or less",      order = 4),
    list(code = sprintf("CATBUY_%s", cat_code), val = "5", text = "Never buy this category", order = 5)
  )

  # Brand purchase frequency (conditional on bought)
  pen_freq <- list(
    list(code = sprintf("BRANDPEN3_%s", cat_code), val = "1", text = "Every time",             order = 1),
    list(code = sprintf("BRANDPEN3_%s", cat_code), val = "2", text = "Most times",             order = 2),
    list(code = sprintf("BRANDPEN3_%s", cat_code), val = "3", text = "About half the time",    order = 3),
    list(code = sprintf("BRANDPEN3_%s", cat_code), val = "4", text = "Occasionally",           order = 4),
    list(code = sprintf("BRANDPEN3_%s", cat_code), val = "5", text = "Rarely / first purchase", order = 5)
  )

  # WOM frequency scales
  wom_pos_freq <- list(
    list(code = "WOM_POS_FREQ", val = "1", text = "Several times a week", order = 1),
    list(code = "WOM_POS_FREQ", val = "2", text = "Weekly",               order = 2),
    list(code = "WOM_POS_FREQ", val = "3", text = "A few times a month",  order = 3),
    list(code = "WOM_POS_FREQ", val = "4", text = "Monthly or less",      order = 4),
    list(code = "WOM_POS_FREQ", val = "5", text = "Never",                order = 5)
  )
  wom_neg_freq <- lapply(wom_pos_freq, function(r) { r$code <- "WOM_NEG_FREQ"; r })

  # DBA fame scale (binary recognition)
  dba_fame <- unlist(lapply(ipk_dba_assets(), function(a) list(
    list(code = sprintf("DBA_FAME_%s", a$code), val = "1",
         text = "Yes, I have seen this before", order = 1),
    list(code = sprintf("DBA_FAME_%s", a$code), val = "2",
         text = "No, I have not seen this before", order = 2)
  )), recursive = FALSE)

  all_options <- c(attitude, cat_buy, pen_freq, wom_pos_freq, wom_neg_freq, dba_fame)

  lapply(all_options, function(o) list(
    QuestionCode = o$code,
    OptionText   = o$val,
    DisplayText  = o$text,
    DisplayOrder = o$order,
    ShowInOutput = "Y"
  ))
}


# ==============================================================================
# BRANDS, CEPs, ATTRIBUTES, DBA_ASSETS SHEETS
# ==============================================================================

# Brand-specific hex colours. Focal (IPK) and two key competitors have fixed
# colours; others left blank so they pick up the automatic Tableau-10 palette.
.BRAND_COLOURS_1BRAND <- list(
  IPK   = "#1A5276",   # Turas navy — focal brand
  ROB   = "#C0392B",   # Robertsons red
  KNORR = "#E67E22"    # Knorr amber
)

.build_1brand_brands_rows <- function() {
  cat_name <- ipk_category()$name
  lapply(ipk_brands(), function(b) list(
    Category     = cat_name,
    BrandCode    = b$code,
    BrandLabel   = b$label,
    DisplayOrder = b$display_order,
    IsFocal      = if (isTRUE(b$is_focal)) "Y" else "N",
    Colour       = .BRAND_COLOURS_1BRAND[[b$code]] %||% ""
  ))
}

.build_1brand_ceps_rows <- function() {
  cat_name <- ipk_category()$name
  mapply(function(c, i) list(
    Category     = cat_name,
    CEPCode      = c$code,
    CEPText      = c$text,
    DisplayOrder = i
  ), ipk_ceps(), seq_along(ipk_ceps()), SIMPLIFY = FALSE)
}

.build_1brand_attrs_rows <- function() {
  cat_name <- ipk_category()$name
  mapply(function(a, i) list(
    Category     = cat_name,
    AttrCode     = a$code,
    AttrText     = a$text,
    DisplayOrder = i
  ), ipk_attributes(), seq_along(ipk_attributes()), SIMPLIFY = FALSE)
}

.build_1brand_dba_structure_rows <- function() {
  lapply(ipk_dba_assets(), function(a) list(
    AssetCode          = a$code,
    AssetLabel         = a$label,
    AssetType          = a$asset_type,
    FameQuestionCode   = sprintf("DBA_FAME_%s",   a$code),
    UniqueQuestionCode = sprintf("DBA_UNIQUE_%s", a$code)
  ))
}


# ==============================================================================
# MAIN GENERATOR
# ==============================================================================

#' Generate the filled Survey_Structure.xlsx for the IPK 1Brand example
#'
#' @param output_path Character. Destination path for Survey_Structure.xlsx.
#' @param overwrite   Logical. Overwrite if file exists (default: TRUE).
#' @return Invisibly returns the output_path.
#' @export
generate_1brand_structure <- function(output_path, overwrite = TRUE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    rlang::abort("Package 'openxlsx' is required", class = "pkg_missing")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  wb <- openxlsx::createWorkbook()

  write_settings_sheet(
    wb, "Project",
    .build_1brand_project_settings_def(),
    title    = "TURAS Survey Structure - Project Settings",
    subtitle = "Shared across brand, tabs, and tracker modules."
  )

  write_table_sheet(
    wb, "Questions",
    .build_questions_columns(),
    title    = "Question Definitions",
    subtitle = "Every CBM question in this survey, mapped to battery and category.",
    example_rows   = .build_1brand_questions_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "Options",
    .build_options_columns(),
    title    = "Response Option Definitions",
    subtitle = "Labels for coded responses on categorical questions.",
    example_rows   = .build_1brand_options_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "Brands",
    .build_brands_columns(),
    title    = "Brand Definitions",
    subtitle = "Ten brands in the Dry Seasonings & Spices competitive set. Focal brand = Ina Paarman's Kitchen.",
    example_rows   = .build_1brand_brands_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "CEPs",
    .build_ceps_columns(),
    title    = "Category Entry Point Definitions",
    subtitle = "15 CEPs covering when South African cooks buy dry seasonings.",
    example_rows   = .build_1brand_ceps_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "Attributes",
    .build_attributes_columns(),
    title    = "Brand Image Attribute Definitions",
    subtitle = "Five perception attributes (not CEPs).",
    example_rows   = .build_1brand_attrs_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "DBA_Assets",
    .build_dba_structure_columns(),
    title    = "DBA Asset Definitions (only if element_dba = Y in Brand_Config)",
    subtitle = "Asset codes linked to fame and uniqueness question codes.",
    example_rows   = .build_1brand_dba_structure_rows(),
    num_blank_rows = 0
  )

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)
  cat(sprintf("  + Survey_Structure.xlsx -> %s\n", output_path))
  invisible(output_path)
}
