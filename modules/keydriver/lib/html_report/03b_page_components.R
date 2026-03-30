# ==============================================================================
# KEYDRIVER HTML REPORT - PAGE COMPONENTS
# ==============================================================================
# Reusable UI components: header, navigation, action bar, insight areas,
# pin buttons, section titles, JS loader, logo resolver.
#
# Extracted from 03_page_builder.R for maintainability.
# ==============================================================================

# ==============================================================================
# HEADER BUILDER
# ==============================================================================

#' Build Header Section
#'
#' Creates the gradient banner header matching tabs/tracker/catdriver design.
#' Includes logo, module name, project title, prepared-by text, and badge bar.
#'
#' @param html_data Transformed HTML data
#' @param config Configuration list
#' @return htmltools tag
#' @keywords internal
build_kd_header <- function(html_data, config) {

  brand_colour  <- config$brand_colour %||% "#323367"
  report_title  <- config$report_title %||% html_data$analysis_name %||%
    "Key Driver Analysis"
  model_info    <- html_data$model_info

  # --- Researcher Logo ---
  logo_el <- NULL
  logo_uri <- kd_resolve_logo_uri(config$researcher_logo_path)
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_el <- htmltools::tags$div(
      class = "kd-header-logo-container",
      htmltools::tags$img(
        src = logo_uri, alt = "Logo",
        style = "height:56px;width:56px;object-fit:contain;"
      )
    )
  }

  # --- Client Logo ---
  client_logo_el <- NULL
  client_logo_uri <- kd_resolve_logo_uri(config$client_logo_path)
  if (!is.null(client_logo_uri) && nzchar(client_logo_uri)) {
    client_logo_el <- htmltools::tags$div(
      class = "kd-header-logo-container",
      style = "margin-left:auto;",
      htmltools::tags$img(
        src = client_logo_uri, alt = "Client Logo",
        style = "height:56px;width:56px;object-fit:contain;"
      )
    )
  }

  # --- Top row ---
  branding_left <- htmltools::tags$div(
    class = "kd-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "kd-header-module-name", "Turas Keydriver"),
      htmltools::tags$div(class = "kd-header-module-sub",
                          "Key Driver Correlation Analysis")
    ),
    client_logo_el
  )

  top_row <- htmltools::tags$div(class = "kd-header-top", branding_left)

  # --- Project title ---
  title_row <- htmltools::tags$div(class = "kd-header-title", report_title)

  # --- Prepared by / for text ---
  prepared_row <- NULL
  company_name    <- config$company_name %||% "The Research Lamppost"
  client_name     <- config$client_name %||% NULL
  researcher_name <- config$researcher_name %||% NULL
  prepared_parts  <- c()

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
      class = "kd-header-prepared",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Badge bar ---
  badge_items <- list()

  # R-squared
  r2 <- model_info$r_squared
  if (!is.null(r2) && !is.na(r2)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        'R\u00B2&nbsp;=&nbsp;<span class="kd-header-badge-val">%.3f</span>', r2
      ))
    )))
  }

  # Sample size
  n_obs <- model_info$n_obs
  if (!is.null(n_obs) && !is.na(n_obs)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        'n&nbsp;=&nbsp;<span class="kd-header-badge-val">%s</span>',
        format(n_obs, big.mark = ",")
      ))
    )))
  }

  # Drivers count
  n_drv <- model_info$n_drivers %||% html_data$n_drivers
  if (!is.null(n_drv) && !is.na(n_drv)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        '<span class="kd-header-badge-val">%d</span>&nbsp;Drivers', n_drv
      ))
    )))
  }

  # Methods count
  n_methods <- length(html_data$methods_available)
  if (n_methods > 0) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      class = "kd-header-badge",
      htmltools::HTML(sprintf(
        '<span class="kd-header-badge-val">%d</span>&nbsp;Methods', n_methods
      ))
    )))
  }

  # Date
  badge_items <- c(badge_items, list(htmltools::tags$span(
    class = "kd-header-badge", format(Sys.Date(), "Created %b %Y")
  )))

  # Interleave with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els,
        list(htmltools::tags$span(class = "kd-header-badge-sep")))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  badges_bar <- htmltools::tags$div(class = "kd-header-badges", badge_els)

  # --- Assemble ---
  htmltools::tags$div(
    class = "kd-header", id = "kd-header",
    htmltools::tags$div(
      class = "kd-header-inner",
      top_row, title_row, prepared_row, badges_bar
    )
  )
}


# ==============================================================================
# NAVIGATION BAR
# ==============================================================================

#' Build Horizontal Section Navigation Bar
#'
#' Creates a sticky horizontal nav bar with section links.
#' Conditionally includes tabs for optional sections.
#'
#' @param html_data Transformed HTML data (used to detect optional sections)
#' @return htmltools tag
#' @keywords internal
build_kd_nav <- function(html_data, settings = list()) {

  has_effect_sizes <- !is.null(html_data$effect_sizes)
  has_quadrant     <- isTRUE(html_data$has_quadrant)
  has_shap         <- isTRUE(html_data$has_shap)
  has_bootstrap    <- isTRUE(html_data$has_bootstrap)
  has_segments     <- !is.null(html_data$segment_comparison)

  # Section visibility from settings
  .show <- function(key, default = TRUE) {
    val <- settings[[key]]
    if (is.null(val)) return(default)
    isTRUE(as.logical(val))
  }

  links <- list()

  # Each link uses data-kd-page for page switching (not scroll anchors)
  if (.show("html_show_exec_summary")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "exec-summary",
                        onclick = "kdSwitchPage('exec-summary')", "Summary", class = "active")))
  }
  if (.show("html_show_importance")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "importance",
                        onclick = "kdSwitchPage('importance')", "Importance")))
  }
  if (.show("html_show_methods")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "method-comparison",
                        onclick = "kdSwitchPage('method-comparison')", "Methods")))
  }
  if (has_effect_sizes && .show("html_show_effect_sizes")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "effect-sizes",
                        onclick = "kdSwitchPage('effect-sizes')", "Effect Sizes")))
  }
  if (.show("html_show_correlations")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "correlations",
                        onclick = "kdSwitchPage('correlations')", "Correlations")))
  }
  if (has_quadrant && .show("html_show_quadrant")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "quadrant",
                        onclick = "kdSwitchPage('quadrant')", "Quadrant")))
  }
  if (has_shap && .show("html_show_shap")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "shap-summary",
                        onclick = "kdSwitchPage('shap-summary')", "SHAP")))
  }
  if (.show("html_show_diagnostics")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "diagnostics",
                        onclick = "kdSwitchPage('diagnostics')", "Diagnostics")))
  }
  if (has_bootstrap && .show("html_show_bootstrap")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "bootstrap-ci",
                        onclick = "kdSwitchPage('bootstrap-ci')", "Bootstrap")))
  }
  if (has_segments && .show("html_show_segments")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "segment-comparison",
                        onclick = "kdSwitchPage('segment-comparison')", "Segments")))
  }
  # v1.04 advanced sections
  if (isTRUE(html_data$has_elastic_net)) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "elastic-net",
                        onclick = "kdSwitchPage('elastic-net')", "Elastic Net")))
  }
  if (isTRUE(html_data$has_nca)) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "nca",
                        onclick = "kdSwitchPage('nca')", "NCA")))
  }
  if (isTRUE(html_data$has_dominance)) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "dominance",
                        onclick = "kdSwitchPage('dominance')", "Dominance")))
  }
  if (isTRUE(html_data$has_gam)) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "gam",
                        onclick = "kdSwitchPage('gam')", "GAM")))
  }
  if (.show("html_show_guide")) {
    links <- c(links, list(
      htmltools::tags$a(`data-kd-page` = "interpretation",
                        onclick = "kdSwitchPage('interpretation')", "Guide")))
  }

  htmltools::tags$nav(
    class = "kd-section-nav", id = "kd-section-nav", links
  )
}



# ==============================================================================

#' Build Action Bar
#'
#' Creates the save button strip.
#'
#' @param report_title Title for filename generation
#' @return htmltools tag
#' @keywords internal
build_kd_action_bar <- function(report_title = "Keydriver Report") {
  htmltools::tags$div(
    class = "kd-action-bar",
    htmltools::tags$span(
      class = "kd-saved-badge", id = "kd-saved-badge"
    ),
    htmltools::tags$button(
      class = "kd-save-btn",
      onclick = "kdSaveReportHTML()",
      "\U0001F4BE Save Report"
    )
  )
}


# ==============================================================================
# JAVASCRIPT INLINER
# ==============================================================================

#' Read and Inline JS Files
#'
#' Reads all required JS files from the js/ subdirectory and returns
#' them as inline script tags.
#'
#' @param html_report_dir Path to the html_report directory
#' @return htmltools tagList of script tags
#' @keywords internal
build_kd_js <- function(html_report_dir) {
  # Load shared TurasPins library first (required by kd_pins.js)
  shared_js_tag <- if (exists("turas_pins_js", mode = "function")) {
    shared_js <- turas_pins_js()
    if (nzchar(shared_js)) htmltools::tags$script(htmltools::HTML(shared_js))
  }

  js_files <- c("kd_utils.js", "kd_navigation.js",
                 "kd_table_export.js", "kd_pins.js", "kd_pins_extras.js")

  js_tags <- lapply(js_files, function(fname) {
    js_path <- file.path(html_report_dir, "js", fname)
    js_content <- if (file.exists(js_path)) {
      paste(readLines(js_path, warn = FALSE), collapse = "\n")
    } else {
      cat(sprintf("    [WARN] JS file not found: %s\n", js_path))
      sprintf("/* %s not found */", fname)
    }
    htmltools::tags$script(htmltools::HTML(js_content))
  })

  # Prepend shared library before module JS
  if (!is.null(shared_js_tag)) js_tags <- c(list(shared_js_tag), js_tags)

  htmltools::tagList(js_tags)
}


# ==============================================================================
# SECTION TITLE ROW — title + pin button
# ==============================================================================

#' Build Section Title Row
#'
#' Wraps a section title and pin button in a flex row.
#'
#' @param title Title text
#' @param section_key Section key for pinning
#' @param prefix ID prefix (default empty string)
#' @param show_pin Whether to show the pin button
#' @return htmltools tag
#' @keywords internal
build_kd_section_title_row <- function(title, section_key, prefix = "",
                                        show_pin = TRUE) {
  pin_btn <- if (show_pin) {
    htmltools::tags$button(
      class = "kd-pin-btn",
      `data-kd-pin-section` = section_key,
      `data-kd-pin-prefix` = prefix,
      onclick = sprintf("kdPinSection('%s','%s')", section_key, prefix),
      title = "Pin to Views",
      "\U0001F4CC"
    )
  }

  htmltools::tags$div(
    class = "kd-section-title-row",
    htmltools::tags$h2(class = "kd-section-title", title),
    pin_btn
  )
}


# ==============================================================================
# COMPONENT PIN BUTTON
# ==============================================================================

#' Build Component Pin Button
#'
#' Small ghost-style pin button for individual chart/table pinning.
#'
#' @param section_key Section key (e.g., "importance", "correlations")
#' @param component Component type: "chart" or "table"
#' @param prefix ID prefix (default empty string)
#' @return htmltools tag
#' @keywords internal
build_kd_component_pin_btn <- function(section_key, component, prefix = "") {
  label <- if (component == "chart") "\U0001F4CC Chart" else "\U0001F4CC Table"
  htmltools::tags$button(
    class = "kd-component-pin",
    `data-kd-pin-section` = section_key,
    `data-kd-pin-prefix` = prefix,
    `data-kd-pin-component` = component,
    onclick = sprintf("kdPinComponent('%s','%s','%s')",
                      section_key, component, prefix),
    title = sprintf("Pin %s only", component),
    label
  )
}


# ==============================================================================
# INSIGHT AREA
# ==============================================================================

#' Build Insight Area
#'
#' Creates the editable insight area: toggle button + hidden editor.
#'
#' @param section_key Section key string (e.g., "exec-summary", "importance")
#' @param prefix ID prefix (default empty string)
#' @return htmltools tagList
#' @keywords internal
build_kd_insight_area <- function(section_key, prefix = "", config = NULL) {
  # Check for pre-populated insight from config$insights
  pre_text <- NULL
  pre_image_tag <- NULL
  if (!is.null(config) && !is.null(config$insights)) {
    ins <- config$insights
    match_row <- ins[tolower(ins$section) == tolower(section_key), , drop = FALSE]
    if (nrow(match_row) > 0) {
      pre_text <- match_row$insight_text[1]
      # Handle optional image (file path → base64 inline)
      img_path <- match_row$image_path[1]
      if (!is.null(img_path) && !is.na(img_path) && nchar(trimws(img_path)) > 0) {
        img_path <- trimws(img_path)
        if (file.exists(img_path)) {
          ext <- tolower(tools::file_ext(img_path))
          mime <- switch(ext, png = "image/png", jpg = , jpeg = "image/jpeg",
                         gif = "image/gif", svg = "image/svg+xml", "image/png")
          b64 <- tryCatch({
            raw_bytes <- readBin(img_path, "raw", file.info(img_path)$size)
            if (requireNamespace("base64enc", quietly = TRUE)) {
              base64enc::base64encode(raw_bytes)
            } else {
              # Fallback: use base R base64 encoding (R >= 4.0)
              jsonlite::base64_enc(raw_bytes)
            }
          }, error = function(e) NULL)
          if (!is.null(b64)) {
            pre_image_tag <- htmltools::tags$img(
              src = paste0("data:", mime, ";base64,", b64),
              alt = paste("Insight image for", section_key),
              style = "max-width:100%; border-radius:6px; margin-top:8px;"
            )
          }
        }
      }
    }
  }

  # Build the editor content
  editor_children <- list()
  if (!is.null(pre_text) && !is.na(pre_text) && nchar(pre_text) > 0) {
    editor_children <- list(htmltools::HTML(htmltools::htmlEscape(pre_text)))
  }

  # Build the container — auto-show if pre-populated
  has_content <- !is.null(pre_text) && !is.na(pre_text) && nchar(pre_text) > 0
  container_style <- if (has_content) "display:block;" else ""

  htmltools::tags$div(
    class = "kd-insight-area",
    `data-kd-insight-section` = section_key,
    `data-kd-insight-prefix` = prefix,
    htmltools::tags$button(
      class = "kd-insight-toggle",
      id = paste0(prefix, "kd-insight-toggle-", section_key),
      onclick = sprintf("kdToggleInsight('%s','%s')", section_key, prefix),
      if (has_content) "Edit Insight" else "+ Add Insight"
    ),
    htmltools::tags$div(
      class = "kd-insight-container",
      id = paste0(prefix, "kd-insight-container-", section_key),
      style = container_style,
      htmltools::tags$div(
        class = "kd-insight-editor",
        contenteditable = "true",
        role = "textbox",
        `aria-label` = paste("Analyst insight for", section_key, "section"),
        `data-placeholder` = "Type your insight or comment here...",
        oninput = sprintf("kdSyncInsight('%s','%s')", section_key, prefix),
        editor_children
      ),
      pre_image_tag,
      htmltools::tags$button(
        class = "kd-insight-dismiss",
        onclick = sprintf("kdDismissInsight('%s','%s')", section_key, prefix),
        "\u00D7"
      )
    )
  )
}


# ==============================================================================
# INSIGHT CALLOUT CARD
# ==============================================================================

#' Build Insight Callout Card
#'
#' An insight callout with left brand border.
#'
#' @param text Insight text
#' @return htmltools tag
#' @keywords internal
build_kd_insight_card <- function(text) {
  htmltools::tags$div(
    class = "kd-callout",
    htmltools::tags$div(class = "kd-callout-text", text)
  )
}


# ==============================================================================
# LOGO URI RESOLVER
# ==============================================================================

#' Resolve Logo URI
#'
#' Converts a file path to a base64 data URI for self-contained HTML.
#' Accepts NULL, file paths, or already-formed data: URIs.
#'
#' @param logo_path File path or URI string
#' @return Character data URI or NULL
#' @keywords internal
kd_resolve_logo_uri <- function(logo_path) {
  if (is.null(logo_path) || !nzchar(logo_path %||% "")) return(NULL)

  # Already a URI
  if (grepl("^(data:|https?://)", logo_path)) return(logo_path)

  # File path -- convert to base64
  if (!file.exists(logo_path)) return(NULL)

  if (!requireNamespace("base64enc", quietly = TRUE)) {
    cat("[WARN] base64enc package required for logo embedding. Install with: install.packages('base64enc')\n")
    return(NULL)
  }

  ext <- tolower(tools::file_ext(logo_path))
  mime_type <- switch(ext,
    png = "image/png",
    jpg = , jpeg = "image/jpeg",
    svg = "image/svg+xml",
    gif = "image/gif",
    "image/png"
  )

  tryCatch({
    base64enc::dataURI(file = logo_path, mime = mime_type)
  }, error = function(e) {
    cat(sprintf("[WARN] Failed to encode logo '%s': %s\n",
                logo_path, e$message))
    NULL
  })
}
