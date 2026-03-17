# ==============================================================================
# WEIGHTING HTML REPORT - TABLE BUILDER
# ==============================================================================

#' Build Summary Table HTML
#'
#' Creates the overview table showing all weights at a glance.
#'
#' @param weight_details List of per-weight detail structures
#' @return Character, HTML string
#' @keywords internal
build_summary_table <- function(weight_details) {
  rows <- ""
  for (detail in weight_details) {
    diag <- detail$diagnostics
    if (is.null(diag)) next

    quality_class <- switch(diag$quality$status,
      "GOOD" = "quality-good",
      "ACCEPTABLE" = "quality-warn",
      "quality-poor"
    )

    rows <- paste0(rows, sprintf(
      '<tr>
        <td class="wt-label-col">%s</td>
        <td>%s</td>
        <td class="wt-num">%d</td>
        <td class="wt-num">%d</td>
        <td class="wt-num">%.4f</td>
        <td class="wt-num">%.4f</td>
        <td class="wt-num">%.4f</td>
        <td class="wt-num">%.2f</td>
        <td class="wt-num">%.1f%%</td>
        <td class="%s">%s</td>
      </tr>\n',
      htmlEscape(detail$weight_name),
      htmlEscape(detail$method),
      diag$sample_size$n_total,
      diag$effective_sample$effective_n,
      diag$distribution$min,
      diag$distribution$max,
      diag$distribution$mean,
      diag$effective_sample$design_effect,
      diag$effective_sample$efficiency,
      quality_class,
      diag$quality$status
    ))
  }

  sprintf(
    '<table class="wt-table">
      <thead>
        <tr>
          <th class="wt-label-col">Weight</th>
          <th>Method</th>
          <th class="wt-num">N</th>
          <th class="wt-num">Eff. N</th>
          <th class="wt-num">Min</th>
          <th class="wt-num">Max</th>
          <th class="wt-num">Mean</th>
          <th class="wt-num">DEFF</th>
          <th class="wt-num">Efficiency</th>
          <th style="text-align:center;">Quality</th>
        </tr>
      </thead>
      <tbody>%s</tbody>
    </table>', rows
  )
}

#' Build Diagnostics Table HTML
#'
#' @param diagnostics List, from diagnose_weights()
#' @return Character, HTML string
#' @keywords internal
build_diagnostics_table <- function(diagnostics) {
  diag <- diagnostics
  if (is.null(diag)) return("")

  grid_html <- sprintf(
    '<div class="wt-diag-grid">
      <div class="wt-diag-card">
        <h4>Sample Size</h4>
        <table class="wt-table wt-table-compact">
          <tr><td>Total</td><td class="wt-num">%d</td></tr>
          <tr><td>Valid</td><td class="wt-num">%d</td></tr>
          <tr><td>NA</td><td class="wt-num">%d</td></tr>
          <tr><td>Zero</td><td class="wt-num">%d</td></tr>
        </table>
      </div>
      <div class="wt-diag-card">
        <h4>Distribution</h4>
        <table class="wt-table wt-table-compact">
          <tr><td>Min</td><td class="wt-num">%.4f</td></tr>
          <tr><td>Q1</td><td class="wt-num">%.4f</td></tr>
          <tr><td>Median</td><td class="wt-num">%.4f</td></tr>
          <tr><td>Q3</td><td class="wt-num">%.4f</td></tr>
          <tr><td>Max</td><td class="wt-num">%.4f</td></tr>
          <tr><td>Mean</td><td class="wt-num">%.4f</td></tr>
          <tr><td>SD</td><td class="wt-num">%.4f</td></tr>
          <tr><td>CV</td><td class="wt-num">%.4f</td></tr>
        </table>
      </div>
      <div class="wt-diag-card">
        <h4>Effective Sample</h4>
        <table class="wt-table wt-table-compact">
          <tr><td>Effective N</td><td class="wt-num">%d</td></tr>
          <tr><td>Design Effect</td><td class="wt-num">%.2f</td></tr>
          <tr><td>Efficiency</td><td class="wt-num">%.1f%%</td></tr>
        </table>
      </div>
    </div>',
    diag$sample_size$n_total, diag$sample_size$n_valid,
    diag$sample_size$n_na, diag$sample_size$n_zero,
    diag$distribution$min, diag$distribution$q1, diag$distribution$median,
    diag$distribution$q3, diag$distribution$max, diag$distribution$mean,
    diag$distribution$sd, diag$distribution$cv,
    diag$effective_sample$effective_n, diag$effective_sample$design_effect,
    diag$effective_sample$efficiency
  )

  callout <- '<div class="wt-callout" style="margin-top:16px;">
    <strong>Reading these metrics:</strong><br/>
    <strong>Min/Max:</strong> The smallest and largest weights assigned to any respondent. Values far from 1.0 mean some respondents are being counted much more or less than others.<br/>
    <strong>Q1/Q3:</strong> The 25th and 75th percentiles. The middle 50%% of weights fall between these values &mdash; a narrow Q1&ndash;Q3 range means most respondents carry similar weight.<br/>
    <strong>SD:</strong> Standard deviation of the weights. Lower values indicate more uniform weighting.<br/>
    <strong>CV:</strong> Coefficient of variation (SD &divide; Mean). Summarises weight variability as a ratio; values below 0.20 indicate good uniformity, above 0.50 may warrant review.<br/>
    <strong>Design Effect (DEFF):</strong> Kish&rsquo;s design effect due to unequal weighting, calculated as n &times; &sum;w&sup2; / (&sum;w)&sup2;. DEFF = 1.0 means all weights are equal (no variance inflation). Higher values mean the effective sample size is reduced relative to the actual sample size.<br/>
    <strong>Efficiency:</strong> 100%% &divide; DEFF &mdash; the proportion of the sample&rsquo;s statistical power retained after weighting. Above 70%% is generally good; below 50%% suggests the weights are highly variable and precision is substantially reduced.
  </div>'

  paste0(grid_html, callout)
}

#' Build Rim Margins Table HTML
#'
#' @param margins Data frame from calculate_achieved_margins()
#' @return Character, HTML string
#' @keywords internal
build_margins_table <- function(margins) {
  if (is.null(margins) || nrow(margins) == 0) return("")

  rows <- ""
  for (i in seq_len(nrow(margins))) {
    r <- margins[i, ]
    diff_class <- if (abs(r$diff_pct) < 0.5) "diff-good"
                  else if (abs(r$diff_pct) < 2.0) "diff-warn"
                  else "diff-poor"

    rows <- paste0(rows, sprintf(
      '<tr><td>%s</td><td>%s</td><td class="wt-num">%.1f%%</td><td class="wt-num">%.1f%%</td><td class="wt-num %s">%+.1f%%</td></tr>\n',
      htmlEscape(r$variable), htmlEscape(r$category),
      r$target_pct, r$achieved_pct, diff_class, r$diff_pct
    ))
  }

  callout <- '<div class="wt-callout" style="margin-bottom:12px;">
    This table compares the target marginal percentages with the achieved (weighted) percentages for each variable and category.
    Differences close to zero (green) confirm that the raking algorithm converged successfully.
    Small residual differences (amber) are normal and typically arise from rounding or near-empty cells.
    Large differences (red, &gt;2pp) may indicate convergence issues or structural problems in the data.
  </div>'

  sprintf(
    '<h4>Rim Target Achievement</h4>
    %s
    <table class="wt-table">
      <thead><tr><th>Variable</th><th>Category</th><th>Target</th><th>Achieved</th><th>Diff</th></tr></thead>
      <tbody>%s</tbody>
    </table>', callout, rows
  )
}

#' Build Stratum Table HTML
#'
#' @param stratum_summary Data frame
#' @return Character, HTML string
#' @keywords internal
build_stratum_table <- function(stratum_summary) {
  if (is.null(stratum_summary) || nrow(stratum_summary) == 0) return("")

  rows <- ""
  for (i in seq_len(nrow(stratum_summary))) {
    r <- stratum_summary[i, ]
    rows <- paste0(rows, sprintf(
      '<tr><td>%s</td><td class="wt-num">%s</td><td class="wt-num">%d</td><td class="wt-num">%.4f</td></tr>\n',
      htmlEscape(r$stratum), format(r$population_size, big.mark = ","),
      r$sample_size, r$weight
    ))
  }

  callout <- '<div class="wt-callout" style="margin-bottom:12px;">
    Each stratum&rsquo;s weight equals its population size divided by the number of respondents sampled from it.
    Strata that are under-represented in the sample relative to the population receive weights greater than 1.0;
    over-represented strata receive weights less than 1.0.
  </div>'

  sprintf(
    '<h4>Stratum Details</h4>
    %s
    <table class="wt-table">
      <thead><tr><th>Stratum</th><th>Population</th><th>Sample</th><th>Weight</th></tr></thead>
      <tbody>%s</tbody>
    </table>', callout, rows
  )
}

#' Build Cell Details Table HTML
#'
#' @param cell_summary Data frame
#' @return Character, HTML string
#' @keywords internal
build_cell_table <- function(cell_summary) {
  if (is.null(cell_summary) || nrow(cell_summary) == 0) return("")

  rows <- ""
  for (i in seq_len(nrow(cell_summary))) {
    r <- cell_summary[i, ]
    rows <- paste0(rows, sprintf(
      '<tr><td>%s</td><td class="wt-num">%.1f%%</td><td class="wt-num">%d</td><td class="wt-num">%.1f%%</td><td class="wt-num">%.4f</td></tr>\n',
      htmlEscape(r$cell), r$target_pct, r$sample_count, r$sample_pct, r$weight
    ))
  }

  callout <- '<div class="wt-callout" style="margin-bottom:12px;">
    Each cell represents a unique combination of the interlocking variables.
    The weight for each cell is: (target %% &times; total N) &divide; cell count.
    Cells with very few respondents will receive large weights &mdash; consider combining sparse
    categories if any single cell has fewer than ~10 respondents.
  </div>'

  sprintf(
    '<h4>Cell Details</h4>
    %s
    <table class="wt-table">
      <thead><tr><th>Cell</th><th>Target%%</th><th>Sample N</th><th>Sample%%</th><th>Weight</th></tr></thead>
      <tbody>%s</tbody>
    </table>', callout, rows
  )
}

#' HTML Escape Helper
#'
#' @param x Character string
#' @return Character, escaped
#' @keywords internal
htmlEscape <- function(x) {
  x <- gsub("&", "&amp;", x)
  x <- gsub("<", "&lt;", x)
  x <- gsub(">", "&gt;", x)
  x <- gsub('"', "&quot;", x)
  x
}
