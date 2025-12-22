#!/usr/bin/env Rscript
# =============================================================================
# TURAS FILE INVENTORY SCRIPT
# =============================================================================
# Purpose: Conduct a comprehensive inventory of all files in the Turas project
# Author: The Research LampPost (Pty) Ltd
# Usage: source("tools/inventory/file_inventory.R") or Rscript tools/inventory/file_inventory.R
# Output: Creates structure/TURAS_FILE_INVENTORY.csv and prints summary to console
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# Set the root directory (script is in tools/inventory, so go up 2 levels)
TURAS_ROOT <- normalizePath(file.path(dirname(sys.frame(1)$ofile), "..", ".."),
                            mustWork = FALSE)
if (is.null(sys.frame(1)$ofile)) {
  # Running interactively or via source()
  TURAS_ROOT <- getwd()
  if (!file.exists(file.path(TURAS_ROOT, "Turas.Rproj"))) {
    TURAS_ROOT <- normalizePath(file.path(TURAS_ROOT, ".."), mustWork = FALSE)
  }
  if (!file.exists(file.path(TURAS_ROOT, "Turas.Rproj"))) {
    TURAS_ROOT <- normalizePath(file.path(TURAS_ROOT, ".."), mustWork = FALSE)
  }
}

# Ensure structure directory exists
STRUCTURE_DIR <- file.path(TURAS_ROOT, "structure")
if (!dir.exists(STRUCTURE_DIR)) {
  dir.create(STRUCTURE_DIR, recursive = TRUE)
}

# Output file - save to structure/ directory
OUTPUT_FILE <- file.path(TURAS_ROOT, "structure", "TURAS_FILE_INVENTORY.csv")

# Directories to exclude from inventory
EXCLUDE_DIRS <- c(".git", ".Rproj.user", "__pycache__", ".idea", "node_modules")

# -----------------------------------------------------------------------------
# FILE TYPE DEFINITIONS
# -----------------------------------------------------------------------------

FILE_TYPES <- list(
  # Code files
  R = list(extensions = c("R", "r"), category = "Code", description = "R Script"),
  Python = list(extensions = c("py"), category = "Code", description = "Python Script"),
  Stan = list(extensions = c("stan"), category = "Code", description = "Stan Model"),
  Shell = list(extensions = c("sh", "bash"), category = "Code", description = "Shell Script"),
  Batch = list(extensions = c("bat", "cmd"), category = "Code", description = "Batch Script"),

  # Documentation
  Markdown = list(extensions = c("md"), category = "Documentation", description = "Markdown Document"),
  Text = list(extensions = c("txt"), category = "Documentation", description = "Text Document"),
  Word = list(extensions = c("docx", "doc"), category = "Documentation", description = "Word Document"),
  PDF = list(extensions = c("pdf"), category = "Documentation", description = "PDF Document"),

  # Data files
  CSV = list(extensions = c("csv"), category = "Data", description = "CSV Data File"),
  Excel = list(extensions = c("xlsx", "xls"), category = "Data/Config", description = "Excel File"),
  RDS = list(extensions = c("rds", "rda", "RData"), category = "Data", description = "R Data File"),
  JSON = list(extensions = c("json"), category = "Data", description = "JSON Data File"),
  SPSS = list(extensions = c("sav"), category = "Data", description = "SPSS Data File"),

  # Config/Project
  RProj = list(extensions = c("Rproj"), category = "Project", description = "RStudio Project"),
  Git = list(extensions = c("gitignore", "gitattributes"), category = "Config", description = "Git Config"),
  YAML = list(extensions = c("yml", "yaml"), category = "Config", description = "YAML Config"),

  # Other
  Image = list(extensions = c("png", "jpg", "jpeg", "gif", "svg"), category = "Media", description = "Image File"),
  Log = list(extensions = c("log"), category = "Log", description = "Log File")
)

# -----------------------------------------------------------------------------
# STATUS CLASSIFICATION RULES
# -----------------------------------------------------------------------------

classify_status <- function(filepath, filename, directory) {
  # Convert to lowercase for comparison
  dir_lower <- tolower(directory)
  file_lower <- tolower(filename)

  # ARCHIVED: Files in archive directories or with archive indicators
  if (grepl("archive", dir_lower) ||
      grepl("old_", dir_lower) ||
      grepl("legacy", dir_lower) ||
      grepl("deprecated", file_lower) ||
      grepl("_old\\.", file_lower) ||
      grepl("_backup\\.", file_lower)) {
    return("Archived")
  }

  # ACTIVE: Core module code, main scripts, launchers
  if (grepl("/modules/[^/]+/lib/", filepath) ||
      grepl("/modules/[^/]+/[^/]+\\.R$", filepath) ||
      grepl("launch.*\\.R$", file_lower) ||
      grepl("run_.*\\.R$", file_lower) ||
      grepl("/modules/shared/", filepath)) {
    return("Active")
  }

  # SUPPORTING: Tests, examples, templates, tools
  if (grepl("/tests/", dir_lower) ||
      grepl("/examples/", dir_lower) ||
      grepl("/templates/", dir_lower) ||
      grepl("/tools/", dir_lower) ||
      grepl("test_", file_lower) ||
      grepl("_test\\.", file_lower) ||
      grepl("example", file_lower) ||
      grepl("template", file_lower) ||
      grepl("mock", file_lower)) {
    return("Supporting")
  }

  # INFORMATIONAL: Documentation, specs, manuals
  if (grepl("\\.md$", file_lower) ||
      grepl("\\.txt$", file_lower) ||
      grepl("\\.docx?$", file_lower) ||
      grepl("\\.pdf$", file_lower) ||
      grepl("readme", file_lower) ||
      grepl("manual", file_lower) ||
      grepl("specification", file_lower) ||
      grepl("docs", dir_lower)) {
    return("Informational")
  }

  # Default based on file type
  ext <- tools::file_ext(filename)
  if (ext %in% c("R", "r", "py", "stan")) {
    return("Active")
  }
  if (ext %in% c("csv", "xlsx", "xls", "rds", "json")) {
    return("Supporting")
  }


  return("Supporting")
}

# -----------------------------------------------------------------------------
# PURPOSE INFERENCE
# -----------------------------------------------------------------------------

infer_purpose <- function(filepath, filename, directory, file_type) {
  file_lower <- tolower(filename)
  dir_lower <- tolower(directory)

  # Module-specific purposes
  modules <- c("alchemerparser", "confidence", "conjoint", "keydriver",
               "maxdiff", "pricing", "segment", "tabs", "tracker", "shared")

  for (mod in modules) {
    if (grepl(mod, dir_lower)) {
      mod_name <- tools::toTitleCase(mod)
      if (grepl("lib/", dir_lower)) {
        return(paste(mod_name, "module core library"))
      }
      if (grepl("test", file_lower) || grepl("/tests/", dir_lower)) {
        return(paste(mod_name, "module tests"))
      }
      if (grepl("example", dir_lower)) {
        return(paste(mod_name, "module example/sample data"))
      }
      if (grepl("\\.md$", file_lower)) {
        return(paste(mod_name, "module documentation"))
      }
      if (grepl("config", file_lower) || grepl("\\.xlsx$", file_lower)) {
        return(paste(mod_name, "module configuration"))
      }
      return(paste(mod_name, "module component"))
    }
  }

  # Directory-based purpose inference
  if (grepl("/templates/", dir_lower)) {
    return("Configuration template")
  }
  if (grepl("/docs/", dir_lower)) {
    if (grepl("manual", file_lower)) return("User manual")
    if (grepl("technical", file_lower)) return("Technical documentation")
    if (grepl("template", file_lower)) return("Template documentation")
    return("Project documentation")
  }
  if (grepl("/tools/", dir_lower)) {
    return("Utility/maintenance script")
  }
  if (grepl("/archive/", dir_lower)) {
    return("Historical/archived content")
  }
  if (grepl("/tests/", dir_lower)) {
    if (grepl("regression", dir_lower)) return("Regression test")
    return("Unit test")
  }
  if (grepl("/examples/", dir_lower)) {
    if (grepl("test_data", dir_lower)) return("Cross-module test data")
    return("Example/sample data")
  }

  # Filename-based purpose inference
  if (grepl("readme", file_lower)) return("Project/module overview")
  if (grepl("launch", file_lower)) return("Application launcher")
  if (grepl("config", file_lower)) return("Configuration")
  if (grepl("specification", file_lower) || grepl("spec", file_lower)) return("Specification document")
  if (grepl("manual", file_lower)) return("User manual")
  if (grepl("changelog", file_lower)) return("Change log")
  if (grepl("license", file_lower)) return("License file")
  if (grepl("inventory", file_lower)) return("File inventory")
  if (grepl("validation", file_lower)) return("Validation script/data")
  if (grepl("troubleshoot", file_lower)) return("Troubleshooting guide")
  if (grepl("maintenance", file_lower)) return("Maintenance documentation")

  # File type based
  if (file_type == "R Script") return("R analysis/utility script")
  if (file_type == "Python Script") return("Python utility script")
  if (file_type == "Excel File") return("Data or configuration file")
  if (file_type == "CSV Data File") return("Data file")
  if (file_type == "Markdown Document") return("Documentation")
  if (file_type == "Stan Model") return("Bayesian statistical model")

  return("General project file")
}

# -----------------------------------------------------------------------------
# QUALITY ASSESSMENT
# -----------------------------------------------------------------------------

assess_quality <- function(filepath, filename, file_type, file_size) {
  # Quality indicators
  quality_score <- 3  # Start at "Good" (scale: 1-5)
  notes <- character(0)

  file_lower <- tolower(filename)

  # File size checks
  if (file_size == 0) {
    return(list(rating = "Empty", notes = "File is empty"))
  }

  # For code files, check basic quality indicators
  if (file_type %in% c("R Script", "Python Script")) {
    if (file.exists(filepath)) {
      tryCatch({
        content <- readLines(filepath, warn = FALSE, n = 100)

        # Check for header/documentation
        has_header <- any(grepl("^#[^!].*=|^#.*Purpose|^#.*Author|^#.*Description", content))
        if (has_header) {
          quality_score <- quality_score + 1
          notes <- c(notes, "Has documentation header")
        }

        # Check for comments
        comment_lines <- sum(grepl("^\\s*#", content))
        if (comment_lines > length(content) * 0.1) {
          notes <- c(notes, "Well commented")
        }

        # Check for function definitions
        if (file_type == "R Script") {
          has_functions <- any(grepl("<-\\s*function\\s*\\(", content))
          if (has_functions) {
            notes <- c(notes, "Contains function definitions")
          }
        }
      }, error = function(e) {
        notes <- c(notes, "Could not read file for analysis")
      })
    }
  }

  # For documentation files
  if (file_type %in% c("Markdown Document", "Text Document")) {
    if (file.exists(filepath)) {
      tryCatch({
        content <- readLines(filepath, warn = FALSE, n = 200)

        # Check for structure
        has_headings <- any(grepl("^#{1,3}\\s", content))
        if (has_headings) {
          quality_score <- quality_score + 1
          notes <- c(notes, "Well structured with headings")
        }

        # Check content length
        total_chars <- sum(nchar(content))
        if (total_chars > 5000) {
          notes <- c(notes, "Comprehensive content")
        } else if (total_chars < 500) {
          quality_score <- quality_score - 1
          notes <- c(notes, "Brief content")
        }
      }, error = function(e) {
        notes <- c(notes, "Could not read file for analysis")
      })
    }
  }

  # Check for staleness (files not modified recently might need review)
  if (file.exists(filepath)) {
    mtime <- file.info(filepath)$mtime
    days_old <- as.numeric(difftime(Sys.time(), mtime, units = "days"))
    if (days_old > 365) {
      notes <- c(notes, sprintf("Not modified in %.0f days", days_old))
    }
  }

  # Convert score to rating
  rating <- switch(as.character(min(5, max(1, quality_score))),
    "1" = "Needs Review",
    "2" = "Fair",
    "3" = "Good",
    "4" = "Very Good",
    "5" = "Excellent"
  )

  return(list(
    rating = rating,
    notes = if (length(notes) > 0) paste(notes, collapse = "; ") else ""
  ))
}

# -----------------------------------------------------------------------------
# GET FILE TYPE
# -----------------------------------------------------------------------------

get_file_type <- function(filename) {
  ext <- tools::file_ext(filename)

  # Handle files without extensions
  if (ext == "") {
    if (grepl("^\\.", filename)) {
      return(list(type = "Hidden/Config", category = "Config"))
    }
    return(list(type = "Unknown", category = "Other"))
  }

  # Handle special git files
  if (grepl("gitignore|gitattributes", filename)) {
    return(list(type = "Git Config", category = "Config"))
  }

  # Match against known types
  for (type_name in names(FILE_TYPES)) {
    type_info <- FILE_TYPES[[type_name]]
    if (tolower(ext) %in% tolower(type_info$extensions)) {
      return(list(type = type_info$description, category = type_info$category))
    }
  }

  return(list(type = paste0(toupper(ext), " File"), category = "Other"))
}

# -----------------------------------------------------------------------------
# MAIN INVENTORY FUNCTION
# -----------------------------------------------------------------------------

create_inventory <- function(root_dir = TURAS_ROOT, output_file = OUTPUT_FILE) {

  cat("=============================================================================\n")
  cat("TURAS FILE INVENTORY\n")
  cat("=============================================================================\n")
  cat(sprintf("Root Directory: %s\n", root_dir))
  cat(sprintf("Timestamp: %s\n", Sys.time()))
  cat("=============================================================================\n\n")

  # Get all files recursively
  cat("Scanning files...\n")
  all_files <- list.files(root_dir, recursive = TRUE, full.names = TRUE,
                          include.dirs = FALSE, all.files = TRUE)

  # Filter out excluded directories
  for (excl in EXCLUDE_DIRS) {
    pattern <- paste0("/", excl, "/|/", excl, "$")
    all_files <- all_files[!grepl(pattern, all_files)]
  }

  cat(sprintf("Found %d files\n\n", length(all_files)))

  # Build inventory
  cat("Building inventory...\n")
  inventory <- data.frame(
    File_Name = character(),
    Location = character(),
    Relative_Path = character(),
    File_Type = character(),
    Category = character(),
    Size_KB = numeric(),
    Modified = character(),
    Purpose = character(),
    Quality = character(),
    Quality_Notes = character(),
    Status = character(),
    stringsAsFactors = FALSE
  )

  pb <- txtProgressBar(min = 0, max = length(all_files), style = 3)

  for (i in seq_along(all_files)) {
    filepath <- all_files[i]
    filename <- basename(filepath)
    directory <- dirname(filepath)
    rel_path <- sub(paste0("^", normalizePath(root_dir), "/?"), "", filepath)
    rel_dir <- sub(paste0("^", normalizePath(root_dir), "/?"), "", directory)

    # Get file info
    file_info <- file.info(filepath)
    file_size <- file_info$size / 1024  # Convert to KB
    modified <- format(file_info$mtime, "%Y-%m-%d %H:%M")

    # Get file type
    type_info <- get_file_type(filename)

    # Infer purpose
    purpose <- infer_purpose(filepath, filename, directory, type_info$type)

    # Assess quality
    quality_info <- assess_quality(filepath, filename, type_info$type, file_info$size)

    # Classify status
    status <- classify_status(filepath, filename, directory)

    # Add to inventory
    inventory <- rbind(inventory, data.frame(
      File_Name = filename,
      Location = if (rel_dir == "") "Root" else rel_dir,
      Relative_Path = rel_path,
      File_Type = type_info$type,
      Category = type_info$category,
      Size_KB = round(file_size, 2),
      Modified = modified,
      Purpose = purpose,
      Quality = quality_info$rating,
      Quality_Notes = quality_info$notes,
      Status = status,
      stringsAsFactors = FALSE
    ))

    setTxtProgressBar(pb, i)
  }

  close(pb)

  # Sort by location and filename
  inventory <- inventory[order(inventory$Location, inventory$File_Name), ]
  rownames(inventory) <- NULL

  # Write to CSV
  cat(sprintf("\nWriting inventory to: %s\n", output_file))
  write.csv(inventory, output_file, row.names = FALSE)

  # Print summary
  cat("\n=============================================================================\n")
  cat("INVENTORY SUMMARY\n")
  cat("=============================================================================\n\n")

  # By Status
  cat("FILES BY STATUS:\n")
  cat("-----------------\n")
  status_counts <- table(inventory$Status)
  for (s in names(sort(status_counts, decreasing = TRUE))) {
    cat(sprintf("  %-15s: %4d files\n", s, status_counts[s]))
  }
  cat(sprintf("  %-15s: %4d files\n", "TOTAL", nrow(inventory)))

  # By Category
  cat("\nFILES BY CATEGORY:\n")
  cat("-------------------\n")
  cat_counts <- table(inventory$Category)
  for (c in names(sort(cat_counts, decreasing = TRUE))) {
    cat(sprintf("  %-15s: %4d files\n", c, cat_counts[c]))
  }

  # By File Type (top 15)
  cat("\nFILES BY TYPE (Top 15):\n")
  cat("------------------------\n")
  type_counts <- sort(table(inventory$File_Type), decreasing = TRUE)
  for (i in seq_len(min(15, length(type_counts)))) {
    t <- names(type_counts)[i]
    cat(sprintf("  %-20s: %4d files\n", t, type_counts[i]))
  }

  # By Quality
  cat("\nFILES BY QUALITY:\n")
  cat("------------------\n")
  qual_counts <- table(inventory$Quality)
  qual_order <- c("Excellent", "Very Good", "Good", "Fair", "Needs Review", "Empty")
  for (q in qual_order) {
    if (q %in% names(qual_counts)) {
      cat(sprintf("  %-15s: %4d files\n", q, qual_counts[q]))
    }
  }

  # Files that may need attention
  cat("\n=============================================================================\n")
  cat("FILES THAT MAY NEED ATTENTION\n")
  cat("=============================================================================\n")

  # Empty files
  empty_files <- inventory[inventory$Quality == "Empty", ]
  if (nrow(empty_files) > 0) {
    cat(sprintf("\nEMPTY FILES (%d):\n", nrow(empty_files)))
    for (i in seq_len(min(10, nrow(empty_files)))) {
      cat(sprintf("  - %s\n", empty_files$Relative_Path[i]))
    }
    if (nrow(empty_files) > 10) {
      cat(sprintf("  ... and %d more\n", nrow(empty_files) - 10))
    }
  }

  # Archived files (for review)
  archived_files <- inventory[inventory$Status == "Archived", ]
  if (nrow(archived_files) > 0) {
    cat(sprintf("\nARCHIVED FILES (%d):\n", nrow(archived_files)))
    cat("  (Consider if these can be removed or should be kept)\n")
    # Group by top-level archive directory
    archive_dirs <- unique(dirname(archived_files$Relative_Path))
    archive_dirs <- archive_dirs[grepl("^archive", archive_dirs, ignore.case = TRUE)]
    for (d in head(archive_dirs, 10)) {
      count <- sum(grepl(paste0("^", d), archived_files$Relative_Path))
      cat(sprintf("  - %s/ (%d files)\n", d, count))
    }
  }

  cat("\n=============================================================================\n")
  cat(sprintf("Inventory complete! Output saved to: %s\n", output_file))
  cat("=============================================================================\n")

  return(invisible(inventory))
}

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS FOR WORKING WITH INVENTORY
# -----------------------------------------------------------------------------

#' Filter inventory by status
#' @param inventory The inventory data frame
#' @param status One of: "Active", "Supporting", "Informational", "Archived"
filter_by_status <- function(inventory, status) {
  inventory[inventory$Status == status, ]
}

#' Filter inventory by category
#' @param inventory The inventory data frame
#' @param category One of: "Code", "Documentation", "Data", "Config", etc.
filter_by_category <- function(inventory, category) {
  inventory[inventory$Category == category, ]
}

#' Get files in a specific directory
#' @param inventory The inventory data frame
#' @param dir_pattern Regex pattern for directory
filter_by_directory <- function(inventory, dir_pattern) {
  inventory[grepl(dir_pattern, inventory$Location, ignore.case = TRUE), ]
}

#' Get files that may be candidates for archiving
#' @param inventory The inventory data frame
get_archive_candidates <- function(inventory) {
  # Files that are old and not in active directories
  old_threshold <- 180  # days

  candidates <- inventory[
    inventory$Status != "Archived" &
    as.Date(inventory$Modified) < (Sys.Date() - old_threshold) &
    !grepl("modules/.*/lib", inventory$Location) &
    !grepl("README|MANUAL|TECHNICAL", inventory$File_Name, ignore.case = TRUE),
  ]

  return(candidates)
}

#' Generate summary report
#' @param inventory The inventory data frame
generate_summary_report <- function(inventory) {
  report <- list()

  report$total_files <- nrow(inventory)
  report$total_size_mb <- sum(inventory$Size_KB) / 1024

  report$by_status <- as.data.frame(table(inventory$Status))
  names(report$by_status) <- c("Status", "Count")

  report$by_category <- as.data.frame(table(inventory$Category))
  names(report$by_category) <- c("Category", "Count")

  report$by_quality <- as.data.frame(table(inventory$Quality))
  names(report$by_quality) <- c("Quality", "Count")

  return(report)
}

# -----------------------------------------------------------------------------
# RUN INVENTORY IF EXECUTED DIRECTLY
# -----------------------------------------------------------------------------

if (!interactive() || (exists("run_inventory") && run_inventory)) {
  inventory <- create_inventory()
}

# If sourced interactively, provide usage instructions
if (interactive()) {
  cat("\n")
  cat("TURAS FILE INVENTORY SCRIPT LOADED\n")
  cat("==================================\n")
  cat("\nTo run the inventory:\n")
  cat("  inventory <- create_inventory()\n")
  cat("\nTo filter results:\n")
  cat("  active_files <- filter_by_status(inventory, 'Active')\n")
  cat("  code_files <- filter_by_category(inventory, 'Code')\n")
  cat("  module_files <- filter_by_directory(inventory, 'modules/')\n")
  cat("\nTo find archive candidates:\n")
  cat("  candidates <- get_archive_candidates(inventory)\n")
  cat("\nTo generate a summary report:\n")
  cat("  report <- generate_summary_report(inventory)\n")
  cat("\n")
}
