# ==============================================================================
# TURAS SHARED UTILITIES - UNIFIED IMPORT
# ==============================================================================
# Single entry point for loading all shared utilities
#
# USAGE:
#   source(file.path(find_turas_root(), "modules/shared/lib/import_all.R"))
#
# Or if turas root not yet known:
#   shared_path <- dirname(sys.frame(1)$ofile)  # Get this file's directory
#   source(file.path(shared_path, "import_all.R"))
#
# LOADS 19 utilities in dependency order:
#   1.  trs_refusal.R          (TRS v1.0 - must be first - no dependencies)
#   2.  source_utils.R         (source_if_exists - no dependencies)
#   3.  console_capture.R      (TRS v1.0 - Shiny GUI capture)
#   4.  validation_utils.R     (no dependencies)
#   5.  data_utils.R           (depends on validation)
#   6.  config_utils.R         (depends on validation, data)
#   7.  logging_utils.R        (no dependencies)
#   8.  formatting_utils.R     (no dependencies)
#   9.  weights_utils.R        (no dependencies)
#   10. turas_log.R            (TRS v1.0 - unified logging)
#   11. trs_run_state.R        (TRS v1.0 - run state management)
#   12. trs_run_status_writer.R (TRS v1.0 - run status Excel writer)
#   13. trs_banner.R           (TRS v1.0 - banner display)
#   14. turas_save_workbook_atomic.R (TRS v1.0 - atomic workbook save)
#   15. turas_excel_escape.R   (TRS v1.0 - formula-injection protection)
#   16. turas_minify_verify.R  (minification verification)
#   17. turas_minify_watermark.R (watermark encode/decode)
#   17b. turas_release_audit.R (what the finished file contains)
#   18. turas_minify.R         (report minification pipeline)
#   19. stats_pack_writer.R    (diagnostic stats pack workbook)
# ==============================================================================

# Determine this file's directory for relative sourcing
# Where this file is. sys.frame(1) is the OUTERMOST frame, not the frame doing
# the sourcing, so it holds this file's ofile only when import_all.R is sourced
# from the top of a script. Sourced from inside a function, which is what a
# Shiny GUI does, it is NULL or another file's path, and the working-directory
# fallbacks below are then the only thing left. When the working directory is
# not the project root they all miss, this file fails, and the caller carries
# on without the shared library until something dies with "could not find
# function". Walking the frames outward-in finds it wherever it was sourced
# from.
.shared_lib_self <- local({
  found <- NULL
  if (sys.nframe() > 0) {
    for (i in rev(seq_len(sys.nframe()))) {
      of <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
      if (is.character(of) && length(of) == 1 && grepl("import_all[.]R$", of)) {
        found <- dirname(normalizePath(of, mustWork = FALSE))
        break
      }
      # This tested is.list(sf), and a frame's srcfile is never a list: it
      # arrives either as the character path source() was given, or as a
      # srcfile object carrying $filename. So the branch never fired and the
      # ofile test above was doing all the work (review F23). Both shapes are
      # handled now, which matters for the sourcing paths where ofile is
      # absent.
      sf <- tryCatch(sys.frame(i)$srcfile, error = function(e) NULL)
      sf_name <- if (is.character(sf) && length(sf) == 1) {
        sf
      } else if (!is.null(sf)) {
        nm <- tryCatch(sf$filename, error = function(e) NULL)
        if (is.character(nm) && length(nm) == 1) nm else NULL
      } else {
        NULL
      }
      if (!is.null(sf_name) && grepl("import_all[.]R$", sf_name)) {
        found <- dirname(normalizePath(sf_name, mustWork = FALSE))
        break
      }
    }
  }
  found
})

.shared_lib_path <- if (!is.null(.shared_lib_self) && dir.exists(.shared_lib_self)) {
  .shared_lib_self
} else if (sys.nframe() > 0 && !is.null(sys.frame(1)$ofile)) {
  dirname(sys.frame(1)$ofile)
} else {
  # Fallback: try to find from working directory
  test_paths <- c(
    file.path(getwd(), "modules/shared/lib"),
    file.path(dirname(getwd()), "shared/lib"),
    file.path(dirname(dirname(getwd())), "modules/shared/lib")
  )
  found <- test_paths[dir.exists(test_paths)]
  if (length(found) > 0) {
    found[1]
  } else {
    # Cannot use turas_refuse here as trs_refusal.R hasn't been loaded yet
    # Provide TRS-style error message manually
    stop(paste0(
      "\n", paste0(rep("=", 80), collapse = ""), "\n",
      "  [REFUSE] IO_SHARED_LIB_NOT_FOUND: Cannot Locate Shared Library Directory\n",
      paste0(rep("=", 80), collapse = ""), "\n\n",
      "Problem:\n",
      "  Cannot locate the modules/shared/lib directory from the current location.\n\n",
      "Why it matters:\n",
      "  Turas shared utilities must be found to load required functions.\n\n",
      "How to fix:\n",
      "  1. Ensure you are running from within the Turas directory structure\n",
      "  2. Check that modules/shared/lib/ exists in your Turas installation\n",
      "  3. Verify your working directory is set correctly\n",
      "  4. Current working directory: ", getwd(), "\n",
      "  5. Searched in:\n",
      paste0("     - ", test_paths, collapse = "\n"), "\n\n",
      paste0(rep("=", 80), collapse = ""), "\n"
    ), call. = FALSE)
  }
}

# Source in dependency order
# 1. TRS Refusal infrastructure (TRS v1.0 - no dependencies, needed by all modules)
source(file.path(.shared_lib_path, "trs_refusal.R"), local = FALSE)

# 2. Source utilities (source_if_exists - no dependencies, used by all modules)
source(file.path(.shared_lib_path, "source_utils.R"), local = FALSE)

# 3. Console capture for Shiny GUIs (TRS v1.0 - ensures no silent failures in GUI)
source(file.path(.shared_lib_path, "console_capture.R"), local = FALSE)

# 4. Validation (no dependencies)
source(file.path(.shared_lib_path, "validation_utils.R"), local = FALSE)

# 5. Data utils (uses validation)
source(file.path(.shared_lib_path, "data_utils.R"), local = FALSE)

# 6. Config utils (uses validation, includes find_turas_root)
source(file.path(.shared_lib_path, "config_utils.R"), local = FALSE)

# 7. Logging (independent)
source(file.path(.shared_lib_path, "logging_utils.R"), local = FALSE)

# 8. Formatting (independent)
source(file.path(.shared_lib_path, "formatting_utils.R"), local = FALSE)

# 9. Weights (independent)
source(file.path(.shared_lib_path, "weights_utils.R"), local = FALSE)

# 10. TRS Unified Logging (TRS v1.0)
source(file.path(.shared_lib_path, "turas_log.R"), local = FALSE)

# 11. TRS Run State Management (TRS v1.0)
source(file.path(.shared_lib_path, "trs_run_state.R"), local = FALSE)

# 12. TRS Run Status Excel Writer (TRS v1.0)
source(file.path(.shared_lib_path, "trs_run_status_writer.R"), local = FALSE)

# 13. TRS Banner (TRS v1.0)
source(file.path(.shared_lib_path, "trs_banner.R"), local = FALSE)

# 14. TRS Atomic Workbook Save (TRS v1.0)
source(file.path(.shared_lib_path, "turas_save_workbook_atomic.R"), local = FALSE)

# 15. TRS Excel Formula-Injection Protection (TRS v1.0)
source(file.path(.shared_lib_path, "turas_excel_escape.R"), local = FALSE)

# 16. Minification verification helpers (independent)
source(file.path(.shared_lib_path, "turas_minify_verify.R"), local = FALSE)

# 17. Watermark encode/decode helpers (independent)
source(file.path(.shared_lib_path, "turas_minify_watermark.R"), local = FALSE)

# 17b. Release audit: what is in the finished file (depends on trs_refusal)
source(file.path(.shared_lib_path, "turas_release_audit.R"), local = FALSE)

# 18. Report minification pipeline (depends on trs_refusal, watermark, verify,
#     release audit)
source(file.path(.shared_lib_path, "turas_minify.R"), local = FALSE)

# 19. Stats pack writer (depends on turas_save_workbook_atomic, turas_excel_escape)
# Loaded here so that any caller which has already sourced the shared infrastructure
# still has turas_write_stats_pack available. Modules that source it themselves are
# unaffected — sourcing twice is harmless.
source(file.path(.shared_lib_path, "stats_pack_writer.R"), local = FALSE)

# Clean up
rm(.shared_lib_path)
