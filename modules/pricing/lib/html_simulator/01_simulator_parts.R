# ==============================================================================
# TURAS PRICING - STANDALONE SIMULATOR: DATA AND MARKUP
# ==============================================================================
#
# The pieces the standalone simulator is assembled from: the demand data pulled
# off a pricing run, the JSON the engine reads, and the panel markup.
#
# HISTORY: these functions lived in the pricing HTML report
# (lib/html_report/01_data_transformer.R and 03_page_builder.R) and in a dead
# fork (lib/simulator/). Both are retired; this is the one copy.
#
# WHAT CHANGED ON THE WAY ACROSS:
#   - The islands are serialised by jsonlite, not by a hand-rolled escaper, and
#     escaped the way every Turas island is: every "<" becomes its JSON unicode
#     escape, so a segment name can never close the script tag (review P2a).
#   - The panel carries no pins and no insight editors. Those belong to the
#     report layer that is being retired; the simulator is a tool.
#
# ==============================================================================

PRICING_SIMULATOR_VERSION <- "2.0.0"

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}


# ==============================================================================
# DATA EXTRACTION
# ==============================================================================

#' The Demand Curve The Simulator Interpolates
#'
#' @param results The `results` element of a pricing run.
#' @param method The analysis method that produced them.
#' @return A list with `price_range`, `demand_curve` and `revenue_curve`, or
#'   NULL when the method produced no curve to simulate against.
#' @keywords internal
extract_demand_data <- function(results, method) {
  method <- tolower(method %||% "unknown")

  from_gg <- function(gg) {
    if (is.null(gg) || is.null(gg$demand_curve)) return(NULL)
    list(
      price_range = gg$demand_curve$price,
      demand_curve = gg$demand_curve$purchase_intent,
      revenue_curve = gg$revenue_curve$revenue_index %||%
        (gg$demand_curve$price * gg$demand_curve$purchase_intent)
    )
  }

  if (method == "monadic") {
    if (is.null(results$demand_curve)) return(NULL)
    return(list(
      price_range = results$demand_curve$price,
      demand_curve = results$demand_curve$predicted_intent,
      revenue_curve = results$demand_curve$revenue_index
    ))
  }
  if (method == "gabor_granger") return(from_gg(results))
  if (method == "both") return(from_gg(results$gabor_granger))

  # Van Westendorp on its own has no demand curve. The NMS extension would
  # give one, and it is refused until it has a golden (the Session A review's
  # F3), so a VW-only run has nothing to simulate.
  NULL
}


#' The Price The Run Called Revenue-Optimal
#' @keywords internal
extract_optimal_price <- function(results, method) {
  method <- tolower(method %||% "unknown")
  if (method == "monadic") return(results$optimal_price$price)
  if (method == "gabor_granger") return(results$optimal_price$price)
  if (method == "both") return(results$gabor_granger$optimal_price$price)
  NULL
}


#' One Demand Curve Per Segment, Where The Run Produced Them
#' @keywords internal
extract_segment_demand <- function(segment_results, method) {
  if (is.null(segment_results) || is.null(segment_results$segment_results)) return(list())
  out <- list()
  for (nm in names(segment_results$segment_results)) {
    dd <- extract_demand_data(segment_results$segment_results[[nm]], method)
    if (!is.null(dd)) out[[nm]] <- dd
  }
  out
}


# ==============================================================================
# THE ISLANDS
# ==============================================================================

#' Serialise A List As A Script-Safe JSON Island
#'
#' Real JSON from jsonlite, then the island escaping every Turas island uses:
#' each "<" becomes `\\u003c`, which is valid JSON and restores on parse, so no
#' string in the data can close the script element it lives in (review P2a).
#'
#' @keywords internal
.pricing_sim_island <- function(x) {
  txt <- jsonlite::toJSON(x, auto_unbox = TRUE, na = "null", digits = 6, null = "null")
  # NOT fixed = TRUE. With fixed matching the replacement is taken literally,
  # so the two backslashes in the R string reach the JSON as an escaped
  # backslash and the value parses back as the text "\u003c" instead of "<".
  # build_report_v2.R does it this way for the same reason.
  gsub("<", "\\\\u003c", as.character(txt))
}


#' The Data Island: the curves, the optimum and the segments
#' @keywords internal
build_pricing_json <- function(demand_data, optimal_price, segment_data) {
  num <- function(x) {
    v <- suppressWarnings(as.numeric(x))
    v[!is.finite(v)] <- NA_real_
    unname(v)
  }
  segs <- NULL
  if (length(segment_data) > 0) {
    segs <- lapply(segment_data, function(s) list(
      price_range = I(num(s$price_range)),
      demand_curve = I(num(s$demand_curve)),
      revenue_curve = I(num(s$revenue_curve))
    ))
  }
  out <- list(
    price_range = I(num(demand_data$price_range)),
    demand_curve = I(num(demand_data$demand_curve)),
    revenue_curve = I(num(demand_data$revenue_curve)),
    optimal_price = if (is.null(optimal_price)) NULL else num(optimal_price)[1]
  )
  if (!is.null(segs)) out$segments <- segs
  .pricing_sim_island(out)
}


#' The Config Island: currency, brand, unit cost and any preset scenarios
#' @keywords internal
build_simulator_config_json <- function(config, scenarios = NULL) {
  unit_cost <- suppressWarnings(as.numeric(config$unit_cost %||% 0))
  if (!is.finite(unit_cost) || unit_cost < 0) unit_cost <- 0
  .pricing_sim_island(list(
    currency = as.character(config$currency_symbol %||% ""),
    brand_colour = as.character(config$brand_colour %||% "#323367"),
    unit_cost = unit_cost,
    project_name = as.character(config$project_name %||% "Pricing"),
    scenarios = build_scenarios_list(scenarios %||% config$simulator$scenarios)
  ))
}


#' Preset Scenarios, From A Data Frame Or A List
#' @keywords internal
build_scenarios_list <- function(scenarios) {
  if (is.null(scenarios) || length(scenarios) == 0) return(list())

  one <- function(name, price, description) {
    price <- suppressWarnings(as.numeric(price))
    if (!is.finite(price)) return(NULL)
    list(name = as.character(name), price = price,
         description = as.character(description %||% ""))
  }

  if (is.data.frame(scenarios)) {
    pick <- function(row, a, b) {
      if (a %in% names(scenarios)) return(scenarios[[a]][row])
      if (b %in% names(scenarios)) return(scenarios[[b]][row])
      NULL
    }
    out <- lapply(seq_len(nrow(scenarios)), function(i) {
      one(pick(i, "name", "Scenario_Name") %||% paste("Scenario", i),
          pick(i, "price", "Price") %||% NA,
          pick(i, "description", "Description"))
    })
    return(Filter(Negate(is.null), out))
  }

  out <- lapply(scenarios, function(sc) {
    one(sc$name %||% sc$Scenario_Name %||% "Scenario",
        sc$price %||% sc$Price %||% NA,
        sc$description %||% sc$Description)
  })
  Filter(Negate(is.null), out)
}


# ==============================================================================
# MARKUP
# ==============================================================================

#' Escape Text For HTML
#' @keywords internal
.pricing_sim_escape <- function(x) {
  x <- as.character(x %||% "")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}


#' The Simulator Panel
#'
#' Every id here is one the engine binds (`pricing_simulator.js`). The panel
#' keeps the `panel-simulator` id because the stylesheet scopes its rules to it.
#'
#' @param has_segments Logical, does the data carry per-segment curves.
#' @param has_unit_cost Logical, did the config set one.
#' @return A single HTML string.
#' @keywords internal
build_simulator_panel <- function(has_segments = FALSE, has_unit_cost = FALSE) {

  segment_section <- if (has_segments) {
    paste0('<div id="sim-segment-section">',
           '<div class="sim-segment-toggle" id="sim-segment-buttons"></div></div>')
  } else {
    '<div id="sim-segment-section" style="display:none;"></div>'
  }

  segment_callout <- if (has_segments) {
    paste0('<div class="sim-callout"><strong>Segments</strong>: switch between ',
           'groups to see how price sensitivity differs. Each segment is drawn ',
           'on its own prices, not the total sample\'s.</div>')
  } else ""

  profit_callout <- if (has_unit_cost) {
    paste0('<div class="sim-callout"><strong>Profit Index</strong>: (price minus ',
           'unit cost) times purchase intent. Change the unit cost below to see ',
           'the effect.</div>')
  } else {
    paste0('<div class="sim-callout"><strong>Profit Index</strong>: (price minus ',
           'unit cost) times purchase intent. Enter a unit cost below to switch ',
           'it on.</div>')
  }

  paste0(
'<div id="panel-simulator">
  <h2>Price simulator</h2>

  <div class="sim-callouts">
    <div class="sim-callout"><strong>Purchase Intent</strong>: the share of respondents who said they would buy, read off the demand curve at the price you choose. Between the prices that were asked it is interpolated.</div>
    <div class="sim-callout"><strong>Revenue Index</strong>: price times purchase intent. It compares prices with each other; it is not a revenue forecast.</div>
    ', profit_callout, '
    ', segment_callout, '
  </div>

  <div class="sim-actions">
    <button class="sim-btn sim-btn-primary" onclick="PricingSimulator.exportPNG()">Export PNG</button>
  </div>

  ', segment_section, '

  <div class="sim-grid">
    <div class="sim-controls">
      <h3>Price controls</h3>
      <div class="sim-control-group">
        <div class="sim-control-label">
          <span>Price</span>
          <span class="sim-control-value" id="sim-current-price">--</span>
        </div>
        <input type="range" id="sim-price-slider">
        <div class="sim-range-labels">
          <span id="sim-range-min"></span>
          <span id="sim-range-max"></span>
        </div>
        <div class="sim-price-input-row">
          <label style="font-size:11px;color:var(--sim-text-muted);">Set price:</label>
          <input type="number" id="sim-price-input" step="0.01">
        </div>
      </div>

      <div id="sim-scenarios-section" class="sim-scenarios">
        <h3>Preset scenarios</h3>
        <div class="sim-scenario-grid" id="sim-scenario-cards"></div>
      </div>

      <div class="sim-control-group" style="margin-top:18px;">
        <div class="sim-control-label"><span>Unit cost</span></div>
        <input type="number" id="sim-unit-cost-input" step="0.01" min="0"
          placeholder="Unit cost, for the profit index"
          style="width:100%;padding:6px 8px;border:1px solid var(--sim-border);border-radius:4px;font-size:13px;">
      </div>
    </div>

    <div class="sim-results">
      <div class="sim-metrics">
        <div class="sim-metric">
          <div class="sim-metric-value" id="sim-intent-value">--</div>
          <div class="sim-metric-label">Purchase Intent</div>
        </div>
        <div class="sim-metric">
          <div class="sim-metric-value" id="sim-revenue-value">--</div>
          <div class="sim-metric-label">Revenue Index</div>
          <div id="sim-revenue-delta" class="sim-metric-delta"></div>
        </div>
        <div class="sim-metric">
          <div class="sim-metric-value" id="sim-volume-value">--</div>
          <div class="sim-metric-label">Volume Index</div>
        </div>
        <div class="sim-metric" id="sim-profit-card">
          <div class="sim-metric-value" id="sim-profit-value">N/A</div>
          <div class="sim-metric-label">Profit Index</div>
        </div>
      </div>

      <div class="sim-chart-area">
        <div class="sim-chart-title">Demand and revenue</div>
        <div id="sim-chart-svg"></div>
      </div>
    </div>
  </div>

  <div class="sim-compare" id="sim-compare-section">
    <div class="sim-compare-header">
      <h3>Scenario comparison</h3>
      <div class="sim-compare-actions">
        <button class="sim-btn sim-btn-outline" id="sim-compare-add">+ Add scenario</button>
      </div>
    </div>
    <div class="sim-compare-note">
      Add prices to compare them side by side. Revenue Index and Profit Index are the raw figures, price times intent and margin times intent; the rows below them show each as a percentage of the revenue-maximising price.
    </div>
    <div class="sim-compare-table-wrap">
      <table class="sim-compare-table" id="sim-compare-table">
        <thead><tr id="sim-compare-thead"></tr></thead>
        <tbody id="sim-compare-tbody"></tbody>
      </table>
    </div>
  </div>
</div>')
}
