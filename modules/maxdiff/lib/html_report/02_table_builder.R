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
build_preference_scores_table <- function(scores, anchor_data = NULL, segment_data = NULL, segment_config = NULL) {

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

  main_table <- sprintf('<table class="md-table">%s<tbody>%s</tbody></table>',
          header, paste(rows, collapse = "\n"))

  # Wrap in segment-filterable container if segment data exists
  if (!is.null(segment_data) && length(segment_data) > 0) {
    seg_tables <- build_segment_variant_tables(segment_data, "preference", segment_config)
    return(sprintf(
      '<div class="md-segment-tables">
        <div data-segment="all">%s</div>
        %s
      </div>', main_table, seg_tables))
  }

  main_table
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
build_count_scores_table <- function(count_data, discrimination = NULL, segment_data = NULL, segment_config = NULL) {

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

  main_table <- sprintf('<table class="md-table">%s<tbody>%s</tbody></table>',
          header, paste(rows, collapse = "\n"))

  if (!is.null(segment_data) && is.data.frame(segment_data) && nrow(segment_data) > 0) {
    seg_tables <- build_segment_variant_tables(segment_data, "counts", segment_config)
    return(sprintf(
      '<div class="md-segment-tables">
        <div data-segment="all">%s</div>
        %s
      </div>', main_table, seg_tables))
  }

  main_table
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
      '<th class="md-th md-h2h-cell" style="writing-mode:vertical-rl;max-width:40px;font-size:10px;">%s</th>',
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


# ==============================================================================
# SEGMENT VARIANT TABLE BUILDER (hidden per-segment tables)
# ==============================================================================

#' Build hidden per-segment table variants for segment filtering
#'
#' Creates hidden <div> elements for each segment level, each containing
#' a simple table of scores. Used by JS segment dropdown to show/hide.
#'
#' @param segment_data Long-format data frame with Segment_ID, Item_Label, BW_Score columns
#' @param table_type Character. "preference" or "counts"
#' @param segment_config Data frame from config$segment_settings (with Variable_Name, Segment_ID)
#'
#' @return HTML string of hidden segment table divs
#' @keywords internal
build_segment_variant_tables <- function(segment_data, table_type = "preference", segment_config = NULL) {

  if (is.null(segment_data) || !is.data.frame(segment_data) || nrow(segment_data) == 0) return("")
  if (!"Segment_ID" %in% names(segment_data)) return("")

  # Filter to in-segment rows only (Segment_Value == TRUE)
  if ("Segment_Value" %in% names(segment_data)) {
    segment_data <- segment_data[segment_data$Segment_Value == TRUE, , drop = FALSE]
    if (nrow(segment_data) == 0) return("")
  }

  # Check if enriched data is available (has Pref_Share, Rescaled, Rank)
  has_enriched <- all(c("Pref_Share", "Rescaled", "Rank") %in% names(segment_data))

  # Build lookup from Segment_ID -> Variable_Name
  var_lookup <- list()
  if (!is.null(segment_config) && is.data.frame(segment_config) &&
      "Variable_Name" %in% names(segment_config) && "Segment_ID" %in% names(segment_config)) {
    for (i in seq_len(nrow(segment_config))) {
      var_lookup[[segment_config$Segment_ID[i]]] <- segment_config$Variable_Name[i]
    }
  }

  all_divs <- character()

  for (seg_id in unique(segment_data$Segment_ID)) {
    seg_rows <- segment_data[segment_data$Segment_ID == seg_id, , drop = FALSE]
    if (nrow(seg_rows) == 0) next

    seg_label <- if ("Segment_Label" %in% names(seg_rows)) seg_rows$Segment_Label[1] else seg_id
    seg_n <- if ("Segment_N" %in% names(seg_rows)) seg_rows$Segment_N[1] else NA
    n_text <- if (!is.na(seg_n)) sprintf(" (n=%s)", format(seg_n, big.mark = ",")) else ""

    # Key must match dropdown option value: Variable_Name:Segment_ID
    var_name <- var_lookup[[seg_id]] %||% seg_id
    seg_key <- paste0(var_name, ":", seg_id)

    if (has_enriched && table_type == "counts") {
      # Counts table: match "all" table headers exactly (Item | Best % | Worst % | BW Score)
      seg_rows <- seg_rows[order(-seg_rows$BW_Score, na.last = TRUE), , drop = FALSE]

      has_best <- "Best_Pct" %in% names(seg_rows) && any(!is.na(seg_rows$Best_Pct))
      has_worst <- "Worst_Pct" %in% names(seg_rows) && any(!is.na(seg_rows$Worst_Pct))

      cols <- c('<th class="md-th md-label-col">Item</th>',
                '<th class="md-th md-num">Best %</th>',
                '<th class="md-th md-num">Worst %</th>',
                '<th class="md-th md-num">BW Score</th>')
      header <- sprintf('<thead><tr>%s</tr></thead>', paste(cols, collapse = "\n"))

      rows <- vapply(seq_len(nrow(seg_rows)), function(i) {
        s <- seg_rows[i, ]
        label <- htmlEscape(s$Item_Label)
        cells <- sprintf('<td class="md-td md-label-col">%s</td>', label)

        best_val <- if (has_best && !is.na(s$Best_Pct)) {
          sprintf('<span class="md-positive">%s%%</span>', fmt_num(s$Best_Pct, 1))
        } else "&mdash;"
        cells <- paste0(cells, sprintf('<td class="md-td md-num">%s</td>', best_val))

        worst_val <- if (has_worst && !is.na(s$Worst_Pct)) {
          sprintf('<span class="md-negative">%s%%</span>', fmt_num(s$Worst_Pct, 1))
        } else "&mdash;"
        cells <- paste0(cells, sprintf('<td class="md-td md-num">%s</td>', worst_val))

        bw <- if (!is.na(s$BW_Score)) {
          bw_class <- if (s$BW_Score > 0) "md-positive" else if (s$BW_Score < 0) "md-negative" else ""
          sprintf('<strong class="%s">%s</strong>', bw_class, fmt_num(s$BW_Score, 3))
        } else {
          "&mdash;"
        }
        cells <- paste0(cells, sprintf('<td class="md-td md-num">%s</td>', bw))
        sprintf('<tr>%s</tr>', cells)
      }, character(1))

      table_html <- sprintf(
        '<table class="md-table">%s<tbody>%s</tbody></table>',
        header, paste(rows, collapse = "\n"))

    } else if (has_enriched) {
      # Preference table: rich format with Rank, Score, Pref Share, Must-Have
      seg_rows <- seg_rows[order(seg_rows$Rank), , drop = FALSE]
      max_score <- max(seg_rows$Rescaled, na.rm = TRUE)
      has_seg_anchor <- "Anchor_Rate" %in% names(seg_rows) && any(!is.na(seg_rows$Anchor_Rate))

      # Header
      cols <- c('<th class="md-th md-label-col">Item</th>',
                '<th class="md-th md-num">Rank</th>',
                '<th class="md-th md-num">Score (0-100)</th>',
                '<th class="md-th md-num">Pref Share</th>')
      if (has_seg_anchor) {
        cols <- c(cols, '<th class="md-th md-num">Must-Have %</th>')
      }
      if ("BW_Score" %in% names(seg_rows) && any(!is.na(seg_rows$BW_Score))) {
        cols <- c(cols, '<th class="md-th md-num">BW Score</th>')
      }
      header <- sprintf('<thead><tr>%s</tr></thead>', paste(cols, collapse = "\n"))

      rows <- vapply(seq_len(nrow(seg_rows)), function(i) {
        s <- seg_rows[i, ]
        bar_width <- if (max_score > 0) round(s$Rescaled / max_score * 100) else 0
        label <- htmlEscape(s$Item_Label)

        cells <- sprintf(
          '<td class="md-td md-label-col"><div class="md-bar-cell"><div class="md-bar-bg" style="width:%d%%"></div><span class="md-bar-label">%s</span></div></td>',
          bar_width, label)
        cells <- paste0(cells, sprintf('<td class="md-td md-num">%d</td>', s$Rank))
        cells <- paste0(cells, sprintf('<td class="md-td md-num"><strong>%s</strong></td>', fmt_num(s$Rescaled, 1)))
        cells <- paste0(cells, sprintf('<td class="md-td md-num">%s%%</td>', fmt_num(s$Pref_Share, 1)))
        if (has_seg_anchor) {
          anchor_rate <- if (!is.null(s$Anchor_Rate) && !is.na(s$Anchor_Rate)) s$Anchor_Rate else NA
          if (!is.na(anchor_rate)) {
            badge_class <- if (isTRUE(s$Is_Must_Have)) "md-badge-good" else ""
            cells <- paste0(cells, sprintf('<td class="md-td md-num"><span class="%s">%s%%</span></td>',
                                            badge_class, fmt_num(anchor_rate * 100, 0)))
          } else {
            cells <- paste0(cells, '<td class="md-td md-num">&mdash;</td>')
          }
        }
        if ("BW_Score" %in% names(seg_rows) && any(!is.na(seg_rows$BW_Score))) {
          bw <- if (!is.na(s$BW_Score)) {
            bw_class <- if (s$BW_Score > 0) "md-positive" else if (s$BW_Score < 0) "md-negative" else ""
            sprintf('<span class="%s">%s</span>', bw_class, fmt_num(s$BW_Score, 3))
          } else {
            "&mdash;"
          }
          cells <- paste0(cells, sprintf('<td class="md-td md-num">%s</td>', bw))
        }
        sprintf('<tr>%s</tr>', cells)
      }, character(1))

      table_html <- sprintf(
        '<table class="md-table">%s<tbody>%s</tbody></table>',
        header, paste(rows, collapse = "\n"))

    } else {
      # Basic table with BW_Score only (fallback)
      if (!"BW_Score" %in% names(seg_rows)) next
      item_labels <- seg_rows$Item_Label %||% seg_rows$Item_ID
      vals <- seg_rows$BW_Score
      ord <- order(-vals)

      rows <- vapply(ord, function(i) {
        label <- htmlEscape(item_labels[i])
        val <- vals[i]
        bw_class <- if (val > 0) "md-positive" else if (val < 0) "md-negative" else ""
        sprintf('<tr><td class="md-td md-label-col">%s</td><td class="md-td md-num %s"><strong>%s</strong></td></tr>',
                label, bw_class, fmt_num(val, 3))
      }, character(1))

      table_html <- sprintf(
        '<table class="md-table"><thead><tr><th class="md-th md-label-col">Item</th><th class="md-th md-num">BW Score (%s)</th></tr></thead><tbody>%s</tbody></table>',
        htmlEscape(seg_label), paste(rows, collapse = "\n"))
    }

    all_divs <- c(all_divs, sprintf(
      '<div data-segment="%s" style="display:none;">%s</div>',
      htmlEscape(seg_key), table_html))
  }

  paste(all_divs, collapse = "\n")
}


# ==============================================================================
# H2H SEGMENT TABLE BUILDER
# ==============================================================================

#' Build H2H table wrapped in segment-filterable container
#'
#' Wraps the main H2H table in a segment-filterable div and adds per-segment
#' H2H tables if segment H2H data is available.
#'
#' @param main_h2h_html Character. The "all respondents" H2H table HTML
#' @param segment_h2h_list Named list. Per-segment H2H data frames (from compute_segment_h2h)
#' @param label_map Named character vector. Item_ID -> Item_Label
#'
#' @return HTML string with segment-filterable wrapper
#' @keywords internal
build_h2h_with_segments <- function(main_h2h_html, segment_h2h_list, label_map = NULL) {

  if (is.null(segment_h2h_list) || length(segment_h2h_list) == 0) {
    return(main_h2h_html)
  }

  seg_divs <- character()

  for (seg_key in names(segment_h2h_list)) {
    h2h_data <- segment_h2h_list[[seg_key]]
    seg_table <- build_h2h_table(h2h_data, label_map)
    seg_divs <- c(seg_divs, sprintf(
      '<div data-segment="%s" style="display:none;">%s</div>',
      htmlEscape(seg_key), seg_table))
  }

  sprintf(
    '<div class="md-segment-tables">
      <div data-segment="all">%s</div>
      %s
    </div>',
    main_h2h_html, paste(seg_divs, collapse = "\n"))
}


# ==============================================================================
# SEGMENT-ONLY CONTAINER (for sub-panels that need segment data added)
# ==============================================================================

#' Build a segment-only container with empty "all" div
#'
#' Creates a .md-segment-tables container where the "all" div is empty
#' (nothing shows by default) and per-segment divs appear when a segment
#' is selected. Used to add segment tables to sub-panels that otherwise
#' only have charts.
#'
#' @param segment_data Data frame. Enriched segment scores
#' @param table_type Character. "preference" or "counts"
#' @param segment_config Data frame. Config segment settings
#'
#' @return HTML string, or "" if no segment data
#' @keywords internal
build_segment_only_container <- function(segment_data, table_type = "preference", segment_config = NULL) {

  seg_tables <- build_segment_variant_tables(segment_data, table_type, segment_config)
  if (!nzchar(seg_tables)) return("")

  sprintf(
    '<div class="md-segment-tables"><div data-segment="all" style="display:block;"></div>%s</div>',
    seg_tables)
}


# ==============================================================================
# H2H SEGMENT TABLE WITH N= LABELS
# ==============================================================================

#' Build H2H table wrapped in segment container with n= labels
#'
#' @param main_h2h_html Character. The "all respondents" H2H table HTML
#' @param segment_h2h_list Named list. Per-segment H2H data frames
#' @param label_map Named character vector. Item_ID -> Item_Label
#' @param segment_n Named list. seg_key -> n (sample size)
#'
#' @return HTML string
#' @keywords internal
build_h2h_with_segments_and_n <- function(main_h2h_html, segment_h2h_list, label_map = NULL, segment_n = NULL) {

  if (is.null(segment_h2h_list) || length(segment_h2h_list) == 0) {
    return(main_h2h_html)
  }

  seg_divs <- character()

  for (seg_key in names(segment_h2h_list)) {
    h2h_data <- segment_h2h_list[[seg_key]]
    seg_table <- build_h2h_table(h2h_data, label_map)

    # Add n= label if available
    n_label <- ""
    if (!is.null(segment_n) && seg_key %in% names(segment_n)) {
      n_val <- segment_n[[seg_key]]
      n_label <- sprintf(
        '<div class="md-segment-n-label" style="text-align:right;font-size:13px;color:#64748b;margin-bottom:8px;font-weight:500;">n = %s</div>',
        format(as.integer(n_val), big.mark = ","))
    }

    seg_divs <- c(seg_divs, sprintf(
      '<div data-segment="%s" style="display:none;">%s%s</div>',
      htmlEscape(seg_key), n_label, seg_table))
  }

  sprintf(
    '<div class="md-segment-tables">
      <div data-segment="all">%s</div>
      %s
    </div>',
    main_h2h_html, paste(seg_divs, collapse = "\n"))
}
