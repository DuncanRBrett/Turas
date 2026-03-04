# ==============================================================================
# CATDRIVER HTML REPORT - SUBGROUP COMPARISON SECTION
# ==============================================================================
# Builds HTML section for comparing driver importance across subgroups.
# Mirrors the architecture of 06_comparison_report.R but for segments/subgroups
# rather than multiple outcome variables.
#
# Components:
#   1. Overview cards (one per subgroup)
#   2. Grouped importance bar chart (SVG)
#   3. Driver classification table
#   4. Auto-generated insights
#
# Version: 1.0
# ==============================================================================


#' Build Subgroup Comparison Section
#'
#' Creates the full "Subgroup Comparison" section for the HTML report.
#' Only called when subgroup analysis is active.
#'
#' @param subgroup_comparison Comparison object from build_subgroup_comparison()
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @param id_prefix ID prefix for namespace safety
#' @return htmltools tag list, or NULL if no comparison data
#' @export
build_cd_subgroup_section <- function(subgroup_comparison,
                                       brand_colour = "#323367",
                                       accent_colour = "#CC9900",
                                       id_prefix = "") {

  if (is.null(subgroup_comparison) || subgroup_comparison$n_groups < 2) {
    return(NULL)
  }

  comp <- subgroup_comparison

  # Section title row
  title_row <- build_cd_section_title_row(
    sprintf("Subgroup Comparison: %s", comp$subgroup_var %||% "Subgroup"),
    "subgroup-comparison",
    id_prefix = id_prefix
  )

  # Insight area
  insight_area <- build_cd_insight_area("subgroup-comparison", id_prefix = id_prefix)

  # Intro text
  intro <- htmltools::tags$p(
    class = "cd-section-intro",
    sprintf(
      "This section compares driver importance across %d subgroups defined by '%s'. Drivers are classified as Universal (consistently important), Segment-Specific (important in one group only), or Mixed.",
      comp$n_groups, comp$subgroup_var %||% "subgroup"
    )
  )

  # 1. Overview cards
  overview_cards <- build_subgroup_overview_cards(comp, brand_colour)

  # 2. Grouped importance bar chart
  importance_chart <- build_subgroup_importance_chart(comp, brand_colour)

  # 3. Driver classification table
  classification_table <- build_subgroup_classification_table(comp, brand_colour)

  # 4. Insights
  insights_section <- build_subgroup_insights_html(comp, brand_colour)

  # Assemble section
  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-subgroup-comparison"),
    `data-cd-section` = "subgroup-comparison",
    title_row,
    insight_area,
    intro,
    overview_cards,
    importance_chart,
    classification_table,
    insights_section
  )
}


# ==============================================================================
# OVERVIEW CARDS
# ==============================================================================

#' Build Subgroup Overview Cards
#'
#' One card per subgroup showing n, R-squared, and top driver.
#'
#' @param comp Subgroup comparison object
#' @param brand_colour Brand colour hex
#' @return htmltools tag
#' @keywords internal
build_subgroup_overview_cards <- function(comp, brand_colour) {

  if (is.null(comp$model_fit) || nrow(comp$model_fit) == 0) return(NULL)

  cards <- lapply(seq_len(nrow(comp$model_fit)), function(i) {
    row <- comp$model_fit[i, ]

    # Find top driver for this group
    top_driver <- "-"
    grp_rank_col <- paste0(row$subgroup, "_rank")
    if (!is.null(comp$importance_matrix) && grp_rank_col %in% names(comp$importance_matrix)) {
      top_idx <- which(comp$importance_matrix[[grp_rank_col]] == 1)
      if (length(top_idx) > 0) {
        top_driver <- comp$importance_matrix$label[top_idx[1]]
      }
    }

    r2_label <- if (is.na(row$mcfadden_r2)) "N/A" else sprintf("%.3f", row$mcfadden_r2)
    r2_class <- if (is.na(row$mcfadden_r2)) "" else {
      if (row$mcfadden_r2 >= 0.4) "cd-fit-excellent"
      else if (row$mcfadden_r2 >= 0.2) "cd-fit-good"
      else if (row$mcfadden_r2 >= 0.1) "cd-fit-moderate"
      else "cd-fit-limited"
    }

    htmltools::tags$div(
      class = "cd-comp-card",
      style = sprintf("border-top: 3px solid %s;", brand_colour),

      htmltools::tags$div(
        class = "cd-comp-card-title",
        row$subgroup
      ),

      htmltools::tags$div(
        class = "cd-comp-card-stats",
        htmltools::tags$div(
          class = "cd-comp-stat",
          htmltools::tags$span(class = "cd-comp-stat-value", format(row$n, big.mark = ",")),
          htmltools::tags$span(class = "cd-comp-stat-label", "Sample")
        ),
        htmltools::tags$div(
          class = "cd-comp-stat",
          htmltools::tags$span(class = paste("cd-comp-stat-value", r2_class), r2_label),
          htmltools::tags$span(class = "cd-comp-stat-label", "R\u00b2")
        )
      ),

      htmltools::tags$div(
        class = "cd-comp-card-footer",
        htmltools::tags$span(class = "cd-comp-stat-label", "Top driver: "),
        htmltools::tags$span(style = "font-weight: 600;", top_driver)
      )
    )
  })

  htmltools::tags$div(
    class = "cd-chart-wrapper",
    style = "margin-top: 16px;",
    htmltools::tags$div(
      class = "cd-comp-card-grid",
      cards
    )
  )
}


# ==============================================================================
# GROUPED IMPORTANCE BAR CHART (SVG)
# ==============================================================================

#' Build Subgroup Importance Bar Chart
#'
#' Horizontal grouped bar chart showing importance % by subgroup for each driver.
#' Uses opacity/shade differentiation of brand colour.
#'
#' @param comp Subgroup comparison object
#' @param brand_colour Brand colour hex
#' @return htmltools tag wrapping SVG, or NULL
#' @keywords internal
build_subgroup_importance_chart <- function(comp, brand_colour) {

  imp <- comp$importance_matrix
  if (is.null(imp) || nrow(imp) == 0) return(NULL)

  group_names <- comp$group_names
  n_groups <- length(group_names)
  n_drivers <- nrow(imp)

  # Chart dimensions
  label_width <- 160
  chart_width <- 900
  bar_area_width <- chart_width - label_width - 60

  bar_height <- 16
  bar_gap <- 3
  group_height <- n_groups * (bar_height + bar_gap) + 8
  total_height <- n_drivers * group_height + 60

  # Colour palette: brand colour at different opacities
  opacities <- seq(1.0, 0.35, length.out = max(n_groups, 2))

  # Find max pct for scale
  pct_cols <- paste0(group_names, "_pct")
  all_pcts <- unlist(imp[, pct_cols, drop = FALSE])
  max_pct <- max(all_pcts, na.rm = TRUE)
  if (is.na(max_pct) || max_pct <= 0) max_pct <- 100
  scale_max <- ceiling(max_pct / 10) * 10

  # Build SVG content
  svg_elements <- list()

  # Gridlines
  for (g_pct in seq(0, scale_max, by = 10)) {
    x_pos <- label_width + (g_pct / scale_max) * bar_area_width
    svg_elements <- c(svg_elements, list(sprintf(
      '<line x1="%.1f" y1="30" x2="%.1f" y2="%d" stroke="#e2e8f0" stroke-opacity="0.6" stroke-dasharray="2,2"/>',
      x_pos, x_pos, total_height - 20
    )))
    svg_elements <- c(svg_elements, list(sprintf(
      '<text x="%.1f" y="22" text-anchor="middle" font-size="10" fill="#94a3b8" font-weight="400">%d%%</text>',
      x_pos, g_pct
    )))
  }

  # Bars
  y_offset <- 35
  for (d in seq_len(n_drivers)) {
    driver_label <- imp$label[d]

    # Driver label
    svg_elements <- c(svg_elements, list(sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" font-size="12" fill="#1e293b" font-weight="500">%s</text>',
      label_width - 10, y_offset + (n_groups * (bar_height + bar_gap)) / 2, driver_label
    )))

    for (g in seq_along(group_names)) {
      grp <- group_names[g]
      pct_val <- imp[[paste0(grp, "_pct")]][d]
      if (is.na(pct_val)) pct_val <- 0

      bar_w <- max(0, (pct_val / scale_max) * bar_area_width)
      bar_y <- y_offset + (g - 1) * (bar_height + bar_gap)

      # Bar
      svg_elements <- c(svg_elements, list(sprintf(
        '<rect x="%d" y="%.1f" width="%.1f" height="%d" rx="3" fill="%s" opacity="%.2f"/>',
        label_width, bar_y, bar_w, bar_height, brand_colour, opacities[g]
      )))

      # Value label
      if (pct_val > 0) {
        svg_elements <- c(svg_elements, list(sprintf(
          '<text x="%.1f" y="%.1f" font-size="10" fill="#64748b" font-weight="500">%.1f%%</text>',
          label_width + bar_w + 4, bar_y + bar_height - 3, pct_val
        )))
      }
    }

    y_offset <- y_offset + group_height
  }

  # Legend
  legend_y <- total_height - 10
  legend_x <- label_width
  for (g in seq_along(group_names)) {
    svg_elements <- c(svg_elements, list(sprintf(
      '<rect x="%.1f" y="%d" width="12" height="12" rx="2" fill="%s" opacity="%.2f"/>',
      legend_x, legend_y, brand_colour, opacities[g]
    )))
    svg_elements <- c(svg_elements, list(sprintf(
      '<text x="%.1f" y="%d" font-size="11" fill="#64748b" font-weight="400">%s</text>',
      legend_x + 16, legend_y + 10, group_names[g]
    )))
    legend_x <- legend_x + nchar(group_names[g]) * 7 + 30
  }

  svg_content <- paste(svg_elements, collapse = "\n")
  svg_tag <- sprintf(
    '<svg class="cd-subgroup-chart" viewBox="0 0 %d %d" width="%d" xmlns="http://www.w3.org/2000/svg" style="font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,sans-serif;">%s</svg>',
    chart_width, total_height, chart_width, svg_content
  )

  htmltools::tags$div(
    class = "cd-chart-wrapper",
    style = "margin-top: 20px;",
    htmltools::tags$h4(
      style = "font-size: 13px; font-weight: 600; color: #1e293b; margin-bottom: 8px;",
      "Driver Importance by Subgroup"
    ),
    htmltools::HTML(svg_tag)
  )
}


# ==============================================================================
# CLASSIFICATION TABLE
# ==============================================================================

#' Build Subgroup Driver Classification Table
#'
#' Shows each driver with its rank per subgroup and classification.
#'
#' @param comp Subgroup comparison object
#' @param brand_colour Brand colour hex
#' @return htmltools tag
#' @keywords internal
build_subgroup_classification_table <- function(comp, brand_colour) {

  imp <- comp$importance_matrix
  if (is.null(imp) || nrow(imp) == 0) return(NULL)

  group_names <- comp$group_names

  # Build header row
  header_cells <- list(
    htmltools::tags$th(class = "cd-th", "Driver"),
    htmltools::tags$th(class = "cd-th", "Classification")
  )
  for (grp in group_names) {
    header_cells <- c(header_cells, list(
      htmltools::tags$th(class = "cd-th", style = "text-align:center;", paste0(grp, " Rank"))
    ))
  }
  header_cells <- c(header_cells, list(
    htmltools::tags$th(class = "cd-th", style = "text-align:center;", "Max Diff")
  ))

  # Build data rows
  rows <- lapply(seq_len(nrow(imp)), function(i) {
    classification <- imp$classification[i]
    class_css <- switch(classification,
      "Universal" = "cd-comp-rank-1",
      "Segment-Specific" = "cd-comp-rank-other",
      "cd-comp-rank-2"
    )

    cells <- list(
      htmltools::tags$td(class = "cd-td", style = "font-weight:500;", imp$label[i]),
      htmltools::tags$td(class = paste("cd-td", class_css),
        style = "font-weight:600; text-align:center;", classification)
    )

    for (grp in group_names) {
      rank_val <- imp[[paste0(grp, "_rank")]][i]
      rank_class <- if (is.na(rank_val)) "" else {
        if (rank_val == 1) "cd-comp-rank-1"
        else if (rank_val == 2) "cd-comp-rank-2"
        else if (rank_val == 3) "cd-comp-rank-3"
        else "cd-comp-rank-other"
      }
      cells <- c(cells, list(
        htmltools::tags$td(
          class = paste("cd-td", rank_class),
          style = "text-align:center; font-weight:600;",
          if (is.na(rank_val)) "-" else paste0("#", rank_val)
        )
      ))
    }

    cells <- c(cells, list(
      htmltools::tags$td(class = "cd-td", style = "text-align:center;",
        as.character(imp$max_rank_diff[i])
      )
    ))

    htmltools::tags$tr(cells)
  })

  htmltools::tags$div(
    class = "cd-table-wrapper",
    style = "margin-top: 20px;",
    htmltools::tags$h4(
      style = "font-size: 13px; font-weight: 600; color: #1e293b; margin-bottom: 8px;",
      "Driver Classification"
    ),
    htmltools::tags$table(
      class = "cd-table cd-comp-table",
      htmltools::tags$thead(htmltools::tags$tr(header_cells)),
      htmltools::tags$tbody(rows)
    )
  )
}


# ==============================================================================
# INSIGHTS
# ==============================================================================

#' Build Subgroup Insights HTML
#'
#' Renders auto-generated insights as bullet points.
#'
#' @param comp Subgroup comparison object
#' @param brand_colour Brand colour hex
#' @return htmltools tag
#' @keywords internal
build_subgroup_insights_html <- function(comp, brand_colour) {

  insights <- comp$insights
  if (is.null(insights) || length(insights) == 0) return(NULL)

  items <- lapply(insights, function(ins) {
    htmltools::tags$li(
      class = "cd-comp-insight",
      style = "margin-bottom: 6px; font-size: 13px; color: #1e293b; line-height: 1.5;",
      ins
    )
  })

  htmltools::tags$div(
    class = "cd-chart-wrapper",
    style = "margin-top: 20px;",
    htmltools::tags$h4(
      style = "font-size: 13px; font-weight: 600; color: #1e293b; margin-bottom: 8px;",
      "Key Findings"
    ),
    htmltools::tags$ul(
      style = "padding-left: 20px;",
      items
    )
  )
}
