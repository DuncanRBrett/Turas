# ==============================================================================
# BRAND MODULE - MA PANEL: MENTAL ADVANTAGE SUB-TAB
# ==============================================================================
# Server-emits the HTML scaffolding for the Mental Advantage sub-tab.
# All three views (strategic quadrant, diverging matrix heatmap, action
# list) are populated by brand_ma_advantage.js from the JSON payload
# embedded by build_ma_panel_html(): same render-on-change pattern used
# by the MMSxNS scatter and CEP-ranking bar chart.
#
# Romaniuk's Mental Advantage isolates a brand's true competitive
# strength on a stimulus by removing two confounds: brand size effects
# and prototypicality. Cells are coloured by the +/- threshold (default
# 5pp) and the chi-square standardised residual flags significance.
#
# REFERENCES:
#   Romaniuk, J. (2022). Better Brand Health.
#   Quantilope (2024). Mental Advantage Analysis.
# ==============================================================================


#' Build the Mental Advantage sub-tab HTML.
#'
#' @param pd Panel data list from \code{build_ma_panel_data()}.
#' @param focal_colour Character. Hex colour for focal accents.
#' @param part Character. \code{"main"} for the quadrant and the action list,
#'   which the impact map puts in Mental Availability's main view, or
#'   \code{"detail"} for the full matrix, the buyer-gap diagnostic and the
#'   methodology, which it puts in the Advanced drawer.
#' @return Character. HTML fragment, or empty string when no advantage data.
#' @export
build_ma_advantage_section <- function(pd, focal_colour = "#1A5276",
                                       part = "main") {
  adv <- pd$advantage
  if (is.null(adv) || length(adv$available_stims) == 0) {
    return(.ma_adv_empty_state())
  }

  # Two parts, because the impact map's destination summary puts the
  # quadrant and the action list in Mental Availability's main view and the
  # full matrix, the buyer-gap diagnostic and the MA methodology in its
  # Advanced drawer. Each part is rendered into its own .ma-panel host, and
  # brand_ma_advantage.js already guards every view it renders on the view
  # being present, so a host renders exactly what it holds.
  #
  # Each part carries its own controls bar, because a control belongs beside
  # the view it governs: Show chart governs the quadrant, Show counts and the
  # Excel export govern the matrix, and the stimulus toggle governs both. The
  # two stimulus toggles are kept in step by a document event, so the matrix
  # in the drawer can never be showing attributes while the quadrant above it
  # shows CEPs.
  #
  # Callouts sit next to the thing they explain until the destination's
  # "How this works" drawer collects them at load, and there is one such
  # drawer per tier, so the methodology follows the matrix into Advanced.
  detail <- identical(part, "detail")
  paste0(
    sprintf(paste0('<section class="ma-section ma-advantage-section" ',
                   'data-ma-stim="advantage" data-ma-adv-part="%s">'), part),
    if (detail) "" else .ma_adv_intro(adv),
    .ma_adv_controls_bar(pd, adv, part = part),
    .ma_adv_views_layout(adv, part = part),
    if (detail) .ma_adv_focal_view_section(pd) else "",
    # Stage 5: the Mental Availability destination carries one commentary
    # box, and the headline box on the Metrics sub-tab is the panel's own.
    if (detail) .ma_adv_about(adv) else "",
    '</section>'
  )
}


# ==============================================================================
# INTERNAL: INTRO + CONTROLS
# ==============================================================================

.ma_adv_intro <- function(adv) {
  # Body is sourced from the central callout registry
  # (modules/shared/lib/callouts/callouts.json -> brand.mental_advantage_intro).
  # The section heading wraps the callout so the page still has the
  # "Mental Advantage" h3 at the top of the section.
  callout <- if (exists("turas_callout", mode = "function")) {
    turas_callout("brand", "mental_advantage_intro", collapsed = FALSE)
  } else {
    ""
  }
  paste0(
    '<div class="ma-adv-intro">',
    # The section heading moved to the leaf head in 03_page_builder.R, which
    # names every analysis on every destination the same way and adds the
    # category. Two "Mental Advantage" headings one under the other said
    # nothing the first did not.
    callout,
    '</div>'
  )
}


.ma_adv_controls_bar <- function(pd, adv, part = "main") {
  detail <- identical(part, "detail")
  stims <- adv$available_stims
  stim_buttons <- if (length(stims) > 1) {
    paste0(
      '<div class="sig-level-switcher ma-adv-stim-switcher" role="group" aria-label="Stimulus type">',
      '<span class="sig-level-label">Stimulus:</span>',
      paste(vapply(seq_along(stims), function(i) {
        st <- stims[i]
        active <- if (st == adv$default_stim) " sig-btn-active" else ""
        pressed <- if (st == adv$default_stim) "true" else "false"
        label <- if (st == "ceps") "CEPs" else "Attributes"
        sprintf('<button type="button" class="sig-btn%s" data-ma-action="adv-stim" data-ma-adv-stim="%s" aria-pressed="%s">%s</button>',
                active, st, pressed, label)
      }, character(1)), collapse = ""),
      '</div>'
    )
  } else ""

  # Romaniuk-faithful: base is always total respondents. Shown as a
  # static notation so the user knows the denominator without offering
  # a misleading toggle.
  base_notation <- '<div class="ma-adv-base-notation" title="Mental Advantage is computed on the total respondent base, per Romaniuk (Better Brand Health, 2022).">
       <span class="sig-level-label">Base:</span>
       <span class="ma-adv-base-value">total respondents</span>
     </div>'

  # Brand selector lives in .ma_focus_bar (panel-level), shared across sub-tabs.

  paste0(
    '<div class="ma-controls controls-bar ma-adv-controls">',
    '<div class="ma-meta-row">',
    stim_buttons,
    base_notation,
    # Show counts governs the matrix, which only the detail part holds, and
    # Show chart governs the quadrant, which only the main part holds. A
    # control over a view that is not on the page is a control that does
    # nothing, which is what the Dirichlet Norms brand filter used to be.
    if (detail)
      '<label class="toggle-label"><input type="checkbox" data-ma-action="adv-show-counts"> Show counts</label>'
    else
      '<label class="toggle-label"><input type="checkbox" data-ma-action="adv-show-chart" checked> Show chart</label>',
    '<button type="button" class="export-btn ma-pin-dropdown-btn" data-ma-action="adv-pindropdown" data-ma-pin-scope="advantage" title="Pin a section" aria-haspopup="true">&#128204; Pin &#9662;</button>',
    '<button type="button" class="export-btn ma-png-btn" onclick="brExportPngFromEl(this)" title="Export view to PNG">&#x1F5BC; PNG</button>',
    # The Excel export writes the matrix, so it goes where the matrix is.
    if (detail)
      '<button type="button" class="export-btn ma-export-btn" data-ma-action="exporttable" data-ma-stim="advantage" title="Export Mental Advantage to Excel">⭳ Excel ▾</button>'
    else "",
    '</div>',
    '</div>'
  )
}


#' HTML legend for the diverging palette + decision colours.
#' @keywords internal
.ma_adv_legend <- function(adv) {
  threshold <- as.integer(adv$threshold_pp %||% 5)
  paste0(
    '<div class="ma-adv-legend" role="group" aria-label="Mental Advantage colour legend">',
    sprintf('<span class="ma-adv-legend-item"><span class="ma-adv-legend-swatch ma-adv-legend-defend"></span>Defend (MA &ge; +%dpp)</span>', threshold),
    '<span class="ma-adv-legend-item"><span class="ma-adv-legend-swatch ma-adv-legend-maintain"></span>Maintain (within &plusmn;', threshold, 'pp)</span>',
    sprintf('<span class="ma-adv-legend-item"><span class="ma-adv-legend-swatch ma-adv-legend-build"></span>Build (MA &le; &minus;%dpp)</span>', threshold),
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: VIEW LAYOUT (THREE EMPTY CONTAINERS, JS POPULATES)
# ==============================================================================

.ma_adv_views_layout <- function(adv, part = "main") {
  detail <- identical(part, "detail")
  # The legend explains the diverging palette, which colours the matrix cells
  # and the quadrant bubbles alike, so both parts carry it. So does the
  # tooltip: each part has hover targets of its own and tooltipEl() resolves
  # it inside the host.
  paste0(
    '<div class="ma-adv-views">',
    .ma_adv_legend(adv),
    if (detail) .ma_adv_matrix_view() else "",
    if (detail) "" else .ma_adv_quadrant_view(),
    if (detail) "" else .ma_adv_action_list_view(),
    '<div class="ma-adv-tooltip" role="status" aria-live="polite" hidden></div>',
    '</div>'
  )
}


.ma_adv_quadrant_view <- function() {
  paste0(
    '<div class="ma-adv-view ma-adv-quadrant-view" data-ma-adv-view="quadrant">',
    '<div class="ma-adv-view-header">',
    '<h4 class="ma-subsection-title">Strategic Quadrant:&nbsp;<span class="ma-adv-focal-name" data-ma-adv-focal-name></span></h4>',
    '<details class="ma-chart-callout">',
    '<summary>About this chart</summary>',
    '<p class="ma-subsection-note">',
    'Each bubble is a CEP or attribute for the focal brand. X-axis: how big',
    ' the stimulus is in the category. Y-axis: focal',
    " brand's Mental Advantage in pp. Bubble size: focal's raw linkage % to",
    ' that stimulus (on a fixed 0&ndash;100% scale, so % aware vs % total',
    ' produces visibly different sizes). Top-right (big + advantaged) =',
    ' Defend; bottom-right (big + disadvantaged) = Build; top-left = niche',
    ' but advantaged (Amplify); bottom-left = low priority.',
    '</p></details>',
    '</div>',
    '<div class="ma-adv-quadrant-rangebar">',
    '<span class="ma-ctl-label">X-axis range</span>',
    '<label class="ma-adv-xrange-label">Min',
    '<input type="number" class="ma-adv-xrange-input" data-ma-action="adv-xrange-min" min="0" max="100" step="5" placeholder="auto"></label>',
    '<label class="ma-adv-xrange-label">Max',
    '<input type="number" class="ma-adv-xrange-input" data-ma-action="adv-xrange-max" min="0" max="100" step="5" placeholder="auto"></label>',
    '<button type="button" class="ma-adv-xrange-reset" data-ma-action="adv-xrange-reset">Reset</button>',
    '<span class="ma-adv-rangebar-sep" aria-hidden="true">|</span>',
    '<span class="ma-ctl-label">Y-axis range (pp)</span>',
    '<label class="ma-adv-xrange-label">Min',
    '<input type="number" class="ma-adv-xrange-input" data-ma-action="adv-yrange-min" step="1" placeholder="auto"></label>',
    '<label class="ma-adv-xrange-label">Max',
    '<input type="number" class="ma-adv-xrange-input" data-ma-action="adv-yrange-max" step="1" placeholder="auto"></label>',
    '<button type="button" class="ma-adv-xrange-reset" data-ma-action="adv-yrange-reset">Reset</button>',
    '<span class="ma-adv-base-status">Bubbles sized by: % total</span>',
    '</div>',
    '<svg class="ma-adv-quadrant-svg" data-ma-adv="quadrant" xmlns="http://www.w3.org/2000/svg"></svg>',
    '</div>'
  )
}


.ma_adv_matrix_view <- function() {
  paste0(
    '<div class="ma-adv-view ma-adv-matrix-view" data-ma-adv-view="matrix">',
    '<div class="ma-adv-view-header">',
    '<h4 class="ma-subsection-title">Mental Advantage Matrix</h4>',
    '<details class="ma-chart-callout">',
    '<summary>About this chart</summary>',
    '<p class="ma-subsection-note">',
    'Mental Advantage scores (in pp) for every brand on every stimulus.',
    ' Rows are sorted by the focal brand’s advantage descending. Green',
    ' cells = Defend (over-index), red cells = Build (under-index), grey',
    ' cells = Maintain. A bullet (•) marks cells whose chi-square',
    ' standardised residual exceeds 1.96 (p &lt; 0.05).',
    '</p></details>',
    '</div>',
    '<div class="ma-adv-matrix-wrap" data-ma-adv="matrix"></div>',
    '</div>'
  )
}


.ma_adv_action_list_view <- function() {
  paste0(
    '<div class="ma-adv-view ma-adv-action-list-view" data-ma-adv-view="actions">',
    '<div class="ma-adv-view-header">',
    '<h4 class="ma-subsection-title">Action List:&nbsp;<span class="ma-adv-focal-name" data-ma-adv-focal-name></span></h4>',
    '<details class="ma-chart-callout">',
    '<summary>About this chart</summary>',
    '<p class="ma-subsection-note">',
    'Stimuli sorted into three strategic buckets for the focal brand.',
    ' Defend lists the strongest over-indexes by absolute MA. Build lists',
    ' the biggest gaps (most negative MA), each with the leading',
    ' competitor on that CEP/attribute. Maintain catches the rest.',
    '</p></details>',
    '</div>',
    '<div class="ma-adv-action-cols">',
    '<div class="ma-adv-action-col ma-adv-defend" data-ma-decision="defend">',
    '<div class="ma-adv-col-head"><span class="ma-adv-col-title">Defend</span><span class="ma-adv-col-count" data-ma-decision-count="defend">–</span></div>',
    '<ol class="ma-adv-action-list" data-ma-adv-list="defend"></ol>',
    '</div>',
    '<div class="ma-adv-action-col ma-adv-build" data-ma-decision="build">',
    '<div class="ma-adv-col-head"><span class="ma-adv-col-title">Build</span><span class="ma-adv-col-count" data-ma-decision-count="build">–</span></div>',
    '<ol class="ma-adv-action-list" data-ma-adv-list="build"></ol>',
    '</div>',
    '<div class="ma-adv-action-col ma-adv-maintain" data-ma-decision="maintain">',
    '<div class="ma-adv-col-head"><span class="ma-adv-col-title">Maintain</span><span class="ma-adv-col-count" data-ma-decision-count="maintain">–</span></div>',
    '<ol class="ma-adv-action-list" data-ma-adv-list="maintain"></ol>',
    '</div>',
    '</div>',
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: INSIGHT BOX, ABOUT DRAWER, EMPTY STATE
# ==============================================================================

# ==============================================================================
# INTERNAL: FOCAL-BRAND VIEW (Drivers & Barriers lens)
# ==============================================================================
# Replaces the standalone Drivers & Barriers HTML page. Pairs the
# market-relative MA score with the focal brand's buyer-vs-non-buyer
# linkage gap per stimulus, and assigns a four-way Read label.
#
# Renders an empty scaffold; brand_ma_advantage.js fills the table
# whenever the stimulus toggle (CEPs / Attributes) flips, reading
# panel.advantage.{ceps|attributes}.focal_view from the JSON payload.

.ma_adv_focal_view_section <- function(pd) {
  adv <- pd$advantage
  has_focal <- FALSE
  for (st in c("ceps", "attributes")) {
    fv <- adv[[st]]$focal_view
    if (!is.null(fv) && is.list(fv$by_brand) && length(fv$by_brand) > 0) {
      has_focal <- TRUE; break
    }
  }
  if (!has_focal) return("")

  focal_label <- pd$config$focal_brand_name %||%
                 pd$config$focal_brand_code %||% "Focal brand"
  callout <- if (exists("turas_callout", mode = "function")) {
    turas_callout("brand", "ma_focal_view_intro", collapsed = TRUE)
  } else ""

  paste0(
    '<section class="ma-section ma-adv-focal-view" data-ma-focal-view="root" data-ma-stim="advantage_focal">',
    sprintf(
      '<div class="ma-adv-focal-header">
         <div class="ma-adv-focal-headline">
           <h4 class="ma-adv-focal-title">Focal brand view: <span data-ma-focal-brand>%s</span></h4>
           <span class="ma-adv-focal-base" data-ma-focal-base></span>
         </div>
         <div class="ma-adv-focal-toolbar">
           <button type="button" class="export-btn ma-pin-dropdown-btn ma-adv-focal-pin-btn" data-ma-action="adv-focal-pindropdown" title="Pin this focal-brand view" aria-haspopup="true">&#128204; Pin &#9662;</button>
           <button type="button" class="export-btn ma-png-btn ma-adv-focal-png-btn" onclick="brExportPngFromEl(this)" title="Export the focal-brand view to PNG">&#x1F5BC; PNG</button>
         </div>
       </div>',
      htmltools::htmlEscape(focal_label)),
    callout,
    '<div class="ma-adv-focal-table-wrap">',
    '<table class="ct-table ma-adv-focal-table" data-ma-focal-table>',
    '<thead><tr>',
    '<th class="ct-lbl ma-adv-focal-th-stim">Stimulus</th>',
    '<th class="ma-adv-focal-th-ma">MA score<span class="ma-adv-focal-sub">market-relative (pp)</span></th>',
    '<th class="ma-adv-focal-th-gap">Buyer gap<span class="ma-adv-focal-sub">buyer % &minus; non-buyer % (pp)</span></th>',
    '<th class="ma-adv-focal-th-read">Read</th>',
    '</tr></thead>',
    '<tbody data-ma-focal-tbody></tbody>',
    '</table>',
    '</div>',
    '<p class="ma-adv-focal-footnote">',
    'Buyer gap = % of focal-brand P3M buyers linking the stimulus, minus the same for non-buyers. ',
    'Significance = 95% two-proportion z (unweighted bases). ',
    'Cells suppressed when either base is below n=30.',
    '</p>',
    '</section>'
  )
}


.ma_adv_insight_box <- function() {
  '<section class="ma-insight-box" data-ma-stim="advantage">
     <div class="ma-insight-box-header">
       <span class="ma-insight-box-title">Insight</span>
       <button type="button" class="ma-insight-box-clear" data-ma-action="clear-insight" data-ma-stim="advantage" title="Clear">&#215;</button>
     </div>
     <textarea class="ma-insight-box-text" data-ma-stim="advantage" placeholder="Write the headline for Mental Advantage (one or two sentences)…"></textarea>
   </section>'
}


.ma_adv_about <- function(adv) {
  # Body sourced from the central callout registry
  # (modules/shared/lib/callouts/callouts.json -> brand.mental_advantage_methodology).
  if (exists("turas_callout", mode = "function")) {
    turas_callout("brand", "mental_advantage_methodology", collapsed = TRUE)
  } else {
    ""
  }
}


.ma_adv_empty_state <- function() {
  paste0(
    '<section class="ma-section ma-advantage-section ma-adv-empty">',
    '<div class="ma-adv-empty-msg">',
    '<strong>Mental Advantage is not available for this category.</strong>',
    ' Make sure CEP linkage data is loaded and ‘calculate_mental_advantage’ is sourced.',
    '</div>',
    '</section>'
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
