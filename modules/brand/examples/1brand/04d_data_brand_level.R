# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - BRAND-LEVEL DATA BUILDERS
# ==============================================================================
# Word-of-Mouth and Distinctive Brand Assets — the two batteries that operate
# at brand level rather than per-category (Category = "ALL" in the structure).
# ==============================================================================


# ==============================================================================
# WORD-OF-MOUTH
# ==============================================================================

#' Add WOM columns
#'
#' Per brand, four binary indicators plus two brand-level frequency scales:
#'   WOM_POS_REC_{BRAND}   — received positive WOM about this brand
#'   WOM_NEG_REC_{BRAND}   — received negative WOM about this brand
#'   WOM_POS_SHARE_{BRAND} — shared positive WOM about this brand
#'   WOM_NEG_SHARE_{BRAND} — shared negative WOM about this brand
#'   WOM_POS_FREQ          — overall frequency of hearing positive WOM (1-5)
#'   WOM_NEG_FREQ          — overall frequency of hearing negative WOM (1-5)
#'
#' Positive WOM tracks brand strength (bigger brands get more positive WOM).
#' Shared positive WOM is driven by attitude = 1 (love).
#' Shared negative WOM is driven by attitude = 4 (reject).
#' Received negative WOM tracks overall rejection rate weakly.
#'
#' @keywords internal
add_wom <- function(df) {
  n <- nrow(df)
  cat_code <- ipk_category()$code
  brands <- ipk_brands()

  # Respondent-level WOM engagement (some people talk about brands, some don't)
  wom_engagement <- .rtrunc(n, mean = 1.0, sd = 0.28, lo = 0.2, hi = 1.8)

  for (b in brands) {
    att_col <- sprintf("BRANDATT1_%s_%s", cat_code, b$code)
    att <- df[[att_col]]

    rec_pos <- integer(n)
    rec_neg <- integer(n)
    share_pos <- integer(n)
    share_neg <- integer(n)

    # Received positive WOM: scales with brand strength + awareness
    p_rec_pos <- pmin(b$strength * 0.35 * wom_engagement, 0.70)
    rec_pos <- .rbern(n, p_rec_pos)

    # Received negative WOM: small baseline, higher for less-loved brands
    base_rec_neg <- 0.08 + 0.06 * (1 - b$strength)
    p_rec_neg <- pmin(base_rec_neg * wom_engagement, 0.35)
    rec_neg <- .rbern(n, p_rec_neg)

    # Shared positive WOM: only respondents who love (att=1) or prefer (att=2)
    love_mask <- !is.na(att) & att == 1L
    prefer_mask <- !is.na(att) & att == 2L
    share_pos[love_mask] <- .rbern(sum(love_mask), 0.55 * wom_engagement[love_mask])
    share_pos[prefer_mask] <- .rbern(sum(prefer_mask), 0.18 * wom_engagement[prefer_mask])

    # Shared negative WOM: driven by rejection (att=4)
    reject_mask <- !is.na(att) & att == 4L
    share_neg[reject_mask] <- .rbern(sum(reject_mask), 0.62 * wom_engagement[reject_mask])

    df[[sprintf("WOM_POS_REC_%s",   b$code)]] <- rec_pos
    df[[sprintf("WOM_NEG_REC_%s",   b$code)]] <- rec_neg
    df[[sprintf("WOM_POS_SHARE_%s", b$code)]] <- share_pos
    df[[sprintf("WOM_NEG_SHARE_%s", b$code)]] <- share_neg
  }

  # Overall WOM frequency scales (1 = several times a week, 5 = never)
  df$WOM_POS_FREQ <- .rcat(n, c(0.08, 0.18, 0.32, 0.28, 0.14))
  df$WOM_NEG_FREQ <- .rcat(n, c(0.03, 0.08, 0.18, 0.38, 0.33))
  df
}


# ==============================================================================
# DISTINCTIVE BRAND ASSETS
# ==============================================================================

#' Add DBA columns
#'
#' Per asset, two columns:
#'   DBA_FAME_{ASSET}   — 1 = recognised, 2 = not recognised
#'   DBA_UNIQUE_{ASSET} — brand code attributed (only if fame = 1)
#'
#' Fame rate and correct-attribution rate come from the asset definition in
#' ipk_dba_assets(). Respondents who don't recognise an asset (fame = 2)
#' get NA on the uniqueness column.
#'
#' @keywords internal
add_dba <- function(df) {
  n <- nrow(df)
  assets <- ipk_dba_assets()
  focal <- ipk_focal_brand_code()

  # Respondent-level asset-recognition skill (some people notice more branding)
  recognition_factor <- .rtrunc(n, mean = 1.0, sd = 0.18, lo = 0.5, hi = 1.5)

  for (a in assets) {
    fame_col   <- sprintf("DBA_FAME_%s", a$code)
    unique_col <- sprintf("DBA_UNIQUE_%s", a$code)

    # Fame draw: 1 = seen before, 2 = not seen
    p_recognise <- pmin(a$fame_rate * recognition_factor, 0.97)
    recognised <- .rbern(n, p_recognise)
    fame <- ifelse(recognised == 1L, 1L, 2L)

    # Uniqueness: only for recognised respondents
    unique_val <- rep(NA_character_, n)
    n_rec <- sum(recognised)
    if (n_rec > 0) {
      unique_val[recognised == 1L] <-
        .sample_dba_attribution(n_rec, focal, a$unique_attribution_rate)
    }

    df[[fame_col]]   <- fame
    df[[unique_col]] <- unique_val
  }
  df
}
