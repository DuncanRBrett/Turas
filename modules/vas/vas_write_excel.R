# vas_write_excel.R
# ------------------------------------------------------------------------------
# Write the derived numbers, their documentation and the settings that produced
# them into a single workbook, so the file explains itself without this repo.
#
# Sheets:
#   Derived     one row per respondent - the deliverable
#   Dictionary  one row per column of Derived: what it is and the exact arithmetic
#   Settings    every config value actually used on this run
#   Audit       one row per respondent x category x base, carrying the status
# ------------------------------------------------------------------------------

VAS_EXCEL_HEADER_FILL <- "#1F3864"
VAS_EXCEL_HEADER_TEXT <- "#FFFFFF"
VAS_EXCEL_GROUP_FILL <- "#EAEFF7"
VAS_EXCEL_FONT <- "Calibri"
VAS_EXCEL_FONT_SIZE <- 10

#' The header style used on every sheet
#'
#' @return An openxlsx style.
excel_header_style <- function() {
  return(openxlsx::createStyle(
    fontName = VAS_EXCEL_FONT, fontSize = VAS_EXCEL_FONT_SIZE, fontColour = VAS_EXCEL_HEADER_TEXT,
    fgFill = VAS_EXCEL_HEADER_FILL, textDecoration = "bold",
    halign = "left", valign = "top", wrapText = TRUE, border = "TopBottomLeftRight",
    borderColour = VAS_EXCEL_HEADER_FILL
  ))
}

#' Add one sheet, with a frozen header row and an autofilter
#'
#' @param wb An openxlsx workbook.
#' @param sheet The sheet name.
#' @param data The data frame to write.
#' @param widths A numeric vector of column widths, or "auto".
#' @param wrap_columns Indices of columns to wrap text in.
#'
#' @return The workbook, invisibly.
add_vas_sheet <- function(wb, sheet, data, widths = "auto", wrap_columns = integer(0)) {
  openxlsx::addWorksheet(wb, sheet)
  openxlsx::writeData(wb, sheet, data, headerStyle = excel_header_style())
  openxlsx::freezePane(wb, sheet, firstActiveRow = 2L, firstActiveCol = 2L)
  openxlsx::addFilter(wb, sheet, rows = 1L, cols = seq_len(ncol(data)))
  openxlsx::setColWidths(wb, sheet, cols = seq_len(ncol(data)), widths = widths)
  openxlsx::addStyle(wb, sheet,
    style = openxlsx::createStyle(fontName = VAS_EXCEL_FONT, fontSize = VAS_EXCEL_FONT_SIZE,
                                  valign = "top"),
    rows = seq_len(nrow(data)) + 1L, cols = seq_len(ncol(data)), gridExpand = TRUE)
  if (length(wrap_columns)) {
    openxlsx::addStyle(wb, sheet,
      style = openxlsx::createStyle(fontName = VAS_EXCEL_FONT, fontSize = VAS_EXCEL_FONT_SIZE,
                                    valign = "top", wrapText = TRUE),
      rows = seq_len(nrow(data)) + 1L, cols = wrap_columns, gridExpand = TRUE)
  }
  return(invisible(wb))
}

#' Flatten the config into a readable two-column table
#'
#' Nested lists and the income band frame are rendered as text so the whole
#' configuration is visible on one sheet.
#'
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of \code{setting} and \code{value}.
flatten_config <- function(config) {
  as_text <- function(x) {
    if (is.numeric(x)) format(x, scientific = FALSE, trim = TRUE) else as.character(x)
  }
  rows <- list()
  for (name in names(config)) {
    value <- config[[name]]
    rendered <- if (is.data.frame(value)) {
      # keep the column headings, so a lookup table reads as a table
      body <- apply(value, 1, function(r) paste(trimws(as_text(r)), collapse = " | "))
      paste(c(paste(names(value), collapse = " | "), body), collapse = "\n")
    } else if (is.list(value)) {
      paste(sprintf("%s = %s", names(value),
                    vapply(value, function(v) as_text(v)[1], character(1))), collapse = "\n")
    } else {
      paste(as_text(value), collapse = ", ")
    }
    rows[[length(rows) + 1L]] <- data.frame(setting = name, value = rendered,
                                            stringsAsFactors = FALSE)
  }
  return(do.call(rbind, rows))
}

#' Write the whole workbook
#'
#' @param result The list returned by \code{derive_vas()}.
#' @param dictionary The data frame from \code{build_data_dictionary()}.
#' @param config The VAS_CONFIG list.
#' @param source_origin "api" or "export", recorded on the Settings sheet.
#' @param path Where to write the .xlsx.
#'
#' @return The path, invisibly.
#'
#' @throws Stops with class "vas_dictionary_mismatch" when the dictionary and
#'   the derived table do not describe exactly the same columns.
write_vas_workbook <- function(result, dictionary, config, source_origin, path) {
  undocumented <- setdiff(names(result$wide), dictionary$column)
  orphaned <- setdiff(dictionary$column, names(result$wide))
  if (length(undocumented) || length(orphaned)) {
    stop(structure(class = c("vas_dictionary_mismatch", "error", "condition"), list(
      message = sprintf("Dictionary does not match the output.\n  undocumented columns: %s\n  documented but absent: %s",
                        paste(undocumented, collapse = ", ") , paste(orphaned, collapse = ", ")),
      call = NULL)))
  }

  settings <- rbind(
    data.frame(setting = "source", value = source_origin, stringsAsFactors = FALSE),
    data.frame(setting = "respondents", value = as.character(nrow(result$wide)),
               stringsAsFactors = FALSE),
    flatten_config(config)
  )

  wb <- openxlsx::createWorkbook()
  add_vas_sheet(wb, "Derived", result$wide, widths = "auto")
  add_vas_sheet(wb, "Dictionary", dictionary,
                widths = c(34, 13, 20, 7, 14, 20, 46, 62, 34, 52),
                wrap_columns = 7:10)
  add_vas_sheet(wb, "Settings", settings, widths = c(28, 74), wrap_columns = 2L)
  add_vas_sheet(wb, "Audit", result$audit, widths = "auto")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  return(invisible(path))
}

#' Write the dictionary as markdown, for reading in the repo
#'
#' @param dictionary The data frame from \code{build_data_dictionary()}.
#' @param path Where to write the .md.
#'
#' @return The path, invisibly.
write_dictionary_markdown <- function(dictionary, path) {
  lines <- c(
    "# VAS derived variables — the exact calculation for every column",
    "",
    sprintf("Generated from `vas_category_map.csv` and `vas_derived_config.R` by `run_vas_derive.R`. %d columns.",
            nrow(dictionary)),
    "Do not edit this file: change the map or the config and regenerate.",
    ""
  )
  for (group in unique(dictionary$group)) {
    lines <- c(lines, sprintf("## %s", group), "")
    section <- dictionary[dictionary$group == group, ]
    for (i in seq_len(nrow(section))) {
      lines <- c(lines,
        sprintf("### `%s`", section$column[i]),
        "",
        sprintf("%s Unit: %s.", section$description[i], section$unit[i]),
        "",
        "```",
        strsplit(section$calculation[i], "\n", fixed = TRUE)[[1]],
        "```",
        "",
        sprintf("Source questions: %s", section$source_questions[i]),
        "",
        sprintf("Missing and zero: %s", section$missing_rule[i]),
        "")
    }
  }
  writeLines(lines, path)
  return(invisible(path))
}
