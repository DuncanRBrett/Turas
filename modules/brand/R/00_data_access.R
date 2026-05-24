# ==============================================================================
# BRAND MODULE — DATA-ACCESS LAYER
# ==============================================================================
# Shared helpers that every analytical element calls to read respondent-level
# answers from the AlchemerParser-shape data file. Two question shapes are
# supported:
#
#   1. Slot-indexed Multi_Mention. Columns Q_root_1..N hold option codes
#      (or NA) where each respondent's selections are left-packed across
#      slots. Helper: respondent_picked() / multi_mention_brand_matrix().
#
#   2. Per-brand Single_Response. One column per brand named
#      Q_root_{cat}_{brand} holding a numeric or character code value.
#      Helper: single_response_brand_column() / single_response_brand_matrix().
#
# Every brand-analysis function in modules/brand/R/ MUST go through these
# helpers. Direct data[[paste0(...)]] access is forbidden in the rebuild —
# the helpers are the single seam between the role registry and respondent
# data.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DATA_ACCESS_VERSION <- "1.0"


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Did each respondent select a given option for a Multi_Mention question?
#'
#' Searches across all slot columns matching \code{^{root}_[0-9]+$} for the
#' given option code. Returns a logical vector of length \code{nrow(data)}.
#' NA-safe: a slot with NA contributes FALSE for that respondent.
#'
#' @param data Data frame.
#' @param root Question root code (e.g. \code{"BRANDAWARE_DSS"}).
#' @param option_code Option code to test for (character; e.g.
#'   \code{"IPK"}, \code{"NONE"}).
#' @param aliases Optional character vector of alternate values that should
#'   also count as a hit (e.g. \code{"FNF"} for F&F when the survey was
#'   programmed with an alias). NA / empty / duplicate-of-\code{option_code}
#'   entries are dropped.
#' @return Logical vector, length \code{nrow(data)}.
#' @examples
#' \dontrun{
#'   ipk_aware <- respondent_picked(data, "BRANDAWARE_DSS", "IPK")
#' }
#' @export
respondent_picked <- function(data, root, option_code, aliases = NULL) {
  .require_dataframe(data)
  .require_root(root)
  if (length(option_code) != 1L) {
    brand_da_refuse(
      code = "DATA_ACCESS_OPTION_CODE_NOT_SCALAR",
      title = "respondent_picked() requires a single option code",
      problem = sprintf(
        "Got option_code of length %d for root '%s'. Only single codes are supported.",
        length(option_code), root),
      how_to_fix = "Pass exactly one option code as a character scalar."
    )
  }

  cols <- .slot_columns(data, root)
  if (length(cols) == 0L) {
    return(rep(FALSE, nrow(data)))
  }
  target <- as.character(option_code)
  if (!is.null(aliases) && length(aliases) > 0L) {
    a <- as.character(aliases)
    a <- a[!is.na(a) & nzchar(trimws(a))]
    a <- a[a != target]
    target <- unique(c(target, a))
  }
  hit <- rep(FALSE, nrow(data))
  for (col in cols) {
    vals <- as.character(data[[col]])
    hit <- hit | (!is.na(vals) & vals %in% target)
  }
  hit
}


#' Build a per-respondent × per-brand logical matrix from a Multi_Mention root
#'
#' Wraps \code{respondent_picked()} across a brand list. Columns of the
#' returned matrix are brand codes; rows are respondents.
#'
#' @param data Data frame.
#' @param root Question root code (e.g. \code{"BRANDAWARE_DSS"}).
#' @param brand_codes Character vector of brand codes (or a brand_list data
#'   frame with a \code{BrandCode} column — and optionally
#'   \code{BrandCodeAlias} for the alias-aware path).
#' @param brand_aliases Optional named character vector mapping BrandCode →
#'   alternate option-value suffix that may appear in the data slots. Used to
#'   reconcile cases where the Alchemer survey was programmed with a
#'   different option-value than the canonical brand code (see
#'   BrandCodeAlias in the Brands sheet, BRAND_CONFIG_GUIDE.md). When a
#'   respondent slot holds the alias value, the cell is counted as a hit for
#'   the canonical brand code. NULL = exact-match only.
#' @return Logical matrix of dimension \code{[nrow(data) × length(brand_codes)]},
#'   with \code{brand_codes} as \code{colnames}.
#' @examples
#' \dontrun{
#'   mat <- multi_mention_brand_matrix(data, "BRANDPEN1_DSS",
#'                                     c("IPK", "ROB", "KNORR"))
#' }
#' @export
multi_mention_brand_matrix <- function(data, root, brand_codes,
                                        brand_aliases = NULL) {
  .require_dataframe(data)
  .require_root(root)
  # Accept brand_list data frame for ergonomic call sites — extract codes +
  # auto-detect aliases. Existing character-vector callers are untouched.
  if (is.data.frame(brand_codes)) {
    bl <- brand_codes
    brand_codes <- as.character(bl$BrandCode)
    if (is.null(brand_aliases))
      brand_aliases <- .brand_aliases_from_list(bl)
  }
  if (length(brand_codes) == 0L) {
    return(matrix(FALSE, nrow = nrow(data), ncol = 0L))
  }
  brand_codes <- as.character(brand_codes)
  cols <- .slot_columns(data, root)
  mat <- matrix(FALSE, nrow = nrow(data), ncol = length(brand_codes),
                dimnames = list(NULL, brand_codes))
  if (length(cols) == 0L) return(mat)

  # Cache the slot column values once
  slot_vals <- lapply(cols, function(col) as.character(data[[col]]))
  for (b in brand_codes) {
    # Match the canonical brand code AND its alias (if declared). The alias
    # path was added to handle Alchemer surveys programmed with a different
    # option value than the structure's BrandCode — e.g. IPK 2026 POS where
    # F&F's option value was 'FNF' but the brand code is 'FNFPS'.
    targets <- b
    if (!is.null(brand_aliases) && b %in% names(brand_aliases)) {
      alias <- as.character(brand_aliases[[b]])
      if (!is.na(alias) && nzchar(trimws(alias)) && !identical(alias, b))
        targets <- c(b, alias)
    }
    hit <- rep(FALSE, nrow(data))
    for (vals in slot_vals) {
      hit <- hit | (!is.na(vals) & vals %in% targets)
    }
    mat[, b] <- hit
  }
  mat
}


#' Read a per-brand Single_Response column directly
#'
#' For per-brand-radio questions like \code{BRANDATT1_DSS_IPK}. Returns the
#' raw column vector as-is (numeric or character per AlchemerParser output).
#' Refuses if the column is missing.
#'
#' @param data Data frame.
#' @param root Question root (e.g. \code{"BRANDATT1"}).
#' @param cat_code Category code (e.g. \code{"DSS"}).
#' @param brand_code Brand code (e.g. \code{"IPK"}).
#' @return Vector of length \code{nrow(data)} — the raw column.
#' @examples
#' \dontrun{
#'   att <- single_response_brand_column(data, "BRANDATT1", "DSS", "IPK")
#' }
#' @export
single_response_brand_column <- function(data, root, cat_code, brand_code) {
  .require_dataframe(data)
  col <- paste0(root, "_", cat_code, "_", brand_code)
  if (!col %in% names(data)) {
    brand_da_refuse(
      code = "DATA_ACCESS_COLUMN_MISSING",
      title = sprintf("Per-brand column missing: %s", col),
      problem = sprintf("Column '%s' not found in data.", col),
      how_to_fix = c(
        sprintf("Confirm column '%s' exists in the parsed data file.", col),
        "Check the AlchemerParser output covers this question.",
        "Verify root / cat_code / brand_code spelling and case."
      ),
      missing = col
    )
  }
  data[[col]]
}


#' Build a per-respondent × per-brand matrix from per-brand columns
#'
#' For per-brand Single_Response families. Concatenates
#' \code{single_response_brand_column()} across the brand list. Brands without
#' a corresponding column contribute an NA column (does NOT refuse — caller
#' decides whether missing brands are an error in their context).
#'
#' Returns a character matrix to preserve original coding (numeric or string);
#' callers coerce as needed.
#'
#' @param data Data frame.
#' @param root Question root (e.g. \code{"BRANDATT1"}).
#' @param cat_code Category code (e.g. \code{"DSS"}).
#' @param brand_codes Character vector of brand codes (or a brand_list data
#'   frame with a \code{BrandCode} column — and optionally
#'   \code{BrandCodeAlias} for the alias-aware path).
#' @param brand_aliases Optional named character vector mapping BrandCode →
#'   alternate column-suffix that may appear in the data. Used to reconcile
#'   surveys where the per-brand column was named with a different suffix
#'   than the canonical brand code (see BrandCodeAlias in the Brands sheet,
#'   BRAND_CONFIG_GUIDE.md). When the exact column is missing but the alias
#'   column exists, the alias column's values are used. NULL = exact-match
#'   only.
#' @return Character matrix \code{[nrow(data) × length(brand_codes)]} with
#'   \code{brand_codes} as \code{colnames}. NA where neither column is
#'   present.
#' @examples
#' \dontrun{
#'   mat <- single_response_brand_matrix(data, "BRANDATT1", "DSS",
#'                                       c("IPK", "ROB"))
#' }
#' @export
single_response_brand_matrix <- function(data, root, cat_code, brand_codes,
                                          brand_aliases = NULL) {
  .require_dataframe(data)
  # Accept brand_list data frame for ergonomic call sites — extract codes +
  # auto-detect aliases. Existing character-vector callers are untouched.
  if (is.data.frame(brand_codes)) {
    bl <- brand_codes
    brand_codes <- as.character(bl$BrandCode)
    if (is.null(brand_aliases))
      brand_aliases <- .brand_aliases_from_list(bl)
  }
  if (length(brand_codes) == 0L) {
    return(matrix(NA_character_, nrow = nrow(data), ncol = 0L))
  }
  brand_codes <- as.character(brand_codes)
  mat <- matrix(NA_character_, nrow = nrow(data), ncol = length(brand_codes),
                dimnames = list(NULL, brand_codes))
  for (b in brand_codes) {
    col <- paste0(root, "_", cat_code, "_", b)
    if (col %in% names(data)) {
      mat[, b] <- as.character(data[[col]])
      next
    }
    # Alias fallback: e.g. IPK 2026 POS where F&F's data column was named
    # with suffix 'FNF' but the structure's BrandCode is 'FNFPS'. Declared
    # via the optional BrandCodeAlias column on the Brands sheet.
    if (!is.null(brand_aliases) && b %in% names(brand_aliases)) {
      alias <- as.character(brand_aliases[[b]])
      if (!is.na(alias) && nzchar(trimws(alias)) && !identical(alias, b)) {
        alias_col <- paste0(root, "_", cat_code, "_", alias)
        if (alias_col %in% names(data)) {
          mat[, b] <- as.character(data[[alias_col]])
        }
      }
    }
  }
  mat
}


#' Extract BrandCodeAlias mappings from a brand_list data frame
#'
#' Reads the optional \code{BrandCodeAlias} column on a brand_list and returns
#' a named character vector mapping \code{BrandCode → alias suffix}. Drops
#' rows where the alias is NA / blank / identical to the BrandCode. Returns
#' NULL when no alias column is present or no row declares one (so callers
#' can branch on \code{is.null(.)} cheaply).
#'
#' @param brand_list Data frame with at least \code{BrandCode}.
#' @return Named character vector or NULL.
#' @keywords internal
.brand_aliases_from_list <- function(brand_list) {
  if (is.null(brand_list) || !is.data.frame(brand_list)) return(NULL)
  if (!"BrandCodeAlias" %in% names(brand_list)) return(NULL)
  alias <- as.character(brand_list$BrandCodeAlias)
  code  <- as.character(brand_list$BrandCode)
  keep  <- !is.na(alias) & nzchar(trimws(alias)) & !is.na(code) &
           trimws(alias) != trimws(code)
  if (!any(keep)) return(NULL)
  stats::setNames(trimws(alias[keep]), trimws(code[keep]))
}


#' Build a per-respondent x per-option 0/1 indicator matrix
#'
#' Adapter for elements (e.g. shopper behaviour) that expect 0/1 column-per-
#' option data. Wraps multi_mention_brand_matrix() and coerces logical to
#' integer.
#'
#' @param data Data frame.
#' @param root Question root code (e.g. "CHANNEL_DSS").
#' @param codes Character vector of option codes to test (e.g. channel codes).
#' @return Integer matrix [nrow(data) x length(codes)] with codes as colnames,
#'   1 where the respondent selected that option, 0 otherwise.
#' @examples
#' \dontrun{
#'   ind <- multi_mention_indicator_matrix(data, "CHANNEL_DSS",
#'                                         c("SPMKT","ONLINE"))
#' }
#' @export
multi_mention_indicator_matrix <- function(data, root, codes) {
  m <- multi_mention_brand_matrix(data, root, codes)
  # Preserve dim + dimnames when coercing
  out <- matrix(as.integer(m), nrow = nrow(m), ncol = ncol(m),
                dimnames = dimnames(m))
  out
}


#' Build a per-respondent x per-option numeric matrix from a slot-paired
#' Multi_Mention + Continuous_Sum question pair
#'
#' Used for the BRANDPEN2 + BRANDPEN3 shape: BRANDPEN2_DSS_1..N hold brand
#' codes (where the respondent bought that brand in the target window) and
#' BRANDPEN3_DSS_1..N hold purchase counts at the same slot index. Returns
#' a numeric matrix where cell [i, brand] = count if the brand appears in
#' any slot for respondent i, else 0.
#'
#' Slot N in BRANDPEN3 maps to the brand at slot N in BRANDPEN2 — the
#' Alchemer Continuous Sum question is piped from the previous Multi_Mention.
#'
#' @param data Data frame.
#' @param root_codes Question root for the brand-code multi-mention
#'   (e.g. "BRANDPEN2_DSS").
#' @param root_values Question root for the numeric per-slot values
#'   (e.g. "BRANDPEN3_DSS").
#' @param brand_codes Character vector of brand codes (or a brand_list data
#'   frame with a \code{BrandCode} column — and optionally
#'   \code{BrandCodeAlias} for the alias-aware path).
#' @param brand_aliases Optional named character vector mapping BrandCode →
#'   alternate option-value that may appear in the data slots (see
#'   BrandCodeAlias in the Brands sheet, BRAND_CONFIG_GUIDE.md). NULL =
#'   exact-match only.
#' @return Numeric matrix [nrow(data) x length(brand_codes)] with brand_codes
#'   as colnames. NA values in the value root become 0. If a brand appears
#'   multiple times across slots for the same respondent (shouldn't happen
#'   in a well-piped Alchemer survey), counts are summed.
#' @examples
#' \dontrun{
#'   x_mat <- slot_paired_numeric_matrix(data, "BRANDPEN2_DSS",
#'                                       "BRANDPEN3_DSS",
#'                                       c("IPK","ROB"))
#' }
#' @export
slot_paired_numeric_matrix <- function(data, root_codes, root_values,
                                       brand_codes, brand_aliases = NULL) {
  .require_dataframe(data)
  .require_root(root_codes)
  .require_root(root_values)
  if (is.data.frame(brand_codes)) {
    bl <- brand_codes
    brand_codes <- as.character(bl$BrandCode)
    if (is.null(brand_aliases))
      brand_aliases <- .brand_aliases_from_list(bl)
  }
  if (length(brand_codes) == 0L) {
    return(matrix(0, nrow = nrow(data), ncol = 0L))
  }
  brand_codes <- as.character(brand_codes)

  code_cols <- .slot_columns(data, root_codes)
  val_cols  <- .slot_columns(data, root_values)
  if (length(code_cols) == 0L || length(val_cols) == 0L) {
    return(matrix(0, nrow = nrow(data), ncol = length(brand_codes),
                  dimnames = list(NULL, brand_codes)))
  }

  # Pair slots by trailing index. Some Alchemer surveys have BRANDPEN3 with
  # length(brands) slots while BRANDPEN2 has length(brands)+1 (NONE option).
  # Match on minimum index range; slots beyond either end contribute 0.
  code_idx <- as.integer(sub(paste0("^", root_codes, "_"), "", code_cols))
  val_idx  <- as.integer(sub(paste0("^", root_values, "_"), "", val_cols))
  shared <- intersect(code_idx, val_idx)

  out <- matrix(0, nrow = nrow(data), ncol = length(brand_codes),
                dimnames = list(NULL, brand_codes))
  for (slot in shared) {
    code_vec <- as.character(data[[paste0(root_codes, "_", slot)]])
    val_vec  <- suppressWarnings(as.numeric(
      data[[paste0(root_values, "_", slot)]]))
    val_vec[is.na(val_vec)] <- 0
    for (b in brand_codes) {
      targets <- b
      if (!is.null(brand_aliases) && b %in% names(brand_aliases)) {
        alias <- as.character(brand_aliases[[b]])
        if (!is.na(alias) && nzchar(trimws(alias)) && !identical(alias, b))
          targets <- c(b, alias)
      }
      hit <- !is.na(code_vec) & code_vec %in% targets
      out[hit, b] <- out[hit, b] + val_vec[hit]
    }
  }
  out
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Find slot columns for a Multi_Mention root
#'
#' Returns column names matching \code{^{root}_[0-9]+$}, sorted by slot index.
#' @keywords internal
.slot_columns <- function(data, root) {
  pat <- paste0("^", gsub("([\\.\\+\\*\\?\\(\\)\\[\\]\\{\\}\\|\\^\\$])",
                          "\\\\\\1", root, perl = TRUE), "_[0-9]+$")
  cols <- grep(pat, names(data), value = TRUE)
  if (length(cols) == 0L) return(character(0))
  # Sort by trailing slot index
  idx <- as.integer(sub(paste0("^", root, "_"), "", cols))
  cols[order(idx)]
}

.require_dataframe <- function(data) {
  if (is.data.frame(data)) return(invisible(TRUE))
  brand_da_refuse(
    code = "DATA_ACCESS_NOT_DATA_FRAME",
    title = "Data must be a data frame",
    problem = "Input was not a data.frame.",
    how_to_fix = "Pass a data frame as the 'data' argument."
  )
}

.require_root <- function(root) {
  if (is.character(root) && length(root) == 1L && nchar(root) > 0L) {
    return(invisible(TRUE))
  }
  brand_da_refuse(
    code = "DATA_ACCESS_INVALID_ROOT",
    title = "Question root must be a non-empty character scalar",
    problem = sprintf("Got root of class %s, length %d.",
                      class(root)[1], length(root)),
    how_to_fix = "Pass a single non-empty character string as the 'root' argument."
  )
}

#' Local refusal helper — wraps brand_refuse() if available, else stop()
#'
#' During the rebuild, this file may be sourced before 00_guard.R.
#' @keywords internal
brand_da_refuse <- function(code, title, problem, how_to_fix,
                            missing = NULL, ...) {
  if (exists("brand_refuse", mode = "function", envir = .GlobalEnv) ||
      exists("brand_refuse", mode = "function")) {
    brand_refuse(code = code, title = title, problem = problem,
                 why_it_matters = "Data-access layer cannot proceed.",
                 how_to_fix = how_to_fix, missing = missing, ...)
  } else {
    msg <- sprintf("[%s] %s — %s\nHow to fix: %s",
                   code, title, problem,
                   paste(how_to_fix, collapse = "; "))
    cat("\n=== TURAS ERROR ===\n", msg, "\n===================\n", sep = "")
    # TRS-FALLBACK: brand_refuse() is the canonical refusal path. This
    # stop() only fires during the rebuild when this file is sourced
    # before 00_guard.R (i.e. brand_refuse isn't yet defined). The boxed
    # message above is already TRS-formatted, so the user-facing output
    # is identical to a normal refusal — only the control-flow shape
    # differs (raised error instead of returned list).
    stop(msg, call. = FALSE)
  }
}


# ==============================================================================
# PSEUDO-BRAND DETECTION
# ==============================================================================

#' Recognise "None of the above" pseudo-brand codes
#'
#' Survey instruments sometimes include a "None of the above" option in the
#' BRANDAWARE pick list as an escape hatch ("I don't recognise any of these
#' brands"). The corresponding row in the Brands sheet is a pseudo-brand,
#' not a real one — it should never appear as a row in funnel / WoM /
#' relationship tables, nor as a real brand in CEP linkage computations.
#'
#' Matches common variants case-insensitively after stripping non-letter
#' characters: NONE, NoTA, N/A, n.a., n_a, noneoftheabove.
#'
#' @param brand_code Character vector of brand codes (NA-safe).
#' @return Logical vector — TRUE where the code is a NONE pseudo-brand.
#' @keywords internal
.is_none_brand_code <- function(brand_code) {
  if (is.null(brand_code) || length(brand_code) == 0L) {
    return(logical(0))
  }
  bc <- gsub("[^A-Za-z]", "", as.character(brand_code))
  out <- grepl("^(none|nota|na|noneoftheabove)$", bc, ignore.case = TRUE)
  out[is.na(brand_code)] <- FALSE
  out
}


#' Drop NONE pseudo-brand rows from a brand_list data frame
#'
#' Lightweight wrapper around \code{.is_none_brand_code} that filters a
#' brand_list data frame (must contain a BrandCode column). Returns the
#' input unchanged when no pseudo-brand rows are present.
#'
#' @param brand_list Data frame with at least a BrandCode column.
#' @return Filtered data frame.
#' @keywords internal
.drop_none_brands <- function(brand_list) {
  if (is.null(brand_list) || !"BrandCode" %in% names(brand_list)) {
    return(brand_list)
  }
  is_none <- .is_none_brand_code(brand_list$BrandCode)
  if (!any(is_none)) return(brand_list)
  brand_list[!is_none, , drop = FALSE]
}
