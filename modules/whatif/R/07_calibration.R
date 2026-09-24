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
