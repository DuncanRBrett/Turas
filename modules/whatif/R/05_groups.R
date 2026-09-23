# ==============================================================================
# WHAT IF - GROUP RESULTS
# ==============================================================================
#
# For a group of respondents: the actual score, and for every lever and move
# the change in the group's predicted score, from the main fit and from each
# bootstrap refit. The change is always the model's prediction after the move
# minus its prediction before, averaged over the group with the weights, so a
# model that misses a group's level still gives a fair change.
#
# Session 1 takes groups as given. Which groups may be published client-safe
# (secondary suppression, the nesting check) is session 4's job.
#
# ==============================================================================

#' Masks for Group Definitions
#'
#' @param context Named context list
#' @param defs Named list of definitions; each is a named character vector
#'   key = level (an empty vector means everyone)
#' @return Named list of logical masks
#' @keywords internal
whatif_group_masks <- function(context, defs) {
  n <- length(context[[1]]$values %||% NULL)
  lapply(defs, function(d) {
    m <- rep(TRUE, n)
    for (k in names(d)) {
      if (is.null(context[[k]])) {
        whatif_refuse("CFG_GROUP_UNKNOWN_CONTEXT", "Group uses an unknown variable",
          sprintf("A group is defined on '%s', which is not a context variable.", k),
          "The group cannot be formed, so its results would be empty.",
          "Define groups only on the spec's context variables.")
      }
      m <- m & context[[k]]$values == d[[k]]
    }
    m
  })
}


#' Summarise Draws as Point and 90 Percent Range
#'
#' @param d Numeric vector: main fit first, then refits
#' @return Named numeric: est, lo, hi (lo and hi NA with no refits)
#' @keywords internal
whatif_summarise_draws <- function(d) {
  boot <- d[-1]
  if (!length(boot) || all(is.na(boot))) return(c(est = d[1], lo = NA_real_, hi = NA_real_))
  q <- stats::quantile(boot, c(0.05, 0.95), type = 7, names = FALSE, na.rm = TRUE)
  c(est = d[1], lo = q[1], hi = q[2])
}


#' Results for a Set of Groups
#'
#' @param model A model from whatif_run_engine()
#' @param masks Named list of logical masks (see whatif_group_masks())
#' @return Named list, one entry per group, each with
#'   \item{n}{respondents in the group (unweighted)}
#'   \item{actual}{the group's actual weighted score}
#'   \item{predicted}{the main fit's average predicted score}
#'   \item{levers}{data frame: key, move, est, lo, hi, need, per_100}
#'   \item{bundles}{data frame: name, est, lo, hi}
#'   \item{draws}{array [lever, move, fit] of gains, main fit first}
#'   \item{bundle_draws}{matrix [bundle, fit]}
#'   or a structured refusal, printed to the console
#' @export
whatif_group_results <- function(model, masks) {
  with_refusal_handler(whatif_group_results_impl(model, masks), module = "WHATIF")
}


#' @keywords internal
whatif_group_results_impl <- function(model, masks) {
  spec <- model$spec
  X <- model$design$X
  w <- spec$weights
  score <- spec$outcome$score
  fits <- c(list(model$main), model$boot)
  levers <- spec$levers
  keys <- vapply(levers, `[[`, character(1), "key")
  deltas <- model$deltas
  bundles <- spec$bundles %||% list()

  for (nm in names(masks)) {
    if (sum(masks[[nm]]) == 0) {
      whatif_refuse("DATA_GROUP_EMPTY", "Group has no respondents",
        sprintf("Group '%s' has no respondents.", nm),
        "A result for an empty group would be a number with nothing behind it.",
        "Remove the group or check its definition against the data.")
    }
  }
  Wg <- vapply(masks, function(m) m * w, numeric(length(w)))
  Wg <- sweep(Wg, 2, colSums(Wg), `/`)

  n_g <- length(masks)
  gain <- array(NA_real_, c(n_g, length(keys), length(WHATIF_MOVES), length(fits)),
                dimnames = list(names(masks), keys, WHATIF_MOVES, NULL))
  bgain <- array(NA_real_, c(n_g, length(bundles), length(fits)))
  pred_base <- matrix(NA_real_, n_g, length(fits))

  for (f in seq_along(fits)) {
    fit <- fits[[f]]
    eta <- drop(X %*% fit$b)
    base <- whatif_score_vec(fit, eta, score)
    gb <- drop(crossprod(Wg, base))
    pred_base[, f] <- gb
    for (j in seq_along(keys)) {
      bj <- fit$b[[model$design$lever_col[[keys[j]]]]]
      for (mv in WHATIF_MOVES) {
        dx <- deltas[[keys[j]]][[mv]]
        if (is.null(dx)) next
        gain[, j, mv, f] <- drop(crossprod(Wg, whatif_score_vec(fit, eta + bj * dx, score))) - gb
      }
    }
    for (bi in seq_along(bundles)) {
      e2 <- eta
      for (k in names(bundles[[bi]]$moves)) {
        e2 <- e2 + fit$b[[model$design$lever_col[[k]]]] * deltas[[k]][[bundles[[bi]]$moves[[k]]]]
      }
      bgain[, bi, f] <- drop(crossprod(Wg, whatif_score_vec(fit, e2, score))) - gb
    }
  }

  out <- list()
  for (g in seq_len(n_g)) {
    m <- masks[[g]]
    shares <- whatif_category_shares(spec$y[m], w[m], spec$n_cat)
    rows <- list()
    for (j in seq_along(keys)) {
      need <- sum(whatif_need_mask(levers[[j]])[m])
      for (mv in whatif_moves_for_kind(levers[[j]]$kind)) {
        s <- whatif_summarise_draws(gain[g, j, mv, ])
        reach <- if (mv %in% c("floor", "extend")) need else NA_integer_
        rows[[length(rows) + 1]] <- data.frame(
          key = keys[j], move = mv, est = s[["est"]], lo = s[["lo"]], hi = s[["hi"]],
          need = need,
          per_100 = if (!is.na(reach) && reach > 0) s[["est"]] * sum(m) / reach else NA_real_,
          stringsAsFactors = FALSE)
      }
    }
    brows <- lapply(seq_along(bundles), function(bi) {
      s <- whatif_summarise_draws(bgain[g, bi, ])
      data.frame(name = bundles[[bi]]$name, est = s[["est"]], lo = s[["lo"]], hi = s[["hi"]],
                 stringsAsFactors = FALSE)
    })
    out[[names(masks)[g]]] <- list(
      n = sum(m),
      actual = sum(shares * score),
      predicted = pred_base[g, 1],
      levers = do.call(rbind, rows),
      bundles = if (length(brows)) do.call(rbind, brows) else NULL,
      draws = array(gain[g, , , ], dim(gain)[-1], dimnames(gain)[-1]),
      bundle_draws = if (length(bundles)) matrix(bgain[g, , ], nrow = length(bundles)) else NULL
    )
  }
  out
}
