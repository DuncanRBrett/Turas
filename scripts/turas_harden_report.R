#!/usr/bin/env Rscript
# ==============================================================================
# TURAS: harden a composed report from outside R
# ==============================================================================
#
#   Rscript scripts/turas_harden_report.R <input.html> [output.html]
#
# It lives in scripts/ and not in modules/shared/lib/ deliberately. Several
# tests source every .R file in that directory, and this one RUNS when sourced:
# it would refuse for want of an argument and call quit(), taking the test run
# down with it. scripts/ is where the repo keeps things meant to be executed.
#
# The hardening step for a report that Turas did not write on its own. A
# composed report is one where a later step stitches finished pages into a
# Turas report: the VAS integrated report is the first, and there will be
# others. That stitching happens outside R, so the hardening has to be callable
# from outside R too.
#
# The rule this exists to enforce: COMPOSE FIRST, HARDEN LAST. Hardening cannot
# be applied twice, so a composed report has to be built from the working copy
# of its Turas report and hardened once, at the end, over the whole thing.
# Doing it the other way round is what shipped the VAS integrated report with
# nineteen readable pages inside an otherwise protected file.
#
# Pages carried as islands are hardened too, if the composing step marked them
# data-embed="document". See step 2c in turas_minify.R.
#
# Exit codes:
#   0  the deliverable was written
#   1  refused, or failed. The reason is on stdout, in the usual TRS shape.
#
# Nothing is written to the output path unless hardening succeeded, so a caller
# can treat a non-zero exit as "there is no client file" without checking.
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)

.die <- function(...) {
  cat("\n")
  cat(strrep("=", 71), "\n", sep = "")
  cat(" REFUSED - ", ..., "\n", sep = "")
  cat(strrep("=", 71), "\n", sep = "")
  cat("\n")
  quit(save = "no", status = 1L)
}

if (length(args) < 1L || !nzchar(args[1])) {
  .die("no input file\n",
       " Usage: Rscript scripts/turas_harden_report.R <input.html> [output.html]")
}

input_path <- args[1]
output_path <- if (length(args) >= 2L && nzchar(args[2])) args[2] else NULL

if (!file.exists(input_path)) {
  .die("the file to harden does not exist\n Looked for: ", input_path)
}

# Where this script lives, so it can find its siblings whatever the caller's
# working directory is. Finder-launched callers do not get a useful one.
.self <- (function() {
  a <- commandArgs(trailingOnly = FALSE)
  m <- grep("^--file=", a, value = TRUE)
  if (length(m)) return(normalizePath(sub("^--file=", "", m[1])))
  NA_character_
})()
# scripts/ sits beside modules/, so the library is one level up and across.
lib_dir <- if (!is.na(.self)) {
  file.path(dirname(dirname(.self)), "modules", "shared", "lib")
} else {
  home <- Sys.getenv("TURAS_HOME", unset = getwd())
  file.path(home, "modules", "shared", "lib")
}

if (!dir.exists(lib_dir)) {
  .die("cannot find the Turas shared library\n Looked in: ", lib_dir,
       "\n Set TURAS_HOME to the Turas checkout and run this again.")
}

# The node tools live where a login shell finds them, but a process started by
# something other than a shell may not have them on PATH. Adding the two usual
# locations is cheaper than a build that refuses for a tool that is installed.
# .minify_check_tools() still does the finding, and still refuses by name if a
# tool is genuinely absent.
.extra_path <- c("/opt/homebrew/bin", "/usr/local/bin")
.have <- strsplit(Sys.getenv("PATH"), .Platform$path.sep, fixed = TRUE)[[1]]
.add <- setdiff(.extra_path[dir.exists(.extra_path)], .have)
if (length(.add)) {
  Sys.setenv(PATH = paste(c(.have, .add), collapse = .Platform$path.sep))
}

for (f in c("trs_refusal.R", "turas_minify_verify.R", "turas_minify_watermark.R",
            "turas_release_audit.R", "turas_minify.R")) {
  p <- file.path(lib_dir, f)
  if (!file.exists(p)) .die("the shared library is incomplete\n Missing: ", p)
  source(p, local = FALSE)
}

client <- Sys.getenv("TURAS_CLIENT_NAME", unset = "")
client <- if (nzchar(client)) client else NULL

# TURAS_DELIVERY_CLIENT_SAFE is the declaration the release audit enforces. It
# is deliberately opt-in and off by default: a composed report that has not been
# built as client-safe must not claim to be one. Note that the audit checks for
# a respondent ISLAND, so it cannot see respondent data held some other way, for
# instance as a JavaScript constant inside an embedded page. Declaring a
# composed report client-safe is not enough on its own to make it one.
client_safe <- identical(toupper(Sys.getenv("TURAS_DELIVERY_CLIENT_SAFE",
                                            unset = "FALSE")),
                         "TRUE")

cat(sprintf("\n  Hardening %s\n", basename(input_path)))
if (!is.null(client)) cat(sprintf("  Watermark: %s\n", client))
if (client_safe) cat("  Declared client-safe: the release audit will enforce it\n")

result <- tryCatch(
  turas_minify(input_path,
               output_path = output_path,
               keep_dev_copy = FALSE,
               watermark = client,
               client_safe = client_safe,
               deliverable = TRUE,
               verbose = TRUE),
  # A refusal already carries its code, problem and fix, and turas_minify() has
  # printed the boxed version to the console. Repeating it here would say the
  # same thing twice, so this only sets the exit code the caller reads.
  turas_refusal = function(e) {
    cat(conditionMessage(e), "\n")
    NULL
  },
  error = function(e) {
    cat("\n+-- TURAS ERROR ----------------------------------------------+\n")
    cat("| Context:    Harden a composed report\n")
    cat("| Code:       CALC_HARDEN_FAILED\n")
    cat("| Message:   ", conditionMessage(e), "\n")
    cat("+-------------------------------------------------------------+\n\n")
    NULL
  }
)

if (is.null(result) || identical(result$status, "REFUSED")) {
  cat("\n  No client file was written.\n\n")
  quit(save = "no", status = 1L)
}

# PARTIAL is a real outcome, not a failure: it means something warned. The
# warnings are already on the console. The file was written, so this exits 0
# and lets the caller decide, but it says so plainly rather than reporting a
# clean run.
if (identical(result$status, "PARTIAL")) {
  cat(sprintf("\n  Written WITH WARNINGS (%d). Read them above before sending this file.\n",
              length(result$warnings)))
}

cat(sprintf("\n  Hardened: %s\n", basename(result$output_path)))
cat(sprintf("  %.1f MB in, %.1f MB out\n",
            result$input_size_kb / 1024, result$output_size_kb / 1024))
if (isTRUE(result$island_documents_hardened > 0L)) {
  cat(sprintf("  Embedded pages hardened: %d\n", result$island_documents_hardened))
}
cat("\n")

quit(save = "no", status = 0L)
