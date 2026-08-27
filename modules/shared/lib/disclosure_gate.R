# ==============================================================================
# TURAS SHARED — MINIMUM BASE / DISCLOSURE GATE
# ==============================================================================
#
# One predicate for "is this base big enough to say something about".
#
# The rule itself is not new — every site already compared a base against
# significance_min_base (default 30) inline. What was missing was a single
# place to say it, so that a module migrating into the V2 report gates the
# same way at analysis, at render and at export, rather than reimplementing
# the comparison three times and drifting on the edge cases.
#
# The V2 migration plan (modules/tabs/docs/V2_MIGRATION_PLAN.md, §5) requires
# the same predicate at all three points. This is that predicate.
# ==============================================================================

#' Does a Base Meet the Minimum for Disclosure?
#'
#' Returns TRUE where a base is large enough to be reported and significance-
#' tested, FALSE where it is not.
#'
#' A missing base is not a large base: `NA` returns FALSE. So does a
#' non-finite one. This matters because the inline comparisons this replaces
#' (`n < min_base`) return `NA` on a missing base, and `if (NA)` is an error —
#' the guard silently depended on its inputs never being absent.
#'
#' @param base Numeric vector of base sizes (unweighted n, or effective n where
#'   the study is weighted — the caller decides which, as it did before).
#' @param min_base Single numeric, the threshold. Defaults to 30, the platform
#'   default for `significance_min_base`.
#' @return Logical vector the same length as `base`.
#'
#' @examples
#' meets_min_base(c(29, 30, 31))        # FALSE TRUE TRUE
#' meets_min_base(50, min_base = 100)   # FALSE
#' meets_min_base(NA)                   # FALSE
#'
#' @export
meets_min_base <- function(base, min_base = 30L) {

  if (length(min_base) != 1 || !is.numeric(min_base) || !is.finite(min_base)) {
    stop("meets_min_base(): min_base must be a single finite number")
  }

  base <- suppressWarnings(as.numeric(base))

  ok <- !is.na(base) & is.finite(base) & base >= min_base
  ok[is.na(ok)] <- FALSE

  ok
}
