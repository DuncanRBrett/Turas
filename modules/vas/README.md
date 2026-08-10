# VAS derived engine

The calculation engine behind the Electrum VAS study: it reads an Alchemer
export (or the live survey), derives transactions and spend per category from
the frequency cascade and the amount questions, and builds the Turas dataset,
survey structure and crosstab config that the tabs module then reports on.

It lived in `~/Dev/alchemer-gps-capture` until 2026-08-08 — outside version
control, which is why it moved here.

## Running it

Nothing in this module is run directly. The entry points are the launchers in
the project folder on OneDrive (`Electrum/VAS 2026/`), which set
`VAS_CODE_DIR` to this directory and call `load_vas_library()`:

- `Fieldwork/run_vas_fieldwork.R` — derived numbers + report register
- `Reporting/run_vas_turas_reporting.R` — the Turas dataset
- `Reporting/build_vas_reporting_layer.py`, `build_vas_reporting_config.py`
- `Fieldwork/build_vas_field_report.py`

`vas_pipeline.R` defines `VAS_LIBRARY_FILES`, the load order, and
`load_vas_library()`. Add a file to that vector or it will never be sourced.

## What is where

| | |
|---|---|
| `vas_pipeline.R` | the loader and the file manifest |
| `vas_read_source.R` | export / API reading; aliases are the export headers, checkboxes are `"<option>:<alias>"` |
| `vas_frequency.R` | the Freq1 cascade to transactions a month |
| `vas_amount_parser.R` | amount answers, including the don't-know rule |
| `vas_derive_category.R` | one category, one base (Own / Oth) |
| `vas_derive.R` | Own + Oth into Total, the wallet totals, the published columns |
| `vas_category_map.csv` | one row per category and base — what to read and how |
| `vas_report_labels.csv` | the question text a reader should see, where the survey's own wording or the dictionary's description is not it |
| `vas_turas_*.R` + `vas_turas_columns.csv` | the Turas dataset, structure and config |
| `docs/` | the calculation reference and the dataset plan |
| `tests/testthat/` | 458 assertions — `testthat::test_dir("tests/testthat")` |

## Rewording a question for the report

Two different labels reach the crosstab, and neither was written for a reader.
An asked question carries its Alchemer title, phrased for the respondent. A
derived column carries its dictionary description, phrased for documentation.

`vas_report_labels.csv` has the last word. Two columns — `question_code` and
`question_text` — one row per question you want to reword. It is applied when
the structure workbook is built, so it survives every rebuild; hand-editing the
generated `VAS_Survey_Structure.xlsx` does not, because the next data build
overwrites it.

A code that matches nothing in the study **stops the build** and names the
offending code. A typo that silently did nothing would be worse: the run would
succeed, the label would not change, and there would be no reason to look at the
file.

For wording that should change for *every* category — the derived families like
`_Total_TxnPerMonth` — edit the description templates in
`vas_data_dictionary.R` / `vas_data_dictionary_headline.R` instead. One edit
there covers all 33 categories; the labels file is for the exceptions.

## Things that will catch you

- **The category map is the contract.** `presence_alias` / `presence_option`
  make the survey's own screener decide who is a buyer. The option wording is
  NOT uniform: prepaid electricity says "Your own household" where airtime,
  data and vouchers say "Myself". Check the export headers before editing.
- **A don't-know amount is not a zero.** The respondent stays a buyer and keeps
  their transactions, but leaves the amount means and medians. That blanking
  happens in `build_category_columns()`, deliberately *not* in
  `combine_bases_to_total()` — the wallet totals are built from what is present.
- **Survey snapshots are project data**, not code: they live in
  `Electrum/VAS 2026/Survey/Snapshots/` and only the "api" reader needs them.
