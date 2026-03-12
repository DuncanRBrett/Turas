# ==============================================================================
# CONJOINT HTML REPORT - TABLE BUILDER
# ==============================================================================
# Builds plain HTML tables (no external deps) with export-ready data attributes.
# All tables use cj-table class and include data-col-key / data-export-value
# attributes for CSV/Excel export support.
# ==============================================================================

.html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


#' Build Importance Summary Table
#' @param importance Data frame with Attribute, Importance
#' @return HTML string
#' @keywords internal
build_importance_table <- function(importance) {

  rows <- vapply(seq_len(nrow(importance)), function(i) {
    imp <- importance$Importance[i]
    bar_width <- min(imp, 100)
    sprintf(
      '<tr><td class="cj-label-col" data-col-key="attribute" data-export-value="%s">%s</td><td class="cj-num" data-col-key="importance" data-export-value="%.1f">%.1f%%</td><td><div class="cj-bar-cell"><div class="cj-bar" style="width:%.1f%%"></div></div></td></tr>',
      .html_escape(importance$Attribute[i]),
      .html_escape(importance$Attribute[i]), imp, imp, bar_width
    )
  }, character(1))

  paste0(
    '<table class="cj-table" data-table-id="importance"><thead><tr>',
    '<th data-col-key="attribute">Attribute</th>',
    '<th data-col-key="importance">Importance</th>',
    '<th></th></tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build Utilities Table for an Attribute
#' @param utilities Data frame filtered to one attribute
#' @return HTML string
#' @keywords internal
build_utilities_table <- function(utilities) {

  has_se <- "SE" %in% names(utilities)

  rows <- vapply(seq_len(nrow(utilities)), function(i) {
    u <- utilities$Utility[i]
    class <- if (u > 0) "cj-positive" else if (u < 0) "cj-negative" else ""
    baseline <- if (!is.null(utilities$is_baseline) && utilities$is_baseline[i]) {
      ' <span class="cj-baseline">(baseline)</span>'
    } else ""

    se_cell <- if (has_se) {
      se_val <- if (!is.null(utilities$SE[i]) && !is.na(utilities$SE[i])) utilities$SE[i] else NA
      sprintf(
        '<td class="cj-num" data-col-key="se" data-export-value="%s">%s</td>',
        if (is.na(se_val)) "" else sprintf("%.3f", se_val),
        if (is.na(se_val)) "\u2014" else sprintf("%.3f", se_val)
      )
    } else ""

    sprintf(
      '<tr><td class="cj-label-col" data-col-key="level" data-export-value="%s">%s%s</td><td class="cj-num %s" data-col-key="utility" data-export-value="%.4f">%.3f</td>%s</tr>',
      .html_escape(utilities$Level[i]),
      .html_escape(utilities$Level[i]), baseline, class, u, u, se_cell
    )
  }, character(1))

  se_header <- if (has_se) '<th data-col-key="se">Std. Error</th>' else ""

  paste0(
    '<table class="cj-table" data-table-id="utilities"><thead><tr>',
    '<th data-col-key="level">Level</th>',
    '<th data-col-key="utility">Utility</th>',
    se_header,
    '</tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build Model Fit Table
#' @param diagnostics Diagnostics list with fit_statistics
#' @param model_result Model result list
#' @return HTML string
#' @keywords internal
build_model_fit_table <- function(diagnostics, model_result) {

  metrics <- list()

  if (!is.null(diagnostics$fit_statistics)) {
    fs <- diagnostics$fit_statistics
    metrics[["McFadden R\u00b2"]] <- sprintf("%.4f", fs$mcfadden_r2 %||% NA)
    metrics[["Hit Rate"]] <- sprintf("%.1f%%", (fs$hit_rate %||% 0) * 100)
    metrics[["Log-Likelihood"]] <- sprintf("%.2f", fs$log_likelihood %||% NA)
    if (!is.null(fs$aic)) metrics[["AIC"]] <- sprintf("%.1f", fs$aic)
    if (!is.null(fs$bic)) metrics[["BIC"]] <- sprintf("%.1f", fs$bic)
  }

  metrics[["Method"]] <- model_result$method %||% "N/A"
  metrics[["Observations"]] <- as.character(model_result$n_obs %||% "N/A")
  metrics[["Respondents"]] <- as.character(model_result$n_respondents %||% "N/A")
  metrics[["Choice Sets"]] <- as.character(model_result$n_choice_sets %||% "N/A")
  metrics[["Converged"]] <- if (!is.null(model_result$convergence$converged))
    ifelse(model_result$convergence$converged, "Yes", "No") else "N/A"

  rows <- vapply(names(metrics), function(m) {
    sprintf(
      '<tr><td class="cj-label-col" data-col-key="metric" data-export-value="%s">%s</td><td class="cj-num" data-col-key="value" data-export-value="%s">%s</td></tr>',
      .html_escape(m), m, .html_escape(metrics[[m]]), metrics[[m]]
    )
  }, character(1))

  paste0(
    '<table class="cj-table" data-table-id="model-fit"><thead><tr>',
    '<th data-col-key="metric">Metric</th>',
    '<th data-col-key="value">Value</th>',
    '</tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build HB Convergence Table
#' @param convergence Convergence list with geweke_z, effective_sample_size
#' @return HTML string
#' @keywords internal
build_convergence_table <- function(convergence) {

  if (is.null(convergence$geweke_z)) return("")

  param_names <- names(convergence$geweke_z)
  rows <- vapply(seq_along(param_names), function(i) {
    gz <- convergence$geweke_z[i]
    ess <- convergence$effective_sample_size[i]
    gz_class <- if (abs(gz) < 1.96) "cj-positive" else "cj-negative"
    ess_class <- if (ess > 100) "cj-positive" else "cj-negative"
    sprintf(
      '<tr><td class="cj-label-col" data-col-key="parameter" data-export-value="%s">%s</td><td class="cj-num %s" data-col-key="geweke_z" data-export-value="%.2f">%.2f</td><td class="cj-num %s" data-col-key="ess" data-export-value="%.0f">%.0f</td></tr>',
      .html_escape(param_names[i]), .html_escape(param_names[i]),
      gz_class, gz, gz, ess_class, ess, ess
    )
  }, character(1))

  paste0(
    '<table class="cj-table" data-table-id="convergence"><thead><tr>',
    '<th data-col-key="parameter">Parameter</th>',
    '<th data-col-key="geweke_z">Geweke z</th>',
    '<th data-col-key="ess">ESS</th>',
    '</tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build LC Comparison Table
#' @param comparison LC comparison data frame with K, AIC, BIC, Entropy_R2
#' @param optimal_k Optimal number of classes
#' @return HTML string
#' @keywords internal
build_lc_comparison_table <- function(comparison, optimal_k) {

  if (is.null(comparison) || nrow(comparison) == 0) return("")

  rows <- vapply(seq_len(nrow(comparison)), function(i) {
    k <- comparison$K[i]
    highlight <- if (k == optimal_k) ' class="cj-highlight-row"' else ""
    sprintf(
      '<tr%s><td class="cj-num" data-col-key="k" data-export-value="%d">%d</td><td class="cj-num" data-col-key="aic" data-export-value="%.1f">%.1f</td><td class="cj-num" data-col-key="bic" data-export-value="%.1f">%.1f</td><td class="cj-num" data-col-key="entropy_r2" data-export-value="%.3f">%.3f</td></tr>',
      highlight, k, k, comparison$AIC[i], comparison$AIC[i],
      comparison$BIC[i], comparison$BIC[i],
      comparison$Entropy_R2[i], comparison$Entropy_R2[i]
    )
  }, character(1))

  paste0(
    '<table class="cj-table" data-table-id="lc-comparison"><thead><tr>',
    '<th data-col-key="k">K</th>',
    '<th data-col-key="aic">AIC</th>',
    '<th data-col-key="bic">BIC</th>',
    '<th data-col-key="entropy_r2">Entropy R\u00b2</th>',
    '</tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build WTP Table
#' @param wtp_data WTP data list with wtp_table, price_attribute
#' @return HTML string
#' @keywords internal
build_wtp_table <- function(wtp_data) {

  if (is.null(wtp_data) || is.null(wtp_data$wtp_table)) return("")

  wtp <- wtp_data$wtp_table
  has_ci <- all(c("WTP_Lower", "WTP_Upper") %in% names(wtp))

  rows <- vapply(seq_len(nrow(wtp)), function(i) {
    is_bl <- if ("is_baseline" %in% names(wtp)) wtp$is_baseline[i] else FALSE
    wtp_val <- wtp$WTP[i]
    wtp_class <- if (is_bl) "" else if (wtp_val > 0) "cj-positive" else if (wtp_val < 0) "cj-negative" else ""
    wtp_display <- if (is_bl) "\u2014" else sprintf("$%.2f", wtp_val)

    ci_cell <- if (has_ci) {
      if (is_bl) {
        '<td class="cj-num" data-col-key="ci">\u2014</td>'
      } else {
        sprintf(
          '<td class="cj-num" data-col-key="ci" data-export-value="[%.2f, %.2f]">[$%.2f, $%.2f]</td>',
          wtp$WTP_Lower[i], wtp$WTP_Upper[i], wtp$WTP_Lower[i], wtp$WTP_Upper[i]
        )
      }
    } else ""

    sprintf(
      '<tr><td class="cj-label-col" data-col-key="attribute" data-export-value="%s">%s</td><td class="cj-label-col" data-col-key="level" data-export-value="%s">%s%s</td><td class="cj-num %s" data-col-key="wtp" data-export-value="%s">%s</td>%s</tr>',
      .html_escape(wtp$Attribute[i]), .html_escape(wtp$Attribute[i]),
      .html_escape(wtp$Level[i]), .html_escape(wtp$Level[i]),
      if (is_bl) ' <span class="cj-baseline">(baseline)</span>' else "",
      wtp_class,
      if (is_bl) "" else sprintf("%.2f", wtp_val),
      wtp_display,
      ci_cell
    )
  }, character(1))

  ci_header <- if (has_ci) '<th data-col-key="ci">95% CI</th>' else ""

  paste0(
    '<table class="cj-table" data-table-id="wtp"><thead><tr>',
    '<th data-col-key="attribute">Attribute</th>',
    '<th data-col-key="level">Level</th>',
    '<th data-col-key="wtp">WTP</th>',
    ci_header,
    '</tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build Demand Curve Table
#' @param demand_curve Data frame with Price, Demand (or Share)
#' @return HTML string
#' @keywords internal
build_demand_table <- function(demand_curve) {

  if (is.null(demand_curve) || nrow(demand_curve) == 0) return("")

  share_col <- if ("Share" %in% names(demand_curve)) "Share" else if ("Demand" %in% names(demand_curve)) "Demand" else NULL
  if (is.null(share_col)) return("")

  rows <- vapply(seq_len(nrow(demand_curve)), function(i) {
    price <- demand_curve$Price[i]
    share <- demand_curve[[share_col]][i]
    sprintf(
      '<tr><td class="cj-num" data-col-key="price" data-export-value="%.2f">$%.2f</td><td class="cj-num" data-col-key="share" data-export-value="%.1f">%.1f%%</td></tr>',
      price, price, share, share
    )
  }, character(1))

  paste0(
    '<table class="cj-table" data-table-id="demand-curve"><thead><tr>',
    '<th data-col-key="price">Price</th>',
    '<th data-col-key="share">Market Share</th>',
    '</tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build Class Importance Table (Latent Class)
#' @param class_importance Data frame with importance by class
#' @param class_sizes Named vector or list of class sizes
#' @return HTML string
#' @keywords internal
build_class_importance_table <- function(class_importance, class_sizes = NULL) {

  if (is.null(class_importance) || nrow(class_importance) == 0) return("")

  # Determine class columns (columns starting with "Class_" or numeric suffix)
  class_cols <- grep("^Class", names(class_importance), value = TRUE)
  if (length(class_cols) == 0) {
    # Try columns that are numeric besides Attribute
    num_cols <- setdiff(names(class_importance), "Attribute")
    class_cols <- num_cols[vapply(num_cols, function(c) is.numeric(class_importance[[c]]), logical(1))]
  }
  if (length(class_cols) == 0) return("")

  # Header row
  class_headers <- vapply(class_cols, function(cc) {
    label <- gsub("_", " ", cc)
    size_label <- ""
    if (!is.null(class_sizes)) {
      idx <- gsub("\\D", "", cc)
      if (nzchar(idx) && as.integer(idx) <= length(class_sizes)) {
        size_label <- sprintf(" (%.0f%%)", class_sizes[[as.integer(idx)]] * 100)
      }
    }
    sprintf('<th data-col-key="%s">%s%s</th>', .html_escape(cc), .html_escape(label), size_label)
  }, character(1))

  header <- paste0(
    '<tr><th data-col-key="attribute">Attribute</th>',
    paste(class_headers, collapse = ""),
    '</tr>'
  )

  # Data rows
  rows <- vapply(seq_len(nrow(class_importance)), function(i) {
    cells <- vapply(class_cols, function(cc) {
      val <- class_importance[[cc]][i]
      sprintf(
        '<td class="cj-num" data-col-key="%s" data-export-value="%.1f">%.1f%%</td>',
        .html_escape(cc), val, val
      )
    }, character(1))
    sprintf(
      '<tr><td class="cj-label-col" data-col-key="attribute" data-export-value="%s">%s</td>%s</tr>',
      .html_escape(class_importance$Attribute[i]),
      .html_escape(class_importance$Attribute[i]),
      paste(cells, collapse = "")
    )
  }, character(1))

  paste0(
    '<table class="cj-table" data-table-id="class-importance"><thead>',
    header,
    '</thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build Respondent Quality Table (HB)
#' @param quality Quality list with mean_rlh, n_flagged, chance_rlh
#' @param n_respondents Total respondents
#' @return HTML string
#' @keywords internal
build_respondent_quality_table <- function(quality, n_respondents = NA) {

  if (is.null(quality)) return("")

  metrics <- list()
  if (!is.null(quality$mean_rlh)) metrics[["Mean RLH"]] <- sprintf("%.4f", quality$mean_rlh)
  if (!is.null(quality$chance_rlh)) metrics[["Chance RLH"]] <- sprintf("%.4f", quality$chance_rlh)
  if (!is.null(quality$mean_rlh) && !is.null(quality$chance_rlh)) {
    ratio <- quality$mean_rlh / quality$chance_rlh
    metrics[["RLH / Chance"]] <- sprintf("%.2fx", ratio)
  }
  if (!is.null(quality$n_flagged)) {
    flag_pct <- if (!is.na(n_respondents) && n_respondents > 0) {
      sprintf(" (%.1f%%)", quality$n_flagged / n_respondents * 100)
    } else ""
    metrics[["Flagged Respondents"]] <- paste0(quality$n_flagged, flag_pct)
  }
  if (!is.na(n_respondents)) metrics[["Total Respondents"]] <- as.character(n_respondents)

  if (length(metrics) == 0) return("")

  rows <- vapply(names(metrics), function(m) {
    sprintf(
      '<tr><td class="cj-label-col" data-col-key="metric" data-export-value="%s">%s</td><td class="cj-num" data-col-key="value" data-export-value="%s">%s</td></tr>',
      .html_escape(m), m, .html_escape(metrics[[m]]), metrics[[m]]
    )
  }, character(1))

  paste0(
    '<table class="cj-table" data-table-id="respondent-quality"><thead><tr>',
    '<th data-col-key="metric">Metric</th>',
    '<th data-col-key="value">Value</th>',
    '</tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}
