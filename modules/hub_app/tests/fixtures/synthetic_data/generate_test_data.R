# ==============================================================================
# TURAS > HUB APP — Synthetic Test Data Generator
# ==============================================================================
# Creates mock project directories, HTML reports, and pin sidecar files
# for use in unit and integration tests.
# ==============================================================================

#' Create a Mock Turas Project Directory
#'
#' Builds a temporary directory structure resembling a real Turas project
#' with HTML report files containing proper meta tags.
#'
#' @param base_dir Parent directory for the project folder
#' @param name Project folder name
#' @param report_types Character vector of report types to create
#'   (e.g., "tabs", "tracker", "confidence")
#' @param add_hub_config Logical. Add a Report_Hub_Config.xlsx file?
#' @param add_pins Logical. Add a .turas_pins.json sidecar?
#'
#' @return Path to the created project directory
create_mock_project <- function(base_dir,
                                name,
                                report_types = "tabs",
                                add_hub_config = FALSE,
                                add_pins = FALSE) {

  proj_dir <- file.path(base_dir, name)
  dir.create(proj_dir, recursive = TRUE, showWarnings = FALSE)

  for (rtype in report_types) {
    html_content <- sprintf(
      paste0(
        '<!DOCTYPE html>\n',
        '<html lang="en">\n',
        '<head>\n',
        '  <meta charset="UTF-8">\n',
        '  <meta name="turas-report-type" content="%s">\n',
        '  <title>%s Report - %s</title>\n',
        '</head>\n',
        '<body>\n',
        '  <div class="header"><h1>%s Report</h1></div>\n',
        '  <div class="report-tabs"><button>Tab 1</button></div>\n',
        '  <div id="pinned-views-data" style="display:none;">[]</div>\n',
        '  <h2>Test Report Content</h2>\n',
        '  <p>This is a synthetic %s report for testing.</p>\n',
        '</body>\n',
        '</html>'
      ),
      rtype,
      tools::toTitleCase(rtype),
      name,
      tools::toTitleCase(rtype),
      rtype
    )
    writeLines(html_content, file.path(proj_dir, paste0(rtype, "_report.html")))
  }

  if (add_hub_config) {
    # Create a minimal placeholder (not a real xlsx, just for detection)
    writeLines("placeholder", file.path(proj_dir,
      paste0(name, "_Report_Hub_Config.xlsx")))
  }

  if (add_pins) {
    pin_data <- list(
      version = 1L,
      last_modified = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
      turas_version = "1.0",
      pins = list(
        list(
          id = "pin-test-001",
          type = "pin",
          source = report_types[1],
          sourceLabel = paste(tools::toTitleCase(report_types[1]), "Report"),
          title = "Test Pin - Q01 Overall Satisfaction",
          subtitle = "Top-2 box by segment",
          insight = "## Key Finding\n\nSatisfaction is **stable** at 72%.",
          chartSvg = '<svg viewBox="0 0 400 300"><rect width="400" height="300" fill="#f0f0f0"/><text x="200" y="150" text-anchor="middle">Test Chart</text></svg>',
          timestamp = as.numeric(Sys.time()) * 1000,
          position = 0L
        )
      ),
      sections = list(
        list(
          id = "sec-test-001",
          type = "section",
          title = "Overview",
          position = 0L
        )
      )
    )
    jsonlite::write_json(pin_data, file.path(proj_dir, ".turas_pins.json"),
                          auto_unbox = TRUE, pretty = TRUE)
  }

  proj_dir
}


#' Create Mock Pin Items for Export Testing
#'
#' Returns a list of pin and section objects suitable for passing to
#' export_pins_to_pptx().
#'
#' @param n_pins Number of pin items to create
#' @param n_sections Number of section dividers to intersperse
#' @param include_charts Logical. Include SVG chart data?
#' @param include_insights Logical. Include insight markdown text?
#'
#' @return List of item objects (pins and sections)
create_mock_export_items <- function(n_pins = 3,
                                      n_sections = 1,
                                      include_charts = TRUE,
                                      include_insights = TRUE) {

  items <- list()

  # Add a section at the start
  if (n_sections >= 1) {
    items[[length(items) + 1]] <- list(
      type = "section",
      title = "Key Findings"
    )
  }

  for (i in seq_len(n_pins)) {
    pin <- list(
      type = "pin",
      id = paste0("pin-mock-", sprintf("%03d", i)),
      title = paste("Q", sprintf("%02d", i), "- Test Metric", i),
      subtitle = paste("Subtitle for metric", i),
      source = "tabs",
      sourceLabel = "Crosstabs Report"
    )

    if (include_insights) {
      pin$insight <- sprintf(
        "## Finding %d\n\nMetric %d shows a **significant** change of +5pp.",
        i, i
      )
    }

    if (include_charts) {
      # Create a minimal SVG that can be base64-encoded
      pin$chartPng <- paste0(
        "data:image/png;base64,",
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk",
        "+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
      )
    }

    items[[length(items) + 1]] <- pin
  }

  # Add another section in the middle if requested

  if (n_sections >= 2) {
    items[[length(items) + 1]] <- list(
      type = "section",
      title = "Appendix"
    )
  }

  items
}


#' Create a Non-Turas HTML File
#'
#' Creates an HTML file without a turas-report-type meta tag,
#' for testing that the scanner correctly ignores it.
#'
#' @param dir_path Directory to create the file in
#' @param filename Filename (default: "random_page.html")
#'
#' @return Path to the created file
create_non_turas_html <- function(dir_path, filename = "random_page.html") {
  html <- paste0(
    '<!DOCTYPE html>\n<html>\n<head>\n',
    '  <title>Not a Turas Report</title>\n',
    '</head>\n<body>\n',
    '  <h1>This is not a Turas report</h1>\n',
    '</body>\n</html>'
  )
  path <- file.path(dir_path, filename)
  writeLines(html, path)
  path
}
