#!/usr/bin/env Rscript
# ==============================================================================
# TURAS FILE REGISTRY SCANNER
# ==============================================================================
# Scans the entire Turas project and produces a comprehensive file inventory.
# Identifies duplicates, dated/versioned files, and output files in source.
# Outputs a multi-sheet Excel workbook for ongoing file management.
#
# Usage:
#   source("tools/file_registry.R")          # from RStudio
#   Rscript tools/file_registry.R            # from terminal
#
# Output:
#   Console summary + Excel workbook in docs/System docs/
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')")
}

# ---------------------------------------------------------------------------
# Find Turas root
# ---------------------------------------------------------------------------

find_root <- function() {
  candidates <- c(
    Sys.getenv("TURAS_ROOT", ""),
    getwd(),
    tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "")
  )
  for (d in candidates) {
    if (nzchar(d) && file.exists(file.path(d, "launch_turas.R"))) return(d)
    parent <- dirname(d)
    if (file.exists(file.path(parent, "launch_turas.R"))) return(parent)
  }
  stop("Cannot locate Turas root. Run from the Turas directory.")
}

turas_root <- find_root()
timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M")

cat("\n")
cat("==============================================================================\n")
cat("  TURAS FILE REGISTRY SCANNER\n")
cat(sprintf("  Generated: %s\n", timestamp))
cat("==============================================================================\n\n")
cat("  Scanning project files...\n")

# ---------------------------------------------------------------------------
# Scan all files (exclude .git, renv/library, node_modules, .claude)
# ---------------------------------------------------------------------------

all_files <- list.files(
  turas_root,
  recursive = TRUE,
  full.names = TRUE,
  all.files = FALSE,
  include.dirs = FALSE
)

# Exclude non-project directories
exclude_patterns <- c(
  "/\\.git/", "/renv/library/", "/renv/staging/", "/renv/python/",
  "/node_modules/", "/\\.claude/", "/\\.vscode/", "/\\.idea/",
  "/__pycache__/"
)
for (pat in exclude_patterns) {
  all_files <- all_files[!grepl(pat, all_files)]
}

cat(sprintf("  Found %d files total\n", length(all_files)))

# ---------------------------------------------------------------------------
# File metadata helpers
# ---------------------------------------------------------------------------

get_extension <- function(path) {
  ext <- tools::file_ext(path)
  tolower(ext)
}

get_file_type <- function(ext) {
  types <- list(
    "R Script"    = c("r"),
    "JavaScript"  = c("js"),
    "CSS"         = c("css"),
    "HTML"        = c("html", "htm"),
    "Markdown"    = c("md", "rmd"),
    "Excel"       = c("xlsx", "xls"),
    "JSON"        = c("json"),
    "YAML"        = c("yml", "yaml"),
    "Image"       = c("png", "jpg", "jpeg", "gif", "svg", "ico"),
    "PDF"         = c("pdf"),
    "Word"        = c("docx", "doc"),
    "PowerPoint"  = c("pptx", "ppt"),
    "Text"        = c("txt", "log"),
    "Python"      = c("py"),
    "Shell"       = c("sh", "bash"),
    "Data"        = c("csv", "tsv", "sav", "rds", "rda")
  )
  for (type_name in names(types)) {
    if (ext %in% types[[type_name]]) return(type_name)
  }
  if (nzchar(ext)) return(paste0("Other (.", ext, ")"))
  "Other"
}

get_module <- function(rel_path) {
  parts <- strsplit(rel_path, "/")[[1]]
  if (parts[1] == "modules" && length(parts) >= 2) return(parts[2])
  if (parts[1] == "tests") return("shared")
  if (parts[1] == "examples" && length(parts) >= 2) return(paste0("examples/", parts[2]))
  parts[1]
}

get_category <- function(rel_path, ext) {
  lp <- tolower(rel_path)

  if (grepl("/tests/", lp) || grepl("^tests/", lp))             return("Test")
  if (grepl("/templates/", lp) && ext %in% c("xlsx", "xls"))    return("Template")
  if (grepl("/examples/", lp) || grepl("^examples/", lp))       return("Example")
  if (grepl("/docs/", lp) || grepl("^docs/", lp))               return("Documentation")
  if (grepl("^archive/", lp))                                    return("Archive")
  if (grepl("^tools/", lp))                                      return("Tool")
  if (ext %in% c("md", "rmd"))                                   return("Documentation")
  if (ext %in% c("png", "jpg", "jpeg", "gif", "svg", "ico"))    return("Asset")
  if (ext %in% c("html", "htm") && !grepl("/lib/", lp))         return("Output")
  if (ext %in% c("r"))                                            return("Source")
  if (ext %in% c("js", "css"))                                   return("Source")
  if (ext %in% c("json", "yml", "yaml"))                         return("Config")
  if (ext %in% c("docx", "doc", "pdf", "pptx", "ppt"))          return("Documentation")
  "Other"
}

format_size <- function(bytes) {
  if (is.na(bytes)) return("-")
  if (bytes < 1024) return(paste0(bytes, " B"))
  if (bytes < 1024^2) return(sprintf("%.1f KB", bytes / 1024))
  sprintf("%.1f MB", bytes / 1024^2)
}

# ---------------------------------------------------------------------------
# Flag detection
# ---------------------------------------------------------------------------

detect_flags <- function(filename, rel_path, category) {
  flags <- character(0)

  # Dated files (e.g., "Report 20260103.docx", "file_2026-01-03.R")
  if (grepl("20[0-9]{6}", filename) || grepl("20[0-9]{2}-[0-9]{2}-[0-9]{2}", filename)) {
    flags <- c(flags, "DATED")
  }

  # Versioned files (v1, v2, v1.0, v1_1, etc.)
  if (grepl("_v[0-9]", filename, ignore.case = TRUE) ||
      grepl(" v[0-9]", filename, ignore.case = TRUE)) {
    flags <- c(flags, "VERSIONED")
  }

  # Old/backup/draft/legacy patterns
  if (grepl("(^|_)(old|backup|bak|draft|legacy|deprecated|temp|scratch)",
            filename, ignore.case = TRUE)) {
    flags <- c(flags, "LEGACY")
  }

  # Output files in source (HTML not in lib/ or docs/)
  ext <- get_extension(filename)
  if (ext %in% c("html", "htm") && !grepl("/lib/", rel_path) &&
      !grepl("/docs/", rel_path) && !grepl("^docs/", rel_path)) {
    flags <- c(flags, "OUTPUT_IN_SOURCE")
  }

  # Archive files
  if (grepl("^archive/", rel_path)) {
    flags <- c(flags, "ARCHIVED")
  }

  # .Rhistory, .RData, etc.
  if (grepl("\\.(Rhistory|RData|Ruserdata)$", filename)) {
    flags <- c(flags, "SHOULD_BE_IGNORED")
  }

  if (length(flags) == 0) return("")
  paste(flags, collapse = ", ")
}

# ---------------------------------------------------------------------------
# Build registry data frame
# ---------------------------------------------------------------------------

cat("  Classifying files...\n")

registry <- data.frame(
  File      = character(0),
  Path      = character(0),
  Type      = character(0),
  Module    = character(0),
  Category  = character(0),
  Size      = character(0),
  Size_Bytes = numeric(0),
  Status    = character(0),
  Flags     = character(0),
  Notes     = character(0),
  stringsAsFactors = FALSE
)

for (f in all_files) {
  rel_path <- substring(f, nchar(turas_root) + 2)
  filename <- basename(f)
  ext <- get_extension(filename)
  file_type <- get_file_type(ext)
  module <- get_module(rel_path)
  category <- get_category(rel_path, ext)
  finfo <- file.info(f)
  size_bytes <- finfo$size
  size_str <- format_size(size_bytes)
  flags <- detect_flags(filename, rel_path, category)

  # Auto-set status based on flags
  status <- "Active"
  if (grepl("ARCHIVED", flags)) status <- "Deprecated"
  if (grepl("LEGACY", flags)) status <- "Review"
  if (grepl("OUTPUT_IN_SOURCE", flags)) status <- "Review"
  if (grepl("SHOULD_BE_IGNORED", flags)) status <- "Review"

  registry <- rbind(registry, data.frame(
    File       = filename,
    Path       = rel_path,
    Type       = file_type,
    Module     = module,
    Category   = category,
    Size       = size_str,
    Size_Bytes = size_bytes,
    Status     = status,
    Flags      = flags,
    Notes      = "",
    stringsAsFactors = FALSE
  ))
}

rownames(registry) <- NULL

# ---------------------------------------------------------------------------
# Identify duplicates (same filename in multiple locations)
# ---------------------------------------------------------------------------

cat("  Finding duplicates...\n")

file_counts <- table(registry$File)
dup_names <- names(file_counts[file_counts > 1])
dup_df <- registry[registry$File %in% dup_names, , drop = FALSE]
dup_df <- dup_df[order(dup_df$File, dup_df$Path), ]
rownames(dup_df) <- NULL

# ---------------------------------------------------------------------------
# Config templates sheet
# ---------------------------------------------------------------------------

template_extensions <- c("xlsx", "xls")
template_rows <- registry[
  get_extension(registry$File) %in% template_extensions |
  grepl("template", registry$File, ignore.case = TRUE) |
  grepl("config", registry$File, ignore.case = TRUE) |
  registry$Category == "Template",
  , drop = FALSE
]
template_rows <- template_rows[order(template_rows$File, template_rows$Path), ]
rownames(template_rows) <- NULL

# ---------------------------------------------------------------------------
# Documents sheet
# ---------------------------------------------------------------------------

doc_extensions <- c("md", "rmd", "docx", "doc", "pdf", "pptx", "ppt", "txt")
doc_rows <- registry[
  get_extension(registry$File) %in% doc_extensions |
  registry$Category == "Documentation",
  , drop = FALSE
]
doc_rows <- doc_rows[order(doc_rows$Module, doc_rows$File), ]
rownames(doc_rows) <- NULL

# ---------------------------------------------------------------------------
# Flagged for review
# ---------------------------------------------------------------------------

flagged_df <- registry[nzchar(registry$Flags), , drop = FALSE]
flagged_df <- flagged_df[order(flagged_df$Flags, flagged_df$Path), ]
rownames(flagged_df) <- NULL

# ---------------------------------------------------------------------------
# Summary table
# ---------------------------------------------------------------------------

summary_by_type <- as.data.frame(table(registry$Type), stringsAsFactors = FALSE)
names(summary_by_type) <- c("File Type", "Count")
summary_by_type <- summary_by_type[order(-summary_by_type$Count), ]

summary_by_category <- as.data.frame(table(registry$Category), stringsAsFactors = FALSE)
names(summary_by_category) <- c("Category", "Count")
summary_by_category <- summary_by_category[order(-summary_by_category$Count), ]

summary_by_module <- as.data.frame(table(registry$Module), stringsAsFactors = FALSE)
names(summary_by_module) <- c("Module", "Count")
summary_by_module <- summary_by_module[order(-summary_by_module$Count), ]

summary_by_status <- as.data.frame(table(registry$Status), stringsAsFactors = FALSE)
names(summary_by_status) <- c("Status", "Count")

# ---------------------------------------------------------------------------
# Console output
# ---------------------------------------------------------------------------

cat("\n")
cat("==============================================================================\n")
cat("  FILE REGISTRY SUMMARY\n")
cat("==============================================================================\n\n")

cat(sprintf("  Total files scanned:        %d\n", nrow(registry)))
cat(sprintf("  Duplicate filenames:        %d files (%d unique names)\n",
            nrow(dup_df), length(dup_names)))
cat(sprintf("  Config templates found:     %d\n", nrow(template_rows)))
cat(sprintf("  Documents found:            %d\n", nrow(doc_rows)))
cat(sprintf("  Flagged for review:         %d\n", nrow(flagged_df)))

cat("\n  BY STATUS:\n")
for (i in seq_len(nrow(summary_by_status))) {
  cat(sprintf("    %-15s %d\n", summary_by_status[i, 1], summary_by_status[i, 2]))
}

cat("\n  BY CATEGORY:\n")
for (i in seq_len(nrow(summary_by_category))) {
  cat(sprintf("    %-15s %d\n", summary_by_category[i, 1], summary_by_category[i, 2]))
}

cat("\n  BY FILE TYPE:\n")
for (i in seq_len(min(15, nrow(summary_by_type)))) {
  cat(sprintf("    %-15s %d\n", summary_by_type[i, 1], summary_by_type[i, 2]))
}

# Highlight duplicate templates specifically
if (nrow(template_rows) > 0) {
  tpl_counts <- table(template_rows$File)
  tpl_dups <- names(tpl_counts[tpl_counts > 1])
  if (length(tpl_dups) > 0) {
    cat("\n  DUPLICATE TEMPLATES (same file in multiple locations):\n")
    for (tname in tpl_dups) {
      cat(sprintf("\n    %s:\n", tname))
      matches <- template_rows[template_rows$File == tname, ]
      for (j in seq_len(nrow(matches))) {
        cat(sprintf("      - %s  (%s)\n", matches$Path[j], matches$Size[j]))
      }
    }
  }
}

cat("\n")

# ===========================================================================
# Excel output
# ===========================================================================

cat("  Writing Excel workbook...\n")

output_dir <- file.path(turas_root, "docs", "System docs")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
output_file <- file.path(output_dir, "Turas_File_Registry.xlsx")

wb <- openxlsx::createWorkbook()

# Styles (matching platform_stats.R)
sty_header <- openxlsx::createStyle(
  fontName = "Arial", fontSize = 11, textDecoration = "bold",
  fgFill = "#2c3e50", fontColour = "#ffffff", halign = "center",
  border = "bottom", borderStyle = "medium"
)
sty_title <- openxlsx::createStyle(
  fontName = "Arial", fontSize = 14, textDecoration = "bold"
)
sty_subtitle <- openxlsx::createStyle(
  fontName = "Arial", fontSize = 10, fontColour = "#7f8c8d"
)
sty_review <- openxlsx::createStyle(fontColour = "#e67e22", textDecoration = "italic")
sty_deprecated <- openxlsx::createStyle(fontColour = "#e74c3c", textDecoration = "italic")
sty_flag <- openxlsx::createStyle(fontColour = "#c0392b")

# Helper: write a titled sheet
write_sheet <- function(wb, sheet_name, title, df, col_widths = NULL) {
  openxlsx::addWorksheet(wb, sheet_name)
  sheet_idx <- which(names(wb) == sheet_name)

  openxlsx::writeData(wb, sheet_idx, title, startRow = 1)
  openxlsx::addStyle(wb, sheet_idx, sty_title, rows = 1, cols = 1)
  openxlsx::writeData(wb, sheet_idx, paste("Generated:", timestamp), startRow = 2)
  openxlsx::addStyle(wb, sheet_idx, sty_subtitle, rows = 2, cols = 1)

  # Remove Size_Bytes from display if present
  display_df <- df[, !names(df) %in% "Size_Bytes", drop = FALSE]
  openxlsx::writeData(wb, sheet_idx, display_df, startRow = 4, headerStyle = sty_header)

  # Colour status column if present
  if ("Status" %in% names(display_df)) {
    status_col <- which(names(display_df) == "Status")
    review_rows <- which(display_df$Status == "Review") + 4
    dep_rows <- which(display_df$Status == "Deprecated") + 4
    if (length(review_rows) > 0) {
      openxlsx::addStyle(wb, sheet_idx, sty_review, rows = review_rows, cols = status_col)
    }
    if (length(dep_rows) > 0) {
      openxlsx::addStyle(wb, sheet_idx, sty_deprecated, rows = dep_rows, cols = status_col)
    }
  }

  # Colour flags column if present
  if ("Flags" %in% names(display_df)) {
    flags_col <- which(names(display_df) == "Flags")
    flagged_rows <- which(nzchar(display_df$Flags)) + 4
    if (length(flagged_rows) > 0) {
      openxlsx::addStyle(wb, sheet_idx, sty_flag, rows = flagged_rows, cols = flags_col)
    }
  }

  # Column widths
  if (!is.null(col_widths)) {
    for (i in seq_along(col_widths)) {
      openxlsx::setColWidths(wb, sheet_idx, cols = i, widths = col_widths[i])
    }
  }

  # Auto-filter
  if (nrow(display_df) > 0) {
    openxlsx::addFilter(wb, sheet_idx, rows = 4, cols = seq_len(ncol(display_df)))
  }

  # Freeze top rows
  openxlsx::freezePane(wb, sheet_idx, firstActiveRow = 5, firstActiveCol = 2)

  invisible(sheet_idx)
}

# Column widths for main registry
main_widths <- c(30, 60, 12, 18, 15, 10, 12, 25, 20)

# --- Sheet 1: All Files ---
write_sheet(wb, "All Files",
            "TURAS File Registry — Complete Inventory",
            registry, main_widths)

# --- Sheet 2: Duplicate Filenames ---
write_sheet(wb, "Duplicates",
            "Files with Same Name in Multiple Locations",
            dup_df, main_widths)

# --- Sheet 3: Config Templates ---
write_sheet(wb, "Config Templates",
            "Configuration Templates — Verify Latest Polished Versions",
            template_rows, main_widths)

# --- Sheet 4: Documents ---
write_sheet(wb, "Documents",
            "All Documentation Files",
            doc_rows, main_widths)

# --- Sheet 5: Flagged for Review ---
write_sheet(wb, "Flagged for Review",
            "Files Flagged for Review — Dated, Versioned, Legacy, or Misplaced",
            flagged_df, main_widths)

# --- Sheet 6: Summary ---
openxlsx::addWorksheet(wb, "Summary")
sheet_idx <- which(names(wb) == "Summary")

openxlsx::writeData(wb, sheet_idx, "TURAS File Registry — Summary", startRow = 1)
openxlsx::addStyle(wb, sheet_idx, sty_title, rows = 1, cols = 1)
openxlsx::writeData(wb, sheet_idx, paste("Generated:", timestamp), startRow = 2)
openxlsx::addStyle(wb, sheet_idx, sty_subtitle, rows = 2, cols = 1)

# Key metrics
openxlsx::writeData(wb, sheet_idx, sprintf("Total files: %d", nrow(registry)), startRow = 4)
openxlsx::writeData(wb, sheet_idx, sprintf("Duplicate filenames: %d (%d unique)",
                                            nrow(dup_df), length(dup_names)), startRow = 5)
openxlsx::writeData(wb, sheet_idx, sprintf("Flagged for review: %d", nrow(flagged_df)), startRow = 6)

# Summary tables side by side
row_offset <- 8
openxlsx::writeData(wb, sheet_idx, "By Status", startRow = row_offset)
openxlsx::addStyle(wb, sheet_idx, sty_header, rows = row_offset, cols = 1:2, gridExpand = TRUE)
openxlsx::writeData(wb, sheet_idx, summary_by_status, startRow = row_offset + 1,
                    colNames = FALSE)

openxlsx::writeData(wb, sheet_idx, "By Category", startRow = row_offset, startCol = 4)
openxlsx::addStyle(wb, sheet_idx, sty_header, rows = row_offset, cols = 4:5, gridExpand = TRUE)
openxlsx::writeData(wb, sheet_idx, summary_by_category, startRow = row_offset + 1,
                    startCol = 4, colNames = FALSE)

type_row <- row_offset + max(nrow(summary_by_status), nrow(summary_by_category)) + 2
openxlsx::writeData(wb, sheet_idx, "By File Type", startRow = type_row)
openxlsx::addStyle(wb, sheet_idx, sty_header, rows = type_row, cols = 1:2, gridExpand = TRUE)
openxlsx::writeData(wb, sheet_idx, summary_by_type, startRow = type_row + 1, colNames = FALSE)

openxlsx::writeData(wb, sheet_idx, "By Module/Location", startRow = type_row, startCol = 4)
openxlsx::addStyle(wb, sheet_idx, sty_header, rows = type_row, cols = 4:5, gridExpand = TRUE)
openxlsx::writeData(wb, sheet_idx, summary_by_module, startRow = type_row + 1,
                    startCol = 4, colNames = FALSE)

openxlsx::setColWidths(wb, sheet_idx, cols = 1:5, widths = c(20, 10, 5, 20, 10))

# --- Save ---
openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)

cat("\n")
cat("==============================================================================\n")
cat(sprintf("  Excel registry saved: %s\n", output_file))
cat("==============================================================================\n")
cat("\n")
cat("  Sheets:\n")
cat("    1. All Files          — Complete inventory with status & flags\n")
cat("    2. Duplicates         — Same filename in multiple locations\n")
cat("    3. Config Templates   — All templates (verify latest versions)\n")
cat("    4. Documents          — All docs (.md, .docx, .pdf, etc.)\n")
cat("    5. Flagged for Review — Dated, versioned, legacy, or misplaced files\n")
cat("    6. Summary            — Counts by type, category, module, status\n")
cat("\n")
cat("  Use the Status column to mark files as Active / Review / Deprecated\n")
cat("  Use the Notes column to document decisions\n")
cat("\n")
