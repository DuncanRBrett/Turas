# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - MATRIX DATA BUILDERS
# ==============================================================================
# CEP x brand matrix (150 columns) and attribute x brand matrix (50 columns).
# These are the most data-dense parts of the survey — for each respondent who
# is aware of a brand, we simulate whether they link that brand to each CEP /
# attribute, using the factor model in 04a_data_helpers.R.
# ==============================================================================


# ==============================================================================
# CEP MATRIX
# ==============================================================================

#' Add CEP x brand matrix columns
#'
#' 15 CEPs x 10 brands = 150 binary columns named CEP{NN}_{BRAND}.
#'
#' Linkage is conditional on awareness: a respondent who isn't aware of a
#' brand cannot link a CEP to it. The linkage probability is driven by the
#' factor model in .cep_linkage_prob(): base_rate x brand_strength x
#' (1 + specialty_boost). A respondent-level engagement factor adds noise.
#'
#' @param df Data frame with awareness columns already present.
#' @return Data frame with 150 CEP x brand columns added.
#' @keywords internal
add_cep_matrix <- function(df) {
  n <- nrow(df)
  cat_code <- ipk_category()$code
  brands <- ipk_brands()
  ceps   <- ipk_ceps()

  # Per-respondent engagement noise (multiplicative, mean 1)
  engagement <- .rtrunc(n, mean = 1.0, sd = 0.22, lo = 0.35, hi = 1.55)

  for (b in brands) {
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware <- df[[aware_col]] == 1L

    for (cep in ceps) {
      col <- sprintf("%s_%s", cep$code, b$code)
      p_link <- .cep_linkage_prob(b, cep)
      # Linkage noise per respondent
      p_row <- pmin(pmax(p_link * engagement, 0), 0.97)
      # Only aware respondents can link; others get 0
      draws <- .rbern(n, p_row)
      draws[!aware] <- 0L
      df[[col]] <- draws
    }
  }
  df
}


# ==============================================================================
# ATTRIBUTE MATRIX
# ==============================================================================

#' Add attribute x brand matrix columns
#'
#' 5 attributes x 10 brands = 50 binary columns named ATTR{NN}_{BRAND}.
#'
#' Same logic as CEPs but uses .attr_linkage_prob(). Attribute strength is
#' skewed by brand quality tier (premium brands strong on quality/trust,
#' value brands strong on value/easy-to-use).
#'
#' @param df Data frame with awareness columns already present.
#' @return Data frame with 50 attribute x brand columns added.
#' @keywords internal
add_attribute_matrix <- function(df) {
  n <- nrow(df)
  cat_code <- ipk_category()$code
  brands <- ipk_brands()
  attrs  <- ipk_attributes()

  # Separate engagement factor (less variation than CEPs — attributes are
  # more universally known than situation-specific CEPs)
  engagement <- .rtrunc(n, mean = 1.0, sd = 0.15, lo = 0.55, hi = 1.45)

  for (b in brands) {
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware <- df[[aware_col]] == 1L

    for (a in attrs) {
      col <- sprintf("%s_%s", a$code, b$code)
      p_link <- .attr_linkage_prob(b, a$code)
      p_row <- pmin(pmax(p_link * engagement, 0), 0.95)
      draws <- .rbern(n, p_row)
      draws[!aware] <- 0L
      df[[col]] <- draws
    }
  }
  df
}
