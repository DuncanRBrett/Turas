# ==============================================================================
# CONFIDENCE HTML REPORT - TABLE BUILDER
# ==============================================================================
# Builds plain HTML tables for confidence interval results.
# No external dependencies — pure HTML with CSS class hooks.
# ==============================================================================

#' Build Summary Table (All Questions at a Glance)
#'
#' @param questions Named list from transform_confidence_for_html()
#' @return Character string of HTML
#' @keywords internal
build_ci_summary_table <- function(questions, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  if (length(questions) == 0) return("")

  rows <- character()
  for (q in questions) {
    badge_class <- paste0("ci-quality-", q$quality$badge)
    badge_label <- switch(q$quality$badge, good = "Good", warn = "Caution", poor = "Poor", "?")
    type_label <- switch(q$type, proportion = "Proportion", mean = "Mean", nps = "NPS", q$type)

    # Format estimate
    est <- if (q$type == "proportion" && !is.na(q$estimate)) {
      sprintf("%.1f%%", q$estimate * 100)
    } else if (!is.na(q$estimate)) {
      sprintf("%.2f", q$estimate)
    } else "N/A"

    # Format CI bounds
    fmt_ci <- function(val, is_prop) {
      if (is.na(val)) return("N/A")
      if (is_prop) sprintf("%.1f%%", val * 100) else sprintf("%.2f", val)
    }
    is_prop <- q$type == "proportion"
    lower_str <- fmt_ci(q$ci_lower, is_prop)
    upper_str <- fmt_ci(q$ci_upper, is_prop)

    # CI width display
    width_str <- if (!is.na(q$ci_width)) {
      if (is_prop) sprintf("%.1f pp", q$ci_width)
      else sprintf("%.2f", q$ci_width)
    } else "N/A"

    rows <- c(rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">%s</td>
        <td class="ci-td">%s</td>
        <td class="ci-td ci-num">%s</td>
        <td class="ci-td ci-num">%s</td>
        <td class="ci-td ci-num">%s</td>
        <td class="ci-td ci-num">%s</td>
        <td class="ci-td"><span class="%s">%s</span></td>
      </tr>',
      htmlEscape(q$question_id), type_label, est, lower_str, upper_str,
      width_str, badge_class, badge_label
    ))
  }

  sprintf(
    '<table class="ci-table">
      <thead>
        <tr>
          <th class="ci-th ci-label-col">Question</th>
          <th class="ci-th">Type</th>
          <th class="ci-th ci-num">Estimate</th>
          <th class="ci-th ci-num">%s Lower</th>
          <th class="ci-th ci-num">%s Upper</th>
          <th class="ci-th ci-num">%s Width</th>
          <th class="ci-th">Quality</th>
        </tr>
      </thead>
      <tbody>
        %s
      </tbody>
    </table>',
    labels$interval_abbrev, labels$interval_abbrev, labels$interval_abbrev,
    paste(rows, collapse = "\n")
  )
}


#' Build Study-Level Statistics Table
#'
#' @param study_level List with stats_df, weight_concentration, margin_comparison
#' @return Character string of HTML
#' @keywords internal
build_study_level_table <- function(study_level) {
  stats_df <- study_level$stats_df
  if (is.null(stats_df)) return("")

  rows <- character()
  for (i in seq_len(nrow(stats_df))) {
    r <- stats_df[i, ]
    warn_html <- if (nzchar(r$Warning %||% "")) {
      sprintf('<span class="ci-quality-warn">%s</span>', htmlEscape(r$Warning))
    } else {
      '<span class="ci-quality-good">None</span>'
    }

    rows <- c(rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">%s</td>
        <td class="ci-td ci-num">%s</td>
        <td class="ci-td ci-num">%.3f</td>
        <td class="ci-td ci-num">%.2f</td>
        <td class="ci-td ci-num">%s</td>
        <td class="ci-td ci-num">%.1f%%</td>
        <td class="ci-td">%s</td>
      </tr>',
      htmlEscape(r$Group),
      format(r$Actual_n, big.mark = ","),
      r$Mean_Weight,
      r$DEFF,
      format(r$Effective_n, big.mark = ","),
      if (!is.na(r$DEFF) && r$DEFF > 0) 100 / r$DEFF else NA,
      warn_html
    ))
  }

  sprintf(
    '<table class="ci-table">
      <thead>
        <tr>
          <th class="ci-th ci-label-col">Group</th>
          <th class="ci-th ci-num">Sample N</th>
          <th class="ci-th ci-num">Mean Weight</th>
          <th class="ci-th ci-num">DEFF</th>
          <th class="ci-th ci-num">Effective N</th>
          <th class="ci-th ci-num">Efficiency</th>
          <th class="ci-th">Warnings</th>
        </tr>
      </thead>
      <tbody>
        %s
      </tbody>
    </table>',
    paste(rows, collapse = "\n")
  )
}


#' Build Proportion Detail Table (Method Comparison)
#'
#' @param result List with moe, wilson, bootstrap, bayesian sub-lists
#' @param conf_level Numeric confidence level
#' @return Character string of HTML
#' @keywords internal
build_proportion_detail_table <- function(result, conf_level, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  pct <- round(conf_level * 100)
  rows <- character()

  add_row <- function(method, lower, upper, extra_info = "") {
    if (is.null(lower) || is.null(upper)) return()
    moe <- (upper - lower) / 2
    rows <<- c(rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">%s</td>
        <td class="ci-td ci-num">%.1f%%</td>
        <td class="ci-td ci-num">%.1f%%</td>
        <td class="ci-td ci-num">&plusmn;%.1f%%</td>
        <td class="ci-td">%s</td>
      </tr>',
      method, lower * 100, upper * 100, moe * 100, extra_info
    ))
  }

  if (!is.null(result$moe)) {
    add_row("Normal Approximation",
            result$moe$lower, result$moe$upper,
            sprintf("SE = %.4f", result$moe$se %||% NA))
  }
  if (!is.null(result$wilson)) {
    add_row("Wilson Score",
            result$wilson$lower, result$wilson$upper,
            "Recommended for extreme proportions")
  }
  if (!is.null(result$bootstrap)) {
    add_row("Bootstrap",
            result$bootstrap$lower, result$bootstrap$upper,
            sprintf("B = %s", format(result$bootstrap$B %||% NA, big.mark = ",")))
  }
  if (!is.null(result$bayesian)) {
    add_row("Bayesian Credible",
            result$bayesian$lower, result$bayesian$upper,
            sprintf("Prior: %s", result$bayesian$prior_type %||% "Uninformed"))
  }

  if (length(rows) == 0) return("")

  sprintf(
    '<table class="ci-table ci-table-compact">
      <thead>
        <tr>
          <th class="ci-th ci-label-col">Method</th>
          <th class="ci-th ci-num">%d%% Lower</th>
          <th class="ci-th ci-num">%d%% Upper</th>
          <th class="ci-th ci-num">%s</th>
          <th class="ci-th">Notes</th>
        </tr>
      </thead>
      <tbody>
        %s
      </tbody>
    </table>',
    pct, pct, labels$moe_abbrev, paste(rows, collapse = "\n")
  )
}


#' Build Mean Detail Table (Method Comparison)
#'
#' @param result List with t_dist, bootstrap, bayesian sub-lists
#' @param conf_level Numeric confidence level
#' @return Character string of HTML
#' @keywords internal
build_mean_detail_table <- function(result, conf_level, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  pct <- round(conf_level * 100)
  rows <- character()

  add_row <- function(method, lower, upper, extra_info = "") {
    if (is.null(lower) || is.null(upper)) return()
    half_width <- (upper - lower) / 2
    rows <<- c(rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">%s</td>
        <td class="ci-td ci-num">%.2f</td>
        <td class="ci-td ci-num">%.2f</td>
        <td class="ci-td ci-num">&plusmn;%.2f</td>
        <td class="ci-td">%s</td>
      </tr>',
      method, lower, upper, half_width, extra_info
    ))
  }

  if (!is.null(result$t_dist)) {
    add_row("t-Distribution",
            result$t_dist$lower, result$t_dist$upper,
            sprintf("df = %d, SE = %.3f", result$t_dist$df %||% NA, result$t_dist$se %||% NA))
  }
  if (!is.null(result$bootstrap)) {
    add_row("Bootstrap",
            result$bootstrap$lower, result$bootstrap$upper,
            sprintf("B = %s", format(result$bootstrap$B %||% NA, big.mark = ",")))
  }
  if (!is.null(result$bayesian)) {
    add_row("Bayesian Credible",
            result$bayesian$lower, result$bayesian$upper,
            sprintf("Prior: %s", result$bayesian$prior_type %||% "Uninformed"))
  }

  if (length(rows) == 0) return("")

  sprintf(
    '<table class="ci-table ci-table-compact">
      <thead>
        <tr>
          <th class="ci-th ci-label-col">Method</th>
          <th class="ci-th ci-num">%d%% Lower</th>
          <th class="ci-th ci-num">%d%% Upper</th>
          <th class="ci-th ci-num">%s</th>
          <th class="ci-th">Notes</th>
        </tr>
      </thead>
      <tbody>
        %s
      </tbody>
    </table>',
    pct, pct, labels$halfwidth_name, paste(rows, collapse = "\n")
  )
}


#' Build NPS Detail Table
#'
#' @param result List with nps_score, pct_promoters, pct_detractors, CI results
#' @param conf_level Numeric confidence level
#' @return Character string of HTML
#' @keywords internal
build_nps_detail_table <- function(result, conf_level, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  pct <- round(conf_level * 100)

  # NPS breakdown row
  breakdown <- sprintf(
    '<tr class="ci-row-highlight">
      <td class="ci-td ci-label-col"><strong>NPS Score</strong></td>
      <td class="ci-td ci-num" colspan="3"><strong>%+.0f</strong></td>
      <td class="ci-td">Promoters: %.0f%% &minus; Detractors: %.0f%%</td>
    </tr>',
    result$nps_score %||% NA,
    result$pct_promoters %||% NA,
    result$pct_detractors %||% NA
  )

  ci_rows <- character()

  if (!is.null(result$moe_normal)) {
    ci_rows <- c(ci_rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">Normal Approximation</td>
        <td class="ci-td ci-num">%+.1f</td>
        <td class="ci-td ci-num">%+.1f</td>
        <td class="ci-td ci-num">&plusmn;%.1f</td>
        <td class="ci-td">SE = %.2f</td>
      </tr>',
      result$moe_normal$lower, result$moe_normal$upper,
      (result$moe_normal$upper - result$moe_normal$lower) / 2,
      result$moe_normal$se %||% NA
    ))
  }

  if (!is.null(result$bootstrap)) {
    ci_rows <- c(ci_rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">Bootstrap</td>
        <td class="ci-td ci-num">%+.1f</td>
        <td class="ci-td ci-num">%+.1f</td>
        <td class="ci-td ci-num">&plusmn;%.1f</td>
        <td class="ci-td">Resampling-based</td>
      </tr>',
      result$bootstrap$lower, result$bootstrap$upper,
      (result$bootstrap$upper - result$bootstrap$lower) / 2
    ))
  }

  if (!is.null(result$bayesian)) {
    ci_rows <- c(ci_rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">Bayesian Credible</td>
        <td class="ci-td ci-num">%+.1f</td>
        <td class="ci-td ci-num">%+.1f</td>
        <td class="ci-td ci-num">&plusmn;%.1f</td>
        <td class="ci-td">Posterior: mean=%+.1f</td>
      </tr>',
      result$bayesian$lower, result$bayesian$upper,
      (result$bayesian$upper - result$bayesian$lower) / 2,
      result$bayesian$posterior_mean %||% NA
    ))
  }

  sprintf(
    '<table class="ci-table ci-table-compact">
      <thead>
        <tr>
          <th class="ci-th ci-label-col">Metric</th>
          <th class="ci-th ci-num">%d%% Lower</th>
          <th class="ci-th ci-num">%d%% Upper</th>
          <th class="ci-th ci-num">%s</th>
          <th class="ci-th">Notes</th>
        </tr>
      </thead>
      <tbody>
        %s
        %s
      </tbody>
    </table>',
    pct, pct, labels$moe_abbrev, breakdown, paste(ci_rows, collapse = "\n")
  )
}


#' Build Representativeness Table (Margin Comparison)
#'
#' @param margin_comparison Data frame from compute_margin_comparison()
#' @return Character string of HTML
#' @keywords internal
build_representativeness_table <- function(margin_comparison) {
  if (is.null(margin_comparison) || nrow(margin_comparison) == 0) return("")

  rows <- character()
  for (i in seq_len(nrow(margin_comparison))) {
    r <- margin_comparison[i, ]
    flag_class <- switch(r$Flag,
      GREEN = "ci-diff-good",
      AMBER = "ci-diff-warn",
      RED   = "ci-diff-poor",
      "ci-diff-warn"
    )
    flag_label <- switch(r$Flag,
      GREEN = "OK",
      AMBER = "Caution",
      RED   = "Off-target",
      r$Flag
    )

    rows <- c(rows, sprintf(
      '<tr>
        <td class="ci-td ci-label-col">%s</td>
        <td class="ci-td">%s</td>
        <td class="ci-td ci-num">%.1f%%</td>
        <td class="ci-td ci-num">%.1f%%</td>
        <td class="ci-td ci-num">%+.1f pp</td>
        <td class="ci-td"><span class="%s">%s</span></td>
      </tr>',
      htmlEscape(r$Variable %||% ""),
      htmlEscape(r$Category_Label %||% r$Category_Code %||% ""),
      r$Target_Pct, r$Weighted_Sample_Pct, r$Diff_pp,
      flag_class, flag_label
    ))
  }

  sprintf(
    '<table class="ci-table">
      <thead>
        <tr>
          <th class="ci-th ci-label-col">Variable</th>
          <th class="ci-th">Category</th>
          <th class="ci-th ci-num">Target</th>
          <th class="ci-th ci-num">Achieved</th>
          <th class="ci-th ci-num">Difference</th>
          <th class="ci-th">Status</th>
        </tr>
      </thead>
      <tbody>
        %s
      </tbody>
    </table>',
    paste(rows, collapse = "\n")
  )
}


# ==============================================================================
# UTILITY
# ==============================================================================

# HTML escaping utility (canonical definition — other HTML files guard-check this)
#' @keywords internal
htmlEscape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

# Null-coalescing operator (canonical definition in utils.R)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
