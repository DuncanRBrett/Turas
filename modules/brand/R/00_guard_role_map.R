# ==============================================================================
# BRAND MODULE — GUARDS V2 (REBUILD)
# ==============================================================================
# Rebuild-specific guard helpers. Extend the legacy 00_guard.R with:
#
#   * guard_alchemer_parser_shape(data) — refuses if the data file looks
#     like a raw Alchemer export (column-per-brand format) instead of
#     parser-cleaned slot-indexed format.
#
#   * guard_slot_columns_present(data, root, expected) — refuses if a
#     Multi_Mention root's expected slot columns are missing.
#
#   * guard_per_brand_column_present(data, root, cat, brand) — refuses if a
#     per-brand single-response column is absent (used by elements that
#     require attitude/WOM-count data).
#
#   * resolve_active_categories(data, brand_config) — non-refusing helper.
#     Returns the categories we should report on: Active = Y AND at least
#     one expected column present in data. Categories with Active = Y but
#     no data in the file get a "data not yet collected" placeholder.
#
# Every refusal flows through brand_refuse() (defined in 00_guard.R) so the
# console-visible boxed TURAS ERROR format is preserved.
#
# VERSION: 2.0
# ==============================================================================

BRAND_GUARD_V2_VERSION <- "2.0"


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Refuse if the data file is not AlchemerParser-cleaned shape
#'
#' Detects two telltale signs of un-parsed data:
#'   * Raw Alchemer headers like \code{X1, X2, ...} (sequence of unnamed cols)
#'   * Per-brand columns for Multi_Mention questions (e.g.
#'     \code{BRANDAWARE_DSS_IPK} as a 0/1 column instead of slot-indexed
#'     \code{BRANDAWARE_DSS_1..16}). Heuristic: more than 5 \code{BRANDAWARE_*}
#'     columns whose suffix is a brand code (not a digit).
#'
#' @param data Data frame.
#' @return Invisibly TRUE on pass; refuses with TRS error otherwise.
#' @export
guard_alchemer_parser_shape <- function(data) {
  if (!is.data.frame(data)) {
    .brand_v2_refuse(
      code = "DATA_NOT_DATA_FRAME",
      title = "Data is not a data frame",
      problem = "guard_alchemer_parser_shape() requires a data frame.",
      how_to_fix = "Pass a data frame loaded from your AlchemerParser output."
    )
  }

  cols <- names(data)
  if (length(cols) == 0L) {
    .brand_v2_refuse(
      code = "DATA_NO_COLUMNS",
      title = "Data file has no columns",
      problem = "Loaded data has zero columns.",
      how_to_fix = "Check the data file path and that the file is non-empty."
    )
  }

  # Telltale 1: raw Alchemer placeholders X1, X2, ...
  raw_placeholders <- grepl("^X[0-9]+$", cols)
  if (sum(raw_placeholders) >= 5L) {
    .brand_v2_refuse(
      code = "DATA_NO_ALCHEMER_PARSER_OUTPUT",
      title = "Data appears to be a raw Alchemer export",
      problem = paste(
        "Found", sum(raw_placeholders),
        "columns named like X1, X2, ... — typical of an unparsed Alchemer",
        "export with multi-row headers."),
      how_to_fix = c(
        "Run AlchemerParser on the export first.",
        "The brand module reads parser-cleaned output, never raw exports.",
        paste("See modules/brand/docs/PLANNING_IPK_REBUILD.md sec 5 for the",
              "expected data shape.")
      )
    )
  }

  # Telltale 2: column-per-brand BRANDAWARE_* shape
  bandaware_per_brand <- grep("^BRANDAWARE_[A-Z0-9]+_[A-Z]{2,}$",
                              cols, value = TRUE)
  bandaware_slot <- grep("^BRANDAWARE_[A-Z0-9]+_[0-9]+$",
                         cols, value = TRUE)
  if (length(bandaware_per_brand) > 5L && length(bandaware_slot) == 0L) {
    .brand_v2_refuse(
      code = "DATA_LEGACY_COLUMN_PER_BRAND",
      title = "Data uses pre-rebuild column-per-brand shape",
      problem = paste(
        "Found", length(bandaware_per_brand), "columns named like",
        "BRANDAWARE_{cat}_{brand} but zero slot-indexed BRANDAWARE_{cat}_N.",
        "The new brand module reads slot-indexed format only."),
      how_to_fix = c(
        "Run AlchemerParser on the export to produce slot-indexed columns.",
        "The brand module rebuild deprecated the column-per-brand format.",
        "If using a legacy fixture, regenerate it with the new fixture.",
        "tools at modules/brand/tests/fixtures/ipk_wave1/00_generate.R"
      )
    )
  }

  invisible(TRUE)
}


#' Refuse if expected slot columns for a Multi_Mention root are absent
#'
#' @param data Data frame.
#' @param root Question root (e.g. "BRANDAWARE_DSS").
#' @param min_slots Minimum number of slot columns required. Default 1.
#' @return Invisibly TRUE on pass.
#' @export
guard_slot_columns_present <- function(data, root, min_slots = 1L) {
  if (!is.data.frame(data)) {
    return(.brand_v2_refuse(
      code     = "DATA_NOT_DATA_FRAME",
      title    = "Data is not a data frame",
      problem  = "guard_slot_columns_present() requires a data frame.",
      how_to_fix = "Pass a data frame loaded from your AlchemerParser output."
    ))
  }
  pat <- paste0("^", .v2_regex_escape(root), "_[0-9]+$")
  found <- grep(pat, names(data), value = TRUE)
  if (length(found) < min_slots) {
    .brand_v2_refuse(
      code = "DATA_SLOT_COLUMNS_MISSING",
      title = sprintf("Slot columns missing for root '%s'", root),
      problem = sprintf(
        "Expected at least %d slot columns matching %s_N; found %d.",
        min_slots, root, length(found)),
      how_to_fix = c(
        sprintf("Confirm the data file contains %s_1, %s_2, ... columns",
                root, root),
        "Check AlchemerParser was run and produced this question.",
        "Verify Survey_Structure Questions sheet matches data shape."
      ),
      missing = paste0(root, "_N")
    )
  }
  invisible(TRUE)
}


#' Refuse if a per-brand single-response column is absent
#'
#' @param data Data frame.
#' @param root Question root (e.g. "BRANDATT1").
#' @param cat_code Category code (e.g. "DSS").
#' @param brand_code Brand code (e.g. "IPK").
#' @return Invisibly TRUE on pass.
#' @export
guard_per_brand_column_present <- function(data, root, cat_code, brand_code) {
  col <- paste0(root, "_", cat_code, "_", brand_code)
  if (!(col %in% names(data))) {
    .brand_v2_refuse(
      code = "DATA_PER_BRAND_COLUMN_MISSING",
      title = sprintf("Per-brand column missing: %s", col),
      problem = sprintf(
        "Column '%s' is required by the calling element but not in data.",
        col),
      how_to_fix = c(
        sprintf("Confirm column '%s' is in the parsed data file.", col),
        "Check the AlchemerParser output covers this brand-question pair.",
        "Verify brand code spelling matches the Brands sheet exactly."
      ),
      missing = col
    )
  }
  invisible(TRUE)
}


#' Determine which categories to report on
#'
#' Active = Y in Brand_Config AND at least one expected data column present.
#' Returns three lists:
#'   * full       — Active + has data; render full report
#'   * partial    — Active + has SOME but not all expected columns; render
#'                  with placeholder cards for missing elements
#'   * awaiting   — Active but zero data columns present
#'   * inactive   — Active = N (silently skipped from report)
#'
#' Non-refusing — caller decides how to render each list.
#'
#' @param data Data frame.
#' @param brand_config List with $categories.
#' @return List with named character vectors: full, partial, awaiting, inactive.
#' @export
resolve_active_categories <- function(data, brand_config) {
  if (is.null(brand_config) || is.null(brand_config$categories)) {
    return(list(full = character(0), partial = character(0),
                awaiting = character(0), inactive = character(0)))
  }
  cats <- brand_config$categories
  if (!"Active" %in% names(cats)) cats$Active <- "Y"

  inactive <- as.character(cats$CategoryCode[
    is.na(cats$Active) | toupper(cats$Active) != "Y"
  ])
  active <- as.character(cats$CategoryCode[
    !is.na(cats$Active) & toupper(cats$Active) == "Y"
  ])

  full <- character(0); partial <- character(0); awaiting <- character(0)
  data_names <- names(data)

  for (cc in active) {
    bucket <- .classify_category_data(cc, data_names)
    switch(bucket,
      full     = full     <- c(full, cc),
      partial  = partial  <- c(partial, cc),
      awaiting = awaiting <- c(awaiting, cc)
    )
  }

  list(full = full, partial = partial,
       awaiting = awaiting, inactive = inactive)
}


# ==============================================================================
# INTERNAL
# ==============================================================================

#' Classify a category's data presence in the file
#'
#' Looks for the expected DSS-style core columns. Heuristic — works for the
#' canonical naming convention; QuestionMap overrides bypass this check.
#'
#' @keywords internal
.classify_category_data <- function(cat_code, data_names) {
  expected <- c(
    paste0("BRANDAWARE_", cat_code),
    paste0("BRANDPEN1_", cat_code),
    paste0("BRANDPEN2_", cat_code),
    paste0("CATBUY_", cat_code)
  )
  pats <- vapply(expected, function(root) {
    any(grepl(paste0("^", .v2_regex_escape(root), "(_[0-9]+)?$"), data_names))
  }, logical(1))
  hits <- sum(pats)
  if (hits == length(expected)) "full"
  else if (hits == 0L)          "awaiting"
  else                          "partial"
}

.v2_regex_escape <- function(s) {
  gsub("([\\.\\+\\*\\?\\(\\)\\[\\]\\{\\}\\|\\^\\$])",
       "\\\\\\1", s, perl = TRUE)
}

#' Refuse helper that uses brand_refuse() if available, else falls back
#' @keywords internal
.brand_v2_refuse <- function(code, title, problem, how_to_fix,
                             missing = NULL, ...) {
  if (exists("brand_refuse", mode = "function")) {
    brand_refuse(code = code, title = title, problem = problem,
                 why_it_matters = "Brand module rebuild guard.",
                 how_to_fix = how_to_fix, missing = missing, ...)
  } else {
    msg <- sprintf("[%s] %s — %s\nHow to fix: %s",
                   code, title, problem,
                   paste(how_to_fix, collapse = "; "))
    cat("\n=== TURAS ERROR ===\n", msg, "\n===================\n", sep = "")
    stop(msg, call. = FALSE)
  }
}
