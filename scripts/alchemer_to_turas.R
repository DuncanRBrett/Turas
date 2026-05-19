# scripts/alchemer_to_turas.R
#
# Convert an Alchemer survey into populated Turas config templates via the v5 API.
#
# Outputs (written to output_dir):
#   All targets:
#     {survey_id}_Data_Headers.xlsx          — single row of Turas column codes
#                                              aligned 1:1 with the data export.
#     {survey_id}_data.xlsx                  — Turas-ready data file: raw export
#                                              with Data_Headers as the single
#                                              header row. Only when a data
#                                              export was provided.
#   targets includes "tabs":
#     {survey_id}_Survey_Structure.xlsx      — Questions + Options sheets populated
#     {survey_id}_Crosstab_Config.xlsx       — Selection sheet + full Settings copy
#   targets includes "brand":
#     {survey_id}_Survey_Structure_Brand.xlsx — Brand survey structure
#     {survey_id}_Brand_Config.xlsx           — Brand config with Categories +
#                                                survey-specific filenames
#                                                pre-filled
#
# Usage from R:
#   source("scripts/alchemer_to_turas.R")
#   alchemer_to_turas(8822527, "projects/my_project",
#                     targets = c("tabs", "brand"))
#
# Usage from CLI:
#   Rscript scripts/alchemer_to_turas.R <survey_id> <output_dir>

suppressPackageStartupMessages({
  library(openxlsx)
  library(data.table)
})

# Resolve Turas root: prefer TURAS_ROOT env var (set by launcher), fall back to cwd.
.att_turas_root <- function() {
  root <- Sys.getenv("TURAS_ROOT", "")
  if (nzchar(root) && dir.exists(file.path(root, "scripts"))) return(root)
  getwd()
}

source(file.path(.att_turas_root(), "scripts", "fetch_alchemer_reporting_values.R"))

# ---- constants ---------------------------------------------------------------

.att_ss_template <- function() file.path(.att_turas_root(), "modules", "tabs", "templates",
                                          "Survey_Structure_Template.xlsx")
.att_cc_template <- function() file.path(.att_turas_root(), "modules", "tabs", "templates",
                                          "Crosstab_Config_Template.xlsx")
.att_ss_brand_template <- function() file.path(.att_turas_root(), "modules", "brand", "templates",
                                                "Survey_Structure_Brand_Config_Template.xlsx")
.att_bc_template <- function() file.path(.att_turas_root(), "modules", "brand", "templates",
                                          "Brand_Config_Template.xlsx")

# Row where data begins (rows 1-4 are title/instructions/headers/descriptions)
.ATT_DATA_START_ROW <- 5L

.ATT_VALID_TARGETS <- c("tabs", "brand")

# Alchemer _type → Turas Variable_Type
.ATT_TYPE_MAP <- c(
  RADIO       = "Single_Response",
  CHECKBOX    = "Multi_Mention",
  RATING      = "Rating",
  LIKERT      = "Likert",
  NPS         = "NPS",
  RANKING     = "Ranking",
  TEXTBOX     = "Open_End",
  ESSAY       = "Open_End",
  NUMBER      = "Numeric",
  SLIDER      = "Numeric",
  DEMOGRAPHIC = "Single_Response",
  CONT_SUM    = "Allocation"
)

# Types with no survey output — omit from all sheets
.ATT_SKIP_TYPES <- c(
  "HIDDEN_VALUE", "HIDDEN", "CUSTOM_GROUP",
  "ACTION", "INSTRUCTIONS", "PAGE_TIMER",
  "LOGIC", "JAVASCRIPT"
)

# Option title patterns that trigger ExcludeFromIndex = Y on scored questions
.ATT_DK_REGEX <- paste(c(
  "don.?t know", "not sure", "\\bdk\\b",
  "\\bn/?a\\b", "not applicable", "not available",
  "prefer not", "refus", "\\bunsure\\b",
  "none of the above", "not stated", "\\bother\\b"
), collapse = "|")

# Variable types where CreateIndex defaults to Y
.ATT_INDEX_TYPES <- c("Rating", "Likert", "NPS")

# ---- helpers -----------------------------------------------------------------

.att_strip_html <- function(x) {
  if (is.na(x) || !nzchar(x)) return(x)
  x <- gsub("&amp;",   "&",  x, fixed = TRUE)
  x <- gsub("&lt;",    "<",  x, fixed = TRUE)
  x <- gsub("&gt;",    ">",  x, fixed = TRUE)
  x <- gsub("&quot;",  "\"", x, fixed = TRUE)
  x <- gsub("&#39;",   "'",  x, fixed = TRUE)
  x <- gsub("&nbsp;",  " ",  x, fixed = TRUE)
  x <- gsub("&ndash;", "–", x, fixed = TRUE)
  x <- gsub("&mdash;", "—", x, fixed = TRUE)
  x <- gsub("<[^>]+>", "", x, perl = TRUE)
  trimws(gsub("\\s+", " ", x))
}

# Strip leading "Type — text" prefix (em dash or spaced hyphen).
# e.g. "CEP — When I'm cooking" → "When I'm cooking"
# e.g. "Attribute — Good value" → "Good value"
.att_strip_label_prefix <- function(x) {
  for (sep in c(" — ", " - ")) {
    parts <- strsplit(x, sep, fixed = TRUE)[[1L]]
    if (length(parts) >= 2L) return(trimws(paste(parts[-1L], collapse = sep)))
  }
  x
}

.att_classify_type <- function(alchemer_type) {
  type_upper <- toupper(trimws(alchemer_type %||% ""))
  if (!nzchar(type_upper)) return("Single_Response")
  mapped <- .ATT_TYPE_MAP[type_upper]
  if (is.na(mapped)) {
    warning(sprintf(
      "Unknown Alchemer type '%s' — defaulting to Single_Response", alchemer_type
    ), call. = FALSE)
    return("Single_Response")
  }
  unname(mapped)
}

.att_should_skip <- function(alchemer_type) {
  toupper(trimws(alchemer_type %||% "")) %in% .ATT_SKIP_TYPES
}

.att_make_code <- function(shortname, question_id) {
  ifelse(
    !is.na(shortname) & nzchar(shortname),
    shortname,
    paste0("Q", question_id)
  )
}

# ---- build Questions sheet ---------------------------------------------------

.att_build_questions <- function(api_dt) {
  questions <- unique(api_dt[, .(question_id, question_shortname, question_title, question_type)])
  questions <- questions[!vapply(question_type, .att_should_skip, logical(1L))]
  if (nrow(questions) == 0L) stop("No processable questions found in survey.", call. = FALSE)

  questions[, QuestionCode  := .att_make_code(question_shortname, question_id)]
  questions[, Variable_Type := vapply(question_type, .att_classify_type, character(1L))]

  option_counts <- api_dt[!is.na(option_id), .(n_options = .N), by = question_id]
  questions <- option_counts[questions, on = "question_id"]
  questions[is.na(n_options), n_options := 0L]

  questions[, Columns := data.table::fcase(
    Variable_Type %in% c("Multi_Mention", "Ranking", "Allocation") & n_options > 0L, n_options,
    default = 1L
  )]

  dupes <- questions[duplicated(QuestionCode), QuestionCode]
  if (length(dupes) > 0L) {
    warning(sprintf(
      "Duplicate QuestionCode(s) detected: %s — check question_shortname values in Alchemer.",
      paste(unique(dupes), collapse = ", ")
    ), call. = FALSE)
  }

  data.table(
    QuestionCode      = questions$QuestionCode,
    QuestionText      = questions$question_title,
    Variable_Type     = questions$Variable_Type,
    Columns           = questions$Columns,
    Category          = NA_character_,
    Ranking_Format    = ifelse(questions$Variable_Type == "Ranking", "Position",    NA_character_),
    Ranking_Positions = ifelse(questions$Variable_Type == "Ranking", questions$Columns, NA_integer_),
    Ranking_Direction = ifelse(questions$Variable_Type == "Ranking", "BestToWorst", NA_character_),
    Min_Value         = NA_real_,
    Max_Value         = NA_real_,
    Notes             = NA_character_
  )
}

# ---- build Options sheet -----------------------------------------------------

# Single naming convention across all modules: positional Q_n suffix for every
# multi-column option (multi-mention, ranking, allocation). The brand module's
# `multi_mention_brand_matrix` and `slot_paired_numeric_matrix` expect exactly
# this layout — they read slot columns matching ^<root>_[0-9]+$ and scan the
# cell *values* for brand codes (the codes themselves come from the Brands
# sheet, not from column names). Tabs reads the same shape.
#
# `option_value` / `option_sku` are intentionally ignored when deriving the
# suffix; they survive in the OptionText column of Survey_Structure's Options
# sheet, which is what the brand module actually consults to know "slot index
# i corresponds to brand X".
.att_option_suffix <- function(shortname, option_value, opt_seq,
                                option_sku = NULL) {
  as.character(opt_seq)
}

.att_build_options <- function(api_dt, questions_dt) {
  q_lookup <- unique(api_dt[, .(question_id, question_shortname)])[
    questions_dt[, .(QuestionCode, Variable_Type)],
    on = c(question_shortname = "QuestionCode"),
    nomatch = NULL
  ]

  # Keep options where EITHER option_value or option_sku is populated. Allocation
  # (CONT_SUM) grids often leave option_value blank but set option_sku to the
  # brand code — without this fallback those questions emit zero option rows
  # and the brand module can't find the per-brand columns.
  opts <- api_dt[!is.na(option_id) &
                   (!is.na(option_value) | !is.na(option_sku))]
  if (nrow(opts) == 0L) opts <- data.table()

  if (nrow(opts) > 0L) {
    opts <- q_lookup[opts, on = "question_id", nomatch = NULL]
    opts[, opt_seq := seq_len(.N), by = question_id]
    # Per-house convention: brand questions use brand-code suffix (so the
    # brand module can look up BRANDPEN2_BAK_CHK by name), everything else
    # uses positional Q_n (so tabs and other downstream modules keep working).
    opts[, opt_suffix := .att_option_suffix(question_shortname, option_value,
                                             opt_seq, option_sku)]
    opts[, OptionQuestionCode := ifelse(
      Variable_Type %in% c("Multi_Mention", "Ranking", "Allocation"),
      paste0(question_shortname, "_", opt_suffix),
      question_shortname
    )]
  } else {
    opts <- data.table(
      question_id = character(0), question_shortname = character(0),
      Variable_Type = character(0), option_value = character(0),
      option_title = character(0), opt_seq = integer(0),
      OptionQuestionCode = character(0)
    )
  }

  # Per-brand fallback for Allocation / CONT_SUM grids that the Alchemer API
  # returns *without* an option list. These questions are typically per-brand
  # buy-frequency batteries (BRANDPEN3_<CAT>) — their column count and brand
  # codes are the same as the BRANDAWARE_<CAT> options. Synthesise rows so
  # Survey_Structure has something for the brand module to look up.
  alloc_qs <- questions_dt[Variable_Type == "Allocation", QuestionCode]
  for (alloc_code in alloc_qs) {
    if (alloc_code %in% opts$question_shortname) next  # already has options
    # Look for "BRANDPEN<N>_<CAT>" patterns; the sibling is BRANDAWARE_<CAT>
    cat_code <- sub("^BRAND[A-Z0-9]+_", "", alloc_code)
    aware_q <- opts[question_shortname == paste0("BRANDAWARE_", cat_code)]
    if (nrow(aware_q) == 0L) next
    synth <- data.table(
      question_id        = NA_character_,
      question_shortname = alloc_code,
      Variable_Type      = "Allocation",
      option_value       = aware_q$option_value,
      option_title       = aware_q$option_title,
      opt_seq            = aware_q$opt_seq,
      OptionQuestionCode = paste0(alloc_code, "_", aware_q$opt_suffix)
    )
    opts <- rbind(opts, synth, fill = TRUE)
  }

  if (nrow(opts) == 0L) return(data.table())

  opts[, ExcludeFromIndex := ifelse(
    Variable_Type %in% c("Rating", "Likert", "NPS") &
      grepl(.ATT_DK_REGEX, option_title, ignore.case = TRUE, perl = TRUE),
    "Y",
    NA_character_
  )]

  data.table(
    QuestionCode     = opts$OptionQuestionCode,
    OptionText       = opts$option_value,
    DisplayText      = opts$option_title,
    DisplayOrder     = opts$opt_seq,
    ShowInOutput     = "Y",
    ExcludeFromIndex = opts$ExcludeFromIndex,
    Index_Weight     = NA_real_,
    OptionValue      = NA_real_,
    BoxCategory      = NA_character_,
    Min              = NA_real_,
    Max              = NA_real_
  )
}

# ---- build Selection sheet ---------------------------------------------------

.att_build_selection <- function(questions_dt) {
  total_row <- data.table(
    QuestionCode      = "Total",
    Include           = "N",
    UseBanner         = "Y",
    BannerBoxCategory = NA_character_,
    BannerLabel       = "Total",
    DisplayOrder      = 1L,
    CreateIndex       = "N",
    BaseFilter        = NA_character_,
    FilterLabel       = NA_character_,
    QuestionText      = "Total (all respondents)"
  )

  question_rows <- data.table(
    QuestionCode      = questions_dt$QuestionCode,
    Include           = "N",
    UseBanner         = "N",
    BannerBoxCategory = NA_character_,
    BannerLabel       = NA_character_,
    DisplayOrder      = NA_integer_,
    CreateIndex       = ifelse(questions_dt$Variable_Type %in% .ATT_INDEX_TYPES, "Y", "N"),
    BaseFilter        = NA_character_,
    FilterLabel       = NA_character_,
    QuestionText      = questions_dt$QuestionText
  )

  rbindlist(list(total_row, question_rows), use.names = TRUE)
}

# ---- build Brand sheets ------------------------------------------------------

#' Extract Brands sheet from BRANDAWARE_{CAT} question options.
#' BrandCode = option_value (reporting code), BrandLabel = option_title (display name).
#' IsFocal defaults to N — analyst sets one Y per category.
# Extract a category display name from a BRANDAWARE_<CAT> question title.
# IPK titles read "Which of the following brands of <CATEGORY> have you heard
# of — even if you have never bought them?", so we lift the bit between
# "brands of" and "have you heard of". Falls back to the category code if the
# title doesn't match the pattern.
.att_category_name_from_aware <- function(question_title, cat_code) {
  if (is.null(question_title) || is.na(question_title) ||
      !nzchar(question_title)) return(cat_code)
  # Alchemer titles often contain U+00A0 (non-breaking space) where a normal
  # space would be expected — collapsing all whitespace to plain spaces lets
  # the regex match reliably.
  clean <- gsub("[[:space:] ]+", " ", question_title, perl = TRUE)
  m <- regmatches(
    clean,
    regexec("which of the following brands of (.+?) have you (heard|ever heard) of",
            clean, ignore.case = TRUE)
  )[[1L]]
  if (length(m) >= 2L) {
    candidate <- trimws(m[[2L]])
    if (nzchar(candidate) && nchar(candidate) < 80L) return(candidate)
  }
  cat_code
}

.att_build_brands <- function(api_dt) {
  aware_q <- unique(api_dt[
    grepl("^BRANDAWARE_", question_shortname, ignore.case = TRUE),
    .(question_id, question_shortname, question_title)
  ])
  if (nrow(aware_q) == 0L) {
    warning("No BRANDAWARE_* questions found — Brands sheet will be empty.", call. = FALSE)
    return(data.table(Category = character(), CategoryCode = character(),
                      BrandCode = character(), BrandLabel = character(),
                      DisplayOrder = integer(), IsFocal = character()))
  }

  rows <- lapply(seq_len(nrow(aware_q)), function(i) {
    q        <- aware_q[i]
    cat_code <- toupper(sub("^BRANDAWARE_", "", q$question_shortname, ignore.case = TRUE))
    cat_name <- .att_category_name_from_aware(q$question_title, cat_code)

    opts <- api_dt[question_id == q$question_id & !is.na(option_id) & !is.na(option_value)]
    if (nrow(opts) == 0L) return(NULL)

    opts[, opt_seq := seq_len(.N)]
    data.table(
      Category     = cat_name,
      CategoryCode = cat_code,
      BrandCode    = opts$option_value,
      BrandLabel   = opts$option_title,
      DisplayOrder = opts$opt_seq,
      IsFocal      = "N"
    )
  })
  data.table::rbindlist(Filter(Negate(is.null), rows), use.names = TRUE)
}

.att_resolve_cat_name <- function(cat_code, cat_map) {
  if (!is.null(cat_map) && cat_code %in% cat_map$CategoryCode) {
    cat_map[CategoryCode == cat_code, Category][[1L]]
  } else {
    cat_code
  }
}

#' Extract CEPs from both IPK naming conventions:
#'   * BRANDATTR_<CAT>_CEP<NN>  (DSS/PAS-style — per-CEP list-brands question)
#'   * BRANDCEP_<CAT><NN>       (BAK/POS-style — per-CEP list-brands question)
#' CEPText is taken from each question's title (the CEP statement itself).
.att_build_ceps <- function(api_dt, cat_map) {
  # Pattern A — DSS/PAS naming
  q_a <- unique(api_dt[
    grepl("^BRANDATTR_[^_]+_CEP", question_shortname, ignore.case = TRUE),
    .(question_id, question_shortname, question_title)
  ])
  # Pattern B — BAK/POS naming
  q_b <- unique(api_dt[
    grepl("^BRANDCEP_[A-Z]+[0-9]+$", question_shortname, ignore.case = TRUE),
    .(question_id, question_shortname, question_title)
  ])

  if (nrow(q_a) == 0L && nrow(q_b) == 0L) {
    warning("No CEP questions found (neither BRANDATTR_*_CEP* nor BRANDCEP_*) — CEPs sheet will be empty.",
            call. = FALSE)
    return(data.table(Category = character(), CategoryCode = character(),
                      CEPCode = character(), CEPText = character(), DisplayOrder = integer()))
  }

  rows_a <- lapply(seq_len(nrow(q_a)), function(i) {
    q     <- q_a[i]
    parts <- strsplit(q$question_shortname, "_", fixed = TRUE)[[1L]]
    cat_code <- toupper(parts[[2L]])
    cep_code <- paste(parts[seq(3L, length(parts))], collapse = "_")
    data.table(
      Category     = .att_resolve_cat_name(cat_code, cat_map),
      CategoryCode = cat_code,
      CEPCode      = cep_code,
      CEPText      = q$question_title
    )
  })

  rows_b <- lapply(seq_len(nrow(q_b)), function(i) {
    q <- q_b[i]
    m <- regmatches(q$question_shortname,
                    regexec("^BRANDCEP_([A-Z]+)([0-9]+)$", q$question_shortname,
                            ignore.case = TRUE))[[1L]]
    if (length(m) < 3L) return(NULL)
    cat_code <- toupper(m[[2L]])
    cep_num  <- m[[3L]]
    data.table(
      Category     = .att_resolve_cat_name(cat_code, cat_map),
      CategoryCode = cat_code,
      CEPCode      = paste0("CEP", cep_num),
      CEPText      = q$question_title
    )
  })

  cep_dt <- data.table::rbindlist(
    Filter(Negate(is.null), c(rows_a, rows_b)),
    use.names = TRUE
  )
  cep_dt[, DisplayOrder := seq_len(.N), by = CategoryCode]
  cep_dt
}

#' Extract Attributes from both IPK conventions:
#'   * BRANDATTR_<CAT>_ATT<NN>     (DSS/PAS-style — per-attribute list-brands;
#'                                  attribute text = question_title)
#'   * BRANDATT1_<CAT>_<BRAND>     (BAK/POS-style — per-brand list-attributes;
#'                                  attribute statements live in the question
#'                                  OPTIONS, so we pick the first such question
#'                                  per category and read its options as the
#'                                  attribute battery)
#' Open-end follow-ups (BRANDATT2_<CAT>_<BRAND>) are intentionally skipped —
#' those are avoidance reasons, not an attribute battery.
.att_build_attributes <- function(api_dt, cat_map) {
  # Pattern A — DSS/PAS naming
  q_a <- unique(api_dt[
    grepl("^BRANDATTR_[^_]+_ATT", question_shortname, ignore.case = TRUE),
    .(question_id, question_shortname, question_title)
  ])
  # Pattern B — BAK/POS naming: one question per brand, attributes are options.
  # We collapse to ONE representative question per category (the first).
  q_b_all <- unique(api_dt[
    grepl("^BRANDATT1_[A-Z]+_", question_shortname, ignore.case = TRUE),
    .(question_id, question_shortname, question_title)
  ])
  if (nrow(q_b_all) > 0L) {
    q_b_all[, cat_code := toupper(sub("^BRANDATT1_([A-Z]+)_.*$", "\\1",
                                       question_shortname, ignore.case = TRUE))]
    q_b <- q_b_all[, .SD[1L], by = cat_code]
  } else {
    q_b <- data.table(cat_code = character(0), question_id = character(0))
  }

  if (nrow(q_a) == 0L && nrow(q_b) == 0L) {
    warning("No attribute questions found (neither BRANDATTR_*_ATT* nor BRANDATT1_*) — Attributes sheet will be empty.",
            call. = FALSE)
    return(data.table(Category = character(), CategoryCode = character(),
                      AttrCode = character(), AttrText = character(), DisplayOrder = integer()))
  }

  rows_a <- lapply(seq_len(nrow(q_a)), function(i) {
    q         <- q_a[i]
    parts     <- strsplit(q$question_shortname, "_", fixed = TRUE)[[1L]]
    cat_code  <- toupper(parts[[2L]])
    attr_code <- paste(parts[seq(3L, length(parts))], collapse = "_")
    data.table(
      Category     = .att_resolve_cat_name(cat_code, cat_map),
      CategoryCode = cat_code,
      AttrCode     = attr_code,
      AttrText     = q$question_title
    )
  })

  rows_b <- lapply(seq_len(nrow(q_b)), function(i) {
    q        <- q_b[i]
    cat_code <- q$cat_code
    opts <- api_dt[question_id == q$question_id & !is.na(option_id) &
                     !is.na(option_value)]
    if (nrow(opts) == 0L) return(NULL)
    opts[, opt_seq := seq_len(.N)]
    data.table(
      Category     = .att_resolve_cat_name(cat_code, cat_map),
      CategoryCode = cat_code,
      AttrCode     = sprintf("ATT%02d", opts$opt_seq),
      AttrText     = opts$option_title
    )
  })

  attr_dt <- data.table::rbindlist(
    Filter(Negate(is.null), c(rows_a, rows_b)),
    use.names = TRUE
  )
  attr_dt[, DisplayOrder := seq_len(.N), by = CategoryCode]
  attr_dt
}

#' Build Categories data for Brand_Config.xlsx from the Brands sheet.
.att_build_categories <- function(brands_dt) {
  if (nrow(brands_dt) == 0L) {
    return(data.table(Category = character(), CategoryCode = character(),
                      Active = character(), Type = character(), Analysis_Depth = character()))
  }
  cats <- unique(brands_dt[, .(Category, CategoryCode)])
  cats[, `:=`(Active = "Y", Type = "transaction", Analysis_Depth = "full")]
  cats
}

# ---- write helpers -----------------------------------------------------------

# Clear example data rows from a sheet, preserving header rows 1-4.
# Uses max(n_cols, actual sheet width) so sheets with more columns than the
# written data (e.g. Brand_Config Categories) are fully cleared.
.att_clear_examples <- function(wb, sheet_name, n_cols) {
  existing <- tryCatch(
    openxlsx::read.xlsx(wb, sheet = sheet_name, colNames = FALSE, skipEmptyRows = FALSE),
    error = function(e) NULL
  )
  if (is.null(existing) || nrow(existing) < .ATT_DATA_START_ROW) return(invisible(NULL))

  example_rows <- seq(.ATT_DATA_START_ROW, nrow(existing))
  openxlsx::deleteData(
    wb, sheet = sheet_name,
    cols = seq_len(max(n_cols, ncol(existing))),
    rows = example_rows,
    gridExpand = TRUE
  )
}

.att_write_survey_structure <- function(questions_dt, options_dt, output_path) {
  wb <- openxlsx::loadWorkbook(.att_ss_template())

  .att_clear_examples(wb, "Questions", n_cols = ncol(questions_dt))
  openxlsx::writeData(wb, "Questions", questions_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)

  .att_clear_examples(wb, "Options", n_cols = ncol(options_dt))
  if (nrow(options_dt) > 0L) {
    openxlsx::writeData(wb, "Options", options_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)
  }

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}

.att_write_crosstab_config <- function(selection_dt, output_path) {
  wb <- openxlsx::loadWorkbook(.att_cc_template())

  .att_clear_examples(wb, "Selection", n_cols = ncol(selection_dt))
  openxlsx::writeData(wb, "Selection", selection_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}

.att_write_brand_survey_structure <- function(questions_dt, options_dt,
                                               brands_dt, ceps_dt, attrs_dt,
                                               output_path,
                                               attitude_optionmap_dt = NULL) {
  wb <- openxlsx::loadWorkbook(.att_ss_brand_template())

  .att_clear_examples(wb, "Questions", n_cols = ncol(questions_dt))
  openxlsx::writeData(wb, "Questions", questions_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)

  .att_clear_examples(wb, "Options", n_cols = ncol(options_dt))
  if (nrow(options_dt) > 0L) {
    openxlsx::writeData(wb, "Options", options_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)
  }

  .att_clear_examples(wb, "Brands", n_cols = ncol(brands_dt))
  if (nrow(brands_dt) > 0L) {
    openxlsx::writeData(wb, "Brands", brands_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)
  }

  .att_clear_examples(wb, "CEPs", n_cols = ncol(ceps_dt))
  if (nrow(ceps_dt) > 0L) {
    openxlsx::writeData(wb, "CEPs", ceps_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)
  }

  .att_clear_examples(wb, "Attributes", n_cols = ncol(attrs_dt))
  if (nrow(attrs_dt) > 0L) {
    openxlsx::writeData(wb, "Attributes", attrs_dt, startRow = .ATT_DATA_START_ROW, colNames = FALSE)
  }

  # OptionMap: overwrite the template's attitude_scale rows with whatever scale
  # the actual survey uses. This is what makes the brand funnel module treat
  # code 4 as Price (vs Avoid) on the 6-level IPK 2026 scale automatically —
  # without it the analyst has to hand-edit the OptionMap to match.
  if (!is.null(attitude_optionmap_dt) && nrow(attitude_optionmap_dt) > 0L) {
    .att_overwrite_attitude_optionmap(wb, attitude_optionmap_dt)
  }

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}

# Map attitude option text to a canonical role token. Order-sensitive — earlier
# patterns win — so we put narrower expressions first (e.g. "price" before the
# generic "right").
.ATT_ATTITUDE_ROLE_PATTERNS <- list(
  list(role = "love",       pat = "love|favourite|favorite"),
  list(role = "prefer",     pat = "prefer"),
  list(role = "price",      pat = "price"),
  list(role = "avoid",      pat = "avoid|refuse|reject"),
  list(role = "no_opinion", pat = "no opinion|don.?t know|don.?t have an opinion|never heard"),
  list(role = "ambivalent", pat = "no other option|nothing else|only consider|acceptable|wouldn.?t usually|if no alternative")
)

.att_infer_attitude_role <- function(option_text) {
  if (is.null(option_text) || is.na(option_text) || !nzchar(option_text)) {
    return(NA_character_)
  }
  text_lc <- tolower(option_text)
  for (p in .ATT_ATTITUDE_ROLE_PATTERNS) {
    if (grepl(p$pat, text_lc, perl = TRUE)) return(p$role)
  }
  NA_character_
}

#' Build an OptionMap dt for the attitude_scale from the first per-brand
#' attitude question (BRANDATT1_<cat>_<brand>). One row per option, ordered
#' by position. Roles inferred from option text via keyword matching; any
#' option whose role can't be inferred is still emitted with role = NA so the
#' analyst can fill it in by hand.
#'
#' @keywords internal
.att_build_attitude_optionmap <- function(api_dt) {
  q <- unique(api_dt[
    grepl("^BRANDATT1_[A-Z]+_", question_shortname, ignore.case = TRUE),
    .(question_id)
  ])
  if (nrow(q) == 0L) return(NULL)
  first_q <- q$question_id[[1L]]
  opts <- api_dt[question_id == first_q & !is.na(option_id) & !is.na(option_value)]
  if (nrow(opts) == 0L) return(NULL)
  opts[, opt_seq := seq_len(.N)]

  roles <- vapply(opts$option_title, .att_infer_attitude_role,
                  character(1L), USE.NAMES = FALSE)
  data.table(
    Scale       = "attitude_scale",
    ClientCode  = as.character(opts$option_value),
    Role        = ifelse(is.na(roles), NA_character_,
                          paste0("attitude_scale.", roles)),
    ClientLabel = opts$option_title,
    OrderIndex  = opts$opt_seq
  )
}

# Wipe the attitude_scale rows currently in the OptionMap template (rows 5+)
# and write the freshly-inferred ones in their place, preserving every other
# scale block (cat_buy_scale, reach_seen_scale, etc.).
.att_overwrite_attitude_optionmap <- function(wb, new_rows) {
  existing <- tryCatch(
    openxlsx::read.xlsx(wb, sheet = "OptionMap",
                        startRow = .ATT_DATA_START_ROW, colNames = FALSE,
                        skipEmptyRows = FALSE),
    error = function(e) NULL
  )
  keep <- if (is.null(existing) || nrow(existing) == 0L) {
    data.table()
  } else {
    as.data.table(existing)[!grepl("^attitude_scale", as.character(get("X1")),
                                    ignore.case = TRUE)]
  }
  # Coerce both blocks to a common 5-column shape (Scale, ClientCode, Role,
  # ClientLabel, OrderIndex) before stacking.
  to_block <- function(dt) {
    if (is.null(dt) || nrow(dt) == 0L) {
      return(data.table(Scale = character(0), ClientCode = character(0),
                        Role = character(0), ClientLabel = character(0),
                        OrderIndex = integer(0)))
    }
    if (!"Scale" %in% names(dt)) {
      setnames(dt, paste0("X", seq_len(ncol(dt))))
      dt <- dt[, .(Scale = as.character(X1), ClientCode = as.character(X2),
                   Role  = as.character(X3), ClientLabel = as.character(X4),
                   OrderIndex = suppressWarnings(as.integer(X5)))]
    }
    dt
  }
  combined <- rbind(to_block(keep), to_block(new_rows), use.names = TRUE, fill = TRUE)
  .att_clear_examples(wb, "OptionMap", n_cols = 5L)
  openxlsx::writeData(wb, "OptionMap", combined,
                      startRow = .ATT_DATA_START_ROW, colNames = FALSE)
}

.att_write_brand_config <- function(categories_dt, output_path, survey_id) {
  wb <- openxlsx::loadWorkbook(.att_bc_template())

  .att_clear_examples(wb, "Categories", n_cols = ncol(categories_dt))
  if (nrow(categories_dt) > 0L) {
    openxlsx::writeData(wb, "Categories", categories_dt,
                        startRow = .ATT_DATA_START_ROW, colNames = FALSE)
  }

  # Pre-populate the Settings sheet with survey-specific defaults so the
  # analyst doesn't have to type filenames the script already knows. Anything
  # not in this list keeps the template's default value.
  #
  # `data_file` is a *suggested filename* — the analyst saves their cleaned
  # data file (with the Data_Headers row pasted as the top row) under exactly
  # this name in the same folder, and it just works.
  defaults <- list(
    project_name   = sprintf("Survey %s", survey_id),
    data_file      = sprintf("%s_data.xlsx", survey_id),
    structure_file = sprintf("%s_Survey_Structure_Brand.xlsx", survey_id),
    output_html    = "Y"
  )
  .att_fill_brand_settings(wb, defaults)

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}

# Write values into the Settings sheet's Value column by matching on the
# Setting name in column A. Silently skips names not present in the template.
.att_fill_brand_settings <- function(wb, settings) {
  s_raw <- openxlsx::readWorkbook(wb, sheet = "Settings", colNames = FALSE,
                                  skipEmptyRows = FALSE)
  setting_names <- trimws(as.character(s_raw[[1]]))
  for (nm in names(settings)) {
    row_idx <- which(setting_names == nm)
    if (length(row_idx) == 1L) {
      openxlsx::writeData(wb, "Settings", settings[[nm]],
                          startRow = row_idx, startCol = 2L, colNames = FALSE)
    }
  }
}

#' Locate the Alchemer header row in a data export
#'
#' Alchemer exports may have one or more rows above the data — sometimes just
#' the standard header, sometimes prefixed with manually-added Turas codes or
#' blank separators. We scan the first few rows and pick the one with the most
#' "<option>:<question_label>" colon-format cells, which is the unambiguous
#' fingerprint of Alchemer's actual header row.
#'
#' Returns a list with `row_index` (1-based, into the worksheet) and `values`
#' (character vector of cell contents for that row).
#'
#' @keywords internal
.att_detect_alchemer_header_row <- function(data_export_path, max_scan = 5L) {
  ext <- tolower(tools::file_ext(data_export_path))
  if (ext == "csv") {
    h <- names(data.table::fread(data_export_path, nrows = 0L, header = TRUE))
    return(list(row_index = 1L, values = h))
  }
  block <- openxlsx::read.xlsx(data_export_path, sheet = 1L,
                               rows = seq_len(max_scan), colNames = FALSE,
                               skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  best <- list(row_index = 1L, n_colon = -1L, values = character(0))
  for (i in seq_len(nrow(block))) {
    vals    <- as.character(block[i, ])
    n_colon <- sum(grepl(":", vals, fixed = TRUE), na.rm = TRUE)
    if (n_colon > best$n_colon) {
      best <- list(row_index = i, n_colon = n_colon, values = vals)
    }
  }
  list(row_index = best$row_index, values = best$values)
}

# Normalise a key for lookup: strip HTML, collapse whitespace, lowercase,
# canonicalise smart-quote / dash variants. This makes the Alchemer colon
# headers (often HTML-rich) match the API option strings.
.att_norm_key <- function(x) {
  if (is.null(x)) return(character(0))
  out <- as.character(x)
  out <- ifelse(is.na(out), "", out)
  # Inline (vectorised) HTML strip — .att_strip_html is scalar.
  out <- gsub("&amp;",   "&",  out, fixed = TRUE)
  out <- gsub("&lt;",    "<",  out, fixed = TRUE)
  out <- gsub("&gt;",    ">",  out, fixed = TRUE)
  out <- gsub("&quot;",  "\"", out, fixed = TRUE)
  out <- gsub("&#39;",   "'",  out, fixed = TRUE)
  out <- gsub("&nbsp;",  " ",  out, fixed = TRUE)
  out <- gsub("&ndash;", "-",  out, fixed = TRUE)
  out <- gsub("&mdash;", "-",  out, fixed = TRUE)
  out <- gsub("<[^>]+>", "",   out, perl  = TRUE)
  # Smart-quote / dash normalisation so "Ina Paarman's" matches "Ina Paarman’s"
  out <- gsub("[‘’‚‛]", "'", out, perl = TRUE)
  out <- gsub("[“”„‟]", "\"", out, perl = TRUE)
  out <- gsub("[‐‑‒–—―]", "-", out, perl = TRUE)
  out <- gsub("\\s+", " ", out, perl = TRUE)
  tolower(trimws(out))
}

#' Build the export → Turas code lookup table
#'
#' One row per (question, option). Used to resolve Alchemer colon-format
#' headers ("<option_text>:<question_label>") to Turas option codes
#' ("<shortname>_<position>").
#'
#' @keywords internal
.att_build_translation_lookup <- function(api_dt, questions_dt) {
  opts <- api_dt[!is.na(option_id) &
                   (!is.na(option_value) | !is.na(option_sku) |
                      !is.na(option_title))]
  if (nrow(opts) == 0L) {
    return(data.table::data.table(
      q_key = character(0), opt_key = character(0), turas_code = character(0)
    ))
  }
  opts <- data.table::copy(opts)
  opts[, opt_seq    := seq_len(.N), by = question_id]
  opts[, q_title_lc := .att_norm_key(question_title)]
  opts[, q_short_lc := .att_norm_key(question_shortname)]
  opts[, opt_t_lc   := .att_norm_key(option_title)]
  opts[, opt_v_lc   := .att_norm_key(option_value)]
  opts[, opt_sku_lc := .att_norm_key(option_sku)]

  # Per-question Turas QuestionCode (Multi_Mention/Ranking/Allocation → shortname_N;
  # other types → shortname). We use this as the base code so the result matches
  # exactly what Survey_Structure declares.
  q_meta <- questions_dt[, .(q_short_lc = tolower(trimws(QuestionCode)),
                             vtype      = Variable_Type)]
  opts <- q_meta[opts, on = "q_short_lc", nomatch = NA]

  # Suffix MUST match what .att_build_options writes into Survey_Structure —
  # otherwise data column names won't line up with the structure's QuestionCodes.
  # Same per-house convention: brand questions = brand-code, others = position.
  opts[, opt_suffix := .att_option_suffix(question_shortname, option_value,
                                           opt_seq, option_sku)]
  opts[, turas_code := ifelse(
    vtype %in% .ATT_MULTI_COL_VTYPES,
    paste0(question_shortname, "_", opt_suffix),
    question_shortname
  )]

  # Allocation-grid fallback (mirrors .att_build_options): for each
  # Allocation question without API options, borrow the brand list from the
  # sibling BRANDAWARE_<CAT> question so the data translator can resolve
  # colon-format export headers like "Knorr:BRANDPEN3_BAK".
  alloc_short <- questions_dt[Variable_Type == "Allocation", QuestionCode]
  for (alloc_code in alloc_short) {
    if (alloc_code %in% opts$question_shortname) next
    cat_code <- sub("^BRAND[A-Z0-9]+_", "", alloc_code)
    aware   <- opts[question_shortname == paste0("BRANDAWARE_", cat_code)]
    if (nrow(aware) == 0L) next
    synth <- aware[, .(
      question_id        = NA_character_,
      question_shortname = alloc_code,
      question_title     = NA_character_,
      question_type      = "CONT_SUM",
      option_id          = option_id,
      option_sku         = option_sku,
      option_value       = option_value,
      option_title       = option_title,
      opt_seq            = opt_seq,
      q_title_lc         = "",
      q_short_lc         = .att_norm_key(alloc_code),
      opt_t_lc           = opt_t_lc,
      opt_v_lc           = opt_v_lc,
      opt_sku_lc         = opt_sku_lc,
      vtype              = "Allocation",
      opt_suffix         = opt_suffix,
      turas_code         = paste0(alloc_code, "_", opt_suffix)
    )]
    opts <- rbind(opts, synth, fill = TRUE)
  }

  # Long table — one row per (q_key, opt_key, turas_code) covering every
  # plausible matching key for the colon-format export header.
  pairs <- list(
    opts[nzchar(q_short_lc) & nzchar(opt_t_lc),
         .(q_key = q_short_lc, opt_key = opt_t_lc,   turas_code)],
    opts[nzchar(q_short_lc) & nzchar(opt_v_lc),
         .(q_key = q_short_lc, opt_key = opt_v_lc,   turas_code)],
    opts[nzchar(q_short_lc) & nzchar(opt_sku_lc),
         .(q_key = q_short_lc, opt_key = opt_sku_lc, turas_code)],
    opts[nzchar(q_title_lc) & nzchar(opt_t_lc),
         .(q_key = q_title_lc, opt_key = opt_t_lc,   turas_code)],
    opts[nzchar(q_title_lc) & nzchar(opt_v_lc),
         .(q_key = q_title_lc, opt_key = opt_v_lc,   turas_code)],
    opts[nzchar(q_title_lc) & nzchar(opt_sku_lc),
         .(q_key = q_title_lc, opt_key = opt_sku_lc, turas_code)]
  )
  rbindlist(pairs, fill = TRUE)[
    !duplicated(paste(q_key, opt_key, sep = "▁"))]
}

#' Translate one Alchemer header cell to a Turas code
#'
#' Order of resolution:
#'   1. Colon-format "<option>:<label>" → lookup by question label + option text.
#'   2. Cell matches a Survey_Structure QuestionCode → keep verbatim.
#'   3. Cell matches a question_title → use that question's QuestionCode.
#'   4. Cell matches a known Alchemer metadata header → normalised passthrough.
#'   5. Anything else → original cell, with a flag for the warning count.
#'
#' Returns a list(code, resolved) so the caller can tally resolution stats.
#'
#' @keywords internal
.att_translate_one <- function(cell, lookup, code_index, title_index, meta_index) {
  if (is.na(cell) || !nzchar(cell)) return(list(code = cell, resolved = FALSE))
  cell_clean <- sub("^﻿", "", cell)            # strip BOM
  cell_clean <- gsub("^\"|\"$", "", cell_clean)     # strip wrapping quotes
  key_full   <- .att_norm_key(cell_clean)

  if (grepl(":", cell_clean, fixed = TRUE)) {
    parts <- strsplit(cell_clean, ":", fixed = TRUE)[[1L]]
    label <- parts[[length(parts)]]
    text  <- paste(parts[-length(parts)], collapse = ":")
    hit   <- lookup[q_key == .att_norm_key(label) &
                    opt_key == .att_norm_key(text)]
    if (nrow(hit) == 1L) return(list(code = hit$turas_code, resolved = TRUE))
  }

  if (!is.null(code_index[[key_full]])) {
    return(list(code = code_index[[key_full]], resolved = TRUE))
  }
  if (!is.null(title_index[[key_full]])) {
    return(list(code = title_index[[key_full]], resolved = TRUE))
  }
  if (!is.null(meta_index[[key_full]])) {
    return(list(code = meta_index[[key_full]], resolved = TRUE))
  }
  list(code = cell_clean, resolved = FALSE)
}

# Standard Alchemer metadata column names → tidier passthrough labels
.ATT_META_MAP <- c(
  "response id"    = "ResponseID",
  "time started"   = "TimeStarted",
  "date submitted" = "DateSubmitted",
  "status"         = "Status",
  "contact id"     = "ContactID",
  "legacy comments"= "LegacyComments",
  "comments"       = "Comments",
  "language"       = "Language",
  "referer"        = "Referer",
  "sessionid"      = "SessionID",
  "user agent"     = "UserAgent",
  "tags"           = "Tags",
  "ip address"     = "IPAddress",
  "longitude"      = "Longitude",
  "latitude"       = "Latitude",
  "country"        = "Country",
  "city"           = "City",
  "state/region"   = "StateRegion",
  "postal"         = "Postal",
  "url variable: id" = "URL_id",
  "id"             = "URL_id",
  "wave"           = "Wave"
)

#' Write Data_Headers.xlsx aligned to the Alchemer data export
#'
#' One row, one cell per export column, each cell holds the Survey_Structure
#' QuestionCode that owns that column (or a tidy passthrough for Alchemer
#' metadata cols). When no export is provided, falls back to a pure
#' Survey_Structure layout (one cell per QuestionCode) and warns.
#'
#' @keywords internal
.att_write_data_headers <- function(questions_dt, options_dt, api_dt,
                                    output_path, data_export_path = NULL) {

  use_export <- !is.null(data_export_path) && nzchar(data_export_path) &&
                file.exists(data_export_path)

  if (!use_export) {
    headers <- .att_build_data_headers_structure_only(questions_dt)
    .att_save_headers_workbook(headers, output_path)
    cat(sprintf(
      "  Data_Headers: %d cells (structure-only fallback; no data export provided)\n",
      length(headers)))
    return(invisible(headers))
  }

  detected <- .att_detect_alchemer_header_row(data_export_path)
  alch_row <- detected$values
  cat(sprintf("  Alchemer header detected on worksheet row %d (%d cells, %d colon-format)\n",
              detected$row_index, length(alch_row),
              sum(grepl(":", alch_row, fixed = TRUE), na.rm = TRUE)))

  lookup      <- .att_build_translation_lookup(api_dt, questions_dt)
  code_index  <- setNames(as.list(questions_dt$QuestionCode),
                          .att_norm_key(questions_dt$QuestionCode))
  title_index <- setNames(as.list(questions_dt$QuestionCode),
                          .att_norm_key(questions_dt$QuestionText))
  meta_index  <- setNames(as.list(unname(.ATT_META_MAP)),
                          .att_norm_key(names(.ATT_META_MAP)))

  out <- character(length(alch_row))
  resolved_flags <- logical(length(alch_row))
  for (i in seq_along(alch_row)) {
    res <- .att_translate_one(alch_row[i], lookup, code_index, title_index, meta_index)
    out[i] <- res$code %||% NA_character_
    resolved_flags[i] <- res$resolved
  }

  # Disambiguate any duplicate codes by suffixing _dupN so column names stay unique
  if (anyDuplicated(out) > 0L) {
    tab <- table(out)
    dup_codes <- names(tab[tab > 1L])
    for (code in dup_codes) {
      idx <- which(out == code)
      out[idx] <- paste0(code, c("", paste0("_dup", seq_len(length(idx) - 1L))))
    }
    warning(sprintf("Duplicate Turas codes encountered (suffixed with _dupN): %s",
                    paste(dup_codes, collapse = ", ")), call. = FALSE)
  }

  .att_save_headers_workbook(out, output_path)

  n_total      <- length(out)
  n_resolved   <- sum(resolved_flags)
  n_colon_in   <- sum(grepl(":", alch_row, fixed = TRUE), na.rm = TRUE)
  n_unresolved <- n_total - n_resolved
  cat(sprintf(
    "  Data_Headers: %d cells aligned to export | %d resolved to Turas codes | %d passthrough / unresolved\n",
    n_total, n_resolved, n_unresolved))
  if (n_unresolved > 0L) {
    unresolved <- alch_row[!resolved_flags & !is.na(alch_row) & nzchar(alch_row)]
    show <- head(unique(unresolved), 6)
    cat(sprintf("    Unresolved sample (%d unique shown): %s\n",
                length(show), paste(sprintf("\"%s\"", substr(show, 1, 50)),
                                    collapse = ", ")))
  }
  invisible(out)
}

# Fallback used when no data export is given: one cell per Survey_Structure
# QuestionCode (Multi/Ranking/Allocation get one cell per option).
.att_build_data_headers_structure_only <- function(questions_dt) {
  per_q <- vector("list", nrow(questions_dt))
  for (i in seq_len(nrow(questions_dt))) {
    code  <- questions_dt$QuestionCode[[i]]
    vtype <- questions_dt$Variable_Type[[i]]
    n_col <- questions_dt$Columns[[i]]
    per_q[[i]] <- if (vtype %in% .ATT_MULTI_COL_VTYPES && !is.na(n_col) && n_col > 1L) {
      paste0(code, "_", seq_len(n_col))
    } else {
      code
    }
  }
  unlist(per_q, use.names = FALSE)
}

.att_save_headers_workbook <- function(headers, output_path) {
  if (length(headers) == 0L) {
    warning("No headers to write — Data_Headers skipped.", call. = FALSE)
    return(invisible(NULL))
  }
  header_dt <- as.data.table(setNames(as.list(headers), headers))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Headers")
  openxlsx::writeData(wb, "Headers", header_dt, startRow = 1L, colNames = TRUE)
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}

#' Write a Turas-ready data file from the raw Alchemer export
#'
#' Strips the Alchemer multi-row header, swaps in the single-row Turas code
#' header produced by `.att_write_data_headers`, and writes the result as
#' `<survey_id>_data.xlsx` — exactly the filename the generated Brand_Config
#' defaults to. So once AlchemerExport finishes the analyst can run the brand
#' / tabs module immediately without any manual header paste.
#'
#' Column counts that don't match (export wider than Data_Headers, or vice
#' versa) get logged as a warning and the file is trimmed to the smaller of
#' the two — better to produce a usable file with a clear log line than fail.
#'
#' @keywords internal
.att_write_turas_ready_data <- function(data_export_path, turas_headers,
                                        output_path) {
  detected   <- .att_detect_alchemer_header_row(data_export_path)
  header_row <- detected$row_index
  ext        <- tolower(tools::file_ext(data_export_path))

  if (ext == "csv") {
    all <- data.table::fread(data_export_path, header = FALSE)
  } else {
    all <- openxlsx::read.xlsx(data_export_path, sheet = 1L, colNames = FALSE,
                               skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  }
  if (is.null(all) || nrow(all) <= header_row) {
    warning("No data rows found below the detected header — data file skipped.",
            call. = FALSE)
    return(invisible(NULL))
  }

  data_rows <- all[(header_row + 1L):nrow(all), , drop = FALSE]
  n_export  <- ncol(data_rows)
  n_hdr     <- length(turas_headers)

  if (n_export != n_hdr) {
    warning(sprintf(
      "Column count mismatch: export has %d cols, Data_Headers has %d — data file trimmed to %d.",
      n_export, n_hdr, min(n_export, n_hdr)), call. = FALSE)
  }
  n <- min(n_export, n_hdr)
  data_rows <- data_rows[, seq_len(n), drop = FALSE]
  names(data_rows) <- turas_headers[seq_len(n)]

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", data_rows, startRow = 1L, colNames = TRUE)
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("  Turas-ready data: %d records x %d columns\n",
              nrow(data_rows), ncol(data_rows)))
  invisible(output_path)
}

# Variable_Type values in Survey_Structure that produce one data column per option.
.ATT_MULTI_COL_VTYPES <- c("Multi_Mention", "Ranking", "Allocation")

# ---- main --------------------------------------------------------------------

#' Convert an Alchemer survey into populated Turas config templates
#'
#' Fetches question and option structure from the Alchemer v5 API and writes
#' pre-populated config workbooks ready for analyst review.
#'
#' @param survey_id Integer or character Alchemer survey ID.
#' @param output_dir Path to output directory. Created if it does not exist.
#' @param api_token  Optional API token. Defaults to ALCHEMER_API_TOKEN env var.
#' @param api_secret Optional API secret. Defaults to ALCHEMER_API_SECRET env var.
#' @param targets Character vector of module targets. Valid values: "tabs", "brand".
#'   Defaults to "tabs". Pass c("tabs", "brand") to generate both.
#' @param data_export_path Optional path to an Alchemer data export (CSV or
#'   XLSX). When provided, Data_Headers is built with one cell per export
#'   column and each cell holds the Survey_Structure QuestionCode that owns
#'   that column (colon-format Alchemer cells are translated via the API
#'   option list; metadata cells are passed through with tidy names). Without
#'   an export, falls back to a row of QuestionCodes mirroring Survey_Structure.
#' @return Invisibly, a named list of paths for files written. Always includes
#'   `data_headers`.
#' @export
alchemer_to_turas <- function(survey_id,
                               output_dir,
                               api_token        = NULL,
                               api_secret       = NULL,
                               targets          = "tabs",
                               data_export_path = NULL) {
  if (missing(survey_id) || !nzchar(as.character(survey_id))) {
    stop("survey_id is required.", call. = FALSE)
  }
  if (missing(output_dir) || !nzchar(output_dir)) {
    stop("output_dir is required.", call. = FALSE)
  }

  targets <- tolower(trimws(targets))
  bad <- setdiff(targets, .ATT_VALID_TARGETS)
  if (length(bad) > 0L) {
    stop(sprintf("Unknown target(s): %s. Valid: %s",
                 paste(bad, collapse = ", "),
                 paste(.ATT_VALID_TARGETS, collapse = ", ")), call. = FALSE)
  }
  if (length(targets) == 0L) stop("targets must not be empty.", call. = FALSE)

  survey_id  <- as.character(survey_id)
  output_dir <- path.expand(output_dir)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # Validate templates for selected targets
  templates_needed <- c(
    if ("tabs"  %in% targets) c(.att_ss_template(), .att_cc_template()),
    if ("brand" %in% targets) c(.att_ss_brand_template(), .att_bc_template())
  )
  missing_tpls <- templates_needed[!file.exists(templates_needed)]
  if (length(missing_tpls) > 0L) {
    stop(sprintf("Template(s) not found:\n%s\n  Run from the Turas project root.",
                 paste0("  ", missing_tpls, collapse = "\n")), call. = FALSE)
  }

  cat(sprintf("Fetching survey %s from Alchemer API...\n", survey_id))
  api_dt <- fetch_alchemer_reporting_values(
    survey_id  = survey_id,
    api_token  = api_token,
    api_secret = api_secret
  )
  cat(sprintf("  %d questions | %d options retrieved\n",
              length(unique(api_dt$question_id)),
              nrow(api_dt[!is.na(option_id)])))

  api_dt[, question_title := vapply(question_title, .att_strip_html, character(1L))]
  api_dt[, option_title   := vapply(option_title,   .att_strip_html, character(1L))]

  cat("Building config sheets...\n")
  questions_dt <- .att_build_questions(api_dt)
  options_dt   <- .att_build_options(api_dt, questions_dt)
  selection_dt <- .att_build_selection(questions_dt)

  cat(sprintf("  Questions: %d | Options: %d | Selection: %d (+1 Total row)\n",
              nrow(questions_dt), nrow(options_dt), nrow(selection_dt) - 1L))

  out_paths <- list()

  # ---- tabs target ------------------------------------------------------------
  if ("tabs" %in% targets) {
    ss_path <- file.path(output_dir, sprintf("%s_Survey_Structure.xlsx",  survey_id))
    cc_path <- file.path(output_dir, sprintf("%s_Crosstab_Config.xlsx",   survey_id))

    cat("Writing Survey_Structure.xlsx...\n")
    .att_write_survey_structure(questions_dt, options_dt, ss_path)

    cat("Writing Crosstab_Config.xlsx...\n")
    .att_write_crosstab_config(selection_dt, cc_path)

    out_paths$survey_structure <- ss_path
    out_paths$crosstab_config  <- cc_path
  }

  # ---- brand target -----------------------------------------------------------
  if ("brand" %in% targets) {
    brands_dt <- .att_build_brands(api_dt)
    cat_map   <- unique(brands_dt[, .(CategoryCode, Category)])
    ceps_dt   <- .att_build_ceps(api_dt, cat_map)
    attrs_dt  <- .att_build_attributes(api_dt, cat_map)
    cats_dt   <- .att_build_categories(brands_dt)

    cat(sprintf("  Brands: %d | CEPs: %d | Attributes: %d | Categories: %d\n",
                nrow(brands_dt), nrow(ceps_dt), nrow(attrs_dt), nrow(cats_dt)))

    ss_brand_path <- file.path(output_dir, sprintf("%s_Survey_Structure_Brand.xlsx", survey_id))
    bc_path       <- file.path(output_dir, sprintf("%s_Brand_Config.xlsx", survey_id))

    cat("Writing Survey_Structure_Brand.xlsx...\n")
    attitude_om <- .att_build_attitude_optionmap(api_dt)
    if (!is.null(attitude_om) && nrow(attitude_om) > 0L) {
      n_unmapped <- sum(is.na(attitude_om$Role))
      cat(sprintf("  Attitude scale: %d levels detected (%d auto-mapped to roles)\n",
                  nrow(attitude_om), nrow(attitude_om) - n_unmapped))
      if (n_unmapped > 0L) {
        cat(sprintf("    %d option(s) need a manual Role in Survey_Structure_Brand > OptionMap\n",
                    n_unmapped))
      }
    }
    .att_write_brand_survey_structure(questions_dt, options_dt,
                                      brands_dt, ceps_dt, attrs_dt, ss_brand_path,
                                      attitude_optionmap_dt = attitude_om)

    cat("Writing Brand_Config.xlsx...\n")
    .att_write_brand_config(cats_dt, bc_path, survey_id = survey_id)

    out_paths$survey_structure_brand <- ss_brand_path
    out_paths$brand_config           <- bc_path
  }

  # ---- data headers (all targets) --------------------------------------------
  dh_path <- file.path(output_dir, sprintf("%s_Data_Headers.xlsx", survey_id))
  cat("Writing Data_Headers.xlsx...\n")
  if (!is.null(data_export_path) && nzchar(data_export_path) &&
      !file.exists(data_export_path)) {
    warning(sprintf(
      "data_export_path not found: '%s' — falling back to structure-only.",
      data_export_path
    ), call. = FALSE)
    data_export_path <- NULL
  }
  turas_headers <- .att_write_data_headers(
    questions_dt     = questions_dt,
    options_dt       = options_dt,
    api_dt           = api_dt,
    output_path      = dh_path,
    data_export_path = data_export_path
  )
  out_paths$data_headers <- dh_path

  # ---- Turas-ready data file (only when a data export was provided) ----------
  if (!is.null(data_export_path) && length(turas_headers) > 0L) {
    data_out <- file.path(output_dir, sprintf("%s_data.xlsx", survey_id))
    cat("Writing Turas-ready data file...\n")
    .att_write_turas_ready_data(data_export_path, turas_headers, data_out)
    out_paths$data_file <- data_out
  }

  written <- paste(sprintf("  %s", basename(unlist(out_paths))), collapse = "\n")
  cat(sprintf("\nDone. Files in: %s\n%s\n", output_dir, written))

  invisible(out_paths)
}

# ---- CLI entry point ---------------------------------------------------------

if (sys.nframe() == 0L && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2L) {
    stop(
      "Usage: Rscript scripts/alchemer_to_turas.R <survey_id> <output_dir> [data_export]",
      call. = FALSE
    )
  }
  alchemer_to_turas(
    survey_id        = args[[1L]],
    output_dir       = args[[2L]],
    data_export_path = if (length(args) >= 3L) args[[3L]] else NULL
  )
}
