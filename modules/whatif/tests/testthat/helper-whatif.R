# Loads the module when a test file is run on its own (test_file); the runner
# has already sourced everything, in which case this does nothing.
if (!exists("whatif_run_engine", mode = "function")) {
  module_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  turas_root <- dirname(dirname(module_root))
  source(file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R"))
  for (f in sort(list.files(file.path(module_root, "R"), pattern = "\\.R$", full.names = TRUE))) source(f)
  source(file.path(module_root, "tests", "fixtures", "synthetic_data", "generate_test_data.R"))
}

# Run an engine call quietly and return its value (refusals print a box).
quietly <- function(expr) {
  out <- NULL
  utils::capture.output(out <- expr)
  out
}

# Fit once per file and reuse; n_boot kept small for speed.
fixture_model <- function(..., baselines = character(0), n_boot = 30) {
  spec <- whatif_synthetic_study(...)
  spec$baselines <- baselines
  spec$n_boot <- n_boot
  m <- quietly(whatif_run_engine(spec, verbose = FALSE))
  if (!inherits(m, "whatif_model")) stop("fixture model did not fit: ", m$code %||% m$message)
  m
}
