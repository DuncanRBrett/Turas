# ==============================================================================
# BRAND MODULE - MA PANEL: MENTAL ADVANTAGE SUB-TAB
# ==============================================================================
# Server-emits the HTML scaffolding for the Mental Advantage sub-tab.
# All three views (strategic quadrant, diverging matrix heatmap, action
# list) are populated by brand_ma_advantage.js from the JSON payload
# embedded by build_ma_panel_html() — same render-on-change pattern used
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
#' @return Character. HTML fragment, or empty string when no advantage data.
#' @export
build_ma_advantage_section <- function(pd, focal_colour = "#1A5276") {
  adv <- pd$advantage
  if (is.null(adv) || length(adv$available_stims) == 0) {
    return(.ma_adv_empty_state())
  }

  paste0(
    '<section class="ma-section ma-advantage-section" data-ma-stim="advantage">',
    .ma_adv_intro(adv),
    .ma_adv_controls_bar(pd, adv),
    .ma_adv_chip_row(pd),
    .ma_adv_views_layout(adv),
    .ma_adv_insight_box(),
    .ma_adv_about(adv),
    '</section>'
  )
}


# ==============================================================================
# INTERNAL: INTRO + CONTROLS
# ==============================================================================

.ma_adv_intro <- function(adv) {
  threshold <- as.integer(adv$threshold_pp %||% 5)
  paste0(
    '<div class="ma-adv-intro">',
    '<h3 class="ma-section-title">Mental Advantage</h3>',
    '<details class="ma-adv-intro-callout" open>',
    '<summary>What is Mental Advantage?</summary>',
    '<div class="ma-adv-intro-body">',
    '<p>Mental Advantage answers a simple question: <em>does this brand own this',
    ' situation more than its size says it should?</em> A big brand attracts more',
    ' associations on every CEP just because it is big. A widely held attribute',
    ' (like “tastes good”) gets ticked for every brand. Raw linkage charts can’t',
    ' tell those effects apart from real competitive strength.</p>',
    '<p>For each brand × stimulus cell, we compare the <strong>actual</strong> number',
    ' of respondents who linked the two, to the number we’d <strong>expect</strong>',
    ' if linkage were purely a function of how big the brand is and how popular',
    ' the stimulus is. The difference, expressed in percentage points of the',
    ' sample, is the Mental Advantage score.</p>',
    '<ul class="ma-adv-intro-list">',
    sprintf('<li><strong>Defend</strong> &nbsp;(score &ge; +%dpp): the brand over-indexes — protect this territory.</li>', threshold),
    sprintf('<li><strong>Build</strong> &nbsp;(score &le; &minus;%dpp): the brand under-indexes — a gap to close, especially on big stimuli.</li>', threshold),
    '<li><strong>Maintain</strong> (in between): the brand is performing in line with its size — no urgent move.</li>',
    '</ul>',
    '<p>A bullet (&bull;) marks cells where the gap is large enough to be',
    ' statistically significant (chi-square standardised residual |z| &gt; 1.96,',
    ' p &lt; 0.05). The score itself is computed once on the total sample base',
    ' (Romaniuk-faithful); the Base toggle changes the linkage % shown alongside',
    ' the score, not the score itself.</p>',
    '<p class="ma-adv-intro-source"><em>Source: Romaniuk, J. (2022). Better Brand Health',
    ' (Ehrenberg-Bass). Worked example via Quantilope (2024).</em></p>',
    '</div></details></div>'
  )
}


.ma_adv_controls_bar <- function(pd, adv) {
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

  base_buttons <- '<div class="sig-level-switcher ma-adv-base-switcher" role="group" aria-label="Linkage base">
       <span class="sig-level-label">Base:</span>
       <button type="button" class="sig-btn sig-btn-active" data-ma-action="adv-base" data-ma-adv-base="total" aria-pressed="true">% total</button>
       <button type="button" class="sig-btn" data-ma-action="adv-base" data-ma-adv-base="aware" aria-pressed="false">% aware</button>
     </div>'

  filter_buttons <- '<div class="sig-level-switcher ma-adv-filter-switcher" role="group" aria-label="Bubble filter">
       <span class="sig-level-label">Show:</span>
       <button type="button" class="sig-btn sig-btn-active" data-ma-action="adv-filter" data-ma-adv-filter="all" aria-pressed="true">All</button>
       <button type="button" class="sig-btn" data-ma-action="adv-filter" data-ma-adv-filter="actionable" aria-pressed="false">Defend + Build</button>
       <button type="button" class="sig-btn" data-ma-action="adv-filter" data-ma-adv-filter="top10" aria-pressed="false">Top 10 by |MA|</button>
     </div>'

  paste0(
    '<div class="ma-controls controls-bar ma-adv-controls">',
    '<div class="ma-meta-row">',
    stim_buttons,
    base_buttons,
    filter_buttons,
    '<label class="toggle-label"><input type="checkbox" data-ma-action="adv-show-counts"> Show counts</label>',
    '<label class="toggle-label"><input type="checkbox" data-ma-action="adv-show-chart" checked> Show chart</label>',
    '<button type="button" class="export-btn ma-pin-dropdown-btn" data-ma-action="adv-pindropdown" data-ma-pin-scope="advantage" title="Pin a section" aria-haspopup="true">&#128204; Pin &#9662;</button>',
    '<button type="button" class="export-btn ma-png-btn" onclick="brExportPngFromEl(this)" title="Export view to PNG">&#x1F5BC; PNG</button>',
    '<button type="button" class="export-btn ma-export-btn" data-ma-action="exporttable" data-ma-stim="advantage" title="Export Mental Advantage to Excel">⭳ Excel ▾</button>',
    '</div>',
    '</div>'
  )
}


#' Brand-column visibility chips for the matrix and chart.
#' Mirrors the pattern used on the existing CEPs/Attributes tabs so the
#' interaction language is consistent across the panel. Clicking a chip
#' toggles the brand column off/on in the matrix; the chart shows only
#' the focal brand so chip toggles don't affect it directly, but stim
#' rows greyed out from the matrix DO drop their bubble from the chart.
#' @keywords internal
.ma_adv_chip_row <- function(pd) {
  brand_codes <- pd$config$brand_codes %||% character(0)
  brand_names <- pd$config$brand_names %||% brand_codes
  focal       <- pd$meta$focal_brand_code

  if (length(brand_codes) == 0) return("")
  sorted <- order(brand_codes != focal, tolower(brand_names))
  brand_codes <- brand_codes[sorted]; brand_names <- brand_names[sorted]

  chips <- paste(vapply(seq_along(brand_codes), function(i) {
    sprintf('<button type="button" class="col-chip" data-ma-adv-chip-brand="%s">%s</button>',
            .ma_esc(brand_codes[i]), .ma_esc(brand_names[i]))
  }, character(1)), collapse = "")

  paste0(
    '<div class="ma-adv-chip-bar">',
    '<span class="ma-ctl-label">Show brands</span>',
    '<div class="ma-chip-row col-chip-bar" data-ma-adv-scope="brands">', chips, '</div>',
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
    '<span class="ma-adv-legend-item"><span class="ma-adv-legend-sig">&bull;</span>Significant (chi-square |z| &gt; 1.96)</span>',
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: VIEW LAYOUT (THREE EMPTY CONTAINERS — JS POPULATES)
# ==============================================================================

.ma_adv_views_layout <- function(adv) {
  paste0(
    '<div class="ma-adv-views">',
    .ma_adv_legend(adv),
    .ma_adv_matrix_view(),
    .ma_adv_quadrant_view(),
    .ma_adv_action_list_view(),
    '<div class="ma-adv-tooltip" role="status" aria-live="polite" hidden></div>',
    '</div>'
  )
}


.ma_adv_quadrant_view <- function() {
  paste0(
    '<div class="ma-adv-view ma-adv-quadrant-view" data-ma-adv-view="quadrant">',
    '<div class="ma-adv-view-header">',
    '<h4 class="ma-subsection-title">Strategic Quadrant</h4>',
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
    '<h4 class="ma-subsection-title">Action List — focal brand</h4>',
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
    '<div class="ma-adv-col-head"><span class="ma-adv-col-title">Defend</span><span class="ma-adv-col-count" data-ma-decision-count="defend">—</span></div>',
    '<ol class="ma-adv-action-list" data-ma-adv-list="defend"></ol>',
    '</div>',
    '<div class="ma-adv-action-col ma-adv-build" data-ma-decision="build">',
    '<div class="ma-adv-col-head"><span class="ma-adv-col-title">Build</span><span class="ma-adv-col-count" data-ma-decision-count="build">—</span></div>',
    '<ol class="ma-adv-action-list" data-ma-adv-list="build"></ol>',
    '</div>',
    '<div class="ma-adv-action-col ma-adv-maintain" data-ma-decision="maintain">',
    '<div class="ma-adv-col-head"><span class="ma-adv-col-title">Maintain</span><span class="ma-adv-col-count" data-ma-decision-count="maintain">—</span></div>',
    '<ol class="ma-adv-action-list" data-ma-adv-list="maintain"></ol>',
    '</div>',
    '</div>',
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: INSIGHT BOX, ABOUT DRAWER, EMPTY STATE
# ==============================================================================

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
  threshold <- as.integer(adv$threshold_pp %||% 5)
  paste0(
    '<details class="ma-adv-about ma-chart-callout">',
    '<summary>Methodology</summary>',
    '<div class="ma-adv-about-body">',
    '<p><strong>Source:</strong> Romaniuk, J. (2022). <em>Better Brand Health</em>; ',
    'Quantilope (2024). <em>Mental Advantage Analysis</em>.</p>',
    '<p><strong>Formula:</strong> ',
    'expected[s,b] = (row_total[s] × col_total[b]) ÷ grand_total. ',
    'MA[s,b] = (actual[s,b] − expected[s,b]) ÷ n × 100, in pp.</p>',
    sprintf('<p><strong>Decisions:</strong> Defend if MA ≥ +%d pp, Build if MA ≤ −%d pp, Maintain in between.</p>',
            threshold, threshold),
    '<p><strong>Significance:</strong> chi-square standardised residual ',
    'z = (actual − expected) ÷ √expected. Cells flagged when |z| &gt; 1.96 (p &lt; 0.05). ',
    'Bootstrap confidence intervals are a documented stretch, not implemented in v1.</p>',
    '<p><strong>Base:</strong> total respondents (Romaniuk-faithful). The bubble-size toggle ',
    'switches the displayed raw linkage between % total and % aware; the MA score itself is computed once on the total base.</p>',
    '</div></details>'
  )
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
