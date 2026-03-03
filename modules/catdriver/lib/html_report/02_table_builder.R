# ==============================================================================
# CATDRIVER HTML REPORT - TABLE BUILDER
# ==============================================================================
# Builds HTML tables from transformed data using htmltools.
# All IDs and classes use cd- prefix for Report Hub namespace safety.
# ==============================================================================

#' Build Importance Table HTML
#'
#' Creates a ranked table of driver importance with visual bars.
#'
#' @param importance List of importance entries from transformer
#' @return htmltools tag object
#' @keywords internal
build_cd_importance_table <- function(importance, id_prefix = "") {

  header <- htmltools::tags$tr(
    htmltools::tags$th("Rank", class = "cd-th cd-th-rank"),
    htmltools::tags$th("Factor", class = "cd-th cd-th-label"),
    htmltools::tags$th("Importance", class = "cd-th cd-th-bar"),
    htmltools::tags$th("%", class = "cd-th cd-th-num"),
    htmltools::tags$th("Chi-Square", class = "cd-th cd-th-num"),
    htmltools::tags$th("P-Value", class = "cd-th cd-th-num"),
    htmltools::tags$th("Sig.", class = "cd-th cd-th-sig"),
    htmltools::tags$th("Effect", class = "cd-th cd-th-effect")
  )

  rows <- lapply(importance, function(d) {
    bar_width <- min(100, max(0, d$importance_pct))
    bar_colour <- if (d$importance_pct >= 30) "#2563EB"
                  else if (d$importance_pct >= 15) "#3B82F6"
                  else if (d$importance_pct >= 5) "#93C5FD"
                  else "#DBEAFE"

    sig_text <- if (is.null(d$significance) || is.na(d$significance)) "" else d$significance
    sig_class <- if (grepl("\\*\\*", sig_text)) "cd-sig-strong"
                 else if (grepl("\\*", sig_text)) "cd-sig-moderate"
                 else "cd-sig-none"

    htmltools::tags$tr(
      class = "cd-tr",
      htmltools::tags$td(d$rank, class = "cd-td cd-td-rank"),
      htmltools::tags$td(d$label, class = "cd-td cd-td-label"),
      htmltools::tags$td(
        class = "cd-td cd-td-bar",
        htmltools::tags$div(
          class = "cd-bar-container",
          htmltools::tags$div(
            class = "cd-bar-fill",
            style = sprintf("width:%.1f%%;background:%s;", bar_width, bar_colour)
          )
        )
      ),
      htmltools::tags$td(sprintf("%.1f%%", d$importance_pct), class = "cd-td cd-td-num"),
      htmltools::tags$td(sprintf("%.2f", d$chi_square), class = "cd-td cd-td-num"),
      htmltools::tags$td(d$p_formatted, class = "cd-td cd-td-num"),
      htmltools::tags$td(sig_text, class = paste("cd-td cd-td-sig", sig_class)),
      htmltools::tags$td(d$effect_size %||% "", class = "cd-td cd-td-effect")
    )
  })

  htmltools::tags$table(
    class = "cd-table cd-importance-table",
    id = paste0(id_prefix, "cd-importance-table"),
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


#' Build Pattern Table HTML for One Driver
#'
#' @param pattern_data Transformed pattern data for one driver
#' @param var_name Variable name (used for ID)
#' @return htmltools tag object
#' @keywords internal
build_cd_pattern_table <- function(pattern_data, var_name, id_prefix = "") {

  # Build outcome headers
  outcome_ths <- lapply(pattern_data$outcome_categories, function(cat_name) {
    htmltools::tags$th(cat_name, class = "cd-th cd-th-num")
  })

  header <- htmltools::tags$tr(
    htmltools::tags$th("Category", class = "cd-th cd-th-label"),
    htmltools::tags$th("N", class = "cd-th cd-th-num"),
    htmltools::tags$th("% of Total", class = "cd-th cd-th-num"),
    outcome_ths,
    htmltools::tags$th("OR vs Ref", class = "cd-th cd-th-num"),
    htmltools::tags$th("95% CI", class = "cd-th cd-th-num"),
    htmltools::tags$th("Effect", class = "cd-th cd-th-effect")
  )

  rows <- lapply(pattern_data$categories, function(cat) {
    outcome_tds <- lapply(pattern_data$outcome_categories, function(oname) {
      val <- cat$outcome_pcts[[oname]]
      htmltools::tags$td(
        sprintf("%.0f%%", val),
        class = "cd-td cd-td-num"
      )
    })

    or_display <- if (cat$is_reference) {
      "1.00 (ref)"
    } else {
      format_or(cat$odds_ratio)
    }

    ci_display <- if (cat$is_reference) {
      "-"
    } else {
      format_ci(cat$or_lower, cat$or_upper)
    }

    row_class <- if (cat$is_reference) "cd-tr cd-tr-reference" else "cd-tr"

    htmltools::tags$tr(
      class = row_class,
      htmltools::tags$td(cat$category, class = "cd-td cd-td-label"),
      htmltools::tags$td(cat$n, class = "cd-td cd-td-num"),
      htmltools::tags$td(sprintf("%.0f%%", cat$pct_of_total), class = "cd-td cd-td-num"),
      outcome_tds,
      htmltools::tags$td(or_display, class = "cd-td cd-td-num"),
      htmltools::tags$td(ci_display, class = "cd-td cd-td-num"),
      htmltools::tags$td(cat$effect, class = "cd-td cd-td-effect")
    )
  })

  safe_id <- gsub("[^a-zA-Z0-9_]", "-", var_name)

  htmltools::tags$table(
    class = "cd-table cd-pattern-table",
    id = paste0(id_prefix, "cd-pattern-", safe_id),
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


#' Build Odds Ratio Table HTML
#'
#' @param odds_ratios List of OR entries from transformer
#' @param has_bootstrap Whether bootstrap columns are available
#' @return htmltools tag object
#' @keywords internal
build_cd_odds_ratio_table <- function(odds_ratios, has_bootstrap = FALSE, id_prefix = "") {

  base_ths <- list(
    htmltools::tags$th("Factor", class = "cd-th cd-th-label"),
    htmltools::tags$th("Comparison", class = "cd-th cd-th-label"),
    htmltools::tags$th("Reference", class = "cd-th cd-th-label"),
    htmltools::tags$th("OR", class = "cd-th cd-th-num"),
    htmltools::tags$th("95% CI", class = "cd-th cd-th-num"),
    htmltools::tags$th("P-Value", class = "cd-th cd-th-num"),
    htmltools::tags$th("Sig.", class = "cd-th cd-th-sig"),
    htmltools::tags$th("Effect", class = "cd-th cd-th-effect"),
    htmltools::tags$th("Interpretation", class = "cd-th cd-th-interp")
  )

  if (has_bootstrap) {
    base_ths <- c(base_ths, list(
      htmltools::tags$th("Boot OR", class = "cd-th cd-th-num"),
      htmltools::tags$th("Boot CI", class = "cd-th cd-th-num"),
      htmltools::tags$th("Stability", class = "cd-th cd-th-num")
    ))
  }

  # Add outcome_level column if present
  has_outcome_level <- !is.null(odds_ratios[[1]]$outcome_level)
  if (has_outcome_level) {
    base_ths <- c(
      list(htmltools::tags$th("Outcome", class = "cd-th cd-th-label")),
      base_ths
    )
  }

  header <- htmltools::tags$tr(base_ths)

  rows <- lapply(odds_ratios, function(r) {
    or_val <- r$or_value
    interp <- if (is.na(or_val)) ""
              else if (or_val > 3.0) "Much more likely"
              else if (or_val > 2.0) "Substantially more likely"
              else if (or_val > 1.5) "Moderately more likely"
              else if (or_val > 1.1) "Slightly more likely"
              else if (or_val >= 0.9) "No meaningful difference"
              else if (or_val >= 0.67) "Slightly less likely"
              else if (or_val >= 0.5) "Moderately less likely"
              else "Much less likely"

    sig_text <- if (is.null(r$significance) || is.na(r$significance)) "" else r$significance
    sig_class <- if (grepl("\\*\\*", sig_text)) "cd-sig-strong"
                 else if (grepl("\\*", sig_text)) "cd-sig-moderate"
                 else "cd-sig-none"

    # Effect colour class
    effect_text <- if (is.null(r$effect) || is.na(r$effect)) "" else r$effect
    effect_class <- if (grepl("large|very large", tolower(effect_text))) {
      if (!is.na(or_val) && or_val >= 1.0) "cd-effect-pos" else "cd-effect-neg"
    } else if (grepl("medium", tolower(effect_text))) {
      "cd-effect-mod"
    } else {
      "cd-effect-none"
    }

    base_tds <- list(
      htmltools::tags$td(r$factor_label, class = "cd-td cd-td-label"),
      htmltools::tags$td(r$comparison, class = "cd-td cd-td-label"),
      htmltools::tags$td(r$reference, class = "cd-td cd-td-label"),
      htmltools::tags$td(r$or_formatted, class = "cd-td cd-td-num"),
      htmltools::tags$td(r$ci_formatted, class = "cd-td cd-td-num"),
      htmltools::tags$td(r$p_formatted, class = "cd-td cd-td-num"),
      htmltools::tags$td(sig_text, class = paste("cd-td cd-td-sig", sig_class)),
      htmltools::tags$td(effect_text, class = paste("cd-td cd-td-effect", effect_class)),
      htmltools::tags$td(interp, class = "cd-td cd-td-interp")
    )

    if (has_bootstrap) {
      boot_or <- if (!is.null(r$boot_median_or) && !is.na(r$boot_median_or)) {
        format_or(r$boot_median_or)
      } else "-"
      boot_ci <- if (!is.null(r$boot_ci_lower) && !is.na(r$boot_ci_lower)) {
        format_ci(r$boot_ci_lower, r$boot_ci_upper)
      } else "-"
      stability <- if (!is.null(r$sign_stability) && !is.na(r$sign_stability)) {
        sprintf("%.0f%%", r$sign_stability * 100)
      } else "-"

      base_tds <- c(base_tds, list(
        htmltools::tags$td(boot_or, class = "cd-td cd-td-num"),
        htmltools::tags$td(boot_ci, class = "cd-td cd-td-num"),
        htmltools::tags$td(stability, class = "cd-td cd-td-num")
      ))
    }

    if (has_outcome_level) {
      base_tds <- c(
        list(htmltools::tags$td(r$outcome_level, class = "cd-td cd-td-label")),
        base_tds
      )
    }

    htmltools::tags$tr(class = "cd-tr", `data-cd-factor` = r$factor_label, base_tds)
  })

  htmltools::tags$table(
    class = "cd-table cd-or-table",
    id = paste0(id_prefix, "cd-odds-ratios-table"),
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


#' Build Diagnostics Table HTML
#'
#' @param diagnostics Transformed diagnostics from transformer
#' @param model_info Model info from transformer
#' @param config Configuration list
#' @return htmltools tag object
#' @keywords internal
build_cd_diagnostics_table <- function(diagnostics, model_info, config, id_prefix = "") {

  min_sample <- config$min_sample_size %||% 30

  # Status checks
  checks <- list(
    list(
      check = "Sample size",
      status = if (diagnostics$complete_n >= min_sample) "PASS" else "FAIL",
      detail = sprintf("N=%d (min %d required)", diagnostics$complete_n, min_sample)
    ),
    list(
      check = "Complete cases",
      status = if (diagnostics$pct_complete >= 70) "PASS"
               else if (diagnostics$pct_complete >= 50) "WARN" else "FAIL",
      detail = sprintf("%s%% complete (%d/%d)",
                       diagnostics$pct_complete, diagnostics$complete_n,
                       diagnostics$original_n)
    ),
    list(
      check = "Convergence",
      status = if (diagnostics$convergence) "PASS" else "WARN",
      detail = if (diagnostics$convergence) "Converged normally" else "Did not fully converge"
    ),
    list(
      check = "Small cells",
      status = if (!diagnostics$has_small_cells) "PASS" else "WARN",
      detail = if (!diagnostics$has_small_cells) "No cells < 5 observations"
               else sprintf("%d predictors with small cells", diagnostics$n_small_cell_vars)
    )
  )

  header <- htmltools::tags$tr(
    htmltools::tags$th("Check", class = "cd-th cd-th-label"),
    htmltools::tags$th("Status", class = "cd-th cd-th-status"),
    htmltools::tags$th("Details", class = "cd-th cd-th-detail")
  )

  rows <- lapply(checks, function(chk) {
    badge_class <- switch(chk$status,
      "PASS" = "cd-badge-pass",
      "WARN" = "cd-badge-warn",
      "FAIL" = "cd-badge-fail",
      "cd-badge-info"
    )

    htmltools::tags$tr(
      class = "cd-tr",
      htmltools::tags$td(chk$check, class = "cd-td cd-td-label"),
      htmltools::tags$td(
        class = "cd-td cd-td-status",
        htmltools::tags$span(class = paste("cd-badge", badge_class), chk$status)
      ),
      htmltools::tags$td(chk$detail, class = "cd-td cd-td-detail")
    )
  })

  htmltools::tags$table(
    class = "cd-table cd-diagnostics-table",
    id = paste0(id_prefix, "cd-diagnostics-table"),
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}
