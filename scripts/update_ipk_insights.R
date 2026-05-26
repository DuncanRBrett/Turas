#!/usr/bin/env Rscript
# Refresh IPK Section_Insights against the regenerated 26 May 2026 brand report.
# - Numbers verified against the per-tab values shown in
#   8844718_Brand_Config_report.html (regenerated after 100 replaced interviews).
# - Each insight rewritten to stick to facts on its own tab and drop
#   cross-tab references.

cfg_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/8844718_Brand_Config.xlsx"

patches <- list(
  list(cat = "_REPORT", sec = "Background",
       text = "Wave 1, May 2026. Ina Paarman's operates in the nine categories surveyed. Four are taken to deep-dive — Dry Seasonings, Pasta Sauces, Pour-Over Sauces, Baking Mixes — with full Funnel, Mental Advantage, Category Buying and Word-of-Mouth panels. Sample n=1,200, female-only, Western Cape lean. Fieldwork 19–26 May 2026."),

  list(cat = "_REPORT", sec = "Executive Summary",
       text = ""),

  list(cat = "_REPORT", sec = "Portfolio Overview",
       text = "Ina Paarman's awareness sits between 39% (Baking Mixes) and 57% (Pestos) across the nine categories. Gap to the category leader ranges from 6pp (Pestos, Woolworths the leader) to 39pp (Baking Mixes, Snowflake the leader)."),

  list(cat = "_REPORT", sec = "Portfolio Category Context",
       text = "Dominant in Pestos and Antipasti. Contested in Cook-in Sauces and Pour-Over Sauces. Crowded out in Dry Seasonings and Pasta Sauces. Open space in Salad Dressings, Stock and Baking Mixes."),

  list(cat = "_REPORT", sec = "Portfolio Competitive Set",
       text = ""),

  list(cat = "_REPORT", sec = "Portfolio Footprint",
       text = "Awareness by brand × category. Ina Paarman's is top-3 in Pestos (2nd of 11) and Antipasti (3rd of 10); ranks mid-pack in Pour-Over Sauces, Cook-in Sauces, Salad Dressings, Stock, Pasta Sauces and Dry Seasonings; lowest among measured brands in Baking Mixes (7th of 11)."),

  list(cat = "POS", sec = "Brand Funnel",
       text = "Aware 50%, prefer 66%, past 12m 44%, past 3m 37%. Above category average (46% / 66% / 43% / 31%) at aware, past 12m and past 3m; on par at prefer. Prefer (66%) exceeds aware (50%) by 16pp."),

  list(cat = "POS", sec = "Mental Advantage",
       text = "Ina Paarman's sits behind the leader on every Category Entry Point by 10 to 21 percentage points. Knorr leads 11 of 12 CEPs; Woolworths leads the remaining one. Narrowest gap: \"With guests you want to impress slightly\" (Woolworths 10pp ahead). Widest: \"To make vegetables actually enjoyable for kids\" (Knorr 21pp ahead)."),

  list(cat = "PAS", sec = "Brand Funnel",
       text = "Aware 40%, prefer 65%, past 12m 43%, past 3m 28%. Above category average (40% / 62% / 34% / 23%) at prefer, past 12m and past 3m; on par at aware. Prefer (65%) exceeds aware (40%) by 25pp."),

  list(cat = "PAS", sec = "Category Buying",
       text = "Ina Paarman's buyers buy more pasta sauce in total than the average pasta-sauce buyer — mean basket 25.1 vs category 15.8. Buyer mix: 49% heavy, 35% medium, 16% light category buyers."),

  list(cat = "DSS", sec = "Brand Funnel",
       text = "Aware 42%, prefer 59%, past 12m 31%, past 3m 20%. Below category average (47% / 64% / 39% / 27%) at every stage. Prefer (59%) exceeds aware (42%) by 17pp."),

  list(cat = "DSS", sec = "Mental Advantage",
       text = "Ina Paarman's sits behind the leader on every Category Entry Point by 20 to 38 percentage points. Robertsons leads 13 of 15 CEPs; Six Gun Grill leads the other 2. Narrowest gap: \"When I want flavour without unhealthy additives\" (Robertsons 20pp ahead). Widest: \"At an outdoor braai or while camping\" (Six Gun Grill 38pp ahead)."),

  list(cat = "BAK", sec = "Brand Funnel",
       text = "Aware 34%, prefer 48%, past 12m 28%, past 3m 18%. Below category average (42% / 58% / 38% / 25%) at every stage. Prefer (48%) exceeds aware (34%) by 14pp."),

  list(cat = "BAK", sec = "Mental Advantage",
       text = "Ina Paarman's sits behind Snowflake on every Category Entry Point by 23 to 52 percentage points. Snowflake leads all 13 CEPs. Narrowest gap: \"With store-bought icing, toppings or fruit added in\" (23pp). Widest: \"For a school bake sale or birthday party\" (52pp).")
)

wb <- openxlsx::loadWorkbook(cfg_path)
existing <- openxlsx::read.xlsx(cfg_path, sheet = "Section_Insights")
updated_text <- existing$Insight
updated_date <- existing$Date
today <- format(Sys.Date(), "%Y-%m-%d")

matched <- character(0)
for (i in seq_len(nrow(existing))) {
  cat_i <- trimws(as.character(existing$Category[i]))
  sec_i <- trimws(as.character(existing$Section[i]))
  for (p in patches) {
    if (identical(trimws(p$cat), cat_i) && identical(trimws(p$sec), sec_i)) {
      updated_text[i] <- p$text
      updated_date[i] <- today
      matched <- c(matched, paste0(cat_i, " / ", sec_i))
    }
  }
}

openxlsx::writeData(wb, "Section_Insights", updated_text,
                    startCol = 3, startRow = 2, colNames = FALSE)
openxlsx::writeData(wb, "Section_Insights", updated_date,
                    startCol = 6, startRow = 2, colNames = FALSE)
openxlsx::saveWorkbook(wb, cfg_path, overwrite = TRUE)

cat(sprintf("Patched %d Section_Insights rows:\n", length(matched)))
for (m in matched) cat(" -", m, "\n")
