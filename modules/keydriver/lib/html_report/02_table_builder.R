# ==============================================================================
# KEYDRIVER HTML REPORT - TABLE BUILDER
# ==============================================================================
# Builds HTML tables from transformed keydriver data using htmltools.
# All IDs and classes use kd- prefix for Report Hub namespace isolation.
#
# Tables:
#   1. Importance table (ranked drivers with inline bars)
#   2. Method comparison table (cross-method rank agreement)
#   3. Model summary table (key-value pairs)
#   4. Correlation matrix table (color-coded cells)
#   5. VIF diagnostics table (multicollinearity concern)
#   6. Effect size table (badge-style labels)
#   7. Quadrant action table (priority / action mapping)
#   8. Bootstrap CI table (confidence intervals)
#   9. Segment comparison table (per-segment ranks and deltas)
# ==============================================================================


# ==============================================================================
# 1. IMPORTANCE TABLE
# ==============================================================================

#' Build Key Driver Importance Table
#'
#' Creates a ranked table of driver importance with inline bar visualisations.
#' Top 3 rows are highlighted with a subtle accent background.
#'
#' @param importance List or data.frame of importance entries. Each entry/row
#'   should contain: rank, label (or driver), importance_pct, top_method.
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_importance_table <- function(importance) {

  if (is.null(importance) || length(importance) == 0) return(NULL)

  # Normalise: accept data.frame or list-of-lists
  rows_data <- .kd_normalise_to_list(importance)
  if (length(rows_data) == 0) return(NULL)

  header <- htmltools::tags$tr(
    htmltools::tags$th("Rank",       class = "kd-th kd-th-rank"),
    htmltools::tags$th("Driver",     class = "kd-th kd-th-label"),
    htmltools::tags$th("Importance", class = "kd-th kd-th-bar"),
    htmltools::tags$th("%",          class = "kd-th kd-th-num")
  )

  rows <- lapply(rows_data, function(d) {
    rank_val <- d$rank %||% NA
    label    <- d$label %||% d$driver %||% d$Driver %||% ""
    pct      <- as.numeric(d$importance_pct %||% d$Importance_Pct %||% 0)

    bar_width  <- min(100, max(0, pct))
    bar_colour <- if (pct >= 20) "#2563EB"
                  else if (pct >= 10) "#3B82F6"
                  else if (pct >= 5)  "#93C5FD"
                  else "#DBEAFE"

    # Highlight top 3
    row_class <- if (!is.na(rank_val) && is.numeric(rank_val) && rank_val <= 3) {
      "kd-tr kd-tr-highlight"
    } else {
      "kd-tr"
    }

    htmltools::tags$tr(
      class = row_class,
      htmltools::tags$td(rank_val, class = "kd-td kd-td-rank"),
      htmltools::tags$td(label,    class = "kd-td kd-td-label"),
      htmltools::tags$td(
        class = "kd-td kd-td-bar",
        htmltools::tags$div(
          class = "kd-bar-container",
          htmltools::tags$div(
            class = "kd-bar-fill",
            style = sprintf("width:%.1f%%;background:%s;", bar_width, bar_colour)
          )
        )
      ),
      htmltools::tags$td(sprintf("%.0f%%", pct), class = "kd-td kd-td-num")
    )
  })

  htmltools::tags$table(
    class = "kd-table kd-importance-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 2. METHOD COMPARISON TABLE
# ==============================================================================

#' Build Method Comparison Table
#'
#' Shows per-method ranks for each driver, the mean rank, and an agreement
#' indicator color-coded High (green), Medium (amber), Low (red).
#'
#' @param method_comparison List or data.frame. Each entry/row: driver/label,
#'   per-method rank columns, mean_rank, agreement.
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_method_comparison_table <- function(method_comparison) {

  if (is.null(method_comparison) || length(method_comparison) == 0) return(NULL)

  # Accept data.frame directly
  if (is.data.frame(method_comparison)) {
    df <- method_comparison
  } else {
    df <- .kd_list_to_df(method_comparison)
    if (is.null(df) || nrow(df) == 0) return(NULL)
  }

  # Identify rank columns (everything except Driver, Label, Mean_Rank, Agreement)
  meta_cols <- c("Driver", "Label", "driver", "label",
                 "Mean_Rank", "mean_rank", "Agreement", "agreement")
  rank_cols <- setdiff(names(df), meta_cols)

  # Build header
  driver_th  <- htmltools::tags$th("Driver", class = "kd-th kd-th-label")
  rank_ths   <- lapply(rank_cols, function(col) {
    htmltools::tags$th(col, class = "kd-th kd-th-num")
  })
  mean_th    <- htmltools::tags$th("Mean Rank",  class = "kd-th kd-th-num")
  agree_th   <- htmltools::tags$th("Agreement",  class = "kd-th kd-th-label")

  header <- htmltools::tags$tr(c(list(driver_th), rank_ths,
                                  list(mean_th, agree_th)))

  rows <- lapply(seq_len(nrow(df)), function(i) {
    row <- df[i, , drop = FALSE]
    driver_label <- row$Label %||% row$label %||% row$Driver %||% row$driver %||% ""
    mean_rank    <- as.numeric(row$Mean_Rank %||% row$mean_rank %||% NA)
    agreement    <- as.character(row$Agreement %||% row$agreement %||% "")

    # Agreement badge colour
    agree_class <- switch(tolower(agreement),
      "high"   = "kd-agree-high",
      "medium" = "kd-agree-medium",
      "low"    = "kd-agree-low",
      "kd-agree-none"
    )

    rank_tds <- lapply(rank_cols, function(col) {
      val <- row[[col]]
      htmltools::tags$td(
        if (is.na(val)) "-" else as.character(val),
        class = "kd-td kd-td-num"
      )
    })

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(driver_label, class = "kd-td kd-td-label"),
      rank_tds,
      htmltools::tags$td(
        if (is.na(mean_rank)) "-" else sprintf("%.1f", mean_rank),
        class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(
        class = "kd-td",
        htmltools::tags$span(class = paste("kd-badge", agree_class), agreement)
      )
    )
  })

  htmltools::tags$table(
    class = "kd-table kd-method-comparison-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 3. MODEL SUMMARY TABLE
# ==============================================================================

#' Build Model Summary Table (Key-Value Pairs)
#'
#' Renders model diagnostics as a two-column Metric | Value layout.
#' Expected fields: r_squared, adj_r_squared, f_statistic, p_value, rmse,
#' n, n_drivers.
#'
#' @param model_info List of model summary key-value pairs
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_model_summary_table <- function(model_info) {

  if (is.null(model_info) || length(model_info) == 0) return(NULL)

  # Define display mapping: label -> field name(s) to look up
  metric_map <- list(
    list(label = "R\u00b2",           keys = c("r_squared", "R_Squared", "r2")),
    list(label = "Adjusted R\u00b2",  keys = c("adj_r_squared", "Adj_R_Squared", "adj_r2")),
    list(label = "F-statistic",       keys = c("f_statistic", "F_Statistic", "f_stat")),
    list(label = "p-value",           keys = c("p_value", "P_Value", "model_p")),
    list(label = "RMSE",              keys = c("rmse", "RMSE")),
    list(label = "N (observations)",  keys = c("n", "N", "n_obs")),
    list(label = "N (drivers)",       keys = c("n_drivers", "N_Drivers"))
  )

  header <- htmltools::tags$tr(
    htmltools::tags$th("Metric", class = "kd-th kd-th-label"),
    htmltools::tags$th("Value",  class = "kd-th kd-th-num")
  )

  rows <- lapply(metric_map, function(m) {
    # Look up value from model_info
    val <- NULL
    for (k in m$keys) {
      if (!is.null(model_info[[k]])) {
        val <- model_info[[k]]
        break
      }
    }

    # Format the value
    display_val <- if (is.null(val) || (length(val) == 1 && is.na(val))) {
      "-"
    } else if (is.numeric(val)) {
      if (abs(val) < 0.001 && val != 0) {
        sprintf("%.2e", val)
      } else if (val == round(val) && abs(val) > 1) {
        format(as.integer(val), big.mark = ",")
      } else {
        sprintf("%.4f", val)
      }
    } else {
      as.character(val)
    }

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(m$label,    class = "kd-td kd-td-label"),
      htmltools::tags$td(display_val, class = "kd-td kd-td-num")
    )
  })

  htmltools::tags$table(
    class = "kd-table kd-model-summary-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 4. CORRELATION TABLE (Matrix Layout)
# ==============================================================================

#' Build Correlation Matrix Table
#'
#' Renders a correlation matrix with color-coded cells: positive values use
#' a blue gradient, negative values use a red gradient. Stronger correlations
#' produce more saturated colours. Uses tabular-nums for alignment.
#'
#' @param correlations Matrix or data.frame of correlation values.
#'   Row and column names are used as labels.
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_correlation_table <- function(correlations) {

  if (is.null(correlations)) return(NULL)

  # Accept matrix or data.frame

  mat <- as.matrix(correlations)
  if (nrow(mat) == 0 || ncol(mat) == 0) return(NULL)

  var_names <- colnames(mat)
  if (is.null(var_names)) var_names <- paste0("V", seq_len(ncol(mat)))

  # Header row: empty corner cell + variable names
  header_cells <- list(htmltools::tags$th("", class = "kd-th kd-th-corner"))
  for (vn in var_names) {
    header_cells <- c(header_cells, list(
      htmltools::tags$th(vn, class = "kd-th kd-th-corr")
    ))
  }
  header <- htmltools::tags$tr(header_cells)

  # Data rows
  row_names <- rownames(mat)
  if (is.null(row_names)) row_names <- var_names

  rows <- lapply(seq_len(nrow(mat)), function(i) {
    cells <- list(htmltools::tags$td(row_names[i], class = "kd-td kd-td-label"))
    for (j in seq_len(ncol(mat))) {
      val <- mat[i, j]
      if (is.na(val)) {
        cells <- c(cells, list(
          htmltools::tags$td("-", class = "kd-td kd-td-corr")
        ))
      } else {
        bg <- .kd_correlation_colour(val)
        # Use dark text on light backgrounds, light text on saturated backgrounds
        text_col <- if (abs(val) >= 0.6) "#ffffff" else "#1e293b"
        cells <- c(cells, list(
          htmltools::tags$td(
            sprintf("%.2f", val),
            class = "kd-td kd-td-corr",
            style = sprintf(
              "background:%s;color:%s;font-variant-numeric:tabular-nums;text-align:center;",
              bg, text_col
            )
          )
        ))
      }
    }
    htmltools::tags$tr(class = "kd-tr", cells)
  })

  htmltools::tags$table(
    class = "kd-table kd-correlation-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 5. VIF TABLE
# ==============================================================================

#' Build VIF Diagnostics Table
#'
#' Columns: Driver | VIF | Concern. Color-codes concern levels:
#' None (green), Moderate (amber), High (red).
#'
#' @param vif_values List or data.frame with driver, vif, concern fields
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_vif_table <- function(vif_values) {

  if (is.null(vif_values) || length(vif_values) == 0) return(NULL)

  # Accept named numeric vector (driver -> VIF)
  if (is.numeric(vif_values) && !is.null(names(vif_values))) {
    vif_list <- lapply(names(vif_values), function(nm) {
      list(driver = nm, vif = vif_values[[nm]])
    })
  } else if (is.data.frame(vif_values)) {
    vif_list <- lapply(seq_len(nrow(vif_values)), function(i) as.list(vif_values[i, ]))
  } else if (is.list(vif_values)) {
    vif_list <- vif_values
  } else {
    return(NULL)
  }

  if (length(vif_list) == 0) return(NULL)

  header <- htmltools::tags$tr(
    htmltools::tags$th("Driver",  class = "kd-th kd-th-label"),
    htmltools::tags$th("VIF",     class = "kd-th kd-th-num"),
    htmltools::tags$th("Concern", class = "kd-th kd-th-label")
  )

  rows <- lapply(vif_list, function(d) {
    driver_name <- d$driver %||% d$Driver %||% d$label %||% ""
    vif_val     <- as.numeric(d$vif %||% d$VIF %||% NA)

    # Determine concern level
    concern <- d$concern %||% d$Concern
    if (is.null(concern)) {
      concern <- if (is.na(vif_val)) "Unknown"
                 else if (vif_val >= 10) "High"
                 else if (vif_val >= 5)  "Moderate"
                 else "None"
    }

    concern_class <- switch(tolower(concern),
      "high"     = "kd-concern-high",
      "moderate" = "kd-concern-moderate",
      "none"     = "kd-concern-none",
      "kd-concern-none"
    )

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(driver_name, class = "kd-td kd-td-label"),
      htmltools::tags$td(
        if (is.na(vif_val)) "-" else sprintf("%.2f", vif_val),
        class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(
        class = "kd-td",
        htmltools::tags$span(class = paste("kd-badge", concern_class), concern)
      )
    )
  })

  htmltools::tags$table(
    class = "kd-table kd-vif-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 6. EFFECT SIZE TABLE
# ==============================================================================

#' Build Effect Size Table
#'
#' Columns: Driver | Effect Value | Effect Size | Interpretation.
#' Effect Size is rendered as a badge-style label.
#'
#' @param effect_sizes Data.frame or list with Driver, Effect_Value,
#'   Effect_Size, Interpretation columns/fields
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_effect_size_table <- function(effect_sizes) {

  if (is.null(effect_sizes) || length(effect_sizes) == 0) return(NULL)

  if (is.data.frame(effect_sizes)) {
    df <- effect_sizes
  } else {
    df <- .kd_list_to_df(effect_sizes)
    if (is.null(df) || nrow(df) == 0) return(NULL)
  }

  header <- htmltools::tags$tr(
    htmltools::tags$th("Driver",         class = "kd-th kd-th-label"),
    htmltools::tags$th("Effect Value",   class = "kd-th kd-th-num"),
    htmltools::tags$th("Effect Size",    class = "kd-th kd-th-label"),
    htmltools::tags$th("Interpretation", class = "kd-th kd-th-label")
  )

  rows <- lapply(seq_len(nrow(df)), function(i) {
    row <- df[i, , drop = FALSE]
    driver_name <- row$Driver %||% row$driver %||% ""
    effect_val  <- as.numeric(row$Effect_Value %||% row$effect_value %||% NA)
    effect_size <- as.character(row$Effect_Size %||% row$effect_size %||% "")
    interp      <- as.character(row$Interpretation %||% row$interpretation %||% "")

    # Badge class by effect size category
    badge_class <- switch(tolower(effect_size),
      "large"      = "kd-effect-large",
      "medium"     = "kd-effect-medium",
      "small"      = "kd-effect-small",
      "negligible" = "kd-effect-negligible",
      "kd-effect-none"
    )

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(driver_name, class = "kd-td kd-td-label"),
      htmltools::tags$td(
        if (is.na(effect_val)) "-" else sprintf("%.3f", effect_val),
        class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(
        class = "kd-td",
        htmltools::tags$span(class = paste("kd-badge", badge_class), effect_size)
      ),
      htmltools::tags$td(interp, class = "kd-td kd-td-label")
    )
  })

  htmltools::tags$table(
    class = "kd-table kd-effect-size-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 7. QUADRANT ACTION TABLE
# ==============================================================================

#' Build Quadrant Action Table
#'
#' Columns: Priority | Driver | Quadrant | Importance | Performance | Action.
#' Rows are color-coded by quadrant assignment.
#'
#' @param quadrant_data Data.frame or list with driver, quadrant, importance,
#'   performance, action, priority fields
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_quadrant_action_table <- function(quadrant_data) {

  if (is.null(quadrant_data) || length(quadrant_data) == 0) return(NULL)

  if (is.data.frame(quadrant_data)) {
    df <- quadrant_data
  } else {
    df <- .kd_list_to_df(quadrant_data)
    if (is.null(df) || nrow(df) == 0) return(NULL)
  }

  header <- htmltools::tags$tr(
    htmltools::tags$th("Priority",    class = "kd-th kd-th-rank"),
    htmltools::tags$th("Driver",      class = "kd-th kd-th-label"),
    htmltools::tags$th("Quadrant",    class = "kd-th kd-th-label"),
    htmltools::tags$th("Importance",  class = "kd-th kd-th-num"),
    htmltools::tags$th("Performance", class = "kd-th kd-th-num"),
    htmltools::tags$th("Action",      class = "kd-th kd-th-label")
  )

  rows <- lapply(seq_len(nrow(df)), function(i) {
    row <- df[i, , drop = FALSE]

    priority    <- row$priority    %||% row$Priority    %||% i
    driver_name <- row$driver      %||% row$Driver      %||% row$label %||% ""
    quadrant    <- as.character(row$quadrant %||% row$Quadrant %||% "")
    importance  <- as.numeric(row$importance  %||% row$Importance  %||% NA)
    performance <- as.numeric(row$performance %||% row$Performance %||% NA)
    action_full <- as.character(row$action %||% row$Action %||% "")

    # Extract short action keyword (e.g. "IMPROVE" from "IMPROVE: High importance...")
    action_short <- sub(":.*$", "", action_full)
    action_short <- trimws(action_short)
    if (nchar(action_short) == 0) action_short <- quadrant

    # Action badge colour based on keyword
    action_bg    <- switch(toupper(action_short),
      "IMPROVE"  = "#fee2e2", "MAINTAIN" = "#dcfce7",
      "MONITOR"  = "#f1f5f9", "REASSESS" = "#dbeafe",
      "ASSESS"   = "#dbeafe", "#f1f5f9")
    action_color <- switch(toupper(action_short),
      "IMPROVE"  = "#991b1b", "MAINTAIN" = "#166534",
      "MONITOR"  = "#64748b", "REASSESS" = "#1e40af",
      "ASSESS"   = "#1e40af", "#64748b")

    # Quadrant colour class
    quad_class <- .kd_quadrant_class(quadrant)

    action_badge <- htmltools::tags$span(
      style = sprintf(
        "background:%s;color:%s;padding:2px 10px;border-radius:10px;font-size:11px;font-weight:600;text-transform:uppercase;",
        action_bg, action_color
      ),
      action_short
    )

    htmltools::tags$tr(
      class = paste("kd-tr", quad_class),
      htmltools::tags$td(priority,    class = "kd-td kd-td-rank"),
      htmltools::tags$td(driver_name, class = "kd-td kd-td-label"),
      htmltools::tags$td(
        class = "kd-td",
        htmltools::tags$span(class = paste("kd-badge", quad_class), quadrant)
      ),
      htmltools::tags$td(
        if (is.na(importance)) "-" else sprintf("%.0f%%", importance),
        class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(
        if (is.na(performance)) "-" else sprintf("%.2f", performance),
        class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(action_badge, class = "kd-td", style = "text-align:center;")
    )
  })

  htmltools::tags$table(
    class = "kd-table kd-quadrant-action-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 8. BOOTSTRAP CI TABLE
# ==============================================================================

#' Build Bootstrap Confidence Interval Table
#'
#' Columns: Driver | Method | Point Estimate | CI Lower | CI Upper | SE.
#'
#' @param bootstrap_ci Data.frame with columns Driver, Method,
#'   Point_Estimate, CI_Lower, CI_Upper, SE (as returned by
#'   bootstrap_importance_ci)
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_bootstrap_ci_table <- function(bootstrap_ci) {

  if (is.null(bootstrap_ci) || length(bootstrap_ci) == 0) return(NULL)

  if (is.data.frame(bootstrap_ci)) {
    df <- bootstrap_ci
  } else {
    df <- .kd_list_to_df(bootstrap_ci)
    if (is.null(df) || nrow(df) == 0) return(NULL)
  }

  header <- htmltools::tags$tr(
    htmltools::tags$th("Driver",         class = "kd-th kd-th-label"),
    htmltools::tags$th("Method",         class = "kd-th kd-th-label"),
    htmltools::tags$th("Point Estimate", class = "kd-th kd-th-num"),
    htmltools::tags$th("CI Lower",       class = "kd-th kd-th-num"),
    htmltools::tags$th("CI Upper",       class = "kd-th kd-th-num"),
    htmltools::tags$th("SE",             class = "kd-th kd-th-num")
  )

  rows <- lapply(seq_len(nrow(df)), function(i) {
    row <- df[i, , drop = FALSE]

    driver_name <- as.character(row$Driver %||% row$driver %||% "")
    method      <- as.character(row$Method %||% row$method %||% "")
    point_est   <- as.numeric(row$Point_Estimate %||% row$point_estimate %||% NA)
    ci_lower    <- as.numeric(row$CI_Lower %||% row$ci_lower %||% NA)
    ci_upper    <- as.numeric(row$CI_Upper %||% row$ci_upper %||% NA)
    se          <- as.numeric(row$SE %||% row$se %||% NA)

    htmltools::tags$tr(
      class = "kd-tr",
      htmltools::tags$td(driver_name, class = "kd-td kd-td-label"),
      htmltools::tags$td(method,      class = "kd-td kd-td-label"),
      htmltools::tags$td(
        .kd_fmt_num(point_est, 4), class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(
        .kd_fmt_num(ci_lower, 4), class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(
        .kd_fmt_num(ci_upper, 4), class = "kd-td kd-td-num"
      ),
      htmltools::tags$td(
        .kd_fmt_num(se, 4), class = "kd-td kd-td-num"
      )
    )
  })

  htmltools::tags$table(
    class = "kd-table kd-bootstrap-ci-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# 9. SEGMENT COMPARISON TABLE
# ==============================================================================

#' Build Segment Comparison Table
#'
#' Wide table with per-segment ranks and importance percentages. If exactly
#' two segments are present, a delta column is appended showing the difference
#' in importance between segments.
#'
#' @param segment_comparison Data.frame as returned by
#'   build_importance_comparison_matrix(), or a list with
#'   comparison_matrix element
#' @return htmltools tag object (table), or NULL if input is empty
#' @keywords internal
build_kd_segment_comparison_table <- function(segment_comparison) {

  if (is.null(segment_comparison) || length(segment_comparison) == 0) return(NULL)

  # Accept either a data.frame or a list with $comparison_matrix
  if (is.data.frame(segment_comparison)) {
    df <- segment_comparison
  } else if (is.list(segment_comparison) && !is.null(segment_comparison$comparison_matrix)) {
    df <- segment_comparison$comparison_matrix
  } else {
    df <- .kd_list_to_df(segment_comparison)
    if (is.null(df) || nrow(df) == 0) return(NULL)
  }

  if (!is.data.frame(df) || nrow(df) == 0) return(NULL)

  # Identify segment columns: *_Pct and *_Rank pairs
  # Exclude Mean_Pct which is an aggregate, not a segment
  pct_cols  <- grep("_Pct$",  names(df), value = TRUE)
  rank_cols <- grep("_Rank$", names(df), value = TRUE)
  all_seg_names <- sub("_Pct$", "", pct_cols)
  # Only keep segments that have both _Pct and _Rank columns
  segment_names <- all_seg_names[paste0(all_seg_names, "_Rank") %in% rank_cols]

  # Build header: Driver | (Seg_Pct | Seg_Rank) per segment | Total % [| Delta]
  header_cells <- list(htmltools::tags$th("Driver", class = "kd-th kd-th-label"))

  for (seg in segment_names) {
    header_cells <- c(header_cells, list(
      htmltools::tags$th(paste0(seg, " %"),    class = "kd-th kd-th-num",
                         `data-kd-seg-col` = seg),
      htmltools::tags$th(paste0(seg, " Rank"), class = "kd-th kd-th-num",
                         `data-kd-seg-col` = seg)
    ))
  }

  # Total column (average across segments)
  has_mean <- "Mean_Pct" %in% names(df)
  if (has_mean) {
    header_cells <- c(header_cells, list(
      htmltools::tags$th("Total %", class = "kd-th kd-th-num",
                         `data-kd-seg-col` = "total")
    ))
  }

  # Delta column for exactly 2 segments
  show_delta <- length(segment_names) == 2
  if (show_delta) {
    delta_label <- sprintf("\u0394 (%s\u2013%s)", segment_names[1], segment_names[2])
    header_cells <- c(header_cells, list(
      htmltools::tags$th(delta_label, class = "kd-th kd-th-num")
    ))
  }

  header <- htmltools::tags$tr(header_cells)

  # Data rows
  rows <- lapply(seq_len(nrow(df)), function(i) {
    row <- df[i, , drop = FALSE]
    driver_name <- as.character(row$Driver %||% row$driver %||% "")

    cells <- list(htmltools::tags$td(driver_name, class = "kd-td kd-td-label"))

    for (seg in segment_names) {
      pct_val  <- as.numeric(row[[paste0(seg, "_Pct")]])
      rank_val <- row[[paste0(seg, "_Rank")]]

      cells <- c(cells, list(
        htmltools::tags$td(
          if (is.na(pct_val)) "-" else sprintf("%.0f%%", pct_val),
          class = "kd-td kd-td-num",
          `data-kd-seg-col` = seg,
          `data-kd-sort-val` = if (is.na(pct_val)) "0" else sprintf("%.4f", pct_val)
        ),
        htmltools::tags$td(
          if (is.na(rank_val)) "-" else as.character(rank_val),
          class = "kd-td kd-td-num",
          `data-kd-seg-col` = seg
        )
      ))
    }

    # Total column (average across segments)
    if (has_mean) {
      mean_val <- as.numeric(row$Mean_Pct)
      cells <- c(cells, list(
        htmltools::tags$td(
          if (is.na(mean_val)) "-" else sprintf("%.0f%%", mean_val),
          class = "kd-td kd-td-num",
          `data-kd-seg-col` = "total",
          `data-kd-sort-val` = if (is.na(mean_val)) "0" else sprintf("%.4f", mean_val)
        )
      ))
    }

    # Delta column
    if (show_delta) {
      pct_1 <- as.numeric(row[[paste0(segment_names[1], "_Pct")]])
      pct_2 <- as.numeric(row[[paste0(segment_names[2], "_Pct")]])

      if (!is.na(pct_1) && !is.na(pct_2)) {
        delta <- pct_1 - pct_2
        delta_colour <- if (abs(delta) >= 5) {
          if (delta > 0) "#059669" else "#DC2626"
        } else {
          "#64748b"
        }

        cells <- c(cells, list(
          htmltools::tags$td(
            class = "kd-td kd-td-num",
            htmltools::tags$span(
              style = sprintf("color:%s;font-weight:600;", delta_colour),
              sprintf("%+.0f pp", delta)
            )
          )
        ))
      } else {
        cells <- c(cells, list(
          htmltools::tags$td("-", class = "kd-td kd-td-num")
        ))
      }
    }

    htmltools::tags$tr(class = "kd-tr", cells)
  })

  htmltools::tags$table(
    class = "kd-table kd-segment-comparison-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Format numeric value for table display
#' @param val Numeric value
#' @param digits Number of decimal places
#' @return Formatted character string, or "-" for NA
#' @keywords internal
.kd_fmt_num <- function(val, digits = 2) {
  if (is.null(val) || length(val) == 0 || is.na(val)) return("-")
  sprintf(paste0("%.", digits, "f"), val)
}


#' Generate correlation cell background colour
#'
#' Maps a correlation value (-1 to +1) to a background colour.
#' Positive = blue gradient, negative = red gradient.
#' Stronger = more saturated.
#'
#' @param r Numeric correlation value
#' @return CSS colour string
#' @keywords internal
.kd_correlation_colour <- function(r) {
  if (is.na(r)) return("#f9fafb")

  abs_r <- min(1, abs(r))

  if (r >= 0) {
    # Blue gradient: white (#f8fafc) -> medium (#93C5FD) -> strong (#2563EB)
    if (abs_r < 0.3) {
      # Light range
      alpha <- abs_r / 0.3
      .kd_interpolate_colour("#f8fafc", "#DBEAFE", alpha)
    } else if (abs_r < 0.6) {
      alpha <- (abs_r - 0.3) / 0.3
      .kd_interpolate_colour("#DBEAFE", "#93C5FD", alpha)
    } else {
      alpha <- (abs_r - 0.6) / 0.4
      .kd_interpolate_colour("#93C5FD", "#2563EB", alpha)
    }
  } else {
    # Red gradient: white (#f8fafc) -> light red (#FEE2E2) -> strong (#DC2626)
    if (abs_r < 0.3) {
      alpha <- abs_r / 0.3
      .kd_interpolate_colour("#f8fafc", "#FEE2E2", alpha)
    } else if (abs_r < 0.6) {
      alpha <- (abs_r - 0.3) / 0.3
      .kd_interpolate_colour("#FEE2E2", "#FCA5A5", alpha)
    } else {
      alpha <- (abs_r - 0.6) / 0.4
      .kd_interpolate_colour("#FCA5A5", "#DC2626", alpha)
    }
  }
}


#' Interpolate between two hex colours
#'
#' @param colour1 Start colour (hex string, e.g. "#ffffff")
#' @param colour2 End colour (hex string)
#' @param alpha Interpolation factor 0..1 (0 = colour1, 1 = colour2)
#' @return Hex colour string
#' @keywords internal
.kd_interpolate_colour <- function(colour1, colour2, alpha) {
  alpha <- max(0, min(1, alpha))

  r1 <- strtoi(substr(colour1, 2, 3), 16L)
  g1 <- strtoi(substr(colour1, 4, 5), 16L)
  b1 <- strtoi(substr(colour1, 6, 7), 16L)

  r2 <- strtoi(substr(colour2, 2, 3), 16L)
  g2 <- strtoi(substr(colour2, 4, 5), 16L)
  b2 <- strtoi(substr(colour2, 6, 7), 16L)

  r <- round(r1 + alpha * (r2 - r1))
  g <- round(g1 + alpha * (g2 - g1))
  b <- round(b1 + alpha * (b2 - b1))

  sprintf("#%02x%02x%02x", r, g, b)
}


#' Map quadrant name to CSS class
#'
#' @param quadrant Character string quadrant name
#' @return CSS class string with kd- prefix
#' @keywords internal
.kd_quadrant_class <- function(quadrant) {
  q_lower <- tolower(quadrant %||% "")
  if (grepl("improve|priority|focus", q_lower)) {
    "kd-quad-improve"
  } else if (grepl("maintain|protect|leverage", q_lower)) {
    "kd-quad-maintain"
  } else if (grepl("monitor|secondary", q_lower)) {
    "kd-quad-monitor"
  } else if (grepl("low|depriori", q_lower)) {
    "kd-quad-low"
  } else {
    "kd-quad-default"
  }
}


#' Normalise importance data to list-of-lists
#'
#' Accepts either a data.frame or a list-of-lists and returns
#' a consistent list-of-lists representation.
#'
#' @param data Data.frame or list
#' @return List of lists, each representing one row
#' @keywords internal
.kd_normalise_to_list <- function(data) {
  if (is.data.frame(data)) {
    lapply(seq_len(nrow(data)), function(i) as.list(data[i, , drop = FALSE]))
  } else if (is.list(data) && length(data) > 0) {
    # If first element is a list, assume list-of-lists
    if (is.list(data[[1]])) {
      data
    } else {
      # Single entry - wrap in list
      list(data)
    }
  } else {
    list()
  }
}


#' Convert list-of-lists to data.frame
#'
#' @param lst List of lists with consistent field names
#' @return data.frame, or NULL on failure
#' @keywords internal
.kd_list_to_df <- function(lst) {
  if (!is.list(lst) || length(lst) == 0) return(NULL)

  tryCatch({
    if (is.data.frame(lst)) return(lst)
    if (is.list(lst[[1]])) {
      # list-of-lists: each element is a named list (row)
      do.call(rbind, lapply(lst, function(x) {
        as.data.frame(x, stringsAsFactors = FALSE)
      }))
    } else {
      # Single list entry
      as.data.frame(lst, stringsAsFactors = FALSE)
    }
  }, error = function(e) {
    cat(sprintf("[WARN] .kd_list_to_df conversion failed: %s\n", e$message))
    NULL
  })
}


# ==============================================================================
# NULL-COALESCING OPERATOR (guarded)
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
