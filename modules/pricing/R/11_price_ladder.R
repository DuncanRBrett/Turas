# ==============================================================================
# TURAS PRICING MODULE - PRICE LADDER BUILDER
# ==============================================================================
#
# Purpose: Automatically generate Good/Better/Best tier structure from
#          pricing analysis results
# Version: 1.0.0
# Date: 2025-12-11
#
# ==============================================================================

#' Build Price Tier Ladder
#'
#' Generates recommended price tiers from Van Westendorp and/or
#' Gabor-Granger results.
#'
#' @param vw_results Van Westendorp results (from run_van_westendorp)
#' @param gg_results Gabor-Granger results (from run_gabor_granger), optional
#' @param config Configuration list with price_ladder settings
#'
#' @return List containing tier_table, gap_analysis, notes, diagnostics
#'
#' @export
build_price_ladder <- function(vw_results = NULL, gg_results = NULL, config = NULL) {

  # ============================================================================
  # STEP 1: Validate inputs
  # ============================================================================

  if (is.null(vw_results) && is.null(gg_results)) {
    pricing_refuse(
      code = "DATA_NO_RESULTS",
      title = "No Analysis Results Provided",
      problem = "At least one of vw_results or gg_results must be provided",
      why_it_matters = "Cannot build price ladder without pricing analysis results",
      how_to_fix = c(
        "Run Van Westendorp or Gabor-Granger analysis first",
        "Pass the results to build_price_ladder()"
      ),
      expected = "vw_results and/or gg_results"
    )
  }

  # Get config with defaults
  ladder_config <- config$price_ladder %||% list()

  n_tiers <- as.integer(ladder_config$n_tiers %||% 3)
  if (n_tiers < 2 || n_tiers > 4) {
    pricing_refuse(
      code = "CFG_INVALID_N_TIERS",
      title = "Invalid Number of Tiers",
      problem = sprintf("n_tiers is %d, but must be between 2 and 4", n_tiers),
      why_it_matters = "Price ladder requires 2-4 tiers for meaningful differentiation",
      how_to_fix = "Set n_tiers in PriceLadder configuration to 2, 3, or 4",
      observed = n_tiers,
      expected = "2, 3, or 4"
    )
  }

  tier_names_raw <- ladder_config$tier_names %||% switch(as.character(n_tiers),
    "2" = "Standard;Premium",
    "3" = "Value;Standard;Premium",
    "4" = "Economy;Value;Standard;Premium"
  )
  tier_names <- trimws(strsplit(tier_names_raw, ";")[[1]])

  if (length(tier_names) != n_tiers) {
    pricing_refuse(
      code = "CFG_TIER_NAMES_MISMATCH",
      title = "Tier Names Count Mismatch",
      problem = sprintf("%d tier names provided but n_tiers is %d", length(tier_names), n_tiers),
      why_it_matters = "Each tier must have exactly one name",
      how_to_fix = c(
        "Adjust tier_names in PriceLadder configuration to match n_tiers",
        "Use semicolon-separated names (e.g., 'Value;Standard;Premium' for 3 tiers)"
      ),
      observed = sprintf("%d tier names: %s", length(tier_names), paste(tier_names, collapse = ", ")),
      expected = sprintf("%d tier names", n_tiers)
    )
  }

  min_gap <- as.numeric(ladder_config$min_gap_pct %||% 15) / 100
  max_gap <- as.numeric(ladder_config$max_gap_pct %||% 50) / 100
  round_to <- ladder_config$round_to %||% "0.99"
  anchor <- ladder_config$anchor %||% "Standard"

  # ============================================================================
  # STEP 2: Extract key prices from results
  # ============================================================================

  reference_prices <- list()

  if (!is.null(vw_results)) {
    reference_prices$PMC <- vw_results$price_points$PMC
    reference_prices$OPP <- vw_results$price_points$OPP
    reference_prices$IDP <- vw_results$price_points$IDP
    reference_prices$PME <- vw_results$price_points$PME
    reference_prices$vw_optimal <- (vw_results$price_points$OPP +
                                    vw_results$price_points$IDP) / 2

    # Use NMS revenue optimal if available
    if (!is.null(vw_results$nms_results)) {
      reference_prices$nms_optimal <- vw_results$nms_results$revenue_optimal
    }
  }

  if (!is.null(gg_results)) {
    reference_prices$gg_optimal <- gg_results$optimal_price$price
    reference_prices$gg_intent <- gg_results$optimal_price$purchase_intent
  }

  # ============================================================================
  # STEP 3: Determine anchor price
  # ============================================================================

  # Priority: NMS revenue optimal > GG optimal > VW midpoint
  if (!is.null(reference_prices$nms_optimal)) {
    anchor_price <- reference_prices$nms_optimal
    anchor_source <- "NMS revenue optimal"
  } else if (!is.null(reference_prices$gg_optimal)) {
    anchor_price <- reference_prices$gg_optimal
    anchor_source <- "Gabor-Granger optimal"
  } else if (!is.null(reference_prices$vw_optimal)) {
    anchor_price <- reference_prices$vw_optimal
    anchor_source <- "Van Westendorp OPP-IDP midpoint"
  } else {
    pricing_refuse(
      code = "DATA_NO_ANCHOR_PRICE",
      title = "Cannot Determine Anchor Price",
      problem = "No suitable anchor price found in analysis results",
      why_it_matters = "Price ladder requires an anchor point to build tier structure",
      how_to_fix = c(
        "Ensure Van Westendorp or Gabor-Granger results contain valid price recommendations",
        "Check that analysis results have expected price points"
      ),
      expected = "Valid price recommendation in vw_results or gg_results"
    )
  }

  # ============================================================================
  # STEP 4: Calculate tier prices
  # ============================================================================

  # Determine which tier is the anchor
  anchor_tier_idx <- which(tolower(tier_names) == tolower(anchor))
  if (length(anchor_tier_idx) == 0) {
    # Default to middle tier
    anchor_tier_idx <- ceiling(n_tiers / 2)
  }

  # Calculate spread based on available range
  if (!is.null(reference_prices$PMC) && !is.null(reference_prices$PME)) {
    floor_price <- reference_prices$PMC
    ceiling_price <- reference_prices$PME
  } else {
    # Estimate range as +/- 40% from anchor
    floor_price <- anchor_price * 0.6
    ceiling_price <- anchor_price * 1.4
  }

  # Generate tier prices
  tier_prices <- numeric(n_tiers)
  tier_prices[anchor_tier_idx] <- anchor_price

  # Tiers below anchor
  if (anchor_tier_idx > 1) {
    tiers_below <- anchor_tier_idx - 1
    step_down <- (anchor_price - floor_price) / (tiers_below + 0.5)

    for (i in (anchor_tier_idx - 1):1) {
      steps_from_anchor <- anchor_tier_idx - i
      tier_prices[i] <- anchor_price - (step_down * steps_from_anchor)
    }
  }

  # Tiers above anchor
  if (anchor_tier_idx < n_tiers) {
    tiers_above <- n_tiers - anchor_tier_idx
    step_up <- (ceiling_price - anchor_price) / (tiers_above + 0.5)

    for (i in (anchor_tier_idx + 1):n_tiers) {
      steps_from_anchor <- i - anchor_tier_idx
      tier_prices[i] <- anchor_price + (step_up * steps_from_anchor)
    }
  }

  # Ensure prices don't exceed bounds
  tier_prices[1] <- max(tier_prices[1], floor_price * 1.05)
  tier_prices[n_tiers] <- min(tier_prices[n_tiers], ceiling_price * 0.95)

  # ============================================================================
  # STEP 5: Apply psychological rounding
  # ============================================================================

  tier_prices_rounded <- apply_price_rounding(tier_prices, round_to)

  # ============================================================================
  # STEP 6: Calculate gaps and validate
  # ============================================================================

  gap_analysis <- analyze_gaps(tier_prices_rounded, tier_names, min_gap, max_gap)

  # ============================================================================
  # STEP 7: Add demand estimates if GG available
  # ============================================================================

  demand_estimates <- NULL

  if (!is.null(gg_results)) {
    demand_estimates <- estimate_tier_demand(tier_prices_rounded, gg_results)
  }

  # ============================================================================
  # STEP 8: Build output table
  # ============================================================================

  tier_table <- data.frame(
    tier = tier_names,
    price = tier_prices_rounded,
    gap_to_next_pct = c(gap_analysis$gaps * 100, NA),
    stringsAsFactors = FALSE
  )

  # Add demand estimates if available
  if (!is.null(demand_estimates)) {
    tier_table$est_purchase_intent <- demand_estimates$intent
    tier_table$est_revenue_index <- demand_estimates$revenue_index
  }

  # Add notes column
  tier_table$notes <- gap_analysis$notes

  # ============================================================================
  # STEP 9: Generate recommendations
  # ============================================================================

  notes <- generate_ladder_notes(
    tier_table = tier_table,
    gap_analysis = gap_analysis,
    reference_prices = reference_prices,
    anchor_tier_idx = anchor_tier_idx
  )

  # ============================================================================
  # STEP 10: Compile diagnostics
  # ============================================================================

  diagnostics <- list(
    anchor_price = anchor_price,
    anchor_source = anchor_source,
    anchor_tier = tier_names[anchor_tier_idx],
    floor_price = floor_price,
    ceiling_price = ceiling_price,
    rounding_applied = round_to,
    has_demand_estimates = !is.null(demand_estimates)
  )

  # ============================================================================
  # STEP 11: Return results
  # ============================================================================

  list(
    tier_table = tier_table,
    gap_analysis = gap_analysis,
    notes = notes,
    diagnostics = diagnostics
  )
}


#' Apply Psychological Price Rounding
#'
#' @param prices Numeric vector of prices
#' @param round_to Rounding style: "0.99", "0.95", "0.00", "none"
#' @return Rounded prices
#' @keywords internal
apply_price_rounding <- function(prices, round_to) {

  if (round_to == "none") {
    return(round(prices, 2))
  }

  ending <- switch(round_to,
    "0.99" = 0.99,
    "0.95" = 0.95,
    "0.00" = 0.00,
    0.99  # default
  )

  # Round to nearest integer then apply ending
  rounded <- floor(prices) + ending

  # Adjust if rounding pushed price too far from original
  # (more than 10% change)
  for (i in seq_along(prices)) {
    if (abs(rounded[i] - prices[i]) / prices[i] > 0.10) {
      # Try rounding up instead
      alt_rounded <- ceiling(prices[i]) + ending - 1
      if (abs(alt_rounded - prices[i]) < abs(rounded[i] - prices[i])) {
        rounded[i] <- alt_rounded
      }
    }
  }

  return(rounded)
}


#' Analyze Price Gaps Between Tiers
#'
#' @param prices Vector of tier prices
#' @param tier_names Tier names
#' @param min_gap Minimum acceptable gap (proportion)
#' @param max_gap Maximum acceptable gap (proportion)
#' @return List with gaps, flags, and notes
#' @keywords internal
analyze_gaps <- function(prices, tier_names, min_gap, max_gap) {

  n <- length(prices)
  gaps <- numeric(n - 1)
  notes <- character(n)
  flags <- character(0)

  for (i in 1:(n - 1)) {
    gaps[i] <- (prices[i + 1] - prices[i]) / prices[i]

    if (gaps[i] < min_gap) {
      flag_msg <- sprintf("%s to %s gap (%.0f%%) below minimum (%.0f%%) - cannibalization risk",
                          tier_names[i], tier_names[i + 1],
                          gaps[i] * 100, min_gap * 100)
      flags <- c(flags, flag_msg)
      notes[i] <- paste0(notes[i], "Gap narrow. ")
    }

    if (gaps[i] > max_gap) {
      flag_msg <- sprintf("%s to %s gap (%.0f%%) exceeds maximum (%.0f%%) - market gap",
                          tier_names[i], tier_names[i + 1],
                          gaps[i] * 100, max_gap * 100)
      flags <- c(flags, flag_msg)
      notes[i] <- paste0(notes[i], "Gap wide. ")
    }
  }

  # Check overall spread
  total_spread <- (prices[n] - prices[1]) / prices[1]
  if (total_spread < 0.3) {
    flags <- c(flags, "Total spread across tiers is narrow (<30%) - limited differentiation")
  }

  list(
    gaps = gaps,
    flags = flags,
    notes = trimws(notes),
    all_gaps_valid = length(flags) == 0
  )
}


#' Estimate Demand at Tier Prices
#'
#' Uses Gabor-Granger demand curve to estimate purchase intent at each tier.
#'
#' @param tier_prices Vector of tier prices
#' @param gg_results Gabor-Granger results
#' @return Data frame with intent and revenue index per tier
#' @keywords internal
estimate_tier_demand <- function(tier_prices, gg_results) {

  demand_curve <- gg_results$demand_curve

  # Interpolate purchase intent for each tier price
  intent <- approx(
    x = demand_curve$price,
    y = demand_curve$purchase_intent,
    xout = tier_prices,
    rule = 2  # Use nearest value for extrapolation
  )$y

  revenue_index <- tier_prices * intent

  data.frame(
    intent = round(intent * 100, 1),
    revenue_index = round(revenue_index, 2)
  )
}


#' Generate Price Ladder Notes
#'
#' @param tier_table Tier table
#' @param gap_analysis Gap analysis results
#' @param reference_prices Reference prices from analyses
#' @param anchor_tier_idx Index of anchor tier
#' @return Character vector of notes
#' @keywords internal
generate_ladder_notes <- function(tier_table, gap_analysis,
                                  reference_prices, anchor_tier_idx) {

  notes <- character(0)

  # Note the anchor
  notes <- c(notes, sprintf(
    "%s tier anchored to optimal price point ($%.2f).",
    tier_table$tier[anchor_tier_idx],
    tier_table$price[anchor_tier_idx]
  ))

  # Add gap flags
  if (length(gap_analysis$flags) > 0) {
    notes <- c(notes, gap_analysis$flags)
  }

  # Add demand insights if available
  if ("est_revenue_index" %in% names(tier_table)) {
    best_revenue_idx <- which.max(tier_table$est_revenue_index)
    notes <- c(notes, sprintf(
      "%s tier shows highest revenue potential (index: %.2f).",
      tier_table$tier[best_revenue_idx],
      tier_table$est_revenue_index[best_revenue_idx]
    ))
  }

  # Add bounds check
  if (!is.null(reference_prices$PMC)) {
    lowest_tier <- tier_table$price[1]
    if (lowest_tier < reference_prices$PMC * 1.05) {
      notes <- c(notes, sprintf(
        "Value tier ($%.2f) near quality concern threshold ($%.2f) - consider raising.",
        lowest_tier, reference_prices$PMC
      ))
    }
  }

  if (!is.null(reference_prices$PME)) {
    highest_tier <- tier_table$price[nrow(tier_table)]
    if (highest_tier > reference_prices$PME * 0.95) {
      notes <- c(notes, sprintf(
        "Premium tier ($%.2f) near 'too expensive' threshold ($%.2f) - limited headroom.",
        highest_tier, reference_prices$PME
      ))
    }
  }

  return(notes)
}


# Helper operator for default values (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
  }
}
