# ==============================================================================
# 9CAT SYNTHETIC EXAMPLE - Survey_Structure.xlsx GENERATOR
# ==============================================================================
# Generates a fully-filled Survey_Structure.xlsx for the IPK 9-category study:
#   4 full CBM categories  : DSS, POS, PAS, BAK
#   5 awareness-only cats  : SLD, STO, PES, COO, ANT
#
# Depends on: 01_constants.R
# ==============================================================================


# ==============================================================================
# LOCAL COLUMN BUILDER HELPERS
# (defined in 1brand/03_structure.R; replicated here to keep 9cat self-contained)
# ==============================================================================

.build_questionmap_columns <- function() {
  list(
    list(name = "Role",               width = 36, required = TRUE,
         description = "Registry role name (e.g. funnel.awareness.DSS). See ROLE_REGISTRY.md."),
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


# ==============================================================================
# PROJECT SHEET
# ==============================================================================

.build_9cat_project_settings_def <- function() {
  meta <- cat9_study_meta()
  list(
    list(
      section_name = "PROJECT IDENTIFICATION",
      fields = list(
        list(name = "project_name", required = TRUE, default = meta$project_name,
             description = "[REQUIRED] Must match Brand_Config.xlsx",
             valid_values_text = "Free text"),
        list(name = "data_file",    required = TRUE, default = meta$data_file_name,
             description = "[REQUIRED] Must match Brand_Config.xlsx",
             valid_values_text = ".csv or .xlsx"),
        list(name = "client_name",  required = TRUE, default = meta$client_name,
             description = "[REQUIRED] Client organisation name",
             valid_values_text = "Free text"),
        list(name = "focal_brand",  required = TRUE, default = meta$focal_brand,
             description = "[REQUIRED] Focal brand code (must match Brands sheet)",
             valid_values_text = "Brand code")
      )
    )
  )
}


# ==============================================================================
# QUESTIONS SHEET
# ==============================================================================

.build_9cat_questions_rows <- function() {

  full_cats  <- Filter(function(c) c$analysis_depth == "full",           cat9_categories())
  aware_cats <- Filter(function(c) c$analysis_depth == "awareness_only", cat9_categories())

  # Full-category question battery: CATBUY + funnel + CEPs + attributes
  full_qs <- unlist(lapply(full_cats, function(cat) {
    base <- list(
      list(QuestionCode = sprintf("CATBUY_%s",     cat$code),
           QuestionText = sprintf("How often do you buy %s?", tolower(cat$name)),
           VariableType = "Single_Mention", Battery = "cat_buying",  Category = cat$name),
      list(QuestionCode = sprintf("BRANDAWARE_%s", cat$code),
           QuestionText = sprintf("Which of these brands of %s have you heard of before today?", tolower(cat$name)),
           VariableType = "Multi_Mention",  Battery = "awareness",   Category = cat$name),
      list(QuestionCode = sprintf("BRANDATT1_%s",  cat$code),
           QuestionText = "Which of the following statements best describes how you feel about this brand?",
           VariableType = "Single_Mention", Battery = "attitude",    Category = cat$name),
      list(QuestionCode = sprintf("BRANDATT2_%s",  cat$code),
           QuestionText = "Why would you refuse to buy this brand? (open-ended)",
           VariableType = "Open_End",       Battery = "attitude_oe", Category = cat$name),
      list(QuestionCode = sprintf("BRANDPEN1_%s",  cat$code),
           QuestionText = sprintf("Which of these brands have you bought in the last %s?", cat$timeframe_long),
           VariableType = "Multi_Mention",  Battery = "penetration", Category = cat$name),
      list(QuestionCode = sprintf("BRANDPEN2_%s",  cat$code),
           QuestionText = sprintf("Which of these brands have you bought in the last %s?", cat$timeframe_target),
           VariableType = "Multi_Mention",  Battery = "penetration", Category = cat$name),
      list(QuestionCode = sprintf("BRANDPEN3_%s",  cat$code),
           QuestionText = "How frequently do you buy each brand when purchasing in this category?",
           VariableType = "Rating",         Battery = "penetration", Category = cat$name)
    )
    cep_qs <- lapply(cat9_ceps(cat$code), function(cep) list(
      QuestionCode = cep$code,
      QuestionText = cep$text,
      VariableType = "Multi_Mention",
      Battery      = "cep_matrix",
      Category     = cat$name
    ))
    attr_qs <- lapply(cat9_attributes(), function(attr) list(
      QuestionCode = sprintf("%s_%s", cat$code, attr$code),
      QuestionText = attr$text,
      VariableType = "Multi_Mention",
      Battery      = "attribute",
      Category     = cat$name
    ))
    c(base, cep_qs, attr_qs)
  }), recursive = FALSE)

  # Awareness-only category questions: BRANDAWARE only
  aware_qs <- lapply(aware_cats, function(cat) list(
    QuestionCode = sprintf("BRANDAWARE_%s", cat$code),
    QuestionText = sprintf("Which of these brands of %s have you heard of before today?", tolower(cat$name)),
    VariableType = "Multi_Mention",
    Battery      = "awareness_only",
    Category     = cat$name
  ))

  # WOM battery (brand-level, full categories; Category = "ALL")
  wom_qs <- list(
    list(QuestionCode = "WOM_POS_REC",
         QuestionText = "Has someone you know shared something POSITIVE about any of these brands in the last 3 months? (QWOMBRAND1a)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_REC",
         QuestionText = "Has someone you know shared something NEGATIVE about any of these brands in the last 3 months? (QWOMBRAND1b)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_POS_SHARE",
         QuestionText = "Have you shared something POSITIVE about any of these brands in the last 3 months? (QWOMBRAND2a)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_POS_COUNT",
         QuestionText = "On how many occasions have you shared something POSITIVE about each brand in the last 3 months? (QWOMBRAND2b)",
         VariableType = "Rating", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_SHARE",
         QuestionText = "Have you shared something NEGATIVE about any of these brands in the last 3 months? (QWOMBRAND3a)",
         VariableType = "Multi_Mention", Battery = "wom", Category = "ALL"),
    list(QuestionCode = "WOM_NEG_COUNT",
         QuestionText = "On how many occasions have you shared something NEGATIVE about each brand in the last 3 months? (QWOMBRAND3b)",
         VariableType = "Rating", Battery = "wom", Category = "ALL")
  )

  # DBA battery (all respondents across all 9 categories; IPK assets only)
  dba_qs <- unlist(lapply(cat9_dba_assets(), function(a) list(
    list(QuestionCode = sprintf("DBA_FAME_%s",   a$code),
         QuestionText = sprintf("Have you seen this before? (%s)", a$label),
         VariableType = "Single_Mention", Battery = "dba", Category = "ALL"),
    list(QuestionCode = sprintf("DBA_UNIQUE_%s", a$code),
         QuestionText = sprintf("Which brand does this belong to? (%s)", a$label),
         VariableType = "Open_End",       Battery = "dba", Category = "ALL")
  )), recursive = FALSE)

  c(full_qs, aware_qs, wom_qs, dba_qs)
}


# ==============================================================================
# OPTIONS SHEET
# ==============================================================================

.build_9cat_options_rows <- function() {

  full_cats <- Filter(function(c) c$analysis_depth == "full", cat9_categories())

  # Attitude scale (Romaniuk 5-level) — one set per full category
  attitude <- unlist(lapply(full_cats, function(cat) {
    code <- sprintf("BRANDATT1_%s", cat$code)
    list(
      list(code = code, val = "1", text = "I love it / it's my favourite",                                    order = 1),
      list(code = code, val = "2", text = "It's among the ones I prefer",                                     order = 2),
      list(code = code, val = "3", text = "I wouldn't usually consider it, but I would if no other option",   order = 3),
      list(code = code, val = "4", text = "I would refuse to buy this brand",                                 order = 4),
      list(code = code, val = "5", text = "I have no opinion about this brand",                               order = 5)
    )
  }), recursive = FALSE)

  # Category buying frequency — one set per full category
  cat_buy <- unlist(lapply(full_cats, function(cat) {
    code <- sprintf("CATBUY_%s", cat$code)
    list(
      list(code = code, val = "1", text = "Several times a week",    order = 1),
      list(code = code, val = "2", text = "About once a week",       order = 2),
      list(code = code, val = "3", text = "A few times a month",     order = 3),
      list(code = code, val = "4", text = "Monthly or less",         order = 4),
      list(code = code, val = "5", text = "Never buy this category", order = 5)
    )
  }), recursive = FALSE)

  # Brand purchase frequency (BRANDPEN3) — one set per full category
  pen_freq <- unlist(lapply(full_cats, function(cat) {
    code <- sprintf("BRANDPEN3_%s", cat$code)
    list(
      list(code = code, val = "1", text = "Every time",              order = 1),
      list(code = code, val = "2", text = "Most times",              order = 2),
      list(code = code, val = "3", text = "About half the time",     order = 3),
      list(code = code, val = "4", text = "Occasionally",            order = 4),
      list(code = code, val = "5", text = "Rarely / first purchase", order = 5)
    )
  }), recursive = FALSE)

  # WOM occasion count scales
  wom_pos_count <- list(
    list(code = "WOM_POS_COUNT", val = "1", text = "Once",            order = 1),
    list(code = "WOM_POS_COUNT", val = "2", text = "Twice",           order = 2),
    list(code = "WOM_POS_COUNT", val = "3", text = "3 times",         order = 3),
    list(code = "WOM_POS_COUNT", val = "4", text = "4 times",         order = 4),
    list(code = "WOM_POS_COUNT", val = "5", text = "5 or more times", order = 5)
  )
  wom_neg_count <- lapply(wom_pos_count, function(r) { r$code <- "WOM_NEG_COUNT"; r })

  # DBA fame binary scale — one set per asset
  dba_fame <- unlist(lapply(cat9_dba_assets(), function(a) {
    code <- sprintf("DBA_FAME_%s", a$code)
    list(
      list(code = code, val = "1", text = "Yes, I have seen this before",    order = 1),
      list(code = code, val = "2", text = "No, I have not seen this before", order = 2)
    )
  }), recursive = FALSE)

  all_opts <- c(attitude, cat_buy, pen_freq, wom_pos_count, wom_neg_count, dba_fame)

  lapply(all_opts, function(o) list(
    QuestionCode = o$code,
    OptionText   = o$val,
    DisplayText  = o$text,
    DisplayOrder = o$order,
    ShowInOutput = "Y"
  ))
}


# ==============================================================================
# BRANDS SHEET  (90 rows: 10 brands × 9 categories)
# IsFocal = "Y" only for IPK in the 4 full categories.
# ==============================================================================

.build_9cat_brands_rows <- function() {
  unlist(lapply(cat9_categories(), function(cat) {
    lapply(cat9_brands(cat$code), function(b) list(
      Category     = cat$name,
      BrandCode    = b$code,
      BrandLabel   = b$label,
      DisplayOrder = b$display_order,
      IsFocal      = if (isTRUE(b$is_focal) && cat$analysis_depth == "full") "Y" else "N",
      Colour       = cat9_brand_colour(b$code)
    ))
  }), recursive = FALSE)
}


# ==============================================================================
# CEPs SHEET  (60 rows: 15 per full category)
# ==============================================================================

.build_9cat_ceps_rows <- function() {
  full_cats <- Filter(function(c) c$analysis_depth == "full", cat9_categories())
  unlist(lapply(full_cats, function(cat) {
    mapply(function(cep, i) list(
      Category     = cat$name,
      CEPCode      = cep$code,
      CEPText      = cep$text,
      DisplayOrder = i
    ), cat9_ceps(cat$code), seq_along(cat9_ceps(cat$code)), SIMPLIFY = FALSE)
  }), recursive = FALSE)
}


# ==============================================================================
# ATTRIBUTES SHEET  (20 rows: 5 per full category, category-prefixed codes)
# ==============================================================================

.build_9cat_attrs_rows <- function() {
  full_cats <- Filter(function(c) c$analysis_depth == "full", cat9_categories())
  unlist(lapply(full_cats, function(cat) {
    mapply(function(attr, i) list(
      Category     = cat$name,
      AttrCode     = sprintf("%s_%s", cat$code, attr$code),
      AttrText     = attr$text,
      DisplayOrder = i
    ), cat9_attributes(), seq_along(cat9_attributes()), SIMPLIFY = FALSE)
  }), recursive = FALSE)
}


# ==============================================================================
# DBA_ASSETS SHEET  (Survey_Structure version: links to question codes)
# ==============================================================================

.build_9cat_dba_structure_rows <- function() {
  lapply(cat9_dba_assets(), function(a) list(
    AssetCode          = a$code,
    AssetLabel         = a$label,
    AssetType          = a$asset_type,
    FameQuestionCode   = sprintf("DBA_FAME_%s",   a$code),
    UniqueQuestionCode = sprintf("DBA_UNIQUE_%s", a$code)
  ))
}


# ==============================================================================
# QUESTIONMAP SHEET
# ==============================================================================

.build_9cat_questionmap_rows <- function() {

  full_cats  <- Filter(function(c) c$analysis_depth == "full",           cat9_categories())
  aware_cats <- Filter(function(c) c$analysis_depth == "awareness_only", cat9_categories())

  # System rows (once)
  system_rows <- list(
    list(Role = "system.respondent.id",
         ClientCode = "Respondent_ID", QuestionText = "Respondent identifier",
         QuestionTextShort = "Resp ID", Variable_Type = "Single_Response",
         ColumnPattern = "{code}", OptionMapScale = "", Notes = "Unique per row"),
    list(Role = "system.respondent.weight",
         ClientCode = "Weight", QuestionText = "Post-stratification respondent weight",
         QuestionTextShort = "Weight", Variable_Type = "Numeric",
         ColumnPattern = "{code}", OptionMapScale = "", Notes = ""),
    list(Role = "system.focal.category",
         ClientCode = "Focal_Category", QuestionText = "Focal category assigned to respondent",
         QuestionTextShort = "Focal Cat", Variable_Type = "Single_Response",
         ColumnPattern = "{code}", OptionMapScale = "",
         Notes = "DSS, POS, PAS, or BAK — full categories only")
  )

  # Funnel rows per full category (6 roles each)
  funnel_rows <- unlist(lapply(full_cats, function(cat) {
    tfl <- cat$timeframe_long
    tft <- cat$timeframe_target
    list(
      list(Role = sprintf("funnel.awareness.%s", cat$code),
           ClientCode = sprintf("BRANDAWARE_%s", cat$code),
           QuestionText = sprintf("Which of these brands of %s have you heard of before today?", tolower(cat$name)),
           QuestionTextShort = sprintf("%s awareness", cat$code),
           Variable_Type = "Multi_Mention",
           ColumnPattern = "{code}_{brandcode}",
           OptionMapScale = "",
           Notes = sprintf("QBRANDAWARE — %s category", cat$name)),
      list(Role = sprintf("funnel.attitude.%s", cat$code),
           ClientCode = sprintf("BRANDATT1_%s", cat$code),
           QuestionText = "Which of the following statements best describes how you feel about this brand?",
           QuestionTextShort = sprintf("%s attitude", cat$code),
           Variable_Type = "Single_Response",
           ColumnPattern = "{code}_{brandcode}",
           OptionMapScale = "attitude_scale",
           Notes = "Romaniuk 5-position scale; codes 1-3 = positive disposition"),
      list(Role = sprintf("funnel.rejection_oe.%s", cat$code),
           ClientCode = sprintf("BRANDATT2_%s", cat$code),
           QuestionText = "Why would you refuse to buy this brand? (open-ended)",
           QuestionTextShort = sprintf("%s rejection", cat$code),
           Variable_Type = "Open_End",
           ColumnPattern = "{code}_{brandcode}",
           OptionMapScale = "",
           Notes = "Only populated when attitude = 4 (refuse)"),
      list(Role = sprintf("funnel.transactional.bought_long.%s", cat$code),
           ClientCode = sprintf("BRANDPEN1_%s", cat$code),
           QuestionText = sprintf("Which of these brands have you bought in the last %s?", tfl),
           QuestionTextShort = sprintf("Bought %s", tfl),
           Variable_Type = "Multi_Mention",
           ColumnPattern = "{code}_{brandcode}",
           OptionMapScale = "",
           Notes = "BRANDPENTRANS1"),
      list(Role = sprintf("funnel.transactional.bought_target.%s", cat$code),
           ClientCode = sprintf("BRANDPEN2_%s", cat$code),
           QuestionText = sprintf("Which of these brands have you bought in the last %s?", tft),
           QuestionTextShort = sprintf("Bought %s", tft),
           Variable_Type = "Multi_Mention",
           ColumnPattern = "{code}_{brandcode}",
           OptionMapScale = "",
           Notes = "BRANDPENTRANS2"),
      list(Role = sprintf("funnel.transactional.frequency.%s", cat$code),
           ClientCode = sprintf("BRANDPEN3_%s", cat$code),
           QuestionText = "How frequently do you buy each brand when purchasing in this category?",
           QuestionTextShort = "Purchase freq",
           Variable_Type = "Rating",
           ColumnPattern = "{code}_{brandcode}",
           OptionMapScale = "purchase_freq_scale",
           Notes = "BRANDPENTRANS3 — scale 1=Every time … 5=Rarely")
    )
  }), recursive = FALSE)

  # Cross-category awareness rows (1 role per awareness-only category)
  cross_aware_rows <- lapply(aware_cats, function(cat) {
    list(Role = sprintf("cross_cat.awareness.%s", cat$code),
         ClientCode = sprintf("BRANDAWARE_%s", cat$code),
         QuestionText = sprintf("Which of these brands of %s have you heard of before today?", tolower(cat$name)),
         QuestionTextShort = sprintf("%s awareness", cat$code),
         Variable_Type = "Multi_Mention",
         ColumnPattern = "{code}_{brandcode}",
         OptionMapScale = "",
         Notes = sprintf("Cross-category awareness only — %s is not a focal category", cat$name))
  })

  # WOM rows (brand-level, full-category brands)
  wom_rows <- list(
    list(Role = "wom.received_positive",
         ClientCode = "WOM_POS_REC",
         QuestionText = "Has someone you know shared something POSITIVE about this brand in the last 3 months?",
         QuestionTextShort = "Pos WOM received",
         Variable_Type = "Multi_Mention",
         ColumnPattern = "{code}_{brandcode}",
         OptionMapScale = "",
         Notes = "QWOMBRAND1a — filled for focal category brands only"),
    list(Role = "wom.received_negative",
         ClientCode = "WOM_NEG_REC",
         QuestionText = "Has someone you know shared something NEGATIVE about this brand in the last 3 months?",
         QuestionTextShort = "Neg WOM received",
         Variable_Type = "Multi_Mention",
         ColumnPattern = "{code}_{brandcode}",
         OptionMapScale = "",
         Notes = "QWOMBRAND1b"),
    list(Role = "wom.shared_positive",
         ClientCode = "WOM_POS_SHARE",
         QuestionText = "Have you shared something POSITIVE about this brand in the last 3 months?",
         QuestionTextShort = "Pos WOM shared",
         Variable_Type = "Multi_Mention",
         ColumnPattern = "{code}_{brandcode}",
         OptionMapScale = "",
         Notes = "QWOMBRAND2a"),
    list(Role = "wom.shared_positive_count",
         ClientCode = "WOM_POS_COUNT",
         QuestionText = "On how many occasions have you shared something POSITIVE about this brand in the last 3 months?",
         QuestionTextShort = "Pos WOM count",
         Variable_Type = "Rating",
         ColumnPattern = "{code}_{brandcode}",
         OptionMapScale = "wom_count_scale",
         Notes = "QWOMBRAND2b — conditional on WOM_POS_SHARE = 1"),
    list(Role = "wom.shared_negative",
         ClientCode = "WOM_NEG_SHARE",
         QuestionText = "Have you shared something NEGATIVE about this brand in the last 3 months?",
         QuestionTextShort = "Neg WOM shared",
         Variable_Type = "Multi_Mention",
         ColumnPattern = "{code}_{brandcode}",
         OptionMapScale = "",
         Notes = "QWOMBRAND3a"),
    list(Role = "wom.shared_negative_count",
         ClientCode = "WOM_NEG_COUNT",
         QuestionText = "On how many occasions have you shared something NEGATIVE about this brand in the last 3 months?",
         QuestionTextShort = "Neg WOM count",
         Variable_Type = "Rating",
         ColumnPattern = "{code}_{brandcode}",
         OptionMapScale = "wom_count_scale",
         Notes = "QWOMBRAND3b — conditional on WOM_NEG_SHARE = 1")
  )

  # DBA rows (one pair per asset — brand-level, IPK only)
  dba_rows <- unlist(lapply(cat9_dba_assets(), function(a) list(
    list(Role = sprintf("dba.fame.%s", a$code),
         ClientCode = sprintf("DBA_FAME_%s", a$code),
         QuestionText = sprintf("Have you seen this before? (%s)", a$label),
         QuestionTextShort = sprintf("Fame: %s", a$label),
         Variable_Type = "Single_Response",
         ColumnPattern = "{code}",
         OptionMapScale = "dba_fame_scale",
         Notes = "All respondents see all assets; recognition = 1"),
    list(Role = sprintf("dba.unique.%s", a$code),
         ClientCode = sprintf("DBA_UNIQUE_%s", a$code),
         QuestionText = sprintf("Which brand does this belong to? (%s)", a$label),
         QuestionTextShort = sprintf("Unique: %s", a$label),
         Variable_Type = "Open_End",
         ColumnPattern = "{code}",
         OptionMapScale = "",
         Notes = "Open-ended attribution; text coded to brand for uniqueness scoring")
  )), recursive = FALSE)

  c(system_rows, funnel_rows, cross_aware_rows, wom_rows, dba_rows)
}


# ==============================================================================
# OPTIONMAP SHEET
# ==============================================================================

.build_9cat_optionmap_rows <- function() {
  list(
    # Attitude scale (Romaniuk 5-position; shared across full categories via attitude_scale)
    list(Scale = "attitude_scale", ClientCode = "1",
         Role = "attitude.love",       ClientLabel = "I love it / it's my favourite",                                 OrderIndex = 1),
    list(Scale = "attitude_scale", ClientCode = "2",
         Role = "attitude.prefer",     ClientLabel = "It's among the ones I prefer",                                  OrderIndex = 2),
    list(Scale = "attitude_scale", ClientCode = "3",
         Role = "attitude.ambivalent", ClientLabel = "I wouldn't usually consider it, but I would if no other option", OrderIndex = 3),
    list(Scale = "attitude_scale", ClientCode = "4",
         Role = "attitude.reject",     ClientLabel = "I would refuse to buy this brand",                              OrderIndex = 4),
    list(Scale = "attitude_scale", ClientCode = "5",
         Role = "attitude.no_opinion", ClientLabel = "I have no opinion about this brand",                            OrderIndex = 5),

    # Purchase frequency scale (BRANDPEN3)
    list(Scale = "purchase_freq_scale", ClientCode = "1",
         Role = "freq.always",    ClientLabel = "Every time",              OrderIndex = 1),
    list(Scale = "purchase_freq_scale", ClientCode = "2",
         Role = "freq.most",      ClientLabel = "Most times",              OrderIndex = 2),
    list(Scale = "purchase_freq_scale", ClientCode = "3",
         Role = "freq.half",      ClientLabel = "About half the time",     OrderIndex = 3),
    list(Scale = "purchase_freq_scale", ClientCode = "4",
         Role = "freq.occ",       ClientLabel = "Occasionally",            OrderIndex = 4),
    list(Scale = "purchase_freq_scale", ClientCode = "5",
         Role = "freq.rarely",    ClientLabel = "Rarely / first purchase", OrderIndex = 5),

    # WOM count scale (occasions)
    list(Scale = "wom_count_scale", ClientCode = "1",
         Role = "", ClientLabel = "Once",            OrderIndex = 1),
    list(Scale = "wom_count_scale", ClientCode = "2",
         Role = "", ClientLabel = "Twice",           OrderIndex = 2),
    list(Scale = "wom_count_scale", ClientCode = "3",
         Role = "", ClientLabel = "3 times",         OrderIndex = 3),
    list(Scale = "wom_count_scale", ClientCode = "4",
         Role = "", ClientLabel = "4 times",         OrderIndex = 4),
    list(Scale = "wom_count_scale", ClientCode = "5",
         Role = "", ClientLabel = "5 or more times", OrderIndex = 5),

    # DBA fame binary scale
    list(Scale = "dba_fame_scale", ClientCode = "1",
         Role = "dba.recognised",     ClientLabel = "Yes, I have seen this before",    OrderIndex = 1),
    list(Scale = "dba_fame_scale", ClientCode = "2",
         Role = "dba.not_recognised", ClientLabel = "No, I have not seen this before", OrderIndex = 2)
  )
}


# ==============================================================================
# MAIN GENERATOR
# ==============================================================================

#' Generate the filled Survey_Structure.xlsx for the IPK 9-category example
#'
#' @param output_path Character. Destination path for Survey_Structure.xlsx.
#' @param overwrite   Logical. Overwrite if file exists (default: TRUE).
#' @return Invisibly returns the output_path.
#' @export
generate_9cat_structure <- function(output_path, overwrite = TRUE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  wb <- openxlsx::createWorkbook()

  write_settings_sheet(
    wb, "Project",
    .build_9cat_project_settings_def(),
    title    = "TURAS Survey Structure - Project Settings",
    subtitle = "Shared across brand, tabs, and tracker modules."
  )

  write_table_sheet(
    wb, "Questions",
    .build_questions_columns(),
    title    = "Question Definitions",
    subtitle = paste0(
      "All CBM questions across 9 categories. ",
      "4 FULL categories (DSS, POS, PAS, BAK) receive the complete battery: ",
      "category buying, brand funnel, 15 CEPs, 5 attributes. ",
      "5 AWARENESS-ONLY categories (SLD, STO, PES, COO, ANT) contribute brand awareness only. ",
      "WOM and DBA batteries are brand-level (Category = ALL)."
    ),
    example_rows   = .build_9cat_questions_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "Options",
    .build_options_columns(),
    title    = "Response Option Definitions",
    subtitle = paste0(
      "Attitude and category-buying scales replicated for each of the 4 full categories. ",
      "WOM count and DBA fame scales are shared across all categories."
    ),
    example_rows   = .build_9cat_options_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "Brands",
    .build_brands_columns(),
    title    = "Brand Definitions",
    subtitle = paste0(
      "90 brand entries: 10 brands × 9 categories. ",
      "IPK is focal (IsFocal = Y) only in the 4 full categories (DSS, POS, PAS, BAK). ",
      "Some brands appear in multiple categories (e.g. Knorr: DSS, POS, PAS, STO, COO)."
    ),
    example_rows   = .build_9cat_brands_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "CEPs",
    .build_ceps_columns(),
    title    = "Category Entry Point Definitions",
    subtitle = paste0(
      "60 CEPs total: 15 per full category. Codes are globally unique: ",
      "DSS=CEP01-15, POS=CEP16-30, PAS=CEP31-45, BAK=CEP46-60. ",
      "Awareness-only categories have no CEP questions."
    ),
    example_rows   = .build_9cat_ceps_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "Attributes",
    .build_attributes_columns(),
    title    = "Brand Image Attribute Definitions",
    subtitle = paste0(
      "20 attribute rows: 5 per full category (DSS, POS, PAS, BAK). ",
      "Same 5 perception items across all full categories; codes are category-prefixed ",
      "(e.g. DSS_ATTR01) to keep data columns distinct across categories."
    ),
    example_rows   = .build_9cat_attrs_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "DBA_Assets",
    .build_dba_structure_columns(),
    title    = "DBA Asset Definitions (only if element_dba = Y in Brand_Config)",
    subtitle = paste0(
      "5 distinctive brand assets for Ina Paarman's Kitchen. ",
      "DBA is brand-level: all 400 respondents across all 9 categories see these assets. ",
      "FameQuestionCode and UniqueQuestionCode link to question column prefixes."
    ),
    example_rows   = .build_9cat_dba_structure_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "QuestionMap",
    .build_questionmap_columns(),
    title    = "Question Role Map (required for role-registry elements)",
    subtitle = paste0(
      "Maps semantic roles to client question codes. ",
      "Funnel roles are category-qualified (e.g. funnel.awareness.DSS) for the 4 full categories. ",
      "Cross-category awareness roles (cross_cat.awareness.*) cover the 5 awareness-only categories. ",
      "See ROLE_REGISTRY.md for full role vocabulary."
    ),
    example_rows   = .build_9cat_questionmap_rows(),
    num_blank_rows = 0
  )

  write_table_sheet(
    wb, "OptionMap",
    .build_optionmap_columns(),
    title    = "Response Option Map (for Single_Response roles)",
    subtitle = paste0(
      "Maps coded values to semantic position roles. ",
      "attitude_scale is referenced by all 4 full-category attitude questions via QuestionMap."
    ),
    example_rows   = .build_9cat_optionmap_rows(),
    num_blank_rows = 0
  )

  openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)
  cat(sprintf("  + Survey_Structure.xlsx -> %s\n", output_path))
  invisible(output_path)
}
