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
#' @return Logical vector, length \code{nrow(data)}.
#' @examples
#' \dontrun{
#'   ipk_aware <- respondent_picked(data, "BRANDAWARE_DSS", "IPK")
#' }
#' @export
respondent_picked <- function(data, root, option_code) {
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
  hit <- rep(FALSE, nrow(data))
  for (col in cols) {
    vals <- as.character(data[[col]])
    hit <- hit | (!is.na(vals) & vals == target)
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
#' @param brand_codes Character vector of brand codes.
#' @return Logical matrix of dimension \code{[nrow(data) × length(brand_codes)]},
#'   with \code{brand_codes} as \code{colnames}.
#' @examples
#' \dontrun{
#'   mat <- multi_mention_brand_matrix(data, "BRANDPEN1_DSS",
#'                                     c("IPK", "ROB", "KNORR"))
#' }
#' @export
multi_mention_brand_matrix <- function(data, root, brand_codes) {
  .require_dataframe(data)
  .require_root(root)
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
    hit <- rep(FALSE, nrow(data))
    for (vals in slot_vals) {
      hit <- hit | (!is.na(vals) & vals == b)
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
#' @param brand_codes Character vector of brand codes.
#' @return Character matrix \code{[nrow(data) × length(brand_codes)]} with
#'   \code{brand_codes} as \code{colnames}. NA where the column is absent.
#' @examples
#' \dontrun{
#'   mat <- single_response_brand_matrix(data, "BRANDATT1", "DSS",
#'                                       c("IPK", "ROB"))
#' }
#' @export
single_response_brand_matrix <- function(data, root, cat_code, brand_codes) {
  .require_dataframe(data)
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
    }
  }
  mat
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
    stop(msg, call. = FALSE)
  }
}
