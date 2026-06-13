# Session 1 — Tabs JSON data-layer writer (build plan)

**Branch:** `feature/tabs-json-data-layer` (off `main`, with the stats-pack fix
merged in — `run_crosstabs.R` helper-move + numeric-zero base fix).
**Goal:** a writer that emits the `data-agg` JSON island from a normal tabs run,
alongside the existing Excel/HTML outputs, behind a config flag. **Aggregates
only** — no microdata (that defers the privacy decision; published tables,
dashboards and tracking all work without it).
**Why this first:** it is the only blocker between the proven v2 renderer and a
real report. Everything downstream of it is already gated by the prototype.

This plan is grounded in code that was read and verified on 2026-06-13, not
inferred. Field names below are real.

---

## 1. The target — what the renderer consumes (verified)

The renderer boots from a `data-agg` object. **`d2.validate` (`src/js/20_data.js:103`)
hard-fails the boot on only two things:**

- `agg.questions` — non-empty array (`DATA_NO_QUESTIONS`)
- `agg.columns` — non-empty array (`DATA_NO_COLUMNS`)

Everything else is optional or conditional. But the renderer *reads* these
`project` fields (verified by grep across `src/js/*.js`), so emit them for a
correct display:

| project field | reads | meaning |
|---|---|---|
| `name` | 8 | report title |
| `low_base_threshold` | 6 | base < this ⇒ low-base flag |
| `wave` | 5 | wave label (Step 1: a single static string) |
| `tracking` | 2 | `{enabled, default_scope}` — Step 1: `{enabled:false, default_scope:"all"}` |
| `sampling_method` | 2 | drives CI/MOE vs SI/PE vocabulary (see §6) |
| `brand_colour` | 1 | header/links |
| `accent_colour` | 1 | heatmap |

`alpha`, `client`, `sig_note` are used in the confidence/legend text — emit them
too (cheap), but they are not hard-required.

### Top-level shape
```
{ schema_version: 2, project: {...}, columns: [...], banner_groups: [...],
  categories: [...], questions: [...] }
```

### columns[] (one per banner column, Total first)
```
{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }
{ key: "GENDER::Male", group: "GENDER", label: "Male", letter: "A" }
```
- `key` must be unique and equal across every `row.pct/n/sig` index position.
- `group` = `"total"` for Total, else the banner question code.
- `letter` = the sig letter used inside `row.sig` strings (Total = `""`).
- **tabs' own `internal_keys` ("GENDER::Male") satisfy this as-is** — we do *not*
  need SACAP's exact "Q002::BOXCAT::…" strings, only internal consistency.

### banner_groups[]
```
{ id: "GENDER", name: "Gender" }   // id matches columns[].group
```

### categories[] — string array of unique `question.category` labels.

### questions[] — one entry per question
```
{ code, title, category, type,           // type: "single"|"multiple"|"scale"|...
  bases: [ {n, low}, ... ],              // length = columns.length
  index_desc, index_scores,              // scale questions only; else null
  net_members: { "<rowIdx>": [memberIdx,...] },   // optional
  net_diffs: {},
  rows: [ {kind, label, pct[], n[], sig[]}, ... ] }
```
Row kinds and their cell arrays (all arrays length = `columns.length`):
- `kind:"category"` — `pct[]` percentages, `n[]` counts, `sig[]` letter strings.
- `kind:"net"`      — `pct[]` aggregated, **`n[]` all null**, `sig[]` letters.
- `kind:"mean"`     — `pct[]` holds the mean/index/score, **`n[]` all null**, `sig[]` usually `""`.

---

## 2. The source — what a tabs run already has (verified)

`generate_html_report(all_results, banner_info, config_obj, output_path, survey_structure)`
is called at `modules/tabs/lib/run_crosstabs.R:617`. Same inputs feed the writer.

- **`all_results[[q_code]]`**: `question_code`, `question_text`, `question_type`
  (`Single_Choice`/`Multi_Mention`/`Numeric`/`NPS`/`Rating`/`Likert`/`Ranking`),
  `category`, `bases` (named list by internal_key → `{unweighted, weighted, effective}`),
  and `table` — a **long-format** data.frame.
- **`table`**: one physical row per (`RowLabel`, `RowType`). `RowType` ∈
  {`Frequency`, `Column %`, `Row %`, `Sig.`, `Sig.2`, `Average`, `Index`,
  `Score`, `Base (n=)`, …}. `RowSource` ∈ {`individual`, `boxcategory`,
  `net_positive`, `ranking`, `summary`, …}. Banner values live in columns named
  by internal_key (`table[["GENDER::Male"]]`).
- **`banner_info`**: `internal_keys` (Total first), `key_to_display`, `letters`,
  `column_to_banner`, and per-code meta in `banner_info$banner_info[[CODE]]`
  (`is_boxcategory`, `boxcat_groups`, `internal_keys`, `letters`).
- **`config_obj`**: `project_title`, `client_name`, `brand_colour`,
  `accent_colour`, `alpha`, `significance_min_base`, `apply_weighting`,
  decimal-places, descriptors, etc.

**Reuse, don't reinvent:** `01_data_transformer.R` already implements the
long→wide pivot and row classification we need —
`detect_available_stats()` (scans `RowType`) and `classify_row_labels()` (uses
`RowSource`, with a NET/box-category regex fallback). The writer should call the
same helpers so the JSON and the HTML report classify rows identically.

---

## 3. Field-by-field mapping (source → data-agg)

| data-agg | source |
|---|---|
| `schema_version` | literal `2` |
| `project.name` | `config_obj$project_title` |
| `project.client` | `config_obj$client_name` |
| `project.wave` | new optional config `wave` (default `""`) |
| `project.brand_colour` | `config_obj$brand_colour` |
| `project.accent_colour` | `config_obj$accent_colour` (fallback `heatmap_colour`) |
| `project.low_base_threshold` | `config_obj$significance_min_base` (confirm this is the intended low-base line; see §10) |
| `project.alpha` | `config_obj$alpha` |
| `project.sampling_method` | new optional config `sampling_method` (default `"Not_Specified"`) — §6 |
| `project.sig_note` | generated from `alpha` + sampling labels |
| `project.tracking` | Step 1: `{enabled:false, default_scope:"all"}` |
| `columns[]` | walk `banner_info$internal_keys`; `key`=internal_key, `group`=`column_to_banner[key]` (or `"total"`), `label`=`key_to_display[key]`, `letter`=`banner_info$letters[i]` |
| `banner_groups[]` | unique non-total groups → `{id:CODE, name: banner label}` |
| `categories[]` | unique `all_results[[q]]$category` (config category order if present) |
| `questions[].code/title/type` | `question_code` / `question_text` / mapped `question_type` (§5) |
| `questions[].category` | `all_results[[q]]$category` |
| `questions[].bases[]` | per internal_key: `{n: bases[[key]]$unweighted, low: n < low_base_threshold}` |
| `rows[]` | pivot `table` (§4) |
| `net_members` | from `boxcat_groups` / `net_positive` rows (§7) |
| `index_scores`/`index_desc` | scale score map + descriptor (§7) |

---

## 4. The pivot (long table → wide rows)

For each question, in `banner_info$internal_keys` order (call it `KEYS`):

1. Run `detect_available_stats(table)` and `classify_row_labels(table)` (reuse).
2. For each classified display label (in table order):
   - `pct[]`  = the primary-stat row's values across `KEYS`
     (`Column %` for categorical; `Average`/`Index`/`Score` for mean rows).
   - `n[]`    = the `Frequency` row across `KEYS` for `category` rows;
     **all `null`** for `net`/`mean` rows.
   - `sig[]`  = the `Sig.` row across `KEYS` (use `Sig.2` only if dual-alpha is
     the selected display — Step 1: primary only, keep it simple).
   - `kind`   = `net` if classified NET/box-category-net; `mean` if the row is
     `Average`/`Index`/`Score`; else `category`.
3. JSON null ≠ R `NA`/`NULL`: emit JSON `null` for absent cells (jsonlite
   `na="null"`), and ensure arrays are length `length(KEYS)` (never ragged).

**Numbers must match the HTML report exactly** — same rounding, same primary
stat selection. That equality is the golden-test invariant (§8).

---

## 5. Type mapping (tabs Variable_Type → renderer type)

| tabs | renderer | notes |
|---|---|---|
| `Single_Choice` | `single` | |
| `Multi_Mention` | `multiple` | |
| `Rating`/`Likert` | `scale` | carries `index_scores` + a `mean` row |
| `NPS` | `scale` | NPS score as the `mean` row |
| `Numeric` | `scale` | `mean` row = Average; no category dist if continuous |
| `Ranking` | `single` (Step 1) | revisit if the prototype grows a ranking view |

---

## 6. sampling_method + sig_note (the honesty layer)

The confidence vocabulary (CI/MOE for probability designs vs SI/PE for
non-probability) is driven by `project.sampling_method`. tabs has **no such
field today**. Step 1: add one **optional** Settings field `sampling_method`
(enum from `modules/confidence/R/sampling_labels.R`:
`Random`/`Stratified`/`Cluster`/`Census` vs
`Quota`/`Online_Panel`/`Self_Selected`/`Not_Specified`), defaulting to
`Not_Specified` (the cautious default → SI/PE). `sig_note` is generated from
`alpha` + the sampling labels, mirroring the prototype's `21c_confidence.js`.

---

## 7. The fiddly bits

- **net_members**: for box-category questions, `banner_info$banner_info[[CODE]]$boxcat_groups`
  (or `RowSource=="net_positive"`) tells which member options feed each NET.
  Map each NET row's index in `rows[]` → the integer indexes of its member
  category rows. If a NET's membership can't be resolved, emit the NET row
  without a `net_members` entry (renderer treats it as a standalone net row) —
  do **not** guess.
- **index_scores / index_desc**: for `scale` questions, the label→score map
  (e.g. `{"Terrible":0,...,"Excellent":100}`) comes from the question's scale
  definition / index weights; `index_desc` from `config_obj$index_descriptor`.
  If the scale isn't recoverable, emit `index_scores:null` and a `mean` row
  carrying the computed Average — the renderer tolerates a null score map.
- **dual significance**: Step 1 emits primary `Sig.` only. `Sig.2` is a later
  enhancement (the renderer already supports a dual flag).

---

## 8. Tests (R↔JS golden — copied from the prototype's parity discipline)

1. **R-side schema asserts** (testthat): emit JSON from
   `make_html_test_results()` + `make_html_test_banner_info()` (already in
   `test_html_report.R`); assert top-level keys, every `row.pct/n/sig` length ==
   `columns.length`, net/mean `n[]` all null, bases length, kind enum.
2. **JS contract gate**: shell out to `node` running `d2.validate` on the
   emitted file → assert `ok:true` (mirror the prototype's selftest).
3. **Golden fixture**: commit a golden `*_data.json` for the test fixture;
   re-emit and diff. Drift fails the test (the parity-gate pattern).
4. **HTML/JSON equality**: for the same run, assert the JSON `pct` values equal
   the numbers the HTML report shows (sample a few cells) — guards against the
   two paths diverging.

---

## 9. File + flag wiring

- **New file:** `modules/tabs/lib/data_layer_writer.R` (tabs uses flat `lib/`),
  with a `00`-style guard if it grows. Export `write_data_layer(all_results,
  banner_info, config_obj, output_path, survey_structure)` returning the TRS
  `{status, result/output_file, ...}` shape.
- **Flag:** add `html_report_v2` (working name) to `build_config_object()` and
  the Settings template, default `N`. Surface a checkbox in `run_tabs_gui.R`.
- **Hook:** in `run_crosstabs.R`, right after the existing
  `if (isTRUE(config_result$config_obj$html_report)) { ... }` block (line ~610),
  add a sibling `if (isTRUE(config_result$config_obj$html_report_v2))` that calls
  the writer to `sub("\\.xlsx$", "_data.json", output_path)`. Old path untouched.

---

## 10. Open decisions (Duncan)

1. **`sampling_method`** — add the optional Settings field now (recommended:
   yes, default `Not_Specified`)? This is the *one* real config addition beyond
   the on/off flag. Everything else is derived from existing config/data.
2. **`low_base_threshold`** — is `significance_min_base` the right source, or
   should low-base be its own Settings number?
3. **Flag name** — `html_report_v2`, or something friendlier
   (`data_report` / `report_v2`)?

## Definition of done

- Writer emits a `*_data.json` that passes `d2.validate` and renders in the v2
  engine (drop it into a built shell, boots clean).
- testthat green incl. the new schema + golden + equality tests; full tabs
  suite still green.
- Old Excel/HTML path byte-identical when the flag is off.
