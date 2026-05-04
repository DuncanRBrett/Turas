# ==============================================================================
# BRAND MODULE — CONVENTION-FIRST ROLE INFERENCE
# ==============================================================================
# Walks the Survey_Structure Questions sheet + Brand_Config Categories + Brand
# list and produces role entries by naming convention. The full set of
# patterns is documented in modules/brand/templates/README.md and
# docs/PLANNING_IPK_REBUILD.md §5.3.
#
# Role-entry shape (used everywhere downstream):
#   list(
#     role               = string,           # e.g. "funnel.awareness.DSS"
#     category           = string or NA,     # e.g. "DSS" / NA for sample-wide
#     client_code        = string,           # the question root (e.g. BRANDAWARE)
#     variable_type      = string,           # tabs vocabulary
#     column_root        = string,           # "BRANDAWARE_DSS"
#     per_brand          = logical,          # TRUE = Q_root_{brand} per-brand
#     columns            = character,        # slot cols or per-brand cols
#     applicable_brands  = character or NULL,
#     question_text      = string or NA,
#     option_scale       = string or NA,
#     option_map         = data.frame or NULL,
#     notes              = string
#   )
#
# This file owns ONLY the inference rules. The public entry — combining
# inference + QuestionMap overrides — lives in 00_role_map.R.
#
# VERSION: 1.0
# ==============================================================================

BRAND_ROLE_INFERENCE_VERSION <- "1.0"


# ==============================================================================
# PUBLIC ENTRY
# ==============================================================================

#' Infer a brand role map from the structure + config (convention-first)
#'
#' @param questions Data frame from Survey_Structure 'Questions' sheet:
#'   columns QuestionCode, QuestionText, Variable_Type, Columns.
#' @param brands Data frame from Survey_Structure 'Brands' sheet:
#'   columns CategoryCode, BrandCode, IsFocal, ...
#' @param active_cats Character vector of category codes flagged Active = Y
#'   in Brand_Config Categories.
#' @return Named list of role entries, keyed by role name.
#' @export
infer_role_map <- function(questions, brands, active_cats) {
  if (!isTRUE(.require_questions_df(questions))) return(list())
  if (is.null(brands)) brands <- data.frame()
  if (length(active_cats) == 0L) active_cats <- character(0)

  brands_by_cat <- if (nrow(brands) > 0L) {
    split(brands$BrandCode, brands$CategoryCode)
  } else list()

  role_map <- list()
  per_brand_collect <- list()  # role -> list(match, qrow, brands)
  q_codes <- questions$QuestionCode

  # Pass 1: per-row matching. Non-per-brand entries land directly in role_map;
  # per-brand entries are deferred so we can aggregate brands per role.
  for (qc in q_codes) {
    qrow <- questions[questions$QuestionCode == qc, , drop = FALSE][1, ]
    matches <- .match_patterns(qc)
    for (m in matches) {
      if (!is.null(m$category) &&
          length(active_cats) > 0L && !(m$category %in% active_cats)) next
      kind <- m$column_kind %||% "system"
      if (kind == "per_brand") {
        # Defer — collect brands by role
        if (is.null(per_brand_collect[[m$role]])) {
          per_brand_collect[[m$role]] <- list(
            match = m, qrow = qrow, brands = character(0)
          )
        }
        per_brand_collect[[m$role]]$brands <- unique(c(
          per_brand_collect[[m$role]]$brands,
          m$detail$brand
        ))
      } else {
        entry <- .build_entry_from_match(m, qc, qrow, brands_by_cat)
        if (!is.null(entry)) role_map[[entry$role]] <- entry
      }
    }
  }

  # Pass 2: build a single compound entry per per-brand role
  for (role in names(per_brand_collect)) {
    coll <- per_brand_collect[[role]]
    role_map[[role]] <- .entry_per_brand_compound(coll, brands_by_cat)
  }

  role_map
}


# ==============================================================================
# PATTERN MATCHING — recognise question codes by convention
# ==============================================================================

#' Match a question code against the convention patterns
#'
#' Returns a list of one or more match descriptors (since one question code
#' can emit multiple roles, e.g. BRANDAWARE_DSS -> funnel.awareness +
#' portfolio.awareness).
#'
#' Each match is a list with:
#'   * pattern:    pattern key (string)
#'   * role:       role name to emit
#'   * category:   category code (or NULL if sample-wide)
#'   * detail:     additional structured info (e.g. CEP code, brand code)
#'   * column_kind: "multi_mention_root", "per_brand", "per_category",
#'                  "system", "demographic", "adhoc"
#'
#' @keywords internal
.match_patterns <- function(qc) {
  matches <- list()

  # System / fixed roles
  if (qc == "Focal_Category") {
    return(list(list(pattern = "focal_category",
                     role = "system.focal_category", category = NULL,
                     column_kind = "system")))
  }
  if (qc == "Wave") {
    return(list(list(pattern = "wave", role = "system.wave",
                     category = NULL, column_kind = "system")))
  }
  if (qc == "Response.ID" || qc == "ResponseID") {
    return(list(list(pattern = "response_id",
                     role = "system.respondent.id", category = NULL,
                     column_kind = "system")))
  }
  if (qc == "SQ1") {
    return(list(list(pattern = "sq1", role = "screener.sq1",
                     category = NULL, column_kind = "multi_mention_root")))
  }
  if (qc == "SQ2") {
    return(list(list(pattern = "sq2", role = "screener.sq2",
                     category = NULL, column_kind = "multi_mention_root")))
  }

  # Demographics — DEMO_{KEY}
  if (grepl("^DEMO_", qc)) {
    key <- sub("^DEMO_", "", qc)
    return(list(list(pattern = "demographic",
                     role = paste0("demographics.", tolower(key)),
                     category = NULL, detail = list(key = key),
                     column_kind = "demographic")))
  }

  # Per-brand single-response: BRANDATT1_{CAT}_{BRAND}
  m <- regmatches(qc, regexec("^BRANDATT1_([A-Z0-9]+)_([A-Z0-9]+)$", qc))[[1]]
  if (length(m) == 3L) {
    return(list(list(pattern = "brandatt1",
                     role = paste0("funnel.attitude.", m[2]),
                     category = m[2], detail = list(brand = m[3]),
                     column_kind = "per_brand")))
  }
  m <- regmatches(qc, regexec("^BRANDATT2_([A-Z0-9]+)_([A-Z0-9]+)$", qc))[[1]]
  if (length(m) == 3L) {
    return(list(list(pattern = "brandatt2",
                     role = paste0("funnel.rejection_oe.", m[2]),
                     category = m[2], detail = list(brand = m[3]),
                     column_kind = "per_brand")))
  }

  # CEP / Attribute matrices: BRANDATTR_{CAT}_{CEP|ATT}{NN}
  m <- regmatches(qc, regexec("^BRANDATTR_([A-Z0-9]+)_(CEP|ATT)([0-9]+)$",
                              qc))[[1]]
  if (length(m) == 4L) {
    item_kind <- if (m[3] == "CEP") "cep" else "attr"
    item_code <- paste0(m[3], m[4])
    return(list(list(pattern = "brandattr",
                     role = paste0("mental_avail.", item_kind, ".",
                                   m[2], ".", item_code),
                     category = m[2],
                     detail = list(item_kind = item_kind, item_code = item_code),
                     column_kind = "multi_mention_root")))
  }

  # WOM count per-brand: WOM_{POS|NEG}_COUNT_{CAT}_{BRAND}
  m <- regmatches(qc, regexec("^WOM_(POS|NEG)_COUNT_([A-Z0-9]+)_([A-Z0-9]+)$",
                              qc))[[1]]
  if (length(m) == 4L) {
    return(list(list(pattern = "wom_count",
                     role = sprintf("wom.%s_count.%s",
                                    tolower(m[2]), m[3]),
                     category = m[3],
                     detail = list(polarity = tolower(m[2]), brand = m[4]),
                     column_kind = "per_brand")))
  }

  # WOM mention sets: WOM_{POS|NEG}_{REC|SHARE}_{CAT}
  m <- regmatches(qc, regexec(
    "^WOM_(POS|NEG)_(REC|SHARE)_([A-Z0-9]+)$", qc))[[1]]
  if (length(m) == 4L) {
    return(list(list(pattern = "wom_mention",
                     role = sprintf("wom.%s_%s.%s",
                                    tolower(m[2]), tolower(m[3]), m[4]),
                     category = m[4],
                     detail = list(polarity = tolower(m[2]),
                                   direction = tolower(m[3])),
                     column_kind = "multi_mention_root")))
  }

  # Brand awareness — also feeds portfolio
  m <- regmatches(qc, regexec("^BRANDAWARE_([A-Z0-9]+)$", qc))[[1]]
  if (length(m) == 2L) {
    return(list(
      list(pattern = "brandaware", role = paste0("funnel.awareness.", m[2]),
           category = m[2], column_kind = "multi_mention_root"),
      list(pattern = "portfolio_aware",
           role = paste0("portfolio.awareness.", m[2]),
           category = m[2], column_kind = "multi_mention_root")
    ))
  }

  # Penetration roots
  for (which in c("BRANDPEN1", "BRANDPEN2", "BRANDPEN3")) {
    m <- regmatches(qc, regexec(paste0("^", which, "_([A-Z0-9]+)$"), qc))[[1]]
    if (length(m) == 2L) {
      role_key <- switch(which,
        BRANDPEN1 = "funnel.penetration_long.",
        BRANDPEN2 = "funnel.penetration_target.",
        BRANDPEN3 = "funnel.frequency."
      )
      return(list(list(pattern = tolower(which),
                       role = paste0(role_key, m[2]),
                       category = m[2],
                       column_kind = "multi_mention_root")))
    }
  }

  # Cat-buying per-category roots
  per_cat_roots <- list(
    list(prefix = "CATBUY",   role = "cat_buying.frequency.",
         kind = "per_category"),
    list(prefix = "CATCOUNT", role = "cat_buying.count.",
         kind = "per_category"),
    list(prefix = "CHANNEL",  role = "cat_buying.channel.",
         kind = "multi_mention_root"),
    list(prefix = "PACK",     role = "cat_buying.packsize.",
         kind = "multi_mention_root")
  )
  for (def in per_cat_roots) {
    m <- regmatches(qc,
                    regexec(paste0("^", def$prefix, "_([A-Z0-9]+)$"), qc))[[1]]
    if (length(m) == 2L) {
      return(list(list(pattern = tolower(def$prefix),
                       role = paste0(def$role, m[2]),
                       category = m[2], column_kind = def$kind)))
    }
  }

  # Ad hoc — sample-wide ADHOC_{KEY} or category-specific ADHOC_{KEY}_{CAT}
  m <- regmatches(qc, regexec("^ADHOC_([A-Z0-9]+)_([A-Z0-9]+)$", qc))[[1]]
  if (length(m) == 3L) {
    return(list(list(pattern = "adhoc_cat",
                     role = sprintf("adhoc.%s.%s", tolower(m[2]), m[3]),
                     category = m[3],
                     detail = list(key = m[2]),
                     column_kind = "adhoc")))
  }
  m <- regmatches(qc, regexec("^ADHOC_([A-Z0-9]+)$", qc))[[1]]
  if (length(m) == 2L) {
    return(list(list(pattern = "adhoc_all",
                     role = sprintf("adhoc.%s.ALL", tolower(m[2])),
                     category = NULL,
                     detail = list(key = m[2]),
                     column_kind = "adhoc")))
  }

  # No convention matched — caller may fall back to QuestionMap override
  list()
}


# ==============================================================================
# ENTRY BUILDERS — one per column_kind
# ==============================================================================

.build_entry_from_match <- function(m, qc, qrow, brands_by_cat) {
  kind <- m$column_kind %||% "system"
  switch(kind,
    multi_mention_root = .entry_multi_mention(m, qc, qrow, brands_by_cat),
    per_brand          = .entry_per_brand(m, qc, qrow),
    per_category       = .entry_per_category(m, qc, qrow),
    system             = .entry_system(m, qc, qrow),
    demographic        = .entry_demographic(m, qc, qrow),
    adhoc              = .entry_adhoc(m, qc, qrow)
  )
}

.entry_multi_mention <- function(m, qc, qrow, brands_by_cat) {
  cat <- m$category
  applicable <- if (!is.null(cat) && cat %in% names(brands_by_cat)) {
    as.character(brands_by_cat[[cat]])
  } else NULL
  list(
    role = m$role, category = cat %||% NA_character_,
    client_code = .extract_client_code(qc),
    variable_type = qrow$Variable_Type %||% "Multi_Mention",
    column_root = qc, per_brand = FALSE,
    columns = NULL,  # populated by resolver against actual data
    applicable_brands = applicable,
    question_text = .nz(qrow$QuestionText),
    option_scale = NA_character_, option_map = NULL,
    notes = "", detail = m$detail %||% list()
  )
}

.entry_per_brand <- function(m, qc, qrow) {
  # Single-brand stub used during pass 1 of infer_role_map; consolidated
  # into a compound entry by .entry_per_brand_compound() in pass 2.
  list(
    role = m$role, category = m$category %||% NA_character_,
    client_code = .extract_per_brand_root(qc),
    variable_type = qrow$Variable_Type %||% "Single_Response",
    column_root = sub(paste0("_", m$detail$brand, "$"), "", qc),
    per_brand = TRUE, columns = qc,
    applicable_brands = m$detail$brand,
    question_text = .nz(qrow$QuestionText),
    option_scale = NA_character_, option_map = NULL,
    notes = "", detail = m$detail %||% list()
  )
}

#' Build a per-brand compound entry from collected per-brand matches
#'
#' Per-brand patterns (BRANDATT1_DSS_IPK, BRANDATT1_DSS_ROB, ...) all share
#' the same role (\code{funnel.attitude.DSS}). This function aggregates
#' them into a single entry whose \code{applicable_brands} lists every
#' brand seen. \code{column_root} keeps the brand-stripped form so the
#' resolver can rebuild per-brand columns by paste0(root, "_", brand).
#'
#' @keywords internal
.entry_per_brand_compound <- function(coll, brands_by_cat) {
  m <- coll$match
  qrow <- coll$qrow
  cat <- m$category
  # column_root = strip brand suffix from the original question code
  column_root <- sub(paste0("_", m$detail$brand, "$"), "",
                     qrow$QuestionCode)
  list(
    role = m$role, category = cat %||% NA_character_,
    client_code = .extract_per_brand_root(qrow$QuestionCode),
    variable_type = qrow$Variable_Type %||% "Single_Response",
    column_root = column_root,
    per_brand = TRUE,
    columns = NULL,  # populated by .resolve_columns()
    applicable_brands = sort(unique(coll$brands)),
    question_text = .nz(qrow$QuestionText),
    option_scale = NA_character_, option_map = NULL,
    notes = "", detail = list(pattern_kind = "per_brand_compound")
  )
}

.entry_per_category <- function(m, qc, qrow) {
  list(
    role = m$role, category = m$category %||% NA_character_,
    client_code = .extract_client_code(qc),
    variable_type = qrow$Variable_Type %||% "Single_Response",
    column_root = qc, per_brand = FALSE,
    columns = qc, applicable_brands = NULL,
    question_text = .nz(qrow$QuestionText),
    option_scale = NA_character_, option_map = NULL,
    notes = "", detail = m$detail %||% list()
  )
}

.entry_system <- function(m, qc, qrow) {
  list(
    role = m$role, category = NA_character_,
    client_code = qc,
    variable_type = qrow$Variable_Type %||% "Single_Response",
    column_root = qc, per_brand = FALSE,
    columns = qc, applicable_brands = NULL,
    question_text = .nz(qrow$QuestionText),
    option_scale = NA_character_, option_map = NULL,
    notes = "", detail = m$detail %||% list()
  )
}

.entry_demographic <- function(m, qc, qrow) {
  .entry_per_category(m, qc, qrow)  # same shape
}

.entry_adhoc <- function(m, qc, qrow) {
  list(
    role = m$role, category = m$category %||% NA_character_,
    client_code = qc,
    variable_type = qrow$Variable_Type %||% "Single_Response",
    column_root = qc, per_brand = FALSE,
    columns = qc, applicable_brands = NULL,
    question_text = .nz(qrow$QuestionText),
    option_scale = NA_character_, option_map = NULL,
    notes = "", detail = m$detail %||% list()
  )
}


# ==============================================================================
# UTILITIES
# ==============================================================================

.extract_client_code <- function(qc) {
  # Strip trailing _CAT for QC like BRANDAWARE_DSS -> BRANDAWARE
  sub("_[A-Z0-9]+$", "", qc)
}

.extract_per_brand_root <- function(qc) {
  # BRANDATT1_DSS_IPK -> BRANDATT1
  sub("_[A-Z0-9]+_[A-Z0-9]+$", "", qc)
}

.nz <- function(x) if (is.null(x) || is.na(x)) NA_character_ else as.character(x)

.require_questions_df <- function(qs) {
  if (!is.data.frame(qs)) {
    cat("\n[REFUSED: DATA_INVALID] infer_role_map: questions must be a data frame\n")
    return(FALSE)
  }
  required <- c("QuestionCode", "Variable_Type")
  missing <- setdiff(required, names(qs))
  if (length(missing) > 0L) {
    cat(sprintf(
      "\n[REFUSED: DATA_MISSING] infer_role_map: questions sheet missing columns: %s\n",
      paste(missing, collapse = ", ")))
    return(FALSE)
  }
  TRUE
}

# `%||%` may not be defined yet (loader order); define a local copy
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
