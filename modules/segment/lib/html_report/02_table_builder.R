# ==============================================================================
# SEGMENT HTML REPORT - TABLE BUILDER
# ==============================================================================
# Builds HTML tables for the segmentation report.
# Uses htmltools for structured HTML generation.
# CSS prefix: seg-
# Version: 11.0
# ==============================================================================


#' Build Segment Overview Table
#'
#' Creates a summary table showing segment sizes and status badges.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @return htmltools tag object, or NULL if data is missing
#' @keywords internal
build_seg_overview_table <- function(html_data) {

  if (is.null(html_data$segment_sizes) || nrow(html_data$segment_sizes) == 0) {
    return(htmltools::tags$div(
      class = "seg-empty-notice",
      "No segment size data available."
    ))
  }

  sizes <- html_data$segment_sizes

  header <- htmltools::tags$tr(
    htmltools::tags$th("Segment", class = "seg-th seg-th-id"),
    htmltools::tags$th("Name", class = "seg-th seg-th-label"),
    htmltools::tags$th("Size (n)", class = "seg-th seg-th-num"),
    htmltools::tags$th("Size (%)", class = "seg-th seg-th-num"),
    htmltools::tags$th("Status", class = "seg-th seg-th-status")
  )

  rows <- lapply(seq_len(nrow(sizes)), function(i) {
    seg_id <- sizes$segment_id[i]
    seg_name <- sizes$segment_name[i]
    seg_n <- sizes$n[i]
    seg_pct <- sizes$pct[i]

    is_small <- seg_pct < 5
    badge_class <- if (is_small) "seg-badge seg-badge-warn" else "seg-badge seg-badge-pass"
    badge_text <- if (is_small) "Small" else "OK"

    htmltools::tags$tr(
      class = "seg-tr",
      htmltools::tags$td(seg_id, class = "seg-td seg-td-id"),
      htmltools::tags$td(seg_name, class = "seg-td seg-td-label"),
      htmltools::tags$td(format(seg_n, big.mark = ","), class = "seg-td seg-td-num"),
      htmltools::tags$td(sprintf("%.1f%%", seg_pct), class = "seg-td seg-td-num"),
      htmltools::tags$td(
        class = "seg-td seg-td-status",
        htmltools::tags$span(class = badge_class, badge_text)
      )
    )
  })

  htmltools::tags$table(
    class = "seg-table seg-overview-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


#' Build Segment Profile Table
#'
#' Creates a profile table with variable means per segment, colored by
#' deviation from overall mean (index score). Includes F-statistic and
#' eta-squared columns when available.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @return htmltools tag object, or NULL if profile data is missing
#' @keywords internal
build_seg_profile_table <- function(html_data) {

  profile <- html_data$profile_data
  if (is.null(profile) || nrow(profile) == 0) {
    return(htmltools::tags$div(
      class = "seg-empty-notice",
      "No profile data available."
    ))
  }

  k <- html_data$k
  question_labels <- html_data$question_labels
  segment_names <- html_data$segment_names

  # Identify segment columns
  seg_cols <- paste0("Segment_", seq_len(k))
  seg_cols <- seg_cols[seg_cols %in% names(profile)]

  # Check for F-statistic and eta-squared columns
  has_f <- "F_statistic" %in% names(profile)
  has_eta <- any(c("eta_sq", "eta_squared", "Eta_Sq", "Eta_Squared") %in% names(profile))
  eta_col <- NULL
  if (has_eta) {
    for (col in c("eta_sq", "eta_squared", "Eta_Sq", "Eta_Squared")) {
      if (col %in% names(profile)) { eta_col <- col; break }
    }
  }

  # Build header
  seg_ths <- lapply(seq_along(seg_cols), function(i) {
    th_label <- if (!is.null(segment_names) && length(segment_names) >= i) {
      segment_names[i]
    } else {
      paste("Seg", i)
    }
    htmltools::tags$th(th_label, class = "seg-th seg-th-num")
  })

  header_cells <- list(
    htmltools::tags$th("Variable", class = "seg-th seg-th-label")
  )
  header_cells <- c(header_cells, seg_ths)
  header_cells <- c(header_cells, list(
    htmltools::tags$th("Overall", class = "seg-th seg-th-num")
  ))
  if (has_f) {
    header_cells <- c(header_cells, list(
      htmltools::tags$th("F-stat", class = "seg-th seg-th-num")
    ))
  }
  if (!is.null(eta_col)) {
    header_cells <- c(header_cells, list(
      htmltools::tags$th(htmltools::HTML("Eta&sup2;"), class = "seg-th seg-th-num")
    ))
  }

  header <- htmltools::tags$tr(header_cells)

  # Build rows
  rows <- lapply(seq_len(nrow(profile)), function(i) {
    var_name <- profile$Variable[i]

    # Resolve display label
    display_label <- var_name
    if (!is.null(question_labels) && var_name %in% names(question_labels)) {
      display_label <- question_labels[var_name]
    }

    overall_val <- profile$Overall[i]

    # Build segment value cells with index-based coloring
    seg_tds <- lapply(seg_cols, function(sc) {
      val <- profile[[sc]][i]

      if (is.na(val) || is.na(overall_val) || overall_val == 0) {
        td_class <- "seg-td seg-td-num"
        display_val <- if (is.na(val)) "-" else sprintf("%.2f", round(val, 2))
      } else {
        index <- 100 * (val / overall_val)
        td_class <- if (index > 120) {
          "seg-td seg-td-high"
        } else if (index >= 105) {
          "seg-td seg-td-mod-high"
        } else if (index <= 80) {
          "seg-td seg-td-low"
        } else if (index <= 95) {
          "seg-td seg-td-mod-low"
        } else {
          "seg-td seg-td-num"
        }
        display_val <- sprintf("%.2f", round(val, 2))
      }

      htmltools::tags$td(display_val, class = td_class)
    })

    # Overall cell
    overall_display <- if (is.na(overall_val)) "-" else sprintf("%.2f", round(overall_val, 2))

    row_cells <- list(
      htmltools::tags$td(display_label, class = "seg-td seg-td-label")
    )
    row_cells <- c(row_cells, seg_tds)
    row_cells <- c(row_cells, list(
      htmltools::tags$td(overall_display, class = "seg-td seg-td-num")
    ))

    # F-statistic
    if (has_f) {
      f_val <- profile$F_statistic[i]
      f_display <- if (is.na(f_val)) "-" else sprintf("%.2f", round(f_val, 2))
      row_cells <- c(row_cells, list(
        htmltools::tags$td(f_display, class = "seg-td seg-td-num")
      ))
    }

    # Eta-squared
    if (!is.null(eta_col)) {
      eta_val <- profile[[eta_col]][i]
      eta_display <- if (is.na(eta_val)) "-" else sprintf("%.4f", round(eta_val, 4))
      row_cells <- c(row_cells, list(
        htmltools::tags$td(eta_display, class = "seg-td seg-td-num")
      ))
    }

    htmltools::tags$tr(class = "seg-tr", row_cells)
  })

  htmltools::tags$table(
    class = "seg-table seg-profile-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


#' Build Validation Metrics Table
#'
#' Creates a table of clustering validation metrics with interpretive labels.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @return htmltools tag object, or NULL if validation data is missing
#' @keywords internal
build_seg_validation_table <- function(html_data) {

  diag <- html_data$diagnostics
  if (is.null(diag)) {
    return(htmltools::tags$div(
      class = "seg-empty-notice",
      "No validation metrics available."
    ))
  }

  method_info <- html_data$method_info %||% list()

  header <- htmltools::tags$tr(
    htmltools::tags$th("Metric", class = "seg-th seg-th-label"),
    htmltools::tags$th("Value", class = "seg-th seg-th-num"),
    htmltools::tags$th("Interpretation", class = "seg-th seg-th-interp")
  )

  # Build metric rows dynamically
  metric_rows <- list()

  # -- Average Silhouette --
  sil_val <- diag$avg_silhouette
  if (!is.null(sil_val) && !is.na(sil_val)) {
    sil_label <- if (sil_val >= 0.71) {
      "Strong structure"
    } else if (sil_val >= 0.51) {
      "Good structure"
    } else if (sil_val >= 0.26) {
      "Fair structure"
    } else {
      "Weak structure"
    }
    metric_rows <- c(metric_rows, list(
      .build_seg_validation_row("Average Silhouette", sprintf("%.3f", sil_val), sil_label)
    ))
  }

  # -- Between/Total SS --
  bt_val <- diag$betweenss_totss
  if (!is.null(bt_val) && !is.na(bt_val)) {
    bt_pct <- sprintf("%.1f%%", bt_val * 100)
    metric_rows <- c(metric_rows, list(
      .build_seg_validation_row("Between/Total SS", sprintf("%.3f", bt_val), bt_pct)
    ))
  }

  # -- Method --
  method_val <- diag$method
  if (!is.null(method_val) && nzchar(method_val)) {
    metric_rows <- c(metric_rows, list(
      .build_seg_validation_row("Method", method_val, "")
    ))
  }

  # -- Linkage (hclust-specific) --
  linkage <- method_info$linkage %||% NULL
  if (!is.null(linkage) && nzchar(linkage)) {
    metric_rows <- c(metric_rows, list(
      .build_seg_validation_row("Linkage", linkage, "Hierarchical clustering linkage method")
    ))
  }

  # -- Cophenetic correlation (hclust-specific) --
  coph <- method_info$cophenetic %||% NULL
  if (!is.null(coph) && !is.na(coph)) {
    coph_label <- if (coph >= 0.9) {
      "Excellent fit"
    } else if (coph >= 0.8) {
      "Good fit"
    } else if (coph >= 0.7) {
      "Acceptable fit"
    } else {
      "Poor fit"
    }
    metric_rows <- c(metric_rows, list(
      .build_seg_validation_row("Cophenetic Correlation", sprintf("%.3f", coph), coph_label)
    ))
  }

  # -- BIC (GMM-specific) --
  bic_val <- method_info$bic %||% method_info$BIC %||% NULL
  if (!is.null(bic_val) && !is.na(bic_val)) {
    metric_rows <- c(metric_rows, list(
      .build_seg_validation_row("BIC", sprintf("%.1f", bic_val), "Lower is better (model comparison)")
    ))
  }

  if (length(metric_rows) == 0) {
    return(htmltools::tags$div(
      class = "seg-empty-notice",
      "No validation metrics to display."
    ))
  }

  htmltools::tags$table(
    class = "seg-table seg-validation-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(metric_rows)
  )
}


#' Build a Single Validation Row (internal helper)
#' @keywords internal
.build_seg_validation_row <- function(metric, value, interpretation) {
  htmltools::tags$tr(
    class = "seg-tr",
    htmltools::tags$td(metric, class = "seg-td seg-td-label"),
    htmltools::tags$td(value, class = "seg-td seg-td-num"),
    htmltools::tags$td(interpretation, class = "seg-td seg-td-interp")
  )
}


#' Build Demographics Table
#'
#' Creates sub-tables for each demographic/profile variable showing
#' counts and percentages per category per segment.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @return htmltools tag list, or NULL if no demographic data is available
#' @keywords internal
build_seg_demographics_table <- function(html_data) {

  # Demographics come from the enhanced features or profile_profile
  enhanced <- html_data$enhanced %||% list()
  demo_data <- enhanced$demographic_profiles %||% NULL

  # If no enhanced demographics, check profile_profile from the profile result
  if (is.null(demo_data)) {
    # profile_data only has clustering variable means, not categorical cross-tabs
    # Return graceful NULL
    return(NULL)
  }

  cat_profiles <- demo_data$categorical_profiles %||% NULL
  if (is.null(cat_profiles) || length(cat_profiles) == 0) {
    return(NULL)
  }

  segment_names <- html_data$segment_names %||% demo_data$segment_names
  k <- html_data$k

  # Build one sub-table per demographic variable
  sub_tables <- lapply(names(cat_profiles), function(var_name) {

    prof_df <- cat_profiles[[var_name]]
    if (is.null(prof_df) || nrow(prof_df) == 0) return(NULL)

    # Determine segment columns present in the profile data frame
    all_cols <- names(prof_df)
    seg_col_names <- setdiff(all_cols, c("Category", "Overall"))

    # Header: Category | Overall | Seg1 | Seg2 | ...
    seg_ths <- lapply(seg_col_names, function(sn) {
      htmltools::tags$th(sn, class = "seg-th seg-th-num")
    })

    header <- htmltools::tags$tr(
      htmltools::tags$th("Category", class = "seg-th seg-th-label"),
      htmltools::tags$th("Overall", class = "seg-th seg-th-num"),
      seg_ths
    )

    # Rows
    rows <- lapply(seq_len(nrow(prof_df)), function(i) {
      cat_val <- prof_df$Category[i]
      overall_val <- prof_df$Overall[i]

      seg_tds <- lapply(seg_col_names, function(sn) {
        val <- prof_df[[sn]][i]
        display <- if (is.na(val)) "-" else sprintf("%.1f%%", val)
        htmltools::tags$td(display, class = "seg-td seg-td-num")
      })

      overall_display <- if (is.na(overall_val)) "-" else sprintf("%.1f%%", overall_val)

      htmltools::tags$tr(
        class = "seg-tr",
        htmltools::tags$td(cat_val, class = "seg-td seg-td-label"),
        htmltools::tags$td(overall_display, class = "seg-td seg-td-num"),
        seg_tds
      )
    })

    htmltools::tags$div(
      class = "seg-demo-block",
      htmltools::tags$h4(class = "seg-demo-var-title", var_name),
      htmltools::tags$table(
        class = "seg-table seg-demographics-table",
        htmltools::tags$thead(header),
        htmltools::tags$tbody(rows)
      )
    )
  })

  # Remove NULLs
  sub_tables <- Filter(Negate(is.null), sub_tables)

  if (length(sub_tables) == 0) return(NULL)

  htmltools::tags$div(class = "seg-demographics-section", sub_tables)
}


#' Build Classification Rules Table
#'
#' Displays decision-tree classification rules with predicted segment
#' and accuracy per segment.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @return htmltools tag object, or NULL if rules are not available
#' @keywords internal
build_seg_rules_table <- function(html_data) {

  enhanced <- html_data$enhanced %||% list()
  rules <- enhanced$rules %||% NULL

  if (is.null(rules)) return(NULL)

  rules_df <- rules$rules_df
  rules_text <- rules$rules_text
  overall_accuracy <- rules$accuracy

  if (is.null(rules_df) || nrow(rules_df) == 0) {
    return(htmltools::tags$div(
      class = "seg-empty-notice",
      "No classification rules generated."
    ))
  }

  # If we have text rules, use them; otherwise fall back to rules_df
  if (!is.null(rules_text) && length(rules_text) > 0) {
    return(.build_seg_rules_from_text(rules_text, rules_df, overall_accuracy))
  }

  # Fallback: table from rules_df
  .build_seg_rules_from_df(rules_df, overall_accuracy)
}


#' Build Rules Table from Text Rules (internal helper)
#' @keywords internal
.build_seg_rules_from_text <- function(rules_text, rules_df, overall_accuracy) {

  header <- htmltools::tags$tr(
    htmltools::tags$th("Rule", class = "seg-th seg-th-label"),
    htmltools::tags$th("Predicted Segment", class = "seg-th seg-th-label"),
    htmltools::tags$th("Accuracy", class = "seg-th seg-th-num")
  )

  rows <- lapply(seq_along(rules_text), function(i) {
    rule_text <- rules_text[i]

    # Extract segment name from rule text (after "THEN " or "DEFAULT: ")
    predicted_seg <- ""
    if (grepl("THEN ", rule_text)) {
      predicted_seg <- sub(".*THEN\\s+", "", rule_text)
    } else if (grepl("DEFAULT:", rule_text)) {
      predicted_seg <- sub("DEFAULT:\\s*", "", rule_text)
    }

    # Try to match accuracy from rules_df
    acc_display <- "-"
    if (!is.null(rules_df) && nrow(rules_df) > 0) {
      match_idx <- which(rules_df$Segment_Name == predicted_seg)
      if (length(match_idx) > 0) {
        acc_display <- sprintf("%.1f%%", rules_df$Accuracy[match_idx[1]])
      }
    }

    htmltools::tags$tr(
      class = "seg-tr",
      htmltools::tags$td(
        class = "seg-td seg-td-label seg-td-rule",
        htmltools::tags$code(rule_text)
      ),
      htmltools::tags$td(predicted_seg, class = "seg-td seg-td-label"),
      htmltools::tags$td(acc_display, class = "seg-td seg-td-num")
    )
  })

  # Footer with overall accuracy
  footer_row <- htmltools::tags$tr(
    class = "seg-tr seg-tr-footer",
    htmltools::tags$td("Overall", class = "seg-td seg-td-label", colspan = "2"),
    htmltools::tags$td(
      sprintf("%.1f%%", overall_accuracy * 100),
      class = "seg-td seg-td-num"
    )
  )

  htmltools::tags$table(
    class = "seg-table seg-rules-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows),
    htmltools::tags$tfoot(footer_row)
  )
}


#' Build Rules Table from Data Frame (internal helper)
#' @keywords internal
.build_seg_rules_from_df <- function(rules_df, overall_accuracy) {

  header <- htmltools::tags$tr(
    htmltools::tags$th("Rule", class = "seg-th seg-th-label"),
    htmltools::tags$th("Predicted Segment", class = "seg-th seg-th-label"),
    htmltools::tags$th("Accuracy", class = "seg-th seg-th-num")
  )

  rows <- lapply(seq_len(nrow(rules_df)), function(i) {
    seg_name <- rules_df$Segment_Name[i]
    acc <- rules_df$Accuracy[i]
    rule_text <- sprintf("Classify as %s (n=%d, %.1f%%)", seg_name, rules_df$N[i], rules_df$Pct[i])

    htmltools::tags$tr(
      class = "seg-tr",
      htmltools::tags$td(rule_text, class = "seg-td seg-td-label seg-td-rule"),
      htmltools::tags$td(seg_name, class = "seg-td seg-td-label"),
      htmltools::tags$td(sprintf("%.1f%%", acc), class = "seg-td seg-td-num")
    )
  })

  footer_row <- NULL
  if (!is.null(overall_accuracy) && !is.na(overall_accuracy)) {
    footer_row <- htmltools::tags$tfoot(
      htmltools::tags$tr(
        class = "seg-tr seg-tr-footer",
        htmltools::tags$td("Overall", class = "seg-td seg-td-label", colspan = "2"),
        htmltools::tags$td(
          sprintf("%.1f%%", overall_accuracy * 100),
          class = "seg-td seg-td-num"
        )
      )
    )
  }

  htmltools::tags$table(
    class = "seg-table seg-rules-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows),
    footer_row
  )
}


#' Build GMM Membership Probabilities Table
#'
#' Summarises GMM soft membership probabilities per segment, showing
#' mean probability, maximum uncertainty, and borderline case count.
#'
#' @param html_data Transformed data from transform_segment_for_html()
#' @return htmltools tag object, or NULL if GMM data is not available
#' @keywords internal
build_seg_gmm_membership_table <- function(html_data) {

  gmm <- html_data$gmm_membership
  if (is.null(gmm)) return(NULL)

  # gmm_membership is expected to be a matrix or data frame of probabilities
  # Rows = observations, Columns = segments (probabilities summing to 1)
  if (!is.data.frame(gmm) && !is.matrix(gmm)) return(NULL)

  gmm_mat <- as.matrix(gmm)
  if (ncol(gmm_mat) == 0 || nrow(gmm_mat) == 0) return(NULL)

  k <- ncol(gmm_mat)
  segment_names <- html_data$segment_names

  # Assign each observation to its most probable segment
  assignments <- apply(gmm_mat, 1, which.max)

  # Borderline threshold: max probability < 0.6 means uncertain assignment
  borderline_threshold <- 0.6

  header <- htmltools::tags$tr(
    htmltools::tags$th("Segment", class = "seg-th seg-th-label"),
    htmltools::tags$th("Mean Probability", class = "seg-th seg-th-num"),
    htmltools::tags$th("Max Uncertainty", class = "seg-th seg-th-num"),
    htmltools::tags$th("N Borderline", class = "seg-th seg-th-num")
  )

  rows <- lapply(seq_len(k), function(seg) {
    seg_label <- if (!is.null(segment_names) && length(segment_names) >= seg) {
      segment_names[seg]
    } else {
      paste("Segment", seg)
    }

    # Observations assigned to this segment
    assigned_idx <- which(assignments == seg)
    if (length(assigned_idx) == 0) {
      return(htmltools::tags$tr(
        class = "seg-tr",
        htmltools::tags$td(seg_label, class = "seg-td seg-td-label"),
        htmltools::tags$td("-", class = "seg-td seg-td-num"),
        htmltools::tags$td("-", class = "seg-td seg-td-num"),
        htmltools::tags$td("0", class = "seg-td seg-td-num")
      ))
    }

    # Mean of the assigned-segment probability for those observations
    probs_for_seg <- gmm_mat[assigned_idx, seg]
    mean_prob <- mean(probs_for_seg, na.rm = TRUE)

    # Max uncertainty = 1 - minimum probability among assigned observations
    max_uncertainty <- 1 - min(probs_for_seg, na.rm = TRUE)

    # Count borderline observations (max probability < threshold)
    max_probs <- apply(gmm_mat[assigned_idx, , drop = FALSE], 1, max)
    n_borderline <- sum(max_probs < borderline_threshold, na.rm = TRUE)

    htmltools::tags$tr(
      class = "seg-tr",
      htmltools::tags$td(seg_label, class = "seg-td seg-td-label"),
      htmltools::tags$td(sprintf("%.3f", mean_prob), class = "seg-td seg-td-num"),
      htmltools::tags$td(sprintf("%.3f", max_uncertainty), class = "seg-td seg-td-num"),
      htmltools::tags$td(
        class = "seg-td seg-td-num",
        if (n_borderline > 0) {
          htmltools::tags$span(class = "seg-badge seg-badge-warn", n_borderline)
        } else {
          as.character(n_borderline)
        }
      )
    )
  })

  htmltools::tags$table(
    class = "seg-table seg-gmm-membership-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}
