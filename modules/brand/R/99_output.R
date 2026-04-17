# ==============================================================================
# BRAND MODULE - OUTPUT GENERATION
# ==============================================================================
# Generates Excel workbook and CSV files from brand analysis results.
# One sheet per element, formatted with headers and styles.
#
# VERSION: 1.0
#
# DEPENDENCIES:
#   - openxlsx
# ==============================================================================

BRAND_OUTPUT_VERSION <- "1.0"


#' Generate Excel output from brand analysis results
#'
#' Creates a formatted Excel workbook with one sheet per analytical element.
#'
#' @param results List. Output from \code{run_brand()}.
#' @param output_path Character. Path for the output Excel file.
#' @param config List. Brand config (for project metadata).
#'
#' @return List with status and output_path.
#'
#' @export
generate_brand_excel <- function(results, output_path, config = NULL) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING",
      message = "openxlsx required for Excel output"
    ))
  }

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  wb <- openxlsx::createWorkbook()

  # Header style
  header_style <- openxlsx::createStyle(
    fontName = "Calibri", fontSize = 11, fontColour = "#FFFFFF",
    fgFill = "#323367", textDecoration = "bold",
    border = "TopBottomLeftRight", halign = "center"
  )

  # Helper to write a data frame as a sheet
  .write_sheet <- function(sheet_name, data, title = NULL) {
    if (is.null(data) || nrow(data) == 0) return()
    openxlsx::addWorksheet(wb, sheet_name)

    start_row <- 1
    if (!is.null(title)) {
      openxlsx::writeData(wb, sheet_name, x = title, startRow = 1, startCol = 1)
      openxlsx::addStyle(wb, sheet_name,
        openxlsx::createStyle(fontName = "Calibri", fontSize = 13,
                              fontColour = "#323367", textDecoration = "bold"),
        rows = 1, cols = 1)
      start_row <- 3
    }

    openxlsx::writeData(wb, sheet_name, data, startRow = start_row)
    openxlsx::addStyle(wb, sheet_name, header_style,
                       rows = start_row, cols = seq_len(ncol(data)),
                       gridExpand = TRUE)
    openxlsx::setColWidths(wb, sheet_name,
                           cols = seq_len(ncol(data)),
                           widths = "auto")
    openxlsx::freezePane(wb, sheet_name,
                         firstActiveRow = start_row + 1)
  }

  # Project info sheet
  if (!is.null(config)) {
    openxlsx::addWorksheet(wb, "Project_Info")
    info <- data.frame(
      Setting = c("Project", "Client", "Focal Brand", "Wave",
                  "Study Type", "Date Generated"),
      Value = c(config$project_name %||% "", config$client_name %||% "",
                config$focal_brand %||% "", config$wave %||% 1,
                config$study_type %||% "", format(Sys.time(), "%Y-%m-%d %H:%M")),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Project_Info", info)
    openxlsx::addStyle(wb, "Project_Info", header_style, rows = 1,
                       cols = 1:2, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Project_Info", cols = 1:2, widths = c(20, 40))
  }

  # Per-category elements
  if (!is.null(results$results$categories)) {
    for (cat_name in names(results$results$categories)) {
      cat_res <- results$results$categories[[cat_name]]
      cat_prefix <- gsub(" ", "_", substr(cat_name, 1, 15))

      # Mental Availability
      ma <- cat_res$mental_availability
      if (!is.null(ma) && !identical(ma$status, "REFUSED")) {
        .write_sheet(paste0(cat_prefix, "_MMS"), ma$mms,
                     paste("Mental Market Share -", cat_name))
        .write_sheet(paste0(cat_prefix, "_MPen"), ma$mpen,
                     paste("Mental Penetration -", cat_name))
        .write_sheet(paste0(cat_prefix, "_NS"), ma$ns,
                     paste("Network Size -", cat_name))
        .write_sheet(paste0(cat_prefix, "_CEP_Matrix"), ma$cep_brand_matrix,
                     paste("CEP x Brand Matrix -", cat_name))
        .write_sheet(paste0(cat_prefix, "_CEP_Pen"), ma$cep_penetration,
                     paste("CEP Penetration -", cat_name))
        if (!is.null(ma$cep_turf) && !is.null(ma$cep_turf$incremental_table)) {
          .write_sheet(paste0(cat_prefix, "_CEP_TURF"),
                       ma$cep_turf$incremental_table,
                       paste("CEP TURF -", cat_name))
        }
      }

      # Funnel (role-registry architecture; new long-format result).
      # The combined workbook keeps per-category sheets via the legacy
      # wide adapter for consistency with other elements; the dedicated
      # funnel workbook with the richer 4-sheet layout is written via
      # write_funnel_excel() in the CSV output branch below.
      funnel <- cat_res$funnel
      if (!is.null(funnel) && !identical(funnel$status, "REFUSED") &&
          !is.null(funnel$stages) && nrow(funnel$stages) > 0) {
        bl <- data.frame(
          BrandCode = unique(as.character(funnel$stages$brand_code)),
          stringsAsFactors = FALSE)
        bl$BrandLabel <- bl$BrandCode
        legacy_wide <- build_funnel_legacy_wide(funnel, bl)
        legacy_conv <- build_funnel_legacy_conversions(funnel, bl)
        .write_sheet(paste0(cat_prefix, "_Funnel"), legacy_wide,
                     paste("Brand Funnel -", cat_name))
        .write_sheet(paste0(cat_prefix, "_Conversion"), legacy_conv,
                     paste("Conversion Ratios -", cat_name))
      }

      # Repertoire
      rep <- cat_res$repertoire
      if (!is.null(rep) && !identical(rep$status, "REFUSED")) {
        .write_sheet(paste0(cat_prefix, "_Rep_Size"), rep$repertoire_size,
                     paste("Repertoire Size -", cat_name))
        .write_sheet(paste0(cat_prefix, "_Sole_Loyalty"), rep$sole_loyalty,
                     paste("Sole Loyalty -", cat_name))
        if (!is.null(rep$brand_overlap)) {
          .write_sheet(paste0(cat_prefix, "_Overlap"), rep$brand_overlap,
                       paste("Brand Overlap -", cat_name))
        }
        if (!is.null(rep$share_of_requirements)) {
          .write_sheet(paste0(cat_prefix, "_SoR"), rep$share_of_requirements,
                       paste("Share of Requirements -", cat_name))
        }
      }

      # Drivers & Barriers
      db <- cat_res$drivers_barriers
      if (!is.null(db) && !identical(db$status, "REFUSED")) {
        .write_sheet(paste0(cat_prefix, "_Importance"), db$importance,
                     paste("Derived Importance -", cat_name))
        .write_sheet(paste0(cat_prefix, "_IxP"), db$ixp_quadrants,
                     paste("Importance x Performance -", cat_name))
        if (!is.null(db$competitive_advantage)) {
          .write_sheet(paste0(cat_prefix, "_CompAdv"),
                       db$competitive_advantage,
                       paste("Competitive Advantage -", cat_name))
        }
        if (!is.null(db$rejection_themes)) {
          .write_sheet(paste0(cat_prefix, "_Rejection"), db$rejection_themes,
                       paste("Rejection Themes -", cat_name))
        }
      }
    }
  }

  # Brand-level elements
  if (!is.null(results$results$wom) &&
      !identical(results$results$wom$status, "REFUSED")) {
    wom <- results$results$wom
    .write_sheet("WOM_Metrics", wom$wom_metrics, "Word-of-Mouth Metrics")
    .write_sheet("WOM_Net_Balance", wom$net_balance, "WOM Net Balance")
    .write_sheet("WOM_Amplification", wom$amplification, "WOM Amplification")
  }

  if (!is.null(results$results$dba) &&
      !identical(results$results$dba$status, "REFUSED")) {
    .write_sheet("DBA_Metrics", results$results$dba$dba_metrics,
                 "Distinctive Brand Assets")
  }

  # Portfolio
  if (!is.null(results$results$portfolio) &&
      !identical(results$results$portfolio$status, "REFUSED")) {
    port <- results$results$portfolio
    .write_sheet("Portfolio_Map", port$portfolio_map, "Portfolio Map")
    .write_sheet("Portfolio_Quadrants", port$priority_quadrants,
                 "Priority Quadrants")
    if (!is.null(port$category_turf) &&
        !is.null(port$category_turf$incremental_table)) {
      .write_sheet("Category_TURF", port$category_turf$incremental_table,
                   "Category TURF")
    }
  }

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  list(
    status = "PASS",
    output_path = output_path,
    message = sprintf("Excel output saved to %s", output_path)
  )
}


#' Generate CSV output from brand analysis results
#'
#' Writes long-format CSV files per element to the output directory.
#'
#' @param results List. Output from \code{run_brand()}.
#' @param output_dir Character. Directory for CSV files.
#' @param config List. Brand config (for naming).
#'
#' @return List with status and file paths.
#'
#' @export
generate_brand_csv <- function(results, output_dir, config = NULL) {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files_written <- character(0)

  .write_csv <- function(data, filename) {
    if (is.null(data) || nrow(data) == 0) return()
    path <- file.path(output_dir, filename)
    write.csv(data, path, row.names = FALSE)
    files_written <<- c(files_written, path)
  }

  # Per-category
  if (!is.null(results$results$categories)) {
    for (cat_name in names(results$results$categories)) {
      cat_res <- results$results$categories[[cat_name]]
      prefix <- tolower(gsub(" ", "_", cat_name))

      ma <- cat_res$mental_availability
      if (!is.null(ma) && !identical(ma$status, "REFUSED")) {
        .write_csv(ma$mms, paste0(prefix, "_mms.csv"))
        .write_csv(ma$mpen, paste0(prefix, "_mpen.csv"))
        .write_csv(ma$ns, paste0(prefix, "_ns.csv"))
        .write_csv(ma$cep_brand_matrix, paste0(prefix, "_cep_matrix.csv"))
      }

      funnel <- cat_res$funnel
      if (!is.null(funnel) && !identical(funnel$status, "REFUSED") &&
          !is.null(funnel$stages) && nrow(funnel$stages) > 0) {
        bl <- data.frame(
          BrandCode = unique(as.character(funnel$stages$brand_code)),
          stringsAsFactors = FALSE)
        bl$BrandLabel <- bl$BrandCode
        # Canonical 4-sheet funnel workbook + long CSV per FUNNEL_SPEC §7
        cat_code <- gsub("[^A-Za-z0-9]+", "_", cat_name)
        write_funnel_excel(
          result = funnel, brand_list = bl, role_map = NULL,
          output_path = file.path(output_dir,
            sprintf("funnel_%s.xlsx", cat_code)),
          config = list(
            `funnel.conversion_metric` = config$`funnel.conversion_metric`,
            `funnel.warn_base` = config$low_base_warning,
            `funnel.suppress_base` = config$min_base_size))
        write_funnel_csv(
          result = funnel, brand_list = bl, role_map = NULL,
          output_path = file.path(output_dir,
            sprintf("funnel_%s_long.csv", cat_code)),
          config = list(category_code = cat_code,
                        wave_label = as.character(config$wave %||% "")))
      }

      rep <- cat_res$repertoire
      if (!is.null(rep) && !identical(rep$status, "REFUSED")) {
        .write_csv(rep$sole_loyalty, paste0(prefix, "_sole_loyalty.csv"))
      }

      db <- cat_res$drivers_barriers
      if (!is.null(db) && !identical(db$status, "REFUSED")) {
        .write_csv(db$importance, paste0(prefix, "_importance.csv"))
        .write_csv(db$ixp_quadrants, paste0(prefix, "_ixp.csv"))
      }
    }
  }

  # Brand-level
  wom <- results$results$wom
  if (!is.null(wom) && !identical(wom$status, "REFUSED")) {
    .write_csv(wom$wom_metrics, "wom_metrics.csv")
  }

  dba <- results$results$dba
  if (!is.null(dba) && !identical(dba$status, "REFUSED")) {
    .write_csv(dba$dba_metrics, "dba_metrics.csv")
  }

  list(
    status = "PASS",
    output_dir = output_dir,
    files_written = files_written,
    n_files = length(files_written)
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand output module loaded (v%s)",
                  BRAND_OUTPUT_VERSION))
}
