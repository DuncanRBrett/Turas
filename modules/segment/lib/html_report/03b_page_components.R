# ==============================================================================
# SEGMENT HTML REPORT - PAGE COMPONENTS
# ==============================================================================
# Reusable UI components: section nav, header, insight areas, toolbars,
# action bar, pin buttons.
#
# Extracted from 03_page_builder.R for maintainability.
#
# FUNCTIONS:
# - build_seg_section_nav()       - Sticky section navigation bar
# - build_seg_header()            - Report header with metadata
# - build_seg_section_title_row() - Section heading with controls
# - build_seg_insight_area()      - Editable insight text areas
# - build_seg_component_pin_btn() - Pin button for individual components
# - build_seg_table_toolbar()     - Table view toggles
# - build_seg_table_export_toolbar() - Excel export button
# - build_seg_action_bar()        - Save/Print/Help action bar
# ==============================================================================

# ==============================================================================
# SECTION NAVIGATION
# ==============================================================================

#' Build Section Navigation Bar
#'
#' Creates a sticky horizontal nav bar below the header with section links.
#' Only shows sections where show=TRUE in sections_config.
#'
#' @param brand_colour Brand colour hex string
#' @param sections_config Named list of list(label, show) entries
#' @return htmltools tag
#' @keywords internal
build_seg_section_nav <- function(brand_colour = "#323367", sections_config = list()) {

  links <- list()
  first <- TRUE
  for (key in names(sections_config)) {
    sec <- sections_config[[key]]
    if (!isTRUE(sec$show)) next

    active_class <- if (first) "active" else NULL
    first <- FALSE

    links <- c(links, list(
      htmltools::tags$a(
        href = paste0("#seg-", key),
        class = active_class,
        sec$label
      )
    ))
  }

  htmltools::tags$nav(
    class = "seg-section-nav",
    id = "seg-section-nav",
    links
  )
}


# ==============================================================================
# HEADER
# ==============================================================================

#' Build Header Section
#'
#' Creates the gradient banner header with module name, report title,
#' prepared-by text, and badge bar showing method, k, n, and date.
#'
#' @param html_data Transformed HTML data
#' @param config Configuration list
#' @param brand_colour Brand colour hex string
#' @param report_title Report title text
#' @return htmltools tag
#' @keywords internal
build_seg_header <- function(html_data, config, brand_colour, report_title) {

  method_label <- switch(tolower(html_data$method %||% "kmeans"),
    kmeans  = "K-Means",
    pam     = "PAM (K-Medoids)",
    hclust  = "Hierarchical",
    gmm     = "GMM (Gaussian Mixture)",
    mclust  = "GMM (Gaussian Mixture)",
    lca     = "Latent Class",
    html_data$method
  )

  # --- Researcher Logo ---
  logo_el <- NULL
  if (exists("resolve_logo_uri", mode = "function")) {
    logo_uri <- resolve_logo_uri(config$researcher_logo_path)
    if (!is.null(logo_uri) && nzchar(logo_uri)) {
      logo_el <- htmltools::tags$div(
        class = "seg-header-logo-container",
        htmltools::tags$img(
          src = logo_uri,
          alt = "Logo",
          style = "height:56px;width:56px;object-fit:contain;"
        )
      )
    }
  }

  # --- Client Logo ---
  client_logo_el <- NULL
  if (exists("resolve_logo_uri", mode = "function")) {
    client_logo_uri <- resolve_logo_uri(config$client_logo_path)
    if (!is.null(client_logo_uri) && nzchar(client_logo_uri)) {
      client_logo_el <- htmltools::tags$div(
        class = "seg-header-logo-container",
        style = "margin-left:auto;",
        htmltools::tags$img(
          src = client_logo_uri,
          alt = "Client Logo",
          style = "height:56px;width:56px;object-fit:contain;"
        )
      )
    }
  }

  # --- Top row: [logo] TURAS SEGMENTATION / subtitle [client logo] ---
  branding_left <- htmltools::tags$div(
    class = "seg-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "seg-header-module-name", "TURAS Segmentation"),
      htmltools::tags$div(class = "seg-header-module-sub", "Survey Analytics Platform")
    ),
    client_logo_el
  )

  top_row <- htmltools::tags$div(
    class = "seg-header-top",
    branding_left
  )

  # --- Project title ---
  title_row <- htmltools::tags$div(
    class = "seg-header-title",
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
      class = "seg-header-prepared",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Badge bar ---
  badge_items <- list()

  # Method badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    htmltools::HTML(sprintf(
      '<span class="seg-header-badge-val">%s</span>',
      method_label
    ))
  )))

  # Segments badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    htmltools::HTML(sprintf(
      'Segments:&nbsp;<span class="seg-header-badge-val">%d</span>',
      html_data$k %||% 0L
    ))
  )))

  # Sample size badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    htmltools::HTML(sprintf(
      'n&nbsp;=&nbsp;<span class="seg-header-badge-val">%s</span>',
      format(html_data$n_observations %||% 0L, big.mark = ",")
    ))
  )))

  # Date badge
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "seg-header-badge",
    format(Sys.Date(), "Created %b %Y")
  )))

  # Interleave with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els, list(
        htmltools::tags$span(class = "seg-header-badge-sep")
      ))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  badges_bar <- htmltools::tags$div(
    class = "seg-header-badges",
    badge_els
  )

  # --- Assemble header ---
  htmltools::tags$div(
    class = "seg-header",
    id = "seg-header",
    htmltools::tags$div(
      class = "seg-header-inner",
      top_row,
      title_row,
      prepared_row,
      badges_bar
    )
  )
}


# ==============================================================================
# SECTION TITLE ROW — title + pin button
# ==============================================================================

#' Build Section Title Row
#'
#' Wraps a section title and pin button in a flex row.
#'
#' @param title_text Title text
#' @param section_key Section key for pinning
#' @param show_pin Whether to show the pin button (default TRUE)
#' @return htmltools tag
#' @keywords internal
build_seg_section_title_row <- function(title_text, section_key,
                                         show_pin = TRUE) {
  pin_btn <- if (show_pin) {
    htmltools::tags$button(
      class = "seg-pin-btn",
      `data-seg-pin-section` = section_key,
      onclick = sprintf("segPinSection('%s')", section_key),
      title = "Pin to Views",
      "\U0001F4CC"
    )
  }

  htmltools::tags$div(
    class = "seg-section-title-row",
    htmltools::tags$h2(class = "seg-section-title", title_text),
    pin_btn
  )
}


# ==============================================================================
# INSIGHT AREA — editable text per section
# ==============================================================================

#' Build Insight Area
#'
#' Creates the editable insight area: toggle button + hidden editor.
#'
#' @param section_key Section key string
#' @return htmltools tagList
#' @keywords internal
build_seg_insight_area <- function(section_key, pre_text = NULL) {
  # Auto-lookup from config insights if not explicitly passed
  if (is.null(pre_text) && exists(".seg_config_insights", envir = .GlobalEnv)) {
    insights <- get(".seg_config_insights", envir = .GlobalEnv)
    if (!is.null(insights) && length(insights) > 0) {
      # Try exact match, then with hyphens replaced by spaces/underscores
      key_variants <- c(section_key, gsub("-", " ", section_key), gsub("-", "_", section_key))
      for (kv in key_variants) {
        if (kv %in% names(insights) && nzchar(insights[kv])) {
          pre_text <- unname(insights[kv])
          break
        }
      }
    }
  }
  has_pre <- !is.null(pre_text) && nzchar(trimws(pre_text))
  # Apply basic markdown formatting to pre-populated insights
  pre_html <- if (has_pre) {
    txt <- pre_text
    txt <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", txt, perl = TRUE)
    txt <- gsub("\\*(.+?)\\*", "<em>\\1</em>", txt, perl = TRUE)
    txt <- gsub("^- (.+)", "<li>\\1</li>", txt, perl = TRUE)
    txt <- gsub("\n", "<br/>", txt)
    htmltools::HTML(txt)
  } else {
    NULL
  }
  htmltools::tags$div(
    class = "seg-insight-area",
    `data-seg-insight-section` = section_key,
    htmltools::tags$button(
      class = "seg-insight-toggle",
      id = paste0("seg-insight-toggle-", section_key),
      onclick = sprintf("segToggleInsight('%s')", section_key),
      style = if (has_pre) "display:none;" else "",
      "\u270E Add Insight"
    ),
    htmltools::tags$div(
      class = "seg-insight-container",
      id = paste0("seg-insight-container-", section_key),
      style = if (has_pre) "display:block;" else "",
      htmltools::tags$div(
        class = "seg-insight-editor",
        contenteditable = "true",
        `data-placeholder` = "Type your insight or comment here...",
        oninput = sprintf("segSyncInsight('%s')", section_key),
        if (has_pre) pre_html
      ),
      htmltools::tags$div(
        class = "seg-insight-hint",
        "Your notes will appear on exported slides"
      ),
      htmltools::tags$button(
        class = "seg-insight-dismiss",
        onclick = sprintf("segDismissInsight('%s')", section_key),
        "\u00D7"
      )
    )
  )
}


# ==============================================================================
# COMPONENT PIN BUTTON
# ==============================================================================

#' Build Component Pin Button
#'
#' Small ghost-style pin button for individual chart/table pinning.
#'
#' @param section_key Section key
#' @param component Component type: "chart" or "table"
#' @return htmltools tag
#' @keywords internal
build_seg_component_pin_btn <- function(section_key, component, prefix = "") {
  label <- if (component == "chart") "\U0001F4CC Chart" else "\U0001F4CC Table"
  htmltools::tags$button(
    class = "seg-component-pin",
    `data-seg-pin-section` = section_key,
    `data-seg-pin-component` = component,
    onclick = sprintf("segPinComponent('%s','%s','%s')", section_key, component, prefix),
    title = sprintf("Pin %s only", component),
    label
  )
}


#' Build Table Toolbar
#'
#' Creates a toolbar row with export and pin buttons that appears on hover
#' above a table wrapper. Keeps buttons out of the table header area.
#'
#' @param section_key Section identifier
#' @param prefix Optional prefix for pin component
#' @return htmltools tag — a div.seg-table-toolbar containing both buttons
#' @keywords internal
build_seg_table_toolbar <- function(section_key, prefix = "") {
  htmltools::tags$div(
    class = "seg-table-toolbar",
    htmltools::tags$button(
      class = "seg-table-export",
      onclick = sprintf("segExportTableCSV(this, '%s')", section_key),
      title = "Export table to Excel (CSV)",
      htmltools::HTML("&#x1F4E5; Excel")
    ),
    htmltools::tags$button(
      class = "seg-component-pin",
      `data-seg-pin-section` = section_key,
      `data-seg-pin-component` = "table",
      onclick = sprintf("segPinComponent('%s','table','%s')", section_key, prefix),
      title = "Pin table only",
      "\U0001F4CC Table"
    )
  )
}

#' Build Table Export-Only Toolbar
#'
#' Creates a toolbar row with just an export button (no pin) for tables
#' that don't have a pin button.
#'
#' @param section_key Section identifier
#' @return htmltools tag
#' @keywords internal
build_seg_table_export_toolbar <- function(section_key) {
  htmltools::tags$div(
    class = "seg-table-toolbar",
    htmltools::tags$button(
      class = "seg-table-export",
      onclick = sprintf("segExportTableCSV(this, '%s')", section_key),
      title = "Export table to Excel (CSV)",
      htmltools::HTML("&#x1F4E5; Excel")
    )
  )
}


# ==============================================================================
# ACTION BAR
# ==============================================================================

#' Build Action Bar
#'
#' Creates the save button strip.
#'
#' @param report_title Title for filename generation
#' @return htmltools tag
#' @keywords internal
build_seg_action_bar <- function(report_title = "Segment Report") {

  # Help overlay
  help_overlay <- htmltools::tags$div(
    id = "seg-help-overlay",
    style = paste0(
      "display:none; position:fixed; top:0; left:0; width:100%; height:100%; ",
      "background:rgba(0,0,0,0.5); z-index:10000; justify-content:center; align-items:center;"
    ),
    onclick = "if(event.target===this) segToggleHelp();",
    htmltools::tags$div(
      style = paste0(
        "background:#fff; border-radius:12px; max-width:560px; width:90%; max-height:80vh; ",
        "overflow-y:auto; padding:28px; position:relative; box-shadow:0 8px 32px rgba(0,0,0,0.2);"
      ),
      htmltools::tags$button(
        style = paste0(
          "position:absolute; top:12px; right:16px; background:none; border:none; ",
          "font-size:22px; color:#94a3b8; cursor:pointer;"
        ),
        onclick = "segToggleHelp()",
        "\u00D7"
      ),
      htmltools::tags$h3(
        style = "color:var(--seg-brand); margin:0 0 16px; font-size:18px;",
        "\u2753 Navigating This Report"
      ),
      htmltools::tags$div(
        style = "font-size:13px; color:#334155; line-height:1.7;",
        htmltools::HTML(paste0(
          "<p><strong>Tabs</strong> \u2014 Switch between <em>Analysis</em> (main results), ",
          "<em>Pinned Views</em> (saved charts for presentations), <em>Slides</em> (custom ",
          "presentation slides with images), and <em>About</em> (analyst &amp; project details).</p>",
          "<p><strong>Section Nav</strong> \u2014 Click any section name (Summary, Overview, etc.) ",
          "to jump directly to that section. The active section is highlighted.</p>",
          "<p><strong>Pin Button</strong> <span style='color:var(--seg-brand);'>\U0001F4CC</span> \u2014 ",
          "Click the pin icon on any chart or table to save it to Pinned Views for export.</p>",
          "<p><strong>Add Insight</strong> <span style='color:var(--seg-brand);'>\u270E</span> \u2014 ",
          "Click to add your own notes or commentary to any section. Insights are saved ",
          "when you save the report.</p>",
          "<p><strong>Variable Importance</strong> \u2014 Click the \u00D7 on any bar to hide ",
          "it for presentations. Click the + to restore, or use 'Show all'.</p>",
          "<p><strong>Golden Questions</strong> \u2014 Use checkboxes to see how classification ",
          "accuracy changes as questions are added or removed.</p>",
          "<p><strong>Save Report</strong> \u2014 Downloads the current report as a self-contained ",
          "HTML file. All your insights, pins, and edits are preserved. Open the saved file ",
          "in any browser.</p>",
          "<p><strong>Slides</strong> \u2014 Create presentation slides with titles, text, and ",
          "uploaded images. Pre-configure slides from the Excel config (Slides sheet).</p>"
        ))
      )
    )
  )

  htmltools::tagList(
    help_overlay,
    htmltools::tags$div(
      class = "seg-action-bar",
      htmltools::tags$button(
        style = paste0(
          "background:none; border:1px solid #d1d5db; border-radius:50%; ",
          "width:32px; height:32px; cursor:pointer; color:#64748b; font-size:16px; ",
          "font-weight:700; margin-right:8px; line-height:1;"
        ),
        onclick = "segToggleHelp()",
        title = "Help",
        "?"
      ),
      htmltools::tags$span(
        class = "seg-saved-badge",
        id = "seg-saved-badge"
      ),
      htmltools::tags$button(
        class = "seg-save-btn",
        onclick = "segSaveReportHTML()",
        "\U0001F4BE Save Report"
      )
    )
  )
}

