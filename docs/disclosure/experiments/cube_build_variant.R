# Rebuild the Karoo demo's TABS step with html_report_v2_interactivity = cube,
# into a sibling folder, so the two reports can be compared cell for cell.
# The config workbook is written FRESH (never loadWorkbook + save, which
# collapses each sheet's declared dimension to A1).
args <- commandArgs(trailingOnly = TRUE)
turas_root <- normalizePath(args[1])
src_dir <- normalizePath(args[2])       # .../demo/tabs
dst_dir <- args[3]                      # .../demo_cube/tabs
setwd(turas_root)
suppressPackageStartupMessages(library(openxlsx))
source(file.path(turas_root, "modules/shared/lib/turas_save_workbook_atomic.R"))

dir.create(dst_dir, recursive = TRUE, showWarnings = FALSE)
for (f in list.files(src_dir, pattern = "[.]xlsx$", full.names = TRUE)) {
  file.copy(f, file.path(dst_dir, basename(f)), overwrite = TRUE)
}
cfg_path <- file.path(dst_dir, "Karoo_Demo_Crosstab_Config.xlsx")

settings <- openxlsx::read.xlsx(cfg_path, sheet = "Settings", skipEmptyRows = FALSE)
selection <- openxlsx::read.xlsx(cfg_path, sheet = "Selection", skipEmptyRows = FALSE)

set_row <- function(df, name, value) {
  hit <- which(trimws(as.character(df$Setting)) == name)
  if (length(hit)) { df$Value[hit[1]] <- value; return(df) }
  rbind(df, data.frame(Setting = name, Value = value, stringsAsFactors = FALSE))
}
settings <- set_row(settings, "html_report_v2_interactivity", "cube")
settings <- set_row(settings, "min_reporting_base", "5")
settings <- set_row(settings, "html_report_v2_cube_order", "2")
settings <- set_row(settings, "html_report_v2_filter_vars", "Q008,Q009")

wb <- createWorkbook()
addWorksheet(wb, "Settings"); writeData(wb, "Settings", settings)
addWorksheet(wb, "Selection"); writeData(wb, "Selection", selection)
turas_saveWorkbook(wb, cfg_path, overwrite = TRUE)
cat("Config rewritten with interactivity = cube, k = 5, order = 2\n")

source(file.path(turas_root, "modules/tabs/run_tabs.R"))
ok <- run_tabs_analysis(cfg_path)
report <- file.path(dst_dir, "report", "Karoo_Demo_Crosstabs_report.html")
if (!isTRUE(ok) || !file.exists(report)) stop("[CUBE DEMO] tabs did not write ", report)
cat(sprintf("Cube report: %s (%.2f MB)\n", report, file.size(report) / 1e6))
