# ==============================================================================
# TURAS SHARED UTILITY - source_if_exists()
# ==============================================================================
# Canonical implementation. All modules should use this instead of local copies.
#
# Safely sources an R file if it exists, with optional environment control
# and fallback path resolution for modules using the R/ subdirectory convention.
# ==============================================================================

#' Source a file if it exists
#'
#' Safely sources an R file, checking the given path first,
#' then fallback paths in R/ and ../R/ subdirectories.
#' Wraps in tryCatch to prevent sourcing errors from crashing the caller.
#'
#' @param file_path Character, path to the R script.
#' @param envir Environment in which to source the file. Defaults to the
#'   caller's environment (parent.frame()), which preserves the behaviour
#'   expected by modules that source helpers into their own scope.
#'
#' @return Invisible NULL. Side effect: sources the file into \code{envir}.
#' @keywords internal
source_if_exists <- function(file_path, envir = parent.frame()) {
  # Resolve the first path that exists: literal, R/, or ../R/
  candidates <- c(
    file_path,
    file.path("R", file_path),
    file.path("..", "R", file_path)
  )
  resolved <- candidates[file.exists(candidates)]

  if (length(resolved) == 0L) {
    return(invisible(NULL))
  }

  tryCatch({
    source(resolved[1L], local = envir)
    invisible(NULL)
  }, error = function(e) {
    cat(sprintf(
      "  [WARNING] Failed to source %s: %s\n",
      resolved[1L], conditionMessage(e)
    ))
    invisible(NULL)
  })
}
