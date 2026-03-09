# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT TABLE BUILDER (Layer 2)
# ==============================================================================
#
# Purpose: Build HTML tables from transformed pricing data
# Pattern: Follows confidence module 4-layer architecture
# Version: 1.0.0
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

htmlEscape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# VAN WESTENDORP TABLES
# ==============================================================================

#' Build VW Price Points Table
#' @param vw_data Transformed VW section from data transformer
#' @param currency Currency symbol
#' @return HTML table string
#' @keywords internal
build_vw_price_points_table <- function(vw_data, currency = "$") {

  pp <- vw_data$price_points

  rows <- sprintf(
    '<tr><td class="pr-td pr-label-col">%s</td><td class="pr-td">%s</td><td class="pr-td pr-num">%s%.2f</td></tr>',
    c(pp$pmc$label, pp$opp$label, pp$idp$label, pp$pme$label),
    c(pp$pmc$desc, pp$opp$desc, pp$idp$desc, pp$pme$desc),
    rep(currency, 4),
    c(pp$pmc$value, pp$opp$value, pp$idp$value, pp$pme$value)
  )

  # Add range rows
  if (!is.null(vw_data$acceptable_range)) {
    ar <- vw_data$acceptable_range
    rows <- c(rows, sprintf(
      '<tr class="pr-tr-section"><td class="pr-td pr-label-col" colspan="3"><strong>Ranges</strong></td></tr>'
    ))
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-label-col">Acceptable Range</td><td class="pr-td">Floor to ceiling</td><td class="pr-td pr-num">%s%.2f &ndash; %s%.2f</td></tr>',
      currency, ar$lower, currency, ar$upper
    ))
  }
  if (!is.null(vw_data$optimal_range)) {
    or <- vw_data$optimal_range
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-label-col">Optimal Zone</td><td class="pr-td">Sweet spot</td><td class="pr-td pr-num">%s%.2f &ndash; %s%.2f</td></tr>',
      currency, or$lower, currency, or$upper
    ))
  }

  # NMS
  if (!is.null(vw_data$nms_results)) {
    nms <- vw_data$nms_results
    rows <- c(rows, sprintf(
      '<tr class="pr-tr-section"><td class="pr-td pr-label-col" colspan="3"><strong>NMS Extension</strong></td></tr>'
    ))
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-label-col">Trial Optimal</td><td class="pr-td">Maximises trial/adoption</td><td class="pr-td pr-num">%s%.2f</td></tr>',
      currency, nms$trial_optimal
    ))
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-label-col">Revenue Optimal</td><td class="pr-td">Maximises expected revenue</td><td class="pr-td pr-num">%s%.2f</td></tr>',
      currency, nms$revenue_optimal
    ))
  }

  sprintf(
    '<table class="pr-table">
      <thead><tr>
        <th class="pr-th pr-label-col">Metric</th>
        <th class="pr-th">Description</th>
        <th class="pr-th pr-num">Price</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}

#' Build VW Confidence Intervals Table
#' @keywords internal
build_vw_ci_table <- function(vw_data, currency = "$") {
  ci <- vw_data$confidence_intervals
  if (is.null(ci) || !is.data.frame(ci)) return("")

  rows <- character(0)
  for (i in seq_len(nrow(ci))) {
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-label-col">%s</td><td class="pr-td pr-num">%s%.2f</td><td class="pr-td pr-num">%s%.2f</td><td class="pr-td pr-num">%s%.2f</td><td class="pr-td pr-num">%s%.2f</td></tr>',
      htmlEscape(as.character(ci[i, 1])),
      currency, as.numeric(ci[i, 2]),
      currency, as.numeric(ci[i, 3]),
      currency, as.numeric(ci[i, 4]),
      currency, as.numeric(ci[i, 5])
    ))
  }

  sprintf(
    '<table class="pr-table pr-table-compact">
      <thead><tr>
        <th class="pr-th pr-label-col">Price Point</th>
        <th class="pr-th pr-num">Estimate</th>
        <th class="pr-th pr-num">Lower CI</th>
        <th class="pr-th pr-num">Upper CI</th>
        <th class="pr-th pr-num">CI Width</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}


# ==============================================================================
# GABOR-GRANGER TABLES
# ==============================================================================

#' Build GG Demand Curve Table
#' @keywords internal
build_gg_demand_table <- function(gg_data, currency = "$") {
  dc <- gg_data$demand_curve
  if (is.null(dc) || !is.data.frame(dc)) return("")

  rows <- character(0)
  for (i in seq_len(nrow(dc))) {
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-num">%s%.2f</td><td class="pr-td pr-num">%.1f%%</td><td class="pr-td pr-num">%.2f</td>%s</tr>',
      currency, dc$price[i],
      dc$purchase_intent[i] * 100,
      dc$revenue_index[i],
      if ("profit_index" %in% names(dc) && !all(is.na(dc$profit_index))) {
        sprintf('<td class="pr-td pr-num">%.2f</td>', dc$profit_index[i])
      } else ""
    ))
  }

  has_profit <- "profit_index" %in% names(dc) && !all(is.na(dc$profit_index))

  sprintf(
    '<table class="pr-table pr-table-compact">
      <thead><tr>
        <th class="pr-th pr-num">Price</th>
        <th class="pr-th pr-num">Purchase Intent</th>
        <th class="pr-th pr-num">Revenue Index</th>
        %s
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    if (has_profit) '<th class="pr-th pr-num">Profit Index</th>' else "",
    paste(rows, collapse = "\n")
  )
}

#' Build GG Optimal Price Table
#' @keywords internal
build_gg_optimal_table <- function(gg_data, currency = "$") {
  op <- gg_data$optimal_price
  if (is.null(op)) return("")

  rows <- sprintf(
    '<tr><td class="pr-td pr-label-col">Revenue-Maximising Price</td><td class="pr-td pr-num">%s%.2f</td></tr>
     <tr><td class="pr-td pr-label-col">Purchase Intent</td><td class="pr-td pr-num">%.1f%%</td></tr>
     <tr><td class="pr-td pr-label-col">Revenue Index</td><td class="pr-td pr-num">%.2f</td></tr>',
    currency, op$price, op$purchase_intent * 100, op$revenue_index
  )

  if (!is.null(gg_data$optimal_price_profit)) {
    opp <- gg_data$optimal_price_profit
    rows <- c(rows, sprintf(
      '<tr class="pr-tr-section"><td class="pr-td pr-label-col" colspan="2"><strong>Profit Optimisation</strong></td></tr>
       <tr><td class="pr-td pr-label-col">Profit-Maximising Price</td><td class="pr-td pr-num">%s%.2f</td></tr>
       <tr><td class="pr-td pr-label-col">Profit Index</td><td class="pr-td pr-num">%.2f</td></tr>
       <tr><td class="pr-td pr-label-col">Margin</td><td class="pr-td pr-num">%.1f%%</td></tr>',
      currency, opp$price, opp$profit_index, opp$margin * 100
    ))
  }

  sprintf(
    '<table class="pr-table">
      <thead><tr>
        <th class="pr-th pr-label-col">Metric</th>
        <th class="pr-th pr-num">Value</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}

#' Build GG Elasticity Table
#' @keywords internal
build_gg_elasticity_table <- function(gg_data, currency = "$") {
  el <- gg_data$elasticity
  if (is.null(el) || !is.data.frame(el) || nrow(el) == 0) return("")

  rows <- character(0)
  for (i in seq_len(nrow(el))) {
    class_badge <- switch(el$classification[i],
      "elastic" = '<span class="pr-badge-elastic">Elastic</span>',
      "inelastic" = '<span class="pr-badge-inelastic">Inelastic</span>',
      '<span class="pr-badge-unitary">Unitary</span>'
    )
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-num">%s%.2f &ndash; %s%.2f</td><td class="pr-td pr-num">%.2f</td><td class="pr-td">%s</td></tr>',
      currency, el$price_low[i], currency, el$price_high[i],
      el$arc_elasticity[i], class_badge
    ))
  }

  sprintf(
    '<table class="pr-table pr-table-compact">
      <thead><tr>
        <th class="pr-th pr-num">Price Range</th>
        <th class="pr-th pr-num">Arc Elasticity</th>
        <th class="pr-th">Classification</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}


# ==============================================================================
# MONADIC TABLES
# ==============================================================================

#' Build Monadic Model Summary Table
#' @keywords internal
build_monadic_model_table <- function(monadic_data) {
  ms <- monadic_data$model_summary
  if (is.null(ms)) return("")

  sig_badge <- if (ms$price_coefficient_p <= 0.01) {
    '<span class="pr-badge-good">p &lt; 0.01</span>'
  } else if (ms$price_coefficient_p <= 0.05) {
    '<span class="pr-badge-warn">p &lt; 0.05</span>'
  } else {
    '<span class="pr-badge-poor">Not significant</span>'
  }

  rows <- sprintf(
    '<tr><td class="pr-td pr-label-col">Model Type</td><td class="pr-td pr-num">%s</td></tr>
     <tr><td class="pr-td pr-label-col">Observations</td><td class="pr-td pr-num">%s</td></tr>
     <tr><td class="pr-td pr-label-col">Pseudo R&sup2;</td><td class="pr-td pr-num">%.4f</td></tr>
     <tr><td class="pr-td pr-label-col">AIC</td><td class="pr-td pr-num">%.1f</td></tr>
     <tr><td class="pr-td pr-label-col">Null Deviance</td><td class="pr-td pr-num">%.2f</td></tr>
     <tr><td class="pr-td pr-label-col">Residual Deviance</td><td class="pr-td pr-num">%.2f</td></tr>
     <tr><td class="pr-td pr-label-col">Price Coefficient</td><td class="pr-td pr-num">%s</td></tr>',
    htmlEscape(ms$model_type),
    format(ms$n_observations, big.mark = ","),
    ms$pseudo_r2, ms$aic, ms$null_deviance, ms$residual_deviance,
    sig_badge
  )

  sprintf(
    '<table class="pr-table">
      <thead><tr>
        <th class="pr-th pr-label-col">Metric</th>
        <th class="pr-th pr-num">Value</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}

#' Build Monadic Observed Data Table
#' @keywords internal
build_monadic_observed_table <- function(monadic_data, currency = "$") {
  obs <- monadic_data$observed_data
  if (is.null(obs) || !is.data.frame(obs)) return("")

  rows <- character(0)
  for (i in seq_len(nrow(obs))) {
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-num">%s%.2f</td><td class="pr-td pr-num">%d</td><td class="pr-td pr-num">%.1f%%</td></tr>',
      currency, obs$price[i], obs$n[i], obs$observed_intent[i] * 100
    ))
  }

  sprintf(
    '<table class="pr-table pr-table-compact">
      <thead><tr>
        <th class="pr-th pr-num">Price</th>
        <th class="pr-th pr-num">n</th>
        <th class="pr-th pr-num">Observed Intent</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}

#' Build Monadic Optimal Price Table
#' @keywords internal
build_monadic_optimal_table <- function(monadic_data, currency = "$") {
  op <- monadic_data$optimal_price
  if (is.null(op)) return("")

  rows <- sprintf(
    '<tr><td class="pr-td pr-label-col">Revenue-Optimal Price</td><td class="pr-td pr-num">%s%.2f</td></tr>
     <tr><td class="pr-td pr-label-col">Predicted Intent</td><td class="pr-td pr-num">%.1f%%</td></tr>
     <tr><td class="pr-td pr-label-col">Revenue Index</td><td class="pr-td pr-num">%.2f</td></tr>',
    currency, op$price, op$predicted_intent * 100, op$revenue_index
  )

  if (!is.null(monadic_data$optimal_price_profit)) {
    opp <- monadic_data$optimal_price_profit
    rows <- c(rows, sprintf(
      '<tr class="pr-tr-section"><td class="pr-td pr-label-col" colspan="2"><strong>Profit Optimisation</strong></td></tr>
       <tr><td class="pr-td pr-label-col">Profit-Optimal Price</td><td class="pr-td pr-num">%s%.2f</td></tr>
       <tr><td class="pr-td pr-label-col">Predicted Intent</td><td class="pr-td pr-num">%.1f%%</td></tr>
       <tr><td class="pr-td pr-label-col">Profit Index</td><td class="pr-td pr-num">%.2f</td></tr>',
      currency, opp$price, opp$predicted_intent * 100, opp$profit_index
    ))
  }

  # Confidence intervals
  if (!is.null(monadic_data$confidence_intervals$optimal_price_ci)) {
    ci <- monadic_data$confidence_intervals$optimal_price_ci
    rows <- c(rows, sprintf(
      '<tr class="pr-tr-section"><td class="pr-td pr-label-col" colspan="2"><strong>Confidence Intervals</strong></td></tr>
       <tr><td class="pr-td pr-label-col">Revenue-Optimal CI</td><td class="pr-td pr-num">%s%.2f &ndash; %s%.2f</td></tr>',
      currency, ci[1], currency, ci[2]
    ))
  }

  sprintf(
    '<table class="pr-table">
      <thead><tr>
        <th class="pr-th pr-label-col">Metric</th>
        <th class="pr-th pr-num">Value</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}


# ==============================================================================
# RECOMMENDATION & EVIDENCE TABLES
# ==============================================================================

#' Build Evidence Table
#' @keywords internal
build_evidence_html_table <- function(evidence_table, currency = "$") {
  if (is.null(evidence_table) || !is.data.frame(evidence_table) || nrow(evidence_table) == 0) return("")

  rows <- character(0)
  for (i in seq_len(nrow(evidence_table))) {
    rows <- c(rows, sprintf(
      '<tr><td class="pr-td pr-label-col">%s</td><td class="pr-td">%s</td><td class="pr-td pr-num">%s</td><td class="pr-td">%s</td></tr>',
      htmlEscape(evidence_table$method[i]),
      htmlEscape(evidence_table$metric[i]),
      htmlEscape(evidence_table$value[i]),
      htmlEscape(evidence_table$interpretation[i])
    ))
  }

  sprintf(
    '<table class="pr-table">
      <thead><tr>
        <th class="pr-th pr-label-col">Method</th>
        <th class="pr-th">Metric</th>
        <th class="pr-th pr-num">Value</th>
        <th class="pr-th">Interpretation</th>
      </tr></thead>
      <tbody>%s</tbody>
     </table>',
    paste(rows, collapse = "\n")
  )
}

#' Build Segment Comparison Table
#' @keywords internal
build_segment_comparison_table <- function(segment_data) {
  ct <- segment_data$comparison_table
  if (is.null(ct) || !is.data.frame(ct) || nrow(ct) == 0) return("")

  # Build headers from column names
  headers <- paste(sprintf('<th class="pr-th">%s</th>', htmlEscape(names(ct))), collapse = "\n")

  rows <- character(0)
  for (i in seq_len(nrow(ct))) {
    cells <- character(0)
    for (j in seq_len(ncol(ct))) {
      val <- ct[i, j]
      cls <- if (j == 1) "pr-td pr-label-col" else "pr-td pr-num"
      cells <- c(cells, sprintf('<td class="%s">%s</td>', cls, htmlEscape(as.character(val))))
    }
    rows <- c(rows, sprintf('<tr>%s</tr>', paste(cells, collapse = "")))
  }

  sprintf(
    '<table class="pr-table pr-table-compact">
      <thead><tr>%s</tr></thead>
      <tbody>%s</tbody>
     </table>',
    headers,
    paste(rows, collapse = "\n")
  )
}
