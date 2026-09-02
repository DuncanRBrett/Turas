# ==============================================================================
# QUALITATIVE ISLAND FIXTURE. Generator
# ==============================================================================
#
# Builds a DATA_QUAL island through the REAL builder (`qual_build_data_qual`) and
# writes it to JSON. That JSON is COMMITTED and is what the JS half of the
# qualitative gate reads, so the JS suite exercises the record shape R actually
# emits, not a hand-authored stub that agrees with R by coincidence.
#
# WHY THIS EXISTS (production review 2026-08, I12a). The main qual JS suite ran
# on a pre-I20 island shape: 86 hand-written fixture records, not one of them
# carrying a `rid`. The rekey suite had rids but no `band`, no `suppressed` and
# no `demos`. So the shape production emits. All four fields on one record,
# was exercised by no JS test at all, and every mark helper (which keys on
# `rid` when it is present) was tested only on its legacy fallback path.
#
# WHAT THE FIXTURE DELIBERATELY CARRIES, in one island:
#   - `rid` on every record            (the reader-key sidecar is healthy)
#   - `band` on Q1's records           (a split-bearing NPS-unioned open-end)
#   - `suppressed` on two records      (verbatim_scope = "noteworthy" withholds
#                                       tier-0 text; a hide marker withholds one
#                                       that would otherwise have shipped)
#   - `demos` on every record          (demographic_cuts = "allow", two dimensions)
#   - themes, sentiment, all four tiers, and one respondent in both questions
#
# REGENERATE WITH (from the Turas root):
#   Rscript modules/tabs/tests/fixtures/qual_island/generate_qual_island.R
#
# Regenerate only when the island builder deliberately changes shape. The R half
# of the gate (test_qual_island_fixture.R) rebuilds this island in memory on
# every run and compares it to the committed JSON, so a builder change that has
# not been regenerated fails the suite rather than passing silently.
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) return(normalizePath(path))
    path <- dirname(path)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME or run from the Turas root.")
}

# ------------------------------------------------------------------------------
# The fixture definition. Sourced by BOTH this generator and the R drift gate, so
# the two cannot describe different islands.
# ------------------------------------------------------------------------------

#' Build the fixture island through the real builder.
#'
#' @param turas_root The Turas project root.
#' @return The DATA_QUAL island list.
qual_fixture_island <- function(turas_root) {
  source(file.path(turas_root, "modules/tabs/lib/qual_workbook_reader.R"), local = TRUE)
  source(file.path(turas_root, "modules/tabs/lib/qual_island_builder.R"), local = TRUE)
  source(file.path(turas_root, "modules/tabs/lib/qual_reader_keys.R"), local = TRUE)

  theme <- function(label) list(col = NA_integer_, label = label)

  # `hidden` = the reader's hide marker; `noteworthy_tier` 0/1/2/3 =
  # other / noteworthy / must-read / priority.
  rec <- function(id, text, tier, sentiment, themeVals = list(),
                  band = NULL, demos = NULL, hidden = FALSE, rating = NA_real_) {
    out <- list(id = id, text = text, noteworthy = tier >= 1L,
                noteworthy_tier = as.integer(tier), hidden = hidden,
                sentiment = if (is.na(sentiment)) NA_integer_ else as.integer(sentiment),
                rating = rating, themeVals = themeVals, demos = demos)
    if (!is.null(band)) out$band <- band
    out
  }

  d <- function(dept, tenure) list(Dept = dept, Tenure = tenure)

  # Q1. A themed, band-split open-end (the NPS Detractor/Passive/Promoter union).
  # Tier 0 records have their text withheld by verbatim_scope = "noteworthy";
  # respondent 4 is tier 2 but hide-marked, so it is withheld despite the tier.
  # Two of them are tier 3 (priority) in two different bands, so the priority-quote
  # path. The crosstab pin, which reads tier >= 3 and orders by the declared band
  # order. Has something to find. A fixture with no priority record would leave
  # that path returning [] and looking tested.
  q1_records <- list(
    rec("1", "Great value for the price", 3L, 1L, list(Price = 1L),
        band = "Promoter", demos = d("Admin", "5+ yrs")),
    rec("2", "Support is slow to respond", 3L, 3L, list(Service = 3L),
        band = "Detractor", demos = d("Finance", "1-4 yrs")),
    rec("3", "It is fine, nothing special", 0L, 2L, list(Service = 2L),
        band = "Passive", demos = d("Admin", "1-4 yrs")),
    rec("4", "asdfasdf", 2L, NA, list(),
        band = "Detractor", demos = d("Finance", "5+ yrs"), hidden = TRUE)
  )
  q1 <- list(
    code = "Q1", title = "Why that score?", type = "themed", sheet = "Q1",
    roles = list(themes = list(theme("Price"), theme("Service"))),
    records = q1_records, meta = list(dropped_codes = 0L),
    split = list(dim = "NPS", bands = c("Detractor", "Passive", "Promoter")))

  # Q2. A plain raw open-end, no themes, no split. Respondent 1 appears in both
  # questions, so the same rid must key marks on two different comments.
  q2 <- list(
    code = "Q2", title = "Anything else?", type = "raw", sheet = "Q2",
    roles = list(themes = list()),
    records = list(
      rec("1", "More parking please", 1L, NA, list(), demos = d("Admin", "5+ yrs")),
      rec("5", "No further comment", 0L, NA, list(), demos = d("Finance", "1-4 yrs"))),
    meta = list(dropped_codes = 0L))

  ids <- c("1", "2", "3", "4", "5")
  master <- list(
    id_to_idx = stats::setNames(seq_along(ids) - 1L, ids), n = length(ids),
    banner_dims = list(list(label = "Dept",   values = c("Admin", "Finance")),
                       list(label = "Tenure", values = c("1-4 yrs", "5+ yrs"))))

  # Real tokens from the real minter, made reproducible by a fixed seed. A
  # committed fixture must not churn on every regeneration.
  set.seed(20260806L)
  rid_map <- stats::setNames(
    vapply(seq_along(ids), function(i) qual_mint_rid(character(0)), character(1)), ids)

  qual_build_data_qual(
    questions = list(q1, q2), master = master,
    config = list(text_mode = "full", demographic_cuts = "allow",
                  noteworthy_default = "all", verbatim_scope = "noteworthy"),
    rid_map = rid_map)
}

# ------------------------------------------------------------------------------
# Write (only when run as a script, not when sourced by the drift gate)
# ------------------------------------------------------------------------------

if (sys.nframe() == 0L) {
  turas_root <- detect_turas_root()
  out_dir <- file.path(turas_root, "modules/tabs/tests/fixtures/qual_island")
  island <- qual_fixture_island(turas_root)
  out_path <- file.path(out_dir, "qual_island.json")
  jsonlite::write_json(island, out_path, auto_unbox = TRUE, null = "null",
                       na = "null", pretty = TRUE, digits = NA)
  cat(sprintf("Wrote %s (%d questions, %d records)\n", out_path,
              length(island$questions),
              sum(vapply(island$questions, function(q) length(q$records), integer(1)))))
}
