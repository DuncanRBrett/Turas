# Vendored v2 renderer assets (segment)

`js/*.js`, `styles.css` and `template.html` here are a **vendored copy** of the
data-centric report v2 engine, copied from
`modules/tabs/lib/html_report_v2/assets/` (itself vendored from
`prototypes/report-redesign/fable/`, the canonical source of truth). Copied
2026-06-15 for the segment v2 build (`feature/segment-report-v2`).

## Why a copy

Per the build plan (`../PLAN.md`, "vendor-then-extract"): segment runs on its own
copy of the generic engine first. Once segment — and ideally one more module —
have proven what is genuinely generic, the shared core is extracted into one
shared platform module (Phase 6) and these copies are replaced by a dependency
on it. Drawing the abstraction boundary from two real consumers beats guessing it
from one.

## Keep in sync

Until that extraction, treat `modules/tabs/lib/html_report_v2/assets/` as the
lead copy. If the engine changes there (or in the prototype), re-copy here. A
0-drift check should diff segment's `js/` against the tabs copy (the tabs build
already gates 0-drift against the prototype).

## Do not hand-edit

These are the shared engine. Segment-specific behaviour belongs in segment's own
modules layered on top (and ultimately in the extracted platform's extension
points), **not** in forks of these files — forking here is exactly the drift the
extraction phase exists to prevent.

## What's wired today

`../data_layer_writer.R` maps the segment profile onto the engine's `agg`
contract (segments → banner columns, profile variables → mean-row questions);
`../build_report_v2.R` inlines these assets + the data island into a
self-contained `*_report_v2.html`. This first cut renders the profile through the
existing (crosstab-flavoured) Dashboard/Crosstabs views; segment-native views are
the next phase.
