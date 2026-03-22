#' Navigation Builder (iframe approach)
#'
#' Builds Level 1 navigation only. Each report's internal navigation
#' lives inside its own iframe — no Level 2 nav needed in the hub shell.

#' Build Hub Navigation HTML
#'
#' Creates the Level 1 tab bar: Overview, one tab per report, Pinned Views,
#' and optionally an About tab.
#'
#' @param report_configs List of report configs (each with $key and $label)
#' @param has_about Logical; include an About tab?
#' @return HTML string for the navigation bar
build_navigation <- function(report_configs, has_about = FALSE) {

  tabs <- character(0)

  # Overview tab (always first, always active on load)
  tabs <- c(tabs,
    '<button class="hub-tab active" onclick="ReportHub.switchReport(\'overview\')" data-hub-tab="overview">Overview</button>'
  )

  # One tab per report
  for (report in report_configs) {
    tabs <- c(tabs, sprintf(
      '<button class="hub-tab" onclick="ReportHub.switchReport(\'%s\')" data-hub-tab="%s">%s</button>',
      report$key, report$key, htmltools::htmlEscape(report$label)
    ))
  }

  # Pinned views tab
  tabs <- c(tabs,
    '<button class="hub-tab" onclick="ReportHub.switchReport(\'pinned\')" data-hub-tab="pinned">',
    'Pinned Views <span class="hub-pin-badge" id="hub-pin-count">0</span></button>'
  )

  # About tab (optional)
  if (has_about) {
    tabs <- c(tabs,
      '<button class="hub-tab" onclick="ReportHub.switchReport(\'about\')" data-hub-tab="about">About</button>'
    )
  }

  sprintf('<div class="hub-nav-level1">\n  %s\n</div>', paste(tabs, collapse = "\n  "))
}
