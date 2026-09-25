# ==============================================================================
# MAXDIFF - REFERENCE FIXTURES (robustness gate 1)
# ==============================================================================
#
# Simulators and hand-written references that share no code with the module.
# Sourced explicitly by the test_reference_*.R files (the runner only runs
# test*.R files, so a helper is never picked up on its own).
#
# Nothing here calls a module function. The reference conditional logit below
# is written from the likelihood, so a test comparing it with
# fit_aggregate_logit() compares two independent implementations.
# ==============================================================================

#' Simulate MaxDiff choices from known utilities (logit best, logit on -u worst)
#'
#' @param true_utils Named numeric. Population utilities.
#' @param n_resp,n_tasks,items_per_task Design size.
#' @param indiv_sd Respondent heterogeneity around true_utils.
#' @param seed RNG seed.
#' @return list(long = long-format data in the module's shape,
#'              indiv = n_resp x J matrix of the respondents' true utilities)
md_ref_simulate <- function(true_utils, n_resp = 40, n_tasks = 6,
                            items_per_task = 4, indiv_sd = 0, seed = 11) {
  set.seed(seed)
  item_ids <- names(true_utils)
  J <- length(item_ids)
  indiv <- matrix(rep(true_utils, each = n_resp), n_resp, J,
                  dimnames = list(paste0("R", seq_len(n_resp)), item_ids))
  if (indiv_sd > 0) indiv <- indiv + matrix(rnorm(n_resp * J, 0, indiv_sd), n_resp, J)
  rows <- vector("list", n_resp * n_tasks * items_per_task)
  k <- 0L
  for (r in seq_len(n_resp)) {
    for (t in seq_len(n_tasks)) {
      shown <- sample(item_ids, items_per_task)
      u <- indiv[r, shown]
      best <- sample(shown, 1, prob = exp(u) / sum(exp(u)))
      rem <- setdiff(shown, best)
      uw <- indiv[r, rem]
      worst <- if (length(rem) == 1) rem else sample(rem, 1, prob = exp(-uw) / sum(exp(-uw)))
      for (pos in seq_along(shown)) {
        k <- k + 1L
        rows[[k]] <- data.frame(
          resp_id = rownames(indiv)[r], version = 1L, task = t,
          item_id = shown[pos], position = pos,
          is_best = as.integer(shown[pos] == best),
          is_worst = as.integer(shown[pos] == worst),
          weight = 1, stringsAsFactors = FALSE
        )
      }
    }
  }
  long <- do.call(rbind, rows)
  long$obs_id <- seq_len(nrow(long))
  list(long = long, indiv = indiv)
}

md_ref_items <- function(item_ids, anchor = NULL) {
  data.frame(Item_ID = item_ids, Item_Label = paste("Label", item_ids),
             Item_Group = "G", Display_Order = seq_along(item_ids),
             Include = 1L, Anchor_Item = as.integer(item_ids %in% anchor),
             stringsAsFactors = FALSE)
}

#' Reference conditional logit for best-worst data, written from the likelihood
#'
#' Each respondent-task contributes two choice sets over the items shown:
#' the best choice with P(best = i) = exp(b_i) / sum_j exp(b_j), and the worst
#' choice with P(worst = i) = exp(-b_i) / sum_j exp(-b_j). The worst set keeps
#' the item already picked best, which is how the module models it.
#' The anchor's utility is fixed at 0.
#'
#' Weighted log-likelihood: sum over tasks of w_task * (log P_best + log P_worst).
#' Unweighted SE: sqrt(diag(H^-1)), H the Hessian of -loglik at the optimum.
#' Weighted SE: the sandwich H^-1 (sum_r U_r U_r') H^-1, U_r the weighted score
#' of respondent r summed over all their choice sets. It does not move when
#' every weight is multiplied by a constant.
#'
#' @return list(coef = named utilities of the non-anchor items, se_model, se_sandwich)
md_ref_clogit <- function(long, anchor) {
  items <- setdiff(sort(unique(long$item_id)), anchor)
  key <- paste(long$resp_id, long$version, long$task, sep = "\r")
  tasks <- split(seq_len(nrow(long)), key)
  sets <- list()
  for (ix in tasks) {
    X <- outer(long$item_id[ix], items, `==`) * 1
    w <- long$weight[ix[1]]
    r <- long$resp_id[ix[1]]
    sets[[length(sets) + 1]] <- list(X = X, y = long$is_best[ix], w = w, r = r)
    sets[[length(sets) + 1]] <- list(X = -X, y = long$is_worst[ix], w = w, r = r)
  }
  nll <- function(b) {
    -sum(vapply(sets, function(s) {
      v <- drop(s$X %*% b)
      s$w * (sum(v * s$y) - log(sum(exp(v))))
    }, numeric(1)))
  }
  grad <- function(b) {
    -Reduce(`+`, lapply(sets, function(s) {
      v <- drop(s$X %*% b); p <- exp(v) / sum(exp(v))
      s$w * (colSums(s$X * s$y) - colSums(s$X * p))
    }))
  }
  op <- optim(rep(0, length(items)), nll, grad, method = "BFGS",
              control = list(reltol = 1e-14, maxit = 5000))
  b <- op$par
  H <- Reduce(`+`, lapply(sets, function(s) {
    v <- drop(s$X %*% b); p <- exp(v) / sum(exp(v))
    s$w * (crossprod(s$X * p, s$X) - tcrossprod(colSums(s$X * p)))
  }))
  Hinv <- solve(H)
  U <- t(vapply(sets, function(s) {
    v <- drop(s$X %*% b); p <- exp(v) / sum(exp(v))
    s$w * (colSums(s$X * s$y) - colSums(s$X * p))
  }, numeric(length(items))))
  Ur <- rowsum(U, vapply(sets, `[[`, "", "r"))
  V_sand <- Hinv %*% crossprod(Ur) %*% Hinv
  list(coef = setNames(b, items),
       se_model = setNames(sqrt(diag(Hinv)), items),
       se_sandwich = setNames(sqrt(diag(V_sand)), items))
}

#' Module logit utilities as a named vector over the non-anchor items
md_module_logit <- function(long, items_df, anchor, weighted) {
  res <- fit_aggregate_logit(long, items_df, weighted = weighted,
                             anchor_item = anchor, verbose = FALSE)
  u <- res$utilities
  u <- u[u$Item_ID != anchor, ]
  list(coef = setNames(u$Logit_Utility, u$Item_ID),
       se = setNames(u$Logit_SE, u$Item_ID),
       fit = res)
}
