# ==============================================================================
# WHAT IF - BOOTSTRAP REFITS AND THE SIGN CHECK
# ==============================================================================
#
# Refits resample respondents with replacement and keep each respondent's
# weight fixed (brief section 4: fine at a design effect near 1; re-weighting
# inside each resample is an after-version-1 item). Each refit starts from the
# main fit, as the prototype does.
#
# The sign check counts the share of refits in which a lever's coefficient
# points against its expected direction. The prototype greys a lever out above
# 10 percent (WHATIF_SIGN_UNCLEAR).
#
# ==============================================================================

#' Share of Refits Above Which a Lever Is Shown as Unclear
WHATIF_SIGN_UNCLEAR <- 0.10


#' Bootstrap Refits of the Ordinal Model
#'
#' @param X,y,w,n_cat Data
#' @param penalty Per-column penalty (the same as the main fit)
#' @param main The main fit (warm start)
#' @param n_boot Number of refits
#' @param seed Seed
#' @return List of fits (main fit not included)
#' @keywords internal
whatif_bootstrap <- function(X, y, w, n_cat, penalty, main, n_boot, seed) {
  n <- length(y)
  if (n_boot < 1) return(list())
  draws <- whatif_with_seed(seed, lapply(seq_len(n_boot), function(i) sample.int(n, n, replace = TRUE)))
  lapply(draws, function(i) {
    whatif_fit_ordinal(X[i, , drop = FALSE], y[i], w[i], n_cat, penalty, start = main$par)
  })
}


#' Sign Check Across Refits
#'
#' @param fits Bootstrap fits
#' @param levers Guarded levers (expected direction)
#' @param lever_col Named column index of each lever's moved term
#' @return Data frame: key, expected, wrong_share, unclear
#' @keywords internal
whatif_sign_check <- function(fits, levers, lever_col) {
  keys <- vapply(levers, `[[`, character(1), "key")
  expected <- vapply(levers, function(lv) as.numeric(lv$expected), numeric(1))
  wrong <- vapply(seq_along(keys), function(j) {
    if (!length(fits)) return(NA_real_)
    bj <- vapply(fits, function(f) f$b[[lever_col[[keys[j]]]]], numeric(1))
    mean(bj * expected[j] < 0)
  }, numeric(1))
  data.frame(key = keys, expected = expected, wrong_share = wrong,
             unclear = !is.na(wrong) & wrong > WHATIF_SIGN_UNCLEAR,
             stringsAsFactors = FALSE)
}
