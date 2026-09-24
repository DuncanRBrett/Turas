# ==============================================================================
# PIPELINE FIXTURE - Confidence Module
# ==============================================================================
# Builds a small weighted study (data workbook + config workbook) in a temp
# directory and runs run_confidence_analysis() on it in a CHILD Rscript, the
# way the GUI does: script_dir_override stays set for the whole run, or the
# HTML report cannot find its submodules. Nothing the run sets can leak into
# the test runner's session.
#
# Sourced explicitly by test_pipeline_end_to_end.R (the runner only picks up
# test*.R files).
#
# THE STUDY (n = 90)
#   aware   1,1,2 repeating                proportion of code 1
#   aware2  copy of aware                  same, filtered to region 1
#   sat     3,4,5,5,2,1 repeating, 2 NA    mean
#   nps     10,9,8,7,6,3,0,10,9,5          NPS (9-10 promoters, 0-6 detractors)
#   allna   all missing                    skipped -> run must be PARTIAL
#   region  1,2 repeating                  filter and margin variable
#   w       0.5,1,1.5,2,3.7 repeating      fractional Kish n_eff on purpose
# Plus two rows (91, 92) whose weight is 0 and missing. Every analysis drops
# them, so each reference is computed on the 90 rows with a usable weight,
# and the stats pack must report 90 respondents and 2 excluded.
# ==============================================================================

confidence_pipeline_data <- function() {
  n <- 90
  sat <- rep(c(3, 4, 5, 5, 2, 1), 15)
  sat[c(5, 50)] <- NA
  aware <- rep(c(1, 1, 2), 30)
  d <- data.frame(
    id = seq_len(n),
    aware = aware,
    aware2 = aware,
    sat = sat,
    nps = rep(c(10, 9, 8, 7, 6, 3, 0, 10, 9, 5), 9),
    allna = rep(NA_real_, n),
    region = rep(c(1, 2), 45),
    w = rep(c(0.5, 1, 1.5, 2, 3.7), 18)
  )
  rbind(d, data.frame(id = 91:92, aware = 1, aware2 = 1, sat = 5, nps = 10,
                      allna = NA_real_, region = 1, w = c(0, NA)))
}

build_confidence_pipeline_fixture <- function(dir, seed = "42") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  d <- confidence_pipeline_data()

  save_wb <- function(wb, path) {
    if (exists("turas_saveWorkbook", mode = "function")) {
      turas_saveWorkbook(wb, path, overwrite = TRUE)
    } else {
      openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
    }
  }

  data_wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(data_wb, "Data")
  openxlsx::writeData(data_wb, "Data", d)
  save_wb(data_wb, file.path(dir, "data.xlsx"))

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "File_Paths")
  openxlsx::writeData(wb, "File_Paths", data.frame(
    Setting = c("Data_File", "Output_File", "Weight_Variable"),
    Value = c("data.xlsx", "out.xlsx", "w")))
  openxlsx::addWorksheet(wb, "Study_Settings")
  openxlsx::writeData(wb, "Study_Settings", data.frame(
    Setting = c("Calculate_Effective_N", "Multiple_Comparison_Adjustment",
                "Multiple_Comparison_Method", "Bootstrap_Iterations",
                "Confidence_Level", "Decimal_Separator", "Generate_HTML_Report",
                "Generate_Stats_Pack", "Sampling_Method", "random_seed"),
    Value = c("Y", "N", "None", "1000", "0.95", ".", "Y", "Y", "Quota", seed)))
  openxlsx::addWorksheet(wb, "Question_Analysis")
  openxlsx::writeData(wb, "Question_Analysis", data.frame(
    Question_ID     = c("aware", "aware2", "sat", "nps", "allna"),
    Question_Label  = c("=SUM(A1) Café & <b>aware</b>", "Aware, region 1",
                        "Satisfaction", "Recommend", "Never asked"),
    Statistic_Type  = c("proportion", "proportion", "mean", "nps", "proportion"),
    Categories      = c("1", "1", NA, NA, "1"),
    Promoter_Codes  = c(NA, NA, NA, "9,10", NA),
    Detractor_Codes = c(NA, NA, NA, "0,1,2,3,4,5,6", NA),
    Filter_Variable = c(NA, "region", NA, NA, NA),
    Filter_Values   = c(NA, "1", NA, NA, NA),
    Run_MOE         = "Y",
    Run_Wilson      = c("Y", "Y", "N", "N", "Y"),
    Run_Bootstrap   = "Y",
    Run_Credible    = "Y",
    Prior_Mean      = NA, Prior_SD = NA, Prior_N = NA,
    stringsAsFactors = FALSE))
  openxlsx::addWorksheet(wb, "Population_Margins")
  openxlsx::writeData(wb, "Population_Margins", data.frame(
    Variable = "region", Category_Label = c("North", "South"),
    Category_Code = c("1", "2"), Target_Prop = c(0.45, 0.55)))
  save_wb(wb, file.path(dir, "config.xlsx"))

  list(dir = dir, config_path = file.path(dir, "config.xlsx"), data = d)
}

run_confidence_child <- function(turas_root, config_path) {
  script <- tempfile(fileext = ".R")
  writeLines(c(
    sprintf("setwd(%s)", deparse(turas_root)),
    "source(file.path('modules', 'shared', 'lib', 'import_all.R'))",
    sprintf("script_dir_override <- %s",
            deparse(file.path(turas_root, "modules", "confidence", "R"))),
    "source(file.path(script_dir_override, '00_main.R'))",
    sprintf("res <- run_confidence_analysis(%s, verbose = TRUE)", deparse(config_path)),
    sprintf("saveRDS(list(html = res$html_report$status, run = res$run_result$status), %s)",
            deparse(file.path(dirname(config_path), "child_result.rds")))
  ), script)
  on.exit(unlink(script), add = TRUE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), shQuote(script),
    stdout = TRUE, stderr = TRUE,
    env = c(paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep)),
            "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE")))
  status <- attr(out, "status")
  list(status = if (is.null(status)) 0L else status, log = out)
}

# Rows of an HTML detail table for one question: method -> first two numbers
# (lower, upper), as the report prints them.
html_detail_rows <- function(html, q_id) {
  start <- regexpr(sprintf('id="ci-detail-%s"', q_id), html, fixed = TRUE)
  if (start < 0) return(NULL)
  rest <- substring(html, start + 1)
  nxt <- regexpr('id="ci-detail-', rest, fixed = TRUE)
  block <- if (nxt > 0) substring(rest, 1, nxt) else rest
  pat <- paste0('<td class="ci-td ci-label-col">([^<]+)</td>\\s*',
                '<td class="ci-td ci-num">([^<]+)</td>\\s*',
                '<td class="ci-td ci-num">([^<]+)</td>')
  m <- regmatches(block, gregexpr(pat, block, perl = TRUE))[[1]]
  if (length(m) == 0) return(NULL)
  parts <- regmatches(m, regexec(pat, m, perl = TRUE))
  num <- function(x) as.numeric(gsub("[%+]", "", x))
  data.frame(
    method = vapply(parts, `[`, "", 2),
    lower = vapply(parts, function(p) num(p[3]), 0),
    upper = vapply(parts, function(p) num(p[4]), 0),
    stringsAsFactors = FALSE
  )
}
