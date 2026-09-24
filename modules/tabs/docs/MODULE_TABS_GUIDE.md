# Bringing Other Modules into the Tabs Report

The tabs report can carry results from six other Turas modules, and
segment, conjoint, maxdiff and pricing can also add new questions to the
crosstabs themselves. This guide says how each one gets there, which
setting on which side switches it on, and what changes when the report is
sent client safe.

Checked against the code on 24 September 2026. This guide stays at the
level of settings and files; each module's README has the detail.

---

## Two routes, and when to use which

| Route | What you get | Modules |
|----|----|----|
| **1. A module tab** | A tab of its own in the report's Read group, showing that module's results as the module computed them | Conjoint, MaxDiff, Pricing, Key drivers, Categorical drivers, What if |
| **2. New crosstab questions** | Per-respondent results written as ordinary tabs questions, so they can be cut by any banner, weighted and significance-tested like the rest of the survey | Segment (as a banner), Conjoint, MaxDiff, Pricing |

A project can use both. Conjoint is the usual example: the Conjoint tab
shows importance and utilities for the whole sample, and the importance
export lets the same importance be cut by region in the crosstabs.

---

## Route 1: a module tab

### The three steps

1. **Run the module.** It writes a small contribution file beside its own
   Excel output (the file names are in the table below). Catdriver is the
   one module that needs switching on first: set `v2_island = TRUE` on its
   Settings sheet.
2. **Name the file in the tabs config.** On the Settings sheet, set the
   module's `*_island` key to the file's path. A relative path is read
   from the tabs config's own folder, so `04 Conjoint/Study_cj_island.json`
   works when that folder sits beside the config. A full path works too.
3. **Rebuild the tabs report.** The tab appears in the Read group, after
   Qualitative and before Story.

Leave the key blank and there is no tab, and nothing else about the report
changes. There is no `show_` switch for a module tab: the blank key is the
switch.

### The six modules

| Module | File it writes | Switched on in the module by | Tabs setting | Tab |
|----|----|----|----|----|
| Conjoint | `{output}_cj_island.json` | Always written when the run produced utilities | `conjoint_island` | Conjoint |
| MaxDiff | `{output}_md_island.json` | Always written | `maxdiff_island` | MaxDiff |
| Pricing | `{output}_pr_island.json` | Always written | `pricing_island` | Pricing |
| Key driver | `{output}_kd_island.json` | Always written | `keydriver_island` | Key drivers |
| Categorical driver | `{output}_cd_island.json` | `v2_island = TRUE` on the catdriver Settings sheet (default FALSE) | `catdriver_island` | Categorical drivers |
| What if | `{output_name}_whatif_island.json` in the What if config's `output_folder` | Always written | `whatif_island` | What if |

`{output}` is the module's own Excel output name without `.xlsx`.

### What each tab shows

- **Conjoint.** Attribute importance, part-worth utilities, model fit and
  willingness to pay. The market simulator stays a separate HTML file
  (`generate_html_simulator` in the conjoint config); the tab links to it
  when it exists.
- **MaxDiff.** Item scores, preference shares, TURF and must-haves, with
  the estimator named.
- **Pricing.** Van Westendorp price points with their intervals, the
  Gabor-Granger demand and revenue curves, the monadic cells and the
  recommended price. The pricing simulator stays a separate file.
- **Key drivers.** Importance per driver by method with bootstrap
  intervals, the importance-performance quadrant, the driver by segment
  matrix with its bases, and model diagnostics.
- **Categorical drivers.** Driver importance, the odds ratio for every
  driver level with its interval, probability lifts, the raw factor
  patterns, any subgroup comparison and the model diagnostics.
- **What if.** Where to direct effort, scenarios, and "Build a ...". In a
  full report it follows the filter bar. See the What if section below.

The first five are frozen results: they show what the module estimated on
its own sample and do not respond to the report's audience filter. To cut
conjoint, maxdiff or pricing results by audience, use route 2.

### When the file is wrong or missing

The run does not stop. The console prints a `[WARNING]` naming the file,
and the report is built without that tab. Check the console after every
build that should have a module tab. The usual causes:

- The path is wrong, or the module has not been run since the folder moved.
- The file is from a different module (each reader checks the file's kind).
- The What if file is from an earlier What if version. Run the What if
  module again. The other five readers do not check versions, so after a
  Turas upgrade, rerun the module before rebuilding the report.

### Weighting

Only What if is checked against the report. The What if file holds an
unweighted version, and a weighted one when its config names a
`weight_variable`. The report uses the version that matches its own
`apply_weighting` and `weight_variable`, and leaves the tab out, with a
boxed console warning, when there is no match.

The other five follow their own module's config and are never compared
with the tabs weighting:

| Module | Weighting of the tab's numbers |
|----|----|
| Conjoint | Always unweighted (the tab says so) |
| MaxDiff | The maxdiff config's own weight setting |
| Pricing | The pricing config's `weight_var` |
| Key driver | The keydriver config's `weight_var` |
| Categorical driver | The catdriver config's `weight_var` |

For a weighted study, set the same weight in each module's config as in
the tabs config, or the tab and the crosstabs will disagree.

### Client-safe builds

The tabs GUI asks **Who is this file for?** on every build (see
[06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md), "Who Is This File
For?").

- **What if** changes with the answer. A full report gets the live,
  respondent-level version, lined up with the report's own respondents so
  it follows the filter bar. A client-safe build (interactive or frozen)
  gets precomputed results for published groups only. If the tabs
  `min_reporting_base` is larger than the What if file's `min_group`, the
  tab is left out with a disclosure warning: raise `min_group` in the What
  if config and run it again.
- **The other five ship unchanged in every mode.** None of their files
  carries respondent rows. Two of them do carry per-segment cells, gated by
  their own module's minimum rather than the tabs `min_reporting_base`:
  maxdiff's `Min_Respondents_Per_Segment` and keydriver's `min_segment_n`.
  Tabs does not compare those with `min_reporting_base`. For a client-safe
  report on a small or sensitive sample, set them at least as high as
  `min_reporting_base` before running the module.

The What if contribution file itself holds respondent IDs. Keep it with the
project and never send it; the report embeds only the part the delivery
mode allows.

### The What if tab

The What if module is set up in its own config workbook (the **What If**
tile in `launch_turas()` can create a blank one). Its Levers sheet decides
which areas the model uses. Things to keep in line with the tabs config:

- `data_file`: the same data file as the tabs report.
- `id_variable`: the respondent ID. The full report lines up What if rows
  with its own respondents by this ID.
- `weight_variable`: the tabs report's weight column, or blank if the
  report is unweighted.
- `min_group`: at least the tabs `min_reporting_base`.
- `profile_builder = N` for staff surveys and any study where the client
  manages the respondents.

Module guide: `modules/whatif/README.md`.

---

## Route 2: new crosstab questions

These modules write an extra workbook that tabs does not read on its own.
You wire it in by hand, once: the module tells you exactly which rows to
paste where.

| Module | Switch in the module's config | File written | Arrives in tabs as |
|----|----|----|----|
| Segment | `tabs_export = Y` (Settings) | `{prefix}tabs_data.xlsx` and `{prefix}tabs_banner_stub.xlsx` | A banner: one Single_Response column of segment names |
| Conjoint | `generate_tabs_export = Y`, code from `tabs_question_code` (default `CJIMP`) | `{output}_tabs_importance.xlsx` | An Allocation question: attribute importance per respondent, summing to 100 |
| MaxDiff | `Generate_Tabs_Export = YES` (OUTPUT_SETTINGS sheet), code from `Tabs_Question_Code` (default `MDSHARE`) | `{output}_tabs_shares.xlsx` | An Allocation question: preference shares per respondent, summing to 100 |
| Pricing | `Generate_Tabs_Export = Y`, code from `Tabs_Question_Code` (default `GGACC`); `Export_WTP = Y` adds willingness to pay. Both need `ID_Variable` | `{output}_tabs_pricing.xlsx` | The Gabor-Granger acceptance grid as a Multi_Mention question, a validity flag, and optionally WTP as a Numeric question |

### Segment as a banner

`{prefix}tabs_data.xlsx` is your survey file with a segment column joined
on by respondent ID. Respondents the segmentation removed are labelled
`Unassigned`. `{prefix}tabs_banner_stub.xlsx` holds three sets of rows and
says where each goes:

1. The **Questions** row goes into Survey_Structure's Questions sheet.
2. The **Options** rows go into Survey_Structure's Options sheet. Keep the
   OptionText exactly as written: tabs matches it against the data
   literally.
3. The **Selection** row goes into the tabs config's Selection sheet. It
   arrives with `UseBanner = Y` and `Include = N`; set `Include = Y` too if
   you also want the segment as a table.

Then point the Survey_Structure's `data_file` (Project sheet) at
`{prefix}tabs_data.xlsx`. Segment refuses the export for a run that
compares several methods; export from the final single-method run.

Clustering is unweighted, so a weighted tabs run shows different segment
sizes from the segmentation report. And significance tests across segments
on the variables that built them are in-sample and will flatter the
solution: the stub's provenance sheet says so.

### Conjoint, MaxDiff and Pricing exports

Each workbook has the same three sheets:

- **DATA**: the respondent ID and the new columns (`{code}_1` to `{code}_k`
  for an Allocation). Add these columns to your survey data file, matched
  on the respondent ID.
- **QUESTIONMAP_SNIPPET**: the Survey_Structure rows. The question row
  goes into the Questions sheet (its heading in the workbook says
  "QuestionMap sheet"; it means Survey_Structure's Questions sheet), and
  the option rows into the Options sheet. Then add the question to the
  tabs config's Selection sheet with `Include = Y`.
- **METHOD**: what the numbers are and how they were made. The question
  text carries the method, so the label follows the numbers into the
  crosstab.

Only genuine respondent-level estimates export. Conjoint refuses unless
`estimation_method` is `hb` or `latent_class`. MaxDiff refuses without an
HB model, and refuses its empirical-Bayes fallback unless
`Allow_Approx_Utilities_Export = YES`, in which case the question text is
stamped as approximate. Pricing exports only answers respondents gave (and
the opt-in WTP); price points and curves are whole-sample estimates and
never go to tabs.

---

## Not a route into tabs

- **Weighting.** The weighting module writes an ID and weight file. Tabs
  reads only a weight column that is already in the data file, so merge
  the weights in before the tabs run and name the column in
  `weight_variable`.
- **Brand, confidence, report_hub.** No route into the tabs report.
  Report_hub combines finished HTML reports instead.
- **Tracker.** Tabs has its own Tracking tab, driven by `waves_source`.
  See [11_DATA_CENTRIC_REPORT_V2.md](11_DATA_CENTRIC_REPORT_V2.md).

---

## Checklist before sending a report with module content

- Every module tab you expected is in the tab bar, and the console shows
  no `[WARNING] ... island` line.
- Each module was run on the same data file and with the same weighting as
  the tabs report.
- The module files were written by the current Turas version (rerun after
  an upgrade).
- For a client-safe report: `min_group` on What if, and any per-segment
  minimum on maxdiff or keydriver, is at least `min_reporting_base`.
- No `*_whatif_island.json` or route 2 DATA workbook is in the folder you
  send. Both hold respondent-level rows.
