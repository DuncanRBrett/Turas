#!/usr/bin/env Rscript
# ==============================================================================
# TURAS PLATFORM STATISTICS
# ==============================================================================
# Generates a per-module summary of R/JS code volume, test counts,
# config templates, and documentation. Outputs to console and Excel.
#
# Usage:
#   source("tools/platform_stats.R")          # from RStudio
#   Rscript tools/platform_stats.R            # from terminal
#
# Output:
#   Console tables + Excel workbook in docs/System docs/
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')")
}

# Find Turas root
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

`%||%` <- function(a, b) if (is.null(a)) b else a

turas_root <- find_root()
timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

count_lines <- function(files, exclude_blanks = TRUE, exclude_comments = TRUE) {
  if (length(files) == 0) return(0L)
  total <- 0L
  for (f in files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character(0))
    if (exclude_blanks)   lines <- lines[nzchar(trimws(lines))]
    if (exclude_comments) lines <- lines[!grepl("^\\s*#", lines) & !grepl("^\\s*//", lines)]
    total <- total + length(lines)
  }
  total
}

count_pattern <- function(files, pattern) {
  if (length(files) == 0) return(0L)
  total <- 0L
  for (f in files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character(0))
    total <- total + sum(grepl(pattern, lines, perl = TRUE))
  }
  total
}

# ---------------------------------------------------------------------------
# Gather stats for one module
# ---------------------------------------------------------------------------

module_stats <- function(mod_dir, test_dirs = NULL) {

  # R files (exclude tests)
  all_r <- list.files(mod_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  r_src <- all_r[!grepl("/tests/", all_r)]

  # JS files (exclude tests)
  all_js <- list.files(mod_dir, pattern = "\\.js$", recursive = TRUE, full.names = TRUE)
  js_src <- all_js[!grepl("/tests/", all_js)]

  # Test files
  if (is.null(test_dirs)) {
    test_dirs <- file.path(mod_dir, "tests")
  }
  test_files <- character(0)
  for (td in test_dirs) {
    if (dir.exists(td)) {
      test_files <- c(test_files,
                      list.files(td, pattern = "\\.R$", recursive = TRUE, full.names = TRUE))
    }
  }

  # Config templates (.xlsx in templates/, examples/, or docs/)
  template_dirs <- c(
    file.path(mod_dir, "templates"),
    file.path(mod_dir, "docs", "templates")
  )
  templates <- character(0)
  for (td in template_dirs) {
    if (dir.exists(td)) {
      templates <- c(templates,
                     list.files(td, pattern = "\\.(xlsx|xls)$", recursive = TRUE,
                                full.names = TRUE, ignore.case = TRUE))
    }
  }
  # Also count config templates in examples
  examples_dir <- file.path(turas_root, "examples", basename(mod_dir))
  if (dir.exists(examples_dir)) {
    example_configs <- list.files(examples_dir, pattern = "config.*\\.(xlsx|xls)$",
                                  recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
    templates <- c(templates, example_configs)
  }

  # Documentation files (.md, .Rmd in module, excluding tests)
  docs <- list.files(mod_dir, pattern = "\\.(md|Rmd)$", recursive = TRUE,
                     full.names = TRUE, ignore.case = TRUE)
  docs <- docs[!grepl("/tests/", docs)]

  list(
    r_scripts    = length(r_src),
    r_functions  = count_pattern(r_src, "<-\\s*function\\s*\\(|=\\s*function\\s*\\("),
    r_loc        = count_lines(r_src),
    js_scripts   = length(js_src),
    js_functions = count_pattern(js_src,
      "function\\s+\\w+\\s*\\(|\\w+\\s*[:=]\\s*function\\s*\\(|=>\\s*\\{|=>\\s*[^{]"),
    js_loc       = count_lines(js_src),
    tests        = count_pattern(test_files, "test_that\\s*\\("),
    assertions   = count_pattern(test_files, "expect_"),
    templates    = length(templates),
    docs         = length(docs)
  )
}

# ---------------------------------------------------------------------------
# Collect per-module stats
# ---------------------------------------------------------------------------

module_names <- c("AlchemerParser", "catdriver", "confidence", "conjoint",
                  "hub_app", "keydriver", "maxdiff", "pricing", "report_hub",
                  "segment", "shared", "tabs", "tracker", "weighting")

rows <- list()
for (mod in module_names) {
  mod_path <- file.path(turas_root, "modules", mod)
  if (!dir.exists(mod_path)) next
  s <- module_stats(mod_path)
  rows[[mod]] <- s
}

# Root-level (launch_turas.R + root tests + root templates + root docs)
root_r <- file.path(turas_root, "launch_turas.R")
root_test_dir <- file.path(turas_root, "tests")
root_test_files <- list.files(root_test_dir, pattern = "\\.R$",
                               recursive = TRUE, full.names = TRUE)

# Root templates (templates/ directory)
root_templates <- list.files(file.path(turas_root, "templates"),
                              pattern = "\\.(xlsx|xls)$", recursive = TRUE,
                              full.names = TRUE, ignore.case = TRUE)

# Root docs (docs/ directory, top-level .md files)
root_docs <- c(
  list.files(file.path(turas_root, "docs"), pattern = "\\.(md|Rmd)$",
             recursive = TRUE, full.names = TRUE, ignore.case = TRUE),
  list.files(turas_root, pattern = "\\.(md|Rmd)$", full.names = TRUE)
)

root_s <- list(
  r_scripts    = as.integer(file.exists(root_r)),
  r_functions  = count_pattern(root_r, "<-\\s*function\\s*\\(|=\\s*function\\s*\\("),
  r_loc        = count_lines(root_r),
  js_scripts   = 0L, js_functions = 0L, js_loc = 0L,
  tests        = count_pattern(root_test_files, "test_that\\s*\\("),
  assertions   = count_pattern(root_test_files, "expect_"),
  templates    = length(root_templates),
  docs         = length(root_docs)
)
rows[["Root"]] <- root_s

# ---------------------------------------------------------------------------
# Build main data frame
# ---------------------------------------------------------------------------

df <- data.frame(
  Module       = names(rows),
  R_Scripts    = sapply(rows, `[[`, "r_scripts"),
  R_Functions  = sapply(rows, `[[`, "r_functions"),
  R_LOC        = sapply(rows, `[[`, "r_loc"),
  JS_Scripts   = sapply(rows, `[[`, "js_scripts"),
  JS_Functions = sapply(rows, `[[`, "js_functions"),
  JS_LOC       = sapply(rows, `[[`, "js_loc"),
  Tests        = sapply(rows, `[[`, "tests"),
  Assertions   = sapply(rows, `[[`, "assertions"),
  Templates    = sapply(rows, `[[`, "templates"),
  Docs         = sapply(rows, `[[`, "docs"),
  stringsAsFactors = FALSE, row.names = NULL
)

totals <- data.frame(
  Module       = "TOTAL",
  R_Scripts    = sum(df$R_Scripts),
  R_Functions  = sum(df$R_Functions),
  R_LOC        = sum(df$R_LOC),
  JS_Scripts   = sum(df$JS_Scripts),
  JS_Functions = sum(df$JS_Functions),
  JS_LOC       = sum(df$JS_LOC),
  Tests        = sum(df$Tests),
  Assertions   = sum(df$Assertions),
  Templates    = sum(df$Templates),
  Docs         = sum(df$Docs),
  stringsAsFactors = FALSE
)
df_with_totals <- rbind(df, totals)

# ---------------------------------------------------------------------------
# Table 2: R Packages per module
# ---------------------------------------------------------------------------

extract_packages <- function(files) {
  if (length(files) == 0) return(character(0))
  pkgs <- character(0)
  for (f in files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character(0))
    m1 <- regmatches(lines, regexpr("(?<=library\\()[A-Za-z0-9.]+", lines, perl = TRUE))
    m2 <- regmatches(lines, regexpr("(?<=require\\()[A-Za-z0-9.]+", lines, perl = TRUE))
    m3 <- regmatches(lines, regexpr('(?<=requireNamespace\\(")[A-Za-z0-9.]+', lines, perl = TRUE))
    m4 <- regmatches(lines, regexpr("[A-Za-z0-9.]+(?=::)", lines, perl = TRUE))
    pkgs <- c(pkgs, unlist(m1), unlist(m2), unlist(m3), unlist(m4))
  }
  base_pkgs <- c("base", "utils", "stats", "grDevices", "graphics", "methods",
                 "datasets", "tools", "parallel", "grid")
  pkgs <- unique(pkgs)
  pkgs <- pkgs[!pkgs %in% base_pkgs]
  pkgs <- pkgs[nchar(pkgs) > 1]
  pkgs <- pkgs[!grepl("\\.[Rr]$", pkgs)]
  pkgs <- pkgs[!grepl("^[A-Z][0-9]", pkgs)]
  pkgs <- pkgs[!grepl("^[A-Z]+$", pkgs) | pkgs %in% c("MASS", "DT", "NCA")]
  noise <- c("empty", "input", "pkg", "self", "result", "config",
             "data", "model", "output", "file", "container", "scroll",
             "divider", "Age", "Gender", "BOXCAT", "TOTAL", "Unknown",
             "QuestionCode")
  pkgs <- pkgs[!pkgs %in% noise]
  sort(pkgs)
}

get_pkg_version <- function(pkg) {
  tryCatch(as.character(packageVersion(pkg)), error = function(e) "not installed")
}

pkg_data <- list()
for (mod in module_names) {
  mod_path <- file.path(turas_root, "modules", mod)
  if (!dir.exists(mod_path)) next
  all_r <- list.files(mod_path, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  pkgs <- extract_packages(all_r)
  if (length(pkgs) > 0) pkg_data[[mod]] <- pkgs
}
root_files <- file.path(turas_root, "launch_turas.R")
root_pkgs <- extract_packages(root_files)
if (length(root_pkgs) > 0) pkg_data[["Root"]] <- root_pkgs

all_pkgs <- unique(unlist(pkg_data))
pkg_versions <- setNames(sapply(all_pkgs, get_pkg_version), all_pkgs)

# Build packages data frame for Excel
pkg_rows_list <- list()
for (mod in names(pkg_data)) {
  for (pkg in pkg_data[[mod]]) {
    pkg_rows_list[[length(pkg_rows_list) + 1]] <- data.frame(
      Module  = mod,
      Package = pkg,
      Version = pkg_versions[pkg],
      stringsAsFactors = FALSE
    )
  }
}
pkg_df <- do.call(rbind, pkg_rows_list)
rownames(pkg_df) <- NULL

# ===========================================================================
# Console output
# ===========================================================================

cat("\n")
cat("==============================================================================\n")
cat("  TURAS ANALYTICS PLATFORM — CODE & TEST INVENTORY\n")
cat(sprintf("  Generated: %s\n", timestamp))
cat("==============================================================================\n\n")

# Column widths
w <- c(18, 9, 11, 9, 10, 12, 8, 7, 11, 10, 5)
headers <- c("Module", "R Scripts", "R Functions", "R LOC", "JS Scripts",
             "JS Functions", "JS LOC", "Tests", "Assertions", "Templates", "Docs")

hdr <- sprintf("%-*s %*s %*s %*s %*s %*s %*s %*s %*s %*s %*s",
               w[1], headers[1], w[2], headers[2], w[3], headers[3],
               w[4], headers[4], w[5], headers[5], w[6], headers[6],
               w[7], headers[7], w[8], headers[8], w[9], headers[9],
               w[10], headers[10], w[11], headers[11])
cat(hdr, "\n")
cat(paste(rep("-", nchar(hdr)), collapse = ""), "\n")

for (i in seq_len(nrow(df_with_totals))) {
  r <- df_with_totals[i, ]
  if (r$Module == "TOTAL") {
    cat(paste(rep("-", nchar(hdr)), collapse = ""), "\n")
  }
  cat(sprintf("%-*s %*s %*s %*s %*s %*s %*s %*s %*s %*s %*s\n",
              w[1], r$Module,
              w[2], format(r$R_Scripts, big.mark = ","),
              w[3], format(r$R_Functions, big.mark = ","),
              w[4], format(r$R_LOC, big.mark = ","),
              w[5], format(r$JS_Scripts, big.mark = ","),
              w[6], format(r$JS_Functions, big.mark = ","),
              w[7], format(r$JS_LOC, big.mark = ","),
              w[8], format(r$Tests, big.mark = ","),
              w[9], format(r$Assertions, big.mark = ","),
              w[10], format(r$Templates, big.mark = ","),
              w[11], format(r$Docs, big.mark = ",")))
}

cat("\n")
cat("  Tests    = test_that() blocks\n")
cat("  Assertions = individual expect_*() checks within tests\n")
cat("\n")

# Packages table to console
cat("==============================================================================\n")
cat("  R PACKAGE DEPENDENCIES BY MODULE\n")
cat("==============================================================================\n\n")

pw <- c(18, 30, 15)
pkg_hdr <- sprintf("%-*s %-*s %*s", pw[1], "Module", pw[2], "Package", pw[3], "Version")
cat(pkg_hdr, "\n")
cat(paste(rep("-", nchar(pkg_hdr)), collapse = ""), "\n")

for (mod in names(pkg_data)) {
  pkgs <- pkg_data[[mod]]
  for (i in seq_along(pkgs)) {
    pkg <- pkgs[i]
    ver <- pkg_versions[pkg]
    label <- if (i == 1) mod else ""
    cat(sprintf("%-*s %-*s %*s\n", pw[1], label, pw[2], pkg, pw[3], ver))
  }
  if (mod != tail(names(pkg_data), 1)) {
    cat(paste(rep("-", nchar(pkg_hdr)), collapse = ""), "\n")
  }
}

cat(paste(rep("-", nchar(pkg_hdr)), collapse = ""), "\n")
cat(sprintf("\nTotal unique packages: %d\n", length(all_pkgs)))

# ===========================================================================
# Excel output
# ===========================================================================

output_dir <- file.path(turas_root, "docs", "System docs")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
output_file <- file.path(output_dir, "Turas_Platform_Inventory.xlsx")

wb <- openxlsx::createWorkbook()

# Styles
sty_header <- openxlsx::createStyle(
  fontName = "Arial", fontSize = 11, textDecoration = "bold",
  fgFill = "#2c3e50", fontColour = "#ffffff", halign = "center",
  border = "bottom", borderStyle = "medium"
)
sty_total <- openxlsx::createStyle(
  fontName = "Arial", fontSize = 11, textDecoration = "bold",
  fgFill = "#ecf0f1", border = "TopBottom", borderStyle = "thin"
)
sty_number <- openxlsx::createStyle(numFmt = "#,##0", halign = "right")
sty_title <- openxlsx::createStyle(
  fontName = "Arial", fontSize = 14, textDecoration = "bold"
)
sty_subtitle <- openxlsx::createStyle(
  fontName = "Arial", fontSize = 10, fontColour = "#7f8c8d"
)

# --- Sheet 1: Code & Test Inventory ---
openxlsx::addWorksheet(wb, "Code & Test Inventory")

# Title
openxlsx::writeData(wb, 1, "TURAS Analytics Platform — Code & Test Inventory", startRow = 1)
openxlsx::addStyle(wb, 1, sty_title, rows = 1, cols = 1)
openxlsx::writeData(wb, 1, paste("Generated:", timestamp), startRow = 2)
openxlsx::addStyle(wb, 1, sty_subtitle, rows = 2, cols = 1)

# Nice column names for Excel
df_excel <- df_with_totals
names(df_excel) <- c("Module", "R Scripts", "R Functions", "R Lines of Code",
                     "JS Scripts", "JS Functions", "JS Lines of Code",
                     "Tests (test_that)", "Assertions (expect_*)",
                     "Config Templates", "Docs & Manuals")

openxlsx::writeData(wb, 1, df_excel, startRow = 4, headerStyle = sty_header)

n_data <- nrow(df_excel)
n_cols <- ncol(df_excel)

# Number formatting for data columns
openxlsx::addStyle(wb, 1, sty_number,
                   rows = 5:(4 + n_data), cols = 2:n_cols,
                   gridExpand = TRUE)

# Total row styling
openxlsx::addStyle(wb, 1, sty_total,
                   rows = 4 + n_data, cols = 1:n_cols,
                   gridExpand = TRUE)

# Column widths
openxlsx::setColWidths(wb, 1, cols = 1, widths = 18)
openxlsx::setColWidths(wb, 1, cols = 2:n_cols, widths = 16)

# Footnote
footnote_row <- 4 + n_data + 2
openxlsx::writeData(wb, 1, "Tests = test_that() blocks. Assertions = individual expect_*() checks within tests.",
                    startRow = footnote_row)
openxlsx::addStyle(wb, 1, sty_subtitle, rows = footnote_row, cols = 1)

# --- Sheet 2: Package Dependencies ---
openxlsx::addWorksheet(wb, "Package Dependencies")

openxlsx::writeData(wb, 2, "R Package Dependencies by Module", startRow = 1)
openxlsx::addStyle(wb, 2, sty_title, rows = 1, cols = 1)
openxlsx::writeData(wb, 2, paste("Generated:", timestamp), startRow = 2)
openxlsx::addStyle(wb, 2, sty_subtitle, rows = 2, cols = 1)

names(pkg_df) <- c("Module", "Package", "Installed Version")
openxlsx::writeData(wb, 2, pkg_df, startRow = 4, headerStyle = sty_header)

openxlsx::setColWidths(wb, 2, cols = 1, widths = 18)
openxlsx::setColWidths(wb, 2, cols = 2, widths = 30)
openxlsx::setColWidths(wb, 2, cols = 3, widths = 18)

# Highlight "not installed" in red
not_installed_rows <- which(pkg_df$`Installed Version` == "not installed") + 4
if (length(not_installed_rows) > 0) {
  sty_warn <- openxlsx::createStyle(fontColour = "#e74c3c", textDecoration = "italic")
  openxlsx::addStyle(wb, 2, sty_warn, rows = not_installed_rows, cols = 3)
}

pkg_footnote_row <- 4 + nrow(pkg_df) + 2
openxlsx::writeData(wb, 2, sprintf("Total unique packages: %d", length(all_pkgs)),
                    startRow = pkg_footnote_row)
openxlsx::addStyle(wb, 2, sty_subtitle, rows = pkg_footnote_row, cols = 1)

# --- Save ---
openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)

cat("\n")
cat(sprintf("  Excel report saved: %s\n", output_file))
cat("\n")
