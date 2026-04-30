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
    "00_data_access.R",
    "00_role_inference.R",
    "00_role_map.R",
    "00_role_map_v2.R",
    "00_guard_role_map.R",
    "00_guard_v2.R",
    "01_config.R",
    "02_mental_availability.R",
    "02b_mental_advantage.R",
    "02a_ma_panel_data.R",
    "02b_ma_advantage_data.R",
    "03a_funnel_derive.R",
    "03b_funnel_metrics.R",
    "03_funnel.R",
    "03c_funnel_panel_data.R",
    "03d_funnel_output.R",
    "03e_funnel_legacy_adapter.R",
    "04_repertoire.R",
    "05_wom.R",
    "05a_wom_panel_data.R",
    "06_drivers_barriers.R",
    "07_dba.R",
    "08_cat_buying.R",
    "08b_brand_volume.R",
    "08c_dirichlet_norms.R",
    "08d_buyer_heaviness.R",
    "08e_shopper_behaviour.R",
    "09_portfolio.R",
    "09a_portfolio_footprint.R",
    "09b_portfolio_constellation.R",
    "09c_portfolio_clutter.R",
    "09d_portfolio_strength.R",
    "09e_portfolio_extension.R",
    "09f_portfolio_panel_data.R",
    "09g_portfolio_output.R",
    "09h_portfolio_overview_data.R",
    "10a_br_panel_data.R",
    "10b_br_misattribution.R",
    "10c_br_media_mix.R",
    "10d_br_output.R",
    "10_branded_reach.R",
    "11_demographics.R",
    "11a_demographics_panel_data.R",
    "12_adhoc.R",
    "12a_adhoc_panel_data.R",
    "13_audience_lens.R",
    "13a_al_audiences.R",
    "13b_al_metrics.R",
    "13c_al_classify.R",
    "13d_al_panel_data.R"
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

  # --- STEP 3b: Build v2 role map (convention-first + override) ---
  # One pass over the full data + structure produces the resolved role map
  # used by every v2 element. Falls back to NULL if the inferer cannot run
  # (e.g. structure has no Questions sheet) so legacy elements still work.
  role_map <- tryCatch({
    if (exists("build_brand_role_map", mode = "function") &&
        !is.null(structure$questions)) {
      build_brand_role_map(
        structure    = structure,
        brand_config = list(categories = categories),
        data         = data
      )
    } else NULL
  }, error = function(e) {
    warnings_list <<- c(warnings_list,
      sprintf("Role map build failed: %s — v2 elements will skip", e$message))
    NULL
  })

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

    # Brand Volume Matrix + Dirichlet Norms + Buyer Heaviness (full categories only)
    # These three elements require BRANDPEN2 and BRANDPEN3 columns resolved via
    # the cat_code detected above. They are skipped when cat_code is NULL.
    if (isTRUE(config$element_repertoire) && cat_depth == "full" &&
        !is.null(cat_code)) {

      pen2_prefix  <- paste0("BRANDPEN2_", cat_code)
      pen3_prefix  <- paste0("BRANDPEN3_", cat_code)

      if (verbose) cat("  Building brand volume matrix...\n")
      vol_result <- tryCatch(
        build_brand_volume_matrix(
          cat_data         = cat_data,
          cat_brands       = cat_brands,
          pen_target_prefix = pen2_prefix,
          freq_prefix      = pen3_prefix,
          verbose          = verbose
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Brand volume matrix failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
      cat_result$brand_volume <- vol_result

      if (!identical(vol_result$status, "REFUSED")) {
        if (verbose) cat("  Running Dirichlet norms...\n")
        cat_result$dirichlet_norms <- tryCatch(
          run_dirichlet_norms(
            pen_mat       = vol_result$pen_mat,
            x_mat         = vol_result$x_mat,
            m_vec         = vol_result$m_vec,
            brand_codes   = cat_brands$BrandCode,
            focal_brand   = config$focal_brand,
            weights       = cat_weights,
            target_months = config$target_timeframe_months %||% 3L,
            longer_months = config$longer_timeframe_months %||% 12L
          ),
          error = function(e) {
            warnings_list <<- c(warnings_list,
              sprintf("Dirichlet norms failed for %s: %s", cat_name, e$message))
            list(status = "REFUSED", message = e$message)
          }
        )

        # P1.2 fix: buyer heaviness requires a successful Dirichlet run —
        # both analyses depend on the same Dirichlet parameterisation.
        if (!identical(cat_result$dirichlet_norms$status, "REFUSED")) {
          if (verbose) cat("  Running buyer heaviness...\n")
          cat_result$buyer_heaviness <- tryCatch(
            run_buyer_heaviness(
              pen_mat     = vol_result$pen_mat,
              m_vec       = vol_result$m_vec,
              brand_codes = cat_brands$BrandCode,
              focal_brand = config$focal_brand,
              weights     = cat_weights,
              x_mat       = vol_result$x_mat
            ),
            error = function(e) {
              warnings_list <<- c(warnings_list,
                sprintf("Buyer heaviness failed for %s: %s", cat_name, e$message))
              list(status = "REFUSED", message = e$message)
            }
          )
        }

        # Pass frequency_matrix into run_repertoire for share_of_requirements
        # (re-run repertoire with frequency data now that vol_result is available)
        if (!is.null(cat_result$repertoire) &&
            !identical(cat_result$repertoire$status, "REFUSED")) {
          cat_result$repertoire <- tryCatch(
            run_repertoire(
              vol_result$pen_mat,
              cat_brands$BrandCode,
              focal_brand      = config$focal_brand,
              frequency_matrix = vol_result$x_mat,
              weights          = cat_weights
            ),
            error = function(e) {
              warnings_list <<- c(warnings_list,
                sprintf("Repertoire (with frequency) failed for %s: %s",
                        cat_name, e$message))
              cat_result$repertoire
            }
          )
        }

        # Shopper Behaviour: optional purchase channel + pack size analytics.
        # Each role is independently optional; absence means the panel
        # section silently hides. Both consume the same pen_mat used for
        # Dirichlet to identify each brand's buyers.
        sb <- .run_shopper_for_category(
          structure   = structure,
          cat_code    = cat_code,
          cat_name    = cat_name,
          cat_data    = cat_data,
          pen_mat     = vol_result$pen_mat,
          brand_codes = cat_brands$BrandCode,
          weights     = cat_weights,
          verbose     = verbose
        )
        cat_result$shopper_location <- sb$location
        cat_result$shopper_packsize <- sb$packsize
        if (length(sb$warnings) > 0) {
          warnings_list <- c(warnings_list, sb$warnings)
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
        pos_cnt  <- .wom_prefix(wom_qs, "POS.*COUNT|COUNT.*POS|POS.*FREQ|FREQ.*POS",
                                "WOM_POS_COUNT")
        neg_cnt  <- .wom_prefix(wom_qs, "NEG.*COUNT|COUNT.*NEG|NEG.*FREQ|FREQ.*NEG",
                                "WOM_NEG_COUNT")
        cat_result$wom <- tryCatch(
          run_wom(
            cat_data, cat_brands$BrandCode,
            received_pos_prefix    = pos_rec,
            received_neg_prefix    = neg_rec,
            shared_pos_prefix      = pos_shr,
            shared_neg_prefix      = neg_shr,
            shared_pos_freq_prefix = pos_cnt,
            shared_neg_freq_prefix = neg_cnt,
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

    # Branded Reach (full categories only; v2 entry — placeholder-aware).
    # When structure has no MarketingReach sheet (IPK Wave 1), v2 returns a
    # PASS placeholder so the panel-data renderer can show "Data not yet
    # collected for Branded Reach". Otherwise delegates to run_branded_reach.
    if (isTRUE(config$element_branded_reach) && cat_depth == "full") {
      if (verbose) cat("  Running Branded Reach...\n")
      cat_result$branded_reach <- tryCatch(
        run_branded_reach_v2(
          data        = cat_data,
          structure   = structure,
          brand_list  = cat_brands,
          weights     = cat_weights,
          cat_code    = cat_code,
          focal_brand = config$focal_brand
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Branded reach failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }

    # Audience Lens (full categories only; respects per-category opt-in via
    # Categories$AudienceLens_Use). Runs after the upstream blocks so the
    # engine can enrich its per-audience cards with branded-reach + WOM
    # totals from the already-computed category result.
    if (isTRUE(config$element_audience_lens) && cat_depth == "full") {
      al_audiences <- tryCatch(
        parse_audience_lens_definitions(
          structure = structure, config = config,
          cat_code = cat_code %||% "", cat_name = cat_name,
          data = cat_data,
          thresholds = list(max_audiences = as.integer(
            config$audience_lens_max %||% 6L))),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Audience lens parse failed for %s: %s",
                    cat_name, e$message))
          list()
        })

      if (is.list(al_audiences) && identical(al_audiences$status, "REFUSED")) {
        warnings_list <<- c(warnings_list,
          sprintf("[AUDIENCE LENS %s] %s: %s",
                  al_audiences$code, cat_name, al_audiences$message))
        cat_result$audience_lens <- al_audiences
      } else if (length(al_audiences) > 0) {
        if (verbose) cat("  Running Audience Lens...\n")
        cat_result$audience_lens <- tryCatch(
          run_audience_lens(
            data = cat_data, weights = cat_weights,
            cat_brands = cat_brands,
            cat_code = cat_code %||% "",
            cat_name = cat_name,
            focal_brand = config$focal_brand,
            audiences = al_audiences,
            structure = structure, config = config,
            category_results = cat_result),
          error = function(e) {
            warnings_list <<- c(warnings_list,
              sprintf("Audience lens failed for %s: %s",
                      cat_name, e$message))
            list(status = "REFUSED",
                 code = "CALC_AUDIENCE_LENS_ERROR",
                 message = e$message)
          })
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

    # Demographics (per-category; full categories only — relies on cat_data
    # being filtered to focal-category respondents and cat_result$brand_volume
    # for the per-brand pen matrix). Awareness-only categories don't have a
    # full brand-volume matrix, so the buyer / brand cuts collapse to the
    # total distribution.
    if (isTRUE(config$element_demographics %||% TRUE) && cat_depth == "full") {
      if (verbose) cat("  Running Demographics...\n")
      cat_result$demographics <- tryCatch(
        .run_demographics_for_category(
          structure   = structure, config = config,
          cat_data    = cat_data, cat_weights = cat_weights,
          cat_brands  = cat_brands, cat_name = cat_name,
          brand_volume    = cat_result$brand_volume,
          buyer_heaviness = cat_result$buyer_heaviness,
          verbose     = verbose
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Demographics failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }

    # Ad Hoc (per-category; full categories only). v2 dispatcher walks
    # role_map for ^adhoc\.* keys. ALL-scoped questions use the full sample;
    # CATCODE-scoped questions use cat_data + this category's brand cut.
    # Falls through to the legacy QuestionMap dispatcher when no v2 role map
    # was built (e.g. structure missing Questions sheet).
    if (isTRUE(config$element_adhoc %||% TRUE) && cat_depth == "full") {
      if (verbose) cat("  Running Ad Hoc...\n")
      cat_result$adhoc <- tryCatch(
        if (!is.null(role_map))
          .run_adhoc_for_category_v2(
            role_map     = role_map, structure = structure, config = config,
            data_full    = data, weights_full = weights,
            cat_data     = cat_data, cat_weights = cat_weights,
            cat_brands   = cat_brands, cat_name = cat_name,
            cat_code     = cat_code,
            brand_volume = cat_result$brand_volume,
            verbose      = verbose
          )
        else
          .run_adhoc_for_category(
            structure   = structure, config = config,
            data_full   = data, weights_full = weights,
            cat_data    = cat_data, cat_weights = cat_weights,
            cat_brands  = cat_brands, cat_name = cat_name,
            cat_code    = cat_code,
            brand_volume = cat_result$brand_volume,
            verbose     = verbose
          ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Ad hoc failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }

    category_results[[cat_name]] <- cat_result
  }

  results$categories <- category_results

  # --- STEP 5a: Cross-category portfolio data (full 1200 respondents) ---
  # Computes category usage and focal brand awareness from the FULL dataset,
  # not from per-category filtered subsets.
  results$portfolio <- .compute_portfolio_data(data, categories, structure,
                                               config, weights)

  # --- STEP 5b: Portfolio Overview (focal-brand view across ALL categories) ---
  # Deep-dive AND awareness-only categories together, enriched with pen/SCR/vol
  # for deep-dive cats from category_results.
  results$portfolio_overview <- tryCatch(
    compute_portfolio_overview_data(
      data, categories, structure, config,
      weights          = weights,
      category_results = category_results
    ),
    error = function(e) {
      warnings_list <<- c(warnings_list,
        sprintf("Portfolio overview failed: %s", e$message))
      NULL
    }
  )

  # --- STEP 5: Brand-level elements ---

  # DBA — v2 entry. Always runs when element is enabled; v2 emits a
  # placeholder result when the structure has no DBA assets or the
  # per-asset Fame/Unique columns are absent from data.
  if (isTRUE(config$element_dba)) {
    if (verbose) cat("\nRunning DBA (brand-level)...\n")

    dba_structure <- structure
    if ((is.null(dba_structure$dba_assets) ||
         nrow(dba_structure$dba_assets) == 0) &&
        !is.null(config$dba_assets) && nrow(config$dba_assets) > 0) {
      dba_structure$dba_assets <- config$dba_assets
    }

    results$dba <- tryCatch(
      run_dba_v2(
        data                 = data,
        structure            = dba_structure,
        focal_brand          = config$focal_brand,
        fame_threshold       = config$dba_fame_threshold %||%
                                  DBA_DEFAULT_FAME_THRESHOLD,
        uniqueness_threshold = config$dba_uniqueness_threshold %||%
                                  DBA_DEFAULT_UNIQUENESS_THRESHOLD,
        attribution_type     = config$dba_attribution_type %||% "open",
        weights              = weights
      ),
      error = function(e) {
        warnings_list <<- c(warnings_list, sprintf("DBA failed: %s", e$message))
        list(status = "REFUSED", message = e$message)
      }
    )
  }

  # WOM is now per-category (see Step 4 above). No brand-level WOM.
  # Demographics + Ad Hoc are also per-category — see the per-category
  # block above; results land on category_results[[cat]]$demographics
  # and $adhoc and surface as sub-tabs inside each category panel.

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
# SHOPPER BEHAVIOUR DISPATCHER (per category)
# ==============================================================================

#' Run shopper-behaviour engines for one category
#'
#' Resolves the optional \code{channel.purchase.{CAT}} and
#' \code{cat_buying.packsize.{CAT}} roles via
#' \code{resolve_shopper_role_columns()} and dispatches to the
#' \code{run_shopper_*} engines when the columns and option sheet are both
#' present. Absent role / absent code-list / engine REFUSED all collapse
#' to \code{NULL}, which the panel renderer treats as "skip section".
#'
#' Engine errors are caught and surfaced through the \code{warnings} list
#' so the category-level pipeline never breaks because shopper data is
#' malformed.
#'
#' @return List with three slots: \code{location}, \code{packsize} (each
#'   either NULL or an engine result), and \code{warnings} (character
#'   vector to splice into the parent warnings list).
#' @keywords internal
.run_shopper_for_category <- function(structure, cat_code, cat_name,
                                       cat_data, pen_mat, brand_codes,
                                       weights, verbose = FALSE) {
  loc <- .run_shopper_one(
    structure, paste0("channel.purchase.", cat_code), "location",
    cat_data, pen_mat, brand_codes, weights, cat_name, verbose
  )
  pak <- .run_shopper_one(
    structure, paste0("cat_buying.packsize.", cat_code), "packsize",
    cat_data, pen_mat, brand_codes, weights, cat_name, verbose
  )
  list(
    location = loc$result,
    packsize = pak$result,
    warnings = c(loc$warnings, pak$warnings)
  )
}


# Single-engine dispatcher: resolves columns, checks they exist in cat_data,
# runs the appropriate engine, catches errors. Returns a list with
# \code{result} (NULL when the role / columns are absent -- legitimate
# "no question asked") and \code{warnings} (engine errors only; missing
# data is silent).
.run_shopper_one <- function(structure, role, kind, cat_data, pen_mat,
                              brand_codes, weights, cat_name, verbose) {

  spec <- tryCatch(
    resolve_shopper_role_columns(structure, role, kind),
    error = function(e) NULL
  )
  if (is.null(spec)) return(list(result = NULL, warnings = character(0)))

  cols_present <- spec$cols %in% names(cat_data)
  if (!any(cols_present)) {
    return(list(result = NULL, warnings = character(0)))
  }
  if (!all(cols_present)) {
    msg <- sprintf(
      "Shopper %s for %s: %d/%d expected columns missing - skipping section.",
      kind, cat_name, sum(!cols_present), length(spec$cols))
    return(list(result = NULL, warnings = msg))
  }

  if (verbose) cat(sprintf("  Running shopper %s...\n", kind))
  data_df <- cat_data[, spec$cols, drop = FALSE]
  fn <- if (identical(kind, "location")) run_shopper_location else run_shopper_packsize
  warnings <- character(0)
  res <- tryCatch(
    fn(data_df, spec$cols, spec$codes, spec$labels,
       pen_mat = pen_mat, brand_codes = brand_codes, weights = weights),
    error = function(e) {
      warnings <<- sprintf("Shopper %s failed for %s: %s",
                            kind, cat_name, e$message)
      list(status = "REFUSED", code = "CALC_ENGINE_ERROR",
           message = conditionMessage(e))
    }
  )
  list(result = res, warnings = warnings)
}


# ==============================================================================
# DEMOGRAPHICS DISPATCH (per-category)
# ==============================================================================
# Runs the demographics engine once per full category, against that
# category's filtered respondent set (cat_data). Buyer/tier cuts use the
# pen matrix produced upstream by the brand_volume + buyer_heaviness
# elements; brand_cut uses the per-category brand list. When upstream
# elements weren't run the cut sub-results collapse to NULL and the
# panel hides those tabs silently.

.run_demographics_for_category <- function(structure, config, cat_data,
                                            cat_weights, cat_brands, cat_name,
                                            brand_volume, buyer_heaviness,
                                            verbose = TRUE) {

  if (is.null(structure$questionmap) || nrow(structure$questionmap) == 0L) {
    return(list(status = "EMPTY",
                message = "Demographics needs a QuestionMap with demo.* roles."))
  }
  qmap <- structure$questionmap
  demo_rows <- qmap[grepl("^demo\\.", as.character(qmap$Role)), , drop = FALSE]
  if (nrow(demo_rows) == 0L) {
    return(list(status = "EMPTY",
                message = "No demo.* roles in QuestionMap; demographics tab hidden for this category."))
  }

  # Focal-brand buyer indicator + tier vector for THIS category. Both come
  # from the brand_volume + buyer_heaviness elements that ran earlier in
  # the same per-category loop.
  buyer_info <- .demo_buyer_for_category(brand_volume, buyer_heaviness,
                                          config$focal_brand)
  bmat_info  <- .demo_brand_matrix_for_category(brand_volume, cat_brands)

  questions <- list()
  for (i in seq_len(nrow(demo_rows))) {
    entry <- .demo_question_from_role(structure, demo_rows$Role[i],
                                       cat_data, cat_weights, buyer_info,
                                       bmat_info, verbose = verbose)
    if (!is.null(entry)) questions[[length(questions) + 1L]] <- entry
  }

  # Synthetic questions: Buyer-status (focal-brand pen) + Heaviness (category
  # tertiles). Both derive from buyer_info and render alongside the
  # demographic questions in the matrix view. Skipped when the upstream
  # vectors are unavailable (e.g. brand_volume refused, no tertile bounds).
  syn <- .demo_synthetic_questions(cat_data, cat_weights, buyer_info,
                                    bmat_info, config$focal_brand)
  for (q in syn) questions[[length(questions) + 1L]] <- q

  if (length(questions) == 0L) {
    return(list(status = "EMPTY",
                message = sprintf("No demographic questions resolved for %s.", cat_name)))
  }
  list(
    status        = "PASS",
    cat_name      = cat_name,
    questions     = questions,
    brand_codes   = bmat_info$brand_codes,
    brand_labels  = bmat_info$brand_labels,
    brand_colours = bmat_info$brand_colours,
    n_total       = nrow(cat_data),
    weighted      = !is.null(cat_weights)
  )
}


# Resolve one demo.* role and run the engine. Returns NULL when the role
# can't be resolved or its data column is absent (caller skips silently).
.demo_question_from_role <- function(structure, role, cat_data, cat_weights,
                                      buyer_info, bmat_info, verbose = TRUE) {
  role <- trimws(as.character(role))
  spec <- resolve_demographic_role(structure, role)
  if (is.null(spec) || !spec$column %in% names(cat_data)) {
    if (verbose) cat(sprintf("    Demographics skip %s (unresolved or missing)\n", role))
    return(NULL)
  }
  res <- run_demographic_question(
    values        = cat_data[[spec$column]],
    option_codes  = spec$codes,
    option_labels = spec$labels,
    weights       = cat_weights,
    focal_buyer   = buyer_info$focal_buyer,
    buyer_tiers   = buyer_info$tiers,
    pen_mat       = bmat_info$pen_mat,
    brand_codes   = bmat_info$brand_codes,
    brand_labels  = bmat_info$brand_labels
  )
  list(
    role          = spec$role,
    column        = spec$column,
    question_text = spec$question_text,
    short_label   = spec$short_label,
    variable_type = spec$variable_type,
    codes         = spec$codes,
    labels        = spec$labels,
    is_synthetic  = FALSE,
    synthetic_kind = NA_character_,
    result        = res
  )
}


# Build the two synthetic questions ("Buyer status" + "Heaviness") that are
# always shown at the end of the demographics matrix. Both reuse the engine
# so percentages + Wilson CIs + brand cuts are computed identically.
.demo_synthetic_questions <- function(cat_data, cat_weights, buyer_info,
                                       bmat_info, focal_brand) {
  out <- list()
  buyer <- .demo_synthetic_buyer_status(cat_data, cat_weights, buyer_info,
                                         bmat_info, focal_brand)
  if (!is.null(buyer)) out[[length(out) + 1L]] <- buyer
  hv    <- .demo_synthetic_heaviness(cat_data, cat_weights, buyer_info,
                                      bmat_info)
  if (!is.null(hv))    out[[length(out) + 1L]] <- hv
  out
}


.demo_synthetic_buyer_status <- function(cat_data, cat_weights, buyer_info,
                                          bmat_info, focal_brand) {
  fb <- buyer_info$focal_buyer
  if (is.null(fb)) return(NULL)
  vals <- ifelse(is.na(fb), NA_character_,
                 ifelse(as.integer(fb) > 0L, "BUYER", "NON_BUYER"))
  focal_lbl <- if (is.null(focal_brand) || !nzchar(focal_brand))
    "focal brand" else focal_brand
  res <- run_demographic_question(
    values        = vals,
    option_codes  = c("BUYER", "NON_BUYER"),
    option_labels = c(sprintf("Buyer of %s", focal_lbl),
                       sprintf("Non-buyer of %s", focal_lbl)),
    weights       = cat_weights,
    pen_mat       = bmat_info$pen_mat,
    brand_codes   = bmat_info$brand_codes,
    brand_labels  = bmat_info$brand_labels
  )
  list(
    role          = "demo.synthetic.buyer_status",
    column        = NA_character_,
    question_text = sprintf("Buyer status — %s", focal_lbl),
    short_label   = "Buyer status",
    variable_type = "Single_Response",
    codes         = c("BUYER", "NON_BUYER"),
    labels        = c(sprintf("Buyer of %s", focal_lbl),
                       sprintf("Non-buyer of %s", focal_lbl)),
    is_synthetic  = TRUE,
    synthetic_kind = "buyer_status",
    result        = res
  )
}


.demo_synthetic_heaviness <- function(cat_data, cat_weights, buyer_info,
                                       bmat_info) {
  tiers <- buyer_info$tiers
  if (is.null(tiers) || all(is.na(tiers))) return(NULL)
  res <- run_demographic_question(
    values        = tiers,
    option_codes  = c("LIGHT", "MEDIUM", "HEAVY"),
    option_labels = c("Light category buyer", "Medium category buyer",
                       "Heavy category buyer"),
    weights       = cat_weights,
    pen_mat       = bmat_info$pen_mat,
    brand_codes   = bmat_info$brand_codes,
    brand_labels  = bmat_info$brand_labels
  )
  list(
    role          = "demo.synthetic.heaviness",
    column        = NA_character_,
    question_text = "Buyer heaviness (category tertiles)",
    short_label   = "Heaviness",
    variable_type = "Single_Response",
    codes         = c("LIGHT", "MEDIUM", "HEAVY"),
    labels        = c("Light category buyer", "Medium category buyer",
                       "Heavy category buyer"),
    is_synthetic  = TRUE,
    synthetic_kind = "heaviness",
    result        = res
  )
}


.demo_buyer_for_category <- function(brand_volume, buyer_heaviness, focal_brand) {
  if (is.null(focal_brand) || !nzchar(focal_brand) ||
      is.null(brand_volume) || identical(brand_volume$status, "REFUSED") ||
      is.null(brand_volume$pen_mat)) {
    return(list(focal_buyer = NULL, tiers = NULL))
  }
  bcs <- as.character(colnames(brand_volume$pen_mat))
  if (!focal_brand %in% bcs) return(list(focal_buyer = NULL, tiers = NULL))
  j <- which(bcs == focal_brand)[1L]
  pen_vec <- brand_volume$pen_mat[, j]
  buyer <- as.integer(!is.na(pen_vec) & pen_vec > 0)

  tiers <- rep(NA_character_, length(buyer))
  if (!is.null(buyer_heaviness) &&
      !identical(buyer_heaviness$status, "REFUSED") &&
      !is.null(buyer_heaviness$tertile_bounds)) {
    q33 <- buyer_heaviness$tertile_bounds$light[2L]
    q67 <- buyer_heaviness$tertile_bounds$heavy[1L]
    if (is.finite(q33) && is.finite(q67) && !is.null(brand_volume$m_vec)) {
      m <- brand_volume$m_vec
      is_buy <- buyer == 1L
      tiers[is_buy & m <= q33]                   <- "LIGHT"
      tiers[is_buy & m > q33 & m <= q67]         <- "MEDIUM"
      tiers[is_buy & m > q67]                    <- "HEAVY"
    }
  }
  list(focal_buyer = buyer, tiers = tiers)
}


.demo_brand_matrix_for_category <- function(brand_volume, cat_brands) {
  if (is.null(brand_volume) || identical(brand_volume$status, "REFUSED") ||
      is.null(brand_volume$pen_mat)) {
    return(list(pen_mat = NULL, brand_codes = character(0),
                brand_labels = character(0), brand_colours = list()))
  }
  bcs <- as.character(colnames(brand_volume$pen_mat))
  bls <- bcs
  cols <- list()
  if (!is.null(cat_brands) && nrow(cat_brands) > 0L) {
    if ("BrandLabel" %in% names(cat_brands)) {
      lookup <- stats::setNames(as.character(cat_brands$BrandLabel),
                                 as.character(cat_brands$BrandCode))
      bls <- ifelse(bcs %in% names(lookup), lookup[bcs], bcs)
    }
    if ("Colour" %in% names(cat_brands)) {
      for (i in seq_len(nrow(cat_brands))) {
        bc <- trimws(as.character(cat_brands$BrandCode[i]))
        col <- trimws(as.character(cat_brands$Colour[i]))
        if (nzchar(bc) && nzchar(col) &&
            grepl("^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", col)) {
          cols[[bc]] <- col
        }
      }
    }
  }
  list(pen_mat       = brand_volume$pen_mat,
       brand_codes   = bcs,
       brand_labels  = bls,
       brand_colours = cols)
}


# Legacy brand-level demographics dispatcher kept for callers that still
# need a sample-wide view (none currently — engine runs per-category in
# the orchestrator loop). Retained as an unused helper signature stub so
# the function name remains greppable in case the brand-level view returns.
.run_demographics_brand_level <- function(data, structure, config, weights,
                                          category_results, verbose = TRUE) {

  if (is.null(structure$questionmap) || nrow(structure$questionmap) == 0L) {
    return(list(status = "REFUSED", code = "CFG_NO_QUESTIONMAP",
                message = "Demographics needs a QuestionMap with demo.* roles."))
  }

  qmap <- structure$questionmap
  demo_rows <- qmap[grepl("^demo\\.", as.character(qmap$Role)), , drop = FALSE]
  if (nrow(demo_rows) == 0L) {
    return(list(status = "EMPTY",
                message = "No demo.* roles in QuestionMap; demographics tab hidden."))
  }

  # Build a brand-level focal-buyer vector + tier classification by union of
  # full categories. Non-buyers are respondents with no purchase in any cat.
  buyer_info <- .demo_brand_level_buyer_vector(data, category_results,
                                                config$focal_brand)

  # Cross-category brand pen matrix: union of pen vectors across full cats.
  bmat_info <- .demo_brand_level_brand_matrix(data, category_results, structure)

  questions <- list()
  for (i in seq_len(nrow(demo_rows))) {
    role <- trimws(as.character(demo_rows$Role[i]))
    spec <- resolve_demographic_role(structure, role)
    if (is.null(spec)) {
      if (verbose) cat(sprintf("  Demographics: skipping %s (unresolved)\n", role))
      next
    }
    if (!spec$column %in% names(data)) {
      if (verbose) cat(sprintf("  Demographics: skipping %s (column %s missing)\n",
                                role, spec$column))
      next
    }

    res <- run_demographic_question(
      values        = data[[spec$column]],
      option_codes  = spec$codes,
      option_labels = spec$labels,
      weights       = weights,
      focal_buyer   = buyer_info$focal_buyer,
      buyer_tiers   = buyer_info$tiers,
      pen_mat       = bmat_info$pen_mat,
      brand_codes   = bmat_info$brand_codes,
      brand_labels  = bmat_info$brand_labels
    )

    questions[[length(questions) + 1L]] <- list(
      role          = spec$role,
      column        = spec$column,
      question_text = spec$question_text,
      short_label   = spec$short_label,
      variable_type = spec$variable_type,
      codes         = spec$codes,
      labels        = spec$labels,
      result        = res
    )
  }

  if (length(questions) == 0L) {
    return(list(status = "EMPTY",
                message = "No demographic questions could be resolved."))
  }

  list(
    status        = "PASS",
    questions     = questions,
    brand_codes   = bmat_info$brand_codes,
    brand_labels  = bmat_info$brand_labels,
    n_total       = nrow(data),
    weighted      = !is.null(weights)
  )
}


# Build the focal-brand buyer indicator across all full categories. A
# respondent is a buyer iff they purchased the focal brand in ANY full
# category (BRANDPEN2_<CAT>_<BRAND> > 0). Tiers use the per-category
# buyer-heaviness tertiles where available; respondents are assigned to the
# heaviest tier they appear in across categories.
.demo_brand_level_buyer_vector <- function(data, category_results, focal_brand) {

  if (is.null(focal_brand) || !nzchar(focal_brand)) {
    return(list(focal_buyer = NULL, tiers = NULL))
  }

  n <- nrow(data)
  buyer  <- rep(0L, n)
  tiers  <- rep(NA_character_, n)
  rank   <- c(LIGHT = 1L, MEDIUM = 2L, HEAVY = 3L)

  for (cat_name in names(category_results)) {
    cr <- category_results[[cat_name]]
    if (is.null(cr$brand_volume) || identical(cr$brand_volume$status, "REFUSED")) next
    bv <- cr$brand_volume
    if (is.null(bv$pen_mat) || is.null(bv$m_vec)) next

    bcs <- as.character(colnames(bv$pen_mat))
    if (!focal_brand %in% bcs) next
    j <- which(bcs == focal_brand)[1L]

    # bv$pen_mat rows correspond to focal-category respondents; the brand
    # volume builder filters to focal_category respondents only. Match back
    # to full-data row indices via the Focal_Category column.
    focal_col <- "Focal_Category"
    if (!focal_col %in% names(data)) next
    cat_code <- bv$cat_code %||%
      .demo_resolve_cat_code_from_results(cat_name, cr)
    if (is.null(cat_code)) next

    rows_in_cat <- which(!is.na(data[[focal_col]]) &
                            data[[focal_col]] == cat_code)
    if (length(rows_in_cat) != nrow(bv$pen_mat)) next  # row alignment broken

    is_buyer <- bv$pen_mat[, j] > 0
    buyer[rows_in_cat[is_buyer]] <- 1L

    # Tier classification: use buyer_heaviness tertile bounds when available
    bh <- cr$buyer_heaviness
    if (!is.null(bh) && !identical(bh$status, "REFUSED") &&
        !is.null(bh$tertile_bounds)) {
      q33 <- bh$tertile_bounds$light[2L]
      q67 <- bh$tertile_bounds$heavy[1L]
      if (is.finite(q33) && is.finite(q67)) {
        m_focal <- bv$m_vec
        for (k in which(is_buyer)) {
          row_idx <- rows_in_cat[k]
          tier <- if (m_focal[k] <= q33) "LIGHT" else
                  if (m_focal[k] <= q67) "MEDIUM" else "HEAVY"
          # Keep the heaviest classification across categories
          old <- tiers[row_idx]
          if (is.na(old) || rank[[tier]] > rank[[old]]) tiers[row_idx] <- tier
        }
      }
    }
  }

  list(focal_buyer = buyer, tiers = tiers)
}


# Resolve the short category code (e.g. "DSS") used to filter Focal_Category.
# Falls back to a pen-prefix detection when results don't carry it explicitly.
.demo_resolve_cat_code_from_results <- function(cat_name, cat_result) {
  if (!is.null(cat_result$mental_availability) &&
      !is.null(cat_result$mental_availability$cat_code)) {
    return(cat_result$mental_availability$cat_code)
  }
  if (!is.null(cat_result$funnel) && !is.null(cat_result$funnel$meta)) {
    cc <- cat_result$funnel$meta$category_code
    if (!is.null(cc) && nzchar(cc)) return(cc)
  }
  # Last resort: 3-letter uppercase tail of cat_name
  toupper(substr(gsub("[^A-Za-z]", "", cat_name), 1L, 3L))
}


# Build a brand-level pen matrix that maps full-data rows to brands across
# all full categories. Each column is a brand; cell = 1 if respondent
# bought that brand in any full category they participated in.
.demo_brand_level_brand_matrix <- function(data, category_results, structure) {

  brand_codes  <- character(0)
  brand_labels <- character(0)
  cat_pens     <- list()

  for (cat_name in names(category_results)) {
    cr <- category_results[[cat_name]]
    if (is.null(cr$brand_volume) || identical(cr$brand_volume$status, "REFUSED")) next
    bv <- cr$brand_volume
    if (is.null(bv$pen_mat)) next
    bcs <- as.character(colnames(bv$pen_mat))
    new <- setdiff(bcs, brand_codes)
    brand_codes <- c(brand_codes, new)
    cat_pens[[cat_name]] <- list(pen = bv$pen_mat, codes = bcs,
                                  cat_code = bv$cat_code %||%
                                    .demo_resolve_cat_code_from_results(cat_name, cr))
  }

  if (length(brand_codes) == 0L) {
    return(list(pen_mat = NULL, brand_codes = character(0),
                brand_labels = character(0)))
  }

  # Brand labels lookup from structure$brands (first occurrence wins)
  if (!is.null(structure$brands) && nrow(structure$brands) > 0L) {
    bn <- structure$brands
    for (bc in brand_codes) {
      lbl <- bc
      r <- bn[!is.na(bn$BrandCode) & as.character(bn$BrandCode) == bc, , drop = FALSE]
      if (nrow(r) > 0L && "BrandLabel" %in% names(r)) {
        lbl <- as.character(r$BrandLabel[1L])
      }
      brand_labels <- c(brand_labels, lbl)
    }
  } else {
    brand_labels <- brand_codes
  }

  pen <- matrix(0L, nrow = nrow(data), ncol = length(brand_codes))
  colnames(pen) <- brand_codes

  focal_col <- "Focal_Category"
  for (info in cat_pens) {
    if (!focal_col %in% names(data)) break
    rows_in_cat <- which(!is.na(data[[focal_col]]) &
                          data[[focal_col]] == info$cat_code)
    if (length(rows_in_cat) != nrow(info$pen)) next
    for (j in seq_along(info$codes)) {
      bc <- info$codes[j]
      col_idx <- match(bc, brand_codes)
      bought  <- info$pen[, j] > 0
      pen[rows_in_cat[bought], col_idx] <- 1L
    }
  }

  list(pen_mat = pen, brand_codes = brand_codes, brand_labels = brand_labels)
}


# ==============================================================================
# AD HOC DISPATCH V2 (role-map driven, per-category)
# ==============================================================================
# v2 sibling of .run_adhoc_for_category. Walks role_map for ^adhoc\.* keys
# instead of the legacy QuestionMap. ALL-scoped questions use data_full,
# CATCODE-scoped questions use cat_data + the per-category brand-cut matrix
# from brand_volume. Returns the legacy-shape PASS payload (questions[],
# n_total, weighted) when at least one role resolves; otherwise the v2
# placeholder so the panel-data renderer can show "Data not yet collected
# for Ad Hoc" — matching the placeholder pattern across the rebuild.

.run_adhoc_for_category_v2 <- function(role_map, structure, config,
                                        data_full, weights_full,
                                        cat_data, cat_weights, cat_brands,
                                        cat_name, cat_code, brand_volume,
                                        verbose = TRUE) {

  bmat <- .demo_brand_matrix_for_category(brand_volume, cat_brands)

  # ALL-scope: sample-wide context, no brand cut.
  out_all <- run_adhoc_v2(
    role_map     = role_map, structure = structure, data = data_full,
    weights      = weights_full, scope_filter = "ALL",
    pen_mat      = NULL,
    brand_codes  = character(0), brand_labels = character(0)
  )

  # CATCODE-scope: focal-category respondents with this cat's brand cuts.
  out_cat <- if (!is.null(cat_code) && nzchar(cat_code))
    run_adhoc_v2(
      role_map     = role_map, structure = structure, data = cat_data,
      weights      = cat_weights, scope_filter = cat_code,
      pen_mat      = bmat$pen_mat,
      brand_codes  = bmat$brand_codes, brand_labels = bmat$brand_labels
    )
  else list(questions = list(), placeholder = TRUE)

  questions <- c(out_all$questions %||% list(),
                 out_cat$questions %||% list())

  if (length(questions) == 0L) {
    return(list(
      status      = "PASS",
      placeholder = TRUE,
      cat_name    = cat_name, cat_code = cat_code,
      questions   = list(),
      n_total     = nrow(cat_data),
      weighted    = !is.null(cat_weights),
      note        = ADHOC_PLACEHOLDER_NOTE
    ))
  }

  list(status   = "PASS",
       cat_name = cat_name, cat_code = cat_code,
       questions = questions,
       n_total   = nrow(cat_data),
       weighted  = !is.null(cat_weights))
}


# ==============================================================================
# AD HOC DISPATCH (per-category, legacy QuestionMap path — superseded by v2)
# ==============================================================================
# For each category, picks up:
#   - adhoc.<key>.<CATCODE>  rows belonging to this category, scoped to
#     cat_data (focal-category respondents) with this cat's brand cuts;
#   - adhoc.<key>.ALL        rows scoped to ALL respondents (use full data)
#     so the same brand-level question shows up consistently in every
#     category panel without re-asking, and is rendered as a separate
#     "Across all respondents" group inside the panel.

.run_adhoc_for_category <- function(structure, config, data_full, weights_full,
                                     cat_data, cat_weights, cat_brands, cat_name,
                                     cat_code, brand_volume, verbose = TRUE) {

  if (is.null(structure$questionmap) || nrow(structure$questionmap) == 0L) {
    return(list(status = "EMPTY",
                message = "No QuestionMap; ad hoc tab hidden for this category."))
  }
  qmap <- structure$questionmap
  rows <- qmap[grepl("^adhoc\\.", as.character(qmap$Role)), , drop = FALSE]
  if (nrow(rows) == 0L) {
    return(list(status = "EMPTY",
                message = "No adhoc.* roles in QuestionMap; ad hoc tab hidden."))
  }

  # Per-category brand pen for the per-category brand_cut. ALL-scope
  # questions don't get a brand_cut (sample-wide context, no scope match).
  bmat <- .demo_brand_matrix_for_category(brand_volume, cat_brands)

  questions <- list()
  for (i in seq_len(nrow(rows))) {
    role <- trimws(as.character(rows$Role[i]))
    spec <- resolve_adhoc_role(structure, role)
    if (is.null(spec)) next

    sc <- spec$scope %||% "ALL"
    is_all <- identical(sc, "ALL")
    is_cat <- !is.null(cat_code) && nzchar(cat_code) && identical(sc, cat_code)
    if (!is_all && !is_cat) next  # belongs to another category

    if (is_all) {
      if (!spec$column %in% names(data_full)) next
      values  <- data_full[[spec$column]]
      weights <- weights_full
      pen     <- NULL  # ALL-scope is sample-wide; brand cut not meaningful here
      brand_codes <- character(0)
      brand_labels <- character(0)
      n_scope_base <- nrow(data_full)
    } else {
      if (!spec$column %in% names(cat_data)) next
      values  <- cat_data[[spec$column]]
      weights <- cat_weights
      pen     <- bmat$pen_mat
      brand_codes  <- bmat$brand_codes
      brand_labels <- bmat$brand_labels
      n_scope_base <- nrow(cat_data)
    }

    res <- run_adhoc_question(
      values        = values,
      option_codes  = spec$codes,
      option_labels = spec$labels,
      weights       = weights,
      pen_mat       = pen,
      brand_codes   = brand_codes,
      brand_labels  = brand_labels,
      variable_type = spec$variable_type
    )
    questions[[length(questions) + 1L]] <- list(
      role = spec$role, column = spec$column, scope = sc,
      question_text = spec$question_text, short_label = spec$short_label,
      variable_type = spec$variable_type,
      codes = spec$codes, labels = spec$labels,
      brand_codes = brand_codes, brand_labels = brand_labels,
      n_scope_base = n_scope_base, result = res
    )
  }

  if (length(questions) == 0L) {
    return(list(status = "EMPTY",
                message = sprintf("No ad hoc questions resolved for %s.", cat_name)))
  }
  list(status = "PASS",
       cat_name = cat_name, cat_code = cat_code,
       questions = questions,
       n_total = nrow(cat_data),
       weighted = !is.null(cat_weights))
}


# Legacy brand-level dispatcher (kept as a stub; engine now per-category).
# ==============================================================================
# AD HOC DISPATCH (brand-level, legacy)
# ==============================================================================
# Walks "adhoc.<key>.<scope>" rows. Scope = "ALL" runs over the whole
# sample; scope = a category code runs only over respondents in that
# focal category. The brand_cut matrix uses the corresponding category's
# pen matrix when scoped, or the union pen matrix when ALL.

.run_adhoc_brand_level <- function(data, structure, config, weights, categories,
                                   verbose = TRUE) {

  if (is.null(structure$questionmap) || nrow(structure$questionmap) == 0L) {
    return(list(status = "EMPTY",
                message = "No QuestionMap; ad hoc tab hidden."))
  }

  qmap <- structure$questionmap
  rows <- qmap[grepl("^adhoc\\.", as.character(qmap$Role)), , drop = FALSE]
  if (nrow(rows) == 0L) {
    return(list(status = "EMPTY",
                message = "No adhoc.* roles in QuestionMap; ad hoc tab hidden."))
  }

  # Pre-compute brand pen matrices keyed by category code (for category-scoped
  # ad hoc questions). ALL-scope falls back to the union matrix used by the
  # demographics dispatcher.
  cat_pen_by_code <- list()
  if (!is.null(structure$brands)) {
    for (i in seq_len(nrow(categories))) {
      cat_name <- categories$Category[i]
      pen_qs <- get_questions_for_battery(structure, "penetration", cat_name)
      if (nrow(pen_qs) == 0L) next
      pen_prefix <- pen_qs$QuestionCode[1L]
      cat_brands <- get_brands_for_category(structure, cat_name)
      cat_code <- toupper(substr(gsub("[^A-Za-z]", "", cat_name), 1L, 3L))
      bcs <- as.character(cat_brands$BrandCode)
      pen <- matrix(0L, nrow = nrow(data), ncol = length(bcs))
      colnames(pen) <- bcs
      for (b in seq_along(bcs)) {
        col <- .find_brand_col(data, pen_prefix, bcs[b])
        if (!is.null(col)) {
          v <- data[[col]]
          pen[, b] <- as.integer(!is.na(v) & v > 0)
        }
      }
      bn <- if ("BrandLabel" %in% names(cat_brands))
        as.character(cat_brands$BrandLabel) else bcs
      cat_pen_by_code[[cat_code]] <- list(pen_mat = pen, brand_codes = bcs,
                                            brand_labels = bn,
                                            cat_name = cat_name)
    }
  }

  questions <- list()
  for (i in seq_len(nrow(rows))) {
    role <- trimws(as.character(rows$Role[i]))
    spec <- resolve_adhoc_role(structure, role)
    if (is.null(spec)) {
      if (verbose) cat(sprintf("  Ad hoc: skipping %s (unresolved)\n", role))
      next
    }
    if (!spec$column %in% names(data)) {
      if (verbose) cat(sprintf("  Ad hoc: skipping %s (column %s missing)\n",
                                role, spec$column))
      next
    }

    scope <- spec$scope %||% "ALL"
    if (scope == "ALL") {
      scope_rows <- rep(TRUE, nrow(data))
      pen_info <- list(pen_mat = NULL, brand_codes = character(0),
                       brand_labels = character(0))
    } else {
      focal_col <- "Focal_Category"
      if (!focal_col %in% names(data)) {
        if (verbose) cat(sprintf("  Ad hoc: %s — no Focal_Category column to scope by\n",
                                  role))
        next
      }
      scope_rows <- !is.na(data[[focal_col]]) & data[[focal_col]] == scope
      info <- cat_pen_by_code[[scope]]
      if (is.null(info)) {
        pen_info <- list(pen_mat = NULL, brand_codes = character(0),
                         brand_labels = character(0))
      } else {
        # Sub-set the pen matrix to scope rows
        pen_info <- list(
          pen_mat      = info$pen_mat[scope_rows, , drop = FALSE],
          brand_codes  = info$brand_codes,
          brand_labels = info$brand_labels
        )
      }
    }

    scope_data    <- data[scope_rows, , drop = FALSE]
    scope_weights <- if (!is.null(weights)) weights[scope_rows] else NULL

    res <- run_adhoc_question(
      values        = scope_data[[spec$column]],
      option_codes  = spec$codes,
      option_labels = spec$labels,
      weights       = scope_weights,
      pen_mat       = pen_info$pen_mat,
      brand_codes   = pen_info$brand_codes,
      brand_labels  = pen_info$brand_labels,
      variable_type = spec$variable_type
    )

    questions[[length(questions) + 1L]] <- list(
      role          = spec$role,
      column        = spec$column,
      question_text = spec$question_text,
      short_label   = spec$short_label,
      variable_type = spec$variable_type,
      scope         = scope,
      codes         = spec$codes,
      labels        = spec$labels,
      brand_codes   = pen_info$brand_codes,
      brand_labels  = pen_info$brand_labels,
      n_scope_base  = sum(scope_rows),
      result        = res
    )
  }

  if (length(questions) == 0L) {
    return(list(status = "EMPTY",
                message = "No ad hoc questions could be resolved."))
  }

  list(
    status    = "PASS",
    questions = questions,
    n_total   = nrow(data),
    weighted  = !is.null(weights)
  )
}


# ==============================================================================
# PORTFOLIO DATA (cross-category, full respondent base)
# ==============================================================================

#' Compute cross-category portfolio data (thin wrapper)
#'
#' Delegates to \code{run_portfolio()} for the full portfolio analysis.
#' Preserves the \code{results$portfolio} output key for backwards
#' compatibility with downstream code.
#'
#' @keywords internal
.compute_portfolio_data <- function(data, categories, structure, config, weights) {
  run_portfolio(data, categories, structure, config, weights)
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand module loaded (v%s)", BRAND_VERSION))
}
