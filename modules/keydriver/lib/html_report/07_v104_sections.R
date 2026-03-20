# ==============================================================================
# KEYDRIVER HTML REPORT - v10.4 SECTION BUILDERS
# ==============================================================================
# Extracted from 03_page_builder.R to keep file sizes manageable.
# Contains: Elastic Net, NCA, Dominance Analysis, GAM section builders.
# ==============================================================================

# Null-coalescing operator (ensure available when sourced independently)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}


# ==============================================================================
# ELASTIC NET SECTION (v10.4)
# ==============================================================================

#' Build Elastic Net Section
#'
#' Displays elastic net coefficients showing which drivers are retained/zeroed.
#'
#' @param html_data Transformed data with $elastic_net
#' @param config Configuration list (optional, for insight pre-population)
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_elastic_net_section <- function(html_data, config = NULL) {
  enet <- html_data$elastic_net
  if (is.null(enet)) return(NULL)

  coefs <- enet$coefficients
  if (is.null(coefs) || !is.data.frame(coefs) || nrow(coefs) == 0) {
    cat("    [WARN] Elastic net data present but coefficients table is empty — section skipped\n")
    return(NULL)
  }

  # Build table rows
  header <- htmltools::tags$tr(
    htmltools::tags$th("Driver",     class = "kd-th kd-th-label"),
    htmltools::tags$th("Coefficient", class = "kd-th kd-th-num"),
    htmltools::tags$th("Importance %", class = "kd-th kd-th-num"),
    htmltools::tags$th("Status",     class = "kd-th kd-th-label")
  )

  rows <- lapply(seq_len(nrow(coefs)), function(i) {
    selected <- isTRUE(coefs$Selected_1se[i])
    status_class <- if (selected) "kd-badge kd-agree-high" else "kd-badge kd-concern-moderate"
    status_text  <- if (selected) "Retained" else "Zeroed"

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(coefs$Driver[i], class = "kd-td kd-td-label"),
      htmltools::tags$td(sprintf("%.3f", coefs$Coefficient_1se[i]), class = "kd-td kd-td-num"),
      htmltools::tags$td(sprintf("%.1f%%", coefs$Importance_Pct[i]), class = "kd-td kd-td-num"),
      htmltools::tags$td(class = "kd-td", htmltools::tags$span(class = status_class, status_text))
    )
  })

  table <- htmltools::tags$table(
    class = "kd-table kd-elastic-net-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-elastic-net",
    `data-kd-section` = "elastic-net",
    build_kd_section_title_row("Elastic Net Variable Selection", "elastic-net", show_pin = TRUE),
    htmltools::tags$p(
      class = "kd-section-intro",
      sprintf("Elastic net regression (alpha = %.2f) identifies which drivers survive regularization. Drivers marked 'Zeroed' can be safely deprioritised. %d of %d drivers retained at lambda.1se (parsimonious model).",
              enet$alpha %||% 0.5,
              length(enet$selected_drivers %||% character(0)),
              nrow(coefs))
    ),
    htmltools::tags$div(class = "kd-table-wrapper", table),
    build_kd_insight_area("elastic-net", config = config)
  )
}


# ==============================================================================
# NCA SECTION (v10.4)
# ==============================================================================

#' Build Necessary Condition Analysis Section
#'
#' @param html_data Transformed data with $nca
#' @param config Configuration list (optional, for insight pre-population)
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_nca_section <- function(html_data, config = NULL) {
  nca <- html_data$nca
  if (is.null(nca)) return(NULL)

  summary_df <- nca$nca_summary
  if (is.null(summary_df) || !is.data.frame(summary_df) || nrow(summary_df) == 0) {
    cat("    [WARN] NCA data present but summary table is empty — section skipped\n")
    return(NULL)
  }

  header <- htmltools::tags$tr(
    htmltools::tags$th("Driver",        class = "kd-th kd-th-label"),
    htmltools::tags$th("NCA Effect",    class = "kd-th kd-th-num"),
    htmltools::tags$th("p-value",       class = "kd-th kd-th-num"),
    htmltools::tags$th("Classification", class = "kd-th kd-th-label")
  )

  rows <- lapply(seq_len(nrow(summary_df)), function(i) {
    is_nec <- isTRUE(summary_df$Is_Necessary[i])
    cls_class <- if (is_nec) "kd-badge kd-concern-high" else "kd-badge kd-concern-none"
    p_display <- if (is.na(summary_df$NCA_p_value[i])) "-"
                 else if (summary_df$NCA_p_value[i] < 0.001) "<0.001"
                 else sprintf("%.3f", summary_df$NCA_p_value[i])

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(summary_df$Driver[i], class = "kd-td kd-td-label"),
      htmltools::tags$td(sprintf("%.3f", summary_df$NCA_Effect_Size[i]), class = "kd-td kd-td-num"),
      htmltools::tags$td(p_display, class = "kd-td kd-td-num"),
      htmltools::tags$td(class = "kd-td",
        htmltools::tags$span(class = cls_class, summary_df$Classification[i]))
    )
  })

  table <- htmltools::tags$table(
    class = "kd-table kd-nca-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-nca",
    `data-kd-section` = "nca",
    build_kd_section_title_row("Necessary Condition Analysis", "nca", show_pin = TRUE),
    htmltools::tags$p(
      class = "kd-section-intro",
      sprintf(
        "NCA identifies 'hygiene factors' \u2014 drivers that are necessary conditions for high outcomes. A driver is necessary if high outcome values require at least moderate levels of that driver. %d of %d drivers identified as necessary conditions (Dul, 2016).",
        nca$n_necessary %||% 0, nca$n_analysed %||% 0)
    ),
    htmltools::tags$div(class = "kd-table-wrapper", table),
    build_kd_insight_area("nca", config = config)
  )
}


# ==============================================================================
# DOMINANCE ANALYSIS SECTION (v10.4)
# ==============================================================================

#' Build Dominance Analysis Section
#'
#' @param html_data Transformed data with $dominance
#' @param config Configuration list (optional, for insight pre-population)
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_dominance_section <- function(html_data, config = NULL) {
  dom <- html_data$dominance
  if (is.null(dom)) return(NULL)

  summary_df <- dom$summary
  if (is.null(summary_df) || !is.data.frame(summary_df) || nrow(summary_df) == 0) {
    cat("    [WARN] Dominance data present but summary table is empty — section skipped\n")
    return(NULL)
  }

  header <- htmltools::tags$tr(
    htmltools::tags$th("Rank",            class = "kd-th kd-th-rank"),
    htmltools::tags$th("Driver",          class = "kd-th kd-th-label"),
    htmltools::tags$th("General Dom. R\u00b2", class = "kd-th kd-th-num"),
    htmltools::tags$th("Share %",         class = "kd-th kd-th-num")
  )

  rows <- lapply(seq_len(nrow(summary_df)), function(i) {
    row_class <- if (summary_df$Rank[i] <= 3) "kd-tr kd-tr-highlight" else "kd-tr"
    htmltools::tags$tr(
      class = row_class,
      htmltools::tags$td(summary_df$Rank[i], class = "kd-td kd-td-rank"),
      htmltools::tags$td(summary_df$Driver[i], class = "kd-td kd-td-label"),
      htmltools::tags$td(sprintf("%.4f", summary_df$General_Dominance[i]), class = "kd-td kd-td-num"),
      htmltools::tags$td(sprintf("%.1f%%", summary_df$General_Pct[i]), class = "kd-td kd-td-num")
    )
  })

  table <- htmltools::tags$table(
    class = "kd-table kd-dominance-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )

  htmltools::tags$div(
    class = "kd-section", id = "kd-dominance",
    `data-kd-section` = "dominance",
    build_kd_section_title_row("Dominance Analysis", "dominance", show_pin = TRUE),
    htmltools::tags$p(
      class = "kd-section-intro",
      sprintf(
        "Dominance analysis decomposes model R\u00b2 (%.3f) into per-driver contributions using all possible subset models. General dominance is equivalent to Shapley values. This analysis examined %d drivers across %d sub-models (Budescu, 1993; Azen & Budescu, 2003).",
        dom$total_r_squared %||% 0, dom$n_drivers %||% 0, 2^(dom$n_drivers %||% 0))
    ),
    htmltools::tags$div(class = "kd-table-wrapper", table),
    build_kd_insight_area("dominance", config = config)
  )
}


# ==============================================================================
# GAM SECTION (v10.4)
# ==============================================================================

#' Build GAM Nonlinear Effects Section
#'
#' @param html_data Transformed data with $gam
#' @param config Configuration list (optional, for insight pre-population)
#' @return htmltools tag or NULL
#' @keywords internal
build_kd_gam_section <- function(html_data, config = NULL) {
  gam_data <- html_data$gam
  if (is.null(gam_data)) return(NULL)

  summary_df <- gam_data$nonlinearity_summary
  if (is.null(summary_df) || !is.data.frame(summary_df) || nrow(summary_df) == 0) {
    cat("    [WARN] GAM data present but nonlinearity summary is empty — section skipped\n")
    return(NULL)
  }

  header <- htmltools::tags$tr(
    htmltools::tags$th("Driver",    class = "kd-th kd-th-label"),
    htmltools::tags$th("EDF",       class = "kd-th kd-th-num"),
    htmltools::tags$th("F-stat",    class = "kd-th kd-th-num"),
    htmltools::tags$th("p-value",   class = "kd-th kd-th-num"),
    htmltools::tags$th("Shape",     class = "kd-th kd-th-label")
  )

  rows <- lapply(seq_len(nrow(summary_df)), function(i) {
    is_nl <- isTRUE(summary_df$Is_Nonlinear[i])
    shape_class <- if (is_nl) "kd-badge kd-concern-high" else "kd-badge kd-concern-none"
    p_display <- if (summary_df$p_value[i] < 0.001) "<0.001"
                 else sprintf("%.3f", summary_df$p_value[i])

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(summary_df$Driver[i], class = "kd-td kd-td-label"),
      htmltools::tags$td(sprintf("%.1f", summary_df$EDF[i]), class = "kd-td kd-td-num"),
      htmltools::tags$td(sprintf("%.1f", summary_df$F_statistic[i]), class = "kd-td kd-td-num"),
      htmltools::tags$td(p_display, class = "kd-td kd-td-num"),
      htmltools::tags$td(class = "kd-td",
        htmltools::tags$span(class = shape_class, summary_df$Shape[i]))
    )
  })

  table <- htmltools::tags$table(
    class = "kd-table kd-gam-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )

  improvement <- gam_data$improvement %||% 0
  improvement_text <- if (improvement > 0.01) {
    sprintf("The GAM explains %.1f%% more variance than the linear model (%.1f%% vs %.1f%%), suggesting actionable nonlinear patterns.",
            improvement * 100, (gam_data$deviance_explained %||% 0) * 100,
            (gam_data$linear_r_squared %||% 0) * 100)
  } else {
    "The GAM shows minimal improvement over the linear model, confirming that driver effects are approximately linear."
  }

  htmltools::tags$div(
    class = "kd-section", id = "kd-gam",
    `data-kd-section` = "gam",
    build_kd_section_title_row("Nonlinear Effects (GAM)", "gam", show_pin = TRUE),
    htmltools::tags$p(
      class = "kd-section-intro",
      sprintf(
        "Generalized Additive Models test whether driver-outcome relationships are nonlinear. EDF (effective degrees of freedom) > 1.5 with p < 0.05 indicates meaningful curvature. %d of %d drivers show significant nonlinearity. %s (Wood, 2017).",
        gam_data$n_nonlinear %||% 0, gam_data$n_analysed %||% 0, improvement_text)
    ),
    htmltools::tags$div(class = "kd-table-wrapper", table),
    build_kd_insight_area("gam", config = config)
  )
}
