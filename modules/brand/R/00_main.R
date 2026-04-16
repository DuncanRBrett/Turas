# ==============================================================================
# BRAND MODULE - MAIN ORCHESTRATION
# ==============================================================================
# Entry point for the brand module. Loads config, validates inputs,
# dispatches to each active element, and collects results.
#
# USAGE:
#   source("modules/brand/R/00_main.R")
#   result <- run_brand("path/to/Brand_Config.xlsx")
#
# VERSION: 1.0
#
# FILE LAYOUT: R/ subdirectory pattern
#   00_main.R              - This file (orchestration)
#   00_guard.R             - TRS guard layer
#   01_config.R            - Config loading + structure access
#   02_mental_availability.R - MMS, MPen, NS, CEP TURF
#   03_funnel.R            - Derived funnel + attitude decomposition
#   04_repertoire.R        - Multi-brand buying, share of requirements
#   05_wom.R               - Word-of-mouth analysis
#   generate_config_templates.R - Excel template generators
# ==============================================================================

BRAND_VERSION <- "1.0"

# --- Source module files ---
.get_brand_script_dir <- function() {
  # Try sys.frame ofile first
  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(ofile)) return(dirname(ofile))

  # Try script_dir_override (testing)
  if (exists("brand_script_dir_override", envir = globalenv())) {
    return(get("brand_script_dir_override", envir = globalenv()))
  }

  # Try find_turas_root
  if (exists("find_turas_root", mode = "function")) {
    return(file.path(find_turas_root(), "modules", "brand", "R"))
  }

  "modules/brand/R"
}

.source_brand_module <- function() {
  base_dir <- .get_brand_script_dir()

  module_files <- c(
    "00_guard.R",
    "01_config.R",
    "02_mental_availability.R",
    "03_funnel.R",
    "04_repertoire.R",
    "05_wom.R"
  )

  for (f in module_files) {
    fpath <- file.path(base_dir, f)
    if (file.exists(fpath)) {
      source(fpath, local = FALSE)
    }
  }

  # Source shared TURF engine
  turf_candidates <- c(
    file.path(dirname(base_dir), "..", "shared", "lib", "turf_engine.R"),
    "modules/shared/lib/turf_engine.R"
  )
  if (exists("find_turas_root", mode = "function")) {
    turf_candidates <- c(
      file.path(find_turas_root(), "modules", "shared", "lib", "turf_engine.R"),
      turf_candidates
    )
  }
  for (tp in turf_candidates) {
    tp <- normalizePath(tp, mustWork = FALSE)
    if (file.exists(tp)) {
      source(tp, local = FALSE)
      break
    }
  }
}

.source_brand_module()


# ==============================================================================
# MAIN ENTRY FUNCTION
# ==============================================================================

#' Run brand analysis
#'
#' Main entry point for the brand module. Loads configuration, validates
#' all inputs, and dispatches to each active analytical element.
#'
#' @param config_path Character. Path to Brand_Config.xlsx.
#' @param project_root Character. Project root directory (optional).
#' @param verbose Logical. Print progress to console (default: TRUE).
#'
#' @return List with:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{config}{Loaded configuration}
#'   \item{results}{Named list of element results (one per category
#'     for per-category elements, one for brand-level elements)}
#'   \item{warnings}{Character vector of warnings}
#'   \item{elapsed_seconds}{Numeric}
#'
#' @examples
#' \dontrun{
#'   result <- run_brand("config/Brand_Config.xlsx")
#'   if (result$status != "REFUSED") {
#'     print(result$results$mental_availability$mms)
#'   }
#' }
#'
#' @export
run_brand <- function(config_path, project_root = NULL, verbose = TRUE) {

  start_time <- proc.time()["elapsed"]
  warnings_list <- character(0)

  if (verbose) {
    cat("\n")
    cat("========================================\n")
    cat("  TURAS Brand Module v", BRAND_VERSION, "\n")
    cat("========================================\n")
  }

  # --- STEP 1: Load config ---
  if (verbose) cat("\nSTEP 1: Loading configuration...\n")

  config <- tryCatch(
    load_brand_config(config_path, project_root),
    error = function(e) {
      return(list(
        status = "REFUSED",
        code = "CFG_LOAD_FAILED",
        message = conditionMessage(e)
      ))
    }
  )

  if (!is.null(config$status) && config$status == "REFUSED") {
    return(config)
  }

  # --- STEP 2: Load survey structure ---
  if (verbose) cat("STEP 2: Loading survey structure...\n")

  # Use resolved path (relative paths already resolved against config dir)
  structure_path <- config$structure_file_resolved %||% config$structure_file

  structure <- tryCatch(
    load_brand_survey_structure(structure_path),
    error = function(e) {
      return(list(
        status = "REFUSED",
        code = "CFG_STRUCTURE_LOAD_FAILED",
        message = conditionMessage(e)
      ))
    }
  )

  if (!is.null(structure$status) && identical(structure$status, "REFUSED")) {
    return(structure)
  }

  # Validate structure
  struct_guard <- tryCatch(
    guard_validate_structure(structure, config),
    error = function(e) {
      list(status = "REFUSED", message = conditionMessage(e))
    }
  )

  if (!is.null(struct_guard$status) &&
      identical(struct_guard$status, "REFUSED")) {
    return(struct_guard)
  }

  # --- STEP 3: Load data ---
  if (verbose) cat("STEP 3: Loading survey data...\n")

  # Use resolved path (relative paths already resolved against config dir)
  data_path <- config$data_file_resolved %||% config$data_file

  data <- tryCatch({
    if (grepl("\\.csv$", data_path, ignore.case = TRUE)) {
      if (requireNamespace("data.table", quietly = TRUE)) {
        as.data.frame(data.table::fread(data_path))
      } else {
        read.csv(data_path, stringsAsFactors = FALSE)
      }
    } else if (grepl("\\.xlsx?$", data_path, ignore.case = TRUE)) {
      openxlsx::read.xlsx(data_path)
    } else {
      read.csv(data_path, stringsAsFactors = FALSE)
    }
  }, error = function(e) {
    return(list(
      status = "REFUSED",
      code = "IO_DATA_LOAD_FAILED",
      message = sprintf("Cannot load data file: %s", e$message)
    ))
  })

  if (is.list(data) && !is.data.frame(data) &&
      identical(data$status, "REFUSED")) {
    return(data)
  }

  # Validate data
  data_guard <- guard_validate_data(data, structure, config)
  if (identical(data_guard$status, "REFUSED")) {
    return(data_guard)
  }
  if (identical(data_guard$status, "PARTIAL")) {
    warnings_list <- c(warnings_list, data_guard$warnings)
  }

  # Get weights
  weights <- NULL
  weight_col <- config$weight_variable
  if (!is.null(weight_col) && nchar(trimws(weight_col)) > 0 &&
      weight_col %in% names(data)) {
    weights <- data[[weight_col]]
  }

  categories <- config$categories

  if (verbose) {
    cat(sprintf("  Data: %d respondents, %d columns\n",
                nrow(data), ncol(data)))
    cat(sprintf("  Categories: %d\n", nrow(categories)))
    cat(sprintf("  Focal brand: %s\n", config$focal_brand))
    cat(sprintf("  Weighted: %s\n", if (!is.null(weights)) "Yes" else "No"))
  }

  # --- STEP 4: Run elements per category ---
  results <- list()
  category_results <- list()

  for (i in seq_len(nrow(categories))) {
    cat_name <- categories$Category[i]
    if (verbose) cat(sprintf("\n--- Category: %s ---\n", cat_name))

    cat_brands <- get_brands_for_category(structure, cat_name)
    cat_ceps <- get_ceps_for_category(structure, cat_name)
    cat_attrs <- get_attributes_for_category(structure, cat_name)

    cat_result <- list(category = cat_name)

    # Mental Availability
    if (isTRUE(config$element_mental_avail) && nrow(cat_ceps) > 0) {
      if (verbose) cat("  Running Mental Availability...\n")

      # Build CEP linkage (try pre-shaped matrix approach)
      linkage <- tryCatch(
        build_cep_linkage_from_matrix(
          data, cat_ceps$CEPCode, cat_brands$BrandCode
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("MA failed for %s: %s", cat_name, e$message))
          NULL
        }
      )

      if (!is.null(linkage)) {
        cat_result$mental_availability <- run_mental_availability(
          linkage = linkage,
          cep_labels = cat_ceps,
          focal_brand = config$focal_brand,
          weights = weights,
          run_cep_turf = isTRUE(config$element_cep_turf),
          turf_max_items = min(10, nrow(cat_ceps))
        )
      }
    }

    # Funnel
    if (isTRUE(config$element_funnel)) {
      if (verbose) cat("  Running Funnel...\n")

      # Find question prefixes for this category
      aware_qs <- get_questions_for_battery(structure, "awareness", cat_name)
      att_qs <- get_questions_for_battery(structure, "attitude", cat_name)
      pen_qs <- get_questions_for_battery(structure, "penetration", cat_name)

      aware_prefix <- if (nrow(aware_qs) > 0) aware_qs$QuestionCode[1] else ""
      att_prefix <- if (nrow(att_qs) > 0) att_qs$QuestionCode[1] else ""
      pen_prefix <- if (nrow(pen_qs) > 0) pen_qs$QuestionCode[1] else ""

      cat_result$funnel <- tryCatch(
        run_funnel(
          data, cat_brands,
          awareness_prefix = aware_prefix,
          attitude_prefix = att_prefix,
          penetration_prefix = pen_prefix,
          focal_brand = config$focal_brand,
          weights = weights,
          min_base = config$min_base_size,
          low_base_warning = config$low_base_warning
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Funnel failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }

    # Repertoire
    if (isTRUE(config$element_repertoire)) {
      if (verbose) cat("  Running Repertoire...\n")

      # Build penetration matrix from data
      pen_mat <- matrix(0L, nrow = nrow(data), ncol = nrow(cat_brands))
      colnames(pen_mat) <- cat_brands$BrandCode

      pen_qs <- get_questions_for_battery(structure, "penetration", cat_name)
      if (nrow(pen_qs) > 0) {
        pen_prefix <- pen_qs$QuestionCode[1]
        for (b in seq_len(nrow(cat_brands))) {
          col <- .find_brand_col(data, pen_prefix, cat_brands$BrandCode[b])
          if (!is.null(col)) {
            vals <- data[[col]]
            pen_mat[, b] <- as.integer(!is.na(vals) & vals > 0)
          }
        }
      }

      cat_result$repertoire <- tryCatch(
        run_repertoire(
          pen_mat, cat_brands$BrandCode,
          focal_brand = config$focal_brand,
          weights = weights
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Repertoire failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }

    category_results[[cat_name]] <- cat_result
  }

  results$categories <- category_results

  # --- STEP 5: Brand-level elements ---

  # WOM
  if (isTRUE(config$element_wom)) {
    if (verbose) cat("\nRunning WOM (brand-level)...\n")

    wom_qs <- get_questions_for_battery(structure, "wom")
    if (!is.null(wom_qs) && nrow(wom_qs) > 0) {
      # Get unique brand codes across all categories
      all_brands <- unique(structure$brands$BrandCode)

      # Find WOM column prefixes from question codes
      pos_rec_qs <- wom_qs[grepl("POS.*REC|REC.*POS", wom_qs$QuestionCode,
                                  ignore.case = TRUE), , drop = FALSE]
      neg_rec_qs <- wom_qs[grepl("NEG.*REC|REC.*NEG", wom_qs$QuestionCode,
                                  ignore.case = TRUE), , drop = FALSE]
      pos_share_qs <- wom_qs[grepl("POS.*SHARE|SHARE.*POS|POS_S",
                                    wom_qs$QuestionCode,
                                    ignore.case = TRUE), , drop = FALSE]
      neg_share_qs <- wom_qs[grepl("NEG.*SHARE|SHARE.*NEG|NEG_S",
                                    wom_qs$QuestionCode,
                                    ignore.case = TRUE), , drop = FALSE]

      results$wom <- tryCatch(
        run_wom(
          data, all_brands,
          received_pos_prefix = if (nrow(pos_rec_qs) > 0) pos_rec_qs$QuestionCode[1] else "WOM_POS_REC",
          received_neg_prefix = if (nrow(neg_rec_qs) > 0) neg_rec_qs$QuestionCode[1] else "WOM_NEG_REC",
          shared_pos_prefix = if (nrow(pos_share_qs) > 0) pos_share_qs$QuestionCode[1] else "WOM_POS_SHARE",
          shared_neg_prefix = if (nrow(neg_share_qs) > 0) neg_share_qs$QuestionCode[1] else "WOM_NEG_SHARE",
          focal_brand = config$focal_brand,
          weights = weights
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("WOM failed: %s", e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }
  }

  # --- STEP 6: Determine overall status ---
  elapsed <- proc.time()["elapsed"] - start_time

  overall_status <- "PASS"
  if (length(warnings_list) > 0) {
    overall_status <- "PARTIAL"
  }

  # Check if any element refused
  for (cat_name in names(category_results)) {
    for (elem_name in names(category_results[[cat_name]])) {
      elem <- category_results[[cat_name]][[elem_name]]
      if (is.list(elem) && identical(elem$status, "REFUSED")) {
        overall_status <- "PARTIAL"
      }
    }
  }

  if (verbose) {
    cat("\n========================================\n")
    cat(sprintf("  Brand analysis complete: %s\n", overall_status))
    cat(sprintf("  Elapsed: %.1f seconds\n", elapsed))
    if (length(warnings_list) > 0) {
      cat(sprintf("  Warnings: %d\n", length(warnings_list)))
      for (w in warnings_list) cat(sprintf("    - %s\n", w))
    }
    cat("========================================\n\n")
  }

  list(
    status = overall_status,
    config = config,
    structure = structure,
    results = results,
    warnings = warnings_list,
    elapsed_seconds = elapsed
  )
}


# ==============================================================================
# .find_brand_col (exposed at module level for 00_main.R orchestration)
# ==============================================================================

if (!exists(".find_brand_col", mode = "function")) {
  .find_brand_col <- function(data, prefix, brand) {
    candidates <- c(
      paste0(prefix, "_", brand),
      paste0(prefix, ".", brand),
      paste0(prefix, brand)
    )
    match <- intersect(candidates, names(data))
    if (length(match) > 0) match[1] else NULL
  }
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand module loaded (v%s)", BRAND_VERSION))
}
