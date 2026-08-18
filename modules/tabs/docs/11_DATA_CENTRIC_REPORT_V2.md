# Tabs Data-Centric Report v2 (+ confidence, + tracking)

The data-centric report v2 is a single, self-contained, offline HTML report the
tabs module emits **alongside** the Excel workbook. Rather than pre-rendering
tables, it embeds the data as JSON "islands" plus a small renderer that
recomputes views in the browser — so the reader can filter the audience, build
custom banners, and (for trackers) explore wave history, all without leaving the
file or contacting a server.

This is the report Turas ships. (An earlier pre-rendered HTML report — the
"classic" report — was retired in August 2026 and its code deleted; a config
that still sets `html_report` is told so on load.) The report is written
whenever the GUI runs; a config can force it on or off with `html_report_v2`,
and the Excel workbook is byte-for-byte the same either way.

---

## The three cumulative options

Each option is a superset of the one before it. All are off by default.

| Option | What the reader gets | Turn it on with |
|--------|----------------------|-----------------|
| **1. Workbook only** | The Excel workbook | (always written) |
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

### Which statistic a question reports (`stat`)

Each `data-agg` question puts ONE quantity in its rows' `pct` array. Normally
that is the **column percentage** — but a config with `show_percent_column = N`
puts row percentages or raw frequencies there instead, and a single row that has
no column percentage substitutes another statistic of its own.

- `question.stat` — `"Column %"` | `"Row %"` | `"Frequency"` | `"Average"`.
- `row.stat` — set only when that row differs from its question's.

Both are **emitted only when they are not `"Column %"`**, so an ordinary report's
island is byte-identical and a reader that finds neither treats the values as
column percentages (which every report built before this field did carry).

`TR.fmt.statOf / isPctStat / isColPctStat / statName / value` are the single
vocabulary. Anything that assumes a column proportion — the "%" suffix, Wilson
intervals, data bars, the heat tint, wave trending, the Differences pp gaps, the
Patterns/KeyShare share scans and the confidence explainer's worked example —
must gate on it. A filtered/custom-banner recompute always produces column
percentages, so its model reports `stat: "Column %"` plus `statWas` naming what
the question published, and the table says so rather than silently changing unit.

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

The Tracking tab has its own **Significance** control (in the pulse bar:
off / 95% / 95% + 80%) that sets the same report-wide `d2.state.sigMode` the
Crosstabs tab uses — change it on either tab and both follow. With **95% + 80%**
chosen, every wave-on-wave comparison carries two flags instead of one:
`sig_prev`/`sig_base` (significant at 95%, the solid ▲▼ marker) and
`soft_prev`/`soft_base` (significant at **80% but not 95%**, the hollow △▽ marker
+ a "nearly significant" pulse tally). `cellsFor(points, canSig, mode)` reads the
mode directly: `off` suppresses all flags, `95` is strong-only, `dual` adds the
soft band. Soft flags are only populated in dual mode, so the default 95%-only
report is unchanged. This catches real-but-noisy moves — e.g. an NPS that, at
n≈60, has a ±28-point 95% margin, so a 25-point drop reads as nearly-significant
rather than vanishing into "stable". The 80% level is the same one the crosstab
tab marks with lowercase letters; thresholds are `stats.Z95` / `stats.Z80`.

#### Narrative pulled from the config (Comments sheet → report)

The report fills its narrative from the config's **Comments sheet** — nothing
is hand-retyped:

- **Per-question insights**: each question's comment is carried in
  `AGG.comments[code] = [{banner, text}]` and pre-fills that question's *Analyst
  insight* box (`TR.insights.get` falls back to the config comment, banner-
  specific first then general). The analyst's own edit overrides it.
- **Background & method** and **Executive summary**: the reserved `_BACKGROUND`
  and `_EXECUTIVE_SUMMARY` rows ride in `project.report_meta.background` /
  `.exec_summary` and pre-fill those (editable) Report-tab sections.
- **About this report** is **read-only** — analyst, contact and disclaimers come
  straight from the config (`report_meta`) and are displayed, not edited.

All of this is omitted from the data layer when not configured, so a report
without a Comments sheet is byte-identical to before.

#### Question & category order (Selection sheet)

The data layer emits `questions[]` grouped by category in the Selection sheet's
order — categories by `CategoryOrder` (then first-appearance), questions in
their within-category order, uncategorised last — exactly like the crosstab
workbook (`workbook_builder.R`). So the report opens on, and groups by, the
same sections as the workbook (e.g. an "Overall metrics" category with
`CategoryOrder = 1` leads, and `state.activeQ` defaults to its first question).
`categories[]` carries the same order; the renderer's `d2.categories()` groups
by `questions[]` appearance, so nothing else needs to know the order. A config
that sets no `CategoryOrder` keeps first-appearance order (still grouped).

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
| `html_report_v2_microdata` | `Y` | Embed the anonymised per-respondent microdata island. `N` = the **confidentiality ship**: an aggregates-only file for insider populations (see Anonymisation & governance) — the live filter, custom banners, COMPUTED views and the Tracking tab switch off for that build. Only an explicit `N`/`FALSE` disables; blank keeps the island. |
| `html_report_v2_tracking` | `N` | Add the Tracking tab (Option 3). Requires `html_report_v2 = Y` and a `waves_source` with prior contributions. Weighted studies are supported (the wave trend is weighted to match the crosstab). |
| `waves_source` | *(blank)* | Folder holding prior waves' `*_wave.json` contributions (see Forward path). |
| `question_mapping` | *(auto)* | Path to the classic tracker's `Question_Mapping.xlsx` (absolute, or relative to the project root / config dir). **Blank → auto-detected**: a `*Question_Mapping*.xlsx` in `waves_source`, the project root, or the config dir. When found, waves link by its **canonical key** (`Track_01`…) — robust to renames — and only the mapped metrics track, each with its `TrackingSpecs` metric. None found → metrics match by question **title** (fragile to wording drift). |
| `wave` | *(blank)* | Wave label shown in the header and used as the trend label. |
| `wave_order` | *(blank)* | Numeric x-axis order key for this wave (e.g. `2025.5`). Blank → a 4-digit year is parsed from the `wave` label. |
| `researcher_logo_path` / `client_logo_path` | *(blank)* | Logos embedded (base64) into the v2 header. |
| `sampling_method` | `Not_Specified` | Drives honest CI vocabulary (probability → CI/MOE; otherwise stability/PE). |

Outputs land next to the Excel file: `<project>_report.html` (the interactive
report — built by default from the GUI), `<project>_data.json`, and (tracking
on) `<project>_wave.json`.

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
- **Anonymised ≠ unidentifiable for insiders.** The coded records decode against
  the labels shipped in the same file, so a recipient who *knows the population*
  (an employer reading a small staff survey) can re-identify small cells from
  banner-variable combinations and then read that respondent's full answer
  vector. The display k-gate (`min_reporting_base`) governs what *renders*, not
  what ships in the page source. For those ships set
  `html_report_v2_microdata = N`: the file then carries published aggregates
  only — the same confidentiality as a printed report. Costs: no live filter,
  custom banners or COMPUTED views; the Tracking tab is skipped for that build
  and no `_wave.json` is written (keep the wave file from your full build).
  Recommended workflow: **two configs** — your own working copy with microdata
  ON, the client copy with it OFF — and pair the client copy with the qual
  dials (`qual_confidentiality_mode` hidden, `qual_demographic_cuts = block`)
  for a fully source-safe ship.

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

## Where the report's words come from

The interpretive prose in a v2 report — the explainers, legends, method notes
and the About card's construction note — is **authored, not coded**. It lives in
the shared callout registry (`modules/shared/lib/callouts/callouts.json`, module
`tabs`) and is edited in the **Callout Editor**, launched from `launch_turas()`.
The renderer holds no fallback wording: if a sentence is not in the registry, it
does not exist.

Three pieces, and the loop between them closes itself:

| Piece | File | Holds |
|---|---|---|
| The words | `modules/shared/lib/callouts/callouts.json` (module `tabs`) | what the report says |
| The contract | `modules/tabs/lib/html_report_v2/assets/text_manifest.json` | which keys exist, what `{placeholders}` each may use, and where it renders |
| The check | `modules/tabs/lib/html_report_v2/report_text.R` | validates one against the other at build time and emits the `#data-text` island |
| The lookup | `assets/js/02_text.js` (`TR.txt`) | serves a key to the renderer |

### One block, one entry

A thing the reader sees as one thing is **one entry**, however many paragraphs
or bullets it renders as. The whitespace carries the structure: a **blank line**
starts a new paragraph, a **single newline** starts a new bullet. So the whole
"Understanding the significance testing" panel is one entry of six paragraphs,
and "Reading this table" is one entry of five bullets.

Text is only split across entries when the code has to choose between the
pieces — a sentence that renders only on a weighted report, a clause that
appears only at the 80% level, two forms of the same sentence for reports with
and without a base. Where a conditional sentence sits *inside* an otherwise
continuous block, it arrives as a placeholder instead (`{waves_note}` in the
Report construction note), so the author still edits one entry and decides where
that sentence goes — or deletes the placeholder to never say it.

### Adding a new authored block

1. Call it where it renders: `TR.txt.block("cards.my_note")`, or
   `TR.txt("cards.my_note", { level: 95 })` for a fragment inside other markup.
2. Declare it in `text_manifest.json` with its `page`, `context` and `tokens`.
3. Write the text in the Callout Editor, under module `tabs`.

Miss step 2 or 3 and the next build **refuses and names the key** — the renderer
is scanned for its own `TR.txt(...)` calls, so nothing can silently render blank.
A build also refuses on a `{placeholder}` the key does not declare, on markup
outside the inline whitelist (`strong em b i br p ul ol li h3 h4 span code sup sub`,
all balanced, no attributes), and on a key deleted from the registry.

**Blank text is legitimate** and means "do not show this block on any report" —
that is how an author switches a paragraph off without a code change. Deleting
the entry is a different act, and refuses.

### Finding a block's key on the page

Open a report and press **ctrl+alt+K** (or open it with `#keys=1`). Every
authored block wears its key; click one to copy it, then paste it into the
Callout Editor's filter. Gold badges are platform text from the editor; navy
`config:` badges are text this study wrote in its own config (the Comments
sheet's `_BACKGROUND`, `_EXECUTIVE_SUMMARY`, `_REPORT_CONSTRUCTION`), which the
editor does not own.

The flag is author-only by construction: it is not in `d2.encodeHash()`, so it
cannot travel in a shared link; not in `report.saveCopy()`'s state whitelist, so
it cannot be baked into an annotated copy; and PNG/PPTX exports render from the
data model rather than the DOM, so badges cannot reach a deck.

### The rule for tests

**No test may assert on authored wording.** Assert on the catalogue value
(`TXT(key)` from `tests/_text.mjs`) or on the `data-txt-key` attribute. Enforced
by the mutation check, which reruns the whole node suite against a catalogue
whose every value has been replaced:

```
node modules/tabs/lib/html_report_v2/tests/mutate_text_check.mjs
```

It must pass. A failure there is a test pinned to words the report author is
entitled to change.

### Overriding the wording for one study

Platform text is edited once, in the Callout Editor, and every study picks it up
at its next generation. When ONE study has to say something differently, put the
key and its replacement in the config's **ReportText** sheet.

The sheet ships empty and should usually stay that way. A missing row or a blank
`Text` cell means "use the platform wording" — so a config can never quietly
carry a stale copy of text that has been improved since. A `Key` that matches
nothing refuses the build and names it, because a typo there looks exactly like
an override that is working. Overrides are validated like any other authored
text, and apply to that build only; the registry is untouched.

A study's own *narrative* (background, executive summary, how its numbers were
built) still belongs in the Comments sheet's `_BACKGROUND`,
`_EXECUTIVE_SUMMARY` and `_REPORT_CONSTRUCTION` rows. ReportText is for the
report's standing explanatory furniture.

### Editing operationally

Text applies at the **next report generation** — an editor save changes nothing
in an HTML file that already exists. `callouts.json` is repo content: commit it
like code. The editor writes it atomically and keeps its last ten saves under
`modules/shared/lib/callouts/backups/`.

## Where the code lives

| Concern | File |
|--------|------|
| Aggregates island + project block + logos | `modules/tabs/lib/data_layer_writer.R` |
| Shared scoring helpers (`index_scores`, NPS buckets, option values) | `modules/tabs/lib/score_utils.R` |
| Microdata island (`TR.MICRO`) | `modules/tabs/lib/microdata_writer.R` |
| Tracking island assembler (`TR.PREV`) | `modules/tabs/lib/tracking_island.R` |
| Bundler (inlines renderer + islands → one HTML) | `modules/tabs/lib/html_report_v2/build_report_v2.R` |
| Vendored renderer (engine + v2 modules) | `modules/tabs/lib/html_report_v2/assets/` |
| Authored text: validation + island | `modules/tabs/lib/html_report_v2/report_text.R`, `assets/text_manifest.json` |
| Authored text: the words | `modules/shared/lib/callouts/callouts.json` (module `tabs`), edited in the Callout Editor |
| Per-study text overrides | `ReportText` sheet -> `load_report_text_sheet()` in `crosstabs/crosstabs_config.R` |
| Wiring (Step 4d) | `modules/tabs/lib/run_crosstabs.R` |
| Tests | `tests/testthat/test_{data_layer_writer,microdata_writer,tracking_island,report_v2_bundler,report_text}.R` + the node suite in `html_report_v2/tests/` (`*_tests.mjs`, plus `mutate_text_check.mjs`) |

The renderer under `modules/tabs/lib/html_report_v2/assets/` **is** the
source of truth. It began as a vendored copy of
`prototypes/report-redesign/fable/v2/`, and that line used to say the two must
stay in sync — but the prototype has carried no `assets/js` for some time, so
there is nothing there to sync with. What remains under `prototypes/` is design
history: read it for how the v2 report came to be shaped this way, not for code.
(Retired 2026-08-17, with the authored-text work, which changed the vendored
renderer and could otherwise have been erased by a future "re-vendor" sweep.)
