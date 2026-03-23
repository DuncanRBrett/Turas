# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT DATA TRANSFORMER (Layer 1)
# ==============================================================================
#
# Purpose: Transform pricing analysis results into HTML-optimized structure
#          with plain-English callouts for each section.
#
# Pattern: Follows confidence module 4-layer architecture
# Version: 1.0.0
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

#' Transform Pricing Results for HTML Report
#'
#' Converts raw pricing analysis results into a structured format optimized
#' for HTML rendering, with plain-English callouts for each section.
#'
#' @param pricing_results Full results list from run_pricing_analysis()
#' @param config Configuration list
#' @return List with transformed data for each report section
#' @keywords internal
transform_pricing_for_html <- function(pricing_results, config = list()) {

  method <- tolower(pricing_results$method %||% config$analysis_method %||% "unknown")
  currency <- config$currency_symbol %||% "$"
  brand <- config$brand_colour %||% "#323367"

  # Extract sub-results
  results <- pricing_results$results
  synthesis <- pricing_results$synthesis
  segment_results <- pricing_results$segment_results
  ladder_results <- pricing_results$ladder_results
  diagnostics <- pricing_results$diagnostics

  # Build transformed structure
  transformed <- list(
    meta = list(
      method = method,
      currency = currency,
      brand_colour = brand,
      project_name = config$project_name %||% "Pricing Analysis",
      generated = format(Sys.time(), "%Y-%m-%d %H:%M"),
      n_total = diagnostics$n_total %||% 0,
      n_valid = diagnostics$n_valid %||% 0
    ),
    summary = transform_summary(pricing_results, config),
    van_westendorp = NULL,
    gabor_granger = NULL,
    monadic = NULL,
    segments = NULL,
    recommendation = NULL
  )

  # Transform method-specific results

  if (method %in% c("van_westendorp", "both")) {
    vw <- if (method == "both") results$van_westendorp else results
    transformed$van_westendorp <- transform_vw_section(vw, config)
  }

  if (method %in% c("gabor_granger", "both")) {
    gg <- if (method == "both") results$gabor_granger else results
    transformed$gabor_granger <- transform_gg_section(gg, config)
  }

  if (method == "monadic") {
    transformed$monadic <- transform_monadic_section(results, config)
  }

  # Segments
  if (!is.null(segment_results)) {
    transformed$segments <- transform_segments_section(segment_results, config)
  }

  # Recommendation synthesis
  if (!is.null(synthesis)) {
    transformed$recommendation <- transform_recommendation_section(synthesis, config)
  }

  transformed
}


# ==============================================================================
# SUMMARY TRANSFORMER
# ==============================================================================

transform_summary <- function(pricing_results, config) {
  method <- tolower(pricing_results$method %||% "unknown")
  currency <- config$currency_symbol %||% "$"
  synthesis <- pricing_results$synthesis

  summary <- list(
    method_label = switch(method,
      "van_westendorp" = "Van Westendorp Price Sensitivity Meter",
      "gabor_granger" = "Gabor-Granger Demand Analysis",
      "monadic" = "Monadic Price Testing (Logistic Regression)",
      "both" = "Combined Van Westendorp + Gabor-Granger",
      "Pricing Analysis"
    ),
    n_valid = pricing_results$diagnostics$n_valid %||% 0,
    n_total = pricing_results$diagnostics$n_total %||% 0,
    recommended_price = NULL,
    confidence_level = NULL,
    confidence_score = NULL
  )

  if (!is.null(synthesis)) {
    summary$recommended_price <- sprintf("%s%.2f", currency, synthesis$recommendation$price)
    summary$confidence_level <- synthesis$recommendation$confidence
    summary$confidence_score <- synthesis$recommendation$confidence_score
  }

  # Build summary callout
  summary$callout <- build_summary_callout(summary, pricing_results, config)

  summary
}

build_summary_callout <- function(summary, pricing_results, config) {
  currency <- config$currency_symbol %||% "$"
  parts <- character(0)

  # Key result
  if (!is.null(summary$recommended_price)) {
    conf_text <- if (!is.null(summary$confidence_level)) {
      sprintf(" with %s confidence", tolower(summary$confidence_level))
    } else ""
    parts <- c(parts, sprintf(
      '<div class="pr-callout-result">
        <strong>Recommended Price: %s</strong>%s.
        Based on %s analysis of %s valid respondents.
       </div>',
      summary$recommended_price, conf_text,
      tolower(summary$method_label),
      format(summary$n_valid, big.mark = ",")
    ))
  }

  # Method note (use safe method extraction)
  safe_method <- tolower(pricing_results$method %||% config$analysis_method %||% "unknown")
  method_note <- switch(safe_method,
    "van_westendorp" = "Van Westendorp PSM identifies the acceptable price range through four price perception questions. The optimal zone represents where pricing resistance is minimised.",
    "gabor_granger" = "Gabor-Granger analysis constructs a demand curve from sequential purchase intent questions, identifying the price that maximises expected revenue.",
    "monadic" = "Monadic price testing uses logistic regression on randomised price cells to model the relationship between price and purchase probability, yielding a statistically rigorous demand curve.",
    "both" = "This analysis combines Van Westendorp PSM (acceptable range identification) with Gabor-Granger demand curve analysis for triangulated price optimisation.",
    "Pricing analysis completed."
  )
  parts <- c(parts, sprintf(
    '<div class="pr-callout-method">%s</div>', method_note
  ))

  paste(parts, collapse = "\n")
}


# ==============================================================================
# VAN WESTENDORP TRANSFORMER
# ==============================================================================

transform_vw_section <- function(vw_results, config) {
  currency <- config$currency_symbol %||% "$"

  pp <- vw_results$price_points
  section <- list(
    price_points = list(
      pmc = list(value = pp$PMC, label = "PMC", desc = "Point of Marginal Cheapness"),
      opp = list(value = pp$OPP, label = "OPP", desc = "Optimal Price Point"),
      idp = list(value = pp$IDP, label = "IDP", desc = "Indifference Price Point"),
      pme = list(value = pp$PME, label = "PME", desc = "Point of Marginal Expensiveness")
    ),
    acceptable_range = vw_results$acceptable_range,
    optimal_range = vw_results$optimal_range,
    curves = vw_results$curves,
    descriptives = vw_results$descriptives,
    confidence_intervals = vw_results$confidence_intervals,
    nms_results = vw_results$nms_results,
    diagnostics = vw_results$diagnostics
  )

  # Callout
  range_width <- pp$PME - pp$PMC
  range_pct <- range_width / pp$OPP * 100

  callout_parts <- character(0)

  # Key result
  callout_parts <- c(callout_parts, sprintf(
    '<div class="pr-callout-result">
      <strong>Acceptable price range: %s%.2f to %s%.2f</strong> (spread: %s%.2f).
      The optimal price point is <strong>%s%.2f</strong> where price resistance is minimised.
      The indifference price is %s%.2f, representing balanced perception.
     </div>',
    currency, pp$PMC, currency, pp$PME, currency, range_width,
    currency, pp$OPP, currency, pp$IDP
  ))

  # NMS note
  if (!is.null(vw_results$nms_results)) {
    callout_parts <- c(callout_parts, sprintf(
      '<div class="pr-callout-result">
        <strong>NMS Revenue Optimal: %s%.2f</strong>.
        The Newton-Miller-Smith extension calibrates VW results with stated purchase intent
        to identify the revenue-maximising price point.
       </div>',
      currency, vw_results$nms_results$revenue_optimal
    ))
  }

  # Method note
  range_assessment <- if (range_pct > 100) {
    "very wide"
  } else if (range_pct > 50) {
    "moderately wide"
  } else {
    "relatively narrow"
  }
  callout_parts <- c(callout_parts, sprintf(
    '<div class="pr-callout-method">
      The acceptable range is %s (%.0f%% of OPP), suggesting %s.
      Respondents were asked four price perception questions: too cheap, cheap/good value,
      expensive/getting expensive, and too expensive. Cumulative distributions of these
      responses intersect to define the key price points.
     </div>',
    range_assessment, range_pct,
    if (range_pct > 80) "high price tolerance in this market" else "moderate price sensitivity"
  ))

  section$callout <- paste(callout_parts, collapse = "\n")
  section
}


# ==============================================================================
# GABOR-GRANGER TRANSFORMER
# ==============================================================================

transform_gg_section <- function(gg_results, config) {
  currency <- config$currency_symbol %||% "$"

  section <- list(
    demand_curve = gg_results$demand_curve,
    revenue_curve = gg_results$revenue_curve,
    optimal_price = gg_results$optimal_price,
    optimal_price_profit = gg_results$optimal_price_profit,
    elasticity = gg_results$elasticity,
    confidence_intervals = gg_results$confidence_intervals,
    diagnostics = gg_results$diagnostics
  )

  callout_parts <- character(0)

  # Key result
  if (!is.null(gg_results$optimal_price)) {
    op <- gg_results$optimal_price
    callout_parts <- c(callout_parts, sprintf(
      '<div class="pr-callout-result">
        <strong>Revenue-maximising price: %s%.2f</strong> with %.0f%% purchase intent
        (revenue index: %.2f).
       </div>',
      currency, op$price, op$purchase_intent * 100, op$revenue_index
    ))
  }

  if (!is.null(gg_results$optimal_price_profit)) {
    opp <- gg_results$optimal_price_profit
    callout_parts <- c(callout_parts, sprintf(
      '<div class="pr-callout-result">
        <strong>Profit-maximising price: %s%.2f</strong> (profit index: %.2f, margin: %.0f%%).
       </div>',
      currency, opp$price, opp$profit_index, opp$margin * 100
    ))
  }

  # Elasticity summary
  if (!is.null(gg_results$elasticity) && nrow(gg_results$elasticity) > 0) {
    avg_e <- mean(gg_results$elasticity$arc_elasticity, na.rm = TRUE)
    if (!is.na(avg_e) && is.finite(avg_e)) {
      e_class <- if (abs(avg_e) > 1.5) "highly elastic" else if (abs(avg_e) > 1) "moderately elastic" else "inelastic"
      callout_parts <- c(callout_parts, sprintf(
        '<div class="pr-callout-method">
          Average price elasticity: %.2f (%s). %s
         </div>',
        avg_e, e_class,
        if (abs(avg_e) > 1) "Demand is sensitive to price changes; small increases could reduce volume significantly."
        else "Demand is relatively insensitive to price; there may be room to increase price without major volume loss."
      ))
    }
  }

  section$callout <- paste(callout_parts, collapse = "\n")
  section
}


# ==============================================================================
# MONADIC TRANSFORMER
# ==============================================================================

transform_monadic_section <- function(monadic_results, config) {
  currency <- config$currency_symbol %||% "$"

  section <- list(
    demand_curve = monadic_results$demand_curve,
    observed_data = monadic_results$observed_data,
    optimal_price = monadic_results$optimal_price,
    optimal_price_profit = monadic_results$optimal_price_profit,
    elasticity = monadic_results$elasticity,
    model_summary = monadic_results$model_summary,
    confidence_intervals = monadic_results$confidence_intervals,
    diagnostics = monadic_results$diagnostics
  )

  ms <- monadic_results$model_summary
  callout_parts <- character(0)

  # Key result
  callout_parts <- c(callout_parts, sprintf(
    '<div class="pr-callout-result">
      <strong>Revenue-optimal price: %s%.2f</strong> with %.0f%% predicted purchase intent.
      Model type: %s (pseudo-R&sup2;=%.3f, AIC=%.1f).
     </div>',
    currency, monadic_results$optimal_price$price,
    monadic_results$optimal_price$predicted_intent * 100,
    ms$model_type, ms$pseudo_r2, ms$aic
  ))

  if (!is.null(monadic_results$optimal_price_profit)) {
    callout_parts <- c(callout_parts, sprintf(
      '<div class="pr-callout-result">
        <strong>Profit-optimal price: %s%.2f</strong> (profit index: %.2f).
       </div>',
      currency, monadic_results$optimal_price_profit$price,
      monadic_results$optimal_price_profit$profit_index
    ))
  }

  # CI note
  if (!is.null(monadic_results$confidence_intervals$optimal_price_ci)) {
    ci <- monadic_results$confidence_intervals$optimal_price_ci
    callout_parts <- c(callout_parts, sprintf(
      '<div class="pr-callout-result">
        95%% confidence interval for revenue-optimal price: %s%.2f to %s%.2f
        (bootstrap, %d iterations).
       </div>',
      currency, ci[1], currency, ci[2],
      monadic_results$confidence_intervals$n_attempted %||% 1000
    ))
  }

  # Model assessment (guard against NA p-value or pseudo-R2)
  p_val <- ms$price_coefficient_p
  sig_text <- if (!is.null(p_val) && !is.na(p_val) && p_val <= 0.01) {
    "Price effect is highly significant (p < 0.01), providing strong evidence of a price-demand relationship."
  } else if (!is.null(p_val) && !is.na(p_val) && p_val <= 0.05) {
    "Price effect is statistically significant (p < 0.05)."
  } else if (!is.null(p_val) && !is.na(p_val)) {
    sprintf("Price effect is NOT statistically significant (p = %.3f). Interpret the demand curve and optimal price with caution.", p_val)
  } else {
    "Price effect significance could not be assessed."
  }

  pr2 <- ms$pseudo_r2
  fit_text <- if (!is.null(pr2) && !is.na(pr2) && pr2 >= 0.1) {
    "Model fit is reasonable for discrete choice data."
  } else if (!is.null(pr2) && !is.na(pr2) && pr2 >= 0.02) {
    "Model fit is modest but typical for survey-based pricing data."
  } else {
    "Model fit is low, suggesting price alone may not fully explain purchase intent."
  }

  callout_parts <- c(callout_parts, sprintf(
    '<div class="pr-callout-method">
      %s %s
      Each respondent saw one randomly assigned price and reported purchase intent,
      producing unbiased demand estimation via logistic regression.
     </div>',
    sig_text, fit_text
  ))

  # Observed data note
  n_cells <- nrow(monadic_results$observed_data)
  min_cell <- min(monadic_results$observed_data$n)
  max_cell <- max(monadic_results$observed_data$n)
  callout_parts <- c(callout_parts, sprintf(
    '<div class="pr-callout-sampling">
      Data from %d price cells (cell sizes: %d to %d respondents). %s
     </div>',
    n_cells, min_cell, max_cell,
    if (min_cell < 30) "Some cells have fewer than 30 respondents; estimates at those price points may be less stable."
    else "All cells have adequate sample sizes for reliable estimation."
  ))

  section$callout <- paste(callout_parts, collapse = "\n")
  section
}


# ==============================================================================
# SEGMENTS TRANSFORMER
# ==============================================================================

transform_segments_section <- function(segment_results, config) {
  currency <- config$currency_symbol %||% "$"

  section <- list(
    comparison_table = segment_results$comparison_table,
    insights = segment_results$insights %||% character(0)
  )

  callout_parts <- character(0)

  n_segments <- if (!is.null(segment_results$comparison_table)) {
    nrow(segment_results$comparison_table)
  } else 0

  callout_parts <- c(callout_parts, sprintf(
    '<div class="pr-callout-result">
      <strong>%d segments analysed.</strong> %s
     </div>',
    n_segments,
    if (length(segment_results$insights) > 0) segment_results$insights[1] else ""
  ))

  if (length(segment_results$insights) > 1) {
    insight_list <- paste(sprintf("<li>%s</li>", segment_results$insights[-1]), collapse = "\n")
    callout_parts <- c(callout_parts, sprintf(
      '<div class="pr-callout-method"><ul>%s</ul></div>', insight_list
    ))
  }

  section$callout <- paste(callout_parts, collapse = "\n")
  section
}


# ==============================================================================
# RECOMMENDATION TRANSFORMER
# ==============================================================================

transform_recommendation_section <- function(synthesis, config) {
  currency <- config$currency_symbol %||% "$"

  section <- list(
    recommendation = synthesis$recommendation,
    acceptable_range = synthesis$acceptable_range,
    optimal_zone = synthesis$optimal_zone,
    evidence_table = synthesis$evidence_table,
    risks = synthesis$risks,
    executive_summary = synthesis$executive_summary,
    method_prices = synthesis$method_prices
  )

  callout_parts <- character(0)

  # Main recommendation
  rec <- synthesis$recommendation
  callout_parts <- c(callout_parts, sprintf(
    '<div class="pr-callout-result">
      <strong>Recommended price: %s%.2f</strong><br>
      Confidence: %s (%.0f%% score). Source: %s.
     </div>',
    currency, rec$price,
    rec$confidence, rec$confidence_score * 100, rec$source
  ))

  # Range context
  if (!is.null(synthesis$acceptable_range)) {
    ar <- synthesis$acceptable_range
    callout_parts <- c(callout_parts, sprintf(
      '<div class="pr-callout-method">
        Acceptable range: %s%.2f (floor) to %s%.2f (ceiling).
        %s below the floor; %s above the ceiling.
       </div>',
      currency, ar$lower, currency, ar$upper,
      ar$lower_desc, ar$upper_desc
    ))
  }

  # Risks summary
  if (!is.null(synthesis$risks)) {
    risk_items <- character(0)
    if (length(synthesis$risks$downside) > 0) {
      risk_items <- c(risk_items, sprintf("<li>%s</li>", synthesis$risks$downside))
    }
    if (length(risk_items) > 0) {
      callout_parts <- c(callout_parts, sprintf(
        '<div class="pr-callout-sampling">
          <strong>Key risks:</strong><ul>%s</ul>
         </div>',
        paste(risk_items, collapse = "\n")
      ))
    }
  }

  section$callout <- paste(callout_parts, collapse = "\n")
  section
}
