# ==============================================================================
# CATDRIVER HTML REPORT - PAGE BUILDER (Orchestrator)
# ==============================================================================
# Assembles the complete HTML page from sub-modules.
# Split files:
#   03a_page_styling.R      - CSS stylesheet generation
#   03b_page_components.R   - Nav, header, insight areas, help, action bar
#   03c_section_builders.R  - All report section builders
# All IDs and classes use cd- prefix for Report Hub namespace safety.
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
      error = function(e) message("[CD HTML] Callout registry load failed: ", e$message)
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

#' Build Complete Catdriver HTML Page
#'
#' Assembles all report components into a single browsable HTML page.
#'
#' @param html_data Transformed data from transform_catdriver_for_html()
#' @param tables Named list of htmltools table objects
#' @param charts Named list of htmltools SVG chart objects
#' @param config Configuration list
#' @return htmltools::browsable tagList
#' @keywords internal
build_cd_html_page <- function(html_data, tables, charts, config,
                                subgroup_comparison = NULL) {

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title <- config$report_title %||% html_data$analysis_name

  # Build CSS
  css <- build_cd_css(brand_colour, accent_colour)

  # Build sections
  header_section <- build_cd_header(html_data, config, brand_colour, report_title)
  exec_summary_section <- build_cd_exec_summary(html_data, brand_colour)
  importance_section <- build_cd_importance_section(tables, charts, brand_colour,
                                                     n_drivers = length(html_data$importance))
  patterns_section <- build_cd_patterns_section(html_data, tables)
  prob_lifts_section <- build_cd_probability_lifts_section(html_data, tables, charts)
  or_section <- build_cd_or_section(tables, charts, html_data$has_bootstrap,
                                     odds_ratios = html_data$odds_ratios)
  diagnostics_section <- build_cd_diagnostics_section(tables, html_data)

  # Subgroup comparison section (only when subgroup analysis is active)
  subgroup_section <- if (!is.null(subgroup_comparison) &&
                          exists("build_cd_subgroup_section", mode = "function")) {
    tryCatch(
      build_cd_subgroup_section(subgroup_comparison, brand_colour, accent_colour),
      error = function(e) {
        cat(sprintf("    [WARNING] Subgroup section failed: %s\n", e$message))
        NULL
      }
    )
  } else NULL

  interpretation_section <- build_cd_interpretation_section(brand_colour)

  # Qualitative slides section (from config or interactive)
  slides_data <- config$slides %||% NULL
  qualitative_section <- build_cd_qualitative_panel(slides_data, brand_colour)

  footer_section <- build_cd_footer(config)

  # Horizontal section nav bar
  nav <- build_cd_section_nav(brand_colour,
                               has_subgroup = !is.null(subgroup_section))

  # Action bar (save button)
  action_bar <- build_cd_action_bar(report_title)

  # Help overlay — comprehensive quick guide (same pattern as tabs module)
  help_overlay <- build_cd_help_overlay()

  # Help toggle JS
  help_js <- htmltools::tags$script(htmltools::HTML('
function cdToggleHelp() {
  var overlay = document.getElementById("cd-help-overlay");
  if (!overlay) return;
  overlay.classList.toggle("active");
}
'))

  # Hidden insight store (single report mode — no prefix)
  insight_store <- htmltools::tags$textarea(
    class = "cd-insight-store",
    id = "cd-insight-store",
    `data-cd-prefix` = "",
    style = "display:none;",
    "{}"
  )

  # Hidden pinned views data store
  pinned_store <- htmltools::tags$script(
    id = "cd-pinned-views-data",
    type = "application/json",
    "[]"
  )

  # Load shared TurasPins library first (required by cd_pins.js)
  shared_js_tag <- if (exists("turas_pins_js", mode = "function")) {
    shared_js <- turas_pins_js()
    if (nzchar(shared_js)) htmltools::tags$script(htmltools::HTML(shared_js))
  }

  # Read module JS files
  js_files <- c("cd_utils.js", "cd_navigation.js", "cd_insights.js",
                 "cd_pins.js", "cd_qualitative.js", "cd_table_export.js")
  js_tags <- lapply(js_files, function(fname) {
    js_path <- file.path(.cd_html_report_dir, "js", fname)
    js_content <- if (file.exists(js_path)) {
      paste(readLines(js_path, warn = FALSE), collapse = "\n")
    } else {
      sprintf("/* %s not found */", fname)
    }
    htmltools::tags$script(htmltools::HTML(js_content))
  })
  # Prepend shared library before module JS
  if (!is.null(shared_js_tag)) js_tags <- c(list(shared_js_tag), js_tags)

  # Report Hub metadata
  source_filename <- basename(config$output_file %||%
                               config$report_title %||% "Catdriver_Report")
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "catdriver"),
    htmltools::tags$meta(name = "turas-module-version", content = "1.1"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # Pinned Views section — its own navigable page/section
  pinned_section <- htmltools::tags$div(
    class = "cd-section",
    id = "cd-pinned-section",
    `data-cd-section` = "pinned-views",
    htmltools::tags$div(
      class = "cd-pinned-panel-header",
      htmltools::tags$div(class = "cd-pinned-panel-title",
                          "\U0001F4CC Pinned Views"),
      htmltools::tags$div(
        class = "cd-pinned-panel-actions",
        htmltools::tags$button(
          class = "cd-pinned-panel-btn",
          onclick = "cdAddSection()",
          "\u2795 Add Section"
        ),
        htmltools::tags$button(
          class = "cd-pinned-panel-btn",
          onclick = "cdExportAllPinnedPNG()",
          "\U0001F4E5 Export All as PNG"
        ),
        htmltools::tags$button(
          class = "cd-pinned-panel-btn",
          onclick = "cdPrintPinnedViews()",
          "\U0001F5B6 Print / PDF"
        ),
        htmltools::tags$button(
          class = "cd-pinned-panel-btn",
          onclick = "cdClearAllPinned()",
          "\U0001F5D1 Clear All"
        )
      )
    ),
    htmltools::tags$div(
      id = "cd-pinned-empty",
      class = "cd-pinned-empty",
      htmltools::tags$div(class = "cd-pinned-empty-icon", "\U0001F4CC"),
      htmltools::tags$div("No pinned views yet.")
    ),
    htmltools::tags$div(id = "cd-pinned-cards-container")
  )

  # Assemble page — linear layout (no sidebar)
  # Header → action bar → sticky nav bar → content → pinned → footer
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "cd-body",
      header_section,
      action_bar,
      nav,
      htmltools::tags$main(
        class = "cd-main",
        htmltools::tags$div(
          class = "cd-content",
          exec_summary_section,
          importance_section,
          patterns_section,
          prob_lifts_section,
          or_section,
          diagnostics_section,
          subgroup_section,
          interpretation_section,
          qualitative_section,
          pinned_section,
          footer_section,
          help_overlay,
          insight_store,
          pinned_store
        )
      ),
      help_js,
      js_tags
    )
  )

  htmltools::browsable(page)
}


#' Build Catdriver CSS
#'
#' Generates the complete stylesheet aligned with the shared Turas design system.
#' Uses CSS variables for brand consistency across modules.
#'
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @return Character string of CSS
#' @keywords internal
