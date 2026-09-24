# Notes: What if tab, speed and visual polish

Session of 24 September 2026, from `HANDOVER_WHATIF_PERF_AND_POLISH.md`.
Branch `feature/whatif-perf-polish`, worktree `../Turas-whatif-perf`, off
`main` at `710e10f2`. Two commits: `f3cff8cb` (speed) and `a171b1e2` (polish).

## Task 1: speed

All in `modules/tabs/lib/html_report_v2/assets/js/27w_whatif.js`.

- `openChange()` works out each move's change to a respondent's lever column
  once, because it does not depend on the fit. Each refit then visits only the
  respondents the move touches.
- `etas()` also caches each respondent's baseline score per fit
  (`baseScores()`), so a moved respondent costs one `scoreAt()` call, not two.
- `openGroup()` keeps its results by their moves (`movesKey()`), so the
  effort table, the bundles and the scenario share one store per audience.
- `currentGroup()` keeps the last six audiences (`AUDIENCES_KEPT`), not one, so
  filtering back to everyone is instant.

The arithmetic and its order did not change. A parity script ran the old and
new files side by side on the SACAP 2025 island, covering everyone and two
filtered groups: every slip, fix, single move, bundle and scenario. All 567
values were bit-identical, and the rendered page was byte-identical after
Task 1.

Timing from `tests/whatif_timing.mjs` on the SACAP island (1,361 students,
101 fits, 8 levers, weighted), node, same script before and after:

| Step | Before | After |
|---|---|---|
| first render | 1,208 ms | 314 ms |
| render again, nothing changed | 446 ms | 1 ms |
| a scenario pick | 490 ms | 1 ms |
| a second pick (a new combination) | 511 ms | 12 ms |
| a filter change (half the students) | 631 ms | 144 ms |
| back to everyone | 1,261 ms | 1 ms |

What is left is `Math.exp`, about two calls per moved student per refit, which
is the real arithmetic. Inlining `scoreAt()` was tried and gained nothing, so
it was reverted. One more step would roughly halve it: compute `exp(eta)` once
per student and fit. It was not taken because it changes the arithmetic, which
would give up the bit-identical parity check. The times are already under the
handover's 300 ms target.

`whatif_timing.mjs` is committed as a check, not a gate. With no argument it
runs on the synthetic fixture. To run it on a real study, pass an island cut to
open mode by `.read_whatif_contribution(..., "records", survey_data)` and
written to a scratch file.

## Task 3: polish

JS and `styles.css` only. Nothing shown changed except as listed here. On the
SACAP view every number is the same as before, except the six "~0" cells,
which are now dashes. The one new number is the 10% threshold in the unclear
note.

- Effort table: the Area column is 45% wide and every row is one line. A halo
  area carries a "caught in the halo" chip. One note under the table gives each
  such area's two numbers and says to read the table's number as a floor. An
  unclear area carries an "unclear" chip, a dash in each number cell and no
  bar. A note under the table states the threshold. The net gain number and
  its bar share one cell. The header is "Net gain per 100 reached", with the
  full wording in its tooltip.
- Build a scenario: moves are rows with the select on the right, and chosen
  rows are marked. The result line sits in its own box, with larger numbers,
  above the bundle table.
- Panels take the report's card radius and shadow. The KPI tiles take the
  Dashboard stat tile look (label above a large value, brand edge). The two
  collapsed panels get a heading and a one-line hint. Lead and note text is
  capped at 720px.
- Both tables scroll inside their card on a phone. The old tab also ran wider
  than a phone screen, so this is a small fix beyond the list.

### Deviations from the handover

- Scenario groups: the island has no lever families, only bundles. The rows are
  grouped under the bundle names when no lever sits in two bundles (SACAP:
  Teaching, Service, Other areas). Otherwise they form one plain list. I added
  no family field to the R config.
- The Rate panel's eight selects keep their grid. The handover did not list
  them, so I left them.
- The halo gate test was rewritten for the new layout. It now checks the row
  chip, the row's own number, the note's two numbers, the floor sentence and
  the How this works entry. Two tests were added: kept results match a fresh
  start (Task 1), and unclear rows plus scenario grouping (Task 3). The gate
  now runs 21 tests.

## Task 2: hardening

Checked on a scratch copy only. The SACAP dev report from 12:14 was copied to
the scratchpad, this branch's JS and CSS were swapped in, and the copy was
hardened with `scripts/turas_harden_report.R`: all checks passed. The
hardened copy holds one executable script plus the JSON islands, the same
shape as Duncan's own hardened report. None of the new function names or UI
strings appear in it (`haloNote`, `scenarioGroups`, `movesKey`, `baseScores`,
`AUDIENCES_KEPT`, "caught in the halo", "Other areas", "Net gain per 100
reached"). Rendered headless, it shows a What if view identical to the dev
copy's. The script keeps its IIFE, and nothing is declared outside it.

## How it was looked at

The permission check refused a `.claude/launch.json` preview server, so pages
were rendered with headless Chrome to PNG (see the memory note on HTML render
QA). Tall windows capture a scrolled band and the viewport cannot go below
500px, so the checks used a harness page instead: the report's `styles.css`,
the What if JS and the SACAP island, in 900px bands. A body capped at 358px
stood in for a 390px phone. The final check was the real dev report with the
new JS and CSS swapped in.

## For Duncan

Regenerate SACAP 2025 through `launch_turas()` once this is merged. Look at
the What if tab in the dev report and in the hardened report. Things to try:
change the audience filter, go back to everyone, pick two scenario moves, and
look at the effort table's halo note.

Not checked here: pins. "Where to direct effort" and "Build a scenario" are
pinnable cards, and the TurasPins capture inliner skips default-looking style
values (CLAUDE.md, report rendering). The bar now sits in a flex cell, and
the halo and unclear chips are new. Pin both cards to the Story and check
that the bars and chips survive in the pin.

## Follow-up, same day: folding panels and the Rate wording

Duncan found that every dropdown in "Rate SACAP as one student" folded the
panel shut. The cause: each change re-renders the tab, and a re-rendered
`<details>` starts closed. Branch `fix/whatif-panel-fold`:

- Every panel below the headline now folds, with a chevron button, and the
  title also toggles. Where to direct effort, Build a scenario and Build a
  student start open. Rate and How this works start folded. `wi.state.open`
  keeps the folds, so a dropdown or a filter re-render leaves each panel as
  the reader left it. A fold flips only that panel's body, with no re-render.
- Pins: `shell.snapshotCard` (24_shell.js) drops `.snap-skip` elements (the
  fold button) and un-hides `.snap-show` ones (the panel body). A pin of a
  folded card therefore shows the whole card.
- Rate says what it is: one student's chance of ending up a Detractor, a
  Passive or a Promoter, "not NPS: NPS is a score for a group". The headline
  reads "This student has a 62% chance of ending up a Promoter", and the row
  is labelled "Chance of ending up". Build a student's headline now reads
  "Expected NPS for students like this: 54. Each has a 66% chance of ending
  up a Promoter."

Checked: the gate has 22 tests. The new fold test fails when the fold state
is forgotten. The shell snapshot suite has 13 tests, and its new test fails on
the old shell. All 58 v2 node suites exit 0, and engine parity is still
bit-identical. In real headless Chrome, a fold click, a Rate dropdown change
and a scenario pick leave the folds as set. A scratch hardening passed its
checks, with no new names or strings, and the hardened copy renders the folds.
