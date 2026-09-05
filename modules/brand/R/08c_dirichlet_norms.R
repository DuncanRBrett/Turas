BRAND_DIRICHLET_VERSION <- "1.2"

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
  warnings_out <- c(warnings_out, dir_result$warnings %||% character(0))

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
    nstar_used       = dir_result$nstar_used,
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


# nstar is where NBDdirichlet truncates the NBD category purchase-count
# distribution. Every closure the engine reads (brand.pen, brand.buyrate, wp,
# Pn, p.rj.n) sums over 0:nstar, and the brand-level S is fitted over the same
# range, so a truncation that drops real mass biases every expected value.
# The package default of 50 is too short for a category bought about ten
# times in the window (IPK Dry Seasonings: kept mass 0.9945, expected SCR off
# by up to 2 points, two of fifteen DJ flags flipped). The ladder doubles
# until the fit converges. Extraction cost is quadratic in nstar
# (brand.buyrate sums 1:n for each n), hence the cap at 400 (about 7 s for
# 15 brands).
.DN_NSTAR_LADDER <- c(50L, 100L, 200L, 400L)
.DN_PN_MASS_MIN  <- 1 - 1e-6


#' Has the Dirichlet fit converged at its nstar?
#'
#' Accepts a fit only when the package's own check passed (\code{error == 0}:
#' kept mass at least 0.99 and truncated mean within 0.1 of M) and the kept
#' mass of the purchase-count distribution is at least
#' \code{.DN_PN_MASS_MIN}, the point past which the expected values no longer
#' move at four decimals.
#' @param dir_obj A \code{dirichlet} object.
#' @return list(ok, mass, nstar).
#' @keywords internal
.dn_nstar_ok <- function(dir_obj) {
  ns   <- as.integer(dir_obj$nstar %||% NA_integer_)
  mass <- tryCatch(
    sum(vapply(0:ns, function(k) as.numeric(dir_obj$Pn(k)), numeric(1))),
    error = function(e) NA_real_)
  err_flag <- suppressWarnings(as.integer(dir_obj$error %||% 1L))
  ok <- isTRUE(err_flag == 0L) && is.finite(mass) && mass >= .DN_PN_MASS_MIN
  list(ok = ok, mass = mass, nstar = ns)
}


#' Call NBDdirichlet and extract expected metrics
#'
#' Fits at each nstar on \code{.DN_NSTAR_LADDER} until \code{.dn_nstar_ok()}
#' accepts the fit. The package reports a truncated distribution with
#' \code{cat()}, not a condition, so each attempt's console output is
#' captured: a retry that then converges must not leave a "too small" line
#' behind. At the top of the ladder a fit the package itself accepts
#' (\code{error == 0}) but that misses the tighter mass check is used with a
#' warning (the element goes PARTIAL); a fit the package rejects is a refusal.
#' @param nstar_ladder Integer vector of nstar values to try, in order.
#' @keywords internal
.dn_call_dirichlet <- function(cat_pen, cat_mean_purch, brand_shares,
                                brand_pen_obs, brand_codes,
                                nstar_ladder = .DN_NSTAR_LADDER) {
  fit_at <- function(ns) tryCatch({
    dir_obj <- NULL
    utils::capture.output(dir_obj <- suppressWarnings(NBDdirichlet::dirichlet(
      cat.pen       = cat_pen,
      cat.buyrate   = cat_mean_purch,
      brand.share   = brand_shares,
      brand.pen.obs = brand_pen_obs,
      nstar         = ns
    )))
    dir_obj
  }, error = function(e) {
    list(.error = conditionMessage(e))
  })

  result <- NULL
  check  <- list(ok = FALSE, mass = NA_real_, nstar = NA_integer_)
  for (ns in nstar_ladder) {
    result <- fit_at(ns)
    if (!is.null(result$.error))
      return(.dn_refuse("CALC_DIRICHLET_FAILED",
                        sprintf("NBDdirichlet::dirichlet() failed at nstar = %d: %s",
                                ns, result$.error)))
    check <- .dn_nstar_ok(result)
    if (isTRUE(check$ok)) break
  }

  fit_warnings <- character(0)
  pkg_ok <- isTRUE(suppressWarnings(as.integer(result$error %||% 1L)) == 0L)
  if (!isTRUE(check$ok) && pkg_ok) {
    fit_warnings <- sprintf(paste0(
      "Dirichlet fit used nstar = %d with kept purchase-count mass %.6f ",
      "(below %.6f); expected values may move in the third decimal"),
      check$nstar, check$mass, .DN_PN_MASS_MIN)
  }
  if (!isTRUE(check$ok) && !pkg_ok)
    return(.dn_refuse("CALC_DIRICHLET_NSTAR",
                      sprintf(paste0(
                        "The NBD purchase-count distribution does not converge ",
                        "by nstar = %d (kept mass %.5f, M = %.3f purchases per ",
                        "respondent). The category is bought too often for the ",
                        "Dirichlet norm to be fitted here; the observed metrics ",
                        "are still valid but the norm comparison cannot be shown."),
                        check$nstar, check$mass, as.numeric(result$M %||% NA_real_))))

  # Extract the theoretical brand metrics through the object's function API
  # (see .dn_extract_expected). A failure here is a refusal, never NA-under-PASS.
  exp_df <- tryCatch(
    .dn_extract_expected(result, brand_codes),
    error = function(e)
      list(.error = conditionMessage(e))
  )

  if (is.list(exp_df) && !is.null(exp_df$.error))
    return(.dn_refuse("CALC_DIRICHLET_EXTRACT",
                      sprintf("Failed to extract Dirichlet expected values: %s",
                              exp_df$.error)))

  bad <- .dn_expected_problems(exp_df)
  if (length(bad) > 0)
    return(.dn_refuse("CALC_DIRICHLET_EXTRACT",
                      paste0("Dirichlet expected values are missing or out of range: ",
                             paste(bad, collapse = "; "),
                             ". The observed metrics are still valid but the norm ",
                             "comparison cannot be shown for this category.")))

  list(status = "PASS", expected = exp_df,
       nstar_used = check$nstar, pn_mass = check$mass,
       warnings = fit_warnings)
}


#' Extract brand-level expected values from NBDdirichlet result object
#'
#' The \code{dirichlet} object carries no data fields for the brand-level
#' theoretical metrics; it carries closures. Per brand index \code{j}:
#' \itemize{
#'   \item \code{brand.pen(j)}: theoretical penetration (fraction of the
#'     category population buying brand j in the base period);
#'   \item \code{brand.buyrate(j)}: theoretical purchase frequency among
#'     brand j buyers;
#'   \item \code{wp(j)}: theoretical category purchase frequency among
#'     brand j buyers, so SCR = \code{brand.buyrate(j) / wp(j)};
#'   \item 100 percent loyal: the share of brand j buyers whose every
#'     category purchase was brand j, computed from the object's own
#'     \code{Pn(n)} (category purchase-count distribution) and
#'     \code{p.rj.n(n, n, j)} (all n purchases go to j), summed over
#'     \code{1:nstar} and divided by \code{brand.pen(j)}.
#' }
#' None of these closures vectorise over \code{j}; each is called once per
#' brand. \code{summary.dirichlet()} is deliberately not used: it rounds to
#' two decimals and mutates the object's period through \code{period.set()}.
#'
#' A previous version probed \code{dir_obj[["pen"]]} and similar fields
#' that the package never defines, so every expected value was NA under a
#' PASS status (production review 2026-07-12, C1).
#' @keywords internal
.dn_extract_expected <- function(dir_obj, brand_codes) {
  n <- length(brand_codes)

  needed <- c("brand.pen", "brand.buyrate", "wp", "Pn", "p.rj.n", "nstar")
  missing <- needed[!vapply(needed, function(nm) !is.null(dir_obj[[nm]]),
                            logical(1))]
  if (length(missing) > 0)
    stop(sprintf("dirichlet object lacks %s", paste(missing, collapse = ", ")))

  n_obj <- dir_obj$nbrand %||% NA_integer_
  if (!is.na(n_obj) && n_obj != n)
    stop(sprintf("dirichlet object has %d brands, expected %d", n_obj, n))

  per_brand <- function(f) vapply(seq_len(n), function(j) as.numeric(f(j)),
                                  numeric(1))

  pen_exp     <- per_brand(dir_obj$brand.pen)
  buyrate_exp <- per_brand(dir_obj$brand.buyrate)
  wp_exp      <- per_brand(dir_obj$wp)
  scr_exp     <- ifelse(is.finite(wp_exp) & wp_exp > 0,
                        buyrate_exp / wp_exp, NA_real_)

  n_star  <- as.integer(dir_obj$nstar)
  pn_vec  <- vapply(seq_len(n_star), function(k) as.numeric(dir_obj$Pn(k)),
                    numeric(1))
  loyal_exp <- vapply(seq_len(n), function(j) {
    all_j <- vapply(seq_len(n_star),
                    function(k) as.numeric(dir_obj$p.rj.n(k, k, j)),
                    numeric(1))
    if (!is.finite(pen_exp[j]) || pen_exp[j] <= 0) return(NA_real_)
    sum(pn_vec * all_j) / pen_exp[j]
  }, numeric(1))

  data.frame(
    BrandCode           = brand_codes,
    Penetration_Pct_Exp = pen_exp * 100,
    BuyRate_Exp         = buyrate_exp,
    SCR_Pct_Exp         = scr_exp * 100,
    Pct100Loyal_Exp     = loyal_exp * 100,
    stringsAsFactors    = FALSE
  )
}


#' Name the expected-value columns that are missing or out of range
#'
#' Returns character(0) when every expected value is finite and inside its
#' valid range (penetration, SCR and loyalty in 0 to 100; buy rate above 0).
#' @keywords internal
.dn_expected_problems <- function(exp_df) {
  checks <- list(
    Penetration_Pct_Exp = c(0, 100),
    BuyRate_Exp         = c(0, Inf),
    SCR_Pct_Exp         = c(0, 100),
    Pct100Loyal_Exp     = c(0, 100)
  )
  problems <- character(0)
  for (col in names(checks)) {
    v <- exp_df[[col]]
    if (is.null(v)) { problems <- c(problems, paste(col, "absent")); next }
    rng <- checks[[col]]
    ok <- is.finite(v) & v >= rng[1] & v <= rng[2]
    if (!all(ok))
      problems <- c(problems, sprintf("%s (%d of %d values)", col,
                                      sum(!ok), length(v)))
  }
  problems
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
                    xout = x_grid, rule = 2, ties = mean)$y,
      error = function(e) rep(NA_real_, length(x_grid)))
  } else rep(NA_real_, length(x_grid))

  fit_w <- if (length(exp_df$Penetration_Pct_Exp) >= 2 &&
                !all(is.na(exp_df$BuyRate_Exp))) {
    tryCatch(
      stats::approx(exp_df$Penetration_Pct_Exp / 100, exp_df$BuyRate_Exp,
                    xout = x_grid, rule = 2, ties = mean)$y,
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
