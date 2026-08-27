# TURAS Operator Guide

Quick-start reference for running the Turas Analytics Platform.

---

## Starting Turas

### Local (Mac/Windows)

```r
# Open R or RStudio, set working directory to the Turas folder, then:
source("launch_turas.R")
launch_turas()
```

The Shiny launcher opens in your browser with a grid of all modules.

### Docker — mothballed 11 August 2026

Docker existed so a second operator could run Turas on Windows without an R setup. TRL is a one-person operation now, so nothing runs in a container and the image is no longer built or pushed. The files are all still in the repo, so this is reversible; `Docker/DOCKER_MANUAL.md` is the record. The commands below are kept for that revival, not for daily use.

```bash
# Build the image (first time only)
docker build -t turas .

# Run — mount your data folder so Turas can see your files
docker run -p 3838:3838 -v /path/to/your/data:/data turas
```

Then open `http://localhost:3838` in your browser.

Inside Docker, place config and data files under `/data` — that is the mount point Turas expects.

---

## Module Quick Reference

| Module | What it does | Config format |
|--------|-------------|---------------|
| **AlchemerParser** | Parse Alchemer CSV exports → generate Tabs config | Alchemer CSV + data map |
| **Weighting** | Rim/cell/design weighting | Excel (Config + Weight_Specs + targets) |
| **Tabs** | Cross-tabulation with significance tests | Excel (Config + variable mapping) |
| **Tracker** | Wave-over-wave trend analysis | Excel (same as Tabs + wave settings) |
| **Conjoint** | Choice-based conjoint (HB estimation) | Excel (Config + design) |
| **MaxDiff** | Best-worst scaling | Excel (Config + items + design) |
| **Pricing** | Van Westendorp / Gabor-Granger / Monadic | Excel (Config + price data) |
| **Segment** | K-means / HClust / GMM clustering | Excel (Config sheet) |
| **Key Driver** | Correlation-based importance drivers | Excel (Config sheet) |
| **Categorical Driver** | Logistic regression + SHAP drivers | Excel (Config sheet) |
| **Confidence** | CIs for proportions, means, NPS | Excel (Config sheet) |
| **Report Hub** | Combine HTML reports into a portal | Excel (Config + report list) |
| **Project Steps** | Run the project's external tools (e.g. the comment-appendix builder) | None — a form per tool |

Every analytical module uses an **Excel configuration file** as its primary input. The Config sheet is always a two-column layout: `parameter | value`.

---

## Project Steps (external tools)

Not every step in producing a deliverable is an analytical module. The **Project Steps** tile
runs the ones that aren't — today, the three comment-appendix modes (build/update, report
changed comments, apply approved changes). Pick a step, fill the form, click **RUN STEP**: the
tool's output streams into the page as it runs, and a failure comes back as a TRS refusal
naming what went wrong rather than a silent stop.

The tools can be written in any language. Python ones need their packages first:

```bash
python3 -m pip install -r scripts/requirements.txt
```

The tile checks that before it runs anything, and refuses with `PKG_RUNTIME_MISSING` if the
runtime or a package is absent. Adding a tool: see `modules/steps/README.md`. Why the tile
exists and what it may and may not do: `docs/REPORT_GENERATION_METHOD.md`.

---

## Stats Pack (Diagnostic Workbook)

All modules support an optional **stats pack** — a diagnostic workbook saved alongside the main output as `{output_name}_stats_pack.xlsx`. It provides a full audit trail of data received, methods used, assumptions, and reproducibility information. Designed for advanced partners and research statisticians.

### Enabling the stats pack

Set `generate_stats_pack` in the config Settings sheet (lowercase — setting
names are case-sensitive). **For Tabs it defaults to Y**: the stats pack ships
with every run unless you set `generate_stats_pack = N`.

### Study identification fields

Add optional identity information to the config Settings sheet. These fields
appear on the stats pack Declaration sheet for sign-off and provenance purposes.

| Field | Purpose |
|-------|---------|
| `project_name` | Project name (STUDY IDENTIFICATION section) |
| `analyst_name` | Analyst name (ANALYST & CLOSING SECTION) |
| `research_house` | Research organisation or white-label partner name |

---

## Finite Population Correction (Census Surveys)

For a **census / full-invite** study — you tried to reach a whole, known, finite group (all staff, an entire student body) rather than sampling from a large frame — Turas can apply a finite population correction (FPC). It sizes the statistics on what was actually reached: confidence intervals **narrow as a group's coverage of its universe rises** (reaching zero for a full census), significance is tested on that corrected base, and a small base that is most of its known group is no longer flagged "unstable" (it shows `xx% of N` instead). The reported percentages and means never change — only the intervals and the significance flags.

**It applies to the Excel workbook too, not just the interactive report.** The correction is computed once, in the R engine, so the `Sig.` and `Sig.2` rows in the workbook and the letters in the report are the same letters. Two consequences worth knowing before you read a census deliverable:

- **A fully counted column carries no significance letters at all.** If you reached everyone in a group, there is no sampling error left to test — the difference you can see is simply the difference. Turas leaves that column out of the pairwise tests rather than reporting a p-value for a number that is not an estimate. It still shows its percentages, its base and its interval (which collapses to the point estimate).
- **A corrected column earns letters more easily.** A smaller standard error means a difference that fell just short of significance on an uncorrected base can clear it. This is the correction doing its job, but it does mean a census report is not directly comparable to the same data run without a population configured.

Weighted census studies are corrected too: the correction and the design effect stack, so the test rides the weighted effective base with the correction applied to it.

> FPC corrects **sampling** error only. It does nothing about **non-response bias** — whether the people who did not answer differ from those who did. The report's design note states the response rate and this caveat; you should still check whether low-response groups look different before leaning on group-level findings.

### Configuring it

Two pieces in the **crosstab config** (`Crosstab_Config_Template.xlsx`):

| Where | What |
|-------|------|
| **Settings sheet** | `population_size` = the total universe (e.g. everyone invited). Drives the Total column and the overall response rate shown in the report. |
| **Population sheet** (optional) | One row per banner subgroup: `Group` (the column label exactly as it appears in the report), `Population` (that group's universe N), and an optional `Banner` (the banner question — leave blank unless the same label appears under two banners). Enter only `N`; the responded count is measured from the data. |

Set `sampling_method = Census` as well, so the report speaks "confidence interval" rather than the softened "stability interval".

**Example** (Settings `population_size = 220`, plus the Population sheet):

| Group | Population |
|-------|-----------|
| Head Office | 85 |
| Durban Campus | 13 |
| Academic (general) | 62 |
| Marketing | 8 |

### When to use it vs standard CI

| Use FPC | Use standard CI (leave it off) |
|---------|-------------------------------|
| A census / full-invite of a **known, finite** group, and you are describing **that** group | You sampled from a large or open frame (panel, big customer base) |
| You know the universe size `N` for the groups you report | You don't know `N`, or you're generalising **beyond** the people you enumerated |
| Coverage is meaningful (roughly >10–15% of the universe) | Coverage is tiny (<10%) — FPC barely moves anything |

### Safe by design

- **No population configured** → the report and the workbook behave exactly as before (standard intervals, uncorrected significance). FPC is purely additive.
- **Under a filter or a custom banner** → the interactive report reverts to standard significance, because a filtered sub-population's universe is unknown. Those views are already badged *computed*; the correction belongs to the published cuts you configured a universe for.
- **Incomplete data** → groups with a known `N` are corrected; groups without keep a standard interval. Any `Population` row that matches **no** report column (a typo or stale label) is reported on the console (`matched X of Y subgroup rows…` plus the offending labels), so nothing is silently skipped.

---

## Confidentiality Ship (Disclosure Control)

For anonymity-sensitive studies (staff climate surveys, small insider
populations) the tabs config has two dials that work together:

| Setting | What it does |
|---------|--------------|
| `min_reporting_base` | Hides identifying detail on screen for any cut smaller than k (crosstab columns, comment demographic tags). 1 = off; ~10 for a sensitive sample. |
| `html_report_v2_microdata` | TRUE embeds the anonymised per-respondent island that powers live filters and computed views. **FALSE is the confidential ship**: the file carries published aggregates only. |

**The rule:** the on-screen gate is a viewing convenience. Wherever the
k-gate is a *promise* to respondents, the copy that leaves your hands must be
built with `html_report_v2_microdata = FALSE` — with the island present, the
withheld numbers and per-comment demographics are reconstructable from the
page source (View Source), whatever the screen shows. The build prints a
boxed DISCLOSURE WARNING whenever `min_reporting_base > 1` and the island
still ships, so you cannot send the wrong copy unwarned.

The confidential copy keeps its Tracking tab. It has no per-respondent scores
to recompute from, so the current wave is built from the published figures
instead, and the wave-on-wave significance test takes the current wave's spread
from its published category distribution. The trend and the history are the
same as the analyst's own copy; only the live filter and the computed views are
gone. A question that publishes only its mean, with every category hidden, is
the exception: it has no distribution to take a spread from, so it plots
untested. That build writes no `*_wave.json`, so keep the one your microdata run
produced — it is this wave's contribution to next year's history.

Typical setup: your own working config keeps microdata TRUE (full
interactivity); a second config for the client copy sets it FALSE. The Excel
workbook applies the same k-gate on every sheet (Crosstabs, Index_Summary,
Sample Composition, Summary) in all cases.

---

## The Reader-Key Sidecar (comment reports)

Any project with a coded-comment workbook grows one extra file beside its
config:

```
My_Crosstab_Config.xlsx
My_Crosstab_Config_reader_keys.json     <- the reader-key sidecar
```

**What it is.** Readers mark comments in the report — a shortlist star, a
highlighted passage, a named hub. Those marks live in the reader's browser and
have to point at a specific comment. The sidecar holds one opaque random token
per respondent, and that token is what the marks attach to. It is the *only*
thing that makes a mark survive a re-export.

**What it is not.** It carries no survey answers and no verbatim text — just
respondent id → random token. It never travels into a report, a deck or an
Excel file. Only the token side of it is ever published, and a token on its own
means nothing to anyone without this file.

**Rules:**

- **Do not delete it, and do not rename the config.** The sidecar is found by
  the config's name. Lose either one and every reader mark in every copy of
  that report detaches. There is no way to rebuild it.
- **It travels with the project.** Keep it in the project folder alongside the
  config (OneDrive syncs it like any other file). If you copy a project to a
  new folder, copy this file too.
- **It only grows.** New respondents get new tokens; respondents who drop out
  of an export keep theirs, so if they come back their old marks still fit.
- **If it goes missing or unreadable**, the build says so in a boxed console
  warning and carries on. The report is fine, but marks made against it are not
  durable. Restore the file (or delete it to start clean) and rebuild.

**One-off, the first time you rebuild a project after upgrading:** run the
rebuild on the *unchanged* data before your next real re-export. Existing marks
are re-attached to their new tokens using the current data's row order, so that
first rebuild has to match the data the marks were made against. After that,
re-export freely — that is the whole point of the change.

---

## Typical Workflow

1. **Prepare data** — Clean survey data in Excel/CSV format
2. **Create config** — Copy the module's template from `modules/{module}/templates/`
   (for Tabs: `Crosstab_Config_Template.xlsx` + `Survey_Structure_Template.xlsx`)
   and fill in your settings
3. **Launch Turas** — `source("launch_turas.R"); launch_turas()`
4. **Select module** — Click the module tile in the launcher
5. **Browse to project** — Point the module at your project folder; detected
   config workbooks appear as checkboxes
6. **Run** — Click the Run button; watch the console for progress
7. **Check output** — Results are saved to the output folder specified in your config

For a scripted (non-GUI) Tabs run:

```r
source("modules/tabs/run_tabs.R")
run_tabs_analysis("path/to/My_Crosstab_Config.xlsx")
```

---

## Where to Find Examples

The Tabs module ships a complete synthetic demo project (also the fixture for
its end-to-end test suite):

```
examples/
  tabs/demo_survey/    — Demo_Crosstab_Config.xlsx + Demo_Survey_Structure.xlsx
                         + Demo_Survey_Data.xlsx (regenerate with generate_demo.R)
  tabs/basic/          — minimal structure + config + CSV data
```

To test the module, point it at `examples/tabs/demo_survey/Demo_Crosstab_Config.xlsx`
and run it. Other modules ship worked examples in their own `modules/{module}/`
docs and test fixtures.

---

## Reading Error Messages

Turas uses a structured error system (**TRS**). When something goes wrong, you'll see a boxed message in the console:

```
┌─── TURAS ERROR ───────────────────────────────────────┐
│ Code: CFG_MISSING_COLUMN                              │
│ Message: Column 'Q1_satisfaction' not found in data   │
│ How to fix: Check column names in your data file      │
└───────────────────────────────────────────────────────┘
```

- **Code** tells you the error category (`CFG_` = config problem, `DATA_` = data problem, `IO_` = file problem)
- **Message** says what went wrong
- **How to fix** tells you what to do

Common error prefixes:
- `CFG_` — Fix your config file (wrong parameter, missing setting)
- `DATA_` — Fix your data (missing columns, wrong types, too many NAs)
- `IO_` — Fix file paths (file not found, can't write, directory missing)
- `PKG_` — Install a missing R package

---

## Health Check

After setup (especially Docker), run the health check to verify everything works:

```r
source("scripts/health_check.R")
```

Or from the command line:

```bash
Rscript scripts/health_check.R
```

This checks all dependencies, shared infrastructure, module files, and Docker readiness. All 73 checks should pass.

---

## Troubleshooting

### "Error: package 'X' not found"

```r
renv::restore()   # Installs all required packages from lockfile
```

### "Cannot locate Turas root"

Make sure you're running R from the Turas directory, or set:

```r
Sys.setenv(TURAS_ROOT = "/path/to/Turas")
```

### Output file won't save

- Close the output Excel file if it's open
- Check that the output directory exists
- Check write permissions on the output folder

### Shiny app shows blank / spinner

- Check the R **console** (not the browser) for error messages
- TRS errors always print to the console even if the browser shows nothing

### Module runs but produces empty output

- Check the console for `[TRS INFO]` messages — these show what was skipped and why
- Verify your data file has the columns specified in the config
- Run with a known-good example first to confirm the module works

---

## Console Tips

- **Progress messages** appear as the module runs — watch for step numbers (Step 1/10, etc.)
- **Warnings** are collected and shown at the end (also saved to the Warnings sheet in Excel output)
- **PARTIAL status** means the run completed but with warnings — check the output's Warnings sheet
- **REFUSED status** means the run could not complete — read the error message in the console
