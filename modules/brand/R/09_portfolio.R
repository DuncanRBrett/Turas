# ==============================================================================
# BRAND MODULE - PORTFOLIO MAPPING ORCHESTRATOR
# ==============================================================================
# Entry point for all portfolio analyses (footprint, constellation, clutter,
# strength, extension). Sub-analyses are delegated to 09a-09e files in
# phases 2-5 of the build.
#
# DENOMINATOR RULE (§3.1 of PORTFOLIO_SPEC_v1.md):
#   build_portfolio_base() is the single source of truth for the SQ1/SQ2
#   qualifier filter. Every analysis calls it. No analysis file should filter
#   SQ1_* or SQ2_* columns directly. A grep for "SQ1_" or "SQ2_" in new
#   code should return only this function.
#
# VERSION: 1.0
# ==============================================================================

PORTFOLIO_VERSION <- "1.0"

PORTFOLIO_TIMEFRAME_3M  <- "3m"
PORTFOLIO_TIMEFRAME_13M <- "13m"

PORTFOLIO_MIN_BASE_DEFAULT          <- 30L
PORTFOLIO_COOCCUR_MIN_PAIRS_DEFAULT <- 20L
PORTFOLIO_EDGE_TOP_N_DEFAULT        <- 40L


# ==============================================================================
# DENOMINATOR HELPER
# ==============================================================================

#' Build portfolio analysis denominator base for one category
#'
#' Single source of truth for the SQ1/SQ2 qualifier filter (§3.1 of spec).
#' Every portfolio analysis calls this function; no analysis file should filter
#' SQ1_* or SQ2_* columns directly.
#'
#' For timeframe = "3m", uses SQ2_{cat_code}.
#' For timeframe = "13m", uses SQ1_{cat_code}.
#'
#' @param data Data frame. Full survey data.
#' @param cat_code Character scalar. Category code, e.g. "DSS".
#' @param timeframe Character scalar. "3m" or "13m". Default "3m".
#' @param weights Numeric vector or NULL. Survey weights (length == nrow(data)).
#'   NULL treated as uniform weights of 1.0.
#'
#' @return List:
#'   \item{idx}{Logical vector, length == nrow(data). TRUE = qualifier.}
#'   \item{n_uw}{Integer. Unweighted count of qualifiers.}
#'   \item{n_w}{Numeric. Weighted count of qualifiers.}
#'   \item{col_used}{Character. Column actually used (e.g. "SQ2_DSS").}
#'
#'   On failure: TRS-shaped list with status = "REFUSED".
#'
#' @keywords internal
build_portfolio_base <- function(data, cat_code,
                                 timeframe = PORTFOLIO_TIMEFRAME_3M,
                                 weights = NULL) {

  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(list(
      status     = "REFUSED",
      code       = "DATA_PORTFOLIO_NO_AWARENESS_COLS",
      message    = "data must be a non-empty data frame",
      how_to_fix = "Provide a non-empty data frame to build_portfolio_base()",
      context    = list(cat_code = cat_code, timeframe = timeframe)
    ))
  }

  if (is.null(cat_code) || length(cat_code) != 1L ||
      !nzchar(trimws(as.character(cat_code)))) {
    return(list(
      status     = "REFUSED",
      code       = "DATA_PORTFOLIO_TIMEFRAME_MISSING",
      message    = "cat_code must be a non-empty character scalar",
      how_to_fix = "Provide a valid category code such as 'DSS' or 'POS'",
      context    = list(cat_code = cat_code)
    ))
  }

  cat_code <- trimws(as.character(cat_code))

  if (identical(timeframe, PORTFOLIO_TIMEFRAME_3M)) {
    primary_col  <- paste0("SQ2_", cat_code)
    fallback_col <- paste0("SQ1_", cat_code)
  } else {
    primary_col  <- paste0("SQ1_", cat_code)
    fallback_col <- NULL
  }

  col_used <- if (primary_col %in% names(data)) {
    primary_col
  } else if (!is.null(fallback_col) && fallback_col %in% names(data)) {
    fallback_col
  } else {
    NULL
  }

  if (is.null(col_used)) {
    return(list(
      status     = "REFUSED",
      code       = "DATA_PORTFOLIO_TIMEFRAME_MISSING",
      message    = sprintf(
        "No screener column found for category '%s' with timeframe '%s'. Expected '%s'.",
        cat_code, timeframe, primary_col
      ),
      how_to_fix = sprintf(
        paste0("Ensure the data contains column '%s'. ",
               "If the survey used only SQ1, switch portfolio_timeframe to '13m'."),
        primary_col
      ),
      context    = list(
        cat_code     = cat_code,
        timeframe    = timeframe,
        expected_col = primary_col
      )
    ))
  }

  vals <- data[[col_used]]
  idx  <- !is.na(vals) & as.integer(vals) == 1L
  n_uw <- sum(idx)

  w   <- if (!is.null(weights)) weights else rep(1.0, nrow(data))
  n_w <- sum(w[idx], na.rm = TRUE)

  list(
    idx      = idx,
    n_uw     = n_uw,
    n_w      = n_w,
    col_used = col_used
  )
}


# ==============================================================================
# MAIN ORCHESTRATOR (stub — filled in phases 2-5)
# ==============================================================================

#' Run portfolio mapping analysis
#'
#' Orchestrates all five portfolio analyses: footprint heatmap (§4.1),
#' competitive constellation (§4.2), clutter quadrant (§4.3), portfolio
#' strength map (§4.4), and permission-to-extend table (§4.5).
#'
#' Sub-analyses are implemented in 09a_portfolio_footprint.R through
#' 09e_portfolio_extension.R and wired in here in phases 2-5.
#'
#' @param data Data frame. Full survey data — all respondents, not filtered.
#' @param categories Data frame. Categories sheet from loaded brand config.
#' @param structure List. Loaded survey structure (from load_brand_survey_structure).
#' @param config List. Loaded brand config (from load_brand_config).
#' @param weights Numeric vector or NULL. Survey weights, length == nrow(data).
#'
#' @return List with:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{focal_brand}{Character. Focal brand code.}
#'   \item{timeframe}{Character. "3m" or "13m".}
#'   \item{n_total}{Integer. Total respondents.}
#'   \item{n_weighted}{Numeric. Weighted total.}
#'   \item{bases}{List. Per-category and per-brand base counts.}
#'   \item{footprint_matrix}{Matrix or NULL. Brand x category awareness %.}
#'   \item{constellation}{List or NULL. Nodes, edges, layout.}
#'   \item{clutter}{Data frame or NULL. Per-category quadrant data.}
#'   \item{strength}{List or NULL. Per-brand strength data.}
#'   \item{extension}{Data frame or NULL. Permission-to-extend lift table.}
#'   \item{supporting}{List or NULL. Hero-strip KPI values.}
#'   \item{suppressions}{List. Low-base categories, dropped brands/edges.}
#'
#' @export
run_portfolio <- function(data, categories, structure, config, weights = NULL) {

  focal     <- config$focal_brand %||% ""
  timeframe <- config$portfolio_timeframe %||% PORTFOLIO_TIMEFRAME_3M

  # --- Guard validation (turas_refuse throws; catch and convert to TRS list) ---
  guard_result <- tryCatch(
    guard_validate_portfolio(data, categories, structure, config),
    turas_refusal = function(e) {
      list(
        status     = "REFUSED",
        code       = e$code,
        message    = e$problem %||% conditionMessage(e),
        how_to_fix = e$how_to_fix
      )
    }
  )
  if (!is.null(guard_result$status) && identical(guard_result$status, "REFUSED")) {
    cat("\n┌─── TURAS BRAND ERROR ──────────────────────────────────────────┐\n")
    cat("│ Context: run_portfolio()\n")
    cat(sprintf("│ Code: %s\n", guard_result$code))
    cat(sprintf("│ Message: %s\n", guard_result$message))
    cat(sprintf("│ How to fix: %s\n",
                paste(guard_result$how_to_fix, collapse = "; ")))
    cat("└────────────────────────────────────────────────────────────────┘\n\n")
    return(guard_result)
  }

  n_total   <- nrow(data)
  total_w   <- if (!is.null(weights)) {
    sum(weights, na.rm = TRUE)
  } else {
    as.numeric(n_total)
  }

  # Phase 2: footprint matrix + clutter quadrant
  footprint_result <- tryCatch(
    compute_footprint_matrix(data, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO] Footprint failed: %s", e$message))
      NULL
    }
  )

  clutter_result <- tryCatch(
    compute_clutter_data(data, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO] Clutter failed: %s", e$message))
      NULL
    }
  )

  # Phase 3: strength map + extension
  strength_result <- tryCatch(
    compute_strength_map(data, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO] Strength failed: %s", e$message))
      NULL
    }
  )

  extension_result <- tryCatch(
    compute_extension_table(data, categories, structure, config, weights,
                            footprint_result = footprint_result),
    error = function(e) {
      message(sprintf("[PORTFOLIO] Extension failed: %s", e$message))
      NULL
    }
  )

  # Phase 4: constellation (stub)
  constellation_result <- NULL

  # Aggregate suppressed categories across analyses
  all_suppressed <- unique(c(
    if (!is.null(footprint_result)) footprint_result$suppressed_cats   else character(0),
    if (!is.null(clutter_result))   clutter_result$suppressed_cats     else character(0),
    if (!is.null(strength_result))  strength_result$suppressed_cats    else character(0),
    if (!is.null(extension_result) &&
        identical(extension_result$status, "PASS"))
      extension_result$suppressed_cats else character(0)
  ))

  # Build per-category bases from footprint
  bases_per_cat <- if (!is.null(footprint_result) &&
                        !is.null(footprint_result$bases_df) &&
                        nrow(footprint_result$bases_df) > 0) {
    footprint_result$bases_df
  } else {
    data.frame(cat = character(0), n_buyers_uw = integer(0),
               n_buyers_w = numeric(0), stringsAsFactors = FALSE)
  }

  list(
    status       = "PASS",
    focal_brand  = focal,
    timeframe    = timeframe,
    n_total      = n_total,
    n_weighted   = total_w,
    bases        = list(
      per_category = bases_per_cat,
      per_brand    = data.frame(
        brand                = character(0),
        n_aware_uw           = integer(0),
        n_aware_w            = numeric(0),
        n_categories_present = integer(0),
        stringsAsFactors     = FALSE
      )
    ),
    footprint_matrix = if (!is.null(footprint_result)) footprint_result$matrix_df else NULL,
    constellation    = constellation_result,
    clutter          = clutter_result,
    strength         = if (!is.null(strength_result) &&
                           identical(strength_result$status, "PASS"))
                         strength_result else NULL,
    extension        = if (!is.null(extension_result) &&
                           identical(extension_result$status, "PASS"))
                         extension_result else NULL,
    supporting       = NULL,
    suppressions     = list(
      low_base_cats  = all_suppressed,
      dropped_brands = character(0),
      dropped_edges  = 0L
    )
  )
}
