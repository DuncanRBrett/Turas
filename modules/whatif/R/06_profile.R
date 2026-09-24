# ==============================================================================
# WHAT IF - PROFILE MODEL ("Build a student")
# ==============================================================================
#
# A second, additive ordinal model on who the respondent is (campus, course,
# year and so on), with a ridge penalty chosen by cross-validation from the
# prototype's grid. It gives the Economist-style line: a respondent described
# in a sentence of dropdowns, and the score the model expects from people like
# that.
#
# The engine never answers for an impossible profile (brief decision 10).
# Structure rules name pairs of structural levels that cannot go together
# (a Masters student on the Bachelor of Social Work); a profile that matches any
# rule is refused. Personal traits (age, gender) are never blocked: a
# combination nobody in the sample has is still answered.
#
# ==============================================================================

#' Fit the Profile Model
#'
#' @param spec Guarded spec with a profile
#' @param folds Fold list shared with the lever model
#' @param verbose Print progress
#' @return List with fits (main first), penalty, cv (table), cv_r2, levels,
#'   cols, spread (5th, 50th, 95th percentile of real respondents' predicted
#'   scores), keys, structural, rules
#' @keywords internal
whatif_fit_profile <- function(spec, folds, verbose = TRUE) {
  pr <- spec[["profile"]]
  pd <- whatif_profile_design(spec$context, pr$keys)
  if (is.null(pd$X) || ncol(pd$X) == 0) {
    whatif_refuse("DATA_PROFILE_NO_VARIATION", "Profile traits do not vary",
      "Every profile trait has a single level, so there is nothing to build a profile from.",
      "The profile line would show the same number for every choice.",
      "Add traits that vary, or switch the profile builder off.")
  }
  y <- spec$y
  w <- spec$weights
  pen <- whatif_choose_penalty(pd$X, y, w, spec$n_cat, rep(TRUE, ncol(pd$X)),
                               spec$penalty_grid_profile, 0, folds)
  main <- whatif_fit_ordinal(pd$X, y, w, spec$n_cat, pen$penalty)
  boot <- whatif_bootstrap(pd$X, y, w, spec$n_cat, pen$penalty, main, spec$n_boot, spec$seed + 1L)
  real <- whatif_score_vec(main, drop(pd$X %*% main$b), spec$outcome$score)
  spread <- stats::quantile(real, c(0.05, 0.5, 0.95), type = 7, names = FALSE)
  cv_r2 <- pen$table$cv_r2[pen$table$penalty == pen$penalty]
  whatif_say(sprintf("profile model: penalty %s chosen by cross-validation (held-out pseudo R2 %.4f); real profiles 5/50/95: %.1f / %.1f / %.1f",
                     format(pen$penalty), cv_r2, spread[1], spread[2], spread[3]), verbose = verbose)
  list(fits = c(list(main), boot), penalty = pen$penalty, cv = pen$table, cv_r2 = cv_r2,
       levels = pd$levels, cols = pd$cols, spread = spread,
       keys = pr$keys, structural = pr$structural, rules = pr$rules)
}


#' Check a Profile Against the Structure Rules
#'
#' @param pm Profile model from whatif_fit_profile()
#' @param profile Named character vector, one level per profile key
#' @return TRUE invisibly; refuses an incomplete, unknown or impossible profile
#' @keywords internal
whatif_profile_check <- function(pm, profile) {
  missing_keys <- setdiff(pm$keys, names(profile))
  extra_keys <- setdiff(names(profile), pm$keys)
  if (length(missing_keys) || length(extra_keys)) {
    whatif_refuse("CFG_PROFILE_KEYS", "Profile does not match the profile traits",
      sprintf("A profile needs exactly one level for each of: %s.", paste(pm$keys, collapse = ", ")),
      "A trait left out would silently take its reference level.",
      "Give every profile trait a level and nothing else.",
      details = sprintf("Missing: %s. Not profile traits: %s.",
                        paste(missing_keys, collapse = ", "), paste(extra_keys, collapse = ", ")))
  }
  for (k in pm$keys) {
    if (!profile[[k]] %in% pm$levels[[k]]) {
      whatif_refuse("CFG_PROFILE_LEVEL", "Profile level not in the data",
        sprintf("'%s' is not a level of %s.", profile[[k]], k),
        "The model has no estimate for a level it never saw.",
        sprintf("Choose one of: %s.", paste(pm$levels[[k]], collapse = ", ")))
    }
  }
  rules <- pm$rules
  hit <- which(profile[rules$key1] == rules$level1 & profile[rules$key2] == rules$level2)
  if (length(hit)) {
    r <- rules[hit[1], ]
    whatif_refuse("CFG_PROFILE_IMPOSSIBLE", "Impossible profile",
      sprintf("%s = '%s' cannot go with %s = '%s' under the study's Structure rules.",
              r$key1, r$level1, r$key2, r$level2),
      "An estimate for a respondent who cannot exist would be read as a finding about real people.",
      sprintf("Change %s or %s to a combination the Structure rules allow.", r$key1, r$key2))
  }
  invisible(TRUE)
}


#' Predicted Score for One Profile
#'
#' @param model A model from whatif_run_engine() with a profile
#' @param profile Named character vector, one level per profile key
#' @return Named numeric: est, lo, hi (90 percent range across refits), or a
#'   structured refusal (printed to the console) for an impossible profile
#' @export
whatif_profile_predict <- function(model, profile) {
  with_refusal_handler(whatif_profile_predict_impl(model, profile), module = "WHATIF")
}


#' @keywords internal
whatif_profile_predict_impl <- function(model, profile) {
  pm <- model$profile
  if (is.null(pm)) {
    whatif_refuse("CFG_PROFILE_OFF", "Profile builder is off",
      "This study was run without a profile model.",
      "There is no model to answer a profile question.",
      "Set profile keys in the spec to switch the builder on.")
  }
  profile <- unlist(profile)
  whatif_profile_check(pm, profile)
  x <- as.numeric(profile[pm$cols$key] == pm$cols$level)
  d <- vapply(pm$fits, function(f) {
    whatif_score_vec(f, sum(x * f$b), model$spec$outcome$score)
  }, numeric(1))
  whatif_summarise_draws(d)
}
