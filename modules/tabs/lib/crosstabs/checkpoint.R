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

#' Save Analysis Checkpoint
#'
#' Saves current analysis progress to disk so processing can be resumed
#' if interrupted.
#'
#' @param checkpoint_file Character, path to checkpoint file
#' @param all_results List, results processed so far
#' @param processed_questions Character vector, question codes processed
#' @return Invisible NULL
#' @export
save_checkpoint <- function(checkpoint_file, all_results, processed_questions) {
  # Ensure checkpoint directory exists
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) {
    dir.create(checkpoint_dir, recursive = TRUE)
  }

  checkpoint_data <- list(
    results = all_results,
    processed = processed_questions,
    timestamp = Sys.time()
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
#' @return List with results and processed questions, or NULL
#' @export
load_checkpoint <- function(checkpoint_file) {
  # Check if directory exists first (important for OneDrive paths)
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) return(NULL)

  # Check if file exists
  if (!file.exists(checkpoint_file)) return(NULL)

  tryCatch({
    checkpoint_data <- readRDS(checkpoint_file)
    log_message(sprintf("Checkpoint loaded: %d questions already processed",
                        length(checkpoint_data$processed)), "INFO")
    return(checkpoint_data)
  }, error = function(e) {
    # TRS v1.0: Make checkpoint load failure visible
    message(sprintf("[TRS INFO] Checkpoint file exists but could not be loaded: %s\n  Starting fresh instead.", conditionMessage(e)))
    return(NULL)
  })
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
#' @return List with all_results, processed_questions, and remaining_questions
#' @export
setup_checkpointing <- function(enable_checkpointing, checkpoint_file, crosstab_questions) {
  if (enable_checkpointing) {
    checkpoint_data <- load_checkpoint(checkpoint_file)

    if (!is.null(checkpoint_data)) {
      all_results <- checkpoint_data$results
      processed_questions <- checkpoint_data$processed
      remaining_questions <- crosstab_questions[
        !crosstab_questions$QuestionCode %in% processed_questions,
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
