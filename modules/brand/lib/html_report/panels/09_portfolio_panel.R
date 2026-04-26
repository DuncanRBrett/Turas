# ==============================================================================
# BRAND MODULE - PORTFOLIO PANEL HTML RENDERER
# ==============================================================================
# Overrides build_br_portfolio_panel() from 03_page_builder.R with a new
# implementation that consumes run_portfolio() output (§6.1 data structure).
#
# Phase 2: Footprint (§4.1) + Category Context (§4.3) subtabs active.
#          Competitive Set + Extension subtabs render a "coming in next phase"
#          placeholder so the nav is complete but non-functional until Phase 4/3.
#
# Sub-renderers (to be added in later phases):
#   09_portfolio_panel_chart.R  — chart wrappers
#   09_portfolio_panel_table.R  — table wrappers
# ==============================================================================

PORTFOLIO_PANEL_VERSION <- "1.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

.pf_esc <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# PUBLIC ENTRY POINT  (overrides 03_page_builder.R version)
# ==============================================================================

#' Build the portfolio tab HTML panel
#'
#' Replaces the legacy \code{build_br_portfolio_panel()} from
#' \code{03_page_builder.R} with an implementation that consumes the full
#' §6.1 data structure produced by \code{run_portfolio()}.
#'
#' @param results List. Full \code{run_brand()} result.
#' @param config List. Loaded brand config.
#'
#' @return Character. HTML fragment for the portfolio tab panel.
#' @keywords internal
build_br_portfolio_panel <- function(results, config) {
  focal_colour <- config$colour_focal %||% "#1A5276"
  focal_brand  <- config$focal_brand  %||% ""

  portfolio <- results$results$portfolio

  if (is.null(portfolio) || identical(portfolio$status, "REFUSED")) {
    return(.pf_empty_panel("Portfolio analysis not available."))
  }

  panel_data <- tryCatch(
    build_portfolio_panel_data(portfolio, config, results$structure),
    error = function(e) {
      message(sprintf("[BRAND HTML] Portfolio panel data failed: %s", e$message))
      NULL
    }
  )

  overview <- tryCatch(
    if (exists("build_portfolio_overview", mode = "function"))
      build_portfolio_overview(results, config) else NULL,
    error = function(e) {
      message(sprintf("[BRAND HTML] Portfolio overview failed: %s", e$message))
      NULL
    }
  )

  ov_html <- if (!is.null(overview) && identical(overview$status, "PASS") &&
                  exists(".pf_overview_subtab", mode = "function")) {
    .pf_overview_subtab(overview, focal_brand, focal_colour,
                        about_text = panel_data$about$overview %||% "")
  } else {
    '<p style="color:#94a3b8;padding:24px 0;">Overview data not available.</p>'
  }

  fp_html <- .pf_footprint_subtab(portfolio, panel_data, focal_brand, focal_colour)
  cn_html <- .pf_constellation_subtab(portfolio, panel_data, focal_brand, focal_colour)
  cl_html <- .pf_clutter_subtab(portfolio, panel_data, focal_brand, focal_colour)
  ex_html <- .pf_extension_subtab(portfolio, panel_data, focal_brand, focal_colour)

  timeframe_label <- if (identical(portfolio$timeframe, "3m")) "3-month" else "13-month"
  n_label         <- format(portfolio$n_total %||% 0L, big.mark = ",")

  paste0(
    '<div class="br-panel" id="panel-portfolio">',
    '<div class="br-section">',
    '<div class="pf-panel">',

    # Panel header
    '<h2 style="font-size:20px;color:#1e293b;margin:0 0 4px;">Portfolio Mapping</h2>',
    sprintf(
      '<p style="font-size:12px;color:#64748b;margin:0 0 16px;">Cross-category brand presence. Timeframe: %s. Base: all %s respondents.</p>',
      timeframe_label, n_label
    ),

    # NOTE: removed the top hero KPI strip (§5) per Duncan — those four
    # "focal category" cards were misleading because the portfolio panel
    # has no single focal category. The four per-focal-brand cards on
    # the Overview sub-tab cover the same information correctly.

    # 5-subtab nav
    .pf_sub_nav(),

    # Overview subtab (default)
    '<div class="pf-subtab active" id="pf-subtab-overview">',
    ov_html,
    '</div>',

    # Footprint subtab
    '<div class="pf-subtab" id="pf-subtab-footprint">',
    fp_html,
    '</div>',

    # Competitive Set subtab
    '<div class="pf-subtab" id="pf-subtab-constellation">',
    cn_html,
    '</div>',

    # Category Context subtab
    '<div class="pf-subtab" id="pf-subtab-clutter">',
    cl_html,
    '</div>',

    # Extension subtab
    '<div class="pf-subtab" id="pf-subtab-extension">',
    ex_html,
    '</div>',

    '</div>',  # .pf-panel
    '</div>',  # .br-section
    '</div>'   # .br-panel
  )
}


# ==============================================================================
# HERO STRIP KPI CARDS (§5)
# ==============================================================================

# Look up the focal brand's display NAME, preferring (in order):
#   1. The brand_names map already computed by compute_footprint_matrix
#      and threaded through panel_data$footprint.
#   2. The portfolio_overview cats_list, where each category records its
#      brand_codes + brand_names — Overview is computed independently and
#      always available alongside the Portfolio panel.
#   3. The focal brand code itself, as a last-resort fallback.
.pf_resolve_focal_name <- function(panel_data, portfolio, focal_brand) {
  if (is.null(focal_brand) || !nzchar(focal_brand)) return("")

  # 1. Footprint brand_names map.
  fp_names <- panel_data$footprint$brand_names
  if (!is.null(fp_names) && length(fp_names) > 0 &&
      focal_brand %in% names(fp_names)) {
    v <- fp_names[[focal_brand]]
    if (!is.null(v) && length(v) > 0 && !is.na(v) && nzchar(as.character(v)))
      return(as.character(v))
  }

  # 2. Overview cats_list (used when overview was built via the
  #    .po_build_category_record pipeline).
  ov_cats <- portfolio$overview$categories
  if (!is.null(ov_cats)) {
    for (cat in ov_cats) {
      codes <- cat$brand_codes %||% character(0)
      names_v <- cat$brand_names %||% codes
      idx <- match(focal_brand, codes)
      if (!is.na(idx) && idx <= length(names_v) && nzchar(names_v[idx]))
        return(as.character(names_v[idx]))
    }
  }

  # 3. Fallback.
  focal_brand
}


.pf_hero_strip <- function(supporting, focal_brand, focal_colour,
                            focal_brand_name = NULL) {
  if (is.null(supporting)) return("")

  .kpi <- function(value, label) {
    sprintf(
      '<div class="pf-kpi-card"><div class="pf-kpi-value">%s</div><div class="pf-kpi-label">%s</div></div>',
      .pf_esc(value), .pf_esc(label)
    )
  }

  fmt_n <- function(x) if (is.null(x) || is.na(x)) "\u2014" else
    format(round(x, 1), nsmall = 1)
  fmt_x <- function(x) if (is.null(x) || is.na(x)) "\u2014" else
    sprintf("%.1f\u00d7", x)

  n_cats <- supporting$n_cats_total %||% 0L
  breadth <- supporting$focal_footprint_breadth %||% 0L

  # Use the focal brand display name when available \u2014 e.g.
  # "Ina Paarman's Kitchen present across categories" rather than
  # "IPK present across categories". Falls back to the code if the
  # name isn't supplied.
  focal_label <- if (!is.null(focal_brand_name) && nzchar(focal_brand_name))
                   focal_brand_name else focal_brand

  paste0(
    '<div class="pf-hero-strip">',
    .kpi(fmt_n(supporting$avg_awareness_set_size_focal_cat),
         "Brands known per buyer in focal category"),
    .kpi(sprintf("%d of %d", breadth, n_cats),
         paste(focal_label, "present across categories")),
    .kpi(fmt_x(supporting$focal_awareness_efficiency),
         "Awareness efficiency vs category penetration"),
    .kpi(fmt_n(supporting$mean_repertoire_depth),
         "Avg categories shopped per respondent"),
    '</div>'
  )
}


# ==============================================================================
# SUBTAB NAV
# ==============================================================================

.pf_sub_nav <- function() {
  paste0(
    '<div class="pf-sub-nav" role="tablist">',
    '<button class="pf-sub-btn active" data-pf-subtab="overview"',
    '  onclick="pfSwitchSubtab(\'overview\')"',
    '  role="tab" aria-selected="true">Overview</button>',
    '<button class="pf-sub-btn" data-pf-subtab="footprint"',
    '  onclick="pfSwitchSubtab(\'footprint\')"',
    '  role="tab" aria-selected="false">Footprint</button>',
    '<button class="pf-sub-btn" data-pf-subtab="constellation"',
    '  onclick="pfSwitchSubtab(\'constellation\')"',
    '  role="tab" aria-selected="false">Competitive Set</button>',
    '<button class="pf-sub-btn" data-pf-subtab="clutter"',
    '  onclick="pfSwitchSubtab(\'clutter\')"',
    '  role="tab" aria-selected="false">Category Context</button>',
    '<button class="pf-sub-btn" data-pf-subtab="extension"',
    '  onclick="pfSwitchSubtab(\'extension\')"',
    '  role="tab" aria-selected="false">Extension</button>',
    '</div>'
  )
}


# ==============================================================================
# FOOTPRINT SUBTAB
# ==============================================================================

.pf_footprint_subtab <- function(portfolio, panel_data, focal_brand,
                                  focal_colour) {
  section_id <- "pf-footprint"

  # Footprint block (matrix_df, bases_df, cat_names, brand_names,
  # suppressed_cats) is assembled by .portfolio_footprint_block().
  footprint <- panel_data$footprint
  if (is.null(footprint)) {
    # Fallback to portfolio_result if panel_data didn't run.
    fp_df <- portfolio$footprint_matrix
    if (!is.null(fp_df) && nrow(fp_df) > 0) {
      meta <- portfolio$footprint_meta %||% list()
      footprint <- list(
        matrix_df       = fp_df,
        bases_df        = portfolio$bases$per_category,
        cat_names       = meta$cat_names %||% character(0),
        brand_names     = meta$brand_names %||% character(0),
        n_total         = portfolio$n_total %||% NA_integer_,
        suppressed_cats = portfolio$suppressions$low_base_cats %||% character(0)
      )
    }
  }

  if (is.null(footprint) || is.null(footprint$matrix_df) ||
      nrow(footprint$matrix_df) == 0) {
    return(paste0(
      .pf_section_toolbar(section_id),
      '<p style="color:#94a3b8;padding:24px 0;">Footprint data not available.</p>'
    ))
  }

  table_html <- if (exists("build_pf_footprint_html", mode = "function")) {
    tryCatch(
      build_pf_footprint_html(footprint, focal_brand, focal_colour),
      error = function(e) sprintf(
        '<p style="color:#b91c1c;padding:16px 0;">Footprint render failed: %s</p>',
        .pf_esc(e$message)
      )
    )
  } else {
    '<p style="color:#94a3b8;padding:24px 0;">Footprint renderer not loaded.</p>'
  }

  about_text <- if (!is.null(panel_data)) {
    panel_data$about$footprint %||% ""
  } else ""

  paste0(
    .pf_section_toolbar(section_id),
    '<div id="', section_id, '-chart" style="margin:8px 0;">',
    table_html,
    '</div>',
    if (nzchar(about_text)) {
      sprintf('<div class="pf-about-drawer"><strong>About this chart:</strong> %s</div>',
              .pf_esc(about_text))
    } else ""
  )
}


# ==============================================================================
# CONSTELLATION SUBTAB
# ==============================================================================

.pf_constellation_subtab <- function(portfolio, panel_data, focal_brand,
                                      focal_colour) {
  section_id <- "pf-constellation"

  # Prefer the per-category set; fall back to the legacy pooled
  # constellation if the per-cat compute didn't run.
  per_cat <- portfolio$constellation_per_cat
  has_per_cat <- !is.null(per_cat) && length(per_cat$by_cat %||% list()) > 0

  if (!has_per_cat) {
    cn <- portfolio$constellation
    if (is.null(cn) || is.null(cn$nodes) || nrow(cn$nodes) == 0) {
      return(paste0(
        .pf_section_toolbar(section_id),
        '<p style="color:#94a3b8;padding:24px 0;">Competitive constellation data not available.</p>'
      ))
    }
    chart_svg <- tryCatch(
      build_network(
        nodes        = cn$nodes,
        edges        = cn$edges,
        layout       = cn$layout,
        focal_colour = focal_colour,
        title        = "Competitive Constellation (Co-awareness Jaccard)"
      ),
      error = function(e) ""
    )
    return(paste0(
      .pf_section_toolbar(section_id),
      '<div id="', section_id, '-chart" style="margin:8px 0;">',
      chart_svg,
      '</div>'
    ))
  }

  cat_codes <- per_cat$cat_order
  cat_names <- per_cat$cat_names %||% list()
  default_cat <- if (length(cat_codes) > 0) cat_codes[1] else ""

  # Union of brands that appear in any per-cat network (each carries
  # both code + display label). The focal-brand <select> picks from this
  # union — every brand the user might want to centre the analysis on.
  brand_union <- list()
  for (cc in cat_codes) {
    nd <- per_cat$by_cat[[cc]]$nodes
    if (is.null(nd) || nrow(nd) == 0) next
    for (i in seq_len(nrow(nd))) {
      bc <- nd$brand[i]
      if (!bc %in% names(brand_union)) {
        brand_union[[bc]] <- as.character(nd$brand_lbl[i] %||% bc)
      }
    }
  }
  brand_codes  <- names(brand_union)
  brand_labels <- vapply(brand_codes, function(bc) brand_union[[bc]], character(1))
  ord <- order(brand_codes != focal_brand, tolower(brand_labels))
  brand_codes  <- brand_codes[ord]
  brand_labels <- brand_labels[ord]

  focal_options <- paste(vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    nm  <- brand_labels[i]
    sel <- if (identical(bc, focal_brand)) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .pf_esc(bc), sel, .pf_esc(nm))
  }, character(1)), collapse = "")

  # Picker chips — one per category with a constellation.
  chips <- vapply(seq_along(cat_codes), function(i) {
    cc  <- cat_codes[i]
    nm  <- as.character(cat_names[[cc]] %||% cc)
    active_cls <- if (identical(cc, default_cat)) " pf-cn-cat-chip-on" else ""
    sprintf(
      '<button type="button" class="pf-cn-cat-chip%s" data-pf-cn-cat="%s">%s</button>',
      active_cls, .pf_esc(cc), .pf_esc(tolower(nm))
    )
  }, character(1))

  # JSON payload — one entry per cat, edges + node labels. JS uses this to
  # rebuild the "Closest competitors to <focal>" list whenever the user
  # changes the focal-brand picker, without the round-trip of a re-render.
  panel_data_json <- .pf_cn_to_json(per_cat)
  data_script <- sprintf(
    '<script type="application/json" id="pf-cn-data">%s</script>',
    panel_data_json
  )

  # One <div> per category — only the default starts visible. Each
  # category panel includes the SVG chart and a side panel that JS fills
  # with the closest-competitors list for the active focal.
  panels <- vapply(seq_along(cat_codes), function(i) {
    cc <- cat_codes[i]
    nm <- as.character(cat_names[[cc]] %||% cc)
    cn <- per_cat$by_cat[[cc]]
    chart_svg <- tryCatch(
      build_network(
        nodes        = cn$nodes,
        edges        = cn$edges,
        layout       = cn$layout,
        focal_colour = focal_colour,
        title        = paste0("Competitive Constellation — ", nm)
      ),
      error = function(e) ""
    )
    n_brands <- nrow(cn$nodes)
    n_edges  <- nrow(cn$edges)
    sub <- sprintf("%d brands · %d co-awareness edges", n_brands, n_edges)
    visible_cls <- if (identical(cc, default_cat)) "" else " hidden"
    sprintf(
      '<div class="pf-cn-cat-panel%s" data-pf-cn-cat-panel="%s">
         <div class="pf-cn-layout">
           <div class="pf-cn-chart-wrap">
             <div class="pf-cn-meta">%s</div>%s
           </div>
           <aside class="pf-cn-side">
             <h4 class="pf-cn-side-title">Closest competitors</h4>
             <p class="pf-cn-side-sub">Brands ranked by co-awareness Jaccard with the focal. Higher = consumers tend to know both brands together — direct mental-space rivals.</p>
             <ol class="pf-cn-rivals" data-pf-cn-rivals="%s"></ol>
           </aside>
         </div>
       </div>',
      visible_cls, .pf_esc(cc), .pf_esc(sub), chart_svg, .pf_esc(cc)
    )
  }, character(1))

  # Suppressed-categories note (cats too sparse / low-base for a constellation).
  supp_df <- per_cat$suppressed_cats
  supp_note <- if (!is.null(supp_df) && nrow(supp_df) > 0) {
    items <- paste(vapply(seq_len(nrow(supp_df)), function(i) {
      sprintf("%s (%s)", .pf_esc(supp_df$cat[i]), .pf_esc(supp_df$reason[i]))
    }, character(1)), collapse = ", ")
    sprintf('<p class="pf-cn-suppressed">Categories without a constellation: %s</p>', items)
  } else ""

  reading_guide <- paste0(
    '<div class="pf-cn-reading">',
    '<p class="pf-cn-reading-line"><strong>How to read it:</strong> ',
    'Each dot is a brand. The lines that light up in the focal colour connect your focal (highlighted with the dashed ring) to its co-awareness rivals — thicker line = stronger Jaccard, so a thicker line means consumers are more likely to know both brands together. ',
    'Hover any dot to see its exact Jaccard score with the focal, plus how it ranks against the other brands in this category.</p>',

    '<p class="pf-cn-reading-line"><strong>About distance on the chart:</strong> ',
    'The position of each dot is set by a <em>force-directed layout</em> — every brand is pulled toward all the brands it shares awareness with, not just toward your focal. ',
    'That means a brand can sit visually closer to your focal than another even though its Jaccard score is lower (it gets dragged that way by its own ties to other brands). ',
    'Trust the highlighted lines and the side-panel ranking for the focal-vs-rival comparison; use the dot positions to read the wider <em>shape</em> of the network — clusters of brands that hang together, isolated outliers, and so on.</p>',

    '<p class="pf-cn-reading-line"><strong>What the numbers mean:</strong> ',
    'The score next to each rival in the side panel is a <em>Jaccard similarity</em> — the overlap in awareness between two brands. ',
    'Imagine everyone in the category who is aware of <em>either</em> brand A <em>or</em> brand B. ',
    'Jaccard asks: of those people, what percentage are aware of <em>both</em>? ',
    '<strong>80%</strong> means almost everyone who knows one brand also knows the other — they live in the same mental space and you have to win consumer attention against them directly. ',
    '<strong>20%</strong> means awareness barely overlaps — the two brands are known by mostly different people, so they’re not really competing for the same minds.</p>',

    '<p class="pf-cn-reading-line"><strong>What to do with it:</strong> ',
    'The brands at the top of the side list are the ones to study first — they’re your real rivals in this category. ',
    'If your focal sits alone with no high-Jaccard neighbours, you have distinctive mental space to defend. ',
    'If it sits inside a tight cluster, your differentiation is doing less work than the chart might suggest. ',
    'Use the focal picker to repeat the read for any other brand in this category, or switch categories with the chips above.</p>',
    '</div>'
  )

  paste0(
    .pf_section_toolbar(section_id),
    data_script,
    '<div class="pf-cn-controls">',
    '<div class="pf-cn-ctl-group">',
    '<label for="pf-cn-focal-select" class="pf-cn-ctl-label">Focal brand</label>',
    sprintf('<select id="pf-cn-focal-select" class="pf-cn-focal-select" data-pf-cn-focal="%s">%s</select>',
            .pf_esc(focal_brand), focal_options),
    '</div>',
    '<div class="pf-cn-ctl-group">',
    '<span class="pf-cn-ctl-label">Category</span>',
    sprintf('<div class="pf-cn-cat-chips">%s</div>',
            paste(chips, collapse = "")),
    '</div>',
    '</div>',
    sprintf('<div id="%s-chart" class="pf-cn-cat-panels" data-pf-cn-focal="%s">%s</div>',
            section_id, .pf_esc(focal_brand), paste(panels, collapse = "")),
    supp_note,
    reading_guide
  )
}


# Compact JSON serialiser for the per-category constellations. The
# payload is tiny — node code + label + per-pair Jaccard — but enough
# for the JS-side competitors-list re-compute on focal change.
.pf_cn_to_json <- function(per_cat) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  by_cat <- per_cat$by_cat %||% list()
  payload <- lapply(by_cat, function(cn) {
    nodes <- cn$nodes
    edges <- cn$edges
    list(
      nodes = if (!is.null(nodes) && nrow(nodes) > 0) {
        lapply(seq_len(nrow(nodes)), function(i) list(
          code  = as.character(nodes$brand[i]),
          label = as.character(nodes$brand_lbl[i] %||% nodes$brand[i]),
          n_aw  = as.numeric(nodes$n_aware_w[i])
        ))
      } else list(),
      edges = if (!is.null(edges) && nrow(edges) > 0) {
        lapply(seq_len(nrow(edges)), function(i) list(
          b1  = as.character(edges$b1[i]),
          b2  = as.character(edges$b2[i]),
          jac = as.numeric(edges$jaccard[i])
        ))
      } else list()
    )
  })
  tryCatch(
    jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = 4),
    error = function(e) "{}"
  )
}


# ==============================================================================
# CLUTTER SUBTAB
# ==============================================================================

.pf_clutter_subtab <- function(portfolio, panel_data, focal_brand,
                                focal_colour) {
  section_id <- "pf-clutter"
  cl <- portfolio$clutter
  if (is.null(cl) || is.null(cl$clutter_df) || nrow(cl$clutter_df) == 0) {
    return(paste0(
      .pf_section_toolbar(section_id),
      '<p style="color:#94a3b8;padding:24px 0;">Category context data not available.</p>'
    ))
  }

  clutter_df <- cl$clutter_df

  # Initial render — uses the configured focal. JS swaps the SVG to a
  # client-rendered version when the focal picker changes.
  df_plot <- clutter_df
  df_plot$focal_share_pct <- df_plot$focal_share_of_aware * 100
  initial_svg <- tryCatch(
    build_scatter(
      df              = df_plot,
      x_col           = "awareness_set_size_mean",
      y_col           = "focal_share_pct",
      label_col       = "cat",
      focal_label     = NULL,
      brand_colour    = focal_colour,
      comp_colour     = "#64748b",
      title           = "Category context — clutter vs focal brand position",
      x_label         = "Awareness set size (brands known per buyer)",
      y_label         = "Focal share of awareness (%)",
      y_suffix        = "%",
      quadrant_labels = c("Dominant", "Contested",
                          "Niche opportunity", "Forgotten / wrong battle"),
      ref_x           = cl$ref_x,
      ref_y           = if (!is.na(cl$ref_y)) cl$ref_y * 100 else NULL,
      size_col        = "cat_penetration"
    ),
    error = function(e) ""
  )

  # JSON payload — per-category awareness data + ref_x. JS recomputes
  # focal_share_of_aware, fair_share and quadrant on focal change, then
  # rebuilds the SVG without a server round-trip.
  per_cat_full <- panel_data$clutter$per_cat_full %||% cl$per_cat_full %||% list()
  payload_json <- .pf_cl_to_json(per_cat_full, cl$ref_x, focal_colour)
  data_script <- sprintf(
    '<script type="application/json" id="pf-cl-data">%s</script>',
    payload_json
  )

  # Brand picker — union of brands across all clutter cats, focal first.
  brand_union <- list()
  for (cc in names(per_cat_full)) {
    pcs <- per_cat_full[[cc]]
    codes <- names(pcs$brand_pcts %||% list())
    lbls  <- pcs$brand_lbls %||% list()
    for (bc in codes) {
      if (!bc %in% names(brand_union)) {
        brand_union[[bc]] <- as.character(lbls[[bc]] %||% bc)
      }
    }
  }
  brand_codes  <- names(brand_union)
  brand_labels <- vapply(brand_codes, function(bc) brand_union[[bc]], character(1))
  ord <- order(brand_codes != focal_brand, tolower(brand_labels))
  brand_codes  <- brand_codes[ord]
  brand_labels <- brand_labels[ord]

  focal_options <- paste(vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    nm  <- brand_labels[i]
    sel <- if (identical(bc, focal_brand)) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .pf_esc(bc), sel, .pf_esc(nm))
  }, character(1)), collapse = "")

  # Server emits an empty table shell — JS fills it from the JSON
  # payload so the table re-renders when the focal brand changes.
  table_shell <- '<div id="pf-cl-table-host" class="pf-cl-table-host"></div>'
  coverage_note <- '<p id="pf-cl-coverage" class="pf-cl-coverage"></p>'

  reading_guide <- paste0(
    '<div class="pf-cl-reading">',
    '<p class="pf-cl-reading-line"><strong>How to read it:</strong> ',
    'Each dot is a category. Its position is set by two numbers about your focal brand’s mental availability in that category. ',
    'The dot size is the category’s overall penetration (how many of all respondents qualify as buyers there).</p>',

    '<p class="pf-cl-reading-line"><strong>The two axes:</strong> ',
    '<em>X (horizontal)</em> = the average number of brands a buyer in that category is aware of. Far right = cluttered mental space (consumers know lots of brands here, hard to break through). Far left = sparse mental space (few brands top-of-mind, lower threshold to be salient). ',
    '<em>Y (vertical)</em> = your focal brand’s <em>share</em> of all brand-awareness mentions in that category. High up = focal owns a big slice of mental availability. Low down = focal is one of many or barely registers.</p>',

    '<p class="pf-cl-reading-line"><strong>Why the Y axis differs from the awareness % on the Overview tab:</strong> ',
    'These are two different metrics — the table below shows both side by side. ',
    '<em>Focal awareness</em> (on the Overview tab) is the simple "% of category buyers aware of the focal" — e.g. <strong>58%</strong> know All Gold in Pasta Sauces. ',
    '<em>Focal share of awareness</em> (this chart’s Y axis) is the focal’s slice of the total awareness pie: focal awareness ÷ sum of every brand’s awareness. ',
    'In a category where buyers each know 4–5 brands on average, those individual awareness scores can sum to 400% or more, so a 58% awareness rate ends up as roughly <strong>14%</strong> share of awareness. ',
    'Awareness % tells you how many people know the brand at all; share of awareness tells you how big a slice of mental space the brand owns once you account for how many other brands are competing for that same head-space.</p>',

    '<p class="pf-cl-reading-line"><strong>The four quadrants:</strong> ',
    '<strong>Dominant</strong> (top-left, low clutter / high share) — you own this category mentally. <em>Defend it.</em> ',
    '<strong>Contested</strong> (top-right, high clutter / high share) — cluttered space but you’re winning. <em>Keep investing to hold ground.</em> ',
    '<strong>Niche opportunity</strong> (bottom-left, low clutter / low share) — tractable category where presence could grow. <em>Evaluate as an expansion target.</em> ',
    '<strong>Forgotten / wrong battle</strong> (bottom-right, high clutter / low share) — hard to break through and you have low presence. <em>Consider deprioritising marketing spend.</em></p>',

    '<p class="pf-cl-reading-line"><strong>What to do with it:</strong> ',
    'Hover any dot to see the exact set size, focal awareness, share of awareness, category penetration and quadrant. ',
    'Switch the focal-brand picker to read the same map for any other brand — the chart redraws instantly. ',
    'Use the table below for the precise numbers in a sortable form.</p>',
    '</div>'
  )

  # Category show/hide chips — one per category in the data, all on by
  # default. Toggling hides the dot from the scatter without recomputing.
  cat_chips <- vapply(names(per_cat_full), function(cc) {
    nm <- as.character(per_cat_full[[cc]]$cat_label %||% cc)
    sprintf(
      '<button type="button" class="pf-cl-cat-chip pf-cl-cat-chip-on" data-pf-cl-cat="%s">%s</button>',
      .pf_esc(cc), .pf_esc(tolower(nm))
    )
  }, character(1))

  paste0(
    .pf_section_toolbar(section_id),
    data_script,
    '<div class="pf-cl-controls">',
    '<div class="pf-cl-ctl-group">',
    '<label for="pf-cl-focal-select" class="pf-cl-ctl-label">Focal brand</label>',
    sprintf('<select id="pf-cl-focal-select" class="pf-cl-focal-select" data-pf-cl-focal="%s">%s</select>',
            .pf_esc(focal_brand), focal_options),
    '</div>',
    '<div class="pf-cl-ctl-group">',
    '<span class="pf-cl-ctl-label">Categories</span>',
    sprintf('<div class="pf-cl-cat-chips">%s</div>',
            paste(cat_chips, collapse = "")),
    '</div>',
    '</div>',
    sprintf('<div id="%s-chart" class="pf-cl-chart" data-pf-cl-focal="%s" data-pf-cl-focal-colour="%s">%s</div>',
            section_id, .pf_esc(focal_brand), .pf_esc(focal_colour), initial_svg),
    coverage_note,
    table_shell,
    reading_guide
  )
}


# JSON for the Category Context client-side renderer.
.pf_cl_to_json <- function(per_cat_full, ref_x, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  payload <- list(
    ref_x        = if (is.null(ref_x) || is.na(ref_x)) NULL else as.numeric(ref_x),
    focal_colour = focal_colour,
    cats         = lapply(per_cat_full, function(c) {
      list(
        cat_code        = c$cat_code,
        cat_label       = c$cat_label,
        set_size_mean   = c$set_size_mean,
        cat_penetration = c$cat_penetration,
        n_brands        = c$n_brands,
        brand_pcts      = c$brand_pcts,
        brand_lbls      = c$brand_lbls
      )
    })
  )
  tryCatch(
    jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = 4),
    error = function(e) "{}"
  )
}


.pf_clutter_table <- function(clutter_df) {
  if (nrow(clutter_df) == 0) return("")
  rows_html <- paste(vapply(seq_len(nrow(clutter_df)), function(i) {
    r <- clutter_df[i, ]
    sprintf(
      '<tr><td>%s</td><td>%.1f</td><td>%.1f%%</td><td>%.1f%%</td><td>%s</td></tr>',
      .pf_esc(r$cat),
      r$awareness_set_size_mean,
      r$focal_share_of_aware * 100,
      r$cat_penetration * 100,
      .pf_esc(r$quadrant)
    )
  }, character(1)), collapse = "")

  paste0(
    '<div style="margin-top:16px;overflow-x:auto;">',
    '<table style="width:100%;border-collapse:collapse;font-size:12px;">',
    '<thead><tr style="background:#f8fafc;font-weight:600;color:#475569;">',
    '<th style="padding:8px;text-align:left;border-bottom:1px solid #e2e8f0;">Category</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Avg brands known</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Focal share</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Cat. penetration</th>',
    '<th style="padding:8px;text-align:left;border-bottom:1px solid #e2e8f0;">Quadrant</th>',
    '</tr></thead><tbody>',
    rows_html,
    '</tbody></table></div>'
  )
}


# ==============================================================================
# EXTENSION SUBTAB
# ==============================================================================

.pf_extension_subtab <- function(portfolio, panel_data, focal_brand, focal_colour) {
  section_id <- "pf-extension"

  strength    <- portfolio$strength
  ext_per_br  <- portfolio$extension_per_brand

  if (is.null(ext_per_br) || length(ext_per_br$per_brand %||% list()) == 0) {
    return(paste0(
      .pf_section_toolbar(section_id),
      '<p style="color:#94a3b8;padding:24px 0;">Extension analysis data not available.</p>'
    ))
  }

  # ---- Brand picker — every brand for which we have an extension result.
  # Append cat-coverage suffix to each option ("Brand (3 cats)") so the
  # user sees up front which brands have rich cross-cat awareness data
  # versus those measured only in their home category.
  brand_codes  <- names(ext_per_br$per_brand)
  brand_names  <- ext_per_br$brand_names %||% list()
  brand_labels <- vapply(brand_codes, function(bc) {
    v <- brand_names[[bc]]
    if (is.null(v) || !nzchar(v)) bc else as.character(v)
  }, character(1))
  brand_coverage <- vapply(brand_codes, function(bc) {
    res <- ext_per_br$per_brand[[bc]]
    df  <- res$extension_df
    if (is.null(df) || nrow(df) == 0) return(0L)
    as.integer(nrow(df))
  }, integer(1))
  # Sort: focal first; then brands with >1 cat (more useful for extension)
  # before single-cat brands; tiebreak alphabetical.
  ord <- order(brand_codes != focal_brand,
               brand_coverage <= 1,
               tolower(brand_labels))
  brand_codes    <- brand_codes[ord]
  brand_labels   <- brand_labels[ord]
  brand_coverage <- brand_coverage[ord]
  if (!focal_brand %in% brand_codes && length(brand_codes) > 0) {
    focal_brand <- brand_codes[1]
  }

  focal_options <- paste(vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    nm  <- brand_labels[i]
    nc  <- brand_coverage[i]
    sel <- if (identical(bc, focal_brand)) " selected" else ""
    suffix <- if (nc > 0) sprintf(" (%d cat%s)", nc, if (nc == 1) "" else "s") else ""
    sprintf('<option value="%s"%s>%s%s</option>',
            .pf_esc(bc), sel, .pf_esc(nm), suffix)
  }, character(1)), collapse = "")

  # ---- JSON payload — strength bubbles + extension rows for every brand.
  payload_json <- .pf_ex_to_json(strength, ext_per_br, focal_colour)
  data_script <- sprintf(
    '<script type="application/json" id="pf-ex-data">%s</script>',
    payload_json
  )

  # ---- Initial server-side strength SVG so the page works pre-JS.
  initial_svg <- ''
  if (!is.null(strength) && !is.null(strength$per_brand) &&
      focal_brand %in% names(strength$per_brand)) {
    fb_df <- strength$per_brand[[focal_brand]]
    if (nrow(fb_df) >= 2) {
      fb_df$cat_pen_pct    <- fb_df$cat_pen * 100
      fb_df$brand_aware_pct <- fb_df$brand_aware
      initial_svg <- tryCatch(
        build_bubble_scatter(
          df           = fb_df,
          x_col        = "cat_pen_pct",
          y_col        = "brand_aware_pct",
          label_col    = "cat_label",
          size_col     = "aware_n_w",
          brand_colour = focal_colour,
          title        = sprintf("Portfolio strength — %s",
                                  brand_labels[match(focal_brand, brand_codes)])
        ),
        error = function(e) ""
      )
    }
  }

  reading_guide <- paste0(
    '<div class="pf-ex-reading">',

    '<p class="pf-ex-reading-line"><strong>What this tab actually answers:</strong> ',
    'two related questions about the focal brand’s mental availability. ',
    'The <em>strength map</em> on the left says <em>"where does this brand stand right now, across the categories we measured it in?"</em> ',
    'The <em>extension table</em> on the right says <em>"of those measured categories, which ones could the brand plausibly extend into next?"</em></p>',

    '<p class="pf-ex-reading-line"><strong>What it needs in the data:</strong> ',
    'Both views can only score categories where the questionnaire actually asked buyers of that category whether they’re aware of the focal brand. ',
    'In your study this is set by the BrandList sheet — every brand × category combination where the brand is listed has a `BRANDAWARE_<cat>_<brand>` column in the data. ',
    'A brand listed in <em>all</em> categories (typically the study’s focal client) gets a full read. ',
    'A brand listed in only its home category gets only one row — and the extension half can’t do anything for it until the next wave adds cross-category awareness. ',
    'The number after each option in the picker (<em>"Brand (3 cats)"</em>) tells you up front how much data is available for that brand.</p>',

    '<p class="pf-ex-reading-line"><strong>How to read the strength map:</strong> ',
    '<em>X (horizontal)</em> = how many of all respondents are buyers of that category — its market size. ',
    '<em>Y (vertical)</em> = the focal brand’s awareness <strong>among</strong> those buyers — how big the focal looms in the minds of people who actually shop the category. ',
    'Bubble size = the weighted count of aware buyers; big bubbles are categories where lots of real people know the brand. ',
    '<strong>Top-right</strong> — big category, the focal is well-known: bread-and-butter. ',
    '<strong>Top-left</strong> — small but you dominate awareness: a defensible niche. ',
    '<strong>Bottom-right</strong> — big category but the focal is barely known: opportunity or wrong-battle. ',
    '<strong>Bottom-left</strong> — small and unknown: usually deprioritise.</p>',

    '<p class="pf-ex-reading-line"><strong>How to read the extension table:</strong> ',
    'For every measured category that <em>isn’t</em> the focal’s home, <em>lift</em> = how much more likely buyers of that category are to be aware of the focal compared with the baseline awareness rate. ',
    '<strong>Lift &gt; 1</strong> means buyers of that category have an above-average awareness of the focal — there’s a halo to lean on if you launched there. ',
    '<strong>Lift ≈ 1</strong> means no halo; entering would be cold-starting awareness. ',
    '<strong>★</strong> = significant after BH correction across all rows; <strong>†</strong> = low category base, interpret cautiously. ',
    'The home row sits at the top as a reference and is greyed out — it’s not an extension target, it’s where the brand already lives.</p>',

    '<p class="pf-ex-reading-line"><strong>How lift is actually calculated:</strong> ',
    '<code class="pf-ex-formula">lift(category) = P(aware of focal | bought category) ÷ P(aware of focal | baseline)</code> ',
    'In plain English: the numerator is the share of <em>that category’s buyers</em> who are aware of the focal brand (the "Aware of focal" column in the table). ',
    'The denominator is the share of <em>the baseline group</em> who are aware of the focal brand <em>in the same awareness column</em> — by default the baseline is <strong>all respondents</strong> in the survey (set by <code>portfolio_extension_baseline</code> in config; the alternative is <em>non-buyers of the home category</em>).</p>',

    '<p class="pf-ex-reading-line"><strong>Worked example:</strong> ',
    'Imagine the focal brand has <strong>70%</strong> awareness among Pasta Sauces buyers (numerator) and <strong>40%</strong> awareness among all 1,200 respondents in the survey (denominator, because not everyone shops Pasta Sauces). ',
    'Lift = 70 ÷ 40 = <strong>1.75×</strong>. ',
    'Read: Pasta Sauces buyers are 1.75× more likely than the average respondent to be aware of the focal — that’s a meaningful halo, the brand has equity to lean on if it launched a Pasta Sauces line. ',
    'Hover any row to see both numbers (numerator + baseline) for the live data.</p>',

    '<p class="pf-ex-reading-line"><strong>What to do with it:</strong> ',
    'Hover any bubble or row to see the exact numbers. ',
    'For a focal brand with rich coverage (the study’s focal client), the extension table is your shortlist of plausible expansion categories — high lift + statistical significance + a meaningfully large category base = a sound target. ',
    'For a brand the questionnaire only asked about in one category, the strength map will still show that single bubble, but the extension table will explicitly tell you there’s nothing to extend into in this dataset — either accept that limitation, or add cross-category awareness for that brand in the next wave.</p>',
    '</div>'
  )

  paste0(
    .pf_section_toolbar(section_id),
    data_script,
    '<div class="pf-ex-controls">',
    '<div class="pf-ex-ctl-group">',
    '<label for="pf-ex-focal-select" class="pf-ex-ctl-label">Focal brand</label>',
    sprintf('<select id="pf-ex-focal-select" class="pf-ex-focal-select" data-pf-ex-focal="%s">%s</select>',
            .pf_esc(focal_brand), focal_options),
    '</div>',
    '</div>',
    sprintf('<div class="pf-ex-layout" data-pf-ex-focal="%s" data-pf-ex-focal-colour="%s">',
            .pf_esc(focal_brand), .pf_esc(focal_colour)),
    sprintf('<div id="%s-strength" class="pf-ex-strength">%s</div>', section_id, initial_svg),
    sprintf('<div id="%s-table" class="pf-ex-table-host"></div>', section_id),
    '</div>',
    reading_guide
  )
}


# Compact JSON for the Extension subtab — strength bubbles + extension
# rows + cat-name lookup. Iterates the per-brand extension table and
# normalises numeric columns to plain JS-friendly arrays.
.pf_ex_to_json <- function(strength, ext_per_br, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  cat_names <- ext_per_br$cat_names %||% list()
  brand_names <- ext_per_br$brand_names %||% list()

  # Strength bubbles per brand — pre-formatted for the JS bubble renderer.
  strength_payload <- if (!is.null(strength) && !is.null(strength$per_brand)) {
    lapply(strength$per_brand, function(df) {
      if (is.null(df) || nrow(df) == 0) return(list())
      lapply(seq_len(nrow(df)), function(i) {
        list(
          cat       = as.character(df$cat[i]),
          cat_label = as.character(df$cat_label[i] %||% df$cat[i]),
          x         = as.numeric(df$cat_pen[i]) * 100,
          y         = as.numeric(df$brand_aware[i]),
          size      = as.numeric(df$aware_n_w[i])
        )
      })
    })
  } else list()

  # Extension table per brand.
  ext_payload <- lapply(ext_per_br$per_brand, function(res) {
    df <- res$extension_df
    if (is.null(df) || nrow(df) == 0)
      return(list(home_cat = res$home_cat %||% "", rows = list()))
    list(
      home_cat        = res$home_cat %||% "",
      home_cat_source = res$home_cat_source %||% "",
      rows = lapply(seq_len(nrow(df)), function(i) list(
        cat            = as.character(df$cat[i]),
        cat_label      = as.character(cat_names[[df$cat[i]]] %||% df$cat[i]),
        is_home        = isTRUE(df$is_home[i]),
        n_buyers_uw    = as.integer(df$n_buyers_uw[i]),
        focal_aware_pct = as.numeric(df$focal_aware_pct[i]),
        lift           = as.numeric(df$lift[i]),
        p_adj          = as.numeric(df$p_adj[i]),
        low_base_flag  = isTRUE(df$low_base_flag[i])
      ))
    )
  })

  payload <- list(
    focal_colour = focal_colour,
    cat_names    = cat_names,
    brand_names  = brand_names,
    strength     = strength_payload,
    extension    = ext_payload
  )
  tryCatch(
    jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = 4),
    error = function(e) "{}"
  )
}


# ==============================================================================
# SHARED HELPERS
# ==============================================================================

.pf_section_toolbar <- function(section_id) {
  sprintf(
    '<div class="br-section-toolbar" style="display:flex;gap:8px;margin-bottom:12px;">
  <button class="br-pin-btn" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin to Views"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:15px;padding:5px 10px;color:#94a3b8;">
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
  <button class="br-insight-toggle" onclick="_brToggleInsight(\'%s\')"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    + Add Insight
  </button>
</div>
<div class="br-insight-container" data-section="%s" style="display:none;margin-bottom:16px;position:relative;">
  <textarea class="br-insight-editor" data-section="%s" placeholder="Type key insight here..."
    style="width:100%%;min-height:60px;border:1px solid #e2e8f0;border-radius:6px;padding:10px;font-family:inherit;font-size:13px;resize:vertical;"></textarea>
  <div class="br-insight-rendered" data-section="%s" ondblclick="_brToggleInsightEdit(\'%s\')"
    style="display:none;padding:10px;border:1px solid #e2e8f0;border-radius:6px;min-height:40px;cursor:pointer;font-size:13px;line-height:1.5;"></div>
  <button class="br-insight-dismiss" onclick="_brDismissInsight(\'%s\')"
    style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:16px;position:absolute;top:4px;right:8px;">&times;</button>
</div>',
    section_id, section_id, section_id, section_id, section_id,
    section_id, section_id, section_id, section_id, section_id
  )
}

.pf_empty_panel <- function(msg = "Portfolio analysis not available.") {
  sprintf(
    '<div class="br-panel" id="panel-portfolio"><div class="br-section"><p style="color:#94a3b8;padding:32px;text-align:center;">%s</p></div></div>',
    .pf_esc(msg)
  )
}
