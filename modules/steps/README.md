# Project Steps

**Status:** Phase 1 (Opus, 2026-08-11). Plan: [`docs/RUN_EVERYTHING_FROM_TURAS_PLAN.md`](../../docs/RUN_EVERYTHING_FROM_TURAS_PLAN.md).
Policy: [`docs/REPORT_GENERATION_METHOD.md`](../../docs/REPORT_GENERATION_METHOD.md).

Some steps in producing a deliverable are not analytical modules — the comment-appendix
builder is the clearest case. Before this module they ran as terminal commands, which meant
they were documented only in Duncan's head and were exactly the steps that tempt an AI
session into running the pipeline itself.

This module gives them a tile. The GUI reads a **manifest** describing each tool, renders a
form from it, runs the tool with its output streaming into the page, and turns a non-zero
exit code into a TRS refusal instead of a silent failure. The tool's language does not
matter — Python, R, anything on PATH. The launch surface does.

## What is here

| File | What it does |
|------|--------------|
| `run_steps_gui.R` | The Shiny GUI. Returns a `shiny.appobj` — the launcher calls `run_steps_gui()` then `runApp()` on the result. |
| `lib/registry.R` | Manifest definitions and their validation. |
| `lib/run_tool.R` | Command construction, the environment guard, process execution, exit-code mapping. |
| `lib/runbook.R` | Reading, validating and creating the per-project runbook; the sidecar last-run state. |
| `tests/testthat/` | The suite. Everything except the rendered page is covered. |

Tools stay where they live (`scripts/`, later `custom/<client>/`); the registry only points
at them.

## Registering a tool

Add a manifest to `steps_builtin_manifests()` in `lib/registry.R`. The field reference is at
the top of that file. A minimal one:

```r
list(
  id          = "my_tool",
  name        = "My tool",
  description = "One line, shown under the name",
  runtime     = "python3",
  entry       = "scripts/my_tool.py",     # relative to TURAS_ROOT
  requires    = c("openpyxl"),            # importable modules
  docs        = "scripts/README_my_tool.md",
  args = list(
    list(id = "data", label = "Data file", type = "file",
         required = TRUE, cli = "--data")
  )
)
```

Argument types: `file`, `dir`, `text`, `choice`, `flag`, `flag_value`. Two of them earn their
keep on the comment appendix and are worth knowing:

- **`flag_value`** always emits its switch, and appends a value when one is given. It exists
  for switches like `--report-changes`, whose value is optional and whose presence selects the
  tool's mode. Put it **last** in the manifest — nothing may follow an optional-value switch
  on the command line.
- **`exclusive = "<group>"`** marks arguments that cannot both be set (`--columns-file` and
  `--pattern`). Setting both refuses before the tool runs, naming both fields, rather than
  letting the tool exit with an argument-parser error.

Set `must_exist = FALSE` on a `file` argument that names an output the tool creates.

Manifests are validated on startup: a missing field, an unknown type, a duplicate id or a
`cli` that is not a switch refuses and names the offender.

## The comment-appendix trio

Three manifests wrap `scripts/build_comment_appendix.py` — build/update, report changed
comments, apply approved changes. See [`scripts/README_comment_appendix.md`](../../scripts/README_comment_appendix.md)
for what the script does and [`modules/tabs/docs/QUAL_COMMENT_APPENDIX_GUIDE.md`](../tabs/docs/QUAL_COMMENT_APPENDIX_GUIDE.md)
for the end-to-end workflow.

Two things about them that are easy to get wrong, both covered by tests:

1. **All three modes carry the column-resolution arguments.** The script resolves the comment
   columns *before* it dispatches on mode, so a review mode without `--columns-file` /
   `--pattern` would silently fall back to the default name pattern and review a different set
   of sheets. On a survey like CCPB (39 named comment columns) that would quietly miss most of
   them.
2. **`--dry-run` is offered on the build mode only.** The script checks it after the mode
   dispatch, so it does nothing in the two review modes. Showing the checkbox there would be a
   lie.

The manifests deliberately expose a subset of the script's flags: `--data`, `--appendix`,
`--columns-file`, `--pattern`, `--dry-run`, `--report-changes`, `--apply-changes`. Not
exposed: `--columns`, `--structure`, `--auto`, `--yes`, `--id-header`, `--no-backup`. Those
stay terminal-only until there is a reason to surface them; `--auto` in particular needs its
printed picks eyeballed before it writes.

## The runbook

A runbook is one workbook per project — `<Project> Runbook.xlsx`, living in the project
folder — recording the ordered steps that produce the deliverable. It is the answer to "how
was this made?", including for the steps no button can run.

Sheet **`Steps`**, one row per step: `Order`, `Step` (plain words — this is the
documentation), `Type`, `Tool`, `Notes`, and any number of `arg:<id>` columns supplying that
tool's arguments. Sheet **`Provenance`**, parameter/value: which AI features were on and
where the client's approval or restriction lives. Sheet **`Guide`**, written by the template
generator, explaining both.

Four step types:

| Type | Means |
|------|-------|
| `module` | A Turas module run from its own tile. |
| `tool` | Runs from this tile. The `Tool` cell must name a registered id, or the runbook refuses naming the row. |
| `ai-assisted` | Analyst-supervised AI — AI proposes, a person checks every output. Never recorded as "manual". |
| `manual` | A genuinely human step. Listed so the sequence is complete. |

In the GUI: open a runbook, and the steps render as a checklist in order. **Open** on a tool
row loads that step's arguments into the form — you still press RUN STEP, so a single click
never starts something that writes files. **Mark done** on any other row records that you did
it. Outcomes go to a sidecar `.<name>_runbook_state.rds` beside the workbook; the workbook
itself is the analyst's and is never written to. Last-used arguments beat the runbook's on
the next open, so a corrected path sticks without editing Excel.

**Not a pipeline engine.** No dependency resolution, no auto-sequencing, no "run all". The
work between steps — coding, checking, calling respondents — is the point, not an edge case.

Three runbooks exist today, seeded 11 August 2026 from each project's own documents: ASSA
(22 steps), Electrum VAS 2026 (10, mapped onto `Reporting/00 VAS REPORTING CONTROL.md`) and
SACAP SACS 2026 (16, prospective — that wave has not launched). They live in the project
folders, not in this repo.

## How a tool is run

1. **Validate** the manifest, then build the command. Blank required fields, missing files,
   conflicting exclusive arguments and out-of-range choices all refuse here, before anything
   starts.
2. **Guard the environment.** The runtime must be on PATH and each `requires` module must
   import. Failure is `PKG_RUNTIME_MISSING` naming what is absent, with the fix
   (`python3 -m pip install -r scripts/requirements.txt`).
3. **Run** via `processx`, with stdout and stderr merged so the output reads in the order the
   tool produced it. The GUI polls every 300ms and appends to the page as the tool runs — a
   long fieldwork append must never look hung.
4. **Map the exit code.** Zero is PASS. Non-zero is an `IO_STEP_FAILED` refusal carrying the
   last lines of the tool's output, printed in the boxed console format *and* shown as a
   notification.

**Why `processx` rather than `system2` with inherited stdout:** the launcher starts each
module as a background `Rscript` whose stdout goes to a temp log it deletes after five
seconds (`launch_turas.R:934-945`). Console-only streaming is therefore invisible in exactly
the case that matters — a module launched from the hub. Output goes to the page, and is
`cat()`-ed as well so a directly-run session still sees it in the console. `processx` 3.8.6
is already in `renv.lock`; this adds no dependency.

## Python dependencies

`scripts/requirements.txt` pins what the Python tools need (`openpyxl`, `pandas`).

```bash
python3 -m pip install -r scripts/requirements.txt
```

Verified working on Duncan's machine (`/usr/bin/python3` 3.9.6, openpyxl 3.1.5, pandas
2.3.3) — that is this machine only.

**Docker is mothballed** (11 August 2026, when Jess left — see `Docker/DOCKER_MANUAL.md`).
Turas runs on the desktop. If a container is ever revived it will need python3 plus those
packages, or these steps will refuse with `PKG_RUNTIME_MISSING` — which is the tile working,
not a bug. The env guard is written to be runtime-agnostic either way.

## Tests

```bash
Rscript -e 'testthat::test_dir("modules/steps/tests/testthat", reporter = "summary")'
```

Covers manifest validation, command construction, the environment guard (through injected
`which`/probe functions, so both the PASS and the REFUSED paths run on any machine), process
execution and exit-code mapping (against a probe script run by the suite's own runtime), and
the comment-appendix trio end to end against a synthetic workbook in a temp folder.

The end-to-end tests skip themselves where python3 + openpyxl + pandas are absent, which
doubles as a check that the guard's PASS verdict is honest: when it says PASS, the tool
really does run.

The GUI's **server logic** is covered too, headlessly, via `shiny::testServer`: the form
rendered from a manifest, a blank required field refusing without starting a process, and a
real run streaming its output through the polling observer to a PASS. Plus the contract the
launcher depends on — `run_steps_gui()` returns a `shiny.appobj` — and the tile's
registration in `launch_turas.R`.

What that does **not** cover is the page: layout, the file pickers, whether the output reads
well while a long run is in flight. The GUI is verified by Duncan through `launch_turas()`.

The Python script keeps its own suite, untouched by this module:

```bash
python3 scripts/test_build_comment_appendix.py
```

## Known interop caveat

Workbooks written by **openxlsx** cannot be re-opened by **openpyxl** (it fails looking for
`xl/drawings/drawing1.xml`, or on a non-integer `xWindow`). `pandas.read_excel` copes, which
is why the appendix builder reads an openxlsx-written data file happily. It matters if a
Python tool is ever asked to `load_workbook` something Turas wrote — the e2e test writes its
approval mark with openpyxl for exactly this reason.

## Not in this phase

Phase 2 adds the per-project runbook (an ordered checklist read from
`<Project> Runbook.xlsx`, with Run buttons on the tool rows and a sidecar remembering
last-used arguments). Phase 3 adds `custom/<client>/` view discovery. This is deliberately
**not a pipeline engine**: no dependency resolution, no auto-sequencing, no "run all".
Human work between steps is the normal case, not an edge case.
