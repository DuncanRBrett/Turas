# ==============================================================================
# WHAT IF - LOAD THE MODULE
# ==============================================================================
#
# The one way to load the What if module:
#
#   source("modules/whatif/source_whatif.R")
#   res <- run_whatif("path/to/WhatIf_Config.xlsx")
#
# Loads the shared TRS infrastructure (import_all.R), the shared disclosure
# rules (disclosure_groups.R, not part of import_all), then the module's R/
# files. Every file in R/ only defines functions, so the order does not matter;
# they are loaded in name order.
# ==============================================================================

.whatif_module_dir <- local({
  from_stack <- NULL
  for (i in seq_len(sys.nframe())) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(ofile) && nzchar(ofile)) from_stack <- ofile
  }
  if (!is.null(from_stack)) {
    normalizePath(dirname(from_stack), winslash = "/", mustWork = FALSE)
  } else {
    candidates <- c(file.path(getwd(), "modules", "whatif"), file.path(getwd(), "whatif"), getwd())
    hit <- candidates[file.exists(file.path(candidates, "R", "00_main.R"))]
    if (!length(hit)) {
      cat("\n[What if] source_whatif.R cannot find the module folder.\n",
          "Run it from the Turas project root, or source it by its full path.\n", sep = "")
      stop("What if module folder not found", call. = FALSE)
    }
    normalizePath(hit[[1]], winslash = "/", mustWork = FALSE)
  }
})

local({
  shared <- normalizePath(file.path(.whatif_module_dir, "..", "shared", "lib"), winslash = "/", mustWork = FALSE)
  for (f in c("import_all.R", "disclosure_groups.R")) {
    p <- file.path(shared, f)
    if (!file.exists(p)) {
      cat("\n[What if] Missing shared file:", p, "\n")
      stop("Shared library not found", call. = FALSE)
    }
    source(p)
  }
})

local({
  for (f in sort(list.files(file.path(.whatif_module_dir, "R"), pattern = "\\.R$", full.names = TRUE))) {
    source(f)
  }
})
