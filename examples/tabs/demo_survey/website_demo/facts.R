# Observed figures from the generated synthetic data, so every sentence in the
# demo's executive summary can be checked against the numbers it describes.
suppressPackageStartupMessages(library(openxlsx))
root <- commandArgs(trailingOnly = TRUE)[1]

wmean <- function(x, w) { ok <- !is.na(x); sum(x[ok] * w[ok]) / sum(w[ok]) }

d <- list()
for (y in c("2022", "2023", "2024", "2025")) {
  d[[y]] <- read.xlsx(file.path(root, paste0("w", y), "Demo_Survey_Data.xlsx"),
                      sheet = "Data", skipEmptyRows = FALSE)
}

cat("=== WAVE MEANS (weighted) ===\n")
qs <- c(sprintf("Q%03d", 2:17))
tab <- sapply(names(d), function(y) sapply(qs, function(q) round(wmean(d[[y]][[q]], d[[y]]$Weight), 2)))
print(tab)

cat("\n=== NPS (weighted net) ===\n")
nps <- sapply(names(d), function(y) {
  x <- d[[y]]$Q001; w <- d[[y]]$Weight
  round(100 * (sum(w[x >= 9]) - sum(w[x <= 6])) / sum(w), 1)
})
print(nps)

cur <- d[["2025"]]
cat("\n=== 2025 SEGMENT MEANS ===\n")
segtab <- sapply(c("Q002", "Q003", "Q004", "Q005", "Q006", "Q009"), function(q)
  sapply(c("Premium", "Standard", "Budget", "New Customer"), function(s) {
    i <- cur$Segment == s; round(wmean(cur[[q]][i], cur$Weight[i]), 2) }))
print(segtab)

cat("\n=== 2025 REGION MEANS ===\n")
regtab <- sapply(c("Q001", "Q005", "Q007"), function(q)
  sapply(c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"), function(s) {
    i <- cur$Region == s; round(wmean(cur[[q]][i], cur$Weight[i]), 2) }))
print(regtab)

cat("\n=== 2025 DIGITAL CHANNELS (weighted mean) ===\n")
print(sapply(c(website = "Q008", app = "Q009"), function(q) round(wmean(cur[[q]], cur$Weight), 2)))

# ---- Qualitative coding ----
cat("\n=== QUAL THEMES ===\n")
cw <- file.path(root, "w2025", "Demo_Comments.xlsx")
for (sh in getSheetNames(cw)) {
  raw <- read.xlsx(cw, sheet = sh, colNames = FALSE, skipEmptyRows = FALSE)
  hdr <- as.character(unlist(raw[2, ]))
  body <- raw[-(1:2), , drop = FALSE]
  names(body) <- hdr
  theme_cols <- hdr[7:length(hdr)]
  n_comments <- nrow(body)
  res <- t(sapply(theme_cols, function(tc) {
    v <- suppressWarnings(as.integer(body[[tc]]))
    c(mentions = sum(!is.na(v)),
      pct = round(100 * sum(!is.na(v)) / n_comments),
      pos = sum(v == 1, na.rm = TRUE), neg = sum(v == 3, na.rm = TRUE),
      net = round(100 * (sum(v == 1, na.rm = TRUE) - sum(v == 3, na.rm = TRUE)) /
                    max(sum(!is.na(v)), 1)))
  }))
  cat("\n--", sh, "-- n comments =", n_comments, "\n")
  print(res[order(-res[, "mentions"]), ])

  if (sh == "Recommend") {
    v <- suppressWarnings(as.integer(body[["Delivery"]]))
    ec <- body$Region == "Eastern Cape"
    cat("  Delivery mention rate: Eastern Cape",
        round(100 * sum(!is.na(v[ec])) / sum(ec)), "% vs rest",
        round(100 * sum(!is.na(v[!ec])) / sum(!ec)), "%\n")
    # which theme does the Eastern Cape raise most?
    ec_counts <- sapply(theme_cols, function(tc)
      sum(!is.na(suppressWarnings(as.integer(body[[tc]][ec])))))
    cat("  Eastern Cape theme order:", paste(names(sort(-ec_counts)), collapse = " > "), "\n")
  }
}
