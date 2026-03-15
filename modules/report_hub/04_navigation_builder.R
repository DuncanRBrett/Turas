#' Navigation Builder
#'
#' Builds the two-tier navigation system for the combined report.
#' Level 1: report tabs (Overview, Tracker, Crosstabs, Pinned)
#' Level 2: sub-tabs within each report (reusing existing report tabs)

#' Build Level 1 Navigation HTML
#'
#' @param reports List of report configs (each with key, label, type)
#' @return HTML string for Level 1 navigation
build_level1_nav <- function(reports, has_about = FALSE) {
  # Overview tab is always first
  tabs <- '<button class="hub-tab active" onclick="ReportHub.switchReport(\'overview\')" data-hub-tab="overview">Overview</button>'

  # Add one tab per report in config order
  for (report in reports) {
    tabs <- paste0(tabs, sprintf(
      '<button class="hub-tab" onclick="ReportHub.switchReport(\'%s\')" data-hub-tab="%s">%s</button>',
      report$key, report$key, htmltools::htmlEscape(report$label)
    ))
  }

  # Pinned tab
  tabs <- paste0(tabs,
    '<button class="hub-tab" onclick="ReportHub.switchReport(\'pinned\')" data-hub-tab="pinned">',
    'Pinned Views <span class="hub-pin-badge" id="hub-pin-count">0</span></button>'
  )

  # About tab (only if about fields are configured)
  if (has_about) {
    tabs <- paste0(tabs,
      '<button class="hub-tab" onclick="ReportHub.switchReport(\'about\')" data-hub-tab="about">About</button>'
    )
  }

  html <- sprintf('<div class="hub-nav-level1">\n  %s\n</div>', tabs)
  return(html)
}


#' Build Level 2 Navigation HTML for a Report
#'
#' Rebuilds the report's internal tab bar with namespaced IDs
#' and removes the pinned tab (managed at Level 1).
#' For report types with help overlays (tabs, tracker), appends a
#' help button that triggers the namespaced toggleHelpOverlay function.
#'
#' @param report_key Report key
#' @param tab_names Character vector of tab names (excluding "pinned")
#' @param tab_labels Named vector mapping tab names to display labels (optional)
#' @param report_type "tracker" or "tabs"
#' @param has_help_overlay Logical; whether this report has a help overlay
#' @return HTML string for Level 2 navigation
build_level2_nav <- function(report_key, tab_names, tab_labels = NULL,
                             report_type = NULL, has_help_overlay = FALSE) {
  if (length(tab_names) == 0) return("")

  # Default labels based on report type
  if (is.null(tab_labels)) {
    if (!is.null(report_type) && report_type == "tracker") {
      tab_labels <- c(
        summary = "Summary",
        metrics = "Metrics by Segment",
        overview = "Segment Overview",
        about = "About"
      )
    } else {
      tab_labels <- c(
        summary = "Summary",
        crosstabs = "Crosstabs",
        qualitative = "Added Slides",
        about = "About"
      )
    }
  }

  tabs <- ""
  for (i in seq_along(tab_names)) {
    name <- tab_names[i]
    label <- if (name %in% names(tab_labels)) tab_labels[name] else name
    active <- if (i == 1) " active" else ""
    tabs <- paste0(tabs, sprintf(
      '<button class="hub-subtab%s" onclick="ReportHub.switchSubTab(\'%s\',\'%s\')" data-subtab="%s">%s</button>',
      active, report_key, name, name, label
    ))
  }

  # Add help button for reports with help overlays
  if (has_help_overlay) {
    tabs <- paste0(tabs, sprintf(
      '<button class="hub-help-btn" onclick="%s_toggleHelpOverlay()" title="Help guide">?</button>',
      report_key
    ))
  }

  html <- sprintf(
    '<div class="hub-nav-level2" id="hub-l2-%s" style="display:none;">\n  %s\n</div>',
    report_key, tabs
  )
  return(html)
}


#' Build Complete Navigation Block
#'
#' @param parsed_reports List of parsed/rewritten report objects
#' @param report_configs List of report configs from guard
#' @return HTML string with full navigation (Level 1 + all Level 2 bars)
build_navigation <- function(parsed_reports, report_configs, has_about = FALSE) {
  # Level 1
  nav_html <- build_level1_nav(report_configs, has_about = has_about)

  # Level 2 for each report
  for (parsed in parsed_reports) {
    has_help <- !is.null(parsed$help_overlay) && nzchar(parsed$help_overlay)
    l2 <- build_level2_nav(
      report_key = parsed$report_key,
      tab_names = parsed$report_tabs$tab_names,
      report_type = parsed$report_type,
      has_help_overlay = has_help
    )
    nav_html <- paste0(nav_html, "\n", l2)
  }

  return(nav_html)
}
