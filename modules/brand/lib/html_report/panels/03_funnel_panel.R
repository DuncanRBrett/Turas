# ==============================================================================
# BRAND MODULE - FUNNEL PANEL HTML RENDERER (FUNNEL_SPEC_v2 §6)
# ==============================================================================
# Consumes build_funnel_panel_data() output and emits a self-contained
# HTML fragment for one category's funnel tab.
#
# Visual contract: this panel reuses the tabs module's ct-* CSS classes
# verbatim so the funnel card looks identical to a tabs crosstab card.
# The only funnel-specific CSS lives in 03_funnel_panel_styling.R and
# covers things tabs doesn't express (sub-tab nav, focus dropdown,
# stage-definition popovers, stacked attitude bars).
#
# Interaction JS: js/brand_funnel_panel.js (loaded once per report).
#
# Sub-renderers:
#   03_funnel_panel_table.R: ct-table heatmap
#   03_funnel_panel_chart.R, slope chart + consideration detail
#   03_funnel_panel_styling.R, CSS bundle
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_PANEL_VERSION <- "2.0"


# ==============================================================================
# PUBLIC: build_funnel_panel_html
# ==============================================================================

#' Build the funnel panel HTML fragment
#'
#' @param panel_data List from \code{build_funnel_panel_data()}.
#' @param category_code Character. Used to scope element ids on the page.
#' @param focal_colour Character. Hex colour for the focal brand. Defaults
#'   to Turas navy.
#' @param excel_filename Character or NULL. Path (relative to the HTML file)
#'   of the dedicated funnel Excel workbook. When set, the Export button
#'   downloads this file; when NULL the button alerts with a setup hint.
#' @param only_tab Character or NULL. When set to \code{"funnel"} or
#'   \code{"relationship"}, the fragment carries only that internal sub-tab's
#'   content (the Summary cards travel with the funnel tab, where they are
#'   unreached today and stay unreached). The hidden sub-nav is emitted in
#'   full either way, because \code{switchCategorySubtab()} routes by clicking
#'   the button inside the host. NULL emits every sub-tab, which is the
#'   pre-split behaviour and what direct callers and tests still get.
#' @param island Logical. FALSE suppresses the JSON payload script, for a
#'   second host of the same category that reads the payload from the
#'   primary host instead.
#' @param island_host Character or NULL. Element id of the panel root that
#'   carries the payload. Emitted as \code{data-island-host} so the panel JS
#'   can find it.
#'
#' @return Character. A single HTML fragment (string).
#' @export
build_funnel_panel_html <- function(panel_data, category_code = "cat",
                                    focal_colour = "#1A5276",
                                    excel_filename = NULL,
                                    chip_default = "focal_only",
                                    only_tab = NULL,
                                    island = TRUE,
                                    island_host = NULL) {
  if (is.null(panel_data) || is.null(panel_data$meta) ||
      length(panel_data$meta) == 0) {
    return('<div class="fn-panel-empty">Funnel not available for this category.</div>')
  }

  chip_default <- if (identical(chip_default, "all")) "all" else "focal_only"
  panel_data$config$chip_default <- chip_default

  # Host identity. The primary host (every sub-tab, or the funnel sub-tab)
  # keeps the historical id so nothing that resolves fn-<cat> moves.
  is_primary <- is.null(only_tab) || identical(only_tab, "funnel")
  panel_id <- if (is_primary) paste0("fn-", category_code)
              else paste0("fn-", category_code, "-", only_tab)
  wants <- function(tab) is.null(only_tab) || identical(only_tab, tab)

  json_payload <- .funnel_panel_json(panel_data, focal_colour)
  excel_attr <- if (!is.null(excel_filename) && nzchar(excel_filename))
    sprintf(' data-fn-excel-filename="%s"', .fn_esc(excel_filename)) else ""
  host_attr <- if (!is.null(island_host) && nzchar(island_host))
    sprintf(' data-island-host="%s"', .fn_esc(island_host)) else ""
  active_tab <- if (is.null(only_tab)) "funnel" else only_tab

  paste0(
    sprintf('<div class="fn-panel" id="%s" data-category-key="%s" data-focal-colour="%s" data-chip-default="%s"%s%s>',
            panel_id, .fn_esc(category_code), focal_colour, chip_default,
            excel_attr, host_attr),
    if (isTRUE(island))
      sprintf('<script type="application/json" class="fn-panel-data">%s</script>',
              .br_json_island(json_payload)) else "",
    .fn_sub_tabs(active_tab),
    .fn_focus_bar(panel_data),
    # The Summary cards travel with the funnel host. They are unreached in
    # the report as shipped and stay unreached here (Duncan's ruling 5).
    if (wants("funnel")) paste0(
    '<div class="fn-subtab" data-fn-subtab="summary" hidden>',
      .fn_cards_section(panel_data, focal_colour),
    '</div>') else "",
    if (wants("funnel")) paste0(
    '<div class="fn-subtab" data-fn-subtab="funnel">',
      .fn_table_controls(panel_data),
      # Sits outside .fn-controls on purpose: the controls bar is hidden in
      # print, and a reader with a printed page cannot open a drawer, so the
      # explanation of the base has to survive the print rule. The gating
      # statement is here for the same reason, and above the how-this-works
      # drawer because it decides which views exist.
      .fn_gating_notice(panel_data),
      .fn_base_howto(panel_data),
      .fn_table_section(panel_data, focal_colour),
      '<div class="fn-mf-section-heading">Mini Funnels</div>',
      '<div class="fn-mini-funnels-view" data-fn-view="minifunnels"></div>',
      '<div class="fn-chart-wrap-outer">',
        .fn_chart_header(panel_data),
        '<div class="fn-chart-view" data-fn-view="slope">',
          '<div class="fn-aware-note" style="display:none;font-size:11px;color:#64748b;padding:4px 8px 0;font-style:italic;">Awareness pinned to 100%. Chart shows conversion efficiency from awareness.</div>',
          .fn_chart_section(panel_data, focal_colour),
        '</div>',
      '</div>',
      .fn_add_insight_strip(),
      # Funnel-page callout lives INSIDE the funnel sub-tab so it doesn't
      # leak onto the Summary or Relationship sub-tabs (each has its own
      # callout / explanation).
      .fn_about_section(panel_data),
    '</div>') else "",
    if (wants("relationship")) paste0(
    sprintf('<div class="fn-subtab" data-fn-subtab="relationship"%s>',
            if (identical(only_tab, "relationship")) "" else " hidden"),
      .fn_relationship_section(panel_data, focal_colour),
    '</div>') else "",
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: TITLE CARD + SUB-TAB NAV
# ==============================================================================

.fn_title_card <- function(pd) {
  meta <- pd$meta
  n_u <- meta$n_unweighted %||% NA
  wave <- meta$wave_label %||% ""
  sub_parts <- character(0)
  if (!is.null(meta$focal_brand_name))
    sub_parts <- c(sub_parts,
      sprintf("Focal: <strong>%s</strong>", .fn_esc(meta$focal_brand_name)))
  if (!is.null(meta$category_type))
    sub_parts <- c(sub_parts, sprintf("%s funnel",
      .fn_capitalise(meta$category_type)))
  if (nzchar(wave)) sub_parts <- c(sub_parts, sprintf("Wave %s", .fn_esc(wave)))
  if (is.finite(n_u)) sub_parts <- c(sub_parts, sprintf("n = %d", n_u))

  # Plain white card, tabs question-title-card idiom (no gradient; the
  # dark-navy header lives at the report level, not per panel).
  sprintf(
    '<div class="fn-title-card question-title-card">
       <div class="fn-title-card-top">
         <h2 class="fn-title"><span class="fn-title-caret">\u25BE</span> Brand Funnel</h2>
         <button type="button" class="fn-pin-btn pin-btn" title="Pin this panel" aria-label="Pin">\U0001F4CC</button>
       </div>
       <div class="fn-title-sub">%s</div>
     </div>',
    paste(sub_parts, collapse = " &middot; ")
  )
}


.fn_sub_tabs <- function(active_tab = "funnel") {
  tabs <- list(
    list(key = "summary",      label = "Summary"),
    list(key = "funnel",       label = "Funnel"),
    list(key = "relationship", label = "Relationship")
  )
  btns <- vapply(tabs, function(t) {
    on <- identical(t$key, active_tab)
    sprintf(paste0('<button type="button" class="fn-subtab-btn%s" ',
                   'data-fn-subtab-target="%s" role="tab" aria-selected="%s">%s</button>'),
            if (on) " active" else "", t$key,
            if (on) "true" else "false", t$label)
  }, character(1))
  sprintf('<nav class="fn-subnav" role="tablist" aria-label="Funnel sections">%s</nav>',
          paste(btns, collapse = ""))
}


# ==============================================================================
# INTERNAL: CONTROLS
# ==============================================================================

#' Summary sub-tab: focus-brand dropdown (changing this re-renders cards).
#' @keywords internal
.fn_focus_bar <- function(pd) {
  brand_codes <- pd$config$chip_picker$all_brands %||%
    (pd$table$brand_codes %||% character(0))
  brand_names <- pd$table$brand_names %||% brand_codes
  focal <- pd$meta$focal_brand_code %||% brand_codes[1]

  focus_options <- paste(vapply(seq_along(brand_codes), function(i) {
    sel <- if (brand_codes[i] == focal) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .fn_esc(brand_codes[i]), sel, .fn_esc(brand_names[i]))
  }, character(1)), collapse = "")

  selector_trigger <- if (length(brand_codes) > 0L) {
    build_brand_selector_trigger(
      panel_id = "funnel",
      n_total  = length(brand_codes),
      label    = "Filter brands"
    )
  } else ""

  sprintf(
    '<div class="fn-focus-bar br-header-governed">
       <label class="fn-ctl-label">Focal brand</label>
       <select class="fn-focus-select" data-fn-action="focus">%s</select>
       %s
     </div>',
    focus_options, selector_trigger)
}


#' Funnel sub-tab: the view-controls row above the table.
#'
#' Matches tabs' controls bar exactly:
#' - \code{.toggle-label} pills for Heatmap / Show count / Show chart
#' - \code{.sig-level-switcher} segmented button for Base (% of total / previous)
#' - \code{.export-btn} with the \u2B73 Export \u25BE icon
#' @keywords internal
.fn_table_controls <- function(pd) {
  # BrandSelector trigger lives in .fn_focus_bar (next to the focal-brand
  # <select>), see Demographics / WoM / Cat Buying for the same pattern.
  g <- (pd$meta %||% list())$gating
  gated <- is.null(g) || isTRUE(g$gated)

  paste0(
    '<div class="fn-controls controls-bar">',
    '<div class="fn-meta-row">',
    '<label class="toggle-label"><input type="checkbox" data-fn-action="showci"> Show heatmap</label>',
    '<label class="toggle-label"><input type="checkbox" data-fn-action="showcounts"> Show count</label>',
    '<label class="toggle-label"><input type="checkbox" checked data-fn-action="showchart"> Show chart</label>',
    # Base toggle. The nested chain is the default (2026-09-06): it is the
    # only view in which the word funnel is honest, because every later
    # stage counts respondents who passed every earlier stage. The other
    # three views stay, each labelled with what it computes. The JS reads
    # data-fn-pctmode, and the pin and PNG exporters read the active
    # button's text through brReadBaseLabel(), so these labels have to read
    # as a base after the word "Base:".
    # The nested chain is offered only when the questionnaire routed the
    # questions. On an ungated instrument the chain would assert an ordering
    # the survey never enforced, so the button is not rendered at all and
    # "Each stage on its own" is the active default, with the two conversion
    # ratios beside it. See .fn_gating_notice() and detect_instrument_gating().
    '<div class="sig-level-switcher fn-base-switcher" role="group" aria-label="Percentage base">',
    '<span class="sig-level-label">Base:</span>',
    if (gated)
      '<button type="button" class="sig-btn sig-btn-active" data-fn-action="pctmode" data-fn-pctmode="chain" aria-pressed="true" title="The nested funnel. Each stage counts respondents who passed every earlier stage, as a percentage of all respondents.">Funnel, % of all</button>'
    else "",
    sprintf('<button type="button" class="sig-btn%s" data-fn-action="pctmode" data-fn-pctmode="total" aria-pressed="%s" title="Each stage on its own survey response, as a percentage of all respondents. The stages are not chained, so a later stage can read higher than an earlier one.">Each stage on its own</button>',
            if (gated) "" else " sig-btn-active",
            if (gated) "false" else "true"),
    '<button type="button" class="sig-btn" data-fn-action="pctmode" data-fn-pctmode="previous" aria-pressed="false" title="Each stage as a percentage of the stage before it. On a routed survey this walks the nested chain; where the survey did not route, it is the plain step-to-step ratio.">% of previous stage</button>',
    '<button type="button" class="sig-btn" data-fn-action="pctmode" data-fn-pctmode="aware" aria-pressed="false" title="Each stage crossed with awareness and divided by the aware count. Awareness pinned to 100%. Preference is not a precondition.">% of those aware</button>',
    '</div>',
    '<button type="button" class="fn-pin-dropdown-btn export-btn" data-fn-action="pindropdown" title="Pin a section" aria-haspopup="true">&#128204; Pin &#9662;</button>',
    '<button type="button" class="export-btn fn-png-btn" onclick="brExportPngFromEl(this)" title="Export view to PNG">&#x1F5BC; PNG</button>',
    '<button type="button" class="export-btn fn-export-btn" data-fn-action="exporttable" title="Export table to Excel">\u2B73 Excel \u25BE</button>',
    '</div>',
    '</div>'
  )
}


#' "How this works" for the base toggle, collapsed.
#'
#' The funnel's main explainer is the shared callout registry entry
#' (\code{brand.funnel} in modules/shared), which this module does not own
#' and does not edit. What the four base views compute, and why the nested
#' view shows no significance mark, is written here instead, next to the
#' control it explains. Its toggle is handled in brand_funnel_panel.js
#' (\code{data-fn-action="basehowto"}).
#' Whether the questionnaire gated the questions, said on the page
#'
#' Not only in a console warning. A reader looking at a funnel is entitled to
#' know whether the survey enforced the ordering the picture implies, and a
#' reader looking at separate measures is entitled to know why the funnel
#' view is missing. Sits outside \code{.fn-controls} so it survives the print
#' rule that hides the controls bar.
#'
#' Digit free: the reachability gate compares the numeric content of every
#' JSON island and this text rides in the funnel payload. The counts behind
#' it go to the console.
#' @keywords internal
.fn_gating_notice <- function(pd) {
  g <- (pd$meta %||% list())$gating
  if (is.null(g) || !nzchar(g$statement %||% "")) return("")
  gated <- isTRUE(g$gated)
  mode_label <- if (gated) "Nested funnel" else "Separate measures"
  cls <- if (gated) "fn-gating-note fn-gating-gated"
         else "fn-gating-note fn-gating-ungated"
  sprintf(paste0(
    '<div class="%s" data-fn-gating="%s" data-fn-gating-mode="%s">',
    '<span class="fn-gating-mode">%s</span>',
    '<span class="fn-gating-text">%s</span>',
    '</div>'),
    cls, if (gated) "gated" else "ungated", .fn_esc(g$mode %||% "nested"),
    mode_label, .fn_esc(g$statement))
}


#' @keywords internal
.fn_base_howto <- function(pd = NULL) {
  g <- (pd$meta %||% list())$gating
  gated <- is.null(g) || isTRUE(g$gated)
  nested_bullet <- if (gated) paste0(
        '<li><strong>Funnel, % of all.</strong> The nested chain. At each stage the ',
        'count is the respondents who passed that stage and every earlier one, ',
        'divided by all respondents in the category. This is the only view in which ',
        'the stages narrow by construction, and the only one the word funnel fits.</li>')
    else paste0(
        '<li><strong>Funnel, % of all is not offered on this survey.</strong> ',
        'The questionnaire did not route the questions, so a respondent could ',
        'answer a later one without the earlier one. Chaining those answers ',
        'would draw an ordering the survey never enforced.</li>')
  paste0(
    '<div class="fn-base-howto" data-fn-base-howto>',
      '<button type="button" class="fn-base-howto-toggle" aria-expanded="false" ',
        'data-fn-action="basehowto">How this works',
        '<span class="fn-base-howto-arrow" aria-hidden="true"></span></button>',
      '<div class="fn-base-howto-body" hidden>',
        '<p><strong>The base toggle sets which question the table answers.</strong> ',
        'The views are not scalings of one number.</p>',
        '<ul>',
        nested_bullet,
        '<li><strong>Each stage on its own.</strong> Each stage\'s own survey response ',
        'over all respondents, with nothing chained. The stages are asked ',
        'independently, so a later stage can read higher than an earlier one. ',
        'Preference above awareness means people gave an attitude for a brand they ',
        'did not name as known.</li>',
        '<li><strong>% of previous stage.</strong> Each stage divided by the stage ',
        'before it, along the same chain the nested view uses. The step-by-step ',
        'conversion read.</li>',
        '<li><strong>% of those aware.</strong> Each stage crossed with awareness and ',
        'divided by the aware count. Preference is not a precondition, so this answers ',
        'how many of the people who know the brand went on to buy it, whatever they ',
        'said about preferring it.</li>',
        '</ul>',
        '<p><strong>Significance marks.</strong> The table carries two. The triangle ',
        'beside a cell is the engine\'s test of that brand against the category ',
        'average, computed on each stage\'s own base whichever view is showing. The ',
        'arrow is a comparison against the spread of brands at the base now ',
        'displayed. In the nested view neither is shown: the engine never tested the ',
        'chain, and marking a figure that was not tested would be worse than showing ',
        'nothing. Switch to "Each stage on its own" to read them.</p>',
      '</div>',
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: CARDS (10 total, 5 funnel + 5 relationship)
# ==============================================================================

.fn_cards_section <- function(pd, focal_colour) {
  funnel_cards <- .fn_cards_with_chain(pd)
  rel_cards    <- pd$cards$relationship %||% list()

  paste0(
    '<section class="fn-section fn-cards-section">',
    '<h3 class="fn-section-title">Summary <span class="fn-insight-marker" title="AI insight available">&#9679;</span></h3>',
    '<div class="fn-cards-group-label">Funnel</div>',
    sprintf('<div class="fn-cards-base-note" data-fn-cards-base-note>Base: %s</div>',
            "the nested funnel, % of all respondents"),
    '<div class="fn-card-strip tk-hero-strip">',
    paste(lapply(funnel_cards, .fn_funnel_card, focal_colour),
          collapse = ""),
    '</div>',
    if (length(rel_cards) > 0) paste0(
      '<div class="fn-cards-group-label">Relationship</div>',
      '<div class="fn-card-strip tk-hero-strip">',
      paste(lapply(rel_cards, .fn_relationship_card, focal_colour),
            collapse = ""),
      '</div>'
    ) else "",
    '</section>'
  )
}


#' Add the nested-chain figures to each funnel card.
#'
#' Derived here from the table cells and \code{meta$n_weighted}, both of
#' which are already in the panel payload, so the card can render in the
#' default view without a new engine number.
#'
#' The category average follows \code{.card_for_stage()} in
#' 03c_funnel_panel_data.R and averages the NON-focal brands, which is a
#' different set from the table's Category average row. The two disagree by
#' design; changing it here would move a figure the absolute view has always
#' shown.
#' @keywords internal
.fn_cards_with_chain <- function(pd) {
  cards <- pd$cards$funnel %||% list()
  if (length(cards) == 0) return(cards)
  cells <- pd$table$cells %||% list()
  focal <- pd$meta$focal_brand_code
  n_w   <- suppressWarnings(as.numeric(pd$meta$n_weighted %||% NA_real_))
  if (length(cells) == 0 || !is.finite(n_w) || n_w <= 0) return(cards)

  chain_of <- function(cell) {
    v <- suppressWarnings(as.numeric(cell$base_chain_filtered %||% NA_real_))
    if (!is.finite(v)) NA_real_ else v / n_w
  }

  lapply(cards, function(card) {
    k <- card$stage_key
    focal_v <- NA_real_; focal_n <- NA_real_; others <- numeric(0)
    for (cl in cells) {
      if (!identical(cl$stage_key, k)) next
      if (identical(cl$brand_code, focal)) {
        focal_v <- chain_of(cl)
        focal_n <- suppressWarnings(
          as.numeric(cl$base_chain_unweighted %||% NA_real_))
      } else {
        v <- chain_of(cl)
        if (is.finite(v)) others <- c(others, v)
      }
    }
    card$focal_chain_pct <- if (is.finite(focal_v)) focal_v else NULL
    card$cat_avg_chain_pct <- if (length(others) > 0) mean(others) else NULL
    card$focal_chain_base_unweighted <- if (is.finite(focal_n)) focal_n else NULL
    card
  })
}


.fn_funnel_card <- function(card, focal_colour) {
  # The cards follow the base toggle on the funnel sub-tab, so they are
  # rendered in the default view (the nested chain) and reflowed by
  # rebuildFunnelCards() in brand_funnel_panel.js. Without that they read a
  # stage's own figure while the table beside them reads the chain, which
  # is the contradiction this stage exists to remove.
  focal_pct <- .fn_pct_string(card$focal_chain_pct %||% card$focal_pct)
  avg_pct   <- .fn_pct_string(card$cat_avg_chain_pct %||% card$cat_avg_pct)
  sig <- card$sig_vs_avg %||% "na"
  # No badge in the default view: the test behind it is run on the stage's
  # own base. The direction rides on the card and the JS writes the badge
  # back in the views the test belongs to. Same reasoning as .fn_cell_html.
  sig_badge <- ""
  base_n <- card$focal_chain_base_unweighted %||% card$focal_base_unweighted
  base_line <- if (is.finite(base_n %||% NA))
    sprintf('<div class="fn-card-base">Focal n = %d</div>', as.integer(base_n))
  else ""

  sprintf(
    '<div class="tk-hero-card fn-card fn-card-funnel" style="border-left-color:%s;" data-fn-stage="%s" data-fn-sig-avg="%s">
       <div class="tk-hero-label">%s</div>
       <div class="fn-card-row">
         <div class="tk-hero-value" style="color:%s;">%s</div>
         %s
       </div>
       <div class="fn-card-compare">Category avg: <strong>%s</strong></div>
       %s
     </div>',
    focal_colour, .fn_esc(card$stage_key), .fn_esc(sig),
    .fn_esc(card$stage_label),
    focal_colour, focal_pct, sig_badge,
    avg_pct, base_line
  )
}


.fn_relationship_card <- function(card, focal_colour) {
  focal_pct <- .fn_pct_string(card$focal_pct)
  avg_pct   <- .fn_pct_string(card$cat_avg_pct)
  sprintf(
    '<div class="tk-hero-card fn-card fn-card-relationship" style="border-left-color:%s;">
       <div class="tk-hero-label">%s</div>
       <div class="fn-card-row">
         <div class="tk-hero-value" style="color:%s;">%s</div>
       </div>
       <div class="fn-card-compare">Category avg: <strong>%s</strong></div>
     </div>',
    focal_colour, .fn_esc(card$attitude_label),
    focal_colour, focal_pct, avg_pct
  )
}


.fn_sig_badge <- function(direction) {
  if (direction == "higher") return('<span class="fn-sig fn-sig-up">&uarr;</span>')
  if (direction == "lower")  return('<span class="fn-sig fn-sig-down">&darr;</span>')
  return("")
}


# ==============================================================================
# INTERNAL: SECTION SLOTS (populated by table + chart helpers)
# ==============================================================================

.fn_chart_header <- function(pd) {
  # Stage info for stacked emphasis chips
  stage_keys   <- pd$table$stage_keys   %||% character(0)
  stage_labels <- pd$table$stage_labels %||% list()

  # Cat Avg chip stays as a standalone toggle chip (per Decision 2, Cat avg
  # remains a chip; the brand list moves to the BrandSelector dropdown in
  # the table-controls bar). Cat Avg is on by default under all modes.
  chips_html <- '<button type="button" class="col-chip fn-chip-avg" data-fn-action="toggle-avg">Cat Avg</button>'

  # Stage selector chips for bar view: first stage active by default
  stage_chips <- if (length(stage_keys) > 0)
    paste(vapply(seq_along(stage_keys), function(j) {
      k   <- stage_keys[j]
      lbl <- stage_labels[[k]] %||% k
      cls <- if (j == 1) "fn-stk-emph-chip fn-stk-emph-active" else "fn-stk-emph-chip"
      sprintf('<button type="button" class="%s" data-fn-stk-emphasis="%s">%s</button>',
              cls, .fn_esc(k), .fn_esc(lbl))
    }, character(1)), collapse = "")
  else ""

  paste0(
    '<div class="fn-chart-header">',
    # View toggle: always visible
    '<div class="sig-level-switcher fn-view-switcher" role="group" aria-label="View">',
    '<span class="sig-level-label">View:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-action="chartview" data-fn-view="slope" aria-pressed="true">Slope</button>',
    '<button type="button" class="sig-btn" data-fn-action="chartview" data-fn-view="bar" aria-pressed="false">Bar</button>',
    '</div>',
    # Brand chips: always visible
    '<div class="fn-chart-brand-chips col-chip-bar">', chips_html, '</div>',
    # Slope-only controls
    '<div class="sig-level-switcher fn-slope-ctl" role="group" aria-label="Values">',
    '<span class="sig-level-label">Values:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-action="showvalues" data-fn-showvalues="focal" aria-pressed="true">Focal</button>',
    '<button type="button" class="sig-btn" data-fn-action="showvalues" data-fn-showvalues="all" aria-pressed="false">All</button>',
    '<button type="button" class="sig-btn" data-fn-action="showvalues" data-fn-showvalues="none" aria-pressed="false">None</button>',
    '</div>',
    '<div class="sig-level-switcher fn-shading-switcher fn-slope-ctl" role="group" aria-label="Shading">',
    '<span class="sig-level-label">Shading:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-action="shading" data-fn-shading="range" aria-pressed="true">Range</button>',
    '<button type="button" class="sig-btn" data-fn-action="shading" data-fn-shading="ci" aria-pressed="false">CI</button>',
    '<button type="button" class="sig-btn" data-fn-action="shading" data-fn-shading="none" aria-pressed="false">None</button>',
    '</div>',
    '<div class="fn-yaxis-range fn-slope-ctl">',
    '<span class="sig-level-label">Y-axis:</span>',
    '<input type="number" class="fn-yaxis-input" data-fn-yaxis="min" placeholder="0" min="0" max="100" step="5">',
    '<span class="fn-yaxis-sep">\u2013</span>',
    '<input type="number" class="fn-yaxis-input" data-fn-yaxis="max" placeholder="100" min="0" max="100" step="5">',
    '<button type="button" class="fn-yaxis-reset" data-fn-action="yaxisreset" title="Reset y-axis">\u21BA</button>',
    '</div>',
    # Bar-only controls: stage selector
    if (length(stage_keys) > 0) paste0(
      '<div class="fn-stk-ctl fn-stk-emph-row" hidden>',
      '<span class="sig-level-label">Stage:</span>',
      stage_chips,
      '</div>'
    ) else '',
    '</div>'
  )
}


.fn_table_section <- function(pd, focal_colour) {
  build_funnel_table_section(pd, focal_colour)
}

.fn_chart_section <- function(pd, focal_colour) {
  build_funnel_chart_section(pd, focal_colour)
}

.fn_relationship_section <- function(pd, focal_colour) {
  build_funnel_relationship_section(pd, focal_colour)
}


# ==============================================================================
# INTERNAL: ABOUT DRAWER
# ==============================================================================

.fn_about_section <- function(pd) {
  # Pulls the "About this funnel" body from the central callout registry
  # (modules/shared/lib/callouts/callouts.json -> brand.funnel) so the
  # text is editable via the Callout Editor without touching code.
  if (exists("turas_callout", mode = "function")) {
    turas_callout("brand", "funnel", collapsed = TRUE)
  } else {
    ""
  }
}


# ==============================================================================
# INTERNAL: HELPERS
# ==============================================================================

.funnel_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  payload <- list(
    meta = pd$meta,
    cards = pd$cards,
    table = pd$table,
    shape_chart = pd$shape_chart,
    consideration_detail = pd$consideration_detail,
    config = pd$config,
    focal_colour = focal_colour
  )
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null",
                   pretty = FALSE, digits = 6)
}


.fn_pct_string <- function(pct) {
  if (is.null(pct) || is.na(pct)) return("&ndash;")
  sprintf("%.0f%%", 100 * pct)
}


.fn_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


.fn_capitalise <- function(x) {
  if (is.null(x) || !nzchar(x)) return("")
  paste0(toupper(substring(x, 1, 1)), substring(x, 2))
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
