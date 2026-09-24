# ==============================================================================
# WHAT IF - ENGINE ENTRY POINT
# ==============================================================================
#
# whatif_run_engine(spec) fits everything the What if tab needs from one study
# spec (see 00_guard.R for its fields):
#
#   1. the lever model: ordinal outcome on the levers, plus context baselines
#      with a ridge penalty chosen by cross-validation (penalty on the context
#      terms only);
#   2. bootstrap refits and the sign check;
#   3. the change each move makes to each lever's model column;
#   4. the halo check (each lever's fix effect alone against its partial
#      effect) and the LMG relative importance, both in 07_calibration.R;
#   5. the profile model for "Build a ...", when the spec has a profile.
#
# Group results (whatif_group_results), profile answers
# (whatif_profile_predict) and the calibration table (whatif_calibration) are
# computed from the returned model.
#
# Ported from prototypes/nps-simulator/whatif_engine.py (session 1 of
# docs/v2_lift/BRIEF_WHATIF_SIMULATOR.md).
#
# ==============================================================================

#' Fit the What if Model for One Study
#'
#' @param spec Study spec (see 00_guard.R)
#' @param verbose Print progress to the console
#' @return A \code{whatif_model} list with status "PASS" or "PARTIAL"
#'   (warnings listed), or a structured TRS refusal, printed to the console:
#'   \item{status}{"PASS" or "PARTIAL"}
#'   \item{warnings}{character vector}
#'   \item{spec}{the guarded spec}
#'   \item{design}{design matrix and column map}
#'   \item{penalty}{per-column penalty used}
#'   \item{baseline_penalty, baseline_cv}{chosen baseline penalty and its CV table}
#'   \item{main, boot}{main fit and bootstrap refits}
#'   \item{sign}{sign check table}
#'   \item{cv_r2}{held-out pseudo R-squared of the lever model}
#'   \item{deltas}{per lever, per move: change in the lever's column}
#'   \item{halo}{halo check table: key, single, partial, ratio, halo}
#'   \item{lmg}{LMG relative importance table, or NULL with many levers}
#'   \item{profile}{profile model, or NULL}
#' @examples
#' \dontrun{
#'   model <- whatif_run_engine(spec)
#'   if (!is_refusal(model)) {
#'     res <- whatif_group_results(model, list(all = rep(TRUE, length(spec$y))))
#'   }
#' }
#' @export
whatif_run_engine <- function(spec, verbose = TRUE) {
  with_refusal_handler(whatif_run_engine_impl(spec, verbose), module = "WHATIF")
}


#' @keywords internal
whatif_run_engine_impl <- function(spec, verbose = TRUE) {
  spec <- whatif_guard_spec(spec)
  sid <- spec$id %||% "study"
  y <- spec$y
  w <- spec$weights
  n <- length(y)
  warnings <- character(0)

  design <- whatif_build_design(spec$levers, spec$scale %||% list(centre = 0),
                                spec$context, spec$baselines)
  X <- design$X
  folds <- whatif_cv_folds(n, spec$folds, spec$cv_seed)
  is_ctx <- design$cols$is_context

  baseline_penalty <- NA_real_
  baseline_cv <- NULL
  if (any(is_ctx)) {
    ch <- whatif_choose_penalty(X, y, w, spec$n_cat, is_ctx, spec$penalty_grid_baselines,
                                spec$penalty_levers, folds)
    baseline_penalty <- ch$penalty
    baseline_cv <- ch$table
    whatif_say(sprintf("[%s] context baselines (%s): penalty %s chosen by cross-validation",
                       sid, paste(spec$baselines, collapse = ", "), format(baseline_penalty)),
               verbose = verbose)
    if (baseline_penalty == max(spec$penalty_grid_baselines) || baseline_penalty == min(spec$penalty_grid_baselines)) {
      warnings <- c(warnings, sprintf(
        "The chosen baseline penalty (%s) is at the edge of the grid; a wider grid may fit better.",
        format(baseline_penalty)))
    }
  }
  penalty <- ifelse(is_ctx, baseline_penalty, spec$penalty_levers)

  main <- whatif_fit_ordinal(X, y, w, spec$n_cat, penalty)
  if (!main$converged) {
    whatif_refuse("MODEL_NOT_CONVERGED", "Lever model did not converge",
      sprintf("The ordinal model for '%s' did not converge.", sid),
      "Coefficients from an unconverged fit are not estimates of anything.",
      c("Check for a lever that perfectly separates the outcome categories.",
        "Drop levers with almost no variation, or merge thin outcome categories."))
  }
  boot <- whatif_bootstrap(X, y, w, spec$n_cat, penalty, main, spec$n_boot, spec$seed)
  n_bad <- sum(!vapply(boot, `[[`, logical(1), "converged"))
  if (n_bad) warnings <- c(warnings, sprintf("%d of %d bootstrap refits did not converge.", n_bad, length(boot)))

  sign <- whatif_sign_check(boot, spec$levers, design$lever_col)
  cv_r2 <- whatif_pseudo_r2(whatif_cv_probs(X, y, w, spec$n_cat, penalty, folds), y, w)
  whatif_say(sprintf("[%s] lever model: n %d, held-out pseudo R2 %.3f; refits against the expected sign: %s",
                     sid, n, cv_r2,
                     paste(sprintf("%s %.2f", sign$key, sign$wrong_share), collapse = ", ")),
             verbose = verbose)
  if (any(sign$unclear)) {
    warnings <- c(warnings, sprintf("Sign check: %s point the wrong way in more than %d%% of refits.",
                                    paste(sign$key[sign$unclear], collapse = ", "),
                                    round(100 * WHATIF_SIGN_UNCLEAR)))
  }

  deltas <- lapply(spec$levers, function(lv) {
    stats::setNames(lapply(WHATIF_MOVES, function(mv) whatif_move_delta(lv, mv, spec$scale)), WHATIF_MOVES)
  })
  names(deltas) <- vapply(spec$levers, `[[`, character(1), "key")

  halo <- whatif_halo_check(spec, design, main, deltas)
  if (any(halo$halo)) {
    whatif_say(sprintf("[%s] halo check: %s fixed alone would be worth far more than with the other areas held; shown as caught in the halo",
                       sid, paste(halo$key[halo$halo], collapse = ", ")), verbose = verbose)
  }
  lmg <- whatif_lmg(spec, design)

  profile <- if (!is.null(spec[["profile"]]) && length(spec[["profile"]]$keys)) {
    whatif_fit_profile(spec, folds, verbose)
  } else NULL

  structure(list(
    status = if (length(warnings)) "PARTIAL" else "PASS",
    warnings = warnings,
    spec = spec, design = design, penalty = penalty, folds = folds,
    baseline_penalty = baseline_penalty, baseline_cv = baseline_cv,
    main = main, boot = boot, sign = sign, cv_r2 = cv_r2,
    deltas = deltas, halo = halo, lmg = lmg, profile = profile
  ), class = "whatif_model")
}
