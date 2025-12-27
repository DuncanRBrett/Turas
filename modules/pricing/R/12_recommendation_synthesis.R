# ==============================================================================
# TURAS PRICING MODULE - RECOMMENDATION SYNTHESIS
# ==============================================================================
#
# Purpose: Generate executive summary synthesizing all analyses into
#          clear recommendation with confidence assessment
# Version: 1.0.0
# Date: 2025-12-11
#
# ==============================================================================

#' Synthesize Pricing Recommendation
#'
#' Combines outputs from multiple pricing methods into unified
#' recommendation with confidence assessment and key insights.
#'
#' @param vw_results Van Westendorp results (optional)
#' @param gg_results Gabor-Granger results (optional)
#' @param segment_results Segmentation results (optional)
#' @param ladder_results Price ladder results (optional)
#' @param config Configuration list
#'
#' @return List containing recommendation, supporting_evidence,
#'         confidence, risks, executive_summary
#'
#' @export
synthesize_recommendation <- function(vw_results = NULL,
                                      gg_results = NULL,
                                      segment_results = NULL,
                                      ladder_results = NULL,
                                      config = NULL) {

  # ============================================================================
  # STEP 1: Validate inputs
  # ============================================================================

  if (is.null(vw_results) && is.null(gg_results)) {
    pricing_refuse(
      code = "DATA_NO_RESULTS",
      title = "No Analysis Results Provided",
      problem = "At least one of vw_results or gg_results must be provided",
      why_it_matters = "Cannot synthesize recommendation without pricing analysis results",
      how_to_fix = c(
        "Run Van Westendorp or Gabor-Granger analysis first",
        "Pass the results to synthesize_recommendation()"
      ),
      expected = "vw_results and/or gg_results"
    )
  }

  synth_config <- config$synthesis %||% list()
  currency <- config$currency_symbol %||% synth_config$currency_symbol %||% "$"
  project_name <- config$project_name %||% synth_config$project_name %||% "Pricing Analysis"

  # ============================================================================
  # STEP 2: Extract price recommendations from each method
  # ============================================================================

  method_prices <- list()

  if (!is.null(vw_results)) {
    method_prices$vw_opp <- list(
      price = vw_results$price_points$OPP,
      label = "Van Westendorp OPP",
      description = "Optimal Price Point - minimal resistance"
    )
    method_prices$vw_idp <- list(
      price = vw_results$price_points$IDP,
      label = "Van Westendorp IDP",
      description = "Indifference Price - balanced perception"
    )
    method_prices$vw_midpoint <- list(
      price = (vw_results$price_points$OPP + vw_results$price_points$IDP) / 2,
      label = "VW Optimal Zone Midpoint",
      description = "Center of optimal zone"
    )

    # NMS if available
    if (!is.null(vw_results$nms_results)) {
      method_prices$nms_revenue <- list(
        price = vw_results$nms_results$revenue_optimal,
        label = "NMS Revenue Optimal",
        description = "Revenue-maximizing price (purchase calibrated)"
      )
    }
  }

  if (!is.null(gg_results)) {
    method_prices$gg_optimal <- list(
      price = gg_results$optimal_price$price,
      label = "Gabor-Granger Optimal",
      description = sprintf("Revenue-maximizing (%.0f%% intent)",
                            gg_results$optimal_price$purchase_intent * 100)
    )
  }

  # ============================================================================
  # STEP 3: Calculate consensus price
  # ============================================================================

  prices <- sapply(method_prices, function(x) x$price)

  # Use NMS or GG as primary if available (behaviorally calibrated)
  if (!is.null(method_prices$nms_revenue)) {
    primary_price <- method_prices$nms_revenue$price
    primary_source <- "NMS revenue optimal"
  } else if (!is.null(method_prices$gg_optimal)) {
    primary_price <- method_prices$gg_optimal$price
    primary_source <- "Gabor-Granger optimal"
  } else {
    primary_price <- method_prices$vw_midpoint$price
    primary_source <- "Van Westendorp optimal zone midpoint"
  }

  # Apply constraints
  if (!is.null(synth_config$price_floor)) {
    if (primary_price < synth_config$price_floor) {
      primary_price <- synth_config$price_floor
      primary_source <- paste(primary_source, "(constrained to floor)")
    }
  }

  if (!is.null(synth_config$price_ceiling)) {
    if (primary_price > synth_config$price_ceiling) {
      primary_price <- synth_config$price_ceiling
      primary_source <- paste(primary_source, "(constrained to ceiling)")
    }
  }

  # Round to psychological price point
  recommended_price <- round_to_psychological(primary_price)

  # ============================================================================
  # STEP 4: Assess confidence
  # ============================================================================

  confidence <- assess_recommendation_confidence(
    method_prices = method_prices,
    recommended_price = recommended_price,
    vw_results = vw_results,
    gg_results = gg_results
  )

  # ============================================================================
  # STEP 5: Extract acceptable range
  # ============================================================================

  acceptable_range <- NULL
  optimal_zone <- NULL

  if (!is.null(vw_results)) {
    acceptable_range <- list(
      lower = vw_results$price_points$PMC,
      upper = vw_results$price_points$PME,
      lower_desc = "Below this, quality concerns arise",
      upper_desc = "Above this, most find too expensive"
    )

    optimal_zone <- list(
      lower = vw_results$price_points$OPP,
      upper = vw_results$price_points$IDP
    )
  }

  # ============================================================================
  # STEP 6: Build supporting evidence table
  # ============================================================================

  evidence_table <- build_evidence_table(
    method_prices = method_prices,
    vw_results = vw_results,
    gg_results = gg_results,
    recommended_price = recommended_price,
    currency = currency
  )

  # ============================================================================
  # STEP 7: Generate segment notes
  # ============================================================================

  segment_notes <- NULL

  if (!is.null(segment_results)) {
    segment_notes <- list(
      comparison = segment_results$comparison_table,
      insights = segment_results$insights
    )
  }

  # ============================================================================
  # STEP 8: Generate tier notes
  # ============================================================================

  tier_notes <- NULL

  if (!is.null(ladder_results)) {
    tier_notes <- list(
      tiers = ladder_results$tier_table,
      notes = ladder_results$notes
    )
  }

  # ============================================================================
  # STEP 9: Identify risks
  # ============================================================================

  risks <- identify_pricing_risks(
    recommended_price = recommended_price,
    vw_results = vw_results,
    gg_results = gg_results,
    confidence = confidence
  )

  # ============================================================================
  # STEP 10: Generate executive summary text
  # ============================================================================

  executive_summary <- generate_executive_summary(
    recommended_price = recommended_price,
    primary_source = primary_source,
    confidence = confidence,
    acceptable_range = acceptable_range,
    optimal_zone = optimal_zone,
    gg_results = gg_results,
    segment_notes = segment_notes,
    tier_notes = tier_notes,
    risks = risks,
    currency = currency,
    project_name = project_name
  )

  # ============================================================================
  # STEP 11: Return results
  # ============================================================================

  list(
    recommendation = list(
      price = recommended_price,
      source = primary_source,
      confidence = confidence$level,
      confidence_score = confidence$score
    ),
    acceptable_range = acceptable_range,
    optimal_zone = optimal_zone,
    evidence_table = evidence_table,
    segment_notes = segment_notes,
    tier_notes = tier_notes,
    risks = risks,
    executive_summary = executive_summary,
    method_prices = method_prices
  )
}


#' Round Price to Psychological Point
#'
#' @param price Raw price
#' @return Rounded price ending in .99 or .95
#' @keywords internal
round_to_psychological <- function(price) {

  # Determine magnitude
  if (price < 10) {
    # Under $10: round to X.99
    rounded <- floor(price) + 0.99
  } else if (price < 100) {
    # $10-99: round to X9.99 or X4.99
    base <- floor(price / 5) * 5
    if (price - base < 2.5) {
      rounded <- base - 0.01
    } else {
      rounded <- base + 4.99
    }
  } else {
    # $100+: round to nearest $5 ending in .99
    base <- round(price / 5) * 5
    rounded <- base - 0.01
  }

  # Don't round more than 10% from original
  if (abs(rounded - price) / price > 0.10) {
    rounded <- round(price, 2)
  }

  return(rounded)
}


#' Assess Recommendation Confidence
#'
#' @param method_prices List of prices from each method
#' @param recommended_price Final recommended price
#' @param vw_results Van Westendorp results
#' @param gg_results Gabor-Granger results
#' @return List with score, level, and factors
#' @keywords internal
assess_recommendation_confidence <- function(method_prices, recommended_price,
                                             vw_results, gg_results) {

  factors <- list()
  scores <- numeric(0)

  # Factor 1: Method agreement
  prices <- sapply(method_prices, function(x) x$price)
  cv <- sd(prices) / mean(prices)

  if (cv < 0.08) {
    factors$method_agreement <- "Strong agreement across methods (<8% variation)"
    scores <- c(scores, 1.0)
  } else if (cv < 0.15) {
    factors$method_agreement <- "Moderate agreement across methods (8-15% variation)"
    scores <- c(scores, 0.7)
  } else {
    factors$method_agreement <- sprintf("Methods show variation (%.0f%% CV) - interpret with caution", cv * 100)
    scores <- c(scores, 0.4)
  }

  # Factor 2: Sample size
  n_total <- 0
  if (!is.null(vw_results)) {
    n_total <- max(n_total, vw_results$diagnostics$n_valid)
  }
  if (!is.null(gg_results)) {
    n_total <- max(n_total, gg_results$diagnostics$n_respondents)
  }

  if (n_total >= 300) {
    factors$sample_size <- sprintf("Adequate sample size (n=%d)", n_total)
    scores <- c(scores, 1.0)
  } else if (n_total >= 100) {
    factors$sample_size <- sprintf("Acceptable sample size (n=%d)", n_total)
    scores <- c(scores, 0.7)
  } else {
    factors$sample_size <- sprintf("Low sample size (n=%d) - results may be unstable", n_total)
    scores <- c(scores, 0.4)
  }

  # Factor 3: Data quality (VW violations)
  if (!is.null(vw_results)) {
    violation_rate <- vw_results$diagnostics$violation_rate

    if (violation_rate < 0.05) {
      factors$data_quality <- "Good data quality (<5% logical violations)"
      scores <- c(scores, 1.0)
    } else if (violation_rate < 0.15) {
      factors$data_quality <- sprintf("Acceptable data quality (%.0f%% violations)", violation_rate * 100)
      scores <- c(scores, 0.7)
    } else {
      factors$data_quality <- sprintf("Data quality concerns (%.0f%% violations)", violation_rate * 100)
      scores <- c(scores, 0.4)
    }
  }

  # Factor 4: Price within optimal zone
  if (!is.null(vw_results)) {
    opp <- vw_results$price_points$OPP
    idp <- vw_results$price_points$IDP

    if (recommended_price >= opp && recommended_price <= idp) {
      factors$zone_fit <- "Recommended price within optimal zone"
      scores <- c(scores, 1.0)
    } else if (recommended_price >= vw_results$price_points$PMC &&
               recommended_price <= vw_results$price_points$PME) {
      factors$zone_fit <- "Recommended price within acceptable range (outside optimal zone)"
      scores <- c(scores, 0.6)
    } else {
      factors$zone_fit <- "Recommended price outside acceptable range - unusual"
      scores <- c(scores, 0.3)
    }
  }

  # Factor 5: Method coverage
  n_methods <- length(method_prices)
  if (n_methods >= 4) {
    factors$method_coverage <- "Multiple methods provide triangulation"
    scores <- c(scores, 1.0)
  } else if (n_methods >= 2) {
    factors$method_coverage <- "Two methods available for comparison"
    scores <- c(scores, 0.7)
  } else {
    factors$method_coverage <- "Single method only - no triangulation"
    scores <- c(scores, 0.4)
  }

  # Calculate overall score
  overall_score <- mean(scores)

  # Determine level
  if (overall_score >= 0.75) {
    level <- "HIGH"
  } else if (overall_score >= 0.55) {
    level <- "MEDIUM"
  } else {
    level <- "LOW"
  }

  list(
    score = round(overall_score, 2),
    level = level,
    factors = factors
  )
}


#' Build Supporting Evidence Table
#'
#' @param method_prices List of method prices
#' @param vw_results Van Westendorp results
#' @param gg_results Gabor-Granger results
#' @param recommended_price Final recommendation
#' @param currency Currency symbol
#' @return Data frame with evidence
#' @keywords internal
build_evidence_table <- function(method_prices, vw_results, gg_results,
                                 recommended_price, currency) {

  rows <- list()

  # Van Westendorp evidence
  if (!is.null(vw_results)) {
    rows$vw_range <- data.frame(
      method = "Van Westendorp",
      metric = "Acceptable Range",
      value = sprintf("%s%.2f - %s%.2f",
                      currency, vw_results$price_points$PMC,
                      currency, vw_results$price_points$PME),
      interpretation = "Price floor and ceiling",
      stringsAsFactors = FALSE
    )

    rows$vw_optimal <- data.frame(
      method = "Van Westendorp",
      metric = "Optimal Zone",
      value = sprintf("%s%.2f - %s%.2f",
                      currency, vw_results$price_points$OPP,
                      currency, vw_results$price_points$IDP),
      interpretation = "Sweet spot for pricing",
      stringsAsFactors = FALSE
    )

    if (!is.null(vw_results$nms_results)) {
      rows$nms <- data.frame(
        method = "NMS Extension",
        metric = "Revenue Optimal",
        value = sprintf("%s%.2f", currency, vw_results$nms_results$revenue_optimal),
        interpretation = "Purchase-calibrated optimum",
        stringsAsFactors = FALSE
      )
    }
  }

  # Gabor-Granger evidence
  if (!is.null(gg_results)) {
    rows$gg_optimal <- data.frame(
      method = "Gabor-Granger",
      metric = "Revenue Optimal",
      value = sprintf("%s%.2f", currency, gg_results$optimal_price$price),
      interpretation = sprintf("%.0f%% purchase intent",
                               gg_results$optimal_price$purchase_intent * 100),
      stringsAsFactors = FALSE
    )

    if (!is.null(gg_results$elasticity)) {
      avg_elast <- mean(gg_results$elasticity$arc_elasticity, na.rm = TRUE)
      elast_type <- if (avg_elast > -1) "Inelastic" else if (avg_elast < -2) "Highly elastic" else "Moderately elastic"

      rows$gg_elast <- data.frame(
        method = "Gabor-Granger",
        metric = "Price Elasticity",
        value = sprintf("%.2f (avg)", avg_elast),
        interpretation = elast_type,
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, rows)
}


#' Identify Pricing Risks
#'
#' @param recommended_price Final recommendation
#' @param vw_results Van Westendorp results
#' @param gg_results Gabor-Granger results
#' @param confidence Confidence assessment
#' @return List of risks
#' @keywords internal
identify_pricing_risks <- function(recommended_price, vw_results,
                                   gg_results, confidence) {

  risks <- list(
    upside = character(0),
    downside = character(0),
    assumptions = character(0)
  )

  # Upside risks (opportunities)
  if (!is.null(vw_results)) {
    headroom <- vw_results$price_points$PME - recommended_price
    headroom_pct <- headroom / recommended_price * 100

    if (headroom_pct > 30) {
      risks$upside <- c(risks$upside, sprintf(
        "%.0f%% headroom to PME - potential for premium variant or future increases",
        headroom_pct
      ))
    }
  }

  if (!is.null(gg_results)) {
    if (!is.null(gg_results$elasticity)) {
      avg_elast <- mean(gg_results$elasticity$arc_elasticity, na.rm = TRUE)
      if (avg_elast > -1) {
        risks$upside <- c(risks$upside,
          "Inelastic demand suggests price increases may be absorbed"
        )
      }
    }
  }

  # Downside risks (threats)
  if (!is.null(vw_results)) {
    buffer <- recommended_price - vw_results$price_points$PMC
    buffer_pct <- buffer / recommended_price * 100

    if (buffer_pct < 20) {
      risks$downside <- c(risks$downside, sprintf(
        "Only %.0f%% buffer to PMC - limited room for discounting",
        buffer_pct
      ))
    }
  }

  if (!is.null(gg_results)) {
    if (!is.null(gg_results$elasticity)) {
      avg_elast <- mean(gg_results$elasticity$arc_elasticity, na.rm = TRUE)
      if (avg_elast < -2) {
        risks$downside <- c(risks$downside,
          "Highly elastic demand - price increases risk significant volume loss"
        )
      }
    }
  }

  if (confidence$level == "LOW") {
    risks$downside <- c(risks$downside,
      "Low confidence in recommendation - consider additional research"
    )
  }

  # Assumptions
  risks$assumptions <- c(
    "Competitive pricing assumed stable",
    "Survey responses reflect actual purchase behavior",
    "Market conditions unchanged since data collection"
  )

  if (!is.null(vw_results) && vw_results$diagnostics$violation_rate > 0.10) {
    risks$assumptions <- c(risks$assumptions,
      sprintf("%.0f%% of respondents gave inconsistent prices - may affect reliability",
              vw_results$diagnostics$violation_rate * 100)
    )
  }

  return(risks)
}


#' Generate Executive Summary Text
#'
#' @param recommended_price Final recommendation
#' @param primary_source Source of recommendation
#' @param confidence Confidence assessment
#' @param acceptable_range Acceptable range
#' @param optimal_zone Optimal zone
#' @param gg_results Gabor-Granger results
#' @param segment_notes Segment analysis notes
#' @param tier_notes Price ladder notes
#' @param risks Risk assessment
#' @param currency Currency symbol
#' @param project_name Project name
#' @return Character string with formatted summary
#' @keywords internal
generate_executive_summary <- function(recommended_price, primary_source,
                                       confidence, acceptable_range, optimal_zone,
                                       gg_results, segment_notes, tier_notes,
                                       risks, currency, project_name) {

  # Build summary sections
  lines <- character(0)

  # Header
  lines <- c(lines, sprintf("PRICING RECOMMENDATION: %s", project_name))
  lines <- c(lines, paste(rep("=", 60), collapse = ""))
  lines <- c(lines, sprintf("Date: %s", format(Sys.Date(), "%B %d, %Y")))
  lines <- c(lines, "")

  # Primary recommendation
  lines <- c(lines, "PRIMARY RECOMMENDATION")
  lines <- c(lines, paste(rep("-", 30), collapse = ""))
  lines <- c(lines, sprintf("Recommended Price: %s%.2f", currency, recommended_price))
  lines <- c(lines, sprintf("Confidence: %s", confidence$level))
  lines <- c(lines, "")

  # Acceptable range
  if (!is.null(acceptable_range)) {
    lines <- c(lines, "ACCEPTABLE PRICE RANGE")
    lines <- c(lines, paste(rep("-", 30), collapse = ""))
    lines <- c(lines, sprintf("Floor:   %s%.2f  (%s)",
                              currency, acceptable_range$lower,
                              acceptable_range$lower_desc))
    lines <- c(lines, sprintf("Ceiling: %s%.2f  (%s)",
                              currency, acceptable_range$upper,
                              acceptable_range$upper_desc))
    lines <- c(lines, "")
  }

  # Optimal zone
  if (!is.null(optimal_zone)) {
    lines <- c(lines, "OPTIMAL ZONE")
    lines <- c(lines, paste(rep("-", 30), collapse = ""))
    lines <- c(lines, sprintf("%s%.2f to %s%.2f",
                              currency, optimal_zone$lower,
                              currency, optimal_zone$upper))
    lines <- c(lines, "")
  }

  # Purchase intent (if GG available)
  if (!is.null(gg_results)) {
    lines <- c(lines, "AT RECOMMENDED PRICE")
    lines <- c(lines, paste(rep("-", 30), collapse = ""))

    # Interpolate intent at recommended price
    intent <- approx(
      x = gg_results$demand_curve$price,
      y = gg_results$demand_curve$purchase_intent,
      xout = recommended_price,
      rule = 2
    )$y

    lines <- c(lines, sprintf("Estimated Purchase Intent: %.0f%%", intent * 100))
    lines <- c(lines, "")
  }

  # Segment notes
  if (!is.null(segment_notes) && length(segment_notes$insights) > 0) {
    lines <- c(lines, "SEGMENT CONSIDERATIONS")
    lines <- c(lines, paste(rep("-", 30), collapse = ""))
    for (insight in segment_notes$insights) {
      lines <- c(lines, sprintf("* %s", insight))
    }
    lines <- c(lines, "")
  }

  # Tier recommendations
  if (!is.null(tier_notes)) {
    lines <- c(lines, "TIER STRUCTURE")
    lines <- c(lines, paste(rep("-", 30), collapse = ""))
    for (i in 1:nrow(tier_notes$tiers)) {
      lines <- c(lines, sprintf("%-10s %s%.2f",
                                tier_notes$tiers$tier[i],
                                currency,
                                tier_notes$tiers$price[i]))
    }
    lines <- c(lines, "")
  }

  # Confidence factors
  lines <- c(lines, "CONFIDENCE ASSESSMENT")
  lines <- c(lines, paste(rep("-", 30), collapse = ""))
  for (factor_name in names(confidence$factors)) {
    lines <- c(lines, sprintf("* %s", confidence$factors[[factor_name]]))
  }
  lines <- c(lines, "")

  # Risks
  if (length(risks$downside) > 0) {
    lines <- c(lines, "KEY RISKS")
    lines <- c(lines, paste(rep("-", 30), collapse = ""))
    for (risk in risks$downside) {
      lines <- c(lines, sprintf("* %s", risk))
    }
    lines <- c(lines, "")
  }

  # Next steps
  lines <- c(lines, "RECOMMENDED NEXT STEPS")
  lines <- c(lines, paste(rep("-", 30), collapse = ""))
  lines <- c(lines, "1. Validate recommendation against cost/margin requirements")
  lines <- c(lines, "2. Consider market testing at recommended price")
  lines <- c(lines, "3. Develop promotional pricing strategy")
  if (!is.null(segment_notes)) {
    lines <- c(lines, "4. Evaluate segment-specific pricing if operationally feasible")
  }

  paste(lines, collapse = "\n")
}


# Helper operator for default values (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
  }
}
