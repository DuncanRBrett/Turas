# ==============================================================================
# WORKED EXAMPLE — SACS engagement, segment wave-trends backfill
# ==============================================================================
# Generates the PRIOR-wave segment sidecars (2023 + 2024) that make the
# SACS-2025 v2 tabs report show engagement trends by Total / Campus / Department
# / Tenure. The current wave (2025) stays the live tabs run.
#
# HOW TO USE (you run this, then launch_turas — nothing here touches a report):
#   1. Edit SACS_BASE / OUT_DIR below if needed.
#   2. Rscript modules/tabs/examples/sacs_segment_backfill.R
#      -> writes <OUT_DIR>/SACS_2023_wave.json + SACS_2024_wave.json
#   3. In SACS-2025_Crosstab_Config.xlsx:
#        - Settings: html_report_v2 = TRUE, html_report_v2_tracking = TRUE,
#                    waves_source = <OUT_DIR>
#        - Selection: make Q02 (Campus), Q03 (Department), Q04 (Tenure) BANNERS
#          so the live 2025 model carries those columns (the current-wave segment
#          points are read from them; priors come from the sidecars).
#   4. launch_turas() -> build the SACS-2025 crosstab -> open the v2 report ->
#      Tracking tab -> "Segments for question".
#
# Engagement battery wording is identical across years, so metrics match by text
# despite renumbering (2023 Q01-12 -> 2024/25 Q05-16). Campus + Tenure labels are
# stable across years (clean trends); Department was restructured (partial).
# ==============================================================================

suppressMessages(library(openxlsx))

SACS_BASE <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/SACAP/SACS"
OUT_DIR   <- Sys.getenv("SACS_SEG_OUT", file.path(SACS_BASE, "SACS-2025", "wave_history"))  # waves_source (in-project)
TURAS     <- Sys.getenv("TURAS_HOME", "/Users/duncan/Dev/Turas")

source(file.path(TURAS, "modules/tracker/lib/statistical_core.R"))
source(file.path(TURAS, "modules/tabs/lib/tracking_island.R"))
source(file.path(TURAS, "modules/tabs/lib/tracking_segment_compute.R"))
source(file.path(TURAS, "modules/tabs/lib/tracking_segment_bridge.R"))
norm <- tracking_norm

# --- prior waves only (2025 is the live current wave) -------------------------
wavedef <- list(
  list(id = "2023", label = "SACS 2023", year = 2023, camp = "Q24", dept = "Q25", ten = "Q26"),
  list(id = "2024", label = "SACS 2024", year = 2024, camp = "Q02", dept = "Q03", ten = "Q04"))

load_wave <- function(w) {
  dir <- file.path(SACS_BASE, sprintf("SACS-%s", w$id))
  d <- read.xlsx(file.path(dir, "03_Data", sprintf("SACS-%s_data.xlsx", w$id)), sheet = 1)
  q <- read.xlsx(file.path(dir, sprintf("SACS-%s_Survey_Structure.xlsx", w$id)), sheet = "Questions")
  list(id = w$id, data = d, w = w,
       inv = setNames(as.character(q$QuestionCode), vapply(q$QuestionText, norm, "")))
}
WL <- lapply(wavedef, load_wave); names(WL) <- vapply(wavedef, function(w) w$id, "")

# canonical tracked metrics from the 2025 structure: engagement Q05-Q16 + Q28
q25 <- read.xlsx(file.path(SACS_BASE, "SACS-2025", "SACS-2025_Survey_Structure.xlsx"), sheet = "Questions")
t25 <- setNames(as.character(q25$QuestionText), as.character(q25$QuestionCode))
metrics <- lapply(c(sprintf("Q%02d", 5:16), "Q28"), function(cd) {
  key <- norm(t25[[cd]])
  list(code = paste0("M_", cd), title = t25[[cd]], type = "mean",
       cols = setNames(lapply(WL, function(x) x$inv[[key]]), names(WL)))
})
seg_dim <- function(label, field)
  list(label = label, cols = setNames(lapply(WL, function(x) x$w[[field]]), names(WL)))
segment_dims <- list(seg_dim("Campus", "camp"), seg_dim("Department", "dept"), seg_dim("Tenure", "ten"))

waves <- lapply(WL, function(x) list(id = x$id, data = x$data))
paths <- write_segment_wave_sidecars(
  waves, metrics, segment_dims, OUT_DIR,
  wave_labels = setNames(lapply(wavedef, function(w) w$label), names(WL)),
  wave_years  = setNames(lapply(wavedef, function(w) w$year),  names(WL)))

cat("Wrote", length(paths), "segment sidecars to:", OUT_DIR, "\n")
for (p in paths) cat("  -", basename(p), "\n")
cat("\nNext: set waves_source =", OUT_DIR, "in SACS-2025_Crosstab_Config (Settings),\n")
cat("make Q02/Q03/Q04 banners (Selection), enable html_report_v2_tracking, then launch_turas.\n")
