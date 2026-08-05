# ==============================================================================
# TABS — AI INSIGHTS STEP (sidecar refresh)
# ==============================================================================
# Refreshes the AI insights sidecar (<config>_ai_insights.json) that the v2
# report's data layer reads (build_dl_ai in data_layer_writer.R): the per-question
# callouts the model flagged as noteworthy, plus the executive summary.
#
# This ran inside the classic HTML report's orchestrator until that report was
# retired (2026-08). It is a pipeline step in its own right — the insights are
# read by the interactive report, not by any HTML the classic writer produced —
# so it now runs from run_crosstabs.R, gated only on enable_ai_insights.
#
# The AI modules are sourced lazily (here, not at load) so a run with AI off
# never pays for them and never fails on a missing provider file.
# ==============================================================================


#' Generate or refresh the AI insights sidecar
#'
#' Does nothing unless \code{enable_ai_insights} is TRUE and the config's own
#' path is known (the sidecar name is derived from it). Creates a default
#' sidecar on first use, then asks the configured model for insights. Every
#' failure degrades to a console warning — AI is additive, and neither the
#' Excel workbook nor the interactive report depends on it.
#'
#' @param all_results List of question results
#' @param banner_info Banner structure
#' @param config_obj Configuration object (needs enable_ai_insights,
#'   config_file_path and, optionally, ai_model)
#'
#' @return The insights list from \code{generate_all_insights()}, or NULL when
#'   AI is off, the sidecar path cannot be derived, or generation failed. The
#'   sidecar file on disk is the actual product — the v2 data layer reads it.
#'
#' @examples
#' \dontrun{
#'   generate_ai_insights_sidecar(all_results, banner_info, config_obj)
#' }
#'
#' @export
generate_ai_insights_sidecar <- function(all_results, banner_info, config_obj) {

  if (!isTRUE(config_obj$enable_ai_insights)) {
    cat("  AI insights: disabled (enable_ai_insights = FALSE)\n")
    return(NULL)
  }

  cat("  AI insights: processing...\n")

  # Derive sidecar path from config file
  ai_sidecar_path <- NULL
  if (!is.null(config_obj$config_file_path) && nzchar(config_obj$config_file_path %||% "")) {
    ai_sidecar_path <- paste0(tools::file_path_sans_ext(config_obj$config_file_path),
                              "_ai_insights.json")
  }

  if (is.null(ai_sidecar_path)) {
    cat("    [WARNING] Config file path unknown — cannot locate the AI sidecar.\n")
    cat("    Continuing without AI insights.\n")
    return(NULL)
  }

  # Source AI modules
  ai_sourced <- tryCatch({
    turas_root_dir <- Sys.getenv("TURAS_ROOT", "")
    if (!nzchar(turas_root_dir)) turas_root_dir <- getwd()

    source(file.path(turas_root_dir, "modules/shared/lib/ai/ai_provider.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/shared/lib/ai/ai_voice.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/shared/lib/ai/ai_schemas.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/shared/lib/ai/ai_utils.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/shared/lib/ai/ai_verify.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/tabs/lib/ai/ai_extraction.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/tabs/lib/ai/ai_prompts.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/tabs/lib/ai/ai_schemas_tabs.R"), local = FALSE)
    source(file.path(turas_root_dir, "modules/tabs/lib/ai/ai_insights.R"), local = FALSE)
    TRUE
  }, error = function(e) {
    cat(sprintf("    [WARNING] Failed to load AI modules: %s\n", e$message))
    cat("    Continuing without AI insights.\n")
    FALSE
  })

  if (!ai_sourced) return(NULL)

  # Resolve the model chosen in the crosstab config. Blank = leave the
  # sidecar's own model untouched (preserves advanced provider switching).
  config_obj$ai_model <- resolve_ai_model_alias(config_obj$ai_model)
  if (nzchar(config_obj$ai_model)) {
    cat(sprintf("    AI model (from config): %s\n", config_obj$ai_model))
  }

  # Auto-create sidecar with defaults if it doesn't exist
  if (!file.exists(ai_sidecar_path)) {
    cat("    Creating AI insights sidecar with default settings...\n")
    default_sidecar <- if (nzchar(config_obj$ai_model)) {
      create_default_sidecar(model = config_obj$ai_model)
    } else {
      create_default_sidecar()
    }
    write_ai_sidecar_to_path(default_sidecar, ai_sidecar_path)
  }

  tryCatch({
    generate_all_insights(all_results, banner_info, config_obj, ai_sidecar_path)
  }, error = function(e) {
    cat(sprintf("    [WARNING] AI insights generation failed: %s\n", e$message))
    cat("    Continuing without AI insights.\n")
    NULL
  })
}
