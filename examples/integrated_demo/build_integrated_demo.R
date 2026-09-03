# ==============================================================================
# TURAS INTEGRATED DEMO: survey + conjoint + MaxDiff in ONE interactive report
# ==============================================================================
# Builds, from nothing, a complete study for a fictional company, "Karoo Coffee
# Roasters", and runs every module involved so the tabs v2 report carries:
#
#   - the survey crosstabs (NPS, ratings, agreement, buying behaviour) by four
#     banners (region, gender, age, customer segment);
#   - a Conjoint tab (the conjoint module's island) and the per-respondent
#     attribute importance as a crosstabbable Allocation question;
#   - a MaxDiff tab (the maxdiff module's island) and the per-respondent
#     preference shares as a crosstabbable Allocation question;
#   - a Pricing tab (the pricing module's island) and the Gabor-Granger
#     acceptance ladder as a crosstabbable Multi_Mention question;
#   - links to the three standalone simulators, copied beside the report.
#
# The same 600 synthetic respondents answer all four instruments, so the
# module exports join to the survey data by respondent id. Everything is
# synthetic; no client data is involved at any point.
#
# Usage, from the Turas root (about two minutes; HB estimation is the slow part):
#   Rscript examples/integrated_demo/build_integrated_demo.R [turas_root] [out_dir]
#
# Writes into <out_dir> (default examples/integrated_demo/Output):
#   conjoint/   the CBC data, config and the conjoint module's outputs
#   maxdiff/    the MaxDiff design, data, config and the module's outputs
#   pricing/    the pricing data, config and the module's outputs
#   tabs/       the survey data, structure, config, and report/ with the
#               final Karoo_Demo_Crosstabs_report.html and both simulators
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
turas_root <- normalizePath(if (length(args) >= 1) args[1] else getwd())
out_dir <- if (length(args) >= 2) args[2] else file.path(turas_root, "examples", "integrated_demo", "Output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
out_dir <- normalizePath(out_dir)
SEED <- 2026
N_RESP <- 600

setwd(turas_root)
suppressPackageStartupMessages(library(openxlsx))
source(file.path(turas_root, "modules", "shared", "lib", "turas_save_workbook_atomic.R"))
options(turas.example.no_run = TRUE)
source(file.path(turas_root, "examples", "maxdiff", "create_maxdiff_example.R"))
source(file.path(turas_root, "examples", "pricing", "create_pricing_example.R"))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
say <- function(...) cat(sprintf(...), "\n", sep = "")
save_wb <- function(wb, path) turas_saveWorkbook(wb, path, overwrite = TRUE)

say("\n=== TURAS INTEGRATED DEMO ===")
say("Turas root: %s", turas_root)
say("Output:     %s\n", out_dir)

# ==============================================================================
# 1. ONE RESPONDENT FRAME
# ==============================================================================

frame <- karoo_default_respondents(n = N_RESP, seed = SEED)
say("1. %d respondents across %d regions and %d segments",
    nrow(frame), length(unique(frame$Region)), length(unique(frame$Segment)))

# ==============================================================================
# 2. THE SURVEY
# ==============================================================================

set.seed(SEED + 1)
n <- nrow(frame)
seg_shift <- function(map) unname(vapply(frame$Segment, function(s) map[[s]] %||% 0, numeric(1)))
reg_shift <- function(map) unname(vapply(frame$Region, function(r) map[[r]] %||% 0, numeric(1)))
clip <- function(x, lo, hi) pmin(pmax(round(x), lo), hi)

survey <- data.frame(RespID = frame$RespID, Region = frame$Region, Gender = frame$Gender,
                     Age_Group = frame$Age_Group, Segment = frame$Segment,
                     stringsAsFactors = FALSE)
survey$Q001 <- clip(rnorm(n, 7.8, 2.0) + seg_shift(list(Premium = 1.0, Budget = -0.8, "New Customer" = 0.2)) +
                      reg_shift(list("Eastern Cape" = -0.8, "Western Cape" = 0.4)), 0, 10)
survey$Q002 <- clip(rnorm(n, 7.2, 1.7) + seg_shift(list(Premium = 0.8, Budget = -0.5)), 1, 10)
survey$Q003 <- clip(rnorm(n, 7.6, 1.5) + seg_shift(list(Premium = 0.9, Budget = -0.6)), 1, 10)
survey$Q004 <- clip(rnorm(n, 6.3, 1.9) + seg_shift(list(Premium = -0.4, Budget = 0.6)), 1, 10)
survey$Q005 <- clip(rnorm(n, 6.8, 2.0) + reg_shift(list("Eastern Cape" = -1.2, Gauteng = 0.5)), 1, 10)
survey$Q006 <- clip(rnorm(n, 3.4, 1.1) + seg_shift(list(Premium = 0.7, Budget = -0.6)), 1, 5)
survey$Q007 <- clip(rnorm(n, 3.3, 1.1) + seg_shift(list(Premium = 0.8, Budget = -0.5)), 1, 5)
survey$Q008 <- sample(c("Weekly", "Monthly", "Quarterly", "Less often"), n, replace = TRUE,
                      prob = c(.22, .48, .20, .10))
survey$Q009 <- sample(c("Online shop", "Subscription", "In store", "Marketplace"), n, replace = TRUE,
                      prob = c(.40, .28, .22, .10))
say("2. Survey answers simulated (%d questions)", 9L)

# ==============================================================================
# 3. THE CONJOINT (choice-based, 10 sets x 3 alternatives, full profiles)
# ==============================================================================

cj_dir <- file.path(out_dir, "conjoint")
dir.create(cj_dir, showWarnings = FALSE, recursive = TRUE)

cj_attributes <- list(
  Roast = c("Light", "Medium", "Dark"),
  Origin = c("Blend", "Single origin with the farm named"),
  Pack_Size = c("250 g", "500 g", "1 kg"),
  Price_Per_250g = c("R95", "R120", "R145", "R170"),
  Delivery = c("Paid delivery", "Free delivery")
)
cj_labels <- c(Roast = "Roast", Origin = "Origin", Pack_Size = "Pack size",
               Price_Per_250g = "Price per 250 g", Delivery = "Delivery")
# True part-worths, zero-centred within attribute.
cj_true <- list(
  Roast = c(-0.2, 0.5, -0.3),
  Origin = c(-0.45, 0.45),
  Pack_Size = c(-0.1, 0.25, -0.15),
  Price_Per_250g = c(0.9, 0.35, -0.35, -0.9),
  Delivery = c(-0.4, 0.4)
)
# Segment shifts: Budget weighs price more and origin less; Premium the reverse.
cj_seg <- list(
  Budget = list(Price_Per_250g = c(0.6, 0.2, -0.2, -0.6), Origin = c(0.25, -0.25)),
  Premium = list(Price_Per_250g = c(-0.4, -0.15, 0.15, 0.4), Origin = c(-0.4, 0.4),
                 Roast = c(0.1, 0.2, -0.3)),
  "New Customer" = list(Delivery = c(-0.2, 0.2))
)

set.seed(SEED + 2)
n_sets <- 10; n_alts <- 3
cj_rows <- vector("list", n * n_sets * n_alts)
k <- 0
for (r in seq_len(n)) {
  u <- lapply(names(cj_attributes), function(a) {
    base <- cj_true[[a]]
    shift <- cj_seg[[frame$Segment[r]]][[a]] %||% rep(0, length(base))
    base + shift + rnorm(length(base), 0, 0.35)
  })
  names(u) <- names(cj_attributes)
  for (s in seq_len(n_sets)) {
    profiles <- lapply(seq_len(n_alts), function(i) {
      vapply(names(cj_attributes), function(a) sample(seq_along(cj_attributes[[a]]), 1), integer(1))
    })
    tot <- vapply(profiles, function(p) sum(vapply(names(cj_attributes), function(a) u[[a]][p[[a]]], numeric(1))), numeric(1))
    p_choose <- exp(tot - max(tot)); p_choose <- p_choose / sum(p_choose)
    chosen <- sample(n_alts, 1, prob = p_choose)
    for (i in seq_len(n_alts)) {
      k <- k + 1
      row <- list(RespID = frame$RespID[r], choice_set_id = (r - 1) * n_sets + s,
                  alternative_id = i)
      for (a in names(cj_attributes)) row[[a]] <- cj_attributes[[a]][profiles[[i]][[a]]]
      row$chosen <- as.integer(i == chosen)
      cj_rows[[k]] <- row
    }
  }
}
cj_data <- do.call(rbind, lapply(cj_rows, as.data.frame, stringsAsFactors = FALSE))
cj_data_file <- file.path(cj_dir, "Karoo_CBC_Data.csv")
write.csv(cj_data, cj_data_file, row.names = FALSE)
say("3. Conjoint choices simulated: %d rows (%d respondents x %d sets x %d alternatives)",
    nrow(cj_data), n, n_sets, n_alts)

cj_config <- file.path(cj_dir, "Karoo_Conjoint_Config.xlsx")
{
  wb <- createWorkbook()
  st <- data.frame(
    Setting = c("project_name", "analysis_type", "estimation_method", "choice_type",
                "data_file", "output_file", "respondent_id_column", "choice_set_column",
                "alternative_id_column", "chosen_column", "confidence_level",
                "generate_market_simulator", "generate_html_simulator",
                "generate_tabs_export", "tabs_question_code", "generate_stats_pack",
                "brand_colour", "currency_symbol"),
    Value = c("Karoo Coffee Roasters", "choice", "hb", "single",
              "Karoo_CBC_Data.csv", "Karoo_Conjoint_Results.xlsx", "RespID", "choice_set_id",
              "alternative_id", "chosen", "0.95",
              "FALSE", "TRUE", "Y", "CJIMP", "Y", "#0d8a8a", "R"),
    stringsAsFactors = FALSE)
  addWorksheet(wb, "Settings"); writeData(wb, "Settings", st)
  at <- data.frame(
    AttributeName = names(cj_attributes),
    AttributeLabel = unname(cj_labels[names(cj_attributes)]),
    NumLevels = vapply(cj_attributes, length, integer(1)),
    LevelNames = vapply(cj_attributes, paste, character(1), collapse = ", "),
    stringsAsFactors = FALSE)
  addWorksheet(wb, "Attributes"); writeData(wb, "Attributes", at)
  save_wb(wb, cj_config)
}

# ==============================================================================
# 4. THE MAXDIFF (design through the module, then simulated responses)
# ==============================================================================

md_dir <- file.path(out_dir, "maxdiff")
md <- build_maxdiff_example(turas_root, md_dir, respondents = frame,
                            project_name = "Karoo", file_stem = "Karoo_MaxDiff",
                            seed = SEED + 3, verbose = FALSE)
say("4. MaxDiff design generated and choices simulated: %s", basename(md$config))

# ==============================================================================
# 4b. THE PRICING STUDY (the same respondents, priced)
# ==============================================================================

pr_dir <- file.path(out_dir, "pricing")
pr <- build_pricing_example(turas_root, pr_dir, respondents = frame,
                            file_stem = "Karoo_Pricing", seed = SEED + 4,
                            verbose = FALSE, tabs_export = TRUE, simulator = TRUE)
say("4b. Pricing answers simulated and configs written: %s", basename(pr$config))

# ==============================================================================
# 5. RUN THE THREE MODULES
# ==============================================================================

say("\n5a. Running the conjoint module (HB, bayesm)...")
source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))
cj_res <- run_conjoint_analysis(config_file = cj_config, verbose = FALSE)
if (!is.list(cj_res) || is.null(cj_res$utilities)) stop("[DEMO] the conjoint run did not produce utilities; see the messages above")
cj_island <- file.path(cj_dir, "Karoo_Conjoint_Results_cj_island.json")
cj_export <- file.path(cj_dir, "Karoo_Conjoint_Results_tabs_importance.xlsx")
cj_sim <- file.path(cj_dir, "Karoo_Conjoint_Results_simulator.html")
for (f in c(cj_island, cj_export, cj_sim)) if (!file.exists(f)) stop("[DEMO] conjoint did not write ", f)
say("    status %s; importance: %s", cj_res$status,
    paste(sprintf("%s %.0f%%", cj_res$importance$Attribute, cj_res$importance$Importance), collapse = ", "))

say("\n5b. Running the maxdiff module...")
if (!exists("run_maxdiff", mode = "function")) source(file.path(turas_root, "modules", "maxdiff", "R", "00_main.R"))
md_res <- run_maxdiff(md$config, verbose = FALSE)
md_island <- file.path(md_dir, "Output", "Karoo_MaxDiff_Results_md_island.json")
md_export <- file.path(md_dir, "Output", "Karoo_MaxDiff_Results_tabs_shares.xlsx")
md_sim <- file.path(md_dir, "Output", "Karoo_MaxDiff_Results_simulator.html")
for (f in c(md_island, md_export, md_sim)) if (!file.exists(f)) stop("[DEMO] maxdiff did not write ", f)
cs <- md_res$count_scores[order(-md_res$count_scores$Net_Score), ]
say("    status %s; top items by net score: %s", md_res$run_result$status %||% "?",
    paste(head(cs$Item_ID, 3), collapse = ", "))

say("\n5c. Running the pricing module (Van Westendorp and Gabor-Granger)...")
source(file.path(turas_root, "modules", "pricing", "R", "00_main.R"))
pr_res <- run_pricing_analysis(pr$config)
pr_island <- file.path(pr_dir, "Output", "Karoo_Pricing_Results_pr_island.json")
pr_export <- file.path(pr_dir, "Output", "Karoo_Pricing_Results_tabs_pricing.xlsx")
pr_sim <- file.path(pr_dir, "Output", "Karoo_Pricing_Results_simulator.html")
for (f in c(pr_island, pr_export, pr_sim)) if (!file.exists(f)) stop("[DEMO] pricing did not write ", f)
pp <- pr_res$results$van_westendorp$price_points
say("    status %s; VW price points: PMC R%.2f, OPP R%.2f, IDP R%.2f, PME R%.2f",
    pr_res$run_result$status %||% "?", pp$PMC, pp$OPP, pp$IDP, pp$PME)

# ==============================================================================
# 6. JOIN THE THREE EXPORTS TO THE SURVEY DATA BY RESPONDENT ID
# ==============================================================================

cj_shares <- read.xlsx(cj_export, sheet = "DATA")
md_shares <- read.xlsx(md_export, sheet = "DATA")
cj_qm <- read.xlsx(cj_export, sheet = "QUESTIONMAP_SNIPPET", startRow = 2, rows = 2:3)
cj_opts <- read.xlsx(cj_export, sheet = "QUESTIONMAP_SNIPPET", startRow = 6)
md_qm <- read.xlsx(md_export, sheet = "QUESTIONMAP_SNIPPET", startRow = 2, rows = 2:3)
md_opts <- read.xlsx(md_export, sheet = "QUESTIONMAP_SNIPPET", startRow = 6)

# The pricing export's own QuestionMap and Options rows come back on the
# result object, so nothing has to be parsed out of the workbook.
pr_grid <- read.xlsx(pr_export, sheet = "DATA")
pr_qm <- pr_res$tabs_export$questionmap
pr_qm <- pr_qm[pr_qm$QuestionCode == pr_res$tabs_export$question_code, ]
pr_opts <- pr_res$tabs_export$options
pr_code <- pr_res$tabs_export$question_code

survey <- merge(survey, cj_shares, by = "RespID", all.x = TRUE, sort = FALSE)
survey <- merge(survey, md_shares, by = "RespID", all.x = TRUE, sort = FALSE)
survey <- merge(survey, pr_grid, by = "RespID", all.x = TRUE, sort = FALSE)
survey <- survey[order(survey$RespID), ]
say("\n6. Exports joined by RespID: %d of %d have conjoint importance, %d of %d have MaxDiff shares, %d of %d are in the pricing base",
    sum(!is.na(survey$CJIMP_1)), n, sum(!is.na(survey$MDSHARE_1)), n,
    sum(survey$pricing_valid %in% 1), n)

# ==============================================================================
# 7. THE TABS PROJECT: data, structure, config
# ==============================================================================

tabs_dir <- file.path(out_dir, "tabs")
dir.create(tabs_dir, showWarnings = FALSE, recursive = TRUE)

data_path <- file.path(tabs_dir, "Karoo_Demo_Survey_Data.xlsx")
{
  wb <- createWorkbook(); addWorksheet(wb, "Data"); writeData(wb, "Data", survey); save_wb(wb, data_path)
}

q_text <- c(
  Region = "Region", Gender = "Gender", Age_Group = "Age group", Segment = "Customer segment",
  Q001 = "How likely are you to recommend Karoo Coffee Roasters to a friend or colleague?",
  Q002 = "How would you rate your overall satisfaction with Karoo Coffee Roasters?",
  Q003 = "How would you rate the quality of the coffee?",
  Q004 = "How would you rate the value for money?",
  Q005 = "How would you rate your delivery experience?",
  Q006 = "I would pay more for beans roasted this month",
  Q007 = "Knowing which farm the beans come from matters to me",
  Q008 = "How often do you buy from Karoo Coffee Roasters?",
  Q009 = "Where do you usually buy?",
  CJIMP = cj_qm$QuestionText[1],
  MDSHARE = md_qm$QuestionText[1]
)
q_text[[pr_code]] <- pr_qm$QuestionText[1]
q_type <- c(Region = "Single_Response", Gender = "Single_Response", Age_Group = "Single_Response",
            Segment = "Single_Response", Q001 = "NPS", Q002 = "Rating", Q003 = "Rating",
            Q004 = "Rating", Q005 = "Rating", Q006 = "Likert", Q007 = "Likert",
            Q008 = "Single_Response", Q009 = "Single_Response",
            CJIMP = "Allocation", MDSHARE = "Allocation")
q_type[[pr_code]] <- "Multi_Mention"
q_cols <- c(Region = 1, Gender = 1, Age_Group = 1, Segment = 1, Q001 = 1, Q002 = 1, Q003 = 1,
            Q004 = 1, Q005 = 1, Q006 = 1, Q007 = 1, Q008 = 1, Q009 = 1,
            CJIMP = cj_qm$Columns[1], MDSHARE = md_qm$Columns[1])
q_cols[[pr_code]] <- pr_qm$Columns[1]
q_cat <- c(Region = "Demographics", Gender = "Demographics", Age_Group = "Demographics",
           Segment = "Demographics", Q001 = "Overall", Q002 = "Overall", Q003 = "Product",
           Q004 = "Product", Q005 = "Service", Q006 = "Attitudes", Q007 = "Attitudes",
           Q008 = "Buying behaviour", Q009 = "Buying behaviour",
           CJIMP = "What drives choice (conjoint)", MDSHARE = "What matters most (MaxDiff)")
q_cat[[pr_code]] <- "What they would pay (pricing)"
codes <- names(q_text)

questions_df <- data.frame(QuestionCode = codes, QuestionText = unname(q_text[codes]),
                           Variable_Type = unname(q_type[codes]), Columns = unname(q_cols[codes]),
                           Category = unname(q_cat[codes]), stringsAsFactors = FALSE)

opt_rows <- list()
add_opts <- function(qc, opts, disp = NULL, weights = NA, box = NA) {
  if (is.null(disp)) disp <- opts
  opt_rows[[length(opt_rows) + 1]] <<- data.frame(
    QuestionCode = qc, OptionText = opts, DisplayText = disp, ShowInOutput = "Y",
    DisplayOrder = seq_along(opts), Index_Weight = weights, BoxCategory = box,
    ExcludeFromIndex = NA, stringsAsFactors = FALSE)
}
add_opts("Region", c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"))
add_opts("Gender", c("Male", "Female"))
add_opts("Age_Group", c("18 - 24", "25 - 34", "35 - 44", "45 - 54", "55+"))
add_opts("Segment", c("Premium", "Standard", "Budget", "New Customer"))
add_opts("Q001", as.character(0:10), NULL, NA,
         c(rep("Detractor (0-6)", 7), rep("Passive (7-8)", 2), rep("Promoter (9-10)", 2)))
for (qc in c("Q002", "Q003", "Q004", "Q005")) {
  add_opts(qc, as.character(1:10), NULL, 1:10,
           c(rep("Poor (1-3)", 3), rep("Average (4-6)", 3), rep("Good or excellent (7-10)", 4)))
}
for (qc in c("Q006", "Q007")) {
  add_opts(qc, as.character(1:5), c("Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"),
           1:5, c("Negative", "Negative", "Neutral", "Positive", "Positive"))
}
add_opts("Q008", c("Weekly", "Monthly", "Quarterly", "Less often"))
add_opts("Q009", c("Online shop", "Subscription", "In store", "Marketplace"))
add_opts("CJIMP", cj_opts$OptionText)
add_opts("MDSHARE", md_opts$OptionText)
# The pricing ladder is a Multi_Mention, and tabs looks a Multi_Mention's
# options up by COLUMN name ({code}_1, {code}_2, ...), not by the question
# code the way an Allocation does. The export writes its Options rows already
# keyed that way, so they are used as they came.
for (i in seq_len(nrow(pr_opts))) {
  add_opts(pr_opts$QuestionCode[i], pr_opts$OptionText[i])
}
options_df <- do.call(rbind, opt_rows)

structure_path <- file.path(tabs_dir, "Karoo_Demo_Survey_Structure.xlsx")
{
  wb <- createWorkbook()
  addWorksheet(wb, "Project")
  writeData(wb, "Project", data.frame(
    Setting = c("project_name", "project_code", "client_name", "study_type", "study_date", "data_file"),
    Value = c("Karoo Coffee Roasters customer study (demo)", "KAROO_DEMO_2026",
              "Karoo Coffee Roasters (fictional)", "Ad-hoc", "20260901", basename(data_path)),
    stringsAsFactors = FALSE))
  addWorksheet(wb, "Questions"); writeData(wb, "Questions", questions_df)
  addWorksheet(wb, "Options"); writeData(wb, "Options", options_df)
  save_wb(wb, structure_path)
}

banners <- c("Region", "Gender", "Age_Group", "Segment")
selection_df <- data.frame(
  QuestionCode = codes,
  Include = ifelse(codes %in% banners, "N", "Y"),
  UseBanner = ifelse(codes %in% banners, "Y", "N"),
  BannerLabel = ifelse(codes %in% banners,
                       c(Region = "Region", Gender = "Gender", Age_Group = "Age",
                         Segment = "Customer segment")[codes], ""),
  DisplayOrder = ifelse(codes %in% banners, match(codes, banners) + 1L, NA_integer_),
  CreateIndex = "N",
  BaseFilter = "", FilterLabel = "",
  Category = unname(q_cat[codes]),
  stringsAsFactors = FALSE
)

config_path <- file.path(tabs_dir, "Karoo_Demo_Crosstab_Config.xlsx")
{
  settings <- data.frame(
    Setting = c("structure_file", "output_subfolder", "output_filename", "output_format",
                "apply_weighting", "show_unweighted_n", "show_frequency", "show_percent_column",
                "show_percent_row", "decimal_places_percent", "decimal_places_ratings",
                "decimal_places_index", "decimal_places_numeric",
                "boxcategory_frequency", "boxcategory_percent_column",
                "enable_significance_testing", "alpha", "significance_min_base",
                "bonferroni_correction", "create_index_summary", "show_standard_deviation",
                "show_net_positive", "project_title", "brand_colour", "fieldwork_dates",
                "dashboard_scale_mean", "dashboard_green_mean", "dashboard_amber_mean",
                "html_report_v2", "html_report_v2_microdata",
                "conjoint_island", "maxdiff_island", "pricing_island"),
    Value = c(basename(structure_path), "report", "Karoo_Demo_Crosstabs.xlsx", "xlsx",
              "FALSE", "TRUE", "TRUE", "TRUE",
              "FALSE", "0", "1", "1", "1",
              "FALSE", "TRUE",
              "TRUE", "0.05", "30",
              "TRUE", "N", "FALSE",
              "TRUE", "Karoo Coffee Roasters: customer study 2026 (demo, synthetic data)",
              "#0d8a8a", "Synthetic data, September 2026",
              "10", "7", "5",
              "TRUE", "TRUE",
              cj_island, md_island, pr_island),
    stringsAsFactors = FALSE)
  wb <- createWorkbook()
  addWorksheet(wb, "Settings"); writeData(wb, "Settings", settings)
  addWorksheet(wb, "Selection"); writeData(wb, "Selection", selection_df)
  save_wb(wb, config_path)
}
say("7. Tabs project written: %s", tabs_dir)

# ==============================================================================
# 8. RUN TABS, THEN PUT THE SIMULATORS BESIDE THE REPORT
# ==============================================================================

say("\n8. Running tabs...")
source(file.path(turas_root, "modules", "tabs", "run_tabs.R"))
ok <- run_tabs_analysis(config_path)
report_dir <- file.path(tabs_dir, "report")
report <- file.path(report_dir, "Karoo_Demo_Crosstabs_report.html")
if (!isTRUE(ok) || !file.exists(report)) stop("[DEMO] tabs did not write ", report)

# The islands link to their simulators by file name, relative to the report.
file.copy(cj_sim, file.path(report_dir, basename(cj_sim)), overwrite = TRUE)
file.copy(md_sim, file.path(report_dir, basename(md_sim)), overwrite = TRUE)
file.copy(pr_sim, file.path(report_dir, basename(pr_sim)), overwrite = TRUE)

html <- paste(readLines(report, warn = FALSE), collapse = "\n")
say("\n=== DONE ===")
say("Report:              %s (%.1f MB)", report, file.size(report) / 1e6)
say("Conjoint tab:        %s", if (grepl('"kind":"conjoint"', html, fixed = TRUE)) "present" else "MISSING")
say("MaxDiff tab:         %s", if (grepl('"kind":"maxdiff"', html, fixed = TRUE)) "present" else "MISSING")
say("Pricing tab:         %s", if (grepl('"kind":"pricing"', html, fixed = TRUE)) "present" else "MISSING")
say("Conjoint simulator:  %s", file.path(report_dir, basename(cj_sim)))
say("MaxDiff simulator:   %s", file.path(report_dir, basename(md_sim)))
say("Pricing simulator:   %s", file.path(report_dir, basename(pr_sim)))
say("Open the report in a browser. The Conjoint, MaxDiff and Pricing tabs sit in the Read")
say("group. CJIMP and MDSHARE are Allocation questions in the crosstabs and %s is a", pr_code)
say("Multi_Mention, so importance, preference shares and the acceptance ladder can all be")
say("read by region, gender, age and customer segment. The three module tabs are frozen:")
say("they show what was estimated on the whole sample and hide the audience filter.")
