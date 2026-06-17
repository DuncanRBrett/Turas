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
  #   Portfolio (when enabled) — cross-cat lens comes first so the reader
  #     opens on the brand's whole-portfolio picture before drilling in.
  #   Summary — per-cat snapshot for any picked category.
  #   Per-category tabs — order driven by the Categories sheet in
  #     Brand_Config.xlsx; reorder rows there to change tab order.
  #   Brand Assets (when enabled).
  #   Pinned Views, About — always trailing.
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
#'   Insight" toggle + insight container are emitted — the pin / PNG /
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
  # the rendered CSS is invalid and the browser silently drops the rule —
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
      } else "\u2014"
      mpen_val <- if (!is.null(ma) && !is.null(ma$metrics_summary$focal_mpen)) {
        sprintf("%.0f%%", ma$metrics_summary$focal_mpen * 100)
      } else "\u2014"
      aware_val <- if (!is.null(funnel) &&
                        !is.null(funnel$metrics_summary$focal_by_stage$aware)) {
        sprintf("%.0f%%", 100 * funnel$metrics_summary$focal_by_stage$aware)
      } else "\u2014"

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


# Sub-tabs that make up the "category story" an analyst presents (Level 2 of
# the three-level IA). Every other sub-tab is demoted to the on-demand
# "Detail" appendix (Level 3). Single source of truth — edit this vector to
# re-tier the per-category sub-tab nav. The order here is also the display
# order of the primary tabs. See docs/PHASE1_CLARITY_IMPLEMENTATION_PLAN.md.
.BR_PRIMARY_SUBTABS <- c("fn-funnel", "ma-metrics", "rep", "wom")


#' Render the per-category sub-tab nav, tiered into primary + appendix
#'
#' Primary "category story" tabs (see \code{.BR_PRIMARY_SUBTABS}) are emitted
#' first, in that vector's order, followed by a muted "Detail" divider and the
#' remaining tabs (the on-demand appendix) in their original order. Every
#' button keeps the class and \code{data-*} attributes the JS switcher
#' (\code{switchCategorySubtab}) relies on, so switching behaviour is
#' unchanged — only grouping, order, and emphasis change.
#'
#' Load-state safety: tiering only engages when the active-on-load tab
#' (\code{flat_tabs[[1]]}, always "fn-funnel" when a Brand Funnel is derived)
#' is itself a primary tab. Otherwise the original flat order is rendered
#' unchanged, so the sub-panel shown on first paint is never altered.
#'
#' @param flat_tabs List of tab specs, each a list with elements key, label,
#'   subpanel, internal_tab. Order as built by build_br_category_panel().
#' @param cat_id Character. Category id used as the data-group value.
#' @return Character. The .br-subtab-nav HTML, or "" when flat_tabs is empty.
#' @keywords internal
build_br_subtab_nav <- function(flat_tabs, cat_id) {
  n <- length(flat_tabs)
  if (n == 0L) return("")
  keys <- vapply(flat_tabs, function(t) t$key, character(1L))
  active_key <- keys[1L]

  btn <- function(t, is_active, is_appendix) sprintf(
    '<button class="br-subtab-btn%s%s" data-group="%s" data-subtab="%s" data-subpanel="%s" data-internal-tab="%s" onclick="switchCategorySubtab(this)">%s</button>',
    if (isTRUE(is_active)) " active" else "",
    if (isTRUE(is_appendix)) " br-subtab-btn--appendix" else "",
    cat_id, t$key, t$subpanel, t$internal_tab, t$label)

  # No tiering when the on-load tab is not itself primary (e.g. a category
  # with no derived funnel) — preserve the original order + active sub-panel.
  if (!(active_key %in% .BR_PRIMARY_SUBTABS)) {
    btns <- vapply(seq_len(n), function(i) btn(flat_tabs[[i]], i == 1L, FALSE),
                   character(1L))
    return(sprintf('<div class="br-subtab-nav">%s</div>',
                   paste(btns, collapse = "\n")))
  }

  is_prim  <- keys %in% .BR_PRIMARY_SUBTABS
  prim_idx <- which(is_prim)
  prim_idx <- prim_idx[order(match(keys[prim_idx], .BR_PRIMARY_SUBTABS))]
  apx_idx  <- which(!is_prim)   # appendix tabs keep their original order

  out <- vapply(prim_idx,
                function(i) btn(flat_tabs[[i]], keys[i] == active_key, FALSE),
                character(1L))
  if (length(apx_idx) > 0L) {
    # Appendix ("detail") tabs follow the primary tabs directly — no divider
    # and no label. A CSS gap before the first appendix tab (adjacency rule in
    # build_brand_page) sets them apart, and they render muted.
    out <- c(out,
      vapply(apx_idx, function(i) btn(flat_tabs[[i]], FALSE, TRUE),
             character(1L)))
  }
  sprintf('<div class="br-subtab-nav">%s</div>', paste(out, collapse = "\n"))
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
                                     cat_display_name = NULL) {
  # cat_id is based on CategoryCode when available (same as transformer) so
  # that panel lookup keys in the `panels` list match element IDs in the page.
  cat_id <- gsub("[^a-z0-9]", "-",
                 tolower(cat_results$cat_code %||% cat_name))
  panel_id <- paste0("cat-", cat_id)
  # Use the human-readable display name for labels; fall back to the key.
  cat_name <- cat_display_name %||% cat_results$category %||% cat_name

  # Local helper — looks up the optional pre-filled insight text from the
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
  # Drivers & Barriers HTML tab is retired — the focal-brand view on the
  # Mental Advantage sub-tab carries the same diagnostic. The engine in
  # 06_drivers_barriers.R still runs; its Importance / IxP / Competitive
  # Advantage / Rejection sheets continue to write to Excel and CSV.

  # Build flat sub-tab list in the required display order.
  # Each entry: key (unique), label, subpanel (which .br-subpanel to show),
  # internal_tab (which internal panel tab to switch to, "" = n/a).
  flat_tabs <- list()
  if (has_funnel) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "fn-funnel",       label = "Brand Funnel",
                subpanel = "fn",  internal_tab = "funnel")),
      list(list(key = "fn-relationship", label = "Brand Attitude",
                subpanel = "fn",  internal_tab = "relationship"))
    )
  }
  if (has_ma) {
    has_ma_advantage <- !is.null(cat_results$mental_availability) && (
      !is.null(cat_results$mental_availability$cep_advantage) ||
      !is.null(cat_results$mental_availability$attribute_advantage))
    flat_tabs <- c(flat_tabs,
      list(list(key = "ma-attributes",   label = "Brand Attributes",
                subpanel = "ma",  internal_tab = "attributes")),
      list(list(key = "ma-ceps",         label = "Category Entry Points",
                subpanel = "ma",  internal_tab = "ceps"))
    )
    if (has_ma_advantage) {
      flat_tabs <- c(flat_tabs,
        list(list(key = "ma-advantage",  label = "Mental Advantage",
                  subpanel = "ma",  internal_tab = "advantage")))
    }
    flat_tabs <- c(flat_tabs,
      list(list(key = "ma-metrics",      label = "MA Metrics",
                subpanel = "ma",  internal_tab = "metrics"))
    )
  }
  if (has_repertoire) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "rep",             label = "Category Buying",
                subpanel = "rep", internal_tab = ""))
    )
  }
  if (has_wom) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "wom",             label = "Word of Mouth",
                subpanel = "wom", internal_tab = ""))
    )
  }
  if (has_branded_reach) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "branded_reach",   label = "Branded Reach",
                subpanel = "br", internal_tab = ""))
    )
  }
  if (has_demographics) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "demographics",    label = "Demographics",
                subpanel = "demo", internal_tab = ""))
    )
  }
  if (has_adhoc) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "adhoc",           label = "Ad Hoc",
                subpanel = "ah", internal_tab = ""))
    )
  }
  if (has_audience_lens) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "audience_lens",   label = "Audience Lens",
                subpanel = "al", internal_tab = ""))
    )
  }

  # Sub-tab navigation bar — primary "category story" tabs first, then a
  # muted "Detail" divider introducing the on-demand appendix tabs. See
  # build_br_subtab_nav() + .BR_PRIMARY_SUBTABS for the tiering contract.
  if (length(flat_tabs) > 0) {
    parts <- c(parts, build_br_subtab_nav(flat_tabs, cat_id))
  }

  # One sub-panel per element. Active sub-panel = the one containing the first tab.
  first_subpanel <- if (length(flat_tabs) > 0) flat_tabs[[1]]$subpanel else ""

  # Element map: subpanel key → element name used for chart/panel lookup keys
  element_map <- list()
  if (has_funnel)        element_map[["fn"]]  <- "funnel"
  if (has_ma)            element_map[["ma"]]  <- "ma"
  if (has_repertoire)    element_map[["rep"]] <- "repertoire"
  if (has_wom)           element_map[["wom"]] <- "wom"
  if (has_branded_reach) element_map[["br"]]  <- "branded_reach"
  if (has_demographics)  element_map[["demo"]] <- "demographics"
  if (has_adhoc)         element_map[["ah"]]  <- "adhoc"
  if (has_audience_lens) element_map[["al"]]  <- "audience_lens"

  for (sp_key in names(element_map)) {
    el        <- element_map[[sp_key]]
    active    <- if (sp_key == first_subpanel) " active" else ""
    section_id <- paste0(el, "-", cat_id)
    chart_key  <- paste0(el, "_", cat_id)

    parts <- c(parts, sprintf(
      '<div class="br-subpanel%s" data-group="%s" data-subpanel="%s">',
      active, cat_id, sp_key))
    parts <- c(parts, sprintf(
      '<div class="br-element-section" id="section-%s" data-section="%s">',
      section_id, section_id))

    if (!is.null(panels[[chart_key]])) {
      # WOM, branded-reach, repertoire/cat-buying, funnel, and MA panels
      # all get the shared section toolbar prepended. Funnel and MA also
      # render their own internal pin/PNG controls (different position) \u2014
      # the shared toolbar carries the insight editor which the embedded
      # controls do not.
      if (el == "wom") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Word of Mouth \u2014 %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "branded_reach") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Branded Reach \u2014 %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "demographics") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Demographics \u2014 %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "adhoc") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Ad Hoc Questions \u2014 %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "audience_lens") {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Audience Lens \u2014 %s</h3>',
          .br_esc(cat_name)))
      } else if (el == "funnel" || el == "ma") {
        # Per-sub-tab insight toolbars. The funnel panel has 2 internal
        # sub-tabs (funnel / relationship) and the MA panel has 4 (attributes
        # / advantage / ceps / metrics). Emit one toolbar per sub-tab, tagged
        # with data-insight-internal-tab so the JS sub-tab switcher
        # (brand_report.js::switchCategorySubtab) can hide all but the active
        # one. Anchors: <internal-tab>-<cat_id>, e.g. funnel-bak, ceps-pos.
        #
        # omit_chart_buttons=TRUE — the panel itself emits its own pin /
        # PNG / Excel toolbar (data-fn-action="pindropdown" /
        # ma-pin-dropdown-btn), so we render only the Add/Edit Insight
        # toggle here to avoid duplicate pin buttons. The panel pin
        # dropdowns read .br-insight-editor from the parent section so
        # the Section_Insights text still pins correctly.
        sub_specs <- if (el == "funnel") {
          list(
            list(anchor_el = "funnel",       internal = "funnel"),
            list(anchor_el = "attitude",     internal = "relationship")
          )
        } else {
          list(
            list(anchor_el = "attributes",   internal = "attributes"),
            list(anchor_el = "advantage",    internal = "advantage"),
            list(anchor_el = "ceps",         internal = "ceps"),
            list(anchor_el = "metrics",      internal = "metrics")
          )
        }
        for (i in seq_along(sub_specs)) {
          sp <- sub_specs[[i]]
          sub_anchor <- paste0(sp$anchor_el, "-", cat_id)
          parts <- c(parts, build_br_section_toolbar(
            section_id         = sub_anchor,
            prefill_text       = section_insight_for(config$section_insights,
                                                     sub_anchor),
            internal_tab       = sp$internal,
            initial_visible    = (i == 1L),
            omit_chart_buttons = TRUE))
        }
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
          '<h3 class="br-element-title">Word of Mouth \u2014 %s</h3>',
          .br_esc(cat_name)))
        parts <- c(parts, panels[[wom_key]])
      } else {
        parts <- c(parts, toolbar_for(section_id))
        parts <- c(parts, sprintf(
          '<h3 class="br-element-title">Word of Mouth \u2014 %s</h3>',
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
      cb_panel_key <- paste0("cat_buying_", cat_id)

      if (!is.null(panels[[cb_panel_key]])) {
        # New Dirichlet panel — self-contained HTML fragment.
        # Layout overrides (per design request):
        #   - Pin + Export emitted at top with class cb-toolbar-top so JS can
        #     relocate them into the Brand Summary controls bar (right side).
        #   - No redundant h3 title or timeframe subtitle.
        #   - +Add Insight button moved BELOW the panel, full width.
        parts <- c(parts, sprintf('
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
        cb_insight_text <- section_insight_for(config$section_insights,
                                               section_id)
        cb_has <- nzchar(cb_insight_text)
        # Single % — see note in build_br_section_toolbar above.
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

        parts <- c(parts, sprintf('
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
          '<h3 class="br-element-title">Category Buying \u2014 %s</h3>',
          .br_esc(cat_name)))

        cbf <- cat_results$cat_buying_frequency
        if (!is.null(cbf) && !identical(cbf$status, "REFUSED")) {
          pct_b  <- if (!is.null(cbf$pct_buyers) && !is.na(cbf$pct_buyers))
            sprintf("%.0f%%", cbf$pct_buyers) else "\u2014"
          mfreq  <- if (!is.null(cbf$mean_freq) && !is.na(cbf$mean_freq))
            sprintf("%.1f\u00d7/month", cbf$mean_freq) else "\u2014"
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

        if (!is.null(charts[[chart_key]])) {
          for (ch in charts[[chart_key]]) {
            parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
          }
        }
        if (!is.null(tables[[chart_key]])) {
          parts <- c(parts, tables[[chart_key]])
        }
      }
    } else {
      # Legacy path: any future elements without a dedicated panel
      parts <- c(parts, toolbar_for(section_id))
      if (!is.null(charts[[chart_key]])) {
        for (ch in charts[[chart_key]]) {
          parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
        }
      }
      if (!is.null(tables[[chart_key]])) {
        parts <- c(parts, tables[[chart_key]])
      }
    }

    parts <- c(parts, '</div></div>')
  }

  parts <- c(parts, '</div>')
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
  brand_colour <- config$colour_focal %||% "#1A5276"

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
  # Both keys can appear in config$section_insights — the resolver passes
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
      sprintf("%.0f%%", usage_pct) else "\u2014"
    aware_str <- if (!is.null(init_aw) && is.finite(init_aw))
      sprintf("%.0f%%", init_aw) else "\u2014"

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
  var section = document.getElementById("section-%s");
  if (!section) return;
  var brandColour = "%s";
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
      if (cell) cell.textContent = (val != null && isFinite(val)) ? Math.round(val) + "%%" : "\u2014";
    });
  });
})();
</script>', section_id, brand_colour))
  }

  parts <- c(parts, '</div>')  # element-section

  # Future sections placeholder
  parts <- c(parts, '
<div class="br-element-section" style="margin-top:16px;">
  <h3 class="br-element-title">Portfolio Optimisation \u2014 Coming Soon</h3>
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
/* Three-level IA: the on-demand "detail" sub-tabs follow the primary
   "category story" tabs after a gap and render muted — no divider, no label.
   The gap lands on the first appendix tab via the adjacency selector (an
   appendix button immediately preceded by a primary button). */
.br-subtab-btn:not(.br-subtab-btn--appendix) + .br-subtab-btn--appendix {
  margin-left: 28px;
}
.br-subtab-btn--appendix:not(.active) { color: #cbd5e1; }
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
/* 2-layer nav: internal panel sub-navbars are hidden — their tabs are
   promoted to the category-level .br-subtab-nav. The internal nav HTML
   is kept in the DOM so JS click-dispatch still works. */
.fn-subnav, .ma-subnav { display: none !important; }

/* === PINNED CARD (br-pinned-*) — matches conjoint/tabs visual standard === */
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
}
  ', brand_colour, accent_colour, brand_colour,
     brand_colour, brand_colour, brand_colour,
     brand_colour, brand_colour,
     brand_colour, brand_colour,
     brand_colour, brand_colour)

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

  for (cat_key in deep_cats) {
    cr_entry    <- results$results$categories[[cat_key]]
    cat_display <- cat_display_map[[cat_key]]
    panel_parts <- c(panel_parts, build_br_category_panel(
      cat_key, cr_entry,
      charts, tables, config, panels = panels,
      cat_display_name = cat_display
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
  # category panel (see build_br_category_panel) — no separate top-level
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
