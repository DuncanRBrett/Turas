# ==============================================================================
# KEYDRIVER HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Restructures analysis results into HTML-friendly format.
# Pure data transformation -- no HTML generation here.
#
# Version: Turas v10.3
# Module:  keydriver / lib / html_report
# ==============================================================================

#' Transform Key Driver Results for HTML Rendering
#'
#' Converts the raw results list from \code{run_keydriver_analysis()} into a
#' structured format optimised for HTML table and chart generation.  Every
#' optional section (\code{effect_sizes}, \code{quadrant_data},
#' \code{bootstrap_ci}, \code{segment_comparison}) is included only when
#' the corresponding field is present in \code{results}.
#'
#' @param results Analysis results from \code{run_keydriver_analysis()}.
#'   Expected fields: \code{$importance}, \code{$model} or
#'   \code{$model_summary}, \code{$correlations}, \code{$config}.
#'   Optional fields: \code{$vif_values}, \code{$shap_results},
#'   \code{$quadrant_results}, \code{$bootstrap_ci}, \code{$effect_sizes},
#'   \code{$segment_comparison}, \code{$executive_summary},
#'   \code{$term_mapping}.
#' @param config Configuration list.
#'
#' @return List with transformed data for each report section:
#'   \describe{
#'     \item{importance}{List of per-driver entries for importance display}
#'     \item{method_comparison}{Data frame with rank columns and agreement}
#'     \item{correlations}{Correlation matrix or data frame}
#'     \item{model_info}{List of model summary statistics}
#'     \item{vif_values}{Data frame with Driver, VIF, Concern}
#'     \item{effect_sizes}{Data frame (if available)}
#'     \item{quadrant_data}{List with quadrant info (if available)}
#'     \item{bootstrap_ci}{Data frame (if available)}
#'     \item{segment_comparison}{List (if available)}
#'     \item{narrative}{Auto-generated insights (list with $insights etc.)}
#'     \item{methods_available}{Character vector of method names}
#'     \item{n_drivers}{Integer}
#'     \item{has_shap}{Logical}
#'     \item{has_quadrant}{Logical}
#'     \item{has_bootstrap}{Logical}
#'   }
#'
#' @keywords internal
transform_keydriver_for_html <- function(results, config) {

  imp_df <- results$importance

  if (is.null(imp_df) || !is.data.frame(imp_df) || nrow(imp_df) == 0) {
    cat("[WARN] KD_HTML_TRANSFORM: importance data frame is NULL or empty\n")
    return(NULL)
  }

  n_drivers <- nrow(imp_df)

  # --------------------------------------------------------------------------
  # Detect which methods are available
  # --------------------------------------------------------------------------
  methods_available <- character(0)

  if ("Correlation" %in% names(imp_df))     methods_available <- c(methods_available, "correlation")
  if ("Beta_Weight" %in% names(imp_df))     methods_available <- c(methods_available, "beta")
  if ("Relative_Weight" %in% names(imp_df)) methods_available <- c(methods_available, "rel_weight")
  # Std_Beta may appear as Beta_Coefficient in some configs
  if ("Beta_Coefficient" %in% names(imp_df) || "Std_Beta" %in% names(imp_df)) {
    methods_available <- c(methods_available, "std_beta")
  }
  if ("Shapley_Value" %in% names(imp_df))   methods_available <- c(methods_available, "shapley")

  has_shap <- "SHAP_Importance" %in% names(imp_df) ||
              !is.null(results$shap_results) ||
              !is.null(results$shap)
  if (has_shap) methods_available <- c(methods_available, "shap")

  has_quadrant  <- !is.null(results$quadrant_results) || !is.null(results$quadrant)
  has_bootstrap <- !is.null(results$bootstrap_ci)

  # --------------------------------------------------------------------------
  # 1. Importance list -- one entry per driver
  # --------------------------------------------------------------------------
  # Pick primary importance column for pct (prefer Shapley, then Relative Weight)
  primary_col <- .kd_pick_primary_importance(imp_df)

  # Sort by primary column descending
  sort_vals <- if (!is.null(primary_col)) imp_df[[primary_col]] else seq_len(n_drivers)
  sort_order <- order(-sort_vals)
  imp_df_sorted <- imp_df[sort_order, , drop = FALSE]

  importance <- lapply(seq_len(nrow(imp_df_sorted)), function(i) {
    row <- imp_df_sorted[i, ]

    label <- .kd_resolve_label(row, config)
    pct   <- if (!is.null(primary_col)) as.numeric(row[[primary_col]]) else 0

    # Build per-method scores
    method_scores <- list(
      correlation = .kd_safe_numeric(row, "Correlation"),
      beta        = .kd_safe_numeric(row, "Beta_Weight"),
      rel_weight  = .kd_safe_numeric(row, "Relative_Weight"),
      std_beta    = .kd_safe_numeric(row, c("Beta_Coefficient", "Std_Beta")),
      shapley     = .kd_safe_numeric(row, "Shapley_Value"),
      shap        = .kd_safe_numeric(row, "SHAP_Importance")
    )

    list(
      rank          = i,
      driver        = as.character(row$Driver),
      label         = label,
      pct           = pct,
      method_scores = method_scores,
      top3          = (i <= 3)
    )
  })

  # --------------------------------------------------------------------------
  # 2. Method comparison
  # --------------------------------------------------------------------------
  method_comparison <- .kd_build_method_comparison(imp_df_sorted, has_shap)

  # --------------------------------------------------------------------------
  # 3. Correlations
  # --------------------------------------------------------------------------
  correlations <- results$correlations

  # --------------------------------------------------------------------------
  # 4. Model info
  # --------------------------------------------------------------------------
  model_info <- .kd_extract_model_info(results)

  # --------------------------------------------------------------------------
  # 5. VIF values
  # --------------------------------------------------------------------------
  vif_values <- .kd_transform_vif(results)

  # --------------------------------------------------------------------------
  # 6. Effect sizes (optional)
  # --------------------------------------------------------------------------
  effect_sizes <- results$effect_sizes  # pass through if available

  # --------------------------------------------------------------------------
  # 7. Quadrant data (optional)
  # --------------------------------------------------------------------------
  quadrant_data <- NULL
  quad_source <- results$quadrant_results %||% results$quadrant
  if (!is.null(quad_source)) {
    quadrant_data <- list(
      data         = quad_source$data,
      action_table = quad_source$action_table,
      gap_analysis = quad_source$gap_analysis,
      plots        = quad_source$plots
    )
  }

  # --------------------------------------------------------------------------
  # 8. Bootstrap CI (optional)
  # --------------------------------------------------------------------------
  bootstrap_ci <- results$bootstrap_ci  # data.frame pass-through

  # --------------------------------------------------------------------------
  # 9. Segment comparison (optional)
  # --------------------------------------------------------------------------
  segment_comparison <- results$segment_comparison  # list pass-through

  # --------------------------------------------------------------------------
  # 10. Narrative insights
  # --------------------------------------------------------------------------
  narrative <- generate_kd_narrative(
    importance       = importance,
    method_comparison = method_comparison,
    model_info       = model_info,
    vif_values       = vif_values,
    has_shap         = has_shap,
    has_quadrant     = has_quadrant,
    has_bootstrap    = has_bootstrap,
    executive_summary = results$executive_summary
  )

  # --------------------------------------------------------------------------
  # Return assembled structure
  # --------------------------------------------------------------------------
  list(
    importance         = importance,
    method_comparison  = method_comparison,
    correlations       = correlations,
    model_info         = model_info,
    vif_values         = vif_values,
    effect_sizes       = effect_sizes,
    quadrant_data      = quadrant_data,
    bootstrap_ci       = bootstrap_ci,
    segment_comparison = segment_comparison,
    narrative          = narrative,
    methods_available  = methods_available,
    n_drivers          = n_drivers,
    has_shap           = has_shap,
    has_quadrant       = has_quadrant,
    has_bootstrap      = has_bootstrap,
    analysis_name      = config$analysis_name %||% "Key Driver Analysis",
    run_status         = results$run_status %||% "PASS"
  )
}


# ==============================================================================
# NARRATIVE GENERATOR
# ==============================================================================

#' Generate Narrative Insights for Key Driver HTML Report
#'
#' Produces 3-5 plain-English insight strings for the executive summary
#' section of the HTML report.  Detects patterns such as dominant drivers,
#' method consensus, model quality, and multicollinearity concerns.
#'
#' @param importance List of importance entries (from transform step).
#' @param method_comparison Data frame from \code{.kd_build_method_comparison}.
#' @param model_info Model information list.
#' @param vif_values VIF data frame or NULL.
#' @param has_shap Logical.
#' @param has_quadrant Logical.
#' @param has_bootstrap Logical.
#' @param executive_summary Optional pre-built executive summary list
#'   (if present, its headline and key findings are folded in).
#'
#' @return List with:
#'   \describe{
#'     \item{insights}{Character vector of 3-5 insight strings}
#'     \item{dominant_driver}{Driver name or NULL}
#'     \item{key_findings}{List of finding structures}
#'   }
#'
#' @keywords internal
generate_kd_narrative <- function(importance,
                                  method_comparison = NULL,
                                  model_info        = NULL,
                                  vif_values        = NULL,
                                  has_shap          = FALSE,
                                  has_quadrant      = FALSE,
                                  has_bootstrap     = FALSE,
                                  executive_summary = NULL) {

  insights <- character(0)
  key_findings <- list()
  dominant_driver <- NULL

  n_drivers <- length(importance)
  if (n_drivers == 0) {
    return(list(
      insights        = "No driver importance data available.",
      dominant_driver = NULL,
      key_findings    = list()
    ))
  }

  # --- Use pre-built executive summary if available ---
  if (!is.null(executive_summary) && is.list(executive_summary)) {
    if (!is.null(executive_summary$headline) && nzchar(executive_summary$headline)) {
      insights <- c(insights, executive_summary$headline)
    }
    if (length(executive_summary$key_findings) > 0) {
      # Take up to 2 findings from the executive summary to avoid duplication
      n_take <- min(2L, length(executive_summary$key_findings))
      insights <- c(insights, executive_summary$key_findings[seq_len(n_take)])
    }
  }

  # --- Insight: Dominant driver detection ---
  top_pct   <- importance[[1]]$pct
  top_label <- importance[[1]]$label

  if (top_pct >= 40) {
    dominant_driver <- top_label
    insight_dom <- sprintf(
      "%s is the dominant driver, accounting for %.0f%% of explained variation -- substantially more than any other factor.",
      top_label, top_pct
    )
    if (!.kd_insight_redundant(insights, top_label, "dominant")) {
      insights <- c(insights, insight_dom)
    }
  } else if (n_drivers >= 2) {
    top2_pct <- importance[[1]]$pct + importance[[2]]$pct
    if (top2_pct >= 70) {
      insight_top2 <- sprintf(
        "%s (%.0f%%) and %s (%.0f%%) together account for %.0f%% of explained variation, forming a clear top tier.",
        importance[[1]]$label, importance[[1]]$pct,
        importance[[2]]$label, importance[[2]]$pct,
        top2_pct
      )
      if (!.kd_insight_redundant(insights, importance[[1]]$label, "top tier")) {
        insights <- c(insights, insight_top2)
      }
    }
  }

  # --- Insight: Method agreement ---
  if (!is.null(method_comparison) && is.data.frame(method_comparison) && nrow(method_comparison) > 0) {
    agreement_levels <- method_comparison$Agreement
    n_high  <- sum(agreement_levels == "High", na.rm = TRUE)
    n_total <- length(agreement_levels)
    pct_high <- round(100 * n_high / max(n_total, 1))

    if (pct_high >= 80) {
      insights <- c(insights,
        sprintf("Strong cross-method consensus: %d of %d drivers (%.0f%%) show high agreement across importance methods.",
                n_high, n_total, pct_high)
      )
    } else if (pct_high < 40) {
      insights <- c(insights,
        sprintf("Methods show limited agreement: only %d of %d drivers have consistent rankings. Interpret results cautiously.",
                n_high, n_total)
      )
    }
  }

  # --- Insight: Model quality ---
  if (!is.null(model_info)) {
    r2 <- model_info$r_squared
    if (!is.null(r2) && !is.na(r2)) {
      if (r2 < 0.10) {
        insights <- c(insights,
          sprintf("The model explains only %.0f%% of the variation, suggesting important unmeasured drivers exist. Interpret as directional signals.",
                  r2 * 100)
        )
      } else if (r2 >= 0.50) {
        insights <- c(insights,
          sprintf("The model has good explanatory power (R%s = %.0f%%), supporting confident interpretation of driver rankings.",
                  "\u00b2", r2 * 100)
        )
      }
    }
  }

  # --- Insight: VIF concerns ---
  if (!is.null(vif_values) && is.data.frame(vif_values) && nrow(vif_values) > 0) {
    high_vif <- vif_values[vif_values$Concern == "High", , drop = FALSE]
    if (nrow(high_vif) > 0) {
      vif_drivers <- paste(high_vif$Driver, collapse = ", ")
      insights <- c(insights,
        sprintf("Multicollinearity concern: %s %s high VIF values. Importance estimates for %s drivers may be inflated.",
                vif_drivers,
                if (nrow(high_vif) == 1) "has" else "have",
                if (nrow(high_vif) == 1) "this" else "these")
      )
    }
  }

  # --- Cap at 5 insights ---
  if (length(insights) > 5) {
    insights <- insights[1:5]
  }

  # Guarantee at least 3

  if (length(insights) < 3) {
    # Add filler based on available features
    if (has_shap && length(insights) < 3) {
      insights <- c(insights,
        "SHAP-based importance is available, providing a machine-learning perspective alongside traditional methods."
      )
    }
    if (has_quadrant && length(insights) < 3) {
      insights <- c(insights,
        "Quadrant analysis maps importance against performance, highlighting actionable priorities."
      )
    }
    if (has_bootstrap && length(insights) < 3) {
      insights <- c(insights,
        "Bootstrap confidence intervals quantify the uncertainty around each driver's importance score."
      )
    }
    if (length(insights) < 3) {
      insights <- c(insights,
        sprintf("Analysis covers %d drivers using %s.",
                n_drivers,
                if (has_shap) "multiple methods including SHAP" else "traditional importance methods")
      )
    }
  }

  # --- Build key findings from top 3 ---
  for (i in seq_len(min(3L, n_drivers))) {
    entry <- importance[[i]]
    key_findings <- c(key_findings, list(list(
      rank   = entry$rank,
      driver = entry$driver,
      label  = entry$label,
      pct    = entry$pct,
      text   = sprintf("#%d %s accounts for %.0f%% of driver importance.",
                        entry$rank, entry$label, entry$pct)
    )))
  }

  list(
    insights        = insights,
    dominant_driver = dominant_driver,
    key_findings    = key_findings
  )
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Pick Primary Importance Column
#'
#' Selects the best available importance column from the data frame for sorting
#' and display.  Preference: Shapley > SHAP > Relative Weight > Beta Weight.
#'
#' @param imp_df Importance data frame.
#' @return Column name string, or NULL.
#' @keywords internal
.kd_pick_primary_importance <- function(imp_df) {
  preference <- c("Shapley_Value", "SHAP_Importance", "Relative_Weight",
                   "Beta_Weight", "Importance")
  for (col in preference) {
    if (col %in% names(imp_df)) return(col)
  }
  NULL
}


#' Resolve Driver Label
#'
#' Returns the best human-readable label for a driver row.  Uses the Label
#' column if present, otherwise falls back to Driver.
#'
#' @param row Single data frame row.
#' @param config Configuration list (used for variable labels lookup).
#' @return Character string.
#' @keywords internal
.kd_resolve_label <- function(row, config) {
  # Try Label column in importance data
  if ("Label" %in% names(row)) {
    lbl <- as.character(row$Label)
    if (!is.na(lbl) && nzchar(lbl)) return(lbl)
  }

  # Try config variable labels
  driver_name <- as.character(row$Driver)
  if (!is.null(config$variables) && is.data.frame(config$variables)) {
    idx <- match(driver_name, config$variables$VariableName)
    if (!is.na(idx)) {
      cfg_label <- config$variables$Label[idx]
      if (!is.na(cfg_label) && nzchar(cfg_label)) return(cfg_label)
    }
  }

  driver_name
}


#' Safely Extract Numeric Value from a Data Frame Row
#'
#' Tries one or more column names and returns the first valid numeric value.
#' Returns NA_real_ if none are found.
#'
#' @param row Single data frame row.
#' @param col_names Character vector of column names to try.
#' @return Numeric value or NA_real_.
#' @keywords internal
.kd_safe_numeric <- function(row, col_names) {
  for (col in col_names) {
    if (col %in% names(row)) {
      val <- row[[col]]
      if (is.numeric(val) && length(val) == 1 && !is.na(val)) {
        return(as.numeric(val))
      }
    }
  }
  NA_real_
}


#' Build Method Comparison Data Frame
#'
#' Creates a data frame showing each driver's rank across methods and an
#' agreement classification (High / Medium / Low) based on the standard
#' deviation of ranks.
#'
#' @param imp_df Importance data frame (already sorted).
#' @param has_shap Logical, whether SHAP ranks are available.
#' @return Data frame with columns: Driver, Rank_Correlation, Rank_Beta,
#'   Rank_RelWeight, Rank_StdBeta, optionally Rank_SHAP, Mean_Rank, Agreement.
#' @keywords internal
.kd_build_method_comparison <- function(imp_df, has_shap) {

  mc <- data.frame(Driver = imp_df$Driver, stringsAsFactors = FALSE)

  # Map available rank columns
  rank_map <- list(
    Rank_Correlation = c("Corr_Rank"),
    Rank_Beta        = c("Beta_Rank"),
    Rank_RelWeight   = c("RelWeight_Rank"),
    Rank_StdBeta     = c("Shapley_Rank")
  )

  for (out_col in names(rank_map)) {
    src_cols <- rank_map[[out_col]]
    found <- FALSE
    for (src in src_cols) {
      if (src %in% names(imp_df)) {
        mc[[out_col]] <- as.numeric(imp_df[[src]])
        found <- TRUE
        break
      }
    }
    if (!found) {
      mc[[out_col]] <- NA_real_
    }
  }

  # SHAP rank (optional)
  if (has_shap && "SHAP_Rank" %in% names(imp_df)) {
    mc$Rank_SHAP <- as.numeric(imp_df$SHAP_Rank)
  }

  # Calculate mean rank across available columns
  rank_cols <- grep("^Rank_", names(mc), value = TRUE)
  if (length(rank_cols) > 0) {
    rank_matrix <- as.matrix(mc[, rank_cols, drop = FALSE])
    mc$Mean_Rank <- round(rowMeans(rank_matrix, na.rm = TRUE), 1)

    # Agreement classification based on SD of ranks
    mc$Agreement <- vapply(seq_len(nrow(mc)), function(i) {
      vals <- rank_matrix[i, ]
      vals <- vals[!is.na(vals)]
      if (length(vals) < 2) return("N/A")
      sd_val <- sd(vals)
      if (sd_val <= 1.0) return("High")
      if (sd_val <= 2.5) return("Medium")
      "Low"
    }, character(1))
  } else {
    mc$Mean_Rank <- NA_real_
    mc$Agreement <- "N/A"
  }

  mc
}


#' Extract Model Information from Results
#'
#' Builds a list of model summary statistics from the results object.
#' Handles both \code{results$model} (lm object) and
#' \code{results$model_summary} (pre-computed summary).
#'
#' @param results Analysis results list.
#' @return List with: r_squared, adj_r_squared, f_statistic, p_value,
#'   n_obs, n_drivers, rmse.
#' @keywords internal
.kd_extract_model_info <- function(results) {

  info <- list(
    r_squared     = NA_real_,
    adj_r_squared = NA_real_,
    f_statistic   = NA_real_,
    p_value       = NA_real_,
    n_obs         = NA_integer_,
    n_drivers     = NA_integer_,
    rmse          = NA_real_
  )

  # Try pre-computed model_summary first
  ms <- results$model_summary
  model <- results$model

  if (!is.null(model) && inherits(model, "lm")) {
    summ <- tryCatch(summary(model), error = function(e) NULL)
    if (!is.null(summ)) {
      info$r_squared     <- summ$r.squared
      info$adj_r_squared <- summ$adj.r.squared
      info$n_obs         <- tryCatch(as.integer(stats::nobs(model)), error = function(e) NA_integer_)
      info$rmse          <- tryCatch(sqrt(mean(stats::residuals(model)^2)), error = function(e) NA_real_)

      fstat <- summ$fstatistic
      if (!is.null(fstat) && length(fstat) >= 3) {
        info$f_statistic <- fstat[1]
        info$p_value     <- tryCatch(
          stats::pf(fstat[1], fstat[2], fstat[3], lower.tail = FALSE),
          error = function(e) NA_real_
        )
      }

      # Count drivers (coefficients minus intercept)
      n_coefs <- length(stats::coef(model))
      info$n_drivers <- max(0L, n_coefs - 1L)
    }
  } else if (!is.null(ms) && is.list(ms)) {
    # Pre-computed summary (may come from results where model is not saved)
    info$r_squared     <- ms$r.squared     %||% ms$r_squared     %||% NA_real_
    info$adj_r_squared <- ms$adj.r.squared %||% ms$adj_r_squared %||% NA_real_

    fstat <- ms$fstatistic
    if (!is.null(fstat) && length(fstat) >= 3) {
      info$f_statistic <- fstat[1]
      info$p_value     <- tryCatch(
        stats::pf(fstat[1], fstat[2], fstat[3], lower.tail = FALSE),
        error = function(e) NA_real_
      )
    }

    # Coefficients matrix may provide n_drivers
    if (!is.null(ms$coefficients) && is.matrix(ms$coefficients)) {
      info$n_drivers <- max(0L, nrow(ms$coefficients) - 1L)
    }
  }

  # Override n_drivers from config if available
  if (!is.null(results$config) && !is.null(results$config$driver_vars)) {
    info$n_drivers <- length(results$config$driver_vars)
  }

  info
}


#' Transform VIF Values for HTML Display
#'
#' Converts the raw VIF output into a data frame with Driver, VIF, and
#' Concern (None / Moderate / High) columns.
#'
#' @param results Analysis results list.
#' @return Data frame with columns Driver, VIF, Concern, or NULL.
#' @keywords internal
.kd_transform_vif <- function(results) {

  vif_raw <- results$vif_values

  # If not on results directly, try computing from model

  if (is.null(vif_raw) && !is.null(results$model) && inherits(results$model, "lm")) {
    vif_raw <- tryCatch({
      # calculate_vif is defined in 04_output.R and should be in scope
      if (exists("calculate_vif", mode = "function")) {
        calculate_vif(results$model)
      } else {
        NULL
      }
    }, error = function(e) {
      cat(sprintf("[WARN] KD_HTML_TRANSFORM: VIF calculation failed: %s\n", e$message))
      NULL
    })
  }

  if (is.null(vif_raw) || length(vif_raw) == 0) return(NULL)

  # Named numeric vector -> data frame
  if (is.numeric(vif_raw) && !is.null(names(vif_raw))) {
    vif_df <- data.frame(
      Driver  = names(vif_raw),
      VIF     = as.numeric(vif_raw),
      stringsAsFactors = FALSE
    )
  } else if (is.data.frame(vif_raw)) {
    vif_df <- vif_raw
    if (!"Driver" %in% names(vif_df)) {
      cat("[WARN] KD_HTML_TRANSFORM: VIF data frame missing 'Driver' column\n")
      return(NULL)
    }
    if (!"VIF" %in% names(vif_df)) {
      cat("[WARN] KD_HTML_TRANSFORM: VIF data frame missing 'VIF' column\n")
      return(NULL)
    }
  } else {
    return(NULL)
  }

  # Add concern classification
  vif_df$Concern <- vapply(vif_df$VIF, function(v) {
    if (is.na(v)) return("N/A")
    if (v > 10) return("High")
    if (v > 5)  return("Moderate")
    "None"
  }, character(1))

  vif_df
}


#' Check if an Insight is Redundant
#'
#' Simple heuristic to avoid duplicating insights when the executive summary
#' already contains a similar finding.
#'
#' @param existing Character vector of existing insights.
#' @param keyword Character string to look for (driver name, etc.).
#' @param pattern Character string pattern (e.g., "dominant", "top tier").
#' @return Logical, TRUE if redundant.
#' @keywords internal
.kd_insight_redundant <- function(existing, keyword, pattern) {
  if (length(existing) == 0) return(FALSE)
  any(grepl(keyword, existing, fixed = TRUE) & grepl(pattern, existing, fixed = TRUE))
}


# ==============================================================================
# NULL-COALESCING OPERATOR (guarded)
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
