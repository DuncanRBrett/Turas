# Weighting — Runbook

How to run a weighting job end to end, and what to do when it stops. Written to
be enough on its own: if the module refuses, the code it prints is in the table
at the bottom with the fix.

- **Reference for every config field:** `TEMPLATE_REFERENCE.md`
- **Choosing a method, reading diagnostics:** `USER_MANUAL.md`
- **Config at a glance:** `../README.md`

---

## 1. What this produces

A **lookup file**: one row per respondent, the respondent ID, and one column per
weight. Tabs merges it back onto the survey data on the ID column. That is the
deliverable — the HTML report and diagnostics workbook are for checking the
weights, not for shipping.

Everything in this module is built around that merge being safe. If a weight
cannot be calculated, its column is left out of the file rather than written as
blanks; if a respondent cannot be weighted, the run refuses rather than writing
a blank that would silently shrink every base downstream.

---

## 2. Before you start

You need three things:

1. **The data file** — `.csv`, `.xlsx` or `.sav`, with a column that identifies
   each respondent exactly once, and the weighting variables spelled the way
   your targets spell them.
2. **Population targets** — from the census, the panel book, or the client. This
   module calculates weights; it does not know what the population looks like.
3. **A config file** — `Weight_Config.xlsx`.

Generate a fresh config from the template rather than copying an old one:

```bash
Rscript -e 'source("modules/weighting/lib/generate_config_templates.R"); generate_weight_config_template("my_project/Weight_Config.xlsx")'
```

The generated template carries its own column help text in row 4 and example
rows you can overwrite. Both are read back by the test suite, so the examples in
it are examples the engine will actually accept.

---

## 3. Running it

### From the Turas GUI (the normal path)

```r
source("launch_turas.R")
launch_turas()
```

Click **Weighting**, browse to the project folder, pick the config file, click
**Calculate Weights**. Errors appear in the R console you launched from — keep
it visible, because that console is where the refusals print in full.

### From R

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("my_project/Weight_Config.xlsx")
result$status   # "PASS", "PARTIAL" or "REFUSED"
```

### From the command line

```bash
Rscript modules/weighting/run_weighting.R my_project/Weight_Config.xlsx
```

---

## 4. Reading the outcome

**PASS** — every weight calculated, every check met.

**PARTIAL** — the run produced output, but something in it is not what the
config asked for. Never ship a PARTIAL without reading why. The three that
matter:

| Code | What happened |
|---|---|
| `CALC_MARGINS_NOT_ACHIEVED` | A rim weight's achieved margins are further from the targets than `margin_tolerance`. The weights are usable but they are not the weights you asked for. |
| `CALC_WEIGHT_OMITTED_FROM_OUTPUT` | One weight failed. Its column is absent from the lookup file, so a tabs config asking for it will not find it. |
| `IO_HTML_REPORT_INCOMPLETE` | The HTML report is missing one or more tables. The weights are fine; the report is not. |

**REFUSED** — nothing was written. The refusal names the problem and the fix;
section 6 has the full list.

---

## 5. Checking the weights before you use them

From the diagnostics, in order of what usually goes wrong:

1. **Effective N and DEFF.** DEFF above 2.0 means half your sample has been
   spent on weighting. Effective N is what your significance tests are really
   working with.
2. **Max weight.** Above 5 and one respondent is speaking for five. Above 10 the
   diagnostics say so.
3. **Achieved margins** (rim). Every category against its target. The run will
   have told you already if anything missed by more than `margin_tolerance`, but
   look at the near-misses too.
4. **Sum of weights.** Rim and cell weights sum to n. Design weights sum to n
   unless you set `grossing = Y`, in which case they sum to the population.

Then hand the lookup file to tabs and check the weighted base on the first table
against the effective N you just read.

---

## 6. When it refuses

Codes are grouped by what you have to go and change. Every refusal prints its
own `how_to_fix`; this is the index.

### The config file itself

| Code | Fix |
|---|---|
| `IO_CONFIG_NOT_FOUND`, `CFG_FILE_NOT_FOUND` | Check the path. The GUI passes an absolute path; a hand-typed one is relative to the working directory. |
| `CFG_MISSING_SHEET`, `CFG_EMPTY_SHEET` | A required sheet is absent or has no rows. Generate a fresh template and compare. |
| `CFG_MISSING_COLUMNS` | The sheet's headers do not match. If you built the config by hand, headers go in row 1; the generated template puts them in row 3 and the loader handles both. |
| `CFG_MISSING_SETTING` | A required General-sheet setting is blank. |
| `CFG_UNKNOWN_METHOD`, `CFG_INVALID_METHOD` | `method` must be `design`, `rim`, `rake` or `cell`. |

### Targets

| Code | Fix |
|---|---|
| `CFG_TARGET_NOT_NUMERIC` | A target cell is not a number: `52%`, a comma decimal, a stray space, or the letters `NA` (which is text, not an empty cell). The refusal names the row and the value. |
| `CFG_TARGET_SUM_ERROR` | Targets for one variable do not sum to 100 (or to 1, through the direct API). The shortfall used to be absorbed silently by the first category. |
| `CFG_INVALID_TARGET_VALUE` | A target is missing or negative. A cell target of exactly zero is allowed — a sparse census cell rounding to 0.0% is ordinary — but if respondents are standing in that cell they refuse as `DATA_UNWEIGHTED_ROWS`, because a zero weight removes them from every base without their appearing as missing. |
| `CFG_NO_USABLE_TARGETS` | Every populated cell has a zero target, so there is no distribution left to weight towards. Usually a percent/proportion mix-up or a category mismatch. |
| `CFG_DUPLICATE_TARGET_CATEGORY` | One category listed twice for the same variable. |
| `CFG_MISSING_TARGETS`, `CFG_NO_TARGETS`, `CFG_INCOMPLETE_TARGETS` | The targets sheet has no rows for this weight, or is missing combinations. |
| `CFG_INVALID_POPULATION`, `CFG_INVALID_POPULATION_SIZES` | `population_size` must be a positive number. |

### Data and categories

| Code | Fix |
|---|---|
| `DATA_UNWEIGHTED_ROWS` | Two different problems share this code, and the refusal names which one you have. **Respondent side** — someone would end up with no weight: a category with no target, a missing value in a weighting variable, or a cell whose target is zero. The opt-in is `allow_unmatched = Y`; their weights stay blank and the rest sum to the respondents who kept one. **Population side** — a target has a share but nobody in the sample to carry it. The opt-in is `allow_empty_targets = Y`, which redistributes that share across the targets that do have respondents. Setting one does not answer for the other. Fix the spelling or the targets first: matching ignores surrounding spaces but **is case-sensitive**. |
| `DATA_UNMATCHED_VALUES` | The rim equivalent: a data value with no target category. Rim also refuses on missing values in a rim variable. |
| `DATA_DUPLICATE_IDS` | The ID column repeats. tabs joins on it, so a repeat puts weights on the wrong people and the merged file still looks well-formed. If the message says the column was defaulted to the first column, set `id_column` in the General sheet. |
| `DATA_MISSING_ID` | Some rows have a blank ID. |
| `CFG_INVALID_ID_COLUMN`, `CFG_MISSING_ID_COLUMN` | `id_column` is not a column in the data, or could not be resolved. |
| `CFG_WEIGHT_NAME_COLLISION` | A `weight_name` matches a column already in the data — usually last month's weight still sitting in the file. It would be overwritten silently. |
| `CFG_WEIGHT_NAME_IS_ID` | A weight is named after the ID column, which would destroy the merge key. |
| `DATA_KEY_SEPARATOR_IN_VALUE` | A category value contains a control character used to build cell keys. Clean the value. |
| `DATA_NO_COMPLETE_CASES` | Nothing left after excluding rows with missing weighting variables. |

### Calibration (rim)

| Code | Fix |
|---|---|
| `MODEL_NO_CONVERGENCE` | Raking cannot reach the targets. In order: set `calibration_method = logit` with finite `weight_bounds`; widen the bounds; raise `max_iterations`; reduce the number of rim variables. A target needing a 3x+ stretch on one category often defeats raking at any bounds. |
| `MODEL_BOUNDS_ISSUE`, `CFG_INVALID_BOUNDS*` | `weight_bounds` is malformed or too tight. Format is `lower,upper`, e.g. `0.3,3.0`. `logit` needs finite bounds on both sides. |
| `CALC_NONPOSITIVE_WEIGHTS` | `linear` calibration produced zero or negative weights, which would remove those respondents from every base. Use `logit`, or raise the lower bound above zero. |
| `CFG_INVALID_MARGIN_TOLERANCE` | `margin_tolerance` must be a non-negative number of percentage points. Checked on both the config path and the exported core. |

### Trimming

| Code | Fix |
|---|---|
| `CFG_TRIM_USE_CAP` | `apply_trimming = Y` on a rim weight. Capping after raking breaks the margins raking just calibrated. Set `apply_trimming = N` and use `cap_weights` in Advanced_Settings, which caps during calibration. |
| `CFG_INVALID_CAP`, `CFG_INVALID_PERCENTILE` | `trim_value` must be positive for `cap`, and a proportion strictly between 0 and 1 for `percentile` — `0.95`, not `95`. |

### Output and environment

| Code | Fix |
|---|---|
| `CALC_NO_WEIGHTS_PRODUCED` | Every weight failed. Each has its own refusal above it. |
| `IO_DATA_FILE_NOT_FOUND`, `IO_DATA_LOAD_FAILED` | Check `data_file`. Paths are relative to the config file. |
| `IO_UNSUPPORTED_FORMAT` | `.csv`, `.xlsx` or `.sav` only. |
| `IO_WRITE_FAILED`, `IO_DIR_CREATE_FAILED` | The output folder does not exist or is not writable. OneDrive folders can lock briefly while syncing. |
| `PKG_SURVEY_MISSING`, `PKG_OPENXLSX_MISSING`, `PKG_HAVEN_MISSING` | `renv::restore()`. |

---

## 7. Two things that will catch you

**A rim weight cannot be trimmed after the fact.** Every other module in the
market treats trimming as a post-processing step; here it is refused for rim,
because the module has already calibrated the margins and capping would unpick
them without saying so. `cap_weights` is the setting you want, and it does the
job better — the cap holds during calibration and the margins still come out
right.

**Design weights are normalised by default.** A design weight is population over
sample, so it naturally arrives at population scale — mean 20 on a 1-in-20
sample — while a rim weight sums to n. Two weights on one study would then put
weighted bases three orders of magnitude apart. The default normalises design
weights to sum to n so both are on the same scale; `grossing = Y` keeps
population scale when you want grossed-up counts. Kish n_eff is scale-invariant,
so significance testing is identical either way. Only the weighted Ns move.

The stratum table in the report carries both numbers: **Weight** is what the
lookup file contains, and **Pop/Sample** is the population-over-sample
arithmetic it came from. They are the same figure only under `grossing = Y`.

**One weight failing does not stop the others.** In a multi-weight config, a
weight that cannot be calculated is reported, left out of the lookup file, and
the remaining weights are still calculated — the run comes back PARTIAL. Errors
that are not specific to one weight still stop everything: an unreadable config,
a duplicated respondent ID, a weight name that collides with a data column, and
anything preflight rejects. If *every* weight fails, the run refuses with
`CALC_NO_WEIGHTS_PRODUCED` rather than writing a file of bare IDs.

**Where the weighted base is checked.** Every method now states what its weights
should add up to, and the run refuses if they do not: rim sums to the respondents
it calibrated, a normalised design weight to the respondents carrying one, and a
cell weight to the same. A grossed design weight is exempt — it sums to the
population by design, and there is nothing independent to check it against.

---

## 8. Running the tests

```bash
Rscript -e 'testthat::test_dir("modules/weighting/tests/testthat", reporter = "summary")'
```

Two warnings are expected, both the module's own trimming-bias warning fired on
purpose: `test_trimming.R` and `test_config_templates.R` each trim 20% of weights
to exercise it. Anything else is a loose end.
