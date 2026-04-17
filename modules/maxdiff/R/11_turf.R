# ==============================================================================
# MAXDIFF MODULE - TURF ANALYSIS (WRAPPER)
# ==============================================================================
# MaxDiff-specific wrapper around the shared TURF engine.
# The core TURF logic lives in modules/shared/lib/turf_engine.R for reuse
# across maxdiff (portfolio TURF), brand (CEP TURF), and portfolio
# (category TURF) modules.
#
# VERSION HISTORY:
# Turas v11.0 - Initial release (2026-03)
# Turas v11.2 - Extracted core to shared/lib/turf_engine.R (2026-04)
#
# This file provides backward-compatible wrappers that delegate to the
# shared engine while preserving the maxdiff-specific refusal handling.
#
# DEPENDENCIES:
# - modules/shared/lib/turf_engine.R (shared TURF engine)
# ==============================================================================

TURF_VERSION <- "11.2"

# --- Source shared TURF engine ---
.source_turf_engine <- function() {
  # Already loaded?
  if (exists("TURF_ENGINE_VERSION", envir = globalenv(), inherits = FALSE)) {
    return(invisible(NULL))
  }

  # Try multiple paths to find the shared engine
  candidates <- character(0)

  # Path 1: via script_dir_override (set during testing)
  if (exists("script_dir_override", envir = globalenv())) {
    sdir <- get("script_dir_override", envir = globalenv())
    candidates <- c(candidates, file.path(dirname(sdir), "..", "shared", "lib", "turf_engine.R"))
  }

  # Path 2: via find_turas_root() if available
  if (exists("find_turas_root", mode = "function")) {
    candidates <- c(candidates,
      file.path(find_turas_root(), "modules", "shared", "lib", "turf_engine.R"))
  }

  # Path 3: relative to this file (when sourced normally)
  if (exists("sys.frame") && !is.null(tryCatch(sys.frame(1)$ofile, error = function(e) NULL))) {
    this_dir <- dirname(sys.frame(1)$ofile)
    candidates <- c(candidates,
      file.path(this_dir, "..", "..", "shared", "lib", "turf_engine.R"))
  }

  # Path 4: from working directory (launched from Turas root)
  candidates <- c(candidates, "modules/shared/lib/turf_engine.R")

  # Path 5: working directory sits inside modules/maxdiff (GUI launcher
  # does setwd(MODULE_DIR) before sourcing R/00_main.R, per
  # run_maxdiff_gui.R — this is the common case and must work).
  candidates <- c(candidates,
    file.path("..", "shared", "lib", "turf_engine.R"),
    file.path(getwd(), "..", "shared", "lib", "turf_engine.R"))

  for (path in candidates) {
    path <- normalizePath(path, mustWork = FALSE)
    if (file.exists(path)) {
      source(path, local = FALSE)
      return(invisible(NULL))
    }
  }

  warning("Could not find shared TURF engine (turf_engine.R). Using maxdiff-local fallback.")
}

.source_turf_engine()


# ==============================================================================
# BACKWARD-COMPATIBLE MAXDIFF WRAPPERS
# ==============================================================================
# The shared engine uses 'individual_scores' as the parameter name.
# MaxDiff callers use 'individual_utils'. These wrappers maintain the
# existing maxdiff API so no caller code needs to change.

if (!exists("classify_appeal", mode = "function")) {
  # Shared TURF engine failed to load — every path candidate in
  # .source_turf_engine() missed. Refuse loudly with a TRS-compliant
  # message instead of stop(), so the user sees what's actually wrong
  # rather than a cryptic "could not find function maxdiff_refuse"
  # when downstream code tries to call the refusal handler.
  if (exists("maxdiff_refuse", mode = "function")) {
    maxdiff_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "Shared TURF Engine Not Loaded",
      problem = "modules/shared/lib/turf_engine.R could not be sourced from any of the fallback paths in .source_turf_engine().",
      why_it_matters = paste(
        "MaxDiff's TURF analysis delegates to the shared engine.",
        "Without it, run_turf_analysis() cannot compute anything."),
      how_to_fix = c(
        "Verify modules/shared/lib/turf_engine.R exists.",
        "If you launched from a non-standard directory, set script_dir_override = 'path/to/maxdiff/R' in globalenv() before sourcing 00_main.R.",
        "If running via the GUI, launch from the Turas root and use run_maxdiff_gui()."
      )
    )
  } else {
    stop("TURF engine not loaded. Check that modules/shared/lib/turf_engine.R exists.")
  }
}

# Override run_turf_analysis to add maxdiff-specific refusal handling
.shared_run_turf <- run_turf_analysis

#' @rdname run_turf_analysis
#' @description MaxDiff wrapper around shared TURF engine. Adds maxdiff-specific
#'   TRS refusal handling for missing individual utilities.
run_turf_analysis <- function(individual_utils, items,
                              max_items = 10,
                              threshold_method = "ABOVE_MEAN",
                              threshold_k = 3,
                              weights = NULL,
                              verbose = TRUE) {

  # MaxDiff-specific refusal for missing utilities
  if (is.null(individual_utils) || nrow(individual_utils) == 0) {
    if (exists("maxdiff_refuse", mode = "function")) {
      maxdiff_refuse(
        code = "DATA_TURF_NO_UTILS",
        title = "No Individual Utilities for TURF",
        problem = "Individual-level utilities are required for TURF analysis",
        why_it_matters = "TURF needs respondent-level data to compute reach",
        how_to_fix = "Enable HB estimation (Generate_HB_Model = YES) to produce individual utilities"
      )
    }
    return(list(status = "REFUSED", message = "No individual utilities available"))
  }

  # Delegate to shared engine
  .shared_run_turf(
    individual_scores = individual_utils,
    items = items,
    max_items = max_items,
    threshold_method = threshold_method,
    threshold_k = threshold_k,
    weights = weights,
    verbose = verbose,
    id_col = "Item_ID",
    label_col = "Item_Label"
  )
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff TURF wrapper loaded (v%s, engine v%s)",
                TURF_VERSION,
                if (exists("TURF_ENGINE_VERSION")) TURF_ENGINE_VERSION else "?"))
