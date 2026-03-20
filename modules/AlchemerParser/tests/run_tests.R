# ==============================================================================
# ALCHEMERPARSER TEST RUNNER
# ==============================================================================
# Run all unit tests for the AlchemerParser module
#
# Usage:
#   source("modules/AlchemerParser/tests/run_tests.R")
#
# Or from project root:
#   testthat::test_dir("modules/AlchemerParser/tests/testthat")
# ==============================================================================

# Determine paths
test_dir <- dirname(sys.frame(1)$ofile %||% ".")
module_dir <- dirname(test_dir)
project_root <- file.path(module_dir, "../..")

# Source module files in dependency order
source(file.path(module_dir, "R/00_guard.R"))
source(file.path(module_dir, "R/01_parse_data_map.R"))
source(file.path(module_dir, "R/02_parse_translation.R"))
source(file.path(module_dir, "R/03_parse_word_doc.R"))
source(file.path(module_dir, "R/04_classify_questions.R"))
source(file.path(module_dir, "R/05_generate_codes.R"))
source(file.path(module_dir, "R/06_output.R"))

# Run tests
testthat::test_dir(file.path(test_dir, "testthat"), reporter = "summary")
