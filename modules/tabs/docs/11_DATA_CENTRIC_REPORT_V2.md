# Tabs Data-Centric Report v2 (+ confidence, + tracking)

The data-centric report v2 is a single, self-contained, offline HTML report that
the tabs module can emit **alongside** the classic Excel and HTML outputs. Unlike
the classic report (pre-rendered tables), it embeds the data as JSON "islands"
and a small renderer that recomputes views in the browser — so the reader can
filter the audience, build custom banners, and (for trackers) explore wave
history, all without leaving the file or contacting a server.

It is **additive and off by default**. When disabled, the classic Excel/HTML
outputs are byte-for-byte unchanged.

---

## The three cumulative options

Each option is a superset of the one before it. All are off by default.

| Option | What the reader gets | Turn it on with |
|--------|----------------------|-----------------|
| **1. Classic** | The existing Excel workbook + classic HTML report | (always on) |
| **2. New-look v2 + confidence** | A self-contained v2 report: dashboard, crosstabs, differences, **live audience filter**, **"+ Custom…" banners**, stability/confidence intervals | `html_report_v2 = Y` |
| **3. New-look + tracking** | Option 2 **plus a Tracking tab** (Summary / Explorer / Visualise) built from wave history | `html_report_v2 = Y` **and** `html_report_v2_tracking = Y` (+ a `waves_source`) |

Option 2's interactivity (filter + custom banners) is powered by an embedded
**microdata** island; Option 3's Tracking tab is powered by a **tracking** island
assembled from each wave's own microdata.

---

## Two trackers — do not conflate them

There are two completely separate tracking systems. **The classic tracker module
is untouched by any of this.**

| | **Classic tracker** (`modules/tracker/`) | **Tabs-integrated tracker** (this) |
|--|------------------------------------------|------------------------------------|
| Lives in | Its own module, own `Tracking_Config.xlsx` + `Question_Mapping.xlsx` | The tabs v2 report's Tracking tab |
| Output | Its own deep wave-analysis reports | One tab inside the tabs v2 report |
| Model | Pre-computed per-wave summary values | Anonymised per-wave **microdata**, recomputed live by the renderer |
| Status | Standalone, production, **unchanged** | An *option* inside tabs, off by default |

The tabs-integrated tracker is more flexible (it recomputes values, significance
and intervals the same way the live wave does, with no pre-baked numbers) but it
does **not** replace the classic tracker. Pick whichever fits the engagement.

---

## How the interactivity works (the recompute engine)

The v2 renderer carries three JSON islands:

- **`data-agg`** — the published aggregates (the report of record). The default
  view renders these verbatim.
- **`data-micro`** (`TR.MICRO`) — anonymised per-respondent **microdata**. When a
  filter or a custom banner is active, the stats engine recomputes the whole
  table from this. Absent → the report is published-only (no live filter/banner).
- **`data-prev`** (`TR.PREV`) — the **tracking** island (wave history). Present →
  the Tracking tab appears.

Published figures are always the record; recomputed (filtered / custom-banner /
historical) figures are badged as computed.

### The `TR.MICRO` data contract

```jsonc
{
  "n": 1363,                                  // respondent count
  "answers": {                                // one entry PER agg question, length n
    "Q002": [0, 0, 1, null, -2, ...],         //   single: category row-index, null = no answer,
    "Q010": [[0, 2], [], 1, null, ...]         //          -2 = answered but option not displayed
  },                                          //   multi:  array of row-indices ([] = answered, no shown mention)
  "banner_vars": {                            // one entry per banner GROUP, length n
    "Q005": [1, 2, 1, -1, ...]                //   the AGG column index the respondent falls in (-1 = none)
  },
  "weights": [1, 1, 1, ...],                  // per-respondent weight (length n; all 1 = unweighted)
  "scores": {                                 // per-respondent mean score (rating value / Likert weight /
    "Q015": [4, 7, null, 9, ...]              //   NPS ±100), length n. The robust mean-recompute source —
  },                                          //   works even when a rating publishes only its Mean.
  "boxes": {                                  // per-respondent box-category membership: the data-layer row
    "Q015": [1, 0, null, 2, ...]              //   index of the respondent's box NET (e.g. "Good (9-10)"),
  }                                           //   so box NETs recompute even when the scale is hidden.
}
```

Correctness contract: a respondent's answer is mapped to its display-row index
with the **same** exact-string match the crosstab processors use, so a (weighted)
recompute reproduces the **published** figures. Weighted figures use the weighted
counts / weighted base for values and **Kish effective n** = (Σw)²/Σw² for
significance — mirroring `weighting.R`'s `weighted_z_test_proportions`.

Indices are zero-based positions into each question's `rows[]` array
(`d2.catRows`). `index_scores` (display label → numeric score) is carried on each
scale/NPS question as the shown-category mean path; `scores` is the robust path
for hidden-category questions and is preferred when present.

#### Dual significance on the Tracking tab (95% + 80%)

The Tracking tab honours the report's significance selector (top of the
Crosstabs tab). With **95% + 80%** chosen, every wave-on-wave comparison carries
two flags instead of one: `sig_prev`/`sig_base` (significant at 95%, the solid
▲▼ marker) and `soft_prev`/`soft_base` (significant at **80% but not 95%**, the
hollow △▽ marker + a "nearly significant" pulse tally). The soft flags are only
populated in dual mode, so the default **95%-only** report is unchanged. This
catches real-but-noisy moves — e.g. an NPS that, at n≈60, has a ±28-point 95%
margin, so a 25-point drop reads as nearly-significant rather than vanishing into
"stable". The 80% level is the same one the crosstab tab marks with lowercase
letters; thresholds are `stats.Z95` / `stats.Z80`.

### The tracking island contract (`TR.PREV`)

```jsonc
{
  "schema_version": 1,
  "kind": "tracking_microdata",
  "waves": [
    { "wave": "Wave 24", "year": 2025.5, "current": false, "segments": [],
      "questions": [
        { "code": "Q20",                      // this wave's question code (links via aggKeys)
          "match_key": "track_01",            // canonical key (from Question_Mapping) or norm(title)
          "title": "Overall rating", "base": 58,
          "score_type": "mean",               // "mean" | "nps"
          "scores": [6, 8, 7, ...],           // per-respondent metric values for that wave
          "weights": [1.2, 0.9, ...] }        // per-respondent weights (omitted when unweighted)
      ] },
    { "wave": "Wave 25", "year": 2026, "current": true, ... }   // current wave flagged
  ]
}
```

The renderer recomputes each wave's value + dispersion from its `scores` (no
pre-baked numbers); waves are matched to the current questions by `match_key`.
The `year` key is a unique x-axis order key — give twice-yearly waves a decimal
(e.g. `2025` and `2025.5`) so two same-calendar-year waves never collide.

---

## Enabling each option (Settings sheet keys)

Set these in the project's `Crosstab_Config…xlsx` **Settings** sheet (or via the
GUI tick-box for option 2):

| Key | Default | Meaning |
|-----|---------|---------|
| `html_report_v2` | `N` | Emit the v2 report + `_data.json` (Option 2). |
| `html_report_v2_tracking` | `N` | Add the Tracking tab (Option 3). Requires `html_report_v2 = Y` and a `waves_source` with prior contributions. Weighted studies are supported (the wave trend is weighted to match the crosstab). |
| `waves_source` | *(blank)* | Folder holding prior waves' `*_wave.json` contributions (see Forward path). |
| `question_mapping` | *(auto)* | Path to the classic tracker's `Question_Mapping.xlsx` (absolute, or relative to the project root / config dir). **Blank → auto-detected**: a `*Question_Mapping*.xlsx` in `waves_source`, the project root, or the config dir. When found, waves link by its **canonical key** (`Track_01`…) — robust to renames — and only the mapped metrics track, each with its `TrackingSpecs` metric. None found → metrics match by question **title** (fragile to wording drift). |
| `wave` | *(blank)* | Wave label shown in the header and used as the trend label. |
| `wave_order` | *(blank)* | Numeric x-axis order key for this wave (e.g. `2025.5`). Blank → a 4-digit year is parsed from the `wave` label. |
| `researcher_logo_path` / `client_logo_path` | *(blank)* | Logos embedded (base64) into the v2 header. |
| `sampling_method` | `Not_Specified` | Drives honest CI vocabulary (probability → CI/MOE; otherwise stability/PE). |

Outputs land next to the Excel file: `<project>_report_v2.html`,
`<project>_data.json`, and (tracking on) `<project>_wave.json`.

### Forward path for trackers

Each wave's tabs run writes its **own** `_wave.json` contribution (anonymised
per-metric scores). To build the current wave's Tracking tab, point `waves_source`
at the folder holding the **prior** waves' `_wave.json` files; the current run
reads them, adds its own, and assembles the tracking island. No prior wave is
re-run. (A brand-new tracker therefore lights up its Tracking tab from wave 2
onward; a back-catalogue can be produced by running each historical wave once.)

---

## Anonymisation & governance

- The microdata and tracking islands carry **only** zero-based row/column indices
  and per-respondent weights/scores — **never** an identifier, raw answer string,
  free text, or question title-as-data. The indices are meaningless without the
  report they ship inside.
- The whole report is a single offline file with **no external URLs** (enforced
  at build time). Nothing phones home.
- **Real client data never enters the repository.** Per-wave contributions and any
  backfill artifacts are git-ignored; treat `_wave.json` / `_microdata.json` as
  client-confidential and store them with the client's project, not in source
  control.

---

## Current scope & known limitations

Read these before enabling the v2 report for a live client deliverable. None
produce a *wrong* number — each is an honest degrade or a guard.

- **Box-category NETs recompute under a live filter / custom banner** (e.g.
  "Top-2-Box", "Good (9-10)", and the "NET POSITIVE (top − bottom)" difference).
  The microdata carries each respondent's **box membership** (`TR.MICRO.boxes`)
  plus `net_diffs`, so these rows re-sum for a filtered audience — and it works
  whether the underlying scale is shown (SACAP shows 0–10) or hidden (CCS shows
  only the boxes). Verified on real CCS data. *(Arbitrary one-off NETs that are
  not box-categories still fall back to the published value unfiltered.)*
- **Cross-wave matching is by question title unless a `question_mapping` is set.**
  Title-matching is fragile to rewording ("…in 2025" vs "…in 2026" won't link).
  Point `question_mapping` at the classic tracker's `Question_Mapping.xlsx` and
  waves link by the canonical `Track_NN` key instead — robust to renames, and the
  same curated config drives both the classic tracker and this Tracking tab. (The
  current wave's column in the mapping is auto-detected by matching codes.)
- **Numeric (binned) means** also show "–" under a filter (the mean is over raw
  values, not bins) — honest degrade.
- **Data-derived multi-select categories** whose published label is a *semantic*
  recode of the raw value (e.g. `DK` → `Don't know`) with **no** structure option
  to bridge them may under-count under a custom filter. Fix data-side by defining
  the option in `Survey_Structure`.

Everything else — values, weighted recompute, significance (effective n),
means / NPS — recomputes correctly and matches the published figures.

---

## Where the code lives

| Concern | File |
|--------|------|
| Aggregates island + project block + logos | `modules/tabs/lib/data_layer_writer.R` |
| Shared scoring helpers (`index_scores`, NPS buckets, option values) | `modules/tabs/lib/score_utils.R` |
| Microdata island (`TR.MICRO`) | `modules/tabs/lib/microdata_writer.R` |
| Tracking island assembler (`TR.PREV`) | `modules/tabs/lib/tracking_island.R` |
| Bundler (inlines renderer + islands → one HTML) | `modules/tabs/lib/html_report_v2/build_report_v2.R` |
| Vendored renderer (engine + v2 modules) | `modules/tabs/lib/html_report_v2/assets/` |
| Wiring (Step 4d) | `modules/tabs/lib/run_crosstabs.R` |
| Tests | `tests/testthat/test_{data_layer_writer,microdata_writer,tracking_island,report_v2_bundler}.R` + prototype `tests/run_tests_v2.mjs` |

The renderer is vendored from `prototypes/report-redesign/fable/v2/` (the
source-of-truth for the JS); the two must stay in sync.
