# ==============================================================================
# TURAS PRICING MODULE - SIMULATOR BUILDER
# ==============================================================================
#
# Purpose: Build a self-contained interactive HTML pricing simulator dashboard
#          that clients can open in any browser without Turas access.
#
# Features:
#   - Price slider with real-time demand/revenue/profit updates
#   - Preset scenario cards (from config)
#   - Scenario Comparison: multi-scenario table with indices and highlighting
#   - Segment toggle (if segment data available)
#   - Export chart to PNG
#
# Version: 1.0.0
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

#' Build Interactive Pricing Simulator HTML
#'
#' Generates a self-contained HTML file with embedded demand curve data,
#' interactive price sliders, and scenario comparison capabilities.
#'
#' @param pricing_results Full results list from run_pricing_analysis()
#' @param output_path File path for the HTML simulator
#' @param config Configuration list
#' @return List with status, output_file, file_size
#' @export
build_pricing_simulator <- function(pricing_results, output_path,
                                     config = list(), sim_dir = NULL) {

  cat("   Simulator: Building interactive dashboard...\n")

  method <- tolower(pricing_results$method %||% config$analysis_method %||% "unknown")
  currency <- config$currency_symbol %||% "$"
  brand <- config$brand_colour %||% "#323367"
  project_name <- config$project_name %||% "Pricing Simulator"
  unit_cost <- as.numeric(config$unit_cost %||% 0)

  # --------------------------------------------------------------------------
  # Extract demand curve data
  # --------------------------------------------------------------------------
  results <- pricing_results$results
  demand_data <- extract_demand_data(results, method)

  if (is.null(demand_data)) {
    cat("   ! Simulator: No demand curve data available\n")
    return(list(status = "REFUSED", message = "No demand curve data for simulator"))
  }

  # Extract optimal price
  optimal_price <- extract_optimal_price(results, method)

  # Extract segment data
  segment_data <- extract_segment_demand(pricing_results$segment_results, method)

  # Load preset scenarios from config
  scenarios <- config$simulator$scenarios %||% list()

  # --------------------------------------------------------------------------
  # Read embedded assets (reliable path resolution)
  # --------------------------------------------------------------------------
  if (is.null(sim_dir) || !dir.exists(sim_dir)) {
    possible_dirs <- c(
      file.path(getwd(), "modules", "pricing", "lib", "simulator"),
      tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ""),
      file.path(Sys.getenv("TURAS_ROOT", getwd()), "modules", "pricing", "lib", "simulator")
    )
    for (d in possible_dirs) {
      if (nzchar(d) && dir.exists(d)) { sim_dir <- d; break }
    }
  }

  if (is.null(sim_dir) || !dir.exists(sim_dir)) {
    cat("   ! Simulator: Could not locate simulator directory\n")
    return(list(status = "REFUSED", message = "Simulator asset directory not found"))
  }

  css_path <- file.path(sim_dir, "css", "simulator_styles.css")
  js_path <- file.path(sim_dir, "js", "simulator_core.js")

  css_content <- tryCatch(
    paste(readLines(css_path), collapse = "\n"),
    error = function(e) {
      cat(sprintf("   ! Simulator: CSS file not found at %s\n", css_path))
      ""
    }
  )

  js_content <- tryCatch(
    paste(readLines(js_path), collapse = "\n"),
    error = function(e) {
      cat(sprintf("   ! Simulator: JS file not found at %s\n", js_path))
      ""
    }
  )

  if (!nzchar(css_content) || !nzchar(js_content)) {
    cat("   ! Simulator: WARNING - CSS or JS assets are empty. Simulator may not function correctly.\n")
  }

  # --------------------------------------------------------------------------
  # Build data JSON
  # --------------------------------------------------------------------------
  pricing_json <- build_pricing_json(demand_data, optimal_price, segment_data)

  config_json <- sprintf(
    '{"currency":"%s","brand_colour":"%s","unit_cost":%s,"project_name":"%s","scenarios":%s}',
    jsonEscape(currency),
    jsonEscape(brand),
    if (unit_cost > 0) sprintf("%.2f", unit_cost) else "0",
    jsonEscape(project_name),
    build_scenarios_json(scenarios, currency)
  )

  # --------------------------------------------------------------------------
  # Build HTML
  # --------------------------------------------------------------------------
  html <- build_simulator_html(
    project_name = project_name,
    css = css_content,
    js = js_content,
    pricing_json = pricing_json,
    config_json = config_json,
    brand = brand,
    currency = currency,
    unit_cost = unit_cost,
    has_segments = length(segment_data) > 0
  )

  # --------------------------------------------------------------------------
  # Write to disk
  # --------------------------------------------------------------------------
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE)
  }

  writeLines(html, output_path)

  file_size <- file.info(output_path)$size
  cat(sprintf("   Simulator: Written to %s (%.1f KB)\n",
              basename(output_path), file_size / 1024))

  list(
    status = "PASS",
    output_file = output_path,
    file_size_bytes = file_size
  )
}


# ==============================================================================
# DATA EXTRACTION HELPERS
# ==============================================================================

extract_demand_data <- function(results, method) {
  if (method == "monadic") {
    if (is.null(results$demand_curve)) return(NULL)
    return(list(
      price_range = results$demand_curve$price,
      demand_curve = results$demand_curve$predicted_intent,
      revenue_curve = results$demand_curve$revenue_index
    ))
  } else if (method == "gabor_granger") {
    if (is.null(results$demand_curve)) return(NULL)
    return(list(
      price_range = results$demand_curve$price,
      demand_curve = results$demand_curve$purchase_intent,
      revenue_curve = results$revenue_curve$revenue_index %||% (results$demand_curve$price * results$demand_curve$purchase_intent)
    ))
  } else if (method == "both") {
    # Prefer GG demand curve
    gg <- results$gabor_granger
    if (!is.null(gg) && !is.null(gg$demand_curve)) {
      return(list(
        price_range = gg$demand_curve$price,
        demand_curve = gg$demand_curve$purchase_intent,
        revenue_curve = gg$revenue_curve$revenue_index %||% (gg$demand_curve$price * gg$demand_curve$purchase_intent)
      ))
    }
    return(NULL)
  } else if (method == "van_westendorp") {
    # VW doesn't have a demand curve per se, but can use NMS data
    if (!is.null(results$nms_results$data)) {
      nms <- results$nms_results$data
      return(list(
        price_range = nms$price,
        demand_curve = nms$trial %||% nms$purchase_intent,
        revenue_curve = nms$revenue %||% (nms$price * (nms$trial %||% nms$purchase_intent))
      ))
    }
    return(NULL)
  }
  NULL
}

extract_optimal_price <- function(results, method) {
  if (method == "monadic") return(results$optimal_price$price)
  if (method == "gabor_granger") return(results$optimal_price$price)
  if (method == "both") {
    gg <- results$gabor_granger
    if (!is.null(gg)) return(gg$optimal_price$price)
    vw <- results$van_westendorp
    if (!is.null(vw) && !is.null(vw$nms_results)) return(vw$nms_results$revenue_optimal)
    return(NULL)
  }
  if (method == "van_westendorp" && !is.null(results$nms_results)) {
    return(results$nms_results$revenue_optimal)
  }
  NULL
}

extract_segment_demand <- function(segment_results, method) {
  if (is.null(segment_results) || is.null(segment_results$segment_results)) return(list())

  seg_data <- list()
  for (seg_name in names(segment_results$segment_results)) {
    seg <- segment_results$segment_results[[seg_name]]
    dd <- extract_demand_data(seg, method)
    if (!is.null(dd)) {
      seg_data[[seg_name]] <- dd
    }
  }
  seg_data
}


# ==============================================================================
# JSON BUILDERS
# ==============================================================================

build_pricing_json <- function(demand_data, optimal_price, segment_data) {
  segments_json <- "null"
  if (length(segment_data) > 0) {
    seg_parts <- character(0)
    for (sn in names(segment_data)) {
      seg_parts <- c(seg_parts, sprintf(
        '"%s":{"price_range":[%s],"demand_curve":[%s]}',
        jsonEscape(sn),
        paste(sprintf("%.4f", segment_data[[sn]]$price_range), collapse = ","),
        paste(sprintf("%.6f", segment_data[[sn]]$demand_curve), collapse = ",")
      ))
    }
    segments_json <- sprintf("{%s}", paste(seg_parts, collapse = ","))
  }

  sprintf(
    '{"price_range":[%s],"demand_curve":[%s],"revenue_curve":[%s],"optimal_price":%s,"segments":%s}',
    paste(sprintf("%.4f", demand_data$price_range), collapse = ","),
    paste(sprintf("%.6f", demand_data$demand_curve), collapse = ","),
    paste(sprintf("%.4f", demand_data$revenue_curve), collapse = ","),
    if (!is.null(optimal_price)) sprintf("%.2f", optimal_price) else "null",
    segments_json
  )
}

build_scenarios_json <- function(scenarios, currency) {
  if (is.null(scenarios) || length(scenarios) == 0) return("[]")

  # Handle data frame format from config
  if (is.data.frame(scenarios)) {
    parts <- character(0)
    for (i in seq_len(nrow(scenarios))) {
      parts <- c(parts, sprintf(
        '{"name":"%s","price":%s,"description":"%s"}',
        jsonEscape(as.character(scenarios$name[i] %||% scenarios$Scenario_Name[i] %||% paste("Scenario", i))),
        as.numeric(scenarios$price[i] %||% scenarios$Price[i] %||% 0),
        jsonEscape(as.character(scenarios$description[i] %||% scenarios$Description[i] %||% ""))
      ))
    }
    return(sprintf("[%s]", paste(parts, collapse = ",")))
  }

  # Handle list format
  if (is.list(scenarios)) {
    parts <- character(0)
    for (sc in scenarios) {
      parts <- c(parts, sprintf(
        '{"name":"%s","price":%s,"description":"%s"}',
        jsonEscape(sc$name %||% "Scenario"),
        as.numeric(sc$price %||% 0),
        jsonEscape(sc$description %||% "")
      ))
    }
    return(sprintf("[%s]", paste(parts, collapse = ",")))
  }

  "[]"
}

jsonEscape <- function(s) {
  if (is.null(s) || is.na(s)) return("")
  s <- gsub("\\\\", "\\\\\\\\", s)
  s <- gsub('"', '\\\\"', s)
  s <- gsub("\n", "\\\\n", s)
  s <- gsub("\t", "\\\\t", s)
  s
}


# ==============================================================================
# HTML ASSEMBLY
# ==============================================================================

build_simulator_html <- function(project_name, css, js, pricing_json, config_json,
                                  brand, currency, unit_cost, has_segments) {

  # Replace brand token in CSS
  css <- gsub("--sim-brand: #323367", sprintf("--sim-brand: %s", brand), css, fixed = TRUE)

  profit_card <- '<div class="sim-metric" id="sim-profit-card">
       <div class="sim-metric-value" id="sim-profit-value">N/A</div>
       <div class="sim-metric-label">Profit Index</div>
     </div>'

  segment_section <- if (has_segments) {
    '<div id="sim-segment-section">
       <div class="sim-segment-toggle" id="sim-segment-buttons"></div>
     </div>'
  } else '<div id="sim-segment-section" style="display:none;"></div>'

  sprintf(
    '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="turas-report-type" content="pricing-simulator">
  <meta name="turas-generated" content="%s">
  <title>%s - Pricing Simulator</title>
  <style>%s</style>
</head>
<body>

<div class="sim-header">
  <div>
    <h1>%s</h1>
    <div class="sim-subtitle">Interactive Pricing Simulator &middot; TURAS Analytics</div>
  </div>
  <div class="sim-header-actions">
    <button class="sim-btn sim-btn-primary" onclick="TurasSimulator.exportPNG()">Export PNG</button>
  </div>
</div>

<div class="sim-container">

  %s

  <div class="sim-grid">
    <!-- Controls Panel -->
    <div class="sim-controls">
      <h2>Price Controls</h2>
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
      </div>

      <div id="sim-scenarios-section" class="sim-scenarios">
        <h2>Preset Scenarios</h2>
        <div class="sim-scenario-grid" id="sim-scenario-cards"></div>
      </div>

      <div class="sim-control-group" style="margin-top:18px;">
        <div class="sim-control-label">
          <span>Unit Cost</span>
        </div>
        <input type="number" id="sim-unit-cost-input" step="0.01" min="0"
          placeholder="Enter unit cost for profit calc"
          style="width:100%%;padding:6px 8px;border:1px solid var(--sim-border);border-radius:4px;font-size:13px;">
        <div style="font-size:10px;color:var(--sim-text-muted);margin-top:3px;">
          Set unit cost to enable profit index calculations
        </div>
      </div>
    </div>

    <!-- Results Panel -->
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
        %s
      </div>

      <div class="sim-chart-area">
        <div class="sim-chart-title">Demand &amp; Revenue Curves</div>
        <div id="sim-chart-svg"></div>
      </div>
    </div>
  </div>

  <!-- Scenario Comparison Section -->
  <div class="sim-compare" id="sim-compare-section">
    <div class="sim-compare-header">
      <h3>Scenario Comparison</h3>
      <div class="sim-compare-actions">
        <button class="sim-btn sim-btn-outline" id="sim-compare-add">+ Add Scenario</button>
      </div>
    </div>
    <div class="sim-compare-note">
      Add pricing scenarios to compare side by side. Revenue and Profit indices are scaled to 100 at the revenue-maximising price &mdash; values below 100 indicate unrealised potential.
    </div>
    <div class="sim-compare-table-wrap">
      <table class="sim-compare-table" id="sim-compare-table">
        <thead><tr id="sim-compare-thead"></tr></thead>
        <tbody id="sim-compare-tbody"></tbody>
      </table>
    </div>
  </div>

</div>

<div class="sim-footer">
  TURAS Pricing Simulator &middot; Generated %s &middot; For internal use only
</div>

<script>
  var PRICING_DATA = %s;
  var PRICING_CONFIG = %s;
</script>
<script>%s</script>
<script>
  document.addEventListener("DOMContentLoaded", function() {
    TurasSimulator.init(PRICING_DATA, PRICING_CONFIG);
  });
</script>

</body>
</html>',
    format(Sys.time(), "%Y-%m-%dT%H:%M"),
    htmlEscape_sim(project_name),
    css,
    htmlEscape_sim(project_name),
    segment_section,
    profit_card,
    format(Sys.Date(), "%B %Y"),
    pricing_json,
    config_json,
    js
  )
}

htmlEscape_sim <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}
