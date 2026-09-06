# ==============================================================================
# BRAND HTML REPORT - PAGE BUILDER
# ==============================================================================
# SIZE-EXCEPTION: final HTML assembly seam. The tab-bar navigation,
# all inline CSS, all inline JS sourcing, and the per-category page
# assembly all hang off the single build_brand_report_html() entry.
# Splitting would require duplicating the head/body scaffold across
# multiple files with no readability gain.
#
# Assembles the complete HTML document from tables, charts, and data.
# Layer 4 of the 4-layer pipeline.
# ==============================================================================

# Source design system if not loaded
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root) && exists("find_turas_root", mode = "function")) {
    turas_root <- find_turas_root()
  }
  if (!nzchar(turas_root)) turas_root <- getwd()

  ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
  if (!dir.exists(ds_dir)) ds_dir <- file.path("modules", "shared", "lib", "design_system")
  if (!exists("turas_base_css", mode = "function") && dir.exists(ds_dir)) {
    for (f in c("design_tokens.R", "font_embed.R", "base_css.R")) {
      fp <- file.path(ds_dir, f)
      if (file.exists(fp)) source(fp, local = FALSE)
    }
  }

  pins_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!exists("turas_pins_js", mode = "function") && file.exists(pins_path)) {
    source(pins_path, local = FALSE)
  }
})

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

.br_esc <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


#' Quote a value as a JavaScript string literal for an inline <script>
#'
#' HTML escaping is the wrong tool inside a script element: the parser does
#' not decode entities there, so an escaped quote would reach the JS engine
#' as the entity text. This emits a real JSON string literal instead, then
#' writes every "<" as the \\u003c escape so no "</script" can form and end
#' the element early. Same discipline as \code{.br_json_island()}.
#'
#' @param x Character scalar, or NULL.
#' @return Character. A quoted JS string literal, including its quotes.
#' @keywords internal
.br_js_str <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x[1L])) return('""')
  lit <- as.character(jsonlite::toJSON(as.character(x[1L]), auto_unbox = TRUE))
  gsub("<", "\\u003c", lit, fixed = TRUE)
}


#' Reduce a config colour to something safe to drop into CSS
#'
#' \code{colour_focal} is operator-supplied and never validated by the config
#' loader, so it reaches inline style attributes as typed. Anything that is
#' not a recognisable colour token falls back to the default rather than
#' being pasted into a declaration.
#'
#' @param x Character scalar, or NULL.
#' @param default Character. Fallback colour.
#' @return Character. A colour token.
#' @keywords internal
.br_colour <- function(x, default = "#1A5276") {
  if (is.null(x) || length(x) == 0L || is.na(x[1L])) return(default)
  v <- trimws(as.character(x[1L]))
  ok <- grepl("^#[0-9A-Fa-f]{3,8}$", v) ||
    grepl("^(rgb|rgba|hsl|hsla)\\([0-9.,%\\s/-]+\\)$", v, perl = TRUE) ||
    grepl("^[A-Za-z]+$", v)
  if (ok) v else default
}


# ==============================================================================
# COMPONENT BUILDERS
# ==============================================================================

#' Build branded header
#' @keywords internal
build_br_header <- function(config) {
  brand <- config$colour_focal %||% "#1A5276"
  sprintf('
<div class="br-header" style="background:#1a2744;color:#fff;padding:20px 32px;border-radius:0 0 12px 12px;" data-report-title="%s">
  <div style="display:flex;justify-content:space-between;align-items:flex-start;">
    <div>
      <div style="font-size:11px;text-transform:uppercase;letter-spacing:1.5px;opacity:0.7;margin-bottom:4px;">Turas Brand Health</div>
      <h1 id="br-header-title" style="margin:0;font-size:22px;font-weight:700;color:#fff;">%s</h1>
      <div style="font-size:13px;opacity:0.8;margin-top:2px;color:#fff;">%s</div>
    </div>
    <div style="display:flex;gap:8px;">
      <button class="br-save-btn" onclick="_brSaveReport()" title="Save Report"
        style="background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.3);color:#fff;border-radius:6px;padding:8px 14px;cursor:pointer;font-size:12px;font-weight:500;">
        Save Report
      </button>
      <button class="br-help-btn" onclick="_brToggleHelp()" title="Help"
        style="background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.3);color:#fff;border-radius:50%%;width:34px;height:34px;cursor:pointer;font-size:14px;font-weight:700;">
        ?
      </button>
    </div>
  </div>
  <div class="br-badge-bar" style="display:flex;gap:16px;margin-top:12px;font-size:11px;opacity:0.7;">
    <span>Client: %s</span>
    <span style="opacity:0.4;">|</span>
    <span>Focal Brand: %s</span>
    <span style="opacity:0.4;">|</span>
    <span>Wave %s</span>
    <span style="opacity:0.4;">|</span>
    <span>%s</span>
  </div>
</div>',
    .br_esc(config$report_title %||% "Brand Health Report"),
    .br_esc(config$report_title %||% "Brand Health Report"),
    .br_esc(config$report_subtitle %||% ""),
    .br_esc(config$client_name %||% ""),
    .br_esc(config$focal_brand %||% ""),
    config$wave %||% 1,
    format(Sys.Date(), "%B %Y"))
}


#' Build tab navigation
#' @keywords internal
build_br_tab_nav <- function(category_names, config, display_map = NULL,
                              code_map = NULL) {
  # Tab order:
  #   Portfolio (when enabled): cross-cat lens comes first so the reader
  #     opens on the brand's whole-portfolio picture before drilling in.
  #   Summary: per-cat snapshot for any picked category.
  #   Per-category tabs: order driven by the Categories sheet in
  #     Brand_Config.xlsx; reorder rows there to change tab order.
  #   Brand Assets (when enabled).
  #   Pinned Views, About, always trailing.
  btns <- character(0)

  if (isTRUE(config$element_portfolio))
    btns <- c(btns, '<button class="br-tab-btn" data-tab="portfolio" onclick="switchBrandTab(\'portfolio\')">Portfolio</button>')

  btns <- c(btns, '<button class="br-tab-btn active" data-tab="summary" onclick="switchBrandTab(\'summary\')">Summary</button>')

  for (cat_name in category_names) {
    display_name <- if (!is.null(display_map) && cat_name %in% names(display_map))
      display_map[[cat_name]] else cat_name
    id_src  <- if (!is.null(code_map) && cat_name %in% names(code_map))
      code_map[[cat_name]] else cat_name
    cat_id <- gsub("[^a-z0-9]", "-", tolower(id_src))
    btns <- c(btns, sprintf(
      '<button class="br-tab-btn" data-tab="cat-%s" onclick="switchBrandTab(\'cat-%s\')">%s</button>',
      cat_id, cat_id, .br_esc(display_name)))
  }

  if (isTRUE(config$element_dba))
    btns <- c(btns, '<button class="br-tab-btn" data-tab="dba" onclick="switchBrandTab(\'dba\')">Brand Assets</button>')
  # WOM is per-category (each category sub-tab). No top-level WOM tab.
  # Demographics + Ad Hoc are per-category sub-tabs (inside each category
  # panel), not top-level tabs.

  btns <- c(btns, sprintf(
    '<button class="br-tab-btn" data-tab="pinned" onclick="switchBrandTab(\'pinned\')">Pinned Views <span class="br-pin-badge" id="br-pin-count-badge">0</span></button>'))
  btns <- c(btns, '<button class="br-tab-btn" data-tab="about" onclick="switchBrandTab(\'about\')">About</button>')

  sprintf('<div class="br-tab-nav">%s</div>', paste(btns, collapse = "\n"))
}


#' Build section toolbar (pin + PNG export + Excel export + insight)
#'
#' @param section_id   Anchor ID for this section (drives pin / insight wiring).
#' @param prefill_text Optional character. When non-empty, the insight container
#'   is rendered visible by default with the text pre-populated in both the
#'   raw textarea and the rendered display div. This is the seam that lets
#'   the Section_Insights config sheet survive report re-runs.
#' @param internal_tab Optional character. When this toolbar belongs to a
#'   specific internal sub-tab inside a multi-tab panel (Funnel or Mental
#'   Availability), tag it with the data-internal-tab attribute. The JS
#'   sub-tab switcher (brand_report.js::switchCategorySubtab) hides every
#'   toolbar except the one whose internal_tab matches the active sub-tab.
#' @param initial_visible Logical. When emitting multiple toolbars per
#'   sub-panel, only the first should be visible at render time; later
#'   ones are hidden until the matching sub-tab becomes active.
#' @param omit_chart_buttons Logical. When TRUE, only the "Add / Edit
#'   Insight" toggle + insight container are emitted, the pin / PNG /
#'   Excel buttons are skipped. Used for Funnel and Mental Availability
#'   sub-tab toolbars where the panel already renders its own pin /
#'   PNG / Excel controls and a duplicate would clutter the UI.
#'
#' @keywords internal
build_br_section_toolbar <- function(section_id, prefill_text = NULL,
                                      internal_tab = NULL,
                                      initial_visible = TRUE,
                                      omit_chart_buttons = FALSE) {
  has_text <- !is.null(prefill_text) && !is.na(prefill_text) &&
              nzchar(trimws(as.character(prefill_text)))
  prefill_text <- if (has_text) as.character(prefill_text) else ""

  # When pre-filled, the container is open by default and the rendered view
  # is shown (textarea hidden) so the analyst sees the insight as published.
  # Double-click the rendered view to edit (matches existing UX).
  #
  # width:100%; max-width:none; grid-column:1/-1 force the container to span
  # the full available row width regardless of whether the parent panel
  # uses grid, flex, or a constrained column layout. Without these the
  # textarea was being squeezed into ~250px on the Funnel + MA panels.
  #
  # USE SINGLE % HERE. These strings are substituted into the sprintf
  # format below via %s, which does NOT reduce %% → %. A leftover %% in
  # the rendered CSS is invalid and the browser silently drops the rule,
  # the v1.1 narrow-textarea regression. See memory:r-sprintf-css-gotchas.
  base_container <- "margin-bottom:16px;position:relative;width:100%;max-width:none;box-sizing:border-box;grid-column:1 / -1;"
  container_style <- if (has_text) {
    paste0("display:block;", base_container)
  } else {
    paste0("display:none;", base_container)
  }
  base_textarea <- "width:100%;min-width:0;min-height:140px;border:1px solid #e2e8f0;border-radius:6px;padding:12px;font-family:inherit;font-size:13px;line-height:1.55;resize:vertical;box-sizing:border-box;"
  textarea_style <- if (has_text) {
    paste0(base_textarea, "display:none;")
  } else {
    base_textarea
  }
  base_rendered <- "padding:12px 14px;border:1px solid #e2e8f0;border-radius:6px;min-height:48px;cursor:pointer;font-size:13px;line-height:1.55;box-sizing:border-box;"
  rendered_style <- if (has_text) {
    paste0("display:block;background:#f8fafc;", base_rendered)
  } else {
    paste0("display:none;", base_rendered)
  }
  toggle_label <- if (has_text) "Edit Insight" else "+ Add Insight"
  # When pre-filled the container is open by default and the rendered view
  # is showing; the toggle button switches between rendered and edit modes.
  # When empty the toggle hides/shows the whole container.
  toggle_handler <- if (has_text) "_brToggleInsightEdit" else "_brToggleInsight"

  # Pre-render the markdown server-side for the rendered view. Conservative:
  # bold/italic and basic line breaks. Full markdown is handled client-side
  # by the existing JS editor when the analyst opens the textarea.
  rendered_html <- if (has_text) .br_render_insight_md(prefill_text) else ""

  # Optional per-sub-tab wrapper. When this toolbar belongs to a specific
  # internal sub-tab inside a multi-tab panel (Funnel or Mental Avail), we
  # wrap it in a div with data-insight-internal-tab + display state, so the
  # sub-tab switcher in brand_report.js can show one at a time.
  wrapper_open <- ""
  wrapper_close <- ""
  if (!is.null(internal_tab) && nzchar(internal_tab)) {
    wrapper_style <- if (isTRUE(initial_visible))
      "display:block;" else "display:none;"
    wrapper_open <- sprintf(
      '<div class="br-insight-wrap" data-insight-internal-tab="%s" style="%s">',
      .br_esc(internal_tab), wrapper_style)
    wrapper_close <- "</div>"
  }

  # Two toolbar layouts:
  #   * Full toolbar (omit_chart_buttons=FALSE): pin / PNG / Excel /
  #     Add Insight. Used by WOM, Demographics, Adhoc, Branded Reach,
  #     Audience Lens, Cat-Buying fallback, and Portfolio sub-tabs.
  #   * Insight-only toolbar (omit_chart_buttons=TRUE): just the Add /
  #     Edit Insight button. Used by Funnel and MA sub-tabs where the
  #     panel itself renders its own pin / PNG / Excel controls; the
  #     duplicate cluttered the UI and the bottom pin (panel's own)
  #     handles chart + table capture. The panel pin dropdowns
  #     ("Insights" item) read .br-insight-editor from the parent
  #     section so the Section_Insights text still pins correctly.
  toolbar_html <- if (isTRUE(omit_chart_buttons)) {
    sprintf('
<div class="br-section-toolbar" style="display:flex;gap:8px;margin-bottom:12px;">
  <button class="br-insight-toggle" onclick="%s(\'%s\')"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    %s
  </button>
</div>',
      toggle_handler, section_id, toggle_label)
  } else {
    sprintf('
<div class="br-section-toolbar" style="display:flex;gap:8px;margin-bottom:12px;">
  <button class="br-pin-btn" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin to Views"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:15px;padding:5px 10px;color:#94a3b8;transition:all 0.15s;">
    &#x1F4CC;
  </button>
  <button class="br-png-btn" onclick="brExportPng(\'%s\',this)" title="Export PNG"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    &#x1F5BC; PNG
  </button>
  <button class="br-export-btn" onclick="_brExportPanel(\'%s\')" title="Export Excel"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    &#x1F4E5; Excel
  </button>
  <button class="br-insight-toggle" onclick="%s(\'%s\')"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    %s
  </button>
</div>',
      section_id, section_id, section_id, section_id,
      toggle_handler, section_id, toggle_label)
  }

  container_html <- sprintf('
<div class="br-insight-container" data-section="%s" data-prefilled="%s" style="%s">
  <textarea class="br-insight-editor" data-section="%s" placeholder="Type key insight here..."
    style="%s">%s</textarea>
  <div class="br-insight-rendered" data-section="%s" ondblclick="_brToggleInsightEdit(\'%s\')"
    style="%s">%s</div>
  <button class="br-insight-dismiss" onclick="_brDismissInsight(\'%s\')"
    style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:16px;position:absolute;top:4px;right:8px;">&times;</button>
</div>',
    section_id, if (has_text) "true" else "false", container_style,
    section_id, textarea_style, .br_esc(prefill_text),
    section_id, section_id, rendered_style, rendered_html,
    section_id)

  paste0(wrapper_open, toolbar_html, container_html, wrapper_close)
}


#' Render markdown to safe HTML for the insight rendered view
#'
#' Conservative subset: **bold**, *italic*, `code`, line breaks, and bullets
#' (lines starting with "- "). Full editing experience still uses the
#' client-side JS editor. Escapes HTML before applying markdown so analyst
#' text can never inject markup.
#'
#' @keywords internal
.br_render_insight_md <- function(txt) {
  if (is.null(txt) || !nzchar(txt)) return("")
  s <- .br_esc(txt)
  # Bold: **text**
  s <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", s, perl = TRUE)
  # Italic: *text* (after bold so leftover singles don't capture pairs)
  s <- gsub("(?<![*])\\*([^*]+)\\*(?![*])", "<em>\\1</em>", s, perl = TRUE)
  # Inline code: `text`
  s <- gsub("`([^`]+)`", "<code>\\1</code>", s, perl = TRUE)
  # Bullets: lines starting with "- ". Builds <ul><li>...</li></ul> blocks
  # that survive the line-break pass intact. Plain text lines are joined by
  # <br> for readability inside the rendered insight box.
  lines <- strsplit(s, "\n", fixed = TRUE)[[1]]
  out_blocks <- character(0)   # joined as-is, no <br> between
  buf <- character(0)          # accumulating plain lines for current block
  in_ul <- FALSE
  ul_items <- character(0)
  flush_text <- function() {
    if (length(buf) > 0L) {
      out_blocks <<- c(out_blocks, paste(buf, collapse = "<br>"))
      buf <<- character(0)
    }
  }
  flush_ul <- function() {
    if (in_ul) {
      out_blocks <<- c(out_blocks,
                       paste0("<ul>", paste(ul_items, collapse = ""), "</ul>"))
      ul_items <<- character(0)
      in_ul <<- FALSE
    }
  }
  for (ln in lines) {
    if (grepl("^- ", ln)) {
      flush_text()
      in_ul <- TRUE
      ul_items <- c(ul_items, sprintf("<li>%s</li>", sub("^- ", "", ln)))
    } else {
      flush_ul()
      buf <- c(buf, ln)
    }
  }
  flush_ul()
  flush_text()
  paste(out_blocks, collapse = "")
}


#' Wrap content in a chart container with pin button
#' @keywords internal
build_br_chart_wrapper <- function(chart_svg, chart_title = "") {
  if (is.null(chart_svg) || !nzchar(chart_svg)) return("")
  sprintf('
<div class="br-chart-wrapper" style="position:relative;margin:16px 0;">
  <button class="br-chart-pin-btn" onclick="brPinChart(this,\'%s\')"
    style="position:absolute;top:4px;right:4px;background:rgba(255,255,255,0.9);border:1px solid #e2e8f0;border-radius:4px;cursor:pointer;font-size:14px;padding:3px 6px;opacity:0;transition:opacity 0.15s;z-index:5;">
    &#x1F4CC;
  </button>
  <div class="br-chart-container">%s</div>
</div>', .br_esc(chart_title), chart_svg)
}


#' Build the summary dashboard panel
#' @keywords internal
build_br_summary_panel <- function(results, config) {
  focal <- config$focal_brand %||% ""
  parts <- character(0)
  parts <- c(parts, '<div class="br-panel active" id="panel-summary"><div class="br-section">')
  parts <- c(parts, '<h2 style="font-size:20px;color:#1e293b;margin:0 0 20px;">Executive Summary</h2>')

  # Per-category headline cards. Wrapped in a .br-element-section so the
  # standard pin/PNG toolbar (brTogglePin / brExportPng) can target it.
  # The grid carries data-pin-as-table so captureFromRoot grabs the cards
  # HTML (no <table> exists on this panel).
  section_id <- "summary-cards"
  parts <- c(parts, sprintf(
    '<div class="br-element-section" id="section-%s" data-section="%s">',
    section_id, section_id))
  parts <- c(parts, build_br_section_toolbar(
    section_id,
    prefill_text = section_insight_for(config$section_insights, section_id)))

  cats <- results$results$categories
  if (!is.null(cats)) {
    parts <- c(parts, '<div class="br-summary-grid" data-pin-as-table style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;">')
    for (cat_name in names(cats)) {
      cr <- cats[[cat_name]]
      ma <- cr$mental_availability
      funnel <- cr$funnel

      mms_val <- if (!is.null(ma) && !is.null(ma$metrics_summary$focal_mms)) {
        sprintf("%.1f%%", ma$metrics_summary$focal_mms * 100)
      } else "\u2013"
      mpen_val <- if (!is.null(ma) && !is.null(ma$metrics_summary$focal_mpen)) {
        sprintf("%.0f%%", ma$metrics_summary$focal_mpen * 100)
      } else "\u2013"
      aware_val <- if (!is.null(funnel) &&
                        !is.null(funnel$metrics_summary$focal_by_stage$aware)) {
        sprintf("%.0f%%", 100 * funnel$metrics_summary$focal_by_stage$aware)
      } else "\u2013"

      parts <- c(parts, sprintf('
<div class="br-cat-card" style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:16px;">
  <div style="font-size:13px;font-weight:600;color:#64748b;margin-bottom:12px;">%s</div>
  <div style="display:flex;gap:16px;">
    <div style="text-align:center;flex:1;">
      <div style="font-size:22px;font-weight:700;color:%s;">%s</div>
      <div style="font-size:10px;color:#94a3b8;">MMS</div>
    </div>
    <div style="text-align:center;flex:1;">
      <div style="font-size:22px;font-weight:700;color:%s;">%s</div>
      <div style="font-size:10px;color:#94a3b8;">MPen</div>
    </div>
    <div style="text-align:center;flex:1;">
      <div style="font-size:22px;font-weight:700;color:%s;">%s</div>
      <div style="font-size:10px;color:#94a3b8;">Awareness</div>
    </div>
  </div>
</div>',
        .br_esc(cat_name),
        config$colour_focal, mms_val,
        config$colour_focal, mpen_val,
        config$colour_focal, aware_val))
    }
    parts <- c(parts, '</div>')
  }

  parts <- c(parts, '</div>')        # close .br-element-section
  parts <- c(parts, '</div></div>')  # close .br-section + .br-panel
  paste(parts, collapse = "\n")
}


# ==============================================================================
# DESTINATIONS
# ==============================================================================
# The five places a reader can be inside one category.
#
# `id` is the stable internal identifier. It appears in data-destination and
# nowhere else, and it is deliberately not derivable from `label`: the display
# words are expected to change once the vocabulary has been tested on a
# client, and a rename must not touch a single data-* value, a data-section
# anchor or a pin anchor. Those are a config contract; analysts have already
# typed names such as advantage-pas and ceps-pas into Section_Insights sheets.
#
# Nothing in the report may derive a label from an id or an id from a label.

#' Destination registry
#' @keywords internal
.BR_DESTINATIONS <- list(
  list(id = "overview", label = "Overview"),
  list(id = "mental",   label = "Mental Availability"),
  list(id = "buying",   label = "Brand and Buying"),
  list(id = "meaning",  label = "Brand Meaning"),
  list(id = "audience", label = "Audience")
)

#' Where each leaf lives
#'
#' Keyed on the leaf key, which is the historical \code{data-subtab} value or,
#' for Category Buying, \code{cb-} plus the \code{data-cb-tab} value. `tier`
#' is "main" or "advanced"; `order` sorts within a tier.
#'
#' Nineteen leaves, each appearing exactly once. Brand Attributes sits with
#' Category Entry Points under Mental Availability: both are memory
#' structures. Brand Meaning therefore holds Brand Attitude, Word of Mouth
#' and Branded Reach, which is what people say and see.
#'
#' @keywords internal
.BR_LEAF_HOMES <- list(
  "fn-funnel"       = list(dest = "buying",   tier = "main",     order = 10),
  "cb-context"      = list(dest = "buying",   tier = "main",     order = 20),
  "cb-brands"       = list(dest = "buying",   tier = "main",     order = 30),
  "cb-norms"        = list(dest = "buying",   tier = "advanced", order = 10),
  "cb-loyalty"      = list(dest = "buying",   tier = "advanced", order = 20),
  "cb-dist"         = list(dest = "buying",   tier = "advanced", order = 30),
  "cb-heaviness"    = list(dest = "buying",   tier = "advanced", order = 40),
  "cb-dop"          = list(dest = "buying",   tier = "advanced", order = 50),
  "ma-metrics"      = list(dest = "mental",   tier = "main",     order = 10),
  "ma-ceps"         = list(dest = "mental",   tier = "main",     order = 20),
  "ma-attributes"   = list(dest = "mental",   tier = "main",     order = 30),
  "ma-advantage"    = list(dest = "mental",   tier = "main",     order = 40),
  "fn-relationship" = list(dest = "meaning",  tier = "main",     order = 10),
  "wom"             = list(dest = "meaning",  tier = "main",     order = 20),
  "branded_reach"   = list(dest = "meaning",  tier = "advanced", order = 10),
  "demographics"    = list(dest = "audience", tier = "main",     order = 10),
  "adhoc"           = list(dest = "audience", tier = "main",     order = 20),
  "audience_lens"   = list(dest = "audience", tier = "advanced", order = 10),
  "cb-shopper"      = list(dest = "audience", tier = "advanced", order = 20)
)

#' Display labels for the Advanced accordion headers
#'
#' Separate from every identifier, for the reason given above the destination
#' registry. Nothing reads a key out of this list to build an attribute.
#'
#' @keywords internal
.BR_LEAF_LABELS <- list(
  "fn-funnel"       = "Brand Funnel",
  "fn-relationship" = "Brand Attitude",
  "ma-metrics"      = "Headline Metrics",
  "ma-ceps"         = "Category Entry Points",
  "ma-attributes"   = "Brand Attributes",
  "ma-advantage"    = "Mental Advantage",
  "cb-context"      = "Category Context",
  "cb-brands"       = "Brand Summary",
  "cb-norms"        = "Dirichlet Norms",
  "cb-loyalty"      = "Loyalty Segmentation",
  "cb-dist"         = "Purchase Distribution",
  "cb-heaviness"    = "Buyer Heaviness",
  "cb-dop"          = "Duplication of Purchase",
  "cb-shopper"      = "Shopper Behaviour",
  "wom"             = "Word of Mouth",
  "branded_reach"   = "Branded Reach",
  "demographics"    = "Demographics",
  "adhoc"           = "Ad Hoc",
  "audience_lens"   = "Audience Lens"
)


#' Build the header control area for one category
#'
#' A slot system, not two controls side by side. Slot three is reserved and
#' rendered empty, so a period selector can be added when wave comparison is
#' built without moving the two controls that exist. Every slot carries
#' data-slot; nothing here reads a display label.
#'
#' Slot one is the category switcher. It lists full-depth categories only.
#' Slot two is the brand control: one focal select and one comparison
#' trigger, applied to every destination in the category. It is the only
#' brand control a reader sees; every panel's own focal select and brand
#' filter carries \code{br-header-governed} and is hidden.
#'
#' @keywords internal
build_br_category_controls <- function(cat_id, cat_name, config,
                                        cat_results, category_choices = NULL,
                                        cat_brands = NULL) {
  parts <- character(0)
  parts <- c(parts, sprintf('<div class="br-controls" data-group="%s">', cat_id))

  # --- slot 1: category -----------------------------------------------------
  parts <- c(parts, '<div class="br-control-slot" data-slot="category">')
  if (!is.null(category_choices) && length(category_choices) > 1L) {
    opts <- vapply(category_choices, function(ch) sprintf(
      '<option value="%s"%s>%s</option>',
      .br_esc(ch$id), if (identical(ch$id, cat_id)) " selected" else "",
      .br_esc(ch$label)), character(1))
    parts <- c(parts, sprintf(paste0(
      '<label class="br-control-label" for="br-cat-select-%s">Category</label>',
      '<select class="br-cat-select" id="br-cat-select-%s" data-group="%s" ',
      'onchange="brSwitchCategoryFromControl(this)">%s</select>'),
      cat_id, cat_id, cat_id, paste(opts, collapse = "")))
  } else {
    parts <- c(parts, sprintf(
      '<span class="br-control-label">Category</span><span class="br-control-static">%s</span>',
      .br_esc(cat_name)))
  }
  parts <- c(parts, '</div>')

  # --- slot 2: focal brand and comparison set -------------------------------
  # Two controls, deliberately. The focal brand is one choice and the
  # comparison set is many, and folding them together would put the most
  # important choice in the report behind a click. They sit side by side in
  # one slot so a reader still has one place to go.
  #
  # The comparison control has three states, and the trigger always reads
  # the one that is live: focal only, focal and N others, or all brands. The
  # published hidden-brand set matches the state in every case, so the words
  # on the trigger and the rows in the tables cannot drift apart. The word
  # "Brands" stays on the trigger in every state, so it reads as a control
  # rather than as a status line when nothing has been picked.
  #
  # There is no cap on the comparators. The tables have always shown every
  # brand in the category, and chart legibility is the per-chart "Chart
  # brands" control's job.
  brands <- .br_category_brand_list(cat_brands, cat_results, config)
  focal  <- config$focal_brand %||% ""
  # chip_default is the analyst's Brand_Config setting for how much the
  # panels show on open. It is what the header starts on, so the one control
  # inherits the setting rather than overriding it.
  start_all <- identical(tolower(as.character(config$chip_default %||% "focal_only")),
                         "all")
  parts <- c(parts, '<div class="br-control-slot" data-slot="comparison">')
  if (length(brands) > 0L) {
    f_opts <- vapply(brands, function(b) sprintf(
      '<option value="%s"%s>%s</option>',
      .br_esc(b$code), if (identical(b$code, focal)) " selected" else "",
      .br_esc(b$label)), character(1))
    comp_items <- vapply(brands, function(b) sprintf(paste0(
      '<label class="br-cmp-item"><input type="checkbox" class="br-cmp-check" ',
      'value="%s"%s onchange="brComparisonSetChanged(this)"><span>%s</span></label>'),
      .br_esc(b$code),
      if (identical(b$code, focal)) " disabled checked" else "",
      .br_esc(b$label)), character(1))
    parts <- c(parts, sprintf(paste0(
      '<label class="br-control-label" for="br-focal-select-%s">Focal brand</label>',
      '<select class="br-focal-select" id="br-focal-select-%s" data-group="%s" ',
      'onchange="brComparisonFocalChanged(this)">%s</select>',
      '<button type="button" class="br-cmp-trigger" data-group="%s" ',
      'onclick="brToggleComparisonPopover(this)" aria-expanded="false">',
      '<span class="br-cmp-text" data-group="%s">%s</span>',
      '<span class="br-cmp-count" data-group="%s" hidden>%s</span></button>',
      '<div class="br-cmp-popover" data-group="%s" data-cmp-mode="%s" hidden>',
      '<div class="br-cmp-modes">',
      '<button type="button" class="br-cmp-mode%s" data-cmp-set="focal" ',
      'onclick="brSetComparisonMode(this)">Focal only</button>',
      '<button type="button" class="br-cmp-mode%s" data-cmp-set="all" ',
      'onclick="brSetComparisonMode(this)">All brands</button>',
      '</div>',
      '<div class="br-cmp-head">Or tick the brands to compare with the focal brand</div>',
      '<div class="br-cmp-list">%s</div>',
      '</div>'),
      cat_id, cat_id, cat_id, paste(f_opts, collapse = ""),
      cat_id, cat_id,
      if (start_all) sprintf("Brands: all %d", length(brands))
      else "Brands: focal only",
      cat_id,
      # The badge counts the brands on screen out of the category, which is
      # what the words leave out. It is hidden in the two states the words
      # already pin down, and brApplyComparisonSet repaints it on load, but
      # it is emitted correct so a pre-script paint and a saved copy read
      # the same as the live control.
      sprintf("%d/%d", if (start_all) length(brands) else 1L, length(brands)),
      cat_id, if (start_all) "all" else "focal",
      if (start_all) "" else " active", if (start_all) " active" else "",
      paste(comp_items, collapse = "")))
  }
  parts <- c(parts, '</div>')

  # --- slot 3: reserved for a period selector -------------------------------
  # Wave comparison is not built. The slot exists so that adding it later is
  # an insertion into an empty container, not a rebuild of this bar.
  parts <- c(parts, sprintf(
    '<div class="br-control-slot br-control-slot-empty" data-slot="period" data-group="%s"></div>',
    cat_id))

  parts <- c(parts, '</div>')
  paste(parts, collapse = "\n")
}


#' Brands sheet rows for one category
#'
#' Uses the transformer's own category filter so the comparison-set control
#' and the panels agree on which brands belong to a category.
#'
#' @keywords internal
.br_brands_for_cat <- function(results, cat_results, cat_key) {
  all_brands <- results$structure$brands
  if (is.null(all_brands) || !is.data.frame(all_brands) ||
      nrow(all_brands) == 0) return(NULL)
  if (exists(".dt_drop_none_brands", mode = "function"))
    all_brands <- .dt_drop_none_brands(all_brands)
  cat_code <- cat_results$cat_code %||% NULL
  cat_disp <- cat_results$category %||% cat_key
  if (exists(".filter_brands_for_cat", mode = "function")) {
    bl <- .filter_brands_for_cat(all_brands, cat_code, cat_disp)
    if (!is.null(bl) && nrow(bl) > 0) return(bl)
  }
  NULL
}


#' Brand codes and labels for one category, focal first
#'
#' Reads the Brands sheet rows for this category, the same source the panels
#' use, so the comparison-set control offers exactly the brands the panels
#' can show. Falls back to the funnel stages when the sheet is absent.
#'
#' @keywords internal
.br_category_brand_list <- function(cat_brands, cat_results, config) {
  focal <- config$focal_brand %||% ""
  codes <- character(0)
  labels <- list()

  if (!is.null(cat_brands) && is.data.frame(cat_brands) &&
      nrow(cat_brands) > 0 && "BrandCode" %in% names(cat_brands)) {
    codes <- as.character(cat_brands$BrandCode)
    lbls  <- if ("BrandLabel" %in% names(cat_brands))
      as.character(cat_brands$BrandLabel) else codes
    keep  <- nzchar(codes) & !duplicated(codes)
    codes <- codes[keep]; lbls <- lbls[keep]
    for (i in seq_along(codes)) labels[[codes[i]]] <- lbls[i]
  } else {
    st <- cat_results$funnel$stages
    if (!is.null(st) && "brand_code" %in% names(st)) {
      codes <- unique(as.character(st$brand_code))
      codes <- codes[nzchar(codes)]
      for (cd in codes) labels[[cd]] <- cd
    }
  }
  if (length(codes) == 0L) return(list())
  ordered <- c(if (focal %in% codes) focal else character(0),
               setdiff(codes, focal))
  lapply(ordered, function(cd) list(code = cd, label = labels[[cd]] %||% cd))
}


#' Build a category panel with 2-layer flat sub-tabs
#'
#' Each element's internal sections (Funnel/Relationship, Attributes/CEPs/Metrics)
#' are promoted to category-level sub-tabs, removing the intermediate element
#' grouping layer. The panel HTML for each element is kept intact but its
#' internal nav bar is hidden via CSS.
#'
#' Sub-tab order: Brand Funnel → Brand Attitude → Brand Attributes →
#' Category Entry Points → MA Metrics → Category Buying
#'
#' @keywords internal
build_br_category_panel <- function(cat_name, cat_results, charts, tables,
                                     config, panels = list(),
                                     cat_display_name = NULL,
                                     category_choices = NULL,
                                     cat_brands = NULL) {
  # cat_id is based on CategoryCode when available (same as transformer) so
  # that panel lookup keys in the `panels` list match element IDs in the page.
  cat_id <- gsub("[^a-z0-9]", "-",
                 tolower(cat_results$cat_code %||% cat_name))
  panel_id <- paste0("cat-", cat_id)
  # Use the human-readable display name for labels; fall back to the key.
  cat_name <- cat_display_name %||% cat_results$category %||% cat_name

  # Local helper: looks up the optional pre-filled insight text from the
  # config and forwards it to the toolbar builder. Keeps every call site
  # below to a single line.
  toolbar_for <- function(sid) {
    build_br_section_toolbar(
      sid,
      prefill_text = section_insight_for(config$section_insights, sid))
  }

  parts <- character(0)
  parts <- c(parts, sprintf('<div class="br-panel" id="panel-%s">', panel_id))

  # Detect which elements have renderable data
  has_funnel <- !is.null(cat_results$funnel) &&
    !identical(cat_results$funnel$status, "REFUSED")
  has_ma <- !is.null(cat_results$mental_availability) &&
    !identical(cat_results$mental_availability$status, "REFUSED")
  has_repertoire <- !is.null(cat_results$repertoire) &&
    !identical(cat_results$repertoire$status, "REFUSED")
  has_wom <- !is.null(cat_results$wom) &&
    !identical(cat_results$wom$status, "REFUSED") &&
    !is.null(cat_results$wom$wom_metrics)
  has_branded_reach <- !is.null(cat_results$branded_reach) &&
    !identical(cat_results$branded_reach$status, "REFUSED") &&
    length(cat_results$branded_reach$ads %||% list()) > 0
  has_demographics <- !is.null(cat_results$demographics) &&
    identical(cat_results$demographics$status, "PASS") &&
    length(cat_results$demographics$questions %||% list()) > 0
  has_adhoc <- !is.null(cat_results$adhoc) &&
    identical(cat_results$adhoc$status, "PASS") &&
    length(cat_results$adhoc$questions %||% list()) > 0
  has_audience_lens <- !is.null(cat_results$audience_lens) &&
    !identical(cat_results$audience_lens$status, "REFUSED") &&
    length(cat_results$audience_lens$audiences %||% list()) > 0
  # Drivers & Barriers HTML tab is retired, the focal-brand view on the
  # Mental Advantage sub-tab carries the same diagnostic. The engine in
  # 06_drivers_barriers.R still runs; its Importance / IxP / Competitive
  # Advantage / Rejection sheets continue to write to Excel and CSV.

  # ---------------------------------------------------------------------
  # Leaves. One analytical view, one host.
  #
  # A panel whose internal sub-tabs land in different destinations cannot
  # keep them in one DOM host, so the funnel, Mental Availability and
  # Category Buying panels are each rendered once per internal sub-tab
  # (Duncan's ruling 1, option (a) in impact map section 9 item 0). Only
  # the primary host of each panel carries the section wrapper id, the
  # data-section anchor and the JSON payload; the others read the payload
  # from the primary through data-island-host.
  #
  # `key` is the historical data-subtab value where one existed, so the
  # leaf-to-destination table below keys on values that already have a
  # meaning in this codebase. Display labels never appear in a data-*
  # attribute and never drive one.
  # ---------------------------------------------------------------------
  has_ma_advantage <- !is.null(panels[[paste0("ma_", cat_id, "__advantage")]])

  cand <- list(
    list(key = "fn-funnel",       el = "funnel",     sp = "fn",   it = "funnel",
         cb = "", pk = paste0("funnel_", cat_id),
         primary = TRUE,  gate = has_funnel),
    list(key = "fn-relationship", el = "funnel",     sp = "fn",   it = "relationship",
         cb = "", pk = paste0("funnel_", cat_id, "__relationship"),
         primary = FALSE, gate = has_funnel),
    list(key = "ma-metrics",      el = "ma",         sp = "ma",   it = "metrics",
         cb = "", pk = paste0("ma_", cat_id),
         primary = TRUE,  gate = has_ma),
    list(key = "ma-ceps",         el = "ma",         sp = "ma",   it = "ceps",
         cb = "", pk = paste0("ma_", cat_id, "__ceps"),
         primary = FALSE, gate = has_ma),
    list(key = "ma-attributes",   el = "ma",         sp = "ma",   it = "attributes",
         cb = "", pk = paste0("ma_", cat_id, "__attributes"),
         primary = FALSE, gate = has_ma),
    list(key = "ma-advantage",    el = "ma",         sp = "ma",   it = "advantage",
         cb = "", pk = paste0("ma_", cat_id, "__advantage"),
         primary = FALSE, gate = has_ma && has_ma_advantage),
    list(key = "cb-context",      el = "repertoire", sp = "rep",  it = "",
         cb = "context",   pk = paste0("cat_buying_", cat_id),
         primary = TRUE,  gate = has_repertoire),
    list(key = "cb-brands",       el = "repertoire", sp = "rep",  it = "",
         cb = "brands",    pk = paste0("cat_buying_", cat_id, "__brands"),
         primary = FALSE, gate = has_repertoire),
    list(key = "cb-norms",        el = "repertoire", sp = "rep",  it = "",
         cb = "norms",     pk = paste0("cat_buying_", cat_id, "__norms"),
         primary = FALSE, gate = has_repertoire),
    list(key = "cb-loyalty",      el = "repertoire", sp = "rep",  it = "",
         cb = "loyalty",   pk = paste0("cat_buying_", cat_id, "__loyalty"),
         primary = FALSE, gate = has_repertoire),
    list(key = "cb-dist",         el = "repertoire", sp = "rep",  it = "",
         cb = "dist",      pk = paste0("cat_buying_", cat_id, "__dist"),
         primary = FALSE, gate = has_repertoire),
    list(key = "cb-heaviness",    el = "repertoire", sp = "rep",  it = "",
         cb = "heaviness", pk = paste0("cat_buying_", cat_id, "__heaviness"),
         primary = FALSE, gate = has_repertoire),
    list(key = "cb-dop",          el = "repertoire", sp = "rep",  it = "",
         cb = "dop",       pk = paste0("cat_buying_", cat_id, "__dop"),
         primary = FALSE, gate = has_repertoire),
    list(key = "cb-shopper",      el = "repertoire", sp = "rep",  it = "",
         cb = "shopper",   pk = paste0("cat_buying_", cat_id, "__shopper"),
         primary = FALSE, gate = has_repertoire),
    list(key = "wom",             el = "wom",        sp = "wom",  it = "",
         cb = "", pk = paste0("wom_", cat_id),
         primary = TRUE,  gate = has_wom),
    list(key = "branded_reach",   el = "branded_reach", sp = "br", it = "",
         cb = "", pk = paste0("branded_reach_", cat_id),
         primary = TRUE,  gate = has_branded_reach),
    list(key = "demographics",    el = "demographics", sp = "demo", it = "",
         cb = "", pk = paste0("demographics_", cat_id),
         primary = TRUE,  gate = has_demographics),
    list(key = "adhoc",           el = "adhoc",      sp = "ah",   it = "",
         cb = "", pk = paste0("adhoc_", cat_id),
         primary = TRUE,  gate = has_adhoc),
    list(key = "audience_lens",   el = "audience_lens", sp = "al", it = "",
         cb = "", pk = paste0("audience_lens_", cat_id),
         primary = TRUE,  gate = has_audience_lens)
  )

  # A leaf survives when its element is configured and, for a non-primary
  # host, when the panel fragment for that sub-tab was actually produced.
  leaves <- Filter(function(lf) {
    if (!isTRUE(lf$gate)) return(FALSE)
    if (isTRUE(lf$primary)) return(TRUE)
    !is.null(panels[[lf$pk]])
  }, cand)

  # ---------------------------------------------------------------------
  # Destination containers
  # ---------------------------------------------------------------------
  dest_ids <- vapply(.BR_DESTINATIONS, function(d) d$id, character(1))
  home_of  <- function(key) .BR_LEAF_HOMES[[key]]

  leaves_for <- function(dest_id, tier) {
    sel <- Filter(function(lf) {
      h <- home_of(lf$key)
      !is.null(h) && identical(h$dest, dest_id) && identical(h$tier, tier)
    }, leaves)
    ord <- vapply(sel, function(lf) home_of(lf$key)$order, numeric(1))
    sel[order(ord)]
  }

  # The Overview always renders: it holds the route to this category's
  # entry on the Summary tab until Stage 3 builds it out.
  dest_has_content <- function(dest_id) {
    if (identical(dest_id, "overview")) return(TRUE)
    length(leaves_for(dest_id, "main")) > 0L ||
      length(leaves_for(dest_id, "advanced")) > 0L
  }
  live_dests <- Filter(function(d) dest_has_content(d$id), .BR_DESTINATIONS)

  # Header control area. A slot system rather than two hard-coded controls,
  # so a period selector can be added later without moving anything.
  parts <- c(parts, build_br_category_controls(cat_id, cat_name, config,
                                                cat_results, category_choices,
                                                cat_brands = cat_brands))

  # Destination navigation
  if (length(live_dests) > 0L) {
    dest_btns <- vapply(seq_along(live_dests), function(i) {
      d <- live_dests[[i]]
      sprintf(paste0('<button class="br-destination-btn%s" data-group="%s" ',
                     'data-destination="%s" onclick="switchBrandDestination(this)">%s</button>'),
              if (i == 1L) " active" else "", cat_id, d$id, .br_esc(d$label))
    }, character(1))
    parts <- c(parts, sprintf('<div class="br-destination-nav">%s</div>',
                              paste(dest_btns, collapse = "\n")))
  }

  for (i in seq_along(live_dests)) {
    d <- live_dests[[i]]
    parts <- c(parts, sprintf(
      '<div class="br-destination%s" data-group="%s" data-destination="%s">',
      if (i == 1L) " active" else "", cat_id, d$id))

    parts <- c(parts, '<div class="br-dest-main">')
    if (identical(d$id, "overview")) {
      parts <- c(parts, .br_overview_placeholder(cat_id, cat_name))
    }
    for (lf in leaves_for(d$id, "main")) {
      parts <- c(parts, .br_leaf_host(lf, cat_id, cat_name, cat_results,
                                       charts, tables, config, panels,
                                       toolbar_for))
    }
    parts <- c(parts, '</div>')

    adv <- leaves_for(d$id, "advanced")
    if (length(adv) > 0L) {
      # A destination whose only content sits in Advanced would otherwise
      # open on an empty main view, so its drawer starts open.
      main_empty <- length(leaves_for(d$id, "main")) == 0L &&
        !identical(d$id, "overview")
      # A drawer that starts closed opens on its list of titles, so the
      # reader sees what is in there and picks. A drawer that starts open,
      # because the destination has nothing else, opens on its first item,
      # so the destination is never a bare list of headings.
      # One item needs one disclosure, not two: the drawer is the
      # disclosure and the item is a heading over the content.
      single <- length(adv) == 1L
      parts <- c(parts, sprintf(paste0(
        '<div class="br-advanced" data-group="%s" data-destination="%s">',
        '<button type="button" class="br-advanced-toggle" ',
        'onclick="brToggleAdvanced(this)" aria-expanded="%s">',
        'Advanced<span class="br-advanced-count">%d</span></button>',
        '<div class="br-advanced-body"%s>'), cat_id, d$id,
        if (main_empty) "true" else "false",
        length(adv),
        if (main_empty) "" else " hidden"))
      for (j in seq_along(adv)) {
        lf  <- adv[[j]]
        lbl <- .BR_LEAF_LABELS[[lf$key]] %||% lf$key
        # Compact accordion: one researcher-grade analysis expanded at a
        # time (Duncan's ruling 7).
        open <- single || (main_empty && j == 1L)
        head_html <- if (single) sprintf(
          '<div class="br-adv-toggle br-adv-static">%s</div>', .br_esc(lbl))
        else sprintf(paste0(
          '<button type="button" class="br-adv-toggle" ',
          'onclick="brToggleAdvancedItem(this)" aria-expanded="%s">%s</button>'),
          if (open) "true" else "false", .br_esc(lbl))
        parts <- c(parts, sprintf(paste0(
          '<div class="br-adv-item%s" data-group="%s" data-leaf="%s">%s',
          '<div class="br-adv-body"%s>'),
          if (single) " br-adv-item-single" else "",
          cat_id, lf$key, head_html,
          if (open) "" else " hidden"))
        parts <- c(parts, .br_leaf_host(lf, cat_id, cat_name, cat_results,
                                         charts, tables, config, panels,
                                         toolbar_for))
        parts <- c(parts, '</div></div>')
      }
      parts <- c(parts, '</div></div>')
    }

    parts <- c(parts, '</div>')
  }

  parts <- c(parts, '</div>')
  paste(parts, collapse = "\n")
}


#' Placeholder card for the Overview destination
#'
#' Stage 2 rehomes the existing analyses; the Overview itself is built in
#' Stage 3. Until then the destination carries the route to this category's
#' entry on the Summary tab, so the destination is never shown empty and no
#' number or finding is manufactured to fill it.
#'
#' @keywords internal
.br_overview_placeholder <- function(cat_id, cat_name) {
  sprintf('
<div class="br-overview-stub">
  <h3 class="br-element-title">Overview: %s</h3>
  <p>The headline picture for this category is on the Summary tab.</p>
  <button type="button" class="br-overview-stub-btn"
    onclick="brOpenSummaryFor(\'%s\', \'%s\')">Open the summary for %s</button>
</div>',
    .br_esc(cat_name), .br_esc(cat_id), .br_esc(cat_name), .br_esc(cat_name))
}


#' Render one leaf as its own sub-panel host
#'
#' Emits the `.br-subpanel` host, the `.br-element-section` wrapper and the
#' element body. Only a primary host wears the wrapper id and the
#' `data-section` anchor, so the anchor set the report carries is unchanged
#' by the split.
#'
#' @keywords internal
.br_leaf_host <- function(lf, cat_id, cat_name, cat_results, charts, tables,
                           config, panels, toolbar_for) {
  el          <- lf$el
  section_id  <- paste0(el, "-", cat_id)
  legacy_key  <- paste0(el, "_", cat_id)
  # The funnel and MA branches read the host's own fragment. The repertoire
  # branch keeps looking up a "repertoire_<cat>" chart key that no panel
  # writes, which is how it reaches its own cat-buying lookup below.
  chart_key   <- if (el %in% c("funnel", "ma")) lf$pk else legacy_key
  cb_panel_key <- lf$pk
  internal_tab <- lf$it

  wrapper <- if (isTRUE(lf$primary)) sprintf(
    '<div class="br-element-section" id="section-%s" data-section="%s">',
    section_id, section_id) else '<div class="br-element-section">'

  parts <- character(0)
  parts <- c(parts, sprintf(
    '<div class="br-subpanel active" data-group="%s" data-subpanel="%s" data-internal-tab="%s" data-cb-tab="%s" data-leaf="%s">',
    cat_id, lf$sp, internal_tab, lf$cb, lf$key))
  parts <- c(parts, wrapper)

    if (!is.null(panels[[chart_key]])) {
      # WOM, branded-reach, repertoire/cat-buying, funnel, and MA panels
      # all get the shared section toolbar prepended. Funnel and MA also
      # render their own internal pin/PNG controls (different position).
      # the shared toolbar carries the insight editor which the embedded
      # controls do not.
      if (el == "wom") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Word of Mouth: %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "branded_reach") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Branded Reach: %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "demographics") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Demographics: %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "adhoc") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Ad Hoc Questions: %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "audience_lens") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Audience Lens: %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "funnel" || el == "ma") {
        # Per-sub-tab insight toolbars. The funnel panel has 2 internal
        # sub-tabs (funnel / relationship) and the MA panel has 4 (attributes
        # / advantage / ceps / metrics). Emit one toolbar per sub-tab, tagged
        # with data-insight-internal-tab so the JS sub-tab switcher
        # (brand_report.js::switchCategorySubtab) can hide all but the active
        # one. Anchors: <internal-tab>-<cat_id>, e.g. funnel-bak, ceps-pos.
        #
        # omit_chart_buttons=TRUE: the panel itself emits its own pin /
        # PNG / Excel toolbar (data-fn-action="pindropdown" /
        # ma-pin-dropdown-btn), so we render only the Add/Edit Insight
        # toggle here to avoid duplicate pin buttons. The panel pin
        # dropdowns read .br-insight-editor from the parent section so
        # the Section_Insights text still pins correctly.
        #
        # Each host carries exactly one of these, its own. The anchor names
        # are unchanged: funnel and attitude for the funnel panel,
        # attributes / advantage / ceps / metrics for Mental Availability.
        # Note that the attitude anchor does not match its internal tab
        # name, "relationship"; that mismatch is pre-existing and analysts'
        # Section_Insights sheets depend on it.
        anchor_el <- if (identical(internal_tab, "relationship")) "attitude"
                     else internal_tab
        sub_anchor <- paste0(anchor_el, "-", cat_id)
        parts <- c(parts, build_br_section_toolbar(
          section_id         = sub_anchor,
          prefill_text       = section_insight_for(config$section_insights,
                                                   sub_anchor),
          internal_tab       = internal_tab,
          initial_visible    = TRUE,
          omit_chart_buttons = TRUE))
      }
      parts <- c(parts, panels[[chart_key]])
    } else if (el == "ma") {
      parts <- c(parts,
        '<div style="padding:32px;text-align:center;color:#94a3b8;font-size:14px;">',
        'Mental Availability panel could not be rendered.',
        ' Ensure <code>02a_ma_panel_data.R</code> is sourced before calling',
        ' <code>generate_brand_html_report()</code>.',
        '</div>')
    } else if (el == "wom") {
      # WOM: per-category. Renders the new brand-attitude-style panel when
      # panels[[wom_<cat_id>]] is present; falls back to the legacy charts +
      # tables otherwise.
      wom_key <- paste0("wom_", cat_id)
      if (!is.null(panels[[wom_key]])) {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Word of Mouth: %s</h3>',
          .br_esc(cat_name)))
        parts <- c(parts, panels[[wom_key]])
      } else {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Word of Mouth: %s</h3>',
          .br_esc(cat_name)))
        parts <- c(parts, '<p style="font-size:12px;color:#64748b;margin:0 0 12px;">',
          'Percentage of category buyers who received or shared word-of-mouth about each brand ',
          'in the study\'s recall timeframe.</p>')
        if (!is.null(charts[[wom_key]])) {
          for (ch in charts[[wom_key]]) {
            parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
          }
        }
        if (!is.null(tables[[wom_key]])) {
          parts <- c(parts, tables[[wom_key]])
        }
      }
    } else if (el == "repertoire") {
      # Category Buying panel.
      # v3: rendered by the new Dirichlet panel when available (panels key
      # "cat_buying_<cat_id>"); falls back to the legacy inline block when the
      # Dirichlet pipeline was not run or all upstream elements were REFUSED.
      # cb_panel_key is the host's own fragment, set by .br_leaf_host().

      if (!is.null(panels[[cb_panel_key]])) {
        # New Dirichlet panel: self-contained HTML fragment.
        # Layout overrides (per design request):
        #   - Pin + Export emitted at top with class cb-toolbar-top so JS can
        #     relocate them into the Brand Summary controls bar (right side).
        #   - No redundant h3 title or timeframe subtitle.
        #   - +Add Insight button moved BELOW the panel, full width.
        #
        # The toolbar, its section anchor and the insight footer belong to
        # the primary host only. A secondary cat-buying host repeating them
        # would put several buttons and containers on one anchor, and
        # brTogglePin resolves an anchor by taking the first match.
        if (isTRUE(lf$primary)) parts <- c(parts, sprintf('
<div class="br-section-toolbar cb-toolbar-top" data-section="%s" style="display:flex;gap:8px;margin-bottom:12px;">
  <button class="br-pin-btn" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin to Views"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:15px;padding:5px 10px;color:#94a3b8;transition:all 0.15s;">
    &#x1F4CC;
  </button>
  <button class="br-png-btn" onclick="brExportPng(\'%s\',this)" title="Export PNG"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    &#x1F5BC; PNG
  </button>
  <button class="br-export-btn" onclick="_brExportPanel(\'%s\')" title="Export Excel"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    &#x1F4E5; Excel
  </button>
</div>',
          section_id, section_id, section_id, section_id, section_id))
        parts <- c(parts, panels[[cb_panel_key]])
        # Cat-Buying insight footer. Supports Section_Insights prefill via
        # the standard config$section_insights lookup. When pre-filled the
        # container opens by default and the rendered view shows the text.
        cb_insight_text <- if (isTRUE(lf$primary))
          section_insight_for(config$section_insights, section_id) else ""
        cb_has <- nzchar(cb_insight_text)
        # Single %, see note in build_br_section_toolbar above.
        cb_base_container <- "margin-top:12px;position:relative;width:100%;max-width:none;box-sizing:border-box;grid-column:1 / -1;"
        cb_container_style <- if (cb_has)
          paste0("display:block;", cb_base_container)
        else
          paste0("display:none;", cb_base_container)
        cb_base_textarea <- "width:100%;min-width:0;min-height:140px;border:1px solid #e2e8f0;border-radius:6px;padding:12px;font-family:inherit;font-size:13px;line-height:1.55;resize:vertical;box-sizing:border-box;"
        cb_textarea_style <- if (cb_has)
          paste0(cb_base_textarea, "display:none;")
        else
          cb_base_textarea
        cb_base_rendered <- "padding:12px 14px;border:1px solid #e2e8f0;border-radius:6px;min-height:48px;cursor:pointer;font-size:13px;line-height:1.55;box-sizing:border-box;"
        cb_rendered_style <- if (cb_has)
          paste0("display:block;background:#f8fafc;", cb_base_rendered)
        else
          paste0("display:none;", cb_base_rendered)
        cb_toggle_label <- if (cb_has) "Edit Insight" else "+ Add Insight"
        cb_toggle_handler <- if (cb_has) "_brToggleInsightEdit" else "_brToggleInsight"
        cb_rendered_html <- if (cb_has) .br_render_insight_md(cb_insight_text) else ""

        if (isTRUE(lf$primary)) parts <- c(parts, sprintf('
<div class="cb-insight-footer" style="margin-top:20px;">
  <button class="br-insight-toggle" onclick="%s(\'%s\')"
    style="width:100%%;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:13px;padding:10px 14px;color:#334155;background:#f8fafc;font-weight:600;">
    %s
  </button>
  <div class="br-insight-container" data-section="%s" data-prefilled="%s" style="%s">
    <textarea class="br-insight-editor" data-section="%s" placeholder="Type key insight here..."
      style="%s">%s</textarea>
    <div class="br-insight-rendered" data-section="%s" ondblclick="_brToggleInsightEdit(\'%s\')"
      style="%s">%s</div>
    <button class="br-insight-dismiss" onclick="_brDismissInsight(\'%s\')"
      style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:16px;position:absolute;top:4px;right:8px;">&times;</button>
  </div>
</div>',
          cb_toggle_handler, section_id, cb_toggle_label,
          section_id, if (cb_has) "true" else "false", cb_container_style,
          section_id, cb_textarea_style, .br_esc(cb_insight_text),
          section_id, section_id, cb_rendered_style, cb_rendered_html,
          section_id))
      } else {
        # Legacy fallback: frequency KPI strip + SVG charts + legacy tables
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Category Buying: %s</h3>',
          .br_esc(cat_name)))

        cbf <- cat_results$cat_buying_frequency
        if (!is.null(cbf) && !identical(cbf$status, "REFUSED")) {
          pct_b  <- if (!is.null(cbf$pct_buyers) && !is.na(cbf$pct_buyers))
            sprintf("%.0f%%", cbf$pct_buyers) else "\u2013"
          mfreq  <- if (!is.null(cbf$mean_freq) && !is.na(cbf$mean_freq))
            sprintf("%.1f\u00d7/month", cbf$mean_freq) else "\u2013"
          n_resp <- if (!is.null(cbf$n_respondents) && !is.na(cbf$n_respondents))
            sprintf("n = %d all respondents", cbf$n_respondents) else ""

          parts <- c(parts, sprintf(
            '<div style="display:flex;gap:12px;margin:0 0 16px;flex-wrap:wrap;">
  <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:8px;padding:10px 18px;min-width:130px;">
    <div style="font-size:22px;font-weight:700;color:#1A5276;">%s</div>
    <div style="font-size:11px;color:#64748b;margin-top:2px;">Category buyers</div>
  </div>
  <div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:10px 18px;min-width:130px;">
    <div style="font-size:22px;font-weight:700;color:#166534;">%s</div>
    <div style="font-size:11px;color:#64748b;margin-top:2px;">Mean buy rate</div>
  </div>
  <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:10px 18px;min-width:130px;align-self:center;">
    <div style="font-size:12px;color:#94a3b8;">%s</div>
  </div>
</div>', pct_b, mfreq, .br_esc(n_resp)))
        } else {
          parts <- c(parts,
            '<p style="font-size:12px;color:#64748b;margin:0 0 12px;">',
            'Brand repertoire size, sole loyalty, and duplication of purchase among category buyers.</p>')
        }

        if (!is.null(charts[[legacy_key]])) {
          for (ch in charts[[legacy_key]]) {
            parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
          }
        }
        if (!is.null(tables[[legacy_key]])) {
          parts <- c(parts, tables[[legacy_key]])
        }
      }
    } else {
      # Legacy path: any future elements without a dedicated panel
      parts <- c(parts, toolbar_for(section_id))
      if (!is.null(charts[[legacy_key]])) {
        for (ch in charts[[legacy_key]]) {
          parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
        }
      }
      if (!is.null(tables[[legacy_key]])) {
        parts <- c(parts, tables[[legacy_key]])
      }
    }

  parts <- c(parts, '</div></div>')
  paste(parts, collapse = "\n")
}


#' Build the portfolio optimisation panel
#'
#' Cross-category table using the FULL respondent base (all 1200), showing
#' Category Usage (% qualifying) and Brand Awareness per category.
#' A brand picker chip row lets the user select which brand's awareness to view.
#' Per-category MA metrics (MMS/MPen/NS) are excluded.
#'
#' @keywords internal
build_br_portfolio_panel <- function(results, config) {
  focal        <- config$focal_brand %||% ""
  # Sanitised once here: this value lands in inline style declarations and in
  # the brand-picker script below, and the config loader does not check it.
  brand_colour <- .br_colour(config$colour_focal %||% "#1A5276")

  port_overview <- results$results$portfolio_overview
  port_data     <- results$results$portfolio
  cats          <- results$results$categories

  if ((is.null(port_overview) || length(port_overview$categories) == 0) &&
      (is.null(cats) || length(cats) == 0)) {
    return('<div class="br-panel" id="panel-portfolio"><div class="br-section"><p style="color:#94a3b8;padding:32px;text-align:center;">No category data available.</p></div></div>')
  }

  n_total    <- port_data$n_total %||% NA_integer_
  section_id <- "portfolio-overview"
  port_rows  <- if (!is.null(port_overview)) port_overview$categories else list()

  # Build global brand code -> name map from all category rows
  brand_map <- list()
  for (pr in port_rows) {
    bcs <- pr$brand_codes %||% character(0)
    bns <- pr$brand_names %||% list()
    for (bc in bcs) {
      if (!bc %in% names(brand_map)) {
        bn <- if (!is.null(bns[[bc]])) as.character(bns[[bc]]) else bc
        brand_map[[bc]] <- bn
      }
    }
  }
  all_bcs     <- names(brand_map)
  others      <- sort(setdiff(all_bcs, focal))
  ordered_bcs <- c(if (focal %in% all_bcs) focal else character(0), others)
  active_bc   <- if (length(ordered_bcs) > 0L) ordered_bcs[1L] else ""
  active_name <- if (nchar(active_bc) > 0L) (brand_map[[active_bc]] %||% active_bc) else "Brand"

  # Encode brand_awareness named list as JSON for data attribute
  .aw_json <- function(ba) {
    if (is.null(ba) || length(ba) == 0L) return("{}")
    pairs <- vapply(names(ba), function(bc) {
      v <- ba[[bc]]
      if (is.finite(v)) sprintf('"%s":%.6f', bc, v) else sprintf('"%s":null', bc)
    }, character(1L))
    paste0("{", paste(pairs, collapse = ","), "}")
  }

  parts <- character(0)
  parts <- c(parts, '<div class="br-panel" id="panel-portfolio">')
  parts <- c(parts, '<div class="br-section">')
  parts <- c(parts, '<h2 style="font-size:20px;color:#1e293b;margin:0 0 6px;">Portfolio Overview</h2>')
  parts <- c(parts, sprintf(
    '<p style="font-size:13px;color:#64748b;margin:0 0 4px;">Cross-category reach. Based on all %s respondents.</p>',
    if (!is.na(n_total)) format(n_total, big.mark = ",") else "all"))
  parts <- c(parts, '<p style="font-size:11px;color:#94a3b8;margin:0 0 20px;">Category Usage = % of all respondents who qualify (screener SQ2). Brand Awareness = % of category qualifiers aware of the selected brand.</p>')

  parts <- c(parts, sprintf(
    '<div class="br-element-section" id="section-%s" data-section="%s">',
    section_id, section_id))
  # Legacy portfolio overview uses anchor "portfolio-overview". The new
  # portfolio panel (panels/09_portfolio_panel.R) uses "pf-overview" etc.
  # Both keys can appear in config$section_insights, the resolver passes
  # raw anchors through unchanged so each one wires correctly.
  parts <- c(parts, build_br_section_toolbar(
    section_id,
    prefill_text = section_insight_for(config$section_insights, section_id)))

  # Brand picker chip row
  if (length(ordered_bcs) > 0L) {
    base_css   <- paste0("display:inline-block;padding:4px 12px;font-size:12px;font-weight:500;",
                         "cursor:pointer;border:1px solid #e2e8f0;background:#f8fafc;color:#475569;",
                         "border-radius:0;")
    active_css <- paste0("display:inline-block;padding:4px 12px;font-size:12px;font-weight:500;",
                         "cursor:pointer;border:1px solid ", brand_colour, ";background:", brand_colour,
                         ";color:#fff;border-radius:0;")
    n_chips <- length(ordered_bcs)
    chips_html <- vapply(seq_len(n_chips), function(ci) {
      bc   <- ordered_bcs[ci]
      name <- .br_esc(brand_map[[bc]] %||% bc)
      edge <- if (ci == 1L && n_chips == 1L) "border-radius:4px;" else
              if (ci == 1L)     "border-radius:4px 0 0 4px;" else
              if (ci == n_chips) "border-left:none;border-radius:0 4px 4px 0;" else
              "border-left:none;"
      css  <- if (bc == active_bc) paste0(active_css, edge) else paste0(base_css, edge)
      sprintf('<button type="button" style="%s" data-br-port-brand="%s">%s</button>',
              css, .br_esc(bc), name)
    }, character(1L))

    parts <- c(parts,
      '<div style="display:flex;align-items:center;gap:8px;margin-bottom:16px;flex-wrap:wrap;">',
      '<span style="font-size:12px;color:#64748b;white-space:nowrap;">Show awareness for:</span>',
      sprintf('<div id="br-port-brand-picker" style="display:flex;flex-wrap:wrap;">%s</div>',
              paste(chips_html, collapse = "")),
      '</div>')
  }

  # Table
  aware_hdr <- sprintf('%s Awareness', .br_esc(active_name))
  parts <- c(parts, sprintf('
<div style="overflow-x:auto;">
<table class="br-table" data-sortable="true">
<thead><tr>
  <th>Category</th>
  <th>Analysis</th>
  <th style="text-align:right;">Category Usage</th>
  <th id="br-port-aware-hdr" style="text-align:right;">%s</th>
</tr></thead>
<tbody>', aware_hdr))

  for (pr in port_rows) {
    cat_name  <- pr$cat_name %||% pr$category %||% ""
    depth     <- pr$analysis_depth %||% "full"
    usage_pct <- pr$cat_usage_pct
    aw_map    <- pr$awareness_pct %||% pr$brand_awareness %||% list()
    aw_json   <- .aw_json(aw_map)

    init_aw   <- aw_map[[active_bc]]
    # both cat_usage_pct and awareness_pct from portfolio_overview are 0-100 scale
    usage_str <- if (!is.null(usage_pct) && is.finite(usage_pct))
      sprintf("%.0f%%", usage_pct) else "\u2013"
    aware_str <- if (!is.null(init_aw) && is.finite(init_aw))
      sprintf("%.0f%%", init_aw) else "\u2013"

    depth_badge <- if (depth == "full")
      sprintf('<span style="background:#EBF5FB;color:%s;border-radius:4px;padding:2px 7px;font-size:10px;font-weight:600;">Full</span>',
              brand_colour)
    else
      '<span style="background:#f1f5f9;color:#94a3b8;border-radius:4px;padding:2px 7px;font-size:10px;font-weight:500;">Awareness only</span>'

    row_style <- if (depth == "awareness_only") ' style="color:#94a3b8;"' else ""
    fw        <- if (depth == "full") "600" else "400"

    parts <- c(parts, sprintf(
      "<tr%s data-br-port-awareness='%s'><td style=\"font-weight:%s;\">%s</td><td>%s</td><td style=\"text-align:right;\">%s</td><td class=\"br-port-aware-cell\" style=\"text-align:right;\">%s</td></tr>",
      row_style, aw_json, fw, .br_esc(cat_name), depth_badge, usage_str, aware_str))
  }

  parts <- c(parts, '</tbody></table></div>')

  # Inline JS for brand picker (only needed when there are multiple brands)
  if (length(ordered_bcs) > 1L) {
    parts <- c(parts, sprintf('
<script>
(function() {
  var section = document.getElementById("section-" + %s);
  if (!section) return;
  var brandColour = %s;
  section.addEventListener("click", function(e) {
    var chip = e.target;
    if (!chip || !chip.hasAttribute("data-br-port-brand")) return;
    var brand = chip.getAttribute("data-br-port-brand");
    var brandName = chip.textContent.trim();
    var picker = document.getElementById("br-port-brand-picker");
    if (picker) {
      picker.querySelectorAll("[data-br-port-brand]").forEach(function(c) {
        var on = c === chip;
        c.style.background  = on ? brandColour : "#f8fafc";
        c.style.color       = on ? "#fff" : "#475569";
        c.style.borderColor = on ? brandColour : "#e2e8f0";
      });
    }
    var hdr = document.getElementById("br-port-aware-hdr");
    if (hdr) hdr.textContent = brandName + " Awareness";
    section.querySelectorAll("tr[data-br-port-awareness]").forEach(function(row) {
      var map = {};
      try { map = JSON.parse(row.getAttribute("data-br-port-awareness")); } catch(x) {}
      var val = map[brand];
      var cell = row.querySelector(".br-port-aware-cell");
      if (cell) cell.textContent = (val != null && isFinite(val)) ? Math.round(val) + "%%" : "\u2013";
    });
  });
})();
</script>', .br_js_str(section_id), .br_js_str(brand_colour)))
  }

  parts <- c(parts, '</div>')  # element-section

  # Future sections placeholder
  parts <- c(parts, '
<div class="br-element-section" style="margin-top:16px;">
  <h3 class="br-element-title">Portfolio Optimisation: Coming Soon</h3>
  <ul style="font-size:13px;color:#64748b;line-height:2;padding-left:20px;">
    <li>Category investment prioritisation matrix (market size \u00d7 brand strength)</li>
    <li>Awareness-indexed MMS to compare mental availability efficiency across categories</li>
    <li>Cross-category CEP overlap analysis (which entry points span multiple categories)</li>
    <li>Portfolio growth opportunity scoring</li>
  </ul>
</div>')

  parts <- c(parts, '</div>')  # section
  parts <- c(parts, '</div>')  # panel

  paste(parts, collapse = "\n")
}


#' Build pinned views panel
#' @keywords internal
build_br_pinned_panel <- function() {
  '
<div class="br-panel" id="panel-pinned">
  <div style="max-width:1400px;margin:0 auto;padding:20px 0;">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
      <div>
        <h2 style="font-size:18px;font-weight:700;color:#1e293b;margin:0 0 4px;">Pinned Views</h2>
        <p style="font-size:12px;color:#64748b;margin:0;">Pin charts and tables to build a curated set of key findings.</p>
      </div>
      <div style="display:flex;gap:8px;">
        <button class="br-action-btn" onclick="brAddSection()" style="background:#fff;border:1px solid #e2e8f0;border-radius:6px;padding:6px 12px;cursor:pointer;font-size:12px;color:#64748b;">&#x2795; Add Section</button>
        <button class="br-action-btn" onclick="brExportAllPinned()" style="background:#fff;border:1px solid #e2e8f0;border-radius:6px;padding:6px 12px;cursor:pointer;font-size:12px;color:#64748b;">&#x1F4E4; Export All</button>
      </div>
    </div>
    <div id="br-pinned-cards-container"></div>
    <div id="br-pinned-empty" style="text-align:center;padding:60px 20px;color:#94a3b8;">
      <div style="font-size:36px;margin-bottom:12px;">&#x1F4CC;</div>
      <div style="font-size:14px;font-weight:600;">No pinned views yet.</div>
      <div style="font-size:12px;margin-top:4px;">Click the pin icon on any section to add views here.</div>
    </div>
    <script type="application/json" id="br-pinned-views-data">[]</script>
  </div>
</div>'
}


#' Build about panel
#' @keywords internal
build_br_about_panel <- function(config) {
  # Optional project background block, sourced from the Section_Insights
  # config sheet under reserved anchor `_BACKGROUND`. Rendered above the
  # methodology copy so the project context is the first thing the reader
  # sees on the About tab.
  background_text <- if (exists("section_insight_for", mode = "function")) {
    section_insight_for(config$section_insights, "_BACKGROUND")
  } else ""
  background_html <- if (nzchar(background_text)) {
    rendered <- if (exists(".br_render_insight_md", mode = "function"))
      .br_render_insight_md(background_text)
    else
      .br_esc(background_text)
    sprintf('<div class="br-about-background" data-section="_BACKGROUND" style="background:#f8fafc;border-left:3px solid %s;padding:16px 20px;margin:0 0 20px;font-size:13px;line-height:1.6;color:#334155;border-radius:0 6px 6px 0;"><div style="font-size:11px;text-transform:uppercase;letter-spacing:0.5px;color:#64748b;margin:0 0 8px;font-weight:600;">Project background</div>%s</div>',
            config$colour_focal %||% "#1A5276", rendered)
  } else ""

  sprintf('
<div class="br-panel" id="panel-about">
  <div class="br-section" style="max-width:800px;">
    <h2 style="font-size:20px;color:#1e293b;margin:0 0 16px;">About & Methodology</h2>
    %s
    <div style="font-size:13px;line-height:1.7;color:#475569;">
      <p>This report uses the <strong>Category Buyer Mindset (CBM)</strong> framework
      developed by Jenni Romaniuk at the Ehrenberg-Bass Institute for Marketing Science.</p>

      <h3 style="font-size:15px;color:%s;margin:20px 0 8px;">Mental Availability</h3>
      <p><strong>Mental Market Share (MMS)</strong> measures the brand&rsquo;s share of all
      brand&ndash;CEP links in the category. <strong>Mental Penetration (MPen)</strong> measures
      the proportion of category buyers who link the brand to at least one Category Entry Point.
      <strong>Network Size (NS)</strong> measures the average number of CEPs linked among those
      who link at least one.</p>

      <h3 style="font-size:15px;color:%s;margin:20px 0 8px;">Brand Funnel</h3>
      <p>Funnel stages are derived from core CBM data, not from sequential funnel questions.
      The 6-level attitude scale (Love, Prefer, Ambivalent, Price-conditional, Avoid, No opinion)
      provides richer diagnostics than traditional binary consideration, with avoidance captured
      explicitly (attitude code 5).</p>

      <h3 style="font-size:15px;color:%s;margin:20px 0 8px;">References</h3>
      <ul style="padding-left:20px;">
        <li>Romaniuk, J. (2022). <em>Better Brand Health</em>. Oxford University Press.</li>
        <li>Sharp, B. (2010). <em>How Brands Grow</em>. Oxford University Press.</li>
        <li>Romaniuk, J. &amp; Sharp, B. (2016). <em>How Brands Grow Part 2</em>. Oxford University Press.</li>
        <li>Romaniuk, J. (2018). <em>Building Distinctive Brand Assets</em>. Oxford University Press.</li>
      </ul>

      <p style="margin-top:20px;font-size:11px;color:#94a3b8;">Report generated by TURAS Analytics Platform v%s on %s.</p>
    </div>
  </div>
</div>',
    background_html,
    config$colour_focal %||% "#1A5276",
    config$colour_focal %||% "#1A5276",
    config$colour_focal %||% "#1A5276",
    "1.0", format(Sys.time(), "%d %B %Y at %H:%M"))
}


#' Build help overlay
#' @keywords internal
build_br_help_overlay <- function() {
  '
<div id="br-help-overlay" class="br-help-overlay" onclick="if(event.target===this)_brToggleHelp()">
  <div class="br-help-card" style="background:#fff;border-radius:12px;padding:24px 28px;max-width:500px;margin:80px auto;box-shadow:0 20px 60px rgba(0,0,0,0.15);font-size:13px;line-height:1.6;color:#475569;position:relative;">
    <button onclick="_brToggleHelp()" style="position:absolute;top:12px;right:16px;background:none;border:none;font-size:20px;cursor:pointer;color:#94a3b8;">&times;</button>
    <h3 style="margin:0 0 12px;font-size:16px;color:#1e293b;">Report Guide</h3>
    <p><strong>Navigation:</strong> Use the tabs to switch between categories and elements. Sub-tabs within each category show different analytical views.</p>
    <p><strong>Pin:</strong> Click &#x1F4CC; on any section to pin charts/tables to the Pinned Views tab for presentation building.</p>
    <p><strong>Insight:</strong> Click &ldquo;+ Add Insight&rdquo; to annotate any section with your analysis. Double-click the rendered text to edit.</p>
    <p><strong>Export:</strong> Click &ldquo;Export&rdquo; to download section data as Excel. &ldquo;Save Report&rdquo; downloads the full HTML.</p>
    <p><strong>Sort:</strong> Click any table column header to sort ascending/descending.</p>
  </div>
</div>'
}


# ==============================================================================
# MAIN PAGE ASSEMBLY
# ==============================================================================

#' Assemble the full brand HTML page
#'
#' @param results List. Output from run_brand().
#' @param charts Named list. Chart SVGs keyed by element_catid.
#' @param tables Named list. Table HTML keyed by element_catid.
#' @param config List. Brand config.
#' @param brand_js Character. Module JS code.
#' @param pins_js Character. TurasPins JS code.
#'
#' @return Character. Complete HTML document.
#' @keywords internal
build_brand_page <- function(results, charts, tables, config,
                              brand_js = "", pins_js = "",
                              panels = list(), panel_styles = "",
                              panel_js = "") {

  brand_colour <- config$colour_focal %||% "#1A5276"
  accent_colour <- config$colour_focal_accent %||% "#2E86C1"

  # --- CSS ---
  base_css <- ""
  if (exists("turas_base_css", mode = "function")) {
    base_css <- tryCatch(
      turas_base_css(brand_colour = brand_colour, accent_colour = accent_colour),
      error = function(e) ""
    )
  }

  module_css <- sprintf('
:root { --br-brand: %s; --br-accent: %s; --brand-colour: %s; }
body { background: #f8f7f5; margin: 0; padding: 0; }
.br-container { max-width: 1200px; margin: 0 auto; padding: 0 32px 60px; }
.br-tab-nav {
  position: sticky; top: 0; z-index: 100; background: #fff;
  border-bottom: 1px solid #e2e8f0; padding: 0 32px;
  display: flex; gap: 0; overflow-x: auto; white-space: nowrap;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}
.br-tab-btn {
  background: none; border: none; border-bottom: 3px solid transparent;
  padding: 12px 18px; font-size: 13px; font-weight: 500; color: #64748b;
  cursor: pointer; transition: all 0.15s; white-space: nowrap;
}
.br-tab-btn:hover { color: #1e293b; background: #f8f9fa; }
.br-tab-btn.active { color: %s; border-bottom-color: %s; font-weight: 600; }
.br-pin-badge {
  background: %s; color: #fff; border-radius: 10px; padding: 1px 6px;
  font-size: 10px; font-weight: 700; margin-left: 4px; display: inline-block;
  min-width: 16px; text-align: center;
}
.br-panel { display: none; padding: 24px 0; }
.br-panel.active { display: block; }
.br-subtab-nav {
  display: flex; gap: 0; border-bottom: 1px solid #e2e8f0; margin-bottom: 20px;
}
.br-subtab-btn {
  background: none; border: none; border-bottom: 2px solid transparent;
  padding: 10px 16px; font-size: 12px; font-weight: 500; color: #94a3b8;
  cursor: pointer; transition: all 0.15s;
}
.br-subtab-btn.active { color: %s; border-bottom-color: %s; }
.br-subtab-btn:hover { color: #64748b; }
.br-subpanel { display: none; }
.br-subpanel.active { display: block; }
.br-section { margin-bottom: 24px; }
.br-element-section {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  padding: 20px 24px; margin-bottom: 16px; position: relative;
}
.br-element-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 0 0 12px; }
.br-table { width: 100%%; border-collapse: collapse; font-size: 12px; }
.br-table th {
  background: #f8f9fa; color: #64748b; font-weight: 600; font-size: 11px;
  text-transform: uppercase; letter-spacing: 0.5px; padding: 8px 12px;
  border-bottom: 2px solid #e2e8f0; text-align: left; cursor: pointer;
  user-select: none; white-space: nowrap;
}
.br-table td { padding: 8px 12px; border-bottom: 1px solid #f0f0f0; color: #334155; }
.br-table tr:hover td { background: #f8f9fb; }
.br-table .focal-row { background: #EBF5FB !important; font-weight: 600; }
.br-table .focal-row td { color: %s; }
.br-chart-wrapper:hover .br-chart-pin-btn { opacity: 1; }
.pin-flash { animation: br-flash 0.6s ease; }
@keyframes br-flash { 0%%,100%% { transform:scale(1); } 50%% { transform:scale(1.3); color:%s; } }
.br-help-overlay {
  display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.4); z-index: 1000;
}
.br-help-overlay.open { display: block; }
/* 2-layer nav: internal panel sub-navbars are hidden. Their tabs are
   promoted to the category-level .br-subtab-nav. The internal nav HTML
   is kept in the DOM so JS click-dispatch still works. */
.fn-subnav, .ma-subnav, .cb-subnav { display: none !important; }

/* === PINNED CARD (br-pinned-*): matches conjoint/tabs visual standard === */
.br-pinned-card {
  background:#ffffff; border:1px solid #e8e5e0; border-radius:8px;
  padding:20px 24px; margin-bottom:16px; page-break-inside:avoid;
  box-shadow: 0 1px 2px rgba(0,0,0,0.03);
}
.br-pinned-card-header {
  display:flex; justify-content:space-between; align-items:flex-start;
  margin-bottom:12px; gap:12px;
}
.br-pinned-card-title {
  font-size:16px; font-weight:600; color:#1e293b; line-height:1.3;
  flex:1 1 auto; min-width:0;
}
.br-pinned-card-actions { display:flex; gap:4px; flex-shrink:0; align-items:center; }
.br-pinned-action-btn, .br-pinned-remove-btn {
  padding:4px 8px; font-size:14px; line-height:1;
  background:none; border:1px solid #e2e8f0; border-radius:4px;
  cursor:pointer; color:#64748b; transition:all 0.15s;
}
.br-pinned-action-btn:hover { background:#f1f5f9; color:#1e293b; }
.br-pinned-remove-btn:hover { background:#fee2e2; color:#b91c1c; border-color:#fca5a5; }

.br-pinned-card-insight {
  margin-bottom:12px; padding:14px 20px;
  border-left:3px solid %s; background:#f8fafa;
  border-radius:0 6px 6px 0; font-size:14px; line-height:1.6; color:#1e293b;
}
.br-pinned-card-insight:empty { display:none; }
.br-pinned-card-chart { margin-bottom:12px; }
.br-pinned-card-chart svg { width:100%%; height:auto; max-width:100%%; }
.br-pinned-card-table { overflow-x:auto; margin-bottom:8px; }
.br-pinned-card-table table { width:100%% !important; border-collapse:collapse; font-size:13px; }
.br-pinned-card-table th {
  padding:8px 12px; text-align:left; font-size:11px; font-weight:600;
  text-transform:uppercase; letter-spacing:0.3px; color:#64748b;
  background:#f8fafc; border-bottom:2px solid #e2e8f0;
}
.br-pinned-card-table td {
  padding:8px 12px; border-bottom:1px solid #f1f5f9; color:#334155;
}
.br-pinned-card-table tr:last-child td { border-bottom:none; }
.br-pinned-card-table tr:hover td { background:#f8fafc; }

.br-pinned-card[draggable="true"] { cursor:grab; }
.br-pinned-card[draggable="true"]:active { cursor:grabbing; }
.pin-dragging { opacity:0.4 !important; }
.pin-drop-target { outline:2px dashed %s; outline-offset:4px; }

.turas-pin-overflow { font-family:inherit; }
.turas-pin-overflow button { font-family:inherit !important; }

@media print {
  .br-tab-nav, .br-section-toolbar, .br-insight-container,
  .br-chart-pin-btn, .br-save-btn, .br-help-btn,
  .br-pinned-card-actions { display: none !important; }
  .br-panel { display: block !important; page-break-inside: avoid; }
  .br-subpanel { display: block !important; }
  .br-destination { display: block !important; }
  /* Advanced content is collapsed on screen, never dropped from print. */
  .br-advanced-body[hidden], .br-adv-body[hidden] {
    display: block !important; visibility: visible !important;
  }
}

  ', brand_colour, accent_colour, brand_colour,
     brand_colour, brand_colour, brand_colour,
     brand_colour, brand_colour,
     brand_colour, brand_colour,
     brand_colour, brand_colour)

  # The five-destination shell's CSS is appended rather than folded into the
  # sprintf above: R caps a format string at 8192 characters, and the bundle
  # is already close to it. This block needs no substitution because the
  # base rule set defines --br-brand.
  module_css <- paste0(module_css, '
/* === Five-destination shell ============================================== */
/* The category header control area is a slot system, not a fixed pair of
   controls: slot three is reserved and empty until a period selector is
   added for wave comparison. */
.br-controls {
  display: flex; flex-wrap: wrap; align-items: center; gap: 18px;
  padding: 10px 14px; margin-bottom: 14px;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;
}
.br-control-slot { display: flex; align-items: center; gap: 8px; position: relative; }
.br-control-slot-empty { display: none; }
.br-control-label { font-size: 11px; color: #64748b; text-transform: uppercase; letter-spacing: 0.6px; }
.br-control-static { font-size: 13px; font-weight: 600; color: #1e293b; }
.br-cat-select, .br-focal-select {
  font-size: 13px; padding: 5px 8px; border: 1px solid #cbd5e1;
  border-radius: 6px; background: #fff; color: #1e293b; max-width: 240px;
}
.br-cmp-trigger {
  font-size: 12px; padding: 5px 10px; border: 1px solid #cbd5e1;
  border-radius: 6px; background: #fff; color: #334155; cursor: pointer;
}
.br-cmp-trigger:hover { border-color: #94a3b8; }
.br-cmp-count {
  display: inline-block; min-width: 16px; padding: 0 5px; margin-left: 4px;
  border-radius: 9px; background: #e2e8f0; font-size: 11px; font-weight: 600;
}
/* The badge reads "shown of total", which is the one thing the words on the
   trigger leave out. It is hidden in the focal-only and all-brands states,
   where the words already pin the number down, and display:inline-block
   above outranks the browser default for [hidden], so it needs its own
   rule or it shows through in those two states. */
.br-cmp-count[hidden] { display: none; }
.br-cmp-popover {
  position: absolute; top: calc(100% + 6px); left: 0; z-index: 60;
  min-width: 240px; max-height: 320px; overflow-y: auto;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  box-shadow: 0 8px 24px rgba(15,23,42,0.12); padding: 10px 12px;
}
.br-cmp-head { font-size: 11px; color: #64748b; margin: 10px 0 6px; }
.br-cmp-item {
  display: flex; align-items: center; gap: 7px; padding: 3px 0;
  font-size: 13px; color: #1e293b; cursor: pointer;
}
.br-cmp-item input[disabled] + span { color: #94a3b8; }
.br-cmp-modes { display: flex; gap: 6px; }
.br-cmp-mode {
  flex: 1; font-size: 12px; padding: 5px 8px;
  border: 1px solid #e2e8f0; border-radius: 6px; background: #f8fafc;
  color: #475569; cursor: pointer;
}
.br-cmp-mode:hover { border-color: #cbd5e1; }
.br-cmp-mode.active {
  border-color: var(--br-brand); color: var(--br-brand); background: #fff;
  font-weight: 600;
}
/* In "all brands" mode the picks are not what is being shown, so the list
   says so rather than sitting there looking live. */
.br-cmp-list-off { opacity: 0.45; }

/* The category header control is the one place a reader chooses the focal
   brand and the comparison set. Every panel keeps its own focal select and
   its own brand filter in the DOM, because the header drives them and the
   panel JS binds to them, but they are not shown. The selector names the
   class alone, with no ancestor, so a pinned view or a PNG capture that is
   re-parented out of the destination hides them too. */
.br-header-governed { display: none !important; }

.br-destination-nav {
  display: flex; gap: 0; border-bottom: 1px solid #e2e8f0; margin-bottom: 20px;
  flex-wrap: wrap;
}
.br-destination-btn {
  background: none; border: none; border-bottom: 2px solid transparent;
  padding: 11px 18px; font-size: 13px; font-weight: 600; color: #94a3b8;
  cursor: pointer; transition: all 0.15s;
}
.br-destination-btn:hover { color: #64748b; }
.br-destination-btn.active { color: var(--br-brand); border-bottom-color: var(--br-brand); }
.br-destination { display: none; }
.br-destination.active { display: block; }
/* Inside a destination the host is always laid out: the destination
   container is what shows and hides, not the sub-panel. */
.br-destination .br-subpanel { display: block; }

/* Two tiers of disclosure, and they must not look alike. The drawer is a
   quiet section label with a rule above it; the items under it are list
   rows, indented and lighter. scroll-margin-top clears the sticky
   .br-tab-nav so an opened item lands under the tab bar, not behind it. */
.br-advanced { margin-top: 30px; border-top: 1px solid #e2e8f0; }
.br-advanced-toggle {
  display: flex; align-items: center; gap: 7px;
  width: 100%; text-align: left; font-size: 11px; font-weight: 700;
  letter-spacing: 0.9px; text-transform: uppercase; color: #94a3b8;
  background: none; border: none; padding: 12px 2px; cursor: pointer;
  scroll-margin-top: 64px;
}
/* The marker sits at the far edge, where a reader looks for it, rather
   than pushed up against the label. */
.br-advanced-toggle::after { margin-left: auto; letter-spacing: 0; }
.br-adv-toggle::after { float: right; }
.br-advanced-toggle:hover { color: #64748b; }
.br-advanced-toggle::after { content: " \\25BE"; }
.br-advanced-toggle[aria-expanded="true"]::after { content: " \\25B4"; }
.br-advanced-count {
  display: inline-block; padding: 0 6px;
  border-radius: 9px; background: #eef2f6; color: #64748b;
  font-size: 10px; font-weight: 700; letter-spacing: 0;
}
.br-advanced-body { margin-top: 2px; }
.br-adv-item { border-top: 1px solid #eef2f6; }
.br-adv-item:last-child { border-bottom: 1px solid #eef2f6; }
.br-adv-toggle {
  display: block; width: 100%; text-align: left; font-size: 13px;
  font-weight: 600; color: #334155; background: none; border: none;
  padding: 12px 2px 12px 15px; cursor: pointer; scroll-margin-top: 64px;
}
.br-adv-toggle:hover { color: var(--br-brand); }
.br-adv-toggle::after { content: " \\25BE"; color: #94a3b8; }
.br-adv-toggle[aria-expanded="true"]::after { content: " \\25B4"; }
/* A drawer holding one item needs one disclosure, so its heading is a
   heading and carries no marker. */
.br-adv-static { cursor: default; color: #475569; }
.br-adv-static::after { content: ""; }
.br-adv-body { margin: 0 0 18px 15px; }

.br-overview-stub {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  padding: 20px 24px; margin-bottom: 16px;
}
.br-overview-stub p { font-size: 13px; color: #64748b; margin: 4px 0 14px; }
.br-overview-stub-btn {
  font-size: 13px; font-weight: 600; padding: 8px 14px;
  border: 1px solid #cbd5e1; border-radius: 6px; background: #f8fafc;
  color: #334155; cursor: pointer;
}

')

  # Chart brands: the per-chart deviation from the header set. The rules come
  # from the widget that emits the markup, so the two cannot drift apart, and
  # they land in the page's own stylesheet rather than a panel's. Every one of
  # them names its class with no ancestor: a rule scoped under a panel or a
  # destination would look right on screen and vanish from a pin, which is the
  # one place the deviation note has to survive.
  if (exists("build_chart_focus_styles", mode = "function")) {
    module_css <- paste0(
      module_css,
      "\n/* === Chart brands ====================================== */\n",
      build_chart_focus_styles(), "\n")
  }

  # --- Panels ---
  category_names <- names(results$results$categories)
  # Build per-category lookup maps (key = category display-name key).
  # display_map: human-readable label for tab buttons and section headings.
  # code_map:    CategoryCode used for HTML element IDs (must match transformer).
  cat_display_map <- stats::setNames(
    vapply(category_names, function(cn) {
      cr <- results$results$categories[[cn]]
      cr$category %||% cn
    }, character(1L)),
    category_names
  )
  cat_code_map <- stats::setNames(
    vapply(category_names, function(cn) {
      cr <- results$results$categories[[cn]]
      cr$cat_code %||% cn
    }, character(1L)),
    category_names
  )
  # Only include deep-dive categories (those with MA data)
  deep_cats <- character(0)
  for (cn in category_names) {
    cr <- results$results$categories[[cn]]
    has_content <- !is.null(cr$mental_availability) || !is.null(cr$funnel)
    if (has_content) deep_cats <- c(deep_cats, cn)
  }

  # panel_parts = accumulator of per-panel HTML fragments
  # (disambiguated from the `panels` parameter which is a lookup keyed by
  # element_categoryid for dedicated role-registry panel HTML).
  panel_parts <- character(0)
  # Executive Summary panel (v2). The new builder lives in
  # panels/14_summary_panel.R; the legacy build_br_summary_panel is kept as
  # a fallback when the panel file failed to source.
  if (exists("build_brand_summary_panel", mode = "function")) {
    panel_parts <- c(panel_parts, build_brand_summary_panel(results, config))
  } else {
    panel_parts <- c(panel_parts, build_br_summary_panel(results, config))
  }

  # The persistent category switcher lists full-depth categories only.
  # Awareness-only categories produce no category panel and stay on the
  # Portfolio tab, where they already live (impact map section 9 item 6).
  category_choices <- lapply(deep_cats, function(ck) {
    cr <- results$results$categories[[ck]]
    list(id    = gsub("[^a-z0-9]", "-", tolower(cr$cat_code %||% ck)),
         label = cat_display_map[[ck]] %||% cr$category %||% ck)
  })

  for (cat_key in deep_cats) {
    cr_entry    <- results$results$categories[[cat_key]]
    cat_display <- cat_display_map[[cat_key]]
    panel_parts <- c(panel_parts, build_br_category_panel(
      cat_key, cr_entry,
      charts, tables, config, panels = panels,
      cat_display_name = cat_display,
      category_choices = category_choices,
      cat_brands = .br_brands_for_cat(results, cr_entry, cat_key)
    ))
  }

  # Brand-level panels
  # DBA renders as a modern panel built in transform_brand_panels()
  # and stored at panels[["dba"]]. The br-panel wrapper preserves the
  # existing nav-id ("panel-dba") so report navigation continues working.
  if (isTRUE(config$element_dba) && !is.null(panels[["dba"]])) {
    panel_parts <- c(panel_parts,
      '<div class="br-panel" id="panel-dba">',
      panels[["dba"]],
      '</div>')
  }

  # WOM is now per-category (sub-tab inside each category panel).
  # No brand-level WOM panel.

  if (isTRUE(config$element_portfolio))
    panel_parts <- c(panel_parts, build_br_portfolio_panel(results, config))

  # Demographics + Ad Hoc render as per-category sub-tabs inside each
  # category panel (see build_br_category_panel), no separate top-level
  # panels.

  panel_parts <- c(panel_parts, build_br_pinned_panel())
  panel_parts <- c(panel_parts, build_br_about_panel(config))

  # --- Assemble page ---
  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="turas-report-type" content="brand">
  <meta name="turas-source-filename" content="%s">
  <title>%s</title>
  <style>%s\n%s</style>
  %s
</head>
<body>
  %s
  %s
  <div class="br-container">%s</div>
  %s
  %s
  <script>%s</script>
  <script>%s</script>
  <script>%s</script>
</body>
</html>',
    .br_esc(config$report_title %||% "brand_report"),
    .br_esc(config$report_title %||% "Brand Health Report"),
    base_css, module_css,
    panel_styles,
    build_br_header(config),
    build_br_tab_nav(deep_cats, config, display_map = cat_display_map,
                     code_map = cat_code_map),
    paste(panel_parts, collapse = "\n"),
    build_br_help_overlay(),
    "",
    pins_js,
    brand_js,
    panel_js
  )
}
