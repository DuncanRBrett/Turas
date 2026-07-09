# Aggregate-Wave Tracking — setup & reuse guide

How to show a tracker's **full history** in the v2 report's Tracking tab when the
old waves survive only as published summary figures — a percentage, an average,
an NPS net — with no respondent-level data. The recent wave stays live from its
own microdata; the old years are stitched on behind it as one continuous trend,
and the significance stays honest.

Built and proven on CCPB CSAT (2012→2026). Reusable as-is for CCS, SACAP student,
or any tracker you take over.

---

## 1. The idea in one paragraph

A tracker might have run for fifteen years, but you only hold the raw
respondent-by-respondent data for the last wave or two. Everything before that
lives as summary numbers in a spreadsheet. This feature converts those summary
numbers into small per-wave files ("sidecars") that the v2 report already knows
how to read, so the historical years drop straight onto the trend line next to
your live data. The one rule it never breaks: it does not invent the pieces a
significance test needs. Where a number can be tested honestly it is; where it
can't, the point is drawn but left untested — never a fabricated arrow.

---

## 2. The moving parts

| Piece | Where | What it is |
|---|---|---|
| **Engine** | `modules/tabs/lib/tracking_aggregate_bridge.R` | Turns a values table into the wave-island sidecar shapes. Already tested (`tests/testthat/test_tracking_aggregate_bridge.R`). You don't edit this. |
| **Generator** | `modules/tabs/examples/aggregate_wave_backfill.R` | The script you run. Values table + QuestionMap → sidecars, with a verification summary. |
| **Templates** | `modules/tabs/templates/Aggregate_History_Values_Template.xlsx` and `Aggregate_QuestionMap_Template.xlsx` | Copy these to start a new project. |
| **Two inputs you prepare** | your project folder | A **values table** and a **QuestionMap** (sections 3–4). |

The current (live) wave needs nothing extra — its own tabs run produces its
microdata automatically. You are only backfilling the *prior* waves.

---

## 3. What you prepare — the two inputs

### Input A — the values table (the history, one row per number)

A long table, `.csv` or `.xlsx`, one row per (metric, wave):

| column | required | meaning |
|---|---|---|
| `metric_id` | yes | The **live survey QuestionCode** this figure belongs to (e.g. `Q02`). This is the link to the current wave — see the convention below. |
| `wave` | yes | The wave identifier (e.g. `2019`). A 4-digit year in it becomes the x-axis position. |
| `metric_type` | yes | `mean`, `proportion`, or `nps`. |
| `value` | yes | The published figure, exactly as reported (an average like `9.0`, a percentage like `51`, an NPS net like `72`). |
| `base` | optional | Effective base *n* for that figure. **Blank = unknown** → the point plots untested. Never make one up. |
| `sd` | optional | Standard deviation, for `mean` rows only. **Blank = not recorded** → the mean plots untested. |

**The load-bearing convention:** `metric_id` must equal the **live** survey's
QuestionCode for that question — the code in the current wave's data (e.g. `Q02`),
not the old questionnaire's numbering. That is how a 2013 figure knows it belongs
on the same line as the 2026 question. Getting this mapping right (old wording →
live code) is the one genuinely manual step; do it by meaning and verify each one
against the live survey structure.

### Input B — the QuestionMap (which metrics track, and how)

An `.xlsx` with a sheet named **QuestionMap**, one row per tracked metric:

| column | meaning |
|---|---|
| `QuestionCode` | The canonical/live code — **the same value as `metric_id`**. |
| `QuestionText` | The display title. |
| `TrackingSpecs` | `mean`, `nps_score`, or `category:<label>` (see below). |
| `Wave<YEAR>` | The current wave's data column for this metric — usually the same as `QuestionCode`. The report uses this to confirm the mapping matches the live data and to key the current wave by code. |

`TrackingSpecs` tells the report what kind of metric each row is:
- **`mean`** — a rating / scale average.
- **`nps_score`** — an NPS net.
- **`category:<label>`** — a proportion. `<label>` is the crosstab row this % should
  line up with. For a single option, use that option's **exact displayed label**
  (e.g. `category:Yes`, `category:Always`). For a **NET** of several options, use
  the exact **BoxCategory** label you give the NET in the Survey_Structure (section 4).

Matching is forgiving about case and punctuation (both sides are normalised the
same way — e.g. `Merchandised by CCPB/agency` → `merchandised by ccpbagency`), but
the words must be the same on both sides.

---

## 4. NETs (a proportion that combines several options)

Sometimes the historical metric is a **combination** of options, not a single one
— "% quarterly or better" (Monthly + Quarterly), "% shop around" (Sometimes +
Always). To track one of these:

1. In the **Survey_Structure Options sheet**, give the member options a shared
   label in the **`BoxCategory`** column. That renders a NET row in the report
   showing their combined %. (Partial grouping is fine — you only box the options
   the NET needs; the rest stay as normal rows.)
2. In the QuestionMap, set that metric's `TrackingSpecs` to `category:<that exact
   BoxCategory label>`.

The BoxCategory label and the `category:` label must be identical — that's the
whole join. Only single-response questions support BoxCategory NETs; a
Multi_Mention "any of these" NET is **not** covered this way and needs a separate
approach (on CCPB, Q03 "out of stock on any day" was left as a known gap).

---

## 5. Generate the sidecars

Run the generator, pointing it at your two inputs and an output folder (this
folder becomes your `waves_source`):

```bash
AGG_VALUES=/path/to/values.csv \
AGG_QMAP=/path/to/QuestionMap.xlsx \
AGG_OUT=/path/to/waves_source_folder \
Rscript modules/tabs/examples/aggregate_wave_backfill.R
```

It writes one `<wave>_wave.json` per wave and prints a verification summary —
how many waves, how many metrics, and how many carry a base / an sd (i.e. how many
can be significance-tested). Read that summary: if it says everything is untested,
that's expected until you supply bases/sd (section 7).

Run with no env vars and it reproduces the CCPB worked example.

---

## 6. Wire the config and run

In the crosstab config's **Settings** sheet:

| setting | value |
|---|---|
| `html_report_v2` | `True` |
| `html_report_v2_tracking` | `True` |
| `waves_source` | **absolute** path to the sidecars folder |
| `question_mapping` | path to the QuestionMap (relative to the config file is fine) |
| `wave` | the current wave's label (e.g. `W2026`) |
| `wave_order` | the current wave's numeric position (e.g. `2026`) |

Then re-run the tabs report the normal way (launch_turas). The Tracking tab
appears **only if the assembled island has more than one wave** — so if it stays
hidden, that's the first thing to check (section 8).

> **Why `waves_source` must be absolute:** the report reads it raw, without
> resolving it against the config folder (unlike `question_mapping`, which it
> does resolve). A relative `waves_source` may not point where you expect.

---

## 7. How significance works (honest by design)

This is the heart of the feature. A historical figure is only tested when the
ingredients for an honest test are actually present:

- **Mean** — tested only when the values table gives it an **sd** (and a base).
  Old summary sheets almost never recorded the sd, so historical means usually
  plot **untested**. The live microdata wave computes its own sd, so it is tested.
- **Proportion** — tested (a real pooled z-test) wherever a **base** is present.
  No base → untested. This is the cheapest significance to switch on: a base is
  often recoverable even when raw data isn't.
- **NPS** — a net score on its own can't be tested (no promoter/detractor split),
  so it is **always** untested as history.

So a freshly-built aggregate history with blank bases and sds shows the full trend
line but **no significance markers**. That is correct, not a bug. You are seeing
fifteen years of movement honestly; the arrows appear as you supply more (next
section).

---

## 8. Moving from aggregate history to microdata

"Aggregate" and "microdata" aren't a one-way door — significance switches on
**incrementally** as you feed the trend more. There are three ways it happens, in
rough order of how often you'll use them.

### A. Going forward — new waves are microdata automatically (nothing to do)

Every new wave you field and run through Turas the normal way is **already**
microdata: its own tabs run writes its own sidecar from per-respondent scores, so
it is fully tested against the wave before it. The aggregate history just sits
behind it as the untested backdrop. Over time the tested, microdata part of the
line grows from the right; the old aggregate part stays as context. You do not
touch the sidecars for this — it's automatic.

### B. You get the old bases (but not the raw data) — the practical upgrade

Often you can recover the historical **base sizes** — how many people each old
figure was based on — even when the raw respondent data is long gone. When you do:

1. Fill the `base` column in the values table for those waves (and the `sd`
   column too, for any means where you have it).
2. Re-run the generator (section 5) to regenerate the sidecars.
3. Re-run the report.

Now every historical **proportion with a base gets a real z-test**, and any
**mean with an sd gets tested**. This is the highest-value, lowest-effort way to
bring significance to the back-history — no microdata required. NPS stays
untested (a net still has no split).

### C. You get a specific old wave's raw respondent data — full conversion

If the actual respondent-level data for an old wave turns up, you can convert
that one wave to true microdata:

1. Run that wave's data through Turas tabs as its own run. That produces a
   microdata `<wave>_wave.json` — one carrying per-respondent **scores**, from
   which the report recomputes the mean **and** the dispersion.
2. Drop that file into the `waves_source` folder **in place of** the aggregate
   sidecar for that wave (same wave label).

The report then recomputes that wave's value and significance live from the
scores, exactly like the current wave.

**Two honest caveats for path C:**
- A microdata sidecar carries the **mean-kind** metrics (ratings, NPS) only — it
  does **not** carry proportions. Proportions for a prior wave still come from the
  aggregate sidecar's stored rows. So if a wave has both, you usually want path B
  (keep the aggregate rows, just add bases) rather than replacing the file
  wholesale, or you'll lose that wave's proportion history.
- The recomputed mean can differ slightly from the published figure (rounding, or
  a different base). That's the microdata telling the truth; expect small
  movements, not identical numbers.

### What actually changes when a wave becomes tested

Significance arrows appear for and against it, the value may shift a touch (path
C), and the dashboard/summary treat it like any live wave. The design lets you
flip **any single wave** between aggregate and microdata without disturbing the
others — so you can upgrade the history one wave at a time as data becomes
available.

---

## 9. Worked example — CCPB CSAT

- Files live at `…/CCPB/CSAT/W2026/03 Tracker/v2 tabs tracking/`: `sidecars/`
  (14 files, 2012–2025), `CCPB_v2_question_mapping.xlsx`, `ccpb_v2_values.csv`.
- Source history: `…/W2026/02 Data/CCPB Question History.xlsx` (wide sheet; the
  `QuestionCode` column carries the live-code annotation).
- 53 metrics tracked (25 ratings, 1 NPS, 27 proportions), 2012→2025 as aggregates
  behind the live 2026 microdata wave.
- Four NETs via BoxCategory: `Shop around` (Q05), `Quarterly or better` (Q34),
  `Within 12 months` (Q35), `Merchandised by CCPB/agency` (Q16).
- Known gap: Q03 (a Multi_Mention "any day" NET) — not yet trackable via
  BoxCategory.
- All history currently plots untested (no bases/sd supplied yet) — a textbook
  case for the section-8B upgrade when the historical bases are recovered.

---

## 10. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Tracking tab doesn't appear | The island has ≤1 wave. Almost always `waves_source` isn't resolving — confirm it's the **absolute** path to the folder that actually contains the `*_wave.json` files. |
| Tab appears but a question has no history | The current wave keyed by title instead of code — `question_mapping` isn't pointing at your QuestionMap, or its `Wave<YEAR>` codes don't match the live data. |
| One proportion/NET has no history | Label mismatch — the `category:<label>` in the QuestionMap doesn't match the crosstab row / BoxCategory label. Compare them (case/punctuation are normalised; the words must match). |
| No significance anywhere | Expected if no bases/sd are supplied. See section 7–8. |
| A Multi_Mention "any" NET won't track | Not supported via BoxCategory (the CCPB Q03 case). Needs a separate mechanism. |

---

## 11. Files at a glance

```
modules/tabs/
  lib/tracking_aggregate_bridge.R           the engine (don't edit)
  examples/aggregate_wave_backfill.R        the generator (run this)
  templates/Aggregate_History_Values_Template.xlsx    (values table; a real one may be .csv or .xlsx)
  templates/Aggregate_QuestionMap_Template.xlsx
  docs/AGGREGATE_TRACKING_GUIDE.md          this guide
  docs/V2_AGGREGATE_TRACKING_PLAN.md        the original design/build plan
  tests/testthat/test_tracking_aggregate_bridge.R   locks the engine's shapes
```
