# ==============================================================================
# MARKET SIMULATOR - INTERACTIVE EXCEL SHEET
# ==============================================================================
#
# This file creates an interactive market simulator sheet in Excel with:
# - Product configuration dropdowns
# - Automatic market share calculations
# - Utilities breakdown
# - Sensitivity analysis
# - Charts and visualizations
#
# Part of: Turas Enhanced Conjoint Analysis Module
# Version: 2.0.0
# ==============================================================================

# ==============================================================================
# 1. MAIN SIMULATOR SHEET CREATOR
# ==============================================================================

#' Create interactive market simulator sheet in Excel workbook
#'
#' @param wb Workbook object (openxlsx)
#' @param utilities Data frame with Attribute, Level, Utility columns
#' @param importance Data frame with Attribute, Importance columns
#' @param config Configuration object
#' @param header_style Style object for headers
#' @param n_products Integer: number of products to include (default 5)
#'
#' @return NULL (modifies workbook in place)
create_market_simulator_sheet <- function(wb,
                                           utilities,
                                           importance,
                                           config,
                                           header_style,
                                           n_products = 5) {

  sheet_name <- "Market Simulator"

  # Add worksheet
  addWorksheet(wb, sheet_name, gridLines = TRUE, tabColour = "#4472C4")

  # Section 1: Instructions (rows 1-8)
  write_simulator_instructions(wb, sheet_name)

  # Section 2: Product Configuration (rows 10+)
  config_start_row <- 10
  config_end_row <- write_product_configuration(wb, sheet_name, config,
                                                  utilities, n_products,
                                                  config_start_row, header_style)

  # Section 3: Market Share Results (rows after config + 2)
  share_start_row <- config_end_row + 2
  share_end_row <- write_market_share_section(wb, sheet_name, config,
                                                n_products, share_start_row,
                                                header_style, config_start_row)

  # Section 4: Utilities Breakdown (rows after share + 2)
  breakdown_start_row <- share_end_row + 2
  breakdown_end_row <- write_utilities_breakdown(wb, sheet_name, config,
                                                   n_products, breakdown_start_row,
                                                   header_style, config_start_row)

  # Section 5: Sensitivity Analysis (rows after breakdown + 2)
  sensitivity_start_row <- breakdown_end_row + 2
  write_sensitivity_analysis(wb, sheet_name, config, sensitivity_start_row,
                               header_style, config_start_row, share_start_row)

  # Format columns
  setColWidths(wb, sheet_name, cols = 1, widths = 25)
  setColWidths(wb, sheet_name, cols = 2:(n_products + 1), widths = 20)

  # Freeze panes at instructions
  freezePane(wb, sheet_name, firstRow = TRUE, firstCol = TRUE)

  invisible(NULL)
}


# ==============================================================================
# 2. INSTRUCTIONS SECTION
# ==============================================================================

#' Write simulator instructions at top of sheet
write_simulator_instructions <- function(wb, sheet_name) {

  instructions <- c(
    "MARKET SIMULATOR - INSTRUCTIONS",
    "",
    "1. Select attribute levels for each product using dropdowns below",
    "2. Market shares update automatically using multinomial logit model",
    "3. View utilities breakdown to see what drives preference for each product",
    "4. Use sensitivity analysis to test the impact of changing attributes",
    "",
    "TIP: Start with your current product (Product 1) and competitor products (Products 2-3), then test new concepts (Products 4-5)"
  )

  # Write instructions
  for (i in seq_along(instructions)) {
    writeData(wb, sheet_name, instructions[i], startCol = 1, startRow = i)
  }

  # Style header
  inst_style <- createStyle(
    fontSize = 14,
    textDecoration = "bold",
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left"
  )
  addStyle(wb, sheet_name, inst_style, rows = 1, cols = 1:6, gridExpand = TRUE)

  # Merge cells for header
  mergeCells(wb, sheet_name, cols = 1:6, rows = 1)
}


# ==============================================================================
# 3. PRODUCT CONFIGURATION SECTION
# ==============================================================================

#' Write product configuration section with dropdowns
write_product_configuration <- function(wb, sheet_name, config, utilities,
                                         n_products, start_row, header_style) {

  current_row <- start_row

  # Write section header
  writeData(wb, sheet_name, "PRODUCT CONFIGURATION", startCol = 1, startRow = current_row)
  section_header_style <- createStyle(
    fontSize = 12,
    textDecoration = "bold",
    fontColour = "#FFFFFF",
    fgFill = "#5B9BD5"
  )
  addStyle(wb, sheet_name, section_header_style, rows = current_row, cols = 1:6,
           gridExpand = TRUE)
  mergeCells(wb, sheet_name, cols = 1:(n_products + 1), rows = current_row)
  current_row <- current_row + 1

  # Write column headers
  writeData(wb, sheet_name, "Attribute", startCol = 1, startRow = current_row)
  for (i in 1:n_products) {
    writeData(wb, sheet_name, paste0("Product ", i),
              startCol = 1 + i, startRow = current_row)
  }
  addStyle(wb, sheet_name, header_style, rows = current_row,
           cols = 1:(n_products + 1), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write attributes and create dropdowns
  attributes <- config$attributes$AttributeName

  for (attr in attributes) {
    # Write attribute name
    writeData(wb, sheet_name, attr, startCol = 1, startRow = current_row)

    # Get levels for this attribute
    attr_levels <- utilities$Level[utilities$Attribute == attr]
    attr_levels <- unique(attr_levels)

    # Create dropdown for each product
    for (prod in 1:n_products) {
      col <- 1 + prod

      # Create data validation (dropdown)
      dataValidation(
        wb, sheet_name,
        col = col,
        rows = current_row,
        type = "list",
        value = sprintf('"%s"', paste(attr_levels, collapse = '","'))
      )

      # Set default value (first level)
      writeData(wb, sheet_name, attr_levels[1], startCol = col, startRow = current_row)
    }

    current_row <- current_row + 1
  }

  # Add help text
  writeData(wb, sheet_name,
            "Use dropdowns above to configure each product's attributes",
            startCol = 1, startRow = current_row)
  note_style <- createStyle(fontSize = 10, fontColour = "#666666", textDecoration = "italic")
  addStyle(wb, sheet_name, note_style, rows = current_row, cols = 1)
  mergeCells(wb, sheet_name, cols = 1:(n_products + 1), rows = current_row)

  current_row
}


# ==============================================================================
# 4. MARKET SHARE SECTION
# ==============================================================================

#' Write market share calculation section
write_market_share_section <- function(wb, sheet_name, config, n_products,
                                        start_row, header_style, config_start_row) {

  current_row <- start_row

  # Section header
  writeData(wb, sheet_name, "MARKET SHARE PREDICTIONS", startCol = 1, startRow = current_row)
  section_header_style <- createStyle(
    fontSize = 12,
    textDecoration = "bold",
    fontColour = "#FFFFFF",
    fgFill = "#70AD47"
  )
  addStyle(wb, sheet_name, section_header_style, rows = current_row,
           cols = 1:(n_products + 1), gridExpand = TRUE)
  mergeCells(wb, sheet_name, cols = 1:(n_products + 1), rows = current_row)
  current_row <- current_row + 1

  # Column headers
  writeData(wb, sheet_name, "Metric", startCol = 1, startRow = current_row)
  for (i in 1:n_products) {
    writeData(wb, sheet_name, paste0("Product ", i),
              startCol = 1 + i, startRow = current_row)
  }
  addStyle(wb, sheet_name, header_style, rows = current_row,
           cols = 1:(n_products + 1), gridExpand = TRUE)
  current_row <- current_row + 1

  # Row 1: Total Utility
  utility_row <- current_row
  writeData(wb, sheet_name, "Total Utility", startCol = 1, startRow = current_row)

  # Row 2: exp(Utility)
  exp_utility_row <- current_row + 1
  writeData(wb, sheet_name, "exp(Utility)", startCol = 1, startRow = exp_utility_row)

  # Row 3: Market Share (%)
  share_row <- current_row + 2
  writeData(wb, sheet_name, "Market Share (%)", startCol = 1, startRow = share_row)

  # Create formulas for each product
  attributes <- config$attributes$AttributeName
  n_attributes <- length(attributes)

  for (prod in 1:n_products) {
    col <- 1 + prod
    col_letter <- int2col(col)

    # Total Utility Formula: VLOOKUP each attribute's utility from Simulator Data
    # Sum all VLOOKUP results
    utility_formula_parts <- vapply(seq_along(attributes), function(i) {
      config_row <- config_start_row + 1 + i  # +1 for header
      cell_ref <- paste0(col_letter, config_row)
      sprintf('IFERROR(VLOOKUP(%s,\'Simulator Data\'!$A:$C,3,FALSE),0)',
              cell_ref)
    }, character(1))

    utility_formula <- paste0("=", paste(utility_formula_parts, collapse = "+"))

    writeFormula(wb, sheet_name, x = utility_formula,
                 startCol = col, startRow = utility_row)

    # exp(Utility) Formula
    exp_formula <- sprintf("=EXP(%s%d)", col_letter, utility_row)
    writeFormula(wb, sheet_name, x = exp_formula,
                 startCol = col, startRow = exp_utility_row)

    # Market Share Formula
    # Create range for sum of all exp(Utility) values
    sum_range <- sprintf("$%s$%d:$%s$%d",
                         int2col(2), exp_utility_row,
                         int2col(1 + n_products), exp_utility_row)
    share_formula <- sprintf("=%s%d/SUM(%s)*100",
                             col_letter, exp_utility_row, sum_range)
    writeFormula(wb, sheet_name, x = share_formula,
                 startCol = col, startRow = share_row)
  }

  # Format numbers
  pct_style <- createStyle(numFmt = "0.0")
  addStyle(wb, sheet_name, pct_style, rows = utility_row,
           cols = 2:(n_products + 1), gridExpand = TRUE)
  addStyle(wb, sheet_name, pct_style, rows = exp_utility_row,
           cols = 2:(n_products + 1), gridExpand = TRUE)

  bold_pct_style <- createStyle(numFmt = "0.0", textDecoration = "bold",
                                 fgFill = "#E2EFDA")
  addStyle(wb, sheet_name, bold_pct_style, rows = share_row,
           cols = 2:(n_products + 1), gridExpand = TRUE)

  current_row <- share_row + 1

  # Add interpretation
  writeData(wb, sheet_name,
            "Shares calculated using multinomial logit: P(i) = exp(U_i) / sum(exp(U_j))",
            startCol = 1, startRow = current_row)
  note_style <- createStyle(fontSize = 10, fontColour = "#666666",
                             textDecoration = "italic")
  addStyle(wb, sheet_name, note_style, rows = current_row, cols = 1)
  mergeCells(wb, sheet_name, cols = 1:(n_products + 1), rows = current_row)

  current_row
}


# ==============================================================================
# 5. UTILITIES BREAKDOWN SECTION
# ==============================================================================

#' Write utilities breakdown section
write_utilities_breakdown <- function(wb, sheet_name, config, n_products,
                                       start_row, header_style, config_start_row) {

  current_row <- start_row

  # Section header
  writeData(wb, sheet_name, "UTILITIES BREAKDOWN",
            startCol = 1, startRow = current_row)
  section_header_style <- createStyle(
    fontSize = 12,
    textDecoration = "bold",
    fontColour = "#FFFFFF",
    fgFill = "#FFC000"
  )
  addStyle(wb, sheet_name, section_header_style, rows = current_row,
           cols = 1:(n_products + 1), gridExpand = TRUE)
  mergeCells(wb, sheet_name, cols = 1:(n_products + 1), rows = current_row)
  current_row <- current_row + 1

  # Column headers
  writeData(wb, sheet_name, "Attribute", startCol = 1, startRow = current_row)
  for (i in 1:n_products) {
    writeData(wb, sheet_name, paste0("Product ", i),
              startCol = 1 + i, startRow = current_row)
  }
  addStyle(wb, sheet_name, header_style, rows = current_row,
           cols = 1:(n_products + 1), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write each attribute's utility contribution
  attributes <- config$attributes$AttributeName

  for (i in seq_along(attributes)) {
    attr <- attributes[i]
    writeData(wb, sheet_name, attr, startCol = 1, startRow = current_row)

    # For each product, VLOOKUP the utility
    for (prod in 1:n_products) {
      col <- 1 + prod
      col_letter <- int2col(col)

      # Reference to the selected level in configuration section
      config_row <- config_start_row + 1 + i  # +1 for header row
      level_cell <- paste0(col_letter, config_row)

      # VLOOKUP formula
      formula <- sprintf("=IFERROR(VLOOKUP(%s,\'Simulator Data\'!$A:$C,3,FALSE),0)",
                         level_cell)
      writeFormula(wb, sheet_name, x = formula, startCol = col, startRow = current_row)
    }

    current_row <- current_row + 1
  }

  # Add TOTAL row
  writeData(wb, sheet_name, "TOTAL", startCol = 1, startRow = current_row)
  bold_style <- createStyle(textDecoration = "bold", fgFill = "#FFEB9C")

  for (prod in 1:n_products) {
    col <- 1 + prod
    col_letter <- int2col(col)

    # Sum all utilities above
    first_row <- start_row + 2
    last_row <- current_row - 1
    formula <- sprintf("=SUM(%s%d:%s%d)", col_letter, first_row,
                       col_letter, last_row)
    writeFormula(wb, sheet_name, x = formula, startCol = col, startRow = current_row)

    addStyle(wb, sheet_name, bold_style, rows = current_row, cols = col)
  }
  addStyle(wb, sheet_name, bold_style, rows = current_row, cols = 1)

  # Format numbers
  num_style <- createStyle(numFmt = "0.000")
  addStyle(wb, sheet_name, num_style, rows = (start_row + 2):(current_row - 1),
           cols = 2:(n_products + 1), gridExpand = TRUE)

  # Conditional formatting (green/red)
  for (prod in 1:n_products) {
    col <- 1 + prod
    conditionalFormatting(
      wb, sheet_name,
      cols = col,
      rows = (start_row + 2):(current_row - 1),
      type = "colourScale",
      style = c("#F8696B", "#FFFFFF", "#63BE7B"),
      rule = c(-2, 0, 2)
    )
  }

  current_row
}


# ==============================================================================
# 6. SENSITIVITY ANALYSIS SECTION
# ==============================================================================

#' Write sensitivity analysis section
write_sensitivity_analysis <- function(wb, sheet_name, config, start_row,
                                        header_style, config_start_row, share_row) {

  current_row <- start_row

  # Section header
  writeData(wb, sheet_name, "SENSITIVITY ANALYSIS (Product 1)",
            startCol = 1, startRow = current_row)
  section_header_style <- createStyle(
    fontSize = 12,
    textDecoration = "bold",
    fontColour = "#FFFFFF",
    fgFill = "#E74C3C"
  )
  addStyle(wb, sheet_name, section_header_style, rows = current_row,
           cols = 1:4, gridExpand = TRUE)
  mergeCells(wb, sheet_name, cols = 1:4, rows = current_row)
  current_row <- current_row + 1

  # Instructions
  writeData(wb, sheet_name,
            "See how Product 1's market share changes when you modify each attribute:",
            startCol = 1, startRow = current_row)
  mergeCells(wb, sheet_name, cols = 1:4, rows = current_row)
  current_row <- current_row + 1

  # Column headers
  writeData(wb, sheet_name, "Attribute", startCol = 1, startRow = current_row)
  writeData(wb, sheet_name, "Current Level", startCol = 2, startRow = current_row)
  writeData(wb, sheet_name, "Current Share (%)", startCol = 3, startRow = current_row)
  writeData(wb, sheet_name, "Impact", startCol = 4, startRow = current_row)
  addStyle(wb, sheet_name, header_style, rows = current_row, cols = 1:4,
           gridExpand = TRUE)
  current_row <- current_row + 1

  # Write each attribute
  attributes <- config$attributes$AttributeName

  for (i in seq_along(attributes)) {
    attr <- attributes[i]
    writeData(wb, sheet_name, attr, startCol = 1, startRow = current_row)

    # Current level (reference to config)
    config_row_ref <- config_start_row + 1 + i
    formula_level <- sprintf("=%s%d", int2col(2), config_row_ref)
    writeFormula(wb, sheet_name, x = formula_level, startCol = 2, startRow = current_row)

    # Current share (reference to Product 1 share)
    share_cell <- sprintf("=%s%d", int2col(2), share_row + 2)  # +2 for market share row
    writeFormula(wb, sheet_name, x = share_cell, startCol = 3, startRow = current_row)

    # Impact assessment (text based on importance)
    impact_text <- "Varies by level choice"
    writeData(wb, sheet_name, impact_text, startCol = 4, startRow = current_row)

    current_row <- current_row + 1
  }

  # Add note
  writeData(wb, sheet_name,
            "TIP: Change levels in Product Configuration above and watch shares update in real-time",
            startCol = 1, startRow = current_row)
  note_style <- createStyle(fontSize = 10, fontColour = "#666666",
                             textDecoration = "italic")
  addStyle(wb, sheet_name, note_style, rows = current_row, cols = 1)
  mergeCells(wb, sheet_name, cols = 1:4, rows = current_row)

  current_row
}


# ==============================================================================
# 7. SIMULATOR DATA SHEET (HIDDEN LOOKUP TABLES)
# ==============================================================================

#' Create hidden simulator data sheet with lookup tables
#'
#' @param wb Workbook object
#' @param utilities Data frame with utilities
#' @param importance Data frame with importance
#' @param header_style Style for headers
#'
#' @return NULL (modifies workbook)
create_simulator_data_sheet <- function(wb, utilities, importance, header_style) {

  sheet_name <- "Simulator Data"

  # Add worksheet
  addWorksheet(wb, sheet_name, gridLines = FALSE, tabColour = "#767676")

  # Table 1: Utility Lookup (cols A-C)
  lookup_data <- utilities[, c("Level", "Attribute", "Utility")]
  lookup_data <- lookup_data[order(lookup_data$Attribute, lookup_data$Level), ]

  writeData(wb, sheet_name, lookup_data, startRow = 1, startCol = 1,
            colNames = TRUE, headerStyle = header_style)

  # Format as table
  addTable(wb, sheet_name,
           x = lookup_data,
           startCol = 1,
           startRow = 1,
           tableName = "UtilityLookup",
           withFilter = FALSE)

  # Table 2: Attribute Importance (cols E-F)
  importance_data <- importance[, c("Attribute", "Importance")]
  importance_data <- importance_data[order(-importance_data$Importance), ]

  writeData(wb, sheet_name, importance_data, startRow = 1, startCol = 5,
            colNames = TRUE, headerStyle = header_style)

  # Format columns
  setColWidths(wb, sheet_name, cols = 1:3, widths = c(20, 20, 15))
  setColWidths(wb, sheet_name, cols = 5:6, widths = c(20, 15))

  # Hide this sheet
  sheetVisibility(wb)[sheet_name] <- "hidden"

  invisible(NULL)
}


# ==============================================================================
# 8. HELPER FUNCTIONS
# ==============================================================================

#' Convert column number to Excel column letter
#'
#' @param col Integer column number (1-based)
#'
#' @return Character: Excel column letter (A, B, ..., Z, AA, AB, ...)
int2col <- function(col) {
  if (col <= 0) stop("Column number must be positive")

  result <- ""
  while (col > 0) {
    remainder <- (col - 1) %% 26
    result <- paste0(LETTERS[remainder + 1], result)
    col <- floor((col - 1) / 26)
  }

  result
}
