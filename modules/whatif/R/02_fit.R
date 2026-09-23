# ==============================================================================
# WHAT IF - PENALISED ORDINAL FIT
# ==============================================================================
#
# Cumulative logit (proportional odds), the same model as ordinal::clm with a
# logit link:
#
#   P(Y <= j) = plogis(theta_j - eta),   eta = X %*% b
#
# fitted by weighted maximum likelihood with a ridge penalty that can differ
# per column:
#
#   minimise  -sum(w * log p_y) + sum(penalty * b^2)
#
# Thresholds are free parameters t with theta_1 = t_1 and
# theta_j = theta_(j-1) + exp(t_j), so they always stay in order. Two outcome
# categories give ordinary binary logistic regression through the same code.
#
# The analytic gradient is passed to optim(BFGS); with it the fit reproduces
# ordinal::clm to 1e-4 at zero penalty (tests/testthat/test_fit.R).
#
# ==============================================================================

#' Default Penalty on Lever Coefficients
#'
#' A tiny ridge that only keeps the optimiser away from separation; it is the
#' prototype's MAIN_PENALTY, kept so the SACAP numbers reproduce exactly.
WHATIF_LEVER_PENALTY <- 1e-4

#' Penalty Grid for Context Baselines, Chosen by Cross-Validation
WHATIF_BASELINE_PENALTIES <- c(1, 2, 5, 10, 20, 50, 100)

#' Penalty Grid for the Profile Model (the prototype's grid)
WHATIF_PROFILE_PENALTIES <- c(1, 5, 20, 50)


#' Cumulative Probabilities for Each Respondent
#'
#' @param theta Ordered thresholds (length n_cat - 1)
#' @param eta Linear predictor
#' @return List with F (n x (n_cat + 1) cumulative matrix, first column 0 and
#'   last 1) and f (matching logistic densities, 0 in the end columns)
#' @keywords internal
whatif_cumulative <- function(theta, eta) {
  n <- length(eta)
  z <- outer(-eta, theta, `+`)
  Fm <- cbind(0, stats::plogis(z), 1)
  fm <- cbind(0, stats::dlogis(z), 0)
  if (n == 1) {
    Fm <- matrix(Fm, nrow = 1)
    fm <- matrix(fm, nrow = 1)
  }
  list(F = Fm, f = fm)
}


#' Thresholds from Free Parameters
#' @keywords internal
whatif_theta_from_t <- function(t) {
  cumsum(c(t[1], exp(t[-1])))
}


#' Penalised Negative Log-Likelihood and Its Gradient
#'
#' @param par c(b, t)
#' @param X Design matrix
#' @param y Outcome codes 1..n_cat
#' @param w Weights
#' @param penalty Per-column ridge penalty (length ncol(X))
#' @param n_cat Number of outcome categories
#' @return List with value and gradient
#' @keywords internal
whatif_nll <- function(par, X, y, w, penalty, n_cat) {
  k <- ncol(X)
  b <- par[seq_len(k)]
  t <- par[k + seq_len(n_cat - 1)]
  theta <- whatif_theta_from_t(t)
  eta <- if (k) drop(X %*% b) else rep(0, length(y))
  cm <- whatif_cumulative(theta, eta)
  idx <- seq_along(y)
  f_hi <- cm$f[cbind(idx, y + 1)]
  f_lo <- cm$f[cbind(idx, y)]
  p <- cm$F[cbind(idx, y + 1)] - cm$F[cbind(idx, y)]
  p <- pmax(p, 1e-12)
  value <- -sum(w * log(p)) + sum(penalty * b^2)

  a <- w / p
  g_b <- if (k) drop(crossprod(X, a * (f_hi - f_lo))) + 2 * penalty * b else numeric(0)
  g_theta <- vapply(seq_len(n_cat - 1), function(j) {
    fj <- cm$f[, j + 1]
    -sum(a[y == j] * fj[y == j]) + sum(a[y == j + 1] * fj[y == j + 1])
  }, numeric(1))
  jac <- c(1, exp(t[-1]))
  g_t <- rev(cumsum(rev(g_theta))) * jac
  list(value = value, gradient = c(g_b, g_t))
}


#' Fit the Penalised Ordinal Model
#'
#' @param X Design matrix (may have zero columns)
#' @param y Outcome codes 1..n_cat
#' @param w Weights (default all 1)
#' @param n_cat Number of outcome categories (default max(y))
#' @param penalty Ridge penalty, one value or one per column
#' @param start Optional starting parameters c(b, t), for warm starts
#' @return List with b (named), theta, t, par, value, converged
#' @keywords internal
whatif_fit_ordinal <- function(X, y, w = rep(1, length(y)), n_cat = max(y),
                               penalty = 0, start = NULL) {
  k <- ncol(X)
  penalty <- if (length(penalty) == 1) rep(penalty, k) else penalty
  if (is.null(start)) {
    shares <- whatif_category_shares(y, w, n_cat)
    cum <- pmin(pmax(cumsum(shares)[-n_cat], 1e-6), 1 - 1e-6)
    theta0 <- stats::qlogis(cum)
    t0 <- c(theta0[1], log(pmax(diff(theta0), 1e-6)))
    start <- c(rep(0, k), t0)
  }
  cache <- new.env()
  eval_at <- function(par) {
    if (!identical(cache$par, par)) {
      cache$par <- par
      cache$res <- whatif_nll(par, X, y, w, penalty, n_cat)
    }
    cache$res
  }
  opt <- stats::optim(
    start,
    fn = function(par) eval_at(par)$value,
    gr = function(par) eval_at(par)$gradient,
    method = "BFGS",
    control = list(maxit = 5000, reltol = 1e-14)
  )
  b <- opt$par[seq_len(k)]
  names(b) <- colnames(X)
  t <- opt$par[k + seq_len(n_cat - 1)]
  list(b = b, theta = whatif_theta_from_t(t), t = t, par = opt$par,
       value = opt$value, converged = opt$convergence == 0, n_cat = n_cat)
}


#' Category Probabilities
#'
#' @param fit A fit from whatif_fit_ordinal()
#' @param eta Linear predictor
#' @return Matrix, one row per respondent, one column per category
#' @keywords internal
whatif_probs <- function(fit, eta) {
  cm <- whatif_cumulative(fit$theta, eta)
  n_cat <- length(fit$theta) + 1
  cm$F[, 2:(n_cat + 1), drop = FALSE] - cm$F[, 1:n_cat, drop = FALSE]
}


#' Expected Score per Respondent
#'
#' For NPS the score is c(-100, 0, 100), so this is 100 * (P(promoter) -
#' P(detractor)); averaged over a group it is the group's predicted NPS.
#'
#' @param fit A fit
#' @param eta Linear predictor
#' @param score Score per category
#' @return Numeric vector
#' @keywords internal
whatif_score_vec <- function(fit, eta, score) {
  drop(whatif_probs(fit, eta) %*% score)
}


#' Cross-Validation Fold Test Sets
#'
#' A seeded permutation cut into interleaved folds, the prototype's layout.
#'
#' @param n Respondents
#' @param folds Number of folds
#' @param seed Seed
#' @return List of integer index vectors, one per fold
#' @keywords internal
whatif_cv_folds <- function(n, folds = 5L, seed = 7L) {
  ord <- whatif_with_seed(seed, sample.int(n))
  lapply(seq_len(folds), function(q) ord[seq(q, n, by = folds)])
}


#' Held-Out Category Probabilities
#'
#' @param X,y,w,n_cat Data
#' @param penalty Per-column penalty
#' @param folds List of test index vectors from whatif_cv_folds()
#' @return Matrix of out-of-fold probabilities
#' @keywords internal
whatif_cv_probs <- function(X, y, w, n_cat, penalty, folds) {
  P <- matrix(NA_real_, length(y), n_cat)
  for (te in folds) {
    tr <- setdiff(seq_along(y), te)
    fit <- whatif_fit_ordinal(X[tr, , drop = FALSE], y[tr], w[tr], n_cat, penalty)
    eta <- if (ncol(X)) drop(X[te, , drop = FALSE] %*% fit$b) else rep(0, length(te))
    P[te, ] <- whatif_probs(fit, eta)
  }
  P
}


#' McFadden Pseudo R-Squared from Held-Out Probabilities
#'
#' 1 minus the weighted mean log-likelihood of the held-out probabilities over
#' that of the category shares, as the prototype computes it.
#'
#' @param P Probability matrix
#' @param y,w Outcome and weights
#' @return Numeric
#' @keywords internal
whatif_pseudo_r2 <- function(P, y, w) {
  n_cat <- ncol(P)
  base <- whatif_category_shares(y, w, n_cat)
  ll <- stats::weighted.mean(log(pmax(P[cbind(seq_along(y), y)], 1e-12)), w)
  ll0 <- stats::weighted.mean(log(base[y]), w)
  1 - ll / ll0
}


#' Choose a Ridge Penalty by Cross-Validation
#'
#' Fits each candidate on the same folds and keeps the one with the best
#' held-out pseudo R-squared. Only the columns flagged in \code{penalised}
#' take the candidate; the others keep \code{base_penalty}.
#'
#' @param X,y,w,n_cat Data
#' @param penalised Logical, one per column
#' @param grid Candidate penalties
#' @param base_penalty Penalty on the other columns
#' @param folds Fold list
#' @return List with penalty (chosen), table (data frame penalty, cv_r2)
#' @keywords internal
whatif_choose_penalty <- function(X, y, w, n_cat, penalised, grid, base_penalty, folds) {
  r2 <- vapply(grid, function(pen) {
    pv <- ifelse(penalised, pen, base_penalty)
    whatif_pseudo_r2(whatif_cv_probs(X, y, w, n_cat, pv, folds), y, w)
  }, numeric(1))
  list(penalty = grid[which.max(r2)], table = data.frame(penalty = grid, cv_r2 = r2))
}
