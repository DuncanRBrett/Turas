# ==============================================================================
# BRAND MODULE - FUNNEL LEGACY WIDE-FORMAT ADAPTER
# ==============================================================================
# Converts the new long-format run_funnel() result into the wide per-brand
# data frames expected by the pre-rebuild HTML chart and table builders.
#
# This file exists so the canonical role-registry data contract in
# 03c_funnel_panel_data.R can stay focused on its spec-§6 shape while the
# legacy renderers keep working. The new panel renderer (Phase F) does NOT
# go through this adapter; only the pre-rebuild pipeline does.
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_LEGACY_ADAPTER_VERSION <- "2.0"


#' Convert a run_funnel() result to the legacy wide per-brand data frame
#'
#' @param result List returned by \code{run_funnel()}.
#' @param brand_list Data frame with BrandCode column.
#'
#' @return Data frame, one row per brand, with the pre-rebuild column
#'   schema (\code{BrandCode}, \code{Aware_Pct}, \code{Positive_Pct},
#'   \code{Bought_Pct}, \code{Primary_Pct}, attitude-decomposition
#'   percentages). Values are in percentage points (0-100), matching the
#'   legacy convention.
#'
#' @keywords internal
build_funnel_legacy_wide <- function(result, brand_list) {
  if (is.null(result) || identical(result$status, "REFUSED") ||
      is.null(result$stages) || nrow(result$stages) == 0) {
    return(.empty_legacy_wide())
  }
  brand_codes <- as.character(brand_list$BrandCode)

  stage_pcts <- .pivot_stages_to_wide(result$stages, brand_codes)
  att_pcts   <- .pivot_attitude_to_wide(result$attitude_decomposition,
                                        brand_codes)

  out <- data.frame(BrandCode = brand_codes, stringsAsFactors = FALSE)
  out$Aware_Pct       <- 100 * stage_pcts$aware
  out$Positive_Pct    <- 100 * stage_pcts$consideration
  out$Bought_Pct      <- 100 * (stage_pcts$bought_long %||%
                                 stage_pcts$current_owner_d %||%
                                 stage_pcts$current_customer_s %||%
                                 NA_real_)
  out$Primary_Pct     <- 100 * (stage_pcts$bought_target %||%
                                 stage_pcts$long_tenured_d %||%
                                 stage_pcts$long_tenured_s %||%
                                 NA_real_)
  out$Love_Pct        <- 100 * att_pcts$attitude.love
  out$Prefer_Pct      <- 100 * att_pcts$attitude.prefer
  out$Ambivalent_Pct  <- 100 * att_pcts$attitude.ambivalent
  out$Reject_Pct      <- 100 * att_pcts$attitude.reject
  out$NoOpinion_Pct   <- 100 * att_pcts$attitude.no_opinion
  out
}


.empty_legacy_wide <- function() {
  data.frame(
    BrandCode = character(0),
    Aware_Pct = numeric(0), Positive_Pct = numeric(0),
    Bought_Pct = numeric(0), Primary_Pct = numeric(0),
    Love_Pct = numeric(0), Prefer_Pct = numeric(0),
    Ambivalent_Pct = numeric(0), Reject_Pct = numeric(0),
    NoOpinion_Pct = numeric(0),
    stringsAsFactors = FALSE
  )
}


.pivot_stages_to_wide <- function(stages, brand_codes) {
  keys <- unique(as.character(stages$stage_key))
  out <- list()
  for (k in keys) {
    vals <- vapply(brand_codes, function(b) {
      row <- stages[stages$stage_key == k & stages$brand_code == b, ,
                    drop = FALSE]
      if (nrow(row) == 0) NA_real_ else row$pct_weighted[1]
    }, numeric(1))
    out[[k]] <- unname(vals)
  }
  out
}


#' Legacy wide-format conversions for the old dot-plot renderer
#'
#' @param result run_funnel() result.
#' @param brand_list Data frame with BrandCode.
#'
#' @return Data frame with columns BrandCode, Aware_to_Positive,
#'   Positive_to_Bought, Bought_to_Primary, values in 0-100.
#'
#' @keywords internal
build_funnel_legacy_conversions <- function(result, brand_list) {
  if (is.null(result$conversions) || nrow(result$conversions) == 0) {
    return(data.frame(BrandCode = character(0),
                      Aware_to_Positive = numeric(0),
                      Positive_to_Bought = numeric(0),
                      Bought_to_Primary = numeric(0),
                      stringsAsFactors = FALSE))
  }
  brand_codes <- as.character(brand_list$BrandCode)

  .get_ratio <- function(b, from_key, to_keys) {
    for (to_key in to_keys) {
      row <- result$conversions[
        result$conversions$brand_code == b &
          result$conversions$from_stage == from_key &
          result$conversions$to_stage == to_key, , drop = FALSE]
      if (nrow(row) > 0) return(100 * row$value[1])
    }
    NA_real_
  }

  data.frame(
    BrandCode = brand_codes,
    Aware_to_Positive = vapply(brand_codes,
      .get_ratio, numeric(1), from_key = "aware",
      to_keys = c("consideration")),
    Positive_to_Bought = vapply(brand_codes,
      .get_ratio, numeric(1), from_key = "consideration",
      to_keys = c("bought_long", "current_owner_d", "current_customer_s")),
    Bought_to_Primary = vapply(brand_codes,
      .get_ratio, numeric(1),
      from_key = "bought_long",
      to_keys = c("bought_target", "long_tenured_d", "long_tenured_s")),
    stringsAsFactors = FALSE
  )
}


.pivot_attitude_to_wide <- function(att_df, brand_codes) {
  positions <- c("attitude.love", "attitude.prefer", "attitude.ambivalent",
                 "attitude.reject", "attitude.no_opinion")
  out <- list()
  for (p in positions) {
    vals <- vapply(brand_codes, function(b) {
      row <- att_df[att_df$brand_code == b & att_df$attitude_role == p, ,
                    drop = FALSE]
      if (nrow(row) == 0) NA_real_ else row$pct
    }, numeric(1))
    out[[p]] <- unname(vals)
  }
  out
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel legacy adapter loaded (v%s)",
                  BRAND_FUNNEL_LEGACY_ADAPTER_VERSION))
}
