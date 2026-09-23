# ==============================================================================
# WHAT IF - SHARED HELPERS
# ==============================================================================
#
# Refusal wrapper, seeded random numbers that leave the caller's stream alone,
# and console messages. Everything else in the module builds on these.
#
# ==============================================================================

#' Refuse to Run (What if)
#'
#' Thin wrapper around the shared \code{turas_refuse()} that fills the module
#' name. It throws a \code{turas_refusal} condition; the public entry point
#' \code{whatif_run_engine()} catches it with \code{with_refusal_handler()},
#' which prints the boxed message to the console and returns a structured
#' refusal.
#'
#' @param code TRS refusal code (CFG_, DATA_, MODEL_, CALC_ ...)
#' @param title Short title
#' @param problem One sentence on what went wrong
#' @param why_it_matters Why the result would be wrong without the fix
#' @param how_to_fix One string or a vector of steps
#' @param details Optional extra diagnostics
#' @return Never returns
#' @keywords internal
whatif_refuse <- function(code, title, problem, why_it_matters, how_to_fix,
                          details = NULL) {
  turas_refuse(
    code = code,
    title = title,
    problem = problem,
    why_it_matters = why_it_matters,
    how_to_fix = how_to_fix,
    details = details,
    module = "WHATIF"
  )
}


#' Run an Expression with a Fixed Seed, Restoring the Caller's Random Stream
#'
#' Bootstrap refits and cross-validation folds must be reproducible, but the
#' engine should not change what the next \code{runif()} in the caller's
#' session returns.
#'
#' @param seed Integer seed
#' @param expr Expression to evaluate
#' @return The value of \code{expr}
#' @keywords internal
whatif_with_seed <- function(seed, expr) {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = globalenv())
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  })
  set.seed(seed)
  expr
}


#' Print a What if Progress Line to the Console
#'
#' Turas runs inside Shiny, so progress and diagnostics go to the console.
#'
#' @param ... Pieces pasted together with no separator
#' @param verbose When FALSE nothing is printed
#' @return NULL, invisibly
#' @keywords internal
whatif_say <- function(..., verbose = TRUE) {
  if (isTRUE(verbose)) cat("[What if] ", ..., "\n", sep = "")
  invisible(NULL)
}


#' Weighted Share of Each Outcome Category
#'
#' @param y Integer outcome codes 1..n_cat
#' @param w Weights
#' @param n_cat Number of categories
#' @return Numeric vector of length n_cat summing to 1
#' @keywords internal
whatif_category_shares <- function(y, w, n_cat) {
  vapply(seq_len(n_cat), function(k) sum(w[y == k]) / sum(w), numeric(1))
}


#' Levels of a Context Variable, Most Common First
#'
#' The most common level is the reference level for dummy coding, as in the
#' prototype. Ties keep alphabetical order so the result is deterministic.
#'
#' @param x Character vector
#' @return Character vector of distinct levels
#' @keywords internal
whatif_levels_by_frequency <- function(x) {
  tab <- table(x)
  tab <- tab[order(names(tab))]
  names(tab)[order(-as.numeric(tab), method = "radix")]
}
