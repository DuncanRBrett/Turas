# ==============================================================================
# BRAND MODULE - DBA (DISTINCTIVE BRAND ASSETS) ELEMENT
# ==============================================================================
# Romaniuk's Fame x Uniqueness framework for brand asset evaluation.
# Measures recognition (Fame) and correct attribution (Uniqueness) per asset.
# Brand-level, not per-category.
#
# Quadrants:
#   High Fame + High Uniqueness = Use or Lose
#   High Fame + Low Uniqueness  = Avoid Alone
#   Low Fame + High Uniqueness  = Invest to Build
#   Low Fame + Low Uniqueness   = Ignore or Test
#
# VERSION: 1.0
#
# REFERENCES:
#   Romaniuk, J. (2018). Building Distinctive Brand Assets. OUP.
# ==============================================================================

DBA_VERSION <- "1.0"


#' Calculate DBA metrics for all assets
#'
#' Computes Fame (recognition rate) and Uniqueness (correct attribution
#' rate among recognisers) for each brand asset, and classifies into
#' the 2x2 quadrant framework.
#'
#' @param data Data frame. Survey data.
#' @param assets Data frame. Asset definitions with AssetCode,
#'   FameQuestionCode, UniqueQuestionCode columns.
#' @param focal_brand Character. Focal brand code (for attribution matching).
#' @param fame_threshold Numeric. Fame threshold for quadrant (default: 0.50).
#' @param uniqueness_threshold Numeric. Uniqueness threshold (default: 0.50).
#' @param attribution_type Character. "open" (coded text) or "closed_list"
#'   (forced choice). Controls how Uniqueness is calculated.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{dba_metrics}{Data frame: AssetCode, AssetLabel, Fame_Pct,
#'     Uniqueness_Pct, Fame_n, Uniqueness_n, Quadrant}
#'   \item{metrics_summary}{Named list for AI annotations}
#'
#' @export
run_dba <- function(data, assets,
                    focal_brand,
                    fame_threshold = 0.50,
                    uniqueness_threshold = 0.50,
                    attribution_type = "open",
                    weights = NULL) {

  if (is.null(data) || nrow(data) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_EMPTY",
      message = "No data for DBA analysis"
    ))
  }

  if (is.null(assets) || nrow(assets) == 0) {
    return(list(
      status = "REFUSED",
      code = "CFG_NO_ASSETS",
      message = "No DBA assets defined"
    ))
  }

  n_resp <- nrow(data)
  n_assets <- nrow(assets)

  dba_metrics <- data.frame(
    AssetCode = assets$AssetCode,
    AssetLabel = if ("AssetLabel" %in% names(assets)) assets$AssetLabel else assets$AssetCode,
    Fame_Pct = numeric(n_assets),
    Uniqueness_Pct = numeric(n_assets),
    Fame_n = integer(n_assets),
    Uniqueness_n = integer(n_assets),
    Quadrant = character(n_assets),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(n_assets)) {
    fame_col <- assets$FameQuestionCode[i]
    unique_col <- assets$UniqueQuestionCode[i]

    # Fame: % who recognised the asset (responded Yes or Not Sure)
    if (fame_col %in% names(data)) {
      fame_vals <- data[[fame_col]]
      # Code 1 = Yes, 2 = No, 3 = Not Sure
      # Recognised = Yes OR Not Sure (Romaniuk: uncertain familiarity is a finding)
      recognised <- !is.na(fame_vals) & fame_vals %in% c(1, 3)

      if (is.null(weights)) {
        dba_metrics$Fame_Pct[i] <- round(mean(recognised) * 100, 1)
      } else {
        dba_metrics$Fame_Pct[i] <- round(
          sum(weights * recognised) / sum(weights) * 100, 1
        )
      }
      dba_metrics$Fame_n[i] <- sum(recognised)
    }

    # Uniqueness: among recognisers, % who correctly attributed to focal brand
    if (unique_col %in% names(data)) {
      unique_vals <- data[[unique_col]]

      if (fame_col %in% names(data)) {
        fame_vals <- data[[fame_col]]
        recognised <- !is.na(fame_vals) & fame_vals %in% c(1, 3)
      } else {
        recognised <- rep(TRUE, n_resp)
      }

      if (attribution_type == "open") {
        # Open-ended: coded to brand codes or text matching focal brand
        correct <- recognised &
                   !is.na(unique_vals) &
                   toupper(trimws(as.character(unique_vals))) == toupper(focal_brand)
      } else {
        # Closed list: value matches focal brand code
        correct <- recognised &
                   !is.na(unique_vals) &
                   as.character(unique_vals) == focal_brand
      }

      n_recognisers <- sum(recognised)
      if (n_recognisers > 0) {
        if (is.null(weights)) {
          dba_metrics$Uniqueness_Pct[i] <- round(
            sum(correct) / n_recognisers * 100, 1
          )
        } else {
          dba_metrics$Uniqueness_Pct[i] <- round(
            sum(weights[recognised] * correct[recognised]) /
              sum(weights[recognised]) * 100, 1
          )
        }
        dba_metrics$Uniqueness_n[i] <- sum(correct)
      }
    }

    # Quadrant classification
    high_fame <- dba_metrics$Fame_Pct[i] / 100 >= fame_threshold
    high_unique <- dba_metrics$Uniqueness_Pct[i] / 100 >= uniqueness_threshold

    dba_metrics$Quadrant[i] <- if (high_fame && high_unique) {
      "Use or Lose"
    } else if (high_fame && !high_unique) {
      "Avoid Alone"
    } else if (!high_fame && high_unique) {
      "Invest to Build"
    } else {
      "Ignore or Test"
    }
  }

  # Metrics summary
  n_use_or_lose <- sum(dba_metrics$Quadrant == "Use or Lose")
  strongest_asset <- dba_metrics$AssetCode[which.max(
    dba_metrics$Fame_Pct * dba_metrics$Uniqueness_Pct / 100
  )]
  weakest_asset <- dba_metrics$AssetCode[which.min(
    dba_metrics$Fame_Pct * dba_metrics$Uniqueness_Pct / 100
  )]

  metrics_summary <- list(
    focal_brand = focal_brand,
    n_assets = n_assets,
    n_use_or_lose = n_use_or_lose,
    n_avoid_alone = sum(dba_metrics$Quadrant == "Avoid Alone"),
    n_invest = sum(dba_metrics$Quadrant == "Invest to Build"),
    n_ignore = sum(dba_metrics$Quadrant == "Ignore or Test"),
    strongest_asset = strongest_asset,
    weakest_asset = weakest_asset,
    fame_threshold = fame_threshold,
    uniqueness_threshold = uniqueness_threshold
  )

  list(
    status = "PASS",
    dba_metrics = dba_metrics,
    metrics_summary = metrics_summary,
    n_respondents = n_resp,
    n_assets = n_assets
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand DBA element loaded (v%s)", DBA_VERSION))
}
