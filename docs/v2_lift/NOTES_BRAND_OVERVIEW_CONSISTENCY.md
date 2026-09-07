# Brand Overview: three inconsistencies a real four-category report showed

**Date:** 7 September 2026. Worktree `/Users/duncan/Dev/Turas-overview`,
branch `fix/brand-overview-consistency`, cut from main at `36f97062`.

Scope: the Overview only. Three findings Duncan and a third-party reviewer
raised against his real four-category IPK report.

1. The Overview asserted a funnel and a conversion on a report whose funnel
   destination denies both.
2. The header misdated the study: it printed the report's generation month
   with no label, next to the wave number.
3. The category Overview destination was a route card, so clicking a category
   landed the reader on a page that told them to go somewhere else.

Every R run in this log was prefixed
`TURAS_ROOT=/Users/duncan/Dev/Turas-overview`. Every report was generated into
a scratchpad. Nothing was written into the repository, into OneDrive or into
any TurasProjects folder, and Duncan's real IPK config was never opened.

## Baseline, executed before the first edit

- Working tree clean at `36f97062`, branch `fix/brand-overview-consistency`,
  worktree confirmed with `git rev-parse --show-toplevel`.
- Brand suite from the repo root:
  `Rscript -e 'testthat::test_dir("modules/brand/tests/testthat")'` gave
  **FAIL 0, WARN 1, SKIP 2, PASS 3659**. Matches the brief.
- The three QA reports built with
  `modules/brand/tests/qa/generate_qa_reports.R`: `committed.html` (gated),
  `extras.html` (gated, all nineteen leaves), `ungated.html` (the same extras
  fixture with the focal brand cleared from 25 awareness slots, which
  `detect_instrument_gating()` reads as ungated). All three PASS.

## The three findings, read off the rendered ungated report

Not read off the source. `probe_ov.py` injects a reader into a copy of the
report, Chrome renders it headless, and the harness returns the text the
reader sees. On `before/ungated.html`:

| What | What it said |
|---|---|
| Header badge bar | `Client: Ina Paarman's Kitchen \| Focal Brand: IPK \| Wave 1 \| September 2026` |
| Overview card title | `funnel \| Buying funnel \| section=brsum-funnel` |
| Card base line | `n=438, total respondents` |
| Opportunities, last item | `Read off the funnel above` / `The largest step down is from Past 12 months at 62% to Past 3 months at 45%, which is 72% of the stage before it.` |
| "How this works" drawer | `The card draws the nested funnel wherever the data supports it ... The Brand and Buying destination carries a base toggle that shows the funnel either way.` |
| Category tab destinations | `overview* mental buying meaning audience`, the active one being the stub `Overview: Dry Seasonings & Spices. The headline picture for this category is on the Summary tab.` |
| Funnel destination, same report | `Separate measures. Respondents gave an answer at the Consider stage for a brand they did not name as known ... The nested funnel view is not offered here, because a nested picture would show an ordering the survey never enforced.` |

62% and 45% are the two stages measured independently. 45/62 is 0.726, which
is where "72% of the stage before it" comes from. On an instrument that did
not gate the questions those two groups are not nested, so the ratio is not a
conversion and the phrase "of the stage before it" is a claim the data does
not carry. That is the contradiction: one page says separate measures, the
page before it says funnel and conversion.

## Finding 1: the funnel and the conversion

### The sweep, not just the two sites Duncan named

The reviewer had already caught this class once, so the whole Overview was
swept for Stage 3 output that assumes nesting or conversion, in
`panels/14_summary_panel.R` and `js/brand_summary_panel.js`, on the terms
funnel, convert, conversion, nest, chain, step, drop, leak, lost, shrink,
narrow, through, progress, journey and "of those". Everything the sweep
found, and what was done with each:

| Site | Reader visible | Done |
|---|---|---|
| `card("funnel", "Buying funnel")` in `.brsum_card_grid_skeleton()` | yes, the card title | R keeps it as the routed default and `renderFunnelCard()` sets it per category, in both branches |
| the sentence built inline in `renderOpportunitiesCard()` | yes | factored into `funnelStepItem()`, one sentence per mode |
| `.brsum_funnel_base_note()`, in the "How this works" drawer | yes | rewritten to describe both cases; its old last sentence, that Brand and Buying "carries a base toggle that shows the funnel either way", is false on an ungated report, where the chain button is not rendered at all |
| the card base line, `base_label` | yes | now carries "Separate measures: each stage on its own survey response" where the questionnaire did not route |
| `emptyMessage: 'Funnel data not available.'` | yes, on a category with no funnel | "Buying stage data not available." |
| `#   3. Physical conversion, collapsed Aware -> Prefer -> Bought funnel` | no, a file-header comment | corrected |
| `#   6. Funnel: Aware -> Prefer -> Bought.` | no, a comment, and "Prefer" is the pre-Stage-2 stage name | corrected to Consider |
| `heroHeadline()`, "What the numbers say" | yes | nothing to change. Its five clauses are comparisons against the category average and leader flags; the two clauses that read as diagnoses were removed in Stage 3 |
| the mini funnel bars themselves | yes | nothing to change. `buildMiniFunnel()` draws one bar per stage scaled against a shared maximum. It is not a tapering wedge and asserts no ordering |
| `stage_labels` (Aware, Consider, Past 12 months, Past 3 months) | yes | nothing to change. These are the survey's own measure names |
| the "Bought in the target window" headline tile | yes | nothing to change. It is a penetration figure on that stage's own response, which Stage 4 decision 7 settled |

### How the two pages are kept in step

`.brsum_funnel_minif()` writes `gated` onto the funnel block, from the same
expression the funnel panel uses (`is.null(fn$meta$gating) ||
isTRUE(fn$meta$gating$gated)`, so a payload with no gating block at all reads
as gated, which is the convention `.fn_table_controls()` and
`.fn_base_howto()` already use).

It is a boolean, so it puts no digit in the island. Executed rather than
assumed: `reachability_check.py before/committed.html after/committed.html`
reports `brsum-data: 1 distinct payload(s), numeric content identical`, and
the clause appended to `base_label` is digit free for the same reason.

`funnelIsGated()` in the JS reads it. A payload written before this build
carries no such field, and there `nested` stands in, because R only ever
wrote the chain series after deciding the instrument was gated. Neither
present reads as not routed, which is the reading that claims least.

### What each mode now says

Read off the rendered reports, not the source.

**Gated** (`committed.html` and `extras.html`), unchanged from Stage 4:

- title `Buying funnel`
- base line `n=438, total respondents. Nested: each stage counts respondents who passed every earlier stage`
- Opportunities: `Read off the funnel above` / `The largest step down is from Consider at 67% to Past 12 months at 45%, which is 67% of the stage before it.`

**Ungated** (`ungated.html`):

- title `Awareness to purchase`
- base line `n=438, total respondents. Separate measures: each stage on its own survey response`
- a note under the bars: `The questionnaire did not route these questions, so each figure is its own measure over all respondents rather than a stage a respondent had to reach. The Brand and Buying destination says what it found.`
- Opportunities: `Read off the measures above` / `The largest fall is from Aware at 87% to Consider at 67%, a gap of 20 percentage points. These are separate measures, because the questionnaire did not route the questions, so the difference between two of them is a gap and not a conversion. The conversion ratios this data does support are on the Brand and Buying destination, with what each one computes.`

That last clause is there because the funnel destination on the same report
does carry two conversion ratios: "% of previous stage" and "% of those
aware", which are honest intersections rather than routing claims, and
Duncan's ruling keeps both on an ungated report. Without the pointer a
skimming reader meets "not a conversion" on the Overview and "conversion
ratios" on the page after it, which is the failure class this whole task is
about. It points rather than paraphrases: what each ratio computes is on the
buttons' own tooltips in `.fn_table_controls()`, and restating a formula in
two places is how the two drift apart.

### Decisions taken, with reasons

1. **The ungated sentence reports a gap in percentage points, not a ratio.**
   A ratio of two independent proportions on the same base looks like a
   conversion and is not one. A difference between two proportions on one
   base is a fact about the two measures and claims nothing about who moved.
2. **The gap is computed from the rounded figures the card prints**, so a
   reader can subtract the two numbers in front of them and get the third.
   87 minus 67 is 20, and that is what the sentence says. The pair is chosen
   on the same rounded figures, so what is named as largest is largest as
   shown.
3. **A pair that rounds to less than a point apart is not called a fall.**
   Otherwise the sentence would read "a gap of 0 percentage points". Where
   nothing falls the block says so rather than going silent, because silence
   there looks like a bug.
4. **The ungated item was reworded rather than deleted.** Deleting it would
   have removed a true observation from the page. It is still an observation
   an analyst can use; only the mechanism claim was wrong.
5. **The title is "Awareness to purchase", a range rather than a mechanism.**
   The word "Separate measures", which is the funnel destination's own term,
   carries in the base line and the note rather than in the title, so the two
   pages use one term for one thing without the title becoming a sentence.
6. **Both branches set the title, the note and the base line.** The category
   picker can move from a category that routed its questions to one that did
   not. A title set only in the ungated branch would stick on the next
   category, which is the bug this whole finding is an instance of.
7. **`.brsum_funnel_base_note()` describes both cases.** The "How this works"
   drawer renders once for the whole Summary tab while gating is decided per
   category, so the note cannot be mode-specific. It now points at the card's
   own title and base line, which are the two things that do change with the
   picker, and both now say which series they drew.
8. **The card key and its anchor do not move.** `data-brsum-card="funnel"`
   and `data-section="brsum-funnel"` are unchanged, and
   `drive_overview.py` asserts the anchor in both modes. A pin taken from
   this card is titled from the card's own `h3` (`brand_pins.js` line 93), so
   a pin taken on an ungated report is titled "Awareness to purchase" and
   still resolves to the same anchor.

### Coverage that fails on the old behaviour

- `tests/js/test_summary_overview.js`, 31 new assertions, **147 passed, 0
  failed** against 116 before. It holds the routed sentence verbatim, asserts
  the ungated one contains neither "stage before it" nor "step down" nor the
  word funnel, and reproduces the exact old sentence from the same payload to
  assert the new one differs from it. Run against `git show HEAD:` of the
  panel JS it does not pass: `TypeError: D.funnelIsGated is not a function`.
- `tests/qa/drive_overview.py` gained mode-aware checks. Those are the
  behavioural gate, and they were run against the pre-change reports to prove
  they bite:

```
before/ungated.html    64 checks, 5 failed
  FAIL not routed: the card is not titled as a funnel -> Buying funnel
  FAIL not routed: the base line says separate measures -> n=438, total respondents
  FAIL not routed: a note under the bars says why -> no note
  FAIL not routed: Opportunities claims no nesting -> ... which is 72% of the stage before it.
  FAIL not routed: and says what the figures are instead -> ...
before/committed.html  64 checks, 0 failed
```

The gated report passes unchanged on the old build and on the new one, which
is the other half of the claim.

## Finding 2: the header misdated the study

### Where each date came from, checked before either was changed

- The header's date was `format(Sys.Date(), "%B %Y")` in `build_br_header()`
  (`03_page_builder.R`), printed in a bare `<span>` with no label, directly
  after `Wave 1`.
- Nothing in the brand module knew the fieldwork period at all.
  `generate_config_templates.R` declares a `study_date` key, but that is on
  the **Survey_Structure** sheet, a different workbook, and `grep` over
  `modules/brand/R` and `modules/brand/lib` finds no reader for it anywhere.
- The built-in About panel carries no fieldwork text. On Duncan's report the
  May dates will have come from the `_BACKGROUND` Section_Insights entry,
  which `build_br_about_panel()` renders above the methodology copy. **That
  last point is inferred, not verified:** his report was not opened in this
  session and must not be.

### What was built

A free-text `fieldwork_dates` key in the STUDY IDENTIFICATION block of the
Settings sheet. The badge bar reads

    Client: X | Focal Brand: Y | Wave 1 | Fieldwork: 19 to 26 May 2026 | Generated September 2026

and, where the key is blank,

    Client: X | Focal Brand: Y | Wave 1 | Generated September 2026

The About tab repeats the same string under a Fieldwork heading, reading
"Wave 1 fieldwork ran 19 to 26 May 2026.", and its own timestamp line now
ends "That is when this file was written, not when the study was in field."

The About line says only when the wave was in field. A first draft added
"Every figure in this report is from that period", which is a claim about the
data that nothing enforces: wave 2 and later enable tracker integration and
the headline tiles carry a reserved slot for a wave comparison, so a later
report could carry an earlier wave's figures under this wave's fieldwork
string and the sentence would turn false on a client's page with nobody
noticing. It was cut.

### Decisions taken, with reasons

1. **Free text, and nothing parses it.** A fieldwork period is written a
   dozen ways ("19 to 26 May 2026", "Q2 2026", "May and June 2026") and a
   parser would refuse half of them for no gain. The only job is to put the
   study's own date on the page.
2. **The generation date is always printed, and always labelled.** Dropping
   it would lose a fact an analyst uses when two copies of a report are on
   one desk. Labelling it is what stops it being read as the study's date.
3. **The study's date comes first**, before the date the file was written.
4. **A study that has not filled the key in gets no date invented for it.**
   `study_date` on Survey_Structure was deliberately not wired up as a
   fallback: it is a different workbook, it is a start date rather than a
   period, and nothing has ever read it, so treating it as authoritative now
   would put a date on a client's page that no one had checked.
5. **The one new key sits on the Settings sheet, which is read generically.**
   `.brand_load_config()` copies every non-header row into the config list,
   so no whitelist needed changing.

### Coverage

`modules/brand/tests/testthat/test_report_dates.R`, 39 assertions, 0 failed.
It covers the labelled generation date, the absent case, the ordering, five
free-text spellings, blank and NA and NULL, the About tab agreeing with the
header word for word, the Settings key being declared and optional, and no
em dash in either line.

The IPK extras fixture sets `fieldwork_dates`, so `extras.html` and
`ungated.html` prove the filled case on a rendered report and
`committed.html` goes on proving the blank one. Read back from the rendered
files:

```
committed  Client: Ina Paarman's Kitchen | Focal Brand: IPK | Wave 1 | Generated September 2026
extras     Client: Ina Paarman's Kitchen | Focal Brand: IPK | Wave 1 | Fieldwork: 1 to 8 April 2026 | Generated September 2026
ungated    Client: Ina Paarman's Kitchen | Focal Brand: IPK | Wave 1 | Fieldwork: 1 to 8 April 2026 | Generated September 2026
```

"1 to 8 April 2026" is a fixture value invented for the fixture. It is not
the real IPK wave 1 field period, and no figure in that fixture came from a
real field period.

## Finding 3: the category Overview was a dead end

### The decision: drop it, and why

The Overview destination held `.br_overview_placeholder()`, a card reading
"The headline picture for this category is on the Summary tab" over a button.
It was the first entry in `.BR_DESTINATIONS` and therefore the destination a
reader landed on when they clicked a category.

Duncan offered two options, make it a real compact overview or drop it. It is
dropped, for three reasons.

1. **The Summary tab already is the per-category compact overview**, with a
   category picker, four headline tiles, "What the numbers say", two Why
   cards, Opportunities, the buying card and its own commentary box. A second
   one per category would be a duplicate of it that could drift from it.
2. **Building one would mean deriving figures into the category panel**,
   which is what the reachability gate exists to stop happening quietly, and
   the Overview's own Stage 3 log records that constraint deciding the shape
   of that build.
3. **It keeps this branch out of Mental Availability**, where the session in
   `/Users/duncan/Dev/Turas-mal` is moving content between the main view and
   the Advanced drawer.

A reader who clicks a category now lands on the first destination that has
analysis in it. That is Mental Availability wherever Mental Availability
renders, and the next one along where it does not: the rule is "first live
destination in registry order", and nothing hard-codes `mental`.

### The guarantee that had to be replaced

`dest_has_content()` returned `TRUE` for `overview` unconditionally, and that
was what guaranteed a category tab could never render a destination nav with
no buttons. With it gone the guarantee has to come from the gates.

It does, and it was read out of the code rather than assumed.
`build_br_category_panel()` is called only for categories that passed
`.br_cat_has_content()`, which is `any()` over `.br_cat_renderable()`. The
panel's own `has_*` flags come from that same function. Every one of the
eight elements owns exactly one leaf marked `primary`, and a primary leaf
survives the filter on its gate alone, without needing a panel fragment. So
at least one leaf survives and at least one destination is live.

Proved twice rather than left as an argument:

- `test_destination_nav.R` drives all eight element flags one at a time and
  asserts each render has at least one destination button and exactly one
  active one.
- `drive_element_flags.R` does the same through the real pipeline on real
  generated HTML, and its "designed exception" section is rewritten into the
  assertion that a category tab is never a nav with no destinations. **81
  checks, 0 failed, PASS.**

### The route to the Summary tab was kept

`brOpenSummaryFor(catId, catName)` opens the Summary tab and selects the
category in its picker; the top-level Summary tab button does not carry the
category across. So the route moved to a new slot in the category controls
bar, `data-slot="summary"`, as a "Summary for this category" button, rather
than being lost with the destination that used to hold it. The JS function is
untouched.

### Decisions taken, with reasons

1. **The controls bar, not the destination nav.** The controls bar is where
   the other controls that decide what the reader is looking at already live,
   and `build_br_category_controls()` is a different function from the
   destination registry, so this change is less likely to collide with the
   session working on the destinations.
2. **The toolbar guard was removed rather than kept as a no-op.** Every live
   destination now holds a leaf, so `build_br_destination_toolbar()` is
   called unconditionally for the main view. Export stays conditional,
   because a destination whose leaves all sit in the Advanced drawer has
   nothing to export from its main view.
3. **No `data-section`, wrapper id or Section_Insights anchor moved.** The
   Overview stub never carried one. `anchor_resolution.py` confirms it on
   all three reports, comparing the pre-change report's anchor set against
   the post-change one: 41, 69 and 69 of 41, 69 and 69 resolve to content.
4. **A bug carried in the stub was fixed on the way past.** The stub built
   its `onclick` as `brOpenSummaryFor('<cat_name>', ...)` with `.br_esc()`
   alone, and `.br_esc()` escapes `&`, `<`, `>` and `"` but not an
   apostrophe. A category called "Paarman's Rubs" would have ended the JS
   string literal and killed the button, on every build up to this one. The
   new control passes both arguments through `.br_js_str()` and then
   `.br_esc()`, so they survive the HTML parser and the JS parser in turn.
   Read off the rendered file:
   `onclick="brOpenSummaryFor(&quot;dss&quot;, &quot;Dry Seasonings &amp;amp; Spices&quot;)"`.
   No fixture has an apostrophe in a category name, so the failure itself was
   read from the code rather than reproduced on a report;
   `test_destination_nav.R` renders a category called "Paarman's Rubs" and
   asserts the apostrophe survives inside a double-quoted literal and that no
   single-quoted call is emitted.
5. **`brSwitchCategoryFromControl()` was left alone.** It carries the active
   destination across when the reader changes category and does nothing when
   the target category has no such destination, which leaves the target on
   its own first destination. That is the right behaviour and it already
   worked; the Overview had simply been masking it by existing everywhere.

## The committed templates, regenerated

`modules/brand/templates/Brand_Config_Template.xlsx` is what an analyst
copies into a new project, per that folder's README, so the new Settings key
had to reach it. Snapshotted first, then regenerated with
`generate_brand_templates("modules/brand/templates", overwrite = TRUE)`,
which saves through `turas_saveWorkbook()`.

Read back and compared with the snapshot: Settings goes from 79 rows to 81.
Two keys added, **`fieldwork_dates`** and **`funnel_consideration_roles`**.
The second is not this branch's: it was added to the generator by the funnel
definition work on 6 September and the template was never regenerated, so
that drift is corrected here as a side effect and is noted rather than left
to be discovered. Nothing was removed, the three sheets are unchanged,
dropdown count is 15 before and after, and neither workbook references a
drawing part. `Survey_Structure_Brand_Config_Template.xlsx` is rewritten with
the same sheet set and no content change of its own.

## Executed, with the numbers

| Check | Result |
|---|---|
| Brand suite, before the first edit | FAIL 0, WARN 1, SKIP 2, PASS 3659 |
| Brand suite, at the tip | FAIL 0, WARN 1, SKIP 2, PASS 3716 |
| `node tests/js/test_summary_overview.js` | 147 passed, 0 failed (116 before) |
| The new JS assertions against `git show HEAD:` of the panel JS | does not pass |
| `drive_overview.py` on the pre-change ungated report | 64 checks, **5 failed**, naming the old sentence |
| `drive_overview.py` on the pre-change gated report | 64 checks, 0 failed |
| `testthat::test_file("test_report_dates.R")` | 39 assertions, 0 failed |
| `testthat::test_file("test_destination_nav.R")` | 328 assertions, 0 failed |
| `drive_element_flags.R` | 81 checks, 0 failed, PASS |

Every script under `modules/brand/tests/qa/`, on all three reports built by
`generate_qa_reports.R` at the tip:

| Script | committed | extras | ungated |
|---|---|---|---|
| `drive_overview.py` | 64 / 0 | 64 / 0 | 64 / 0 |
| `drive_destinations.py` | 352 / 0 | 383 / 0 | 383 / 0 |
| `drive_funnel_base.py` | 99 / 0 | 99 / 0 | 79 / 0 |
| `drive_chrome.py` | 120 / 0 | 145 / 0 | 147 / 0 |
| `drive_save_roundtrip.py` | 113 / 0 | 117 / 0 | 117 / 0 |
| `drive_two_categories.py` | 15 / 0 | 15 / 0 | 15 / 0 |
| `drive_pin_titles.py` | 60 / 0 | 93 / 0 | 93 / 0 |
| `drive_excel_export.py` | 302 / 0 | 337 / 0 | 338 / 0 |
| `anchor_resolution.py` (before vs after) | 41 of 41, PASS | 69 of 69, PASS | 69 of 69, PASS |
| `reachability_check.py` (before vs after) | PASS | PASS | PASS |
| `count_chrome.py` | reporter, not a gate | | |

## Known limits, stated rather than left to be discovered

- **The fixtures carry one category tab.** `panel-cat-dss` is the only
  full-depth category in the IPK fixture, and `drive_two_categories.py` says
  in its own header that its second category is a clone. So the rule that a
  reader lands on the first live destination is proved, and the behaviour
  Duncan saw on Baking Mixes, a category with a different element mix, is
  not driven here. `drive_element_flags.R` covers the element mixes through
  the pipeline, one flag at a time, on the one category.
- **The picker moving from a routed category to an unrouted one is proved in
  node, not in a browser.** No fixture carries one of each, because the
  ungated fixture makes every category ungated. The reset is why both
  branches set the title, and `funnelCardTitle()` is asserted total over
  every input shape including a missing block.
- **No weighted report was rendered.** The IPK fixture is unweighted. Nothing
  in this branch computes a weighted figure; the gap sentence subtracts two
  percentages the card already prints.
- **Duncan's real IPK report was not opened**, so the claim that its About
  fieldwork sentence comes from `_BACKGROUND` is inferred from the code, not
  verified against his file.
- **The example configs still do not render**, on this branch or on main, for
  the reason the Stage 2 and Stage 4 logs record: their generators emit the
  pre-v2 column-per-brand shape and `run_brand()` refuses before any report
  code runs.
- **No pinned card or PPTX was exported and opened.** `drive_pin_titles.py`
  passes on all three reports and the pin title is read from the card's own
  `h3`, but a pin was not opened in a browser by hand.

## Owed, outside this branch

- The shared callout `brand.executive_summary` in
  `modules/shared/lib/callouts/callouts.json`, which this task may not touch,
  still describes the category context metrics as "how many brands they hold
  at each funnel stage". On an ungated report there are no funnel stages.
  This is the third entry owed to whoever holds the Callout Editor: the
  Stage 4 log and the funnel definition log already list `brand.funnel`,
  which still describes three base toggles, still says the Prefer stage is
  the top 2 of the scale, and still says Turas refuses to render a brand
  whose counts violate nesting.
- `study_date` on the Survey_Structure Settings sheet is declared and read by
  nothing. Either wire it up or drop it from the template.

## The rebase onto the destination relabelling branch

`/Users/duncan/Dev/Turas-mal`, on `fix/brand-destination-labelling`, is
renaming and relabelling tables across the destinations and moving the Mental
Availability Advanced contents. This branch will conflict with it in three
known places, all small:

- `.BR_DESTINATIONS` in `03_page_builder.R`: this branch removes an entry,
  that branch changes labels.
- the destination-count assertions in `test_destination_nav.R`.
- `DEST_HOLDS` and the header comment in `tests/qa/drive_element_flags.R`.

Whoever rebases must rerun `reachability_check.py`, `anchor_resolution.py`
and `drive_destinations.py` on all three fixtures afterwards, because a label
change and a registry change landing together is exactly the case those gates
are for.

## Status

Six commits on `fix/brand-overview-consistency`, on top of `36f97062`.
**Not merged and not pushed.** Duncan owes a `launch_turas()` run on a real
project and an eyeball of the Overview on an ungated category, the header and
a category tab, and then a review briefed as independent of this session.

