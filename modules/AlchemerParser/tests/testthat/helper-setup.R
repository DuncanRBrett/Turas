# ==============================================================================
# ALCHEMERPARSER TEST SETUP
# ==============================================================================
# Source module files so functions are available to all test files.
# testthat loads helper-*.R files automatically before running tests.
# ==============================================================================

find_module_root <- function() {
  current <- getwd()
  while (current != dirname(current)) {
    candidate <- file.path(current, "modules", "AlchemerParser", "R")
    if (dir.exists(candidate)) return(file.path(current, "modules", "AlchemerParser"))
    current <- dirname(current)
  }
  stop("Cannot locate AlchemerParser module root")
}

module_root <- find_module_root()

source(file.path(module_root, "R/00_guard.R"))
source(file.path(module_root, "R/01_parse_data_map.R"))
source(file.path(module_root, "R/02_parse_translation.R"))
source(file.path(module_root, "R/03_parse_word_doc.R"))
source(file.path(module_root, "R/04_classify_questions.R"))
source(file.path(module_root, "R/04b_detect_routing.R"))
source(file.path(module_root, "R/05_generate_codes.R"))
source(file.path(module_root, "R/06_output.R"))
