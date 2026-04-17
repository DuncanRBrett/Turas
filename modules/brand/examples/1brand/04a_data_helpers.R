# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - DATA GENERATOR HELPERS
# ==============================================================================
# Shared helpers for the synthetic data generator. All randomness goes through
# `withr::with_seed()` in the orchestrator (04_data.R) so the generated CSV
# is byte-identical across runs.
# ==============================================================================


# ==============================================================================
# RNG UTILITIES
# ==============================================================================

#' Bernoulli draw
#'
#' @param n Integer. Number of draws.
#' @param p Numeric scalar in [0,1]. Probability of success.
#' @return Integer vector of 0/1.
#' @keywords internal
.rbern <- function(n, p) {
  stopifnot(length(p) == 1 || length(p) == n)
  as.integer(stats::runif(n) < p)
}

#' Multinomial draw returning integer category codes
#'
#' @param n Integer. Number of draws.
#' @param probs Numeric vector summing to 1.
#' @return Integer vector of category indices (1..length(probs)).
#' @keywords internal
.rcat <- function(n, probs) {
  stopifnot(abs(sum(probs) - 1) < 1e-6)
  u <- stats::runif(n)
  cuts <- cumsum(probs)
  findInterval(u, cuts) + 1L
}

#' Truncated normal on [lo, hi] with given mean and sd
#'
#' @keywords internal
.rtrunc <- function(n, mean = 0, sd = 1, lo = -Inf, hi = Inf) {
  x <- stats::rnorm(n, mean = mean, sd = sd)
  x[x < lo] <- lo
  x[x > hi] <- hi
  x
}


# ==============================================================================
# ATTITUDE DISTRIBUTION BY QUALITY TIER
# ==============================================================================

#' Brand attitude probability distribution for a given quality tier
#'
#' Returns probabilities for the 5-level attitude scale:
#'   1 = Love, 2 = Prefer, 3 = Ambivalent (would buy if no choice),
#'   4 = Reject, 5 = No opinion
#'
#' @param tier Character. "premium" | "mainstream" | "value"
#' @param is_focal Logical. TRUE boosts the positive end for the focal brand
#' @return Numeric vector of length 5 summing to 1.
#' @keywords internal
.attitude_dist <- function(tier, is_focal = FALSE) {
  dist <- switch(tier,
    "premium"    = c(0.22, 0.38, 0.22, 0.04, 0.14),
    "mainstream" = c(0.10, 0.42, 0.30, 0.06, 0.12),
    "value"      = c(0.05, 0.24, 0.42, 0.12, 0.17),
    stop("Unknown quality tier: ", tier, call. = FALSE)
  )
  if (isTRUE(is_focal)) {
    # Shift 5pp from "no opinion" to "love" for focal brand
    dist <- dist + c(0.05, 0, 0, 0, -0.05)
  }
  dist / sum(dist)
}


# ==============================================================================
# CEP LINKAGE PROBABILITY
# ==============================================================================

#' Probability that a respondent links a given CEP to a given brand
#'
#' Factor model:
#'   P(linked | aware) = base_rate × brand_strength × (1 + specialty_boost)
#'
#' @param brand List. Brand definition from ipk_brands().
#' @param cep   List. CEP definition from ipk_ceps().
#' @return Scalar probability in [0, 1].
#' @keywords internal
.cep_linkage_prob <- function(brand, cep) {
  base_rate <- 0.28
  brand_factor <- brand$strength
  specialty_boost <- 0
  if (!is.null(cep$specialty_match) && !is.null(brand$specialty) &&
      identical(cep$specialty_match, brand$specialty)) {
    specialty_boost <- 0.85  # Strong specialty boost
  }
  # Small penalty for value brands on aspirational CEPs
  if (identical(brand$quality_tier, "value") &&
      identical(cep$specialty_match, "exotic")) {
    specialty_boost <- specialty_boost - 0.15
  }
  p <- base_rate * brand_factor * (1 + specialty_boost)
  min(max(p, 0), 0.95)
}


# ==============================================================================
# ATTRIBUTE LINKAGE PROBABILITY
# ==============================================================================

#' Probability that a respondent links an attribute to a brand
#'
#' Attributes 01..05 are:
#'   01 = Value, 02 = Quality, 03 = Trust, 04 = Consistent taste, 05 = Easy to use
#'
#' Quality tier skews which attributes are strong:
#'   premium brands: strong on quality, trust; weaker on value
#'   mainstream:     balanced
#'   value:          strong on value, easy-to-use; weaker on quality
#'
#' @param brand List. Brand definition.
#' @param attr_code Character. Attribute code (ATTR01..ATTR05).
#' @return Scalar probability in [0, 1].
#' @keywords internal
.attr_linkage_prob <- function(brand, attr_code) {
  base_rate <- 0.32
  brand_factor <- brand$strength

  tier_boost <- switch(brand$quality_tier,
    "premium" = switch(attr_code,
      "ATTR01" = 0.80,  # value — weaker for premium
      "ATTR02" = 1.40,  # quality
      "ATTR03" = 1.25,  # trust
      "ATTR04" = 1.10,
      "ATTR05" = 0.90,
      1),
    "mainstream" = switch(attr_code,
      "ATTR01" = 1.05,
      "ATTR02" = 1.05,
      "ATTR03" = 1.15,
      "ATTR04" = 1.10,
      "ATTR05" = 1.10,
      1),
    "value" = switch(attr_code,
      "ATTR01" = 1.45,  # value — strong for value brands
      "ATTR02" = 0.65,  # quality — weaker
      "ATTR03" = 0.80,
      "ATTR04" = 0.90,
      "ATTR05" = 1.25,
      1),
    1)

  p <- base_rate * brand_factor * tier_boost
  min(max(p, 0), 0.90)
}


# ==============================================================================
# REJECTION REASON TEXT BANK
# ==============================================================================

#' Return a vector of plausible rejection reason phrases
#'
#' Used for BRANDATT2_{cat} open-ended text for respondents who gave
#' attitude = 4 ("I would refuse to buy this brand").
#' @keywords internal
.rejection_reasons <- function() {
  c(
    "Too expensive for what you get",
    "Doesn't taste as good as others",
    "Had a bad experience with this brand",
    "Quality is inconsistent",
    "Hard to find in my usual shops",
    "Packaging feels cheap",
    "Doesn't suit my cooking style",
    "I prefer smaller artisan brands",
    "Never liked the flavour profile",
    "Too generic / mass-market for my taste"
  )
}


# ==============================================================================
# DBA UNIQUE ATTRIBUTION CHOICES
# ==============================================================================

#' Weighted sample of brand codes used as DBA "uniqueness" attributions
#'
#' When a respondent says "yes, I've seen this before" (fame = 1), they are
#' asked which brand it belongs to (uniqueness). Correct attribution rate is
#' asset-specific; incorrect attributions are weighted toward brand awareness
#' (bigger brands get more misattributions).
#'
#' @param n Integer. Number of attributions to generate.
#' @param correct_code Character. The focal brand code (correct answer).
#' @param correct_rate Numeric in [0, 1]. Probability of correct attribution.
#' @return Character vector of brand codes.
#' @keywords internal
.sample_dba_attribution <- function(n, correct_code, correct_rate) {
  other_codes <- setdiff(ipk_brand_codes(), correct_code)
  # Weight incorrect attributions by brand awareness
  other_weights <- vapply(ipk_brands(), function(b) {
    if (identical(b$code, correct_code)) return(NA_real_)
    b$awareness_rate
  }, numeric(1))
  other_weights <- other_weights[!is.na(other_weights)]
  other_weights <- other_weights / sum(other_weights)

  correct_mask <- .rbern(n, correct_rate)
  result <- character(n)
  result[correct_mask == 1L] <- correct_code
  n_wrong <- sum(correct_mask == 0L)
  if (n_wrong > 0) {
    wrong_codes <- sample(other_codes, size = n_wrong, replace = TRUE,
                          prob = other_weights)
    result[correct_mask == 0L] <- wrong_codes
  }
  result
}
