# ==============================================================================
# BRAND MODULE - WOM PANEL DATA BUILDER
# ==============================================================================
# Shapes run_wom() output into the panel contract consumed by
# build_wom_panel_html() (modules/brand/lib/html_report/panels/05_wom_panel.R).
#
# Output layout (brands-as-rows, questions-as-columns) mirrors the funnel
# relationship (brand attitude) table:
#   Row 1     focal brand
#   Row 2     category average (with 95% CI mini-bars per column)
#   Row 3+    competitor brands
#
# Columns:
#   Heard pos | Heard neg | Net heard | Said pos | Said neg | Net said |
#   Pos freq  | Neg freq
#
# VERSION: 1.0
# ==============================================================================

WOM_PANEL_DATA_VERSION <- "1.0"

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


#' Build the WOM panel data contract.
#'
#' @param wom_result List. Output from \code{run_wom()}.
#' @param brand_list Data frame. Category-scoped brand list with columns
#'   \code{BrandCode} and (optionally) \code{BrandLabel}.
#' @param config List. Additional config — supports:
#'   \item{category_label}{Character. Category display label.}
#'   \item{wave_label}{Character. Wave label.}
#'   \item{focal_brand_code}{Character. Overrides wom_result$metrics_summary.}
#'   \item{focal_colour}{Character. Hex colour for the focal brand.}
#'   \item{brand_colours}{Named list BrandCode -> hex colour. Drives chip
#'     colouring in the show/hide controls bar.}
#'   \item{timeframe_label}{Character. e.g. "last 3 months" — appears in
#'     question labels.}
#'
#' @return List with \code{meta}, \code{columns}, \code{brands},
#'   \code{cat_avg}, \code{config}. Returns NULL if wom_result is REFUSED or
#'   missing the wom_metrics frame.
#' @export
build_wom_panel_data <- function(wom_result,
                                 brand_list,
                                 config = list()) {

  if (is.null(wom_result) || identical(wom_result$status, "REFUSED"))
    return(NULL)
  if (is.null(wom_result$wom_metrics) ||
      nrow(wom_result$wom_metrics) == 0)
    return(NULL)

  wm  <- wom_result$wom_metrics
  nb  <- wom_result$net_balance

  # --- Brand code/name lookup (preserve brand_list display order) ---
  brand_codes_all <- as.character(brand_list$BrandCode)
  brand_names_all <- if ("BrandLabel" %in% names(brand_list))
    as.character(brand_list$BrandLabel) else brand_codes_all

  # Filter wm rows to those present in brand_list, preserving brand_list order
  idx <- match(brand_codes_all, as.character(wm$BrandCode))
  keep <- !is.na(idx)
  brand_codes <- brand_codes_all[keep]
  brand_names <- brand_names_all[keep]
  if (length(brand_codes) == 0) return(NULL)

  focal_code <- config$focal_brand_code %||%
                wom_result$metrics_summary$focal_brand
  focal_name <- if (!is.null(focal_code) && focal_code %in% brand_codes)
    brand_names[match(focal_code, brand_codes)] else NULL

  # --- Per-column raw values (vectors aligned to brand_codes) ---
  rp  <- as.numeric(wm$ReceivedPos_Pct[idx[keep]])
  rn  <- as.numeric(wm$ReceivedNeg_Pct[idx[keep]])
  sp  <- as.numeric(wm$SharedPos_Pct[idx[keep]])
  sn  <- as.numeric(wm$SharedNeg_Pct[idx[keep]])
  pf  <- as.numeric(wm$SharedPosFreq_Mean[idx[keep]])
  nf  <- as.numeric(wm$SharedNegFreq_Mean[idx[keep]])

  net_heard <- rp - rn
  net_said  <- sp - sn

  col_values <- list(
    received_pos = rp,
    received_neg = rn,
    net_heard    = net_heard,
    shared_pos   = sp,
    shared_neg   = sn,
    net_said     = net_said,
    pos_freq     = pf,
    neg_freq     = nf
  )

  # --- Column metadata ---
  tf <- config$timeframe_label %||% "last 3 months"
  columns <- list(
    list(key = "received_pos", label = "Heard positive",
         long_label = sprintf("%% who have had someone share something positive about the brand in the %s", tf),
         value_type = "pct"),
    list(key = "received_neg", label = "Heard negative",
         long_label = sprintf("%% who have had someone share something negative about the brand in the %s", tf),
         value_type = "pct"),
    list(key = "net_heard",    label = "Net heard",
         long_label = "Heard positive \u2212 Heard negative (percentage points)",
         value_type = "net"),
    list(key = "shared_pos",   label = "Said positive",
         long_label = sprintf("%% who have shared something positive about the brand in the %s", tf),
         value_type = "pct"),
    list(key = "shared_neg",   label = "Said negative",
         long_label = sprintf("%% who have shared something negative about the brand in the %s", tf),
         value_type = "pct"),
    list(key = "net_said",     label = "Net said",
         long_label = "Said positive \u2212 Said negative (percentage points)",
         value_type = "net"),
    list(key = "pos_freq",     label = "Said pos (occasions)",
         long_label = sprintf("Mean number of occasions a positive share took place in the %s (among sharers)", tf),
         value_type = "freq"),
    list(key = "neg_freq",     label = "Said neg (occasions)",
         long_label = sprintf("Mean number of occasions a negative share took place in the %s (among sharers)", tf),
         value_type = "freq")
  )

  # --- Category averages + 95% CI per column (across brand values) ---
  cat_avg <- lapply(col_values, function(v) {
    finite_v <- v[is.finite(v)]
    n <- length(finite_v)
    if (n == 0) {
      return(list(mean = NA_real_, ci_lower = NA_real_,
                  ci_upper = NA_real_, sd = NA_real_,
                  n_brands = 0L))
    }
    m <- mean(finite_v)
    if (n < 2) {
      return(list(mean = round(m, 2), ci_lower = NA_real_,
                  ci_upper = NA_real_, sd = NA_real_,
                  n_brands = as.integer(n)))
    }
    sd_v <- stats::sd(finite_v)
    se   <- sd_v / sqrt(n)
    list(mean     = round(m, 2),
         ci_lower = round(m - 1.96 * se, 2),
         ci_upper = round(m + 1.96 * se, 2),
         sd       = round(sd_v, 3),
         n_brands = as.integer(n))
  })
  names(cat_avg) <- names(col_values)

  # --- Brand rows ---
  brands <- lapply(seq_along(brand_codes), function(i) {
    bc <- brand_codes[i]
    list(
      brand_code = bc,
      brand_name = brand_names[i],
      is_focal   = identical(bc, focal_code),
      values = list(
        received_pos = rp[i],
        received_neg = rn[i],
        net_heard    = net_heard[i],
        shared_pos   = sp[i],
        shared_neg   = sn[i],
        net_said     = net_said[i],
        pos_freq     = pf[i],
        neg_freq     = nf[i]
      )
    )
  })

  list(
    meta = list(
      focal_brand_code = focal_code,
      focal_brand_name = focal_name,
      category_label   = config$category_label %||% "",
      wave_label       = config$wave_label %||% "",
      timeframe_label  = tf,
      n_unweighted     = as.integer(wom_result$n_respondents %||% NA_integer_),
      n_brands         = as.integer(length(brand_codes))
    ),
    columns = columns,
    brands  = brands,
    cat_avg = cat_avg,
    config = list(
      brand_codes   = brand_codes,
      brand_names   = brand_names,
      brand_colours = config$brand_colours %||% list(),
      focal_colour  = config$focal_colour %||% "#1A5276"
    )
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand WOM panel data builder loaded (v%s)",
                  WOM_PANEL_DATA_VERSION))
}
