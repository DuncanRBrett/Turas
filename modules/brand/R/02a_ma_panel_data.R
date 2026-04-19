# ==============================================================================
# BRAND MODULE - MA PANEL DATA BUILDER
# ==============================================================================
# Shapes the output of run_mental_availability() into a JSON-serialisable
# payload consumed by build_ma_panel_html() and brand_ma_panel.js.
#
# The panel exposes three sub-tabs:
#   - Attributes   — brand-image attribute x brand matrix
#   - CEPs         — CEP x brand linkage matrix (with base toggle)
#   - Metrics      — MPen, NS, MMS per brand + CEP penetration ranking
#
# All three tabs share: brands-as-columns, heatmap variation vs category
# average, chip picker, pin, export, focal-row accent.
# VERSION: 1.0
# ==============================================================================

BRAND_MA_PANEL_DATA_VERSION <- "1.0"


#' Build the MA panel data payload
#'
#' @param ma_result List. Output from \code{run_mental_availability()}.
#' @param brand_list Data frame with BrandCode + BrandLabel (+ optional
#'   Colour).
#' @param cep_list Data frame with CEPCode + CEPText.
#' @param attribute_list Data frame with AttrCode + AttrText. May be NULL.
#' @param awareness_by_brand Named numeric vector, brand -> awareness %
#'   (0..100). Used as the denominator for the "% aware" base mode and
#'   for the Metrics tab hero cards. May be NULL (base mode forced to
#'   total).
#' @param config Named list with optional entries:
#'   \describe{
#'     \item{category_label}{Category display name.}
#'     \item{focal_brand_code}{Focal brand code (default: ma_result focal).}
#'     \item{focal_brand_name}{Focal brand label (defaults to code).}
#'     \item{wave_label}{Wave label for sub-title.}
#'     \item{brand_colours}{Named list brand_code -> hex colour.}
#'     \item{focal_colour}{Focal hex colour override.}
#'   }
#'
#' @return A list with components \code{meta}, \code{attributes},
#'   \code{ceps}, \code{metrics}, \code{config}, and \code{about}.
#'   Consumed by \code{build_ma_panel_html()}.
#'
#' @export
build_ma_panel_data <- function(ma_result, brand_list, cep_list,
                                attribute_list = NULL,
                                awareness_by_brand = NULL,
                                config = list()) {

  if (is.null(ma_result) || identical(ma_result$status, "REFUSED")) {
    return(list(meta = list(), attributes = NULL, ceps = NULL,
                metrics = NULL, config = list(), about = list()))
  }

  brand_codes <- ma_result$cep_brand_matrix[,
                 !(names(ma_result$cep_brand_matrix) %in% c("CEPCode","AttrCode"))]
  brand_codes <- names(brand_codes)
  brand_names <- brand_list$BrandLabel[match(brand_codes, brand_list$BrandCode)]
  brand_names[is.na(brand_names)] <- brand_codes[is.na(brand_names)]

  focal_code <- config$focal_brand_code %||% ma_result$metrics_summary$focal_brand
  focal_name <- config$focal_brand_name %||%
                brand_names[match(focal_code, brand_codes)]

  brand_colours <- config$brand_colours %||% list()
  if (!is.null(brand_list$Colour)) {
    for (i in seq_len(nrow(brand_list))) {
      col <- trimws(as.character(brand_list$Colour[i]))
      if (nzchar(col) && grepl("^#[0-9A-Fa-f]{6}", col))
        brand_colours[[brand_list$BrandCode[i]]] <- col
    }
  }

  meta <- list(
    category_label    = config$category_label %||% "",
    wave_label        = config$wave_label %||% "",
    focal_brand_code  = focal_code,
    focal_brand_name  = focal_name,
    n_respondents     = ma_result$n_respondents,
    n_brands          = length(brand_codes),
    n_ceps            = ma_result$n_ceps %||% 0L,
    n_attrs           = ma_result$n_attrs %||% 0L
  )

  # Both attribute and CEP matrices honour the "% of total / % of aware"
  # base toggle. Attributes are commonly reported on total base in CBM
  # practice, but operators want the option to flip.
  attributes_block <- .ma_build_stimulus_block(
    matrix_df   = ma_result$attribute_brand_matrix,
    label_df    = attribute_list,
    code_col    = "AttrCode",
    text_col    = "AttrText",
    brand_codes = brand_codes,
    awareness_by_brand = awareness_by_brand,
    n_respondents = ma_result$n_respondents
  )

  ceps_block <- .ma_build_stimulus_block(
    matrix_df   = ma_result$cep_brand_matrix,
    label_df    = cep_list,
    code_col    = "CEPCode",
    text_col    = "CEPText",
    brand_codes = brand_codes,
    awareness_by_brand = awareness_by_brand,
    n_respondents = ma_result$n_respondents
  )

  metrics_block <- .ma_build_metrics_block(
    ma_result, brand_codes, brand_names, focal_code)

  about <- list(
    methodology_note = paste(
      "Mental Availability measures how accessible a brand is in memory",
      "across the category's key entry points (CEPs). Each CEP is a situation,",
      "motive, or trigger that a buyer connects to the category.",
      "Romaniuk (2022), Better Brand Health (Ehrenberg-Bass)."),
    mpen_note = paste("Mental Penetration: % of category buyers who link",
                      "the brand to at least one CEP."),
    ns_note   = paste("Network Size: average number of CEPs linked to the",
                      "brand, among respondents who link at least one."),
    mms_note  = paste("Mental Market Share: the brand's share of all",
                      "brand-CEP links in the category. Share of category",
                      "thinking."),
    attribute_note = paste("Brand-image attribute statements are perception",
                           "items, not entry points. Use them to understand",
                           "the associations the brand owns beyond CEPs."),
    base_note = paste(
      "CEP matrix can be expressed on a total-sample base (classic MMS",
      "denominator) or on a per-brand % aware base (strength among those",
      "who know the brand). Attribute matrix uses total base. Small bases",
      "(n<30) are dimmed."))

  config_out <- list(
    brand_codes   = brand_codes,
    brand_names   = brand_names,
    brand_colours = brand_colours,
    focal_colour  = config$focal_colour %||%
                     brand_colours[[focal_code]] %||% "#1A5276",
    default_base_mode = if (is.null(awareness_by_brand)) "total" else "total"
  )

  list(
    meta       = meta,
    attributes = attributes_block,
    ceps       = ceps_block,
    metrics    = metrics_block,
    config     = config_out,
    about      = about
  )
}


# ------------------------------------------------------------------
# INTERNAL: shape a stimulus x brand matrix into a table/cells payload
# ------------------------------------------------------------------

.ma_build_stimulus_block <- function(matrix_df, label_df, code_col, text_col,
                                     brand_codes,
                                     awareness_by_brand = NULL,
                                     n_respondents = NULL) {
  if (is.null(matrix_df) || nrow(matrix_df) == 0) return(NULL)

  codes <- matrix_df[[code_col]]
  texts <- if (!is.null(label_df) && text_col %in% names(label_df)) {
    label_df[[text_col]][match(codes, label_df[[code_col]])]
  } else codes
  texts[is.na(texts)] <- codes[is.na(texts)]

  # Per-stimulus category average across brands (simple mean of brand
  # percentages — a pooled category-level reading).
  brand_vals <- matrix_df[, brand_codes, drop = FALSE]
  stim_avg <- rowMeans(as.matrix(brand_vals), na.rm = TRUE)
  # Row CI around the cat-avg — treats brand values as a sample of the
  # category. Used server-side to classify each cell as above/within/below
  # and to colour the cat-avg column's "greyed CI band".
  stim_ci <- vapply(seq_len(nrow(matrix_df)), function(i) {
    v <- as.numeric(brand_vals[i, ])
    v <- v[is.finite(v)]
    if (length(v) < 2) return(c(NA_real_, NA_real_))
    m  <- mean(v); sd <- stats::sd(v)
    se <- sd / sqrt(length(v))
    c(lower = m - 1.96 * se, upper = m + 1.96 * se)
  }, numeric(2))
  stim_ci_lower <- stim_ci[1, ]
  stim_ci_upper <- stim_ci[2, ]

  # Per-brand average across stimuli (column means) — used for the
  # summary row.
  brand_avg <- colMeans(as.matrix(brand_vals), na.rm = TRUE)

  # n for each (brand, stim) cell — used for Show-count and sig tests.
  # Without per-cell bases we use the category n (weighted or raw) as a
  # denominator; when awareness_by_brand is provided, aware-base is
  # n_total * aware%/100.
  n_total <- if (is.null(n_respondents)) NA_real_ else as.numeric(n_respondents)

  cells <- vector("list", nrow(matrix_df) * length(brand_codes))
  k <- 1L
  for (i in seq_len(nrow(matrix_df))) {
    row_avg   <- stim_avg[i]
    row_lower <- stim_ci_lower[i]
    row_upper <- stim_ci_upper[i]
    for (b in brand_codes) {
      pct_total <- matrix_df[i, b]
      aware_pct <- if (!is.null(awareness_by_brand) &&
                       !is.na(awareness_by_brand[[b]]) &&
                       awareness_by_brand[[b]] > 0)
        as.numeric(awareness_by_brand[[b]]) else NA_real_
      pct_aware <- if (!is.na(aware_pct) && aware_pct > 0)
        100 * pct_total / aware_pct else NA_real_

      # CI band classification (based on total pct)
      ci_band <- if (is.na(pct_total) || is.na(row_lower) || is.na(row_upper))
        "na"
      else if (pct_total > row_upper) "above"
      else if (pct_total < row_lower) "below"
      else "within"

      # Two-proportion z-test: brand vs cat-avg
      sig_dir <- "na"
      if (!is.na(pct_total) && !is.na(row_avg) &&
          !is.na(n_total) && n_total > 0) {
        p1 <- pct_total / 100
        p2 <- row_avg / 100
        n1 <- n_total
        n2 <- n_total * max(1, length(brand_codes) - 1)  # approx cat-avg base
        p_pool <- (p1 * n1 + p2 * n2) / (n1 + n2)
        se <- sqrt(p_pool * (1 - p_pool) * (1/n1 + 1/n2))
        if (!is.na(se) && se > 0) {
          z <- (p1 - p2) / se
          if (abs(z) > 1.96) sig_dir <- if (z > 0) "higher" else "lower"
        }
      }

      n_cell_total <- if (is.na(n_total)) NA_integer_ else
        as.integer(round(n_total * pct_total / 100))
      n_cell_aware <- if (is.na(n_total) || is.na(aware_pct) || aware_pct <= 0)
        NA_integer_ else
        as.integer(round(n_total * aware_pct / 100 * pct_aware / 100))

      cells[[k]] <- list(
        stim_code   = codes[i],
        brand_code  = b,
        pct_total   = round(as.numeric(pct_total), 1),
        pct_aware   = round(as.numeric(pct_aware %||% NA_real_), 1),
        diff_vs_avg = round(as.numeric(pct_total - row_avg), 1),
        base_total  = if (is.na(n_total)) NA_integer_ else as.integer(n_total),
        base_aware  = if (is.na(aware_pct)) NA_integer_ else
                      as.integer(round(n_total * aware_pct / 100)),
        n_total     = n_cell_total,
        n_aware     = n_cell_aware,
        ci_band     = ci_band,
        sig_vs_avg  = sig_dir
      )
      k <- k + 1L
    }
  }

  # Cat-avg CI width per row — shown as a shaded cat-avg column marker
  list(
    codes         = codes,
    labels        = texts,
    brand_codes   = brand_codes,
    stim_avg      = round(as.numeric(stim_avg), 1),
    stim_ci_lower = round(as.numeric(stim_ci_lower), 1),
    stim_ci_upper = round(as.numeric(stim_ci_upper), 1),
    brand_avg     = round(as.numeric(brand_avg), 1),
    cells         = cells,
    n_total       = if (is.na(n_total)) NULL else as.integer(n_total),
    awareness_by_brand = if (!is.null(awareness_by_brand))
      as.list(round(awareness_by_brand, 1)) else NULL
  )
}


# CI band classification (above/within/below category average 95% CI)
.calc_metric_ci_bounds <- function(vals) {
  v <- vals[!is.na(vals) & is.finite(vals)]
  if (length(v) < 2) return(list(lower = NA_real_, upper = NA_real_))
  m  <- mean(v)
  se <- stats::sd(v) / sqrt(length(v))
  list(lower = round(m - 1.96 * se, 3), upper = round(m + 1.96 * se, 3))
}

.calc_metric_ci_bands <- function(vals) {
  m <- mean(vals, na.rm = TRUE)
  s <- stats::sd(vals, na.rm = TRUE)
  n <- sum(!is.na(vals))
  if (n < 2 || is.na(s) || s == 0)
    return(rep("within", length(vals)))
  se    <- s / sqrt(n)
  upper <- m + 1.96 * se
  lower <- m - 1.96 * se
  ifelse(is.na(vals), "na",
    ifelse(vals > upper, "above",
      ifelse(vals < lower, "below", "within")))
}


.ma_build_metrics_block <- function(ma_result, brand_codes, brand_names,
                                    focal_code) {
  # Align metrics frames to brand_codes order
  align <- function(df, col, id_col) {
    idx <- match(brand_codes, df[[id_col]])
    as.numeric(df[[col]][idx])
  }

  n_ceps <- ma_result$n_ceps %||% 0L

  mpen <- 100 * align(ma_result$mpen, "MPen", "BrandCode")  # to percent
  ns   <- align(ma_result$ns, "NS", "BrandCode")
  mms  <- 100 * align(ma_result$mms, "MMS", "BrandCode")  # to percent
  # Share of Mind (Romaniuk 2022): brand's CEP links as share of ALL links
  # made by buyers with MPen for that brand.  Each brand uses a different
  # respondent base → totals across brands exceed 100%.
  # Derivation: SOM_b = MMS_b × 100 / MPen_b  (MPen factor cancels numerator
  # and denominator when same n_MPen_b appears in both under the independence
  # approximation for cross-brand links).
  som <- round(ifelse(mpen > 0, mms * 100 / mpen, NA_real_), 1)

  # CI band classification vs category average for each metric
  mms_band  <- .calc_metric_ci_bands(mms)
  mpen_band <- .calc_metric_ci_bands(mpen)
  ns_band   <- .calc_metric_ci_bands(ns)
  som_band  <- .calc_metric_ci_bands(som)

  # Per-brand metrics table (brands as rows)
  table_rows <- vector("list", length(brand_codes))
  for (i in seq_along(brand_codes)) {
    table_rows[[i]] <- list(
      brand_code = brand_codes[i],
      brand_name = brand_names[i],
      mpen       = round(mpen[i], 1),
      ns         = round(ns[i], 2),
      mms        = round(mms[i], 1),
      som        = round(som[i], 1),
      mms_band   = mms_band[i],
      mpen_band  = mpen_band[i],
      ns_band    = ns_band[i],
      som_band   = som_band[i]
    )
  }

  # CEP penetration ranking
  cep_rank <- if (!is.null(ma_result$cep_penetration))
    ma_result$cep_penetration else NULL

  # Focal headline (for hero cards)
  focal_idx <- match(focal_code, brand_codes)
  focal_hero <- list(
    mpen = if (!is.na(focal_idx)) round(mpen[focal_idx], 1) else NA_real_,
    ns   = if (!is.na(focal_idx)) round(ns[focal_idx], 2)   else NA_real_,
    mms  = if (!is.na(focal_idx)) round(mms[focal_idx], 1)  else NA_real_,
    som  = if (!is.na(focal_idx)) round(som[focal_idx], 1)  else NA_real_
  )

  # Category average (mean across brands) for context + 95% CI bounds
  mpen_bounds <- .calc_metric_ci_bounds(mpen)
  ns_bounds   <- .calc_metric_ci_bounds(ns)
  mms_bounds  <- .calc_metric_ci_bounds(mms)
  som_bounds  <- .calc_metric_ci_bounds(som)

  cat_avg <- list(
    mpen       = round(mean(mpen, na.rm = TRUE), 1),
    ns         = round(mean(ns,   na.rm = TRUE), 2),
    mms        = round(mean(mms,  na.rm = TRUE), 1),
    som        = round(mean(som,  na.rm = TRUE), 1),
    mpen_ci_lo = mpen_bounds$lower,
    mpen_ci_hi = mpen_bounds$upper,
    ns_ci_lo   = ns_bounds$lower,
    ns_ci_hi   = ns_bounds$upper,
    mms_ci_lo  = mms_bounds$lower,
    mms_ci_hi  = mms_bounds$upper,
    som_ci_lo  = som_bounds$lower,
    som_ci_hi  = som_bounds$upper
  )

  # Leader per metric
  leader <- list(
    mpen = brand_codes[which.max(mpen)],
    ns   = brand_codes[which.max(ns)],
    mms  = brand_codes[which.max(mms)],
    som  = brand_codes[which.max(som)]
  )

  list(
    table       = table_rows,
    focal_hero  = focal_hero,
    cat_avg     = cat_avg,
    leader      = leader,
    cep_penetration = cep_rank,
    max_vals = list(
      mpen = round(max(mpen, na.rm = TRUE), 1),
      ns   = round(max(ns,   na.rm = TRUE), 2),
      mms  = round(max(mms,  na.rm = TRUE), 1),
      som  = round(max(som,  na.rm = TRUE), 1)
    )
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand MA panel data loaded (v%s)",
                  BRAND_MA_PANEL_DATA_VERSION))
}
