# ==============================================================================
# Question_Mapping-driven segment wave-trend backfill (generic; SACS worked example)
# ==============================================================================
# Reads a Question_Mapping workbook and the prior waves' data, then writes one
# `<wave>_wave.json` segment sidecar per prior wave into a `waves_source` folder.
# A v2 tabs build (html_report_v2_tracking + waves_source + the same
# question_mapping in Settings) then assembles a segment-aware island — and the
# sidecars key by the CANONICAL QuestionCode, matching how the live wave keys
# when a mapping is configured (so the link survives renumbering / rewording).
#
# Question_Mapping workbook (SACS-2025_Question_Mapping.xlsx):
#   QuestionMap sheet: QuestionCode | QuestionText | TrackingSpecs |
#                      SourceQuestions | Wave<YYYY>…
#                      - item row: Wave<YYYY> -> that wave's data column;
#                        TrackingSpecs "nps" -> NPS, else mean.
#                      - composite/index row (e.g. Q_Engage): SourceQuestions =
#                        comma-list of source QuestionCodes (ENG01..ENG12); its
#                        value is their per-respondent mean each wave. Wave<YYYY>
#                        cells stay blank (it is not a raw data column). It links
#                        by its data-layer TITLE (QuestionText), because the live
#                        wave emits no per-respondent score for a composite.
#   Banners sheet:     BreakLabel | Wave<YYYY>…   (Total + each banner dimension;
#                      Total has blank wave columns = all respondents)
# The LATEST Wave column is the live/current wave (built by run_crosstabs); all
# earlier Wave columns are priors backfilled here.
#
# Run (you, then re-run the report):
#   Rscript modules/tabs/examples/sacs_segment_backfill.R
#   (override paths with SACS_PROJECT / SACS_QMAP / SACS_SEG_OUT)
# ==============================================================================

suppressMessages(library(openxlsx))

PROJECT <- Sys.getenv("SACS_PROJECT",
  "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/SACAP/SACS/SACS-2025")
QMAP    <- Sys.getenv("SACS_QMAP", file.path(PROJECT, "SACS-2025_Question_Mapping.xlsx"))
OUT_DIR <- Sys.getenv("SACS_SEG_OUT", file.path(PROJECT, "wave_history"))
TURAS   <- Sys.getenv("TURAS_HOME", "/Users/duncan/Dev/Turas")

# Per-study data-file locator: SACS keeps each wave at ../SACS-<year>/03_Data/.
data_path <- function(year)
  file.path(dirname(PROJECT), sprintf("SACS-%s", year), "03_Data", sprintf("SACS-%s_data.xlsx", year))

source(file.path(TURAS, "modules/tracker/lib/statistical_core.R"))
source(file.path(TURAS, "modules/tabs/lib/tracking_island.R"))
source(file.path(TURAS, "modules/tabs/lib/tracking_segment_compute.R"))
source(file.path(TURAS, "modules/tabs/lib/tracking_segment_bridge.R"))

qm <- load_question_mapping(QMAP)
if (is.null(qm)) stop("Could not read QuestionMap sheet from: ", QMAP)
banners <- tryCatch(read.xlsx(QMAP, sheet = "Banners"), error = function(e) NULL)

wave_cols <- sort(grep("^Wave", names(qm), value = TRUE))   # Wave2023, Wave2024, Wave2025
prior_cols <- utils::head(wave_cols, -1)                    # all but the latest (= live wave)
years <- sub("^Wave", "", prior_cols)
cat("Mapping:", nrow(qm), "metrics |", length(prior_cols), "prior waves:", paste(years, collapse = ", "),
    "| live wave:", sub("^Wave", "", utils::tail(wave_cols, 1)), "\n")

waves <- lapply(seq_along(prior_cols), function(i)
  list(id = years[i], data = read.xlsx(data_path(years[i]), sheet = 1)))

per_wave <- function(row) setNames(lapply(prior_cols, function(c) as.character(row[[c]])), years)
blankna  <- function(v) { v <- trimws(as.character(v)); if (nzchar(v) && !identical(tolower(v), "na")) v else NA_character_ }

# canonical QuestionCode -> {Wave<YYYY>: data column} from the single-item rows;
# a composite resolves its SourceQuestions (canonical codes) through this lookup.
code_col <- setNames(
  lapply(seq_len(nrow(qm)), function(i) setNames(lapply(wave_cols, function(c) blankna(qm[[c]][i])), wave_cols)),
  trimws(as.character(qm$QuestionCode)))
src_of <- function(i) if ("SourceQuestions" %in% names(qm)) blankna(qm$SourceQuestions[i]) else NA_character_

metrics <- lapply(seq_len(nrow(qm)), function(i) {
  src <- src_of(i)
  if (!is.na(src)) {
    # composite / index: the metric value is the mean of its source items. The
    # live wave does NOT emit a composite (no per-respondent micro score), so it
    # links by the data-layer TITLE -> key = NULL keeps the bridge on the title
    # path (tracking_norm(QuestionText)), which is the renderer's aggKeys fallback.
    codes <- trimws(strsplit(src, "[,;]")[[1]]); codes <- codes[nzchar(codes)]
    list(code = as.character(qm$QuestionCode[i]), key = NULL,
         title = as.character(qm$QuestionText[i]), type = "mean",
         sources = setNames(lapply(prior_cols, function(c)
           unname(vapply(codes, function(cd) (code_col[[cd]] %||% list())[[c]] %||% NA_character_,
                         character(1)))), years))
  } else {
    list(code  = as.character(qm$QuestionCode[i]),
         key   = as.character(qm$QuestionCode[i]),            # canonical key (matches the live wave)
         title = as.character(qm$QuestionText[i]),
         type  = if (grepl("nps", tolower(qm$TrackingSpecs[i] %||% ""))) "nps" else "mean",
         cols  = per_wave(qm[i, ]))
  }
})

seg_rows <- if (is.null(banners)) integer(0) else which(tolower(trimws(banners$BreakLabel)) != "total")
segment_dims <- lapply(seg_rows, function(i) list(
  label = as.character(banners$BreakLabel[i]), cols = per_wave(banners[i, ])))

paths <- write_segment_wave_sidecars(
  waves, metrics, segment_dims, OUT_DIR,
  wave_labels = setNames(lapply(years, function(y) paste("SACS", y)), years),
  wave_years  = setNames(lapply(years, as.numeric), years))

cat("Wrote", length(paths), "segment sidecars to:", OUT_DIR, "\n")
for (p in paths) cat("  -", basename(p), "\n")
cat("\nNext: ensure the Crosstab_Config Settings has waves_source =", OUT_DIR, "\n")
cat("and question_mapping =", QMAP, "(so the live wave keys by canonical code too), then launch_turas.\n")
