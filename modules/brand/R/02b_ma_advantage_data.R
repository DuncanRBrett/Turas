# ==============================================================================
# BRAND MODULE - MA ADVANTAGE PANEL DATA BUILDER
# ==============================================================================
# Shapes a calculate_mental_advantage() result into the JSON-serialisable
# block consumed by the Mental Advantage sub-tab. Builds parallel sub-blocks
# for CEPs and brand-image attributes when both are available, plus a
# top-level config for the stim toggle, threshold, and decision legend.
#
# The block is shaped to power three coordinated views:
#   - Strategic quadrant (focal brand): X = stim_penetration, Y = MA score
#     per stim, bubble size = focal raw linkage %.
#   - Diverging-palette matrix (all brands): MA scores per stim/brand.
#   - Action list (focal brand): Defend / Build / Maintain CEPs sorted.
#
# VERSION: 1.0
# ==============================================================================

BRAND_MA_ADVANTAGE_DATA_VERSION <- "1.0"


#' Build the Mental Advantage panel block
#'
#' @param ma_result List from \code{run_mental_availability()}. Reads
#'   \code{cep_advantage}, \code{attribute_advantage}, \code{cep_brand_matrix},
#'   \code{attribute_brand_matrix}, plus the labels.
#' @param brand_codes Character vector. Brand codes in display order.
#' @param brand_names Character vector. Display labels.
#' @param cep_list Data frame with CEPCode + CEPText.
#' @param attribute_list Data frame with AttrCode + AttrText. May be NULL.
#' @param awareness_by_brand Named numeric vector (0..100). Used to compute
#'   the per-brand "% aware" linkage value shown in tooltips. May be NULL.
#' @param focal_code Character. Focal brand code.
#'
#' @return A JSON-safe list with components:
#'   \describe{
#'     \item{available_stims}{Character vector of present stimulus types}
#'     \item{default_stim}{Default tab to show}
#'     \item{threshold_pp}{Defend/Build threshold in percentage points}
#'     \item{decisions}{Decision label legend (defend/maintain/build)}
#'     \item{ceps}{Sub-block for CEPs (or NULL)}
#'     \item{attributes}{Sub-block for attributes (or NULL)}
#'   }
#' @export
build_ma_advantage_block <- function(ma_result,
                                     brand_codes,
                                     brand_names = brand_codes,
                                     cep_list = NULL,
                                     attribute_list = NULL,
                                     awareness_by_brand = NULL,
                                     focal_code = NULL) {
  if (is.null(ma_result)) return(NULL)

  ceps_block <- .ma_adv_subblock(
    advantage = ma_result$cep_advantage,
    raw_matrix = ma_result$cep_brand_matrix,
    label_df = cep_list, code_col = "CEPCode", text_col = "CEPText",
    brand_codes = brand_codes, brand_names = brand_names,
    awareness_by_brand = awareness_by_brand, focal_code = focal_code)

  attrs_block <- .ma_adv_subblock(
    advantage = ma_result$attribute_advantage,
    raw_matrix = ma_result$attribute_brand_matrix,
    label_df = attribute_list, code_col = "AttrCode", text_col = "AttrText",
    brand_codes = brand_codes, brand_names = brand_names,
    awareness_by_brand = awareness_by_brand, focal_code = focal_code)

  available <- character(0)
  if (!is.null(ceps_block))  available <- c(available, "ceps")
  if (!is.null(attrs_block)) available <- c(available, "attributes")
  if (length(available) == 0) return(NULL)

  threshold_pp <- ma_result$cep_advantage$threshold_pp %||%
                   ma_result$attribute_advantage$threshold_pp %||%
                   MA_DEFAULT_THRESHOLD_PP

  list(
    available_stims = available,
    default_stim    = available[1],
    threshold_pp    = as.numeric(threshold_pp),
    decisions       = list(
      defend   = list(label = "Defend",   colour = "#059669"),
      maintain = list(label = "Maintain", colour = "#94a3b8"),
      build    = list(label = "Build",    colour = "#dc2626"),
      na       = list(label = "n/a",      colour = "#cbd5e1")),
    ceps        = ceps_block,
    attributes  = attrs_block
  )
}


# ------------------------------------------------------------------
# INTERNAL: per-stim sub-block from a calculate_mental_advantage result
# ------------------------------------------------------------------

.ma_adv_subblock <- function(advantage, raw_matrix, label_df, code_col, text_col,
                             brand_codes, brand_names,
                             awareness_by_brand = NULL, focal_code = NULL) {
  if (is.null(advantage) || identical(advantage$status, "REFUSED")) return(NULL)
  codes <- advantage$stim_codes
  if (length(codes) == 0) return(NULL)

  texts <- if (!is.null(label_df) && text_col %in% names(label_df)) {
    label_df[[text_col]][match(codes, label_df[[code_col]])]
  } else codes
  texts[is.na(texts)] <- codes[is.na(texts)]

  # Align brand columns to the requested display order; missing brands → NA cells.
  adv_brands <- intersect(brand_codes, advantage$brand_codes)
  if (length(adv_brands) == 0) return(NULL)

  cells <- .ma_adv_cells(advantage, raw_matrix, codes, adv_brands,
                          awareness_by_brand)

  focal_summary <- .ma_adv_focal_summary(cells, codes, focal_code, advantage$threshold_pp)

  list(
    codes              = codes,
    labels             = texts,
    brand_codes        = adv_brands,
    n_respondents      = as.numeric(advantage$n_respondents),
    grand_total        = as.numeric(advantage$grand_total),
    threshold_pp       = as.numeric(advantage$threshold_pp),
    stim_penetration   = round(as.numeric(advantage$stim_penetration[codes]), 1),
    stim_links         = as.numeric(advantage$stim_links[codes]),
    brand_links        = as.numeric(advantage$brand_links[adv_brands]),
    cells              = cells,
    focal_brand_code   = focal_code,
    focal_summary      = focal_summary
  )
}


.ma_adv_cells <- function(advantage, raw_matrix, codes, brand_codes,
                          awareness_by_brand = NULL) {
  cells <- vector("list", length(codes) * length(brand_codes))
  k <- 1L
  raw_lookup <- !is.null(raw_matrix)
  raw_code_col <- if (raw_lookup) intersect(c("CEPCode","AttrCode"), names(raw_matrix))[1] else NA_character_

  for (s in codes) {
    for (b in brand_codes) {
      ma_val   <- as.numeric(advantage$advantage[s, b])
      exp_val  <- as.numeric(advantage$expected[s, b])
      act_val  <- as.numeric(advantage$actual[s, b])
      z_val    <- as.numeric(advantage$std_residual[s, b])
      sig      <- isTRUE(as.logical(advantage$is_significant[s, b]))
      decision <- as.character(advantage$decision[s, b])

      pct_total <- if (raw_lookup && !is.na(raw_code_col)) {
        idx <- match(s, raw_matrix[[raw_code_col]])
        if (!is.na(idx) && b %in% names(raw_matrix))
          as.numeric(raw_matrix[idx, b]) else NA_real_
      } else NA_real_

      aware_pct <- if (!is.null(awareness_by_brand) &&
                       !is.null(awareness_by_brand[[b]]) &&
                       !is.na(awareness_by_brand[[b]]) &&
                       awareness_by_brand[[b]] > 0)
        as.numeric(awareness_by_brand[[b]]) else NA_real_
      pct_aware <- if (!is.na(aware_pct) && aware_pct > 0 && !is.na(pct_total))
        100 * pct_total / aware_pct else NA_real_

      cells[[k]] <- list(
        stim_code     = s,
        brand_code    = b,
        ma            = round(ma_val, 2),
        expected      = round(exp_val, 1),
        actual        = round(act_val, 1),
        std_residual  = round(z_val, 3),
        is_sig        = sig,
        decision      = decision,
        pct_total     = round(pct_total, 1),
        pct_aware     = round(pct_aware, 1)
      )
      k <- k + 1L
    }
  }
  cells
}


.ma_adv_focal_summary <- function(cells, codes, focal_code, threshold_pp) {
  if (is.null(focal_code)) {
    return(list(focal_brand_code = NULL, defend = list(), build = list(),
                maintain = list(), counts = list(defend = 0L, build = 0L,
                                                  maintain = 0L)))
  }
  focal_cells <- Filter(function(c) identical(c$brand_code, focal_code), cells)
  if (length(focal_cells) == 0) {
    return(list(focal_brand_code = focal_code, defend = list(), build = list(),
                maintain = list(), counts = list(defend = 0L, build = 0L,
                                                  maintain = 0L)))
  }
  thresh <- as.numeric(threshold_pp %||% MA_DEFAULT_THRESHOLD_PP)
  decision_of <- function(c) {
    if (is.na(c$ma)) return("na")
    if (c$ma >=  thresh) return("defend")
    if (c$ma <= -thresh) return("build")
    "maintain"
  }
  for (i in seq_along(focal_cells)) focal_cells[[i]]$decision <- decision_of(focal_cells[[i]])

  defend   <- Filter(function(c) identical(c$decision, "defend"), focal_cells)
  build    <- Filter(function(c) identical(c$decision, "build"), focal_cells)
  maintain <- Filter(function(c) identical(c$decision, "maintain"), focal_cells)

  defend   <- defend[order(-vapply(defend, function(c) c$ma, numeric(1)))]
  build    <- build[order( vapply(build,  function(c) c$ma, numeric(1)))]
  maintain <- maintain[order(-abs(vapply(maintain, function(c) c$ma, numeric(1))))]

  list(
    focal_brand_code = focal_code,
    defend   = defend,
    build    = build,
    maintain = maintain,
    counts   = list(defend = length(defend),
                    build = length(build),
                    maintain = length(maintain))
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand MA advantage panel data loaded (v%s)",
                  BRAND_MA_ADVANTAGE_DATA_VERSION))
}
