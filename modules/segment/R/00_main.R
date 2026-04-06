# ==============================================================================
# SEGMENT MODULE - MAIN ORCHESTRATOR
# ==============================================================================
# Step-function orchestrator for the Turas Segmentation module.
# Follows the catdriver/keydriver pattern: steps are sequential,
# guard state is threaded through, PARTIAL status tracks degradation.
#
# Entry point: turas_segment_from_config(config_file)
#
# Pipeline:
#   STEP 1: Load & validate configuration
#   STEP 2: Load & prepare data
#   STEP 3: Run hard guards
#   STEP 4: Clustering (kmeans / hclust / gmm)
#   STEP 5: Validation metrics
#   STEP 6: Profiling & enhanced features
#   STEP 7: Output (Excel + segment assignments + HTML report)
#
# Version: 11.0
# ==============================================================================


# ==============================================================================
# LOAD DEPENDENCIES
# ==============================================================================

# Get Turas root
turas_root <- Sys.getenv("TURAS_ROOT", getwd())

# Null coalescing operator (if not already defined)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

# TRS Infrastructure (shared)
tryCatch({
  source(file.path(turas_root, "modules/shared/lib/trs_run_state.R"))
  source(file.path(turas_root, "modules/shared/lib/trs_banner.R"))
  source(file.path(turas_root, "modules/shared/lib/trs_run_status_writer.R"))
  source(file.path(turas_root, "modules/shared/lib/turas_log.R"))
  source(file.path(turas_root, "modules/shared/lib/turas_save_workbook_atomic.R"))
  source(file.path(turas_root, "modules/shared/lib/turas_excel_escape.R"))
  source(file.path(turas_root, "modules/shared/lib/stats_pack_writer.R"))
}, error = function(e) {
  message(sprintf("[TRS INFO] SEG_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# Shared utilities
source(file.path(turas_root, "modules/shared/lib/validation_utils.R"))
source(file.path(turas_root, "modules/shared/lib/config_utils.R"))
source(file.path(turas_root, "modules/shared/lib/data_utils.R"))
source(file.path(turas_root, "modules/shared/lib/logging_utils.R"))
source(file.path(turas_root, "modules/shared/lib/formatting_utils.R"))

# Segment module files (R/ directory)
.seg_r_dir <- file.path(turas_root, "modules/segment/R")

source(file.path(.seg_r_dir, "00_guard.R"))
source(file.path(.seg_r_dir, "00a_guards_hard.R"))
source(file.path(.seg_r_dir, "00b_guards_soft.R"))
source(file.path(.seg_r_dir, "01_config.R"))
source(file.path(.seg_r_dir, "02_data_prep.R"))
source(file.path(.seg_r_dir, "02a_variable_selection.R"))
source(file.path(.seg_r_dir, "02b_outliers.R"))
source(file.path(.seg_r_dir, "03_clustering.R"))
source(file.path(.seg_r_dir, "03a_kmeans.R"))
source(file.path(.seg_r_dir, "03b_hclust.R"))
source(file.path(.seg_r_dir, "03c_gmm.R"))
source(file.path(.seg_r_dir, "04_validation.R"))
source(file.path(.seg_r_dir, "05_profiling.R"))
source(file.path(.seg_r_dir, "05a_profiling_stats.R"))
source(file.path(.seg_r_dir, "06_rules.R"))
source(file.path(.seg_r_dir, "07_cards.R"))
source(file.path(.seg_r_dir, "08_scoring.R"))
source(file.path(.seg_r_dir, "09_output.R"))
source(file.path(.seg_r_dir, "09a_excel_styles.R"))
source(file.path(.seg_r_dir, "10_utilities.R"))
source(file.path(.seg_r_dir, "11_lca.R"))
source(file.path(.seg_r_dir, "12_executive_summary.R"))
source(file.path(.seg_r_dir, "13_vulnerability.R"))
source(file.path(.seg_r_dir, "14_ensemble.R"))

# Preflight validators
.seg_validation_dir <- file.path(turas_root, "modules/segment/lib/validation")
if (file.exists(file.path(.seg_validation_dir, "preflight_validators.R"))) {
  source(file.path(.seg_validation_dir, "preflight_validators.R"))
}

# HTML report pipeline (optional - check if files exist)
.seg_html_dir <- file.path(turas_root, "modules/segment/lib/html_report")
.seg_html_available <- file.exists(file.path(.seg_html_dir, "99_html_report_main.R"))

if (.seg_html_available) {
  tryCatch({
    source(file.path(.seg_html_dir, "99_html_report_main.R"))
    cat("[SEGMENT] HTML report pipeline loaded\n")
  }, error = function(e) {
    .seg_html_available <<- FALSE
    cat(sprintf("[SEGMENT] HTML report pipeline not available: %s\n", e$message))
  })
}


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Segmentation Analysis from Configuration File
#'
#' Main entry point for the Turas segmentation module.
#' Supports K-means, hierarchical clustering, and GMM methods.
#' Automatically detects exploration vs final mode from config.
#'
#' @param config_file Character, path to segmentation config Excel file
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return List with segmentation results
#' @export
turas_segment_from_config <- function(config_file, verbose = TRUE) {
  segment_with_refusal_handler({
    turas_segment_impl(config_file, verbose)
  })
}


#' Internal Segmentation Implementation
#'
#' Called by turas_segment_from_config() inside refusal handler.
#'
#' @param config_file Path to config file
#' @param verbose Print progress
#' @return Results list
#' @keywords internal
turas_segment_impl <- function(config_file, verbose = TRUE) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION
  # ==========================================================================

  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("SEGMENT")
  } else {
    NULL
  }

  if (exists("turas_print_start_banner", mode = "function")) {
    turas_print_start_banner("SEGMENT", SEGMENT_VERSION)
  }

  start_time <- Sys.time()

  cat(sprintf("Configuration file: %s\n", basename(config_file)))
  cat(sprintf("Start time: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("Module version: %s\n\n", SEGMENT_VERSION))

  # ==========================================================================
  # STEP 1: CONFIGURATION
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(1, "Loading & validating configuration")
  } else {
    cat("STEP 1: CONFIGURATION\n")
  }

  config_raw <- read_segment_config(config_file)
  config <- validate_segment_config(config_raw)

  # Set seed for reproducibility
  seed_used <- set_segmentation_seed(config)

  # ==========================================================================
  # STEP 2: DATA PREPARATION
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(2, "Loading & preparing data")
  } else {
    cat("\nSTEP 2: DATA PREPARATION\n")
  }

  data_list <- prepare_segment_data(config)

  # ==========================================================================
  # STEP 3: PRE-ANALYSIS VALIDATION
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(3, "Running validation checks")
  } else {
    cat("\nSTEP 3: VALIDATION\n")
  }

  # Preflight cross-referential validation (if available)
  if (exists("validate_segment_preflight", mode = "function")) {
    preflight_log <- validate_segment_preflight(config, data_list$data)
    n_preflight_errors <- sum(preflight_log$Severity == "Error")
    if (n_preflight_errors > 0) {
      error_details <- preflight_log[preflight_log$Severity == "Error", ]
      segment_refuse(
        code = "CFG_PREFLIGHT_FAILED",
        title = "Preflight Validation Failed",
        problem = sprintf("%d configuration error(s) detected before analysis.", n_preflight_errors),
        why_it_matters = "Analysis cannot proceed with invalid configuration or data.",
        how_to_fix = paste(error_details$Description, collapse = "\n"),
        details = error_details
      )
    }
  }

  # Guard orchestrator: hard guards + data quality soft guards
  guard <- segment_guard_pre_analysis(config, data_list)

  cat("  All validation checks passed\n")

  # ==========================================================================
  # STEP 4: CLUSTERING
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(4, sprintf("Running %s clustering", toupper(config$method)))
  } else {
    cat(sprintf("\nSTEP 4: CLUSTERING (%s)\n", toupper(config$method)))
  }

  if (config$mode == "exploration") {
    return(run_exploration_pipeline(data_list, config, guard, trs_state, start_time, config_file))
  }

  # Multi-method mode: run each method and produce combined report
  if (isTRUE(config$is_multi_method) && config$mode == "final") {
    return(run_multi_method_pipeline(data_list, config, guard, trs_state, start_time, config_file))
  }

  # Final mode
  cluster_result <- run_clustering(data_list, config, guard)

  # ==========================================================================
  # STEP 5: VALIDATION METRICS
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(5, "Calculating validation metrics")
  } else {
    cat("\nSTEP 5: VALIDATION METRICS\n")
  }

  validation_metrics <- calculate_validation_metrics(
    data = data_list$scaled_data,
    model = cluster_result$model,
    k = cluster_result$k,
    clusters = cluster_result$clusters,
    calculate_gap = FALSE
  )

  # Post-clustering guard orchestrator
  guard <- segment_guard_post_clustering(guard, cluster_result, validation_metrics, config)

  cat(sprintf("  Average silhouette: %.3f\n", validation_metrics$avg_silhouette))
  cat(sprintf("  Between/Total SS: %.3f\n", validation_metrics$betweenss_totss))

  # ==========================================================================
  # STEP 6: PROFILING & ENHANCED FEATURES
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(6, "Building segment profiles")
  } else {
    cat("\nSTEP 6: PROFILING\n")
  }

  # Segment names — priority: names file > auto-generate > config
  if (!is.null(config$segment_names_file)) {
    # Step 3 workflow: read edited names from Excel
    file_names <- read_segment_names_from_file(config$segment_names_file, cluster_result$k)
    if (!is.null(file_names) && length(file_names) == cluster_result$k) {
      segment_names <- file_names
    } else {
      cat("  Falling back to auto-generated names\n")
      segment_names <- generate_segment_names(
        k = cluster_result$k,
        method = config$auto_name_style %||% "simple",
        data = data_list$data,
        clusters = cluster_result$clusters,
        clustering_vars = data_list$config$clustering_vars,
        question_labels = config$question_labels,
        scale_max = config$scale_max %||% 10
      )
    }
  } else if (identical(config$segment_names, "auto")) {
    segment_names <- generate_segment_names(
      k = cluster_result$k,
      method = config$auto_name_style %||% "simple",
      data = data_list$data,
      clusters = cluster_result$clusters,
      clustering_vars = data_list$config$clustering_vars,
      question_labels = config$question_labels,
      scale_max = config$scale_max %||% 10
    )
  } else {
    segment_names <- config$segment_names
  }

  # Core profiles
  profile_result <- create_full_segment_profile(
    data = data_list$data,
    clusters = cluster_result$clusters,
    clustering_vars = data_list$config$clustering_vars,
    profile_vars = data_list$config$profile_vars
  )

  # Enhanced features (optional, with tryCatch)
  enhanced <- list()

  # Classification rules
  if (config$generate_rules) {
    enhanced$rules <- tryCatch({
      cat("  Generating classification rules...\n")
      generate_segment_rules(
        data = data_list$data,
        clusters = cluster_result$clusters,
        clustering_vars = data_list$config$clustering_vars,
        question_labels = config$question_labels,
        max_depth = config$rules_max_depth,
        segment_names = segment_names
      )
    }, error = function(e) {
      guard <<- guard_warn(guard, paste("Rules generation failed:", e$message), "rules")
      NULL
    })
  }

  # Segment cards
  if (config$generate_action_cards) {
    enhanced$cards <- tryCatch({
      cat("  Generating segment action cards...\n")
      generate_segment_cards(
        data = data_list$data,
        clusters = cluster_result$clusters,
        clustering_vars = data_list$config$clustering_vars,
        segment_names = segment_names,
        question_labels = config$question_labels,
        scale_max = config$scale_max
      )
    }, error = function(e) {
      guard <<- guard_warn(guard, paste("Card generation failed:", e$message), "cards")
      NULL
    })
  }

  # Stability check
  if (config$run_stability_check) {
    enhanced$stability <- tryCatch({
      cat("  Running stability assessment...\n")
      run_stability_check(
        data = data_list$scaled_data,
        k = cluster_result$k,
        method = config$method,
        n_runs = config$stability_n_runs,
        config = config
      )
    }, error = function(e) {
      guard <<- guard_warn(guard, paste("Stability check failed:", e$message), "stability")
      NULL
    })
  }

  # GMM membership probabilities
  gmm_membership <- NULL
  if (config$method == "gmm" && !is.null(cluster_result$method_info$probabilities)) {
    gmm_membership <- summarize_gmm_membership(
      probabilities = cluster_result$method_info$probabilities,
      uncertainty = cluster_result$method_info$uncertainty,
      segment_names = segment_names
    )
  }

  # Vulnerability / switching analysis
  vulnerability <- tryCatch({
    cat("  Running vulnerability analysis...\n")
    vuln <- calculate_vulnerability(
      data = data_list$scaled_data,
      clusters = cluster_result$clusters,
      centers = cluster_result$centers,
      method = config$method,
      probabilities = cluster_result$method_info$probabilities
    )
    format_vulnerability_summary(vuln, segment_names)
    vuln
  }, error = function(e) {
    guard <<- guard_warn(guard, paste("Vulnerability analysis failed:", e$message), "vulnerability")
    NULL
  })

  # Golden questions (Random Forest variable importance)
  golden_questions <- tryCatch({
    if (exists("identify_golden_questions", mode = "function")) {
      cat("  Identifying golden questions...\n")
      gq <- identify_golden_questions(
        data = data_list$clustering_data %||% data_list$data[, config$clustering_vars, drop = FALSE],
        clusters = cluster_result$clusters,
        segment_names = segment_names,
        n_top = config$golden_questions_n %||% 5,
        n_trees = config$golden_questions_trees %||% 500
      )
      if (gq$status == "SKIPPED") {
        cat(sprintf("    Skipped: %s\n", gq$message))
        NULL
      } else if (gq$status == "PARTIAL") {
        cat(sprintf("    Partial: %s\n", gq$message %||% ""))
        gq
      } else {
        gq
      }
    } else {
      NULL
    }
  }, error = function(e) {
    guard <<- guard_warn(guard, paste("Golden questions failed:", e$message), "golden_questions")
    NULL
  })

  # Executive summary
  exec_summary <- tryCatch({
    generate_segment_executive_summary(
      cluster_result = cluster_result,
      validation_metrics = validation_metrics,
      profile_result = profile_result,
      segment_names = segment_names,
      config = config,
      enhanced = enhanced
    )
  }, error = function(e) {
    guard <<- guard_warn(guard, paste("Executive summary failed:", e$message), "exec_summary")
    NULL
  })

  # ==========================================================================
  # STEP 7: OUTPUT
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(7, "Generating outputs")
  } else {
    cat("\nSTEP 7: OUTPUT\n")
  }

  # Determine run status
  run_status <- segment_determine_status(guard,
    clusters_created = cluster_result$k,
    cases_assigned = length(cluster_result$clusters),
    silhouette_score = validation_metrics$avg_silhouette)

  # TRS run state
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    if (identical(run_status$run_status, "PARTIAL") && exists("turas_run_state_partial", mode = "function")) {
      for (reason in run_status$degraded_reasons %||% character(0)) {
        turas_run_state_partial(
          trs_state,
          code = "QUALITY_DEGRADED",
          title = "Quality Degradation",
          problem = reason
        )
      }
    }
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  # Create output folder
  output_folder <- create_output_folder(config$output_folder, config$create_dated_folder)

  # Export segment assignments (Excel with ID + segment columns)
  assignments_filename <- paste0(config$output_prefix, "segment_assignments.xlsx")
  assignments_path <- file.path(output_folder, assignments_filename)

  export_segment_assignments(
    data = data_list$data,
    clusters = cluster_result$clusters,
    segment_names = segment_names,
    id_var = config$id_variable,
    output_path = assignments_path,
    outlier_flags = data_list$outlier_flags,
    probabilities = cluster_result$method_info$probabilities
  )

  # Export full report (Excel)
  report_filename <- paste0(config$output_prefix, "segmentation_report.xlsx")
  report_path <- file.path(output_folder, report_filename)

  # Augment cluster result with data_list for report export
  final_result_for_export <- cluster_result
  final_result_for_export$data_list <- data_list

  export_final_report(
    final_result = final_result_for_export,
    profile_result = profile_result,
    validation_metrics = validation_metrics,
    output_path = report_path,
    run_result = run_result,
    enhanced = enhanced,
    segment_names = segment_names,
    exec_summary = exec_summary,
    gmm_membership = gmm_membership,
    run_status_details = run_status,
    guard_summary = segment_guard_summary(guard)
  )

  # Save model object
  model_path <- NULL
  if (config$save_model) {
    model_filename <- paste0(config$output_prefix, "model.rds")
    model_path <- file.path(output_folder, model_filename)

    model_object <- list(
      model = cluster_result$model,
      k = cluster_result$k,
      clusters = cluster_result$clusters,
      centers = cluster_result$centers,
      method = cluster_result$method,
      segment_names = segment_names,
      clustering_vars = data_list$config$clustering_vars,
      id_variable = config$id_variable,
      scale_params = data_list$scale_params,
      imputation_params = data_list$imputation_params,
      original_distribution = table(cluster_result$clusters),
      seed = seed_used,
      config = data_list$config,
      timestamp = Sys.time(),
      turas_version = SEGMENT_VERSION
    )

    saveRDS(model_object, model_path)
    cat(sprintf("  Model saved: %s\n", basename(model_path)))
  }

  # HTML report (optional)
  html_path <- NULL
  if (config$html_report && .seg_html_available) {
    html_filename <- paste0(config$output_prefix, "segmentation_report.html")
    html_path <- file.path(output_folder, html_filename)

    cat("  Generating HTML report...\n")
    html_result <- tryCatch({
      generate_segment_html_report(
        results = list(
          mode = "final",
          cluster_result = cluster_result,
          validation_metrics = validation_metrics,
          profile_result = profile_result,
          segment_names = segment_names,
          enhanced = enhanced,
          exec_summary = exec_summary,
          gmm_membership = gmm_membership,
          vulnerability = vulnerability,
          golden_questions = golden_questions,
          data_list = data_list
        ),
        config = config,
        output_path = html_path
      )
    }, error = function(e) {
      cat(sprintf("  [WARNING] HTML report generation failed: %s\n", e$message))
      guard <<- guard_warn(guard, paste("HTML report failed:", e$message), "html")
      NULL
    })

    if (!is.null(html_result)) {
      cat(sprintf("  HTML report: %s (%.1f MB)\n", basename(html_path),
                  html_result$file_size_mb %||% 0))

      # Minify for client delivery (if requested via Shiny checkbox)
      if (exists("turas_prepare_deliverable", mode = "function")) {
        turas_prepare_deliverable(html_path)
      }
    }
  } else if (config$html_report && !.seg_html_available) {
    cat("  [WARNING] HTML report requested but pipeline not available\n")
  }

  # ==========================================================================
  # STATS PACK (Optional)
  # ==========================================================================
  generate_stats_pack_flag <- isTRUE(
    toupper(config$generate_stats_pack %||% "Y") == "Y"
  ) || isTRUE(getOption("turas.generate_stats_pack", FALSE))

  if (generate_stats_pack_flag) {
    cat("  Generating stats pack...\n")
    generate_segment_stats_pack(
      config            = config,
      data_list         = data_list,
      cluster_result    = cluster_result,
      validation_metrics = validation_metrics,
      seed_used         = seed_used,
      run_result        = run_result,
      output_folder     = output_folder,
      start_time        = start_time
    )
  }

  # ==========================================================================
  # COMPLETION
  # ==========================================================================

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  cat(sprintf("\n  Analysis complete in %s\n", format_seconds(elapsed)))
  cat("\n  Outputs:\n")
  cat(sprintf("    Segment assignments: %s\n", basename(assignments_path)))
  cat(sprintf("    Full report: %s\n", basename(report_path)))
  if (!is.null(model_path)) cat(sprintf("    Model object: %s\n", basename(model_path)))
  if (!is.null(html_path)) cat(sprintf("    HTML report: %s\n", basename(html_path)))

  cat(sprintf("\n  Summary: %d segments | %d respondents | silhouette %.3f | method %s\n",
              cluster_result$k, length(cluster_result$clusters),
              validation_metrics$avg_silhouette, toupper(config$method)))

  # TRS final banner
  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  }

  # Return results
  invisible(list(
    mode = "final",
    status = run_status$run_status %||% "PASS",
    k = cluster_result$k,
    method = config$method,
    model = cluster_result$model,
    clusters = cluster_result$clusters,
    centers = cluster_result$centers,
    segment_names = segment_names,
    validation = validation_metrics,
    profiles = profile_result,
    enhanced = enhanced,
    exec_summary = exec_summary,
    gmm_membership = gmm_membership,
    vulnerability = vulnerability,
    golden_questions = golden_questions,
    output_files = list(
      assignments = assignments_path,
      report = report_path,
      model = model_path,
      html = html_path
    ),
    config = config,
    run_result = run_result,
    guard_summary = segment_guard_summary(guard)
  ))
}


# ==============================================================================
# EXPLORATION PIPELINE
# ==============================================================================

#' Run Exploration Mode Pipeline
#'
#' Tests multiple k values and generates comparison report.
#'
#' @keywords internal
run_exploration_pipeline <- function(data_list, config, guard, trs_state, start_time, config_file) {

  cat(sprintf("\n  Mode: EXPLORATION (k = %d to %d, method = %s)\n",
              config$k_min, config$k_max, toupper(config$method)))

  # Run clustering for multiple k values
  exploration_result <- run_clustering_exploration(data_list, config, guard)

  # Calculate metrics for each k
  metrics_result <- calculate_exploration_metrics(exploration_result)

  # Recommend optimal k
  recommendation <- recommend_k(metrics_result$metrics_df, config$min_segment_size_pct)

  # TRS run state
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  # Create output
  output_folder <- create_output_folder(config$output_folder, config$create_dated_folder)
  report_filename <- paste0(config$output_prefix, "k_selection_report.xlsx")
  report_path <- file.path(output_folder, report_filename)

  export_exploration_report(
    exploration_result = exploration_result,
    metrics_result = metrics_result,
    recommendation = recommendation,
    output_path = report_path,
    run_result = run_result
  )

  # HTML exploration report (optional)
  html_path <- NULL
  if (config$html_report && .seg_html_available) {
    html_filename <- paste0(config$output_prefix, "k_selection_report.html")
    html_path <- file.path(output_folder, html_filename)

    html_result <- tryCatch({
      generate_segment_html_report(
        results = list(
          mode = "exploration",
          exploration_result = exploration_result,
          metrics_result = metrics_result,
          recommendation = recommendation,
          data_list = data_list
        ),
        config = config,
        output_path = html_path
      )
    }, error = function(e) {
      cat(sprintf("  [WARNING] HTML exploration report failed: %s\n", e$message))
      NULL
    })

    if (!is.null(html_result) && exists("turas_prepare_deliverable", mode = "function")) {
      turas_prepare_deliverable(html_path)
    }
  }

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  cat(sprintf("\n  Analysis complete in %s\n", format_seconds(elapsed)))
  cat(sprintf("\n  Recommended k: %d\n", recommendation$recommended_k))
  cat(sprintf("  Next: set k_fixed = %d in your config and re-run\n", recommendation$recommended_k))

  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  }

  invisible(list(
    mode = "exploration",
    method = config$method,
    recommendation = recommendation,
    metrics = metrics_result,
    models = exploration_result$results,
    output_files = list(
      report = report_path,
      html = html_path
    ),
    config = config,
    run_result = run_result
  ))
}


# ==============================================================================
# MULTI-METHOD PIPELINE
# ==============================================================================

#' Run Multi-Method Pipeline
#'
#' Runs multiple clustering algorithms on the same data and produces
#' a combined comparison report with tabs.
#'
#' @keywords internal
run_multi_method_pipeline <- function(data_list, config, guard, trs_state, start_time, config_file) {

  methods <- config$methods
  cat(sprintf("\n  Multi-method mode: running %s\n", paste(toupper(methods), collapse = ", ")))

  method_results <- list()

  for (m in methods) {
    cat(sprintf("\n  ── Method: %s ──\n", toupper(m)))

    # Create method-specific config
    method_config <- config
    method_config$method <- m
    method_config$is_multi_method <- FALSE  # prevent recursion

    # Run clustering
    cluster_result <- tryCatch({
      run_clustering(data_list, method_config, guard)
    }, error = function(e) {
      cat(sprintf("    FAILED: %s\n", e$message))
      NULL
    })

    if (is.null(cluster_result)) {
      cat(sprintf("    Skipping %s (clustering failed)\n", toupper(m)))
      next
    }

    # Validation metrics
    validation_metrics <- tryCatch({
      calculate_validation_metrics(
        data = data_list$scaled_data,
        model = cluster_result$model,
        k = cluster_result$k,
        clusters = cluster_result$clusters,
        calculate_gap = FALSE
      )
    }, error = function(e) {
      cat(sprintf("    Warning: validation failed for %s: %s\n", m, e$message))
      list(avg_silhouette = NA, betweenss_totss = NA, tot_withinss = NA)
    })

    # Segment names
    segment_names <- generate_segment_names(cluster_result$k,
      method = config$auto_name_style %||% "simple")

    # Profiles
    profile_result <- tryCatch({
      create_full_segment_profile(
        data = data_list$data,
        clusters = cluster_result$clusters,
        clustering_vars = data_list$config$clustering_vars,
        profile_vars = data_list$config$profile_vars
      )
    }, error = function(e) {
      cat(sprintf("    Warning: profiling failed for %s: %s\n", m, e$message))
      NULL
    })

    # Vulnerability analysis
    vulnerability <- tryCatch({
      if (exists("calculate_vulnerability", mode = "function")) {
        calculate_vulnerability(
          data = data_list$scaled_data,
          clusters = cluster_result$clusters,
          centers = cluster_result$centers,
          method = m,
          probabilities = cluster_result$method_info$probabilities
        )
      } else {
        NULL
      }
    }, error = function(e) {
      cat(sprintf("    Warning: vulnerability analysis failed for %s: %s\n", m, e$message))
      NULL
    })

    # Enhanced features
    enhanced <- list()

    if (config$generate_rules) {
      enhanced$rules <- tryCatch({
        generate_segment_rules(
          data = data_list$data,
          clusters = cluster_result$clusters,
          clustering_vars = data_list$config$clustering_vars,
          question_labels = config$question_labels,
          max_depth = config$rules_max_depth,
          segment_names = segment_names
        )
      }, error = function(e) NULL)
    }

    if (config$generate_action_cards) {
      enhanced$cards <- tryCatch({
        generate_segment_cards(
          data = data_list$data,
          clusters = cluster_result$clusters,
          clustering_vars = data_list$config$clustering_vars,
          segment_names = segment_names,
          question_labels = config$question_labels,
          scale_max = config$scale_max
        )
      }, error = function(e) NULL)
    }

    # GMM membership
    gmm_membership <- NULL
    if (m == "gmm" && !is.null(cluster_result$method_info$probabilities)) {
      gmm_membership <- tryCatch({
        summarize_gmm_membership(
          probabilities = cluster_result$method_info$probabilities,
          uncertainty = cluster_result$method_info$uncertainty,
          segment_names = segment_names
        )
      }, error = function(e) NULL)
    }

    # Executive summary
    exec_summary <- tryCatch({
      generate_segment_executive_summary(
        cluster_result = cluster_result,
        validation_metrics = validation_metrics,
        profile_result = profile_result,
        segment_names = segment_names,
        config = method_config,
        enhanced = enhanced
      )
    }, error = function(e) NULL)

    cat(sprintf("    Silhouette: %.3f | BSS/TSS: %.3f\n",
                validation_metrics$avg_silhouette %||% 0,
                validation_metrics$betweenss_totss %||% 0))

    method_results[[m]] <- list(
      method = m,
      cluster_result = cluster_result,
      validation_metrics = validation_metrics,
      profile_result = profile_result,
      segment_names = segment_names,
      enhanced = enhanced,
      exec_summary = exec_summary,
      gmm_membership = gmm_membership,
      vulnerability = vulnerability
    )
  }

  if (length(method_results) == 0) {
    segment_refuse(
      code = "MODEL_ALL_METHODS_FAILED",
      title = "All Clustering Methods Failed",
      problem = "No clustering method produced valid results.",
      why_it_matters = "Cannot generate a comparison report without at least one successful method.",
      how_to_fix = "Check your data quality and try individual methods to diagnose the issue."
    )
  }

  # ==========================================================================
  # OUTPUT
  # ==========================================================================

  if (exists("turas_step", mode = "function")) {
    turas_step(7, "Generating multi-method outputs")
  } else {
    cat("\nSTEP 7: MULTI-METHOD OUTPUT\n")
  }

  # Determine run status using first successful method
  first_result <- method_results[[1]]
  run_status <- segment_determine_status(guard,
    clusters_created = first_result$cluster_result$k,
    cases_assigned = length(first_result$cluster_result$clusters),
    silhouette_score = first_result$validation_metrics$avg_silhouette)

  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  output_folder <- create_output_folder(config$output_folder, config$create_dated_folder)

  # Export per-method assignments and reports
  for (m_name in names(method_results)) {
    mr <- method_results[[m_name]]

    # Segment assignments
    assignments_path <- file.path(output_folder,
      paste0(config$output_prefix, m_name, "_assignments.xlsx"))
    tryCatch({
      export_segment_assignments(
        data = data_list$data,
        clusters = mr$cluster_result$clusters,
        segment_names = mr$segment_names,
        id_var = config$id_variable,
        output_path = assignments_path,
        outlier_flags = data_list$outlier_flags,
        probabilities = mr$cluster_result$method_info$probabilities
      )
    }, error = function(e) {
      cat(sprintf("    Warning: assignments export failed for %s: %s\n", m_name, e$message))
    })

    # Save model
    if (config$save_model) {
      model_path <- file.path(output_folder,
        paste0(config$output_prefix, m_name, "_model.rds"))
      model_object <- list(
        model = mr$cluster_result$model,
        k = mr$cluster_result$k,
        clusters = mr$cluster_result$clusters,
        centers = mr$cluster_result$centers,
        method = mr$cluster_result$method,
        segment_names = mr$segment_names,
        clustering_vars = data_list$config$clustering_vars,
        id_variable = config$id_variable,
        scale_params = data_list$scale_params,
        timestamp = Sys.time(),
        turas_version = SEGMENT_VERSION
      )
      saveRDS(model_object, model_path)
      cat(sprintf("    Model saved: %s\n", basename(model_path)))
    }
  }

  # Combined HTML report
  html_path <- NULL
  if (config$html_report && .seg_html_available) {
    html_filename <- paste0(config$output_prefix, "combined_report.html")
    html_path <- file.path(output_folder, html_filename)

    cat("  Generating combined multi-method HTML report...\n")
    html_result <- tryCatch({
      generate_segment_html_report(
        results = list(
          mode = "combined",
          method_results = method_results,
          methods = names(method_results),
          data_list = data_list
        ),
        config = config,
        output_path = html_path
      )
    }, error = function(e) {
      cat(sprintf("  [WARNING] Combined HTML report failed: %s\n", e$message))
      NULL
    })

    if (!is.null(html_result)) {
      cat(sprintf("  Combined HTML report: %s (%.1f MB)\n", basename(html_path),
                  html_result$file_size_mb %||% 0))

      # Minify for client delivery (if requested via Shiny checkbox)
      if (exists("turas_prepare_deliverable", mode = "function")) {
        turas_prepare_deliverable(html_path)
      }
    }
  }

  # Completion
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  cat(sprintf("\n  Multi-method analysis complete in %s\n", format_seconds(elapsed)))
  cat(sprintf("  Methods: %s\n", paste(toupper(names(method_results)), collapse = ", ")))

  # Comparison summary
  cat("\n  Method Comparison:\n")
  cat(sprintf("  %-12s  %10s  %10s\n", "Method", "Silhouette", "BSS/TSS"))
  cat(sprintf("  %-12s  %10s  %10s\n", "------", "----------", "-------"))
  for (m_name in names(method_results)) {
    mr <- method_results[[m_name]]
    cat(sprintf("  %-12s  %10.3f  %10.3f\n",
                toupper(m_name),
                mr$validation_metrics$avg_silhouette %||% 0,
                mr$validation_metrics$betweenss_totss %||% 0))
  }

  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  }

  invisible(list(
    mode = "combined",
    status = run_status$run_status %||% "PASS",
    methods = names(method_results),
    method_results = method_results,
    output_files = list(
      html = html_path,
      folder = output_folder
    ),
    config = config,
    run_result = run_result,
    guard_summary = segment_guard_summary(guard)
  ))
}


# ==============================================================================
# STATS PACK HELPER
# ==============================================================================

#' Generate Segment Stats Pack
#'
#' Builds the diagnostic payload from segmentation results and writes
#' the stats pack Excel workbook alongside the main outputs.
#'
#' @keywords internal
generate_segment_stats_pack <- function(config, data_list, cluster_result,
                                        validation_metrics, seed_used,
                                        run_result, output_folder, start_time) {

  if (!exists("turas_write_stats_pack", mode = "function")) {
    cat("  ! Stats pack writer not loaded - skipping\n")
    return(invisible(NULL))
  }

  output_path <- file.path(
    output_folder,
    paste0(config$output_prefix %||% "", "stats_pack.xlsx")
  )

  # Variables used
  n_vars <- length(data_list$config$clustering_vars %||% character(0))

  # Excluded respondents (outlier flags are logical; TRUE = excluded)
  outlier_flags <- data_list$outlier_flags %||% logical(0)
  n_excluded    <- sum(outlier_flags, na.rm = TRUE)
  n_valid       <- nrow(data_list$data)
  n_raw         <- n_valid + n_excluded

  # TRS execution summary
  n_events   <- length(run_result$events %||% list())
  n_refusals <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "REFUSE"), logical(1)))
  n_partials <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "PARTIAL"), logical(1)))
  trs_summary <- if (n_events == 0) {
    "No events — ran cleanly"
  } else {
    parts <- character(0)
    if (n_refusals > 0) parts <- c(parts, sprintf("%d refusal(s)", n_refusals))
    if (n_partials > 0) parts <- c(parts, sprintf("%d partial(s)", n_partials))
    remainder <- n_events - n_refusals - n_partials
    if (remainder  > 0) parts <- c(parts, sprintf("%d info event(s)", remainder))
    paste(parts, collapse = ", ")
  }

  assumptions <- list(
    "Clustering Method"       = config$method %||% "kmeans",
    "k (segments)"            = as.character(cluster_result$k),
    "nstart"                  = as.character(config$nstart %||% 25),
    "Seed"                    = as.character(seed_used %||% "random"),
    "Variables used"          = as.character(n_vars),
    "Standardization"         = if (isTRUE(config$standardize)) "Yes" else "No",
    "Missing data handling"   = config$missing_method %||% config$imputation_method %||% "listwise",
    "Implementation"          = "base R kmeans() / hclust()",
    "TRS Status"              = run_result$status %||% "PASS",
    "TRS Events"              = trs_summary
  )

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  payload <- list(
    module           = "SEGMENT",
    project_name     = config$project_name %||% NULL,
    analyst_name     = config$analyst_name %||% NULL,
    research_house   = config$research_house %||% NULL,
    run_timestamp    = start_time,
    turas_version    = SEGMENT_VERSION,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = duration_secs,
    data_receipt     = list(
      file_name           = basename(config$data_file %||% "unknown"),
      n_rows              = n_raw,
      n_cols              = ncol(data_list$data),
      questions_in_config = n_vars
    ),
    data_used        = list(
      n_respondents = n_valid,
      n_excluded    = n_excluded,
      n_variables   = n_vars,
      k_final       = cluster_result$k
    ),
    assumptions      = assumptions,
    seeds            = list("k-means / clustering" = as.character(seed_used %||% "random")),
    run_result       = run_result,
    packages         = c("openxlsx", "data.table"),
    config_echo      = list(settings = config[c("method", "k", "k_min", "k_max",
                                                  "nstart", "standardize",
                                                  "missing_method", "output_folder",
                                                  "project_name", "data_file")])
  )

  result <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result)) {
    cat(sprintf("  Stats pack written: %s\n", basename(output_path)))
  }

  invisible(result)
}
