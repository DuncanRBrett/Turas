# ==============================================================================
# BRAND MODULE - REPERTOIRE ELEMENT
# ==============================================================================
# Repertoire analysis: multi-brand buying, share of requirements,
# sole loyalty, switching patterns.
#
# VERSION: 1.0
#
# REFERENCES:
#   Sharp, B. (2010). How Brands Grow. (Polygamous loyalty)
# ==============================================================================

REPERTOIRE_VERSION <- "1.0"


#' Calculate repertoire metrics for a category
#'
#' Computes multi-brand buying patterns from penetration data.
#'
#' @param penetration_matrix Matrix. n_resp x n_brands, binary (0/1).
#'   Each column is a brand, each row is a respondent.
#'   Cell = 1 if respondent bought the brand in the target period.
#' @param brand_codes Character vector. Brand codes (column names).
#' @param focal_brand Character. Focal brand code.
#' @param frequency_matrix Matrix. n_resp x n_brands, numeric.
#'   Purchase frequency per brand (optional, TRANS categories only).
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{repertoire_size}{Data frame: Brands_Bought, Count, Percentage}
#'   \item{mean_repertoire}{Numeric. Average brands per buyer.}
#'   \item{sole_loyalty}{Data frame: BrandCode, SoleLoyalty_Pct (% of
#'     brand buyers who bought ONLY this brand)}
#'   \item{brand_overlap}{Data frame: BrandCode, Overlap_Pct
#'     (% of focal brand buyers who also buy this brand)}
#'   \item{share_of_requirements}{Data frame: BrandCode, SoR_Pct
#'     (focal brand's share of its buyers' category purchases, TRANS only)}
#'   \item{metrics_summary}{Named list for AI annotations}
#'
#' @export
run_repertoire <- function(penetration_matrix, brand_codes,
                           focal_brand = NULL,
                           frequency_matrix = NULL,
                           weights = NULL) {

  if (is.null(penetration_matrix) || nrow(penetration_matrix) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_PENETRATION",
      message = "No penetration data for repertoire analysis"
    ))
  }

  n_resp <- nrow(penetration_matrix)
  n_brands <- length(brand_codes)

  # Ensure matrix format
  pen_mat <- as.matrix(penetration_matrix)
  colnames(pen_mat) <- brand_codes

  # Category buyers: bought at least one brand
  brands_per_resp <- rowSums(pen_mat, na.rm = TRUE)
  is_buyer <- brands_per_resp > 0
  n_buyers <- sum(is_buyer)

  if (n_buyers == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_BUYERS",
      message = "No category buyers found in penetration data"
    ))
  }

  # --- Repertoire size distribution ---
  max_bought <- max(brands_per_resp[is_buyer])
  rep_dist <- data.frame(
    Brands_Bought = seq_len(max_bought),
    Count = integer(max_bought),
    Percentage = numeric(max_bought),
    stringsAsFactors = FALSE
  )

  for (k in seq_len(max_bought)) {
    if (k < max_bought) {
      rep_dist$Count[k] <- sum(brands_per_resp[is_buyer] == k)
    } else {
      # Collapse max_bought+ into one row
      rep_dist$Count[k] <- sum(brands_per_resp[is_buyer] >= k)
      rep_dist$Brands_Bought[k] <- paste0(k, "+")
    }
  }
  rep_dist$Percentage <- round(rep_dist$Count / n_buyers * 100, 1)

  # Mean repertoire size
  mean_rep <- if (is.null(weights)) {
    mean(brands_per_resp[is_buyer])
  } else {
    buyer_weights <- weights[is_buyer]
    sum(buyer_weights * brands_per_resp[is_buyer]) / sum(buyer_weights)
  }

  # --- Sole loyalty per brand ---
  sole_loyalty <- data.frame(
    BrandCode = brand_codes,
    SoleLoyalty_Pct = numeric(n_brands),
    Brand_Buyers_n = integer(n_brands),
    stringsAsFactors = FALSE
  )

  for (b in seq_along(brand_codes)) {
    brand_buyers <- pen_mat[, b] == 1
    n_brand_buyers <- sum(brand_buyers, na.rm = TRUE)
    sole_loyalty$Brand_Buyers_n[b] <- n_brand_buyers

    if (n_brand_buyers > 0) {
      sole <- brand_buyers & brands_per_resp == 1
      if (is.null(weights)) {
        sole_loyalty$SoleLoyalty_Pct[b] <- round(
          sum(sole) / n_brand_buyers * 100, 1
        )
      } else {
        sole_loyalty$SoleLoyalty_Pct[b] <- round(
          sum(weights[sole]) / sum(weights[brand_buyers]) * 100, 1
        )
      }
    }
  }

  # --- Brand overlap with focal brand ---
  brand_overlap <- NULL
  if (!is.null(focal_brand) && focal_brand %in% brand_codes) {
    focal_buyers <- pen_mat[, focal_brand] == 1
    n_focal_buyers <- sum(focal_buyers, na.rm = TRUE)

    if (n_focal_buyers > 0) {
      overlap_codes <- setdiff(brand_codes, focal_brand)
      brand_overlap <- data.frame(
        BrandCode = overlap_codes,
        Overlap_Pct = numeric(length(overlap_codes)),
        stringsAsFactors = FALSE
      )

      for (i in seq_along(overlap_codes)) {
        also_bought <- focal_buyers & pen_mat[, overlap_codes[i]] == 1
        if (is.null(weights)) {
          brand_overlap$Overlap_Pct[i] <- round(
            sum(also_bought) / n_focal_buyers * 100, 1
          )
        } else {
          brand_overlap$Overlap_Pct[i] <- round(
            sum(weights[also_bought]) / sum(weights[focal_buyers]) * 100, 1
          )
        }
      }
      brand_overlap <- brand_overlap[order(-brand_overlap$Overlap_Pct), ,
                                      drop = FALSE]
      rownames(brand_overlap) <- NULL
    }
  }

  # --- Full crossover matrix (Duplication of Purchase) ---
  # crossover_matrix[i, j] = % of brand_i buyers who also buy brand_j.
  # This is the Ehrenberg / Sharp "duplication of purchase" table.
  crossover_matrix <- NULL
  if (n_brands >= 2) {
    cross_mat <- matrix(NA_real_, nrow = n_brands, ncol = n_brands,
                        dimnames = list(brand_codes, brand_codes))

    for (i in seq_along(brand_codes)) {
      bi_buyers <- pen_mat[, i] == 1
      n_bi_wt   <- if (is.null(weights)) sum(bi_buyers, na.rm = TRUE)
                   else sum(weights[bi_buyers], na.rm = TRUE)
      if (n_bi_wt <= 0) next
      for (j in seq_along(brand_codes)) {
        if (i == j) { cross_mat[i, j] <- 100; next }
        both <- bi_buyers & (pen_mat[, j] == 1)
        cross_mat[i, j] <- if (is.null(weights)) {
          round(sum(both, na.rm = TRUE) / n_bi_wt * 100, 1)
        } else {
          round(sum(weights[both], na.rm = TRUE) / n_bi_wt * 100, 1)
        }
      }
    }

    cmdf <- as.data.frame(cross_mat, stringsAsFactors = FALSE)
    crossover_matrix <- cbind(
      data.frame(BrandCode = rownames(cmdf), stringsAsFactors = FALSE),
      cmdf,
      stringsAsFactors = FALSE
    )
    rownames(crossover_matrix) <- NULL
  }

  # --- Per-brand loyalty profile ---
  # For each brand, split its buyers into: Sole (1 brand), Dual (2 brands),
  # Multi (3+ brands). Plus mean repertoire size among that brand's buyers.
  # This reveals the buyer-typology profile sitting behind each brand's share.
  brand_repertoire_profile <- data.frame(
    BrandCode       = brand_codes,
    Brand_Buyers_n  = integer(n_brands),
    Sole_Pct        = numeric(n_brands),
    Dual_Pct        = numeric(n_brands),
    Multi_Pct       = numeric(n_brands),
    Mean_Repertoire = numeric(n_brands),
    stringsAsFactors = FALSE
  )

  for (b in seq_along(brand_codes)) {
    bb     <- pen_mat[, b] == 1
    n_bb   <- sum(bb, na.rm = TRUE)
    brand_repertoire_profile$Brand_Buyers_n[b] <- n_bb

    if (n_bb > 0) {
      rep_per_buyer <- brands_per_resp[bb]

      if (is.null(weights)) {
        brand_repertoire_profile$Sole_Pct[b]  <- round(sum(rep_per_buyer == 1) / n_bb * 100, 1)
        brand_repertoire_profile$Dual_Pct[b]  <- round(sum(rep_per_buyer == 2) / n_bb * 100, 1)
        brand_repertoire_profile$Multi_Pct[b] <- round(sum(rep_per_buyer >= 3) / n_bb * 100, 1)
        brand_repertoire_profile$Mean_Repertoire[b] <- round(mean(rep_per_buyer), 1)
      } else {
        bb_wts <- weights[bb]
        wt_tot <- sum(bb_wts, na.rm = TRUE)
        brand_repertoire_profile$Sole_Pct[b]  <- round(
          sum(bb_wts[rep_per_buyer == 1], na.rm = TRUE) / wt_tot * 100, 1)
        brand_repertoire_profile$Dual_Pct[b]  <- round(
          sum(bb_wts[rep_per_buyer == 2], na.rm = TRUE) / wt_tot * 100, 1)
        brand_repertoire_profile$Multi_Pct[b] <- round(
          sum(bb_wts[rep_per_buyer >= 3], na.rm = TRUE) / wt_tot * 100, 1)
        brand_repertoire_profile$Mean_Repertoire[b] <- round(
          sum(bb_wts * rep_per_buyer, na.rm = TRUE) / wt_tot, 1)
      }
    }
  }

  # --- Share of requirements (TRANS only, needs frequency data) ---
  share_of_req <- NULL
  if (!is.null(frequency_matrix)) {
    freq_mat <- as.matrix(frequency_matrix)
    colnames(freq_mat) <- brand_codes

    share_of_req <- data.frame(
      BrandCode = brand_codes,
      SoR_Pct = numeric(n_brands),
      stringsAsFactors = FALSE
    )

    for (b in seq_along(brand_codes)) {
      brand_buyers <- pen_mat[, b] == 1
      if (sum(brand_buyers) > 0) {
        buyer_total_freq <- rowSums(freq_mat[brand_buyers, , drop = FALSE],
                                    na.rm = TRUE)
        brand_freq <- freq_mat[brand_buyers, b]

        # Share = brand freq / total freq per buyer, then average
        valid <- buyer_total_freq > 0
        if (sum(valid) > 0) {
          shares <- brand_freq[valid] / buyer_total_freq[valid]
          if (is.null(weights)) {
            share_of_req$SoR_Pct[b] <- round(mean(shares) * 100, 1)
          } else {
            buyer_wts <- weights[which(brand_buyers)][valid]
            share_of_req$SoR_Pct[b] <- round(
              sum(buyer_wts * shares) / sum(buyer_wts) * 100, 1
            )
          }
        }
      }
    }
  }

  # --- Metrics summary ---
  focal_sole <- NA_real_
  focal_overlap_top <- NA_character_
  if (!is.null(focal_brand) && focal_brand %in% sole_loyalty$BrandCode) {
    focal_sole <- sole_loyalty$SoleLoyalty_Pct[
      sole_loyalty$BrandCode == focal_brand
    ]
  }
  if (!is.null(brand_overlap) && nrow(brand_overlap) > 0) {
    focal_overlap_top <- brand_overlap$BrandCode[1]
  }

  metrics_summary <- list(
    focal_brand = focal_brand,
    mean_repertoire = round(mean_rep, 1),
    n_buyers = n_buyers,
    n_respondents = n_resp,
    focal_sole_loyalty = focal_sole,
    focal_top_overlap_brand = focal_overlap_top,
    pct_single_brand = rep_dist$Percentage[1],
    n_brands = n_brands
  )

  list(
    status = "PASS",
    repertoire_size = rep_dist,
    mean_repertoire = round(mean_rep, 1),
    sole_loyalty = sole_loyalty,
    brand_overlap = brand_overlap,
    crossover_matrix = crossover_matrix,
    brand_repertoire_profile = brand_repertoire_profile,
    share_of_requirements = share_of_req,
    metrics_summary = metrics_summary,
    n_respondents = n_resp,
    n_buyers = n_buyers,
    n_brands = n_brands
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Repertoire element loaded (v%s)",
                  REPERTOIRE_VERSION))
}
