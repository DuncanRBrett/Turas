#!/usr/bin/env Rscript
# ==============================================================================
# Stage 6 QA: build the three reports every other script in this directory
# expects, into one scratch directory.
#
#   committed.html   the committed IPK wave 1 fixture, unchanged. The gated
#                    instrument, the nested funnel, fifteen of the nineteen
#                    leaves. This is the report the suite's own numbers and
#                    the reachability baseline belong to.
#   extras.html      the same fixture regenerated with `extras = TRUE`, which
#                    adds Branded Reach, Ad Hoc, Audience Lens and Shopper
#                    Behaviour, so all nineteen leaves render. Still gated.
#                    Two of the four extras re-shape answers the instrument
#                    genuinely collected and two are invented and labelled as
#                    such: see tests/fixtures/ipk_wave1/08_qa_extras.R.
#   ungated.html     the extras fixture with the focal brand cleared from the
#                    awareness slots of 25 respondents who hold an attitude
#                    towards it, which is the row skip logic makes impossible.
#                    detect_instrument_gating() reads it as ungated, so the
#                    report shows four separate measures with conversion
#                    ratios instead of a nested funnel.
#
# Nothing is written into the repository and nothing is written into any
# project folder. The two generated fixtures go under the same --out
# directory as the reports.
#
# Usage:
#   TURAS_ROOT=<worktree> Rscript modules/brand/tests/qa/generate_qa_reports.R \
#       --out /path/to/scratch [--only committed|extras|ungated]
#
# Then, for example:
#   python3 modules/brand/tests/qa/drive_chrome.py /path/to/scratch/extras.html
# ==============================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

argv <- commandArgs(trailingOnly = TRUE)
arg_val <- function(name, default = NULL) {
  i <- which(argv == name)
  if (length(i) == 1L && length(argv) > i) argv[i + 1L] else default
}

ROOT <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(ROOT)) {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) { ROOT <- dir; break }
    dir <- dirname(dir)
  }
}
if (!nzchar(ROOT)) stop("Set TURAS_ROOT to the worktree root.")

OUT <- arg_val("--out")
if (is.null(OUT)) stop("Give --out, a scratch directory. Never a project folder.")
ONLY <- arg_val("--only")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

FIXTURE <- file.path(ROOT, "modules", "brand", "tests", "fixtures", "ipk_wave1")

suppressWarnings(suppressMessages({
  source(file.path(ROOT, "modules", "brand", "R", "00_main.R"))
  source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                   "99_html_report_main.R"))
}))

build <- function(name, project_dir) {
  html <- file.path(OUT, paste0(name, ".html"))
  t0 <- Sys.time()
  res <- run_brand(file.path(project_dir, "Brand_Config.xlsx"),
                   project_root = project_dir, verbose = FALSE)
  if (identical(res$status, "REFUSED")) {
    cat(sprintf("%-10s REFUSED %s %s\n", name, res$code %||% "",
                res$message %||% ""))
    return(invisible(FALSE))
  }
  rep <- generate_brand_html_report(res, html)
  cat(sprintf("%-10s %s  %s bytes  %.0f s  %s\n", name,
              rep$status %||% "NULL",
              format(file.info(html)$size, big.mark = ","),
              as.numeric(difftime(Sys.time(), t0, units = "secs")), html))
  invisible(identical(rep$status, "PASS"))
}

want <- function(n) is.null(ONLY) || identical(ONLY, n)

if (want("committed")) build("committed", FIXTURE)

if (want("extras") || want("ungated")) {
  suppressWarnings(suppressMessages(
    source(file.path(FIXTURE, "00_generate.R"))))
}

if (want("extras")) {
  d <- file.path(OUT, "fixture_extras")
  suppressMessages(ipk_generate_fixture(out_dir = d, extras = TRUE))
  build("extras", d)
}

if (want("ungated")) {
  d <- file.path(OUT, "fixture_ungated")
  suppressMessages(ipk_generate_fixture(out_dir = d, extras = TRUE,
                                        ungated = TRUE))
  build("ungated", d)
}
