# MaxDiff Sessions B2 + C, and the integrated demo: implementation notes

Branch: `feature/maxdiff-v2-report`, off `feature/maxdiff-correctness` at
6d3e0165 (Session A's tip, left exactly where it was). **Not merged, not
pushed.** Built on an unreviewed Session A, as conjoint C was built on its
unreviewed A: the Fable pre-merge reviews should be taken in order, Session A
first, then this branch's delta.

Written 2026-09-02. Everything below was verified by execution in this
session unless marked otherwise.

---

## What the session set out to do

Duncan's brief: make conjoint and maxdiff work with tabs v2, out of the box,
with no live project, the simulator an essential part of the deliverable, and
a demo. Conjoint already reached tabs v2 on local main (island, Conjoint tab,
tabs importance export, standalone simulator, merged 2026-08-27). MaxDiff had
none of that, and neither module had a shipped example that actually ran.

## What landed, in commit order

| Commit | What |
|---|---|
| `992d945c` test(maxdiff) | Four Session A assertions that could never pass (see "Session A's suite" below). |
| `0f020fbf` feat(maxdiff) | `R/12_tabs_export.R` (B2) and `R/13_v2_island.R` (the maxdiff half of C), wired into the output stage; three OUTPUT_SETTINGS keys. |
| `dd67a135` feat(tabs) | `maxdiff_island` setting, `data-md` island, `27y_maxdiff.js` view, MaxDiff tab, tests on both sides and a node gate. |
| `55f09b3c` feat(maxdiff) | `examples/maxdiff`: a shipped Karoo Coffee study that runs out of the box; the guard-lookup fix. |
| `fbb3b972` fix(conjoint) | The shipped conjoint example runs again (it refused on a retired setting); docs and scripts de-drifted. |
| `f50dfcc7` fix(maxdiff) | The standalone simulator computed on the wrong items; segment filter matched nobody; estimator mislabelled. |
| (this commit) | `examples/integrated_demo`, docs, these notes. |

## The route: conjoint's, not the handover's

The maxdiff handover (§4, Session C) specified `md_utility` / `md_share` /
`md_bw` / `md_anchor` / `md_turf_step` row kinds through `build_dl_question()`.
Conjoint Session C had already shown, and its notes record, that those
functions serialise crosstabs (rows keyed by banner column with a base and a
percentage), and that a part-worth has none of those. The memory note for
Session A said the same: use the conjoint precedent. So: a frozen island
(`{output}_md_island.json`, `meta.kind = "maxdiff"`) plus the module's own
view, zero new row kinds, the filter bar hidden on the tab.

The tabs hook is a second copy of the conjoint one with maxdiff names, not a
generalisation. That is what the codebase established (`qual_json`, `cj_json`,
now `md_json`, each a named parameter), and the whitelist trap
(`crosstabs_config.R` line 342 AND the `TABS_KNOWN_SETTINGS` list) is the same
trap in the same two places.

## Honest-sig (D5) as built

- No individual utilities (`Generate_HB_Model = NO`): the export refuses
  `MODEL_NO_RESPONDENT_UTILITIES`.
- Empirical-Bayes fallback (cmdstanr absent, which is this machine and any
  fresh one): refuses `MODEL_APPROX_UTILITIES` unless
  `Allow_Approx_Utilities_Export = YES`; then the QuestionText reads
  "MaxDiff preference shares (model-derived, empirical Bayes fallback)
  (approximate: count-based)" and the METHOD sheet carries an APPROXIMATE row.
- Stan (`model_fit$method == "cmdstanr"`): exported unstamped.
- The island's `meta.estimationNote` carries the same words, the MaxDiff tab
  shows them in a stamp panel for the fallback, and the simulator's Overview
  callout and Diagnostics tile now say which estimator ran (they said
  "Hierarchical Bayes" whatever ran).

Refusal codes are `MODEL_*` because `maxdiff_refuse()` prefixes anything
outside its list with `CFG_`; the handover's `CALC_APPROX_UTILITIES` would have
become `CFG_CALC_APPROX_UTILITIES`.

## What the island carries (curated, D1)

`scores` (parallel arrays in config item order: counts, best/worst/net,
logit utility and SE, HB utility and its spread, preference share, rescaled
score), `discrimination`, `turf`, `anchor`, and `meta` (method, methodLabel,
estimationNote, n, tasks, items per task, weighting note, frozen + filter
note, simulatorFile). Absent blocks are absent, never `{}`: the conjoint
C-delta review's finding 2 was a `{}` truthy in JavaScript. HB diagnostics,
individual utilities and the per-segment tables stay in the Excel deliverable.

## Findings along the way, all fixed on this branch

1. **Session A's suite was not green at its tip.** In a worktree at 6d3e0165
   the suite reports 4 failures, not the 902/0/0 the notes record: a call with
   an argument name the function does not have (`num_versions`), two anchor
   tests building item ids that could never match ("1" vs "I1"), a fixture
   missing the columns the counts merge in, and assertions on `Best_Count`
   where the frame has `Times_Best`. All four are in the A8 commit that turned
   stubs into assertions. Test-only fixes; no engine change.
2. **The guard was not loaded when 00_main.R is sourced from elsewhere.** The
   lookup used the Rscript `--file` argument, which is the caller's directory,
   so a headless run's first refusal died with "could not find function
   maxdiff_refuse". The README recipe would have crashed on any bad path.
   Found by mistyping a config path. Fixed with a frame walk; test added.
3. **The simulator paired utilities with items by position** while the EB
   fallback's `reshape()` writes item columns alphabetically. Every share,
   head-to-head probability and TURF reach was on the wrong item; the item
   the counts ranked first showed last. Found only by opening it in a browser
   on real output and comparing with the count scores. Nobody had done that
   since the retirement plan. Fixed in the transformer; test added.
4. **The simulator's segment filter matched nobody** since Session A moved
   SEGMENT_SETTINGS to one row per group: the filter entry had an empty value.
   Group rows now expand into the data's levels. Test added.
5. **The shipped conjoint example refused out of the box** on
   `include_diagnostics` (retired) and would have carried `baseline_handling`
   (retired) too; `test_analysis.R` hard-coded `/home/user/Turas`; the README
   pointed at files that do not exist. Rebuilt; the MNL integration tests now
   run an MNL copy of the config rather than assuming the shipped one is MNL.

## Deviations, logged

- Segment cuts are NOT in the island (the handover said "pre-computed rows").
  Under D1 they are the crosstab's job: the tabs export gives the reader
  shares by any banner, live under the audience filter, which is better than
  a frozen table. Excel still has SEGMENT_SCORES.
- The classic maxdiff HTML report is NOT retired. The handover says only after
  Duncan confirms v2 supersedes it. `Generate_HTML_Report` still defaults ON;
  the examples set it NO so the v2 report is the deliverable.
- `Tabs_Question_Code` is sanitised to letters, digits and underscores (a
  leading digit gets a `Q`), so the column names stay valid for tabs.
- The MaxDiff view uses en dashes for missing values and no em dash anywhere;
  the conjoint view on this branch still has them (the em-dash sweep lives on
  `fix/tabs-no-em-dashes`, unmerged, and will take that file).

## Not verified

- The Stan path, again: cmdstanr is not installed (PROG-1). The `stan_hb`
  labelling and unstamped export are covered by unit tests with a synthetic
  `model_fit$method = "cmdstanr"`, not by a sampled run.
- The GUI. Per the standing rule the code was fixed and the suites run;
  Duncan exercises `launch_turas()`. The examples were run headless through
  the same entry points the GUI calls (`run_maxdiff`,
  `run_conjoint_analysis`, `run_tabs_analysis`).
- The tabs R suite in a worktree shows 4 failures in two `test_reader_report.R`
  tests ("cannot open the connection"). They fail identically on the
  untouched baseline in the same worktree and are the known worktree
  environment failures; they are not from this branch.

## What a regen will surface as expected, not regression

- A maxdiff run now writes `{output}_md_island.json` every time, and
  `_tabs_shares.xlsx` when asked. Nothing changes for tabs unless a config
  names `maxdiff_island`.
- With `Generate_Tabs_Export = YES` and no cmdstanr, the run logs a PARTIAL
  "Tabs export not produced: MODEL_APPROX_UTILITIES" unless the override is
  set. That is the gate working.
- The simulator's shares will differ from before on any study whose item ids
  were not already alphabetical: the old numbers were on the wrong items.

## Suites at the tip

maxdiff 1025 / 0 / 0; conjoint 986 / 0 / 0; tabs R 5194 pass / 4 fail (the
two known worktree reader-report tests) / 1 skip; tabs node gate 37 / 37 plus
the text-mutation check.
