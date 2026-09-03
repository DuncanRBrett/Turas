# ==============================================================================
# TURAS PRICING - STANDALONE SIMULATOR: ENTRY POINT
# ==============================================================================
#
# Produces a standalone, self-contained price simulator: one HTML file the
# client can open, share and use without the analysis report around it.
#
# HISTORY: the simulator was a standalone tool, was folded into the combined
# pricing HTML report in March 2026, and is standalone again now that the
# report layer is retired (the retirement tabs made on 2026-08-05 and conjoint
# on 2026-08-27). It is a tool, not report content: the v2 Pricing tab links to
# it rather than embedding it, which is programme decision D2.
#
# ==============================================================================

# Resolve this file's own directory, whichever way it was sourced. sys.frame's
# ofile is only set for a plain source(); under source(local = TRUE), inside a
# test, or from a different working directory it is not, so fall back to
# walking up for the repo. Same resolver the conjoint simulator uses.
.pr_sim_dir <- local({
  d <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NULL)
  if (!is.null(d) && nzchar(d) &&
      file.exists(file.path(d, "01_simulator_parts.R"))) {
    return(normalizePath(d, winslash = "/", mustWork = FALSE))
  }
  rel <- file.path("modules", "pricing", "lib", "html_simulator")
  roots <- c(Sys.getenv("TURAS_ROOT", ""), Sys.getenv("TURAS_HOME", ""))
  roots <- roots[nzchar(roots)]
  w <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:10) {
    roots <- c(roots, w)
    parent <- dirname(w)
    if (identical(parent, w)) break
    w <- parent
  }
  hits <- file.path(roots, rel)
  hits <- hits[file.exists(file.path(hits, "01_simulator_parts.R"))]
  if (length(hits) > 0) hits[[1L]] else rel
})

if (file.exists(file.path(.pr_sim_dir, "01_simulator_parts.R"))) {
  source(file.path(.pr_sim_dir, "01_simulator_parts.R"))
}


#' Generate The Standalone Price Simulator
#'
#' @param results The list returned by `run_pricing_analysis()` (needs
#'   `results`, `method` and optionally `segment_results`).
#' @param output_path Path for the HTML file.
#' @param config The loaded pricing configuration (currency, brand, unit cost,
#'   project name, any preset scenarios).
#' @param verbose Logical.
#'
#' @return A list with `status`, `output_file` and `file_size_mb`, or a
#'   structured refusal when there is no curve to simulate against.
#'
#' @export
generate_pricing_simulator <- function(results, output_path, config = list(),
                                       verbose = TRUE) {

  method <- tolower(results$method %||% config$analysis_method %||% "unknown")
  demand <- extract_demand_data(results$results, method)

  if (is.null(demand) || length(demand$price_range) < 2) {
    return(list(
      status = "REFUSED",
      code = "DATA_SIMULATOR_NO_CURVE",
      message = paste0(
        "This run produced no demand curve, so there is no relationship ",
        "between price and intent for a simulator to move along."),
      how_to_fix = paste0(
        "Run a Gabor-Granger or monadic method. A Van Westendorp study on its ",
        "own measures price perceptions, not demand at a price.")
    ))
  }

  optimal <- extract_optimal_price(results$results, method)
  segments <- extract_segment_demand(results$segment_results, method)

  brand <- as.character(config$brand_colour %||% "#323367")
  accent <- as.character(config$accent_colour %||% "#CC9900")
  project <- as.character(config$project_name %||% "Pricing")
  unit_cost <- suppressWarnings(as.numeric(config$unit_cost %||% 0))
  if (!is.finite(unit_cost)) unit_cost <- 0

  css_path <- file.path(.pr_sim_dir, "simulator_styles.css")
  js_path <- file.path(.pr_sim_dir, "js", "pricing_simulator.js")
  if (!file.exists(css_path) || !file.exists(js_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_SIMULATOR_ASSETS_MISSING",
      message = "The simulator's stylesheet or JavaScript could not be read.",
      how_to_fix = sprintf("Expected them in %s", .pr_sim_dir)
    ))
  }

  css <- paste(readLines(css_path, warn = FALSE), collapse = "\n")
  css <- gsub("BRAND_TOKEN", brand, css, fixed = TRUE)
  css <- gsub("ACCENT_TOKEN", accent, css, fixed = TRUE)
  js <- paste(readLines(js_path, warn = FALSE), collapse = "\n")

  # Inlining is only safe if neither bundle can close its own tag.
  if (grepl("</script", js, fixed = TRUE) || grepl("</style", css, fixed = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "IO_SIMULATOR_ASSETS_UNSAFE",
      message = "The simulator's assets contain a closing tag and cannot be inlined.",
      how_to_fix = "Check the CSS and JavaScript in modules/pricing/lib/html_simulator/."
    ))
  }

  panel <- build_simulator_panel(has_segments = length(segments) > 0,
                                 has_unit_cost = unit_cost > 0)
  pricing_json <- build_pricing_json(demand, optimal, segments)
  config_json <- build_simulator_config_json(config)

  html <- .pricing_sim_page(project = project, panel = panel, css = css, js = js,
                            pricing_json = pricing_json, config_json = config_json,
                            method = method, n_prices = length(demand$price_range))

  out_dir <- dirname(output_path)
  if (!dir.exists(out_dir) && nzchar(out_dir) && out_dir != ".") {
    dir.create(out_dir, recursive = TRUE)
  }
  con <- file(output_path, open = "wb", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(enc2utf8(html), con, useBytes = TRUE)

  size_mb <- round(file.info(output_path)$size / 1024^2, 3)
  if (verbose) {
    cat(sprintf("   Simulator: %s (%.0f KB)\n", basename(output_path),
                file.info(output_path)$size / 1024))
  }

  list(status = "PASS", output_file = output_path, file_size_mb = size_mb)
}


#' The Standalone Page
#' @keywords internal
.pricing_sim_page <- function(project, panel, css, js, pricing_json, config_json,
                              method, n_prices) {

  method_label <- switch(method,
    "gabor_granger" = "Gabor-Granger demand",
    "both" = "Gabor-Granger demand",
    "monadic" = "a monadic price test",
    method)

  subtitle <- sprintf("Price simulator &middot; built on %s across %d price points",
                      .pricing_sim_escape(method_label), n_prices)

  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="turas-report-type" content="pricing-simulator">
<title>%s: price simulator</title>
<style>
%s
</style>
</head>
<body>
<header class="sim-header">
  <h1>%s</h1>
  <div class="sim-sub">%s</div>
</header>
<main class="sim-main">
<p class="sim-standalone-note">Everything here is computed in your browser from the study&rsquo;s own demand curve. Nothing is sent anywhere. Between the prices that were tested, intent is interpolated, so read the numbers as a guide to the shape of demand rather than as a forecast.</p>
%s
</main>
<script type="application/json" id="pricing-simulator-data">%s</script>
<script type="application/json" id="pricing-simulator-config">%s</script>
<script>
%s
</script>
<script>
(function () {
  function island(id) {
    var el = document.getElementById(id);
    if (!el) return null;
    try { return JSON.parse(el.textContent); } catch (e) {
      console.warn("Simulator island failed to parse:", id, e);
      return null;
    }
  }
  var data = island("pricing-simulator-data");
  var cfg = island("pricing-simulator-config");
  if (!data || !cfg) return;
  window.PRICING_DATA = data;
  window.PRICING_CONFIG = cfg;
  if (typeof PricingSimulator !== "undefined" && PricingSimulator.init) {
    PricingSimulator.init();
  }
}());
</script>
</body>
</html>',
    .pricing_sim_escape(project), css, .pricing_sim_escape(project), subtitle,
    panel, pricing_json, config_json, js)
}


message(sprintf("TURAS>Pricing standalone simulator loaded (v%s)",
                if (exists("PRICING_SIMULATOR_VERSION")) PRICING_SIMULATOR_VERSION else "?"))
