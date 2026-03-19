# ==============================================================================
# SEGMENT HTML REPORT - EXPLORATION MODE REPORT
# ==============================================================================
# Builds the exploration (k-selection) HTML report variant.
# Shows elbow chart, silhouette chart, metrics table, k comparisons,
# and recommended k.
# Version: 11.0
# ==============================================================================


#' Generate Segment Exploration HTML Report
#'
#' Alternative entry point for exploration-mode reports. Called from
#' generate_segment_html_report() when results$mode == "exploration".
#'
#' @param results List with exploration results
#' @param config Configuration list
#' @param output_path Character, output file path (.html)
#' @return List with status, output_file, file_size_mb, warnings
#' @keywords internal
generate_segment_exploration_html_report <- function(results, config, output_path) {

  start_time <- Sys.time()

  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  SEGMENT EXPLORATION HTML REPORT\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================

  cat("  Step 1: Validating inputs...\n")
  guard_result <- validate_segment_html_inputs(results, config, output_path)

  if (guard_result$status == "REFUSED") {
    cat(sprintf("    REFUSED: %s\n", guard_result$message %||% guard_result$code))
    return(guard_result)
  }

  # ==========================================================================
  # STEP 2: TRANSFORM DATA
  # ==========================================================================

  cat("  Step 2: Transforming data...\n")
  html_data <- tryCatch(
    transform_segment_for_html(results, config),
    error = function(e) {
      cat(sprintf("    ERROR: Data transformation failed: %s\n", e$message))
      NULL
    }
  )

  if (is.null(html_data)) {
    return(list(
      status = "REFUSED",
      code = "CALC_TRANSFORM_FAILED",
      message = "Failed to transform exploration data for HTML report."
    ))
  }

  # ==========================================================================
  # STEP 3: BUILD CHARTS
  # ==========================================================================

  cat("  Step 3: Building charts...\n")
  warnings <- character(0)
  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  charts <- list()

  charts$elbow <- tryCatch(
    build_seg_elbow_chart(html_data, brand_colour),
    error = function(e) {
      warnings <<- c(warnings, paste("Elbow chart:", e$message))
      NULL
    }
  )

  charts$metrics <- tryCatch(
    build_seg_metrics_chart(html_data, brand_colour, accent_colour),
    error = function(e) {
      warnings <<- c(warnings, paste("Metrics chart:", e$message))
      NULL
    }
  )

  cat(sprintf("    Built %d charts\n", sum(!sapply(charts, is.null))))

  # ==========================================================================
  # STEP 4: BUILD TABLES
  # ==========================================================================

  cat("  Step 4: Building tables...\n")
  tables <- list()

  tables$metrics <- tryCatch(
    build_seg_exploration_metrics_table(html_data),
    error = function(e) {
      warnings <<- c(warnings, paste("Metrics table:", e$message))
      NULL
    }
  )

  tables$k_comparison <- tryCatch(
    build_seg_k_comparison_table(html_data),
    error = function(e) {
      warnings <<- c(warnings, paste("K comparison table:", e$message))
      NULL
    }
  )

  cat(sprintf("    Built %d tables\n", sum(!sapply(tables, is.null))))

  # ==========================================================================
  # STEP 5: ASSEMBLE HTML PAGE
  # ==========================================================================

  cat("  Step 5: Assembling HTML page...\n")
  page <- tryCatch(
    build_seg_exploration_page(html_data, tables, charts, config),
    error = function(e) {
      cat(sprintf("    ERROR: Page assembly failed: %s\n", e$message))
      NULL
    }
  )

  if (is.null(page)) {
    return(list(
      status = "REFUSED",
      code = "CALC_PAGE_BUILD_FAILED",
      message = "Failed to assemble exploration HTML page."
    ))
  }

  # ==========================================================================
  # STEP 6: WRITE HTML FILE
  # ==========================================================================

  cat("  Step 6: Writing HTML file...\n")
  write_result <- write_seg_html_report(page, output_path)

  if (write_result$status == "REFUSED") {
    return(write_result)
  }

  # ==========================================================================
  # DONE
  # ==========================================================================

  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
  final_status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat(sprintf("  Exploration report complete (%s, %.1fs)\n", final_status, elapsed))
  if (length(warnings) > 0) {
    cat(sprintf("  %d warning(s):\n", length(warnings)))
    for (w in warnings) cat(sprintf("    - %s\n", w))
  }
  cat(paste(rep("-", 60), collapse = ""), "\n")

  list(
    status = final_status,
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    elapsed_seconds = elapsed,
    warnings = if (length(warnings) > 0) warnings else NULL
  )
}


# ==============================================================================
# EXPLORATION TABLE BUILDERS
# ==============================================================================


#' Build Exploration Metrics Table
#'
#' Shows k, silhouette, within-SS, CH index, and other metrics for each k tested.
#'
#' @param html_data Exploration mode data from transformer
#' @return htmltools tag or NULL
#' @keywords internal
build_seg_exploration_metrics_table <- function(html_data) {

  metrics_df <- html_data$metrics_df
  if (is.null(metrics_df) || nrow(metrics_df) == 0) return(NULL)

  # Find available columns
  k_col <- intersect(names(metrics_df), c("k", "K", "n_clusters"))[1]
  sil_col <- intersect(names(metrics_df), c("avg_silhouette", "silhouette", "avg_sil"))[1]
  wss_col <- intersect(names(metrics_df), c("tot_withinss", "tot.withinss", "withinss"))[1]
  ch_col <- intersect(names(metrics_df), c("ch_index", "calinski_harabasz", "CH"))[1]
  db_col <- intersect(names(metrics_df), c("db_index", "davies_bouldin", "DB"))[1]
  bss_col <- intersect(names(metrics_df), c("betweenss_totss", "bss_tss_ratio", "bss_ratio"))[1]

  if (is.na(k_col)) return(NULL)

  rec_k <- NULL
  if (!is.null(html_data$recommendation)) {
    rec_k <- html_data$recommendation$recommended_k %||%
             html_data$recommendation$k %||% NULL
  }

  # Build header row
  headers <- c("k")
  if (!is.na(sil_col)) headers <- c(headers, "Avg Silhouette")
  if (!is.na(wss_col)) headers <- c(headers, "Within-SS")
  if (!is.na(ch_col)) headers <- c(headers, "CH Index")
  if (!is.na(db_col)) headers <- c(headers, "DB Index")
  if (!is.na(bss_col)) headers <- c(headers, "BSS/TSS")

  header_cells <- lapply(headers, function(h) {
    htmltools::tags$th(class = "seg-th", h)
  })
  header_row <- htmltools::tags$tr(header_cells)

  # Build data rows
  rows <- lapply(seq_len(nrow(metrics_df)), function(i) {
    k_val <- as.integer(metrics_df[[k_col]][i])
    is_rec <- !is.null(rec_k) && k_val == rec_k

    cells <- list(
      htmltools::tags$td(
        class = "seg-td",
        style = if (is_rec) "font-weight:600; color:#CC9900;" else NULL,
        paste0(k_val, if (is_rec) " *" else "")
      )
    )

    if (!is.na(sil_col)) {
      val <- metrics_df[[sil_col]][i]
      cells <- c(cells, list(htmltools::tags$td(
        class = "seg-td seg-mono",
        style = if (is_rec) "font-weight:600; color:#CC9900;" else NULL,
        if (!is.na(val)) sprintf("%.3f", val) else "-"
      )))
    }
    if (!is.na(wss_col)) {
      val <- metrics_df[[wss_col]][i]
      cells <- c(cells, list(htmltools::tags$td(
        class = "seg-td seg-mono",
        if (!is.na(val)) sprintf("%.1f", val) else "-"
      )))
    }
    if (!is.na(ch_col)) {
      val <- metrics_df[[ch_col]][i]
      cells <- c(cells, list(htmltools::tags$td(
        class = "seg-td seg-mono",
        if (!is.na(val)) sprintf("%.1f", val) else "-"
      )))
    }
    if (!is.na(db_col)) {
      val <- metrics_df[[db_col]][i]
      cells <- c(cells, list(htmltools::tags$td(
        class = "seg-td seg-mono",
        if (!is.na(val)) sprintf("%.3f", val) else "-"
      )))
    }
    if (!is.na(bss_col)) {
      val <- metrics_df[[bss_col]][i]
      cells <- c(cells, list(htmltools::tags$td(
        class = "seg-td seg-mono",
        if (!is.na(val)) sprintf("%.0f%%", val * 100) else "-"
      )))
    }

    htmltools::tags$tr(cells)
  })

  htmltools::tags$table(
    class = "seg-table",
    htmltools::tags$thead(header_row),
    htmltools::tags$tbody(rows)
  )
}


#' Build K Comparison Table
#'
#' Shows segment sizes for each k tested.
#'
#' @param html_data Exploration mode data from transformer
#' @return htmltools tag or NULL
#' @keywords internal
build_seg_k_comparison_table <- function(html_data) {

  k_summaries <- html_data$k_summaries
  if (is.null(k_summaries) || length(k_summaries) == 0) return(NULL)

  rec_k <- NULL
  if (!is.null(html_data$recommendation)) {
    rec_k <- html_data$recommendation$recommended_k %||%
             html_data$recommendation$k %||% NULL
  }

  # Each k gets a card-like section
  cards <- lapply(names(k_summaries), function(k_str) {
    ks <- k_summaries[[k_str]]
    k_val <- ks$k
    is_rec <- !is.null(rec_k) && k_val == rec_k
    n_segs <- length(ks$sizes)

    # Segment size bars (mini horizontal bars)
    max_pct <- max(ks$pcts, 100)
    bars <- lapply(seq_len(n_segs), function(s) {
      pct <- ks$pcts[s]
      cnt <- ks$sizes[s]
      bar_width_pct <- pct / max_pct * 100

      htmltools::tags$div(
        style = "display:flex; align-items:center; gap:8px; margin-bottom:4px;",
        htmltools::tags$span(
          style = "width:60px; font-size:12px; color:#64748b; text-align:right;",
          sprintf("Seg %d", s)
        ),
        htmltools::tags$div(
          style = "flex:1; height:16px; background:#f1f5f9; border-radius:3px; overflow:hidden;",
          htmltools::tags$div(
            style = sprintf(
              "width:%.1f%%; height:100%%; background:%s; border-radius:3px; transition:width 0.3s;",
              bar_width_pct, if (is_rec) "#CC9900" else "#323367"
            )
          )
        ),
        htmltools::tags$span(
          style = "width:80px; font-size:11px; color:#94a3b8; font-family:monospace;",
          sprintf("%d (%.0f%%)", cnt, pct)
        )
      )
    })

    # Silhouette badge
    sil_badge <- if (!is.na(ks$silhouette)) {
      sil_val <- ks$silhouette
      sil_color <- if (sil_val >= 0.5) "#16a34a"
                   else if (sil_val >= 0.25) "#CC9900"
                   else "#dc2626"
      htmltools::tags$span(
        style = sprintf(
          "display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:500; color:white; background:%s;",
          sil_color
        ),
        sprintf("Sil: %.3f", sil_val)
      )
    }

    # Card container
    border_color <- if (is_rec) "#CC9900" else "#e2e8f0"
    border_width <- if (is_rec) "2px" else "1px"

    htmltools::tags$div(
      style = sprintf(
        "border:%s solid %s; border-radius:6px; padding:16px; margin-bottom:12px; background:white;",
        border_width, border_color
      ),
      htmltools::tags$div(
        style = "display:flex; align-items:center; justify-content:space-between; margin-bottom:12px;",
        htmltools::tags$div(
          style = "display:flex; align-items:center; gap:10px;",
          htmltools::tags$h4(
            style = sprintf(
              "margin:0; font-size:15px; font-weight:600; color:%s;",
              if (is_rec) "#CC9900" else "#1e293b"
            ),
            sprintf("k = %d", k_val)
          ),
          if (is_rec) htmltools::tags$span(
            style = "display:inline-block; padding:2px 10px; border-radius:10px; font-size:10px; font-weight:600; color:#CC9900; background:#FFF8E7; border:1px solid #CC9900;",
            "RECOMMENDED"
          )
        ),
        sil_badge
      ),
      htmltools::tags$div(bars)
    )
  })

  htmltools::tagList(cards)
}


# ==============================================================================
# EXPLORATION PAGE BUILDER
# ==============================================================================


#' Build Complete Exploration HTML Page
#'
#' @param html_data Transformed exploration data
#' @param tables Named list of table objects
#' @param charts Named list of chart objects
#' @param config Configuration list
#' @return htmltools::browsable tagList
#' @keywords internal
build_seg_exploration_page <- function(html_data, tables, charts, config) {

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title <- config$report_title %||% html_data$analysis_name

  # Build CSS (reuse from page_builder)
  css <- build_seg_css(brand_colour, accent_colour)

  # Additional exploration-specific CSS
  exploration_css <- htmltools::tags$style(htmltools::HTML("
    .seg-exploration-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
      margin-top: 16px;
    }
    @media (max-width: 900px) {
      .seg-exploration-grid {
        grid-template-columns: 1fr;
      }
    }
    .seg-chart-panel {
      background: white;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 20px;
    }
    .seg-chart-panel-title {
      font-size: 13px;
      font-weight: 600;
      color: #1e293b;
      margin-bottom: 12px;
    }
    .seg-recommendation-card {
      background: #FFFBEB;
      border: 2px solid #CC9900;
      border-radius: 8px;
      padding: 24px;
      margin-top: 16px;
    }
    .seg-recommendation-title {
      font-size: 18px;
      font-weight: 600;
      color: #CC9900;
      margin: 0 0 8px 0;
    }
    .seg-recommendation-text {
      font-size: 14px;
      color: #1e293b;
      line-height: 1.6;
      margin: 0;
    }
    .seg-recommendation-reason {
      margin-top: 12px;
      font-size: 13px;
      color: #64748b;
      line-height: 1.5;
    }
  "))

  # Sections
  sections <- list()

  # -- Header --
  sections$header <- build_seg_exploration_header(html_data, config, brand_colour, report_title)

  # -- Recommendation --
  sections$recommendation <- build_seg_recommendation_section(html_data, accent_colour)

  # -- Charts panel --
  sections$charts <- htmltools::tags$div(
    class = "seg-section",
    id = "seg-charts-section",
    `data-seg-section` = "charts",
    htmltools::tags$h3(class = "seg-section-title", "Cluster Evaluation"),
    htmltools::tags$div(
      class = "seg-exploration-grid",
      if (!is.null(charts$elbow)) {
        htmltools::tags$div(
          class = "seg-chart-panel",
          htmltools::tags$div(class = "seg-chart-panel-title", "Elbow Plot (Within-SS by k)"),
          charts$elbow
        )
      },
      if (!is.null(charts$metrics)) {
        htmltools::tags$div(
          class = "seg-chart-panel",
          htmltools::tags$div(class = "seg-chart-panel-title", "Average Silhouette by k"),
          charts$metrics
        )
      }
    )
  )

  # -- Metrics table --
  sections$metrics <- if (!is.null(tables$metrics)) {
    htmltools::tags$div(
      class = "seg-section",
      id = "seg-metrics-section",
      `data-seg-section` = "metrics",
      htmltools::tags$h3(class = "seg-section-title", "Clustering Metrics"),
      htmltools::tags$p(
        class = "seg-section-desc",
        "Comparison of validation metrics across different k values. ",
        "Higher silhouette and CH index indicate better-separated clusters. ",
        "Lower DB index is better. The recommended k is marked with *."
      ),
      tables$metrics
    )
  }

  # -- K comparison cards --
  sections$comparison <- if (!is.null(tables$k_comparison)) {
    htmltools::tags$div(
      class = "seg-section",
      id = "seg-comparison-section",
      `data-seg-section` = "comparison",
      htmltools::tags$h3(class = "seg-section-title", "Solution Previews"),
      htmltools::tags$p(
        class = "seg-section-desc",
        "Segment size distribution for each k tested. ",
        "Look for balanced, interpretable solutions without very small segments."
      ),
      tables$k_comparison
    )
  }

  # -- Footer --
  sections$footer <- build_seg_footer(config)

  # Load JavaScript
  js_dir <- tryCatch({
    normalizePath(file.path(dirname(sys.frame(1)$ofile), "js"), mustWork = FALSE)
  }, error = function(e) {
    turas_root <- Sys.getenv("TURAS_ROOT", getwd())
    file.path(turas_root, "modules/segment/lib/html_report/js")
  })

  js_files <- c("seg_utils.js", "seg_navigation.js", "seg_slide_export.js")
  js_tags <- lapply(js_files, function(jf) {
    jpath <- file.path(js_dir, jf)
    if (file.exists(jpath)) {
      htmltools::tags$script(htmltools::HTML(readLines(jpath, warn = FALSE) |> paste(collapse = "\n")))
    }
  })

  # Assemble final page
  page <- htmltools::browsable(
    htmltools::tagList(
      htmltools::tags$html(
        lang = "en",
        htmltools::tags$head(
          htmltools::tags$meta(charset = "UTF-8"),
          htmltools::tags$meta(
            name = "viewport",
            content = "width=device-width, initial-scale=1.0"
          ),
          htmltools::tags$meta(name = "turas-report-type", content = "segment-exploration"),
          htmltools::tags$meta(name = "turas-module-version", content = "11.0"),
          htmltools::tags$title(paste(report_title, "- K Selection Report")),
          css,
          exploration_css
        ),
        htmltools::tags$body(
          class = "seg-body",
          sections$header,
          htmltools::tags$main(
            class = "seg-main",
            sections$recommendation,
            sections$charts,
            sections$metrics,
            sections$comparison
          ),
          sections$footer,
          js_tags
        )
      )
    )
  )

  page
}


#' Build Exploration Report Header
#' @keywords internal
build_seg_exploration_header <- function(html_data, config, brand_colour, report_title) {

  method_label <- switch(html_data$method,
    kmeans = "K-Means",
    hclust = "Hierarchical",
    gmm = "Gaussian Mixture Model",
    toupper(html_data$method)
  )

  k_range_str <- if (!is.null(html_data$k_range)) {
    sprintf("%d to %d", html_data$k_range[1], html_data$k_range[2])
  } else "unknown"

  htmltools::tags$header(
    class = "seg-header",
    style = sprintf("border-top: 4px solid %s;", brand_colour),
    htmltools::tags$div(
      class = "seg-header-content",
      htmltools::tags$h1(
        class = "seg-report-title",
        report_title
      ),
      htmltools::tags$p(
        class = "seg-report-subtitle",
        "K Selection / Exploration Report"
      ),
      htmltools::tags$div(
        class = "seg-header-meta",
        htmltools::tags$span(
          class = "seg-meta-item",
          htmltools::tags$span(class = "seg-meta-label", "Method"),
          method_label
        ),
        htmltools::tags$span(
          class = "seg-meta-item",
          htmltools::tags$span(class = "seg-meta-label", "K Range"),
          k_range_str
        ),
        htmltools::tags$span(
          class = "seg-meta-item",
          htmltools::tags$span(class = "seg-meta-label", "Successful"),
          sprintf("%d solutions", html_data$n_successful %||% 0)
        ),
        htmltools::tags$span(
          class = "seg-meta-item",
          htmltools::tags$span(class = "seg-meta-label", "Generated"),
          format(Sys.time(), "%d %B %Y, %H:%M")
        )
      )
    )
  )
}


#' Build Recommendation Section
#' @keywords internal
build_seg_recommendation_section <- function(html_data, accent_colour) {

  rec <- html_data$recommendation
  if (is.null(rec)) return(NULL)

  rec_k <- rec$recommended_k %||% rec$k %||% NULL
  if (is.null(rec_k)) return(NULL)

  reason <- rec$reason %||% rec$rationale %||% ""
  score <- rec$score %||% NULL

  # Build recommendation reasons list
  reason_items <- NULL
  if (!is.null(rec$reasons) && length(rec$reasons) > 0) {
    reason_items <- htmltools::tags$ul(
      style = "margin:8px 0 0 0; padding-left:20px;",
      lapply(rec$reasons, function(r) {
        htmltools::tags$li(
          style = "font-size:13px; color:#64748b; margin-bottom:4px;",
          r
        )
      })
    )
  }

  htmltools::tags$div(
    class = "seg-section",
    id = "seg-recommendation-section",
    `data-seg-section` = "recommendation",
    htmltools::tags$div(
      class = "seg-recommendation-card",
      htmltools::tags$h3(
        class = "seg-recommendation-title",
        sprintf("Recommended: k = %d", rec_k)
      ),
      if (nzchar(reason)) {
        htmltools::tags$p(class = "seg-recommendation-text", reason)
      },
      if (!is.null(score)) {
        htmltools::tags$p(
          class = "seg-recommendation-reason",
          sprintf("Confidence score: %.0f%%", score * 100)
        )
      },
      reason_items
    )
  )
}
