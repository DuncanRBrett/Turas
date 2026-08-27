# ==============================================================================
# CONJOINT MARKET SIMULATOR - ENTRY POINT
# ==============================================================================
#
# Produces a standalone, self-contained market simulator: one HTML file the
# client can open, share and use without the analysis report around it.
#
# HISTORY: the simulator was a standalone tool, was folded into the combined
# HTML report in March 2026, and is standalone again now that the report layer
# has been retired (the same retirement tabs made on 2026-08-05). It is a tool,
# not report content - the v2 report links to it rather than embedding it,
# which is programme decision D2.
#
# ==============================================================================

# Resolve this file's own directory, whichever way it was sourced. sys.frame's
# ofile is only set for a plain source(); under source(local = TRUE), inside a
# test, or from a different working directory it is not, so fall back to
# walking up for the repo.
.cj_sim_dir <- local({
  d <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NULL)
  if (!is.null(d) && nzchar(d) &&
      file.exists(file.path(d, "01_simulator_parts.R"))) {
    return(normalizePath(d, winslash = "/", mustWork = FALSE))
  }

  rel <- file.path("modules", "conjoint", "lib", "html_simulator")
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

if (file.exists(file.path(.cj_sim_dir, "01_simulator_parts.R"))) {
  source(file.path(.cj_sim_dir, "01_simulator_parts.R"))
}


#' Generate the Standalone Market Simulator
#'
#' @param results The list returned by `run_conjoint_analysis()` (needs
#'   `utilities`, `importance`, `model_result` and `config`).
#' @param output_path Path for the HTML file.
#' @param config Optional report-style config (brand colours, project name).
#' @param verbose Logical.
#'
#' @return A list with `status`, `output_path` and `file_size_mb`, or a TRS
#'   refusal.
#'
#' @export
generate_conjoint_simulator <- function(results, output_path,
                                        config = list(), verbose = TRUE) {

  utilities <- results$utilities
  importance <- results$importance
  model_result <- results$model_result
  module_config <- results$config %||% list()

  if (is.null(utilities) || !is.data.frame(utilities) || nrow(utilities) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_SIMULATOR_NO_UTILITIES",
      message = "No part-worth utilities, so there is nothing to simulate.",
      how_to_fix = "Run the analysis first; the simulator is built from its utilities table."
    ))
  }

  # A with-interactions model cannot be simulated from a part-worth table: the
  # interaction coefficients are not in it, so every share would come from a
  # main-effects model the study did not estimate. Same gate the report used.
  if (isTRUE(attr(utilities, "has_interactions")) ||
      isTRUE(model_result$has_interactions)) {
    return(list(
      status = "REFUSED",
      code = "CALC_INTERACTIONS_NOT_IN_SIMULATOR",
      message = paste0(
        "This model includes interaction terms. A part-worth utilities table ",
        "cannot carry them, so simulated shares would come from a ",
        "main-effects model that was never estimated."
      ),
      how_to_fix = paste0(
        "Clear interaction_terms in the Settings sheet to produce a simulator, ",
        "or read the interaction result from the Excel workbook."
      )
    ))
  }

  brand <- config$brand_colour %||% module_config$brand_colour %||% "#323367"
  accent <- config$accent_colour %||% module_config$accent_colour %||% "#CC9900"
  project <- config$project_name %||% module_config$project_name %||% "Market Simulator"

  sim_data <- .build_simulator_data(utilities, importance, model_result,
                                    module_config, config)
  if (is.null(sim_data)) {
    return(list(
      status = "REFUSED",
      code = "DATA_SIMULATOR_BUILD_FAILED",
      message = "The simulator data could not be built from the utilities table.",
      how_to_fix = "Check the console above for what the analysis produced."
    ))
  }

  # The island, hardened the way every Turas island is: escape every "<" as its
  # JSON unicode escape, so an attribute or level name can never close the
  # script tag. Valid JSON; JSON.parse restores it.
  sim_json <- gsub("<", "\\\\u003c", simulator_data_to_json(sim_data), fixed = TRUE)

  js <- .cj_sim_read_js(c("simulator_engine.js", "simulator_charts.js",
                          "simulator_ui.js", "simulator_page.js"))
  if (is.null(js)) {
    return(list(
      status = "REFUSED",
      code = "IO_SIMULATOR_JS_MISSING",
      message = "The simulator's JavaScript could not be read.",
      how_to_fix = sprintf("Expected it in %s", file.path(.cj_sim_dir, "js"))
    ))
  }

  panel <- build_simulator_panel(list(simulator_data = sim_data), brand)

  html <- .cj_sim_page(project = project, brand = brand, accent = accent,
                       panel = panel, sim_json = sim_json, js = js,
                       meta = sim_data$meta)

  con <- file(output_path, open = "wb", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(enc2utf8(html), con, useBytes = TRUE)

  size_mb <- round(file.info(output_path)$size / 1024^2, 2)
  if (verbose) {
    cat(sprintf("  [SIMULATOR] Written to: %s (%.2f MB)\n",
                output_path, size_mb))
  }

  list(status = "PASS", output_path = output_path, file_size_mb = size_mb)
}


#' Read and Concatenate the Simulator's JavaScript
#'
#' @keywords internal
.cj_sim_read_js <- function(files) {
  js_dir <- file.path(.cj_sim_dir, "js")
  paths <- file.path(js_dir, files)
  if (!all(file.exists(paths))) return(NULL)

  bundle <- paste(vapply(paths, function(p) {
    paste(readLines(p, warn = FALSE), collapse = "\n")
  }, character(1)), collapse = "\n\n")

  # Inlining is only safe if the bundle cannot close its own tag.
  if (grepl("</script", bundle, fixed = TRUE)) return(NULL)

  bundle
}


#' The Standalone Page
#'
#' @keywords internal
.cj_sim_page <- function(project, brand, accent, panel, sim_json, js, meta) {

  css <- build_conjoint_css(brand, accent)

  subtitle <- paste(c(
    if (!is.null(meta$estimation_method)) sprintf("Estimated with %s", meta$estimation_method),
    if (!is.null(meta$n_respondents) && !is.na(meta$n_respondents)) {
      sprintf("%s respondents", format(meta$n_respondents, big.mark = ","))
    }
  ), collapse = " &middot; ")

  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s &mdash; Market Simulator</title>
<style>
%s
/* The simulator stands alone here, so its panel is always the visible one. */
.cj-panel { display: block !important; }
.cj-sim-standalone-main { padding: 24px 40px 60px; max-width: 1400px; margin: 0 auto; }
.cj-sim-standalone-note { font-size: 13px; color: #64748b; margin: 0 0 18px; }
</style>
</head>
<body>
<header class="cj-header">
  <h1 style="margin:0;font-size:22px;">%s</h1>
  <div style="opacity:.85;font-size:13px;margin-top:4px;">Market Simulator%s</div>
</header>
<main class="cj-sim-standalone-main">
<p class="cj-sim-standalone-note">Shares are computed in your browser from the study&rsquo;s part-worth utilities. Nothing is sent anywhere.</p>
%s
</main>
<script type="application/json" id="cj-simulator-data">%s</script>
<script>
%s
</script>
<script>
(function () {
  var el = document.getElementById("cj-simulator-data");
  if (!el) return;
  var data;
  try { data = JSON.parse(el.textContent); } catch (e) {
    console.warn("Simulator data failed to parse:", e);
    return;
  }
  if (!data || !data.attributes) return;
  if (typeof SimEngine !== "undefined") SimEngine.init(data);
  if (typeof SimCharts !== "undefined" && SimCharts.setBrand) SimCharts.setBrand("%s");
  if (typeof SimUI !== "undefined") {
    if (data.meta && data.meta.default_customers && SimUI.setRevenueCustomers) {
      SimUI.setRevenueCustomers(data.meta.default_customers);
    }
    SimUI.init();
  }
}());
</script>
</body>
</html>',
    .html_escape(project), css, .html_escape(project),
    if (nzchar(subtitle)) paste0(" &middot; ", subtitle) else "",
    panel, sim_json, js, brand)
}


message(sprintf("TURAS>Conjoint standalone Market Simulator loaded (v%s)",
                if (exists("CONJOINT_SIMULATOR_VERSION")) CONJOINT_SIMULATOR_VERSION else "?"))
