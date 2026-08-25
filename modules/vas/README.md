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
| `vas_report_labels.xlsx` | the question text a reader should see, where the survey's own wording or the dictionary's description is not it |
| `vas_turas_*.R` + `vas_turas_columns.csv` | the Turas dataset, structure and config |
| `docs/` | the calculation reference and the dataset plan |
| `tests/testthat/` | 458 assertions — `testthat::test_dir("tests/testthat")` |

## Rewording a question for the report

Two different labels reach the crosstab, and neither was written for a reader.
An asked question carries its Alchemer title, phrased for the respondent. A
derived column carries its dictionary description, phrased for documentation.

`vas_report_labels.xlsx` has the last word. Two columns — `question_code` and
`question_text` — one row per question you want to reword, on the first sheet.
Any other column is ignored, so the `note` column beside them is free to use for
recording why a wording was chosen. It is applied when the structure workbook is
built, so it survives every rebuild; hand-editing the generated
`VAS_Survey_Structure.xlsx` does not, because the next data build overwrites it.

It ships with the nine demographics and the three prepaid-electricity questions
already relabelled. Add a row for anything else.

A code that matches nothing in the study **stops the build** and names the
offending code. A typo that silently did nothing would be worse: the run would
succeed, the label would not change, and there would be no reason to look at the
file.

For wording that should change for *every* category — the derived families like
`_Total_TxnPerMonth` — edit the description templates in
`vas_data_dictionary.R` / `vas_data_dictionary_headline.R` instead. One edit
there covers all 33 categories; the labels file is for the exceptions.

## The three money constructions — every reporting surface picks one

Settled 25 Aug 2026 after the same fault shipped three times (the wallet
page, its spend column, then the dashboard): different surfaces averaging
the same data on different bases, R290 on one page against R294 on the
next. Any page, table or column that shows a money figure uses exactly one
of these, and says which:

1. **Per buyer** — the monthly spend of every buyer with a COMPLETE amount,
   summed, divided by the number of those buyers. A don't-know is left out,
   never counted as a zero.
2. **Per adult** — every KNOWN rand (a known side counts past a don't-know
   on the other side), divided by everyone in the study. The summing
   construction: category rows on this base add up to the wallet.
3. **Per transaction** — total rand ÷ total transactions, paired over
   buyers with both known. The average TRANSACTION, and the construction
   the restated earlier waves use. The average buyer's own `_SpendPerTxn`
   is a different number: it belongs in a crosstab row under its own label,
   never as a page's headline.

Related engine rule: `submonthly_amount_is_per_occasion` (default TRUE) —
a buyer on a sub-monthly rhythm is read as reporting the cost of ONE
purchase, so per-transaction is the amount itself and monthly spend is the
amount spread over their year, which is also how the 2024 wave derived it.

The project-side statement of the same rule, with the worked example, is
"The three money constructions" in the study's
`Reporting/HOW TO UPDATE THE REPORTING.md`.

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
