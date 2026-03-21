# ==============================================================================
# TURAS Platform Health Check
# ==============================================================================
# Run this script to verify that the entire platform is operational.
# Checks: dependencies, shared infrastructure, all 11 modules, TRS system.
#
# USAGE:
#   Rscript scripts/health_check.R
#   # or from R console:
#   source("scripts/health_check.R")
#
# EXIT CODES:
#   0 = All checks passed
#   1 = One or more checks failed
# ==============================================================================

# ---------------------------------------------------------------------------
# Find Turas root
# ---------------------------------------------------------------------------
find_turas_root <- function() {
  # Check environment variable first (Docker)
  env_root <- Sys.getenv("TURAS_ROOT", unset = "")
  if (nzchar(env_root) && dir.exists(env_root)) return(normalizePath(env_root))

  # Walk up from script / working directory
  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "launch_turas.R"))) return(current)
    current <- dirname(current)
  }
  stop("Cannot locate Turas root. Set TURAS_ROOT or run from project directory.")
}

turas_root <- find_turas_root()
setwd(turas_root)
Sys.setenv(TURAS_ROOT = turas_root)

# ---------------------------------------------------------------------------
# Reporting helpers
# ---------------------------------------------------------------------------
results <- list()
check_count <- 0L
fail_count  <- 0L

check <- function(name, expr) {
  check_count <<- check_count + 1L
  status <- tryCatch({
    result <- eval(expr, envir = parent.frame())
    if (isTRUE(result)) "PASS" else "FAIL"
  }, error = function(e) {
    paste0("FAIL (", conditionMessage(e), ")")
  })

  passed <- status == "PASS"
  if (!passed) fail_count <<- fail_count + 1L
  tag <- if (passed) "\033[32mPASS\033[0m" else "\033[31mFAIL\033[0m"
  cat(sprintf("  [%s] %s\n", tag, name))
  results[[name]] <<- status
  invisible(passed)
}

section <- function(title) {
  cat(sprintf("\n--- %s ---\n", title))
}

# ===========================================================================
cat("\n")
cat("================================================================\n")
cat("  TURAS PLATFORM HEALTH CHECK\n")
cat(sprintf("  Root: %s\n", turas_root))
cat(sprintf("  R version: %s\n", R.version.string))
cat(sprintf("  Date: %s\n", Sys.time()))
cat("================================================================\n")

# ===========================================================================
section("Core Dependencies")
# ===========================================================================

core_pkgs <- c(
  "data.table", "openxlsx", "jsonlite", "shiny",
  "testthat", "survey"
)

# Optional packages (needed by some modules but not all)
optional_pkgs <- c("effectsize", "fastDummies", "ChoiceModelR", "mclust")
for (pkg in optional_pkgs) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  tag <- if (installed) "\033[32mPASS\033[0m" else "\033[33mSKIP\033[0m"
  cat(sprintf("  [%s] Package '%s' (optional)\n", tag, pkg))
}

for (pkg in core_pkgs) {
  check(
    sprintf("Package '%s' installed", pkg),
    quote(requireNamespace(pkg, quietly = TRUE))
  )
}

# ===========================================================================
section("Shared Infrastructure")
# ===========================================================================

shared_files <- c(
  "config_utils.R", "formatting_utils.R", "validation_utils.R",
  "weights_utils.R", "data_utils.R", "logging_utils.R",
  "trs_refusal.R", "trs_run_state.R", "trs_banner.R",
  "trs_run_status_writer.R"
)

for (f in shared_files) {
  check(
    sprintf("Shared: %s exists", f),
    bquote(file.exists(file.path(.(turas_root), "modules", "shared", "lib", .(f))))
  )
}

# Source core shared utilities
check("Source config_utils.R", quote({
  source(file.path(turas_root, "modules", "shared", "lib", "config_utils.R"))
  exists("find_turas_root", mode = "function")
}))

check("Source trs_refusal.R", quote({
  source(file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R"))
  exists("turas_refuse", mode = "function")
}))

check("Source formatting_utils.R", quote({
  source(file.path(turas_root, "modules", "shared", "lib", "formatting_utils.R"))
  exists("format_number", mode = "function")
}))

check("Source validation_utils.R", quote({
  source(file.path(turas_root, "modules", "shared", "lib", "validation_utils.R"))
  exists("validate_data_frame", mode = "function")
}))

# ===========================================================================
section("TRS System")
# ===========================================================================

check("TRS refuse returns structured list", quote({
  result <- tryCatch(
    turas_refuse(
      code = "CFG_HEALTH_CHECK",
      title = "Health Check Test",
      problem = "This is a test refusal",
      why_it_matters = "Verifies TRS is working",
      how_to_fix = "No action needed"
    ),
    turas_refusal = function(e) {
      list(status = "REFUSED", code = e$code)
    }
  )
  identical(result$status, "REFUSED") && identical(result$code, "CFG_HEALTH_CHECK")
}))

check("TRS status helpers exist", quote({
  exists("trs_status_pass", mode = "function") &&
  exists("trs_status_partial", mode = "function") &&
  exists("trs_status_refuse", mode = "function")
}))

# ===========================================================================
section("Module Source Check (syntax + load)")
# ===========================================================================

# Modules with standard R/ directory layout
standard_modules <- list(
  list(name = "AlchemerParser", guard = "R/00_guard.R", main = "R/00_main.R"),
  list(name = "catdriver",      guard = "R/08_guard.R", main = "R/00_main.R"),
  list(name = "confidence",     guard = "R/00_guard.R", main = "R/00_main.R"),
  list(name = "conjoint",       guard = "R/00_guard.R", main = "R/00_main.R"),
  list(name = "keydriver",      guard = "R/00_guard.R", main = "R/00_main.R"),
  list(name = "maxdiff",        guard = "R/00_guard.R", main = "R/00_main.R"),
  list(name = "pricing",        guard = "R/00_guard.R", main = "R/00_main.R"),
  list(name = "segment",        guard = "R/00_guard.R", main = "R/00_main.R")
)

# Modules with lib/ directory layout
lib_modules <- list(
  list(name = "tabs",      guard = "lib/00_guard.R"),
  list(name = "tracker",   guard = "lib/00_guard.R"),
  list(name = "weighting", guard = "lib/00_guard.R")
)

for (mod in standard_modules) {
  mod_dir <- file.path(turas_root, "modules", mod$name)

  check(sprintf("%s: directory exists", mod$name), bquote(dir.exists(.(mod_dir))))

  check(sprintf("%s: guard parses", mod$name), bquote({
    p <- file.path(.(mod_dir), .(mod$guard))
    if (!file.exists(p)) FALSE
    else { parse(file = p); TRUE }
  }))

  check(sprintf("%s: main parses", mod$name), bquote({
    p <- file.path(.(mod_dir), .(mod$main))
    if (!file.exists(p)) FALSE
    else { parse(file = p); TRUE }
  }))
}

for (mod in lib_modules) {
  mod_dir <- file.path(turas_root, "modules", mod$name)

  check(sprintf("%s: directory exists", mod$name), bquote(dir.exists(.(mod_dir))))

  check(sprintf("%s: guard parses", mod$name), bquote({
    p <- file.path(.(mod_dir), .(mod$guard))
    if (!file.exists(p)) FALSE
    else { parse(file = p); TRUE }
  }))
}

# Report Hub (special structure)
check("report_hub: directory exists", quote(
  dir.exists(file.path(turas_root, "modules", "report_hub"))
))
check("report_hub: guard parses", quote({
  p <- file.path(turas_root, "modules", "report_hub", "00_guard.R")
  if (!file.exists(p)) FALSE
  else { parse(file = p); TRUE }
}))

# ===========================================================================
section("GUI Launch Files")
# ===========================================================================

check("launch_turas.R exists", quote(
  file.exists(file.path(turas_root, "launch_turas.R"))
))

check("launch_turas.R parses", quote({
  parse(file = file.path(turas_root, "launch_turas.R"))
  TRUE
}))

gui_modules <- c(
  "AlchemerParser", "catdriver", "confidence", "conjoint",
  "keydriver", "maxdiff", "pricing", "segment",
  "tabs", "tracker", "weighting"
)

for (mod in gui_modules) {
  gui_file <- file.path(turas_root, "modules", mod,
                         paste0("run_", tolower(mod), "_gui.R"))
  # Some modules use different naming

  if (!file.exists(gui_file)) {
    gui_file <- file.path(turas_root, "modules", mod,
                           paste0("run_", mod, "_gui.R"))
  }

  check(sprintf("%s: GUI file exists", mod), bquote(file.exists(.(gui_file))))
}

# ===========================================================================
section("Docker Readiness")
# ===========================================================================

check("Dockerfile exists", quote(
  file.exists(file.path(turas_root, "Dockerfile"))
))

check(".dockerignore exists", quote(
  file.exists(file.path(turas_root, ".dockerignore"))
))

check("renv.lock exists", quote(
  file.exists(file.path(turas_root, "renv.lock"))
))

# ===========================================================================
section("Test Infrastructure")
# ===========================================================================

check("tests/ directory exists", quote(
  dir.exists(file.path(turas_root, "tests"))
))

check("tests/testthat.R exists", quote(
  file.exists(file.path(turas_root, "tests", "testthat.R"))
))

# Count test files across all modules
test_file_count <- length(list.files(
  file.path(turas_root, "modules"),
  pattern = "^test_.*\\.R$",
  recursive = TRUE
))

check(sprintf("Test files found: %d (expect 100+)", test_file_count), quote(
  test_file_count >= 100
))

# ===========================================================================
# SUMMARY
# ===========================================================================
cat("\n================================================================\n")
if (fail_count == 0) {
  cat(sprintf("  \033[32mALL %d CHECKS PASSED\033[0m\n", check_count))
} else {
  cat(sprintf("  \033[31m%d of %d CHECKS FAILED\033[0m\n", fail_count, check_count))
  cat("\n  Failed checks:\n")
  for (name in names(results)) {
    if (results[[name]] != "PASS") {
      cat(sprintf("    - %s: %s\n", name, results[[name]]))
    }
  }
}
cat("================================================================\n\n")

# Exit with appropriate code when run via Rscript
if (!interactive()) {
  quit(status = if (fail_count == 0) 0L else 1L, save = "no")
}
