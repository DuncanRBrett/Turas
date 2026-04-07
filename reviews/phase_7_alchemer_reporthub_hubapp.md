# Phase 7: AlchemerParser + Report Hub + hub_app Review

**Reviewed:** 2026-04-07
**Scope:** modules/AlchemerParser/ (11 prod files, 4,392 LOC) + modules/report_hub/ (10 prod files, 3,978 LOC) + modules/hub_app/ (9 prod files, 3,312 LOC)
**Verdict:** PASS WITH CONDITIONS — 2 critical findings, 5 important, 4 minor

---

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| AlchemerParser tests | `testthat::test_dir("modules/AlchemerParser/tests/testthat", reporter = "summary")` | PASS — 299 passed, 0 failures, 0 skipped, 1 warning (pre-existing) |
| Report Hub tests | `testthat::test_dir("modules/report_hub/tests/testthat", reporter = "summary")` | PASS — 360 passed, 0 failures, 0 skipped, 0 warnings |
| hub_app tests | `testthat::test_dir("modules/hub_app/tests/testthat", reporter = "summary")` | FAIL — 6 errors (path resolution), 1 warning. **Requires `TURAS_ROOT` env var.** With env var set: 263 passed, 0 failures, 0 skipped, 1 warning |

---

## Critical Findings

### C1. No formula injection protection in AlchemerParser Excel output

**Files:** `AlchemerParser/R/06_output.R` (5 writeData calls)
**Affects:** All Excel output from the module

Zero calls to `turas_excel_escape()`, zero inline escape functions. Every `writeData()` call writes data frames directly to Excel without escaping.

User-sourced text reaching Excel unescaped:

- **Selection sheet** (line 58): `crosstab_data` — `QuestionCode` and `QuestionText` columns. Question text originates from the Alchemer translation export, user-controlled.
- **Questions sheet** (line 81): `survey_data$questions` — `QuestionCode`, `QuestionText`, `Variable_Type`, `Notes`. Question text from translation export.
- **Options sheet** (line 90): `survey_data$options` — `OptionText`, `DisplayText`. Option labels from translation export, fully user-controlled.
- **Routing sheet** (line 101): `routing_summary` — condition text extracted from Word document parsing. User-authored document content.
- **Headers sheet** (line 125): `headers_data` — generated question codes. Lower risk but derived from user data column names.

The most dangerous vectors are **OptionText/DisplayText** (translation export option labels, directly user-controlled) and **QuestionText** (from translation export). A survey author who includes `=IMPORTXML(...)` as an option label would have it written verbatim to Excel.

This is the identical pattern found and fixed in pricing (Phase 5 C1), conjoint (Phase 6 C1), maxdiff (Phase 6 C2), segment (Phase 4 C1), keydriver/catdriver (Phase 3 C3), weighting (Phase 2 C2), and stats_pack_writer (Phase 0 C5).

**Fix:** Define `alchemer_escape_cell()`/`alchemer_escape_df()` inline fallback using vapply+substr (not regex, per Phase 3 re-review R3). Apply to all character columns in data frames before `writeData()`. Follow the pricing module pattern.

### C2. hub_app tests fail without TURAS_ROOT environment variable

**Files:** `hub_app/tests/testthat/test_export_pptx.R`, `test_guard.R`, `test_hub_generator.R`, `test_integration.R`, `test_preferences.R`, `test_search_index.R`
**Affects:** Standard test execution via `testthat::test_dir()`

Six of seven test files use:
```r
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules", "hub_app", ...))
```

When run via `testthat::test_dir()`, `getwd()` resolves to the test directory itself, not the project root. The `source()` paths then point to non-existent locations, producing 6 errors and zero test coverage for these files.

Only `test_project_scanner.R` has the correct fallback:
```r
turas_root <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(turas_root)) {
  test_dir <- getwd()
  candidate <- normalizePath(file.path(test_dir, "..", "..", "..", ".."), mustWork = FALSE)
  if (file.exists(file.path(candidate, "launch_turas.R"))) {
    turas_root <- candidate
  }
}
```

This means the standard test command `testthat::test_dir("modules/hub_app/tests/testthat")` fails. Tests only pass when `TURAS_ROOT` is explicitly set. This is inconsistent with every other module in the platform.

**Fix:** Apply the `test_project_scanner.R` walk-up fallback pattern to all 6 affected test files.

---

## Important Findings

### I1. AlchemerParser early_refuse() has no cat() before stop() in GUI launcher

**Files:** `AlchemerParser/run_alchemerparser_gui.R` line 25, `AlchemerParser/run_alchemerparser.R` line 54
**Affects:** Error display when required packages are missing

Both files define `early_refuse()` which constructs a formatted error message and calls `stop(message, call. = FALSE)` without a preceding `cat(message)`. In Shiny, the formatted error may not reach the console.

Same pattern fixed in pricing (Phase 5 I1), conjoint (Phase 6 I1), maxdiff (Phase 6 I2), confidence (Phase 2 I4), keydriver/catdriver (Phase 3 I2-I3), segment (Phase 4 I2).

**Fix:** Add `cat(message)` before the `stop()` call in both files.

### I2. AlchemerParser readxl::read_excel() unprotected in translation parser

**File:** `AlchemerParser/R/02_parse_translation.R`, line 59
**Affects:** Error handling for corrupt or password-protected translation files

```r
translation_data <- readxl::read_excel(file_path)
```

No `tryCatch` wraps this call. File existence is checked (line 31) and readxl availability is verified (line 47), but the actual read operation is unprotected. A corrupt, password-protected, or malformed Excel file would crash with a raw R error instead of a TRS refusal.

Compare with `01_parse_data_map.R` where the `readxl::read_excel()` call IS wrapped in `tryCatch` with a proper TRS refusal.

**Fix:** Wrap in `tryCatch()` with TRS refusal matching the data map parser pattern.

### I3. hub_app PPTX export temp file leak

**File:** `hub_app/lib/export_pptx.R`, lines 128, 192-240
**Affects:** Temp file cleanup after PPTX export

`add_pin_slide()` receives `temp_files` by R value semantics (not by reference). Line 240: `temp_files <- c(temp_files, img_path)` modifies a local copy. The caller's `temp_files` vector at line 109 is never updated. The cleanup loop at lines 146-148 operates on an empty vector, so all decoded PNG temp files leak until R's tempdir is purged.

**Fix:** Use an environment for mutable state:
```r
# In export_pins_to_pptx():
temp_env <- new.env(parent = emptyenv())
temp_env$files <- character(0)

# In add_pin_slide():
temp_env$files <- c(temp_env$files, img_path)

# In cleanup:
for (tf in temp_env$files) { ... }
```

### I4. hub_app create_branded_template returns NULL instead of TRS refusal

**File:** `hub_app/lib/create_branded_template.R`, line 33
**Affects:** Callers expecting TRS result structure

```r
if (!requireNamespace("officer", quietly = TRUE)) {
  cat("[Hub App] ERROR: officer package required...\n")
  return(NULL)
}
```

Returns bare `NULL` when the officer package is missing. Callers checking `result$status` would error on `NULL`. All other hub_app functions return structured TRS refusal lists.

**Fix:** Return `list(status = "REFUSED", code = "PKG_MISSING_DEPENDENCY", message = "...", how_to_fix = "...")` instead of NULL.

### I5. Report Hub config template dropdown missing 4 valid report types

**File:** `report_hub/lib/generate_config_templates.R`, line 203
**Affects:** Config validation assistance for operators

The `report_type` dropdown lists: `tracker, tabs, confidence, catdriver, keydriver, weighting`.

Missing from dropdown but supported by the parser and badge map: `maxdiff`, `conjoint`, `pricing`, `segment` (and aliases `segmentation`, `crosstabs`, `categorical driver`, `key driver`).

An operator configuring a conjoint or pricing report would not get dropdown validation help, potentially leading to a typo in the type field.

**Fix:** Add `maxdiff`, `conjoint`, `pricing`, `segment` to the dropdown. Omit the aliases since the auto-detection path handles them.

---

## Minor Findings

### M1. AlchemerParser guard state infrastructure defined but unused

**File:** `AlchemerParser/R/00_guard.R`
**Affects:** Code maintainability

`alchemerparser_guard_init()`, `guard_record_parse_error()`, `guard_record_unmapped_question()`, and related guard state functions are defined but never called from `00_main.R`. Input validation still occurs inline in the main pipeline and individual parsers, so the module is not unguarded — but the structured guard state mechanism is dormant.

### M2. Report Hub GUI source() outside tryCatch

**File:** `report_hub/run_report_hub_gui.R`, line 487
**Affects:** Error recovery in the "Combine Reports" handler

`source(main_file, local = TRUE)` is executed before the `tryCatch` block at line 495 that wraps `combine_reports()`. If `00_main.R` (or any of its sub-sources) has a syntax error, the error propagates unhandled. The `is_running(TRUE)` flag at line 463 would never be reset, leaving the UI frozen in a "running" state. Low practical risk since source-time errors only occur during development.

### M3. hub_app `%||%` operator defined in 5 files

**Files:** `export_pptx.R:310`, `hub_generator.R:28`, `project_scanner.R:25`, `search_index.R:207`, `run_hub_app_gui.R:13`
**Affects:** Code maintainability

The null-coalescing operator is defined locally in 5 separate files. Each is sourced with `local = TRUE` so there is no conflict, but it is redundant code. Could be consolidated into a shared utility.

### M4. hub_app project_scanner writeLines missing encoding

**File:** `hub_app/lib/project_scanner.R`, line 914
**Affects:** Non-ASCII project notes on Windows

`writeLines(json_out, note_file)` does not specify `useBytes = TRUE` or encoding. Other writeLines calls in the module (run_hub_app_gui.R lines 449, 586) correctly use `useBytes = TRUE`. Inconsistent encoding handling could produce mojibake on Windows for non-ASCII content.

---

## Test Coverage Summary

| Metric | AlchemerParser | Report Hub | hub_app |
|--------|----------------|------------|---------|
| Production files | 11 | 10 | 9 |
| Production LOC | 4,392 | 3,978 | 3,312 |
| Test files | 7 (+1 helper) | 10 (+1 helper) | 7 (+1 fixture gen) |
| Test LOC | 1,561 | 2,442 | 1,550 |
| LOC ratio (test:prod) | 0.36 | 0.61 | 0.47 |
| Tests passing | 299 | 360 | 263 |
| Tests failed | 0 | 0 | 6 (path issue — C2) |
| Tests skipped | 0 | 0 | 0 |
| Warnings | 1 (TRS fallback) | 0 | 1 (hub_generator source) |

### Coverage assessment

**AlchemerParser** has good test coverage for core parsing logic (data map, translation, classification, code generation, routing detection) and output generation. Error handling has 26 dedicated tests. The helper-setup.R correctly defines `alchemerparser_refuse()` as a local fallback. No golden fixtures.

**Report Hub** has the strongest test coverage of the three modules. Integration tests exercise the full pipeline (config read → parse → assemble → write). Guard layer has 79 tests. Preflight validators have 32 tests. Config template generation has dedicated tests with content validation.

**hub_app** has good structural test coverage for project scanning (58 tests), search indexing (39 tests), preferences (27 tests), and PPTX export. Integration tests cover the full flow (scan → generate hub → export). The test path issue (C2) means 6 of 7 test files are non-functional without environment variable setup — this is the most significant test quality finding.

---

## TRS Compliance Summary

| Metric | AlchemerParser | Report Hub | hub_app |
|--------|----------------|------------|---------|
| stop() in core R/ | 0 | 0 | 0 |
| stop() in guard fallback | 2 (acceptable) | 0 | 0 |
| stop() in GUI launcher | 1 (early_refuse — I1) | 1 (structured TRS condition — correct) | 0 |
| stop() in CLI launcher | 1 (early_refuse — I1) | 0 | 0 |
| TRS refusals | 15+ (alchemerparser_refuse) | 20+ (report_hub_refuse) | 15+ (structured lists) |
| Guard layer | Defined, partially unused (M1) | Complete (934 LOC) | Complete (143 LOC) |
| Stats pack | N/A (parsing tool) | N/A (report combiner) | N/A (launcher/GUI) |
| Console output | Good | Comprehensive | Comprehensive |
| Formula escape | ABSENT (C1) | N/A (no Excel output) | Low risk (auto-deleted config) |
| Callout fallback | N/A (no HTML reports) | N/A (no callouts) | N/A (no callouts) |
| HTML escaping | N/A | htmltools::htmlEscape() throughout | N/A |

---

## Module-Specific Assessments

### AlchemerParser — Parsing Accuracy

AlchemerParser is the foundation of everything downstream. The parsing pipeline is well-structured with clear separation:

1. **Data export map parsing** (`01_parse_data_map.R`): Correctly handles multi-column questions, grid sub-questions, other/othermention fields. Column header parsing uses regex for question ID extraction. tryCatch protects the Excel read.

2. **Translation export parsing** (`02_parse_translation.R`): Extracts question and option texts by key pattern (`q-{id}`, `q-{id}-o-{code}`). Correctly skips otherText fields. Missing tryCatch on Excel read (I2).

3. **Word questionnaire parsing** (`03_parse_word_doc.R`): Extracts structural hints (grid markers, scale indicators) from the Word document. Uses officer package. Non-fatal if no hints extracted.

4. **Question classification** (`04_classify_questions.R`): Multi-step classification: data map → translation → Word hints. Variable types (Single_Response, Multi_Mention, Rating, Likert, NPS, Ranking, Open_Ended) correctly assigned. Grid detection uses bracket patterns and Word doc hints.

5. **Routing detection** (`04b_detect_routing.R`): Extracts skip logic from Word questionnaire. Identifies show/hide conditions and dependent questions.

6. **Code generation** (`05_generate_codes.R`): Generates standardized question codes (Q01, Q02, ...). Validation catches duplicates, format mismatches, and ambiguous multi-column questions. Text similarity function for cross-referencing is correctly implemented (Jaccard).

7. **Output generation** (`06_output.R`): Generates 3 Excel files for downstream Tabs module consumption. Structure is correct. Missing formula escaping (C1).

**No statistical calculations requiring correctness verification.** The module is a deterministic parser with no probabilistic or mathematical operations beyond text similarity.

### Report Hub — Assembly Quality

The Report Hub is well-engineered with defense-in-depth:

- **HTML escaping**: All user-sourced text passes through `htmltools::htmlEscape()` before HTML embedding. No XSS vectors found.
- **Report key validation**: Regex-enforced alphanumeric+hyphens+underscores. Safe for DOM insertion and JavaScript string contexts.
- **Base64 iframe isolation**: Reports are base64-encoded and loaded as iframes, preventing cross-report DOM interference.
- **Preflight validation**: 11 independent checks before assembly begins.
- **Pin system**: Correctly delegates to shared TurasPins JavaScript library.
- **UTF-8 handling**: HTML output written via `writeBin(charToRaw(enc2utf8(...)))` — cross-platform safe.

The `early_refuse()` pattern in the GUI launcher (lines 13-40) is the CORRECT pattern: `cat()` output before `stop(cond)` with a typed `turas_refusal` condition class. This module's error handling is the most mature of the three.

### hub_app — Launcher Quality

The hub_app is clean (zero stop() calls) with good error handling throughout:

- **Project scanning**: Efficient directory walking with skip patterns for `.git`, `node_modules`, etc. File type sniffing reads only first 100 lines of HTML files.
- **Preferences**: JSON-based persistence at `~/.turas/hub_app_config.json`. Unknown keys silently dropped (intentional — prevents injection of unexpected settings).
- **PPTX export**: officer-based generation with data URL → PNG decoding. Template fallback chain (custom → branded → Office default). Temp file leak in I3.
- **Search**: `grepl(..., fixed = TRUE)` prevents regex injection. Good.
- **Hub generation**: Auto-discovers reports, generates ephemeral config, calls Report Hub, cleans up.

---

## Fix Status (2026-04-07)

| Finding | Status | What was done |
|---------|--------|---------------|
| C1: AlchemerParser formula injection | FIXED | Added `alchemer_escape_cell()`/`alchemer_escape_df()` inline fallback using vapply+substr. Applied to all 5 writeData paths in `06_output.R` |
| C2: hub_app tests path resolution | FIXED | Applied walk-up-from-test-dir fallback pattern to all 6 affected test files |
| I1: AlchemerParser early_refuse cat() | FIXED | Added `cat(message)` before `stop()` in both `run_alchemerparser.R` and `run_alchemerparser_gui.R` |
| I2: AlchemerParser readxl tryCatch | FIXED | Wrapped `readxl::read_excel()` in `tryCatch()` with TRS refusal for corrupt files |
| I3: hub_app PPTX temp file leak | FIXED | Changed to environment-based mutable state for temp_files tracking |
| I4: hub_app branded template NULL return | FIXED | Returns TRS refusal list instead of NULL |
| I5: Report Hub config template dropdown | FIXED | Added maxdiff, conjoint, pricing, segment to report_type dropdown |
| M1-M4 | DEFERRED | All minor findings deferred to Phase 10 horizontal pass |

**Deferred to Phase 10 (horizontal pass):**
- M1: AlchemerParser guard state infrastructure unused
- M2: Report Hub GUI source() outside tryCatch
- M3: hub_app %||% operator defined in 5 files
- M4: hub_app project_scanner writeLines encoding

**Next:** Re-review in fresh session to verify all fixes.
