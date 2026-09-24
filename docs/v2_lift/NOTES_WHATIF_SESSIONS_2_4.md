# What if simulator, sessions 2 to 4: config, report tab, client-safe

Built 24 Sep 2026 on branch `feature/whatif-engine-r` (commits `fcacaa3f`,
`d007a5ab`, `1c9cff19`, `3ebf97e5`), not merged, not pushed. Brief:
`docs/v2_lift/BRIEF_WHATIF_SIMULATOR.md`, section 6. Session 1 is in
`NOTES_WHATIF_SESSION_1.md`.

## What Duncan asked for, and how it is met

1. **Open or client-safe chosen at run time, for every project, at the
   deliverable.** The What if module writes ONE contribution file with both
   parts. The tabs build keeps the part its delivery mode allows: a full
   report (interactivity `records`) gets the open part, a client-safe report
   (`cube` or `none`, which is what the GUI's "Who is this file for?" choice
   resolves to) gets only the published groups. Nothing about the What if run
   changes between the two. `.read_whatif_contribution` in
   `modules/tabs/lib/run_crosstabs.R`.
2. **Levers set before the run, as now.** The config's Levers sheet: one row
   per lever, `Include` = Y, N or Symptom, averaged items, nested and coverage
   kinds. The preflight flags what needs judgement before the numbers are read.

## How to use it

1. Put the config beside the project (the SACAP and CCPB configs are built by
   `modules/whatif/dev/build_study_configs.R`; a blank one comes from the What
   If tile's "Create a blank config" button).
2. Run it: `launch_turas()` then the **What If** tile, or
   `source("modules/whatif/source_whatif.R"); run_whatif("<config>.xlsx")`.
   It writes `{output_name}.xlsx` (analyst workbook: Effort, Groups,
   Calibration, Preflight, Proposed_Structure, Model, Profile, Symptoms,
   Privacy) and `{output_name}_whatif_island.json`.
3. Set the tabs setting `whatif_island` to that `.json` and rebuild the tabs
   report through `launch_turas()`. Choose the delivery mode as usual.

The `.json` carries respondent IDs and rows: keep it with the project data,
never send it. The report file only ever carries the part its mode allows.

## Session 2: config and preflight

- Config sheets: Settings, Levers, Context, Recodes, Sentence, Structure,
  Crossings, Bundles. Reader `R/08_config.R`; template
  `lib/generate_config_template.R` (house styles, `turas_saveWorkbook`); a test
  ties `WHATIF_KNOWN_SETTINGS` to the template.
- Data preparation `R/09_prepare.R`: data read as text, never type-guessed;
  labelled ratings become scale points from the Survey_Structure Options sheet
  (rank by DisplayOrder among options on the scale); numeric answers keep their
  number; items averaged; a blank item (not asked) is left out of the average,
  a don't-know answer takes the dont_know rule's value and is counted; context
  from missing label, DisplayText or BoxCategory, Recodes, then small levels
  collapsed.
- Preflight `R/10_preflight.R` in keydriver's log shape: outcome categories,
  don't-know shares, routed questions, overlapping levers, likely symptoms,
  coverage with no contrast, small levels, proposed Structure rules, and after
  the fit the sign check.
- `run_whatif()` `R/12_run.R`; Excel `R/13_excel.R`; the contribution file
  `R/11_island.R`; the What If tile `run_whatif_gui.R` plus a `launch_turas.R`
  entry and icon.

Verification (quoted from the runs):

- SACAP 2025 config (`dev/verify_configs.R`, baselines off): coefficients
  within 4.48e-06 of `study_sacap.py`; value for money slip -26.3, lift +14.1;
  all eight need counts and both bundles (16.4, 8.1) identical.
- CCPB 2026 config: coefficients within 4.38e-06 of `study_ccpb.py`; every
  effort number and need count identical; Spaza with delivery and rep both
  slipping one point 82.3 to 69.2 (prototype 82 to 69). Held-out fit 0.158
  against the prototype's 0.172: over 10 fold seeds it runs 0.158 to 0.175,
  and the default seed happens to be the lowest.
- The SACAP preflight proposes 44 Structure rules, the brief's count.

## Session 3: the report tab

- Tabs: `whatif_island` setting (registered in `build_config_object()` and
  the known-settings list; template row; the committed
  `Crosstab_Config_Template.xlsx` regenerated, only that row differs), the
  reader, the island `data-wi` in `template.html` with `data-island="v2"`,
  `27w_whatif.js`, the tab in the Read group before Story, `wi-` styles.
- Live (open) mode: the tab follows the filter bar. `TR.stats.mask()` gives
  the audience, and the tab works each number out respondent by respondent
  from the fixed model. In the node gate the live numbers for everyone and for
  a filtered group equal the R engine's to 0.006 (points, ranges, bundles).
- Client-safe mode: the report's filter bar is hidden on this tab and the
  audience strip says so; the tab has its own picker offering only published
  groups, up to two, the second only along a declared crossing.
- Build a ...: open mode enforces the Structure rules (a blocked level is not
  offered; a change that makes the current choice impossible switches it to
  the allowed level most respondents have, and says so). Client-safe mode
  offers only combinations at least the minimum number of respondents share.
- Rate as one uses the average respondent's baseline (`ctx_offset`).
- Decisions recorded: Pin and Story capture the card's HTML at the moment of
  pinning (`data-snap-card`), like every other v2 card, so a pinned What if
  panel is a snapshot and does not follow later filter changes. A lever
  question with Include = N in the tabs config is no problem: the contribution
  file carries its own lever values.
- Checked in the browser on a synthetic report (parity fixture data layer):
  live mode with a filter ("Cohort: Alpha", 40 students) and a scenario;
  client-safe mode with the picker. Screens not attached; Duncan's eyeball on
  a real regeneration is still owed.

## Session 4: client-safe

- Shared layer `modules/shared/lib/disclosure_groups.R` (tabs can adopt it
  for the cube hole): minimum group, secondary suppression, pairwise nesting
  check, and a recoverability check (below). `disclosure_audit_groups()`
  re-checks.
- The client-safe part carries group results as point and range only, a model
  block without context baselines, a Build a ... model with levels under k
  pooled and no per-level counts, need counts only when both sides clear k,
  symptoms only when both sides clear k, and nothing that names a refused or
  hidden group (those go to the workbook's Privacy sheet).
- The release audit reads the What if island and refuses a client-safe
  deliverable that carries respondent rows, a group under k, named refusals,
  baseline coefficients, profile counts, small need counts or symptoms, a list
  about as long as the study, or a subtraction it can do itself (whole sample
  minus a variable's levels; a level minus its cells) that leaves 1 to k-1.

## Deviation: brief decision 6 was not enough (independent review, 24 Sep)

An independent review found that secondary suppression plus the pairwise
nesting check does not stop recovery. Subtraction chains: the whole sample
minus the other levels gives a small level back, and a row total minus its
shown cells gives a hidden cell that then solves a column. Measured: 117 of
150 random studies leaked a count of 1 to 9; with the old rules, SACAP 2025
leaked 5 small groups and CCPB 2026 leaked 11. The prototype's client-safe
pages in `prototypes/nps-simulator/build/` were built under those rules and
must not be sent to anyone.

Fix (strictly stronger than decision 6, so built without waiting): a fourth
rule. A group can be worked out exactly when its membership is a linear
combination of the published groups' memberships. Every small candidate
(each single level and each cell of every two-way crossing of the filter
variables, declared or not, with 1 to k-1 respondents) is tested by least
squares; the smallest published group in a recovering combination is hidden,
and all the checks repeat until nothing is recoverable.

Result: SACAP publishes 282 groups (was 291), CCPB 236 (was 244). An
independent attack (projection by SVD, over respondents) finds 0 recoverable
small groups on both, and 0 of 150 random studies leak (it finds 117 with the
rule switched off, so it can fail).

Limit, stated plainly: this tests single levels and two-way cells. A small
set of another shape (a three-way cell, a union of cells from different rows)
is not tested. It is the practical bound for what a reader can compose from
one- and two-way groups, not a proof. Two things the file still reveals, by
design: which full Build a ... profiles have fewer than k respondents (they are
simply not offered, the usual k-anonymity practice), and how many cells of each
declared crossing are shown (not which are hidden, nor their sizes, much as
the tabs cube already does).

## Tests (quoted from the runs, 24 Sep 2026)

| Suite | Result |
|---|---|
| What if (`modules/whatif/tests/run_tests.R`) | 293 of 293 |
| Shared disclosure (`test_disclosure_groups.R`) | 305 of 305 |
| Shared release audit (`test_release_audit.R`) | 71 of 71 |
| Tabs What if island (`test_whatif_island.R`) | 62 of 62 |
| Node: whatif view / renderer presence / cover / sig level | 15 / 13 / 37 / 28, all passed |
| Tabs full suite (before the disclosure fix) | 6420, 1 failure: the template drift, fixed by regenerating the template |
| Shared full suite (before the disclosure fix) | 2265, 1 failure that predates this branch |

Failures that are not this branch's: `test_committed_workbook_parts.R` flags
`examples/segment/create_segment_example.R:145` (a direct saveWorkbook call);
`tests/testthat/test_launcher.R` asserts 14 modules and the registry had 17
before this branch (18 now). Both fail on main as well.

## Still open

- **For Duncan**: the SACAP 2025 tabs config has `apply_weighting = True` with
  a `weight` column, while the What if config runs unweighted (brief decision
  8). In an open report the What if tab uses its own weights, so its actual
  NPS (45.6) will not match a weighted report's (46.6). Decide which is right
  and set `weight_variable` to match.
- **For Duncan**: review the 44 proposed Structure rules for SACAP (workbook
  sheet Proposed_Structure) and copy the real ones onto the Structure sheet.
  Only one rule (BSW with Masters) is there now.
- **For Duncan**: regenerate a SACAP report through `launch_turas()` in both
  delivery modes and eyeball the tab (session 5 work).
- SACAP Survey_Structure: Q027's "DK" option is not marked ExcludeFromIndex
  (its Index_Weight is blank, which the What if reader now treats as off the
  scale). Worth fixing in the structure file for tabs too.
- Session 5: stats pack sheets, module README update, "How to read the What
  if tab" for clients, the 2026 wave.
- A multinomial model for an unordered outcome is not built.
- The tabs cube could adopt `disclosure_groups.R` to close the SACS cube hole.
  Proposed, not done.
