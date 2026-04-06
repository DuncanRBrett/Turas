# ==============================================================================
# KEYDRIVER HTML REPORT - PAGE BUILDER (Orchestrator)
# ==============================================================================
# Assembles the complete HTML page from sub-modules.
# Split files:
#   03a_page_styling.R      - CSS stylesheet generation
#   03b_page_components.R   - Header, nav, action bar, insight areas, pin btns
#   03c_section_builders.R  - All report section builders
# ==============================================================================

# Source the shared design system (TURAS_ROOT-aware)
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
  if (!dir.exists(ds_dir)) ds_dir <- file.path("modules", "shared", "lib", "design_system")
  if (!exists("turas_base_css", mode = "function") && dir.exists(ds_dir)) {
    source(file.path(ds_dir, "design_tokens.R"), local = FALSE)
    source(file.path(ds_dir, "font_embed.R"), local = FALSE)
    source(file.path(ds_dir, "base_css.R"), local = FALSE)
  }
  # Source callout registry (with fallback if shared library unavailable)
  callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
  if (!dir.exists(callout_dir)) callout_dir <- file.path("modules", "shared", "lib", "callouts")
  if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
    tryCatch(
      source(file.path(callout_dir, "callout_registry.R"), local = FALSE),
      error = function(e) message("[KD HTML] Callout registry load failed: ", e$message)
    )
  }
  # No-op fallback: if callout registry is unavailable (CLI, standalone, test),
  # define a stub that returns empty string so section builders don't fail
  if (!exists("turas_callout", mode = "function")) {
    turas_callout <<- function(...) ""
  }
  # Source shared pin library loader
  pins_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!file.exists(pins_path)) pins_path <- file.path("modules", "shared", "lib", "turas_pins_js.R")
  if (!exists("turas_pins_js", mode = "function") && file.exists(pins_path)) {
    source(pins_path, local = FALSE)
  }
})

# Null-coalescing operator (existence guard)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}


#' Build Complete Keydriver HTML Page
#'
#' Assembles all report components into a single browsable HTML page.
#' The page is fully self-contained (CSS, JS, charts, tables inlined).
#' Sections that have no data are silently omitted.
#'
#' @param html_data Transformed data from transform_keydriver_for_html()
#' @param tables Named list of htmltools table objects
#' @param charts Named list of htmltools SVG chart objects
#' @param config Configuration list
#' @return htmltools::browsable tagList
#' @keywords internal
build_kd_html_page <- function(html_data, tables, charts, config) {

  brand_colour  <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title  <- config$report_title %||% html_data$analysis_name %||%
    "Key Driver Analysis"

  # --- Section visibility settings (all default TRUE) ---
  settings <- config$settings %||% list()
  .show <- function(key, default = TRUE) {
    val <- settings[[key]]
    if (is.null(val)) return(default)
    isTRUE(as.logical(val))
  }

  show_exec     <- .show("html_show_exec_summary")
  show_imp      <- .show("html_show_importance")
  show_methods  <- .show("html_show_methods")
  show_effect   <- .show("html_show_effect_sizes")
  show_corr     <- .show("html_show_correlations")
  show_quad     <- .show("html_show_quadrant")
  show_shap     <- .show("html_show_shap")
  show_diag     <- .show("html_show_diagnostics")
  show_boot     <- .show("html_show_bootstrap")
  show_seg      <- .show("html_show_segments")
  show_guide    <- .show("html_show_guide")

  corr_display  <- tolower(settings$correlation_display %||% "heatmap")
  boot_display  <- tolower(settings$bootstrap_display %||% "summary")

  # Build CSS
  css <- build_kd_css(config)

  # Build sections — gated by visibility settings
  header_section <- build_kd_header(html_data, config)
  action_bar     <- build_kd_action_bar(report_title)
  nav            <- build_kd_nav(html_data, settings)

  exec_summary_section <- if (show_exec) {
    build_kd_exec_summary_section(html_data, config)
  }
  importance_section <- if (show_imp) {
    build_kd_importance_section(charts, tables, html_data, config)
  }
  method_section <- if (show_methods) {
    build_kd_method_section(charts, tables, html_data, config)
  }
  effect_size_section <- if (show_effect) {
    build_kd_effect_size_section(charts, tables, html_data, config)
  }
  correlation_section <- if (show_corr) {
    build_kd_correlation_section(charts, tables, corr_display, config)
  }
  quadrant_section <- if (show_quad) {
    build_kd_quadrant_section(charts, tables, html_data, config)
  }
  shap_section <- if (show_shap) {
    build_kd_shap_section(html_data, charts, config)
  }
  diagnostics_section <- if (show_diag) {
    build_kd_diagnostics_section(tables, html_data, config)
  }
  bootstrap_section <- if (show_boot) {
    build_kd_bootstrap_section(charts, tables, html_data, boot_display, config)
  }
  segment_section <- if (show_seg) {
    build_kd_segment_section(charts, tables, html_data, config)
  }

  # v10.4 advanced feature sections (shown only when data is present)
  elastic_net_section <- if (isTRUE(html_data$has_elastic_net)) {
    build_kd_elastic_net_section(html_data, config)
  }
  nca_section <- if (isTRUE(html_data$has_nca)) {
    build_kd_nca_section(html_data, config)
  }
  dominance_section <- if (isTRUE(html_data$has_dominance)) {
    build_kd_dominance_section(html_data, config)
  }
  gam_section <- if (isTRUE(html_data$has_gam)) {
    build_kd_gam_section(html_data, config)
  }

  interpretation_section <- if (show_guide) {
    build_kd_interpretation_guide()
  }
  pinned_section <- build_kd_pinned_panel(config)
  footer_section <- build_kd_footer(config)

  # Hidden pinned views data store
  pinned_store <- htmltools::tags$script(
    id = "kd-pinned-views-data",
    type = "application/json",
    "[]"
  )

  # Read JS files
  js_tags <- build_kd_js(.kd_html_report_dir)

  # Report Hub metadata
  source_filename <- basename(config$output_file %||%
                               config$report_title %||% "Keydriver_Report")
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "keydriver"),
    htmltools::tags$meta(name = "turas-module-version", content = "1.0"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # Report-level tab bar (Analysis | Added Slides | Pinned Views)
  report_tab_bar <- htmltools::tags$div(
    class = "kd-report-tabs",
    htmltools::tags$button(
      class = "kd-report-tab active",
      `data-kd-tab` = "content",
      onclick = "kdSwitchReportTab('content')",
      "Analysis"
    ),
    htmltools::tags$button(
      class = "kd-report-tab",
      `data-kd-tab` = "slides",
      onclick = "kdSwitchReportTab('slides')",
      "\U0001F4DD Added Slides"
    ),
    htmltools::tags$button(
      class = "kd-report-tab",
      `data-kd-tab` = "pinned",
      onclick = "kdSwitchReportTab('pinned')",
      "\U0001F4CC Pinned Views",
      htmltools::tags$span(
        class = "kd-pin-count-badge",
        id = "kd-pin-count-badge",
        style = "display:none;",
        "0"
      )
    )
  )

  # Assemble page
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(
        name = "viewport",
        content = "width=device-width, initial-scale=1"
      ),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "kd-body",
      # Skip-to-content link (accessibility)
      htmltools::tags$a(
        class = "kd-skip-link",
        href = "#kd-tab-content",
        "Skip to content"
      ),
      header_section,
      action_bar,
      report_tab_bar,
      htmltools::tags$main(
        class = "kd-main",
        # Tab panel 1: Analysis content
        htmltools::tags$div(
          id = "kd-tab-content",
          class = "kd-tab-panel active",
          nav,
          htmltools::tags$div(
            class = "kd-content",
            exec_summary_section,
            importance_section,
            method_section,
            effect_size_section,
            correlation_section,
            quadrant_section,
            shap_section,
            diagnostics_section,
            bootstrap_section,
            segment_section,
            elastic_net_section,
            nca_section,
            dominance_section,
            gam_section,
            interpretation_section,
            footer_section
          )
        ),
        # Tab panel 2: Added Slides
        htmltools::tags$div(
          id = "kd-tab-slides",
          class = "kd-tab-panel",
          htmltools::tags$div(
            class = "kd-content",
            htmltools::tags$div(
              class = "kd-slides-panel",
              htmltools::tags$div(
                class = "kd-slides-header",
                htmltools::tags$h2("Added Slides"),
                htmltools::tags$p(style = "font-size:12px;color:#64748b;margin:4px 0 0;",
                  "Create custom commentary slides with text and images. Pin slides to Pinned Views for export."),
                htmltools::tags$div(
                  class = "kd-slides-toolbar",
                  htmltools::tags$button(
                    class = "kd-pinned-panel-btn",
                    onclick = "kdAddQualSlide()",
                    "\U0001F4DD + New Slide"
                  ),
                  htmltools::tags$button(
                    class = "kd-pinned-panel-btn",
                    onclick = "kdPinAllQualSlides()",
                    "\U0001F4CC Pin All to Views"
                  )
                )
              ),
              htmltools::tags$div(id = "kd-qual-slides-container",
                class = "kd-qual-slides-container"),
              htmltools::tags$div(id = "kd-qual-slides-empty",
                class = "kd-pinned-empty",
                htmltools::tags$div(class = "kd-pinned-empty-icon", "\U0001F4DD"),
                htmltools::tags$div("No slides yet. Click '+ New Slide' to add one.")
              )
            )
          )
        ),
        # Tab panel 3: Pinned Views
        htmltools::tags$div(
          id = "kd-tab-pinned",
          class = "kd-tab-panel",
          htmltools::tags$div(
            class = "kd-content",
            pinned_section
          )
        ),
        pinned_store
      ),
      js_tags
    )
  )

  htmltools::browsable(page)
}


