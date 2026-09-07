# ==============================================================================
# IPK WAVE 1 FIXTURE: STRUCTURE WRITERS
# ==============================================================================
# Builds Survey_Structure.xlsx and Brand_Config.xlsx alongside the data file
# so the bundle is a complete project (data + config + structure). Schema
# follows the brand-extended Survey_Structure described in
# docs/PLANNING_IPK_REBUILD.md §5.1.
# ==============================================================================

# ------------------------------------------------------------------------------
# Survey_Structure.xlsx: tabs-format Project + Questions + Options +
# brand-extension Brands / CEPs / Attributes / Channels / PackSizes sheets.
# QuestionMap omitted (convention-first inference is the default).
# ------------------------------------------------------------------------------

#' Write Survey_Structure.xlsx for the IPK Wave 1 fixture
#'
#' @param path Destination file path.
#' @param data_path Relative path (from Survey_Structure) to the data file.
#' @param extras Logical. When TRUE, add the sheets the QA extras need:
#'   QuestionMap (the only route into the shopper engine), MarketingReach and
#'   ReachMedia (Branded Reach), AudienceLens, one Questions row and three
#'   Options rows for the ad hoc question, and a PackSizes sheet carrying the
#'   column names the shopper engine reads. See 08_qa_extras.R.
ipk_write_survey_structure <- function(path, data_path = "ipk_wave1_data.xlsx",
                                       extras = FALSE) {

  wb <- openxlsx::createWorkbook()

  # --- Project sheet ---
  project <- data.frame(
    Field = c("project_name", "project_code", "client_name", "study_type",
              "study_date", "lead", "notes",
              "data_file_path", "output_dir", "expected_n",
              "weight_column_exists"),
    Value = c("IPK Brand Health: Wave 1 (fixture)", "IPK_W1_FIX",
              "Ina Paarman's Kitchen", "Tracker", "20260430",
              "Duncan Brett", "Synthetic fixture for brand IPK rebuild",
              data_path, "out", as.character(IPK_N_RESPONDENTS), "N"),
    stringsAsFactors = FALSE
  )
  openxlsx::addWorksheet(wb, "Project")
  openxlsx::writeData(wb, "Project", project)

  # --- Questions sheet ---
  questions <- .ipk_build_questions_df()
  options_df <- .ipk_build_options_df()
  if (isTRUE(extras)) {
    questions  <- rbind(questions,  .ipk_extras_questions_df())
    options_df <- rbind(options_df, .ipk_extras_options_df())
  }
  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", questions)

  # --- Options sheet ---
  openxlsx::addWorksheet(wb, "Options")
  openxlsx::writeData(wb, "Options", options_df)

  # --- Brand sheets ---
  openxlsx::addWorksheet(wb, "Brands")
  openxlsx::writeData(wb, "Brands", .ipk_build_brands_df())

  openxlsx::addWorksheet(wb, "CEPs")
  openxlsx::writeData(wb, "CEPs", .ipk_build_ceps_df())

  openxlsx::addWorksheet(wb, "Attributes")
  openxlsx::writeData(wb, "Attributes", .ipk_build_attrs_df())

  openxlsx::addWorksheet(wb, "Channels")
  openxlsx::writeData(wb, "Channels", .ipk_build_channels_df())

  openxlsx::addWorksheet(wb, "PackSizes")
  openxlsx::writeData(wb, "PackSizes",
                      if (isTRUE(extras)) .ipk_extras_packs_df()
                      else .ipk_build_packs_df())

  if (isTRUE(extras)) {
    openxlsx::addWorksheet(wb, "QuestionMap")
    openxlsx::writeData(wb, "QuestionMap", .ipk_extras_questionmap_df())
    openxlsx::addWorksheet(wb, "MarketingReach")
    openxlsx::writeData(wb, "MarketingReach", .ipk_extras_marketing_reach_df())
    openxlsx::addWorksheet(wb, "ReachMedia")
    openxlsx::writeData(wb, "ReachMedia", .ipk_extras_reach_media_df())
    openxlsx::addWorksheet(wb, "AudienceLens")
    openxlsx::writeData(wb, "AudienceLens", .ipk_extras_audience_lens_df())
  }

  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  invisible(path)
}

# ------------------------------------------------------------------------------
# Brand_Config.xlsx: Settings + Categories + AdHoc + AudienceLens
# ------------------------------------------------------------------------------

#' Write Brand_Config.xlsx for the IPK Wave 1 fixture
ipk_write_brand_config <- function(path, extras = FALSE) {
  wb <- openxlsx::createWorkbook()

  settings <- data.frame(
    Setting = c(
      # Required by guard_validate_brand_config (00_guard.R:130-131)
      "project_name", "client_name", "focal_brand",
      "data_file", "structure_file", "output_dir",
      # Element toggles
      "element_funnel", "element_mental_avail", "element_wom",
      "element_dba", "element_branded_reach", "element_portfolio",
      "element_audience_lens", "element_demographics",
      # Run-time settings
      "wave", "wom_timeframe", "focal_assignment", "min_base_rule"
    ),
    Value = c(
      IPK_PROJECT_NAME, IPK_CLIENT_NAME, IPK_PROJECT_FOCAL_BRAND,
      IPK_DATA_FILE, IPK_STRUCTURE_FILE, IPK_OUTPUT_DIR,
      "Y", "Y", "Y", "N", if (isTRUE(extras)) "Y" else "N", "Y", "Y", "Y",
      as.character(IPK_WAVE), IPK_WOM_TIMEFRAME, "balanced", "30"
    ),
    stringsAsFactors = FALSE
  )
  if (isTRUE(extras)) {
    # When the study was in field, which the header prints beside the wave
    # and the About tab repeats. Only the extras fixture sets it, so the two
    # QA reports built from this generator prove the filled case while the
    # committed fixture goes on proving the blank one. This is a fixture
    # value, invented for the fixture; it is not the real IPK wave 1 field
    # period and no figure in this fixture came from a real field period.
    settings <- rbind(settings, data.frame(
      Setting = "fieldwork_dates", Value = "1 to 8 April 2026",
      stringsAsFactors = FALSE))
  }
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", settings)

  cats <- do.call(rbind, lapply(IPK_CATEGORIES, function(c) {
    data.frame(
      Category         = c$label,
      CategoryCode     = c$code,
      Active           = c$active,
      Type             = "transactional",
      Analysis_Depth   = c$analysis_depth,
      Timeframe_Long   = c$timeframe_long,
      Timeframe_Target = c$timeframe_target %||% NA_character_,
      Focal_Weight     = if (c$role == "Core") 0.25 else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  if (isTRUE(extras)) {
    # The per-category opt-in the audience lens parser looks for first
    # (R/13a_al_audiences.R line 61). Without this column it returns an empty
    # list and logs nothing, which is why the lens has been silently absent.
    cats$AudienceLens_Use <- ifelse(cats$CategoryCode == CAT_DSS, "ALL",
                                    NA_character_)
  }
  openxlsx::addWorksheet(wb, "Categories")
  openxlsx::writeData(wb, "Categories", cats)

  # AdHoc: none in fixture
  openxlsx::addWorksheet(wb, "AdHoc")
  openxlsx::writeData(wb, "AdHoc", data.frame(
    Role = character(0), ClientCode = character(0),
    QuestionTextShort = character(0), Variable_Type = character(0),
    OptionMapScale = character(0), Scope = character(0),
    stringsAsFactors = FALSE
  ))

  # AudienceLens: focal-brand-buyer pair for DSS only
  openxlsx::addWorksheet(wb, "AudienceLens")
  openxlsx::writeData(wb, "AudienceLens", data.frame(
    AudienceCode = "buyer_pair_DSS",
    AudienceLabel = "DSS focal-brand buyer vs non-buyer",
    Definition = "BRANDPEN2_DSS contains 'IPK'",
    Category = "DSS",
    stringsAsFactors = FALSE
  ))

  # Section_Insights: analyst-authored notes that survive a re-run, the sheet
  # R/01b_section_insights.R loads. Every figure below was read off a real
  # run_brand() on this fixture and is correct for the view its section opens
  # on, so the authored-insight number check
  # (lib/html_report/03b_insight_number_check.R) has something true to run
  # over and a false positive here is a real failure, not a fixture quirk.
  # The funnel note quotes the nested chain, which is what the funnel page
  # opens on: IPK 92 / 67 / 45 / 32, category average 61 / 24 / 10 / 6.
  openxlsx::addWorksheet(wb, "Section_Insights")
  openxlsx::writeData(wb, "Section_Insights", data.frame(
    Category = c("_REPORT", "DSS", "DSS", "DSS"),
    Section  = c("Executive Summary", "Brand Funnel",
                 "Category Entry Points", "Word of Mouth"),
    Insight  = c(
      paste("IPK leads the Dry Seasonings funnel at every stage and holds",
            "the top mental market share of the brands measured."),
      paste("IPK is known to 92% of the sample and holds 67% at preference,",
            "45% at past 12 months and 32% at past 3 months.",
            "The category average runs 61% then 24%, so IPK is ahead at",
            "every stage of the chain."),
      paste("IPK's strongest entry point reaches 16.7% of the sample,",
            "against 14.4% for Robertsons and for Knorr on the same one.",
            "Mental penetration sits at 84% across the 15 entry points."),
      paste("IPK receives positive word of mouth from 23.5% of category",
            "buyers and shares it at 21.9%, both ahead of Robertsons at",
            "21.9% received and 13.2% shared.")
    ),
    Order = 1:4,
    Author = rep("Fixture", 4),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  invisible(path)
}

# ==============================================================================
# Internal builders for Survey_Structure sheets
# ==============================================================================

.ipk_build_questions_df <- function() {
  rows <- list()

  add_q <- function(code, text, vt, cols) {
    rows[[length(rows) + 1L]] <<- data.frame(
      QuestionCode = code, QuestionText = text,
      Variable_Type = vt, Columns = cols,
      stringsAsFactors = FALSE
    )
  }

  # Admin / qualifying / demographics
  add_q("Focal_Category", "Assigned focal category", "Single_Response", 1L)
  add_q("Wave", "Survey wave", "Single_Response", 1L)
  add_q("Gender", "Gender (qualifying)", "Single_Response", 1L)
  add_q("Age", "Age (qualifying)", "Single_Response", 1L)
  add_q("Industry_Screen", "Industry screen", "Single_Response", 1L)
  add_q("Region", "Region", "Single_Response", 1L)
  for (k in c("DEMO_AGE", "DEMO_GENDER", "DEMO_PROVINCE",
              "DEMO_GROCERY_ROLE", "DEMO_HH_SIZE",
              "DEMO_EMPLOYMENT", "DEMO_SEM")) {
    add_q(k, k, "Single_Response", 1L)
  }

  # Screeners (slot-indexed)
  add_q("SQ1", "12-month category buyers", "Multi_Mention",
        length(IPK_CATEGORIES) + 1L)
  add_q("SQ2", "3-month category buyers", "Multi_Mention",
        length(IPK_CATEGORIES))

  # BRANDAWARE per category
  for (cat_meta in IPK_CATEGORIES) {
    cat <- cat_meta$code
    add_q(paste0("BRANDAWARE_", cat),
          paste("Brand awareness:", cat_meta$label),
          "Multi_Mention", ipk_brand_slot_count(cat))
  }

  # DSS deep dive only: others added when Jess builds them
  cat <- "DSS"
  n_slots <- ipk_brand_slot_count(cat)
  for (cep in IPK_CEPS_DSS) {
    add_q(paste0("BRANDATTR_", cat, "_", cep$code),
          paste("CEP:", cep$text), "Multi_Mention", n_slots)
  }
  for (att in IPK_ATTS_DSS) {
    add_q(paste0("BRANDATTR_", cat, "_", att$code),
          paste("Attribute:", att$text), "Multi_Mention", n_slots)
  }
  for (b in IPK_BRANDS[[cat]]) {
    add_q(paste0("BRANDATT1_", cat, "_", b),
          paste("Attitude:", b), "Single_Response", 1L)
    add_q(paste0("BRANDATT2_", cat, "_", b),
          paste("Rejection OE:", b), "Open_End", 1L)
  }
  for (typ in c("WOM_POS_REC", "WOM_POS_SHARE",
                "WOM_NEG_REC", "WOM_NEG_SHARE")) {
    add_q(paste0(typ, "_", cat),
          paste("WOM:", typ, "for", cat), "Multi_Mention", n_slots)
  }
  for (b in IPK_BRANDS[[cat]]) {
    add_q(paste0("WOM_POS_COUNT_", cat, "_", b),
          paste("WOM positive count:", b), "Single_Response", 1L)
    add_q(paste0("WOM_NEG_COUNT_", cat, "_", b),
          paste("WOM negative count:", b), "Single_Response", 1L)
  }
  add_q(paste0("CATBUY_", cat), paste("Category buying frequency:", cat),
        "Single_Response", 1L)
  add_q(paste0("CATCOUNT_", cat), paste("Category count:", cat),
        "Numeric", 1L)
  add_q(paste0("CHANNEL_", cat), paste("Channels:", cat),
        "Multi_Mention", length(IPK_CHANNELS))
  add_q(paste0("PACK_", cat), paste("Pack sizes:", cat),
        "Multi_Mention", length(IPK_PACK_SIZES))
  add_q(paste0("BRANDPEN1_", cat),
        paste("Penetration 12m:", cat), "Multi_Mention", n_slots)
  add_q(paste0("BRANDPEN2_", cat),
        paste("Penetration target:", cat), "Multi_Mention", n_slots)
  add_q(paste0("BRANDPEN3_", cat),
        paste("Purchase frequency (continuous sum):", cat),
        "Multi_Mention", length(IPK_BRANDS[[cat]]))

  do.call(rbind, rows)
}

.ipk_build_options_df <- function() {
  rows <- list()

  add_opt <- function(qc, opt_text, display_text, order = NA_integer_) {
    rows[[length(rows) + 1L]] <<- data.frame(
      QuestionCode = qc, OptionText = opt_text,
      DisplayText = display_text, DisplayOrder = order,
      ShowInOutput = "Y", stringsAsFactors = FALSE
    )
  }

  # SQ1 / SQ2: category options
  for (i in seq_along(IPK_CATEGORIES)) {
    c <- IPK_CATEGORIES[[i]]
    add_opt("SQ1", c$code, c$label, i)
    add_opt("SQ2", c$code, c$label, i)
  }
  add_opt("SQ1", "NONE", "None of the above", length(IPK_CATEGORIES) + 1L)

  # BRANDAWARE per cat: brand options + NONE
  for (cat_meta in IPK_CATEGORIES) {
    cat <- cat_meta$code
    qc <- paste0("BRANDAWARE_", cat)
    for (j in seq_along(IPK_BRANDS[[cat]])) {
      add_opt(qc, IPK_BRANDS[[cat]][j], IPK_BRANDS[[cat]][j], j)
    }
    add_opt(qc, "NONE", "None of these",
            length(IPK_BRANDS[[cat]]) + 1L)
  }

  # DSS BRANDATTR (CEP + ATT): brand options + NONE
  cat <- "DSS"
  for (item in c(IPK_CEPS_DSS, IPK_ATTS_DSS)) {
    qc <- paste0("BRANDATTR_", cat, "_", item$code)
    for (j in seq_along(IPK_BRANDS[[cat]])) {
      add_opt(qc, IPK_BRANDS[[cat]][j], IPK_BRANDS[[cat]][j], j)
    }
    add_opt(qc, "NONE", "None", length(IPK_BRANDS[[cat]]) + 1L)
  }

  # BRANDATT1 attitude codes
  for (b in IPK_BRANDS[[cat]]) {
    qc <- paste0("BRANDATT1_", cat, "_", b)
    for (k in seq_along(IPK_ATTITUDE_CODES)) {
      add_opt(qc, IPK_ATTITUDE_CODES[k],
              IPK_ATTITUDE_LABELS[[IPK_ATTITUDE_CODES[k]]], k)
    }
  }

  # WOM mention sets, brand options + NONE
  for (typ in c("WOM_POS_REC", "WOM_POS_SHARE",
                "WOM_NEG_REC", "WOM_NEG_SHARE")) {
    qc <- paste0(typ, "_", cat)
    for (j in seq_along(IPK_BRANDS[[cat]])) {
      add_opt(qc, IPK_BRANDS[[cat]][j], IPK_BRANDS[[cat]][j], j)
    }
    add_opt(qc, "NONE", "None", length(IPK_BRANDS[[cat]]) + 1L)
  }

  # WOM count codes per-brand
  for (b in IPK_BRANDS[[cat]]) {
    for (typ in c("WOM_POS_COUNT", "WOM_NEG_COUNT")) {
      qc <- paste0(typ, "_", cat, "_", b)
      for (k in seq_along(IPK_WOM_COUNT_CODES)) {
        add_opt(qc, IPK_WOM_COUNT_CODES[k],
                IPK_WOM_COUNT_LABELS[[IPK_WOM_COUNT_CODES[k]]], k)
      }
    }
  }

  # CATBUY codes
  qc <- paste0("CATBUY_", cat)
  for (k in seq_along(IPK_CATBUY_CODES)) {
    add_opt(qc, IPK_CATBUY_CODES[k],
            IPK_CATBUY_LABELS[[IPK_CATBUY_CODES[k]]], k)
  }

  # CHANNEL + PACK
  qc <- paste0("CHANNEL_", cat)
  for (j in seq_along(IPK_CHANNELS)) {
    ch <- IPK_CHANNELS[[j]]
    add_opt(qc, ch$code, ch$label, j)
  }
  qc <- paste0("PACK_", cat)
  for (j in seq_along(IPK_PACK_SIZES)) {
    pk <- IPK_PACK_SIZES[[j]]
    add_opt(qc, pk$code, pk$label, j)
  }

  # BRANDPEN1 / BRANDPEN2: brand options + NONE
  for (root in c("BRANDPEN1", "BRANDPEN2")) {
    qc <- paste0(root, "_", cat)
    for (j in seq_along(IPK_BRANDS[[cat]])) {
      add_opt(qc, IPK_BRANDS[[cat]][j], IPK_BRANDS[[cat]][j], j)
    }
    add_opt(qc, "NONE", "None of these",
            length(IPK_BRANDS[[cat]]) + 1L)
  }

  # BRANDPEN3: slot index = brand position from BRANDPEN2 piping; OptionText
  # is the brand at that slot for this fixture.
  qc <- paste0("BRANDPEN3_", cat)
  for (j in seq_along(IPK_BRANDS[[cat]])) {
    add_opt(qc, IPK_BRANDS[[cat]][j], IPK_BRANDS[[cat]][j], j)
  }

  # Demographic option codes: short
  for (key in c("DEMO_AGE", "DEMO_GENDER", "DEMO_PROVINCE",
                "DEMO_GROCERY_ROLE", "DEMO_HH_SIZE",
                "DEMO_EMPLOYMENT", "DEMO_SEM")) {
    dist <- get(paste0("IPK_", key))
    for (k in seq_along(dist$codes)) {
      add_opt(key, dist$codes[k], dist$labels[k], k)
    }
  }

  do.call(rbind, rows)
}

.ipk_build_brands_df <- function() {
  rows <- list()
  for (cat_meta in IPK_CATEGORIES) {
    cat <- cat_meta$code
    focal <- IPK_FOCAL_BRAND[[cat]]
    for (j in seq_along(IPK_BRANDS[[cat]])) {
      b <- IPK_BRANDS[[cat]][j]
      rows[[length(rows) + 1L]] <- data.frame(
        Category = cat_meta$label,
        CategoryCode = cat,
        BrandCode = b,
        BrandLabel = if (exists("IPK_BRAND_LABELS") && b %in% names(IPK_BRAND_LABELS))
          IPK_BRAND_LABELS[[b]] else b,
        DisplayOrder = j,
        IsFocal = if (b == focal) "Y" else "N",
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

.ipk_build_ceps_df <- function() {
  do.call(rbind, lapply(seq_along(IPK_CEPS_DSS), function(i) {
    item <- IPK_CEPS_DSS[[i]]
    data.frame(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
               CEPCode = item$code, CEPText = item$text,
               DisplayOrder = i, stringsAsFactors = FALSE)
  }))
}

.ipk_build_attrs_df <- function() {
  do.call(rbind, lapply(seq_along(IPK_ATTS_DSS), function(i) {
    item <- IPK_ATTS_DSS[[i]]
    data.frame(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
               AttrCode = item$code, AttrText = item$text,
               DisplayOrder = i, stringsAsFactors = FALSE)
  }))
}

.ipk_build_channels_df <- function() {
  do.call(rbind, lapply(seq_along(IPK_CHANNELS), function(i) {
    ch <- IPK_CHANNELS[[i]]
    data.frame(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
               ChannelCode = ch$code, ChannelLabel = ch$label,
               DisplayOrder = i, stringsAsFactors = FALSE)
  }))
}

.ipk_build_packs_df <- function() {
  do.call(rbind, lapply(seq_along(IPK_PACK_SIZES), function(i) {
    pk <- IPK_PACK_SIZES[[i]]
    data.frame(Category = "Dry Seasonings & Spices", CategoryCode = "DSS",
               PackCode = pk$code, PackLabel = pk$label,
               DisplayOrder = i, stringsAsFactors = FALSE)
  }))
}
