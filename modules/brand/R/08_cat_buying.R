# ==============================================================================
# BRAND MODULE - CATEGORY BUYING FREQUENCY ELEMENT
# ==============================================================================
# Computes purchase frequency distribution from the category-level buying
# frequency question (cat_buying.frequency.{CAT} role in QuestionMap).
#
# The question captures ALL respondents (buyers + non-buyers). The "never"
# level is the non-buyer base. This is intentional — the frequency
# distribution doubles as category penetration data.
#
# VERSION: 1.0
# ==============================================================================

CAT_BUYING_VERSION <- "1.0"

# Numeric monthly-equivalent weights for each standard scale level.
# Used to compute mean purchase frequency (e.g. "2.4 times per month").
.CAT_BUY_SCALE_WEIGHTS <- c(
  "cat_buy_scale.several_week" = 12,
  "cat_buy_scale.once_week"    = 4,
  "cat_buy_scale.few_month"    = 2,
  "cat_buy_scale.monthly_less" = 0.5,
  "cat_buy_scale.never"        = 0
)


#' Compute category purchase frequency distribution
#'
#' Transforms a raw single-mention frequency column into a labelled
#' distribution, mean frequency, and buyer percentage. Uses the
#' \code{cat_buy_scale} entries in the OptionMap sheet to map coded
#' values to display labels and numeric equivalents.
#'
#' @param freq_col_data Atomic vector. Raw coded values from the category
#'   buying frequency question (e.g. 1L:5L for a five-point scale).
#'   NA values are excluded from computation.
#' @param option_map Data frame or NULL. The OptionMap sheet from
#'   Survey_Structure.xlsx. Must have columns Scale, ClientCode, Role,
#'   ClientLabel, OrderIndex. Filtered to Scale == "cat_buy_scale" internally.
#'   If NULL, a bare distribution by unique code is returned without labels.
#' @param weights Numeric vector or NULL. Respondent weights.
#'
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{distribution}{Data frame: Code, Label, Role, Order, n, Pct}
#'   \item{mean_freq}{Numeric. Weighted mean monthly purchase frequency.}
#'   \item{pct_buyers}{Numeric. Weighted \% who are not "never buy".}
#'   \item{n_buyers}{Integer. Unweighted count of active buyers.}
#'   \item{n_respondents}{Integer. Total respondents (incl. non-buyers).}
#'
#' @export
run_cat_buying_frequency <- function(freq_col_data, option_map = NULL,
                                     weights = NULL) {

  if (is.null(freq_col_data) || length(freq_col_data) == 0) {
    return(list(
      status  = "REFUSED",
      code    = "DATA_NO_FREQ_DATA",
      message = "No category buying frequency data provided"
    ))
  }

  if (all(is.na(freq_col_data))) {
    return(list(
      status  = "REFUSED",
      code    = "DATA_ALL_NA",
      message = "All category buying frequency values are NA"
    ))
  }

  n_resp <- length(freq_col_data)

  if (!is.null(weights)) {
    if (length(weights) != n_resp) {
      return(list(
        status  = "REFUSED",
        code    = "DATA_WEIGHTS_MISMATCH",
        message = sprintf(
          "Weights length (%d) does not match data length (%d)",
          length(weights), n_resp
        )
      ))
    }
    if (sum(weights, na.rm = TRUE) <= 0) weights <- NULL
  }

  codes_chr <- as.character(freq_col_data)

  # Extract cat_buy_scale rows from option_map
  scale_df <- NULL
  if (!is.null(option_map) && is.data.frame(option_map) &&
      nrow(option_map) > 0 && "Scale" %in% names(option_map)) {
    sub <- option_map[
      !is.na(option_map$Scale) &
        trimws(as.character(option_map$Scale)) == "cat_buy_scale",
      , drop = FALSE]
    if (nrow(sub) > 0) scale_df <- sub
  }

  # Build distribution rows — from scale_df (labelled) or unique values (bare)
  dist_rows <- if (!is.null(scale_df)) {
    # Pre-compute trimmed codes for comparison
    sc_codes <- trimws(as.character(scale_df$ClientCode))

    if ("OrderIndex" %in% names(scale_df)) {
      ord <- suppressWarnings(as.numeric(scale_df$OrderIndex))
      scale_df <- scale_df[order(ifelse(is.na(ord), 999L, ord)), , drop = FALSE]
      sc_codes  <- trimws(as.character(scale_df$ClientCode))
    }

    lapply(seq_len(nrow(scale_df)), function(i) {
      code  <- sc_codes[i]
      label <- if ("ClientLabel" %in% names(scale_df))
        as.character(scale_df$ClientLabel[i]) else code
      role  <- if ("Role" %in% names(scale_df))
        as.character(scale_df$Role[i]) else ""
      in_level  <- !is.na(codes_chr) & codes_chr == code
      n_level   <- sum(in_level)
      pct_level <- if (is.null(weights)) {
        round(n_level / n_resp * 100, 1)
      } else {
        round(sum(weights[in_level], na.rm = TRUE) /
                sum(weights, na.rm = TRUE) * 100, 1)
      }
      list(Code = code, Label = label, Role = role,
           Order = i, n = n_level, Pct = pct_level)
    })
  } else {
    uniq <- sort(unique(codes_chr[!is.na(codes_chr)]))
    lapply(seq_along(uniq), function(i) {
      code      <- uniq[i]
      in_level  <- !is.na(codes_chr) & codes_chr == code
      n_level   <- sum(in_level)
      pct_level <- round(n_level / n_resp * 100, 1)
      list(Code = code, Label = code, Role = "", Order = i,
           n = n_level, Pct = pct_level)
    })
  }

  distribution <- do.call(rbind, lapply(dist_rows, as.data.frame,
                                         stringsAsFactors = FALSE))
  if (is.null(distribution) || nrow(distribution) == 0) {
    return(list(
      status  = "REFUSED",
      code    = "CALC_DIST_EMPTY",
      message = "Could not compute frequency distribution"
    ))
  }

  # --- Mean frequency + buyer counts ---
  mean_freq  <- NA_real_
  n_buyers   <- NA_integer_
  pct_buyers <- NA_real_

  if (!is.null(scale_df) && "Role" %in% names(scale_df)) {
    sc_codes_local <- trimws(as.character(scale_df$ClientCode))
    sc_roles       <- trimws(as.character(scale_df$Role))
    code_to_role   <- stats::setNames(sc_roles, sc_codes_local)

    numeric_vals <- vapply(codes_chr, function(c) {
      if (is.na(c)) return(NA_real_)
      r <- code_to_role[c]
      if (is.na(r) || !r %in% names(.CAT_BUY_SCALE_WEIGHTS)) return(NA_real_)
      unname(.CAT_BUY_SCALE_WEIGHTS[r])
    }, numeric(1))

    valid <- !is.na(numeric_vals)
    if (sum(valid) > 0) {
      mean_freq <- if (is.null(weights)) {
        round(mean(numeric_vals[valid]), 2)
      } else {
        round(sum(weights[valid] * numeric_vals[valid], na.rm = TRUE) /
                sum(weights[valid], na.rm = TRUE), 2)
      }
    }

    # Buyers = anyone whose role is NOT cat_buy_scale.never
    never_codes <- sc_codes_local[sc_roles == "cat_buy_scale.never"]
    is_buyer    <- !is.na(codes_chr) & !codes_chr %in% never_codes
    n_buyers    <- sum(is_buyer)
    pct_buyers  <- if (is.null(weights)) {
      round(n_buyers / n_resp * 100, 1)
    } else {
      round(sum(weights[is_buyer], na.rm = TRUE) /
              sum(weights, na.rm = TRUE) * 100, 1)
    }
  }

  list(
    status        = "PASS",
    distribution  = distribution,
    mean_freq     = mean_freq,
    pct_buyers    = pct_buyers,
    n_buyers      = n_buyers,
    n_respondents = n_resp
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Category Buying element loaded (v%s)",
                  CAT_BUYING_VERSION))
}
