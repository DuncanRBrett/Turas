# ==============================================================================
# HTML REPORT - PAGE BUILDER (V10.8)
# ==============================================================================
# Main page assembler and JavaScript module loader.
# CSS styling is in 03a_page_styling.R.
# UI components are in 03b_page_components.R.
# Both files are auto-sourced by 99_html_report_main.R.
# ==============================================================================

# File-level helper: escape strings for safe insertion into JS single-quoted literals
js_esc <- function(s) gsub("'", "\\\\'", gsub("\\\\", "\\\\\\\\", as.character(s)))


#' Build Complete HTML Page
#'
#' Assembles all components into a single browsable HTML page.
#'
#' @param html_data List from transform_for_html()
#' @param tables Named list of htmltools::HTML table objects (keyed by q_code)
#' @param config_obj Configuration object
#' @return htmltools::browsable tagList
#' @export
build_html_page <- function(html_data, tables, config_obj,
                            dashboard_html = NULL, charts = list(),
                            source_filename = NULL,
                            qualitative_slides = NULL) {

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_JSONLITE",
      message = "Required package 'jsonlite' is not installed",
      how_to_fix = "Install it with: install.packages('jsonlite')"
    ))
  }

  brand_colour <- config_obj$brand_colour %||% "#323367"
  accent_colour <- config_obj$accent_colour %||% "#CC9900"
  project_title <- config_obj$project_title %||% "Crosstab Report"
  min_base <- config_obj$significance_min_base %||% 30
  has_any_sig <- any(sapply(html_data$questions, function(q) q$stats$has_sig))
  has_any_freq <- any(sapply(html_data$questions, function(q) q$stats$has_freq))
  has_any_pct <- any(sapply(html_data$questions, function(q) q$stats$has_col_pct || q$stats$has_row_pct))

  # Build crosstab content (always needed)
  crosstab_content <- htmltools::tags$div(
    class = "main-layout",
    id = "main-content",
    build_sidebar(html_data$questions, has_any_sig, brand_colour),
    htmltools::tags$div(
      class = "content-area",
      build_banner_tabs(html_data$banner_groups, brand_colour),
      build_controls(has_any_freq, has_any_pct, has_any_sig, brand_colour,
                     has_charts = length(charts) > 0),
      build_question_containers(html_data$questions, tables, html_data$banner_groups,
                                config_obj, charts = charts),
      build_footer(config_obj, min_base)
    )
  )

  # Build source-filename meta tag (used by saveReportHTML for _Updated.html naming)
  source_meta <- if (!is.null(source_filename) && nzchar(source_filename)) {
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  }

  if (!is.null(dashboard_html)) {
    # Dashboard mode: two tabs (Summary + Crosstabs)
    crosstab_panel <- htmltools::tags$div(
      id = "tab-crosstabs",
      class = "tab-panel",
      crosstab_content
    )

    pinned_panel <- htmltools::tags$div(
      id = "tab-pinned",
      class = "tab-panel",
      htmltools::tags$div(
        class = "pinned-views-container",
        style = "max-width:1400px;margin:0 auto;padding:20px 32px;",
        htmltools::tags$div(
          class = "pinned-header",
          style = "display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;",
          htmltools::tags$div(
            htmltools::tags$h2(style = "font-size:18px;font-weight:700;color:#1e293b;margin-bottom:4px;", "Pinned Views"),
            htmltools::tags$p(style = "font-size:12px;color:#64748b;", "Pin questions from the Crosstabs tab to create a curated set of key findings.")
          ),
          htmltools::tags$div(
            style = "display:flex;gap:8px;",
            htmltools::tags$button(
              class = "export-btn",
              onclick = "addSection()",
              "\u2795 Add Section"
            ),
            htmltools::tags$button(
              class = "export-btn",
              onclick = "exportAllPinnedSlides()",
              "\U0001F4E4 Export All as PNG"
            ),
            htmltools::tags$button(
              class = "export-btn",
              onclick = "printPinnedViews()",
              "\U0001F5A8 Print / PDF"
            ),
            htmltools::tags$button(
              class = "export-btn",
              onclick = "saveReportHTML()",
              "\U0001F4BE Save Report"
            )
          )
        ),
        htmltools::tags$div(id = "pinned-cards-container"),
        htmltools::tags$div(
          id = "pinned-empty-state",
          style = "text-align:center;padding:60px 20px;color:#94a3b8;",
          htmltools::tags$div(style = "font-size:36px;margin-bottom:12px;", "\U0001F4CC"),
          htmltools::tags$div(style = "font-size:14px;font-weight:600;", "No pinned views yet."),
          htmltools::tags$div(style = "font-size:12px;margin-top:4px;",
            "Click the pin icon on any question in the Crosstabs tab to add it here.")
        ),
        htmltools::tags$script(type = "application/json", id = "pinned-views-data", "[]")
      )
    )

    # Hub-extraction metadata
    hub_meta <- htmltools::tagList(
      htmltools::tags$meta(name = "turas-report-type", content = "tabs"),
      htmltools::tags$meta(name = "turas-total-n",
                           content = if (!is.na(html_data$total_n)) as.character(round(html_data$total_n)) else ""),
      htmltools::tags$meta(name = "turas-questions", content = as.character(html_data$n_questions)),
      htmltools::tags$meta(name = "turas-banner-groups",
                           content = as.character(length(html_data$banner_groups))),
      htmltools::tags$meta(name = "turas-weighted",
                           content = if (isTRUE(config_obj$apply_weighting)) "true" else "false"),
      htmltools::tags$meta(name = "turas-fieldwork",
                           content = config_obj$fieldwork_dates %||% "")
    )

    page <- htmltools::tagList(
      htmltools::tags$head(
        htmltools::tags$meta(charset = "UTF-8"),
        htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
        source_meta,
        hub_meta,
        htmltools::tags$title(project_title),
        build_css(brand_colour, accent_colour),
        build_dashboard_css(brand_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost",
                         client_name = config_obj$client_name,
                         researcher_logo_uri = config_obj$researcher_logo_uri,
                         apply_weighting = isTRUE(config_obj$apply_weighting)),
      build_report_tab_nav(brand_colour, has_qualitative = TRUE,
                           has_about = TRUE),
      dashboard_html,
      crosstab_panel,
      build_qualitative_panel(qualitative_slides, brand_colour),
      build_about_panel(config_obj),
      pinned_panel,
      build_help_overlay(),
      build_javascript(html_data, brand_colour),
      build_tab_javascript()
    )
  } else {
    # No dashboard: original layout unchanged

    # Hub-extraction metadata
    hub_meta <- htmltools::tagList(
      htmltools::tags$meta(name = "turas-report-type", content = "tabs"),
      htmltools::tags$meta(name = "turas-total-n",
                           content = if (!is.na(html_data$total_n)) as.character(round(html_data$total_n)) else ""),
      htmltools::tags$meta(name = "turas-questions", content = as.character(html_data$n_questions)),
      htmltools::tags$meta(name = "turas-banner-groups",
                           content = as.character(length(html_data$banner_groups))),
      htmltools::tags$meta(name = "turas-weighted",
                           content = if (isTRUE(config_obj$apply_weighting)) "true" else "false"),
      htmltools::tags$meta(name = "turas-fieldwork",
                           content = config_obj$fieldwork_dates %||% "")
    )

    page <- htmltools::tagList(
      htmltools::tags$head(
        htmltools::tags$meta(charset = "UTF-8"),
        htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
        source_meta,
        hub_meta,
        htmltools::tags$title(project_title),
        build_css(brand_colour, accent_colour),
        build_print_css()
      ),
      build_header(project_title, brand_colour, html_data$total_n, html_data$n_questions,
                         company_name = config_obj$company_name %||% "The Research Lamppost",
                         client_name = config_obj$client_name,
                         researcher_logo_uri = config_obj$researcher_logo_uri,
                         apply_weighting = isTRUE(config_obj$apply_weighting)),
      crosstab_content,
      build_closing_section(config_obj),
      build_export_actions(),
      build_help_overlay(),
      build_javascript(html_data, brand_colour)
    )
  }

  htmltools::browsable(page)
}


#' Build JavaScript for Interactivity
#'
#' Assembles all JS from focused helper functions into a single script tag.
#' Plain vanilla JavaScript — no HTMLWidgets, no React, no external deps.
#'
#' @param html_data The transformed data
#' @return htmltools::tags$script
build_javascript <- function(html_data, brand_colour = "#323367") {
  group_codes <- sapply(html_data$banner_groups, function(g) g$banner_code)

  # Global brand colour variable — all JS files reference this instead of hardcoded hex
  brand_colour_js <- sprintf('var BRAND_COLOUR = "%s";\n', brand_colour)

  js_full <- paste0(
    brand_colour_js,
    build_js_core_navigation(),
    build_js_chart_picker(),
    build_js_slide_export(),
    build_js_pinned_views(),
    build_js_table_export_and_init()
  )

  js_full <- gsub("BANNER_GROUPS_JSON",
                   jsonlite::toJSON(unname(group_codes), auto_unbox = FALSE),
                   js_full, fixed = TRUE)

  htmltools::tags$script(htmltools::HTML(js_full))
}


# ==============================================================================
# JS FILE LOADING HELPER
# ==============================================================================

# Directory for standalone JS files
.js_dir <- file.path(
  if (exists(".tabs_lib_dir", envir = globalenv())) {
    file.path(get(".tabs_lib_dir", envir = globalenv()), "html_report", "js")
  } else {
    # Fallback: attempt to determine path from the call stack. This is fragile
    # and only works when this file is directly source()'d. Set .tabs_lib_dir
    # in the calling environment before sourcing to avoid this path.
    .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    if (is.null(.ofile) || !nzchar(.ofile %||% "")) {
      cat(paste(
        "  [WARNING] Cannot determine JS directory: .tabs_lib_dir is not set",
        "and sys.frame()$ofile is unavailable. JS files may not load.",
        "Set .tabs_lib_dir before sourcing run_crosstabs.R.\n"
      ))
      file.path(".", "js")
    } else {
      file.path(dirname(.ofile), "js")
    }
  }
)

#' Read a JavaScript file and return its content as a string
#'
#' @param filename Character, name of the JS file (e.g. "core_navigation.js")
#' @return Character string of JavaScript code
#' @keywords internal
read_js_file <- function(filename) {
  js_path <- file.path(.js_dir, filename)
  if (!file.exists(js_path)) {
    cat(sprintf("  [ERROR] JavaScript file not found: %s\n", js_path))
    cat(sprintf("  Expected in: %s\n", .js_dir))
    return("")
  }
  paste(readLines(js_path, warn = FALSE), collapse = "\n")
}


#' Build Core Navigation JavaScript
#'
#' Global state, question navigation, banner switching, heatmap toggle,
#' frequency toggle, print, chart toggle, and insight/comment system.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_core_navigation <- function() {
  read_js_file("core_navigation.js")
}


#' Build Chart Column Picker JavaScript
#'
#' Chart column picker, multi-column stacked/horizontal SVG builders,
#' HSL colour utilities, and chart PNG export.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_chart_picker <- function() {
  read_js_file("chart_picker.js")
}


#' Build Slide Export JavaScript
#'
#' Presentation-quality SVG slide builder with title, base, chart,
#' metrics strip, and insight — rendered to PNG at 3x resolution.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_slide_export <- function() {
  read_js_file("slide_export.js")
}


#' Build Pinned Views JavaScript
#'
#' Pin/unpin questions, render pinned view cards, reorder, persist to JSON,
#' export all pinned views as individual slide PNGs.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_pinned_views <- function() {
  read_js_file("pinned_views.js")
}


#' Build Table Export and Init JavaScript
#'
#' Table data extraction, CSV/Excel export, column toggle chips,
#' column sort, downloadBlob utility, and DOMContentLoaded init.
#'
#' @return Character string of JavaScript code
#' @keywords internal
build_js_table_export_and_init <- function() {
  read_js_file("table_export_init.js")
}


