# ==============================================================================
# BRAND MODULE - AD HOC PANEL HTML RENDERER
# ==============================================================================
# Emits the Ad Hoc tab's HTML fragment. Layout:
#
#   [Sub-tab nav]: one tab per scope (ALL + each category present)
#   [Per-scope panel]:
#     [Question chip strip — show/hide individual questions]
#     [Per-question card]:
#       - Question label
#       - Total horizontal-bar table (with Wilson CI overlay toggle)
#       - Brand heatmap (when brand pen data is available for this scope)
#       - Per-card pin + PNG buttons
#
# Reuses the demographics panel CSS for tables, chips and heatmap colouring;
# only adds a small ad-hoc-specific stylesheet for the scope subnav.
#
# VERSION: 1.0
# ==============================================================================

BRAND_ADHOC_PANEL_VERSION <- "1.0"


#' Build ad-hoc panel HTML
#'
#' @param panel_data List from \code{build_adhoc_panel_data()}.
#' @param panel_id Character. Element id (e.g. "adhoc-panel"). Used to scope
#'   sub-element ids and JS dispatch.
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @return Character. Single HTML fragment.
#' @export
build_adhoc_panel_html <- function(panel_data,
                                    panel_id = "adhoc-panel",
                                    focal_colour = "#1A5276") {

  if (is.null(panel_data) ||
      identical(panel_data$meta$status %||% "", "REFUSED") ||
      identical(panel_data$meta$status %||% "", "EMPTY") ||
      length(panel_data$scopes) == 0L) {
    return(.adhoc_panel_empty_state(panel_data))
  }

  panel_id     <- gsub("[^A-Za-z0-9_-]", "-", panel_id)
  json_payload <- .adhoc_panel_json(panel_data)

  paste0(
    sprintf(
      '<div class="adhoc-panel demo-panel" id="%s" data-focal-colour="%s">',
      panel_id, .adhoc_esc(focal_colour)),
    sprintf('<script type="application/json" class="adhoc-panel-data">%s</script>',
            json_payload),
    .adhoc_panel_header(panel_data),
    .adhoc_panel_scopenav(panel_data, panel_id),
    .adhoc_panel_scope_sections(panel_data, panel_id, focal_colour),
    .adhoc_panel_insight_box(),
    '</div>'
  )
}


# ==============================================================================
# EMPTY STATE
# ==============================================================================

.adhoc_panel_empty_state <- function(pd) {
  msg <- (pd$meta$message) %||%
         "No ad hoc questions configured. Add adhoc.<key>.<scope> rows to the QuestionMap sheet in Survey_Structure.xlsx."
  sprintf(
    '<div class="adhoc-panel-empty" style="padding:32px;text-align:center;color:#94a3b8;font-size:14px;">%s</div>',
    .adhoc_esc(msg))
}


# ==============================================================================
# HEADER
# ==============================================================================

.adhoc_panel_header <- function(pd) {
  n_q <- pd$meta$n_questions %||% 0L
  n_s <- pd$meta$n_scopes    %||% 0L
  sprintf(
    '<header class="demo-panel-header">
       <div class="demo-panel-header-title">Ad Hoc Questions</div>
       <div class="demo-panel-header-sub">%d question%s across %d scope%s</div>
     </header>',
    n_q, if (n_q == 1L) "" else "s",
    n_s, if (n_s == 1L) "" else "s")
}


# ==============================================================================
# SCOPE SUB-NAV (one tab per ALL + category)
# ==============================================================================

.adhoc_panel_scopenav <- function(pd, panel_id) {
  btns <- vapply(seq_along(pd$scopes), function(i) {
    sc <- pd$scopes[[i]]
    active <- if (i == 1L) " active" else ""
    sprintf(
      '<button type="button" class="adhoc-scope-btn%s" data-adhoc-scope="%s">%s <span class="adhoc-scope-count">%d</span></button>',
      active, .adhoc_esc(sc$scope_code), .adhoc_esc(sc$scope_label),
      sc$n_questions)
  }, character(1L))
  sprintf('<nav class="adhoc-scopenav demo-subnav" data-scope="%s">%s</nav>',
          .adhoc_esc(panel_id), paste(btns, collapse = ""))
}


# ==============================================================================
# SCOPE SECTIONS (one section per scope; first visible, rest hidden)
# ==============================================================================

.adhoc_panel_scope_sections <- function(pd, panel_id, focal_colour) {
  sections <- vapply(seq_along(pd$scopes), function(i) {
    sc <- pd$scopes[[i]]
    .adhoc_panel_one_scope(sc, panel_id, focal_colour, hidden = (i != 1L))
  }, character(1L))
  paste(sections, collapse = "")
}


.adhoc_panel_one_scope <- function(sc, panel_id, focal_colour, hidden) {
  scope_id <- sprintf("%s-scope-%s", panel_id,
                       gsub("[^A-Za-z0-9_-]", "-", sc$scope_code))
  hidden_attr <- if (isTRUE(hidden)) " hidden" else ""

  if (length(sc$questions) == 0L) {
    body <- '<div class="demo-empty">No ad hoc questions in this scope.</div>'
  } else {
    chips <- vapply(seq_along(sc$questions), function(j) {
      q <- sc$questions[[j]]
      label <- q$short_label %||% q$question_text %||% q$role
      sprintf(
        '<button type="button" class="demo-q-chip active" data-adhoc-q-idx="%d" data-adhoc-scope="%s" title="%s">%s</button>',
        j - 1L, .adhoc_esc(sc$scope_code),
        .adhoc_esc(q$question_text %||% label), .adhoc_esc(label))
    }, character(1L))
    chip_row <- paste0(
      '<div class="demo-chip-row">',
      '<span class="demo-chip-row-label">Show:</span>',
      paste(chips, collapse = ""),
      '</div>')

    cards <- vapply(seq_along(sc$questions), function(j) {
      .adhoc_panel_question_card(sc$questions[[j]], j - 1L, scope_id,
                                  sc, focal_colour)
    }, character(1L))
    body <- paste0(chip_row,
                   sprintf('<div class="demo-card-grid">%s</div>',
                           paste(cards, collapse = "")))
  }

  sprintf(
    '<section class="adhoc-scope-section" id="%s" data-adhoc-scope="%s"%s>%s</section>',
    .adhoc_esc(scope_id), .adhoc_esc(sc$scope_code), hidden_attr, body)
}


# ==============================================================================
# QUESTION CARD
# ==============================================================================

.adhoc_panel_question_card <- function(q, idx, scope_id, sc, focal_colour) {
  section_id <- sprintf("section-%s-q%d", scope_id, idx)
  brand_picker <- .adhoc_panel_brand_picker(sc, idx)

  body <- .adhoc_panel_total_body(q, focal_colour, 0L)

  sprintf(
    '<article class="demo-card adhoc-card br-element-section" id="%s" data-section="%s" data-adhoc-q-idx="%d">
       <header class="demo-card-header">
         <div class="demo-card-titlebar">
           <h3 class="demo-card-title br-element-title">%s</h3>
           %s
         </div>
         <div class="demo-card-sub">%s &middot; n = %s</div>
       </header>
       %s
       <div class="demo-card-body" data-pin-as-table>
         %s
       </div>
     </article>',
    .adhoc_esc(section_id), .adhoc_esc(section_id), idx,
    .adhoc_esc(q$short_label %||% q$question_text),
    .adhoc_panel_card_toolbar(section_id),
    .adhoc_esc(q$question_text %||% ""),
    .adhoc_int(q$n_total),
    brand_picker, body)
}


.adhoc_panel_total_body <- function(q, focal_colour, dp) {
  rows <- q$total$rows %||% list()
  if (length(rows) == 0L) {
    return('<div class="demo-empty">No responses for this question.</div>')
  }
  max_pct <- max(vapply(rows, function(r) r$pct %||% 0, numeric(1L)), na.rm = TRUE)
  if (!is.finite(max_pct) || max_pct <= 0) max_pct <- 1
  bars <- vapply(rows, function(r) {
    pct      <- r$pct %||% NA_real_
    bar_w    <- if (is.finite(pct)) max(2, 100 * pct / max_pct) else 0
    pct_disp <- .adhoc_pct(pct, dp)
    ci_lo    <- .adhoc_pct(r$ci_lower %||% NA_real_, dp)
    ci_hi    <- .adhoc_pct(r$ci_upper %||% NA_real_, dp)
    sprintf(
      '<tr>
         <td class="demo-row-label">%s</td>
         <td class="demo-row-bar"><div class="demo-row-bar-fill" style="width:%.1f%%;background-color:%s"></div></td>
         <td class="demo-row-pct">%s</td>
         <td class="demo-row-ci">[%s &ndash; %s]</td>
         <td class="demo-row-n">%s</td>
       </tr>',
      .adhoc_esc(r$label %||% r$code), bar_w, .adhoc_esc(focal_colour),
      pct_disp, ci_lo, ci_hi, .adhoc_int(r$n))
  }, character(1L))
  sprintf(
    '<table class="demo-table">
       <thead><tr>
         <th>Option</th><th></th><th>%%</th><th class="demo-ci-col">95%% CI</th><th>n</th>
       </tr></thead>
       <tbody>%s</tbody>
     </table>',
    paste(bars, collapse = ""))
}


.adhoc_panel_brand_picker <- function(sc, idx) {
  bcs <- sc$brand_codes  %||% character(0)
  bls <- sc$brand_labels %||% bcs
  if (length(bcs) == 0L) return("")
  chips <- vapply(seq_along(bcs), function(i) {
    active <- if (i == 1L) " active" else ""
    sprintf('<button type="button" class="demo-brand-chip%s" data-demo-brand="%s">%s</button>',
            active, .adhoc_esc(bcs[i]), .adhoc_esc(bls[i]))
  }, character(1L))
  sprintf(
    '<div class="demo-brand-picker adhoc-brand-picker" hidden data-adhoc-q-idx="%d">
       <span class="demo-brand-picker-label">Brand:</span>
       %s
     </div>', idx, paste(chips, collapse = ""))
}


.adhoc_panel_card_toolbar <- function(section_id) {
  sprintf(
    '<div class="demo-card-toolbar" data-section="%s">
       <button type="button" class="br-pin-btn demo-card-pin" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin this card">&#x1F4CC;</button>
       <button type="button" class="br-png-btn demo-card-png" onclick="brExportPng(\'%s\',this)" title="Export PNG of this card">&#x1F5BC;</button>
       <button type="button" class="demo-ci-btn" data-section="%s" title="Toggle 95%% CI display">CI</button>
       <button type="button" class="adhoc-brand-toggle" data-section="%s" title="Show brand heatmap">By brand</button>
     </div>',
    .adhoc_esc(section_id), .adhoc_esc(section_id),
    .adhoc_esc(section_id), .adhoc_esc(section_id),
    .adhoc_esc(section_id), .adhoc_esc(section_id))
}


.adhoc_panel_insight_box <- function() {
  '<section class="adhoc-insight-box ma-insight-box">
     <div class="ma-insight-box-header">
       <span class="ma-insight-box-title">Insight</span>
       <button type="button" class="ma-insight-box-clear" data-adhoc-action="clear-insight" title="Clear">&#215;</button>
     </div>
     <textarea class="ma-insight-box-text" placeholder="Headline insight for the Ad Hoc tab&hellip;"></textarea>
   </section>'
}


# ==============================================================================
# HELPERS
# ==============================================================================

.adhoc_pct <- function(v, dp) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return('<span class="demo-na">&mdash;</span>')
  sprintf("%.*f%%", as.integer(dp), v)
}

.adhoc_int <- function(v) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return("&mdash;")
  format(as.integer(round(v)), big.mark = ",")
}

.adhoc_panel_json <- function(pd) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  jsonlite::toJSON(pd, auto_unbox = TRUE, na = "null", null = "null",
                   pretty = FALSE, digits = 6)
}

.adhoc_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# CSS (additive — relies on demographics panel CSS for shared classes)
# ==============================================================================

#' Build ad-hoc panel CSS
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character. CSS string (no <style> tags).
#' @export
build_adhoc_panel_styles <- function(focal_colour = "#1A5276") {
  template <- "
.adhoc-panel { font: 13px/1.45 system-ui, -apple-system, Segoe UI, sans-serif; color: #1e293b; }
.adhoc-panel-empty { font-style: italic; }

.adhoc-scope-count {
  display: inline-block; min-width: 18px; padding: 0 5px;
  margin-left: 6px; font-size: 10px; line-height: 16px;
  border-radius: 8px; background: rgba(0,0,0,.08); color: inherit;
}
.adhoc-scope-btn.active .adhoc-scope-count { background: rgba(255,255,255,.25); }

.adhoc-scope-section { margin-top: 4px; }
.adhoc-scope-section[hidden] { display: none; }

.adhoc-brand-toggle {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 6px; cursor: pointer;
  padding: 3px 7px; font-size: 11px; line-height: 1; color: #64748b;
}
.adhoc-brand-toggle:hover { background: #f1f5f9; border-color: #cbd5e1; color: #0f172a; }
.adhoc-brand-toggle.active { background: __FOCAL__; border-color: __FOCAL__; color: #fff; }
"
  gsub("__FOCAL__", focal_colour, template, fixed = TRUE)
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
