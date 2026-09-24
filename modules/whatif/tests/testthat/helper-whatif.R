# Loads the module when a test file is run on its own (test_file); the runner
# has already sourced everything, in which case this does nothing.
if (!exists("run_whatif", mode = "function")) {
  module_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  turas_root <- dirname(dirname(module_root))
  source(file.path(module_root, "source_whatif.R"))
  source(file.path(module_root, "lib", "generate_config_template.R"))
  source(file.path(turas_root, "modules", "shared", "template_styles.R"))
  for (f in list.files(file.path(module_root, "tests", "fixtures", "synthetic_data"), pattern = "\\.R$",
                       full.names = TRUE)) source(f)
}

# A synthetic project on disk, written once per test file into a temp folder.
test_project <- function(config = list(), n = 500, seed = 11) {
  dir <- tempfile("whatif_project_")
  dir.create(dir)
  suppressMessages(utils::capture.output(p <- whatif_write_test_project(dir, n = n, seed = seed, config = config)))
  p
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
