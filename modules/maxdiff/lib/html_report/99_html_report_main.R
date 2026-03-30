# ==============================================================================
# MAXDIFF HTML REPORT - MAIN ORCHESTRATOR - TURAS V11.2
# ==============================================================================
# Entry point for MaxDiff HTML report generation
# Sources the 4-layer pipeline and pipes data through to produce a
# self-contained HTML report file.
# ==============================================================================

MAXDIFF_HTML_REPORT_VERSION <- "11.2"

# Flag to prevent re-sourcing
.md_html_loaded <- FALSE

#' Source HTML report sub-modules
#'
#' @keywords internal
.md_load_report_submodules <- function() {

  if (.md_html_loaded) return(invisible(NULL))

  # Find html_report directory
  report_dir <- NULL

  # Method 1: Relative to this file
  for (i in seq_len(sys.nframe())) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(ofile) && is.character(ofile) && length(ofile) == 1) {
      candidate <- dirname(normalizePath(ofile, mustWork = FALSE))
      if (file.exists(file.path(candidate, "01_data_transformer.R"))) {
        report_dir <- candidate
        break
      }
    }
  }

  # Method 2: Common paths
  if (is.null(report_dir)) {
    candidates <- c(
      file.path(getwd(), "modules", "maxdiff", "lib", "html_report"),
      file.path(getwd(), "lib", "html_report")
    )
    if (exists("script_dir_override", envir = globalenv())) {
      sd <- get("script_dir_override", envir = globalenv())
      candidates <- c(
        file.path(sd, "..", "lib", "html_report"),
        file.path(dirname(sd), "lib", "html_report"),
        candidates
      )
    }
    for (c in candidates) {
      c <- normalizePath(c, mustWork = FALSE)
      if (file.exists(file.path(c, "01_data_transformer.R"))) {
        report_dir <- c
        break
      }
    }
  }

  if (is.null(report_dir)) {
    message("[TRS INFO] MAXD_HTML_DIR_NOT_FOUND: Could not locate html_report directory")
    return(invisible(NULL))
  }

  files <- c(
    "01_data_transformer.R",
    "02_table_builder.R",
    "04_chart_builder.R",
    "03_page_builder.R"
  )

  for (f in files) {
    fpath <- file.path(report_dir, f)
    if (file.exists(fpath)) {
      source(fpath, local = FALSE)
    } else {
      message(sprintf("[TRS INFO] MAXD_HTML_FILE_MISSING: %s not found", f))
    }
  }

  .md_html_loaded <<- TRUE
  invisible(NULL)
}


#' Load JS module for report interactivity
#'
#' @return Character string of JS code, or empty string
#' @keywords internal
.md_load_js_module <- function() {
  # Find JS file relative to this script
  js_paths <- c(
    file.path(getwd(), "modules", "maxdiff", "lib", "html_report", "js", "md_report.js"),
    file.path(getwd(), "lib", "html_report", "js", "md_report.js")
  )

  if (exists("script_dir_override", envir = globalenv())) {
    sd <- get("script_dir_override", envir = globalenv())
    js_paths <- c(
      file.path(sd, "..", "lib", "html_report", "js", "md_report.js"),
      file.path(dirname(sd), "lib", "html_report", "js", "md_report.js"),
      js_paths
    )
  }

  for (jp in js_paths) {
    jp <- normalizePath(jp, mustWork = FALSE)
    if (file.exists(jp)) {
      return(paste(readLines(jp, warn = FALSE), collapse = "\n"))
    }
  }

  message("[TRS INFO] MAXD_HTML_JS_NOT_FOUND: md_report.js not found, report will have limited interactivity")
  ""
}


#' Load pin wrapper JS module
#'
#' @return Character string of JS code, or empty string
#' @keywords internal
.md_load_pins_module <- function() {
  js_paths <- c(
    file.path(getwd(), "modules", "maxdiff", "lib", "html_report", "js", "md_pins.js"),
    file.path(getwd(), "lib", "html_report", "js", "md_pins.js")
  )

  if (exists("script_dir_override", envir = globalenv())) {
    sd <- get("script_dir_override", envir = globalenv())
    js_paths <- c(
      file.path(sd, "..", "lib", "html_report", "js", "md_pins.js"),
      file.path(dirname(sd), "lib", "html_report", "js", "md_pins.js"),
      js_paths
    )
  }

  for (jp in js_paths) {
    jp <- normalizePath(jp, mustWork = FALSE)
    if (file.exists(jp)) {
      return(paste(readLines(jp, warn = FALSE), collapse = "\n"))
    }
  }

  message("[TRS INFO] MAXD_HTML_PINS_NOT_FOUND: md_pins.js not found, pinning will be limited")
  ""
}


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Generate MaxDiff HTML Report
#'
#' Produces a self-contained HTML report from MaxDiff analysis results.
#'
#' @param maxdiff_results List. Full results from run_maxdiff() analysis mode.
#'   Must contain count_scores, logit_results, and/or hb_results.
#' @param output_path Character. Path for the output HTML file.
#' @param config List. Module configuration (from load_maxdiff_config).
#' @param simulator_html Optional. Pre-built simulator HTML string for embedding.
#'
#' @return List with status, output_file, file_size_bytes
#'
#' @export
generate_maxdiff_html_report <- function(maxdiff_results, output_path, config,
                                         simulator_html = NULL) {

  # Source sub-modules
  .md_load_report_submodules()

  # Validate inputs
  if (is.null(maxdiff_results)) {
    cat("[TRS INFO] MAXD_HTML_NO_RESULTS: No results provided for HTML report\n")
    return(list(status = "REFUSED", message = "No results provided"))
  }

  if (is.null(output_path) || !nzchar(output_path)) {
    cat("[TRS INFO] MAXD_HTML_NO_PATH: No output path specified\n")
    return(list(status = "REFUSED", message = "No output path"))
  }

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Load shared pin library
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  pins_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!file.exists(pins_path)) pins_path <- file.path("modules", "shared", "lib", "turas_pins_js.R")
  if (!exists("turas_pins_js", mode = "function") && file.exists(pins_path)) {
    source(pins_path, local = FALSE)
  }

  # Load JS modules (shared lib + report JS + pin wrapper)
  shared_js <- if (exists("turas_pins_js", mode = "function")) turas_pins_js() else ""
  report_js <- .md_load_js_module()
  pins_js <- .md_load_pins_module()
  js_code <- paste(c(shared_js, report_js, pins_js), collapse = "\n\n")

  # --- Layer 1: Transform ---
  cat("  HTML Layer 1: Transforming data...\n")
  html_data <- tryCatch({
    transform_maxdiff_for_html(maxdiff_results, config)
  }, error = function(e) {
    cat(sprintf("  [TRS PARTIAL] MAXD_HTML_TRANSFORM_FAILED: %s\n", e$message))
    return(NULL)
  })

  if (is.null(html_data)) {
    cat("  HTML report REFUSED: Data transformation failed\n")
    return(list(status = "REFUSED", message = "Data transformation failed"))
  }

  brand <- html_data$meta$brand_colour %||% "#323367"

  # --- Layer 2: Tables ---
  tables <- list()

  # Extract segment data for per-segment table variants
  seg_scores <- if (!is.null(html_data$segment_filter)) html_data$segment_filter$segment_scores else NULL
  seg_config <- config$segment_settings

  # Enrich segment scores with preference shares & rescaled scores (from HB individual utilities)
  enriched_seg_scores <- seg_scores
  if (!is.null(seg_scores) && !is.null(maxdiff_results$hb_results$individual_utilities)) {
    enriched_seg_scores <- tryCatch(
      enrich_segment_scores(
        seg_scores,
        maxdiff_results$hb_results$individual_utilities,
        maxdiff_results$raw_data,
        seg_config,
        config$items
      ),
      error = function(e) {
        message(sprintf("  Segment enrichment warning: %s (falling back to basic tables)", e$message))
        seg_scores
      }
    )
  }

  # Add per-segment anchor rates to enriched data (for Must-Have % column in segment tables)
  # Uses Segment_Def expressions from seg_config to determine segment membership
  if (!is.null(enriched_seg_scores) && is.data.frame(enriched_seg_scores) &&
      !is.null(html_data$preferences$anchor_data) && !is.null(maxdiff_results$raw_data) &&
      is.data.frame(seg_config) && nrow(seg_config) > 0) {
    tryCatch({
      anchor_var <- config$output_settings$Anchor_Variable %||% NULL
      anchor_threshold_val <- as.numeric(config$output_settings$Anchor_Threshold %||% 0.50)
      if (is.na(anchor_threshold_val)) anchor_threshold_val <- 0.50
      anchor_format <- config$output_settings$Anchor_Format %||% "COMMA_SEPARATED"
      raw_data_for_anchor <- maxdiff_results$raw_data

      if (!is.null(anchor_var) && nzchar(anchor_var)) {
        enriched_seg_scores$Anchor_Rate <- NA_real_
        enriched_seg_scores$Is_Must_Have <- NA

        for (cfg_i in seq_len(nrow(seg_config))) {
          seg_id <- seg_config$Segment_ID[cfg_i]
          seg_def_expr <- seg_config$Segment_Def[cfg_i]
          seg_var <- seg_config$Variable_Name[cfg_i]

          # Determine segment membership using Segment_Def expression
          if (!is.null(seg_def_expr) && !is.na(seg_def_expr) && nzchar(trimws(seg_def_expr))) {
            seg_membership <- tryCatch({
              if (exists("safe_eval_expression", mode = "function")) {
                safe_eval_expression(seg_def_expr, raw_data_for_anchor,
                                     context = sprintf("anchor seg '%s'", seg_id))
              } else {
                eval(parse(text = seg_def_expr), envir = raw_data_for_anchor)
              }
            }, error = function(e) NULL)
          } else if (seg_var %in% names(raw_data_for_anchor)) {
            seg_membership <- raw_data_for_anchor[[seg_var]]
          } else {
            next
          }
          if (is.null(seg_membership)) next

          seg_mask <- which(seg_membership == TRUE)
          if (length(seg_mask) < 2) next

          seg_raw <- raw_data_for_anchor[seg_mask, , drop = FALSE]
          seg_anchor <- tryCatch(
            process_anchor_data(seg_raw, anchor_var, config$items,
                                anchor_format = anchor_format,
                                anchor_threshold = anchor_threshold_val),
            error = function(e) NULL
          )
          if (!is.null(seg_anchor) && "Anchor_Rate" %in% names(seg_anchor)) {
            anchor_map <- setNames(seg_anchor$Anchor_Rate, seg_anchor$Item_ID)
            musthave_map <- setNames(seg_anchor$Is_Must_Have, seg_anchor$Item_ID)

            seg_rows_idx <- which(enriched_seg_scores$Segment_ID == seg_id &
                                    (is.na(enriched_seg_scores$Segment_Value) | enriched_seg_scores$Segment_Value == TRUE))
            for (idx in seg_rows_idx) {
              item_id <- enriched_seg_scores$Item_ID[idx]
              if (item_id %in% names(anchor_map)) {
                enriched_seg_scores$Anchor_Rate[idx] <- anchor_map[[item_id]]
                enriched_seg_scores$Is_Must_Have[idx] <- musthave_map[[item_id]]
              }
            }
          }
        }
      }
    }, error = function(e) {
      message(sprintf("  Segment anchor enrichment warning: %s", e$message))
    })
  }

  tables$preference_scores <- tryCatch(
    build_preference_scores_table(
      html_data$preferences$scores,
      html_data$preferences$anchor_data,
      segment_data = enriched_seg_scores,
      segment_config = seg_config
    ),
    error = function(e) { message(sprintf("  Table error (preferences): %s", e$message)); "" }
  )

  tables$count_scores <- tryCatch(
    build_count_scores_table(
      html_data$items$count_data,
      html_data$items$discrimination,
      segment_data = enriched_seg_scores,
      segment_config = seg_config
    ),
    error = function(e) { message(sprintf("  Table error (counts): %s", e$message)); "" }
  )

  if (!is.null(html_data$turf)) {
    tables$turf <- tryCatch(
      build_turf_table(html_data$turf$incremental_table),
      error = function(e) { message(sprintf("  Table error (turf): %s", e$message)); "" }
    )
  }

  if (!is.null(html_data$segments)) {
    tables$segments <- tryCatch(
      build_segment_table(html_data$segments$segment_data),
      error = function(e) { message(sprintf("  Table error (segments): %s", e$message)); "" }
    )
  }

  # Head-to-head table (with per-segment variants if HB utilities available)
  if (!is.null(html_data$head_to_head)) {
    main_h2h <- tryCatch(
      build_h2h_table(
        html_data$head_to_head$h2h_data,
        html_data$head_to_head$label_map
      ),
      error = function(e) { message(sprintf("  Table error (h2h): %s", e$message)); "" }
    )

    # Compute per-segment H2H matrices
    segment_h2h <- NULL
    if (!is.null(seg_config) && !is.null(maxdiff_results$hb_results$individual_utilities)) {
      segment_h2h <- tryCatch(
        compute_segment_h2h(
          maxdiff_results$hb_results$individual_utilities,
          maxdiff_results$raw_data,
          seg_config,
          config$items,
          html_data$head_to_head$label_map
        ),
        error = function(e) {
          message(sprintf("  Segment H2H warning: %s", e$message))
          NULL
        }
      )
    }

    # Compute segment n values from enriched segment data
    segment_n <- NULL
    if (!is.null(enriched_seg_scores) && is.data.frame(enriched_seg_scores) &&
        "Segment_N" %in% names(enriched_seg_scores) &&
        "Variable_Name" %in% names(enriched_seg_scores) &&
        "Segment_ID" %in% names(enriched_seg_scores)) {
      seg_unique <- unique(enriched_seg_scores[, c("Variable_Name", "Segment_ID", "Segment_N"), drop = FALSE])
      segment_n <- setNames(
        as.list(seg_unique$Segment_N),
        paste0(seg_unique$Variable_Name, ":", seg_unique$Segment_ID)
      )
    }

    # Wrap in segment-filterable container with n= labels
    tables$head_to_head <- build_h2h_with_segments_and_n(
      main_h2h, segment_h2h, html_data$head_to_head$label_map, segment_n
    )
  }

  tables$diagnostics <- tryCatch(
    build_diagnostics_table(html_data$diagnostics),
    error = function(e) { message(sprintf("  Table error (diagnostics): %s", e$message)); "" }
  )

  # --- Build segment-only containers for sub-panels ---
  # These provide segment tables for sub-tabs that otherwise only have charts
  tables$seg_pref_container <- ""
  tables$seg_counts_container <- ""
  if (!is.null(enriched_seg_scores) && is.data.frame(enriched_seg_scores) && nrow(enriched_seg_scores) > 0) {
    tables$seg_pref_container <- tryCatch(
      build_segment_only_container(enriched_seg_scores, "preference", seg_config),
      error = function(e) { message(sprintf("  Segment container error (pref): %s", e$message)); "" }
    )
    tables$seg_counts_container <- tryCatch(
      build_segment_only_container(enriched_seg_scores, "counts", seg_config),
      error = function(e) { message(sprintf("  Segment container error (counts): %s", e$message)); "" }
    )
  }

  # --- Layer 3: Charts ---
  charts <- list()

  if (!is.null(html_data$preferences$scores)) {
    charts$preference_chart <- tryCatch(
      build_preference_chart(html_data$preferences$scores, brand, use_shares = TRUE),
      error = function(e) { message(sprintf("  Chart error (pref shares): %s", e$message)); "" }
    )
    charts$preference_detail_chart <- tryCatch(
      build_preference_chart(html_data$preferences$scores, brand, use_shares = FALSE),
      error = function(e) { message(sprintf("  Chart error (pref detail): %s", e$message)); "" }
    )

    # Generate per-segment preference share charts AND utility score charts
    charts$segment_preference_charts <- list()
    charts$segment_utility_charts <- list()
    if (!is.null(enriched_seg_scores) && is.data.frame(enriched_seg_scores) && nrow(enriched_seg_scores) > 0) {
      seg_ids <- unique(enriched_seg_scores$Segment_ID)
      for (sid in seg_ids) {
        seg_rows <- enriched_seg_scores[enriched_seg_scores$Segment_ID == sid, , drop = FALSE]
        if ("Segment_Value" %in% names(seg_rows)) {
          seg_rows <- seg_rows[seg_rows$Segment_Value == TRUE, , drop = FALSE]
        }
        if (nrow(seg_rows) < 2) next
        var_name <- seg_rows$Variable_Name[1]
        seg_key <- paste0(var_name, ":", sid)
        seg_n <- if ("Segment_N" %in% names(seg_rows)) seg_rows$Segment_N[1] else NA

        # Preference share chart (use_shares = TRUE)
        seg_chart <- tryCatch(
          build_preference_chart(seg_rows, brand, use_shares = TRUE),
          error = function(e) NULL
        )
        if (!is.null(seg_chart) && nzchar(seg_chart)) {
          charts$segment_preference_charts[[seg_key]] <- list(svg = seg_chart, n = seg_n)
        }

        # Utility score chart (use_shares = FALSE)
        seg_util_chart <- tryCatch(
          build_preference_chart(seg_rows, brand, use_shares = FALSE),
          error = function(e) NULL
        )
        if (!is.null(seg_util_chart) && nzchar(seg_util_chart)) {
          charts$segment_utility_charts[[seg_key]] <- list(svg = seg_util_chart, n = seg_n)
        }
      }
    }
  }

  if (!is.null(html_data$items$count_data)) {
    charts$diverging_chart <- tryCatch(
      build_diverging_chart(html_data$items$count_data, brand),
      error = function(e) { message(sprintf("  Chart error (diverging): %s", e$message)); "" }
    )
  }

  # Generate per-segment diverging charts and strategy quadrant charts
  charts$segment_diverging_charts <- list()
  charts$segment_quadrant_charts <- list()
  if (!is.null(enriched_seg_scores) && is.data.frame(enriched_seg_scores) && nrow(enriched_seg_scores) > 0 &&
      "Best_Pct" %in% names(enriched_seg_scores) && "Worst_Pct" %in% names(enriched_seg_scores)) {
    seg_ids <- unique(enriched_seg_scores$Segment_ID)
    for (sid in seg_ids) {
      seg_rows <- enriched_seg_scores[enriched_seg_scores$Segment_ID == sid, , drop = FALSE]
      if ("Segment_Value" %in% names(seg_rows)) {
        seg_rows <- seg_rows[seg_rows$Segment_Value == TRUE, , drop = FALSE]
      }
      if (nrow(seg_rows) < 2) next
      var_name <- seg_rows$Variable_Name[1]
      seg_key <- paste0(var_name, ":", sid)
      seg_n <- if ("Segment_N" %in% names(seg_rows)) seg_rows$Segment_N[1] else NA

      # Per-segment diverging chart (Best vs Worst)
      div_data <- data.frame(
        Item_Label = seg_rows$Item_Label,
        Best_Pct = seg_rows$Best_Pct,
        Worst_Pct = seg_rows$Worst_Pct,
        stringsAsFactors = FALSE
      )
      div_data <- div_data[order(-div_data$Best_Pct), ]
      seg_div <- tryCatch(build_diverging_chart(div_data, brand), error = function(e) NULL)
      if (!is.null(seg_div) && nzchar(seg_div)) {
        charts$segment_diverging_charts[[seg_key]] <- list(svg = seg_div, n = seg_n)
      }

      # Per-segment strategy quadrant (requires HB_Utility_Mean and HB_Utility_SD)
      if ("HB_Utility_Mean" %in% names(seg_rows) && "HB_Utility_SD" %in% names(seg_rows)) {
        quad_data <- data.frame(
          Item_Label = seg_rows$Item_Label,
          HB_Utility_Mean = seg_rows$HB_Utility_Mean,
          HB_Utility_SD = seg_rows$HB_Utility_SD,
          stringsAsFactors = FALSE
        )
        seg_quad <- tryCatch(build_strategy_quadrant(quad_data, brand), error = function(e) NULL)
        if (!is.null(seg_quad) && nzchar(seg_quad)) {
          charts$segment_quadrant_charts[[seg_key]] <- list(svg = seg_quad, n = seg_n)
        }
      }
    }
  }

  if (!is.null(html_data$turf)) {
    charts$turf_chart <- tryCatch(
      build_turf_chart(html_data$turf$reach_curve, brand),
      error = function(e) { message(sprintf("  Chart error (turf): %s", e$message)); "" }
    )
  }

  if (!is.null(html_data$segments)) {
    charts$segment_chart <- tryCatch(
      build_segment_chart(html_data$segments$segment_data, brand),
      error = function(e) { message(sprintf("  Chart error (segments): %s", e$message)); "" }
    )
  }

  # Item Strategy Quadrant (requires HB population utilities)
  if (!is.null(maxdiff_results$hb_results$population_utilities)) {
    charts$strategy_quadrant <- tryCatch(
      build_strategy_quadrant(maxdiff_results$hb_results$population_utilities, brand),
      error = function(e) { message(sprintf("  Chart error (strategy quadrant): %s", e$message)); "" }
    )
  }

  # Anchored MaxDiff threshold chart
  if (!is.null(html_data$preferences$anchor_data)) {
    anchor_threshold <- config$output_settings$Anchor_Threshold %||% 0.50
    anchor_threshold <- as.numeric(anchor_threshold)
    if (is.na(anchor_threshold)) anchor_threshold <- 0.50
    charts$anchor_threshold <- tryCatch(
      build_anchor_threshold_chart(html_data$preferences$anchor_data, brand, anchor_threshold),
      error = function(e) { message(sprintf("  Chart error (anchor threshold): %s", e$message)); "" }
    )
  }

  # Utility distribution chart (raincloud — requires HB individual utilities)
  if (!is.null(html_data$utility_distributions)) {
    charts$utility_distribution <- tryCatch(
      build_utility_distribution_chart(html_data$utility_distributions, brand),
      error = function(e) { message(sprintf("  Chart error (utility distribution): %s", e$message)); "" }
    )
  }

  # Per-segment utility distribution charts and anchor threshold charts
  # Use seg_config (data frame) to iterate segments with Segment_Def for membership
  charts$segment_distribution_charts <- list()
  charts$segment_anchor_charts <- list()

  if (!is.null(enriched_seg_scores) && is.data.frame(enriched_seg_scores) && nrow(enriched_seg_scores) > 0 &&
      is.data.frame(seg_config) && nrow(seg_config) > 0) {
    indiv_utils <- maxdiff_results$hb_results$individual_utilities
    raw_data_local <- maxdiff_results$raw_data

    for (cfg_i in seq_len(nrow(seg_config))) {
      seg_id <- seg_config$Segment_ID[cfg_i]
      seg_var <- seg_config$Variable_Name[cfg_i]
      seg_def_expr <- seg_config$Segment_Def[cfg_i]
      seg_key <- paste0(seg_var, ":", seg_id)

      # Get segment N from enriched data
      seg_enriched <- enriched_seg_scores[enriched_seg_scores$Segment_ID == seg_id, , drop = FALSE]
      seg_n_val <- if (nrow(seg_enriched) > 0 && "Segment_N" %in% names(seg_enriched)) seg_enriched$Segment_N[1] else NA

      # Determine segment membership using Segment_Def expression
      if (!is.null(raw_data_local)) {
        if (!is.null(seg_def_expr) && !is.na(seg_def_expr) && nzchar(trimws(seg_def_expr))) {
          seg_membership <- tryCatch({
            if (exists("safe_eval_expression", mode = "function")) {
              safe_eval_expression(seg_def_expr, raw_data_local,
                                   context = sprintf("chart seg '%s'", seg_id))
            } else {
              eval(parse(text = seg_def_expr), envir = raw_data_local)
            }
          }, error = function(e) NULL)
        } else if (seg_var %in% names(raw_data_local)) {
          seg_membership <- raw_data_local[[seg_var]]
        } else {
          next
        }
      } else {
        next
      }
      if (is.null(seg_membership)) next
      seg_mask <- which(seg_membership == TRUE)
      if (length(seg_mask) < 5) next

      # --- Per-segment distribution chart ---
      if (!is.null(html_data$utility_distributions) && !is.null(indiv_utils)) {
        seg_indiv <- tryCatch({
          if (is.data.frame(indiv_utils)) {
            indiv_utils[seg_mask, , drop = FALSE]
          } else {
            indiv_utils[seg_mask, , drop = FALSE]
          }
        }, error = function(e) NULL)

        if (!is.null(seg_indiv) && nrow(seg_indiv) >= 5) {
          seg_dist <- tryCatch({
            numeric_cols <- if (is.data.frame(seg_indiv)) vapply(seg_indiv, is.numeric, logical(1)) else rep(TRUE, ncol(seg_indiv))
            if (is.data.frame(seg_indiv)) {
              item_ids <- names(seg_indiv)[numeric_cols]
              mat <- as.matrix(seg_indiv[, numeric_cols, drop = FALSE])
            } else {
              mat <- as.matrix(seg_indiv)
              item_ids <- colnames(mat)
            }
            if (length(item_ids) < 2) NULL
            else {
              dist_df <- data.frame(
                Item_ID = item_ids,
                Mean = vapply(item_ids, function(id) mean(mat[, id], na.rm = TRUE), numeric(1)),
                Median = vapply(item_ids, function(id) median(mat[, id], na.rm = TRUE), numeric(1)),
                SD = vapply(item_ids, function(id) sd(mat[, id], na.rm = TRUE), numeric(1)),
                Q25 = vapply(item_ids, function(id) quantile(mat[, id], 0.25, na.rm = TRUE), numeric(1)),
                Q75 = vapply(item_ids, function(id) quantile(mat[, id], 0.75, na.rm = TRUE), numeric(1)),
                Min = vapply(item_ids, function(id) min(mat[, id], na.rm = TRUE), numeric(1)),
                Max = vapply(item_ids, function(id) max(mat[, id], na.rm = TRUE), numeric(1)),
                stringsAsFactors = FALSE
              )
              densities <- lapply(item_ids, function(id) {
                vals <- mat[, id]; vals <- vals[!is.na(vals)]
                if (length(vals) < 3) return(NULL)
                d <- density(vals, n = 32); list(x = d$x, y = d$y)
              })
              names(densities) <- item_ids
              pop <- maxdiff_results$hb_results$population_utilities
              if (!is.null(pop) && "Item_Label" %in% names(pop)) {
                dist_df$Item_Label <- setNames(pop$Item_Label, pop$Item_ID)[dist_df$Item_ID]
              } else {
                dist_df$Item_Label <- dist_df$Item_ID
              }
              dist_df <- dist_df[order(-dist_df$Mean), ]
              list(summary = dist_df, densities = densities[dist_df$Item_ID])
            }
          }, error = function(e) NULL)

          if (!is.null(seg_dist)) {
            seg_dist_svg <- tryCatch(build_utility_distribution_chart(seg_dist, brand), error = function(e) NULL)
            if (!is.null(seg_dist_svg) && nzchar(seg_dist_svg)) {
              charts$segment_distribution_charts[[seg_key]] <- list(svg = seg_dist_svg, n = seg_n_val)
            }
          }
        }
      }

      # --- Per-segment anchor threshold chart ---
      if (!is.null(html_data$preferences$anchor_data)) {
        anchor_var <- config$output_settings$Anchor_Variable %||% NULL
        if (!is.null(anchor_var) && nzchar(anchor_var)) {
          anchor_threshold_val <- as.numeric(config$output_settings$Anchor_Threshold %||% 0.50)
          if (is.na(anchor_threshold_val)) anchor_threshold_val <- 0.50
          anchor_format <- config$output_settings$Anchor_Format %||% "COMMA_SEPARATED"

          seg_raw <- raw_data_local[seg_mask, , drop = FALSE]
          seg_anchor <- tryCatch(
            process_anchor_data(seg_raw, anchor_var, config$items,
                                anchor_format = anchor_format,
                                anchor_threshold = anchor_threshold_val),
            error = function(e) NULL
          )
          if (!is.null(seg_anchor) && nrow(seg_anchor) > 0 && "Anchor_Rate" %in% names(seg_anchor)) {
            seg_anchor_svg <- tryCatch(
              build_anchor_threshold_chart(seg_anchor, brand, anchor_threshold_val),
              error = function(e) NULL
            )
            if (!is.null(seg_anchor_svg) && nzchar(seg_anchor_svg)) {
              charts$segment_anchor_charts[[seg_key]] <- list(svg = seg_anchor_svg, n = seg_n_val)
            }
          }
        }
      }
    }
  }

  # --- Layer 4: Page assembly ---
  cat("  HTML Layer 4: Assembling page...\n")
  page <- tryCatch({
    build_maxdiff_page(html_data, tables, charts, config,
                       simulator_html = simulator_html,
                       js_code = js_code)
  }, error = function(e) {
    cat(sprintf("  [TRS PARTIAL] MAXD_HTML_PAGE_FAILED: %s\n", e$message))
    return(NULL)
  })

  if (is.null(page)) {
    cat("  HTML report REFUSED: Page assembly failed\n")
    return(list(status = "REFUSED", message = "Page assembly failed"))
  }

  # --- Write ---
  cat(sprintf("  HTML Writing to: %s\n", output_path))
  tryCatch({
    writeLines(page, output_path)
  }, error = function(e) {
    cat(sprintf("  [TRS PARTIAL] MAXD_HTML_WRITE_FAILED: %s\n", e$message))
    return(list(status = "REFUSED", message = sprintf("Write failed: %s", e$message)))
  })

  file_size <- file.info(output_path)$size

  cat(sprintf("  HTML report generated: %s (%.1f KB)\n", output_path, file_size / 1024))

  list(
    status = "PASS",
    output_file = output_path,
    file_size_bytes = file_size,
    file_size_mb = round(file_size / 1024 / 1024, 2)
  )
}
