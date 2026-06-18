# Plan — Per-segment prior-wave trends in the v2 report (Total + published dimensions)

**Status:** PLANNING (no code yet). Branch: `feature/tabs-v2-segment-wave-trends` (stacked on
`fix/tabs-v2-banner-composite-fixes`, which adds the filter-suppression this feature refines).
**Date:** 2026-06-18.

## 1. Goal

Show prior-wave trends in the v2 tabs report **by Total and by published segment
dimensions**, and support **proportions** (not just mean-kind metrics):

- **Next study (greenfield):** trends by **Total, department, campus**.
- **CCPB:** incorporate prior-wave trends by **Total, centre, channel** (needs backfill).

## 2. Decision & rationale (agreed)

**The v2 report consumes the classic `tracker` module's computed per-segment output for
PRIOR waves; the CURRENT wave stays live from the tabs microdata.**

Why:
1. Prior waves are **frozen, published figures of record** — pre-aggregated per-segment values
   (means, proportions, NETs, bases) are the right representation; no live recompute needed.
2. The `tracker` module is the **canonical longitudinal engine** (segments via `banner_trends.R`,
   every metric type via `metric_types.R`, significance, weighting). Single source of truth;
   no duplicated stats logic.
3. **Compact** — pre-aggregated per-segment values fit the self-contained embedded report;
   carrying per-respondent microdata for every historical wave would blow the size budget.

**Boundary (explicit):** this serves *published* dimensions. It does **not** enable arbitrary
*ad-hoc* filtering of history (a subgroup we never published) — that would need prior-wave
microdata and is out of scope. The recent filter-suppression fix remains the correct fallback
for unpublished subgroups.

## 3. Current state — the renderer is already built for this

The JS wave engine (`assets/js/22w_waves.js`) already reads per-segment hooks that the current
writer never populates:

| Consumer | Reads | File |
|---|---|---|
| `meanValue(q,row,waveQ,seg)` | `waveQ.seg_stats[seg].{mean,nps,index}` | 22w_waves.js:207-219 |
| `rowValue(waveQ,label,seg)` | `waveQ.rows[norm].seg[segKey]` (Total = `.pct`) | 22w_waves.js:134-142 |
| `baseOf(waveQ,seg)` | `waveQ.bases[segKey]` (Total = `.base`) | 22w_waves.js:239-242 |
| `waves.segments()` | `w.segments[].norm` matched to `TR.AGG.columns[].label`; `group` from the column | 22w_waves.js:113-130 |
| `netValue` / `indexFromDistribution` | per-segment via `rowValue(...seg)` | 22w_waves.js:145-171 |

The **Tracking** and **Visualise** "Segments for question" views already call
`waves.series(q,row,ri,segNorm)` with a real segment — they render nothing today only because
`seg_stats`/`bases`/`rows[].seg` are empty.

**The gap is the writer + a few render surfaces — not the data model.**

## 4. The bridge — `tracker` output → v2 wave island

The tracker produces (Explore-mapped; field names to be confirmed in Phase 0):

```
trend_results[question_code][segment_name] = list(
  metric_type,                       # "mean" | "nps" | "proportions" | "rating_enhanced" | ...
  question_code, question_text,
  wave_results[wave_id] = list(
    mean|sd, nps|promoters_pct|..., proportions[option]=pct, metrics[box]=pct,
    n_unweighted, n_weighted, eff_n
  ),
  changes, significance               # precomputed (we recompute on the v2 side for consistency)
)
banner_segments[segment_name] = list(name, variable, value, is_total, wave_mapping)
```
(see `lib/trend_calculator.R`, `lib/banner_trends.R`, `lib/statistical_core.R`,
`lib/metric_types.R`; `build_tracking_crosstab()` already flattens this.)

**Target island wave-question payload (per PRIOR wave, per question):**
```jsonc
{
  "match_key": "<canonical key == current aggKeys[q.code]>",
  "title": "...",
  "base": 612,                         // Total n
  "bases":   { "<segKey>": 240, ... }, // per-segment n  -> baseOf
  "stats":     { "mean": 7.6, "nps": 31 },          // Total mean-kind -> meanValue
  "seg_stats": { "<segKey>": { "mean": 7.4 }, ... },// per-segment mean-kind
  "rows": {                             // category / NET / proportion rows -> rowValue
    "<norm(label)>": { "pct": 42.0, "seg": { "<segKey>": 39.0, ... } }
  }
}
```
Plus, per wave: `segments: [{ "norm": "<segKey>", "label": "...", "group": "..." }]`.

**Metric-type mapping:**
- `mean` / `rating_enhanced` → `stats.mean` + `seg_stats[seg].mean`; box metrics (`top2_box` …)
  become NET rows in `rows[norm]` (so they trend via the existing NET path).
- `nps` → `stats.nps` + `seg_stats[seg].nps`.
- `proportions` → one `rows[norm(option)]` per option, `pct` (Total) + `seg[segKey]`.
- bases → `base` (Total) + `bases[segKey]`.

The CURRENT wave continues to come from the live tabs run (scores + `banner_vars`), so
current-wave figures always match the Crosstabs. **Open design point:** the current wave's
*segment* trend point should be taken from the **live tabs banner-column value** (guaranteed to
match Crosstabs) rather than duplicated into the island — see Phase 3.

## 5. Segment keying (collision risk)

Today a segment is identified by **normalised label** (`waves.segments()` matches columns by
`model.norm(label)`). With two dimensions, categories sharing a name collide (e.g. a centre and a
channel both "Online").

- **Option A (ship-first):** require unique labels across tracked dimensions; the writer emits a
  collision **warning** (TRS) if not. Lowest effort.
- **Option B (robust):** key segments by **`group::label`** end-to-end (writer + `segments()` +
  the seg argument threaded through `valueAt`/`baseOf`). Recommended hardening once A proves out.

## 6. Render surfaces

1. **Tracking / Visualise "Segments for question":** lights up once the island carries
   `seg_stats`/`bases`/`rows[].seg`. Minimal JS — wire the current-wave segment point from the
   live model (§4 open point).
2. **Crosstabs / Dashboard `attachDeltas`:** currently Total-only (`seg = null`,
   22w_waves.js:437). To show "Total + per-department" Δ/trend per banner column, compute deltas
   **per column**, mapping each banner column to its segment (`waves.segments()` already gives the
   column↔segment link).
3. **Segment-aware filter:** refine the suppression from `fix/tabs-v2-banner-composite-fixes` —
   if an audience filter matches a published segment, show that segment's trend instead of
   suppressing; else keep suppressing (the fallback).

## 7. Backfill & config

- **CCPB:** re-run the tracker over the historical waves **with centre + channel** (per-respondent
  files; `wave_loader.R` is data-source agnostic) to emit the island. Backfill is one-time and
  kept out of the repo (as CCS history was).
- **Next study:** greenfield — emit the segment-aware island from wave 1; no backfill.
- **Config:** the tracker's Banner sheet already defines break variables; the v2 side must know
  which banner groups are *tracked dimensions* (shared config — the tabs/tracker already share
  the Question_Mapping).

## 8. Phasing (each phase shippable + gated)

- **Phase 0 — spike/confirm:** verify exact tracker field names against the code; confirm CCPB
  historical respondent files carry centre + channel; lock the island schema (§4). Confirm
  independent dimensions (Total | by dept | by campus), **not** the full crossing.
- **Phase 1 — bridge (means + NPS), Total + segments:** writer that serialises tracker
  `trend_results` → island `stats`/`seg_stats`/`bases`/`segments`. Tracking-tab segment trends
  light up. Gate: synthetic 2-dimension fixture; per-segment values + bases assert through
  `valueAt`/`baseOf`.
- **Phase 2 — proportions / NET per segment:** populate `rows[norm].pct/.seg`. Gate: proportion
  + NET segment trends.
- **Phase 3 — Crosstabs/Dashboard per-column deltas + segment-aware filter** (refines the
  suppression). Gate: per-column deltas; filter-matches-segment keeps trend, else suppresses.
- **Phase 4 — CCPB backfill + next-study config**; verify against a real run.
- **Phase 5 (optional hardening) — `group::label` segment keying** (§5 Option B).

## 9. Risks

- **Data provenance (CCPB):** if historical respondent files lack centre/channel, prior segment
  trends can't be reconstructed — Phase 0 gate.
- **Current-vs-prior consistency:** current wave from tabs, priors from tracker — definitions must
  align (shared config). A prior discrepancy (weighted tracker, "I-WTRACK") was found and fixed
  before; same diligence here.
- **Sparsity:** dimension × dimension cells get thin → low-base flags (existing) apply per segment.
- **Label collisions:** §5.
- **Size budget:** per-segment pre-aggregates are compact, but many waves × dimensions × options
  add up — watch the `< 2 MB` artifact gate.

## 10. Decisions (resolved 2026-06-18)

- **History = computed per-segment totals, NOT raw microdata.** Prior waves carry the published
  Total + per-dimension values, so the trend always equals what was reported. Raw data is retained
  upstream in the tracker's wave files — any new breakdown is a tracker re-run + re-emit, not an
  embedded-microdata change. The current wave stays live from the tabs microdata.
- **Independent dimensions** (Total | by dept | by campus), not the full crossing.
- **Tracking-tab segment trends first** (Phase 1); Crosstabs per-column deltas in Phase 3.
- **Segment keying** is an implementation detail (handled in code): guard against same-named
  categories across dimensions; ship with label keys + a collision warning, harden to
  `group::label` if needed. No config burden on the analyst.
- Focus is **build-going-forward**; CCPB backfill (Phase 4) is feasible since the tracker reads
  per-respondent wave files, contingent on those files carrying centre + channel.

## 11. Progress (2026-06-18) — branch `feature/tabs-v2-segment-wave-trends`

**Done + tested (no real data needed; synthetic fixtures):**
- **Phase 0** — tracker output shapes verified against the code; island schema locked.
- **Phase 1a** — JS consumer validated: `waves.series(q,row,ri,seg)` reads `seg_stats`/`bases`;
  `waves.segments()` matches segments to banner columns. JS gate.
- **Phase 1b** — `tracker_segment_contributions()` (`lib/tracking_segment_bridge.R`) serialises the
  tracker's per-segment output → island prior-wave shape (means + NPS, values + bases). Output
  assembles via `build_tracking_island()` + `serialize_tracking_island()` into valid island JSON.
- **Phase 2 proportions** — bridge branches on metric type; proportions → `rows[norm].pct` (Total)
  + `.seg[segKey]`. Renderer already reads it (no JS change).
- **Phase 2 significance (means)** — bridge carries SD on `stats`/`seg_stats`; `sdAtWave` reads a
  stored SD so the Welch test runs per-segment without the distribution. Existing reports unaffected.
- Gates: R bridge **46/0** (`tests/testthat/test_tracking_segment_bridge.R`); JS **79/0**
  (`prototypes/.../run_tests_v2.mjs`). Prototype ↔ production `22w_waves.js` byte-identical.

**Remaining (needs a real tracker run / render verification — Duncan):**
- **Integration wiring:** run the tracker for a study → feed `tracker_segment_contributions()`
  output as `build_tracking_island()` prior_contributions (the current wave stays the live tabs
  contribution). Add `tracking_segment_bridge.R` to the tabs loader.
- **Tracking-tab current-wave segment point** from the live tabs model (so it always matches
  Crosstabs) — small JS + visual check via `launch_turas`.
- **Phase 3** — Crosstabs/Dashboard per-column deltas + segment-aware filter (refines the
  suppression fix).
- **Phase 4** — CCPB backfill (needs the historical respondent files with centre + channel).
- Possible refinement: carry `eff_n` for exact weighted significance (currently `n_unweighted`).

## 12. SACS worked example — data path VERIFIED on real data (2026-06-18)

Source: `OneDrive/DB Files/TurasProjects/SACAP/SACS/SACS-{2023,2024,2025}` (read-only).
Three years, one per-respondent `*_data.xlsx` each; no tracker/mapping config existed.

**Mapping (confirmed from the Survey_Structure + data):**
- **Engagement battery** = the 12 Gallup-style Likert items ("I know what is expected of me…" →
  "…opportunities to learn and grow"), 1–5 scale. Renumbered across years (2023 Q01–Q12; 2024/25
  Q05–Q16) but **identical wording → auto-matches by `tracking_norm(title)`**. Plus **overall
  satisfaction** ("Taking everything into account how satisfied…", 2023 Q21 / 2024 Q26 / 2025 Q28).
- **Segments**: Campus (2023 Q24 / 2024-25 Q02), Department (Q25 / Q03), Tenure (Q26 / Q04).
  Campus + Tenure category labels are **identical across all 3 years** (clean trends); **Department
  was restructured** (labels differ → partial cross-year matching, gaps — handled gracefully).
- **Excluded**: the values items (Integrity/Excellence/…) — reworded 2023→2024 ("I do what's
  right" → "SACAP demonstrates…"), so not comparable; and they're "values", not "engagement".

**Verified (scratch driver, /tmp, nothing written to OneDrive):** real data → the tracker's
`calculate_weighted_mean` → `trend_results` → `tracker_segment_contributions()` →
`build_tracking_island()` → `serialize_tracking_island()`. Island: 3 waves, valid JSON, 71 KB,
13 items × 36 segments. Sample: overall satisfaction Total 4.08 → 3.83 → 3.90; by tenure
"<1 year" 4.3→4.45 vs "3–5 years" 3.88→3.69. Per-segment bases small (campus n≈8–62) → low base.

**Production wiring — BUILT + verified (2026-06-18):**
- `compute_segment_trends()` + `write_segment_wave_sidecars()`
  (`lib/tracking_segment_compute.R`) orchestrate the tracker's calculators over
  Total + each banner value per wave and write per-wave segment **sidecars**. The
  EXISTING `run_crosstabs` pipeline reads them (`read_wave_contributions` →
  `build_tracking_island`) with **no pipeline change**; the Tracking tab already
  reads current-wave segment points from the live banner model
  (`trk.currentFor`), so **no JS change**. Verified on real SACS (parity with the
  proof; sidecars round-trip through the reader; 24 campus/dept/tenure segments).
- Example: `modules/tabs/examples/sacs_segment_backfill.R` writes the 2023/24
  prior sidecars.

**To see it in the SACS-2025 report (Duncan, via launch_turas):**
1. `Rscript modules/tabs/examples/sacs_segment_backfill.R` → sidecars in `<OUT_DIR>`.
2. SACS-2025_Crosstab_Config — Settings: `html_report_v2` + `html_report_v2_tracking`
   = TRUE, `waves_source = <OUT_DIR>`; Selection: make Q02 (Campus) / Q03
   (Department) / Q04 (Tenure) banners so the live 2025 model carries those columns.
3. `launch_turas` → build SACS-2025 → Tracking tab → "Segments for question".

**Follow-up (build-going-forward):** have the current wave's `wave_contribution`
also emit its own segment sidecar, so 2026+ is automatic (no backfill step).
