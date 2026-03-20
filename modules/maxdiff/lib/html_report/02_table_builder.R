# ==============================================================================
# MAXDIFF HTML REPORT - TABLE BUILDER - TURAS V11.2
# ==============================================================================
# Builds HTML tables for the MaxDiff report
# Layer 2 of the 4-layer HTML report pipeline
# ==============================================================================

# htmlEscape() is defined in 01_data_transformer.R (loaded first by 99_html_report_main.R)

fmt_num <- function(x, digits = 1) {
  if (is.null(x) || is.na(x)) return("&mdash;")
  formatC(round(x, digits), format = "f", digits = digits, big.mark = ",")
}


# ==============================================================================
# PREFERENCE SCORES TABLE
# ==============================================================================

#' Build preference scores table
#'
#' @param scores Data frame from transform_preferences_section
#' @param anchor_data Optional anchor data frame
#'
#' @return HTML string
#' @keywords internal
build_preference_scores_table <- function(scores, anchor_data = NULL) {

  if (is.null(scores) || nrow(scores) == 0) {
    return('<p class="md-empty">No preference scores available.</p>')
  }

  has_shares <- "Pref_Share" %in% names(scores)
  has_se <- "SE" %in% names(scores) && any(!is.na(scores$SE))
  has_anchor <- !is.null(anchor_data) && nrow(anchor_data) > 0

  # Header
  cols <- c('<th class="md-th md-label-col">Item</th>',
            '<th class="md-th md-num">Rank</th>',
            '<th class="md-th md-num">Score (0-100)</th>')
  if (has_shares) cols <- c(cols, '<th class="md-th md-num">Pref Share</th>')
  if (has_anchor) cols <- c(cols, '<th class="md-th md-num">Must-Have %</th>')
  if (has_se) cols <- c(cols, '<th class="md-th md-num">SE</th>')

  header <- sprintf('<thead><tr>%s</tr></thead>', paste(cols, collapse = "\n"))

  # Merge anchor data if available
  if (has_anchor) {
    scores <- merge(scores, anchor_data[, c("Item_ID", "Anchor_Rate", "Is_Must_Have")],
                    by = "Item_ID", all.x = TRUE, sort = FALSE)
    scores <- scores[order(-scores$Rescaled), ]
  }

  # Rows
  max_score <- max(scores$Rescaled, na.rm = TRUE)
  rows <- vapply(seq_len(nrow(scores)), function(i) {
    s <- scores[i, ]
    bar_width <- if (max_score > 0) round(s$Rescaled / max_score * 100) else 0
    label <- htmlEscape(s$Item_Label)

    cells <- sprintf(
      '<td class="md-td md-label-col"><div class="md-bar-cell"><div class="md-bar-bg" style="width:%d%%"></div><span class="md-bar-label">%s</span></div></td>',
      bar_width, label
    )
    cells <- paste0(cells, sprintf('<td class="md-td md-num">%d</td>', s$Rank))
    cells <- paste0(cells, sprintf('<td class="md-td md-num"><strong>%s</strong></td>', fmt_num(s$Rescaled, 1)))

    if (has_shares) {
      cells <- paste0(cells, sprintf('<td class="md-td md-num">%s%%</td>', fmt_num(s$Pref_Share, 1)))
    }

    if (has_anchor) {
      anchor_rate <- if (!is.null(s$Anchor_Rate) && !is.na(s$Anchor_Rate)) s$Anchor_Rate else NA
      if (!is.na(anchor_rate)) {
        badge_class <- if (isTRUE(s$Is_Must_Have)) "md-badge-good" else ""
        cells <- paste0(cells, sprintf('<td class="md-td md-num"><span class="%s">%s%%</span></td>',
                                        badge_class, fmt_num(anchor_rate * 100, 0)))
      } else {
        cells <- paste0(cells, '<td class="md-td md-num">&mdash;</td>')
      }
    }

    if (has_se) {
      cells <- paste0(cells, sprintf('<td class="md-td md-num">%s</td>', fmt_num(s$SE, 3)))
    }

    sprintf('<tr>%s</tr>', cells)
  }, character(1))

  sprintf('<table class="md-table">%s<tbody>%s</tbody></table>',
          header, paste(rows, collapse = "\n"))
}


# ==============================================================================
# BEST/WORST COUNT TABLE
# ==============================================================================

#' Build best-worst count scores table
#'
#' @param count_data Data frame with Best_Pct, Worst_Pct, BW_Score
#' @param discrimination Optional discrimination classifications
#'
#' @return HTML string
#' @keywords internal
build_count_scores_table <- function(count_data, discrimination = NULL) {

  if (is.null(count_data) || nrow(count_data) == 0) {
    return('<p class="md-empty">No count scores available.</p>')
  }

  has_disc <- !is.null(discrimination) && nrow(discrimination) > 0

  cols <- c(
    '<th class="md-th md-label-col">Item</th>',
    '<th class="md-th md-num">Best %</th>',
    '<th class="md-th md-num">Worst %</th>',
    '<th class="md-th md-num">BW Score</th>'
  )
  if (has_disc) cols <- c(cols, '<th class="md-th md-num">Type</th>')

  header <- sprintf('<thead><tr>%s</tr></thead>', paste(cols, collapse = "\n"))

  # Merge discrimination if available
  if (has_disc) {
    count_data <- merge(count_data, discrimination[, c("Item_ID", "Classification_Label")],
                        by = "Item_ID", all.x = TRUE, sort = FALSE)
    count_data <- count_data[order(-count_data$BW_Score), ]
  }

  rows <- vapply(seq_len(nrow(count_data)), function(i) {
    d <- count_data[i, ]
    label <- htmlEscape(d$Item_Label)

    bw_class <- if (d$BW_Score > 0) "md-positive" else if (d$BW_Score < 0) "md-negative" else ""

    cells <- sprintf('<td class="md-td md-label-col">%s</td>', label)
    cells <- paste0(cells, sprintf('<td class="md-td md-num md-positive">%s%%</td>', fmt_num(d$Best_Pct, 1)))
    cells <- paste0(cells, sprintf('<td class="md-td md-num md-negative">%s%%</td>', fmt_num(d$Worst_Pct, 1)))
    cells <- paste0(cells, sprintf('<td class="md-td md-num %s"><strong>%s</strong></td>', bw_class, fmt_num(d$BW_Score, 3)))

    if (has_disc) {
      disc_label <- d$Classification_Label %||% ""
      badge <- switch(disc_label,
        "Universal Favorite" = '<span class="md-badge-good">Favorite</span>',
        "Low Priority" = '<span class="md-badge-poor">Low Priority</span>',
        "Polarizing" = '<span class="md-badge-warn">Polarizing</span>',
        disc_label
      )
      cells <- paste0(cells, sprintf('<td class="md-td md-num">%s</td>', badge))
    }

    sprintf('<tr>%s</tr>', cells)
  }, character(1))

  sprintf('<table class="md-table">%s<tbody>%s</tbody></table>',
          header, paste(rows, collapse = "\n"))
}


# ==============================================================================
# TURF TABLE
# ==============================================================================

#' Build TURF incremental reach table
#'
#' @param turf_data Data frame with Step, Item_Label, Reach_Pct, Incremental_Pct
#'
#' @return HTML string
#' @keywords internal
build_turf_table <- function(turf_data) {

  if (is.null(turf_data) || nrow(turf_data) == 0) {
    return('<p class="md-empty">No TURF results available.</p>')
  }

  header <- '<thead><tr>
    <th class="md-th md-num">Step</th>
    <th class="md-th md-label-col">Item Added</th>
    <th class="md-th md-num">Reach</th>
    <th class="md-th md-num">+ Incremental</th>
    <th class="md-th md-num">Avg Frequency</th>
  </tr></thead>'

  rows <- vapply(seq_len(nrow(turf_data)), function(i) {
    d <- turf_data[i, ]
    label <- htmlEscape(d$Item_Label)
    sprintf(
      '<tr>
        <td class="md-td md-num">%d</td>
        <td class="md-td md-label-col">%s</td>
        <td class="md-td md-num"><strong>%s%%</strong></td>
        <td class="md-td md-num md-positive">+%s%%</td>
        <td class="md-td md-num">%s</td>
      </tr>',
      d$Step, label, fmt_num(d$Reach_Pct, 1),
      fmt_num(d$Incremental_Pct, 1), fmt_num(d$Frequency, 2)
    )
  }, character(1))

  sprintf('<table class="md-table">%s<tbody>%s</tbody></table>',
          header, paste(rows, collapse = "\n"))
}


# ==============================================================================
# DIAGNOSTICS TABLE
# ==============================================================================

#' Build model diagnostics table
#'
#' @param diagnostics List with logit_fit and hb_diagnostics
#'
#' @return HTML string
#' @keywords internal
build_diagnostics_table <- function(diagnostics) {

  rows <- character()

  if (!is.null(diagnostics$logit_fit)) {
    lf <- diagnostics$logit_fit
    rows <- c(rows,
      '<tr class="md-tr-section"><td colspan="2">Aggregate Logit Model</td></tr>',
      sprintf('<tr><td class="md-td md-label-col">Log-Likelihood</td><td class="md-td md-num">%s</td></tr>', fmt_num(lf$log_likelihood, 2)),
      sprintf('<tr><td class="md-td md-label-col">AIC</td><td class="md-td md-num">%s</td></tr>', fmt_num(lf$aic, 1)),
      sprintf('<tr><td class="md-td md-label-col">BIC</td><td class="md-td md-num">%s</td></tr>', fmt_num(lf$bic, 1)),
      sprintf('<tr><td class="md-td md-label-col">McFadden Pseudo R&sup2;</td><td class="md-td md-num">%s</td></tr>', fmt_num(lf$pseudo_r2, 4))
    )
  }

  if (!is.null(diagnostics$hb_diagnostics)) {
    hd <- diagnostics$hb_diagnostics
    rhat_badge <- if (!is.null(hd$max_rhat) && !is.na(hd$max_rhat)) {
      if (hd$max_rhat <= 1.05) '<span class="md-badge-good">Good</span>' else '<span class="md-badge-warn">Check</span>'
    } else ""

    rows <- c(rows,
      '<tr class="md-tr-section"><td colspan="2">Hierarchical Bayes Model</td></tr>',
      sprintf('<tr><td class="md-td md-label-col">Divergent Transitions</td><td class="md-td md-num">%s</td></tr>', fmt_num(hd$divergences, 0)),
      sprintf('<tr><td class="md-td md-label-col">Max R-hat</td><td class="md-td md-num">%s %s</td></tr>', fmt_num(hd$max_rhat, 4), rhat_badge),
      sprintf('<tr><td class="md-td md-label-col">Min ESS (Bulk)</td><td class="md-td md-num">%s</td></tr>', fmt_num(hd$min_ess, 0)),
      sprintf('<tr><td class="md-td md-label-col">Quality Score</td><td class="md-td md-num">%s / 100</td></tr>', fmt_num(hd$quality_score, 0))
    )
  }

  rows <- c(rows,
    '<tr class="md-tr-section"><td colspan="2">Study Design</td></tr>',
    sprintf('<tr><td class="md-td md-label-col">Respondents</td><td class="md-td md-num">%s</td></tr>', fmt_num(diagnostics$n_total, 0)),
    sprintf('<tr><td class="md-td md-label-col">Items Evaluated</td><td class="md-td md-num">%s</td></tr>', fmt_num(diagnostics$n_items, 0))
  )

  sprintf('<table class="md-table md-table-compact"><thead><tr><th class="md-th md-label-col">Metric</th><th class="md-th md-num">Value</th></tr></thead><tbody>%s</tbody></table>',
          paste(rows, collapse = "\n"))
}


# ==============================================================================
# SEGMENT COMPARISON TABLE
# ==============================================================================

#' Build segment comparison table
#'
#' @param segment_data Segment results from compute_segment_scores
#'
#' @return HTML string
#' @keywords internal
build_segment_table <- function(segment_data) {

  if (is.null(segment_data) || length(segment_data) == 0) {
    return('<p class="md-empty">No segment data available.</p>')
  }

  tables_html <- character()

  for (seg_name in names(segment_data)) {
    seg <- segment_data[[seg_name]]
    if (is.null(seg) || !is.data.frame(seg) || nrow(seg) == 0) next

    # Determine segment level columns (numeric non-standard columns only)
    standard_cols <- c("Item_ID", "Item_Label", "Include")
    level_cols <- setdiff(names(seg), standard_cols)
    level_cols <- level_cols[!grepl("^(Best|Worst|BW|Net|Count)", level_cols)]
    level_cols <- level_cols[sapply(seg[level_cols], is.numeric)]

    if (length(level_cols) == 0) next

    # Build header
    header_cells <- '<th class="md-th md-label-col">Item</th>'
    for (lc in level_cols) {
      header_cells <- paste0(header_cells,
        sprintf('<th class="md-th md-num">%s</th>', htmlEscape(lc)))
    }

    # Build rows using BW_Score columns if present, otherwise the level columns
    bw_cols <- grep("^BW_Score_", names(seg), value = TRUE)
    use_cols <- if (length(bw_cols) > 0) bw_cols else level_cols

    rows <- vapply(seq_len(nrow(seg)), function(i) {
      cells <- sprintf('<td class="md-td md-label-col">%s</td>',
                       htmlEscape(seg$Item_Label[i] %||% seg$Item_ID[i]))
      for (uc in use_cols) {
        val <- seg[[uc]][i]
        cells <- paste0(cells, sprintf('<td class="md-td md-num">%s</td>', fmt_num(val, 2)))
      }
      sprintf('<tr>%s</tr>', cells)
    }, character(1))

    table_html <- sprintf(
      '<h3>%s</h3><table class="md-table md-table-compact"><thead><tr>%s</tr></thead><tbody>%s</tbody></table>',
      htmlEscape(seg_name), header_cells, paste(rows, collapse = "\n")
    )

    tables_html <- c(tables_html, table_html)
  }

  paste(tables_html, collapse = "\n")
}


# ==============================================================================
# HEAD-TO-HEAD HEATMAP TABLE
# ==============================================================================

#' Build head-to-head comparison heatmap table
#'
#' @param h2h_data H2H data from compute_head_to_head (matrix or data.frame)
#' @param label_map Named character vector mapping Item_ID to Item_Label
#'
#' @return HTML string
#' @keywords internal
build_h2h_table <- function(h2h_data, label_map = NULL) {

  if (is.null(h2h_data)) {
    return('<p class="md-empty">No head-to-head data available.</p>')
  }

  # h2h_data can be a named matrix or a data frame
  # Expected: square matrix where [i,j] = P(item_i preferred over item_j)
  if (is.data.frame(h2h_data)) {
    # Check for Win_Rate column (long format from compute_head_to_head)
    if ("Win_Rate" %in% names(h2h_data) && "Item_A" %in% names(h2h_data)) {
      # Convert long format to matrix
      items <- unique(c(h2h_data$Item_A, h2h_data$Item_B))
      n <- length(items)
      mat <- matrix(50, nrow = n, ncol = n, dimnames = list(items, items))
      for (i in seq_len(nrow(h2h_data))) {
        a <- h2h_data$Item_A[i]
        b <- h2h_data$Item_B[i]
        wr <- h2h_data$Win_Rate[i]
        if (a %in% items && b %in% items) {
          mat[a, b] <- round(wr * 100, 1)
          mat[b, a] <- round((1 - wr) * 100, 1)
        }
      }
      diag(mat) <- NA
      h2h_data <- mat
    } else {
      h2h_data <- as.matrix(h2h_data)
    }
  }

  if (!is.matrix(h2h_data) || nrow(h2h_data) < 2) {
    return('<p class="md-empty">Insufficient data for head-to-head comparison.</p>')
  }

  items <- rownames(h2h_data)
  if (is.null(items)) items <- paste0("Item_", seq_len(nrow(h2h_data)))
  n <- length(items)

  # Map to labels
  get_label <- function(id) {
    lbl <- if (!is.null(label_map) && id %in% names(label_map)) label_map[[id]] else id
    if (nchar(lbl) > 20) lbl <- paste0(substr(lbl, 1, 17), "...")
    htmlEscape(lbl)
  }

  # Header row
  header_cells <- '<th class="md-th md-label-col" style="min-width:120px;">vs</th>'
  for (j in seq_len(n)) {
    header_cells <- paste0(header_cells, sprintf(
      '<th class="md-th md-h2h-cell" style="writing-mode:vertical-lr;transform:rotate(180deg);max-width:40px;font-size:10px;">%s</th>',
      get_label(items[j])))
  }

  # Data rows
  rows <- vapply(seq_len(n), function(i) {
    cells <- sprintf('<td class="md-td md-label-col" style="font-weight:500;font-size:12px;">%s</td>', get_label(items[i]))
    for (j in seq_len(n)) {
      val <- h2h_data[i, j]
      if (i == j || is.na(val)) {
        cells <- paste0(cells, '<td class="md-td md-h2h-cell md-h2h-self">&mdash;</td>')
      } else {
        css_class <- if (val > 55) "md-h2h-win" else if (val < 45) "md-h2h-lose" else "md-h2h-neutral"
        cells <- paste0(cells, sprintf(
          '<td class="md-td md-h2h-cell %s">%.0f%%</td>', css_class, val))
      }
    }
    sprintf('<tr>%s</tr>', cells)
  }, character(1))

  sprintf(
    '<div style="overflow-x:auto;"><table class="md-table md-table-compact" style="table-layout:fixed;"><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>',
    header_cells, paste(rows, collapse = "\n"))
}
