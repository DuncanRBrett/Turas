# Brief: make an Allocation question recomputable under a v2 filter

> Section 3 is answered. The shape decision and the Opus build brief are in
> `HANDOVER_ALLOCATION_LIVE_RECOMPUTE_FOR_OPUS.md` (2026-09-03). Read this
> brief for the why, that handover for the what.

Written 2026-09-03. The design half is for one short Fable session; the build
half is for Opus 5 at high effort against whatever that session decides. Read
section 3 before proposing anything: the shape question there is the whole
reason this is not a straight Opus job.

## 1. Why this, and why it comes before the MaxDiff report work

Duncan's instruction on 2026-09-03 was to bring the classic maxdiff HTML report
up to the tabs v2 standard, then retire it once the tab reaches parity. Working
out what "parity" meant produced a better target than porting panels.

Sort every panel of the old report by one test: does the right answer change
when a reader filters to a subgroup? Diagnostics, TURF, must-haves and the
population item scores do not, so they belong frozen in the MaxDiff tab, and
three of the four are already there. Segments and head to head do change, so
freezing them into the tab would show a client numbers that stop being true the
moment they filter.

Those two belong on the microdata path, and half of that path already exists.
`modules/maxdiff/R/12_tabs_export.R` writes each respondent's preference shares
as an Allocation question, one numeric column per item summing to 100, so
MaxDiff results are crosstabbed, weighted and significance-tested by banner at
build time. What does not exist is the live half: the v2 reader cannot
recompute an Allocation question when someone filters.

Closing that gap pays three ways. MaxDiff segments start working under any
filter. Conjoint's importance export is the same twin file and the same type, so
it gets the same lift. And any constant-sum question a client asks becomes
filterable. Head to head then comes nearly free, because each respondent's
shares are a softmax of that respondent's utilities
(`12_tabs_export.R`, "Softmax per respondent, in percent"), and softmax is
monotone within a row, so `share_A > share_B` exactly when `u_A > u_B`.

## 2. What is actually there today

- **Allocation is live in tabs.** `modules/tabs/lib/allocation_processor.R`, plus
  the orchestrator, validation and preflight. VAS 2026 was the first study to
  use it. Its rows are MEANs tagged `RowSource = "summary"`, the same shape as a
  numeric question's Mean row (`fce6cbc1`).
- **The reader has a live-recompute channel and it is weight-aware.**
  `recomputable()` at `modules/tabs/lib/html_report_v2/assets/js/22_model.js:183`
  returns true when the question has boxes, scores, or non-null answers.
  `TR.MICRO.scores[code]` drives weighted means and medians in
  `21_stats.js` (see lines 483, 518, 551), and `TR.MICRO.weights` is all 1s on an
  unweighted project, so weighted and unweighted take the same path.
- **Allocation is deliberately excluded from that channel.**
  `modules/tabs/lib/microdata_writer.R:236` returns a full column of `NA` for an
  Allocation question, so `recomputable()` reads it as "no microdata" and a
  filtered view says so rather than inventing figures.
- **That exclusion was expedient, not principled.** It came in `fce6cbc1`
  (19 Aug 2026) as one of four fixes for "the Allocation question type never
  worked end to end". The single-response path was indexing a bare column that
  an Allocation question does not have, and the v2 report refused to open with
  `DATA_MICRO_Q`. A full-length NA column was the honest stop-gap. Nothing in
  that commit argues Allocation *should* stay unrecomputable.

## 3. The decision this turns on

`micro_scores_for_question()` (`microdata_writer.R:536`) returns **one flat
numeric vector, one value per respondent**, and it is stored under the question
code alone. That works because every question type it currently serves (Rating,
Likert, NPS, Numeric) has exactly **one** mean row.

An Allocation question has **k** mean rows, one per item, and therefore needs k
score series under a single question code.

So the microdata contract has to change, and it is read in at least three places
in `21_stats.js` (mean at 483, median at 518, ratio at 551). Get the shape wrong
and MaxDiff, conjoint and every future constant-sum question pay for it, inside
a module carrying 5,294 tests.

That is the question for the design session, and it should be answered before
any code is written:

- What shape carries k series per question without breaking the three existing
  consumers or the single-series questions they serve today?
- Does `recomputable()` stay a boolean per question, or does it become per row?
- Significance under filter: build-time banner tables carry sig letters. Does the
  live recompute carry them for Allocation, or does the tab state plainly that a
  filtered view is descriptive? Check what the reader does today for a numeric
  mean under filter and follow it rather than inventing a second rule.
- Payload size: k columns per respondent instead of one. Measure it on a real
  config before committing to carrying them all.

## 4. Boundaries

- The deliverable of the design session is a written shape decision, not code.
- Do not touch `modules/maxdiff/lib/html_report/` in this work. Retiring the
  classic report is a later step and is gated on Duncan's own eyeball
  (handover section 6, step 3).
- The MaxDiff tab's frozen panels are not part of this. Diagnostics is ruling R1
  in the follow-ups handover and stands on its own.
- Nothing is written into `examples/*/Output` or OneDrive. Duncan regenerates
  through `launch_turas()`.

## 5. The verification bar

A test that fails on the code as found and passes with the change, per item. The
tabs suite quoted from the run, against 5,294 pass / 0 fail / 1 skip on
`963d66bd`. The node gate suite. Then a real filtered view: run a config whose
data carries an Allocation question, filter it in the browser, and read the
recomputed means back. VAS 2026 is the first study that used the type.
