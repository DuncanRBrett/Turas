# ==============================================================================
# TurasTracker HTML Report - Page Components
# ==============================================================================
# Reusable UI components: header, footer, help overlay, about panel, pinned tab.
# Extracted from 03_page_builder.R for maintainability.
# VERSION: 3.0.0
# ==============================================================================


#' Build Tracker Header
#'
#' Renders the dark gradient header with logo, project name, branding,
#' and stats badges. Matches the Turas Tabs header design.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @param brand_colour Character. Brand colour hex code
#' @return htmltools tag
#' @keywords internal
build_tracker_header <- function(html_data, config, brand_colour) {

  project_name <- html_data$metadata$project_name %||% "Tracking Report"
  company_name <- get_setting(config, "company_name", default = "") %||% ""
  client_name <- get_setting(config, "client_name", default = "") %||% ""
  n_metrics <- html_data$n_metrics
  n_waves <- length(html_data$waves)
  n_segments <- length(html_data$segments)
  created_date <- format(html_data$metadata$generated_at, "%b %Y")

  # Logos (base64 embedded)
  researcher_logo_html <- ""
  logo_path <- get_setting(config, "researcher_logo_path", default = NULL)
  if (!is.null(logo_path) && file.exists(logo_path)) {
    logo_b64 <- base64enc::dataURI(file = logo_path, mime = "image/png")
    researcher_logo_html <- sprintf(
      '<div class="tk-header-logo-wrap"><img src="%s" alt="Logo" class="tk-header-logo"/></div>',
      logo_b64
    )
  }

  # "Prepared by" line
  prepared_by <- ""
  if (nzchar(company_name) || nzchar(client_name)) {
    parts <- c()
    if (nzchar(company_name)) parts <- c(parts, sprintf("Prepared by <strong>%s</strong>", htmltools::htmlEscape(company_name)))
    if (nzchar(client_name)) parts <- c(parts, sprintf("for <strong>%s</strong>", htmltools::htmlEscape(client_name)))
    prepared_by <- paste(parts, collapse = " ")
  }

  # Stats badge bar
  badge_items <- c(
    sprintf('<span class="tk-badge-item"><strong>%d</strong> Metrics</span>', n_metrics),
    sprintf('<span class="tk-badge-item"><strong>%d</strong> Waves</span>', n_waves),
    sprintf('<span class="tk-badge-item"><strong>%d</strong> Segment%s</span>', n_segments, if (n_segments > 1) "s" else ""),
    sprintf('<span class="tk-badge-item" id="header-date-badge">Created %s</span>', htmltools::htmlEscape(created_date))
  )
  badge_bar <- paste(
    '<div class="tk-badge-bar">',
    paste(badge_items, collapse = '<span class="tk-badge-sep"></span>'),
    '</div>'
  )

  htmltools::tags$header(class = "tk-header",
    htmltools::tags$div(class = "tk-header-inner",
      # Top row: Logo + Branding ... Action buttons + Help
      htmltools::tags$div(class = "tk-header-top",
        htmltools::tags$div(class = "tk-header-brand",
          htmltools::HTML(researcher_logo_html),
          htmltools::tags$div(
            htmltools::tags$div(class = "tk-brand-name", "Turas Tracker"),
            htmltools::tags$div(class = "tk-brand-subtitle", "Interactive Tracking Report")
          )
        ),
        htmltools::tags$div(class = "tk-header-actions")
      ),
      # Project title
      htmltools::tags$div(class = "tk-header-project", project_name),
      # Prepared by line
      if (nzchar(prepared_by)) {
        htmltools::tags$div(class = "tk-header-prepared", htmltools::HTML(prepared_by))
      },
      # Stats badge bar
      htmltools::HTML(badge_bar)
    )
  )
}


#' Build Tracker Footer
#'
#' Renders the footer with significance testing info, baseline details,
#' and credits. Matches Turas Tabs footer pattern.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools tag
#' @keywords internal
build_tracker_footer <- function(html_data, config) {

  company_name <- get_setting(config, "company_name", default = "") %||% ""
  baseline_label <- html_data$wave_lookup[html_data$baseline_wave]
  min_base <- 30L
  alpha <- html_data$metadata$confidence_level
  p_val <- if (!is.null(alpha)) sprintf("p<%.2f", 1 - alpha) else "p<0.05"

  # Significance test method line (matching crosstabs footer pattern)
  sig_info_parts <- c(
    "Significance testing: Wave-on-wave z-test / t-test",
    p_val,
    sprintf("Minimum base n=%d", min_base)
  )
  sig_line <- paste(sig_info_parts, collapse = " \u00B7 ")

  htmltools::tags$footer(class = "tk-footer",
    # Significance test info line
    htmltools::tags$div(class = "tk-footer-sig-info", sig_line),
    htmltools::tags$div(class = "tk-footer-info",
      htmltools::tags$span(sprintf("Baseline: %s (%s)", html_data$baseline_wave, baseline_label)),
      htmltools::tags$span(class = "tk-footer-sep", "|"),
      htmltools::tags$span(sprintf("Confidence: %s%%", round(html_data$metadata$confidence_level * 100))),
      htmltools::tags$span(class = "tk-footer-sep", "|"),
      htmltools::tags$span(sprintf("Generated: %s", format(html_data$metadata$generated_at, "%d %b %Y %H:%M")))
    ),
    if (nzchar(company_name)) {
      htmltools::tags$div(class = "tk-footer-credit",
        htmltools::tags$span(paste0("Prepared by ", company_name)),
        htmltools::tags$span(" | Powered by Turas Analytics")
      )
    }
  )
}


#' Build Help Overlay
#'
#' Renders the modal help overlay with keyboard shortcuts and
#' feature descriptions. Hidden by default, toggled via JS.
#'
#' @return htmltools tag
#' @keywords internal
build_help_overlay <- function() {

  htmltools::tags$div(id = "tk-help-overlay", class = "tk-help-overlay",
                       style = "display:none",
    htmltools::tags$div(class = "tk-help-content",
      htmltools::tags$h2("Tracking Report Help"),
      htmltools::tags$button(class = "tk-help-close", onclick = "toggleHelpOverlay()",
                              htmltools::HTML("&times;")),
      htmltools::tags$div(class = "tk-help-body",
        htmltools::tags$h3("Report Tabs"),
        htmltools::tags$ul(
          htmltools::tags$li(htmltools::tags$strong("Summary"), " \u2014 Key findings and methodology notes"),
          htmltools::tags$li(htmltools::tags$strong("Explorer"), " \u2014 Interactive heatmap table to explore metrics across waves and segments"),
          htmltools::tags$li(htmltools::tags$strong("Added Slides"), " \u2014 Insert custom slides with images and commentary"),
          htmltools::tags$li(htmltools::tags$strong("Pinned Views"), " \u2014 Save and compare specific metric views")
        ),
        htmltools::tags$h3("Significance Indicators"),
        htmltools::tags$ul(
          htmltools::tags$li(htmltools::HTML("<span class='sig-up'>&#x2191;</span> Significant increase")),
          htmltools::tags$li(htmltools::HTML("<span class='sig-down'>&#x2193;</span> Significant decrease")),
          htmltools::tags$li(htmltools::HTML("<span class='not-sig'>&#x2192;</span> No significant change"))
        ),
        htmltools::tags$h3("Segment Chips"),
        htmltools::tags$p("Click segment chips to show or hide individual segments. Total is shown by default."),
        htmltools::tags$h3("Trend Annotations"),
        htmltools::tags$p("Click a data point on any chart to add a contextual annotation (e.g., 'Campaign launched'). Annotations appear as labelled markers on the chart."),
        htmltools::tags$h3("Metric Comparison"),
        htmltools::tags$p("Select metrics in the Explorer tab and click Visualise to overlay up to 3 metrics on a single chart for correlation analysis."),
        htmltools::tags$h3("Export"),
        htmltools::tags$p("Export tables as CSV or Excel. Export charts and metrics as high-resolution PNG slides. Copy charts to clipboard for pasting into presentations.")
      )
    )
  )
}


#' Build About Tab Panel for Tracker
#'
#' Renders analyst contact details, verbatim file reference, and editable
#' closing notes inside a tab-panel div. Returns NULL if no fields are present.
#'
#' @param config Tracker configuration list
#' @return htmltools tag or NULL
#' @keywords internal
build_tracker_about_panel <- function(config) {
  analyst_name  <- get_setting(config, "analyst_name",     default = NULL)
  analyst_email <- get_setting(config, "analyst_email",    default = NULL)
  analyst_phone <- get_setting(config, "analyst_phone",    default = NULL)
  verbatim_file <- get_setting(config, "verbatim_filename", default = NULL)
  closing_notes <- get_setting(config, "closing_notes",    default = NULL)

  has_content <- any(sapply(
    list(analyst_name, analyst_email, analyst_phone, verbatim_file, closing_notes),
    function(x) !is.null(x) && nzchar(trimws(x))
  ))
  if (!has_content) return(NULL)

  # Contact items
  contact_items <- list()
  if (!is.null(analyst_name) && nzchar(analyst_name)) {
    contact_items <- c(contact_items, list(
      htmltools::tags$div(class = "closing-contact-item",
        htmltools::tags$span(class = "closing-label", "Analyst"),
        htmltools::tags$span(class = "closing-value", analyst_name)
      )
    ))
  }
  if (!is.null(analyst_email) && nzchar(analyst_email)) {
    contact_items <- c(contact_items, list(
      htmltools::tags$div(class = "closing-contact-item",
        htmltools::tags$span(class = "closing-label", "Email"),
        htmltools::tags$a(class = "closing-value closing-link",
                          href = paste0("mailto:", analyst_email), analyst_email)
      )
    ))
  }
  if (!is.null(analyst_phone) && nzchar(analyst_phone)) {
    contact_items <- c(contact_items, list(
      htmltools::tags$div(class = "closing-contact-item",
        htmltools::tags$span(class = "closing-label", "Phone"),
        htmltools::tags$span(class = "closing-value", analyst_phone)
      )
    ))
  }

  # Verbatim reference
  verbatim_el <- NULL
  if (!is.null(verbatim_file) && nzchar(verbatim_file)) {
    verbatim_el <- htmltools::tags$div(class = "closing-verbatim",
      htmltools::tags$span(class = "closing-label", "Appendices"),
      htmltools::tags$span(class = "closing-value", verbatim_file)
    )
  }

  # Closing notes (editable)
  notes_content <- if (!is.null(closing_notes) && nzchar(closing_notes)) closing_notes else ""
  notes_el <- htmltools::tags$div(class = "closing-notes-section",
    htmltools::tags$div(class = "closing-label", "Notes"),
    htmltools::tags$div(
      class = "closing-notes-editor",
      contenteditable = "true",
      `data-placeholder` = "Add closing notes...",
      htmltools::HTML(notes_content)
    ),
    htmltools::tags$textarea(
      class = "closing-notes-store",
      style = "display:none;",
      notes_content
    )
  )

  htmltools::tags$div(id = "tab-about", class = "tab-panel",
    htmltools::tags$div(
      class = "closing-section",
      id = "report-closing-section",
      htmltools::tags$div(class = "closing-divider"),
      htmltools::tags$div(class = "closing-content",
        if (length(contact_items) > 0) {
          htmltools::tags$div(class = "closing-contact-grid", contact_items)
        },
        verbatim_el,
        notes_el
      )
    )
  )
}


#' Build Pinned Views Tab
#'
#' Renders the Pinned Views tab container with toolbar and empty state.
#' Content is populated dynamically by JavaScript.
#'
#' @return htmltools tag
#' @keywords internal
build_pinned_tab <- function() {

  htmltools::tags$div(class = "pinned-tab-content",
    # Export toolbar (hidden when no pins)
    htmltools::tags$div(class = "pinned-toolbar", id = "pinned-toolbar",
                         style = "display:none",
      htmltools::tags$button(class = "tk-btn", onclick = "addSection()",
                              htmltools::HTML("&#x2795; Add Section")),
      htmltools::tags$button(class = "tk-btn", onclick = "exportAllPinsPNG()",
                              htmltools::HTML("&#x1F4F8; Export All as PNGs")),
      htmltools::tags$button(class = "tk-btn", onclick = "printAllPins()",
                              htmltools::HTML("&#x1F5A8; Print / Save PDF")),
      htmltools::tags$button(class = "tk-btn", onclick = "saveReportHTML()",
                              htmltools::HTML("&#x1F4BE; Save Report HTML"))
    ),
    htmltools::tags$div(id = "pinned-cards-container"),
    htmltools::tags$div(
      id = "pinned-empty-state",
      class = "pinned-empty-state",
      htmltools::HTML("&#x1F4CC; No pinned views yet. Go to the <strong>Explorer</strong> tab and click <strong>Pin</strong> to save a view here.")
    )
  )
}


#' Build Qualitative Panel (Added Slides)
#'
#' Renders the Added Slides tab with markdown editors, image upload,
#' and slide management controls. Mirrors the Turas Tabs qualitative
#' slides system for visual consistency.
#'
#' @return htmltools tag
#' @keywords internal
build_qualitative_panel <- function() {

  htmltools::tags$div(class = "qual-tab-content",
    # Toolbar
    htmltools::tags$div(class = "qual-toolbar",
      htmltools::tags$button(class = "turas-action-btn",
        onclick = "addQualSlide()",
        htmltools::HTML("&#x2795; Add Slide")),
      htmltools::tags$button(class = "turas-action-btn",
        onclick = "pinAllQualSlides()",
        htmltools::HTML("&#x1F4CC; Pin All to Views"))
    ),
    # Slides container (populated by JS or initial empty state)
    htmltools::tags$div(id = "qual-slides-container"),
    htmltools::tags$div(
      id = "qual-empty-state",
      class = "pinned-empty-state",
      htmltools::HTML("&#x1F4DD; No slides yet. Click <strong>+ Add Slide</strong> to create a commentary slide with images and markdown.")
    ),
    # Hidden stores for persistence (same pattern as pinned views)
    htmltools::tags$script(type = "application/json", id = "qual-slides-data", "[]")
  )
}
