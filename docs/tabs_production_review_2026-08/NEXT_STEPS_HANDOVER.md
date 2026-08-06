# Production-review next steps — handover (2026-08-06)

Two independent implementation jobs remain from the review. Each is sized for
one Opus session. They are independent — either order works, and they should
be separate sessions (separate commits, separate verification).

**Shared context for both sessions:**

- Baseline at handover, re-verified on main @ `1ba9091d` (2026-08-06): tabs R
  suite 3,441 pass / 0 fail / 0 warn / 0 skip; all 26 JS suites green (24 in
  `modules/tabs/lib/html_report_v2/tests/`, 2 in `modules/tabs/tests/js/`).
  Anything below that at the end of a session is a regression.
- Run the R suite via the canonical runner:
  `Rscript tools/run_all_tests.R --module=tabs`. A plain
  `testthat::test_dir("modules/tabs/tests/testthat")` ERRORS in
  `test_audit_stats_fixes.R` — the known missing-`source()` gap (the Job B
  rider fixes it), not a real failure.
- Every fix follows the review's standard: write the test first and **prove it
  fails against the pre-fix code** (revert-run-restore) before accepting the
  fix. No `stop()` — TRS refusals with console output (see `CLAUDE.md`).
- Update `PRODUCTION_REVIEW.md`'s fix-status when done (same style as the
  batch-2 table). Do not push; Duncan verifies via `launch_turas()` and
  regenerates deliverables himself.
- Other sessions sometimes leave uncommitted work on main — run `git status`
  before committing and commit only your own files.

---

## Job A — I20 implementation: reader-mark re-keying — **DONE (2026-08-06)**

Landed to the design, with its §5 test list in full: 8 R areas in the new
`test_qual_reader_keys.R` (plus island-shape regressions in
`test_qual_island_builder.R` and an end-to-end sidecar test in
`test_qual_report.R`), and 9 JS areas in the new
`html_report_v2/tests/qual_rekey_tests.mjs`. R suite 3,516 pass / 0 fail /
0 warn / 0 skip; 27 JS suites green. Review doc and OPERATOR_GUIDE updated;
three implementation notes recorded in the design's new §7. **Job B below is
untouched and still open.** The rest of this section is the original brief.


**The design is done and is binding: `I20_READER_MARK_REKEYING_DESIGN.md` in
this folder.** Read it end to end before writing code; it names the files,
the exact insertion points, the failure modes, and (§5) the mandatory test
list — 8 R tests, 9 JS tests, all required.

Summary of what you are building (the design doc is the authority):

1. New `modules/tabs/lib/qual_reader_keys.R`: `qual_reader_keys(ids,
   config_obj)` — loads/mints/persists an append-only
   `<config>_reader_keys.json` sidecar of random 16-hex per-respondent
   tokens. Never deletes entries; never re-mints over a corrupt file.
2. Island plumbing: `rid` rides each qual record alongside `idx`
   (default-NULL parameters through `qual_build_data_qual` →
   `qual_build_question_island` → `qual_build_record_island`); both entry
   points in `qual_report.R` wire it. `idx` itself changes nowhere.
3. JS (`27q_qualitative.js`): shortlist / highlights / hubs key marks
   `qcode#@<rid>` when records carry `rid`, `qcode#<idx>` otherwise (legacy
   degrade). One-time localStorage migration stamped `_v: 2` — ownership
   preserved, unresolved keys dropped with a console note, no
   down-migration ever.
4. OPERATOR_GUIDE: the sidecar (what it is, don't delete it, travels with
   the config) and the §3.4 caveat — after this ships, each project's FIRST
   rid rebuild must use unchanged data so legacy marks migrate correctly.

Done means: §5 tests all present and passing, full R + JS suites green,
review doc updated (I20 moves from OPEN to FIXED), guide updated.

---

## Job B — M8 / M9 / M11: three silent failures, one contained batch — **DONE (2026-08-06)**

All three fixed with the rider, each proved to fail against the pre-fix code
first. R suite 3,602 pass / 0 fail / 0 warn / 0 skip; all 28 JS suites green.
The M9 diagnosis needed correcting — see `PRODUCTION_REVIEW.md`'s batch table:
the `significance_min_base` half was already closed by I11, and the dashboard
settings were silently taking the *default*, not going NA. Two things found on
the way and deliberately left alone:

- `examples/tabs/basic/tabs_config.xlsx` does not load at all — its Settings
  sheet has no `Setting`/`Value` headers, so it refuses with
  `CFG_INVALID_STRUCTURE` before any of this batch's validation runs. A shipped
  example that cannot be run. Unrelated to M8/M9/M11.
- A counts-only config (`show_percent_column = N`) puts the raw frequency into
  the v2 island's `pct` field, because `build_dl_question`'s `primary_stat`
  falls back to Frequency. Pre-existing, unchanged by M8, and worth its own
  look — the renderer labels that value as a percentage.

The rest of this section is the original brief.



These need no design decisions. For each: reproduce with a failing test
first, then fix.

- **M8** (`standard_processor.R:225`): Excel proportion sig letters silently
  vanish when `show_percent_column = N`. The letters must not depend on a
  display toggle — when the percent column is hidden they should attach to
  the row that still shows (read the surrounding writer code and pick the
  row deliberately; say which in the commit).
- **M9** (`type_utils.R:94-97`, `data_layer_writer.R:144,722`): a junk
  `significance_min_base` becomes a silent NA → island
  `low_base_threshold: null` → every low-base ⚠ flag silently gone in v2.
  The same silent-NA path drops dashboard questions on junk
  `dashboard_scale_*` / `gauge_*`. Fix by the established config-contract
  pattern (junk statistical settings refuse at load, naming the cell — see
  `test_config_contract.R` and the batch that built it), not by patching
  the downstream reads.
- **M11** (`20_data.js:180-188`): a Selection Category named
  `constructor` / `toString` / `valueOf` crashes the v2 boot — plain-object
  membership test hits inherited properties. Null-prototype object or an
  own-property check; add the poison-name fixture to the JS suite.
- **Optional rider** (noted by the review, one line):
  `test_audit_stats_fixes.R`'s own `source()` list omits `report_shared.R`,
  so the file only runs under `tools/run_all_tests.R` and not via the
  `testthat::test_file()` call its header documents. Add the missing
  `source()` so the documented invocation works.

Done means: three failing-first regression tests in, suites green, review
doc's MINOR section annotated FIXED with a one-line what-changed each.
