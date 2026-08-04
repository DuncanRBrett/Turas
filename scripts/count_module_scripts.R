# ==============================================================================
# TURAS Module R Script Census
# ==============================================================================
# Counts the R scripts in every folder under modules/, splits them into source
# vs test files, tallies lines of code, and writes a self-contained HTML report.
#
# USAGE:
#   Rscript scripts/count_module_scripts.R
#   Rscript scripts/count_module_scripts.R --out Output/my_report.html
#   Rscript scripts/count_module_scripts.R --no-html      # console only
#   # or from R console:
#   source("scripts/count_module_scripts.R")
#
# WHAT COUNTS AS AN R SCRIPT:
#   Any file whose name ends in .R or .r, at any depth below modules/<module>/.
#   Case is handled with a single regex so a file is never counted twice.
#   A file is classed as a TEST if any part of its path below the module root
#   contains "test" (case-insensitive) - this catches tests/, testthat/ and
#   test_*.R alike. Everything else is SOURCE.
#
# EXIT CODES:
#   0 = Report produced
#   1 = Could not locate the modules directory
# ==============================================================================

# ---------------------------------------------------------------------------
# Find Turas root (same convention as scripts/health_check.R)
# ---------------------------------------------------------------------------
find_turas_root <- function() {
  env_root <- Sys.getenv("TURAS_ROOT", unset = "")
  if (nzchar(env_root) && dir.exists(env_root)) return(normalizePath(env_root))

  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "launch_turas.R"))) return(current)
    current <- dirname(current)
  }
  stop("Cannot locate Turas root. Set TURAS_ROOT or run from the project directory.")
}

turas_root <- find_turas_root()
modules_dir <- file.path(turas_root, "modules")

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default) {
  hit <- which(args == flag)
  if (length(hit) && length(args) > hit[1]) args[hit[1] + 1L] else default
}

write_html <- !("--no-html" %in% args)
out_path <- arg_value("--out", file.path(turas_root, "Output", "module_script_counts.html"))

if (!dir.exists(modules_dir)) {
  cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
  cat("│ Context: count_module_scripts.R\n")
  cat("│ Message: modules directory not found at", modules_dir, "\n")
  cat("│ How to fix: run from the Turas project root, or set TURAS_ROOT\n")
  cat("└───────────────────────────────────────────────────────┘\n\n")
  quit(status = 1L)
}

# ---------------------------------------------------------------------------
# Census
# ---------------------------------------------------------------------------
# One regex, matched once per file, so .R and .r cannot double-count.
R_FILE_PATTERN <- "\\.[Rr]$"

count_lines <- function(path) {
  tryCatch(
    length(readLines(path, warn = FALSE)),
    error = function(e) NA_integer_
  )
}

module_names <- sort(list.dirs(modules_dir, full.names = FALSE, recursive = FALSE))

census <- lapply(module_names, function(mod) {
  mod_dir <- file.path(modules_dir, mod)

  files <- list.files(
    mod_dir,
    pattern = R_FILE_PATTERN,
    recursive = TRUE,
    full.names = FALSE,
    all.files = TRUE,
    no.. = TRUE
  )

  is_test <- grepl("test", files, ignore.case = TRUE)
  lines <- vapply(file.path(mod_dir, files), count_lines, integer(1), USE.NAMES = FALSE)

  list(
    module = mod,
    total = length(files),
    source = sum(!is_test),
    test = sum(is_test),
    lines = if (length(lines)) sum(lines, na.rm = TRUE) else 0L,
    unreadable = sum(is.na(lines))
  )
})

df <- data.frame(
  module = vapply(census, `[[`, character(1), "module"),
  total = vapply(census, `[[`, integer(1), "total"),
  source = vapply(census, `[[`, integer(1), "source"),
  test = vapply(census, `[[`, integer(1), "test"),
  lines = vapply(census, function(x) as.integer(x$lines), integer(1)),
  unreadable = vapply(census, `[[`, integer(1), "unreadable"),
  stringsAsFactors = FALSE
)

df <- df[order(-df$total, df$module), ]
rownames(df) <- NULL

totals <- list(
  modules = nrow(df),
  with_scripts = sum(df$total > 0L),
  total = sum(df$total),
  source = sum(df$source),
  test = sum(df$test),
  lines = sum(df$lines),
  unreadable = sum(df$unreadable)
)

# ---------------------------------------------------------------------------
# Console output
# ---------------------------------------------------------------------------
fmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

cat("\n")
cat("================================================================\n")
cat("  TURAS MODULE R SCRIPT CENSUS\n")
cat(sprintf("  Scanned: %s\n", modules_dir))
cat("================================================================\n\n")

cat(sprintf("  %-18s %8s %8s %8s %10s\n", "MODULE", "TOTAL", "SOURCE", "TEST", "LINES"))
cat(sprintf("  %s\n", strrep("-", 56)))
for (i in seq_len(nrow(df))) {
  cat(sprintf(
    "  %-18s %8s %8s %8s %10s\n",
    df$module[i], fmt_int(df$total[i]), fmt_int(df$source[i]),
    fmt_int(df$test[i]), fmt_int(df$lines[i])
  ))
}
cat(sprintf("  %s\n", strrep("-", 56)))
cat(sprintf(
  "  %-18s %8s %8s %8s %10s\n",
  sprintf("%d modules", totals$modules), fmt_int(totals$total),
  fmt_int(totals$source), fmt_int(totals$test), fmt_int(totals$lines)
))
cat("\n")

if (totals$unreadable > 0L) {
  cat(sprintf("  NOTE: %d file(s) could not be read for line counting.\n",
              totals$unreadable))
  cat("        They are still included in the file counts.\n\n")
}

# ---------------------------------------------------------------------------
# HTML report
# ---------------------------------------------------------------------------
if (!write_html) {
  cat("  (--no-html given: HTML report skipped)\n\n")
} else {
  esc <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    gsub('"', "&quot;", x, fixed = TRUE)
  }

  max_total <- max(df$total, 1L)

  rows <- vapply(seq_len(nrow(df)), function(i) {
    tot <- df$total[i]
    src_pct <- if (tot > 0L) 100 * df$source[i] / tot else 0
    bar_pct <- 100 * tot / max_total
    sprintf(
      paste0(
        '<tr><th scope="row">%s</th>',
        '<td class="num strong">%s</td>',
        '<td class="num">%s</td><td class="num">%s</td>',
        '<td class="num dim">%s</td>',
        '<td class="barcell"><div class="bar" style="width:%.1f%%">',
        '<span class="seg src" style="width:%.1f%%"></span></div></td></tr>'
      ),
      esc(df$module[i]), fmt_int(tot), fmt_int(df$source[i]),
      fmt_int(df$test[i]), fmt_int(df$lines[i]), bar_pct, src_pct
    )
  }, character(1))

  html <- sprintf('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Turas - R Scripts per Module</title>
<style>
  :root {
    --bg: #ffffff; --fg: #1a1d21; --muted: #6b7280; --line: #e5e7eb;
    --panel: #f8f9fb; --src: #2f6f9f; --test: #b9c6d2; --accent: #2f6f9f;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #14171a; --fg: #e8eaed; --muted: #9aa3ad; --line: #2a2f35;
      --panel: #1c2025; --src: #5b9bd5; --test: #3f4b57; --accent: #5b9bd5;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 2.5rem 1.5rem; background: var(--bg); color: var(--fg);
    font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  }
  .wrap { max-width: 900px; margin: 0 auto; }
  h1 { font-size: 1.6rem; margin: 0 0 .3rem; letter-spacing: -.02em; }
  .sub { color: var(--muted); margin: 0 0 2rem; font-size: .9rem; }
  .tiles { display: flex; flex-wrap: wrap; gap: .75rem; margin-bottom: 2rem; }
  .tile {
    flex: 1 1 150px; background: var(--panel); border: 1px solid var(--line);
    border-radius: 8px; padding: .9rem 1rem;
  }
  .tile .v { font-size: 1.75rem; font-weight: 600; letter-spacing: -.02em; }
  .tile .k { color: var(--muted); font-size: .75rem; text-transform: uppercase;
             letter-spacing: .06em; margin-top: .15rem; }
  .scroll { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%%; font-size: .9rem; }
  th, td { padding: .5rem .7rem; border-bottom: 1px solid var(--line); text-align: left; }
  thead th {
    font-size: .72rem; text-transform: uppercase; letter-spacing: .06em;
    color: var(--muted); font-weight: 600; white-space: nowrap;
  }
  tbody th { font-weight: 500; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
  .num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
  .strong { font-weight: 600; }
  .dim { color: var(--muted); }
  .barcell { width: 30%%; min-width: 130px; }
  .bar { height: 10px; border-radius: 3px; background: var(--test); overflow: hidden; }
  .seg.src { display: block; height: 100%%; background: var(--src); }
  tfoot td, tfoot th {
    border-top: 2px solid var(--line); border-bottom: none;
    font-weight: 600; padding-top: .6rem;
  }
  .legend { display: flex; gap: 1.2rem; margin: .8rem 0 2rem; font-size: .8rem; color: var(--muted); }
  .legend i { display: inline-block; width: 10px; height: 10px; border-radius: 2px;
              margin-right: .35rem; vertical-align: middle; }
  .method {
    background: var(--panel); border: 1px solid var(--line); border-left: 3px solid var(--accent);
    border-radius: 6px; padding: .9rem 1.1rem; font-size: .84rem; color: var(--muted);
  }
  .method h2 { font-size: .78rem; text-transform: uppercase; letter-spacing: .06em;
               margin: 0 0 .5rem; color: var(--fg); }
  .method ul { margin: 0; padding-left: 1.1rem; }
  .method li { margin: .25rem 0; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .95em; }
</style>
</head>
<body>
<div class="wrap">

  <h1>R scripts per module</h1>
  <p class="sub">%s &middot; generated %s</p>

  <div class="tiles">
    <div class="tile"><div class="v">%s</div><div class="k">Module folders</div></div>
    <div class="tile"><div class="v">%s</div><div class="k">R scripts</div></div>
    <div class="tile"><div class="v">%s</div><div class="k">Source files</div></div>
    <div class="tile"><div class="v">%s</div><div class="k">Test files</div></div>
    <div class="tile"><div class="v">%s</div><div class="k">Lines of R</div></div>
  </div>

  <div class="scroll">
  <table>
    <thead>
      <tr>
        <th>Module</th><th class="num">Scripts</th><th class="num">Source</th>
        <th class="num">Test</th><th class="num">Lines</th><th>Split</th>
      </tr>
    </thead>
    <tbody>
%s
    </tbody>
    <tfoot>
      <tr>
        <th scope="row">All modules</th>
        <td class="num">%s</td><td class="num">%s</td>
        <td class="num">%s</td><td class="num">%s</td><td></td>
      </tr>
    </tfoot>
  </table>
  </div>

  <div class="legend">
    <span><i style="background:var(--src)"></i>Source</span>
    <span><i style="background:var(--test)"></i>Test</span>
    <span>Bar length is scaled to the largest module.</span>
  </div>

  <div class="method">
    <h2>How these numbers were counted</h2>
    <ul>
      <li>A script is any file matching <code>\\.[Rr]$</code> at any depth below
          <code>modules/&lt;module&gt;/</code>. The single regex means a file is
          never counted twice on a case-insensitive filesystem.</li>
      <li>A file is a <strong>test</strong> if its path below the module root contains
          &ldquo;test&rdquo; in any case &mdash; covering <code>tests/</code>,
          <code>testthat/</code> and <code>test_*.R</code>. Everything else is source.</li>
      <li>Lines are raw line counts, including blanks and comments.</li>
      <li>Regenerate with <code>Rscript scripts/count_module_scripts.R</code>.</li>
    </ul>
  </div>

</div>
</body>
</html>
',
    esc(modules_dir),
    # NOTE: single % here - this is an ARGUMENT to sprintf, not part of the
    # format template, so it must not be %%-escaped the way the CSS is.
    esc(format(Sys.time(), "%Y-%m-%d %H:%M")),
    fmt_int(totals$modules), fmt_int(totals$total), fmt_int(totals$source),
    fmt_int(totals$test), fmt_int(totals$lines),
    paste(rows, collapse = "\n"),
    fmt_int(totals$total), fmt_int(totals$source),
    fmt_int(totals$test), fmt_int(totals$lines)
  )

  out_dir <- dirname(out_path)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  ok <- tryCatch({
    writeLines(html, out_path, useBytes = TRUE)
    TRUE
  }, error = function(e) {
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Context: count_module_scripts.R - writing HTML report\n")
    cat("│ Message:", conditionMessage(e), "\n")
    cat("│ How to fix: check the --out path is writable\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    FALSE
  })

  if (ok) cat(sprintf("  HTML report written to: %s\n\n", out_path))
}
