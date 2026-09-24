# ==============================================================================
# WHAT IF - CALIBRATION
# ==============================================================================
#
# Does the model get each group's level right on respondents it never saw?
# Every respondent's score is predicted by a fit that left out their fold; each
# context group of at least min_n respondents is then compared with its actual
# score, allowing for the actual's own sampling error. Ported from section 4 of
# prototypes/nps-simulator/robustness.py.
#
# With ratings alone, 6 of 36 SACAP groups missed (weighted run, 23 Sep 2026);
# context baselines are the fix (brief section 4).
#
# ==============================================================================

#' Held-Out Calibration by Group
#'
#' @param model A model from whatif_run_engine()
#' @param min_n Smallest group to test (default 30, the prototype's)
#' @return List with
#'   \item{table}{data frame: variable, level, n, actual, predicted, se, z, outside}
#'   \item{cv_r2}{held-out pseudo R-squared of the model}
#'   \item{n_outside}{groups whose |z| exceeds 1.96}
#'   \item{n_groups}{groups tested}
#'   \item{median_abs_error}{median |predicted - actual| in score points}
#' @export
whatif_calibration <- function(model, min_n = 30) {
  spec <- model$spec
  y <- spec$y
  w <- spec$weights
  score <- spec$outcome$score
  P <- whatif_cv_probs(model$design$X, y, w, spec$n_cat, model$penalty, model$folds)
  pred_i <- drop(P %*% score)
  rows <- list()
  for (k in names(spec$context)) {
    v <- spec$context[[k]]$values
    for (lev in whatif_levels_by_frequency(v)) {
      m <- v == lev
      if (sum(m) < min_n) next
      ww <- w[m]
      shares <- whatif_category_shares(y[m], ww, spec$n_cat)
      actual <- sum(shares * score)
      var_i <- max(sum(shares * score^2) - actual^2, 1e-9)
      neff <- sum(ww)^2 / sum(ww^2)
      se <- sqrt(var_i / neff)
      predicted <- stats::weighted.mean(pred_i[m], ww)
      rows[[length(rows) + 1]] <- data.frame(
        variable = spec$context[[k]]$label, level = lev, n = sum(m),
        actual = actual, predicted = predicted, se = se,
        z = (predicted - actual) / se, stringsAsFactors = FALSE)
    }
  }
  tab <- if (length(rows)) do.call(rbind, rows) else
    data.frame(variable = character(0), level = character(0), n = integer(0), actual = numeric(0),
               predicted = numeric(0), se = numeric(0), z = numeric(0))
  tab$outside <- abs(tab$z) > stats::qnorm(0.975)
  list(table = tab,
       cv_r2 = whatif_pseudo_r2(P, y, w),
       n_outside = sum(tab$outside),
       n_groups = nrow(tab),
       median_abs_error = if (nrow(tab)) stats::median(abs(tab$predicted - tab$actual)) else NA_real_)
}


#' Effect of Each Symptom, Fitted Only to Explain Why It Is Not a Lever
#'
#' A symptom (called the company, shops around) moves with the outcome because
#' it is a sign of the outcome, not a cause the client can pull. Its apparent
#' effect is shown so the reader sees it was considered: the lever model plus
#' the flag, and the average change in score between everyone flagged and
#' nobody flagged. Ported from the prototype's symptom block.
#'
#' @param model A model from whatif_run_engine()
#' @param symptoms List of list(key, label, flag, why)
#' @return Data frame label, n, effect, why (empty when there are none)
#' @keywords internal
whatif_symptom_effects <- function(model, symptoms) {
  if (!length(symptoms)) {
    return(data.frame(label = character(0), n = integer(0), effect = numeric(0), why = character(0)))
  }
  spec <- model$spec
  rows <- lapply(symptoms, function(sm) {
    Xs <- cbind(model$design$X, sm$flag)
    fs <- whatif_fit_ordinal(Xs, spec$y, spec$weights, spec$n_cat, c(model$penalty, spec$penalty_levers))
    X1 <- Xs; X1[, ncol(Xs)] <- 1
    X0 <- Xs; X0[, ncol(Xs)] <- 0
    eff <- stats::weighted.mean(whatif_score_vec(fs, drop(X1 %*% fs$b), spec$outcome$score) -
                                  whatif_score_vec(fs, drop(X0 %*% fs$b), spec$outcome$score), spec$weights)
    data.frame(label = sm$label, n = as.integer(sum(sm$flag)), effect = eff, why = sm$why %||% "",
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}


#' Partial Effect Below This Share of the Single-Lever Effect Flags a Halo
#'
#' Every move holds the other levers fixed, which is right for "what is unique
#' to this area" and a floor for "what happens if this area is fixed", because
#' ratings move together. An area whose effect fitted on its own is large but
#' whose partial effect is small is caught in that shared variance (a halo,
#' or real spillover; the data cannot separate the two). Chosen from the
#' SACAP 2025 probe of 24 Sep 2026 (docs/v2_lift/BLINDSPOT_WHATIF_RESULTS_2026_09_24.md):
#' assessment feedback and email responsiveness sat near a tenth of their
#' single-lever effect, the areas the tab was right about near a half. An
#' area whose single-lever effect is under one point is never flagged: there
#' is nothing to collapse.
WHATIF_HALO_RATIO <- 1 / 3


#' Levers Larger Than This Skip the Relative-Importance Decomposition
#'
#' The LMG shares need a fit for every subset of levers (2 to the power p).
WHATIF_LMG_MAX_LEVERS <- 12L


#' Halo Check: Each Lever's Fix Effect Alone Against Its Partial Effect
#'
#' For every lever, the fix move (floor for a rating or nested lever, extend
#' for coverage) is evaluated for the whole sample twice: from a model with
#' that lever alone (no other levers, no baselines) and from the main fit,
#' where the other levers are held where they are. The ratio partial over
#' single, and the flag when it falls under WHATIF_HALO_RATIO.
#'
#' @param spec Guarded spec
#' @param design Design from whatif_build_design()
#' @param main Main fit
#' @param deltas Per-lever move deltas (from whatif_run_engine())
#' @return Data frame: key, single, partial, ratio, halo
#' @keywords internal
whatif_halo_check <- function(spec, design, main, deltas) {
  y <- spec$y
  w <- spec$weights
  score <- spec$outcome$score
  X <- design$X
  eta_main <- drop(X %*% main$b)
  base_main <- stats::weighted.mean(whatif_score_vec(main, eta_main, score), w)
  rows <- lapply(spec$levers, function(lv) {
    key <- lv$key
    mv <- if (lv$kind == "coverage") "extend" else "floor"
    dx <- deltas[[key]][[mv]]
    col <- design$lever_col[[key]]
    partial <- stats::weighted.mean(whatif_score_vec(main, eta_main + main$b[[col]] * dx, score), w) - base_main
    own <- which(design$cols$lever == key & !design$cols$is_context)
    Xj <- X[, own, drop = FALSE]
    fj <- whatif_fit_ordinal(Xj, y, w, spec$n_cat, spec$penalty_levers)
    eta_j <- drop(Xj %*% fj$b)
    bj <- fj$b[[match(col, own)]]
    single <- stats::weighted.mean(whatif_score_vec(fj, eta_j + bj * dx, score), w) -
      stats::weighted.mean(whatif_score_vec(fj, eta_j, score), w)
    ratio <- if (abs(single) > 1e-9) partial / single else NA_real_
    data.frame(key = key, single = single, partial = partial, ratio = ratio,
               halo = !is.na(ratio) && abs(single) >= 1 && ratio < WHATIF_HALO_RATIO,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}


#' Relative Importance of the Levers (LMG, the Shapley Decomposition of R2)
#'
#' A conventional key driver analysis on the same levers, for the stats pack:
#' a weighted linear regression of the respondent's outcome score on the lever
#' columns, with the explained variance shared out over every order the levers
#' could enter (Lindeman, Merenda and Gold). Correlated levers share credit
#' here, where the effort table gives each its partial effect; the two rankings
#' are shown side by side so a reader can reconcile them. Returns NULL with
#' more than WHATIF_LMG_MAX_LEVERS levers.
#'
#' @param spec Guarded spec
#' @param design Design from whatif_build_design()
#' @return Data frame key, lmg_share (percent of the linear R2), marginal_r
#'   (weighted correlation of the lever's moved column with the score), and
#'   attribute r2 (the full linear R2); or NULL
#' @keywords internal
whatif_lmg <- function(spec, design) {
  keys <- vapply(spec$levers, `[[`, character(1), "key")
  p <- length(keys)
  if (p > WHATIF_LMG_MAX_LEVERS) return(NULL)
  w <- spec$weights
  ys <- spec$outcome$score[spec$y]
  X <- design$X
  own <- lapply(keys, function(k) which(design$cols$lever == k & !design$cols$is_context))
  wm <- stats::weighted.mean(ys, w)
  tss <- sum(w * (ys - wm)^2)
  r2_of <- function(members) {
    if (!length(members)) return(0)
    cols <- unlist(own[members])
    fit <- stats::lm.wfit(cbind(1, X[, cols, drop = FALSE]), ys, w)
    1 - sum(w * fit$residuals^2) / tss
  }
  r2 <- numeric(2^p)
  for (b in seq_len(2^p) - 1L) {
    members <- which(bitwAnd(b, bitwShiftL(1L, seq_len(p) - 1L)) > 0)
    r2[b + 1L] <- r2_of(members)
  }
  code <- function(members) sum(bitwShiftL(1L, members - 1L)) + 1L
  lmg <- vapply(seq_len(p), function(j) {
    total <- 0
    for (b in seq_len(2^p) - 1L) {
      members <- which(bitwAnd(b, bitwShiftL(1L, seq_len(p) - 1L)) > 0)
      if (j %in% members) next
      k <- length(members)
      wgt <- factorial(k) * factorial(p - k - 1) / factorial(p)
      total <- total + wgt * (r2[code(c(members, j))] - r2[b + 1L])
    }
    total
  }, numeric(1))
  marginal <- vapply(seq_len(p), function(j) {
    xj <- X[, design$lever_col[[keys[j]]]]
    cv <- stats::cov.wt(cbind(xj, ys), wt = w / sum(w), cor = TRUE)$cor
    cv[1, 2]
  }, numeric(1))
  full <- r2[2^p]
  out <- data.frame(key = keys,
                    lmg_share = if (full > 0) 100 * lmg / full else NA_real_,
                    marginal_r = marginal, stringsAsFactors = FALSE)
  attr(out, "r2") <- full
  out
}
