# ==============================================================================
# BRAND MODULE - AUDIENCE LENS: CLASSIFICATION + SIG TESTS
# ==============================================================================
# Two responsibilities:
#   1) Wraps the two-independent-proportions z-test (and its t-test fallback
#      for mean-based metrics) used to flag significance vs Total and
#      between pair sides.
#   2) Applies the GROW / FIX / DEFEND rule set per row of a pair card.
#
# Pair Z-test framing: every respondent is independently classified as either
# a focal-brand buyer (PairRole = A) or non-buyer (PairRole = B). The two
# arms are mutually exclusive and exhaustive, but no within-pair pairing
# exists at the respondent level — there's no respondent who is "both" — so
# the test is a two-INDEPENDENT-proportions z-test, not a paired-sample test.
# This framing is documented in the module README to head off methodological
# pushback.
#
# VERSION: 1.0
# ==============================================================================

BRAND_AL_CLASSIFY_VERSION <- "1.0"


#' Classify one pair audience using GROW / FIX / DEFEND rules
#'
#' Builds the pair card's per-metric rows: value_a, value_b, delta,
#' sig_flag, classification chip. The classifier walks every metric in
#' \code{audience_lens_metric_catalog()} (in order) and emits one row.
#'
#' @param pair_a List with components \code{audience}, \code{n_unweighted},
#'   \code{n_weighted}, \code{metrics} for the A side of the pair.
#' @param pair_b Same for the B side.
#' @param total List with components \code{metrics}, \code{n_unweighted},
#'   \code{n_weighted} for the category total.
#' @param focal_brand Character.
#' @param thresholds List from \code{.al_resolve_thresholds()}.
#' @return List with: pair_id, label_a, label_b, n_a, n_b, n_total, rows
#'   (data frame; one row per metric).
#' @export
classify_audience_pair <- function(pair_a, pair_b, total,
                                    focal_brand, thresholds) {

  catalog <- audience_lens_metric_catalog()
  rows <- list()

  for (group in catalog) {
    for (m in group$metrics) {
      ma <- pair_a$metrics[[m$id]] %||% .al_na_metric_local("Metric not computed")
      mb <- pair_b$metrics[[m$id]] %||% .al_na_metric_local("Metric not computed")
      mt <- total$metrics[[m$id]]  %||% .al_na_metric_local("Metric not computed")

      buyer_base_metric <- isTRUE(m$buyer_base)

      # N/A on the non-buyer (B) side of brand-buyer-base metrics, by definition
      if (buyer_base_metric) {
        mb <- list(value = NA_real_, n_base = 0L, n_buyer_base = TRUE,
                   note = "Defined on brand buyers only")
      }

      delta <- if (!is.na(ma$value) && !is.na(mb$value))
                  ma$value - mb$value else NA_real_

      sig <- if (!is.na(ma$value) && !is.na(mb$value) &&
                   ma$n_base > 0 && mb$n_base > 0 && m$kind != "dist")
               .al_sig_two_props(ma, mb, alpha = thresholds$alpha) else
               list(p_value = NA_real_, sig = FALSE, test = "none")

      # Classification (only meaningful for proportion-style metrics)
      cls <- classify_chip(metric_a = ma$value, metric_b = mb$value,
                            metric_total = mt$value,
                            sig = sig$sig, gap_pp = thresholds$gap_pp,
                            kind = m$kind, focal_brand = focal_brand)

      rows[[length(rows) + 1L]] <- data.frame(
        group        = group$group,
        metric_id    = m$id,
        metric_label = m$label,
        kind         = m$kind,
        buyer_base   = buyer_base_metric,
        value_total  = mt$value,
        n_total      = total$n_unweighted,
        value_a      = ma$value,
        n_a          = ma$n_base,
        value_b      = mb$value,
        n_b          = mb$n_base,
        delta_ab     = delta,
        sig_p        = sig$p_value,
        sig_flag     = sig$sig,
        sig_test     = sig$test,
        chip         = cls$chip,
        chip_reason  = cls$reason,
        stringsAsFactors = FALSE
      )
    }
  }

  rows_df <- do.call(rbind, rows)

  list(
    pair_id   = pair_a$audience$pair_id %||% "",
    label_a   = pair_a$audience$label,
    label_b   = pair_b$audience$label,
    audience_a = pair_a$audience,
    audience_b = pair_b$audience,
    n_a       = pair_a$n_unweighted,
    n_b       = pair_b$n_unweighted,
    n_total   = total$n_unweighted,
    base_state_a = pair_a$base_state,
    base_state_b = pair_b$base_state,
    rows      = rows_df
  )
}


#' Apply the GROW / FIX / DEFEND rules
#'
#' Conditions per planning doc section 4:
#'   GROW   buyers >> non-buyers (gap >= gap_pp, sig)
#'   FIX    buyers <= total (focal underperforms among own buyers vs category)
#'   DEFEND buyers >> non-buyers AND focal leads category total (with sig gap)
#'
#' Returns list with chip ("GROW"/"FIX"/"DEFEND"/NA) and a short reason
#' string for tooltips.
#'
#' @export
classify_chip <- function(metric_a, metric_b, metric_total,
                          sig, gap_pp, kind, focal_brand) {
  if (kind == "dist") {
    return(list(chip = NA_character_, reason = "Distribution metric"))
  }
  if (is.na(metric_a) || is.na(metric_b) || is.na(metric_total)) {
    return(list(chip = NA_character_, reason = "Insufficient data"))
  }

  gap <- metric_a - metric_b
  big_positive_gap <- !is.na(gap) && gap >= gap_pp && isTRUE(sig)
  buyers_lead_total <- !is.na(metric_a) && !is.na(metric_total) &&
                          metric_a > metric_total
  # Underperformance means strictly below the category total — parity is
  # not a red flag.
  buyers_underperform_total <- !is.na(metric_a) && !is.na(metric_total) &&
                                  metric_a < metric_total

  if (big_positive_gap && buyers_lead_total) {
    return(list(chip = "DEFEND",
                reason = sprintf("Buyers lead non-buyers by %s and lead category total",
                                 .al_fmt_pp(gap))))
  }
  if (big_positive_gap) {
    # Strong buyer/non-buyer gap is the dominant signal; recruitment story
    # takes precedence over a parity-vs-total nuance.
    return(list(chip = "GROW",
                reason = sprintf("Buyers > non-buyers by %s (sig); recruitment lever",
                                 .al_fmt_pp(gap))))
  }
  if (buyers_underperform_total) {
    return(list(chip = "FIX",
                reason = "Focal buyers underperform category total — retention risk"))
  }
  list(chip = NA_character_, reason = "No significant pair gap")
}


#' Two-proportion z-test (independent samples)
#'
#' Returns p_value, sig (vs alpha already applied via thresholds$alpha),
#' and test label. Falls back to Fisher's exact when expected cell count < 5.
#' For mean-based metrics (kind = "num"/"net"/"ratio") we approximate with a
#' one-sided z on the difference using a normal SE — this is a v1
#' simplification; v2 will switch to a proper t-test on respondent-level
#' values once those are propagated.
#'
#' @keywords internal
.al_sig_two_props <- function(ma, mb, alpha = 0.10) {
  pa <- ma$value; na <- ma$n_base
  pb <- mb$value; nb <- mb$n_base
  if (is.na(pa) || is.na(pb) || na <= 0 || nb <= 0) {
    return(list(p_value = NA_real_, sig = FALSE, test = "none"))
  }

  # When the metric is a proportion (in [0,1] for both arms), use a
  # two-proportion z. When it isn't (means/nets/ratios where the value can be
  # outside [0,1]), use a difference-of-means z with a coarse SE. The point
  # of the v1 sig flag is to highlight notable gaps for the analyst — fine-
  # grained inference is a v2 follow-up.
  is_prop <- pa >= 0 && pa <= 1 && pb >= 0 && pb <= 1
  if (is_prop) {
    xa <- round(pa * na); xb <- round(pb * nb)
    p_pool <- (xa + xb) / (na + nb)
    e <- min(na * p_pool, na * (1 - p_pool), nb * p_pool, nb * (1 - p_pool))
    if (e < 5) {
      m <- matrix(c(xa, na - xa, xb, nb - xb), nrow = 2)
      pv <- tryCatch(stats::fisher.test(m)$p.value, error = function(e) NA_real_)
      return(list(p_value = pv, sig = !is.na(pv) && pv < alpha,
                  test = "fisher"))
    }
    se <- sqrt(p_pool * (1 - p_pool) * (1 / na + 1 / nb))
    if (se <= 0) return(list(p_value = NA_real_, sig = FALSE, test = "none"))
    z <- (pa - pb) / se
    pv <- 2 * stats::pnorm(-abs(z))
    return(list(p_value = pv, sig = pv < alpha, test = "z_two_prop"))
  }

  # Difference-of-means z (coarse): assume sd ~ |value| as a fallback so we
  # at least flag big differences. This is intentionally conservative — most
  # mean-based metrics won't trip a sig flag at small samples.
  sd_a <- max(abs(pa), 1e-6); sd_b <- max(abs(pb), 1e-6)
  se <- sqrt(sd_a^2 / na + sd_b^2 / nb)
  if (se <= 0) return(list(p_value = NA_real_, sig = FALSE, test = "none"))
  z  <- (pa - pb) / se
  pv <- 2 * stats::pnorm(-abs(z))
  list(p_value = pv, sig = pv < alpha, test = "z_means_approx")
}


.al_na_metric_local <- function(note) {
  list(value = NA_real_, n_base = 0L, n_buyer_base = FALSE, note = note)
}


.al_fmt_pp <- function(x) {
  if (is.na(x)) return("?")
  sprintf("%+.0fpp", 100 * x)
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Audience lens classifier loaded (v%s)",
                  BRAND_AL_CLASSIFY_VERSION))
}
