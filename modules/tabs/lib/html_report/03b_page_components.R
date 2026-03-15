# ==============================================================================
# HTML REPORT - PAGE COMPONENTS (V10.8)
# ==============================================================================
# UI component builders for the HTML report layout.
# Extracted from 03_page_builder.R for modularity.
#
# FUNCTIONS:
# - build_report_tab_nav() - Main tab navigation (Summary/Crosstabs/Slides/About)
# - build_tab_javascript() - Tab switching JS
# - build_header() - Branded header with logo, stats badges
# - build_help_overlay() - Modal help guide
# - build_sidebar() - Question navigator sidebar
# - build_banner_tabs() - Banner group tabs
# - build_controls() - Toggle checkboxes (heatmap, count, chart)
# - build_insight_area() - Per-question editable insight callout
# - build_question_containers() - Question containers with tables/charts
# - build_qualitative_panel() - Narrative slides panel
# - build_qual_slide_card() - Individual slide card
# - build_footer() - Report footer
# - build_closing_section() - Contact/closing info section
# - build_about_panel() - About tab wrapper
#
# DEPENDENCIES:
# - js_esc() from 03_page_builder.R
# - jsonlite::toJSON for data embedding
# ==============================================================================

#' Build Report Tab Navigation (Summary / Crosstabs)
#'
#' @param brand_colour Character hex colour
#' @return htmltools::tags$div
#' @keywords internal
build_report_tab_nav <- function(brand_colour, has_qualitative = FALSE, has_about = FALSE) {
  qual_tab <- if (has_qualitative) {
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('qualitative')",
      `data-tab` = "qualitative",
      "Added Slides"
    )
  }

  about_tab <- if (has_about) {
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('about')",
      `data-tab` = "about",
      "About"
    )
  }

  htmltools::tags$div(
    class = "report-tabs",
    htmltools::tags$button(
      class = "report-tab active",
      onclick = "switchReportTab('summary')",
      `data-tab` = "summary",
      "Summary"
    ),
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('crosstabs')",
      `data-tab` = "crosstabs",
      "Crosstabs"
    ),
    qual_tab,
    about_tab,
    htmltools::tags$button(
      class = "report-tab",
      onclick = "switchReportTab('pinned')",
      `data-tab` = "pinned",
      "Pinned Views",
      htmltools::tags$span(class = "pin-count-badge", id = "pin-count-badge", style = paste0("display:none;margin-left:4px;background:", brand_colour, ";color:#fff;font-size:10px;padding:1px 6px;border-radius:8px;"), "0")
    )
  )
}


#' Build Tab Switching JavaScript
#'
#' @return htmltools::tags$script
#' @keywords internal
build_tab_javascript <- function() {
  js <- '
    function switchReportTab(tabName) {
      document.querySelectorAll(".report-tab").forEach(function(btn) {
        btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
      });
      document.querySelectorAll(".tab-panel").forEach(function(panel) {
        panel.classList.remove("active");
      });
      var target = document.getElementById("tab-" + tabName);
      if (target) target.classList.add("active");

      // When switching to crosstabs, rebuild column chips & chart pickers
      // (they may have been built while the panel was hidden)
      if (tabName === "crosstabs") {
        window.dispatchEvent(new Event("resize"));
        if (typeof buildColumnChips === "function") buildColumnChips(currentGroup);
        if (typeof buildChartPickersForGroup === "function") buildChartPickersForGroup(currentGroup);
      }
    }
  '
  htmltools::tags$script(htmltools::HTML(js))
}


#' Build Header
#'
#' Constructs the banner at the top of the HTML report. Layout:
#' - Top row: [researcher logo] "Turas Tabs" / subtitle ... [? help button]
#' - Study name (large, bold)
#' - Prepared by / for line
#' - Stats badge bar (n, questions, weighted/unweighted, updated date)
#'
#' @param project_title Character - study name from config
#' @param brand_colour Character - hex colour for accent border
#' @param total_n Numeric or NA - total sample size
#' @param n_questions Integer - number of questions
#' @param company_name Character - researcher / company name
#' @param client_name Character or NULL - client organisation
#' @param researcher_logo_uri Character or NULL - base64 data URI for logo
#' @param apply_weighting Logical - whether weighting was applied
#' @return htmltools::div
build_header <- function(project_title, brand_colour, total_n, n_questions,
                         company_name = "The Research Lamppost",
                         client_name = NULL,
                         researcher_logo_uri = NULL,
                         apply_weighting = FALSE) {

  # Researcher logo element (left of "Turas Tabs")
  logo_container_style <- paste0(
    "width:72px;height:72px;border-radius:12px;",
    "background:transparent;",
    "display:flex;align-items:center;justify-content:center;",
    "flex-shrink:0;"
  )
  logo_img_style <- paste0(
    "height:56px;width:56px;object-fit:contain;"
  )
  researcher_logo_el <- NULL
  if (!is.null(researcher_logo_uri) && nzchar(researcher_logo_uri)) {
    researcher_logo_el <- htmltools::tags$div(
      style = logo_container_style,
      htmltools::tags$img(
        src = researcher_logo_uri,
        alt = company_name,
        class = "header-logo",
        style = logo_img_style
      )
    )
  }

  # --- Top row: [logo] Turas Tabs / subtitle  ...  [?] ---
  branding_left <- htmltools::tags$div(
    style = "display:flex;align-items:center;gap:16px;",
    researcher_logo_el,
    htmltools::tags$div(
      htmltools::tags$div(
        style = "color:rgba(255,255,255,0.7);font-size:13px;font-weight:600;line-height:1.2;letter-spacing:0.5px;text-transform:uppercase;",
        "Turas Tabs"
      ),
      htmltools::tags$div(
        style = "color:rgba(255,255,255,0.40);font-size:11px;font-weight:400;margin-top:2px;",
        "Interactive Crosstab Explorer"
      )
    )
  )

  help_btn <- htmltools::tags$button(
    class = "help-btn",
    onclick = "toggleHelpOverlay()",
    title = "Show help guide",
    style = paste0(
      "width:28px;height:28px;border-radius:50%;border:1.5px solid rgba(255,255,255,0.5);",
      "background:transparent;color:rgba(255,255,255,0.8);font-size:14px;font-weight:700;",
      "cursor:pointer;display:flex;align-items:center;justify-content:center;"
    ),
    "?"
  )

  top_row <- htmltools::tags$div(
    style = "display:flex;align-items:center;justify-content:space-between;",
    branding_left,
    help_btn
  )

  # --- Study name ---
  study_row <- htmltools::tags$div(
    class = "header-title",
    style = "color:#ffffff;font-size:26px;font-weight:700;letter-spacing:-0.3px;margin-top:14px;line-height:1.2;",
    project_title
  )

  # --- Prepared by / for ---
  prepared_parts <- c()
  if (!is.null(company_name) && nzchar(company_name)) {
    prepared_parts <- c(prepared_parts, paste0(
      "Prepared by <span style=\"font-weight:600;\">",
      htmltools::htmlEscape(company_name), "</span>"
    ))
  }
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared_parts <- c(prepared_parts, paste0(
      "for <span style=\"font-weight:600;\">",
      htmltools::htmlEscape(client_name), "</span>"
    ))
  }

  prepared_row <- NULL
  if (length(prepared_parts) > 0) {
    prepared_row <- htmltools::tags$div(
      style = "color:rgba(255,255,255,0.65);font-size:13px;font-weight:400;margin-top:4px;line-height:1.3;",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  # --- Stats badge bar ---
  badge_style <- paste0(
    "display:inline-flex;align-items:center;padding:5px 14px;",
    "font-size:12px;font-weight:600;color:rgba(255,255,255,0.85);",
    "font-variant-numeric:tabular-nums;"
  )
  separator_style <- paste0(
    "width:1px;height:16px;background:rgba(255,255,255,0.20);flex-shrink:0;"
  )

  badge_items <- list()

  # n badge

  if (!is.na(total_n)) {
    total_n_display <- round(as.numeric(total_n))
    badge_items <- c(badge_items, list(htmltools::tags$span(
      style = badge_style,
      htmltools::HTML(paste0("n&nbsp;=&nbsp;", format(total_n_display, big.mark = ",")))
    )))
  }

  # Questions badge
  if (!is.na(n_questions)) {
    badge_items <- c(badge_items, list(htmltools::tags$span(
      style = badge_style,
      htmltools::HTML(paste0("<span style=\"color:rgba(255,255,255,1);font-weight:700;\">",
                             n_questions, "</span>&nbsp;Questions"))
    )))
  }

  # Weighted / Unweighted badge
  weight_label <- if (isTRUE(apply_weighting)) "Weighted" else "Unweighted"
  badge_items <- c(badge_items, list(htmltools::tags$span(
    style = badge_style, weight_label
  )))

  # Created date badge (file generation date; JS updates to "Last saved …" on save)
  created_label <- format(Sys.Date(), "Created %b %Y")
  badge_items <- c(badge_items, list(htmltools::tags$span(
    id = "header-date-badge",
    style = badge_style, created_label
  )))

  # Interleave badges with separators
  badge_els <- list()
  for (i in seq_along(badge_items)) {
    if (i > 1) {
      badge_els <- c(badge_els, list(htmltools::tags$span(style = separator_style)))
    }
    badge_els <- c(badge_els, list(badge_items[[i]]))
  }

  stats_bar <- htmltools::tags$div(
    style = paste0(
      "display:inline-flex;align-items:center;margin-top:12px;",
      "border:1px solid rgba(255,255,255,0.15);border-radius:6px;",
      "background:rgba(255,255,255,0.05);"
    ),
    badge_els
  )

  # --- Assemble header ---
  htmltools::tags$div(
    class = "header",
    htmltools::tags$div(
      class = "header-inner",
      style = "display:flex;flex-direction:column;",
      top_row,
      study_row,
      prepared_row,
      stats_bar
    )
  )
}


#' Build Help Overlay
#'
#' Creates a modal overlay with a quick-reference guide to interactive features.
#' Shown on first visit (via localStorage) and toggled via the ? button.
#'
#' @return htmltools::tags$div
#' @keywords internal
build_help_overlay <- function() {
  htmltools::tags$div(
    class = "help-overlay",
    id = "help-overlay",
    onclick = "toggleHelpOverlay()",
    htmltools::tags$div(
      class = "help-card",
      onclick = "event.stopPropagation()",
      htmltools::tags$h2("Quick Guide"),
      htmltools::tags$div(class = "help-subtitle", "Everything you need to know to use this report"),

      # --- Navigating ---
      htmltools::tags$h3("Navigating the Report"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Sidebar"),
          "Browse all questions. Type in the search box to filter."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Banner tabs"),
          "Switch between cross-tabulation groups (e.g. Total, Age, Region)."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Summary"),
          "Dashboard with key metrics, gauges, and significant findings."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Crosstabs"),
          "Full data tables with charts for every question.")
      ),

      # --- Tables ---
      htmltools::tags$h3("Working with Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Column headers"),
          "Click any header to sort the table by that column."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Column chips"),
          "Toggle individual columns on or off to focus the view."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Heatmap"),
          "Tick the Heatmap checkbox to colour-code cells by value."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Show count"),
          "Tick to display raw frequencies alongside percentages.")
      ),

      # --- Charts ---
      htmltools::tags$h3("Charts"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Chart toggle"),
          "Tick the Chart checkbox to show or hide the chart."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Chart chips"),
          "Select which columns appear in the chart to compare groups."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\u2715 on rows"),
          "Hover a data row and click \u2715 to exclude it from the chart.")
      ),

      # --- Insights & Notes ---
      htmltools::tags$h3("Adding Insights"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "+ Add Insight"),
          "Click below any question to add your analysis or commentary."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Summary text"),
          "The Summary tab has editable text areas for Background and Executive Summary.")
      ),

      # --- Pinning ---
      htmltools::tags$h3("Pinning Key Findings"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4CC Pin"),
          "Click the pin icon on any question to save it to your Pinned Views deck."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Pinned Views"),
          "A curated set of your key findings. Reorder with \u25B2\u25BC, remove with \u2715."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Section dividers"),
          "Use 'Add Section' in Pinned Views to organise pins into groups."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Summary pins"),
          "Pin gauge sections or sig findings from the Summary tab too.")
      ),

      # --- Added Slides ---
      htmltools::tags$h3("Added Slides"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Add Slide"),
          "Create narrative slides with formatted text (supports **bold**, *italic*, bullets, headings)."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F5BC Add image"),
          "Upload a chart, screenshot, or diagram to any slide. Images are resized automatically."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4CC Pin slide"),
          "Pin an Added Slide to include it alongside your data findings in Pinned Views.")
      ),

      # --- Exporting ---
      htmltools::tags$h3("Exporting & Sharing"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Save Report"),
          "Downloads the HTML file with all your insights, pins, and edits preserved."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4F7 Export PNG"),
          "Download any chart or pinned card as a high-resolution PNG image."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "\U0001F4CB Copy"),
          "Copy a chart or pin to your clipboard, then paste straight into PowerPoint."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "Print / PDF"),
          "Print your Pinned Views as a paginated document (one finding per page)."),
        htmltools::tags$li(htmltools::tags$span(class = "help-key", "CSV / Excel"),
          "Export table data for any question in spreadsheet format.")
      ),

      # --- Tip ---
      htmltools::tags$div(class = "help-tip",
        htmltools::HTML(paste0(
          "<strong>Tip:</strong> This report is a live working document. ",
          "Add insights, pin key findings, create narrative slides, then <strong>Save</strong> ",
          "to keep everything. Re-open the saved file any time to continue where you left off. ",
          "Press <strong>?</strong> to show this guide again."
        ))
      ),

      htmltools::tags$div(class = "help-dismiss", "Click anywhere to close")
    )
  )
}


#' Build Sidebar with Question Navigator
#'
#' Generates the sidebar with question navigation. If questions have a
#' \code{category} field, groups them under collapsible category headings.
#' Falls back to a flat list when no categories are set.
#'
#' @param questions List of transformed question data
#' @param has_sig Logical
#' @param brand_colour Character
#' @return htmltools::div
build_sidebar <- function(questions, has_sig = FALSE, brand_colour = "#323367") {

  # Check if any questions have categories set
  categories <- vapply(questions, function(q) {
    cat_val <- q$category
    if (is.null(cat_val) || is.na(cat_val) || !nzchar(trimws(cat_val))) "" else trimws(cat_val)
  }, character(1))
  has_categories <- any(nzchar(categories))

  # Build individual question items
  build_q_item <- function(i) {
    q <- questions[[i]]
    q_code <- q$q_code
    q_text <- q$question_text
    if (nchar(q_text) > 80) q_text <- paste0(substr(q_text, 1, 80), "...")
    htmltools::tags$div(
      class = if (i == 1) "question-item active" else "question-item",
      `data-index` = i - 1,
      `data-search` = tolower(paste(q_code, q_text)),
      `data-category` = if (has_categories) categories[i] else NULL,
      onclick = sprintf("selectQuestion(%d)", i - 1),
      htmltools::tags$div(class = "question-item-code", q_code),
      htmltools::tags$div(class = "question-item-text", q_text)
    )
  }

  if (has_categories) {
    # Extract category orders (if provided)
    cat_orders <- vapply(questions, function(q) {
      ord <- q$category_order
      if (is.null(ord) || is.na(ord)) NA_real_ else suppressWarnings(as.numeric(ord))
    }, numeric(1))

    # Group questions by category, using CategoryOrder for sort when available
    seen_cats <- character(0)
    cat_order <- character(0)
    cat_sort_key <- numeric(0)
    for (i in seq_along(questions)) {
      cat <- if (nzchar(categories[i])) categories[i] else "Other"
      if (!cat %in% seen_cats) {
        seen_cats <- c(seen_cats, cat)
        cat_order <- c(cat_order, cat)
        # Use the first CategoryOrder value found for this group
        cat_sort_key <- c(cat_sort_key, if (!is.na(cat_orders[i])) cat_orders[i] else Inf)
      }
    }
    # Sort groups by CategoryOrder (groups without order go to end, preserving original order)
    sort_idx <- order(cat_sort_key, seq_along(cat_order))
    cat_order <- cat_order[sort_idx]

    # Build collapsible groups
    group_elements <- lapply(cat_order, function(cat_name) {
      indices <- which(vapply(seq_along(questions), function(i) {
        this_cat <- if (nzchar(categories[i])) categories[i] else "Other"
        this_cat == cat_name
      }, logical(1)))

      items <- lapply(indices, build_q_item)

      htmltools::tags$div(
        class = "sidebar-category-group",
        `data-category` = cat_name,
        htmltools::tags$div(
          class = "sidebar-category-header",
          onclick = "toggleCategoryGroup(this)",
          htmltools::tags$span(class = "sidebar-category-chevron", "\u25BC"),
          htmltools::tags$span(class = "sidebar-category-name", cat_name),
          htmltools::tags$span(class = "sidebar-category-count",
                               sprintf("(%d)", length(indices)))
        ),
        htmltools::tags$div(class = "sidebar-category-items", items)
      )
    })

    scroll_content <- group_elements
  } else {
    # Flat list (original behaviour — no categories)
    scroll_content <- lapply(seq_along(questions), build_q_item)
  }

  sidebar_content <- list(
    htmltools::tags$input(
      type = "text",
      class = "search-box",
      placeholder = "Search questions...",
      oninput = "filterQuestions(this.value)"
    ),
    htmltools::tags$div(
      class = "question-list",
      htmltools::tags$div(class = "question-list-header",
        sprintf("Questions (%d)", length(questions))),
      htmltools::tags$div(class = "question-list-scroll", scroll_content)
    )
  )

  # Legend
  if (has_sig) {
    sidebar_content <- c(sidebar_content, list(
      htmltools::tags$div(
        class = "legend-box",
        htmltools::tags$div(class = "legend-title", "Legend"),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(class = "sig-badge-legend", "\u25B2AB"),
          htmltools::tags$span("Significantly higher than columns")
        ),
        htmltools::tags$div(class = "legend-item",
          htmltools::tags$span(style = "color:#e8614d;font-weight:700;font-size:11px", "\u26A0 28"),
          htmltools::tags$span("Low base warning (n<30)")
        )
      )
    ))
  }

  htmltools::tags$div(
    class = "sidebar",
    htmltools::tags$div(class = "sidebar-inner", sidebar_content)
  )
}


#' Build Banner Group Tab Buttons
#'
#' @param banner_groups Named list of banner groups
#' @param brand_colour Character
#' @return htmltools::div
build_banner_tabs <- function(banner_groups, brand_colour = "#323367") {
  tabs <- lapply(seq_along(banner_groups), function(i) {
    grp_name <- names(banner_groups)[i]
    grp <- banner_groups[[i]]
    htmltools::tags$button(
      class = if (i == 1) "banner-tab active" else "banner-tab",
      `data-group` = grp$banner_code,
      `data-banner-name` = grp_name,
      onclick = sprintf("switchBannerGroup('%s', this)", js_esc(grp$banner_code)),
      grp_name
    )
  })

  htmltools::tags$div(class = "banner-tabs", tabs)
}


#' Build Toggle Controls
#'
#' @param has_any_freq Logical
#' @param has_any_pct Logical
#' @param has_any_sig Logical
#' @param brand_colour Character
#' @return htmltools::div
build_controls <- function(has_any_freq, has_any_pct, has_any_sig,
                           brand_colour = "#323367", has_charts = FALSE) {
  controls <- list()

  if (has_any_pct) {
    controls <- c(controls, list(
      htmltools::tags$label(class = "toggle-label",
        htmltools::tags$input(type = "checkbox", checked = NA, onchange = "toggleHeatmap(this.checked)"),
        "Heatmap"
      )
    ))
  }

  if (has_any_freq && has_any_pct) {
    controls <- c(controls, list(
      htmltools::tags$label(class = "toggle-label",
        htmltools::tags$input(type = "checkbox", onchange = "toggleFrequency(this.checked)"),
        "Show count"
      )
    ))
  }

  if (has_charts) {
    controls <- c(controls, list(
      htmltools::tags$label(class = "toggle-label",
        htmltools::tags$input(type = "checkbox", onchange = "toggleChart(this.checked)"),
        "Chart"
      )
    ))
  }

  htmltools::tags$div(
    class = "controls-bar",
    htmltools::tags$div(style = "flex:1"),
    controls
  )
}


#' Build Key Insight Area
#'
#' Creates an editable insight callout for a question. Supports multi-banner
#' comments: comment_entries is a list of list(banner, text) objects.
#' The initial text shown is the first matching entry for the active banner,
#' or the first global (banner=NULL) entry. All entries are embedded as JSON
#' for JS to switch on banner change.
#'
#' @param q_code Character, question code
#' @param comment_entries List of list(banner, text), or NULL
#' @param first_banner Character, name of the first active banner group
#' @return htmltools::tags$div
#' @keywords internal
build_insight_area <- function(q_code, comment_entries = NULL,
                               first_banner = "", all_banners = NULL) {
  # Determine initial comment to show for the first (active) banner
  # Helper: check if banner field is "global" (NULL or NA = applies to all banners)
  is_global_banner <- function(b) is.null(b) || (length(b) == 1 && is.na(b))

  initial_text <- NULL
  if (!is.null(comment_entries) && length(comment_entries) > 0) {
    # Try banner-specific first, then global
    for (entry in comment_entries) {
      if (!is_global_banner(entry$banner) && identical(entry$banner, first_banner)) {
        initial_text <- entry$text
        break
      }
    }
    if (is.null(initial_text)) {
      for (entry in comment_entries) {
        if (is_global_banner(entry$banner)) {
          initial_text <- entry$text
          break
        }
      }
    }
  }
  has_comment <- !is.null(initial_text) && nzchar(trimws(initial_text))

  # Embed all comments as JSON for banner switching (config-provided defaults)
  comments_json <- if (!is.null(comment_entries) && length(comment_entries) > 0) {
    as.character(jsonlite::toJSON(comment_entries, auto_unbox = TRUE))
  } else {
    NULL
  }

  # Build the per-banner JSON store from config comment entries
  # Format: { "Banner Name": "text", ... }
  # Global comments (banner = NULL/NA) are stored under ALL banner names
  # so that switching banners always shows the global insight.
  store_obj <- list()
  if (!is.null(comment_entries) && length(comment_entries) > 0) {
    for (entry in comment_entries) {
      if (!is.null(entry$text) && nzchar(trimws(entry$text))) {
        if (is_global_banner(entry$banner)) {
          # Global comment → populate for every banner (first-write-wins to
          # let banner-specific entries take precedence if defined later)
          banner_keys <- if (!is.null(all_banners) && length(all_banners) > 0) {
            all_banners
          } else {
            first_banner
          }
          for (bk in banner_keys) {
            if (nzchar(bk) && is.null(store_obj[[bk]])) {
              store_obj[[bk]] <- entry$text
            }
          }
        } else {
          # Banner-specific comment → always overwrites (takes precedence)
          if (nzchar(entry$banner)) {
            store_obj[[entry$banner]] <- entry$text
          }
        }
      }
    }
  }
  store_json <- if (length(store_obj) > 0) {
    as.character(jsonlite::toJSON(store_obj, auto_unbox = TRUE))
  } else {
    ""
  }

  htmltools::tags$div(
    class = "insight-area",
    `data-q-code` = q_code,
    if (!is.null(comments_json)) htmltools::tagList(
      htmltools::tags$script(
        type = "application/json",
        class = "insight-comments-data",
        htmltools::HTML(comments_json)
      )
    ),
    # Toggle button (hidden when comment is pre-filled)
    htmltools::tags$button(
      class = "insight-toggle",
      style = if (has_comment) "display:none;" else NULL,
      onclick = sprintf("toggleInsight('%s')", js_esc(q_code)),
      if (has_comment) "Edit Insight" else "+ Add Insight"
    ),
    # Insight container with markdown editor/renderer (like qual slides)
    htmltools::tags$div(
      class = "insight-container",
      style = if (!has_comment) "display:none;" else NULL,
      # Textarea for editing raw markdown (hidden unless .editing)
      htmltools::tags$textarea(
        class = "insight-md-editor",
        `data-q-code` = q_code,
        placeholder = "Type key insight here\u2026 (supports **bold**, *italic*, - bullets, ## headings)",
        if (has_comment) initial_text
      ),
      # Rendered markdown display (visible unless .editing)
      htmltools::tags$div(
        class = "insight-md-rendered",
        `data-q-code` = q_code,
        ondblclick = sprintf("toggleInsightEdit('%s')", js_esc(q_code))
      ),
      htmltools::tags$button(
        class = "insight-dismiss",
        title = "Delete insight",
        onclick = sprintf("dismissInsight('%s')", js_esc(q_code)),
        "\u00D7"
      )
    ),
    # Hidden textarea persists per-banner insights as JSON: { "banner": "text", ... }
    htmltools::tags$textarea(
      class = "insight-store",
      `data-q-code` = q_code,
      style = "display:none;",
      store_json
    )
  )
}


#' Build Question Containers
#'
#' Creates a container div for each question holding its title and table.
#'
#' @param questions List of transformed question data
#' @param tables Named list of htmltools::HTML table objects
#' @param banner_groups Named list of banner groups
#' @param config_obj Configuration
#' @return htmltools::tagList
build_question_containers <- function(questions, tables, banner_groups,
                                      config_obj, charts = list()) {

  first_group_name <- if (length(banner_groups) > 0) names(banner_groups)[1] else ""

  comments <- config_obj$comments  # Named list or NULL

  containers <- lapply(seq_along(questions), function(i) {
    q <- questions[[i]]
    q_code <- q$q_code
    q_text <- q$question_text
    stat_label <- q$primary_stat

    # Build chart div (hidden by default, toggled via JS)
    # charts[[q_code]] is a list with $svg and $chart_data, or NULL
    chart_div <- NULL
    chart_result <- charts[[q_code]]
    has_chart <- !is.null(chart_result) &&
                 !is.null(chart_result$chart_data) &&
                 !is.null(chart_result$svg)
    if (has_chart) {
      # Embed chart data as JSON for JS-driven multi-column rendering
      chart_json <- jsonlite::toJSON(chart_result$chart_data,
                                      auto_unbox = TRUE, digits = 4)
      chart_div <- htmltools::tags$div(
        class = "chart-wrapper",
        style = "display:none;",
        `data-q-code` = q_code,
        `data-q-title` = q_text,
        `data-chart-data` = as.character(chart_json),
        chart_result$svg
      )
    }

    # Build insight area (pre-filled from config if available)
    comment_entries <- if (!is.null(comments)) comments[[q_code]] else NULL
    insight_div <- build_insight_area(q_code, comment_entries,
                                      first_banner = first_group_name,
                                      all_banners = names(banner_groups))

    htmltools::tags$div(
      class = if (i == 1) "question-container active" else "question-container",
      id = paste0("q-container-", i - 1),
      htmltools::tags$div(
        class = "question-title-card",
        htmltools::tags$div(class = "question-title-row",
          style = "display:flex;align-items:center;",
          htmltools::tags$span(class = "question-code", q_code),
          htmltools::tags$span(class = "question-text", style = "flex:1;", q_text),
          htmltools::tags$button(
            class = "pin-btn",
            `data-q-code` = q_code,
            onclick = sprintf("togglePin('%s')", js_esc(q_code)),
            title = "Pin this view",
            style = paste0(
              "background:none;border:1px solid #e2e8f0;border-radius:4px;cursor:pointer;",
              "font-size:14px;padding:3px 8px;margin-left:8px;color:#94a3b8;transition:all 0.15s;"
            ),
            "\U0001F4CC"
          )
        ),
        htmltools::tags$div(class = "question-meta",
          htmltools::HTML(sprintf("Banner: <strong class=\"banner-name-label\">%s</strong> &middot; Showing %s",
                                  htmltools::htmlEscape(first_group_name), htmltools::htmlEscape(stat_label %||% "")))
        ),
        if (!is.na(q$base_filter) && nchar(q$base_filter %||% "") > 0) {
          htmltools::tags$div(
            style = "margin-top:4px;font-size:11px;color:#e8614d;font-weight:600",
            sprintf("Filter: %s", q$base_filter)
          )
        }
      ),
      htmltools::tags$div(class = "table-wrapper",
        tables[[q_code]]
      ),
      chart_div,
      insight_div,
      htmltools::tags$div(class = "table-actions",
        htmltools::tags$button(
          class = "export-btn",
          onclick = sprintf("exportExcel('%s')", js_esc(q_code)),
          "\u2B73 Export Excel"
        ),
        htmltools::tags$button(
          class = "export-btn",
          style = "margin-left:8px",
          onclick = sprintf("exportCSV('%s')", js_esc(q_code)),
          "\u2B73 Export CSV"
        ),
        if (has_chart) {
          htmltools::tags$button(
            class = "export-btn export-chart-btn",
            style = "margin-left:8px;display:none",
            onclick = sprintf("exportChartPNG('%s')", js_esc(q_code)),
            "\U0001F4CA Export Chart"
          )
        },
        if (has_chart) {
          htmltools::tags$div(
            class = "slide-export-group",
            style = "display:none;position:relative;margin-left:8px;",
            htmltools::tags$button(
              class = "export-btn export-slide-btn",
              onclick = sprintf("toggleSlideMenu('%s')", js_esc(q_code)),
              "\U0001F4C4 Export Slide \u25BE"
            ),
            htmltools::tags$div(
              class = "slide-menu",
              id = sprintf("slide-menu-%s", gsub("[^a-zA-Z0-9]", "-", q_code)),
              style = "display:none;position:absolute;top:100%;right:0;background:#fff;border:1px solid #e2e8f0;border-radius:6px;box-shadow:0 4px 12px rgba(0,0,0,0.1);z-index:100;min-width:160px;padding:4px 0;",
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','chart_table')", js_esc(q_code)),
                "Chart + Table"
              ),
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','chart')", js_esc(q_code)),
                "Chart Only"
              ),
              htmltools::tags$button(
                class = "slide-menu-item",
                style = "display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;cursor:pointer;font-size:12px;font-family:inherit;",
                onclick = sprintf("exportSlidePNG('%s','table')", js_esc(q_code)),
                "Table Only"
              )
            )
          )
        }
      )
    )
  })

  htmltools::tagList(containers)
}


# ==============================================================================
# COMPONENT: QUALITATIVE SLIDES (V10.7.0)
# ==============================================================================

#' Build Qualitative Panel
#'
#' Creates a tab panel for qualitative/open-ended content slides.
#' Slides can be seeded from the config Excel and also added/edited in the browser.
#'
#' @param slides List of slide objects from load_qualitative_sheet(), or NULL
#' @param brand_colour Character hex colour
#' @return htmltools::tags$div
#' @keywords internal
build_qualitative_panel <- function(slides = NULL, brand_colour = "#323367") {
  # Render initial slides from config (if any)
  slide_cards <- if (!is.null(slides) && length(slides) > 0) {
    lapply(slides, function(s) {
      build_qual_slide_card(s$id, s$title, s$content, s$image_data)
    })
  }

  htmltools::tags$div(
    id = "tab-qualitative",
    class = "tab-panel",
    htmltools::tags$div(
      class = "qual-container",
      style = "max-width:1400px;margin:0 auto;padding:20px 32px;",
      htmltools::tags$div(
        class = "qual-header",
        style = "display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;",
        htmltools::tags$div(
          htmltools::tags$h2(style = "font-size:18px;font-weight:700;color:#1e293b;margin-bottom:4px;",
                             "Added Slides"),
          htmltools::tags$p(style = "font-size:12px;color:#64748b;",
                            "Open-ended findings, quotes, and narrative content. Double-click to edit, use markdown for formatting.")
        ),
        htmltools::tags$div(
          style = "display:flex;gap:8px;",
          htmltools::tags$button(class = "export-btn", onclick = "addQualSlide()",
                                 "\u2795 Add Slide")
        )
      ),
      htmltools::tags$div(
        class = "qual-md-help",
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
      htmltools::tags$div(id = "qual-slides-container", slide_cards),
      htmltools::tags$div(
        id = "qual-empty-state",
        style = paste0(
          if (!is.null(slides) && length(slides) > 0) "display:none;" else "",
          "text-align:center;padding:60px 20px;color:#94a3b8;"
        ),
        htmltools::tags$div(style = "font-size:36px;margin-bottom:12px;", "\U0001F4DD"),
        htmltools::tags$div(style = "font-size:14px;font-weight:600;", "No slides yet"),
        htmltools::tags$div(style = "font-size:12px;margin-top:4px;",
          "Click 'Add Slide' to create narrative content, or add a 'Qualitative' sheet to your config Excel.")
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
#' @return htmltools::tags$div
#' @keywords internal
build_qual_slide_card <- function(slide_id, title, content_md, image_data = NULL) {
  htmltools::tags$div(
    class = "qual-slide-card",
    `data-slide-id` = slide_id,
    htmltools::tags$div(
      class = "qual-slide-header",
      htmltools::tags$div(
        class = "qual-slide-title",
        contenteditable = "true",
        title
      ),
      htmltools::tags$div(
        class = "qual-slide-actions",
        htmltools::tags$button(class = "export-btn", title = "Add image",
                               onclick = sprintf("triggerQualImage('%s')", slide_id),
                               htmltools::HTML("&#x1F5BC;")),
        htmltools::tags$button(class = "export-btn", title = "Pin this slide",
                               onclick = sprintf("pinQualSlide('%s')", slide_id),
                               htmltools::HTML("&#x1F4CC;")),
        htmltools::tags$button(class = "export-btn", title = "Move up",
                               onclick = sprintf("moveQualSlide('%s','up')", slide_id),
                               htmltools::HTML("&#x25B2;")),
        htmltools::tags$button(class = "export-btn", title = "Move down",
                               onclick = sprintf("moveQualSlide('%s','down')", slide_id),
                               htmltools::HTML("&#x25BC;")),
        htmltools::tags$button(class = "export-btn", title = "Remove slide",
                               style = "color:#e8614d;",
                               onclick = sprintf("removeQualSlide('%s')", slide_id),
                               htmltools::HTML("&#x2715;"))
      )
    ),
    # Image preview (shown if image_data provided, hidden otherwise)
    htmltools::tags$div(class = "qual-img-preview",
      style = if (is.null(image_data) || !nzchar(image_data %||% "")) "display:none;" else "",
      htmltools::tags$img(class = "qual-img-thumb",
        src = if (!is.null(image_data) && nzchar(image_data %||% "")) image_data else ""),
      htmltools::tags$button(class = "qual-img-remove",
                             onclick = sprintf("removeQualImage('%s')", slide_id),
                             title = "Remove image",
                             htmltools::HTML("&times;"))
    ),
    # Hidden file input for image upload
    htmltools::tags$input(type = "file", class = "qual-img-input",
                          accept = "image/*", style = "display:none;",
                          onchange = sprintf("handleQualImage('%s', this)", slide_id)),
    # Markdown editor (shown when editing)
    htmltools::tags$textarea(
      class = "qual-md-editor",
      rows = "6",
      placeholder = "Enter markdown content... (**bold**, *italic*, > quote, - bullet, ## heading)",
      content_md
    ),
    # Rendered output (shown when not editing)
    htmltools::tags$div(class = "qual-md-rendered"),
    # Hidden stores for save persistence
    htmltools::tags$textarea(class = "qual-md-store", style = "display:none;", content_md),
    htmltools::tags$textarea(class = "qual-img-store", style = "display:none;",
      if (!is.null(image_data) && nzchar(image_data %||% "")) image_data else "")
  )
}


#' Build Footer
#'
#' @param config_obj Configuration
#' @param min_base Numeric
#' @return htmltools::div
build_footer <- function(config_obj, min_base = 30) {
  parts <- c()
  if (isTRUE(config_obj$enable_significance_testing)) {
    parts <- c(parts, "Significance testing: Column proportions z-test")
    if (isTRUE(config_obj$bonferroni_correction)) {
      parts <- c(parts, "with Bonferroni correction")
    }
    alpha <- config_obj$alpha %||% 0.05
    parts <- c(parts, sprintf("p<%.2f", alpha))
  }
  parts <- c(parts, sprintf("Minimum base n=%d", min_base))
  parts <- c(parts, "Generated by Turas Analytics")

  htmltools::tags$div(class = "footer", paste(parts, collapse = " \u00B7 "))
}


# ==============================================================================
# COMPONENT: CLOSING SECTION (V10.7.0)
# ==============================================================================

#' Build Closing Section
#'
#' Professional footer section with analyst contact details, verbatim file
#' reference, and editable closing notes. Only renders if at least one field
#' has content.
#'
#' @param config_obj Configuration object
#' @return htmltools::tags$div or NULL
#' @keywords internal
build_closing_section <- function(config_obj) {
  analyst_name     <- config_obj$analyst_name
  analyst_email    <- config_obj$analyst_email
  analyst_phone    <- config_obj$analyst_phone
  verbatim_file    <- config_obj$verbatim_filename
  closing_notes    <- config_obj$closing_notes

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

  # Closing notes (editable in HTML)
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
}


#' Build Export Actions Section
#'
#' Creates Save Report and Print Report buttons for the About tab.
#' Print includes Summary dashboard, all Crosstabs questions, and Added Slides.
#'
#' @return htmltools::tags$div
#' @keywords internal
build_export_actions <- function() {
  htmltools::tags$div(
    class = "closing-section",
    style = "margin-bottom:24px;",
    htmltools::tags$div(class = "closing-divider"),
    htmltools::tags$div(
      class = "closing-content",
      htmltools::tags$div(
        class = "closing-label",
        style = "margin-bottom:12px;",
        "Export"
      ),
      htmltools::tags$div(
        style = "display:flex;gap:10px;flex-wrap:wrap;",
        htmltools::tags$button(
          class = "export-btn",
          onclick = "saveReportHTML()",
          style = "font-size:13px;padding:8px 18px;",
          "\U0001F4BE Save Report"
        ),
        htmltools::tags$button(
          class = "export-btn",
          onclick = "printReport()",
          style = "font-size:13px;padding:8px 18px;",
          "\U0001F5A8 Print Report"
        )
      ),
      htmltools::tags$p(
        style = "font-size:11px;color:#94a3b8;margin-top:8px;line-height:1.5;",
        "Save embeds all edits (insights, notes, slides) into the HTML file. ",
        "Print outputs Summary, Crosstabs, and Added Slides to PDF."
      )
    )
  )
}


#' Wrap Closing Section as an About Tab Panel
#'
#' Always renders — contains export actions (Save/Print) even when no
#' analyst contact info is configured.
#'
#' @param config_obj Configuration object
#' @return htmltools::tags$div (tab-panel)
#' @keywords internal
build_about_panel <- function(config_obj) {
  closing <- build_closing_section(config_obj)
  export  <- build_export_actions()
  htmltools::tags$div(
    id = "tab-about",
    class = "tab-panel",
    closing,
    export
  )
}
