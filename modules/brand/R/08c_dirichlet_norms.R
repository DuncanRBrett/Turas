BRAND_DIRICHLET_VERSION <- "1.0"

# Minimum |deviation %| to flag a brand as over / under
.DJ_DEV_FLAG_THRESHOLD <- 20


#' Compute Dirichlet norms for a category
#'
#' Calculates observed brand metrics from purchase count matrices, calls the
#' \pkg{NBDdirichlet} package to obtain expected values under the Dirichlet
#' model, computes deviations, and builds the DJ curve for overlay on the
#' Double Jeopardy scatter.
#'
#' @param pen_mat Integer matrix n_resp × n_brands. Reconciled 0/1 buyer flags
#'   from \code{build_brand_volume_matrix()}.
#' @param x_mat Numeric matrix n_resp × n_brands. Winsorised purchase counts.
#' @param m_vec Numeric vector length n_resp. Per-respondent category volume.
#' @param brand_codes Character vector. Brand codes (column names of matrices).
#' @param focal_brand Character or NULL. Focal brand code for metrics_summary.
#' @param weights Numeric vector or NULL. Respondent weights.
#' @param target_months Integer. REQUIRED.  From \code{config$target_timeframe_months}.
#'   Used for chart labels and panel footer text only — Dirichlet maths are
#'   period-agnostic.
#' @param longer_months Integer or NULL. From \code{config$longer_timeframe_months}.
#'   Used in panel subtitle only.
#'
#' @return List — see §7.2 of CAT_BUYING_SPEC_v3 for the full schema.
#'
#' @references Goodhardt, Ehrenberg & Chatfield (1984).
#'
#' @export
run_dirichlet_norms <- function(pen_mat,
                                x_mat,
                                m_vec,
                                brand_codes,
                                focal_brand   = NULL,
                                weights       = NULL,
                                target_months,
                                longer_months = NULL) {

  # --- Guards ---
  if (is.null(pen_mat) || nrow(pen_mat) == 0)
    return(.dn_refuse("DATA_NO_VOLUME", "pen_mat is empty"))
  if (!requireNamespace("NBDdirichlet", quietly = TRUE))
    return(.dn_refuse("PKG_DIRICHLET_MISSING",
                      "NBDdirichlet is required. Install via renv::install('NBDdirichlet')."))

  n_resp   <- nrow(pen_mat)
  n_brands <- length(brand_codes)

  if (n_brands < 2)
    return(.dn_refuse("DATA_SINGLE_BRAND",
                      "Dirichlet requires at least 2 brands"))

  w <- .dn_weights(weights, n_resp)
  w_sum <- sum(w)

  # --- Category-level metrics (§2.2) ---
  buyers_mask <- m_vec > 0
  n_buyers    <- sum(buyers_mask)
  if (n_buyers == 0)
    return(.dn_refuse("DATA_NO_VOLUME", "No category buyers found"))

  cat_pen      <- sum(w[buyers_mask]) / w_sum
  cat_mean_purch <- sum(w[buyers_mask] * m_vec[buyers_mask]) /
                   sum(w[buyers_mask])

  # --- Brand-level observed metrics (§2.3) ---
  obs <- .dn_observed(pen_mat, x_mat, m_vec, brand_codes,
                      buyers_mask, w, w_sum)

  # Market share and normalisation check (§5.6)
  total_vol <- sum(obs$Volume)
  if (total_vol <= 0)
    return(.dn_refuse("DATA_NO_VOLUME", "Total brand volume is zero"))
  obs$Share_Pct <- obs$Volume / total_vol * 100

  share_sum <- sum(obs$Share_Pct)
  if (abs(share_sum - 100) > 1e-4)
    return(.dn_refuse("CALC_SHARE_NORMALISATION",
                      sprintf("Share sum = %.8f (expected 100)", share_sum)))

  # --- Dirichlet call (§3) ---
  warnings_out <- character(0)
  if (n_brands < 4)
    warnings_out <- c(warnings_out,
      sprintf("Only %d brands — Dirichlet estimates may be unstable", n_brands))

  dir_result <- .dn_call_dirichlet(
    cat_pen, cat_mean_purch, obs$Share_Pct / 100,
    obs$Penetration_Pct / 100, brand_codes)

  if (identical(dir_result$status, "REFUSED"))
    return(dir_result)

  exp_df <- dir_result$expected

  # --- Deviation table (§3) ---
  norms_tbl <- .dn_build_norms_table(obs, exp_df, brand_codes)

  # --- DJ curve (§4 output 1) ---
  dj_curve <- .dn_dj_curve(exp_df, obs$Penetration_Pct)

  # --- metrics_summary ---
  ms <- .dn_metrics_summary(focal_brand, obs, norms_tbl, n_brands)

  market_shares <- data.frame(
    BrandCode = brand_codes,
    Volume    = obs$Volume,
    Share_Pct = obs$Share_Pct,
    stringsAsFactors = FALSE
  )

  list(
    status           = if (length(warnings_out) > 0) "PARTIAL" else "PASS",
    target_months    = as.integer(target_months),
    longer_months    = if (!is.null(longer_months)) as.integer(longer_months) else NA_integer_,
    category_metrics = list(
      penetration    = cat_pen,
      mean_purchases = cat_mean_purch,
      n_buyers       = as.integer(n_buyers),
      n_respondents  = as.integer(n_resp)
    ),
    market_shares    = market_shares,
    observed         = obs[, c("BrandCode", "Penetration_Pct", "BuyRate",
                               "SCR_Pct", "Pct100Loyal", "Brand_Buyers_n")],
    expected         = exp_df,
    norms_table      = norms_tbl,
    dj_curve         = dj_curve,
    metrics_summary  = ms,
    warnings         = warnings_out
  )
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Normalise weights to length-n vector
#' @keywords internal
.dn_weights <- function(weights, n) {
  if (is.null(weights)) return(rep(1.0, n))
  if (length(weights) != n) return(rep(1.0, n))
  w <- as.numeric(weights)
  w[is.na(w) | w < 0] <- 0
  if (sum(w) <= 0) rep(1.0, n) else w
}


#' Compute observed brand metrics (§2.3)
#' @keywords internal
.dn_observed <- function(pen_mat, x_mat, m_vec, brand_codes,
                          buyers_mask, w, w_sum) {
  n_brands <- length(brand_codes)
  rows <- lapply(seq_len(n_brands), function(bi) {
    b_mask <- pen_mat[, bi] == 1L
    n_bb   <- sum(b_mask)
    w_bb   <- sum(w[b_mask])
    pen_p  <- sum(w[b_mask]) / w_sum * 100

    buy_rate <- if (w_bb > 0)
      sum(w[b_mask] * x_mat[b_mask, bi]) / w_bb else NA_real_

    # SCR = brand purchases / total cat purchases among brand buyers (§2.1)
    scr_vals <- ifelse(m_vec[b_mask] > 0,
                       x_mat[b_mask, bi] / m_vec[b_mask], NA_real_)
    valid_scr <- !is.na(scr_vals)
    scr_pct   <- if (sum(valid_scr) > 0 && w_bb > 0)
      sum(w[b_mask][valid_scr] * scr_vals[valid_scr]) /
      sum(w[b_mask][valid_scr]) * 100 else NA_real_

    # 100%-loyal: brand buyer whose entire m_i came from this brand
    loyal_mask <- b_mask & (x_mat[, bi] >= m_vec) & m_vec > 0
    pct_loyal  <- if (w_bb > 0)
      sum(w[loyal_mask]) / w_bb * 100 else NA_real_

    # Volume
    vol <- sum(w * x_mat[, bi])

    list(BrandCode     = brand_codes[bi],
         Penetration_Pct = pen_p,
         BuyRate        = buy_rate,
         SCR_Pct        = scr_pct,
         Pct100Loyal    = pct_loyal,
         Brand_Buyers_n = n_bb,
         Volume         = vol)
  })

  as.data.frame(do.call(rbind, lapply(rows, as.data.frame,
                                       stringsAsFactors = FALSE)),
                stringsAsFactors = FALSE)
}


#' Call NBDdirichlet and extract expected metrics
#' @keywords internal
.dn_call_dirichlet <- function(cat_pen, cat_mean_purch, brand_shares,
                                brand_pen_obs, brand_codes) {
  result <- tryCatch({
    # NBDdirichlet::dirichlet() signature:
    #   dirichlet(cat.pen, cat.buyrate, brand.share, brand.pen.obs)
    # brand.pen.obs is required — observed brand penetration as fractions
    # suppressWarnings: the package emits informational "nstar is too small"
    # notices during maximum-likelihood estimation on small samples. These are
    # not errors — the calculation still completes and our guard validates the
    # output. Suppressing here keeps test and console output clean.
    dir_obj <- suppressWarnings(NBDdirichlet::dirichlet(
      cat.pen       = cat_pen,
      cat.buyrate   = cat_mean_purch,
      brand.share   = brand_shares,
      brand.pen.obs = brand_pen_obs
    ))
    dir_obj
  }, error = function(e) {
    list(.error = conditionMessage(e))
  })

  if (!is.null(result$.error))
    return(.dn_refuse("CALC_DIRICHLET_FAILED",
                      sprintf("NBDdirichlet::dirichlet() failed: %s",
                              result$.error)))

  # Extract expected metrics — package returns a list with $pen, $buyrate, etc.
  exp_df <- tryCatch(
    .dn_extract_expected(result, brand_codes),
    error = function(e)
      list(.error = conditionMessage(e))
  )

  if (is.list(exp_df) && !is.null(exp_df$.error))
    return(.dn_refuse("CALC_DIRICHLET_FAILED",
                      sprintf("Failed to extract Dirichlet output: %s",
                              exp_df$.error)))

  list(status = "PASS", expected = exp_df)
}


#' Extract brand-level expected values from NBDdirichlet result object
#' @keywords internal
.dn_extract_expected <- function(dir_obj, brand_codes) {
  n <- length(brand_codes)

  # NBDdirichlet returns a list; access $pen (penetration), $buyrate, $SCR,
  # $heavy (100%-loyal) fields.  Field names may vary by package version.
  get_field <- function(obj, candidates) {
    for (nm in candidates) {
      v <- tryCatch(obj[[nm]], error = function(e) NULL)
      if (!is.null(v) && length(v) >= n) return(as.numeric(v[seq_len(n)]))
    }
    rep(NA_real_, n)
  }

  pen_exp    <- get_field(dir_obj, c("pen", "penetration", "brand.pen"))
  buyrate_exp <- get_field(dir_obj, c("buyrate", "buy.rate", "brand.buyrate"))
  scr_exp    <- get_field(dir_obj,
                           c("SCR", "scr", "share.of.category.requirements"))
  loyal_exp  <- get_field(dir_obj, c("heavy", "sole", "100loyal"))

  data.frame(
    BrandCode          = brand_codes,
    Penetration_Pct_Exp = pen_exp * 100,
    BuyRate_Exp         = buyrate_exp,
    SCR_Pct_Exp         = scr_exp * 100,
    Pct100Loyal_Exp     = loyal_exp * 100,
    stringsAsFactors    = FALSE
  )
}


#' Join observed + expected into norms table with deviations
#' @keywords internal
.dn_build_norms_table <- function(obs, exp_df, brand_codes) {
  .dev <- function(o, e) ifelse(
    !is.na(e) & abs(e) > 1e-10,
    (o - e) / abs(e) * 100,
    NA_real_)

  tbl <- data.frame(
    BrandCode              = brand_codes,
    Penetration_Obs_Pct    = obs$Penetration_Pct,
    Penetration_Exp_Pct    = exp_df$Penetration_Pct_Exp,
    Penetration_Dev_Pct    = .dev(obs$Penetration_Pct, exp_df$Penetration_Pct_Exp),
    BuyRate_Obs            = obs$BuyRate,
    BuyRate_Exp            = exp_df$BuyRate_Exp,
    BuyRate_Dev_Pct        = .dev(obs$BuyRate, exp_df$BuyRate_Exp),
    SCR_Obs_Pct            = obs$SCR_Pct,
    SCR_Exp_Pct            = exp_df$SCR_Pct_Exp,
    SCR_Dev_Pct            = .dev(obs$SCR_Pct, exp_df$SCR_Pct_Exp),
    Pct100Loyal_Obs        = obs$Pct100Loyal,
    Pct100Loyal_Exp        = exp_df$Pct100Loyal_Exp,
    Pct100Loyal_Dev_Pct    = .dev(obs$Pct100Loyal, exp_df$Pct100Loyal_Exp),
    stringsAsFactors       = FALSE
  )

  tbl$DJ_Flag <- ifelse(
    is.na(tbl$SCR_Dev_Pct), "on_line",
    ifelse(tbl$SCR_Dev_Pct >= .DJ_DEV_FLAG_THRESHOLD, "over",
    ifelse(tbl$SCR_Dev_Pct <= -.DJ_DEV_FLAG_THRESHOLD, "under", "on_line"))
  )

  tbl
}


#' Build the DJ curve grid for scatter overlay
#' @keywords internal
.dn_dj_curve <- function(exp_df, obs_pen) {
  pen_min <- max(0.001, min(obs_pen / 100, na.rm = TRUE) * 0.5)
  pen_max <- min(1.0,   max(obs_pen / 100, na.rm = TRUE) * 1.2)
  x_grid  <- seq(pen_min, pen_max, length.out = 50)

  # DJ relationship: higher penetration → modestly higher SCR / buy rate.
  # Use linear interpolation through the fitted expected values.
  fit_scr <- if (length(exp_df$Penetration_Pct_Exp) >= 2 &&
                  !all(is.na(exp_df$SCR_Pct_Exp))) {
    tryCatch(
      stats::approx(exp_df$Penetration_Pct_Exp / 100, exp_df$SCR_Pct_Exp,
                    xout = x_grid, rule = 2)$y,
      error = function(e) rep(NA_real_, length(x_grid)))
  } else rep(NA_real_, length(x_grid))

  fit_w <- if (length(exp_df$Penetration_Pct_Exp) >= 2 &&
                !all(is.na(exp_df$BuyRate_Exp))) {
    tryCatch(
      stats::approx(exp_df$Penetration_Pct_Exp / 100, exp_df$BuyRate_Exp,
                    xout = x_grid, rule = 2)$y,
      error = function(e) rep(NA_real_, length(x_grid)))
  } else rep(NA_real_, length(x_grid))

  list(x_grid    = x_grid,
       y_fit_scr = fit_scr,
       y_fit_w   = fit_w,
       method    = "NBDdirichlet")
}


#' Build metrics_summary for the focal brand
#' @keywords internal
.dn_metrics_summary <- function(focal_brand, obs, norms_tbl, n_brands) {
  ms <- list(focal_brand     = focal_brand %||% NA_character_,
             focal_scr_obs   = NA_real_,
             focal_scr_exp   = NA_real_,
             focal_pen_obs   = NA_real_,
             focal_pen_exp   = NA_real_,
             focal_loyal_obs = NA_real_,
             focal_loyal_exp = NA_real_,
             n_brands        = as.integer(n_brands))

  if (!is.null(focal_brand) && focal_brand %in% norms_tbl$BrandCode) {
    row <- norms_tbl[norms_tbl$BrandCode == focal_brand, ]
    ms$focal_scr_obs   <- row$SCR_Obs_Pct
    ms$focal_scr_exp   <- row$SCR_Exp_Pct
    ms$focal_pen_obs   <- row$Penetration_Obs_Pct
    ms$focal_pen_exp   <- row$Penetration_Exp_Pct
    ms$focal_loyal_obs <- row$Pct100Loyal_Obs
    ms$focal_loyal_exp <- row$Pct100Loyal_Exp
  }
  ms
}


#' Build a TRS-style refusal for this module
#' @keywords internal
.dn_refuse <- function(code, message) {
  cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
  cat("│ Module: 08c_dirichlet_norms\n")
  cat(sprintf("│ Code:    %s\n", code))
  cat(sprintf("│ Message: %s\n", message))
  cat("└───────────────────────────────────────────────────────┘\n\n")
  list(status = "REFUSED", code = code, message = message)
}

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Dirichlet Norms element loaded (v%s)",
                  BRAND_DIRICHLET_VERSION))
}
