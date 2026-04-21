# ==============================================================================
# BRAND MODULE - BUYER HEAVINESS
# ==============================================================================
# Splits category buyers into weight-equal tertiles by purchase volume (m_i),
# computes per-brand buyer-base heaviness composition, buy rate profile, and
# Natural Monopoly Index per §2.4 of CAT_BUYING_SPEC_v3.
#
# VERSION: 1.0
#
# REFERENCES:
#   Ehrenberg, A.S.C. (1988). Repeat Buying (2nd ed.).
#   Romaniuk, J. & Sharp, B. (2022). How Brands Grow Part 2.
# ==============================================================================

BRAND_BUYER_HEAVINESS_VERSION <- "1.0"

# Tie-breaking tolerance: tertile sizes must be within this fraction of 1/3
.BH_TERTILE_TOL <- 0.05


#' Compute buyer heaviness by purchase volume tertile
#'
#' Splits category buyers into three weight-equal tertiles (Light / Medium /
#' Heavy) ranked by per-respondent category volume (\code{m_vec}). Computes
#' each brand's buyer composition across the tertiles, its buy rate vs the
#' category mean, and the Natural Monopoly Index.
#'
#' Tie handling: when \code{m_vec} contains many identical values (common with
#' midpoint-of-range responses), weight is pushed to the next tertile until
#' all three buckets fall within ±5 percentage points of one-third.
#'
#' @param pen_mat Integer matrix n_resp × n_brands. Reconciled 0/1 buyer flags.
#' @param m_vec Numeric vector length n_resp. Per-respondent category volume.
#' @param brand_codes Character vector. Brand codes.
#' @param focal_brand Character or NULL. For metrics_summary.
#' @param weights Numeric vector or NULL. Respondent weights.
#'
#' @return List — see §7.3 of CAT_BUYING_SPEC_v3.
#'
#' @references Ehrenberg (1988); Romaniuk & Sharp (2022).
#'
#' @export
run_buyer_heaviness <- function(pen_mat,
                                m_vec,
                                brand_codes,
                                focal_brand = NULL,
                                weights     = NULL) {

  if (is.null(pen_mat) || nrow(pen_mat) == 0)
    return(.bh_refuse("DATA_NO_BUYERS", "pen_mat is empty"))

  n_resp   <- nrow(pen_mat)
  n_brands <- length(brand_codes)
  w        <- .bh_weights(weights, n_resp)

  # --- Buyers only ---
  buyers_mask <- m_vec > 0
  n_buyers    <- sum(buyers_mask)
  if (n_buyers == 0)
    return(.bh_refuse("DATA_NO_BUYERS", "No category buyers found"))

  # --- Tertile boundaries ---
  m_buyers <- m_vec[buyers_mask]
  w_buyers <- w[buyers_mask]

  # Check for all-same m_vec (tertiles undefined)
  if (length(unique(m_buyers)) == 1) {
    single_tier <- data.frame(
      Tier = "All",
      Pct  = 100, n = n_buyers,
      stringsAsFactors = FALSE)
    return(list(
      status             = "PARTIAL",
      warnings           = "All buyers have identical m_i; tertiles are undefined",
      tertile_bounds     = list(light = c(0, Inf), medium = NULL, heavy = NULL),
      category_buyer_mix = single_tier,
      brand_heaviness    = .bh_empty_heaviness(brand_codes, n_brands),
      metrics_summary    = list(focal_brand = focal_brand %||% NA_character_,
                                focal_nmi = NA_real_, focal_wbar = NA_real_,
                                focal_wbar_gap = NA_real_)
    ))
  }

  tert <- .bh_tertile_bounds(m_buyers, w_buyers)
  q33  <- tert$q33
  q67  <- tert$q67

  # Category-level tertile composition
  tier_masks <- list(
    light  = buyers_mask & m_vec <= q33,
    medium = buyers_mask & m_vec >  q33 & m_vec <= q67,
    heavy  = buyers_mask & m_vec >  q67
  )
  tier_names <- c("Light", "Medium", "Heavy")
  cat_mix <- data.frame(
    Tier = tier_names,
    Pct  = vapply(tier_masks, function(m) {
      sum(w[m]) / sum(w_buyers) * 100
    }, numeric(1)),
    n    = vapply(tier_masks, function(m) sum(m), integer(1)),
    stringsAsFactors = FALSE
  )

  # --- Per-brand heaviness ---
  cat_wbar <- sum(w_buyers * m_buyers) / sum(w_buyers)

  brand_rows <- lapply(seq_len(n_brands), function(bi) {
    b_mask <- pen_mat[, bi] == 1L & buyers_mask
    n_bb   <- sum(b_mask)
    w_bb   <- sum(w[b_mask])

    if (n_bb == 0) {
      return(list(
        BrandCode = brand_codes[bi],
        Heavy_Pct = NA_real_, Medium_Pct = NA_real_, Light_Pct = NA_real_,
        WBar_Brand = NA_real_, WBar_Category = cat_wbar, WBar_Gap = NA_real_,
        NaturalMonopolyIndex = NA_real_, Brand_Buyers_n = 0L
      ))
    }

    heavy_p  <- sum(w[b_mask & tier_masks$heavy])  / w_bb * 100
    medium_p <- sum(w[b_mask & tier_masks$medium]) / w_bb * 100
    light_p  <- sum(w[b_mask & tier_masks$light])  / w_bb * 100

    wbar_brand <- sum(w[b_mask] * m_vec[b_mask]) / w_bb

    cat_light_share <- cat_mix$Pct[cat_mix$Tier == "Light"] / 100
    brand_light_share <- light_p / 100
    nmi <- if (!is.na(cat_light_share) && cat_light_share > 0)
      brand_light_share / cat_light_share * 100 else NA_real_

    list(
      BrandCode            = brand_codes[bi],
      Heavy_Pct            = heavy_p,
      Medium_Pct           = medium_p,
      Light_Pct            = light_p,
      WBar_Brand           = wbar_brand,
      WBar_Category        = cat_wbar,
      WBar_Gap             = wbar_brand - cat_wbar,
      NaturalMonopolyIndex = nmi,
      Brand_Buyers_n       = n_bb
    )
  })

  brand_heaviness <- as.data.frame(
    do.call(rbind, lapply(brand_rows, as.data.frame, stringsAsFactors = FALSE)),
    stringsAsFactors = FALSE)

  # --- metrics_summary ---
  ms <- list(
    focal_brand    = focal_brand %||% NA_character_,
    focal_nmi      = NA_real_,
    focal_wbar     = NA_real_,
    focal_wbar_gap = NA_real_
  )
  if (!is.null(focal_brand) && focal_brand %in% brand_heaviness$BrandCode) {
    fr <- brand_heaviness[brand_heaviness$BrandCode == focal_brand, ]
    ms$focal_nmi      <- fr$NaturalMonopolyIndex
    ms$focal_wbar     <- fr$WBar_Brand
    ms$focal_wbar_gap <- fr$WBar_Gap
  }

  list(
    status             = "PASS",
    tertile_bounds     = list(light = c(0, q33), medium = c(q33, q67),
                               heavy = c(q67, Inf)),
    category_buyer_mix = cat_mix,
    brand_heaviness    = brand_heaviness,
    metrics_summary    = ms
  )
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Compute weight-balanced tertile boundaries with tie-breaking (§2.4)
#' @keywords internal
.bh_tertile_bounds <- function(m_buyers, w_buyers) {
  ord      <- order(m_buyers)
  m_sorted <- m_buyers[ord]
  w_sorted <- w_buyers[ord]
  cumw     <- cumsum(w_sorted)
  total_w  <- sum(w_sorted)
  target   <- total_w / 3

  # Find q33: smallest m where cumulative weight >= target
  q33_idx <- which(cumw >= target)[1]
  q33     <- m_sorted[q33_idx]

  # Tie-break: if many respondents share this value, push them all to medium
  # until light tertile is within ±5pp of 1/3
  while (TRUE) {
    light_w  <- sum(w_buyers[m_buyers <= q33])
    light_p  <- light_w / total_w
    if (abs(light_p - 1/3) <= .BH_TERTILE_TOL) break
    # Find next distinct value above q33
    above    <- unique(m_sorted[m_sorted > q33])
    if (length(above) == 0) break
    q33 <- above[1]
  }

  # q67: light+medium = 2/3
  q67_idx <- which(cumw >= 2 * target)[1]
  q67     <- m_sorted[q67_idx]

  while (q67 <= q33 && q67 < max(m_sorted)) {
    above <- unique(m_sorted[m_sorted > q67])
    if (length(above) == 0) break
    q67 <- above[1]
  }

  list(q33 = q33, q67 = q67)
}


#' Return empty brand_heaviness frame when no buyers
#' @keywords internal
.bh_empty_heaviness <- function(brand_codes, n_brands) {
  data.frame(
    BrandCode            = brand_codes,
    Heavy_Pct            = NA_real_,
    Medium_Pct           = NA_real_,
    Light_Pct            = NA_real_,
    WBar_Brand           = NA_real_,
    WBar_Category        = NA_real_,
    WBar_Gap             = NA_real_,
    NaturalMonopolyIndex = NA_real_,
    Brand_Buyers_n       = 0L,
    stringsAsFactors     = FALSE
  )
}


#' Normalise weights
#' @keywords internal
.bh_weights <- function(weights, n) {
  if (is.null(weights)) return(rep(1.0, n))
  if (length(weights) != n) return(rep(1.0, n))
  w <- as.numeric(weights)
  w[is.na(w) | w < 0] <- 0
  if (sum(w) <= 0) rep(1.0, n) else w
}


#' TRS refusal for this module
#' @keywords internal
.bh_refuse <- function(code, message) {
  cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
  cat("│ Module: 08d_buyer_heaviness\n")
  cat(sprintf("│ Code:    %s\n", code))
  cat(sprintf("│ Message: %s\n", message))
  cat("└───────────────────────────────────────────────────────┘\n\n")
  list(status = "REFUSED", code = code, message = message)
}

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Buyer Heaviness element loaded (v%s)",
                  BRAND_BUYER_HEAVINESS_VERSION))
}
