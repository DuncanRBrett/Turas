# ==============================================================================
# BRAND HTML REPORT - MAIN GENERATOR
# ==============================================================================
# Generates a complete, self-contained HTML report for brand analysis.
# Full page with all CSS/JS inline, TurasPins, insight boxes, and
# conditional sections based on activated elements.
#
# Follows the Turas HTML report pattern:
# - Full DOCTYPE page (not fragment) for report_hub iframe embedding
# - Design system base CSS + module-specific CSS
# - TurasPins JS for pinning/export
# - Tab navigation with conditional panel visibility
# - Meta tag: turas-report-type="brand"
#
# VERSION: 1.0
# ==============================================================================

BRAND_HTML_VERSION <- "1.0"


# --- Source design system if not loaded ---
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

  pins_js_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!exists("turas_pins_js", mode = "function") && file.exists(pins_js_path)) {
    source(pins_js_path, local = FALSE)
  }
})


#' HTML-escape a string
#' @keywords internal
.brand_html_escape <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


#' Build an HTML table from a data frame
#'
#' @param df Data frame to render.
#' @param title Character. Optional section title above the table.
#' @param focal_brand Character. Brand to highlight (optional).
#' @param pct_cols Character vector. Columns to format as percentages.
#' @param caption Character. Table caption (optional).
#'
#' @return Character string of HTML.
#' @keywords internal
.brand_html_table <- function(df, title = NULL, focal_brand = NULL,
                               pct_cols = NULL, caption = NULL) {
  if (is.null(df) || nrow(df) == 0) return("")

  lines <- character(0)

  if (!is.null(title)) {
    lines <- c(lines, sprintf('<h3 class="section-title">%s</h3>',
                               .brand_html_escape(title)))
  }

  lines <- c(lines, '<div class="table-wrapper">')
  lines <- c(lines, '<table class="turas-table">')

  if (!is.null(caption)) {
    lines <- c(lines, sprintf('<caption>%s</caption>',
                               .brand_html_escape(caption)))
  }

  # Header
  lines <- c(lines, '<thead><tr>')
  for (col in names(df)) {
    lines <- c(lines, sprintf('<th>%s</th>', .brand_html_escape(col)))
  }
  lines <- c(lines, '</tr></thead>')

  # Body
  lines <- c(lines, '<tbody>')
  for (i in seq_len(nrow(df))) {
    brand_val <- if ("BrandCode" %in% names(df)) df$BrandCode[i] else NULL
    row_class <- if (!is.null(focal_brand) && !is.null(brand_val) &&
                     brand_val == focal_brand) ' class="focal-row"' else ""

    lines <- c(lines, sprintf('<tr%s>', row_class))
    for (col in names(df)) {
      val <- df[[col]][i]
      if (!is.null(pct_cols) && col %in% pct_cols && is.numeric(val)) {
        cell <- sprintf("%.1f%%", val)
      } else if (is.numeric(val)) {
        cell <- format(val, big.mark = ",")
      } else {
        cell <- .brand_html_escape(as.character(val))
      }
      lines <- c(lines, sprintf('<td>%s</td>', cell))
    }
    lines <- c(lines, '</tr>')
  }
  lines <- c(lines, '</tbody></table></div>')

  paste(lines, collapse = "\n")
}


#' Build a metric card (headline number with label)
#' @keywords internal
.brand_metric_card <- function(value, label, sublabel = NULL) {
  sub_html <- if (!is.null(sublabel)) {
    sprintf('<div class="metric-sublabel">%s</div>', .brand_html_escape(sublabel))
  } else ""
  sprintf(
    '<div class="metric-card"><div class="metric-value">%s</div><div class="metric-label">%s</div>%s</div>',
    .brand_html_escape(as.character(value)),
    .brand_html_escape(label),
    sub_html
  )
}


#' Build section panel HTML for one element within a category
#' @keywords internal
.brand_element_section <- function(element_name, content_html, category = NULL) {
  id <- paste0("section-", gsub("[^a-z0-9]", "-", tolower(element_name)))
  if (!is.null(category)) {
    id <- paste0(id, "-", gsub("[^a-z0-9]", "-", tolower(category)))
  }
  sprintf(
    '<div class="element-section" id="%s"><h2 class="element-title">%s</h2>%s</div>',
    id, .brand_html_escape(element_name), content_html
  )
}


# ==============================================================================
# ELEMENT HTML BUILDERS
# ==============================================================================

#' Build Mental Availability HTML section
#' @keywords internal
.build_ma_html <- function(ma, focal_brand, category) {
  if (is.null(ma) || identical(ma$status, "REFUSED")) return("")

  parts <- character(0)

  # Headline metrics cards
  ms <- ma$metrics_summary
  if (!is.null(ms)) {
    parts <- c(parts, '<div class="metric-cards">')
    parts <- c(parts, .brand_metric_card(
      sprintf("%.1f%%", (ms$focal_mms %||% 0) * 100),
      "Mental Market Share",
      sprintf("Rank %s of %s", ms$mms_rank %||% "?", ms$n_brands %||% "?")
    ))
    parts <- c(parts, .brand_metric_card(
      sprintf("%.1f%%", (ms$focal_mpen %||% 0) * 100),
      "Mental Penetration"
    ))
    parts <- c(parts, .brand_metric_card(
      sprintf("%.1f", ms$focal_ns %||% 0),
      "Network Size",
      sprintf("CEPs per linker")
    ))
    parts <- c(parts, '</div>')
  }

  # MMS table
  parts <- c(parts, .brand_html_table(
    ma$mms, "Mental Market Share by Brand", focal_brand,
    pct_cols = "MMS",
    caption = sprintf("n = %d respondents", ma$n_respondents %||% 0)
  ))

  # CEP x Brand matrix
  parts <- c(parts, .brand_html_table(
    ma$cep_brand_matrix, "CEP x Brand Linkage (%)", focal_brand
  ))

  # CEP Penetration
  parts <- c(parts, .brand_html_table(
    ma$cep_penetration, "CEP Penetration Ranking",
    pct_cols = "Penetration_Pct"
  ))

  # CEP TURF
  if (!is.null(ma$cep_turf) && !is.null(ma$cep_turf$incremental_table)) {
    parts <- c(parts, .brand_html_table(
      ma$cep_turf$incremental_table, "CEP TURF - Reach Optimisation",
      pct_cols = c("Reach_Pct", "Incremental_Pct")
    ))
  }

  .brand_element_section("Mental Availability", paste(parts, collapse = "\n"),
                          category)
}


#' Build Funnel HTML section
#' @keywords internal
.build_funnel_html <- function(funnel, focal_brand, category) {
  if (is.null(funnel) || identical(funnel$status, "REFUSED")) return("")

  parts <- character(0)

  # Headline cards from metrics summary
  ms <- funnel$metrics_summary
  if (!is.null(ms)) {
    parts <- c(parts, '<div class="metric-cards">')
    parts <- c(parts, .brand_metric_card(
      sprintf("%.0f%%", ms$focal_aware %||% 0), "Aided Awareness"
    ))
    parts <- c(parts, .brand_metric_card(
      sprintf("%.0f%%", ms$focal_positive %||% 0), "Positive Disposition"
    ))
    parts <- c(parts, .brand_metric_card(
      sprintf("%.0f%%", ms$focal_bought %||% 0), "Bought in Period"
    ))
    parts <- c(parts, .brand_metric_card(
      sprintf("%.0f%%", ms$focal_reject %||% 0), "Active Rejection"
    ))
    parts <- c(parts, '</div>')
  }

  # Stage metrics
  parts <- c(parts, .brand_html_table(
    funnel$stage_metrics, "Brand Funnel - Stage Metrics", focal_brand,
    pct_cols = c("Aware_Pct", "Positive_Pct", "Love_Pct", "Prefer_Pct",
                 "Ambivalent_Pct", "Reject_Pct", "NoOpinion_Pct",
                 "Bought_Pct", "Primary_Pct"),
    caption = sprintf("n = %d", funnel$n_respondents %||% 0)
  ))

  # Conversion ratios
  parts <- c(parts, .brand_html_table(
    funnel$conversion_metrics, "Stage-to-Stage Conversion (%)", focal_brand,
    pct_cols = c("Aware_to_Positive", "Positive_to_Bought", "Bought_to_Primary")
  ))

  .brand_element_section("Brand Funnel", paste(parts, collapse = "\n"), category)
}


#' Build Repertoire HTML section
#' @keywords internal
.build_repertoire_html <- function(rep, focal_brand, category) {
  if (is.null(rep) || identical(rep$status, "REFUSED")) return("")

  parts <- character(0)

  parts <- c(parts, '<div class="metric-cards">')
  parts <- c(parts, .brand_metric_card(
    rep$mean_repertoire, "Mean Repertoire Size", "brands per buyer"
  ))
  parts <- c(parts, .brand_metric_card(
    rep$n_buyers, "Category Buyers",
    sprintf("of %d respondents", rep$n_respondents %||% 0)
  ))
  parts <- c(parts, '</div>')

  parts <- c(parts, .brand_html_table(
    rep$repertoire_size, "Repertoire Size Distribution",
    pct_cols = "Percentage"
  ))
  parts <- c(parts, .brand_html_table(
    rep$sole_loyalty, "Sole Loyalty by Brand", focal_brand,
    pct_cols = "SoleLoyalty_Pct"
  ))

  if (!is.null(rep$brand_overlap) && nrow(rep$brand_overlap) > 0) {
    parts <- c(parts, .brand_html_table(
      rep$brand_overlap,
      sprintf("Brand Overlap with %s Buyers", focal_brand %||% "Focal"),
      pct_cols = "Overlap_Pct"
    ))
  }

  .brand_element_section("Repertoire", paste(parts, collapse = "\n"), category)
}


#' Build Drivers & Barriers HTML section
#' @keywords internal
.build_db_html <- function(db, focal_brand, category) {
  if (is.null(db) || identical(db$status, "REFUSED")) return("")

  parts <- character(0)

  # Show top columns from importance
  if (!is.null(db$importance)) {
    display_cols <- intersect(
      c("Code", "Label", "Buyer_Pct", "NonBuyer_Pct",
        "Differential", "Importance_Rank"),
      names(db$importance)
    )
    parts <- c(parts, .brand_html_table(
      db$importance[, display_cols, drop = FALSE],
      "Derived Importance (Buyer vs Non-Buyer Differential)",
      pct_cols = c("Buyer_Pct", "NonBuyer_Pct", "Differential")
    ))
  }

  # I x P quadrants
  if (!is.null(db$ixp_quadrants)) {
    display_cols <- intersect(
      c("Code", "Label", "Differential", "Focal_Linkage_Pct", "Quadrant"),
      names(db$ixp_quadrants)
    )
    parts <- c(parts, .brand_html_table(
      db$ixp_quadrants[, display_cols, drop = FALSE],
      "Importance x Performance Quadrants",
      pct_cols = c("Differential", "Focal_Linkage_Pct")
    ))
  }

  # Rejection themes
  if (!is.null(db$rejection_themes) && nrow(db$rejection_themes) > 0) {
    parts <- c(parts, .brand_html_table(
      db$rejection_themes,
      sprintf("Rejection Themes - %s", focal_brand %||% "Focal Brand"),
      pct_cols = "Pct"
    ))
  }

  .brand_element_section("Drivers & Barriers",
                          paste(parts, collapse = "\n"), category)
}


#' Build WOM HTML section
#' @keywords internal
.build_wom_html <- function(wom, focal_brand) {
  if (is.null(wom) || identical(wom$status, "REFUSED")) return("")

  parts <- character(0)

  parts <- c(parts, .brand_html_table(
    wom$wom_metrics, "Word-of-Mouth Metrics", focal_brand,
    pct_cols = c("ReceivedPos_Pct", "ReceivedNeg_Pct",
                 "SharedPos_Pct", "SharedNeg_Pct")
  ))
  parts <- c(parts, .brand_html_table(
    wom$net_balance, "Net WOM Balance", focal_brand
  ))

  .brand_element_section("Word-of-Mouth", paste(parts, collapse = "\n"))
}


#' Build DBA HTML section
#' @keywords internal
.build_dba_html <- function(dba, focal_brand) {
  if (is.null(dba) || identical(dba$status, "REFUSED")) return("")

  parts <- character(0)

  parts <- c(parts, .brand_html_table(
    dba$dba_metrics, "Distinctive Brand Assets", NULL,
    pct_cols = c("Fame_Pct", "Uniqueness_Pct")
  ))

  .brand_element_section("Distinctive Brand Assets",
                          paste(parts, collapse = "\n"))
}


# ==============================================================================
# MAIN GENERATOR
# ==============================================================================

#' Generate brand HTML report
#'
#' Creates a complete, self-contained HTML page from brand analysis results.
#'
#' @param results List. Output from \code{run_brand()}.
#' @param output_path Character. Path for the HTML file.
#' @param config List. Brand config.
#'
#' @return List with status and output_path.
#'
#' @export
generate_brand_html_report <- function(results, output_path, config = NULL) {

  if (is.null(results) || identical(results$status, "REFUSED")) {
    return(list(status = "REFUSED", message = "No results to render"))
  }

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  focal_brand <- config$focal_brand %||% ""
  project_name <- config$project_name %||% "Brand Health"
  report_title <- config$report_title %||% "Brand Health Report"
  report_subtitle <- config$report_subtitle %||% ""
  brand_colour <- config$colour_focal %||% "#323367"
  accent_colour <- config$colour_focal_accent %||% "#CC9900"

  # --- Build CSS ---
  css <- ""
  if (exists("turas_base_css", mode = "function")) {
    css <- turas_base_css(brand_colour = brand_colour,
                           accent_colour = accent_colour)
  }

  # Module-specific CSS
  brand_css <- sprintf('
    .metric-cards { display: flex; gap: 16px; flex-wrap: wrap; margin: 20px 0; }
    .metric-card { background: #fff; border: 1px solid #e0e0e0; border-radius: 8px;
      padding: 16px 20px; min-width: 140px; text-align: center; flex: 1; }
    .metric-value { font-size: 28px; font-weight: 700; color: %s; }
    .metric-label { font-size: 13px; color: #546E7A; margin-top: 4px; }
    .metric-sublabel { font-size: 11px; color: #90A4AE; }
    .element-section { margin-bottom: 32px; padding: 24px; background: #fff;
      border-radius: 8px; border: 1px solid #e0e0e0; }
    .element-title { font-size: 20px; color: %s; margin: 0 0 16px 0;
      border-bottom: 2px solid %s; padding-bottom: 8px; }
    .section-title { font-size: 16px; color: #37474F; margin: 20px 0 8px 0; }
    .table-wrapper { overflow-x: auto; margin: 12px 0; }
    .focal-row { background: #E3F2FD !important; font-weight: 600; }
    .report-header { background: %s; color: #fff; padding: 24px 32px;
      border-radius: 0 0 12px 12px; margin-bottom: 24px; }
    .report-header h1 { margin: 0; font-size: 24px; }
    .report-header .subtitle { opacity: 0.8; font-size: 14px; margin-top: 4px; }
    .report-meta { display: flex; gap: 24px; margin-top: 12px; font-size: 12px; opacity: 0.7; }
    .category-section { margin-top: 32px; }
    .category-heading { font-size: 22px; color: %s; margin: 0 0 16px;
      padding: 12px 0; border-bottom: 3px solid %s; }
    .about-section { background: #f5f5f5; padding: 20px; border-radius: 8px;
      margin-top: 32px; font-size: 13px; line-height: 1.6; color: #546E7A; }
    .about-section h3 { color: %s; }
  ', brand_colour, brand_colour, brand_colour, brand_colour,
     brand_colour, brand_colour, brand_colour)

  # --- Build body content ---
  body_parts <- character(0)

  # Header
  body_parts <- c(body_parts, sprintf('
    <div class="report-header">
      <h1>%s</h1>
      <div class="subtitle">%s</div>
      <div class="report-meta">
        <span>Client: %s</span>
        <span>Focal Brand: %s</span>
        <span>Wave: %s</span>
        <span>Generated: %s</span>
      </div>
    </div>',
    .brand_html_escape(report_title),
    .brand_html_escape(report_subtitle),
    .brand_html_escape(config$client_name %||% ""),
    .brand_html_escape(focal_brand),
    config$wave %||% 1,
    format(Sys.time(), "%d %b %Y")
  ))

  # Per-category sections
  if (!is.null(results$results$categories)) {
    for (cat_name in names(results$results$categories)) {
      cat_res <- results$results$categories[[cat_name]]

      body_parts <- c(body_parts, sprintf(
        '<div class="category-section"><h2 class="category-heading">%s</h2>',
        .brand_html_escape(cat_name)
      ))

      body_parts <- c(body_parts,
        .build_ma_html(cat_res$mental_availability, focal_brand, cat_name),
        .build_funnel_html(cat_res$funnel, focal_brand, cat_name),
        .build_repertoire_html(cat_res$repertoire, focal_brand, cat_name),
        .build_db_html(cat_res$drivers_barriers, focal_brand, cat_name)
      )

      body_parts <- c(body_parts, '</div>')
    }
  }

  # Brand-level elements
  body_parts <- c(body_parts,
    .build_wom_html(results$results$wom, focal_brand),
    .build_dba_html(results$results$dba, focal_brand)
  )

  # About section
  show_about <- config$show_about_section %||% TRUE
  if (isTRUE(show_about) || identical(show_about, "Y")) {
    body_parts <- c(body_parts, '
      <div class="about-section">
        <h3>About & Methodology</h3>
        <p>This report uses the <strong>Category Buyer Mindset (CBM)</strong>
        framework developed by Jenni Romaniuk at the Ehrenberg-Bass Institute.</p>
        <p><strong>Mental Market Share (MMS)</strong> measures the brand\'s share
        of all brand-CEP links in the category. <strong>Mental Penetration (MPen)</strong>
        measures the proportion of category buyers who link the brand to at least
        one Category Entry Point. <strong>Network Size (NS)</strong> measures the
        average number of CEPs linked among those who link at least one.</p>
        <p><strong>Key references:</strong></p>
        <ul>
          <li>Romaniuk, J. (2022). <em>Better Brand Health</em>. Oxford University Press.</li>
          <li>Sharp, B. (2010). <em>How Brands Grow</em>. Oxford University Press.</li>
          <li>Romaniuk, J. (2018). <em>Building Distinctive Brand Assets</em>. Oxford University Press.</li>
        </ul>
        <p>Report generated by TURAS Analytics Platform. All significance tests
        conducted at the specified alpha level with appropriate corrections.</p>
      </div>')
  }

  # --- Assemble full page ---
  # Get TurasPins JS if available
  pins_js <- ""
  if (exists("turas_pins_js", mode = "function")) {
    pins_js <- tryCatch(turas_pins_js(include_vendor = TRUE),
                        error = function(e) "")
  }

  html <- sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="turas-report-type" content="brand">
  <meta name="turas-source-filename" content="%s">
  <title>%s</title>
  <style>
    %s
    %s
  </style>
</head>
<body style="background:#f8f7f5; max-width:1100px; margin:0 auto; padding:16px;">
  %s
  <div id="pinned-views-data" style="display:none;">[]</div>
  <script>
    %s
  </script>
</body>
</html>',
    .brand_html_escape(basename(output_path)),
    .brand_html_escape(report_title),
    css,
    brand_css,
    paste(body_parts, collapse = "\n"),
    pins_js
  )

  # Write file
  writeLines(html, output_path, useBytes = TRUE)

  cat(sprintf("  Brand HTML report generated: %s\n", output_path))

  list(
    status = "PASS",
    output_path = output_path,
    message = sprintf("HTML report generated at %s", output_path)
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand HTML report generator loaded (v%s)",
                  BRAND_HTML_VERSION))
}
