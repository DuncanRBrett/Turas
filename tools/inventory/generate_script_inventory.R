#!/usr/bin/env Rscript
# ==============================================================================
# TURAS R SCRIPT INVENTORY GENERATOR
# ==============================================================================
# Purpose: Analyze all R scripts in the Turas repository and generate a
#          comprehensive inventory with metrics and refactoring assessments
# Usage: source("generate_script_inventory.R") or Rscript generate_script_inventory.R
# Output: Creates CSV and HTML reports in structure/ directory
# Version: 1.0.0
# Date: 2025-12-14
# ==============================================================================

# Suppress warnings for cleaner output
options(warn = -1)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Get script directory (works when sourced or run via Rscript)
SCRIPT_DIR <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  getwd()
})

# Repository root (script is in tools/inventory, so go up 2 levels)
REPO_ROOT <- normalizePath(file.path(SCRIPT_DIR, "..", ".."), mustWork = FALSE)

# Output files - save to structure/ directory
OUTPUT_DIR <- file.path(REPO_ROOT, "structure")
OUTPUT_CSV <- file.path(OUTPUT_DIR, "r_script_inventory.csv")
OUTPUT_HTML <- file.path(OUTPUT_DIR, "r_script_inventory.html")

# Ensure output directory exists
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Directories to exclude from analysis
EXCLUDE_DIRS <- c("renv", ".git", ".Rproj.user")

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

#' Extract function names from R script content
#'
#' Parses R code to find function definitions
#' Handles both <- and = assignment operators
#'
#' @param lines Character vector of file lines
#' @return Character vector of function names
extract_functions <- function(lines) {
  # Remove comments first
  code_lines <- gsub("#.*$", "", lines)

  # Pattern for function definitions
  # Matches: function_name <- function( or function_name = function(
  func_pattern <- "^\\s*([a-zA-Z_][a-zA-Z0-9_\\.]*)\\s*(<-|=)\\s*function\\s*\\("

  # Find matching lines
  func_matches <- grep(func_pattern, code_lines, value = FALSE)

  if (length(func_matches) == 0) {
    return(character(0))
  }

  # Extract function names
  func_names <- character(length(func_matches))
  for (i in seq_along(func_matches)) {
    line <- code_lines[func_matches[i]]
    match <- regmatches(line, regexec(func_pattern, line))[[1]]
    if (length(match) >= 2) {
      func_names[i] <- match[2]
    }
  }

  # Remove empty strings and duplicates
  func_names <- unique(func_names[func_names != ""])

  return(func_names)
}

#' Count line types in an R script
#'
#' Categorizes each line as code, comment, or blank
#'
#' @param lines Character vector of file lines
#' @return Named list with counts for each type
count_line_types <- function(lines) {
  n_blank <- 0
  n_comment <- 0
  n_code <- 0

  for (line in lines) {
    # Trim whitespace
    trimmed <- trimws(line)

    if (trimmed == "") {
      n_blank <- n_blank + 1
    } else if (grepl("^#", trimmed)) {
      # Line starts with comment
      n_comment <- n_comment + 1
    } else if (grepl("#", trimmed)) {
      # Line has code and comment - count as code
      n_code <- n_code + 1
    } else {
      # Pure code line
      n_code <- n_code + 1
    }
  }

  return(list(
    blank = n_blank,
    comment = n_comment,
    code = n_code,
    total = length(lines)
  ))
}

#' Extract task/purpose from script header
#'
#' Looks for purpose description in header comments
#'
#' @param lines Character vector of file lines
#' @return Character string describing the script's purpose
extract_task <- function(lines) {
  # Look in first 30 lines for purpose/task description
  header_lines <- lines[1:min(30, length(lines))]

  # Look for common purpose indicators
  purpose_patterns <- c(
    "Purpose:\\s*(.+)$",
    "Task:\\s*(.+)$",
    "Description:\\s*(.+)$",
    "Main entry point for (.+)$",
    "Module:\\s*(.+)$"
  )

  for (pattern in purpose_patterns) {
    for (line in header_lines) {
      if (grepl(pattern, line, ignore.case = TRUE)) {
        match <- regmatches(line, regexec(pattern, line, ignore.case = TRUE))[[1]]
        if (length(match) >= 2) {
          task <- trimws(gsub("#", "", match[2]))
          return(task)
        }
      }
    }
  }

  # Try to extract from file header block
  comment_block <- grep("^#", header_lines, value = TRUE)
  if (length(comment_block) > 0) {
    # Remove comment markers and trim
    cleaned <- trimws(gsub("^#+\\s*", "", comment_block))
    # Remove separator lines
    cleaned <- cleaned[!grepl("^=+$", cleaned)]
    cleaned <- cleaned[!grepl("^-+$", cleaned)]
    # Remove empty lines
    cleaned <- cleaned[cleaned != ""]

    # Look for the first substantive line after the title
    if (length(cleaned) >= 2) {
      # Skip title lines (all caps, contains "TURAS", etc.)
      for (line in cleaned) {
        if (nchar(line) > 10 &&
            !grepl("^[A-Z\\s\\>\\-]+$", line) &&
            !grepl("^Turas v[0-9]", line) &&
            !grepl("^Version:", line) &&
            !grepl("^Date:", line) &&
            !grepl("^Author:", line)) {
          return(line)
        }
      }
    }
  }

  return("No description found")
}

#' Calculate refactoring complexity score
#'
#' Rates how difficult it would be to refactor the script into smaller files
#' Based on: lines of code, number of functions, dependencies, cohesion
#'
#' @param script_info List with script metrics
#' @return Named list with score (1-10) and rating (Easy/Medium/Hard/Very Hard)
calculate_refactor_score <- function(script_info) {
  score <- 0
  reasons <- character()

  # Factor 1: Lines of code (40% weight)
  code_lines <- script_info$code_lines
  if (code_lines < 100) {
    score <- score + 1
    reasons <- c(reasons, "Small file (<100 LOC)")
  } else if (code_lines < 300) {
    score <- score + 3
    reasons <- c(reasons, "Medium file (100-300 LOC)")
  } else if (code_lines < 600) {
    score <- score + 5
    reasons <- c(reasons, "Large file (300-600 LOC)")
  } else if (code_lines < 1000) {
    score <- score + 7
    reasons <- c(reasons, "Very large file (600-1000 LOC)")
  } else {
    score <- score + 9
    reasons <- c(reasons, "Extremely large file (>1000 LOC)")
  }

  # Factor 2: Number of functions (30% weight)
  n_functions <- script_info$num_functions
  if (n_functions == 0) {
    score <- score + 0.5
    reasons <- c(reasons, "No functions (script/config)")
  } else if (n_functions <= 3) {
    score <- score + 1
    reasons <- c(reasons, "Few functions (1-3)")
  } else if (n_functions <= 10) {
    score <- score + 2.5
    reasons <- c(reasons, "Several functions (4-10)")
  } else if (n_functions <= 20) {
    score <- score + 4
    reasons <- c(reasons, "Many functions (11-20)")
  } else {
    score <- score + 5
    reasons <- c(reasons, "Very many functions (>20)")
  }

  # Factor 3: Function density (20% weight)
  if (code_lines > 0 && n_functions > 0) {
    avg_func_size <- code_lines / n_functions
    if (avg_func_size < 20) {
      score <- score + 0.5
      reasons <- c(reasons, "Small avg function size")
    } else if (avg_func_size < 50) {
      score <- score + 1
      reasons <- c(reasons, "Medium avg function size")
    } else if (avg_func_size < 100) {
      score <- score + 1.5
      reasons <- c(reasons, "Large avg function size")
    } else {
      score <- score + 2
      reasons <- c(reasons, "Very large avg function size")
    }
  }

  # Factor 4: File type bonus (10% weight)
  filename <- basename(script_info$path)
  if (grepl("^00_main", filename)) {
    score <- score + 0.5
    reasons <- c(reasons, "Main entry point (orchestrator)")
  } else if (grepl("^99_", filename)) {
    score <- score + 0
    reasons <- c(reasons, "Helper/utility file")
  } else if (grepl("test", filename, ignore.case = TRUE)) {
    score <- score + 0.5
    reasons <- c(reasons, "Test file")
  }

  # Normalize to 1-10 scale
  # Max possible score is ~17, normalize to 10
  normalized_score <- min(10, max(1, round(score * 10 / 17, 1)))

  # Rating categories
  if (normalized_score <= 2.5) {
    rating <- "Very Easy"
    recommendation <- "No refactoring needed - file is well-sized"
  } else if (normalized_score <= 5) {
    rating <- "Easy"
    recommendation <- "Minor refactoring possible - consider splitting if functions are unrelated"
  } else if (normalized_score <= 7) {
    rating <- "Medium"
    recommendation <- "Moderate refactoring recommended - identify logical function groups"
  } else if (normalized_score <= 8.5) {
    rating <- "Hard"
    recommendation <- "Significant refactoring needed - break into multiple files by responsibility"
  } else {
    rating <- "Very Hard"
    recommendation <- "Major refactoring required - large file with many functions needs careful decomposition"
  }

  return(list(
    score = normalized_score,
    rating = rating,
    recommendation = recommendation,
    reasons = paste(reasons, collapse = "; ")
  ))
}

#' Analyze a single R script file
#'
#' Extracts all metrics for one script
#'
#' @param file_path Path to the R script
#' @return Named list with all script metrics
analyze_script <- function(file_path) {
  # Read file
  tryCatch({
    lines <- readLines(file_path, warn = FALSE, encoding = "UTF-8")
  }, error = function(e) {
    warning(sprintf("Could not read file: %s - %s", file_path, e$message))
    return(NULL)
  })

  if (is.null(lines)) {
    return(NULL)
  }

  # Extract metrics
  line_counts <- count_line_types(lines)
  functions <- extract_functions(lines)
  task <- extract_task(lines)

  # Build result
  result <- list(
    path = file_path,
    relative_path = gsub(paste0("^", REPO_ROOT, "/?"), "", file_path),
    filename = basename(file_path),
    directory = dirname(gsub(paste0("^", REPO_ROOT, "/?"), "", file_path)),
    task = task,
    functions = paste(functions, collapse = ", "),
    num_functions = length(functions),
    total_lines = line_counts$total,
    code_lines = line_counts$code,
    comment_lines = line_counts$comment,
    blank_lines = line_counts$blank
  )

  # Calculate refactoring score
  refactor_info <- calculate_refactor_score(result)
  result$refactor_score <- refactor_info$score
  result$refactor_rating <- refactor_info$rating
  result$refactor_recommendation <- refactor_info$recommendation
  result$refactor_reasons <- refactor_info$reasons

  return(result)
}

#' Find all R scripts in repository
#'
#' Recursively searches for .R files, excluding specified directories
#'
#' @param root_dir Root directory to search
#' @return Character vector of file paths
find_r_scripts <- function(root_dir) {
  all_files <- list.files(
    root_dir,
    pattern = "\\.R$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )

  # Filter out excluded directories
  filtered <- all_files
  for (exclude_dir in EXCLUDE_DIRS) {
    pattern <- paste0("/", exclude_dir, "/")
    filtered <- filtered[!grepl(pattern, filtered)]
  }

  return(filtered)
}

# ==============================================================================
# REPORT GENERATION
# ==============================================================================

#' Generate CSV report
#'
#' @param inventory_df Data frame with inventory
#' @param output_path Path to output CSV
generate_csv_report <- function(inventory_df, output_path) {
  write.csv(inventory_df, output_path, row.names = FALSE)
  cat(sprintf("✓ CSV report saved to: %s\n", output_path))
}

#' Generate HTML report
#'
#' @param inventory_df Data frame with inventory
#' @param output_path Path to output HTML
generate_html_report <- function(inventory_df, output_path) {

  # Summary statistics
  total_scripts <- nrow(inventory_df)
  total_functions <- sum(inventory_df$num_functions)
  total_code_lines <- sum(inventory_df$code_lines)
  total_comment_lines <- sum(inventory_df$comment_lines)

  # Refactoring distribution
  refactor_counts <- table(inventory_df$refactor_rating)

  # Top 10 largest scripts
  top_largest <- head(inventory_df[order(-inventory_df$code_lines), ], 10)

  # Top 10 most complex (for refactoring)
  top_complex <- head(inventory_df[order(-inventory_df$refactor_score), ], 10)

  # Directory distribution
  dir_summary <- aggregate(
    cbind(num_scripts = relative_path) ~ directory,
    data = inventory_df,
    FUN = length
  )
  dir_summary <- dir_summary[order(-dir_summary$num_scripts), ]

  # Build HTML
  html <- sprintf('
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Turas R Script Inventory</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      max-width: 1400px;
      margin: 40px auto;
      padding: 0 20px;
      background: #f5f5f5;
      color: #333;
    }
    h1 {
      color: #2c3e50;
      border-bottom: 3px solid #3498db;
      padding-bottom: 10px;
    }
    h2 {
      color: #34495e;
      margin-top: 40px;
      border-bottom: 2px solid #95a5a6;
      padding-bottom: 5px;
    }
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      margin: 20px 0;
    }
    .summary-card {
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .summary-card h3 {
      margin: 0 0 10px 0;
      color: #7f8c8d;
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .summary-card .value {
      font-size: 32px;
      font-weight: bold;
      color: #2c3e50;
    }
    table {
      width: 100%%;
      border-collapse: collapse;
      background: white;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      margin: 20px 0;
    }
    th {
      background: #34495e;
      color: white;
      padding: 12px;
      text-align: left;
      font-weight: 600;
      position: sticky;
      top: 0;
    }
    td {
      padding: 10px 12px;
      border-bottom: 1px solid #ecf0f1;
    }
    tr:hover {
      background: #f8f9fa;
    }
    .rating-very-easy { color: #27ae60; font-weight: 600; }
    .rating-easy { color: #2ecc71; font-weight: 600; }
    .rating-medium { color: #f39c12; font-weight: 600; }
    .rating-hard { color: #e67e22; font-weight: 600; }
    .rating-very-hard { color: #e74c3c; font-weight: 600; }
    .code-path {
      font-family: "Courier New", monospace;
      font-size: 12px;
      color: #7f8c8d;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 3px;
      font-size: 11px;
      font-weight: 600;
    }
    .badge-functions {
      background: #3498db;
      color: white;
    }
    .badge-lines {
      background: #9b59b6;
      color: white;
    }
    .timestamp {
      color: #95a5a6;
      font-size: 14px;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <h1>📊 Turas R Script Inventory</h1>
  <p class="timestamp">Generated: %s</p>

  <h2>Summary Statistics</h2>
  <div class="summary-grid">
    <div class="summary-card">
      <h3>Total Scripts</h3>
      <div class="value">%d</div>
    </div>
    <div class="summary-card">
      <h3>Total Functions</h3>
      <div class="value">%s</div>
    </div>
    <div class="summary-card">
      <h3>Total Code Lines</h3>
      <div class="value">%s</div>
    </div>
    <div class="summary-card">
      <h3>Total Comments</h3>
      <div class="value">%s</div>
    </div>
  </div>

  <h2>Refactoring Complexity Distribution</h2>
  <table>
    <tr>
      <th>Rating</th>
      <th>Count</th>
      <th>Percentage</th>
    </tr>
',
    format(Sys.time(), "%%Y-%%m-%%d %%H:%%M:%%S"),
    total_scripts,
    format(total_functions, big.mark = ","),
    format(total_code_lines, big.mark = ","),
    format(total_comment_lines, big.mark = ",")
  )

  # Add refactoring distribution rows
  rating_order <- c("Very Easy", "Easy", "Medium", "Hard", "Very Hard")
  for (rating in rating_order) {
    count <- ifelse(rating %in% names(refactor_counts), refactor_counts[rating], 0)
    pct <- round(100 * count / total_scripts, 1)
    rating_class <- tolower(gsub(" ", "-", rating))
    html <- paste0(html, sprintf('
    <tr>
      <td class="rating-%s">%s</td>
      <td>%d</td>
      <td>%.1f%%</td>
    </tr>
', rating_class, rating, count, pct))
  }

  html <- paste0(html, '
  </table>

  <h2>Top 10 Largest Scripts (by lines of code)</h2>
  <table>
    <tr>
      <th>Script</th>
      <th>Directory</th>
      <th>Code Lines</th>
      <th>Functions</th>
      <th>Refactor Rating</th>
    </tr>
')

  for (i in 1:min(10, nrow(top_largest))) {
    row <- top_largest[i, ]
    rating_class <- tolower(gsub(" ", "-", row$refactor_rating))
    html <- paste0(html, sprintf('
    <tr>
      <td><strong>%s</strong><br><span class="code-path">%s</span></td>
      <td>%s</td>
      <td><span class="badge badge-lines">%d LOC</span></td>
      <td><span class="badge badge-functions">%d funcs</span></td>
      <td class="rating-%s">%s (%.1f)</td>
    </tr>
', row$filename, row$relative_path, row$directory, row$code_lines,
   row$num_functions, rating_class, row$refactor_rating, row$refactor_score))
  }

  html <- paste0(html, '
  </table>

  <h2>Top 10 Most Complex Scripts (highest refactoring difficulty)</h2>
  <table>
    <tr>
      <th>Script</th>
      <th>Directory</th>
      <th>Code Lines</th>
      <th>Functions</th>
      <th>Refactor Score</th>
      <th>Recommendation</th>
    </tr>
')

  for (i in 1:min(10, nrow(top_complex))) {
    row <- top_complex[i, ]
    rating_class <- tolower(gsub(" ", "-", row$refactor_rating))
    html <- paste0(html, sprintf('
    <tr>
      <td><strong>%s</strong><br><span class="code-path">%s</span></td>
      <td>%s</td>
      <td><span class="badge badge-lines">%d LOC</span></td>
      <td><span class="badge badge-functions">%d funcs</span></td>
      <td class="rating-%s">%s (%.1f)</td>
      <td style="font-size: 12px;">%s</td>
    </tr>
', row$filename, row$relative_path, row$directory, row$code_lines,
   row$num_functions, rating_class, row$refactor_rating, row$refactor_score,
   row$refactor_recommendation))
  }

  html <- paste0(html, '
  </table>

  <h2>Complete Script Inventory</h2>
  <table id="inventory">
    <tr>
      <th>Script</th>
      <th>Directory</th>
      <th>Task/Purpose</th>
      <th>Functions</th>
      <th>Code Lines</th>
      <th>Comments</th>
      <th>Blank</th>
      <th>Refactor Rating</th>
    </tr>
')

  # Sort by directory and filename
  inventory_sorted <- inventory_df[order(inventory_df$directory, inventory_df$filename), ]

  for (i in 1:nrow(inventory_sorted)) {
    row <- inventory_sorted[i, ]
    rating_class <- tolower(gsub(" ", "-", row$refactor_rating))

    # Truncate task if too long
    task_display <- row$task
    if (nchar(task_display) > 100) {
      task_display <- paste0(substr(task_display, 1, 97), "...")
    }

    # Truncate functions list if too long
    func_display <- row$functions
    if (nchar(func_display) > 60) {
      func_display <- paste0(substr(func_display, 1, 57), "...")
    }

    html <- paste0(html, sprintf('
    <tr>
      <td><strong>%s</strong><br><span class="code-path">%s</span></td>
      <td>%s</td>
      <td style="font-size: 12px;">%s</td>
      <td style="font-size: 11px;">%s<br><span class="badge badge-functions">%d funcs</span></td>
      <td>%d</td>
      <td>%d</td>
      <td>%d</td>
      <td class="rating-%s">%s<br>%.1f/10</td>
    </tr>
', row$filename, row$relative_path, row$directory, task_display,
   func_display, row$num_functions, row$code_lines, row$comment_lines,
   row$blank_lines, rating_class, row$refactor_rating, row$refactor_score))
  }

  html <- paste0(html, '
  </table>
</body>
</html>
')

  # Write HTML file
  writeLines(html, output_path)
  cat(sprintf("✓ HTML report saved to: %s\n", output_path))
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main <- function() {
  cat("\n")
  cat("==============================================================================\n")
  cat("TURAS R SCRIPT INVENTORY GENERATOR\n")
  cat("==============================================================================\n")
  cat("\n")

  # Find all R scripts
  cat("1. Scanning repository for R scripts...\n")
  r_scripts <- find_r_scripts(REPO_ROOT)
  cat(sprintf("   ✓ Found %d R script files\n", length(r_scripts)))

  # Analyze each script
  cat("\n2. Analyzing scripts...\n")
  inventory_list <- list()

  for (i in seq_along(r_scripts)) {
    script_path <- r_scripts[i]

    # Progress indicator
    if (i %% 10 == 0 || i == length(r_scripts)) {
      cat(sprintf("   Progress: %d/%d (%.0f%%)\r",
                  i, length(r_scripts), 100 * i / length(r_scripts)))
    }

    analysis <- analyze_script(script_path)
    if (!is.null(analysis)) {
      inventory_list[[i]] <- analysis
    }
  }
  cat("\n")

  # Convert to data frame
  inventory_df <- do.call(rbind.data.frame, c(inventory_list, stringsAsFactors = FALSE))

  cat(sprintf("   ✓ Successfully analyzed %d scripts\n", nrow(inventory_df)))

  # Generate reports
  cat("\n3. Generating reports...\n")
  generate_csv_report(inventory_df, OUTPUT_CSV)
  generate_html_report(inventory_df, OUTPUT_HTML)

  # Summary
  cat("\n")
  cat("==============================================================================\n")
  cat("INVENTORY COMPLETE\n")
  cat("==============================================================================\n")
  cat(sprintf("Total scripts analyzed: %d\n", nrow(inventory_df)))
  cat(sprintf("Total functions found: %d\n", sum(inventory_df$num_functions)))
  cat(sprintf("Total lines of code: %s\n", format(sum(inventory_df$code_lines), big.mark = ",")))
  cat(sprintf("Total comment lines: %s\n", format(sum(inventory_df$comment_lines), big.mark = ",")))
  cat("\nReports generated:\n")
  cat(sprintf("  - CSV: %s\n", OUTPUT_CSV))
  cat(sprintf("  - HTML: %s\n", OUTPUT_HTML))
  cat("\nRefactoring complexity distribution:\n")
  refactor_table <- table(inventory_df$refactor_rating)
  rating_order <- c("Very Easy", "Easy", "Medium", "Hard", "Very Hard")
  for (rating in rating_order) {
    count <- ifelse(rating %in% names(refactor_table), refactor_table[rating], 0)
    pct <- round(100 * count / nrow(inventory_df), 1)
    cat(sprintf("  - %-12s: %3d scripts (%.1f%%)\n", rating, count, pct))
  }
  cat("==============================================================================\n")
  cat("\n")
}

# Run main function
if (!interactive()) {
  main()
} else {
  cat("Script loaded. Run main() to generate inventory.\n")
}
