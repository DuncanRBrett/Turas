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
    "00_guard_role_map.R",
    "01_config.R",
    "02_mental_availability.R",
    "02b_mental_advantage.R",
    "02c_ma_focal_view.R",
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
  if (!is.null(weight_col) && !is.na(weight_col) && nchar(trimws(weight_col)) > 0 &&
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
    msg <- sprintf("Role map build failed: %s", e$message)
    cat(sprintf(
      "\n=== TURAS BRAND ERROR ===\n[CFG_ROLE_MAP_BUILD_FAILED] %s\nHow to fix: Check Survey_Structure.xlsx has a Questions sheet with valid Role column. All v2 elements will be skipped.\n=========================\n\n",
      msg
    ))
    warnings_list <<- c(warnings_list,
      sprintf("%s — v2 elements will skip", msg))
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

    # Resolve the short category code early so brand/cep/attr lookups can use
    # it for unambiguous CategoryCode matching (guards against misconfigured
    # Category display-name columns in the structure file).
    focal_col  <- config$focal_category_col %||% "Focal_Category"
    cat_code   <- if (cat_depth == "full" &&
                      "CategoryCode" %in% names(categories) &&
                      !is.na(categories$CategoryCode[i]) &&
                      nzchar(as.character(categories$CategoryCode[i]))) {
                    as.character(categories$CategoryCode[i])
                  } else NULL

    cat_brands <- get_brands_for_category(structure, cat_name, cat_code = cat_code)
    cat_ceps   <- get_ceps_for_category(structure, cat_name, cat_code = cat_code)
    cat_attrs  <- get_attributes_for_category(structure, cat_name, cat_code = cat_code)

    cat_result <- list(category = cat_name, cat_code = cat_code,
                       analysis_depth = cat_depth)
    linkage    <- NULL  # populated by MA block; used by D&B

    # Filter data to focal respondents for this category. Focal filtering is
    # used for WOM so each category's WOM metrics reflect its own respondent
    # group and brand list. IPK rebuild configs always supply CategoryCode;
    # legacy QuestionMap detection was removed in the v2 cutover (stage 3).
    cat_data   <- if (!is.null(cat_code) && focal_col %in% names(data)) {
                    data[!is.na(data[[focal_col]]) &
                         data[[focal_col]] == cat_code, ]
                  } else data
    cat_weights <- if (!is.null(weights) && !is.null(cat_code) &&
                       focal_col %in% names(data)) {
                     weights[!is.na(data[[focal_col]]) &
                             data[[focal_col]] == cat_code]
                   } else weights

    # Mental Availability (full categories only — awareness_only cats have no CEPs).
    # v2 entry walks role_map for mental_avail.cep.{cat}.* (and .attr.* for the
    # brand-image battery) and rebuilds the linkage tensor from slot-indexed
    # data via multi_mention_brand_matrix(). Legacy
    # build_cep_linkage_from_matrix() retained as fallback.
    if (isTRUE(config$element_mental_avail) && nrow(cat_ceps) > 0 &&
        cat_depth == "full") {
      if (verbose) cat("  Running Mental Availability...\n")

      use <- !is.null(role_map) && !is.null(cat_code)

      linkage <- tryCatch(
        if (use) {
          build_cep_linkage(cat_data, role_map, cat_code, cat_brands,
                                item_kind = "cep")
        } else {
          cep_questions <- get_questions_for_battery(structure,
                                                     "cep_matrix", cat_name)
          cep_col_codes <- if (nrow(cep_questions) > 0)
            cep_questions$QuestionCode else cat_ceps$CEPCode
          build_cep_linkage_from_matrix(cat_data, cep_col_codes,
                                        cat_brands$BrandCode)
        },
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("MA failed for %s: %s", cat_name, e$message))
          NULL
        }
      )

      if (!is.null(linkage)) {
        # Map item codes to display text. v2 returns CEP01/CEP02/...
        # already; cat_ceps carries the matching CEPText rows.
        cep_col_codes <- linkage$cep_codes
        cep_labels_mapped <- data.frame(
          CEPCode = cep_col_codes,
          CEPText = .ma_resolve_cep_labels(cep_col_codes, cat_ceps,
                                           use,
                                           if (!use)
                                             get_questions_for_battery(
                                               structure, "cep_matrix",
                                               cat_name)
                                           else NULL),
          stringsAsFactors = FALSE
        )

        # Brand image attributes (optional — same matrix shape as CEP)
        attr_linkage <- NULL
        if (!is.null(cat_attrs) && nrow(cat_attrs) > 0) {
          attr_linkage <- tryCatch(
            if (use)
              build_cep_linkage(cat_data, role_map, cat_code, cat_brands,
                                    item_kind = "attr")
            else
              build_cep_linkage_from_matrix(cat_data, cat_attrs$AttrCode,
                                             cat_brands$BrandCode),
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

        # MA Focal Brand View — pairs MA scores with the focal brand's
        # buyer/non-buyer linkage gap (replaces the standalone Drivers &
        # Barriers HTML page; D&B Excel/CSV outputs are unchanged).
        # Computed for EVERY brand so the in-page focal picker can
        # re-render the table without re-running R. Data is keyed by
        # brand_code under focal_view$ceps$by_brand and
        # focal_view$attributes$by_brand.
        if (!is.null(cat_result$mental_availability) &&
            !identical(cat_result$mental_availability$status, "REFUSED") &&
            exists("calculate_ma_focal_view", mode = "function")) {

          pen_role  <- paste0("funnel.penetration_target.", cat_code)
          pen_entry <- if (!is.null(role_map)) role_map[[pen_role]] else NULL
          all_brand_codes <- as.character(cat_brands$BrandCode)

          pen_mat <- if (!is.null(pen_entry) &&
                          !is.null(pen_entry$column_root) &&
                          exists("multi_mention_brand_matrix",
                                 mode = "function")) {
            tryCatch(
              multi_mention_brand_matrix(
                cat_data, pen_entry$column_root, all_brand_codes),
              error = function(e) NULL
            )
          } else NULL

          if (!is.null(pen_mat)) {
            ma_obj <- cat_result$mental_availability
            default_brand <- config$focal_brand %||% all_brand_codes[1]
            fv <- list()

            .build_fv_set <- function(advantage, link_tensor, label) {
              if (is.null(advantage) || is.null(link_tensor)) return(NULL)
              by_brand <- list()
              codes <- advantage$stim_codes
              for (b in all_brand_codes) {
                if (!b %in% colnames(pen_mat)) next
                if (!b %in% names(link_tensor)) next
                if (!b %in% colnames(advantage$advantage)) next
                pen_b <- as.integer(pen_mat[, b])
                df <- tryCatch(
                  calculate_ma_focal_view(
                    linkage_tensor = link_tensor,
                    codes          = codes,
                    focal_brand    = b,
                    pen            = pen_b,
                    weights        = cat_weights,
                    ma_advantage   = as.numeric(advantage$advantage[, b]),
                    ma_significant = as.logical(advantage$is_significant[, b])),
                  error = function(e) {
                    warnings_list <<- c(warnings_list,
                      sprintf("MA focal view (%s/%s) failed for %s: %s",
                              label, b, cat_name, e$message))
                    NULL
                  })
                if (!is.null(df) && nrow(df) > 0)
                  by_brand[[b]] <- df
              }
              if (length(by_brand) == 0) return(NULL)
              list(by_brand = by_brand,
                   default_brand_code = default_brand)
            }

            fv$ceps       <- .build_fv_set(ma_obj$cep_advantage,
                                           linkage$linkage_tensor, "CEP")
            fv$attributes <- .build_fv_set(ma_obj$attribute_advantage,
                                           attr_linkage$linkage_tensor, "Attr")

            if (!is.null(fv$ceps) || !is.null(fv$attributes))
              cat_result$mental_availability$focal_view <- fv
          }
        }
      }
    }

    # Funnel (role-registry architecture; full categories only). v2 path
    # passes the global role_map (built once after Step 3) directly to
    # run_funnel — no per-category QuestionMap normalisation needed because
    # v2 role names already carry the .{cat} suffix that .lookup_role
    if (isTRUE(config$element_funnel) && cat_depth == "full") {
      if (verbose) cat("  Running Funnel...\n")

      cat_result$funnel <- .run_funnel_for_category(
        data = cat_data, role_map = role_map, cat_brands = cat_brands,
        cat_code = cat_code, config = config, weights = cat_weights,
        cat_name = cat_name
      )
    }

    # Repertoire (full categories only). v2 rebuilds penetration +
    # frequency matrices from role_map directly.
    if (isTRUE(config$element_repertoire) && cat_depth == "full") {
      if (verbose) cat("  Running Repertoire...\n")

      cat_result$repertoire <- tryCatch(
        run_repertoire_v2(
          data        = cat_data,
          role_map    = role_map,
          cat_code    = cat_code,
          brand_list  = cat_brands,
          focal_brand = config$focal_brand,
          weights     = cat_weights
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

    # WOM (full categories only; filtered to focal respondents for this category).
    # v2 entry walks role_map for wom.{pos|neg}_{rec|share}.{cat} +
    # wom.{pos|neg}_count.{cat} keys; legacy run_wom (column-prefix sniffing
    # via get_questions_for_battery) only used when role_map is unavailable.
    if (isTRUE(config$element_wom) && cat_depth == "full") {
      if (verbose) cat("  Running WOM...\n")
      cat_result$wom <- tryCatch(
        run_wom(
          data        = cat_data,
          role_map    = role_map,
          cat_code    = cat_code,
          brand_list  = cat_brands,
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

    # Branded Reach (full categories only; v2 entry — placeholder-aware).
    # When structure has no MarketingReach sheet (IPK Wave 1), v2 returns a
    # PASS placeholder so the panel-data renderer can show "Data not yet
    # collected for Branded Reach". Otherwise delegates to run_branded_reach.
    if (isTRUE(config$element_branded_reach) && cat_depth == "full") {
      if (verbose) cat("  Running Branded Reach...\n")
      cat_result$branded_reach <- tryCatch(
        run_branded_reach(
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
            data = cat_data, role_map = role_map,
            cat_code = cat_code %||% "",
            cat_name = cat_name,
            cat_brands = cat_brands,
            focal_brand = config$focal_brand,
            audiences = al_audiences,
            structure = structure, config = config,
            weights = cat_weights,
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

    # Drivers & Barriers (full categories only). v2 rebuilds linkage
    # + CEP-brand matrix + focal-buyer flag from role_map directly.
    if (isTRUE(config$element_drivers_barriers) && cat_depth == "full") {
      if (verbose) cat("  Running Drivers & Barriers...\n")

      cep_labels_df <- if (!is.null(cat_ceps) && nrow(cat_ceps) > 0)
        data.frame(CEPCode = cat_ceps$CEPCode,
                   CEPText = cat_ceps$CEPText,
                   stringsAsFactors = FALSE) else NULL

      cat_result$drivers_barriers <- tryCatch(
        run_drivers_barriers_v2(
          data        = cat_data,
          role_map    = role_map,
          cat_code    = cat_code,
          brand_list  = cat_brands,
          focal_brand = config$focal_brand,
          cep_labels  = cep_labels_df,
          weights     = cat_weights
        ),
        error = function(e) {
          warnings_list <<- c(warnings_list,
            sprintf("Drivers & Barriers failed for %s: %s", cat_name, e$message))
          list(status = "REFUSED", message = e$message)
        }
      )
    }

    # Demographics (per-category; full categories only). v2 dispatcher walks
    # role_map for ^demographics\.* keys via demographic_question_from_role.
    # Synthetic questions (Buyer Status + Heaviness) are unchanged.
    if (isTRUE(config$element_demographics %||% TRUE) && cat_depth == "full") {
      if (verbose) cat("  Running Demographics...\n")
      cat_result$demographics <- tryCatch(
        .run_demographics_for_category(
          role_map    = role_map, structure = structure, config = config,
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
    if (isTRUE(config$element_adhoc %||% TRUE) && cat_depth == "full") {
      if (verbose) cat("  Running Ad Hoc...\n")
      cat_result$adhoc <- tryCatch(
        .run_adhoc_for_category(
          role_map     = role_map, structure = structure, config = config,
          data_full    = data, weights_full = weights,
          cat_data     = cat_data, cat_weights = cat_weights,
          cat_brands   = cat_brands, cat_name = cat_name,
          cat_code     = cat_code,
          brand_volume = cat_result$brand_volume,
          verbose      = verbose
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
  # not from per-category filtered subsets. role_map is threaded through
  # every sub-analysis so awareness columns resolve via slot-indexed
  # parser-shape data.
  results$portfolio <- .compute_portfolio_data(data, categories, structure,
                                               config, weights,
                                               role_map = role_map)

  # --- STEP 5b: Portfolio Overview (focal-brand view across ALL categories) ---
  # Deep-dive AND awareness-only categories together, enriched with pen/SCR/vol
  # for deep-dive cats from category_results. Uses the global role_map for
  # slot-indexed BRANDAWARE_{cat} lookups.
  results$portfolio_overview <- tryCatch(
    compute_portfolio_overview_data(
      data, role_map, categories, structure, config,
      weights          = weights,
      category_results = category_results),
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
      run_dba(
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

#' Run the funnel for one category against the v2 role map
#'
#' v2 sibling of \code{.run_funnel_for_category}. Skips the legacy
#' QuestionMap normalisation entirely — the v2 role_map already has
#' \code{funnel.awareness.DSS}-style keys, and \code{run_funnel}'s
#' \code{.lookup_role} resolves them via the \code{cat_code} config field.
#' @keywords internal
.run_funnel_for_category <- function(data, role_map, cat_brands, cat_code,
                                         config, weights, cat_name) {
  funnel_cfg <- .funnel_config_from_global(config, cat_name, cat_brands)
  funnel_cfg$cat_code <- cat_code

  brand_with_refusal_handler({
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


#' Map MA item codes to display labels
#'
#' v2 emits per-cat CEP codes (CEP01, CEP02, ...) directly — labels come from
#' \code{cat_ceps$CEPText} indexed by \code{cat_ceps$CEPCode}. Legacy emits
#' question codes (\code{CEP01_DSS}) — labels come from
#' \code{cep_questions$QuestionText} by position.
#' @keywords internal
.ma_resolve_cep_labels <- function(cep_codes, cat_ceps, use, cep_questions) {
  if (use && !is.null(cat_ceps) && nrow(cat_ceps) > 0) {
    out <- cat_ceps$CEPText[match(cep_codes, cat_ceps$CEPCode)]
    out[is.na(out)] <- cep_codes[is.na(out)]
    return(out)
  }
  if (!is.null(cep_questions) && nrow(cep_questions) > 0 &&
      !is.null(cat_ceps) && nrow(cat_ceps) > 0) {
    return(cep_questions$QuestionText[seq_along(cep_codes)])
  }
  cep_codes
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

#' Demographics dispatcher (v2 — role-map driven)
#'
#' v2 sibling of \code{.run_demographics_for_category}. Walks role_map for
#' \code{^demographics\\.*} keys (the v2 namespace; legacy used \code{demo.*})
#' and calls \code{demographic_question_from_role} for each role whose
#' column resolves in cat_data. Synthetic Buyer Status + Heaviness questions
#' come from the same helpers as the legacy path.
#' @keywords internal
.run_demographics_for_category <- function(role_map, structure, config,
                                                cat_data, cat_weights,
                                                cat_brands, cat_name,
                                                brand_volume, buyer_heaviness,
                                                verbose = TRUE) {

  buyer_info <- .demo_buyer_for_category(brand_volume, buyer_heaviness,
                                          config$focal_brand)
  bmat_info  <- .demo_brand_matrix_for_category(brand_volume, cat_brands)

  demo_roles <- grep("^demographics\\.", names(role_map), value = TRUE)

  questions <- list()
  for (role in demo_roles) {
    rec <- demographic_question_from_role(
      data         = cat_data,
      role_map     = role_map,
      role         = role,
      structure    = structure,
      weights      = cat_weights,
      focal_buyer  = buyer_info$focal_buyer,
      buyer_tiers  = buyer_info$tiers,
      pen_mat      = bmat_info$pen_mat,
      brand_codes  = bmat_info$brand_codes,
      brand_labels = bmat_info$brand_labels
    )
    if (!is.null(rec)) questions[[length(questions) + 1L]] <- rec
  }

  syn <- .demo_synthetic_questions(cat_data, cat_weights, buyer_info,
                                    bmat_info, config$focal_brand)
  for (q in syn) questions[[length(questions) + 1L]] <- q

  if (length(questions) == 0L) {
    return(list(status = "EMPTY",
                message = sprintf("No demographic questions resolved for %s.",
                                   cat_name)))
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
# Build the focal-brand buyer indicator across all full categories. A
# respondent is a buyer iff they purchased the focal brand in ANY full
# category (BRANDPEN2_<CAT>_<BRAND> > 0). Tiers use the per-category
# buyer-heaviness tertiles where available; respondents are assigned to the
# heaviest tier they appear in across categories.
# Resolve the short category code (e.g. "DSS") used to filter Focal_Category.
# Falls back to a pen-prefix detection when results don't carry it explicitly.
# Build a brand-level pen matrix that maps full-data rows to brands across
# all full categories. Each column is a brand; cell = 1 if respondent
# bought that brand in any full category they participated in.
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

.run_adhoc_for_category <- function(role_map, structure, config,
                                        data_full, weights_full,
                                        cat_data, cat_weights, cat_brands,
                                        cat_name, cat_code, brand_volume,
                                        verbose = TRUE) {

  bmat <- .demo_brand_matrix_for_category(brand_volume, cat_brands)

  # ALL-scope: sample-wide context, no brand cut.
  out_all <- run_adhoc(
    role_map     = role_map, structure = structure, data = data_full,
    weights      = weights_full, scope_filter = "ALL",
    pen_mat      = NULL,
    brand_codes  = character(0), brand_labels = character(0)
  )

  # CATCODE-scope: focal-category respondents with this cat's brand cuts.
  out_cat <- if (!is.null(cat_code) && nzchar(cat_code))
    run_adhoc(
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

# Legacy brand-level dispatcher (kept as a stub; engine now per-category).
# ==============================================================================
# AD HOC DISPATCH (brand-level, legacy)
# ==============================================================================
# Walks "adhoc.<key>.<scope>" rows. Scope = "ALL" runs over the whole
# sample; scope = a category code runs only over respondents in that
# focal category. The brand_cut matrix uses the corresponding category's
# pen matrix when scoped, or the union pen matrix when ALL.

# ==============================================================================
# PORTFOLIO DATA (cross-category, full respondent base)
# ==============================================================================

#' Compute cross-category portfolio data (thin wrapper)
#'
#' Delegates to \code{run_portfolio()} for the full portfolio analysis.
#' Threads \code{role_map} through every sub-analysis so awareness columns
#' resolve via the slot-indexed reader layer. Preserves the
#' \code{results$portfolio} output key for downstream code.
#'
#' @keywords internal
.compute_portfolio_data <- function(data, categories, structure, config, weights,
                                     role_map = NULL) {
  run_portfolio(data, role_map, categories, structure, config, weights)
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand module loaded (v%s)", BRAND_VERSION))
}
