#' Navigation Builder
#'
#' Builds the two-tier navigation system for the combined report.
#' Level 1: report tabs (Overview, Tracker, Crosstabs, Pinned)
#' Level 2: sub-tabs within each report (reusing existing report tabs)

#' Build Level 1 Navigation HTML
#'
#' @param reports List of report configs (each with key, label, type)
#' @return HTML string for Level 1 navigation
build_level1_nav <- function(reports) {
  # Overview tab is always first
  tabs <- '<button class="hub-tab active" onclick="ReportHub.switchReport(\'overview\')" data-hub-tab="overview">Overview</button>'

  # Add one tab per report in config order

  for (report in reports) {
    tabs <- paste0(tabs, sprintf(
      '<button class="hub-tab" onclick="ReportHub.switchReport(\'%s\')" data-hub-tab="%s">%s</button>',
      report$key, report$key, htmltools::htmlEscape(report$label)
    ))
  }

  # Pinned tab is always last
  tabs <- paste0(tabs,
    '<button class="hub-tab" onclick="ReportHub.switchReport(\'pinned\')" data-hub-tab="pinned">',
    'Pinned Views <span class="hub-pin-badge" id="hub-pin-count">0</span></button>'
  )

  html <- sprintf('<div class="hub-nav-level1">\n  %s\n</div>', tabs)
  return(html)
}


#' Build Level 2 Navigation HTML for a Report
#'
#' Rebuilds the report's internal tab bar with namespaced IDs
#' and removes the pinned tab (managed at Level 1).
#'
#' @param report_key Report key
#' @param tab_names Character vector of tab names (excluding "pinned")
#' @param tab_labels Named vector mapping tab names to display labels (optional)
#' @param report_type "tracker" or "tabs"
#' @return HTML string for Level 2 navigation
build_level2_nav <- function(report_key, tab_names, tab_labels = NULL, report_type = NULL) {
  if (length(tab_names) == 0) return("")

  # Default labels based on report type
  if (is.null(tab_labels)) {
    if (!is.null(report_type) && report_type == "tracker") {
      tab_labels <- c(
        summary = "Summary",
        metrics = "Metrics by Segment",
        overview = "Segment Overview"
      )
    } else {
      tab_labels <- c(
        summary = "Summary",
        crosstabs = "Crosstabs"
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
build_navigation <- function(parsed_reports, report_configs) {
  # Level 1
  nav_html <- build_level1_nav(report_configs)

  # Level 2 for each report
  for (parsed in parsed_reports) {
    l2 <- build_level2_nav(
      report_key = parsed$report_key,
      tab_names = parsed$report_tabs$tab_names,
      report_type = parsed$report_type
    )
    nav_html <- paste0(nav_html, "\n", l2)
  }

  return(nav_html)
}
