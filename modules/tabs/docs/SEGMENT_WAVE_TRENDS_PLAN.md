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

## 10. Open questions for Duncan

1. CCPB historical respondent files carry **centre + channel**? (Phase 0 gate.)
2. **Independent** dimensions (Total | by dept | by campus), not the full crossing — confirm.
3. Tracking-tab segment trends first (Phase 1), or also Crosstabs per-column deltas early (Phase 3)?
4. Segment keying: ship with unique-label discipline (Option A) then harden to `group::label`
   (Option B)?
