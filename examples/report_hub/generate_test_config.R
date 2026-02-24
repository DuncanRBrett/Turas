#' Generate Test Config Excel File for Report Hub Module
#'
#' Creates a multi-sheet Excel configuration file used by the Report Hub
#' module to combine multiple HTML reports into a unified portal.
#'
#' Output: examples/report_hub/SACAP_Combined_Config.xlsx
#'
#' @note Requires the openxlsx package.

library(openxlsx)

# ---------------------------------------------------------------------------
# 1. Settings sheet (key-value format)
# ---------------------------------------------------------------------------
settings <- data.frame(
  Field = c(
    "project_title",
    "company_name",
    "client_name",
    "brand_colour",
    "accent_colour",
    "logo_path",
    "output_dir",
    "output_file"
  ),
  Value = c(
    "SACAP Annual Climate Survey",
    "The Research LampPost",
    "SACAP",
    "#323367",
    "#CC9900",
    "sacap_logo.png",
    "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave",
    "SACAP_Combined_Report.html"
  ),
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# 2. Reports sheet (one row per report)
# ---------------------------------------------------------------------------
reports <- data.frame(
  report_path = c(
    "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/SACAP_Annual_Climate_Survey_TrackingCrosstab_20260223.html",
    "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/03_Waves/SACS-2025/04_Analysis/Crosstabs/SACS-2025_Crosstabs.html"
  ),
  report_label = c(
    "Tracker",
    "Crosstabs 2025"
  ),
  report_key = c(
    "tracker",
    "tabs"
  ),
  order = c(1L, 2L),
  report_type = c(
    "tracker",
    "tabs"
  ),
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# 3. CrossRef sheet (empty with column headers only)
# ---------------------------------------------------------------------------
crossref <- data.frame(
  tracker_code = character(0),
  tabs_code    = character(0),
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# Build workbook
# ---------------------------------------------------------------------------
wb <- createWorkbook()

# --- Settings sheet --------------------------------------------------------
addWorksheet(wb, "Settings")
writeData(wb, "Settings", settings)

header_style <- createStyle(
  fontName       = "Arial",
  fontSize       = 11,
  textDecoration = "bold",
  fgFill         = "#323367",
  fontColour     = "#FFFFFF",
  halign         = "left"
)
addStyle(wb, "Settings", style = header_style, rows = 1, cols = 1:2)
setColWidths(wb, "Settings", cols = 1, widths = 20)
setColWidths(wb, "Settings", cols = 2, widths = 40)

# --- Reports sheet ---------------------------------------------------------
addWorksheet(wb, "Reports")
writeData(wb, "Reports", reports)

addStyle(wb, "Reports", style = header_style, rows = 1, cols = 1:5)
setColWidths(wb, "Reports", cols = 1, widths = 80)
setColWidths(wb, "Reports", cols = 2, widths = 20)
setColWidths(wb, "Reports", cols = 3, widths = 15)
setColWidths(wb, "Reports", cols = 4, widths = 10)
setColWidths(wb, "Reports", cols = 5, widths = 15)

# --- CrossRef sheet --------------------------------------------------------
addWorksheet(wb, "CrossRef")
writeData(wb, "CrossRef", crossref)

addStyle(wb, "CrossRef", style = header_style, rows = 1, cols = 1:2)
setColWidths(wb, "CrossRef", cols = 1:2, widths = 20)

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
output_path <- file.path(
  "/Users/duncan/Documents/Turas/examples/report_hub",
  "SACAP_Combined_Config.xlsx"
)

saveWorkbook(wb, output_path, overwrite = TRUE)

cat("Config file written to:", output_path, "\n")
