#!/usr/bin/env Rscript
# Drop the Executive Summary insight (blank the Insight cell).

cfg_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/8844718_Brand_Config.xlsx"
patches <- list(
  list(cat = "_REPORT", sec = "Executive Summary", text = "")
)

wb <- openxlsx::loadWorkbook(cfg_path)
existing <- openxlsx::read.xlsx(cfg_path, sheet = "Section_Insights")
updated_text <- existing$Insight
updated_date <- existing$Date
today <- format(Sys.Date(), "%Y-%m-%d")
for (i in seq_len(nrow(existing))) {
  cat_i <- trimws(as.character(existing$Category[i]))
  sec_i <- trimws(as.character(existing$Section[i]))
  for (p in patches) {
    if (identical(trimws(p$cat), cat_i) && identical(trimws(p$sec), sec_i)) {
      updated_text[i] <- p$text
      updated_date[i] <- today
    }
  }
}
openxlsx::writeData(wb, "Section_Insights", updated_text, startCol = 3, startRow = 2, colNames = FALSE)
openxlsx::writeData(wb, "Section_Insights", updated_date, startCol = 6, startRow = 2, colNames = FALSE)
openxlsx::saveWorkbook(wb, cfg_path, overwrite = TRUE)
cat("Dropped Executive Summary insight.\n")
