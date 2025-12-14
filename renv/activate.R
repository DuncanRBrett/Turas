# ==============================================================================
# renv Activation Script for Turas
# ==============================================================================
# This script is auto-sourced by .Rprofile to activate the renv environment.
# It ensures reproducible package versions across all Turas installations.
#
# DO NOT EDIT manually - this file is managed by renv.
# ==============================================================================

local({

  # The version of renv to use
  version <- "1.0.7"

  # The renv project directory
  project <- getwd()

  # Check if renv is already loaded
  if (requireNamespace("renv", quietly = TRUE)) {
    if (packageVersion("renv") == version) {
      return(renv::load(project = project))
    }
  }

  # Bootstrap renv if not installed or wrong version
  bootstrap <- function(version, library) {
    # Download and install renv
    message("* Bootstrapping renv ", version, " ... ", appendLF = FALSE)

    # Try to install from CRAN
    status <- tryCatch({
      utils::install.packages(
        "renv",
        lib = library,
        repos = c(CRAN = "https://cloud.r-project.org")
      )
      TRUE
    }, error = function(e) {
      FALSE
    })

    if (status) {
      message("Done!")
    } else {
      message("FAILED")
      message("* Failed to bootstrap renv -- please install manually.")
      return(FALSE)
    }

    TRUE
  }

  # Find library path
  libpath <- file.path(project, "renv/library", R.version$platform, getRversion()[1, 1:2])
  if (!dir.exists(libpath)) {
    dir.create(libpath, recursive = TRUE)
  }

  # Bootstrap if needed
  if (!requireNamespace("renv", lib.loc = libpath, quietly = TRUE)) {
    bootstrap(version, libpath)
  }

  # Load renv
  if (requireNamespace("renv", lib.loc = libpath, quietly = TRUE)) {
    library(renv, lib.loc = libpath)
    renv::load(project = project)
  } else {
    message("* renv is not available. Please install it with: install.packages('renv')")
  }

})
