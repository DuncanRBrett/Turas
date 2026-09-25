# ==============================================================================
# CONJOINT - REFERENCE FIXTURES (robustness gate 1)
# ==============================================================================
#
# Hand-written references that share no code with the module. Sourced
# explicitly by the test_reference_*.R files (the runner only runs test*.R).
#
# The multinomial logit below is written from its likelihood:
#   P(alternative a chosen in set s) = exp(x_a b) / sum_{j in s} exp(x_j b)
# with x the dummy coding of each attribute (first listed level = 0).
# mlogit is the module's own default engine, so it cannot be the reference
# for the module's aggregate utilities; this and survival::clogit are.
# ==============================================================================

#' Dummy-code the attributes of a long choice data frame
#'
#' @return matrix with one column per non-baseline level, named attr+level
#'   (the naming R's model.matrix uses, so it lines up with coef names)
cj_ref_design <- function(data, attributes) {
  cols <- list()
  for (a in names(attributes)) {
    lv <- attributes[[a]]
    for (l in lv[-1]) cols[[paste0(a, l)]] <- as.numeric(data[[a]] == l)
  }
  do.call(cbind, cols)
}

#' Reference MNL by maximum likelihood (optim + analytic gradient)
#'
#' @param data Long data: one row per alternative, with a choice-set id and a
#'   0/1 chosen column.
#' @param set_col Column identifying a choice set (unique across respondents).
#' @return list(coef, vcov, se, loglik, loglik_null)
cj_ref_mnl <- function(data, attributes, set_col, chosen_col = "chosen") {
  X <- cj_ref_design(data, attributes)
  sets <- split(seq_len(nrow(data)), data[[set_col]])
  y <- data[[chosen_col]]
  nll <- function(b) {
    v <- drop(X %*% b)
    -sum(vapply(sets, function(ix) sum(v[ix] * y[ix]) - log(sum(exp(v[ix]))), numeric(1)))
  }
  grad <- function(b) {
    v <- drop(X %*% b)
    -Reduce(`+`, lapply(sets, function(ix) {
      p <- exp(v[ix]) / sum(exp(v[ix]))
      colSums(X[ix, , drop = FALSE] * y[ix]) - colSums(X[ix, , drop = FALSE] * p)
    }))
  }
  op <- optim(rep(0, ncol(X)), nll, grad, method = "BFGS",
              control = list(reltol = 1e-14, maxit = 5000))
  b <- setNames(op$par, colnames(X))
  v <- drop(X %*% b)
  H <- Reduce(`+`, lapply(sets, function(ix) {
    p <- exp(v[ix]) / sum(exp(v[ix]))
    Xs <- X[ix, , drop = FALSE]
    crossprod(Xs * p, Xs) - tcrossprod(colSums(Xs * p))
  }))
  V <- solve(H)
  dimnames(V) <- list(colnames(X), colnames(X))
  list(coef = b, vcov = V, se = sqrt(diag(V)), loglik = -op$value,
       loglik_null = -sum(vapply(sets, function(ix) log(length(ix)), numeric(1))))
}

#' Centred part-worths of one attribute and their SEs from the full vcov
#'
#' u = A b_full, with b_full = (0, b_2..b_L) and A = I - 11'/L. Only the
#' non-baseline coefficients are random, so Var(u) = A_[,2:L] V A_[,2:L]'.
cj_ref_centred <- function(coef, vcov, attr, levels) {
  L <- length(levels)
  nm <- paste0(attr, levels[-1])
  b <- c(0, coef[nm])
  A <- diag(L) - matrix(1 / L, L, L)
  u <- drop(A %*% b)
  Ab <- A[, -1, drop = FALSE]
  V <- Ab %*% vcov[nm, nm, drop = FALSE] %*% t(Ab)
  list(utility = setNames(u, levels), se = setNames(sqrt(diag(V)), levels))
}

#' Simulate CBC choices with respondent heterogeneity around known part-worths
#'
#' @param truth Named contrasts, names attr+level (baseline = first level = 0).
#' @param indiv_sd SD of each respondent's contrasts around the truth.
#' @return list(data, config, attributes, indiv) in generate_synthetic_cbc()'s shape
cj_ref_simulate_hetero <- function(attributes, truth, n = 150, n_tasks = 10, n_alts = 3,
                                   indiv_sd = 0.4, seed = 5) {
  set.seed(seed)
  rows <- list(); k <- 0L
  indiv <- matrix(rep(truth, each = n), n, length(truth), dimnames = list(NULL, names(truth)))
  indiv <- indiv + matrix(rnorm(n * length(truth), 0, indiv_sd), n, length(truth))
  for (r in seq_len(n)) for (t in seq_len(n_tasks)) {
    alts <- lapply(seq_len(n_alts), function(a) vapply(attributes, function(l) sample(l, 1), ""))
    v <- vapply(alts, function(al) sum(vapply(names(attributes), function(nm) {
      key <- paste0(nm, al[[nm]]); if (key %in% colnames(indiv)) indiv[r, key] else 0
    }, numeric(1))), numeric(1))
    ch <- sample(seq_len(n_alts), 1, prob = exp(v) / sum(exp(v)))
    for (a in seq_len(n_alts)) {
      k <- k + 1L
      rows[[k]] <- c(list(resp_id = r, task_id = (r - 1) * n_tasks + t, alt_id = a),
                     as.list(alts[[a]]), list(chosen = as.integer(a == ch)))
    }
  }
  data <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  attr_df <- data.frame(AttributeName = names(attributes), NumLevels = lengths(attributes),
                        LevelNames = vapply(attributes, paste, "", collapse = ","),
                        stringsAsFactors = FALSE)
  attr_df$levels_list <- unname(attributes)
  config <- list(respondent_id_column = "resp_id", choice_set_column = "task_id",
                 alternative_id_column = "alt_id", chosen_column = "chosen",
                 estimation_method = "hb", analysis_type = "choice", attributes = attr_df,
                 confidence_level = 0.95, n_alternatives = n_alts)
  list(data = data, config = config, attributes = attributes, indiv = indiv)
}
