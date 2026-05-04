# ==============================================================================
# BRAND MODULE - FUNNEL METRICS + CONVERSIONS + ATTITUDE DECOMPOSITION
# ==============================================================================
# Pure-logic layer: converts the logical matrices from derive_funnel_stages()
# into weighted percentages, conversion ratios, a 5-position attitude
# decomposition, and significance tests against the focal brand and
# category average.
#
# Reference: FUNNEL_SPEC_v2.md §5.2 and §8.
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_METRICS_VERSION <- "2.0"


# ==============================================================================
# CONSTANTS
# ==============================================================================

# Attitude position roles in display order (matches ROLE_REGISTRY §4.2).
.FUNNEL_ATTITUDE_POSITIONS <- c(
  "attitude.love", "attitude.prefer", "attitude.ambivalent",
  "attitude.reject", "attitude.no_opinion"
)

# IPK-canonical numeric attitude codes mapped to attitude roles. Used when
# the role-map entry has no option_map (v2 convention-first inference).
# Operators following a different coding scheme can supply an override via
# attitude_entry$attitude_role_codes (a named list of role -> codes).
.FUNNEL_DEFAULT_ATTITUDE_ROLE_CODES <- list(
  "attitude.love"       = "1",
  "attitude.prefer"     = "2",
  "attitude.ambivalent" = "3",
  "attitude.reject"     = "4",
  "attitude.no_opinion" = "5"
)


# ==============================================================================
# calculate_stage_metrics
# ==============================================================================

#' Compute weighted % and base per (stage × brand)
#'
#' @param stages Named list from derive_funnel_stages()$stages.
#' @param weights Numeric respondent weights, or NULL for unweighted.
#' @param warn_base Integer. Base below which to flag warn.
#' @param suppress_base Integer. Base below which to suppress (0 = off).
#'
#' @return Data frame long-format: brand_code × stage_key × pct_weighted ×
#'   pct_unweighted × base_weighted × base_unweighted × warning_flag
#'   (none / warn / suppress). NULL stages contribute no rows.
#'
#' @export
calculate_stage_metrics <- function(stages, weights = NULL,
                                    warn_base = 75, suppress_base = 0) {
  if (length(stages) == 0) return(.empty_stage_df())

  n_resp <- nrow(stages[[1]]$matrix)
  w <- weights %||% rep(1, n_resp)
  sum_w <- sum(w, na.rm = TRUE)

  out_list <- lapply(stages, function(stage) {
    .one_stage_row(stage, w, sum_w, n_resp, warn_base, suppress_base)
  })
  do.call(rbind, out_list)
}


# ==============================================================================
# calculate_conversions
# ==============================================================================

#' Compute per-stage-transition conversion metrics
#'
#' @param stage_metrics Output of calculate_stage_metrics().
#' @param method One of "ratio", "absolute_gap".
#'
#' @return Data frame long-format: brand_code × from_stage × to_stage ×
#'   value × method. Conversions are NA when the previous stage's
#'   percentage is zero under the "ratio" method.
#'
#' @export
calculate_conversions <- function(stage_metrics, method = "ratio") {
  if (!(method %in% c("ratio", "absolute_gap"))) {
    brand_refuse(
      code = "CFG_CONVERSION_METHOD_INVALID",
      title = "Unknown Conversion Method",
      problem = sprintf("funnel.conversion_metric = '%s' is not valid.", method),
      why_it_matters = paste(
        "Conversion metrics drive the stage-to-stage labels. Only 'ratio'",
        "and 'absolute_gap' are implemented."
      ),
      how_to_fix = "Set funnel.conversion_metric to 'ratio' or 'absolute_gap'.",
      expected = "ratio, absolute_gap",
      observed = method
    )
  }
  if (is.null(stage_metrics) || nrow(stage_metrics) == 0) {
    return(.empty_conv_df())
  }

  stages_in_order <- unique(stage_metrics$stage_key)
  if (length(stages_in_order) < 2) return(.empty_conv_df())

  brands <- unique(stage_metrics$brand_code)
  rows <- list()
  for (b in brands) {
    sub <- stage_metrics[stage_metrics$brand_code == b, , drop = FALSE]
    sub <- sub[match(stages_in_order, sub$stage_key), , drop = FALSE]
    for (i in seq(2, nrow(sub))) {
      rows[[length(rows) + 1]] <- .one_conversion_row(
        sub[i - 1, ], sub[i, ], method)
    }
  }
  do.call(rbind, rows)
}


# ==============================================================================
# calculate_attitude_decomposition
# ==============================================================================

#' Decompose attitude into the 5 positions (% of aware base) per brand
#'
#' @param attitude_entry Role-map entry for funnel.attitude.
#' @param awareness_matrix Logical matrix respondents × brands from Aware stage.
#' @param data Data frame of survey responses.
#' @param brand_list Data frame with BrandCode column.
#' @param weights Numeric weights or NULL.
#'
#' @return Data frame long-format: brand_code × attitude_role × pct × base.
#'
#' @export
calculate_attitude_decomposition <- function(attitude_entry, awareness_matrix,
                                             data, brand_list,
                                             weights = NULL,
                                             positive_attitude_codes = NULL) {
  if (is.null(attitude_entry)) return(.empty_attitude_df())
  n_resp <- nrow(awareness_matrix)
  w <- weights %||% rep(1, n_resp)
  brands <- as.character(brand_list$BrandCode)

  role_to_codes <- .resolve_attitude_role_codes(attitude_entry)
  rows <- list()
  if (isTRUE(attitude_entry$per_brand)) {
    # v2 entry: read per-brand columns via the data-access layer
    val_mat <- single_response_brand_matrix(data, attitude_entry$client_code,
                                            attitude_entry$category, brands)
    for (b in brands) {
      vals <- val_mat[, b]
      if (all(is.na(vals))) next
      rows <- c(rows, .attitude_rows_for_brand(
        b, vals, awareness_matrix[, b], w, role_to_codes))
    }
  } else if (!is.null(attitude_entry$columns)) {
    # Legacy entry: iterate per-brand columns via column suffix matching
    for (b in brands) {
      col <- .legacy_column_for_brand(attitude_entry, b)
      if (is.null(col) || !(col %in% names(data))) next
      rows <- c(rows, .attitude_rows_for_brand(
        b, data[[col]], awareness_matrix[, b], w, role_to_codes))
    }
  }
  if (length(rows) == 0) return(.empty_attitude_df())
  do.call(rbind, rows)
}


#' Resolve attitude role -> codes mapping
#'
#' Order of precedence:
#'   1. attitude_entry$attitude_role_codes (operator-supplied override)
#'   2. attitude_entry$option_map (legacy QuestionMap path)
#'   3. .FUNNEL_DEFAULT_ATTITUDE_ROLE_CODES (IPK convention, 1..5)
#'
#' @keywords internal
.resolve_attitude_role_codes <- function(attitude_entry) {
  if (!is.null(attitude_entry$attitude_role_codes)) {
    return(attitude_entry$attitude_role_codes)
  }
  if (!is.null(attitude_entry$option_map)) {
    return(.option_map_by_role(attitude_entry$option_map))
  }
  .FUNNEL_DEFAULT_ATTITUDE_ROLE_CODES
}


#' Find a per-brand column inside a legacy role entry's $columns vector
#' @keywords internal
.legacy_column_for_brand <- function(entry, brand_code) {
  if (is.null(entry) || length(entry$columns) == 0) return(NULL)
  hits <- entry$columns[endsWith(entry$columns, paste0("_", brand_code))]
  if (length(hits) == 0) return(NULL)
  hits[1]
}


# ==============================================================================
# run_significance_tests
# ==============================================================================

#' Two-proportion z-tests per stage — three comparison families
#'
#' Emits three comparison flavours per stage:
#' \describe{
#'   \item{\code{focal_vs_competitor}}{One row per competitor: focal's
#'     proportion vs that competitor's proportion.}
#'   \item{\code{brand_vs_cat_avg}}{One row per brand (including focal):
#'     that brand's proportion vs the category average computed over
#'     every OTHER brand at the same stage. Used for in-cell ▲/▼ flags
#'     across the whole table, not just the focal row.}
#'   \item{\code{focal_vs_cat_avg}}{Legacy alias — same as
#'     \code{brand_vs_cat_avg} for the focal row. Kept so existing panel
#'     code reading this comparison keeps working.}
#' }
#'
#' @param stage_metrics Output of calculate_stage_metrics().
#' @param focal_brand Character code of the focal brand.
#' @param sig_tester Closure: function(x1, n1, x2, n2, alpha) → list(p_value,
#'   significant, direction). NULL disables testing.
#' @param alpha Significance level (e.g. 0.05).
#'
#' @return Data frame long-format: stage_key × brand_code × comparison ×
#'   direction × p_value × significant. Empty when sig_tester is NULL.
#'
#' @export
run_significance_tests <- function(stage_metrics, focal_brand,
                                   sig_tester = NULL, alpha = 0.05) {
  if (is.null(sig_tester) || is.null(stage_metrics) ||
      nrow(stage_metrics) == 0) {
    return(.empty_sig_df())
  }
  stages_in_order <- unique(stage_metrics$stage_key)
  brands <- unique(stage_metrics$brand_code)
  rows <- list()
  for (stage_key in stages_in_order) {
    stage_rows <- stage_metrics[stage_metrics$stage_key == stage_key, ,
                                drop = FALSE]

    # (1) focal vs every competitor
    focal_row <- stage_rows[stage_rows$brand_code == focal_brand, ,
                            drop = FALSE]
    if (nrow(focal_row) == 1) {
      for (b in setdiff(brands, focal_brand)) {
        comp_row <- stage_rows[stage_rows$brand_code == b, , drop = FALSE]
        if (nrow(comp_row) == 1) {
          rows[[length(rows) + 1]] <- .sig_row(focal_row, comp_row,
            stage_key, focal_brand, b, "focal_vs_competitor",
            sig_tester, alpha)
        }
      }
    }

    # (2) every brand vs category average (excluding itself)
    for (b in brands) {
      brand_row <- stage_rows[stage_rows$brand_code == b, , drop = FALSE]
      if (nrow(brand_row) != 1) next
      cat_avg <- .category_average_excluding(stage_rows, b)
      if (is.null(cat_avg)) next
      # brand_code on the emitted row = the brand tested (not "category_avg")
      rows[[length(rows) + 1]] <- .sig_row_against_summary(
        brand_row, cat_avg, stage_key, b,
        b, "brand_vs_cat_avg", sig_tester, alpha)
      # Legacy alias kept on the focal row so downstream panel_data that
      # still reads `focal_vs_cat_avg` continues to resolve.
      if (identical(b, focal_brand)) {
        rows[[length(rows) + 1]] <- .sig_row_against_summary(
          brand_row, cat_avg, stage_key, focal_brand,
          focal_brand, "focal_vs_cat_avg", sig_tester, alpha)
      }
    }
  }
  if (length(rows) == 0) return(.empty_sig_df())
  do.call(rbind, rows)
}


# ==============================================================================
# INTERNAL: HELPERS
# ==============================================================================

.empty_stage_df <- function() {
  data.frame(brand_code = character(0), stage_key = character(0),
             pct_weighted = numeric(0), pct_unweighted = numeric(0),
             base_weighted = numeric(0), base_unweighted = numeric(0),
             warning_flag = character(0),
             stringsAsFactors = FALSE)
}

.empty_conv_df <- function() {
  data.frame(brand_code = character(0), from_stage = character(0),
             to_stage = character(0), value = numeric(0),
             method = character(0),
             stringsAsFactors = FALSE)
}

.empty_attitude_df <- function() {
  data.frame(brand_code = character(0), attitude_role = character(0),
             pct = numeric(0), base = numeric(0),
             stringsAsFactors = FALSE)
}

.empty_sig_df <- function() {
  data.frame(stage_key = character(0), brand_code = character(0),
             comparison = character(0), direction = character(0),
             p_value = numeric(0), significant = logical(0),
             stringsAsFactors = FALSE)
}


.one_stage_row <- function(stage, w, sum_w, n_resp, warn_base, suppress_base) {
  m <- stage$matrix
  brands <- colnames(m)
  pct_w <- colSums(m * w, na.rm = TRUE) / ifelse(sum_w > 0, sum_w, NA_real_)
  pct_u <- colSums(m, na.rm = TRUE) / n_resp
  base_w <- colSums(m * w, na.rm = TRUE)
  base_u <- colSums(m, na.rm = TRUE)
  flag <- ifelse(base_u < suppress_base, "suppress",
                 ifelse(base_u < warn_base, "warn", "none"))
  data.frame(brand_code = brands,
             stage_key = rep(stage$key, length(brands)),
             pct_weighted = unname(pct_w),
             pct_unweighted = unname(pct_u),
             base_weighted = unname(base_w),
             base_unweighted = unname(base_u),
             warning_flag = flag,
             stringsAsFactors = FALSE)
}


.one_conversion_row <- function(prev_row, curr_row, method) {
  if (method == "ratio") {
    val <- if (is.na(prev_row$pct_weighted) || prev_row$pct_weighted <= 0) {
      NA_real_
    } else {
      curr_row$pct_weighted / prev_row$pct_weighted
    }
  } else {
    val <- curr_row$pct_weighted - prev_row$pct_weighted
  }
  data.frame(brand_code = curr_row$brand_code,
             from_stage = prev_row$stage_key,
             to_stage = curr_row$stage_key,
             value = val,
             method = method,
             stringsAsFactors = FALSE)
}


.attitude_rows_for_brand <- function(brand_code, col_values, aware_vec,
                                     weights, role_to_codes) {
  total_w <- sum(weights, na.rm = TRUE)
  if (total_w == 0) return(list())

  # aware_base = weighted count of respondents aware of this brand.
  # Stored separately so .panel_consideration_detail can expose it as the
  # denominator for "% aware" display without changing the pct contract
  # (pct = count/total_w, the session-3 base).
  aware_w <- sum(weights[as.logical(aware_vec)], na.rm = TRUE)

  values_char <- as.character(col_values)
  rows <- list()
  for (role in .FUNNEL_ATTITUDE_POSITIONS) {
    codes <- role_to_codes[[role]]
    if (is.null(codes) || length(codes) == 0) next
    hits <- !is.na(values_char) & values_char %in% codes
    pct <- sum(weights[hits], na.rm = TRUE) / total_w
    rows[[length(rows) + 1]] <- data.frame(
      brand_code  = brand_code,
      attitude_role = role,
      pct         = pct,
      base        = total_w,
      aware_base  = aware_w,
      stringsAsFactors = FALSE
    )
  }
  rows
}


.option_map_by_role <- function(option_map) {
  out <- list()
  for (role in .FUNNEL_ATTITUDE_POSITIONS) {
    sub <- option_map[!is.na(option_map$Role) &
                        option_map$Role == role, , drop = FALSE]
    out[[role]] <- trimws(as.character(sub$ClientCode))
  }
  out
}


.sig_row <- function(focal_row, comp_row, stage_key, focal, comp,
                     comparison, sig_tester, alpha) {
  x1 <- focal_row$base_weighted
  n1 <- focal_row$base_weighted / ifelse(focal_row$pct_weighted > 0,
                                         focal_row$pct_weighted, NA_real_)
  x2 <- comp_row$base_weighted
  n2 <- comp_row$base_weighted / ifelse(comp_row$pct_weighted > 0,
                                        comp_row$pct_weighted, NA_real_)
  res <- tryCatch(sig_tester(x1, n1, x2, n2, alpha),
                  error = function(e) list(p_value = NA_real_,
                                           significant = FALSE,
                                           direction = "na"))
  data.frame(stage_key = stage_key,
             brand_code = comp,
             comparison = comparison,
             direction = res$direction %||% "na",
             p_value = res$p_value %||% NA_real_,
             significant = isTRUE(res$significant),
             stringsAsFactors = FALSE)
}


.sig_row_against_summary <- function(focal_row, summary_row, stage_key,
                                     focal, label, comparison,
                                     sig_tester, alpha) {
  x1 <- focal_row$base_weighted
  n1 <- focal_row$base_weighted / ifelse(focal_row$pct_weighted > 0,
                                         focal_row$pct_weighted, NA_real_)
  x2 <- summary_row$base
  n2 <- summary_row$total_n
  res <- tryCatch(sig_tester(x1, n1, x2, n2, alpha),
                  error = function(e) list(p_value = NA_real_,
                                           significant = FALSE,
                                           direction = "na"))
  data.frame(stage_key = stage_key,
             brand_code = label,
             comparison = comparison,
             direction = res$direction %||% "na",
             p_value = res$p_value %||% NA_real_,
             significant = isTRUE(res$significant),
             stringsAsFactors = FALSE)
}


#' Category average excluding one brand — used both for the focal's
#' vs-average comparison and for every brand's own vs-average test.
#'
#' pct is the simple mean of per-brand percentages (not a pooled proportion).
#' total_n is the mean per-brand eligible base, used as the denominator in
#' the two-proportion sig test. Summing eligible N across brands inflates by
#' k (the number of brands) because every respondent is counted once per brand;
#' using the mean keeps the sig test at a single-brand-equivalent base.
#' @keywords internal
.category_average_excluding <- function(stage_rows, excluded_brand) {
  other <- stage_rows[stage_rows$brand_code != excluded_brand, , drop = FALSE]
  if (nrow(other) == 0) return(NULL)

  implied_n <- ifelse(other$pct_weighted > 0,
                      other$base_weighted / other$pct_weighted, NA_real_)
  avg_n <- mean(implied_n, na.rm = TRUE)
  if (!is.finite(avg_n) || avg_n <= 0) return(NULL)

  avg_pct <- mean(other$pct_weighted, na.rm = TRUE)
  list(base    = avg_pct * avg_n,
       total_n = avg_n,
       pct     = avg_pct)
}

# Backwards-compat alias — older code paths may still reference this.
.category_average_excluding_focal <- function(stage_rows, focal_brand) {
  .category_average_excluding(stage_rows, focal_brand)
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel metrics loaded (v%s)",
                  BRAND_FUNNEL_METRICS_VERSION))
}
