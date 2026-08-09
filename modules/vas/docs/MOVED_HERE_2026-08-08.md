# Where this module came from, and how to put it back

On 2026-08-08 the VAS code was split out of `~/Dev/alchemer-gps-capture`, which
had grown to hold four unrelated projects and was not under version control.
This note exists so a revert never depends on remembering the conversation.

## What moved where

| From `~/Dev/alchemer-gps-capture` | To |
|---|---|
| the 12 `VAS_LIBRARY_FILES`, `vas_pipeline.R`, the three `vas_turas_*.R`, `build_category_map.R`, `vas_category_map.csv`, `vas_turas_columns.csv`, `tests/` | `Dev/Turas/modules/vas/` |
| `VAS_DERIVED_CALCULATIONS.md`, `VAS_DERIVED_VARIABLES_PLAN.md`, `VAS_TURAS_DATASET_PLAN.md` | `Dev/Turas/modules/vas/docs/` |
| the survey-build one-offs (probes, apply/verify, test-response generators), the VAS survey docs, `VAS_TABLET_CAPI_STYLE.css`, `output/` | `Electrum/VAS 2026/Survey/` |
| `backups/` — 37 Alchemer survey snapshots, 16MB | `Electrum/VAS 2026/Survey/Snapshots/` |
| `assa/` — 25 files | `TurasProjects/ASSA/Survey build/` |
| everything else — the GPS capture JS, the Python supervisor reports, the setup docs | stayed put |

## What was edited, not moved

Six live entry points had the code path hard-coded. All now point at
`/Users/duncan/Dev/Turas/modules/vas`:

- `VAS 2026/Fieldwork/run_vas_fieldwork.R` — also gained `VAS_SNAPSHOT_DIR`,
  because it globbed `VAS_CODE_DIR/backups/survey_*_index.csv` for the "api"
  reader and the snapshots did not come to the repo
- `VAS 2026/Reporting/run_vas_turas_reporting.R`
- `VAS 2026/Reporting/build_vas_reporting_layer.py`
- `VAS 2026/Reporting/build_vas_reporting_config.py`
- `VAS 2026/Fieldwork/build_vas_field_report.py`
- plus two docs (`MONTHLY_WALLET.md`, `HOW TO UPDATE THE REPORTING.md`) and two
  superseded scripts (`build_vas_report_mockup.R`, `build_vas_category_summary.R`)

Thirty scripts in `VAS 2026/Survey/` had relative `source("vas_pipeline.R")` /
`source("alchemer_survey_tools.R")` calls rewritten to absolute module paths,
and 13 ASSA scripts had their self-references and their `alchemer_survey_tools.R`
source rewritten.

## How to put it back

The originals were deleted, not archived — but they are in **Time Machine**.
The local APFS snapshot `com.apple.TimeMachine.2026-08-08-014958.local` was
taken at 01:49, and the move happened at 06:02, so it holds the folder complete
including the 7 August engine fixes. The `TimeMacMini` destination has it too.

1. Restore `~/Dev/alchemer-gps-capture` from that snapshot (Finder → Enter Time
   Machine, or `tmutil restore`).
2. In the six entry points above, set the path back to
   `/Users/duncan/Dev/alchemer-gps-capture`; in `run_vas_fieldwork.R` also drop
   `VAS_SNAPSHOT_DIR` and restore the `VAS_CODE_DIR/backups` glob.
3. Delete `modules/vas`, `VAS 2026/Survey/`, `ASSA/Survey build/`.

## Verified at the time of the move

- 458 tests pass from the new location
- `load_vas_library()` loads, the category map reads (52 rows, 22 with a
  screener), the Turas builders source, the column-plan contract is present
- all 12 survey-index snapshots resolve at the new `VAS_SNAPSHOT_DIR`
- all 74 R files across the three destinations parse; no empty files
- zero references to `alchemer-gps-capture` remain anywhere in `VAS 2026`

**Not verified:** the pipeline end to end. The next
`Run VAS Reporting Data.command` is the real test.
