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

# SIZE-EXCEPTION: file-level. run_brand() is the sequential orchestration
# entry point for every analytical element. Keeping the orchestrator in one
# file mirrors the tabs/tracker pattern and keeps the data flow readable.
# Per-element work is delegated to 02_mental_availability.R, 03_funnel.R +
# helpers, 04_repertoire.R, 05_wom.R, 06_drivers_barriers.R, 07_dba.R.

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
    "00_role_map.R",
    "00_guard_role_map.R",
    "01_config.R",
    "02_mental_availability.R",
    "02a_ma_panel_data.R",
    "03a_funnel_derive.R",
    "03b_funnel_metrics.R",
    "03_funnel.R",
    "03c_funnel_panel_data.R",
    "03d_funnel_output.R",
    "03e_funnel_legacy_adapter.R",
    "04_repertoire.R",
    "05_wom.R",
    "06_drivers_barriers.R",
    "07_dba.R",
    "08_cat_buying.R"
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
# SIZE-EXCEPTION: sequential orchestration (load config, load structure, load
# data, run per-category loop, run brand-level elements, assemble result).
# Decomposing further fragments a linear pipeline without improving
# readability. Funnel dispatch is extracted into .run_funnel_for_category;
# other element dispatchers will follow as each element migrates to the
# role-registry architecture.
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

    # Determine analysis depth from Categories sheet (if present).
    # "full" receives the complete CBM battery; "awareness_only" contributes
    # brand awareness only (used for cross-category portfolio analysis).
    cat_depth <- if ("Analysis_Depth" %in% names(categories))
                   trimws(as.character(categories$Analysis_Depth[i]))
                 else "full"
    if (is.na(cat_depth) || cat_depth == "") cat_depth <- "full"

    if (verbose) cat(sprintf("\n--- Category: %s [%s] ---\n", cat_name, cat_depth))

    cat_brands <- get_brands_for_category(structure, cat_name)
    cat_ceps   <- get_ceps_for_category(structure, cat_name)
    cat_attrs  <- get_attributes_for_category(structure, cat_name)

    cat_result <- list(category = cat_name, analysis_depth = cat_depth)
    linkage    <- NULL  # populated by MA block; used by D&B

    # Detect short category code (e.g. "DSS") and filter data to focal
    # respondents for this category. Focal filtering is used for WOM so each
    # category's WOM metrics reflect its own respondent group and brand list.
    focal_col  <- config$focal_category_col %||% "Focal_Category"
    cat_code   <- if (cat_depth == "full" && !is.null(structure$questionmap))
                    .detect_category_code(structure$questionmap, cat_brands, data)
                  else NULL
    cat_data   <- if (!is.null(cat_code) && focal_col %in% names(data)) {
                    data[!is.na(data[[focal_col]]) &
                         data[[focal_col]] == cat_code, ]
                  } else data
    cat_weights <- if (!is.null(weights) && !is.null(cat_code) &&
                       focal_col %in% names(data)) {
                     weights[!is.na(data[[focal_col]]) &
                             data[[focal_col]] == cat_code]
                   } else weights

    # Mental Availability (full categories only — awareness_only cats have no CEPs)
    if (isTRUE(config$element_mental_avail) && nrow(cat_ceps) > 0 &&
        cat_depth == "full") {
      if (verbose) cat("  Running Mental Availability...\n")

      # Build CEP linkage from data
      # Column names in data follow: QuestionCode_BrandCode pattern
      # QuestionCode comes from Questions sheet (e.g., CEP01_DSS)
      # We need to map CEP codes to their question codes for column matching
      cep_questions <- get_questions_for_battery(structure, "cep_matrix", cat_name)
      cep_col_codes <- if (nrow(cep_questions) > 0) {
        cep_questions$QuestionCode
      } else {
        cat_ceps$CEPCode  # fallback to raw CEP codes
      }

      linkage <- tryCatch(
        build_cep_linkage_from_matrix(
          cat_data, cep_col_codes, cat_brands$BrandCode
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("MA failed for %s: %s", cat_name, e$message))
          NULL
        }
      )

      if (!is.null(linkage)) {
        # Map question codes to CEP labels for display
        cep_labels_mapped <- data.frame(
          CEPCode = cep_col_codes,
          CEPText = if (nrow(cep_questions) > 0 && nrow(cat_ceps) > 0) {
            # Match question codes to CEP texts via position
            cep_questions$QuestionText[seq_along(cep_col_codes)]
          } else {
            cep_col_codes
          },
          stringsAsFactors = FALSE
        )

        # Brand image attributes (optional — same matrix shape as CEP)
        attr_linkage <- NULL
        if (!is.null(cat_attrs) && nrow(cat_attrs) > 0) {
          attr_linkage <- tryCatch(
            build_cep_linkage_from_matrix(
              cat_data, cat_attrs$AttrCode, cat_brands$BrandCode
            ),
            error = function(e) {
              warnings_list <<- c(warnings_list,
                sprintf("MA attribute matrix failed for %s: %s",
                        cat_name, e$message))
              NULL
            }
          )
        }

        cat_result$mental_availability <- run_mental_availability(
          linkage = linkage,
          cep_labels = cep_labels_mapped,
          focal_brand = config$focal_brand,
          weights = cat_weights,
          run_cep_turf = isTRUE(config$element_cep_turf),
          turf_max_items = min(10, length(cep_col_codes)),
          attribute_linkage = attr_linkage,
          attribute_labels = if (!is.null(cat_attrs) && nrow(cat_attrs) > 0)
            data.frame(AttrCode = cat_attrs$AttrCode,
                       AttrText = cat_attrs$AttrText,
                       stringsAsFactors = FALSE) else NULL
        )
      }
    }

    # Funnel (role-registry architecture; full categories only)
    if (isTRUE(config$element_funnel) && cat_depth == "full") {
      if (verbose) cat("  Running Funnel...\n")

      cat_result$funnel <- .run_funnel_for_category(
        data = cat_data, structure = structure, cat_brands = cat_brands,
        cat_ceps = cat_ceps, config = config, weights = cat_weights,
        cat_name = cat_name, warnings_acc = function(msg) {
          warnings_list <<- c(warnings_list, msg)
        }
      )
    }

    # Repertoire (full categories only — awareness_only cats have no pen data)
    if (isTRUE(config$element_repertoire) && cat_depth == "full") {
      if (verbose) cat("  Running Repertoire...\n")

      # Build penetration matrix from cat_data (focal respondents only)
      pen_mat <- matrix(0L, nrow = nrow(cat_data), ncol = nrow(cat_brands))
      colnames(pen_mat) <- cat_brands$BrandCode

      pen_qs <- get_questions_for_battery(structure, "penetration", cat_name)
      if (nrow(pen_qs) > 0) {
        pen_prefix <- pen_qs$QuestionCode[1]
        for (b in seq_len(nrow(cat_brands))) {
          col <- .find_brand_col(cat_data, pen_prefix, cat_brands$BrandCode[b])
          if (!is.null(col)) {
            vals <- cat_data[[col]]
            pen_mat[, b] <- as.integer(!is.na(vals) & vals > 0)
          }
        }
      }

      cat_result$repertoire <- tryCatch(
        run_repertoire(
          pen_mat, cat_brands$BrandCode,
          focal_brand = config$focal_brand,
          weights = cat_weights
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Repertoire failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }

    # Category Buying Frequency (full categories only)
    # Reads the cat_buying.frequency.{cat_code} role from QuestionMap and maps
    # coded responses through the cat_buy_scale OptionMap scale.
    if (isTRUE(config$element_repertoire) && cat_depth == "full" &&
        !is.null(cat_code) && !is.null(structure$questionmap) &&
        nrow(structure$questionmap) > 0) {
      freq_role <- paste0("cat_buying.frequency.", cat_code)
      qmap_rows <- structure$questionmap
      freq_row  <- qmap_rows[
        !is.na(qmap_rows$Role) &
          trimws(as.character(qmap_rows$Role)) == freq_role,
        , drop = FALSE]
      if (nrow(freq_row) > 0) {
        freq_col_name <- trimws(as.character(freq_row$ClientCode[1]))
        if (!is.na(freq_col_name) && nzchar(freq_col_name) &&
            freq_col_name %in% names(cat_data)) {
          if (verbose) cat("  Running Category Buying Frequency...\n")
          cat_result$cat_buying_frequency <- tryCatch(
            run_cat_buying_frequency(
              cat_data[[freq_col_name]],
              option_map = structure$optionmap,
              weights    = cat_weights
            ),
            error = function(e) {
              warnings_list <<- c(warnings_list,
                sprintf("Cat buying frequency failed for %s: %s",
                        cat_name, e$message))
              list(status = "REFUSED", message = e$message)
            }
          )
        }
      }
    }

    # WOM (full categories only; filtered to focal respondents for this category)
    # WOM is category-specific because each category has a different brand list
    # and only its focal respondents answered WOM questions for those brands.
    if (isTRUE(config$element_wom) && cat_depth == "full") {
      if (verbose) cat("  Running WOM...\n")
      wom_qs <- get_questions_for_battery(structure, "wom")
      if (!is.null(wom_qs) && nrow(wom_qs) > 0) {
        pos_rec  <- .wom_prefix(wom_qs, "POS.*REC|REC.*POS",  "WOM_POS_REC")
        neg_rec  <- .wom_prefix(wom_qs, "NEG.*REC|REC.*NEG",  "WOM_NEG_REC")
        pos_shr  <- .wom_prefix(wom_qs, "POS.*SHARE|SHARE.*POS|POS_S", "WOM_POS_SHARE")
        neg_shr  <- .wom_prefix(wom_qs, "NEG.*SHARE|SHARE.*NEG|NEG_S", "WOM_NEG_SHARE")
        cat_result$wom <- tryCatch(
          run_wom(
            cat_data, cat_brands$BrandCode,
            received_pos_prefix = pos_rec,
            received_neg_prefix = neg_rec,
            shared_pos_prefix   = pos_shr,
            shared_neg_prefix   = neg_shr,
            focal_brand = config$focal_brand,
            weights     = cat_weights
          ),
          error = function(e) {
            warnings_list <<- c(warnings_list,
              sprintf("WOM failed for %s: %s", cat_name, e$message))
            list(status = "REFUSED", message = e$message)
          }
        )
      }
    }

    # Drivers & Barriers (full categories only; requires MA linkage)
    if (isTRUE(config$element_drivers_barriers) && cat_depth == "full") {
      if (verbose) cat("  Running Drivers & Barriers...\n")

      db_cep_mat <- if (!is.null(cat_result$mental_availability))
                      cat_result$mental_availability$cep_brand_matrix else NULL

      # Focal brand penetration vector (reuses same question source as repertoire)
      db_pen <- NULL
      pen_qs <- get_questions_for_battery(structure, "penetration", cat_name)
      if (nrow(pen_qs) > 0) {
        pen_prefix    <- pen_qs$QuestionCode[1]
        focal_pen_col <- .find_brand_col(cat_data, pen_prefix, config$focal_brand)
        if (!is.null(focal_pen_col)) {
          vals   <- cat_data[[focal_pen_col]]
          db_pen <- as.integer(!is.na(vals) & vals > 0)
        }
      }

      if (!is.null(linkage) && !is.null(db_cep_mat) && !is.null(db_pen)) {
        cat_result$drivers_barriers <- tryCatch(
          run_drivers_barriers(
            linkage     = linkage,
            cep_mat     = db_cep_mat,
            pen         = db_pen,
            focal_brand = config$focal_brand,
            cep_labels  = if (!is.null(cat_ceps) && nrow(cat_ceps) > 0)
              data.frame(CEPCode = cat_ceps$CEPCode,
                         CEPText = cat_ceps$CEPText,
                         stringsAsFactors = FALSE) else NULL
          ),
          error = function(e) {
            warnings_list <<- c(warnings_list,
              sprintf("Drivers & Barriers failed for %s: %s", cat_name, e$message))
            list(status = "REFUSED", message = e$message)
          }
        )
      } else {
        if (verbose) cat("  Drivers & Barriers skipped: MA linkage or pen data unavailable.\n")
      }
    }

    category_results[[cat_name]] <- cat_result
  }

  results$categories <- category_results

  # --- STEP 5: Brand-level elements ---

  # DBA
  if (isTRUE(config$element_dba)) {
    if (verbose) cat("\nRunning DBA (brand-level)...\n")

    dba_assets <- NULL
    if (!is.null(structure$dba_assets) && nrow(structure$dba_assets) > 0) {
      dba_assets <- structure$dba_assets
    } else if (!is.null(config$dba_assets) && nrow(config$dba_assets) > 0) {
      dba_assets <- config$dba_assets
    }

    if (!is.null(dba_assets)) {
      results$dba <- tryCatch(
        run_dba(
          data, dba_assets,
          focal_brand = config$focal_brand,
          fame_threshold = config$dba_fame_threshold,
          uniqueness_threshold = config$dba_uniqueness_threshold,
          attribution_type = config$dba_attribution_type,
          weights = weights
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list, sprintf("DBA failed: %s", e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }
  }

  # WOM is now per-category (see Step 4 above). No brand-level WOM.

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
# FUNNEL DISPATCH (role-registry architecture)
# ==============================================================================
# Wraps the new run_funnel() signature. Returns a refusal list rather than
# throwing, so a single-category refusal does not abort the whole brand
# analysis. When the structure lacks a QuestionMap sheet the funnel is
# skipped loudly — there is no legacy fallback; the operator must add the
# QuestionMap per modules/brand/docs/ROLE_REGISTRY.md §11.

.run_funnel_for_category <- function(data, structure, cat_brands, cat_ceps,
                                     config, weights, cat_name,
                                     warnings_acc) {
  if (is.null(structure$questionmap) ||
      is.null(nrow(structure$questionmap)) ||
      nrow(structure$questionmap) == 0) {
    msg <- sprintf(
      "Funnel skipped for '%s': Survey_Structure.xlsx has no QuestionMap sheet (role-registry architecture required).",
      cat_name)
    warnings_acc(msg)
    return(list(status = "REFUSED", code = "CFG_QUESTIONMAP_MISSING",
                message = msg))
  }

  funnel_cfg <- .funnel_config_from_global(config, cat_name, cat_brands)

  brand_with_refusal_handler({
    # For multi-category studies, the QuestionMap contains category-suffixed
    # role names (e.g. funnel.awareness.DSS). Normalise to bare names for this
    # category before building the role map so run_funnel() can find its
    # required roles (funnel.awareness, funnel.attitude, etc.).
    cat_qmap <- .normalize_questionmap_for_category(
      structure$questionmap, cat_brands, data
    )
    cat_structure        <- structure
    cat_structure$questionmap <- cat_qmap

    role_map <- load_role_map(cat_structure,
                              brand_list = cat_brands,
                              cep_list   = cat_ceps,
                              asset_list = structure$dba_assets)
    run_funnel(
      data       = data,
      role_map   = role_map,
      brand_list = cat_brands,
      config     = funnel_cfg,
      weights    = weights,
      sig_tester = NULL
    )
  })
}


#' Normalise a QuestionMap for a single-category funnel run
#'
#' Multi-category studies store funnel roles with a category suffix
#' (e.g. \code{funnel.awareness.DSS}) so each category can point at its own
#' data columns. The funnel element, however, expects bare role names
#' (\code{funnel.awareness}). This helper:
#' \enumerate{
#'   \item Detects whether the map uses suffixed funnel roles (three-level
#'     names like \code{funnel.awareness.DSS}).
#'   \item If not, returns the QuestionMap unchanged (single-category study).
#'   \item If yes, identifies the suffix for the current category by testing
#'     which \code{funnel.awareness.*} row resolves columns that exist in data
#'     for the brands supplied.
#'   \item Filters to only that category's funnel rows plus all shared rows
#'     (screener.*, system.*, wom.*, dba.*, reach.*, cross_cat.*, cat_buying.*,
#'     channel.*).
#'   \item Strips the suffix from funnel row role names so they match the bare
#'     names the funnel element requires.
#' }
#'
#' @param qmap Data frame. The raw QuestionMap sheet.
#' @param cat_brands Data frame. Brands for this category; must have BrandCode.
#' @param data Data frame. Survey data used for column resolution check.
#' @return Data frame. Normalised QuestionMap for this category.
#' @keywords internal
.normalize_questionmap_for_category <- function(qmap, cat_brands, data) {
  if (is.null(qmap) || nrow(qmap) == 0) return(qmap)

  roles <- trimws(as.character(qmap$Role))

  # Detect multi-category: funnel role with three dot-separated segments
  # e.g. "funnel.awareness.DSS"
  is_multi <- any(grepl("^funnel\\.[^.]+\\.[^.]+$", roles))
  if (!is_multi) return(qmap)  # Single-category map — use as-is

  cat_suffix <- .detect_category_code(qmap, cat_brands, data)

  if (is.null(cat_suffix)) {
    # Cannot determine category suffix — return unchanged; funnel will refuse
    # with a clear "role missing" message if required roles are absent.
    return(qmap)
  }

  .strip_cat_suffix_from_qmap(qmap, roles, cat_suffix)
}


#' Strip a category suffix from a QuestionMap and filter to that category
#'
#' Shared implementation for .normalize_questionmap_for_category() and callers
#' that already know cat_suffix.
#' @keywords internal
.strip_cat_suffix_from_qmap <- function(qmap, roles, cat_suffix) {
  # Keep rows that either belong to this category's funnel group or are shared
  suffix_rx <- paste0("\\.", cat_suffix, "$")
  is_cat_funnel <- grepl(suffix_rx, roles)
  # Shared: not a category-scoped funnel/attr/cep/channel/cat_buying row
  is_cat_scoped <- grepl("^(funnel|cross_cat)\\..*\\.[A-Z]{2,}$", roles)
  is_shared     <- !is_cat_scoped

  keep   <- is_cat_funnel | is_shared
  result <- qmap[keep, , drop = FALSE]

  # Strip suffix from the funnel rows
  result$Role[is_cat_funnel[keep]] <- sub(suffix_rx, "",
                                          result$Role[is_cat_funnel[keep]])
  result
}


#' Detect the short category code for a given brand list
#'
#' Inspects the QuestionMap's \code{funnel.awareness.*} rows and finds which
#' suffix (e.g. "DSS") has the majority of its expected awareness columns
#' (\code{{ClientCode}_{brand}}) present in the data. Returns NULL when no
#' matching suffix is found (single-category studies, awareness-only cats).
#'
#' @param qmap Data frame. Raw QuestionMap from Survey_Structure.
#' @param cat_brands Data frame. Brands for this category (BrandCode column).
#' @param data Data frame. Survey data.
#' @return Character scalar category code, or NULL.
#' @keywords internal
.detect_category_code <- function(qmap, cat_brands, data) {
  if (is.null(qmap) || nrow(qmap) == 0) return(NULL)
  if (is.null(cat_brands) || nrow(cat_brands) == 0) return(NULL)

  roles     <- trimws(as.character(qmap$Role))
  aw_idx    <- which(grepl("^funnel\\.awareness\\.[^.]+$", roles))
  if (length(aw_idx) == 0) return(NULL)

  threshold <- max(1L, floor(nrow(cat_brands) * 0.5))
  for (i in aw_idx) {
    cc <- trimws(as.character(qmap$ClientCode[i]))
    if (is.na(cc) || cc == "") next
    expected_cols <- paste0(cc, "_", cat_brands$BrandCode)
    n_found <- sum(expected_cols %in% names(data))
    if (n_found >= threshold) {
      parts <- strsplit(roles[i], "\\.")[[1]]
      return(parts[length(parts)])
    }
  }
  NULL
}


#' Extract WOM question code prefix from a questions data frame
#'
#' Matches a WOM question by regex pattern and returns the QuestionCode (used
#' as the column prefix e.g. "WOM_POS_REC"). Falls back to \code{default}
#' if no match is found.
#'
#' @param wom_qs Data frame. Rows where Battery == "wom".
#' @param pattern Character. Regex to match the QuestionCode.
#' @param default Character. Fallback prefix.
#' @return Character scalar.
#' @keywords internal
.wom_prefix <- function(wom_qs, pattern, default) {
  rows <- wom_qs[grepl(pattern, wom_qs$QuestionCode, ignore.case = TRUE), ,
                 drop = FALSE]
  if (nrow(rows) > 0) rows$QuestionCode[1] else default
}


#' Pull the funnel subset of settings out of the full brand config
#'
#' Translates the global Brand_Config settings (underscore-separated) into
#' the funnel.* dot-separated keys expected by run_funnel(). Keeps the
#' orchestration decoupled from funnel-specific parameter names.
#'
#' @keywords internal
.funnel_config_from_global <- function(config, cat_name, cat_brands) {
  cat_type <- config$category_type %||% config$`category.type` %||% "transactional"
  conv <- config$funnel_conversion_metric %||%
           config$`funnel.conversion_metric` %||% "ratio"
  warn_b <- config$funnel_warn_base %||% config$low_base_warning %||% 75
  supp_b <- config$funnel_suppress_base %||% config$min_base_size %||% 0
  tenure <- config$funnel_tenure_threshold %||%
             config$`funnel.tenure_threshold`
  alpha <- config$alpha %||% 0.05

  list(
    `category.type`            = cat_type,
    focal_brand                = config$focal_brand,
    wave                       = config$wave,
    `funnel.conversion_metric` = conv,
    `funnel.warn_base`         = warn_b,
    `funnel.suppress_base`     = supp_b,
    `funnel.tenure_threshold`  = tenure,
    `funnel.significance_level` = alpha
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand module loaded (v%s)", BRAND_VERSION))
}
