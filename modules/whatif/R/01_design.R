# ==============================================================================
# WHAT IF - DESIGN MATRIX
# ==============================================================================
#
# One column per lever term, then one column per context baseline dummy.
#
#   rating    value - centre
#   nested    has (0/1), and has * (value - centre); moves act on the second
#   coverage  0 or 1
#   baseline  one dummy per non-reference level of a context variable; the
#             most common level is the reference
#
# Ported from build_design() in prototypes/nps-simulator/whatif_engine.py; the
# baseline columns are new (the calibration fix, brief section 4).
#
# ==============================================================================

#' Build the Lever Model Design Matrix
#'
#' @param levers Guarded lever list
#' @param scale Scale list (centre used for rating and nested levers)
#' @param context Named context list
#' @param baselines Context keys to enter as baselines
#' @return List with
#'   \item{X}{numeric matrix, one row per respondent}
#'   \item{cols}{data frame describing each column: lever, part, is_context}
#'   \item{lever_col}{named integer: the column each lever's moves act on}
#'   \item{baseline_levels}{named list: levels of each baseline, reference first}
#' @keywords internal
whatif_build_design <- function(levers, scale, context = list(), baselines = character(0)) {
  parts <- list()
  cols <- list()
  lever_col <- integer(0)
  centre <- scale$centre %||% 0

  add <- function(x, lever, part, is_context) {
    parts[[length(parts) + 1]] <<- as.numeric(x)
    cols[[length(cols) + 1]] <<- data.frame(lever = lever, part = part,
                                            is_context = is_context, stringsAsFactors = FALSE)
    length(parts)
  }

  for (lv in levers) {
    if (lv$kind == "rating") {
      lever_col[lv$key] <- add(lv$values - centre, lv$key, "val", FALSE)
    } else if (lv$kind == "nested") {
      has <- as.numeric(lv$has)
      add(has, lv$key, "has", FALSE)
      vv <- ifelse(lv$has, lv$values, centre)
      lever_col[lv$key] <- add(has * (vv - centre), lv$key, "val", FALSE)
    } else {
      lever_col[lv$key] <- add(lv$values, lv$key, "val", FALSE)
    }
  }

  baseline_levels <- list()
  for (k in baselines) {
    v <- context[[k]]$values
    lv_order <- whatif_levels_by_frequency(v)
    baseline_levels[[k]] <- lv_order
    for (lev in lv_order[-1]) {
      add(v == lev, k, lev, TRUE)
    }
  }

  X <- do.call(cbind, parts)
  cols_df <- do.call(rbind, cols)
  colnames(X) <- paste(cols_df$lever, cols_df$part, sep = "_")
  list(X = X, cols = cols_df, lever_col = lever_col, baseline_levels = baseline_levels)
}


#' Build Profile Dummies
#'
#' Additive dummy coding of the profile traits, most common level as reference,
#' as the prototype's profile model does.
#'
#' @param context Named context list
#' @param keys Profile keys, in sentence order
#' @return List with X (matrix), cols (data frame key, level) and levels
#'   (named list, reference first)
#' @keywords internal
whatif_profile_design <- function(context, keys) {
  levels <- list()
  parts <- list()
  cols <- list()
  for (k in keys) {
    v <- context[[k]]$values
    lv_order <- whatif_levels_by_frequency(v)
    levels[[k]] <- lv_order
    for (lev in lv_order[-1]) {
      parts[[length(parts) + 1]] <- as.numeric(v == lev)
      cols[[length(cols) + 1]] <- data.frame(key = k, level = lev, stringsAsFactors = FALSE)
    }
  }
  X <- do.call(cbind, parts)
  cols_df <- do.call(rbind, cols)
  colnames(X) <- paste(cols_df$key, cols_df$level, sep = "=")
  list(X = X, cols = cols_df, levels = levels)
}
