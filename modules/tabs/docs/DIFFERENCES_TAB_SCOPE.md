# The Differences tab — what is wrong with it, and what changing it would cost

*Written 24 August 2026, after reviewing the tab on the live Electrum VAS 2026
report. Duncan: "points 1–3 affect broader Turas, I want this properly thought
through."*

*Everything below was checked by reading the code or driving the built report in
a browser. Nothing has been changed.*

---

## First, a correction

I told Duncan that one of the four problems — near-duplicate measures stacking
up — could be fixed from the VAS config alone. **That was wrong, and the reason
it is wrong is itself a finding.**

`27d_diffs.js` documents an escape hatch at line 33:

> A study whose labels don't match can extend the list via
> `project.insight_exclude_categories` (case-insensitive category names).

That setting cannot be reached from a config. The JavaScript reads
`TR.AGG.project.insight_exclude_categories`; `patterns_echo.R` reads
`proj$insight_exclude_categories`; `diffs_tests.mjs` test 3 exercises it by
injecting it straight into the test double. But `proj` is built in
`data_layer_writer.R` as an **explicit named list**, key by key, and that key is
not among them. It is not registered in `generate_config_templates.R` either.
Nothing writes it, so nothing can set it.

The same file already carries a comment describing the previous instance of this
exact bug — `alpha_default`, "registered, validated and offered by the config
template for a long time, but nothing ever consumed it (review 2026-08-21,
I-25)". This is that defect one layer along: consumed, tested, never written.

So there is nothing to do in the VAS config. Every fix below is engine work.

---

## What is actually wrong

Measured on the VAS report, 1,100 respondents, seven banners.

### It works

Worth saying first, because it does. The banner selector switches. The
significance testing runs and is bidirectional. The cut-off is disclosed on the
face of the page — "top 80 of 98 differences shown". Low bases are respected.
None of what follows is a correctness bug.

### 1. Every finding prints twice on a two-level banner

Gender produces 9 question cards and 18 finding lines:

> Male — Mean 152.8 vs 212.1 of the rest (194.3 overall) · −59.3
> Female — Mean 212.1 vs 152.8 of the rest (194.3 overall) · +59.3

One finding, told from both ends. On a two-level banner every card is exactly
double. `27d_diffs.js` has no concept of a reciprocal pair.

This is the single biggest readability win available: it halves the page on any
two-level cut and removes nothing.

### 2. Raw variable names lead every card

> `LongDistanceBus_Total_MonthlySpend` · Long distance bus: wallet contribution…

The config's own `QuestionText` is clean. The code prefix is added by the
renderer (`27d_diffs.js`, `f.column`). It is engineering vocabulary in a
client-facing deliverable.

### 3. The ranking surfaces the weakest findings first

Sorted by absolute difference, so a rand gap always outranks a percentage-point
gap. On VAS the top card on Gender is **long-distance bus monthly spend — a
number no respondent was asked.** It is trips × an assumed R750 a leg, on 36
male buyers. The label does say "(imputed)", which is to the config's credit,
but a modelled value should not be the first thing a reader meets.

The knock-on: almost no incidence findings surface at all. On Gender, 9 of 9
cards are derived numeric measures. "Who buys what" — the difference a lay
reader most wants — never reaches the top of the list.

### 4. Near-duplicate measures stack

Clothing accounts appear three times on one banner: `Total_SpendPerTxn`,
`Total_MonthlySpend`, `Own_SpendPerTxn`. Three views of one story, three cards,
three places in the ranking.

### 5. Coverage swings wildly between banners

| Banner | Cards | Finding lines |
|---|---|---|
| Province | 5 | 80 (capped) |
| Gender | 9 | 18 |
| Income | 9 | 80 (capped) |
| Area type | 12 | 80 (capped) |
| Race | 15 | 80 (capped) |
| Age | 20 | 80 (capped) |
| Bill payer | 39 | 80 (capped) |

Six of seven hit `MAX_FINDINGS = 80`. Gender does not come close. Flipping
banners feels random because it is: a 2-level cut can only ever produce a
fraction of what a 9-level cut produces, and nothing on the page explains that.

---

## What changing it would cost

### Where the code is

| | |
|---|---|
| Renderer | `lib/html_report_v2/assets/js/27d_diffs.js` — 451 lines, one cohesive module, carries a SIZE-EXCEPTION note against splitting it |
| Tests | `lib/html_report_v2/tests/diffs_tests.mjs` — 485 lines, ~25 named cases pinning the finding contract |
| Sibling consumer | `lib/patterns_echo.R` — the Patterns tab mirrors the same classification rule; a change to what counts as excluded must move both or they disagree |
| Config plumbing | `lib/data_layer_writer.R` (builds `proj`), `lib/generate_config_templates.R` (registers settings) |

### Blast radius

**Every Turas project that ships an HTML v2 report.** The Differences tab is not
VAS-specific. Any change to what counts as a finding, how findings are ranked,
or how many appear changes every report built after it — including ones already
delivered, if they are ever rebuilt.

That argues for changes that are **additive and default-off**, not changes to
the default behaviour, with one exception noted below.

### The five pieces, smallest first

| # | Change | Size | Risk | Default |
|---|---|---|---|---|
| **0** | **Wire `insight_exclude_categories` through** — add it to `proj` in `data_layer_writer.R`, register it in the config template, keep `patterns_echo.R` reading the same key | ~10 lines + 1 test | Very low — additive, the consumer and its test already exist | Empty, so nothing changes until a project sets it |
| **1** | **Collapse reciprocal pairs** — one card per finding, with both sides shown inside it | ~30 lines + tests | Low, but it changes what every existing report displays | Behaviour change (see below) |
| **2** | **Drop the code prefix** — show the question label, keep the code in a title attribute or a "show codes" toggle | ~5 lines | Very low | Behaviour change, cosmetic |
| **3** | **Rank by standardised effect** rather than raw difference, so a percentage-point gap and a rand gap are comparable | ~20 lines + tests | **Medium** — changes which findings reach the top, and the 80-cut-off then admits a different set | Best offered as a sort option first |
| **4** | **Per-question exclusion** — a `ExcludeFromInsights` column on the config's Selection sheet, so a study can drop a duplicate measure from Differences without dropping it from the crosstabs | ~20 lines across R and JS + tests | Low — additive | Off |

**Item 0 is the enabler and should go first regardless.** It costs almost
nothing, it makes an already-tested feature reachable, and on its own it lets
VAS exclude the imputed categories (flights, long-distance bus, TV licence) from
the findings — which removes the worst symptom of item 3 without touching the
ranking at all.

**Item 1 is the one worth arguing about.** It is the biggest readability win and
it is also the one that visibly changes every existing report. Two ways to take
it:

- as a straight behaviour change, on the grounds that printing one finding twice
  was never intended and no reader wants it; or
- behind a project setting, defaulting to the current behaviour, which is safer
  but leaves every project wrong-by-default and needs a second decision later.

I would take it as a straight change, with the tests updated in the same commit
to pin the new contract — but that is a judgement about how much churn existing
reports can absorb, which is Duncan's call, not mine.

**Item 4 replaces the VAS-config fix I wrongly promised.** It is the general
version of it, and it is what any study with Own/Oth/Total variants of the same
measure will need.

### What I would NOT do

- **Raise or remove the 80 cap.** It is disclosed, and a longer list is not a
  better one. Fix the ranking (item 3) and the top 80 becomes worth reading.
- **Split `27d_diffs.js`.** It carries an explicit SIZE-EXCEPTION note saying a
  single deterministic finding contract should not be scattered. That reasoning
  still holds.
- **Special-case VAS anywhere in the engine.** Everything above is a general
  problem; the VAS report just happens to show it clearly.

---

## Suggested order

1. **Item 0** — wire the dead lever. Additive, tiny, unblocks VAS immediately.
2. **Item 2** — drop the code prefix. Cosmetic, low risk, visible improvement.
3. **Item 1** — collapse reciprocal pairs, after Duncan decides straight-change
   versus setting.
4. **Item 4** — per-question exclusion, when a study needs it.
5. **Item 3** — the ranking, last, because it is the one that most changes what
   a report says and deserves its own before-and-after on a real study.

Items 1–3 want a before-and-after comparison on at least two studies with
different banner shapes, not just VAS, before they land.

---

## What Duncan needs to decide

| | Decision | My recommendation |
|---|---|---|
| A | Do items 1–3 at all, given they change every project's report | Yes, but staged in the order above rather than as one change |
| B | Item 1 as a straight behaviour change, or behind a setting | Straight change — one finding printed twice was never the intent |
| C | Item 3's ranking: replace the default sort, or add a sort option | Add the option first, watch it on two studies, then consider the default |
| D | Whether item 0 alone is enough for VAS for now | It is — it removes the imputed categories from the findings, which is the worst of what he saw |
