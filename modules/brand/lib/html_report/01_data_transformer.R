# ==============================================================================
# BRAND HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Transforms run_brand() results into chart-ready and table-ready structures.
# Layer 1 of the 4-layer pipeline.
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


#' Transform brand results into chart data structures
#'
#' @param results List. Output from run_brand().
#' @param config List. Brand config.
#'
#' @return Named list of chart data keyed by element_catid.
#' @keywords internal
transform_brand_charts <- function(results, config) {
  focal <- config$focal_brand %||% ""
  brand_colour <- config$colour_focal %||% "#1A5276"
  comp_colour <- config$colour_competitor %||% "#B0B0B0"
  charts <- list()

  # Per-category charts
  if (!is.null(results$results$categories)) {
    for (cat_name in names(results$results$categories)) {
      cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
      cr <- results$results$categories[[cat_name]]

      # Mental Availability charts
      ma <- cr$mental_availability
      if (!is.null(ma) && !identical(ma$status, "REFUSED")) {
        ma_charts <- list()

        # 1. MMS League dot plot
        if (!is.null(ma$mms)) {
          mms_df <- data.frame(
            Label = ma$mms$BrandCode,
            Value = ma$mms$MMS * 100,
            stringsAsFactors = FALSE
          )
          ma_charts[[length(ma_charts) + 1]] <- list(
            svg = build_dot_plot(mms_df, focal_label = focal,
                                brand_colour = brand_colour,
                                comp_colour = comp_colour,
                                title = sprintf("Mental Market Share \u2014 %s", cat_name),
                                value_suffix = "%",
                                ref_line = mean(mms_df$Value),
                                ref_label = "Category avg"),
            title = "Mental Market Share"
          )
        }

        # 2. MPen x NS scatter
        if (!is.null(ma$mpen) && !is.null(ma$ns)) {
          scatter_df <- merge(ma$mpen, ma$ns, by = "BrandCode")
          scatter_df$MPen_Pct <- scatter_df$MPen * 100
          ma_charts[[length(ma_charts) + 1]] <- list(
            svg = build_scatter(scatter_df, "MPen_Pct", "NS", "BrandCode",
                                focal_label = focal,
                                brand_colour = brand_colour,
                                comp_colour = comp_colour,
                                title = sprintf("MPen \u00d7 NS Diagnostic \u2014 %s", cat_name),
                                x_label = "Mental Penetration (%)",
                                y_label = "Network Size (avg CEPs)",
                                x_suffix = "%",
                                ref_x = median(scatter_df$MPen_Pct),
                                ref_y = median(scatter_df$NS)),
            title = "MPen x NS Diagnostic"
          )
        }

        # 3. CEP x brand heat strip
        if (!is.null(ma$cep_brand_matrix)) {
          ma_charts[[length(ma_charts) + 1]] <- list(
            svg = build_heat_strip(ma$cep_brand_matrix, focal,
                                   brand_colour, title = sprintf(
                                     "CEP \u00d7 Brand Linkage (%%) \u2014 %s", cat_name)),
            title = "CEP x Brand Linkage"
          )
        }

        # 4. CEP TURF reach curve
        if (!is.null(ma$cep_turf) && !is.null(ma$cep_turf$reach_curve)) {
          ma_charts[[length(ma_charts) + 1]] <- list(
            svg = build_reach_curve(ma$cep_turf$reach_curve, brand_colour,
                                    title = sprintf("CEP TURF Reach Curve \u2014 %s", cat_name)),
            title = "CEP TURF Reach Curve"
          )
        }

        charts[[paste0("ma_", cat_id)]] <- ma_charts
      }

      # Funnel charts — consumes new role-registry funnel shape and
      # adapts to the legacy wide data frame expected by the existing
      # SVG builders (build_funnel_chart, build_dot_plot). This adapter
      # stays until the HTML panel migrates to build_funnel_panel_data().
      funnel <- cr$funnel
      if (!is.null(funnel) && !identical(funnel$status, "REFUSED") &&
          !is.null(funnel$stages) && nrow(funnel$stages) > 0) {
        funnel_charts <- list()
        brand_list_local <- data.frame(
          BrandCode = unique(as.character(funnel$stages$brand_code)),
          stringsAsFactors = FALSE)
        legacy_wide <- build_funnel_legacy_wide(funnel, brand_list_local)
        legacy_conv <- build_funnel_legacy_conversions(funnel, brand_list_local)

        if (nrow(legacy_wide) > 0) {
          funnel_charts[[length(funnel_charts) + 1]] <- list(
            svg = build_funnel_chart(legacy_wide, focal, brand_colour,
                                     title = sprintf("Brand Funnel \u2014 %s", cat_name)),
            title = "Brand Funnel"
          )
        }
        if (nrow(legacy_conv) > 0 && !all(is.na(legacy_conv$Aware_to_Positive))) {
          conv_df <- data.frame(
            Label = paste(legacy_conv$BrandCode, "\u2014 Aware\u2192Consideration"),
            Value = legacy_conv$Aware_to_Positive,
            stringsAsFactors = FALSE
          )
          funnel_charts[[length(funnel_charts) + 1]] <- list(
            svg = build_dot_plot(conv_df,
                                focal_label = paste(focal, "\u2014 Aware\u2192Consideration"),
                                brand_colour = brand_colour,
                                comp_colour = comp_colour,
                                title = sprintf("Conversion: Aware \u2192 Consideration \u2014 %s", cat_name),
                                value_suffix = "%",
                                ref_line = median(conv_df$Value, na.rm = TRUE),
                                ref_label = "Median"),
            title = "Conversion Rates"
          )
        }

        charts[[paste0("funnel_", cat_id)]] <- funnel_charts
      }

      # Repertoire charts
      rep <- cr$repertoire
      if (!is.null(rep) && !identical(rep$status, "REFUSED")) {
        rep_charts <- list()

        # 7. Repertoire size distribution
        if (!is.null(rep$repertoire_size)) {
          rep_charts[[length(rep_charts) + 1]] <- list(
            svg = build_h_bar(rep$repertoire_size, "Brands_Bought", "Percentage",
                              brand_colour, title = sprintf("Repertoire Size \u2014 %s", cat_name),
                              value_suffix = "%"),
            title = "Repertoire Size"
          )
        }

        # 8. Brand overlap
        if (!is.null(rep$brand_overlap) && nrow(rep$brand_overlap) > 0) {
          rep_charts[[length(rep_charts) + 1]] <- list(
            svg = build_h_bar(rep$brand_overlap, "BrandCode", "Overlap_Pct",
                              brand_colour,
                              title = sprintf("Brand Overlap with %s \u2014 %s", focal, cat_name),
                              value_suffix = "%"),
            title = "Brand Overlap"
          )
        }

        charts[[paste0("repertoire_", cat_id)]] <- rep_charts
      }

      # Drivers & Barriers charts
      db <- cr$drivers_barriers
      if (!is.null(db) && !identical(db$status, "REFUSED")) {
        db_charts <- list()

        # 9. I x P quadrant
        if (!is.null(db$ixp_quadrants) && "Focal_Linkage_Pct" %in% names(db$ixp_quadrants)) {
          ixp <- db$ixp_quadrants
          ixp$display_label <- ixp$Label %||% ixp$Code
          imp_med <- median(abs(ixp$Differential), na.rm = TRUE)
          perf_med <- median(ixp$Focal_Linkage_Pct, na.rm = TRUE)

          db_charts[[length(db_charts) + 1]] <- list(
            svg = build_scatter(ixp, "Focal_Linkage_Pct", "Differential",
                                "display_label", focal_label = NULL,
                                brand_colour = brand_colour,
                                title = sprintf("Importance \u00d7 Performance \u2014 %s", cat_name),
                                x_label = sprintf("%s Linkage (%%)", focal),
                                y_label = "Derived Importance (differential pp)",
                                x_suffix = "%", y_suffix = "pp",
                                quadrant_labels = c("Strengthen", "Maintain",
                                                     "Deprioritise", "Monitor"),
                                ref_x = perf_med, ref_y = imp_med),
            title = "Importance x Performance"
          )
        }

        # 10. Competitive dumbbell
        if (!is.null(db$competitive_advantage) && nrow(db$competitive_advantage) > 0) {
          db_charts[[length(db_charts) + 1]] <- list(
            svg = build_dumbbell(db$competitive_advantage, focal, brand_colour,
                                 comp_colour,
                                 title = sprintf("Competitive Advantage \u2014 %s", cat_name)),
            title = "Competitive Advantage"
          )
        }

        charts[[paste0("db_", cat_id)]] <- db_charts
      }
    }
  }

  # Brand-level charts

  # 11. WOM diverging bar
  wom <- results$results$wom
  if (!is.null(wom) && !identical(wom$status, "REFUSED") && !is.null(wom$wom_metrics)) {
    charts[["wom"]] <- list(
      list(
        svg = build_diverging_bar(wom$wom_metrics, "BrandCode",
                                   "ReceivedPos_Pct", "ReceivedNeg_Pct",
                                   focal, brand_colour,
                                   title = "WOM Net Balance \u2014 Received"),
        title = "WOM Net Balance"
      )
    )
  }

  # 12. DBA Fame x Uniqueness grid
  dba <- results$results$dba
  if (!is.null(dba) && !identical(dba$status, "REFUSED") && !is.null(dba$dba_metrics)) {
    fame_thresh <- (config$dba_fame_threshold %||% 0.5) * 100
    unique_thresh <- (config$dba_uniqueness_threshold %||% 0.5) * 100

    charts[["dba"]] <- list(
      list(
        svg = build_scatter(dba$dba_metrics, "Uniqueness_Pct", "Fame_Pct",
                            "AssetLabel", focal_label = NULL,
                            brand_colour = brand_colour,
                            title = "DBA Grid \u2014 Fame \u00d7 Uniqueness",
                            x_label = "Uniqueness (%)", y_label = "Fame (%)",
                            x_suffix = "%", y_suffix = "%",
                            quadrant_labels = c("Invest to Build", "Use or Lose",
                                                 "Ignore or Test", "Avoid Alone"),
                            ref_x = unique_thresh, ref_y = fame_thresh),
        title = "DBA Fame x Uniqueness Grid"
      )
    )
  }

  charts
}


#' Transform brand results into table HTML
#'
#' @param results List. Output from run_brand().
#' @param config List. Brand config.
#'
#' @return Named list of table HTML keyed by element_catid.
#' @keywords internal
transform_brand_tables <- function(results, config) {
  focal <- config$focal_brand %||% ""
  tables <- list()

  if (!is.null(results$results$categories)) {
    for (cat_name in names(results$results$categories)) {
      cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
      cr <- results$results$categories[[cat_name]]

      if (!is.null(cr$mental_availability))
        tables[[paste0("ma_", cat_id)]] <- build_ma_tables(cr$mental_availability, focal)
      if (!is.null(cr$funnel))
        tables[[paste0("funnel_", cat_id)]] <- build_funnel_tables(cr$funnel, focal)
      if (!is.null(cr$repertoire))
        tables[[paste0("repertoire_", cat_id)]] <- build_repertoire_tables(cr$repertoire, focal)
      if (!is.null(cr$drivers_barriers))
        tables[[paste0("db_", cat_id)]] <- build_db_tables(cr$drivers_barriers, focal)
    }
  }

  if (!is.null(results$results$wom))
    tables[["wom"]] <- build_wom_tables(results$results$wom, focal)
  if (!is.null(results$results$dba))
    tables[["dba"]] <- build_dba_tables(results$results$dba)

  tables
}


#' Transform brand results into dedicated role-registry panel HTML
#'
#' Currently returns one entry per category for the funnel element
#' (key \code{funnel_<cat_id>}); other elements fall through to the
#' legacy charts + tables path in build_br_category_panel.
#'
#' @param results List. Output from run_brand().
#' @param config List. Brand config.
#' @return Named list of panel HTML strings keyed by \code{element_catid}.
#' @keywords internal
transform_brand_panels <- function(results, config) {
  panels <- list()
  config_focal_colour <- config$colour_focal %||% "#1A5276"

  if (is.null(results$results$categories)) return(panels)

  brand_list_all <- if (!is.null(results$structure) &&
                         !is.null(results$structure$brands)) {
    results$structure$brands
  } else NULL

  for (cat_name in names(results$results$categories)) {
    cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
    cr <- results$results$categories[[cat_name]]
    funnel <- cr$funnel
    if (is.null(funnel) || identical(funnel$status, "REFUSED")) next
    if (is.null(funnel$stages) || nrow(funnel$stages) == 0) next

    cat_brands <- if (!is.null(brand_list_all) &&
                       "Category" %in% names(brand_list_all)) {
      brand_list_all[brand_list_all$Category == cat_name, , drop = FALSE]
    } else if (!is.null(brand_list_all)) {
      brand_list_all
    } else {
      data.frame(
        BrandCode = unique(as.character(funnel$stages$brand_code)),
        stringsAsFactors = FALSE)
    }
    if (!("BrandLabel" %in% names(cat_brands))) {
      cat_brands$BrandLabel <- cat_brands$BrandCode
    }

    # Focal colour: brand's own Colour entry takes precedence over config default.
    focal_colour <- .resolve_focal_colour(cat_brands, funnel$meta$focal_brand,
                                          config_focal_colour)

    panel_data <- build_funnel_panel_data(funnel, cat_brands,
      config = list(category_label = cat_name,
                    wave_label = as.character(config$wave %||% ""),
                    show_counts = FALSE))
    # Link the Export button to the pre-written funnel Excel workbook that
    # write_funnel_excel() drops next to the HTML report.
    xlsx_name <- sprintf("funnel_%s.xlsx", cat_id)
    panel_html <- build_funnel_panel_html(panel_data,
                                          category_code = cat_id,
                                          focal_colour = focal_colour,
                                          excel_filename = xlsx_name)
    panels[[paste0("funnel_", cat_id)]] <- panel_html
  }

  # --- Mental Availability panels (per category) ---
  if (exists("build_ma_panel_data", mode = "function") &&
      exists("build_ma_panel_html", mode = "function")) {
    for (cat_name in names(results$results$categories)) {
      cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
      cr <- results$results$categories[[cat_name]]
      ma <- cr$mental_availability
      if (is.null(ma) || identical(ma$status, "REFUSED")) next
      if (is.null(ma$cep_brand_matrix)) next

      cat_brands <- if (!is.null(brand_list_all) &&
                         "Category" %in% names(brand_list_all)) {
        brand_list_all[brand_list_all$Category == cat_name, , drop = FALSE]
      } else if (!is.null(brand_list_all)) brand_list_all else
        data.frame(BrandCode = setdiff(names(ma$cep_brand_matrix), "CEPCode"),
                   stringsAsFactors = FALSE)
      if (!("BrandLabel" %in% names(cat_brands))) {
        cat_brands$BrandLabel <- cat_brands$BrandCode
      }

      # Awareness per brand (for the "% aware" base toggle on CEPs)
      awareness_by_brand <- NULL
      if (!is.null(cr$funnel) && !is.null(cr$funnel$stages) &&
          nrow(cr$funnel$stages) > 0) {
        aw <- cr$funnel$stages[cr$funnel$stages$stage_key == "aware", , drop = FALSE]
        pct_col <- if ("pct_weighted" %in% names(aw)) "pct_weighted" else
                   if ("pct_absolute" %in% names(aw)) "pct_absolute" else NA_character_
        if (nrow(aw) > 0 && !is.na(pct_col)) {
          awareness_by_brand <- stats::setNames(
            as.numeric(aw[[pct_col]]) * 100, as.character(aw$brand_code))
        }
      }

      cep_list <- if (!is.null(results$structure) &&
                      !is.null(results$structure$ceps)) {
        ceps_all <- results$structure$ceps
        if ("Category" %in% names(ceps_all))
          ceps_all[ceps_all$Category == cat_name, , drop = FALSE]
        else ceps_all
      } else data.frame(CEPCode = character(), CEPText = character(),
                        stringsAsFactors = FALSE)

      attr_list <- if (!is.null(results$structure) &&
                       !is.null(results$structure$attributes)) {
        at_all <- results$structure$attributes
        if (nrow(at_all) > 0 && "Category" %in% names(at_all))
          at_all[at_all$Category == cat_name, , drop = FALSE]
        else at_all
      } else NULL

      focal_colour <- .resolve_focal_colour(cat_brands, config$focal_brand,
                                            config_focal_colour)

      ma_pd <- build_ma_panel_data(
        ma_result = ma,
        brand_list = cat_brands,
        cep_list = cep_list,
        attribute_list = attr_list,
        awareness_by_brand = awareness_by_brand,
        config = list(
          category_label = cat_name,
          wave_label = as.character(config$wave %||% ""),
          focal_brand_code = config$focal_brand,
          focal_colour = focal_colour))

      ma_html <- build_ma_panel_html(ma_pd,
                                      category_code = cat_id,
                                      focal_colour = focal_colour)
      panels[[paste0("ma_", cat_id)]] <- ma_html
    }
  }

  panels
}


#' Resolve the focal brand's display colour.
#'
#' Priority: (1) brand's own Colour column in the Brands sheet, (2) the
#' project-level colour_focal setting in Brand_Config.xlsx, (3) hardcoded
#' Turas navy default.
#'
#' @param cat_brands Data frame. Brands for this category.
#' @param focal_code Character. BrandCode of the focal brand.
#' @param config_colour Character. Project-level fallback colour.
#'
#' @return Character. A validated hex colour string.
#' @keywords internal
.resolve_focal_colour <- function(cat_brands, focal_code, config_colour) {
  default_colour <- "#1A5276"
  if (is.null(focal_code) || is.na(focal_code)) {
    return(config_colour %||% default_colour)
  }
  if (!is.null(cat_brands) && "Colour" %in% names(cat_brands)) {
    focal_row <- cat_brands[cat_brands$BrandCode == focal_code, , drop = FALSE]
    if (nrow(focal_row) > 0) {
      col <- trimws(as.character(focal_row$Colour[1]))
      if (nzchar(col) && grepl("^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", col)) {
        return(col)
      }
    }
  }
  config_colour %||% default_colour
}
