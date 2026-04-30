# ==============================================================================
# BRAND MODULE - DRIVERS & BARRIERS ELEMENT
# ==============================================================================
# Computes derived importance (buyer vs non-buyer differential) and cross-tabulates
# it against focal brand CEP performance (linkage %) to produce an Importance x
# Performance (IxP) quadrant map. Also identifies competitive gaps vs the best
# competitor on each CEP, and optionally summarises rejection reasons.
#
# Dependencies: 02_mental_availability.R (linkage tensor, CEP matrix functions)
# ==============================================================================

DRIVERS_BARRIERS_VERSION <- "1.0"


# ==============================================================================
# DIFFERENTIAL IMPORTANCE
# ==============================================================================

#' Calculate differential importance of CEPs
#'
#' Computes the buyer vs non-buyer linkage gap for each CEP for a given brand.
#' Buyers are respondents who indicate they purchased the focal brand in the
#' target timeframe (pen > 0). The differential is Buyer_Pct - NonBuyer_Pct
#' and is the key derived importance metric.
#'
#' @param tensor Named list of brand matrices from
#'   \code{build_cep_linkage_from_matrix()}. Each element is an n_resp x n_ceps
#'   binary matrix.
#' @param pen Numeric vector (length n_resp). Binary penetration indicator
#'   (1 = buyer, 0 = non-buyer) for the target timeframe.
#' @param brand_code Character. The brand to compute differentials for.
#' @param cep_codes Character vector. CEP codes (column names of brand matrices).
#' @param weights Numeric vector (optional). Respondent weights.
#'
#' @return Data frame with columns:
#'   \item{Code}{CEP code}
#'   \item{Buyer_Pct}{Percentage of buyers who link the CEP to this brand}
#'   \item{NonBuyer_Pct}{Percentage of non-buyers who link the CEP to this brand}
#'   \item{Differential}{Buyer_Pct - NonBuyer_Pct (positive = buyer driver)}
#'   Rows are sorted by |Differential| descending.
#'
#' @export
calculate_differential_importance <- function(tensor, pen, brand_code,
                                               cep_codes, weights = NULL) {
  brand_mat <- tensor[[brand_code]]
  if (is.null(brand_mat)) return(data.frame())

  buyers     <- !is.na(pen) & pen > 0
  non_buyers <- !buyers

  rows <- lapply(cep_codes, function(cep) {
    col_vals <- brand_mat[, cep]

    if (is.null(weights)) {
      n_buy    <- sum(buyers)
      n_nonbuy <- sum(non_buyers)
      buyer_pct    <- if (n_buy    > 0) 100 * mean(col_vals[buyers])     else 0
      nonbuyer_pct <- if (n_nonbuy > 0) 100 * mean(col_vals[non_buyers]) else 0
    } else {
      w_buy    <- weights[buyers]
      w_nonbuy <- weights[non_buyers]
      n_buy    <- sum(w_buy)
      n_nonbuy <- sum(w_nonbuy)
      buyer_pct    <- if (n_buy    > 0)
        100 * weighted.mean(col_vals[buyers],     w_buy)    else 0
      nonbuyer_pct <- if (n_nonbuy > 0)
        100 * weighted.mean(col_vals[non_buyers], w_nonbuy) else 0
    }

    data.frame(
      Code         = cep,
      Buyer_Pct    = round(buyer_pct,    2),
      NonBuyer_Pct = round(nonbuyer_pct, 2),
      Differential = round(buyer_pct - nonbuyer_pct, 2),
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  result[order(-abs(result$Differential)), ]
}


# ==============================================================================
# IxP QUADRANT CLASSIFICATION
# ==============================================================================

#' Classify CEPs into Importance x Performance quadrants
#'
#' Merges importance (differential) and performance (focal linkage %) for each
#' CEP and assigns each to one of four quadrants:
#' \itemize{
#'   \item \strong{Maintain}     — high importance, high performance
#'   \item \strong{Strengthen}   — high importance, low performance (priority gap)
#'   \item \strong{Monitor}      — low importance, high performance
#'   \item \strong{Deprioritise} — low importance, low performance
#' }
#' Thresholds are the median |differential| (importance) and median linkage %
#' (performance) across all CEPs in the set.
#'
#' @param importance Data frame. Output of \code{calculate_differential_importance()}.
#'   Must contain Code and Differential columns.
#' @param performance Data frame. Must contain Code and Focal_Linkage_Pct columns.
#'
#' @return Data frame combining importance and performance columns, plus Quadrant.
#'
#' @export
classify_ixp_quadrants <- function(importance, performance) {
  merged <- merge(importance, performance, by = "Code", all.x = TRUE)

  imp_thresh  <- median(abs(merged$Differential),       na.rm = TRUE)
  perf_thresh <- median(merged$Focal_Linkage_Pct, na.rm = TRUE)

  high_imp  <- abs(merged$Differential)       > imp_thresh
  high_perf <- merged$Focal_Linkage_Pct > perf_thresh

  merged$Quadrant <- ifelse(
    high_imp,
    ifelse(high_perf, "Maintain",     "Strengthen"),
    ifelse(high_perf, "Monitor",      "Deprioritise")
  )

  merged
}


# ==============================================================================
# COMPETITIVE ADVANTAGE
# ==============================================================================

#' Calculate focal brand competitive advantage vs best competitor on each CEP
#'
#' For each CEP, identifies the strongest competitor (highest linkage %) and
#' computes the gap: positive = focal leads, negative = focal lags.
#'
#' @param cep_mat Data frame or matrix. Rows are CEPs; columns are brand linkage
#'   percentages. Data frame must include a CEPCode column; matrix uses rownames.
#' @param focal_brand Character. The focal brand column name.
#'
#' @return Data frame with columns:
#'   \item{Code}{CEP code}
#'   \item{Focal_Pct}{Focal brand linkage \%}
#'   \item{Leader_Brand}{Best-performing competitor}
#'   \item{Leader_Pct}{Best competitor's linkage \%}
#'   \item{Gap_pp}{Focal_Pct - Leader_Pct (positive = focal leads)}
#'   \item{Focal_Leads}{Logical}
#'
#' @export
calculate_competitive_advantage <- function(cep_mat, focal_brand) {
  if (is.matrix(cep_mat)) {
    cep_df          <- as.data.frame(cep_mat)
    cep_df$CEPCode  <- rownames(cep_mat)
  } else {
    cep_df <- cep_mat
  }

  brand_cols <- setdiff(names(cep_df), "CEPCode")
  comp_cols  <- setdiff(brand_cols, focal_brand)

  rows <- lapply(seq_len(nrow(cep_df)), function(i) {
    focal_val <- as.numeric(cep_df[[focal_brand]][i])
    comp_vals <- sapply(comp_cols, function(b) as.numeric(cep_df[[b]][i]))
    names(comp_vals) <- comp_cols

    if (length(comp_vals) == 0) {
      leader_brand <- NA_character_
      leader_val   <- NA_real_
    } else {
      best_idx     <- which.max(comp_vals)
      leader_brand <- names(comp_vals)[best_idx]
      leader_val   <- comp_vals[best_idx]
    }

    data.frame(
      Code         = cep_df$CEPCode[i],
      Focal_Pct    = focal_val,
      Leader_Brand = leader_brand,
      Leader_Pct   = leader_val,
      Gap_pp       = focal_val - leader_val,
      Focal_Leads  = !is.na(leader_val) && focal_val > leader_val,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Drivers & Barriers analysis for a category
#'
#' Combines differential importance (buyer vs non-buyer CEP linkage gap) and
#' focal brand CEP performance (linkage %) to produce an Importance x Performance
#' (IxP) quadrant map. Optionally identifies competitive gaps and summarises
#' rejection reasons.
#'
#' @param linkage List. Output of \code{build_cep_linkage_from_matrix()} or
#'   \code{build_cep_linkage()}.
#' @param cep_mat Matrix or data frame. CEP x brand linkage percentages (0-100).
#'   From \code{calculate_cep_brand_matrix()}.
#' @param pen Numeric vector. Binary focal-brand penetration (1 = buyer).
#' @param focal_brand Character. Focal brand code.
#' @param cep_labels Data frame (optional). Must contain CEPCode and CEPText.
#' @param rejection_data Data frame (optional). Must contain BrandCode and Reason.
#'   If supplied, computes a frequency table of rejection reasons for the focal brand.
#'
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{importance}{Data frame of differential importance scores}
#'   \item{ixp_quadrants}{Data frame with Quadrant classification}
#'   \item{competitive_advantage}{Data frame of focal vs best-competitor gaps}
#'   \item{metrics_summary}{List of summary counts}
#'   \item{rejection_themes}{Data frame (Reason, Count), if rejection_data supplied}
#'
#' @export
run_drivers_barriers <- function(linkage, cep_mat, pen, focal_brand,
                                  cep_labels = NULL, rejection_data = NULL) {

  # --- Guard ---
  if (is.null(linkage) || is.null(cep_mat) || is.null(pen)) {
    return(list(
      status     = "REFUSED",
      code       = "DATA_MISSING",
      message    = "linkage, cep_mat, and pen are all required",
      how_to_fix = paste0(
        "Provide: (1) linkage object from build_cep_linkage_from_matrix(), ",
        "(2) CEP matrix from calculate_cep_brand_matrix(), ",
        "(3) binary penetration vector (1 = buyer, 0 = non-buyer)")
    ))
  }

  cep_codes <- linkage$cep_codes %||% colnames(cep_mat)

  # --- 1. Differential importance ---
  importance <- tryCatch(
    calculate_differential_importance(
      linkage$linkage_tensor, pen, focal_brand, cep_codes
    ),
    error = function(e) {
      return(data.frame(Code = cep_codes, Buyer_Pct = NA, NonBuyer_Pct = NA,
                        Differential = NA, stringsAsFactors = FALSE))
    }
  )

  # --- 2. Performance: focal brand linkage % per CEP ---
  if (is.matrix(cep_mat)) {
    focal_pct <- if (focal_brand %in% colnames(cep_mat))
      as.numeric(cep_mat[, focal_brand]) else rep(NA_real_, nrow(cep_mat))
    performance <- data.frame(
      Code              = rownames(cep_mat),
      Focal_Linkage_Pct = focal_pct,
      stringsAsFactors  = FALSE
    )
  } else {
    focal_pct <- if (focal_brand %in% names(cep_mat))
      as.numeric(cep_mat[[focal_brand]]) else rep(NA_real_, nrow(cep_mat))
    performance <- data.frame(
      Code              = cep_mat$CEPCode,
      Focal_Linkage_Pct = focal_pct,
      stringsAsFactors  = FALSE
    )
  }

  # --- 3. IxP quadrant classification ---
  ixp_quadrants <- tryCatch(
    classify_ixp_quadrants(importance, performance),
    error = function(e) {
      data.frame(Code = cep_codes, Quadrant = NA_character_,
                 stringsAsFactors = FALSE)
    }
  )

  # --- 4. Competitive advantage ---
  if (is.matrix(cep_mat)) {
    cep_df         <- as.data.frame(cep_mat)
    cep_df$CEPCode <- rownames(cep_mat)
  } else {
    cep_df <- cep_mat
  }

  competitive_advantage <- tryCatch(
    calculate_competitive_advantage(cep_df, focal_brand),
    error = function(e) NULL
  )

  # --- 5. Metrics summary ---
  n_buy    <- sum(!is.na(pen) & pen > 0, na.rm = TRUE)
  n_nonbuy <- sum(!is.na(pen) & pen == 0, na.rm = TRUE)

  metrics_summary <- list(
    n_ceps       = length(cep_codes),
    n_buyers     = n_buy,
    n_nonbuyers  = n_nonbuy,
    focal_brand  = focal_brand
  )

  result <- list(
    status               = "PASS",
    importance           = importance,
    ixp_quadrants        = ixp_quadrants,
    competitive_advantage = competitive_advantage,
    metrics_summary      = metrics_summary
  )

  # --- 6. Rejection themes (optional) ---
  if (!is.null(rejection_data) && is.data.frame(rejection_data) &&
      nrow(rejection_data) > 0 &&
      all(c("BrandCode", "Reason") %in% names(rejection_data))) {
    focal_rej <- rejection_data[rejection_data$BrandCode == focal_brand, ,
                                drop = FALSE]
    if (nrow(focal_rej) > 0) {
      theme_counts <- sort(table(focal_rej$Reason), decreasing = TRUE)
      result$rejection_themes <- data.frame(
        Reason = names(theme_counts),
        Count  = as.integer(theme_counts),
        stringsAsFactors = FALSE
      )
    }
  }

  result
}


# ==============================================================================
# V2: BUILD INPUTS FROM ROLE MAP + SLOT-INDEXED DATA
# ==============================================================================

#' Run Drivers & Barriers from a v2 role map and slot-indexed data
#'
#' Thin v2 wrapper that builds the CEP linkage tensor, the CEP x brand
#' matrix, and the focal-brand buyer flag from the v2 role map, then
#' dispatches to \code{run_drivers_barriers()}. The analytical functions
#' (\code{calculate_differential_importance}, \code{classify_ixp_quadrants},
#' \code{calculate_competitive_advantage}) operate on tensors / matrices
#' and run unchanged.
#'
#' Required role-map entries:
#' \itemize{
#'   \item \code{mental_avail.cep.\{cat\}.*} — slot-indexed CEP roles
#'   \item \code{funnel.penetration_target.\{cat\}} — BRANDPEN2 root
#'         (target-window buyer flag for the focal brand)
#' }
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param cat_code Character.
#' @param brand_list Data frame with \code{BrandCode} column.
#' @param focal_brand Character. Required.
#' @param cep_labels Data frame with \code{CEPCode} + \code{CEPText}.
#' @param weights Numeric vector or NULL.
#' @return Same shape as \code{run_drivers_barriers()}.
#' @export
run_drivers_barriers_v2 <- function(data, role_map, cat_code, brand_list,
                                    focal_brand, cep_labels = NULL,
                                    weights = NULL) {
  if (is.null(focal_brand) || !nzchar(focal_brand)) {
    return(list(status = "REFUSED", code = "CFG_FOCAL_MISSING",
                message = "Drivers & Barriers requires focal_brand"))
  }
  if (is.null(data) || nrow(data) == 0L) {
    return(list(status = "REFUSED", code = "DATA_EMPTY",
                message = "No data for Drivers & Barriers"))
  }

  pen_role <- paste0("funnel.penetration_target.", cat_code)
  pen_entry <- role_map[[pen_role]]
  if (is.null(pen_entry) || is.null(pen_entry$column_root)) {
    return(list(status = "REFUSED", code = "CFG_ROLE_MISSING",
                message = sprintf(
                  "Drivers & Barriers requires role '%s'.", pen_role)))
  }

  # CEP linkage tensor + linkage % matrix
  linkage <- build_cep_linkage_v2(data, role_map, cat_code, brand_list,
                                  item_kind = "cep")
  if (length(linkage$cep_codes) == 0L) {
    return(list(status = "REFUSED", code = "CFG_NO_CEPS",
                message = sprintf(
                  "No CEP roles found for '%s' (looking for mental_avail.cep.%s.*).",
                  cat_code, cat_code)))
  }
  cep_mat <- calculate_cep_brand_matrix(linkage$linkage_tensor,
                                         linkage$cep_codes, weights)

  # Focal brand penetration vector (length nrow(data))
  pen_logical <- multi_mention_brand_matrix(data, pen_entry$column_root,
                                            focal_brand)
  pen <- as.integer(pen_logical[, focal_brand])

  run_drivers_barriers(
    linkage     = linkage,
    cep_mat     = cep_mat,
    pen         = pen,
    focal_brand = focal_brand,
    cep_labels  = cep_labels,
    rejection_data = NULL  # rejection OE not yet wired in v2
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Drivers & Barriers element loaded (v%s)",
                  DRIVERS_BARRIERS_VERSION))
}
