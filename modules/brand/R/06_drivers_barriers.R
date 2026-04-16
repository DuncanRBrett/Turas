# ==============================================================================
# BRAND MODULE - DRIVERS & BARRIERS ELEMENT
# ==============================================================================
# Derived importance analysis:
#   - Which CEPs/attributes differentiate buyers from non-buyers?
#   - Importance x Performance quadrant classification
#   - Competitive advantage mapping (focal brand vs leader per attribute)
#   - Explicit rejection themes from rejection open-end
#
# IMPORTANCE METHODS:
#   "differential" — buyer/non-buyer linkage gap (simple, default)
#   "catdriver"    — SHAP or regression via catdriver module (optional)
#
# VERSION: 1.0
#
# REFERENCES:
#   Romaniuk, J. (2022). Better Brand Health. (derived > stated importance)
# ==============================================================================

DRIVERS_BARRIERS_VERSION <- "1.0"


#' Calculate derived importance via buyer/non-buyer differential
#'
#' For each CEP/attribute, computes the difference in linkage rate between
#' buyers and non-buyers of the focal brand. Higher differential = the
#' attribute is more associated with buying.
#'
#' @param linkage_tensor Named list of brand matrices from
#'   \code{build_cep_linkage()}.
#' @param penetration_vector Logical/integer vector. Length n_resp.
#'   TRUE/1 if respondent bought the focal brand.
#' @param focal_brand Character. Focal brand code.
#' @param cep_codes Character vector. CEP/attribute codes.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Data frame with columns: Code, Buyer_Pct, NonBuyer_Pct,
#'   Differential, Importance_Rank.
#'
#' @keywords internal
calculate_differential_importance <- function(linkage_tensor,
                                               penetration_vector,
                                               focal_brand,
                                               cep_codes,
                                               weights = NULL) {

  focal_mat <- linkage_tensor[[focal_brand]]
  if (is.null(focal_mat)) {
    return(data.frame(
      Code = character(0), Buyer_Pct = numeric(0),
      NonBuyer_Pct = numeric(0), Differential = numeric(0),
      Importance_Rank = integer(0), stringsAsFactors = FALSE
    ))
  }

  is_buyer <- !is.na(penetration_vector) & penetration_vector > 0
  is_nonbuyer <- !is.na(penetration_vector) & penetration_vector == 0

  n_ceps <- length(cep_codes)
  result <- data.frame(
    Code = cep_codes,
    Buyer_Pct = numeric(n_ceps),
    NonBuyer_Pct = numeric(n_ceps),
    Differential = numeric(n_ceps),
    stringsAsFactors = FALSE
  )

  for (j in seq_len(n_ceps)) {
    linked <- focal_mat[, j]

    if (is.null(weights)) {
      buyer_rate <- if (sum(is_buyer) > 0) {
        mean(linked[is_buyer], na.rm = TRUE)
      } else 0
      nonbuyer_rate <- if (sum(is_nonbuyer) > 0) {
        mean(linked[is_nonbuyer], na.rm = TRUE)
      } else 0
    } else {
      buyer_rate <- if (sum(is_buyer) > 0) {
        sum(weights[is_buyer] * linked[is_buyer], na.rm = TRUE) /
          sum(weights[is_buyer])
      } else 0
      nonbuyer_rate <- if (sum(is_nonbuyer) > 0) {
        sum(weights[is_nonbuyer] * linked[is_nonbuyer], na.rm = TRUE) /
          sum(weights[is_nonbuyer])
      } else 0
    }

    result$Buyer_Pct[j] <- round(buyer_rate * 100, 1)
    result$NonBuyer_Pct[j] <- round(nonbuyer_rate * 100, 1)
    result$Differential[j] <- round((buyer_rate - nonbuyer_rate) * 100, 1)
  }

  result <- result[order(-abs(result$Differential)), , drop = FALSE]
  result$Importance_Rank <- seq_len(nrow(result))
  rownames(result) <- NULL

  result
}


#' Classify attributes into I x P quadrants
#'
#' Maps each CEP/attribute into one of four quadrants based on its derived
#' importance and the focal brand's performance (linkage rate).
#'
#' @param importance Data frame from \code{calculate_differential_importance()}.
#' @param performance Data frame with columns Code and Focal_Linkage_Pct.
#'
#' @return Data frame with Code, Importance, Performance, Quadrant.
#'   Quadrants: Strengthen, Maintain, Deprioritise, Monitor.
#'
#' @keywords internal
classify_ixp_quadrants <- function(importance, performance) {

  merged <- merge(importance, performance, by = "Code", all.x = TRUE)

  # Quadrant lines at medians
  imp_median <- median(abs(merged$Differential), na.rm = TRUE)
  perf_median <- median(merged$Focal_Linkage_Pct, na.rm = TRUE)

  merged$Quadrant <- mapply(function(imp, perf) {
    high_imp <- abs(imp) >= imp_median
    high_perf <- perf >= perf_median
    if (high_imp && !high_perf) return("Strengthen")
    if (high_imp && high_perf) return("Maintain")
    if (!high_imp && !high_perf) return("Deprioritise")
    if (!high_imp && high_perf) return("Monitor")
    "Unclassified"
  }, merged$Differential, merged$Focal_Linkage_Pct)

  merged$Imp_Median <- imp_median
  merged$Perf_Median <- perf_median

  merged
}


#' Calculate competitive advantage per attribute
#'
#' For each CEP/attribute, compares the focal brand's linkage rate to the
#' category leader's rate. Identifies where the focal brand leads vs lags.
#'
#' @param cep_brand_matrix Data frame from \code{calculate_cep_brand_matrix()}.
#' @param focal_brand Character. Focal brand code.
#'
#' @return Data frame with Code, Focal_Pct, Leader_Brand, Leader_Pct,
#'   Gap_pp, Focal_Leads (logical).
#'
#' @keywords internal
calculate_competitive_advantage <- function(cep_brand_matrix, focal_brand) {

  brand_cols <- setdiff(names(cep_brand_matrix), "CEPCode")
  if (!focal_brand %in% brand_cols) {
    return(data.frame(
      Code = character(0), Focal_Pct = numeric(0),
      Leader_Brand = character(0), Leader_Pct = numeric(0),
      Gap_pp = numeric(0), Focal_Leads = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  other_brands <- setdiff(brand_cols, focal_brand)
  n_ceps <- nrow(cep_brand_matrix)

  result <- data.frame(
    Code = cep_brand_matrix$CEPCode,
    Focal_Pct = cep_brand_matrix[[focal_brand]],
    Leader_Brand = character(n_ceps),
    Leader_Pct = numeric(n_ceps),
    Gap_pp = numeric(n_ceps),
    Focal_Leads = logical(n_ceps),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(n_ceps)) {
    if (length(other_brands) > 0) {
      other_vals <- unlist(cep_brand_matrix[i, other_brands])
      leader_idx <- which.max(other_vals)
      result$Leader_Brand[i] <- other_brands[leader_idx]
      result$Leader_Pct[i] <- other_vals[leader_idx]
    } else {
      result$Leader_Brand[i] <- focal_brand
      result$Leader_Pct[i] <- result$Focal_Pct[i]
    }

    result$Gap_pp[i] <- round(result$Focal_Pct[i] - result$Leader_Pct[i], 1)
    result$Focal_Leads[i] <- result$Focal_Pct[i] > result$Leader_Pct[i]
  }

  result[order(-abs(result$Gap_pp)), , drop = FALSE]
}


#' Run Drivers & Barriers analysis
#'
#' @param linkage Named list from \code{build_cep_linkage()}.
#' @param cep_brand_matrix Data frame from \code{calculate_cep_brand_matrix()}.
#' @param penetration_vector Logical/integer vector of focal brand buying.
#' @param focal_brand Character. Focal brand code.
#' @param cep_labels Data frame with CEPCode and CEPText (optional).
#' @param weights Numeric vector. Respondent weights (optional).
#' @param rejection_data Data frame with BrandCode and Reason columns
#'   (pre-coded rejection open-ends, optional).
#'
#' @return List with status, importance, ixp_quadrants, competitive_advantage,
#'   rejection_themes, metrics_summary.
#'
#' @export
run_drivers_barriers <- function(linkage, cep_brand_matrix,
                                  penetration_vector,
                                  focal_brand,
                                  cep_labels = NULL,
                                  weights = NULL,
                                  rejection_data = NULL) {

  if (is.null(linkage) || length(linkage$linkage_tensor) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_LINKAGE",
      message = "No CEP linkage data for Drivers & Barriers analysis"
    ))
  }

  cep_codes <- linkage$cep_codes
  warnings <- character(0)

  # Derived importance
  importance <- calculate_differential_importance(
    linkage$linkage_tensor, penetration_vector, focal_brand,
    cep_codes, weights
  )

  # Performance = focal brand's linkage rate per CEP
  performance <- data.frame(
    Code = cep_codes,
    Focal_Linkage_Pct = numeric(length(cep_codes)),
    stringsAsFactors = FALSE
  )
  if (!is.null(cep_brand_matrix) && focal_brand %in% names(cep_brand_matrix)) {
    for (j in seq_along(cep_codes)) {
      row_idx <- which(cep_brand_matrix$CEPCode == cep_codes[j])
      if (length(row_idx) > 0) {
        performance$Focal_Linkage_Pct[j] <- cep_brand_matrix[[focal_brand]][row_idx]
      }
    }
  }

  # I x P quadrants
  ixp <- classify_ixp_quadrants(importance, performance)

  # Add labels if available
  if (!is.null(cep_labels) && "CEPCode" %in% names(cep_labels) &&
      "CEPText" %in% names(cep_labels)) {
    importance$Label <- cep_labels$CEPText[match(importance$Code, cep_labels$CEPCode)]
    ixp$Label <- cep_labels$CEPText[match(ixp$Code, cep_labels$CEPCode)]
  }

  # Competitive advantage
  comp_adv <- NULL
  if (!is.null(cep_brand_matrix)) {
    comp_adv <- calculate_competitive_advantage(cep_brand_matrix, focal_brand)
    if (!is.null(cep_labels)) {
      comp_adv$Label <- cep_labels$CEPText[match(comp_adv$Code, cep_labels$CEPCode)]
    }
  }

  # Rejection themes
  rejection_themes <- NULL
  if (!is.null(rejection_data) && nrow(rejection_data) > 0) {
    focal_rej <- rejection_data[rejection_data$BrandCode == focal_brand, ,
                                 drop = FALSE]
    if (nrow(focal_rej) > 0 && "Reason" %in% names(focal_rej)) {
      reasons <- table(focal_rej$Reason)
      rejection_themes <- data.frame(
        Reason = names(reasons),
        Count = as.integer(reasons),
        Pct = round(as.integer(reasons) / nrow(focal_rej) * 100, 1),
        stringsAsFactors = FALSE
      )
      rejection_themes <- rejection_themes[order(-rejection_themes$Count), ,
                                            drop = FALSE]
      rownames(rejection_themes) <- NULL
    }
  }

  # Metrics summary
  strengthen_ceps <- ixp$Code[ixp$Quadrant == "Strengthen"]
  n_focal_leads <- if (!is.null(comp_adv)) sum(comp_adv$Focal_Leads) else 0
  n_total_attrs <- length(cep_codes)

  metrics_summary <- list(
    focal_brand = focal_brand,
    n_attributes = n_total_attrs,
    n_strengthen = length(strengthen_ceps),
    top_strengthen = if (length(strengthen_ceps) > 0) strengthen_ceps[1] else NA,
    n_focal_leads = n_focal_leads,
    n_focal_lags = n_total_attrs - n_focal_leads,
    top_importance_attr = importance$Code[1],
    top_importance_diff = importance$Differential[1],
    n_rejection_themes = if (!is.null(rejection_themes)) nrow(rejection_themes) else 0
  )

  list(
    status = "PASS",
    importance = importance,
    ixp_quadrants = ixp,
    competitive_advantage = comp_adv,
    rejection_themes = rejection_themes,
    metrics_summary = metrics_summary,
    warnings = warnings
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Drivers & Barriers element loaded (v%s)",
                  DRIVERS_BARRIERS_VERSION))
}
