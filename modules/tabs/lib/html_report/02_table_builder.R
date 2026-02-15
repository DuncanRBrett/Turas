# ==============================================================================
# HTML REPORT - TABLE BUILDER (V10.3.3)
# ==============================================================================
# Builds plain HTML <table> elements for each crosstab question.
# No external JS dependencies — uses data attributes for heatmap,
# CSS classes for sig badges, banner group toggling, low-base dimming.
# ==============================================================================


#' Build an HTML Table for a Single Question
#'
#' Creates a plain HTML table string with data attributes for
#' heatmap, significance badges, and low-base warnings.
#'
#' @param question_data List from transform_single_question()
#' @param banner_groups Named list of banner groups
#' @param config_obj Configuration object
#' @param table_id Character, unique ID for this table
#' @return htmltools::HTML object containing a <table> element
#' @export
build_question_table <- function(question_data, banner_groups, config_obj,
                                  table_id = NULL) {

  table_data <- question_data$table_data
  stats <- question_data$stats
  min_base <- config_obj$significance_min_base %||% 30
  brand_colour <- config_obj$brand_colour %||% "#0d8a8a"
  has_sig <- stats$has_sig
  has_freq <- stats$has_freq && isTRUE(config_obj$embed_frequencies)

  # Parse brand colour to RGB for heatmap
  r <- strtoi(substr(brand_colour, 2, 3), 16L)
  g <- strtoi(substr(brand_colour, 4, 5), 16L)
  b <- strtoi(substr(brand_colour, 6, 7), 16L)

  # Get visible internal keys (banner columns — exclude dot-prefixed metadata cols)
  all_internal_keys <- grep("^\\.", names(table_data), value = TRUE, invert = TRUE)

  # Map each key to its banner group code, display label, and letter
  key_to_group <- list()
  key_to_display <- list()
  key_to_letter <- list()

  # First key is always TOTAL::Total
  if (length(all_internal_keys) > 0) {
    key_to_group[[all_internal_keys[1]]] <- "total"
    key_to_display[[all_internal_keys[1]]] <- "Total"
    key_to_letter[[all_internal_keys[1]]] <- ""
  }

  for (grp_name in names(banner_groups)) {
    grp <- banner_groups[[grp_name]]
    for (i in seq_along(grp$internal_keys)) {
      k <- grp$internal_keys[i]
      key_to_group[[k]] <- grp$banner_code
      key_to_display[[k]] <- grp$display_labels[i]
      key_to_letter[[k]] <- grp$letters[i]
    }
  }

  # Determine which rows are percentage-type for heatmap scaling
  is_pct_stat <- !is.null(table_data$.stat_type) &
    table_data$.row_type %in% c("category", "net")
  pct_rows <- which(is_pct_stat & table_data$.stat_type %in% c("Column %", "Row %"))

  # Calculate max percentage for heatmap scaling (only from true percentage rows)
  max_pct <- 0
  if (length(pct_rows) > 0) {
    for (key in all_internal_keys) {
      vals <- suppressWarnings(as.numeric(table_data[[key]][pct_rows]))
      vals <- vals[!is.na(vals) & vals > 0 & vals < 100]
      if (length(vals) > 0) max_pct <- max(max_pct, max(vals))
    }
  }
  if (max_pct == 0) max_pct <- 100

  # ---- BUILD HEADER ROW ----
  header_cells <- '<th class="ct-th ct-label-col">Response</th>'
  for (key in all_internal_keys) {
    display <- key_to_display[[key]] %||% key
    letter <- key_to_letter[[key]] %||% ""
    grp_code <- key_to_group[[key]] %||% "total"
    css_class <- if (grp_code == "total") "bg-total" else paste0("bg-", grp_code)
    is_total <- (grp_code == "total")

    letter_html <- if (nzchar(letter)) {
      sprintf('<div class="ct-letter">(%s)</div>', htmltools::htmlEscape(letter))
    } else {
      ""
    }

    header_cells <- paste0(header_cells, sprintf(
      '<th class="ct-th ct-data-col %s"%s><div class="ct-header-text">%s</div>%s</th>',
      css_class,
      if (is_total) ' style="color:#d4a843"' else "",
      htmltools::htmlEscape(display),
      letter_html
    ))
  }

  # ---- BUILD DATA ROWS ----
  data_rows <- ""
  for (row_idx in seq_len(nrow(table_data))) {
    row_type <- as.character(table_data$.row_type[row_idx])
    row_label <- as.character(table_data$.row_label[row_idx])
    is_net <- isTRUE(table_data$.is_net[row_idx])
    stat_type <- if (".stat_type" %in% names(table_data)) {
      as.character(table_data$.stat_type[row_idx])
    } else {
      "Column %"
    }
    is_pct_row <- stat_type %in% c("Column %", "Row %")

    # Row CSS class
    row_class <- paste0("ct-row ct-row-", row_type)
    if (is_net) row_class <- paste0(row_class, " ct-row-net")

    # Label cell
    label_html <- htmltools::htmlEscape(row_label)
    cells <- sprintf('<td class="ct-td ct-label-col">%s</td>', label_html)

    # Data cells
    for (key in all_internal_keys) {
      grp_code <- key_to_group[[key]] %||% "total"
      css_class <- if (grp_code == "total") "bg-total" else paste0("bg-", grp_code)

      val <- table_data[[key]][row_idx]
      val_num <- suppressWarnings(as.numeric(val))

      # Get base for this column (for low-base check)
      base_col <- paste0(".base_", key)
      base_n <- if (base_col %in% names(table_data)) {
        suppressWarnings(as.numeric(table_data[[base_col]][row_idx]))
      } else {
        NA
      }

      # Build cell content and inline style
      cell_content <- ""
      cell_style <- ""
      cell_extra_class <- ""

      if (is.na(val) || is.null(val)) {
        # Missing value
        cell_content <- '<span class="ct-na">&mdash;</span>'

      } else if (row_type == "base") {
        # Base row
        base_val <- if (!is.na(val_num)) format(round(val_num), big.mark = ",") else val
        if (!is.na(val_num) && val_num < min_base) {
          cell_content <- sprintf(
            '<span class="ct-low-base">%s \u26A0</span>', base_val)
        } else {
          cell_content <- sprintf('<span class="ct-base-n">%s</span>', base_val)
        }

      } else if (row_type == "mean") {
        # Mean/summary row
        cell_content <- sprintf('<span class="ct-mean-val">%s</span>', val)

      } else {
        # Category or NET row — primary value
        display_val <- val
        suffix <- ""

        # Only add % suffix if this row is showing a percentage stat
        if (is_pct_row && !is.na(val_num)) {
          suffix <- "%"
          display_val <- round(val_num)
        } else if (!is.na(val_num)) {
          # Frequency — show as formatted integer
          display_val <- format(round(val_num), big.mark = ",")
        }

        val_class <- if (is_net) "ct-val ct-val-net" else "ct-val"
        cell_content <- sprintf('<span class="%s">%s%s</span>',
                                val_class, display_val, suffix)

        # Significance badge
        if (has_sig) {
          sig_col <- paste0(".sig_", key)
          if (sig_col %in% names(table_data)) {
            sig_val <- as.character(table_data[[sig_col]][row_idx])
            if (!is.na(sig_val) && nzchar(sig_val) && sig_val != "-") {
              cell_content <- paste0(cell_content, sprintf(
                '<span class="ct-sig">\u25B2%s</span>',
                htmltools::htmlEscape(sig_val)))
            }
          }
        }

        # Frequency (hidden by default, shown via CSS class toggle)
        if (has_freq && is_pct_row) {
          freq_col <- paste0(".freq_", key)
          if (freq_col %in% names(table_data)) {
            freq_val <- suppressWarnings(as.numeric(table_data[[freq_col]][row_idx]))
            if (!is.na(freq_val)) {
              cell_content <- paste0(cell_content, sprintf(
                '<div class="ct-freq">n=%s</div>',
                format(round(freq_val), big.mark = ",")))
            }
          }
        }

        # Heatmap data attribute — only for percentage rows
        if (is_pct_row && !is_net && !is.na(val_num) &&
            val_num > 0 && val_num <= 100) {
          intensity <- min(val_num / max_pct, 1)
          hr <- round(r + (248 - r) * (1 - intensity))
          hg <- round(g + (248 - g) * (1 - intensity))
          hb <- round(b + (248 - b) * (1 - intensity))
          alpha <- round(0.08 + intensity * 0.35, 3)
          cell_extra_class <- " ct-heatmap-cell"
          cell_style <- sprintf(
            ' data-heatmap="rgba(%d,%d,%d,%s)"', hr, hg, hb, alpha)
        }

        # Low base dimming
        if (!is.na(base_n) && base_n < min_base) {
          cell_extra_class <- paste0(cell_extra_class, " ct-low-base-dim")
        }
      }

      cells <- paste0(cells, sprintf(
        '<td class="ct-td ct-data-col %s%s"%s>%s</td>',
        css_class, cell_extra_class, cell_style, cell_content))
    }

    data_rows <- paste0(data_rows, sprintf(
      '<tr class="%s">%s</tr>\n', row_class, cells))
  }

  # ---- ASSEMBLE TABLE ----
  table_html <- sprintf(
    '<table class="ct-table" id="%s">\n<thead><tr>%s</tr></thead>\n<tbody>\n%s</tbody>\n</table>',
    table_id %||% "",
    header_cells,
    data_rows
  )

  htmltools::HTML(table_html)
}


# Null-coalescing operator (if not already defined)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
