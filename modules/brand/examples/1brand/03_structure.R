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
  # Follows CBM TRANS questions: QWOMBRAND1a/1b (received), 2a/2b (shared+count), 3a/3b (neg+count)
  wom_qs <- list(
    list(QuestionCode = "WOM_POS_REC",   QuestionText = "Has someone shared something POSITIVE about any of these brands in the last 3 months? (QWOMBRAND1a)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_REC",   QuestionText = "Has someone shared something NEGATIVE about any of these brands in the last 3 months? (QWOMBRAND1b)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_POS_SHARE", QuestionText = "Have you shared something POSITIVE about any of these brands in the last 3 months? (QWOMBRAND2a)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_POS_COUNT", QuestionText = "On how many occasions have you shared something POSITIVE about each brand in the last 3 months? (QWOMBRAND2b)",
         VariableType = "Rating",        Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_SHARE", QuestionText = "Have you shared something NEGATIVE about any of these brands in the last 3 months? (QWOMBRAND3a)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_COUNT", QuestionText = "On how many occasions have you shared something NEGATIVE about each brand in the last 3 months? (QWOMBRAND3b)",
         VariableType = "Rating",        Battery = "wom", Category = "ALL")
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

  # WOM occasion count scales (QWOMBRAND2b / QWOMBRAND3b) — per brand, conditional on sharing
  wom_count_options <- list(
    list(code = "WOM_POS_COUNT", val = "1", text = "Once",          order = 1),
    list(code = "WOM_POS_COUNT", val = "2", text = "Twice",         order = 2),
    list(code = "WOM_POS_COUNT", val = "3", text = "3 times",       order = 3),
    list(code = "WOM_POS_COUNT", val = "4", text = "4 times",       order = 4),
    list(code = "WOM_POS_COUNT", val = "5", text = "5 or more times", order = 5)
  )
  wom_neg_count_options <- lapply(wom_count_options, function(r) { r$code <- "WOM_NEG_COUNT"; r })

  # DBA fame scale (binary recognition)
  dba_fame <- unlist(lapply(ipk_dba_assets(), function(a) list(
    list(code = sprintf("DBA_FAME_%s", a$code), val = "1",
         text = "Yes, I have seen this before", order = 1),
    list(code = sprintf("DBA_FAME_%s", a$code), val = "2",
         text = "No, I have not seen this before", order = 2)
  )), recursive = FALSE)

  all_options <- c(attitude, cat_buy, pen_freq, wom_count_options, wom_neg_count_options, dba_fame)

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
# QUESTIONMAP SHEET (role-registry architecture — required for funnel element)
# ==============================================================================

.build_questionmap_columns <- function() {
  list(
    list(name = "Role",               width = 36, required = TRUE,
         description = "Registry role name (e.g. funnel.awareness). See ROLE_REGISTRY.md."),
    list(name = "ClientCode",         width = 24, required = TRUE,
         description = "Client question code used as column prefix in the data file"),
    list(name = "QuestionText",       width = 52, required = TRUE,
         description = "Full question wording — shown in chart/card labels and About drawer"),
    list(name = "QuestionTextShort",  width = 26, required = FALSE,
         description = "Optional shortened label for tight UI elements"),
    list(name = "Variable_Type",      width = 20, required = TRUE,
         description = "Data type; shared vocabulary with tabs module",
         dropdown = c("Single_Response", "Multi_Mention", "Rating",
                      "Likert", "NPS", "Ranking", "Numeric", "Open_End")),
    list(name = "ColumnPattern",      width = 28, required = TRUE,
         description = paste0("Column naming template. Tokens: {code}, {brandcode},",
                              " {cepcode}, {assetcode}. e.g. {code}_{brandcode}")),
    list(name = "OptionMapScale",     width = 20, required = FALSE,
         description = "Scale name in OptionMap sheet. Leave blank for binary/free-text."),
    list(name = "Notes",              width = 40, required = FALSE,
         description = "Operator notes — not shown in report")
  )
}

.build_1brand_questionmap_rows <- function() {
  cat_def  <- ipk_category()
  cat_code <- cat_def$code
  cat_name <- cat_def$name
  tfl      <- cat_def$timeframe_long
  tft      <- cat_def$timeframe_target

  list(
    list(Role = "system.respondent.id",
         ClientCode        = "Respondent_ID",
         QuestionText      = "Respondent panel identifier",
         QuestionTextShort = "Resp ID",
         Variable_Type     = "Single_Response",
         ColumnPattern     = "{code}",
         OptionMapScale    = "",
         Notes             = "Unique per row"),
    list(Role = "system.respondent.weight",
         ClientCode        = "Weight",
         QuestionText      = "Post-stratification respondent weight",
         QuestionTextShort = "Weight",
         Variable_Type     = "Numeric",
         ColumnPattern     = "{code}",
         OptionMapScale    = "",
         Notes             = ""),
    list(Role = "funnel.awareness",
         ClientCode        = sprintf("BRANDAWARE_%s", cat_code),
         QuestionText      = sprintf("Which of these brands of %s have you heard of?",
                                     tolower(cat_name)),
         QuestionTextShort = "Brand awareness",
         Variable_Type     = "Multi_Mention",
         ColumnPattern     = "{code}_{brandcode}",
         OptionMapScale    = "",
         Notes             = "QBRANDAWARE equivalent"),
    list(Role = "funnel.attitude",
         ClientCode        = sprintf("BRANDATT1_%s", cat_code),
         QuestionText      = paste("Which of these statements best describes",
                                   "how you feel about this brand?"),
         QuestionTextShort = "Brand attitude",
         Variable_Type     = "Single_Response",
         ColumnPattern     = "{code}_{brandcode}",
         OptionMapScale    = "attitude_scale",
         Notes             = "Romaniuk 5-position scale; codes mapped via OptionMap"),
    list(Role = "funnel.rejection_oe",
         ClientCode        = sprintf("BRANDATT2_%s", cat_code),
         QuestionText      = "Why would you refuse to buy this brand? (open-ended)",
         QuestionTextShort = "Rejection reason",
         Variable_Type     = "Open_End",
         ColumnPattern     = "{code}_{brandcode}",
         OptionMapScale    = "",
         Notes             = "Optional; populated only when attitude = reject"),
    list(Role = "funnel.transactional.bought_long",
         ClientCode        = sprintf("BRANDPEN1_%s", cat_code),
         QuestionText      = sprintf("Which of these brands have you bought in the last %s?", tfl),
         QuestionTextShort = sprintf("Bought last %s", tfl),
         Variable_Type     = "Multi_Mention",
         ColumnPattern     = "{code}_{brandcode}",
         OptionMapScale    = "",
         Notes             = "BRANDPENTRANS1 — longer timeframe"),
    list(Role = "funnel.transactional.bought_target",
         ClientCode        = sprintf("BRANDPEN2_%s", cat_code),
         QuestionText      = sprintf("Which of these brands have you bought in the last %s?", tft),
         QuestionTextShort = sprintf("Bought last %s", tft),
         Variable_Type     = "Multi_Mention",
         ColumnPattern     = "{code}_{brandcode}",
         OptionMapScale    = "",
         Notes             = "BRANDPENTRANS2 — target timeframe"),
    list(Role = "funnel.transactional.frequency",
         ClientCode        = sprintf("BRANDPEN3_%s", cat_code),
         QuestionText      = paste("How frequently do you buy each brand",
                                   "when purchasing in this category?"),
         QuestionTextShort = "Purchase frequency",
         Variable_Type     = "Numeric",
         ColumnPattern     = "{code}_{brandcode}",
         OptionMapScale    = "",
         Notes             = "BRANDPENTRANS3 — frequency scale 1-5")
  )
}


# ==============================================================================
# OPTIONMAP SHEET (scale codes for Single_Response roles)
# ==============================================================================

.build_optionmap_columns <- function() {
  list(
    list(name = "Scale",       width = 20, required = TRUE,
         description = "Scale name — must match OptionMapScale in QuestionMap"),
    list(name = "ClientCode",  width = 14, required = TRUE,
         description = "Integer or string code as it appears in the data"),
    list(name = "Role",        width = 28, required = FALSE,
         description = "Position role this code maps to (e.g. attitude.love). Blank = non-analytic."),
    list(name = "ClientLabel", width = 52, required = TRUE,
         description = "Client question wording for this response option — shown in report legend"),
    list(name = "OrderIndex",  width = 14, required = TRUE,
         description = "Display order (integer). Lower = first.",
         integer_range = c(1, 100))
  )
}

.build_1brand_optionmap_rows <- function() {
  list(
    list(Scale = "attitude_scale", ClientCode = "1",
         Role        = "attitude.love",
         ClientLabel = "I love it / it's my favourite",
         OrderIndex  = 1),
    list(Scale = "attitude_scale", ClientCode = "2",
         Role        = "attitude.prefer",
         ClientLabel = "It's among the ones I prefer",
         OrderIndex  = 2),
    list(Scale = "attitude_scale", ClientCode = "3",
         Role        = "attitude.ambivalent",
         ClientLabel = "I wouldn't usually consider it, but I would if no other option",
         OrderIndex  = 3),
    list(Scale = "attitude_scale", ClientCode = "4",
         Role        = "attitude.reject",
         ClientLabel = "I would refuse to buy this brand",
         OrderIndex  = 4),
    list(Scale = "attitude_scale", ClientCode = "5",
         Role        = "attitude.no_opinion",
         ClientLabel = "I have no opinion about this brand",
         OrderIndex  = 5)
  )
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

  write_table_sheet(
    wb, "QuestionMap",
    .build_questionmap_columns(),
    title    = "Question Role Map (required for role-registry elements)",
    subtitle = paste("Maps semantic roles (funnel.awareness, funnel.attitude, etc.)",
                     "to client question codes. See ROLE_REGISTRY.md."),
    example_rows   = .build_1brand_questionmap_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "OptionMap",
    .build_optionmap_columns(),
    title    = "Response Option Map (for Single_Response roles)",
    subtitle = paste("Maps coded values to semantic position roles",
                     "(e.g. attitude_scale code 1 = attitude.love)."),
    example_rows   = .build_1brand_optionmap_rows(),
    num_blank_rows = 0
  )

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)
  cat(sprintf("  + Survey_Structure.xlsx -> %s\n", output_path))
  invisible(output_path)
}
