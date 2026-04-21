# ==============================================================================
# BRAND MODULE - PORTFOLIO OUTPUT WRITERS (§10)
# ==============================================================================
# Excel: 6 sheets added to the main workbook (Portfolio_Footprint,
#   Portfolio_Constellation, Portfolio_Clutter, Portfolio_Strength,
#   Portfolio_Extension, Portfolio_Meta).
# CSV:  same 6 files, written to {output_dir}/portfolio/ subdir.
#
# Both functions are thin — they delegate formatting decisions to the caller's
# workbook/directory; they only write data.
# ==============================================================================


#' Add portfolio sheets to an existing openxlsx workbook
#'
#' Writes six sheets covering all §10 portfolio analyses plus metadata.
#' Silently skips any sheet whose source data is NULL or empty.
#'
#' @param portfolio_result List. Output from \code{run_portfolio()}.
#' @param wb openxlsx Workbook object.  Modified by reference.
#' @param header_style openxlsx Style. Applied to the header row of each sheet.
#' @param config List or NULL. Brand config (used in Portfolio_Meta).
#'
#' @return Invisibly returns \code{wb}.
#' @keywords internal
write_portfolio_sheets <- function(portfolio_result, wb, header_style,
                                   config = NULL) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) return(invisible(wb))
  if (is.null(portfolio_result) ||
      identical(portfolio_result$status, "REFUSED")) return(invisible(wb))

  .ws <- function(sheet, df) {
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) return()
    openxlsx::addWorksheet(wb, sheet)
    openxlsx::writeData(wb, sheet, df, startRow = 1)
    openxlsx::addStyle(wb, sheet, header_style,
                       rows = 1, cols = seq_len(ncol(df)), gridExpand = TRUE)
    openxlsx::setColWidths(wb, sheet, cols = seq_len(ncol(df)), widths = "auto")
    openxlsx::freezePane(wb, sheet, firstActiveRow = 2)
  }

  # --- Portfolio_Footprint (long format) ---
  .ws("Portfolio_Footprint", .pf_footprint_long(portfolio_result))

  # --- Portfolio_Constellation ---
  if (!is.null(portfolio_result$constellation) &&
      !is.null(portfolio_result$constellation$edges)) {
    .ws("Portfolio_Constellation", portfolio_result$constellation$edges)
  }

  # --- Portfolio_Clutter ---
  if (!is.null(portfolio_result$clutter) &&
      !is.null(portfolio_result$clutter$clutter_df)) {
    .ws("Portfolio_Clutter", portfolio_result$clutter$clutter_df)
  }

  # --- Portfolio_Strength (long format) ---
  .ws("Portfolio_Strength", .pf_strength_long(portfolio_result))

  # --- Portfolio_Extension ---
  if (!is.null(portfolio_result$extension) &&
      !is.null(portfolio_result$extension$extension_df)) {
    .ws("Portfolio_Extension", portfolio_result$extension$extension_df)
  }

  # --- Portfolio_Meta ---
  .ws("Portfolio_Meta", .pf_meta_df(portfolio_result, config))

  invisible(wb)
}


#' Write portfolio CSV files to a subdirectory
#'
#' Writes six CSV files (one per §10 sheet) to \code{file.path(output_dir,
#' "portfolio")}. Creates the subdirectory if needed.
#'
#' @param portfolio_result List. Output from \code{run_portfolio()}.
#' @param output_dir Character. Parent output directory.
#' @param config List or NULL. Brand config (used in Portfolio_Meta).
#'
#' @return List with status and files_written character vector.
#' @export
write_portfolio_csv <- function(portfolio_result, output_dir, config = NULL) {
  if (is.null(portfolio_result) ||
      identical(portfolio_result$status, "REFUSED")) {
    return(list(status = "REFUSED", code = "DATA_PORTFOLIO_REFUSED",
                message = "Portfolio result is NULL or REFUSED"))
  }

  pf_dir <- file.path(output_dir, "portfolio")
  if (!dir.exists(pf_dir)) dir.create(pf_dir, recursive = TRUE)

  files_written <- character(0)

  .wcsv <- function(df, filename) {
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) return()
    path <- file.path(pf_dir, filename)
    write.csv(df, path, row.names = FALSE)
    files_written <<- c(files_written, path)
  }

  .wcsv(.pf_footprint_long(portfolio_result), "portfolio_footprint.csv")

  if (!is.null(portfolio_result$constellation$edges)) {
    .wcsv(portfolio_result$constellation$edges, "portfolio_constellation.csv")
  }

  if (!is.null(portfolio_result$clutter$clutter_df)) {
    .wcsv(portfolio_result$clutter$clutter_df, "portfolio_clutter.csv")
  }

  .wcsv(.pf_strength_long(portfolio_result), "portfolio_strength.csv")

  if (!is.null(portfolio_result$extension$extension_df)) {
    .wcsv(portfolio_result$extension$extension_df, "portfolio_extension.csv")
  }

  .wcsv(.pf_meta_df(portfolio_result, config), "portfolio_meta.csv")

  list(
    status        = "PASS",
    output_dir    = pf_dir,
    files_written = files_written,
    n_files       = length(files_written)
  )
}


# ==============================================================================
# PRIVATE DATA SHAPE HELPERS
# ==============================================================================

.pf_footprint_long <- function(portfolio_result) {
  fp <- portfolio_result$footprint_matrix
  if (is.null(fp) || !is.data.frame(fp) || nrow(fp) == 0) {
    return(data.frame(Brand = character(0), Category = character(0),
                      Awareness_Pct = numeric(0), N_Buyers_W = numeric(0),
                      N_Aware_W = numeric(0), stringsAsFactors = FALSE))
  }

  cat_cols <- setdiff(names(fp), "Brand")
  bases    <- portfolio_result$bases$per_category

  rows <- list()
  for (b in seq_len(nrow(fp))) {
    brand <- fp$Brand[b]
    for (cc in cat_cols) {
      pct <- fp[[cc]][b]
      n_buyers_w <- if (!is.null(bases) && cc %in% bases$cat) {
        bases$n_buyers_w[bases$cat == cc][1L]
      } else NA_real_
      n_aware_w <- if (!is.na(pct) && !is.na(n_buyers_w)) {
        (pct / 100) * n_buyers_w
      } else NA_real_
      rows[[length(rows) + 1L]] <- list(
        Brand         = brand,
        Category      = cc,
        Awareness_Pct = round(pct, 2),
        N_Buyers_W    = round(n_buyers_w, 1),
        N_Aware_W     = round(n_aware_w, 1)
      )
    }
  }

  if (length(rows) == 0) return(data.frame(Brand = character(0),
    Category = character(0), Awareness_Pct = numeric(0),
    N_Buyers_W = numeric(0), N_Aware_W = numeric(0), stringsAsFactors = FALSE))

  do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
}


.pf_strength_long <- function(portfolio_result) {
  st <- portfolio_result$strength
  if (is.null(st) || is.null(st$per_brand) || length(st$per_brand) == 0) {
    return(data.frame(Brand = character(0), Category = character(0),
                      Cat_Pen = numeric(0), Brand_Aware_Pct = numeric(0),
                      N_Aware_W = numeric(0), stringsAsFactors = FALSE))
  }

  dfs <- lapply(names(st$per_brand), function(brand) {
    d <- st$per_brand[[brand]]
    if (is.null(d) || nrow(d) == 0) return(NULL)
    data.frame(
      Brand           = brand,
      Category        = d$cat,
      Cat_Pen         = round(d$cat_pen * 100, 2),
      Brand_Aware_Pct = round(d$brand_aware * 100, 2),
      N_Aware_W       = round(d$aware_n_w, 1),
      stringsAsFactors = FALSE
    )
  })

  non_null <- Filter(Negate(is.null), dfs)
  if (length(non_null) == 0) return(data.frame(Brand = character(0),
    Category = character(0), Cat_Pen = numeric(0),
    Brand_Aware_Pct = numeric(0), N_Aware_W = numeric(0), stringsAsFactors = FALSE))

  do.call(rbind, non_null)
}


.pf_meta_df <- function(portfolio_result, config) {
  data.frame(
    Key   = c("focal_brand", "timeframe", "n_total", "n_weighted",
              "min_base", "suppressed_cats", "extension_baseline",
              "generated_at", "wave"),
    Value = c(
      portfolio_result$focal_brand %||% "",
      portfolio_result$timeframe   %||% "3m",
      as.character(portfolio_result$n_total   %||% 0L),
      as.character(round(portfolio_result$n_weighted %||% 0, 1)),
      as.character(config$portfolio_min_base %||% 30L),
      paste(portfolio_result$suppressions$low_base_cats %||% character(0),
            collapse = ", "),
      config$portfolio_extension_baseline %||% "all",
      format(Sys.time(), "%Y-%m-%d %H:%M"),
      as.character(config$wave %||% 1L)
    ),
    stringsAsFactors = FALSE
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
