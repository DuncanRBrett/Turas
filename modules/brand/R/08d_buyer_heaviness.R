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

# Tolerance: tertile sizes may deviate ±5pp from 1/3 to absorb heavy ties in
# m_vec (e.g. when many buyers report exactly 1 purchase per the target window).
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
                                weights     = NULL,
                                x_mat       = NULL) {

  if (is.null(pen_mat) || nrow(pen_mat) == 0)
    return(.bh_refuse("DATA_NO_BUYERS", "pen_mat is empty"))

  n_resp   <- nrow(pen_mat)
  n_brands <- length(brand_codes)
  w        <- .bh_weights(weights, n_resp)

  # Validate x_mat dimensions; discard if mismatched
  if (!is.null(x_mat) &&
      !(is.matrix(x_mat) && nrow(x_mat) == n_resp && ncol(x_mat) == n_brands)) {
    x_mat <- NULL
  }

  # --- Buyers only ---
  buyers_mask <- m_vec > 0
  n_buyers    <- sum(buyers_mask)
  if (n_buyers == 0)
    return(.bh_refuse("DATA_NO_BUYERS", "No category buyers found"))

  # --- Tertile boundaries ---
  m_buyers <- m_vec[buyers_mask]
  w_buyers <- w[buyers_mask]

  # Loyalty segments and purchase frequency distribution (requires x_mat)
  loy_segs  <- if (!is.null(x_mat))
    .bh_loyalty_segments(pen_mat, x_mat, m_vec, brand_codes, w, buyers_mask) else NULL
  freq_dist <- if (!is.null(x_mat))
    .bh_freq_dist(pen_mat, x_mat, brand_codes, w, buyers_mask) else NULL

  # Category-level frequency distribution: bucket m_vec (total category
  # purchases per buyer) into the same 1/2/3-5/6+ breaks used by brand_freq_dist.
  cat_freq_dist <- .bh_category_freq_dist(m_vec, w, buyers_mask)

  # Check for all-same m_vec (tertiles undefined)
  if (length(unique(m_buyers)) == 1) {
    single_tier <- data.frame(
      Tier = "All",
      Pct  = 100, n = n_buyers,
      stringsAsFactors = FALSE)
    return(list(
      status                 = "PARTIAL",
      warnings               = "All buyers have identical m_i; tertiles are undefined",
      tertile_bounds         = list(light = c(0, Inf), medium = NULL, heavy = NULL),
      category_buyer_mix     = single_tier,
      brand_heaviness        = .bh_empty_heaviness(brand_codes, n_brands),
      brand_loyalty_segments = loy_segs,
      brand_freq_dist        = freq_dist,
      category_freq_dist     = cat_freq_dist,
      metrics_summary        = list(focal_brand = focal_brand %||% NA_character_,
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
    status                 = "PASS",
    tertile_bounds         = list(light = c(0, q33), medium = c(q33, q67),
                                   heavy = c(q67, Inf)),
    category_buyer_mix     = cat_mix,
    brand_heaviness        = brand_heaviness,
    brand_loyalty_segments = loy_segs,
    brand_freq_dist        = freq_dist,
    category_freq_dist     = cat_freq_dist,
    metrics_summary        = ms
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


#' Compute 4-segment loyalty profile per brand as % of all category buyers
#'
#' Segments: Sole (only this brand) | Primary (SCR > 50%, not sole) |
#' Secondary (SCR ≤ 50%) | Not in repertoire.
#'
#' @param pen_mat Integer matrix n_resp × n_brands.
#' @param x_mat Numeric matrix n_resp × n_brands. Purchase counts (col index = brand).
#' @param m_vec Numeric vector. Per-respondent category volume.
#' @param brand_codes Character vector.
#' @param w Numeric vector. Weights.
#' @param buyers_mask Logical vector. TRUE for category buyers (m_vec > 0).
#'
#' @return Data frame: BrandCode | Sole_Pct | Primary_Pct | Secondary_Pct | NoBuy_Pct.
#' @keywords internal
.bh_loyalty_segments <- function(pen_mat, x_mat, m_vec, brand_codes, w, buyers_mask) {
  n_brands    <- length(brand_codes)
  w_cat       <- w[buyers_mask]
  total_cat_w <- sum(w_cat)
  m_cat       <- m_vec[buyers_mask]

  rows <- lapply(seq_len(n_brands), function(bi) {
    x_j        <- x_mat[buyers_mask, bi]
    x_j[is.na(x_j)] <- 0
    scr_j      <- ifelse(m_cat > 0, x_j / m_cat, 0)
    bought     <- x_j > 0
    sole       <- bought & (x_j >= m_cat)
    primary    <- bought & !sole & (scr_j > 0.5)
    secondary  <- bought & !sole & !primary
    no_buy     <- !bought

    list(
      BrandCode     = brand_codes[bi],
      Sole_Pct      = sum(w_cat[sole])       / total_cat_w * 100,
      Primary_Pct   = sum(w_cat[primary])    / total_cat_w * 100,
      Secondary_Pct = sum(w_cat[secondary])  / total_cat_w * 100,
      NoBuy_Pct     = sum(w_cat[no_buy])     / total_cat_w * 100
    )
  })

  as.data.frame(
    do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE)),
    stringsAsFactors = FALSE)
}


#' Compute purchase frequency distribution per brand among brand buyers
#'
#' Buckets: 1×, 2×, 3–5×, 6+×. Values as % of weighted brand buyer count.
#'
#' @param pen_mat Integer matrix n_resp × n_brands.
#' @param x_mat Numeric matrix n_resp × n_brands. Purchase counts.
#' @param brand_codes Character vector.
#' @param w Numeric vector. Weights.
#' @param buyers_mask Logical vector. TRUE for category buyers.
#'
#' @return Data frame: BrandCode | Freq1_Pct | Freq2_Pct | Freq3to5_Pct | Freq6plus_Pct.
#' @keywords internal
.bh_freq_dist <- function(pen_mat, x_mat, brand_codes, w, buyers_mask) {
  n_brands <- length(brand_codes)

  rows <- lapply(seq_len(n_brands), function(bi) {
    b_mask <- pen_mat[, bi] == 1L & buyers_mask
    if (!any(b_mask)) {
      return(list(BrandCode = brand_codes[bi], Freq1_Pct = NA_real_,
                  Freq2_Pct = NA_real_, Freq3to5_Pct = NA_real_, Freq6plus_Pct = NA_real_))
    }
    x_j    <- as.integer(round(x_mat[b_mask, bi]))
    x_j[is.na(x_j) | x_j < 1L] <- 1L
    w_bb   <- w[b_mask]
    tot_w  <- sum(w_bb)

    list(
      BrandCode     = brand_codes[bi],
      Freq1_Pct     = sum(w_bb[x_j == 1L])              / tot_w * 100,
      Freq2_Pct     = sum(w_bb[x_j == 2L])              / tot_w * 100,
      Freq3to5_Pct  = sum(w_bb[x_j >= 3L & x_j <= 5L]) / tot_w * 100,
      Freq6plus_Pct = sum(w_bb[x_j >= 6L])              / tot_w * 100
    )
  })

  as.data.frame(
    do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE)),
    stringsAsFactors = FALSE)
}


#' Compute category-level purchase frequency distribution (1/2/3-5/6+ buckets)
#'
#' Buckets each category buyer by total category purchase count (\code{m_vec}).
#' Uses the same breaks as \code{.bh_freq_dist} so the Category Context and
#' Purchase Distribution panels share a consistent frequency concept.
#'
#' @param m_vec Numeric vector. Per-respondent category purchase count.
#' @param w Numeric vector. Weights.
#' @param buyers_mask Logical vector. TRUE for category buyers (m_vec > 0).
#'
#' @return Data frame with columns: Bucket (1, 2, 3to5, 6plus), Label
#'   (1x, 2x, 3-5x, 6+x), Pct (% of category buyers), n (unweighted count).
#' @keywords internal
.bh_category_freq_dist <- function(m_vec, w, buyers_mask) {
  m_b <- as.integer(round(m_vec[buyers_mask]))
  m_b[is.na(m_b) | m_b < 1L] <- 1L
  w_b   <- w[buyers_mask]
  tot_w <- sum(w_b)
  if (!is.finite(tot_w) || tot_w <= 0) {
    return(data.frame(
      Bucket = c("1", "2", "3to5", "6plus"),
      Label  = c("1\u00d7", "2\u00d7", "3\u20135\u00d7", "6+\u00d7"),
      Pct    = rep(NA_real_, 4),
      n      = rep(0L, 4),
      stringsAsFactors = FALSE))
  }
  masks <- list(
    m_b == 1L,
    m_b == 2L,
    m_b >= 3L & m_b <= 5L,
    m_b >= 6L)
  data.frame(
    Bucket = c("1", "2", "3to5", "6plus"),
    Label  = c("1\u00d7", "2\u00d7", "3\u20135\u00d7", "6+\u00d7"),
    Pct    = vapply(masks, function(mk) sum(w_b[mk]) / tot_w * 100, numeric(1)),
    n      = vapply(masks, function(mk) sum(mk), integer(1)),
    stringsAsFactors = FALSE)
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
