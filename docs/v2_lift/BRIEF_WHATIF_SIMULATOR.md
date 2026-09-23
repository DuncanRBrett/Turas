# Brief: a What if simulator for Turas, SACAP student survey first

Written 2026-09-23 from a planning session with Duncan. The design is settled
and proven on real data in Python prototypes; this brief turns it into a Turas
module in five build sessions. Read sections 1 to 4 before any session starts.
The prototypes, the evidence and every decision are in
`prototypes/nps-simulator/PLAN.md`; this brief does not repeat them all.

## 1. What it is, and why

A report tab that answers the question clients ask most: where should we direct
effort? It links one outcome question (NPS here; any categorical outcome in
general) to the experience ratings around it, then shows, for any group:

- what the outcome would lose if an area slipped, and gain if it were fixed for
  the people who need it (the effort table, with net promoters per 100 people
  reached, the nearest the data gets to value for effort);
- combined scenarios (several areas at once);
- "Build a student": the Economist-style line, a respondent described in a
  sentence of dropdowns, with the NPS the model expects from people like that
  against everyone;
- "Rate SACAP as one student": the same lever model seen from one person.

The first project is the SACAP student survey. It must be built generic from
day one: the prototypes already served SACAP (5-point labelled ratings, weights
optional) and CCPB (1 to 10 ratings, averaged lever items, coverage levers such
as "has coolers", a rating that only applies to outlets with signage) from one
engine and one page, with only a study definition changing.

Brand trackers (IPK) are NOT in version 1. They need a person-and-brand model;
the feasibility work is on branch `feature/whatif-ipk` (`36fa85e1`).

## 2. What exists today

**Prototypes** (Python, on main at `37d280f0`, `prototypes/nps-simulator/`):

- `whatif_engine.py`: ordinal lever model (Detractor < Passive < Promoter),
  bootstrap refits, sign check, additive profile model with a cross-validated
  ridge penalty, client-safe groups (secondary suppression plus a cross-table
  nesting check), precomputed group results, and an audit that no list in the
  client-safe output is as long as the number of respondents.
- `study_sacap.py`, `study_ccpb.py`: the study definitions. These are the
  prototype of the config.
- `template_whatif.html`: the tab mockup in the tabs v2 report shell, with an
  Open / Client-safe switch.
- `robustness.py`: the checks in section 5.

Run: `python3 study_sacap.py && python3 build.py` from that folder. Outputs go
to the gitignored `build/` and carry client data: never commit them.

**Turas code this plugs into** (all checked on main, 2026-09-23):

- Catdriver fits ordinal models with `ordinal::clm`, falling back to
  `MASS::polr` (`modules/catdriver/R/04a_ordinal.R:13`). `ordinal` is in
  `renv.lock`. Catdriver refuses continuous drivers
  (`08a_guards_hard.R:395`, `CFG_CONTINUOUS_DRIVER_NOT_ALLOWED` at :421), and
  codes an ordinal driver as one dummy per level, which is why the simulator is
  its own module (section 3).
- The tabs v2 report already carries other modules as tabs through a
  contribution file. The catdriver path end to end: the setting
  (`crosstabs_config.R:406`, and `:1875` in the known-settings list), the
  template entry (`generate_config_templates.R:641`), the reader
  (`run_crosstabs.R:758`), the conditional include
  (`build_report_v2.R:249`, `"27j_catdriver.js" = has_island(...)`) and the
  tab (`24_shell.js:39`). Copy that path.
- The report's data mode is `html_report_v2_interactivity`: records, cube or
  none (`crosstabs_config.R:264`). `hasComputedSource()` in `20_data.js:311`
  tells a view whether respondent records or the cube are installed.
- The minimum group is `min_reporting_base`, counted on respondents
  (`data_layer_writer.R:217`, `:1332`).
- Shared disclosure code: `modules/shared/lib/disclosure_gate.R` and
  `turas_release_audit.R`.
- The known cube hole: `cube_cell_ids()` drops respondents outside a banner's
  levels (`cube_writer.R:742`), so a two-way slice need not add up to its
  margin. See memory `reference_cube_margin_differencing`. The simulator's
  client-safe rules solve the same problem (section 6, session 4).

## 3. Decisions already taken (Duncan, 23 Sep 2026)

1. **A new module, `modules/whatif/`**, not an extension of catdriver. It
   leaves catdriver's reports and guards alone and has its own config.
2. **Its own penalised ordinal fit in R** (`optim`), tested against
   `ordinal::clm` at zero penalty. No new dependency: `ordinalNet` is not needed.
3. **Ordinal by default.** Binary when the outcome has two categories;
   multinomial only for a genuinely unordered outcome.
4. **Two delivery modes, one engine.** Open (respondent rows; national and panel
   studies) and client-safe (model plus precomputed group results; list
   studies). The mode follows the tabs "Who is this file for?" choice.
5. **The minimum group counts respondents**, default 5, settable per project.
   A population basis was considered and dropped: it fails whenever the client
   can tell who answered.
6. **Crossings use secondary suppression plus a cross-table nesting check**,
   never all-or-nothing and never plain small-cell hiding.
7. **Profile builder ("Build a ...")**: off by default for staff surveys and any
   study where the client manages the respondents. In client-safe mode it offers
   only combinations that at least the minimum number of respondents share, and
   every level entering the profile model must itself clear the minimum.
8. **Weighting is a per-study setting that matches the study's report.** SACAP
   student runs unweighted.
9. **Version 1 scope**: effort table, scenarios, Build a student, Rate as one
   student, diagnostics. No brand support, no wave backtest.

**Still open, for Duncan before session 5:** whether the SACAP deliverable is
open or client-safe. Notes from early September say SACAP's report has shipped
with respondent data under a "the recipient cannot re-identify" judgement. Build
both modes regardless.

## 4. The statistics, and what the build must carry over

Measured by `robustness.py` on SACAP 2025 and CCPB 2026 (details in PLAN.md,
"How robust is it"):

- The prototype fit equals `ordinal::clm` to 4 decimals on both studies.
- Proportional odds holds, except value for money in SACAP (`nominal_test`,
  p = 0.001). Ranking unaffected. Report the test in the stats pack.
- One straight-line effect per rating point beats a separate effect per band on
  held-out data.
- **Calibration is the one weakness, and its fix is part of version 1.** With
  ratings alone, 6 of 36 SACAP groups missed their actual NPS beyond sampling
  error (BSocSci Honours: predicted 43, actual 24). Adding who the respondent is
  as baselines with a ridge penalty on those terms only took that to 0 of 36 and
  raised held-out fit from 0.201 to 0.213. That test ran on the weighted SACAP
  file; re-run it unweighted in session 1 and record the numbers.
- The client-safe shortcut (adding single-area results for a combination) is
  within a median 0.3 NPS points of the exact answer; worst seen 5.6.
- Bootstrap ranges keep weights fixed. Fine at SACAP's design effect of 1.12;
  re-weight inside each resample if a study's design effect exceeds about 1.5.
- It is association, not cause. Every page says so, and no wording in the tab,
  the stats pack or a template claims that fixing an area WILL add points.

## 5. Boundaries for every session

- TRS refusals, never `stop()`; every refusal also printed to the console.
- Tests first for anything with a number in it. Synthetic fixtures only in the
  suite; client data never enters `tests/` or git.
- Do not touch catdriver, keydriver or the brand module.
- Nothing is written into OneDrive or `examples/*/Output`. Duncan regenerates
  through `launch_turas()` and eyeballs the report.
- New tabs settings must be registered in `build_config_object()` and the
  known-settings list, or they arrive as NULL (CLAUDE.md, "Whitelists").
- Any page script shipped inside the report is wrapped in an IIFE and hardened
  last (CLAUDE.md, "Composed reports").
- No em dashes in any string a client or Duncan reads.
- Two sessions share one checkout: check the branch and `git status` first, work
  on a branch, and prefer a worktree (memory `feedback_r_suites_in_a_worktree`
  for the renv setup).

## 6. The build, in five sessions

Each session ends with its suite quoted from the run and a short NOTES file in
`docs/v2_lift/`. Recommended model: Opus 5 at high effort; session 4 is the one
worth an independent review afterwards.

### Session 1: the engine in R

`modules/whatif/R/`: design matrix for the three lever kinds (rating,
nested, coverage) plus context baselines; the penalised ordinal fit (penalty on
context terms only, chosen by cross-validation); bootstrap refits that resample
respondents; the sign check with an expected direction per lever; moves (slip,
improve, lift to a target, extend, withdraw); group results; the profile model.

Verification bar:
- Unpenalised fit equals `ordinal::clm` to 1e-4 on a synthetic fixture (a
  testthat test) and on SACAP 2025 (a one-off script, not in the suite).
- With context baselines off, the SACAP 2025 unweighted effort numbers match the
  prototype's main fit exactly (all students, value for money: slip -26.3, lift
  to Good +14.1, from `study_sacap.py`). Bootstrap ranges match within noise.
- With baselines on: the calibration table re-measured, unweighted.

Starting prompt:
> Read docs/v2_lift/BRIEF_WHATIF_SIMULATOR.md sections 1 to 6 and
> prototypes/nps-simulator/PLAN.md. Build session 1: the What if engine in R
> as a new module, modules/whatif/, porting whatif_engine.py's model, moves and
> profile model, with the ridge-penalised context baselines added. Tests first,
> against ordinal::clm and a synthetic fixture. Work on a branch in a worktree.

### Session 2: the config and preflight

A config workbook (template generator entry included): Settings (outcome and how
to band it, unit noun, weight variable, minimum group, reliability floor, profile
builder on or off, bootstrap count), Levers (label, question codes averaged into
it, kind, what counts as having the service, fix target, expected direction,
include or symptom), Profile (questions in sentence order with the words
between), Filters and Crossings, Bundles. Labels, scales and routing come from
Survey_Structure. A preflight flags rating questions correlating above about
0.7, routed questions (suggest nested), likely symptoms (contact, complaints,
switching), and a lever whose sign is unstable.

Verification bar: SACAP 2025 and CCPB 2026 expressed as configs, and both runs
reproduce the session 1 numbers. Every config error is a TRS refusal with a fix.

### Session 3: the report tab (open mode)

A `whatif_island` tabs setting and `{output}_whatif_island.json`, copying the
catdriver path in section 2; a renderer `27w_whatif.js` and a "What if" tab in
the Read group. In records mode the tab is LIVE: the group is the report's own
audience filter, and lever answers come from the respondent data the report
already carries, so the island adds only the model. In none mode it shows the
whole sample and each banner column.

Decide and record: how Pin and the Story tab capture a panel that changes with
the filter; what happens when a lever question is not in the respondent data
(for example Include = N).

Verification bar: node gate tests for the renderer; the mockup
(`prototypes/nps-simulator/template_whatif.html`) is the design reference; the
effort table under a filter matches the R engine for the same group.

### Session 4: client-safe mode

The secondary suppression and nesting check go into the shared disclosure layer
(`modules/shared/lib/`), not into the module, so tabs can use them later. The
engine precomputes results for the slices the cube publishes, at the same
minimum. The release audit learns the simulator island. The profile builder
rules from decision 7.

Verification bar: the prototype's SACAP counts at minimum 5 reproduced (291
groups; campus by course 38 of 53 shown; 3 cells hidden by the nesting check);
the audit refuses a planted leak; an independent review of the disclosure code
before merge.

Note: applying the same rules to the tabs cube would close the SACS cube hole.
That is a separate change to tabs; propose it, do not do it here.

### Session 5: SACAP 2025 dry run, docs, stats pack

Duncan regenerates SACAP 2025 through `launch_turas()` and compares the tab with
the prototype. Stats pack sheets: declaration, fit, proportional-odds test,
calibration table, sign check, symptoms excluded. Module README and a short
"How to read the What if tab" for clients, in Duncan's voice. Then the 2026 wave
when its data arrives: the questions are all still asked, but their numbers have
moved (recommend is Q16 in the 2026 questionnaire), so the config maps codes.

## 7. After version 1

- Brand trackers: the person-and-brand model, a partial "10 more in 100" move,
  mental availability as the headline lever, share shift across brands. Start
  from `feature/whatif-ipk`, and first test whether a link is worth the same for
  every brand.
- The tracker backtest: did groups whose ratings moved between waves move in
  outcome as the model predicted? CCPB has two waves with the same questions.
- Re-weighting inside the bootstrap for heavily weighted national studies.
