#!/usr/bin/env Rscript
# ==============================================================================
# RECOVER A TRACKING WAVE FROM ITS RAW DATA
# ==============================================================================
# Rebuilds one historical wave's rows in a tracking values table — value, base
# and standard deviation — from that wave's respondent-level data, then checks
# every figure against what the wave actually published.
#
# WHY: a wave loaded from published figures alone carries a mean and nothing
# else, so the v2 Tracking tab plots it untested (no spread, no Welch test).
# Where the raw data survives, this recovers what the test needs, in tested
# Turas code, with an audit trail — rather than in a one-off script.
#
# USAGE
#   Rscript scripts/recover_tracking_wave.R <config.R>
#
# The config file is plain R defining PROJECT (see the template written by
# --init). Keep one per wave you recover, beside that wave's data:
#   Rscript scripts/recover_tracking_wave.R --init my_wave_config.R
#
# WHAT IT WRITES
#   <output_csv>            the full values table, history untouched, this
#                           wave's rows replaced
#   <output_csv>.recon.csv  the reconciliation: computed vs published, per metric
#
# It does NOT write sidecars and does NOT run the report. Once the reconciliation
# is clean, regenerate sidecars with write_aggregate_wave_sidecars() and rerun
# the wave from launch_turas().
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)

TEMPLATE <- '# Config for scripts/recover_tracking_wave.R
PROJECT <- list(
  wave = "2025",                       # the wave label, must match the values table

  data          = "…/CSAT2025/03_Data/CCPB_CSAT2025_Data.xlsx",
  structure     = "…/CSAT2025/CCPB_CSAT2025_Survey_Structure_Short.xlsx",
  # Where the NETs are declared. Usually the CURRENT wave\'s structure, because a
  # NET must match the label the current wave\'s report emits. Omit to use the
  # wave\'s own structure.
  net_structure = "…/W2026/CCPB_CSAT_W2026_Survey_Structure.xlsx",
  mapping       = "…/03 Tracker/v2 tabs tracking/CCPB_v2_question_mapping.xlsx",
  values        = "…/03 Tracker/v2 tabs tracking/ccpb_v2_values.csv",
  output_csv    = "…/03 Tracker/v2 tabs tracking/ccpb_v2_values_recovered.csv",

  options_skip = 2,                    # header rows above the Options header row
  weights      = NULL,                 # weight column name, or NULL if unweighted

  # Metrics whose published series was formed on a filtered base.
  base_filters = list(Q26 = \'S11 == "Presell"\'),

  # Metrics to drop from tracking entirely (removed from EVERY wave).
  drop = c("Q34")
)
'

if (length(args) == 2 && args[1] == "--init") {
  writeLines(TEMPLATE, args[2])
  cat("Wrote config template:", args[2], "\n")
  quit(status = 0)
}
if (length(args) != 1) {
  cat("Usage: Rscript scripts/recover_tracking_wave.R <config.R>\n")
  cat("       Rscript scripts/recover_tracking_wave.R --init <config.R>\n")
  quit(status = 2)
}

# ---- load Turas -----------------------------------------------------------
root <- Sys.getenv("TURAS_HOME", unset = getwd())
if (!dir.exists(file.path(root, "modules"))) {
  cat("Cannot find the Turas modules/ directory. Run from the project root, or set TURAS_HOME.\n")
  quit(status = 2)
}
source(file.path(root, "modules/tabs/lib/00_guard.R"))        # tabs_refuse (TRS)
source(file.path(root, "modules/tabs/lib/tracking_island.R"))  # tracking_norm, %||%
source(file.path(root, "modules/tabs/lib/filter_utils.R"))     # apply_base_filter
source(file.path(root, "modules/tabs/lib/tracking_wave_values.R"))

source(args[1], local = TRUE)
if (!exists("PROJECT")) { cat("Config defines no PROJECT list.\n"); quit(status = 2) }
P <- PROJECT

# readxl, never openxlsx — see the trap note in tracking_wave_values.R.
xl <- function(path, sheet = NULL, skip = 0) {
  as.data.frame(readxl::read_excel(path, sheet = sheet, skip = skip,
                                   col_types = "text", na = character(0)))
}

cat("\n=== Recovering wave", P$wave, "===\n")
dat     <- xl(P$data)
mapping <- xl(P$mapping, sheet = "QuestionMap")
opts    <- xl(P$structure, sheet = "Options", skip = P$options_skip %||% 2)
nopts   <- if (!is.null(P$net_structure)) {
  xl(P$net_structure, sheet = "Options", skip = P$options_skip %||% 2)
} else NULL
cat("records:", nrow(dat), " tracked metrics:", nrow(mapping), "\n")

if (!is.null(P$drop) && length(P$drop) > 0) {
  mapping <- mapping[!(trimws(as.character(mapping$QuestionCode)) %in% P$drop), , drop = FALSE]
  cat("dropped from tracking:", paste(P$drop, collapse = ", "), "\n")
}

res <- wave_values_from_microdata(dat, mapping, options = opts, wave = P$wave,
                                  net_options = nopts, weights = P$weights,
                                  base_filters = P$base_filters)
if (identical(res$status, "REFUSED")) quit(status = 1)

# ---- reconcile against the published figures ------------------------------
values <- utils::read.csv(P$values, stringsAsFactors = FALSE)
pub <- values[as.character(values$wave) == as.character(P$wave), c("metric_id", "value")]
rec <- reconcile_wave_values(res$result, pub)
utils::write.csv(rec$result, paste0(P$output_csv, ".recon.csv"), row.names = FALSE, na = "")

# ---- splice into the values table -----------------------------------------
# History is copied through untouched; this wave's rows are replaced, and a
# computed metric the table has no row for is INSERTED (a recovered wave absent
# from the table used to vanish silently — review 2026-08, C5). A metric that
# could not be computed keeps whatever the table already held, so a skipped
# metric degrades to "untested", never to a wrong number.
keep <- !(values$metric_id %in% (P$drop %||% character(0)))
values <- values[keep, , drop = FALSE]

spliced <- splice_wave_values(values, res$result, P$wave)
if (identical(spliced$status, "REFUSED")) quit(status = 1)
values <- spliced$values
# na = "" keeps a missing base/sd an EMPTY cell, matching the values-table
# convention. A literal "NA" would still parse, but it reads as a value.
utils::write.csv(values[, c("metric_id", "wave", "metric_type", "value", "base", "sd")],
                 P$output_csv, row.names = FALSE, na = "")

cat("\nwrote:", P$output_csv, "\n")
cat("wrote:", paste0(P$output_csv, ".recon.csv"), "\n")
if (!identical(rec$status, "PASS") || !identical(res$status, "PASS")) {
  if (is.data.frame(rec$result) && all(is.na(rec$result$published))) {
    cat("\nNOT CROSS-CHECKED — the values table had no published figures for this wave.\n")
    cat("The computed values were written; verify them against the wave's report\n")
    cat("before regenerating sidecars.\n")
  } else {
    cat("\nNOT CLEAN — resolve the metrics named above before regenerating sidecars.\n")
  }
  quit(status = 1)
}
cat("\nClean. Regenerate sidecars with write_aggregate_wave_sidecars(), then rerun the wave.\n")
