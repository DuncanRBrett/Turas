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
                                             weights = NULL) {
  if (is.null(attitude_entry) || is.null(attitude_entry$option_map)) {
    return(.empty_attitude_df())
  }
  n_resp <- nrow(awareness_matrix)
  w <- weights %||% rep(1, n_resp)
  brands <- as.character(brand_list$BrandCode)

  role_to_codes <- .option_map_by_role(attitude_entry$option_map)
  rows <- list()
  for (b in brands) {
    col <- .column_for_brand(attitude_entry, b)
    if (is.null(col) || !(col %in% names(data))) next
    rows <- c(rows, .attitude_rows_for_brand(
      b, data[[col]], awareness_matrix[, b], w, role_to_codes))
  }
  if (length(rows) == 0) return(.empty_attitude_df())
  do.call(rbind, rows)
}


# ==============================================================================
# run_significance_tests
# ==============================================================================

#' Focal-vs-competitor + focal-vs-cat-avg two-proportion z-tests per stage
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
    focal_row <- stage_rows[stage_rows$brand_code == focal_brand, ,
                            drop = FALSE]
    if (nrow(focal_row) != 1) next
    for (b in setdiff(brands, focal_brand)) {
      comp_row <- stage_rows[stage_rows$brand_code == b, , drop = FALSE]
      if (nrow(comp_row) == 1) {
        rows[[length(rows) + 1]] <- .sig_row(focal_row, comp_row,
          stage_key, focal_brand, b, "focal_vs_competitor",
          sig_tester, alpha)
      }
    }
    cat_avg <- .category_average_excluding_focal(stage_rows, focal_brand)
    if (!is.null(cat_avg)) {
      rows[[length(rows) + 1]] <- .sig_row_against_summary(
        focal_row, cat_avg, stage_key, focal_brand,
        "category_avg", "focal_vs_cat_avg", sig_tester, alpha)
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
  if (!any(aware_vec)) return(list())
  aware_w <- sum(weights[aware_vec], na.rm = TRUE)
  if (aware_w == 0) return(list())

  values_char <- as.character(col_values)
  rows <- list()
  for (role in .FUNNEL_ATTITUDE_POSITIONS) {
    codes <- role_to_codes[[role]]
    if (is.null(codes) || length(codes) == 0) next
    hits <- aware_vec & !is.na(values_char) & values_char %in% codes
    pct <- sum(weights[hits], na.rm = TRUE) / aware_w
    rows[[length(rows) + 1]] <- data.frame(
      brand_code = brand_code,
      attitude_role = role,
      pct = pct,
      base = aware_w,
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


.category_average_excluding_focal <- function(stage_rows, focal_brand) {
  other <- stage_rows[stage_rows$brand_code != focal_brand, , drop = FALSE]
  if (nrow(other) == 0) return(NULL)
  tot_base <- sum(other$base_weighted, na.rm = TRUE)
  tot_n <- sum(
    ifelse(other$pct_weighted > 0,
           other$base_weighted / other$pct_weighted, NA_real_),
    na.rm = TRUE)
  if (tot_n <= 0 || !is.finite(tot_n)) return(NULL)
  list(base = tot_base, total_n = tot_n,
       pct = tot_base / tot_n)
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
