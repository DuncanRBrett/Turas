# Handover: What if tab, speed and visual polish

Written 24 September 2026 for a fresh session (Duncan's choice: Opus 5.5, high
effort). Everything below was checked in this session against the code on
`main` at `d567f85d` and against the SACAP 2025 report Duncan generated at
12:03 on 24 September. Read `modules/whatif/README.md` and
`docs/v2_lift/NOTES_WHATIF_DK_HALO.md` first; skim
`docs/v2_lift/NOTES_WHATIF_SESSIONS_2_4.md` for how the tab reaches the report.

## Where things stand

- The What if module and its tab are on `main` and pushed (`d567f85d`):
  engine, config, tabs tab, client-safe disclosure (fixed and re-reviewed),
  don't-know handling, halo check, LMG sheet.
- The tab appears in a report only when the tabs config's Settings sheet has a
  `whatif_island` row naming the island file with a FULL path. The tabs run
  changes its working directory to the tabs library folder, and the island
  readers test the path exactly as written, so a project-relative path is not
  found. SACAP 2025 now has that row and the tab renders in both modes.
- SACAP 2025 files (Duncan's, never write into them):
  config `.../Projects/SACAP/Student_Annual/03_Waves/Student_Annual-2025/SACAP_Student_Annual-2025_Crosstab_Config v2.xlsx`,
  island `.../04_Analysis/WhatIf/SACAP_Student_Annual-2025_WhatIf_whatif_island.json`
  (1,361 students, 101 fits, 8 levers, 268 published groups, weighted and
  unweighted versions), reports in `.../04_Analysis/Crosstabs/`.

## Task 1: the lag

Measured in node with the gate tests' sandbox on the SACAP island embedded
the way a full report embeds it (open mode, weighted):

| Step | Time |
|---|---|
| `openGroup(mask)`: need, slip and fix for 8 levers over 101 refits, 1,361 students | 760 ms |
| the same call again (`etas()` already cached) | 755 ms |
| first `render()` of the tab | 1,232 ms |
| every later `render()` (scenario, two bundles, Build a student, Rate as one) | 457 ms |

So the effort table is cached per audience (`currentGroup()` keys
`wi._cache` on the filter state), but every render recomputes the scenario
and both bundles over all refits, and every filter change pays 760 ms on top
of the report's own recompute. Slip and fix alone are about 2.2 million
`scoreAt()` calls.

All in `modules/tabs/lib/html_report_v2/assets/js/27w_whatif.js`, nothing
shown changes:

1. Cache the baseline score per student per fit once (extend `etas()` or add
   a sibling cache): `openChange()` recomputes `scoreAt(fit, base, scores)`
   for every moved student on every call. Halves the cost of every move.
2. Cache with the audience: bundle results (they depend only on the group)
   and the scenario result keyed by its chosen moves, so a dropdown click
   recomputes one scenario, not the table and both bundles.
3. Tighten the inner loop: per fit, a `Float64Array` of thresholds and base
   etas, an inlined logistic, fits as the outer loop. Expect two to three
   times on top.

Target: a filter change well under 300 ms in node, a scenario click near
instant. Verification is the existing gate,
`node modules/tabs/lib/html_report_v2/tests/whatif_view_tests.mjs` (19
tests), which checks the live numbers against the R engine's published
numbers to 0.006 for everyone and for a filtered group; any arithmetic slip
fails it. Keep a timing check: this script, run against the SACAP island
lined up by the tabs reader (see below), or against the synthetic fixture
scaled up.

```js
// time_wi.mjs <embedded_open_island.json>
import { readFileSync } from "node:fs"; import path from "node:path"; import vm from "node:vm";
const JS_DIR = "modules/tabs/lib/html_report_v2/assets/js";
const W = JSON.parse(readFileSync(process.argv[2], "utf8"));
const sb = { console, Math, JSON }; sb.globalThis = sb; sb.window = sb;
sb.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
sb.TR.d2 = { state: { filters: [] }, filterDescription: () => "all", tracking: () => ({enabled:false}), qualitative: () => ({enabled:false}) };
sb.TR.stats = { source: () => "micro", mask: () => null };
vm.createContext(sb); vm.runInContext(readFileSync(path.join(JS_DIR, "27w_whatif.js"), "utf8"), sb, { filename: "27w_whatif.js" });
sb.TR.WI = W;
let t = Date.now(); sb.TR.whatif._openGroup(null); console.log("openGroup", Date.now() - t, "ms");
const h = { innerHTML: "", querySelectorAll: () => [] };
t = Date.now(); sb.TR.whatif.render(h); console.log("render", Date.now() - t, "ms");
t = Date.now(); sb.TR.whatif.render(h); console.log("render again", Date.now() - t, "ms");
```

To produce `embedded_open_island.json` from the SACAP island without running
tabs: source `modules/shared/lib/*.R`, pull `.read_whatif_contribution` and
`.whatif_open_payload` out of `modules/tabs/lib/run_crosstabs.R` the way
`modules/tabs/tests/testthat/test_whatif_island.R` does (`extract_fn`), build
`survey_data` as a data frame with one `ID` column from the island's
`variants$weighted$open$ids`, and call
`.read_whatif_contribution(list(whatif_island = <path>, apply_weighting = TRUE, weight_variable = "weight", min_reporting_base = 5), "records", survey_data)`.
Write the result to a scratch file, never into the project folder or git.

## Task 2: obfuscation

Already done, verified on the SACAP files. The hardened
`..._Crosstabs v2_report.html` holds one `<script>` tag (the packed bundle)
and keyed islands (`data-island="v2" data-k=...`), with zero readable What if
function names or UI strings ("Where to direct effort", "How this works",
`effortHtml`, `_openGroup` all absent). The readable code Duncan saw is in
`..._report_dev.html`, which is the development copy by design. Nothing to
build; two things to keep true after Task 1 and Task 3:

- `27w_whatif.js` stays wrapped in its `(function (global) { "use strict"; ... })` IIFE
  (CLAUDE.md, composed reports: a top-level name survives hardening).
- After regenerating, grep the hardened `_report.html` for a new function
  name and a new UI string; both must be absent. `turas_release_audit` and
  the minify gate (`modules/shared/tests/testthat/test_turas_minify.R`,
  `test_minify_render_gate.R`) must still pass.

## Task 3: visual polish

Seen in the built-in browser on the SACAP dev report at 1280 wide, 24 Sep.
Design reference: `prototypes/nps-simulator/template_whatif.html` (the
mockup Duncan approved) and the report's own cards (`.card`, `--card`,
`--line`, `--radius`, `--shadow` in
`modules/tabs/lib/html_report_v2/assets/styles.css`; the `.wi-` block is near
line 1735). Keep the `wi-` prefix, `esc()` on every string, no em dashes, no
NaN or undefined on the page (the gate checks all three).

What looks unfinished:

- Effort table, the Area column. It is about a fifth of the width, so the
  halo sentence wraps to five lines under five of the eight areas and every
  row is tall. Make the halo a short chip ("caught in the halo") beside the
  rating chip, keep one short line under the area, and say the full sentence
  once, in the note under the table or in How this works. Same for the
  "Behaves partly like..." config note: one line. Widen the Area column.
- Unclear rows show "~0" in three cells and an empty bar. A single muted
  "unclear" chip and a dash in the cells would read better than three "~0".
- The bar column has no header and sits apart from its number. Put the number
  and bar in one cell, header "Net gain per 100 reached", bar under or beside
  the number.
- The two KPI tiles ("47 Actual NPS", "1361 Students in the model") are
  plain boxes. Match the Dashboard's stat tiles.
- Build a scenario: eight "No change" selects in a four-column grid look like
  a form. Group them under the lever families the config has (teaching,
  service), or list them as rows with the select on the right, and make the
  score line show the change as soon as one move is chosen (it does, but the
  line is easy to miss above the bundle table).
- Build a student is the best panel: the sentence of dropdowns reads well.
  The "Fewer than 5 real students..." note and the closing sentence could sit
  together under the line.
- Rate SACAP as one student and How this works are collapsed `details`
  panels with plain summaries; give the summaries the panel heading style.
- Lead paragraphs are long single lines at desktop width; cap the measure
  (`.wi-view` is 1100px, the text could be 720px).

Nothing here changes a number. Every text change goes through `esc()`; the
gate's hostile-label test must still pass.

## Known open items outside these three tasks

From the independent re-review of the disclosure layer (24 Sep, another
session; its report is in that session's scratchpad, not the repo). Not
yours to fix here, but do not be surprised by them:

- At a minimum group of 10 the exact recoverability check refuses
  SACAP-shaped studies even at the four million cap, and the refusal text
  says "raise the minimum group", which is backwards. SACAP 2025's tabs
  config has `min_reporting_base` 5, so it does not bite there.
- The release audit false-alarms when a lever label, outcome level, filter
  label or units noun contains a standalone small number ("Module 2 admin").
  Fix is to strip labels from the warnings and notes text before the number
  scan.
- The halo numbers were not covered by that re-review; this session's own
  check and test cover them (`NOTES_WHATIF_DK_HALO.md`).

## Boundaries

- Branch off `main`, in a worktree. A worktree's renv library is empty: run R
  with `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` and `R_LIBS_USER` pointing at
  `/Users/duncan/Dev/Turas/renv/library/macos/R-4.5/aarch64-apple-darwin20`;
  set `TURAS_HOME` to the worktree for the tabs and shared tests.
- Suites to quote from the run: node `whatif_view_tests.mjs`, tabs
  `test_whatif_island.R` (100), the What if suite
  (`Rscript modules/whatif/tests/run_tests.R`, 1181), shared
  `test_release_audit.R` (88) and the two minify tests. The full tabs suite
  (6473) before merge.
- Never write into OneDrive or the project folders. Duncan regenerates SACAP
  through `launch_turas()` and looks at both the dev and the hardened report.
- The built-in browser cannot open `file://`. To look at a report, copy it
  into the session scratchpad and serve it with a `.claude/launch.json` entry
  (python `http.server` on a spare port), then `preview_start` by name.
  Remove the entry afterwards.
- Check the branch and `git status` before the first edit; another session
  may be in the checkout.

## Starting prompt

> Read docs/v2_lift/HANDOVER_WHATIF_PERF_AND_POLISH.md. Do Task 1 (speed) and
> Task 3 (visual polish) on the What if tab, in that order, on a branch in a
> worktree. Keep the node gate and the tabs What if tests green, keep the
> timing script as a check and quote before and after times. Then confirm
> Task 2 (the hardened report still shows no What if names or strings). Notes
> in docs/v2_lift/, then tell Duncan what to regenerate and look at.
