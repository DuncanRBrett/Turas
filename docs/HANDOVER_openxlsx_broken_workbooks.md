# HANDOVER — every Excel workbook Turas writes is one Excel offers to repair

**Written 2026-08-16 by the session that found it. For a fresh session to fix.**
**Do the work on a new branch: `fix/openxlsx-dangling-parts`.**

Duncan's words: *"we've not had this issue before - but clearly needs an urgent
fix."* He is right that it is new to him — the symptom only surfaced now because
he opened a config workbook in Excel. The defect is old and it is in every
deliverable.

---

## 1. The symptom

Open a Turas-generated `.xlsx` in Excel. Excel reports that it found a problem
with some content and offers to repair the file. Clicking through works, but
**repairing strips every data-validation dropdown**, and a client seeing that
prompt on a deliverable is the bad outcome.

Duncan hit it on `Reporting Data/VAS_Crosstab_Config.xlsx` and
`VAS_Survey_Structure.xlsx` in the Electrum VAS 2026 project.

## 2. What is actually wrong

**Every worksheet carries a relationship to a drawing part that does not exist
in the archive.** `xl/worksheets/_rels/sheetN.xml.rels` points at
`../drawings/drawingN.xml` and `../drawings/vmlDrawingN.vml`; neither part is
written. `[Content_Types].xml` then declares overrides for the same absent
parts. A relationship to a missing part is a hard OPC error.

No sheet's XML actually references a drawing (`<drawing>` / `<legacyDrawing>`
are absent from every worksheet), so nothing is lost by removing the references.

**`openxlsx::saveWorkbook()` writes them, on every save, whether or not the
workbook has drawings.** Proved by round-tripping an already-clean file:

```
before (repaired)      dangling=0  phantom=0
after openxlsx save    dangling=12 phantom=6
```

So this is not a one-off to clean up. Anything that saves an openxlsx workbook
reintroduces it.

## 3. How wide it is — measured, not assumed

Every crosstab deliverable in Duncan's project folders, checked 16 Aug:

| deliverable | dangling refs | phantom overrides |
|----|----|----|
| ASSA Annuity Puzzle | 12 | 6 |
| CCPB CSAT W2026 | 14 | 7 |
| CCPB CCS W2026_01 | 10 | 5 |
| CCPB CCS W2025_02 | 10 | 5 |
| IPK (3 outputs) | 10 each | 5 each |
| SACS 2023, SACS 2024 | 8 each | 4 each |
| OML demo | 12 | 6 |
| Electrum VAS 2026 | 10 | 5 |

One dangling relationship pair and one content-type override per worksheet.
It is the engine, not any project.

## 4. Do not be misled by these

- **It is NOT the collapsed `<dimension ref="A1"/>`.** openxlsx writes that too
  and it is a separate, milder wart (it also makes `openpyxl`'s read-only mode
  report a sheet as 1 row). Fixing the dimension alone will not stop Excel
  complaining.
- **`pd.read_excel()` succeeding is NOT evidence the file is sound.** Pandas
  uses read-only mode, which skips images, so it never resolves the broken
  relationship. `openpyxl.load_workbook()` FAILS outright with
  `KeyError: "There is no item named 'xl/drawings/drawing1.xml' in the archive"`.
  **Use that as the cheap regression test.**
- **R reads these files fine.** openxlsx does not resolve the relationship
  either. Every Turas test suite passes today with the defect present.
- Duncan's `_clean` copies of the VAS workbooks are the fingerprint: Excel
  repaired and saved them, and they have zero dangling refs **and zero
  validations**.

## 5. Where the fix goes

75 `saveWorkbook` call sites across `modules/`, of which only **21** go through
the shared helper `modules/shared/lib/turas_save_workbook_atomic.R`; **68** call
`openxlsx::saveWorkbook` directly. The tabs crosstab deliverable itself DOES go
through the helper — `modules/tabs/lib/crosstabs/workbook_builder.R:591`.

**Recommended approach: fix it once, in the shared helper, then route the rest.**

1. Add a `turas_repair_workbook_xml(path)` to `modules/shared/lib/` that opens
   the saved `.xlsx` as a zip and rewrites it, dropping relationships whose
   target part is absent and `[Content_Types].xml` overrides for absent parts,
   and setting a real `<dimension>`. Call it at the end of
   `turas_save_workbook_atomic()`, after the atomic rename.
2. That immediately fixes the tabs crosstab deliverable (via
   `workbook_builder.R`) and the other 20 helper call sites.
3. Then convert the direct `openxlsx::saveWorkbook` call sites module by module.
   Prioritise anything a CLIENT opens: `modules/tabs`, `modules/tracker`
   (`tracking_crosstab_excel.R`, `tracker_dashboard_reports.R`),
   `modules/segment/R/09_output.R`, `modules/maxdiff/R/09_output.R`,
   `modules/keydriver/R/04_output.R`, `modules/brand`, `modules/AlchemerParser`.
   The `generate_config_templates.R` files in tabs / tracker / weighting / brand
   write the templates Duncan hands people, so they matter too.

**A working implementation already exists to copy from**, in Python, tested on
real files:
`Electrum/VAS 2026/Reporting/repair_workbook_validations.py` (OneDrive). Port
the `drop_dangling()` logic. It also merges duplicate `<ext>` blocks — that part
is a VAS-specific artefact of a config pour and is **not** needed in the engine.

### Two traps that bit while writing that script

- Splitting the `.rels` XML on `"<Relationship"` also matches the container
  `<Relationships ...>` and throws the opening tag away, producing a document
  no parser will read. Rewrite the children inside the container instead.
- `<row ...>.*?</row>` stops at the first `/>` when a row holds self-closing
  `<c .../>` cells. Only relevant if you touch sheet rows; the relationship fix
  does not need to.

## 6. What "done" looks like

- [ ] A generated workbook opens in `openpyxl.load_workbook()` (not read-only)
      without raising.
- [ ] Zero relationships resolving to a part absent from the archive; zero
      `[Content_Types].xml` overrides for absent parts.
- [ ] Data validations survive — count `<dataValidation>` and
      `<x14:dataValidation>` before and after and assert they match. This is the
      thing Excel's own repair destroys, so a fix that loses them is worse than
      the bug.
- [ ] Every cell value unchanged. Compare at the XML level, or with
      `openxlsx::read.xlsx` sheet by sheet.
- [ ] The file opens in LibreOffice headless
      (`soffice --headless --convert-to csv`) without error.
- [ ] A new test that generates a workbook through the real writer and asserts
      the above, so this cannot come back. Put it beside the existing tabs Excel
      tests (`modules/tabs/tests/testthat/test_excel_output.R`).
- [ ] Full suites green before and after: tabs R (`4796` passing, 0 failing as
      of 16 Aug), tabs JS (33 files), and the suites of any other module you
      touch.

## 7. Scope

**In scope:** the engine writing sound workbooks from now on.

**Out of scope unless Duncan asks:**
- Retro-fixing the deliverables already sitting in project folders. They are
  regenerated routinely; the VAS kept pair has already been repaired by hand.
- The duplicate `<ext>` merge (VAS-specific, already handled there).
- The collapsed `<dimension>` — worth fixing in the same pass because it is free
  once you are rewriting the zip, but it is not what Excel objects to.

## 8. Context worth having

- The VAS kept pair (`Reporting Data/VAS_Survey_Structure.xlsx` and
  `VAS_Crosstab_Config.xlsx`) is ALREADY repaired, and
  `relabel_categories.R` there now runs the repair after itself. Do not assume
  those two files still show the fault.
- Duncan's standing rules: no `stop()`, use TRS refusals; errors must be visible
  in the console because Turas runs under Shiny; test before claiming.
- Fieldwork on VAS 2026 is live (1,100 responses as of 16 Aug) and Duncan
  regenerates reports himself via `launch_turas()`. Do not run his pipeline.

---

# RESOLVED — branch `fix/openxlsx-dangling-parts`

**Written 2026-08-17 by the session that did the work.** The sections above are
left as they were written, because the diagnosis in them is correct and worth
keeping. This section records what was actually done, where it differs, and what
is still open.

## What the fix is, and why it is not the zip repair suggested above

`turas_reconcile_workbook_parts()` in
`modules/shared/lib/turas_save_workbook_atomic.R` fixes the **workbook object
before the save** instead of repairing the file after it.

The defect is fully visible in the openxlsx workbook object:
`wb$worksheets_rels[[i]]` always carries a drawing and a vmlDrawing
relationship, and `wb$Content_Types` always carries the drawing override, while
`wb$drawings[[i]]`, `wb$vml[[i]]` and `wb$comments[[i]]` say whether those parts
will actually be written. Making the two agree before calling `saveWorkbook()`
is strictly better than rewriting the zip afterwards:

- no XML string surgery, so both traps in section 5 above simply do not arise;
- cell values, styles and validations cannot be touched, by construction;
- it preserves the atomic write-then-rename guarantee. Repairing the final file
  in place, as section 5 suggested, would have broken the thing
  `turas_save_workbook_atomic()` exists to provide.

It reconciles rather than only dropping — it re-adds a relationship when a sheet
gains a drawing later — so it is idempotent and safe before every save,
including a second save on the same workbook object.

## A second instance of the same defect, not in the diagnosis above

`xl/sharedStrings.xml` is only written when the workbook holds shared strings,
but the relationship to it and its content-type override are seeded
unconditionally. **A workbook whose cells are entirely numeric, or which has
only an empty sheet, was broken even with every worksheet sound.** The
reconciler handles it on the same rule.

## What was routed

58 production call sites across 17 modules now call `turas_saveWorkbook()`,
which reconciles and then saves.

- Files designed to be sourced on their own — every
  `generate_config_templates.R`, and the standalone tools — locate the shared
  helper themselves rather than assuming the caller loaded it.
- VAS resolves it from its own code directory in `load_vas_library()`, not from
  the working directory, because the fieldwork launcher runs from the project
  folder rather than the repo.
- Tests, examples and fixtures were deliberately left alone.

**A trap worth knowing about.** Many writers already guarded with
`exists("turas_save_workbook_atomic", mode = "function")` and fell back to a
direct save. That branch runs precisely when the shared file is *not* loaded, so
`turas_saveWorkbook()` does not exist there either — it lives in the same file.
Routing those branches turned a working fallback into an error that the
surrounding `tryCatch` swallowed, so the workbook was silently never written.
`test_stats_pack_writer.R` caught it with 11 failures. Those 18 fallbacks were
put back to `openxlsx::saveWorkbook()` and now print a console warning that the
file is being written without reconciliation.

## Verification

- `turas_check_workbook_parts(path)` asserts the invariant at the **zip level** —
  every relationship Target and every `[Content_Types].xml` override resolves to
  a part present in the archive. It is independent of how the file was written,
  so it keeps its meaning if openxlsx changes.
- Regression tests: `modules/shared/tests/testthat/test_workbook_parts.R` and
  three tests through the real tabs writer in
  `modules/tabs/tests/testthat/test_workbook_builder.R`.
- Real templates generated through the real generators:
  `Crosstab_Config.xlsx` keeps all **75** `dataValidation` elements and
  `Survey_Structure.xlsx` all **12**; both now open in
  `openpyxl.load_workbook()` (not read-only) and convert under
  `soffice --headless`.

## Still open

- **The dimension.** Deliberately untouched. It is not free once you are fixing
  the workbook object rather than the zip, and it is not what Excel objects to.
  See section 7 above.
- **Cell comments.** `openpyxl.load_workbook()` still fails on a workbook that
  carries an openxlsx cell comment, for an unrelated reason in openxlsx's
  comment font XML. No production Turas writer writes cell comments, so no
  deliverable is affected. Not investigated further.
- **The live VAS launcher path was not exercised.** The VAS suite passes and the
  path resolution is derived from `code_dir` the way VAS resolves everything
  else, but nobody has run Duncan's OneDrive launcher against it. Worth one run
  before the next fieldwork day.
- **Retro-fixing existing deliverables** remains out of scope, as section 7 says.
