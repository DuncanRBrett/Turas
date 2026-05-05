# ==============================================================================
# BRAND HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Transforms run_brand() results into chart-ready and table-ready structures.
# Layer 1 of the 4-layer pipeline.
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# Filter a brands/CEPs/attrs table to rows for this category.
# Prefers CategoryCode exact match; falls back to Category display name.
.filter_brands_for_cat <- function(tbl, cat_code, cat_display) {
  if (is.null(tbl) || nrow(tbl) == 0) return(tbl)
  if (!is.null(cat_code) && nzchar(cat_code) && "CategoryCode" %in% names(tbl)) {
    rows <- trimws(as.character(tbl$CategoryCode)) == trimws(cat_code)
    if (any(rows)) return(tbl[rows, , drop = FALSE])
  }
  if (!is.null(cat_display) && "Category" %in% names(tbl))
    return(tbl[tbl$Category == cat_display, , drop = FALSE])
  tbl
}

# Position-based brand colour assignment. Self-contained — no dependency on
# any other brand module file being in scope (this file is re-sourced at
# report-generation time independently of the R module loader).
.dt_brand_colours <- function(brand_list, focal_code = NULL,
                               focal_colour = "#1A5276") {
  if (is.null(brand_list) || !is.data.frame(brand_list) ||
      nrow(brand_list) == 0 || !("BrandCode" %in% names(brand_list)))
    return(list())
  palette  <- c(
    "#e15759","#f28e2b","#59a14f","#edc948","#76b7b2","#b07aa1",
    "#d37295","#9c755f","#4e79a7","#499894","#e8a838","#1e8449",
    "#7d3c98","#2980b9","#ff9da7","#bab0ac","#9d7660","#79706e"
  )
  has_col  <- "Colour" %in% names(brand_list)
  out      <- list()
  pal_idx  <- 1L
  for (i in seq_len(nrow(brand_list))) {
    code <- trimws(as.character(brand_list$BrandCode[i]))
    col  <- if (has_col) trimws(as.character(brand_list$Colour[i])) else ""
    if (nzchar(col) && grepl("^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", col)) {
      out[[code]] <- col
    } else if (!is.null(focal_code) && code == focal_code) {
      out[[code]] <- focal_colour
    } else {
      out[[code]] <- palette[[(pal_idx - 1L) %% 18L + 1L]]
      pal_idx <- pal_idx + 1L
    }
  }
  out
}


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

  brand_list_all <- if (!is.null(results$structure) &&
                         !is.null(results$structure$brands))
    results$structure$brands else NULL

  # Per-category charts
  if (!is.null(results$results$categories)) {
    for (cat_key in names(results$results$categories)) {
      cr           <- results$results$categories[[cat_key]]
      cat_code_lcl <- cr$cat_code %||% NULL
      cat_display  <- cr$category %||% cat_key
      cat_id       <- gsub("[^a-z0-9]", "-", tolower(cat_code_lcl %||% cat_key))
      cat_name     <- cat_display

      # Mental Availability: now always rendered as the polished 3-tab panel
      # (build_ma_panel_data + build_ma_panel_html in transform_brand_panels).
      # Legacy SVG charts are no longer generated.

      # Funnel charts — consumes new role-registry funnel shape and
      # adapts to the legacy wide data frame expected by the existing
      # SVG builders (build_funnel_chart, build_dot_plot). This adapter
      # stays until the HTML panel migrates to build_funnel_panel_data().
      funnel <- cr$funnel
      if (!is.null(funnel) && !identical(funnel$status, "REFUSED") &&
          !is.null(funnel$stages) && nrow(funnel$stages) > 0) {
        funnel_charts <- list()
        raw_codes        <- unique(as.character(funnel$stages$brand_code))
        cat_brands_lcl   <- .filter_brands_for_cat(brand_list_all,
                                                   cat_code_lcl, cat_display)
        if (!is.null(cat_brands_lcl) && nrow(cat_brands_lcl) > 0 &&
            "BrandLabel" %in% names(cat_brands_lcl)) {
          brand_list_local <- cat_brands_lcl[
            cat_brands_lcl$BrandCode %in% raw_codes, , drop = FALSE]
          if (nrow(brand_list_local) == 0)
            brand_list_local <- data.frame(BrandCode = raw_codes,
                                           stringsAsFactors = FALSE)
        } else {
          brand_list_local <- data.frame(BrandCode = raw_codes,
                                         stringsAsFactors = FALSE)
        }
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

      # Category Buying + Repertoire charts
      rep <- cr$repertoire
      cbf <- cr$cat_buying_frequency
      if (!is.null(rep) && !identical(rep$status, "REFUSED")) {
        rep_charts <- list()

        # Purchase frequency distribution (category-level, all respondents)
        if (!is.null(cbf) && !identical(cbf$status, "REFUSED") &&
            !is.null(cbf$distribution) && nrow(cbf$distribution) > 0) {
          dist_ordered <- cbf$distribution
          if ("Order" %in% names(dist_ordered)) {
            dist_ordered <- dist_ordered[order(dist_ordered$Order), , drop = FALSE]
          }
          # Colour bars by frequency level: heavy = brand colour, never = muted
          rep_charts[[length(rep_charts) + 1]] <- list(
            svg = build_h_bar(
              dist_ordered, "Label", "Pct", brand_colour,
              title = sprintf("Category Purchase Frequency \u2014 %s (all respondents)",
                              cat_name),
              value_suffix = "%"),
            title = "Category Purchase Frequency"
          )
        }

        # Repertoire size distribution
        if (!is.null(rep$repertoire_size)) {
          rep_charts[[length(rep_charts) + 1]] <- list(
            svg = build_h_bar(rep$repertoire_size, "Brands_Bought", "Percentage",
                              brand_colour,
                              title = sprintf("Repertoire Size \u2014 %s", cat_name),
                              value_suffix = "%"),
            title = "Repertoire Size"
          )
        }

        # Per-brand loyalty profile (stacked: Sole / Dual / Multi)
        if (!is.null(rep$brand_repertoire_profile) &&
            nrow(rep$brand_repertoire_profile) > 0 &&
            exists("build_loyalty_profile_chart", mode = "function")) {
          rep_charts[[length(rep_charts) + 1]] <- list(
            svg = build_loyalty_profile_chart(
              rep$brand_repertoire_profile,
              focal_brand  = focal,
              focal_colour = brand_colour,
              title = sprintf("Buyer Loyalty Profile \u2014 %s", cat_name)),
            title = "Buyer Loyalty Profile"
          )
        }

        charts[[paste0("repertoire_", cat_id)]] <- rep_charts
      }

    }
  }

  # Brand-level charts

  # WOM is now per-category (each category has its own brand list and respondent group).
  # Per-category WOM charts are keyed as wom_{cat_id} and rendered in the category panel.
  if (!is.null(results$results$categories)) {
    for (cat_name in names(results$results$categories)) {
      cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
      wom <- results$results$categories[[cat_name]]$wom
      if (!is.null(wom) && !identical(wom$status, "REFUSED") &&
          !is.null(wom$wom_metrics)) {
        charts[[paste0("wom_", cat_id)]] <- list(
          list(
            svg = build_diverging_bar(wom$wom_metrics, "BrandCode",
                                      "ReceivedPos_Pct", "ReceivedNeg_Pct",
                                      focal, brand_colour,
                                      title = sprintf("WOM Net Balance \u2014 %s", cat_name)),
            title = "WOM Net Balance"
          )
        )
      }
    }
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
    for (cat_key in names(results$results$categories)) {
      cr      <- results$results$categories[[cat_key]]
      cat_id  <- gsub("[^a-z0-9]", "-",
                      tolower(cr$cat_code %||% cat_key))

      # MA is now always rendered by the new panel (build_ma_panel_html).
      # build_ma_tables() is removed; there is no old-format MA fallback.
      if (!is.null(cr$funnel))
        tables[[paste0("funnel_", cat_id)]] <- build_funnel_tables(cr$funnel, focal)
      if (!is.null(cr$repertoire))
        tables[[paste0("repertoire_", cat_id)]] <- build_cat_buying_tables(
          cr$repertoire, cr$cat_buying_frequency, focal)
      # WOM is per-category
      if (!is.null(cr$wom) && !identical(cr$wom$status, "REFUSED"))
        tables[[paste0("wom_", cat_id)]] <- build_wom_tables(cr$wom, focal)
      # Drivers & Barriers HTML moved to MA Mental Advantage focal-brand
      # view (see 02c_ma_focal_view.R). Excel/CSV outputs from
      # 06_drivers_barriers.R are unchanged.
    }
  }

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

  for (cat_key in names(results$results$categories)) {
    cr          <- results$results$categories[[cat_key]]
    cat_code_lc <- cr$cat_code %||% NULL
    cat_display <- cr$category %||% cat_key
    cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
    funnel <- cr$funnel
    if (is.null(funnel) || identical(funnel$status, "REFUSED")) next
    if (is.null(funnel$stages) || nrow(funnel$stages) == 0) next

    cat_brands <- if (!is.null(brand_list_all)) {
      bl <- .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
      if (is.null(bl) || nrow(bl) == 0)
        data.frame(BrandCode = unique(as.character(funnel$stages$brand_code)),
                   stringsAsFactors = FALSE)
      else bl
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

    # Per-category timeframe labels — check by CategoryCode first, then name
    cat_cfg_row <- if (!is.null(config$categories)) {
      cfg_cats <- config$categories
      if (!is.null(cat_code_lc) && "CategoryCode" %in% names(cfg_cats)) {
        r <- cfg_cats[trimws(as.character(cfg_cats$CategoryCode)) ==
                      trimws(cat_code_lc), , drop = FALSE]
        if (nrow(r) > 0) r else cfg_cats[cfg_cats$Category == cat_display,
                                          , drop = FALSE]
      } else if ("Category" %in% names(cfg_cats)) {
        cfg_cats[cfg_cats$Category == cat_display, , drop = FALSE]
      } else NULL
    } else NULL
    timeframe_long   <- if (!is.null(cat_cfg_row) && nrow(cat_cfg_row) > 0 &&
                             "Timeframe_Long"   %in% names(cat_cfg_row))
      as.character(cat_cfg_row$Timeframe_Long[1]) else NULL
    timeframe_target <- if (!is.null(cat_cfg_row) && nrow(cat_cfg_row) > 0 &&
                             "Timeframe_Target" %in% names(cat_cfg_row))
      as.character(cat_cfg_row$Timeframe_Target[1]) else NULL

    panel_data <- build_funnel_panel_data(funnel, cat_brands,
      config = list(category_label    = cat_display,
                    wave_label        = as.character(config$wave %||% ""),
                    show_counts       = FALSE,
                    Timeframe_Long    = timeframe_long,
                    Timeframe_Target  = timeframe_target,
                    decimal_places    = config$decimal_places %||% 0L))
    # Link the Export button to the pre-written funnel Excel workbook that
    # write_funnel_excel() drops next to the HTML report.
    xlsx_name <- sprintf("funnel_%s.xlsx", cat_id)
    panel_html <- build_funnel_panel_html(panel_data,
                                          category_code = cat_id,
                                          focal_colour = focal_colour,
                                          excel_filename = xlsx_name,
                                          chip_default = config$chip_default %||% "focal_only")
    panels[[paste0("funnel_", cat_id)]] <- panel_html
  }

  # --- Mental Availability panels (per category) ---
  if (exists("build_ma_panel_data", mode = "function") &&
      exists("build_ma_panel_html", mode = "function")) {
    for (cat_key in names(results$results$categories)) {
      cr          <- results$results$categories[[cat_key]]
      cat_code_lc <- cr$cat_code %||% NULL
      cat_display <- cr$category %||% cat_key
      cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
      ma <- cr$mental_availability
      if (is.null(ma) || identical(ma$status, "REFUSED")) next
      if (is.null(ma$cep_brand_matrix)) next

      cat_brands <- if (!is.null(brand_list_all)) {
        bl <- .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
        if (is.null(bl) || nrow(bl) == 0)
          data.frame(BrandCode = setdiff(names(ma$cep_brand_matrix), "CEPCode"),
                     stringsAsFactors = FALSE)
        else bl
      } else
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
        .filter_brands_for_cat(results$structure$ceps, cat_code_lc, cat_display) %||%
          data.frame(CEPCode = character(), CEPText = character(),
                     stringsAsFactors = FALSE)
      } else data.frame(CEPCode = character(), CEPText = character(),
                        stringsAsFactors = FALSE)

      attr_list <- if (!is.null(results$structure) &&
                       !is.null(results$structure$attributes)) {
        at_all <- results$structure$attributes
        if (nrow(at_all) > 0)
          .filter_brands_for_cat(at_all, cat_code_lc, cat_display)
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
          category_label = cat_display,
          wave_label = as.character(config$wave %||% ""),
          focal_brand_code = config$focal_brand,
          focal_colour = focal_colour,
          decimal_places = config$decimal_places %||% 0L))

      ma_html <- build_ma_panel_html(ma_pd,
                                      category_code = cat_id,
                                      focal_colour = focal_colour,
                                      chip_default = config$chip_default %||% "focal_only")
      panels[[paste0("ma_", cat_id)]] <- ma_html
    }
  }

  # --- Category Buying (Dirichlet) panels (per category) ---
  if (exists("render_cat_buying_panel", mode = "function")) {
    for (cat_key in names(results$results$categories)) {
      cr          <- results$results$categories[[cat_key]]
      cat_code_lc <- cr$cat_code %||% NULL
      cat_display <- cr$category %||% cat_key
      cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
      cat_name    <- cat_display

      dn  <- cr$dirichlet_norms
      bh  <- cr$buyer_heaviness
      rep <- cr$repertoire
      cbf <- cr$cat_buying_frequency

      # P1.1 fix: only build the Dirichlet panel when at least one of the two
      # paired elements (dirichlet_norms or buyer_heaviness) is present and not
      # REFUSED.  If both are absent or both REFUSED the legacy inline block in
      # 03_page_builder.R renders instead, giving the operator a clear fallback.
      dn_ok <- !is.null(dn) && !identical(dn$status, "REFUSED")
      bh_ok <- !is.null(bh) && !identical(bh$status, "REFUSED")
      if (!dn_ok && !bh_ok) next

      cat_brands_local <- if (!is.null(brand_list_all))
        .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
      else NULL

      focal_colour <- .resolve_focal_colour(cat_brands_local, config$focal_brand,
                                            config_focal_colour)

      # Build brand_labels lookup: prefer BrandLabel column, fall back to
      # title-case conversion of the brand code.
      brand_labels <- NULL
      if (!is.null(cat_brands_local) && nrow(cat_brands_local) > 0 &&
          "BrandCode" %in% names(cat_brands_local)) {
        lbl_col <- if ("BrandLabel" %in% names(cat_brands_local))
          cat_brands_local$BrandLabel else NULL
        brand_labels <- stats::setNames(
          if (!is.null(lbl_col))
            as.character(lbl_col)
          else
            vapply(as.character(cat_brands_local$BrandCode),
                   function(x) tools::toTitleCase(tolower(x)),
                   character(1L)),
          as.character(cat_brands_local$BrandCode))
      }

      brand_colours <- .dt_brand_colours(cat_brands_local,
                                          config$focal_brand %||% NULL,
                                          focal_colour)

      panel_data <- list(
        cat_name              = cat_name,
        category_code         = cat_id,
        focal_brand           = config$focal_brand %||% NULL,
        focal_colour          = focal_colour,
        target_months         = config$target_timeframe_months %||% 3L,
        longer_months         = config$longer_timeframe_months %||% 12L,
        dirichlet_norms       = dn,
        buyer_heaviness       = bh,
        cat_buying_frequency  = cbf,
        repertoire            = rep,
        shopper_location      = cr$shopper_location,
        shopper_packsize      = cr$shopper_packsize,
        brand_labels          = brand_labels,
        brand_colours         = brand_colours,
        cat_buying_dist_labels = config$cat_buying_dist_labels %||% NULL,
        chip_default          = config$chip_default %||% "focal_only"
      )

      cb_html <- tryCatch(
        render_cat_buying_panel(panel_data),
        error = function(e) {
          message(sprintf("[BRAND HTML] Cat buying panel failed for %s: %s",
                          cat_name, e$message))
          NULL
        }
      )
      if (!is.null(cb_html)) {
        panels[[paste0("cat_buying_", cat_id)]] <- cb_html
      }
    }
  }

  # --- Word of Mouth panels (per category) ---
  if (exists("build_wom_panel_data", mode = "function") &&
      exists("build_wom_panel_html", mode = "function")) {
    for (cat_key in names(results$results$categories)) {
      cr          <- results$results$categories[[cat_key]]
      cat_code_lc <- cr$cat_code %||% NULL
      cat_display <- cr$category %||% cat_key
      cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
      cat_name    <- cat_display
      wom <- cr$wom
      if (is.null(wom) || identical(wom$status, "REFUSED")) next
      if (is.null(wom$wom_metrics)) next

      cat_brands_local <- if (!is.null(brand_list_all))
        .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
      else
        data.frame(BrandCode = as.character(wom$wom_metrics$BrandCode),
                   stringsAsFactors = FALSE)
      if (is.null(cat_brands_local) || nrow(cat_brands_local) == 0)
        cat_brands_local <- data.frame(
          BrandCode = as.character(wom$wom_metrics$BrandCode),
          stringsAsFactors = FALSE)
      if (!("BrandLabel" %in% names(cat_brands_local))) {
        cat_brands_local$BrandLabel <- cat_brands_local$BrandCode
      }

      focal_colour <- .resolve_focal_colour(cat_brands_local,
                                            config$focal_brand,
                                            config_focal_colour)

      # Timeframe label — prefer category Timeframe_Target, fall back to
      # the original WOM question wording default.
      cat_cfg_row <- if (!is.null(config$categories)) {
        cfg_cats <- config$categories
        if (!is.null(cat_code_lc) && "CategoryCode" %in% names(cfg_cats)) {
          r <- cfg_cats[trimws(as.character(cfg_cats$CategoryCode)) ==
                        trimws(cat_code_lc), , drop = FALSE]
          if (nrow(r) > 0) r else if ("Category" %in% names(cfg_cats))
            cfg_cats[cfg_cats$Category == cat_display, , drop = FALSE] else NULL
        } else if ("Category" %in% names(cfg_cats)) {
          cfg_cats[cfg_cats$Category == cat_display, , drop = FALSE]
        } else NULL
      } else NULL
      tf_label <- if (!is.null(cat_cfg_row) && nrow(cat_cfg_row) > 0 &&
                      "Timeframe_Target" %in% names(cat_cfg_row))
        as.character(cat_cfg_row$Timeframe_Target[1]) else NULL
      if (is.null(tf_label) || !nzchar(tf_label)) tf_label <- "last 3 months"

      wom_brand_colours <- .dt_brand_colours(cat_brands_local,
                                              config$focal_brand %||% NULL,
                                              focal_colour)

      wom_pd <- tryCatch(
        build_wom_panel_data(
          wom_result = wom,
          brand_list = cat_brands_local,
          config = list(
            category_label   = cat_display,
            wave_label       = as.character(config$wave %||% ""),
            focal_brand_code = config$focal_brand,
            focal_colour     = focal_colour,
            brand_colours    = wom_brand_colours,
            timeframe_label  = tf_label
          )),
        error = function(e) {
          message(sprintf("[BRAND HTML] WOM panel data failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (is.null(wom_pd)) next

      wom_html <- tryCatch(
        build_wom_panel_html(wom_pd,
                             category_code = cat_id,
                             focal_colour = focal_colour,
                             chip_default = config$chip_default %||% "focal_only"),
        error = function(e) {
          message(sprintf("[BRAND HTML] WOM panel render failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (!is.null(wom_html)) {
        panels[[paste0("wom_", cat_id)]] <- wom_html
      }
    }
  }

  # --- Demographics panels (per-category) ---
  if (exists("build_demographics_panel_data", mode = "function") &&
      exists("build_demographics_panel_html", mode = "function")) {
    for (cat_key in names(results$results$categories)) {
      cr          <- results$results$categories[[cat_key]]
      cat_code_lc <- cr$cat_code %||% NULL
      cat_display <- cr$category %||% cat_key
      cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
      demo <- cr$demographics
      if (is.null(demo) || !identical(demo$status, "PASS")) next

      cat_brands_local <- if (!is.null(brand_list_all))
        .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
      else NULL
      focal_colour <- .resolve_focal_colour(cat_brands_local,
                                              config$focal_brand,
                                              config_focal_colour)

      demo_pd <- tryCatch(
        build_demographics_panel_data(
          questions      = demo$questions,
          focal_brand    = config$focal_brand %||% "",
          focal_colour   = focal_colour,
          brand_codes    = demo$brand_codes   %||% character(0),
          brand_labels   = demo$brand_labels  %||% character(0),
          brand_colours  = demo$brand_colours %||% list(),
          decimal_places = config$decimal_places %||% 0L,
          wave_label     = as.character(config$wave %||% ""),
          scope_label    = cat_display,
          n_total        = demo$n_total %||% NA_integer_,
          weighted       = isTRUE(demo$weighted)),
        error = function(e) {
          message(sprintf("[BRAND HTML] Demographics panel data failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (!is.null(demo_pd)) {
        demo_html <- tryCatch(
          build_demographics_panel_html(
            demo_pd,
            panel_id = paste0("demo-panel-", cat_id),
            focal_colour = focal_colour),
          error = function(e) {
            message(sprintf("[BRAND HTML] Demographics panel render failed for %s: %s",
                            cat_name, e$message))
            NULL
          })
        if (!is.null(demo_html)) panels[[paste0("demographics_", cat_id)]] <- demo_html
      }
    }
  }

  # --- Ad Hoc panels (per-category) ---
  if (exists("build_adhoc_panel_data", mode = "function") &&
      exists("build_adhoc_panel_html", mode = "function")) {
    for (cat_key in names(results$results$categories)) {
      cr          <- results$results$categories[[cat_key]]
      cat_code_lc <- cr$cat_code %||% NULL
      cat_display <- cr$category %||% cat_key
      cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
      ah <- cr$adhoc
      if (is.null(ah) || !identical(ah$status, "PASS")) next

      cat_brands_local <- if (!is.null(brand_list_all))
        .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
      else NULL
      focal_colour <- .resolve_focal_colour(cat_brands_local,
                                              config$focal_brand,
                                              config_focal_colour)

      ah_pd <- tryCatch(
        build_adhoc_panel_data(
          questions      = ah$questions,
          focal_brand    = config$focal_brand %||% "",
          focal_colour   = focal_colour,
          decimal_places = config$decimal_places %||% 0L,
          wave_label     = as.character(config$wave %||% "")),
        error = function(e) {
          message(sprintf("[BRAND HTML] Ad hoc panel data failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (!is.null(ah_pd)) {
        ah_html <- tryCatch(
          build_adhoc_panel_html(
            ah_pd,
            panel_id = paste0("adhoc-panel-", cat_id),
            focal_colour = focal_colour),
          error = function(e) {
            message(sprintf("[BRAND HTML] Ad hoc panel render failed for %s: %s",
                            cat_name, e$message))
            NULL
          })
        if (!is.null(ah_html)) panels[[paste0("adhoc_", cat_id)]] <- ah_html
      }
    }
  }

  # --- Audience Lens panels (per category) ---
  if (exists("build_audience_lens_panel_data", mode = "function") &&
      exists("build_audience_lens_panel_html", mode = "function")) {
    for (cat_key in names(results$results$categories)) {
      cr          <- results$results$categories[[cat_key]]
      cat_code_lc <- cr$cat_code %||% NULL
      cat_display <- cr$category %||% cat_key
      cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
      al <- cr$audience_lens
      if (is.null(al) || identical(al$status, "REFUSED")) next
      if (length(al$audiences %||% list()) == 0) next

      cat_brands_local <- if (!is.null(brand_list_all))
        .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
      else NULL

      focal_colour <- .resolve_focal_colour(cat_brands_local,
                                             config$focal_brand,
                                             config_focal_colour)

      al_pd <- tryCatch(
        build_audience_lens_panel_data(
          result         = al,
          category_label = cat_display,
          focal_brand    = config$focal_brand %||% "",
          focal_colour   = focal_colour,
          decimal_places = config$decimal_places %||% 0L,
          wave_label     = as.character(config$wave %||% "")
        ),
        error = function(e) {
          message(sprintf("[BRAND HTML] Audience lens panel data failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (is.null(al_pd)) next

      al_html <- tryCatch(
        build_audience_lens_panel_html(
          panel_data    = al_pd,
          category_code = cat_id,
          focal_colour  = focal_colour),
        error = function(e) {
          message(sprintf("[BRAND HTML] Audience lens render failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (!is.null(al_html)) {
        panels[[paste0("audience_lens_", cat_id)]] <- al_html
      }
    }
  }

  # --- Branded Reach panels (per category) ---
  if (exists("build_branded_reach_panel_data", mode = "function") &&
      exists("build_branded_reach_panel_html", mode = "function")) {
    for (cat_key in names(results$results$categories)) {
      cr          <- results$results$categories[[cat_key]]
      cat_code_lc <- cr$cat_code %||% NULL
      cat_display <- cr$category %||% cat_key
      cat_id      <- gsub("[^a-z0-9]", "-", tolower(cat_code_lc %||% cat_key))
      br <- cr$branded_reach
      if (is.null(br) || identical(br$status, "REFUSED")) next
      if (length(br$ads %||% list()) == 0) next

      cat_brands_local <- if (!is.null(brand_list_all))
        .filter_brands_for_cat(brand_list_all, cat_code_lc, cat_display)
      else NULL

      focal_colour <- .resolve_focal_colour(cat_brands_local,
                                             config$focal_brand,
                                             config_focal_colour)

      br_pd <- tryCatch(
        build_branded_reach_panel_data(
          result         = br,
          category_label = cat_display,
          focal_brand    = config$focal_brand %||% "",
          focal_colour   = focal_colour,
          decimal_places = config$decimal_places %||% 0L,
          wave_label     = as.character(config$wave %||% "")
        ),
        error = function(e) {
          message(sprintf("[BRAND HTML] Branded reach panel data failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (is.null(br_pd)) next

      br_html <- tryCatch(
        build_branded_reach_panel_html(
          panel_data    = br_pd,
          category_code = cat_id,
          focal_colour  = focal_colour),
        error = function(e) {
          message(sprintf("[BRAND HTML] Branded reach panel render failed for %s: %s",
                          cat_name, e$message))
          NULL
        })
      if (!is.null(br_html)) {
        panels[[paste0("branded_reach_", cat_id)]] <- br_html
      }
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
