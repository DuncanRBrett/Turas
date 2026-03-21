# ==============================================================================
# ADD_STATS_PACK_FIELDS_TO_EXAMPLES.R
# ==============================================================================
# Adds Generate_Stats_Pack and STUDY IDENTIFICATION fields to all existing
# example config .xlsx files.
#
# New rows appended to the settings sheet of each file:
#   Generate_Stats_Pack | N | Generate diagnostic stats pack workbook (Y/N)
#   Project_Name        |   | Project name (appears in stats pack Declaration sheet)
#   Analyst_Name        |   | Analyst name (appears in stats pack Declaration sheet)
#   Research_House      |   | Research organisation name (appears in stats pack Declaration sheet)
#
# USAGE:
#   source("tools/add_stats_pack_fields_to_examples.R")
#
# NOTES:
#   - Files where the fields already exist are skipped (no duplicates).
#   - Files that cannot be opened are skipped with a warning.
#   - Only example config files are targeted — output files and data files
#     are excluded from the list.
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
       call. = FALSE)
}
library(openxlsx)

# ------------------------------------------------------------------------------
# Resolve Turas root
# ------------------------------------------------------------------------------

turas_root <- tryCatch(
  normalizePath(file.path(dirname(sys.frame(1)$ofile), ".."), mustWork = TRUE),
  error = function(e) {
    # Fallback: assume the working directory is Turas root
    normalizePath(".", mustWork = TRUE)
  }
)

cat(sprintf("Turas root: %s\n\n", turas_root))

# ------------------------------------------------------------------------------
# List of example config .xlsx files to update
# Each entry: list(path = ..., settings_sheet = ...)
# ------------------------------------------------------------------------------

example_configs <- list(
  # --- Tabs ---
  list(
    path = file.path(turas_root, "examples", "tabs", "basic", "tabs_config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "tabs", "demo_survey", "Demo_Crosstab_Config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "tabs", "demo_survey", "Demo_Crosstab_Config_Template.xlsx"),
    settings_sheet = "Settings"
  ),

  # --- Tracker ---
  list(
    path = file.path(turas_root, "examples", "tracker", "basic", "tracker_config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "tracker", "full_test", "tracking_config.xlsx"),
    settings_sheet = "Settings"
  ),

  # --- Confidence ---
  list(
    path = file.path(turas_root, "examples", "confidence", "basic", "confidence_config.xlsx"),
    settings_sheet = "Settings"
  ),

  # --- Conjoint ---
  list(
    path = file.path(turas_root, "examples", "conjoint", "basic", "conjoint_config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "conjoint", "v3_demo", "demo_config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "conjoint", "Conjoint_Config_Template.xlsx"),
    settings_sheet = "Settings"
  ),

  # --- Pricing ---
  list(
    path = file.path(turas_root, "examples", "pricing", "basic", "pricing_config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "pricing", "demo_showcase", "Demo_Pricing_Config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "pricing", "demo_showcase", "Demo_Monadic_Config.xlsx"),
    settings_sheet = "Settings"
  ),

  # --- Key Driver ---
  list(
    path = file.path(turas_root, "examples", "keydriver", "demo_showcase", "Demo_KeyDriver_Config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "test_data", "keydriver_test_config.xlsx"),
    settings_sheet = "Settings"
  ),

  # --- MaxDiff (uses PROJECT_SETTINGS sheet) ---
  list(
    path = file.path(turas_root, "examples", "maxdiff", "demo_showcase", "Demo_MaxDiff_Config.xlsx"),
    settings_sheet = "PROJECT_SETTINGS"
  ),

  # --- Segment ---
  list(
    path = file.path(turas_root, "examples", "segment", "demo_showcase", "demo_config.xlsx"),
    settings_sheet = "Config"
  ),
  list(
    path = file.path(turas_root, "examples", "segment", "demo_showcase", "demo_combined_config.xlsx"),
    settings_sheet = "Config"
  ),
  list(
    path = file.path(turas_root, "examples", "segment", "demo_showcase", "demo_kmeans_explore.xlsx"),
    settings_sheet = "Config"
  ),
  list(
    path = file.path(turas_root, "examples", "segment", "demo_showcase", "demo_kmeans_final.xlsx"),
    settings_sheet = "Config"
  ),
  list(
    path = file.path(turas_root, "examples", "segment", "demo_showcase", "demo_hclust_final.xlsx"),
    settings_sheet = "Config"
  ),
  list(
    path = file.path(turas_root, "examples", "segment", "demo_showcase", "demo_gmm_final.xlsx"),
    settings_sheet = "Config"
  ),

  # --- Report Hub ---
  list(
    path = file.path(turas_root, "examples", "report_hub", "Demo_Combined_Config.xlsx"),
    settings_sheet = "Settings"
  ),
  list(
    path = file.path(turas_root, "examples", "report_hub", "SACAP_Combined_Config.xlsx"),
    settings_sheet = "Settings"
  )
)

# ------------------------------------------------------------------------------
# New rows to append
# The description column text is stored but only written if the sheet has
# a description/notes column (3+ columns). Otherwise only cols 1-2 are written.
# ------------------------------------------------------------------------------

new_rows <- list(
  list(
    field  = "Generate_Stats_Pack",
    value  = "N",
    description = "Generate diagnostic stats pack workbook (Y/N)"
  ),
  list(
    field  = "Project_Name",
    value  = "",
    description = "Project name (appears in stats pack Declaration sheet)"
  ),
  list(
    field  = "Analyst_Name",
    value  = "",
    description = "Analyst name (appears in stats pack Declaration sheet)"
  ),
  list(
    field  = "Research_House",
    value  = "",
    description = "Research organisation name (appears in stats pack Declaration sheet)"
  )
)

new_field_names <- vapply(new_rows, `[[`, character(1), "field")

# ------------------------------------------------------------------------------
# Helper: detect which column in a data frame holds field/parameter names
# Returns the column index (integer), or NA if not determinable.
# ------------------------------------------------------------------------------

detect_field_col <- function(df) {
  # Check standard first-column names
  known <- c("Setting", "SettingName", "Setting_Name", "Parameter",
             "Field", "Name", "Key")
  col1_name <- names(df)[1]
  if (col1_name %in% known || grepl("setting|param|field|name|key",
                                    col1_name, ignore.case = TRUE)) {
    return(1L)
  }
  # Fallback: assume column 1 holds field names
  return(1L)
}

# ------------------------------------------------------------------------------
# Process each file
# ------------------------------------------------------------------------------

n_updated   <- 0L
n_skipped   <- 0L
n_not_found <- 0L
n_errors    <- 0L
skipped_files  <- character(0)
updated_files  <- character(0)

for (cfg in example_configs) {
  path   <- cfg$path
  sheet  <- cfg$settings_sheet
  label  <- sub(paste0(normalizePath(turas_root, mustWork = FALSE), .Platform$file.sep), "",
                path, fixed = TRUE)

  # --- File must exist ---
  if (!file.exists(path)) {
    cat(sprintf("  [NOT FOUND]  %s\n", label))
    n_not_found <- n_not_found + 1L
    next
  }

  # --- Try to read settings sheet ---
  df <- tryCatch(
    read.xlsx(path, sheet = sheet, colNames = TRUE),
    error = function(e) {
      cat(sprintf("  [ERROR]      %s  —  cannot read sheet '%s': %s\n",
                  label, sheet, conditionMessage(e)))
      NULL
    }
  )
  if (is.null(df)) {
    n_errors <- n_errors + 1L
    next
  }

  if (nrow(df) == 0 || ncol(df) == 0) {
    cat(sprintf("  [SKIP]       %s  —  sheet '%s' is empty\n", label, sheet))
    n_skipped <- n_skipped + 1L
    skipped_files <- c(skipped_files, label)
    next
  }

  # --- Detect field name column ---
  field_col <- detect_field_col(df)
  existing_fields <- as.character(df[[field_col]])

  # --- Determine which new rows are missing ---
  missing_rows <- Filter(function(r) !r$field %in% existing_fields, new_rows)

  if (length(missing_rows) == 0L) {
    cat(sprintf("  [SKIP]       %s  —  all fields already present\n", label))
    n_skipped <- n_skipped + 1L
    skipped_files <- c(skipped_files, label)
    next
  }

  # --- Build new rows as data frame matching sheet columns ---
  n_cols <- ncol(df)
  col_names <- names(df)

  new_df_rows <- lapply(missing_rows, function(r) {
    row <- as.list(rep("", n_cols))
    names(row) <- col_names
    row[[field_col]] <- r$field
    # Write value to column 2 if it exists
    if (n_cols >= 2L) row[[2L]] <- r$value
    # Write description to column 3 or 4 if a description-like column exists
    if (n_cols >= 3L) {
      desc_col <- which(grepl("desc|note|help|valid|comment",
                              col_names, ignore.case = TRUE))
      if (length(desc_col) > 0L) {
        row[[desc_col[1]]] <- r$description
      } else {
        row[[3L]] <- r$description
      }
    }
    as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
  })

  new_df <- do.call(rbind, new_df_rows)

  # --- Append and write back ---
  result <- tryCatch({
    wb <- loadWorkbook(path)
    # Determine next empty row (after existing data, accounting for header)
    # read.xlsx returns data starting after header, so next row = nrow(df) + 2
    next_row <- nrow(df) + 2L  # +1 for header row, +1 for first new row

    for (i in seq_len(nrow(new_df))) {
      for (j in seq_len(n_cols)) {
        val <- new_df[i, j]
        if (!is.na(val) && nchar(as.character(val)) > 0L) {
          writeData(wb, sheet = sheet, x = as.character(val),
                    startRow = next_row + i - 1L, startCol = j,
                    colNames = FALSE)
        }
      }
    }

    saveWorkbook(wb, path, overwrite = TRUE)
    TRUE
  }, error = function(e) {
    cat(sprintf("  [ERROR]      %s  —  write failed: %s\n",
                label, conditionMessage(e)))
    FALSE
  })

  if (isTRUE(result)) {
    added_names <- vapply(missing_rows, `[[`, character(1), "field")
    cat(sprintf("  [UPDATED]    %s  —  added: %s\n",
                label, paste(added_names, collapse = ", ")))
    n_updated <- n_updated + 1L
    updated_files <- c(updated_files, label)
  } else {
    n_errors <- n_errors + 1L
  }
}

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

cat("\n")
cat("========================================\n")
cat("  Stats Pack Fields — Update Summary\n")
cat("========================================\n")
cat(sprintf("  Updated:   %d file(s)\n", n_updated))
cat(sprintf("  Skipped:   %d file(s) (fields already present or empty)\n", n_skipped))
cat(sprintf("  Not found: %d file(s)\n", n_not_found))
cat(sprintf("  Errors:    %d file(s)\n", n_errors))

if (length(updated_files) > 0L) {
  cat("\n  Updated files:\n")
  for (f in updated_files) cat(sprintf("    - %s\n", f))
}

if (length(skipped_files) > 0L) {
  cat("\n  Skipped files:\n")
  for (f in skipped_files) cat(sprintf("    - %s\n", f))
}

cat("========================================\n\n")

invisible(list(
  updated   = updated_files,
  skipped   = skipped_files,
  n_errors  = n_errors,
  n_not_found = n_not_found
))
