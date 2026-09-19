# ==============================================================================
# CATDRIVER - LOAD THE MODULE
# ==============================================================================
#
# The one way to load CatDriver outside the Shiny app:
#
#   source("modules/catdriver/source_catdriver.R")
#   result <- with_refusal_handler(run_categorical_keydriver("my_config.xlsx"))
#
# Why this file exists. The README, the user manual and the example workflows
# all told the reader to source R/00_main.R and call the entry point. That has
# never worked: 00_main.R sources the TRS infrastructure and nothing else, so
# the call died with `could not find function "with_refusal_handler"`. Only the
# GUI's own twenty-file sequence produced a working session, and that sequence
# existed in three places at once (the GUI, the demo runner, and whatever a
# session typed by hand), free to drift apart.
#
# The order below is a dependency order, not alphabetical: utilities and the
# guards first, because everything else calls them, then config and data, then
# the engines, then output, then the orchestrator.
# ==============================================================================

.catdriver_module_dir <- local({

  # Where is this file? Walk the call stack for the frame that sourced it,
  # rather than reading the outermost frame: sourced from inside a function
  # (a Shiny observer, say) the outermost frame has no ofile and the
  # working-directory fallbacks are all that is left. Same mistake the shared
  # loader carried until 2026-09-17.
  from_stack <- NULL
  for (i in seq_len(sys.nframe())) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(ofile) && nzchar(ofile)) from_stack <- ofile
  }

  if (!is.null(from_stack)) {
    normalizePath(dirname(from_stack), winslash = "/", mustWork = FALSE)
  } else {
    candidates <- c(file.path(getwd(), "modules", "catdriver"),
                    file.path(getwd(), "catdriver"),
                    getwd())
    hit <- candidates[file.exists(file.path(candidates, "R", "00_main.R"))]
    if (length(hit) == 0) {
      stop("source_catdriver.R cannot find the catdriver module directory. ",
           "Run it from the Turas project root, or source it by its full path.")
    }
    normalizePath(hit[[1]], winslash = "/", mustWork = FALSE)
  }
})

# The shared TRS infrastructure: refusals, run state, the workbook saver, the
# stats pack writer. Without it every refusal in the module is undefined.
local({
  turas_root <- normalizePath(file.path(.catdriver_module_dir, "..", ".."),
                              winslash = "/", mustWork = FALSE)
  import_all <- file.path(turas_root, "modules", "shared", "lib", "import_all.R")
  if (!file.exists(import_all)) {
    stop("source_catdriver.R cannot find modules/shared/lib/import_all.R beside ",
         "the catdriver module. Expected it at: ", import_all)
  }
  source(import_all)
})

# The module itself, in dependency order. This list is the single source of
# truth: run_catdriver_gui.R and the demo runner both load through this file.
CATDRIVER_SOURCE_ORDER <- c(
  "07_utilities.R",
  "08_guard.R", "08a_guards_hard.R", "08b_guards_soft.R",
  "01_config.R", "02_validation.R", "03_preprocessing.R",
  "09_mapper.R", "10_missing.R",
  "04_analysis.R", "04a_ordinal.R", "04b_multinomial.R",
  "05_importance.R",
  "06a_sheets_summary.R", "06b_sheets_detail.R", "06_output.R",
  "06c_sheets_subgroup.R",
  "11_subgroup_comparison.R",
  "00_main.R"
)

local({
  r_dir <- file.path(.catdriver_module_dir, "R")
  missing <- CATDRIVER_SOURCE_ORDER[!file.exists(file.path(r_dir, CATDRIVER_SOURCE_ORDER))]
  if (length(missing) > 0) {
    stop("source_catdriver.R cannot find these module files in ", r_dir, ": ",
         paste(missing, collapse = ", "))
  }
  for (f in CATDRIVER_SOURCE_ORDER) {
    source(file.path(r_dir, f))
  }
})

# Where the HTML report builders live. The report step discovers them from this
# variable; without it a run completes and then reports every builder missing.
assign(".catdriver_lib_dir", file.path(.catdriver_module_dir, "lib"),
       envir = globalenv())

invisible(TRUE)
