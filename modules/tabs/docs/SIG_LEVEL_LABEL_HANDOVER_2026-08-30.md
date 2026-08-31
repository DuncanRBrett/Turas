# Handover — three v2 report defects found on the ASSA project

Three independent, small defects, each fixable on its own. All three are display
or ordering issues: **no computed value in any report is wrong.**

1. **The secondary significance level is labelled "80%" regardless of config** —
   shared callouts + html_report_v2. ASSA is the only report currently affected.
2. **Banner DisplayOrder is sorted as text**, so a tenth banner renders first —
   `banner.R`. One-line fix, mirrors what `data_setup.R` already does.
3. **An Index row never says what scale it is on** — html_report_v2 renderer.
   The data it needs already ships.

Items 2 and 3 start after the horizontal rules below.

---

# ITEM 1 — the HTML report hard-codes "80%" for the secondary significance level

**Date:** 2026-08-30
**Scope:** `modules/shared/lib/callouts/` + `modules/tabs/lib/html_report_v2/`
**Type:** cosmetic/labelling defect. **No computed value is wrong.**
**Raised from:** ASSA "Unlocking the Annuity Puzzle" analysis session.

---

## 1. The defect in one paragraph

The v2 HTML report tells the reader that lowercase significance letters mean **80%**
confidence. That string is hard-coded. The actual level is whatever the project config
sets in `alpha_secondary`, and the engines (both R and the in-browser JS) honour that
setting correctly. When a project configures `alpha_secondary = 0.1` the letters are
computed at **90%** and the report still calls them 80%. The Excel crosstab labels the
same letters correctly as `Sig. (90%)`.

**The letters themselves are correct in both outputs. Only the HTML prose is wrong.**

---

## 2. Correct a false premise before you start

This was originally raised as "it also affects the CCPB report". **It does not.**
I scanned every `*_data.json` under `OneDrive/DB Files/TurasProjects`:

| Report | `alpha_secondary` | True secondary level | HTML says | Mismatch |
|---|---|---|---|---|
| **ASSA Annuity Puzzle** | **0.1** | **90%** | 80% | **YES** |
| CCPB CSAT W2026 | 0.2 | 80% | 80% | no |
| CCPB CSAT W2025 | unset → 0.2 | 80% | 80% | no |
| CCPB CCS W2025_02 | unset → 0.2 | 80% | 80% | no |
| CCPB CCS W2026_01 | unset → 0.2 | 80% | 80% | no |
| Electrum VAS 2026 (pilot + reporting) | 0.2 | 80% | 80% | no |
| SACAP SACS-2025 / SACS-2026 | 0.2 | 80% | 80% | no |

**ASSA is the only report currently mislabelled.** Every other project either sets
`alpha_secondary = 0.2` (80%, which the hard-coded string happens to match) or leaves it
unset, in which case the code falls back to 0.20 and the label is right by accident.

Two consequences for how you approach this:

- This is a **latent defect** everywhere except ASSA. It is worth fixing because it is
  a trap, not because eight reports are currently lying.
- **The fix must be a visual no-op for every project except ASSA.** If your change alters
  what CCPB, VAS or SACS display, you have broken something. That is your regression test.

---

## 3. Evidence the numbers are fine (do not redo this — but you may re-verify)

Recomputed every pairwise two-proportion z-test from the published counts in
`ASSA_Annuity_Puzzle_Crosstabs_data.json` and compared against the letters the engine
assigned, using the project's Bonferroni divisor (m = k(k−1)/2 pairs per banner group).

- 31 letters appear in `sig2` but not `sig`. All 31 clear the Bonferroni-adjusted
  **90%** threshold.
- That alone cannot separate 90% from 80% (anything passing at 90% also passes at 80%),
  so the discriminating test: comparisons that would earn a letter at 80% **but not** at 90%.
  **138 such comparisons exist. Exactly 0 were lettered.**

Worked examples:
- `Q39_DEPENDANTS` "1", Male vs Female: z = 1.706. crit90 = 1.645, crit80 = 1.282 (m=1).
  Lettered. Consistent with 90%.
- `Q08_INCOME` "More than R80 000", Gauteng vs Cape Town: z = 2.070. crit90 = 2.128,
  crit80 = 1.834 (m=3). **Not** lettered. Would have been at 80%.

Conclusion: the engine tests at the configured `alpha_secondary`. Only the wording lies.

---

## 4. Root cause

`alpha_secondary` became configurable; the prose that describes it did not follow.
The secondary level used to be a fixed 0.20 convention and the help text still assumes it.

### What is already correct (reuse these — do not reinvent)

| Location | What it does |
|---|---|
| `modules/tabs/lib/data_layer_writer.R:128` | reads `alpha_secondary` from config, writes it into the report JSON. Falls back to 0.20 only when absent/invalid. |
| `modules/tabs/lib/html_report_v2/assets/js/21_stats.js:57-65` | `projAlpha2()` reads `project.alpha_secondary`; `stats.zSecondary(m)` derives the critical value. The in-browser recompute (used when filtering) is therefore also correct. |
| `modules/tabs/lib/html_report_v2/assets/js/24a_reader.js:137-146` | `levelText(alpha)` → `Math.round((1-alpha)*100) + "%"`, plus `primaryLevel()` / `secondaryLevel()` and the `reader._levels()` accessor. **This is the correct helper.** Its own comment says the wording must never be a hard-coded "95%"/"80%". Only the reader layer uses it. |
| `modules/tabs/lib/crosstabs/crosstabs_config.R:48` | `alpha_to_confidence_label(alpha)` → `"Sig. (95%)"` / `"Sig. (90%)"`. This is why **Excel is right**. Already covered by tests. |

### What is wrong — user-visible hard-coded strings

**Shared callouts (highest priority — these are the main legend and the long explainer):**

- `modules/shared/lib/callouts/callouts.json:286`
  > "…UPPERCASE letters = 95% confidence; with the 80% option on, **lowercase letters = 80%** (directional, weaker evidence)."
- `modules/shared/lib/callouts/callouts.json:808`
  > "…we call it significant at the 95% level. At 80% it is less than one in 5… Upper case denotes significant at 95%, lowercase at 80%. Letters require a sample of at least {min_base} to show."

Note `callouts.json` **already supports token substitution** — `{min_base}`, `{n}`,
`{threshold}`, `{interval_abbrev}`, `{universe}`, `{moe_pp}` and others are in use.
Adding `{alpha_pct}` / `{alpha2_pct}` is consistent with the existing design, not a new
mechanism. Renderer: `modules/shared/lib/callouts/callout_registry.R`.

**JS strings (rendered, not comments):**

| File | Lines |
|---|---|
| `assets/js/25_cards.js` | 258 — `>95% + 80%</option>` (mode selector) |
| `assets/js/27d_diffs.js` | 492 — `" — nearly significant (80%)"`; 580 — `>95% + 80%</option>` |
| `assets/js/27u_summary.js` | 98, 179, 231, 309, 322, 348 |
| `assets/js/27v_visualise.js` | 172, 182 |

**Lower priority — authoring/help metadata:**
`assets/text_manifest.json` — three `*.context` / `token_help` strings referencing "the
80% level". These describe the feature to whoever edits copy; they are not rendered to
report readers. Fix for consistency, not urgency.

**Do not touch:** the many `// … 80% …` code comments, and
`modules/shared/lib/callouts/backups/*.json`.

---

## 5. Proposed fix

1. Add `{alpha_pct}` and `{alpha2_pct}` tokens to `callouts.json:286` and `:808`, and
   populate them in `callout_registry.R` from the project config, following exactly how
   `{min_base}` is supplied today (see `assets/js/25_cards.js:852` for the tabs-side
   pattern: `paragraphs("cards.sig.explainer", { min_base: p.low_base_threshold })`).
2. Promote `levelText` / `primaryLevel` / `secondaryLevel` out of `24a_reader.js` into a
   shared helper on `TR.stats` (next to `alphaPrimary` / `alphaSecondary` in
   `21_stats.js`, which is where the tests already look), then have `24a_reader.js`
   consume it rather than defining its own.
3. Replace each hard-coded JS string in the table above with the derived value.
4. Sentences of the form "significant at 80% (not 95%)" need **both** levels
   interpolated, not just the secondary one.

### Constraints (from `CLAUDE.md`)

- TRS: no `stop()`. Return structured refusals; echo errors to console for Shiny.
- Tests before merge. `styler::style_file()` on changed R files.
- No behaviour change to letters, thresholds or `sig`/`sig2` computation. **Labels only.**

---

## 6. Tests

`modules/tabs/tests/testthat/test_dual_significance.R` (461 lines) already asserts
`alpha_to_confidence_label()` maps 0.05→95%, 0.10→90%, 0.01→99%, 0.20→80%. It tests the
**Excel** label path only. Extend coverage so the **HTML** label path is asserted the same way:

- a config with `alpha_secondary = 0.1` must render "90%" in the legend, the mode
  selector and the tooltips — and must render **no** user-visible "80%".
- a config with `alpha_secondary = 0.2` must still render "80%" everywhere (the no-op
  guarantee for CCPB / VAS / SACS).
- a config with `alpha_secondary` absent must behave exactly as today (0.20 → "80%").

JS suites live in `modules/tabs/lib/html_report_v2/tests/` —
`parity_stats_tests.mjs` and `reader_polish_tests.mjs` already reason about the 95%/80%
letter sets. Note `reader_polish_tests.mjs:412` currently asserts the string
`"lowercase = 80%"` is **absent**; check whether your change interacts with it.

Run before handing back:
```
testthat::test_dir("modules/tabs/tests")
```
plus the `.mjs` suites, and whatever shared-module suite covers `callout_registry.R`.

---

## 7. Verification

The cheapest end-to-end check, no report regeneration needed:

```bash
python3 - <<'EOF'
import re
f = "<path to regenerated ASSA report>.html"
t = open(f, encoding="utf8").read()
vis = [m for m in re.findall(r'.{0,80}80%.{0,80}', t)
       if not m.strip().startswith(('//','*','/*'))]
print("user-visible 80% strings:", len(vis))   # expect 0 for ASSA
print("count of '90%':", t.count("90%"))       # expect > 0 for ASSA
EOF
```

Baseline in the current shipped ASSA report: `90%` appears **once**, inside a code
comment. Nothing user-visible says 90%.

Then re-run for a CCPB or SACS report and confirm the visible strings are **unchanged**.

---

## 8. Boundaries

- **Do not regenerate any client report.** Duncan runs `launch_turas()` and regenerates
  himself. Fix the code, run the suites, hand back.
- **Do not touch anything under OneDrive.** Those are live client deliverables.
- Do not change `alpha_secondary` in any project config. ASSA's 0.1 is deliberate.
- The ASSA analysis is proceeding in a separate session against the existing outputs.
  The letters are correct, so that work is unaffected and does not block on this.

---

## 9. Useful context

- ASSA report: `OneDrive/DB Files/TurasProjects/ASSA/Output/ASSA_Annuity_Puzzle_Crosstabs_report.html`
  (config: alpha 0.05, alpha_secondary 0.1, bonferroni true, `differences` and
  `qualitative` tabs on; `dashboard`, `patterns`, `tracking` off).
- CCPB W2026 has **all five** tabs on, so it exercises more of the affected JS
  (`27u_summary.js`, `27t_tracking.js`) than ASSA does. Use it as the no-op regression case.
- Reading `*.xlsx` written by openxlsx: `openpyxl` chokes on dangling drawings and
  collapsed dimensions. Parse the sheet XML directly, and handle **self-closing `<c/>`
  cells** — a regex that assumes `<c …>…</c>` will silently shift columns.

---
---

# ITEM 2 — banner DisplayOrder is sorted as text

**Found:** 2026-08-30, same session, while adding an eighth banner to the ASSA project.
**Scope:** `modules/tabs/lib/banner.R`
**Type:** ordering defect. Wrong banner order on screen; no computed value affected.

This is a separate bug from the one above and can be fixed independently. It is
recorded here only so one session can pick up both.

## The defect

`banner.R:64-68` sorts the banner questions by the Selection sheet's
`DisplayOrder` with no type coercion:

```r
if ("DisplayOrder" %in% names(banner_questions) &&
    !all(is.na(banner_questions$DisplayOrder))) {
  banner_questions <- banner_questions[
    order(banner_questions$DisplayOrder, na.last = TRUE),
  ]
}
```

The config template stores `DisplayOrder` as **text** (verified in the ASSA
workbook: every cell in column F of Selection is a shared string), so `order()`
does a lexical sort. With eight banners numbered 2..9 plus one at 10, the order
becomes `"10","2","3","4","6","7","8","9"` — the tenth banner renders **first**.

Observed live on ASSA: a banner at DisplayOrder 10 appeared as the leftmost tab,
ahead of the one at 2.

## Why it has never bitten before

No project had more than nine banners, so `DisplayOrder` never reached two
digits and lexical order happened to match numeric order.

## The fix

`modules/tabs/lib/crosstabs/data_setup.R:180-183` already does the right thing
for the **Options** sheet and even carries the comment:

```r
# Convert DisplayOrder to numeric for proper sorting
if ("DisplayOrder" %in% names(options)) {
  options$DisplayOrder <- as.numeric(options$DisplayOrder)
}
```

The Selection path needs the same treatment. Coerce with `suppressWarnings(as.numeric(...))`
before `order()`, and keep `na.last = TRUE` so a blank or non-numeric entry
still sorts to the end rather than becoming an error. Check whether
`banner.R:216-219` (the per-question option ordering) needs it too — it may
already be fed the coerced Options frame from data_setup.R, in which case leave
it alone.

## Test

`order()` on a character vector is the whole bug, so the test is small:
a Selection frame with banner DisplayOrders 2, 9 and 10 supplied **as
character** must produce banner order 2, 9, 10 — not 10, 2, 9. Add it beside the
existing banner tests.

## Interim workaround now in place on ASSA

The eight ASSA banners were renumbered 2..9 so lexical and numeric order agree.
That config is correct either way and needs no change after the code fix — but
it will break again the moment a ninth banner pushes DisplayOrder to 10, so the
code fix is the real remedy.

---
---

# ITEM 3 — an Index row never says what scale it is on

**Found:** 2026-08-31, same session, reading a Likert index on the ASSA project.
**Scope:** `modules/tabs/lib/html_report_v2/` (renderer only — the data already ships)
**Type:** missing disclosure. No computed value is wrong.

Independent of the two items above. Recorded here so one session can take all three.

## The defect

A scale question renders a summary row — `Index`, `Mean` or `NPS Score` — and the
report never states how it was scored. A reader sees `31.0` on one question and
`8.5` on the next and has no way to know they are on different scales.

On ASSA, three different scoring schemes appear side by side:

| `Variable_Type` | Row rendered | Actual scale |
|---|---|---|
| Likert | `Index` | weighted mean, −100…+100, 0 = the midpoint option |
| Rating | `Mean` | plain average out of 10 |
| NPS | `NPS Score` | promoters − detractors, −100…+100 |

Two of them are labelled with the word "Mean"/"Index" and neither says which.
The "Reading this table" panel says only that Index rows are "score-weighted
means" — true, and not enough to interpret a number.

## Why this is cheap to fix

**The weights are already in the report.** Every scale question carries them in
the data layer:

```json
"index_scores":{"Much worse than expected":-100,"Somewhat worse than expected":-50,
                "About as expected":0,"Somewhat better than expected":50,
                "Much better than expected":100}
```

`21_stats.js:467`, `22w_waves.js:170` and `27d_diffs.js:193` all read it for the
in-browser recompute. Nothing renders it. So this is a display change over data
that is already present and already correct — no config work, no new column, and
it cannot drift out of step with the engine.

## The fix

Surface `q.index_scores` on the summary row. Either a tooltip on the row label
(the gold-edged `Index` row already has a distinct style to hang it off), or a
line in the "Reading this table" panel naming the scale for the question on
screen. Derive the wording from `index_scores` plus the question's type — do not
hard-code "−100 to +100", because Rating questions are 0–10 and NPS is its own
thing. Note that an NPS question's Options-sheet `Index_Weight` values are the
raw 0–10 scores and are IGNORED by the engine, so read `index_scores`, not the
config, or NPS questions will be described wrongly.

## Test

A fixture with one Likert, one Rating and one NPS question must produce three
different scale descriptions, and the NPS one must not describe itself as a mean
out of 10.

## Interim workaround now on ASSA

All 22 scale questions have the scale written into the Selection sheet's
`Source` column, generated from the config's own `Index_Weight` values rather
than typed. `Source` rather than `Formula` deliberately: `25_cards.js:604` sets
`derived: !!fml`, so any Formula value badges the question DERIVED, which would
be wrong for a question that was simply asked. Once the renderer surfaces the
scale itself, those 22 notes become redundant and can be cleared.
