# scripts/alchemer_to_turas.R
#
# Convert an Alchemer survey into populated Turas config templates via the v5 API.
#
# Outputs (written to output_dir):
#   All targets:
#     {survey_id}_Data_Headers.xlsx          — column rename map (if data_export_path given)
#   targets includes "tabs":
#     {survey_id}_Survey_Structure.xlsx      — Questions + Options sheets populated
#     {survey_id}_Crosstab_Config.xlsx       — Selection sheet + full Settings copy
#   targets includes "brand":
#     {survey_id}_Survey_Structure_Brand.xlsx — Brand survey structure
#     {survey_id}_Brand_Config.xlsx           — Brand config with Categories pre-filled
#
# Usage from R:
#   source("scripts/alchemer_to_turas.R")
#   alchemer_to_turas(survey_id = 8822527, output_dir = "projects/my_project")
#   alchemer_to_turas(8822527, "projects/ipk", targets = c("tabs", "brand"),
#                     data_export_path = "projects/ipk/raw.csv")
#
# Usage from CLI:
#   Rscript scripts/alchemer_to_turas.R <survey_id> <output_dir> [data_export.csv]

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

.att_build_options <- function(api_dt, questions_dt) {
  q_lookup <- unique(api_dt[, .(question_id, question_shortname)])[
    questions_dt[, .(QuestionCode, Variable_Type)],
    on = c(question_shortname = "QuestionCode"),
    nomatch = NULL
  ]

  opts <- api_dt[!is.na(option_id) & !is.na(option_value)]
  if (nrow(opts) == 0L) return(data.table())

  opts <- q_lookup[opts, on = "question_id", nomatch = NULL]
  opts[, opt_seq := seq_len(.N), by = question_id]

  opts[, OptionQuestionCode := ifelse(
    Variable_Type %in% c("Multi_Mention", "Ranking"),
    paste0(question_shortname, "_", opt_seq),
    question_shortname
  )]

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
    cat_name <- .att_strip_label_prefix(q$question_title)
    if (!nzchar(trimws(cat_name)) || cat_name == q$question_title) cat_name <- cat_code

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

#' Extract CEPs from BRANDATTR_{CAT}_CEP{NN} questions.
#' CEPCode = shortname suffix (e.g. CEP01), CEPText = question_title with prefix stripped.
.att_build_ceps <- function(api_dt, cat_map) {
  cep_q <- unique(api_dt[
    grepl("^BRANDATTR_[^_]+_CEP", question_shortname, ignore.case = TRUE),
    .(question_id, question_shortname, question_title)
  ])
  if (nrow(cep_q) == 0L) {
    warning("No BRANDATTR_*_CEP* questions found — CEPs sheet will be empty.", call. = FALSE)
    return(data.table(Category = character(), CategoryCode = character(),
                      CEPCode = character(), CEPText = character(), DisplayOrder = integer()))
  }

  rows <- lapply(seq_len(nrow(cep_q)), function(i) {
    q        <- cep_q[i]
    parts    <- strsplit(q$question_shortname, "_", fixed = TRUE)[[1L]]
    cat_code <- toupper(parts[[2L]])
    cep_code <- paste(parts[seq(3L, length(parts))], collapse = "_")
    cep_text <- .att_strip_label_prefix(q$question_title)
    if (!nzchar(trimws(cep_text)) || cep_text == q$question_title) cep_text <- q$question_title

    cat_name <- if (!is.null(cat_map) && cat_code %in% cat_map$CategoryCode) {
      cat_map[CategoryCode == cat_code, Category][[1L]]
    } else {
      cat_code
    }
    data.table(Category = cat_name, CategoryCode = cat_code, CEPCode = cep_code, CEPText = cep_text)
  })
  cep_dt <- data.table::rbindlist(rows, use.names = TRUE)
  cep_dt[, DisplayOrder := seq_len(.N), by = CategoryCode]
  cep_dt
}

#' Extract Attributes from BRANDATTR_{CAT}_ATT{NN} questions.
#' AttrCode = shortname suffix (e.g. ATT01), AttrText = question_title with prefix stripped.
.att_build_attributes <- function(api_dt, cat_map) {
  attr_q <- unique(api_dt[
    grepl("^BRANDATTR_[^_]+_ATT", question_shortname, ignore.case = TRUE),
    .(question_id, question_shortname, question_title)
  ])
  if (nrow(attr_q) == 0L) {
    warning("No BRANDATTR_*_ATT* questions found — Attributes sheet will be empty.", call. = FALSE)
    return(data.table(Category = character(), CategoryCode = character(),
                      AttrCode = character(), AttrText = character(), DisplayOrder = integer()))
  }

  rows <- lapply(seq_len(nrow(attr_q)), function(i) {
    q         <- attr_q[i]
    parts     <- strsplit(q$question_shortname, "_", fixed = TRUE)[[1L]]
    cat_code  <- toupper(parts[[2L]])
    attr_code <- paste(parts[seq(3L, length(parts))], collapse = "_")
    attr_text <- .att_strip_label_prefix(q$question_title)
    if (!nzchar(trimws(attr_text)) || attr_text == q$question_title) attr_text <- q$question_title

    cat_name <- if (!is.null(cat_map) && cat_code %in% cat_map$CategoryCode) {
      cat_map[CategoryCode == cat_code, Category][[1L]]
    } else {
      cat_code
    }
    data.table(Category = cat_name, CategoryCode = cat_code, AttrCode = attr_code, AttrText = attr_text)
  })
  attr_dt <- data.table::rbindlist(rows, use.names = TRUE)
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
                                               output_path) {
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

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}

.att_write_brand_config <- function(categories_dt, output_path) {
  wb <- openxlsx::loadWorkbook(.att_bc_template())

  .att_clear_examples(wb, "Categories", n_cols = ncol(categories_dt))
  if (nrow(categories_dt) > 0L) {
    openxlsx::writeData(wb, "Categories", categories_dt,
                        startRow = .ATT_DATA_START_ROW, colNames = FALSE)
  }

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}

.att_write_data_headers <- function(api_dt, questions_dt, data_export_path, output_path) {
  ext <- tolower(tools::file_ext(data_export_path))
  raw_headers <- tryCatch(
    {
      if (ext == "csv") {
        names(data.table::fread(data_export_path, nrows = 0L, header = TRUE))
      } else {
        names(openxlsx::read.xlsx(data_export_path, rows = 1L, colNames = TRUE))
      }
    },
    error = function(e) {
      warning(sprintf(
        "Could not read data export '%s': %s — Data_Headers skipped.", data_export_path, e$message
      ), call. = FALSE)
      NULL
    }
  )
  if (is.null(raw_headers)) return(invisible(NULL))

  opts_colon <- api_dt[!is.na(option_id) & !is.na(option_title) & nzchar(option_title)]
  opts_colon[, opt_seq    := seq_len(.N), by = question_id]
  opts_colon[, norm_title := gsub(" ", ".", trimws(option_title), fixed = TRUE)]
  opts_colon[, turas_col  := paste0(question_shortname, "_", opt_seq)]
  colon_lookup <- lapply(
    split(opts_colon, by = "question_shortname", keep.by = TRUE),
    function(dt) dt[, .(norm_title, turas_col)]
  )

  all_codes <- questions_dt$QuestionCode
  turas_headers <- vapply(raw_headers, function(h) {
    if (h %in% all_codes) return(h)
    if (grepl(":", h, fixed = TRUE)) {
      parts <- strsplit(h, ":", fixed = TRUE)[[1L]]
      if (length(parts) == 2L) {
        prefix    <- parts[[1L]]
        shortname <- parts[[2L]]
        q_opts    <- colon_lookup[[shortname]]
        if (!is.null(q_opts)) {
          idx <- which(q_opts$norm_title == prefix)
          if (length(idx) == 0L) idx <- which(tolower(q_opts$norm_title) == tolower(prefix))
          if (length(idx) == 1L) return(q_opts$turas_col[idx])
        }
      }
      return(h)
    }
    prefix_match <- all_codes[nchar(all_codes) >= 3L &
                                startsWith(h, paste0(all_codes, "_"))]
    if (length(prefix_match) >= 1L) return(h)
    h
  }, character(1L), USE.NAMES = FALSE)

  n_colon_total  <- sum(grepl(":", raw_headers, fixed = TRUE))
  n_colon_mapped <- sum(turas_headers != raw_headers & grepl(":", raw_headers, fixed = TRUE))

  header_dt <- as.data.table(t(turas_headers))
  names(header_dt) <- turas_headers

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Headers")
  openxlsx::writeData(wb, "Headers", header_dt, startRow = 1L, colNames = TRUE)
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("  Data_Headers: %d / %d colon-format columns mapped; %d simple columns; %d unresolved\n",
              n_colon_mapped, n_colon_total,
              sum(!grepl(":", raw_headers, fixed = TRUE)),
              sum(turas_headers == raw_headers & grepl(":", raw_headers, fixed = TRUE))))
  invisible(turas_headers)
}

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
#' @param data_export_path Optional path to an Alchemer CSV or XLSX data export.
#'   When provided, also writes a Data_Headers rename map.
#' @param targets Character vector of module targets. Valid values: "tabs", "brand".
#'   Defaults to "tabs". Pass c("tabs", "brand") to generate both.
#' @return Invisibly, a named list of paths for files written.
#' @export
alchemer_to_turas <- function(survey_id,
                               output_dir,
                               api_token        = NULL,
                               api_secret       = NULL,
                               data_export_path = NULL,
                               targets          = "tabs") {
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
    .att_write_brand_survey_structure(questions_dt, options_dt,
                                      brands_dt, ceps_dt, attrs_dt, ss_brand_path)

    cat("Writing Brand_Config.xlsx...\n")
    .att_write_brand_config(cats_dt, bc_path)

    out_paths$survey_structure_brand <- ss_brand_path
    out_paths$brand_config           <- bc_path
  }

  # ---- data headers (all targets) --------------------------------------------
  if (!is.null(data_export_path)) {
    dh_path <- file.path(output_dir, sprintf("%s_Data_Headers.xlsx", survey_id))
    if (!file.exists(data_export_path)) {
      warning(sprintf(
        "data_export_path not found: '%s' — Data_Headers skipped.", data_export_path
      ), call. = FALSE)
    } else {
      cat("Writing Data_Headers.xlsx...\n")
      .att_write_data_headers(api_dt, questions_dt, data_export_path, dh_path)
      out_paths$data_headers <- dh_path
    }
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
      "Usage: Rscript scripts/alchemer_to_turas.R <survey_id> <output_dir> [data_export.csv]",
      call. = FALSE
    )
  }
  alchemer_to_turas(
    survey_id        = args[[1L]],
    output_dir       = args[[2L]],
    data_export_path = if (length(args) >= 3L) args[[3L]] else NULL
  )
}
