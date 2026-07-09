# ==============================================================================
# Aggregate-wave tracking backfill (generic; reusable across trackers)
# ==============================================================================
# Turns a tracker's PUBLISHED HISTORY — waves that survive only as summary
# figures (a %, a mean, an NPS net), with no respondent-level data — into the
# prior-wave `<wave>_wave.json` sidecars the v2 report's Tracking tab reads. A
# v2 tabs build (html_report_v2_tracking + waves_source pointed at the output
# folder + the same QuestionMap in Settings) then shows the full history as one
# trend, with the current wave live from its own microdata.
#
# This is the value-only twin of sacs_segment_backfill.R: same island shapes,
# same honest significance, but sourced from a table of figures instead of from
# prior waves' microdata. The only new code it uses is the engine in
# modules/tabs/lib/tracking_aggregate_bridge.R.
#
# ------------------------------------------------------------------------------
# TWO INPUTS YOU PREPARE PER PROJECT (see docs/AGGREGATE_TRACKING_GUIDE.md):
#
# 1. VALUES TABLE (long; .csv or .xlsx) — one row per (metric, wave):
#      metric_id    the LIVE survey QuestionCode this figure belongs to
#                   (e.g. Q02). THIS IS THE LINK to the current wave — it must
#                   equal the QuestionCode in the QuestionMap below.
#      wave         the wave identifier (e.g. 2019). A 4-digit year in it becomes
#                   the trend's x-axis position.
#      metric_type  mean | proportion | nps
#      value        the published figure, as reported (mean, %, NPS net)
#      base         effective base n for that figure — OPTIONAL. Blank = unknown
#                   => the point plots UNTESTED (never a fabricated base).
#      sd           dispersion for a 'mean' — OPTIONAL. Blank = not recorded
#                   => the mean plots untested.
#
# 2. QUESTIONMAP (.xlsx, a "QuestionMap" sheet) — one row per tracked metric:
#      QuestionCode   the canonical/live code (== metric_id above)
#      QuestionText   the display title
#      TrackingSpecs  mean | nps_score | category:<label>
#                       - category:<label> keys a proportion to the crosstab row
#                         with that DISPLAYED label. For a single option use the
#                         option's exact display text; for a NET use the exact
#                         BoxCategory label you gave it in the Options sheet.
#      Wave<YEAR>     the current wave's data column for this metric (usually the
#                       same as QuestionCode). detect_wave_column() matches this
#                       against the live data so the current wave keys by code.
#
# OUTPUT: one `<wave>_wave.json` per wave in AGG_OUT (your waves_source folder).
#
# ------------------------------------------------------------------------------
# RUN (you, then re-run the tabs report):
#   AGG_VALUES=/path/values.csv \
#   AGG_QMAP=/path/QuestionMap.xlsx \
#   AGG_OUT=/path/to/waves_source_folder \
#   Rscript modules/tabs/examples/aggregate_wave_backfill.R
#
# With no env vars it reproduces the CCPB worked example (the defaults below).
# ==============================================================================

TURAS <- Sys.getenv("TURAS_HOME", "/Users/duncan/Dev/Turas")
source(file.path(TURAS, "modules/tabs/lib/tracking_island.R"))            # load_question_mapping, read_wave_contributions, ...
source(file.path(TURAS, "modules/tabs/lib/tracking_aggregate_bridge.R"))  # the engine

# --- Paths (override per project via env vars) --------------------------------
.ccpb <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/CCPB/CSAT/W2026/03 Tracker/v2 tabs tracking"
VALUES <- Sys.getenv("AGG_VALUES", file.path(.ccpb, "ccpb_v2_values.csv"))
QMAP   <- Sys.getenv("AGG_QMAP",   file.path(.ccpb, "CCPB_v2_question_mapping.xlsx"))
OUT    <- Sys.getenv("AGG_OUT",    file.path(.ccpb, "sidecars"))

# --- Load the values table (.csv or .xlsx) ------------------------------------
read_values <- function(path) {
  if (!file.exists(path)) stop("Values table not found: ", path)
  ext <- tolower(tools::file_ext(path))
  if (ext == "csv") {
    read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  } else if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("openxlsx", quietly = TRUE)) stop("openxlsx needed to read ", path)
    openxlsx::read.xlsx(path, sheet = 1, check.names = FALSE)
  } else {
    stop("Unsupported values-table format (use .csv or .xlsx): ", path)
  }
}

cat("Aggregate-wave backfill\n")
cat("  values:  ", VALUES, "\n")
cat("  qmap:    ", QMAP, "\n")
cat("  out:     ", OUT, "\n\n")

values  <- read_values(VALUES)
mapping <- load_question_mapping(QMAP)
if (is.null(mapping)) stop("Could not read a QuestionMap sheet from: ", QMAP)

need <- c("metric_id", "wave", "metric_type", "value")
miss <- setdiff(need, names(values))
if (length(miss) > 0) stop("Values table missing required column(s): ", paste(miss, collapse = ", "))

# --- Generate the sidecars (waves_meta auto-derived from the distinct waves) ---
paths <- write_aggregate_wave_sidecars(values, mapping, waves_meta = NULL, output_dir = OUT)
cat(sprintf("\n%d sidecar(s) written to %s\n", length(paths), OUT))

# --- Round-trip verify + honest-significance summary --------------------------
priors <- read_wave_contributions(OUT)
if (length(priors) == 0) stop("No sidecars read back — check the inputs.")

all_q  <- do.call(c, lapply(priors, function(p) p$questions))
keys   <- unique(vapply(all_q, function(q) as.character(q$match_key), character(1)))
with_sd    <- sum(vapply(all_q, function(q) !is.null(q$stats) && !is.null(q$stats$sd), logical(1)))
with_base  <- sum(vapply(all_q, function(q) !is.null(q$base) && !is.na(q$base), logical(1)))
props      <- sum(vapply(all_q, function(q) !is.null(q$rows), logical(1)))
means_nps  <- sum(vapply(all_q, function(q) !is.null(q$stats), logical(1)))

cat("\n--- verification ---\n")
cat(sprintf("  waves read back : %d\n", length(priors)))
cat(sprintf("  distinct metrics: %d\n", length(keys)))
cat(sprintf("  question-points : %d  (%d mean/nps, %d proportion)\n", length(all_q), means_nps, props))
cat(sprintf("  carry a base    : %d  (proportion z-test runs only where a base exists)\n", with_base))
cat(sprintf("  carry an sd     : %d  (mean t-test runs only where an sd exists)\n", with_sd))
if (with_base == 0 && with_sd == 0) {
  cat("  => all history plots UNTESTED (no bases/sd supplied). The trend line shows;\n")
  cat("     significance switches on when you add bases/sd or a wave gets microdata.\n")
}
cat("\nNext: set waves_source (ABSOLUTE path) + question_mapping in the Crosstab_Config\n")
cat("Settings, then re-run the tabs report. See docs/AGGREGATE_TRACKING_GUIDE.md.\n")
