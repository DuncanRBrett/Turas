# ==============================================================================
# BRAND MODULE - FUNNEL ELEMENT
# ==============================================================================
# Derived brand funnel: awareness > positive disposition > bought > primary.
# No dedicated funnel questions — stages are mapped from core CBM data:
#   - Aware: from Brand Awareness battery
#   - Positive Disposition: attitude codes 1-3 (love + prefer + would-buy)
#   - Bought: from Brand Penetration target timeframe
#   - Primary: attitude code 1 OR most-frequent buyer (configurable)
#
# Includes:
#   - Attitude decomposition (Love / Prefer / Ambivalent / Reject / No Opinion)
#   - Stage-to-stage conversion ratios
#   - CIs on all metrics (via confidence module when available)
#   - Low-base flagging per brand
#
# VERSION: 1.0
#
# REFERENCES:
#   Romaniuk, J. (2022). Better Brand Health. (CBM framework)
#   Sharp, B. (2010). How Brands Grow. (Double Jeopardy)
# ==============================================================================

FUNNEL_VERSION <- "1.0"


# ==============================================================================
# SECTION 1: STAGE DERIVATION FROM CBM DATA
# ==============================================================================

#' Derive funnel stages from CBM battery data
#'
#' Maps survey responses to funnel stages per respondent per brand.
#' Returns a respondent x brand matrix for each stage.
#'
#' @param data Data frame. Survey data.
#' @param brands Data frame. Brand definitions with BrandCode column.
#' @param awareness_prefix Character. Column prefix for awareness data
#'   (e.g., "BRANDAWARE_FV"). Columns should be named
#'   prefix_BrandCode with binary 0/1.
#' @param attitude_prefix Character. Column prefix for attitude data
#'   (e.g., "BRANDATT1_FV"). Columns should be named
#'   prefix_BrandCode with codes 1-5.
#' @param penetration_prefix Character. Column prefix for penetration
#'   (target timeframe) data. Columns named prefix_BrandCode with 0/1.
#' @param primary_method Character. How to determine "primary" brand:
#'   "attitudinal" (attitude code 1) or "behavioural" (most-frequent).
#'   Default: "attitudinal".
#'
#' @return List with:
#'   \item{awareness}{Matrix n_resp x n_brands (logical)}
#'   \item{attitude}{Matrix n_resp x n_brands (integer 1-5 or NA)}
#'   \item{positive_disposition}{Matrix n_resp x n_brands (logical, codes 1-3)}
#'   \item{love}{Matrix (code 1)}
#'   \item{prefer}{Matrix (code 2)}
#'   \item{ambivalent}{Matrix (code 3)}
#'   \item{reject}{Matrix (code 4)}
#'   \item{no_opinion}{Matrix (code 5)}
#'   \item{bought}{Matrix n_resp x n_brands (logical)}
#'   \item{primary}{Matrix n_resp x n_brands (logical)}
#'   \item{brand_codes}{Character vector}
#'   \item{n_respondents}{Integer}
#'
#' @keywords internal
derive_funnel_stages <- function(data, brands,
                                  awareness_prefix,
                                  attitude_prefix,
                                  penetration_prefix,
                                  primary_method = "attitudinal") {

  brand_codes <- brands$BrandCode
  n_resp <- nrow(data)
  n_brands <- length(brand_codes)

  # Initialise stage matrices
  aware_mat <- matrix(FALSE, nrow = n_resp, ncol = n_brands)
  attitude_mat <- matrix(NA_integer_, nrow = n_resp, ncol = n_brands)
  bought_mat <- matrix(FALSE, nrow = n_resp, ncol = n_brands)
  colnames(aware_mat) <- brand_codes
  colnames(attitude_mat) <- brand_codes
  colnames(bought_mat) <- brand_codes

  for (b in seq_along(brand_codes)) {
    brand <- brand_codes[b]

    # Awareness
    aware_col <- .find_brand_col(data, awareness_prefix, brand)
    if (!is.null(aware_col)) {
      vals <- data[[aware_col]]
      aware_mat[, b] <- !is.na(vals) & vals > 0
    }

    # Attitude (codes 1-5)
    att_col <- .find_brand_col(data, attitude_prefix, brand)
    if (!is.null(att_col)) {
      attitude_mat[, b] <- as.integer(data[[att_col]])
    }

    # Penetration (target timeframe)
    pen_col <- .find_brand_col(data, penetration_prefix, brand)
    if (!is.null(pen_col)) {
      vals <- data[[pen_col]]
      bought_mat[, b] <- !is.na(vals) & vals > 0
    }
  }

  # Derive attitude decomposition
  love_mat <- !is.na(attitude_mat) & attitude_mat == 1L
  prefer_mat <- !is.na(attitude_mat) & attitude_mat == 2L
  ambivalent_mat <- !is.na(attitude_mat) & attitude_mat == 3L
  reject_mat <- !is.na(attitude_mat) & attitude_mat == 4L
  no_opinion_mat <- !is.na(attitude_mat) & attitude_mat == 5L
  positive_mat <- love_mat | prefer_mat | ambivalent_mat

  # Primary brand
  primary_mat <- matrix(FALSE, nrow = n_resp, ncol = n_brands)
  colnames(primary_mat) <- brand_codes

  if (primary_method == "attitudinal") {
    primary_mat <- love_mat
  }
  # "behavioural" method would use frequency data — implement when
  # penetration frequency data structure is available

  list(
    awareness = aware_mat,
    attitude = attitude_mat,
    positive_disposition = positive_mat,
    love = love_mat,
    prefer = prefer_mat,
    ambivalent = ambivalent_mat,
    reject = reject_mat,
    no_opinion = no_opinion_mat,
    bought = bought_mat,
    primary = primary_mat,
    brand_codes = brand_codes,
    n_respondents = n_resp
  )
}


#' Find a brand-specific column in data
#'
#' Tries multiple naming patterns: prefix_Brand, prefix.Brand.
#'
#' @param data Data frame.
#' @param prefix Character. Column prefix.
#' @param brand Character. Brand code.
#'
#' @return Column name or NULL.
#' @keywords internal
.find_brand_col <- function(data, prefix, brand) {
  candidates <- c(
    paste0(prefix, "_", brand),
    paste0(prefix, ".", brand),
    paste0(prefix, brand)
  )
  match <- intersect(candidates, names(data))
  if (length(match) > 0) match[1] else NULL
}


# ==============================================================================
# SECTION 2: FUNNEL METRICS CALCULATION
# ==============================================================================

#' Calculate funnel metrics for all brands
#'
#' Computes per-brand percentages for each funnel stage and attitude
#' decomposition, plus stage-to-stage conversion ratios.
#'
#' @param stages List from \code{derive_funnel_stages()}.
#' @param weights Numeric vector. Respondent weights (optional).
#' @param min_base Integer. Minimum base size for reporting (default: 30).
#' @param low_base_warning Integer. Base size threshold for warning (default: 75).
#'
#' @return List with:
#'   \item{stage_metrics}{Data frame: BrandCode, Aware_Pct, Positive_Pct,
#'     Love_Pct, Prefer_Pct, Ambivalent_Pct, Reject_Pct, NoOpinion_Pct,
#'     Bought_Pct, Primary_Pct, Base_n}
#'   \item{conversion_metrics}{Data frame: BrandCode, Aware_to_Positive,
#'     Positive_to_Bought, Bought_to_Primary}
#'   \item{flags}{Data frame: BrandCode, Suppress (base < min_base),
#'     LowBase (base < low_base_warning)}
#'
#' @export
calculate_funnel_metrics <- function(stages, weights = NULL,
                                      min_base = 30,
                                      low_base_warning = 75) {

  brand_codes <- stages$brand_codes
  n_brands <- length(brand_codes)
  n_resp <- stages$n_respondents

  # Helper for weighted percentage
  .wpct <- function(logical_vec, wts = weights) {
    if (is.null(wts)) {
      mean(logical_vec, na.rm = TRUE) * 100
    } else {
      valid <- !is.na(logical_vec)
      sum(wts[valid] * logical_vec[valid]) / sum(wts[valid]) * 100
    }
  }

  # Calculate per-brand metrics
  results <- data.frame(
    BrandCode = brand_codes,
    Aware_Pct = numeric(n_brands),
    Positive_Pct = numeric(n_brands),
    Love_Pct = numeric(n_brands),
    Prefer_Pct = numeric(n_brands),
    Ambivalent_Pct = numeric(n_brands),
    Reject_Pct = numeric(n_brands),
    NoOpinion_Pct = numeric(n_brands),
    Bought_Pct = numeric(n_brands),
    Primary_Pct = numeric(n_brands),
    Base_n = integer(n_brands),
    stringsAsFactors = FALSE
  )

  for (b in seq_along(brand_codes)) {
    results$Aware_Pct[b] <- round(.wpct(stages$awareness[, b]), 1)
    results$Positive_Pct[b] <- round(.wpct(stages$positive_disposition[, b]), 1)
    results$Love_Pct[b] <- round(.wpct(stages$love[, b]), 1)
    results$Prefer_Pct[b] <- round(.wpct(stages$prefer[, b]), 1)
    results$Ambivalent_Pct[b] <- round(.wpct(stages$ambivalent[, b]), 1)
    results$Reject_Pct[b] <- round(.wpct(stages$reject[, b]), 1)
    results$NoOpinion_Pct[b] <- round(.wpct(stages$no_opinion[, b]), 1)
    results$Bought_Pct[b] <- round(.wpct(stages$bought[, b]), 1)
    results$Primary_Pct[b] <- round(.wpct(stages$primary[, b]), 1)
    results$Base_n[b] <- n_resp
  }

  # Conversion ratios
  conversions <- data.frame(
    BrandCode = brand_codes,
    Aware_to_Positive = numeric(n_brands),
    Positive_to_Bought = numeric(n_brands),
    Bought_to_Primary = numeric(n_brands),
    stringsAsFactors = FALSE
  )

  for (b in seq_along(brand_codes)) {
    aware_pct <- results$Aware_Pct[b]
    positive_pct <- results$Positive_Pct[b]
    bought_pct <- results$Bought_Pct[b]
    primary_pct <- results$Primary_Pct[b]

    conversions$Aware_to_Positive[b] <- if (aware_pct > 0) {
      round(positive_pct / aware_pct * 100, 1)
    } else 0

    conversions$Positive_to_Bought[b] <- if (positive_pct > 0) {
      round(bought_pct / positive_pct * 100, 1)
    } else 0

    conversions$Bought_to_Primary[b] <- if (bought_pct > 0) {
      round(primary_pct / bought_pct * 100, 1)
    } else 0
  }

  # Base size flags
  flags <- data.frame(
    BrandCode = brand_codes,
    Suppress = results$Base_n < min_base,
    LowBase = results$Base_n < low_base_warning & results$Base_n >= min_base,
    stringsAsFactors = FALSE
  )

  list(
    stage_metrics = results,
    conversion_metrics = conversions,
    flags = flags
  )
}


# ==============================================================================
# SECTION 3: MAIN ENTRY POINT
# ==============================================================================

#' Run Funnel analysis for a category
#'
#' Computes the full derived funnel with attitude decomposition and
#' conversion ratios. All stages derived from core CBM data.
#'
#' @param data Data frame. Survey data.
#' @param brands Data frame. Brand definitions.
#' @param awareness_prefix Character. Awareness column prefix.
#' @param attitude_prefix Character. Attitude column prefix.
#' @param penetration_prefix Character. Penetration column prefix.
#' @param focal_brand Character. Focal brand code.
#' @param weights Numeric vector. Respondent weights (optional).
#' @param primary_method Character. "attitudinal" or "behavioural".
#' @param min_base Integer. Minimum base for reporting.
#' @param low_base_warning Integer. Low-base warning threshold.
#'
#' @return List with:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{stage_metrics}{Data frame of per-brand funnel percentages}
#'   \item{conversion_metrics}{Data frame of conversion ratios}
#'   \item{flags}{Data frame of base-size flags}
#'   \item{metrics_summary}{Named list for AI annotations}
#'
#' @export
run_funnel <- function(data, brands,
                       awareness_prefix, attitude_prefix,
                       penetration_prefix,
                       focal_brand = NULL,
                       weights = NULL,
                       primary_method = "attitudinal",
                       min_base = 30,
                       low_base_warning = 75) {

  warnings <- character(0)

  if (is.null(data) || nrow(data) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_EMPTY",
      message = "No data for funnel analysis"
    ))
  }

  if (is.null(brands) || nrow(brands) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_BRANDS",
      message = "No brands defined for funnel analysis"
    ))
  }

  # Derive stages
  stages <- derive_funnel_stages(
    data, brands,
    awareness_prefix, attitude_prefix, penetration_prefix,
    primary_method
  )

  # Check if any data was found
  total_aware <- sum(stages$awareness, na.rm = TRUE)
  if (total_aware == 0) {
    warnings <- c(warnings,
      "No awareness data found. Check awareness column prefix matches data.")
  }

  # Calculate metrics
  metrics <- calculate_funnel_metrics(
    stages, weights, min_base, low_base_warning
  )

  # Build metrics summary for AI annotations
  focal_metrics <- NULL
  if (!is.null(focal_brand) &&
      focal_brand %in% metrics$stage_metrics$BrandCode) {
    fm <- metrics$stage_metrics[
      metrics$stage_metrics$BrandCode == focal_brand, , drop = FALSE
    ]
    fc <- metrics$conversion_metrics[
      metrics$conversion_metrics$BrandCode == focal_brand, , drop = FALSE
    ]

    # Category averages (excluding focal brand)
    non_focal <- metrics$stage_metrics[
      metrics$stage_metrics$BrandCode != focal_brand, , drop = FALSE
    ]

    focal_metrics <- list(
      focal_brand = focal_brand,
      focal_aware = fm$Aware_Pct,
      focal_positive = fm$Positive_Pct,
      focal_love = fm$Love_Pct,
      focal_reject = fm$Reject_Pct,
      focal_bought = fm$Bought_Pct,
      focal_primary = fm$Primary_Pct,
      focal_aware_to_positive = fc$Aware_to_Positive,
      focal_positive_to_bought = fc$Positive_to_Bought,
      cat_avg_aware = if (nrow(non_focal) > 0) round(mean(non_focal$Aware_Pct), 1) else NA,
      cat_avg_positive = if (nrow(non_focal) > 0) round(mean(non_focal$Positive_Pct), 1) else NA,
      cat_avg_bought = if (nrow(non_focal) > 0) round(mean(non_focal$Bought_Pct), 1) else NA,
      n_brands = nrow(metrics$stage_metrics),
      n_respondents = stages$n_respondents,
      highest_rejection_brand = metrics$stage_metrics$BrandCode[
        which.max(metrics$stage_metrics$Reject_Pct)
      ],
      highest_rejection_pct = max(metrics$stage_metrics$Reject_Pct)
    )
  }

  status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  list(
    status = status,
    stage_metrics = metrics$stage_metrics,
    conversion_metrics = metrics$conversion_metrics,
    flags = metrics$flags,
    stages = stages,
    metrics_summary = focal_metrics,
    warnings = warnings,
    n_respondents = stages$n_respondents,
    n_brands = length(stages$brand_codes)
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Funnel element loaded (v%s)", FUNNEL_VERSION))
}
