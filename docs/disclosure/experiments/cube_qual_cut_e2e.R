# Build a CUBE report that carries comments, so the cut can be proved in a page
# rather than only in a unit test.
setwd("/Users/duncan/Dev/Turas")
SP <- commandArgs(trailingOnly = TRUE)[1]
FX <- "modules/tabs/tests/fixtures/parity_project"
source("modules/tabs/lib/cube_writer.R")
source("modules/tabs/lib/qual_island_builder.R")
for (f in c("qual_serialize.R","qual_report.R")) { pth <- file.path("modules/tabs/lib", f); if (file.exists(pth)) try(source(pth), silent = TRUE) }
source("modules/tabs/lib/html_report_v2/report_text.R")
source("modules/tabs/lib/html_report_v2/build_report_v2.R")

rd <- function(n) paste(readLines(file.path(FX, n), warn = FALSE), collapse = "\n")
agg_json <- rd("parity_island.json")
agg   <- jsonlite::fromJSON(agg_json, simplifyVector = FALSE)
micro <- jsonlite::fromJSON(rd("parity_micro.json"), simplifyVector = FALSE)
# A JSON array with nulls parses to a list; flatten it back to an atomic vector
# of the SAME length, nulls as NA, or every index after the first null shifts.
flat <- function(x, mode = "integer") {
  if (is.null(x)) return(NULL)
  out <- vapply(x, function(v) {
    if (is.null(v) || length(v) != 1L) NA_real_ else as.numeric(v)
  }, numeric(1))
  if (mode == "integer") as.integer(out) else out
}
micro$n <- as.integer(micro$n)
for (k in names(micro$answers)) micro$answers[[k]] <- flat(micro$answers[[k]])
for (k in names(micro$banner_vars)) micro$banner_vars[[k]] <- flat(micro$banner_vars[[k]])
micro$weights <- flat(micro$weights, "numeric")
for (k in names(micro$scores %||% list())) micro$scores[[k]] <- flat(micro$scores[[k]], "numeric")
for (k in names(micro$boxes %||% list())) micro$boxes[[k]] <- flat(micro$boxes[[k]])
for (k in names(micro$series %||% list())) {
  for (r in names(micro$series[[k]])) micro$series[[k]][[r]] <- flat(micro$series[[k]][[r]], "numeric")
}

cfg <- list(min_reporting_base = 5, html_report_v2_cube_order = 2L,
            html_report_v2_filter_vars = c("Q1", "Q3"))
cube <- build_cube(micro, agg, cfg)
cat("cube vars:", paste(names(cube$vars), collapse = ", "), "\n")

# 60 comments from the first 60 respondents.
n_com <- 60L
ids <- paste0("R", seq_len(n_com))
mk <- function(i) list(id = ids[i], text = paste("Comment", i), noteworthy = FALSE,
                       noteworthy_tier = 0L, noteworthy_marker = "",
                       sentiment = NA_integer_, rating = NA_real_,
                       themeVals = list(), demos = list())
q <- list(code = "QUAL_WHY", title = "Why do you say that?", type = "raw",
          sheet = "QUAL_WHY", roles = list(themes = list()),
          records = lapply(seq_len(n_com), mk),
          meta = list(dropped_codes = 0L, n_records = n_com))
master <- list(n = micro$n, id_to_idx = stats::setNames(seq_len(n_com) - 1L, ids),
               banner_dims = list())
island <- qual_build_data_qual(list(q), master,
  list(text_mode = "full", demographic_cuts = "safe", min_reporting_base = 5),
  cut_levels = cube$respondent_levels)
cat("cutVars in the island:", paste(unlist(island$cutVars), collapse = ", "), "\n")

# What the cut SHOULD give, computed straight from the microdata, independently
# of anything the renderer does.
lv <- cube$respondent_levels
truth <- sum(vapply(seq_len(n_com), function(i) isTRUE(lv$Q1[i] == 0L), logical(1)))
tagged <- sum(vapply(island$questions[[1]]$records,
                     function(r) !is.null(r$cut$Q1), logical(1)))
cat("comments whose author is on Q1 level 0 (from the microdata):", truth, "\n")
cat("comments carrying a Q1 level after k-anonymisation:", tagged, "of", n_com, "\n")

rcfg <- list(project_title = "Cut proof", client_name = "T", wave = "W1",
             brand_colour = "#323367", accent_colour = "#CC9900", alpha = 0.05,
             significance_min_base = 30, min_reporting_base = 5,
             sampling_method = "Not_Specified", apply_weighting = FALSE,
             show_qualitative = TRUE)
html <- build_report_v2_html(agg_json, rcfg, "modules/tabs/lib/html_report_v2/assets",
  generated = "fixed", micro_json = "null", cube_json = serialize_cube(cube),
  qual_json = serialize_data_qual(island))
writeLines(html, file.path(SP, "qual_cube.html"))
cat("wrote qual_cube.html\n")
