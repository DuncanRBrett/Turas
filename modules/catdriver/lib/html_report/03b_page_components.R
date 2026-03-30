# ==============================================================================
# CATDRIVER HTML REPORT - PAGE COMPONENTS
# ==============================================================================
# Reusable UI components: section nav, header, insight areas, help overlay,
# pin buttons, chip bars, action bar, qualitative panel.
# Extracted from 03_page_builder.R for maintainability.
# ==============================================================================

build_cd_section_nav <- function(brand_colour = "#323367", id_prefix = "",
                                  has_subgroup = FALSE) {

  # Page-based navigation (show/hide sections instead of scrolling)
  links <- list(
    htmltools::tags$a(`data-cd-page` = "exec-summary",
                      onclick = "cdSwitchPage('exec-summary')", "Summary", class = "active"),
    htmltools::tags$a(`data-cd-page` = "importance",
                      onclick = "cdSwitchPage('importance')", "Importance"),
    htmltools::tags$a(`data-cd-page` = "patterns",
                      onclick = "cdSwitchPage('patterns')", "Patterns"),
    htmltools::tags$a(`data-cd-page` = "probability-lifts",
                      onclick = "cdSwitchPage('probability-lifts')", "Prob. Lifts"),
    htmltools::tags$a(`data-cd-page` = "odds-ratios",
                      onclick = "cdSwitchPage('odds-ratios')", "Odds Ratios"),
    htmltools::tags$a(`data-cd-page` = "diagnostics",
                      onclick = "cdSwitchPage('diagnostics')", "Diagnostics")
  )

  if (isTRUE(has_subgroup)) {
    links <- c(links, list(
      htmltools::tags$a(`data-cd-page` = "subgroup-comparison",
                        onclick = "cdSwitchPage('subgroup-comparison')", "Subgroups")
    ))
  }

  links <- c(links, list(
    htmltools::tags$a(`data-cd-page` = "interpretation",
                      onclick = "cdSwitchPage('interpretation')", "Guide"),
    htmltools::tags$a(`data-cd-page` = "qualitative",
                      onclick = "cdSwitchPage('qualitative')", "Added Slides"),
    htmltools::tags$a(`data-cd-page` = "pinned-views",
                      onclick = "cdSwitchPage('pinned-views')",
                      htmltools::HTML(paste0(
                        "Pinned Views ",
                        '<span id="cd-pin-count-badge" class="cd-pin-count-badge">0</span>'
                      )))
  ))

  help_btn <- htmltools::tags$button(
    class = "cd-help-btn-nav",
    onclick = "cdToggleHelp()",
    title = "Show help guide",
    "?"
  )

  htmltools::tags$nav(
    class = "cd-section-nav",
    id = paste0(id_prefix, "cd-section-nav"),
    links,
    help_btn
  )
}


#' Build Header Section
#'
#' Creates the gradient banner header matching tabs/tracker design.
#' Includes logo, module name, project title, prepared-by text, and badge bar.
#'
#' @param html_data Transformed HTML data
#' @param config Configuration list (for logos, company name)
#' @param brand_colour Brand colour hex string
#' @param report_title Report title text
#' @return htmltools tag
#' @keywords internal
build_cd_header <- function(html_data, config, brand_colour, report_title, id_prefix = "") {

  model_info <- html_data$model_info
  diag <- html_data$diagnostics

  model_label <- switch(model_info$outcome_type,
    binary = "Binary Logistic",
    ordinal = "Ordinal Logistic",
    nominal = "Multinomial Logistic",
    model_info$outcome_type
  )

  weight_text <- if (!is.null(model_info$weight_var) && nzchar(model_info$weight_var %||% "")) {
    "Weighted"
  } else {
    "Unweighted"
  }

  # --- Researcher Logo ---
  logo_el <- NULL
  logo_uri <- resolve_logo_uri(config$researcher_logo_path)
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_el <- htmltools::tags$div(
      class = "cd-header-logo-container",
      htmltools::tags$img(
        src = logo_uri,
        alt = "Logo",
        style = "height:56px;width:56px;object-fit:contain;"
      )
    )
  }

  # --- Client Logo ---
  client_logo_el <- NULL
  client_logo_uri <- resolve_logo_uri(config$client_logo_path)
  if (!is.null(client_logo_uri) && nzchar(client_logo_uri)) {
    client_logo_el <- htmltools::tags$div(
      class = "cd-header-logo-container",
      style = "margin-left:auto;",
      htmltools::tags$img(
        src = client_logo_uri,
        alt = "Client Logo",
        style = "height:56px;width:56px;object-fit:contain;"
      )
    )
  }

  # --- Top row: [logo] Turas Catdriver / subtitle [client logo] ---
  branding_left <- htmltools::tags$div(
    class = "cd-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "cd-header-module-name", "Turas Catdriver"),
      htmltools::tags$div(class = "cd-header-module-sub", "Categorical Key Driver Analysis")
    ),
    client_logo_el
  )

  top_row <- htmltools::tags$div(
    class = "cd-header-top",
    branding_left
  )

  # --- Project title ---
  title_row <- htmltools::tags$div(
    class = "cd-header-title",
    report_title
  )

  # --- Prepared by / for text ---
  prepared_row <- NULL
  company_name <- config$company_name %||% "The Research Lamppost"
  client_name <- config$client_name %||% NULL
  researcher_name <- config$researcher_name %||% NULL
  prepared_parts <- c()
  if (!is.null(company_name) && nzchar(company_name)) {
    if (!is.null(researcher_name) && nzchar(researcher_name)) {
      # "Prepared by Researcher Name (Company)"
      prepared_parts <- c(prepared_parts, sprintf(
        'Prepared by <span style="font-weight:600;">%s</span> (%s)',
        htmltools::htmlEscape(researcher_name),
        htmltools::htmlEscape(company_name)
      ))
    } else {
      prepared_parts <- c(prepared_parts, sprintf(
        'Prepared by <span style="font-weight:600;">%s</span>',
        htmltools::htmlEscape(company_name)
      ))
    }
  }
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared_parts <- c(prepared_parts, sprintf(
      'for <span style="font-weight:600;">%s</span>',
      htmltools::htmlEscape(client_name)
    ))
  }
  if (length(prepared_parts) > 0) {
    prepared_row <- htmltools::tags$div(
      class = "cd-header-prepared",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Badge bar ---
  badge_items <- list()

  # Model type badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    htmltools::HTML(sprintf(
      '<span class="cd-header-badge-val">%s</span>&nbsp;Model',
      model_label
    ))
  )))

  # Sample size badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    htmltools::HTML(sprintf(
      'n&nbsp;=&nbsp;<span class="cd-header-badge-val">%s</span>',
      format(diag$complete_n, big.mark = ",")
    ))
  )))

  # Drivers badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    htmltools::HTML(sprintf(
      '<span class="cd-header-badge-val">%d</span>&nbsp;Drivers',
      model_info$n_drivers
    ))
  )))

  # Weight status badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge", weight_text
  )))

  # Date badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "cd-header-badge",
    format(Sys.Date(), "Created %b %Y")
  )))

  # Interleave with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els, list(htmltools::tags$span(class = "cd-header-badge-sep")))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  badges_bar <- htmltools::tags$div(
    class = "cd-header-badges",
    badge_els
  )

  # --- Assemble header ---
  htmltools::tags$div(
    class = "cd-header",
    id = paste0(id_prefix, "cd-header"),
    htmltools::tags$div(
      class = "cd-header-inner",
      top_row,
      title_row,
      prepared_row,
      badges_bar
    )
  )
}


#' Resolve Logo URI
#'
#' Converts a file path to a base64 data URI for self-contained HTML.
#' Accepts NULL, file paths, or already-formed data: URIs.
#'
#' @param logo_path File path or URI string
#' @return Character data URI or NULL
#' @keywords internal
resolve_logo_uri <- function(logo_path) {
  if (is.null(logo_path) || !nzchar(logo_path %||% "")) return(NULL)

  # Already a URI
  if (grepl("^(data:|https?://)", logo_path)) return(logo_path)

  # File path — convert to base64
  if (!file.exists(logo_path)) return(NULL)

  if (!requireNamespace("base64enc", quietly = TRUE)) {
    message("base64enc package required for logo embedding. Install with: install.packages('base64enc')")
    return(NULL)
  }

  ext <- tolower(tools::file_ext(logo_path))
  mime_type <- switch(ext,
    png = "image/png",
    jpg = , jpeg = "image/jpeg",
    svg = "image/svg+xml",
    gif = "image/gif",
    "image/png"  # default
  )

  tryCatch({
    base64enc::dataURI(file = logo_path, mime = mime_type)
  }, error = function(e) {
    message(sprintf("Failed to encode logo '%s': %s", logo_path, e$message))
    NULL
  })
}


#' Build Executive Summary Section
#' @keywords internal

# ==============================================================================
# INSIGHT AREA BUILDER — editable text per section
# ==============================================================================

#' Build Insight Area
#'
#' Creates the editable insight area: toggle button + hidden editor + store.
#'
#' @param section_key Section key string (e.g., "exec-summary", "importance")
#' @param id_prefix ID prefix for the panel
#' @return htmltools tagList
#' @keywords internal
build_cd_insight_area <- function(section_key, id_prefix = "") {
  htmltools::tags$div(
    class = "cd-insight-area",
    `data-cd-insight-section` = section_key,
    `data-cd-insight-prefix` = id_prefix,
    htmltools::tags$button(
      class = "cd-insight-toggle",
      id = paste0(id_prefix, "cd-insight-toggle-", section_key),
      onclick = sprintf("cdToggleInsight('%s','%s')", section_key, id_prefix),
      "+ Add Insight"
    ),
    htmltools::tags$div(
      class = "cd-insight-container",
      id = paste0(id_prefix, "cd-insight-container-", section_key),
      htmltools::tags$div(
        class = "cd-insight-editor",
        contenteditable = "true",
        `data-placeholder` = "Type your insight or comment here...",
        oninput = sprintf("cdSyncInsight('%s','%s')", section_key, id_prefix)
      ),
      htmltools::tags$button(
        class = "cd-insight-dismiss",
        onclick = sprintf("cdDismissInsight('%s','%s')", section_key, id_prefix),
        "\u00D7"
      )
    )
  )
}


# ==============================================================================
# HELP OVERLAY — comprehensive quick guide
# ==============================================================================

#' Build Help Overlay
#'
#' Creates a modal overlay with a quick-reference guide to interactive features.
#' Toggled via the ? button in the navigation bar.
#'
#' @return htmltools::tags$div
#' @keywords internal
build_cd_help_overlay <- function() {
  htmltools::tags$div(
    class = "cd-help-overlay",
    id = "cd-help-overlay",
    onclick = "cdToggleHelp()",
    htmltools::tags$div(
      class = "cd-help-card",
      onclick = "event.stopPropagation()",
      htmltools::tags$h2("Quick Guide"),
      htmltools::tags$div(class = "cd-help-subtitle",
        "Everything you need to know to use this report"),

      # --- Navigating ---
      htmltools::tags$h3("Navigating the Report"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Section tabs"),
          "Switch between sections using the navigation bar. Each tab shows a different analysis page."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Summary"),
          "Overview of the model with key metrics, top drivers, and standout findings."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Importance"),
          "Which drivers matter most. Use filter chips to show top 3, 5, 8, or all drivers."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Patterns"),
          "How each category of each driver relates to the outcome. Shows percentages, odds ratios, and effect sizes."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Prob. Lifts"),
          "How each driver category shifts the predicted probability of the outcome."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Odds Ratios"),
          "Forest plot and table of odds ratios with confidence intervals for each driver category."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Diagnostics"),
          "Model fit statistics and validation checks.")
      ),

      # --- Tables & Charts ---
      htmltools::tags$h3("Working with Tables & Charts"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Filter chips"),
          "Click chips above charts to filter which drivers or categories are shown."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Callout boxes"),
          "Expandable explanation boxes beneath sections. Click to expand or collapse."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "CSV / Excel"),
          "Export table data using the buttons above each table.")
      ),

      # --- Insights ---
      htmltools::tags$h3("Adding Insights"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "+ Add Insight"),
          "Click below any section to add your analysis or commentary."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Editable text"),
          "Type directly into the insight area. Your notes are saved with the report.")
      ),

      # --- Pinning ---
      htmltools::tags$h3("Pinning Key Findings"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "\U0001F4CC Pin"),
          "Click the pin icon to save a section. Choose table, chart, or both."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Pinned Views"),
          "A curated deck of your key findings. Drag to reorder, remove with \u2715."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Section dividers"),
          "Use 'Add Section' in Pinned Views to organise pins into groups.")
      ),

      # --- Added Slides ---
      htmltools::tags$h3("Added Slides"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Add Slide"),
          "Create narrative slides with formatted text (bold, italic, bullets, headings)."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "\U0001F5BC Add image"),
          "Upload a chart, screenshot, or diagram to any slide.")
      ),

      # --- Exporting ---
      htmltools::tags$h3("Exporting & Sharing"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Save Report"),
          htmltools::HTML(paste0(
            "Saves the report with all your insights, pins, and edits preserved. ",
            "In Chrome/Edge a <em>Save As</em> dialog lets you choose the location."
          ))),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "\U0001F4F7 Export PNG"),
          "Download any pinned card as a high-resolution PNG image."),
        htmltools::tags$li(htmltools::tags$span(class = "cd-help-key", "Print / PDF"),
          "Print your Pinned Views as a paginated document (one finding per page).")
      ),

      # --- Tip ---
      htmltools::tags$div(class = "cd-help-tip",
        htmltools::HTML(paste0(
          "<strong>Tip:</strong> This report is a live working document. ",
          "Add insights, pin key findings, create slides, then <strong>Save Report</strong> ",
          "to keep everything. Re-open the saved file any time to continue where you left off. ",
          "Press <strong>?</strong> to show this guide again."
        ))
      ),

      htmltools::tags$div(class = "cd-help-dismiss", "Click anywhere to close")
    )
  )
}


# ==============================================================================
# SECTION TITLE ROW — title + pin button in flex row
# ==============================================================================

#' Build Section Title Row
#'
#' Wraps a section title, optional help button, and pin button in a flex row.
#'
#' @param title_text Title text
#' @param section_key Section key for pinning
#' @param id_prefix ID prefix for the panel
#' @param show_pin Whether to show the pin button
#' @param help_id Optional help section ID. When provided, a small (?) button
#'   is rendered next to the title that opens the help modal for this section.
#' @return htmltools tag
#' @keywords internal
build_cd_section_title_row <- function(title_text, section_key, id_prefix = "",
                                        show_pin = TRUE, help_id = NULL) {
  pin_btn <- if (show_pin) {
    htmltools::tags$button(
      class = "cd-pin-btn",
      `data-cd-pin-section` = section_key,
      `data-cd-pin-prefix` = id_prefix,
      onclick = sprintf("cdPinSection('%s','%s')", section_key, id_prefix),
      title = "Pin to Views",
      "\U0001F4CC"
    )
  }

  help_btn <- if (!is.null(help_id)) {
    htmltools::tags$button(
      class = "cd-help-btn",
      onclick = sprintf("cdShowHelp('%s')", help_id),
      title = "Learn more",
      "?"
    )
  }

  htmltools::tags$div(
    class = "cd-section-title-row",
    htmltools::tags$h2(class = "cd-section-title", title_text, help_btn),
    pin_btn
  )
}


# ==============================================================================
# COMPONENT PIN BUTTON — small pin icon on chart/table wrappers
# ==============================================================================

#' Build Component Pin Button
#'
#' Small ghost-style pin button for individual chart/table pinning.
#'
#' @param section_key Section key (e.g., "importance", "odds-ratios")
#' @param component Component type: "chart" or "table"
#' @param id_prefix ID prefix for the panel
#' @return htmltools tag
#' @keywords internal
build_cd_component_pin_btn <- function(section_key, component, id_prefix = "") {
  label <- if (component == "chart") "\U0001F4CC Chart" else "\U0001F4CC Table"
  htmltools::tags$button(
    class = "cd-component-pin",
    `data-cd-pin-section` = section_key,
    `data-cd-pin-prefix` = id_prefix,
    `data-cd-pin-component` = component,
    onclick = sprintf("cdPinComponent('%s','%s','%s')", section_key, component, id_prefix),
    title = sprintf("Pin %s only", component),
    label
  )
}


# ==============================================================================
# OR CHIP BAR — factor filter pills for odds ratios
# ==============================================================================

#' Build OR Chip Bar
#'
#' Generates pill buttons to filter OR table rows by factor.
#'
#' @param odds_ratios List of OR entries (from transformer)
#' @param id_prefix ID prefix
#' @return htmltools tag or NULL
#' @keywords internal
build_cd_or_chip_bar <- function(odds_ratios, id_prefix = "") {
  if (is.null(odds_ratios) || length(odds_ratios) == 0) return(NULL)

  # Extract unique factor labels
  factor_labels <- unique(vapply(odds_ratios, function(r) {
    r$factor_label %||% ""
  }, character(1)))
  factor_labels <- factor_labels[nzchar(factor_labels)]

  if (length(factor_labels) < 2) return(NULL)  # no point with 1 factor

  chips <- lapply(factor_labels, function(fl) {
    htmltools::tags$button(
      class = "cd-or-chip active",
      `data-cd-or-factor` = fl,
      onclick = sprintf("cdToggleOrFactor('%s','%s')",
                        gsub("'", "\\\\'", fl), id_prefix),
      fl
    )
  })

  htmltools::tags$div(class = "cd-or-chip-bar", chips)
}


#' Build Probability Lift Chip Bar
#'
#' Creates a chip bar for showing/hiding drivers in the probability lift chart.
#' Mirrors the OR chip bar pattern.
#'
#' @param probability_lifts Named list of probability lift data
#' @param id_prefix Optional prefix for multi-report mode
#' @return htmltools tag or NULL
#' @keywords internal
build_cd_lift_chip_bar <- function(probability_lifts, id_prefix = "") {
  if (is.null(probability_lifts) || length(probability_lifts) == 0) return(NULL)

  # Extract driver labels
  driver_labels <- vapply(probability_lifts, function(pl) pl$label %||% "", character(1))
  driver_labels <- driver_labels[nzchar(driver_labels)]

  if (length(driver_labels) < 2) return(NULL)

  chips <- lapply(driver_labels, function(dl) {
    htmltools::tags$button(
      class = "cd-or-chip active",
      `data-cd-lift-factor` = dl,
      onclick = sprintf("cdToggleLiftFactor('%s','%s')",
                        gsub("'", "\\\\'", dl), id_prefix),
      dl
    )
  })

  htmltools::tags$div(class = "cd-or-chip-bar", chips)
}


# ==============================================================================
# ACTION BAR — Save button (for single-report mode)
# ==============================================================================

#' Build Action Bar
#'
#' Creates the save button strip.
#'
#' @param report_title Title for filename generation
#' @return htmltools tag
#' @keywords internal
build_cd_action_bar <- function(report_title = "Catdriver Report") {
  htmltools::tags$div(
    class = "cd-action-bar",
    htmltools::tags$span(
      class = "cd-saved-badge",
      id = "cd-saved-badge"
    ),
    htmltools::tags$button(
      class = "cd-save-btn",
      onclick = "cdSaveReportHTML()",
      "\U0001F4BE Save Report"
    )
  )
}


# ==============================================================================
# QUALITATIVE SLIDES PANEL
# ==============================================================================

#' Build Qualitative Slides Panel
#'
#' Creates a section for narrative slides with markdown editing,
#' image upload, and pin-to-pinned-views functionality. Slides can
#' be pre-seeded from the config Excel (Slides sheet) and/or added
#' interactively in the browser.
#'
#' @param slides List of slide objects (each with id, title, content, image_data), or NULL
#' @param brand_colour Hex brand colour
#' @return htmltools tag
#' @keywords internal
build_cd_qualitative_panel <- function(slides = NULL, brand_colour = "#323367") {

  # Build initial slide cards from config (if any)
  slide_cards <- if (!is.null(slides) && length(slides) > 0) {
    lapply(slides, function(s) {
      build_cd_qual_slide_card(
        s$id %||% paste0("cd-qual-", sample.int(1e6, 1)),
        s$title %||% "Untitled Slide",
        s$content %||% "",
        s$image_data
      )
    })
  }

  htmltools::tags$div(
    class = "cd-section",
    id = "cd-qualitative",
    `data-cd-section` = "qualitative",
    htmltools::tags$div(
      class = "cd-qual-container",
      style = "max-width:1400px;margin:0 auto;padding:20px 32px;",
      htmltools::tags$div(
        class = "cd-qual-header",
        style = "display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;",
        htmltools::tags$div(
          htmltools::tags$h2(style = "font-size:18px;font-weight:700;color:#1e293b;margin-bottom:4px;",
                             "Added Slides"),
          htmltools::tags$p(style = "font-size:12px;color:#64748b;",
                            "Narrative findings, interpretations, and supporting images. Double-click to edit, use markdown for formatting.")
        ),
        htmltools::tags$div(
          style = "display:flex;gap:8px;",
          htmltools::tags$button(class = "export-btn", onclick = "cdAddQualSlide()",
                                 "\u2795 Add Slide")
        )
      ),
      htmltools::tags$div(
        class = "cd-qual-md-help",
        style = "background:#f8fafc;border:1px solid #e2e8f0;border-radius:6px;padding:10px 16px;margin-bottom:16px;font-size:11px;color:#64748b;line-height:1.6;",
        htmltools::tags$span(style = "font-weight:600;color:#475569;", "Formatting: "),
        htmltools::HTML(paste0(
          "<code>**bold**</code> &middot; ",
          "<code>*italic*</code> &middot; ",
          "<code>## Heading</code> &middot; ",
          "<code>- bullet</code> &middot; ",
          "<code>&gt; quote</code>"
        ))
      ),
      htmltools::tags$div(id = "cd-qual-slides-container", slide_cards),
      htmltools::tags$div(
        id = "cd-qual-empty-state",
        style = paste0(
          if (!is.null(slides) && length(slides) > 0) "display:none;" else "",
          "text-align:center;padding:60px 20px;color:#94a3b8;"
        ),
        htmltools::tags$div(style = "font-size:36px;margin-bottom:12px;", "\U0001F4DD"),
        htmltools::tags$div(style = "font-size:14px;font-weight:600;", "No slides yet"),
        htmltools::tags$div(style = "font-size:12px;margin-top:4px;",
          "Click 'Add Slide' to create narrative content, or add a 'Slides' sheet to your config Excel.")
      )
    )
  )
}


#' Build Single Qualitative Slide Card
#'
#' @param slide_id Character unique ID
#' @param title Character slide title
#' @param content_md Character markdown content
#' @param image_data Character base64 data URL for embedded image, or NULL
#' @return htmltools tag
#' @keywords internal
build_cd_qual_slide_card <- function(slide_id, title, content_md, image_data = NULL) {
  htmltools::tags$div(
    class = "cd-qual-slide-card",
    `data-slide-id` = slide_id,
    htmltools::tags$div(
      class = "cd-qual-slide-header",
      htmltools::tags$div(
        class = "cd-qual-slide-title",
        contenteditable = "true",
        title
      ),
      htmltools::tags$div(
        class = "cd-qual-slide-actions",
        htmltools::tags$button(class = "export-btn", title = "Add image",
                               onclick = sprintf("cdTriggerQualImage('%s')", slide_id),
                               htmltools::HTML("&#x1F5BC;")),
        htmltools::tags$button(class = "export-btn", title = "Pin to Views",
                               onclick = sprintf("cdPinQualSlide('%s')", slide_id),
                               htmltools::HTML("&#x1F4CC;")),
        htmltools::tags$button(class = "export-btn", title = "Move up",
                               onclick = sprintf("cdMoveQualSlide('%s','up')", slide_id),
                               htmltools::HTML("&#x25B2;")),
        htmltools::tags$button(class = "export-btn", title = "Move down",
                               onclick = sprintf("cdMoveQualSlide('%s','down')", slide_id),
                               htmltools::HTML("&#x25BC;")),
        htmltools::tags$button(class = "export-btn", title = "Remove slide",
                               style = "color:#e8614d;",
                               onclick = sprintf("cdRemoveQualSlide('%s')", slide_id),
                               htmltools::HTML("&#x2715;"))
      )
    ),
    # Image preview
    htmltools::tags$div(class = "cd-qual-img-preview",
      style = if (is.null(image_data) || !nzchar(image_data %||% "")) "display:none;" else "",
      htmltools::tags$img(class = "cd-qual-img-thumb",
        src = if (!is.null(image_data) && nzchar(image_data %||% "")) image_data else ""),
      htmltools::tags$button(class = "cd-qual-img-remove",
                             onclick = sprintf("cdRemoveQualImage('%s')", slide_id),
                             title = "Remove image",
                             htmltools::HTML("&times;"))
    ),
    # Hidden file input for image upload
    htmltools::tags$input(type = "file", class = "cd-qual-img-input",
                          accept = "image/*", style = "display:none;",
                          onchange = sprintf("cdHandleQualImage('%s', this)", slide_id)),
    # Markdown editor (shown when editing)
    htmltools::tags$textarea(
      class = "cd-qual-md-editor",
      rows = "6",
      placeholder = "Enter markdown content... (**bold**, *italic*, > quote, - bullet, ## heading)",
      content_md
    ),
    # Rendered output (shown when not editing)
    htmltools::tags$div(class = "cd-qual-md-rendered"),
    # Hidden stores for persistence
    htmltools::tags$textarea(class = "cd-qual-md-store", style = "display:none;", content_md),
    htmltools::tags$textarea(class = "cd-qual-img-store", style = "display:none;",
      if (!is.null(image_data) && nzchar(image_data %||% "")) image_data else "")
  )
}
