# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS: PANEL DATA ASSEMBLY
# ==============================================================================
# Shapes the engine output into a list ready for the HTML renderer
# (lib/html_report/panels/11_demographics_panel.R) and JSON serialisation.
#
# A demographics result holds N questions. Each question carries its label,
# its option list, the total distribution + (optional) buyer/tier/brand cuts.
# All numbers are pre-rounded percentages (1 dp). Wilson 95% CI bounds are
# carried alongside so the HTML overlay can show whiskers without having
# to round-trip.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DEMOGRAPHICS_OUTPUT_VERSION <- "1.0"


#' Assemble demographics panel data for HTML render
#'
#' @param questions List. One element per demographic question:
#'   list(role, column, question_text, short_label, variable_type,
#'        codes, labels, result). \code{result} is the output of
#'   \code{run_demographic_question()}.
#' @param focal_brand Character. Focal brand code (initial focal selection).
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @param brand_codes Character. Vector of brand codes (column order of any
#'   per-brand matrix).
#' @param brand_labels Character. Display labels parallel to brand_codes.
#' @param brand_colours List. Named hex colours keyed by brand code (optional).
#' @param decimal_places Integer. Display precision for percentages.
#' @param wave_label Character. Optional wave label for the panel header.
#' @param scope_label Character. Either "Total sample" (brand-level) or a
#'   category name (per-category panel). Shown in the header.
#' @param n_total Integer. Unweighted respondent base for the scope.
#' @param weighted Logical. Whether weights were used in the analysis.
#'
#' @return List ready for the HTML panel renderer.
#'
#' @export
build_demographics_panel_data <- function(questions,
                                           focal_brand    = "",
                                           focal_colour   = "#1A5276",
                                           brand_codes    = character(0),
                                           brand_labels   = character(0),
                                           brand_colours  = list(),
                                           decimal_places = 0L,
                                           wave_label     = "",
                                           scope_label    = "Total sample",
                                           n_total        = NA_integer_,
                                           weighted       = FALSE) {

  if (is.null(questions) || length(questions) == 0L) {
    return(list(
      meta = list(status = "EMPTY",
                   message = "No demographic questions configured."),
      questions = list()
    ))
  }

  # Drop questions whose engine result was REFUSED — they would render as
  # broken cards. The meta block records the count so the renderer can show
  # a footer note ("3 of 6 demographic questions skipped — see console").
  kept    <- list()
  skipped <- character(0)
  for (q in questions) {
    res <- q$result
    if (is.null(res) || identical(res$status, "REFUSED")) {
      skipped <- c(skipped, q$role %||% q$column %||% "(unknown)")
      next
    }
    kept[[length(kept) + 1L]] <- .demo_panel_one_question(q)
  }

  if (length(brand_labels) != length(brand_codes)) {
    brand_labels <- brand_codes
  }

  list(
    meta = list(
      status         = "PASS",
      scope_label    = scope_label,
      focal_brand    = focal_brand,
      focal_colour   = focal_colour,
      wave_label     = wave_label,
      n_total        = n_total,
      weighted       = isTRUE(weighted),
      n_questions    = length(kept),
      n_skipped      = length(skipped),
      skipped_roles  = skipped
    ),
    brands = list(
      codes   = as.character(brand_codes),
      labels  = as.character(brand_labels),
      colours = brand_colours
    ),
    questions = kept,
    config = list(
      decimal_places = as.integer(decimal_places %||% 0L),
      focal_colour   = focal_colour
    )
  )
}


# Convert one engine result into the JSON-friendly per-question payload.
# Brand_cut + brand_nonbuyer_cut are reshaped into parallel long lists so
# jsonlite emits them cleanly. The panel table joins them brand-by-brand at
# render time to draw buyer-vs-non-buyer cells.
.demo_panel_one_question <- function(q) {
  res <- q$result

  brand_long          <- .demo_panel_brand_long(res$brand_cut, q$codes)
  brand_nonbuyer_long <- .demo_panel_brand_long(res$brand_nonbuyer_cut,
                                                 q$codes)
  # Penetration-in-option is the table's primary metric — each cell is "% of
  # respondents in this demographic option who buy this brand". The cat-
  # average baseline is the PER-OPTION mean pen across brands (in
  # option_avg_penetration) — that's what the table Cat-avg column and chart
  # marker display, and what cells are shaded against. brand_total_pen is
  # kept as legend context ("focal overall pen") but no longer drives shading.
  brand_pen_long  <- .demo_panel_brand_long(res$brand_penetration_long,
                                             q$codes)
  brand_total_pen <- .demo_panel_brand_total_pen(res$brand_total_penetration)
  option_avg_pen  <- .demo_panel_option_avg_pen(res$option_avg_penetration,
                                                 q$codes)
  buyer_cut  <- if (is.null(res$buyer_cut)) NULL else list(
    buyer     = .demo_panel_dist(res$buyer_cut$buyer),
    non_buyer = .demo_panel_dist(res$buyer_cut$non_buyer)
  )
  tier_cut <- if (is.null(res$tier_cut)) NULL else list(
    light  = .demo_panel_dist(res$tier_cut$light),
    medium = .demo_panel_dist(res$tier_cut$medium),
    heavy  = .demo_panel_dist(res$tier_cut$heavy)
  )

  list(
    role               = q$role,
    column             = q$column,
    question_text      = q$question_text,
    short_label        = q$short_label %||% q$question_text,
    variable_type      = q$variable_type %||% "Single_Response",
    codes              = q$codes,
    labels             = q$labels,
    is_synthetic       = isTRUE(q$is_synthetic),
    synthetic_kind     = q$synthetic_kind %||% NA_character_,
    n_total            = res$n_total,
    n_respondents      = res$n_respondents,
    weighted           = isTRUE(res$weighted),
    conf_level         = res$conf_level %||% 0.95,
    total                   = .demo_panel_dist(res$total),
    buyer_cut               = buyer_cut,
    tier_cut                = tier_cut,
    brand_cut               = brand_long,
    brand_nonbuyer_cut      = brand_nonbuyer_long,
    brand_penetration_long  = brand_pen_long,
    brand_total_penetration = brand_total_pen,
    option_avg_penetration  = option_avg_pen
  )
}


# Convert the option-mean-pen named vector into a code-keyed list the JS
# renderer can index. Mirrors .demo_panel_brand_total_pen shape so the
# JS-side lookup pattern is consistent.
.demo_panel_option_avg_pen <- function(vec, codes) {
  if (is.null(vec) || length(vec) == 0L) return(list())
  out <- list()
  for (cd in codes) {
    v <- vec[[cd]]
    out[[as.character(cd)]] <- list(
      code = as.character(cd),
      pct  = if (is.null(v)) NA_real_ else as.numeric(v)
    )
  }
  out
}


# Convert the brand_total_penetration data frame into a name -> pct map the
# JS renderer can index by brand_code. Order doesn't matter; we look up by
# brand_code at render time.
.demo_panel_brand_total_pen <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) return(list())
  out <- list()
  for (i in seq_len(nrow(df))) {
    out[[as.character(df$BrandCode[i])]] <- list(
      brand_code = as.character(df$BrandCode[i]),
      pct        = as.numeric(df$Pct_Total[i]),
      base_n     = as.integer(df$Base_n[i])
    )
  }
  out
}


# Convert one distribution data frame into a list of named entries. Keeping
# the structure as list-of-lists rather than a transposed data frame plays
# nicely with jsonlite::toJSON(auto_unbox = TRUE).
.demo_panel_dist <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) return(list())
  base_n <- if ("Base_n" %in% names(df)) as.integer(df$Base_n[1L]) else NA_integer_
  # Drop options with zero respondents — these are screen-outs (e.g. IPK 2026
  # excluded under-30 / 51+ ages, Prefer-not-to-answer race, income brackets
  # below the screening cutoff, regions outside the targeted provinces).
  # Empty rows otherwise render as zero-filled cells that misleadingly look
  # like a real demographic group with no buyers.
  keep_idx <- which(!is.na(df$n) & as.integer(df$n) > 0L)
  if (length(keep_idx) == 0L) return(list(base_n = base_n, rows = list()))
  rows <- lapply(keep_idx, function(i) {
    list(
      code  = as.character(df$Code[i]),
      label = as.character(df$Label[i]),
      order = as.integer(df$Order[i]),
      n     = as.integer(df$n[i]),
      pct   = as.numeric(df$Pct[i])
    )
  })
  list(base_n = base_n, rows = rows)
}


# Re-emit a brand_cut / brand_nonbuyer_cut / brand_penetration_long data frame
# as one entry per brand x option. brand_penetration_long carries an extra
# per-option Base_n_<code> column — when present, it's forwarded as
# base_n_in_option on the cell so the panel can compute buyer/non-buyer n.
.demo_panel_brand_long <- function(brand_df, codes) {
  if (is.null(brand_df) || !is.data.frame(brand_df) || nrow(brand_df) == 0L) {
    return(list())
  }
  pct_cols      <- paste0("Pct_",    codes)
  base_opt_cols <- paste0("Base_n_", codes)
  has_per_opt_base <- all(base_opt_cols %in% names(brand_df))

  lapply(seq_len(nrow(brand_df)), function(i) {
    cells <- lapply(seq_along(codes), function(j) {
      cell <- list(
        code = codes[j],
        pct  = as.numeric(brand_df[[pct_cols[j]]][i])
      )
      if (has_per_opt_base) {
        cell$base_n_in_option <- as.integer(brand_df[[base_opt_cols[j]]][i])
      }
      cell
    })
    list(
      brand_code  = as.character(brand_df$BrandCode[i]),
      brand_label = as.character(brand_df$BrandLabel[i]),
      base_n      = as.integer(brand_df$Base_n[i]),
      cells       = cells
    )
  })
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Demographics output loaded (v%s)",
                  BRAND_DEMOGRAPHICS_OUTPUT_VERSION))
}
