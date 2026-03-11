# ==============================================================================
# MAXDIFF SIMULATOR - PAGE BUILDER - TURAS V11.0
# ==============================================================================
# Assembles the interactive simulator HTML page

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

htmlEscape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

#' Build simulator HTML page
#'
#' @param sim_data List from build_simulator_data()
#' @param js_engine Character. Contents of simulator_engine.js
#' @param js_charts Character. Contents of simulator_charts.js
#' @param js_ui Character. Contents of simulator_ui.js
#'
#' @return HTML string
#' @keywords internal
build_simulator_page <- function(sim_data, js_engine, js_charts, js_ui) {

  brand <- sim_data$brand_colour %||% "#1e3a5f"
  project_name <- htmlEscape(sim_data$project_name %||% "MaxDiff Simulator")
  json_data <- jsonlite::toJSON(sim_data, auto_unbox = TRUE, digits = 4)

  # Build item select options
  item_options <- paste(vapply(sim_data$items, function(it) {
    sprintf('<option value="%s">%s</option>', htmlEscape(it$id), htmlEscape(it$label))
  }, character(1)), collapse = "\n")

  # Build portfolio checkboxes
  portfolio_checks <- paste(vapply(sim_data$items, function(it) {
    sprintf(
      '<label class="sim-check-label"><input type="checkbox" class="sim-portfolio-check" value="%s"> %s</label>',
      htmlEscape(it$id), htmlEscape(it$label)
    )
  }, character(1)), collapse = "\n")

  # Build segment filter (if segments defined)
  seg_filter <- ""
  if (length(sim_data$segments) > 0) {
    seg_options <- paste(vapply(sim_data$segments, function(s) {
      sprintf('<option value="%s:%s">%s</option>',
              htmlEscape(s$variable), htmlEscape(s$id), htmlEscape(s$label))
    }, character(1)), collapse = "\n")
    seg_filter <- sprintf(
      '<div class="sim-filter"><label>Segment: <select id="seg-filter"><option value="">All respondents</option>%s</select></label></div>',
      seg_options
    )
  }

  css <- build_simulator_css(brand)

  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="turas-report-type" content="maxdiff-simulator">
  <title>%s - MaxDiff Simulator</title>
  <style>%s</style>
</head>
<body>
  <div class="sim-header">
    <h1>%s</h1>
    <div class="sim-meta"><span>Interactive MaxDiff Simulator</span><span>%d items &middot; %d respondents</span></div>
  </div>
  <div class="sim-container">
    <div class="sim-tab-nav">
      <button class="sim-tab-btn active" data-tab="shares">Preference Shares</button>
      <button class="sim-tab-btn" data-tab="h2h">Head-to-Head</button>
      <button class="sim-tab-btn" data-tab="portfolio">Portfolio (TURF)</button>
    </div>
    <div class="sim-content">

      <div class="sim-panel active" id="panel-shares">
        <h2>Preference Shares</h2>
        <p class="sim-desc">Each item&#39;s probability of being chosen, calculated from individual-level utilities using the multinomial logit model. All shares sum to 100%%.</p>
        %s
        <div id="shares-chart"></div>
      </div>

      <div class="sim-panel" id="panel-h2h">
        <h2>Head-to-Head Comparator</h2>
        <p class="sim-desc">Select any two items to see the probability that a respondent would choose one over the other.</p>
        <div class="sim-h2h-controls">
          <select id="h2h-item-a">%s</select>
          <span class="sim-vs">vs</span>
          <select id="h2h-item-b">%s</select>
        </div>
        <div id="h2h-result"></div>
      </div>

      <div class="sim-panel" id="panel-portfolio">
        <h2>Portfolio Builder (TURF)</h2>
        <p class="sim-desc">Select items for your portfolio and see what %% of respondents find at least one appealing. Use Auto-Optimize to find the best combination.</p>
        <div class="sim-portfolio-controls">
          <div class="sim-portfolio-options">
            <label>Top-K threshold: <select id="turf-top-k">
              <option value="3" selected>Top 3</option>
              <option value="4">Top 4</option>
              <option value="5">Top 5</option>
            </select></label>
            <label>Max items: <select id="turf-max-items">
              <option value="3">3</option>
              <option value="5" selected>5</option>
              <option value="7">7</option>
              <option value="10">10</option>
            </select></label>
            <button id="turf-auto-optimize" class="sim-btn">Auto-Optimize</button>
          </div>
          <div id="turf-count" class="sim-turf-count">0 items selected</div>
        </div>
        <div class="sim-portfolio-grid">%s</div>
        <div id="turf-result"></div>
        <div id="turf-opt-result"></div>
      </div>

    </div>
  </div>
  <div class="sim-footer">TURAS MaxDiff Simulator v11.0 &middot; %s</div>
  <script type="application/json" id="sim-data">%s</script>
  <script>%s</script>
  <script>%s</script>
  <script>%s</script>
</body>
</html>',
    project_name,
    css,
    project_name,
    sim_data$n_items %||% 0,
    sim_data$n_respondents %||% 0,
    seg_filter,
    item_options,
    item_options,
    portfolio_checks,
    format(Sys.Date(), "%B %Y"),
    json_data,
    js_engine,
    js_charts,
    js_ui
  )
}


build_simulator_css <- function(brand) {
  css <- ':root { --sim-brand: BRAND_TOKEN; }
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f1f5f9; color: #1e293b; line-height: 1.5; font-size: 14px; }
.sim-header { background: var(--sim-brand); color: white; padding: 20px 28px; }
.sim-header h1 { font-size: 20px; font-weight: 600; }
.sim-meta { display: flex; gap: 16px; font-size: 12px; opacity: 0.85; }
.sim-container { max-width: 900px; margin: 0 auto; padding: 0 16px; }
.sim-tab-nav { display: flex; background: white; border-bottom: 1px solid #e2e8f0; border-radius: 8px 8px 0 0; margin-top: 20px; overflow-x: auto; }
.sim-tab-btn { background: transparent; border: none; padding: 10px 16px; font-size: 13px; font-weight: 500; color: #64748b; cursor: pointer; border-bottom: 2px solid transparent; white-space: nowrap; }
.sim-tab-btn.active { color: var(--sim-brand); border-bottom-color: var(--sim-brand); }
.sim-content { background: white; border-radius: 0 0 8px 8px; padding: 24px 28px; min-height: 400px; }
.sim-panel { display: none; }
.sim-panel.active { display: block; }
.sim-panel h2 { font-size: 17px; font-weight: 600; color: var(--sim-brand); margin-bottom: 8px; }
.sim-desc { font-size: 13px; color: #64748b; margin-bottom: 16px; }
.sim-filter { margin-bottom: 12px; }
.sim-filter select { padding: 4px 8px; border: 1px solid #e2e8f0; border-radius: 4px; font-size: 13px; }
/* Share bars */
.sim-share-bars { margin: 8px 0; }
.sim-bar-row { display: flex; align-items: center; margin-bottom: 6px; }
.sim-bar-label { width: 180px; font-size: 12px; font-weight: 500; text-align: right; padding-right: 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sim-bar-track { flex: 1; height: 26px; background: #f1f5f9; border-radius: 4px; overflow: hidden; }
.sim-bar-fill { height: 100%; border-radius: 4px; opacity: 0.8; transition: width 0.3s; }
.sim-bar-value { width: 55px; font-size: 12px; font-weight: 600; text-align: right; padding-left: 8px; }
/* Head-to-head */
.sim-h2h-controls { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
.sim-h2h-controls select { padding: 6px 10px; border: 1px solid #e2e8f0; border-radius: 4px; font-size: 13px; flex: 1; }
.sim-vs { font-weight: 700; color: #64748b; }
.sim-h2h { margin: 16px 0; }
.sim-h2h-bar { display: flex; height: 48px; border-radius: 6px; overflow: hidden; }
.sim-h2h-a, .sim-h2h-b { display: flex; align-items: center; justify-content: center; color: white; font-weight: 700; font-size: 18px; transition: width 0.3s; min-width: 40px; }
.sim-h2h-labels { display: flex; justify-content: space-between; margin-top: 6px; font-size: 13px; font-weight: 500; }
/* Portfolio */
.sim-portfolio-controls { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; }
.sim-portfolio-options { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.sim-portfolio-options select { padding: 4px 8px; border: 1px solid #e2e8f0; border-radius: 4px; font-size: 13px; }
.sim-btn { background: var(--sim-brand); color: white; border: none; padding: 6px 14px; border-radius: 4px; font-size: 13px; font-weight: 500; cursor: pointer; }
.sim-btn:hover { opacity: 0.9; }
.sim-turf-count { font-size: 13px; color: #64748b; font-weight: 500; }
.sim-portfolio-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 4px; margin-bottom: 16px; }
.sim-check-label { display: flex; align-items: center; gap: 6px; font-size: 13px; padding: 6px 8px; border-radius: 4px; cursor: pointer; }
.sim-check-label:hover { background: #f8fafc; }
/* TURF gauge */
.sim-turf-gauge { display: flex; align-items: center; gap: 20px; margin: 16px 0; }
.sim-turf-stats { font-size: 13px; color: #64748b; }
.sim-turf-opt-list { margin-top: 12px; font-size: 13px; }
.sim-turf-opt-list ol { padding-left: 20px; }
.sim-turf-opt-list li { margin-bottom: 4px; }
.sim-footer { text-align: center; padding: 20px; font-size: 11px; color: #64748b; }
@media (max-width: 600px) { .sim-content { padding: 16px; } .sim-bar-label { width: 120px; } }'

  gsub("BRAND_TOKEN", brand, css, fixed = TRUE)
}
