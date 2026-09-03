# ==============================================================================
# CHECKPOINT.R - TURAS V10.2 (Phase 4 Refactoring)
# ==============================================================================
# Extracted from run_crosstabs.R for better modularity
#
# PURPOSE: Checkpoint system for resuming interrupted analysis runs
#
# FUNCTIONS:
#   - save_checkpoint() - Save analysis progress to disk
#   - load_checkpoint() - Load saved progress from disk
#   - setup_checkpointing() - Initialize checkpoint state
#   - cleanup_checkpoint() - Remove checkpoint file after successful completion
#
# DEPENDENCIES:
#   - logging_utils.R (for log_message)
#
# ==============================================================================

#' Build a Checkpoint Fingerprint
#'
#' Describes the inputs a checkpoint's results were computed from, so a resume
#' can prove it is continuing the SAME run rather than grafting one run's
#' numbers into another's workbook.
#'
#' Why this exists (review 2026-08-21, finding C-1): checkpoints used to carry
#' only results + a timestamp, and the file name is a constant per output
#' folder. Two ways that shipped wrong numbers silently, (a) a run dies, the
#' operator edits the config or re-exports the data, re-runs, and the resume
#' seeds results computed under the OLD inputs while skipping those questions;
#' (b) two configs sharing one output folder (the GUI batches configs from a
#' folder) share one checkpoint file, so config B resumes config A's results.
#' Neither leaves a trace in the workbook. Every field below is something that,
#' if changed, invalidates already-computed tables.
#'
#' @param config_file Character, path to the config workbook
#' @param structure_file Character, path to the survey structure workbook
#' @param data_file Character, path to the survey data file (NA if unknown)
#' @param question_codes Character vector, the codes selected for this run
#' @param banner_labels Character vector, the banner column labels
#' @param config_obj List, the built config object (weighting/significance keys
#'   that change every published number are fingerprinted)
#' @return List describing the run's inputs
#' @export
build_checkpoint_fingerprint <- function(config_file, structure_file, data_file,
                                         question_codes, banner_labels, config_obj) {
  # mtime + size, not a content hash: hashing a 50MB survey export on every
  # checkpoint write would cost more than recomputing the questions it protects.
  file_stamp <- function(path) {
    if (is.null(path) || length(path) != 1 || is.na(path) || !nzchar(path)) return("none")
    if (!file.exists(path)) return("missing")
    info <- file.info(path)
    paste0(basename(path), "|", as.numeric(info$mtime), "|", info$size)
  }

  cfg_val <- function(key) {
    v <- config_obj[[key]]
    if (is.null(v) || length(v) != 1) "unset" else as.character(v)
  }

  list(
    version = 1L,
    config = file_stamp(config_file),
    structure = file_stamp(structure_file),
    data = file_stamp(data_file),
    # Sorted: a reordered Selection sheet does not invalidate computed tables,
    # but an added/removed/renamed question does.
    questions = paste(sort(as.character(question_codes)), collapse = ""),
    banner = paste(as.character(banner_labels), collapse = ""),
    settings = paste(vapply(
      c("apply_weighting", "weight_variable", "enable_significance_testing",
        "alpha", "alpha_secondary", "use_bonferroni", "min_reporting_base"),
      cfg_val, character(1)
    ), collapse = "")
  )
}


#' Describe How Two Fingerprints Differ
#'
#' @param saved List, the fingerprint stored in the checkpoint
#' @param current List, the fingerprint of the run now starting
#' @return Character vector of human-readable differences (empty if identical)
#' @export
checkpoint_fingerprint_diff <- function(saved, current) {
  if (is.null(saved)) return("the checkpoint predates run fingerprinting")
  labels <- c(config = "the config file", structure = "the survey structure file",
              data = "the survey data file", questions = "the selected questions",
              banner = "the banner definition", settings = "weighting/significance settings")
  diffs <- character(0)
  for (key in names(labels)) {
    if (!identical(saved[[key]], current[[key]])) diffs <- c(diffs, labels[[key]])
  }
  diffs
}


#' Save Analysis Checkpoint
#'
#' Saves current analysis progress to disk so processing can be resumed
#' if interrupted.
#'
#' @param checkpoint_file Character, path to checkpoint file
#' @param all_results List, results processed so far
#' @param processed_questions Character vector, question codes processed
#' @param fingerprint List, run fingerprint from build_checkpoint_fingerprint();
#'   NULL writes a checkpoint that a later resume will refuse to trust.
#' @return Invisible NULL
#' @export
save_checkpoint <- function(checkpoint_file, all_results, processed_questions,
                            fingerprint = NULL) {
  # Ensure checkpoint directory exists
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) {
    dir.create(checkpoint_dir, recursive = TRUE)
  }

  checkpoint_data <- list(
    results = all_results,
    processed = processed_questions,
    timestamp = Sys.time(),
    fingerprint = fingerprint
  )
  saveRDS(checkpoint_data, checkpoint_file)

  invisible(NULL)
}


#' Load Analysis Checkpoint
#'
#' Loads saved analysis progress from disk. Returns NULL if no checkpoint
#' exists or if the checkpoint file is corrupted.
#'
#' @param checkpoint_file Character, path to checkpoint file
#' @param fingerprint List, the current run's fingerprint. When supplied, a
#'   checkpoint whose fingerprint differs is DISCARDED (with a console box
#'   naming what changed) rather than resumed. See build_checkpoint_fingerprint().
#' @return List with results and processed questions, or NULL
#' @export
load_checkpoint <- function(checkpoint_file, fingerprint = NULL) {
  # Check if directory exists first (important for OneDrive paths)
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) return(NULL)

  # Check if file exists
  if (!file.exists(checkpoint_file)) return(NULL)

  checkpoint_data <- tryCatch({
    readRDS(checkpoint_file)
  }, error = function(e) {
    # TRS v1.0: Make checkpoint load failure visible
    message(sprintf("[TRS INFO] Checkpoint file exists but could not be loaded: %s\n  Starting fresh instead.", conditionMessage(e)))
    NULL
  })
  if (is.null(checkpoint_data)) return(NULL)

  # A checkpoint is only resumable into the run that created it. Anything else
  # would mix two vintages of numbers into one workbook with no visible trace.
  if (!is.null(fingerprint)) {
    diffs <- checkpoint_fingerprint_diff(checkpoint_data$fingerprint, fingerprint)
    if (length(diffs) > 0) {
      cat("\n┌─── TURAS CHECKPOINT DISCARDED ─────────────────────────────┐\n")
      cat("│ A checkpoint exists in this output folder, but it was built\n")
      cat("│ from different inputs, so resuming it would mix results from\n")
      cat("│ two different runs into one workbook.\n")
      cat("│ Changed since that checkpoint:", paste(diffs, collapse = ", "), "\n")
      cat("│ Action: starting fresh. Nothing is wrong. This is the guard\n")
      cat("│ working. All questions will be recomputed.\n")
      cat("└────────────────────────────────────────────────────────────┘\n\n")
      return(NULL)
    }
  }

  log_message(sprintf("Checkpoint loaded: %d questions already processed",
                      length(checkpoint_data$processed)), "INFO")
  checkpoint_data
}


#' Setup Checkpointing State
#'
#' Initializes the checkpoint state for an analysis run. If checkpointing
#' is enabled and a valid checkpoint exists, returns the saved state.
#' Otherwise returns empty initial state.
#'
#' @param enable_checkpointing Logical, whether checkpointing is enabled
#' @param checkpoint_file Character, path to checkpoint file
#' @param crosstab_questions Data frame, all questions to process
#' @param fingerprint List, the current run's fingerprint (see load_checkpoint())
#' @return List with all_results, processed_questions, and remaining_questions
#' @export
setup_checkpointing <- function(enable_checkpointing, checkpoint_file, crosstab_questions,
                                fingerprint = NULL) {
  if (enable_checkpointing) {
    checkpoint_data <- load_checkpoint(checkpoint_file, fingerprint)

    if (!is.null(checkpoint_data)) {
      all_results <- checkpoint_data$results
      processed_questions <- checkpoint_data$processed
      # drop = FALSE: a single-column selection frame would otherwise degrade to
      # a vector here, and every downstream nrow()/$QuestionCode would fail.
      remaining_questions <- crosstab_questions[
        !crosstab_questions$QuestionCode %in% processed_questions, , drop = FALSE
      ]

      log_message(sprintf("Resuming: %d questions remaining",
                          nrow(remaining_questions)), "INFO")

      return(list(
        all_results = all_results,
        processed_questions = processed_questions,
        remaining_questions = remaining_questions,
        resumed = TRUE
      ))
    }
  }

  # No checkpoint or checkpointing disabled - start fresh
  list(
    all_results = list(),
    processed_questions = character(0),
    remaining_questions = crosstab_questions,
    resumed = FALSE
  )
}


#' Cleanup Checkpoint File
#'
#' Removes the checkpoint file after successful analysis completion.
#'
#' @param checkpoint_file Character, path to checkpoint file
#' @return Invisible logical, TRUE if file was removed
#' @export
cleanup_checkpoint <- function(checkpoint_file) {
  if (file.exists(checkpoint_file)) {
    result <- file.remove(checkpoint_file)
    return(invisible(result))
  }
  invisible(FALSE)
}


#' Get Checkpoint File Path
#'
#' Constructs the standard checkpoint file path for a project.
#'
#' @param project_root Character, project root directory
#' @param output_subfolder Character, output subfolder name
#' @return Character, checkpoint file path
#' @export
get_checkpoint_path <- function(project_root, output_subfolder) {
  file.path(project_root, output_subfolder, ".crosstabs_checkpoint.rds")
}
