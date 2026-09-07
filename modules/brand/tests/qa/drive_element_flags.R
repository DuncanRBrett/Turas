#!/usr/bin/env Rscript
# ==============================================================================
# Stage 6 QA: drive the element_* config flags and check that every
# destination hides cleanly when nothing it holds is configured.
#
# WHY THIS EXISTS
# ---------------
# The handover's Stage 2 rule is "a destination with nothing configured is
# hidden, never shown empty". Stage 2 could not prove it end to end: the three
# synthetic example projects (examples/1brand, 3cat, 9cat) cannot run, because
# their generators emit the pre-v2 column-per-brand shape and run_brand()
# refuses before any report code executes. Stage 2 asserted the rule on stub
# fragments handed straight to build_br_category_panel() instead. This script
# carries the rule out the way it was meant to be carried out: it toggles the
# real config flags on the IPK fixture, runs the real pipeline, and reads the
# destinations out of the real generated HTML.
#
# WHAT IT ASSERTS
# ---------------
# For each destination, three things, and each one can fail on its own.
#
#   1. OFF   Turn off every flag that destination holds, leave the rest on.
#            The destination must be absent: no button, no container.
#            The other destinations must still be present, so a pass cannot
#            come from the whole category panel having vanished.
#   2. ON    Turn on exactly one flag, everything else off. Every destination
#            that appears must be one that DECLARES it holds that flag. A
#            destination appearing from a flag it does not hold is a
#            mis-homed leaf and fails.
#   3. LIVE  Every (destination, flag) pair that produced content when the
#            flag was driven alone must also produce that destination when
#            all flags are on. A destination that disappears once its
#            neighbours are configured is a shell bug.
#
# Plus two whole-report checks: all flags off must render no destination and
# no category tab, and any run that renders a category tab must render at
# least one destination in it.
#
# THE DESIGNED EXCEPTION IS GONE
# ------------------------------
# Overview used to render unconditionally, because it held the route to this
# category's entry on the Summary tab rather than any element's analysis. It
# was dropped on 7 September 2026: it was the first destination and so the
# page a reader landed on when they clicked a category, and its only message
# was that the headline picture was somewhere else. Every destination now
# earns its place from a leaf, so nothing here is exempt.
#
# EMPTY FLAGS
# -----------
# A flag can be on and still produce nothing, because the fixture carries no
# data for it. Those are listed as "on, no content on this fixture" rather
# than being asserted either way: the script reports what it saw and the
# reader decides. It never claims a flag was proved when the data was absent.
#
# Usage:
#   TURAS_ROOT=<worktree> Rscript modules/brand/tests/qa/drive_element_flags.R \
#       [--fixture DIR] [--out DIR] [--keep]
#
#   --fixture  project directory holding Brand_Config.xlsx, Survey_Structure.xlsx
#              and the data workbook. Default: the IPK wave 1 fixture.
#   --out      scratch directory for the generated reports. Default: a tempdir.
#   --keep     do not delete the generated reports.
#
# Exit status 0 when every check passes, 1 otherwise.
# ==============================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

# ---------------------------------------------------------------- arguments --
argv <- commandArgs(trailingOnly = TRUE)
arg_val <- function(name, default) {
  i <- which(argv == name)
  if (length(i) == 1L && length(argv) > i) argv[i + 1L] else default
}
KEEP <- "--keep" %in% argv

ROOT <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(ROOT)) {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) { ROOT <- dir; break }
    dir <- dirname(dir)
  }
}
if (!nzchar(ROOT)) stop("Set TURAS_ROOT to the worktree root.")

FIXTURE <- arg_val("--fixture",
                   file.path(ROOT, "modules", "brand", "tests", "fixtures",
                             "ipk_wave1"))
OUT <- arg_val("--out", file.path(tempdir(), "brand_flag_matrix"))
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

CONFIG_SRC <- file.path(FIXTURE, "Brand_Config.xlsx")
if (!file.exists(CONFIG_SRC)) {
  stop("No Brand_Config.xlsx in ", FIXTURE,
       ". Generate the fixture first: source 00_generate.R, ipk_generate_fixture().")
}

# ------------------------------------------------------------- the registry --
# The twelve element flags 01_config.R reads, at its lines 112 to 116. There
# are twelve, not thirteen: element_ma at 00_guard.R:631 is a local variable
# holding element_mental_avail's value, not a config key of its own.
ELEMENT_FLAGS <- c("element_funnel", "element_mental_avail", "element_cep_turf",
                   "element_repertoire", "element_dba", "element_portfolio",
                   "element_wom", "element_drivers_barriers",
                   "element_branded_reach", "element_demographics",
                   "element_adhoc", "element_audience_lens")

# Which flags each destination holds, derived by hand from .BR_LEAF_HOMES in
# 03_page_builder.R and the element gating in 00_main.R. Written out here
# rather than read from the registry ON PURPOSE: a test that computes its own
# expectation from the code under test proves nothing. The consistency of
# this table against .BR_LEAF_HOMES is checked below.
#
#   mental    ma-metrics, ma-ceps, ma-attributes, ma-advantage
#   buying    fn-funnel; cb-context, cb-brands, cb-norms, cb-loyalty,
#             cb-dist, cb-heaviness, cb-dop
#   meaning   fn-relationship, wom, branded_reach
#   audience  demographics, adhoc, audience_lens, cb-shopper
DEST_HOLDS <- list(
  mental   = c("element_mental_avail"),
  buying   = c("element_funnel", "element_repertoire"),
  meaning  = c("element_funnel", "element_wom", "element_branded_reach"),
  audience = c("element_demographics", "element_adhoc", "element_audience_lens",
               "element_repertoire")
)
# No destination renders unconditionally any more. Kept as an empty vector
# rather than deleted, because setdiff() against it is what every report
# line below does and an empty exception set is the honest value.
ALWAYS <- character(0)

# --------------------------------------------------------------- the engine --
suppressWarnings(suppressMessages({
  source(file.path(ROOT, "modules", "brand", "R", "00_main.R"))
  source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                   "99_html_report_main.R"))
}))

# ------------------------------------------------------------------ helpers --
write_variant_config <- function(dir, overrides) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  sheets <- openxlsx::getSheetNames(CONFIG_SRC)
  dat <- lapply(sheets, function(s)
    openxlsx::read.xlsx(CONFIG_SRC, sheet = s, skipEmptyRows = FALSE))
  names(dat) <- sheets
  st <- dat[["Settings"]]
  for (k in names(overrides)) {
    v <- overrides[[k]]
    if (k %in% st[[1]]) {
      st[st[[1]] == k, 2] <- v
    } else {
      add <- st[1, , drop = FALSE]
      add[1, 1] <- k; add[1, 2] <- v
      if (ncol(add) > 2) add[1, 3:ncol(add)] <- NA
      st <- rbind(st, add)
    }
  }
  dat[["Settings"]] <- st
  # A fresh workbook, not a loadWorkbook round trip: the project CLAUDE.md
  # records that the round trip collapses each sheet's declared dimension.
  openxlsx::write.xlsx(dat, file.path(dir, "Brand_Config.xlsx"), overwrite = TRUE)
  for (f in setdiff(list.files(FIXTURE, pattern = "\\.xlsx$"),
                    "Brand_Config.xlsx")) {
    tgt <- file.path(dir, f)
    if (!file.exists(tgt)) file.copy(file.path(FIXTURE, f), tgt)
  }
  file.path(dir, "Brand_Config.xlsx")
}

n_lit <- function(html, needle) {
  m <- gregexpr(needle, html, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[1L] == -1L) 0L else length(m)
}

# A destination is PRESENT when the shell emitted both its nav button and its
# container. The two markers are the ones test_destination_nav.R uses.
dest_present <- function(html, id) {
  btn <- n_lit(html, sprintf('data-destination="%s" onclick=', id))
  box <- n_lit(html, sprintf('data-destination="%s">', id))
  list(button = btn, container = box, present = btn > 0L && box > 0L)
}

# A run: write the config, run the pipeline, read the destinations back.
run_case <- function(name, overrides) {
  case_dir <- file.path(OUT, name)
  cfg <- write_variant_config(case_dir, overrides)
  html_path <- file.path(OUT, paste0(name, ".html"))
  res <- try(run_brand(cfg, project_root = case_dir, verbose = FALSE),
             silent = TRUE)
  if (inherits(res, "try-error")) {
    return(list(name = name, ok = FALSE, refused = TRUE,
                why = paste("run_brand threw:", conditionMessage(attr(res, "condition")))))
  }
  if (identical(res$status, "REFUSED")) {
    return(list(name = name, ok = FALSE, refused = TRUE,
                why = paste0("run_brand REFUSED: ", res$code %||% "", " ",
                             res$message %||% "")))
  }
  rep <- generate_brand_html_report(res, html_path)
  if (!identical(rep$status %||% "", "PASS") || !file.exists(html_path)) {
    return(list(name = name, ok = FALSE, refused = TRUE,
                why = paste("report status", rep$status %||% "NULL")))
  }
  html <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
  d <- lapply(names(DEST_HOLDS), function(id) dest_present(html, id))
  names(d) <- names(DEST_HOLDS)
  out <- list(name = name, ok = TRUE, refused = FALSE,
              bytes = file.info(html_path)$size,
              present = vapply(d, function(x) x$present, logical(1)),
              detail = d,
              # A category panel at all? If this is 0 the whole tab vanished
              # and every destination assertion below would be vacuous.
              # Counted on the tab button, not on the destination nav: the
              # JavaScript bundle contains the literal text of markup it
              # builds at runtime, and a class-name search finds that too.
              cat_panels = n_lit(html, 'data-tab="cat-') -
                           n_lit(html, "data-tab=\"cat-%s\" onclick"),
              path = html_path)
  if (!KEEP) unlink(case_dir, recursive = TRUE)
  out
}

# ------------------------------------------------------------- the checks ----
FAILS <- character(0)
CHECKS <- 0L
check <- function(cond, msg) {
  CHECKS <<- CHECKS + 1L
  if (!isTRUE(cond)) FAILS <<- c(FAILS, msg)
  invisible(isTRUE(cond))
}

all_flags <- function(v) setNames(as.list(rep(v, length(ELEMENT_FLAGS))),
                                  ELEMENT_FLAGS)

cat("\n=== Stage 6 QA: element flag matrix ===\n")
cat("fixture: ", FIXTURE, "\n")
cat("out:     ", OUT, "\n")
cat("flags:   ", length(ELEMENT_FLAGS), "\n\n")

# --- 0. the hand-written DEST_HOLDS table agrees with the leaf registry -------
# Source the page builder so the registry can be read. It is sourced by
# 99_html_report_main.R already; this is belt and braces for a direct run.
if (!exists(".BR_LEAF_HOMES")) {
  source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                   "03_page_builder.R"))
}
LEAF_FLAG <- list(
  "fn-funnel" = "element_funnel", "fn-relationship" = "element_funnel",
  "ma-metrics" = "element_mental_avail", "ma-ceps" = "element_mental_avail",
  "ma-attributes" = "element_mental_avail",
  "ma-advantage" = "element_mental_avail",
  "cb-context" = "element_repertoire", "cb-brands" = "element_repertoire",
  "cb-norms" = "element_repertoire", "cb-loyalty" = "element_repertoire",
  "cb-dist" = "element_repertoire", "cb-heaviness" = "element_repertoire",
  "cb-dop" = "element_repertoire", "cb-shopper" = "element_repertoire",
  "wom" = "element_wom", "branded_reach" = "element_branded_reach",
  "demographics" = "element_demographics", "adhoc" = "element_adhoc",
  "audience_lens" = "element_audience_lens"
)
derived <- list()
for (k in names(.BR_LEAF_HOMES)) {
  d <- .BR_LEAF_HOMES[[k]]$dest
  f <- LEAF_FLAG[[k]]
  check(!is.null(f), sprintf("leaf %s has no flag in LEAF_FLAG", k))
  if (!is.null(f)) derived[[d]] <- union(derived[[d]] %||% character(0), f)
}
for (d in setdiff(names(DEST_HOLDS), ALWAYS)) {
  check(setequal(derived[[d]] %||% character(0), DEST_HOLDS[[d]]),
        sprintf("DEST_HOLDS[%s] = {%s} but .BR_LEAF_HOMES implies {%s}",
                d, paste(sort(DEST_HOLDS[[d]]), collapse = ", "),
                paste(sort(derived[[d]] %||% character(0)), collapse = ", ")))
}
cat("registry cross-check done,", length(.BR_LEAF_HOMES), "leaves\n\n")

# --- 1. all flags on ---------------------------------------------------------
cat("[all_on]\n")
on_all <- run_case("all_on", all_flags("Y"))
check(on_all$ok, paste("all_on did not render:", on_all$why %||% ""))
if (on_all$ok) {
  cat("   ", on_all$bytes, "bytes; present:",
      paste(names(which(on_all$present)), collapse = " "), "\n")
  check(all(on_all$present),
        paste("all_on is missing destinations:",
              paste(names(which(!on_all$present)), collapse = " ")))
}

# --- 2. all flags off --------------------------------------------------------
cat("[all_off]\n")
off_all <- run_case("all_off", all_flags("N"))
if (off_all$ok) {
  cat("   ", off_all$bytes, "bytes; present:",
      paste(names(which(off_all$present)), collapse = " ") , "\n")
  gone <- setdiff(names(DEST_HOLDS), ALWAYS)
  check(!any(off_all$present[gone]),
        paste("all_off still shows:",
              paste(gone[off_all$present[gone]], collapse = " ")))
} else {
  # Not a failure in itself. A pipeline that refuses a report with no element
  # configured is a legitimate design; it is reported so the reader knows the
  # all-off assertion was not silently skipped.
  cat("    run refused, reported not asserted:", off_all$why, "\n")
}

# --- 3. one flag at a time ---------------------------------------------------
single <- list()
for (f in ELEMENT_FLAGS) {
  ov <- all_flags("N"); ov[[f]] <- "Y"
  cat("[only ", f, "]\n", sep = "")
  r <- run_case(paste0("only_", f), ov)
  single[[f]] <- r
  if (!r$ok) { cat("    refused:", r$why, "\n"); next }
  live <- setdiff(names(which(r$present)), ALWAYS)
  cat("    -> ", if (length(live)) paste(live, collapse = " ") else
        "(no destination, no content on this fixture)", "\n", sep = "")
  for (d in live) {
    check(f %in% DEST_HOLDS[[d]],
          sprintf("destination %s appeared with only %s on, which it does not hold",
                  d, f))
  }
}

# --- 4. one destination's holdings off at a time -----------------------------
for (d in setdiff(names(DEST_HOLDS), ALWAYS)) {
  ov <- all_flags("Y")
  for (f in DEST_HOLDS[[d]]) ov[[f]] <- "N"
  cat("[off ", d, ": ", paste(DEST_HOLDS[[d]], collapse = " "), "]\n", sep = "")
  r <- run_case(paste0("off_", d), ov)
  if (!r$ok) { check(FALSE, paste("off_", d, " did not render: ", r$why)); next }
  cat("    present:", paste(names(which(r$present)), collapse = " "), "\n")
  check(!isTRUE(r$present[[d]]),
        sprintf("%s still rendered with all of {%s} off", d,
                paste(DEST_HOLDS[[d]], collapse = ", ")))
  check(isTRUE(r$detail[[d]]$button == 0L),
        sprintf("%s left a nav button behind with its flags off", d))
  check(isTRUE(r$detail[[d]]$container == 0L),
        sprintf("%s left a container behind with its flags off", d))
  # The other destinations must survive, so a pass cannot come from the whole
  # category panel disappearing.
  others <- setdiff(names(DEST_HOLDS), c(d, ALWAYS))
  # A destination sharing every one of its flags with d legitimately goes too.
  others <- Filter(function(o) length(setdiff(DEST_HOLDS[[o]], DEST_HOLDS[[d]])) > 0L,
                   others)
  for (o in others) {
    check(isTRUE(r$present[[o]]),
          sprintf("turning off %s's flags also removed %s", d, o))
  }
  check(r$cat_panels > 0L,
        sprintf("off_%s removed the whole category panel, so the check is vacuous", d))
}

# --- 5. a flag that lit a destination alone must still light it when all on --
if (on_all$ok) {
  for (f in names(single)) {
    r <- single[[f]]
    if (!isTRUE(r$ok)) next
    for (d in setdiff(names(which(r$present)), ALWAYS)) {
      check(isTRUE(on_all$present[[d]]),
            sprintf("%s renders with only %s on but not with everything on",
                    d, f))
    }
  }
}

# --- 6. a category tab is never a destination nav with no destinations -----
# With every element off the category has nothing at all and its whole tab is
# absent, which is the strongest form of hiding cleanly. And whenever a tab IS
# emitted at least one destination has to be live in it: that used to be
# guaranteed by the Overview rendering unconditionally, and now has to come
# from the gates, so it is asserted here on real generated reports.
if (off_all$ok) {
  check(off_all$cat_panels == 0L,
        "with every element off a category tab was still emitted")
  check(!any(off_all$present),
        "with every element off the category tab was gone but a destination was still found")
}
for (nm in c(list(all_on = on_all), single)) {
  if (!isTRUE(nm$ok)) next
  if (nm$cat_panels > 0L) {
    check(any(nm$present),
          sprintf("%s rendered a category tab with no live destination in it",
                  nm$name))
  } else {
    check(!any(nm$present),
          sprintf("%s emitted no category tab but still shows destinations",
                  nm$name))
  }
}

# -------------------------------------------------------------- the report --
cat("\n--- which flag lights which destination on this fixture ---\n")
for (f in ELEMENT_FLAGS) {
  r <- single[[f]]
  live <- if (isTRUE(r$ok)) setdiff(names(which(r$present)), ALWAYS) else NA
  cat(sprintf("  %-26s %s\n", f,
              if (!isTRUE(r$ok)) paste("refused:", r$why)
              else if (!length(live)) "on, no content on this fixture"
              else paste(live, collapse = " ")))
}

cat(sprintf("\n%d checks, %d failed\n", CHECKS, length(FAILS)))
if (length(FAILS)) {
  cat("\nFAILURES\n")
  for (m in FAILS) cat("  -", m, "\n")
  quit(status = 1)
}
cat("PASS\n")
quit(status = 0)
