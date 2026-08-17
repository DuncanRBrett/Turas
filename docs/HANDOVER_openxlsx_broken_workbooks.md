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
