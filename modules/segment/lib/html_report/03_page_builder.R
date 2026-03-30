# ==============================================================================
# SEGMENT HTML REPORT - PAGE BUILDER (Orchestrator)
# ==============================================================================
# Assembles the complete HTML page from sub-modules.
# Split files:
#   03a_page_styling.R      - CSS stylesheet generation
#   03b_page_components.R   - Nav, header, insight areas, toolbars, action bar
#   03c_section_builders.R  - All report section builders (exec summary,
#                             overview, validation, profiles, cards, etc.)
# Design system: Turas muted palette, clean typography, seg- CSS prefix.
# Version: 12.0
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
  # Source callout registry
  callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
  if (!dir.exists(callout_dir)) callout_dir <- file.path("modules", "shared", "lib", "callouts")
  if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
    source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
    # Prime callout cache with TURAS_ROOT-resolved path (avoids getwd() issues)
    json_path <- file.path(callout_dir, "callouts.json")
    if (file.exists(json_path) && is.null(.callout_cache$data)) {
      tryCatch({
        cdata <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
        cdata[["_meta"]] <- NULL
        .callout_cache$data <- cdata
      }, error = function(e) NULL)
    }
  }
  # Source shared TurasPins JS loader
  pins_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!file.exists(pins_path)) {
    pins_path <- file.path("modules", "shared", "lib", "turas_pins_js.R")
  }
  if (!exists("turas_pins_js", mode = "function") && file.exists(pins_path)) {
    source(pins_path, local = FALSE)
  }
})


#' Build Complete Segment HTML Page
#'
#' Assembles all report components into a single browsable HTML page.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @param tables Named list of htmltools table objects
#' @param charts Named list of htmltools SVG chart objects
#' @param config Configuration list
#' @return htmltools::browsable tagList
#' @keywords internal
build_seg_html_page <- function(html_data, tables, charts, config) {

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title <- config$report_title %||% html_data$analysis_name

  # Store config insights for use by build_seg_insight_area
  .seg_config_insights <<- config$insights

  # Build CSS
  css <- build_seg_css(brand_colour, accent_colour)

  # Determine section visibility from config flags
  show_rules <- isTRUE(config$html_show_rules) &&
    !is.null(html_data$enhanced$classification_rules)
  show_cards <- isTRUE(config$html_show_cards %||% TRUE) &&
    !is.null(html_data$enhanced$segment_cards)
  show_gmm <- (html_data$method %in% c("gmm", "mclust")) &&
    !is.null(html_data$gmm_membership)
  show_exec <- isTRUE(config$html_show_exec_summary %||% TRUE)
  show_overview <- isTRUE(config$html_show_overview %||% TRUE)
  show_validation <- isTRUE(config$html_show_validation %||% TRUE)
  show_importance <- isTRUE(config$html_show_importance %||% TRUE) &&
    !is.null(html_data$variable_importance)
  show_profiles <- isTRUE(config$html_show_profiles %||% TRUE) &&
    !is.null(html_data$profile_data)
  show_vulnerability <- !is.null(html_data$vulnerability)
  show_overlap <- !is.null(html_data$centers) && html_data$k > 1
  show_golden_questions <- !is.null(html_data$golden_questions) &&
    !is.null(html_data$golden_questions$top_questions)
  show_guide <- isTRUE(config$html_show_guide %||% TRUE)

  # Build sections config for nav (analysis sections only; pinned views is a report-level tab)
  sections_config <- list(
    `exec-summary` = list(label = "Summary", show = show_exec),
    overview       = list(label = "Overview", show = show_overview),
    validation     = list(label = "Validation", show = show_validation),
    overlap        = list(label = "Overlap", show = show_overlap),
    importance     = list(label = "Importance", show = show_importance),
    `golden-questions` = list(label = "Golden Questions", show = show_golden_questions),
    profiles       = list(label = "Profiles", show = show_profiles),
    rules          = list(label = "Rules", show = show_rules),
    cards          = list(label = "Segment Cards", show = show_cards),
    vulnerability  = list(label = "Vulnerability", show = show_vulnerability),
    gmm            = list(label = "GMM Membership", show = show_gmm),
    guide          = list(label = "Guide", show = show_guide)
  )

  # Build sections
  header_section <- build_seg_header(html_data, config, brand_colour, report_title)
  nav <- build_seg_section_nav(brand_colour, sections_config)
  action_bar <- build_seg_action_bar(report_title)

  exec_summary_section <- if (show_exec) {
    build_seg_exec_summary_section(html_data, brand_colour)
  }
  overview_section <- if (show_overview) {
    build_seg_overview_section(tables, charts, html_data)
  }
  validation_section <- if (show_validation) {
    build_seg_validation_section(tables, charts, html_data)
  }
  importance_section <- if (show_importance) {
    build_seg_importance_section(tables, charts, html_data)
  }
  profiles_section <- if (show_profiles) {
    build_seg_profiles_section(tables, charts, html_data)
  }
  rules_section <- if (show_rules) {
    build_seg_rules_section(tables, html_data)
  }
  cards_section <- if (show_cards) {
    build_seg_cards_section(html_data)
  }
  overlap_section <- if (show_overlap) {
    build_seg_overlap_section(charts, html_data)
  }
  golden_questions_section <- if (show_golden_questions) {
    build_seg_golden_questions_section(charts, html_data)
  }
  vulnerability_section <- if (show_vulnerability) {
    build_seg_vulnerability_section(html_data)
  }
  gmm_section <- if (show_gmm) {
    build_seg_gmm_section(tables, html_data)
  }
  guide_section <- if (show_guide) {
    build_seg_guide_section(brand_colour)
  }
  footer_section <- build_seg_footer(config)

  # Pinned Views section
  pinned_section <- htmltools::tags$div(
    class = "seg-section",
    id = "seg-pinned-section",
    `data-seg-section` = "pinned-views",
    htmltools::tags$div(
      class = "seg-pinned-panel-header",
      htmltools::tags$div(class = "seg-pinned-panel-title",
                          "\U0001F4CC Pinned Views"),
      htmltools::tags$div(
        class = "seg-pinned-panel-actions",
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segAddSection()",
          "\u2795 Add Section"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segExportAllPinnedPNG()",
          "\U0001F4E5 Export All as PNG"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segPrintPinnedViews()",
          "\U0001F5B6 Print / PDF"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segClearAllPinned()",
          "\U0001F5D1 Clear All"
        )
      )
    ),
    htmltools::tags$div(
      id = "seg-pinned-empty",
      class = "seg-pinned-empty",
      htmltools::tags$div(class = "seg-pinned-empty-icon", "\U0001F4CC"),
      htmltools::tags$div("No pinned views yet.")
    ),
    htmltools::tags$div(id = "seg-pinned-cards-container")
  )

  # Hidden insight store
  insight_store <- htmltools::tags$textarea(
    class = "seg-insight-store",
    id = "seg-insight-store",
    `data-seg-prefix` = "",
    style = "display:none;",
    "{}"
  )

  # Hidden pinned views data store
  pinned_store <- htmltools::tags$script(
    id = "seg-pinned-views-data",
    type = "application/json",
    "[]"
  )

  # Load shared TurasPins library (required by seg_pins.js)
  shared_js_tag <- if (exists("turas_pins_js", mode = "function")) {
    shared_js <- turas_pins_js()
    if (nzchar(shared_js)) htmltools::tags$script(htmltools::HTML(shared_js))
  }

  # Read module JS files
  js_files <- c("seg_utils.js", "seg_navigation.js",
                "seg_pins.js", "seg_pins_extras.js")
  js_tags <- lapply(js_files, function(fname) {
    js_path <- file.path(.seg_html_report_dir, "js", fname)
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
                               config$report_title %||% "Segment_Report")
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "segment"),
    htmltools::tags$meta(name = "turas-module-version", content = "11.0"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # Report-level tab bar — shared convention (report-tabs / report-tab)
  save_icon <- htmltools::HTML('<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:5px;"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>')

  report_tab_bar <- htmltools::tags$div(
    class = "report-tabs",
    htmltools::tags$button(
      class = "report-tab active",
      `data-tab` = "analysis",
      onclick = "switchReportTab('analysis')",
      "Analysis"
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "pinned",
      onclick = "switchReportTab('pinned')",
      "Pinned Views",
      htmltools::tags$span(
        id = "seg-pin-count-badge",
        class = "seg-pin-count-badge"
      )
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "slides",
      onclick = "switchReportTab('slides')",
      "Added Slides",
      htmltools::tags$span(
        id = "seg-slide-count-badge",
        class = "seg-pin-count-badge",
        style = "display:none;"
      )
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "about",
      onclick = "switchReportTab('about')",
      "About"
    ),
    htmltools::tags$button(
      class = "report-tab seg-save-tab",
      onclick = "segSaveReportHTML()",
      save_icon, "Save Report"
    ),
    htmltools::tags$button(
      class = "seg-help-btn",
      onclick = "toggleHelpOverlay()",
      title = "Show help guide",
      "?"
    )
  )

  # Assemble page
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(name = "viewport",
                           content = "width=device-width, initial-scale=1"),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "seg-body",
      header_section,
      action_bar,
      report_tab_bar,
      nav,
      htmltools::tags$main(
        class = "seg-main",
        # Analysis tab — active by default
        htmltools::tags$div(
          id = "tab-analysis",
          class = "tab-panel active seg-content",
          exec_summary_section,
          overview_section,
          validation_section,
          overlap_section,
          importance_section,
          golden_questions_section,
          profiles_section,
          rules_section,
          cards_section,
          vulnerability_section,
          gmm_section,
          guide_section,
          footer_section
        ),
        # Pinned Views tab
        htmltools::tags$div(
          id = "tab-pinned",
          class = "tab-panel seg-content",
          pinned_section,
          footer_section
        ),
        # Slides tab
        htmltools::tags$div(
          id = "tab-slides",
          class = "tab-panel seg-content",
          build_seg_slides_section(config),
          footer_section
        ),
        # About tab
        htmltools::tags$div(
          id = "tab-about",
          class = "tab-panel seg-content",
          build_seg_about_section(config, html_data),
          footer_section
        ),
        insight_store,
        pinned_store
      ),
      js_tags
    )
  )

  htmltools::browsable(page)
}

