# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - RESPONDENT-LEVEL DATA BUILDERS
# ==============================================================================
# Functions that build columns corresponding to respondent-level properties:
# identification, demographics, weights, category buying, awareness, attitude,
# and brand penetration.
#
# Each function takes a data frame and returns it with new columns attached.
# All randomness assumed to be inside a with_seed() block upstream.
# ==============================================================================


# ==============================================================================
# CORE COLUMNS: id, weight, category, qualifier, demographics, category buying
# ==============================================================================

#' Build the respondent shell
#'
#' @param n Integer. Number of respondents.
#' @return Data frame with core respondent columns.
#' @keywords internal
build_respondent_core <- function(n) {
  cat_def <- ipk_category()

  data.frame(
    Respondent_ID   = sprintf("R%04d", seq_len(n)),
    Weight          = round(.rtrunc(n, mean = 1.0, sd = 0.15, lo = 0.55, hi = 1.55), 3),
    Focal_Category  = cat_def$name,
    Qualified_DSS   = 1L,
    stringsAsFactors = FALSE
  )
}


#' Add demographic columns
#'
#' @keywords internal
add_demographics <- function(df) {
  n <- nrow(df)
  df$Age_Group <- .rcat(n, c(0.15, 0.22, 0.24, 0.20, 0.19))
  df$Gender    <- .rcat(n, c(0.30, 0.68, 0.02))
  df$Income_Group <- .rcat(n, c(0.18, 0.26, 0.28, 0.18, 0.10))
  df$LSM_Group    <- .rcat(n, c(0.05, 0.12, 0.20, 0.28, 0.22, 0.10, 0.03))
  df$Region       <- .rcat(n, c(0.27, 0.22, 0.20, 0.10, 0.07, 0.05, 0.04, 0.03, 0.02))
  df
}


#' Add category-buying frequency
#'
#' @keywords internal
add_category_buying <- function(df) {
  cat_code <- ipk_category()$code
  col <- sprintf("CATBUY_%s", cat_code)
  # Most respondents buy weekly or a few times a month
  df[[col]] <- .rcat(nrow(df), c(0.14, 0.38, 0.34, 0.12, 0.02))
  df
}


# ==============================================================================
# AWARENESS
# ==============================================================================

#' Add per-brand awareness columns
#'
#' One binary column per brand: BRANDAWARE_{CAT}_{BRAND}.
#' Awareness is correlated across brands within a respondent — people who are
#' more category-engaged (CATBUY high frequency) are aware of more brands.
#'
#' @keywords internal
add_awareness <- function(df) {
  n <- nrow(df)
  cat_code <- ipk_category()$code
  cat_buy_col <- sprintf("CATBUY_%s", cat_code)

  # Respondent-level engagement factor: higher for more frequent buyers
  engagement <- 1.0 + 0.22 * (3 - df[[cat_buy_col]]) / 2
  engagement <- pmin(pmax(engagement, 0.7), 1.3)

  for (b in ipk_brands()) {
    col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    p <- pmin(b$awareness_rate * engagement, 0.99)
    df[[col]] <- .rbern(n, p)
  }
  df
}


# ==============================================================================
# ATTITUDE
# ==============================================================================

#' Add per-brand attitude columns and open-ended rejection reasons
#'
#' BRANDATT1_{CAT}_{BRAND} is a 1-5 scale. Respondents who aren't aware of
#' the brand get NA. Otherwise the distribution depends on brand quality tier
#' and whether the brand is focal.
#'
#' BRANDATT2_{CAT}_{BRAND} is a free-text rejection reason, populated only
#' when attitude = 4 ("I would refuse to buy this brand").
#'
#' @keywords internal
add_attitude <- function(df) {
  n <- nrow(df)
  cat_code <- ipk_category()$code
  reasons <- .rejection_reasons()

  for (b in ipk_brands()) {
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    att1_col  <- sprintf("BRANDATT1_%s_%s", cat_code, b$code)
    att2_col  <- sprintf("BRANDATT2_%s_%s", cat_code, b$code)

    aware_mask <- df[[aware_col]] == 1L
    att_vals <- rep(NA_integer_, n)
    att_text <- rep(NA_character_, n)

    n_aware <- sum(aware_mask)
    if (n_aware > 0) {
      dist <- .attitude_dist(b$quality_tier, is_focal = isTRUE(b$is_focal))
      draws <- .rcat(n_aware, dist)
      att_vals[aware_mask] <- draws

      reject_mask_within <- which(draws == 4L)
      if (length(reject_mask_within) > 0) {
        reject_idx_global <- which(aware_mask)[reject_mask_within]
        att_text[reject_idx_global] <- sample(reasons,
          size = length(reject_idx_global), replace = TRUE)
      }
    }
    df[[att1_col]] <- att_vals
    df[[att2_col]] <- att_text
  }
  df
}


# ==============================================================================
# PENETRATION
# ==============================================================================

#' Add per-brand penetration columns (long timeframe, target timeframe, frequency)
#'
#' Penetration depends on attitude:
#'   attitude 1 (love)      -> 90% bought in 12 mo
#'   attitude 2 (prefer)    -> 75%
#'   attitude 3 (ambivalent) -> 35%
#'   attitude 4 (reject)    -> 0%
#'   attitude 5 (no opinion) -> 8%
#'
#' Target timeframe (3 mo) is a subset of long timeframe, 60-70% pass-through.
#' Purchase frequency (1-5) is conditional on bought in target timeframe.
#'
#' @keywords internal
add_penetration <- function(df) {
  n <- nrow(df)
  cat_code <- ipk_category()$code

  # Pass-through rate from 12 mo -> 3 mo, per brand strength
  # (stronger brands have more regular buyers)
  for (b in ipk_brands()) {
    att1_col <- sprintf("BRANDATT1_%s_%s", cat_code, b$code)
    pen1_col <- sprintf("BRANDPEN1_%s_%s", cat_code, b$code)
    pen2_col <- sprintf("BRANDPEN2_%s_%s", cat_code, b$code)
    pen3_col <- sprintf("BRANDPEN3_%s_%s", cat_code, b$code)

    att <- df[[att1_col]]
    pen1 <- integer(n)
    pen2 <- integer(n)
    pen3 <- rep(NA_integer_, n)

    # 12-month penetration by attitude
    p_by_att <- c("1" = 0.90, "2" = 0.75, "3" = 0.35, "4" = 0.00, "5" = 0.08)
    for (att_val in names(p_by_att)) {
      mask <- !is.na(att) & att == as.integer(att_val)
      if (any(mask)) pen1[mask] <- .rbern(sum(mask), p_by_att[[att_val]])
    }

    # 3-month penetration: subset of 12-month
    pass_rate <- 0.55 + 0.20 * b$strength  # stronger brands retain more
    pen2_mask <- pen1 == 1L
    if (any(pen2_mask)) {
      pen2[pen2_mask] <- .rbern(sum(pen2_mask), pass_rate)
    }

    # Purchase frequency: 1 (every time) .. 5 (rarely)
    # Centred higher for preferred brands, lower for ambivalent
    bought_mask <- pen2 == 1L
    if (any(bought_mask)) {
      freq_dist <- .penetration_freq_dist(b)
      pen3[bought_mask] <- .rcat(sum(bought_mask), freq_dist)
    }

    df[[pen1_col]] <- pen1
    df[[pen2_col]] <- pen2
    df[[pen3_col]] <- pen3
  }
  df
}


#' Purchase frequency distribution for a brand
#'
#' Stronger focal brands skew toward "every time / most times";
#' weaker brands skew toward "rarely".
#' @keywords internal
.penetration_freq_dist <- function(brand) {
  base <- c(0.08, 0.22, 0.38, 0.22, 0.10)
  if (brand$strength > 0.80) {
    return(c(0.18, 0.32, 0.30, 0.14, 0.06))
  }
  if (brand$strength > 0.60) {
    return(c(0.12, 0.28, 0.35, 0.18, 0.07))
  }
  if (brand$strength < 0.40) {
    return(c(0.05, 0.15, 0.32, 0.32, 0.16))
  }
  base
}
