# ==============================================================================
# WHAT IF - MOVES
# ==============================================================================
#
# A move changes one lever for every respondent it applies to and returns the
# change in that lever's model column, one value per respondent.
#
#   rating and nested levers
#     slip2, slip1   two or one scale points down, stopped at the bottom
#     up1, up2       one or two points up, stopped at the top
#     floor          lift everyone below the lever's fix target up to it
#                    (the "If fixed" column of the effort table)
#   coverage levers
#     withdraw       take the service away from everyone who has it
#     extend         give it to everyone who lacks it
#
# A nested lever's moves touch only respondents who have the service. A
# respondent flagged dk (no rating of their own; the value is a fill) is never
# moved and never counted as needing the fix: there is no rating to lift or to
# let slip.
# Move names match the prototype and its mockup page.
#
# ==============================================================================

WHATIF_RATING_MOVES <- c("slip2", "slip1", "up1", "up2", "floor")
WHATIF_COVERAGE_MOVES <- c("withdraw", "extend")
WHATIF_MOVES <- c(WHATIF_RATING_MOVES, WHATIF_COVERAGE_MOVES)


#' Moves That Apply to a Lever Kind
#' @keywords internal
whatif_moves_for_kind <- function(kind) {
  if (identical(kind, "coverage")) WHATIF_COVERAGE_MOVES else WHATIF_RATING_MOVES
}


#' Change in a Lever's Model Column Under a Move
#'
#' @param lv Guarded lever
#' @param move Move name
#' @param scale Scale list (min, max, centre)
#' @return Numeric vector (one per respondent), or NULL when the move does not
#'   apply to this kind of lever
#' @keywords internal
whatif_move_delta <- function(lv, move, scale) {
  if (!move %in% whatif_moves_for_kind(lv$kind)) return(NULL)
  v <- lv$values
  if (lv$kind == "coverage") {
    return(if (move == "extend") 1 - v else -v)
  }
  vv <- if (lv$kind == "nested") ifelse(lv$has, v, scale$centre) else v
  out <- if (move == "floor") {
    pmax(vv, lv$target) - vv
  } else {
    step <- c(slip2 = -2, slip1 = -1, up1 = 1, up2 = 2)[[move]]
    pmin(pmax(vv + step, scale$min), scale$max) - vv
  }
  if (lv$kind == "nested") out <- ifelse(lv$has, out, 0)
  if (!is.null(lv$dk)) out[lv$dk] <- 0
  out
}


#' Respondents a Lever's Fix Would Reach
#'
#' Rating: below the fix target. Nested: has the service and below the target.
#' Coverage: does not have the service. A respondent flagged dk gave no rating,
#' so they are not counted whatever fill their value carries.
#'
#' @param lv Guarded lever
#' @return Logical vector
#' @keywords internal
whatif_need_mask <- function(lv) {
  if (lv$kind == "coverage") return(lv$values == 0)
  not_dk <- if (is.null(lv$dk)) TRUE else !lv$dk
  if (lv$kind == "nested") return(lv$has & !is.na(lv$values) & lv$values < lv$target & not_dk)
  lv$values < lv$target & not_dk
}
