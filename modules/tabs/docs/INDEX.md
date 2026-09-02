# Tabs documentation. Index

**Maintained:** 2026-08-21

This folder holds three different kinds of document, and telling them apart
matters: a plan reads like a promise, and several of these plans describe work
that shipped months ago. Start here rather than opening files at random.

## 1. Start here (current, maintained)

| Doc | Read it for |
|-----|-------------|
| [`../README.md`](../README.md) | What the module does, quick start, **how to run the tests** |
| [`01_README.md`](01_README.md) | Overview (overlaps ../README.md, see the caveat below) |
| [`02_TABS_OVERVIEW.md`](02_TABS_OVERVIEW.md) | What the module produces, conceptually |
| [`03_REFERENCE_GUIDE.md`](03_REFERENCE_GUIDE.md) | Feature reference |
| [`04_USER_MANUAL.md`](04_USER_MANUAL.md) | Running a project end to end |
| [`06_TEMPLATE_REFERENCE.md`](06_TEMPLATE_REFERENCE.md) | Every config sheet and setting, field by field |
| [`07_EXAMPLE_WORKFLOWS.md`](07_EXAMPLE_WORKFLOWS.md) | Worked examples |
| [`09_COLOUR_REFERENCE.md`](09_COLOUR_REFERENCE.md) | Palette reference |
| [`11_DATA_CENTRIC_REPORT_V2.md`](11_DATA_CENTRIC_REPORT_V2.md) | The interactive report: architecture, data island, authored text. **The most accurate doc in the set** |
| [`AGGREGATE_TRACKING_GUIDE.md`](AGGREGATE_TRACKING_GUIDE.md) | Bringing historical waves in as aggregates |
| [`AI_INSIGHTS_USER_GUIDE.md`](AI_INSIGHTS_USER_GUIDE.md) / [`AI_PROMPT_TUNING_GUIDE.md`](AI_PROMPT_TUNING_GUIDE.md) | The AI layer |
| [`PATTERNS_KEY_SHARE_GUIDE.md`](PATTERNS_KEY_SHARE_GUIDE.md) | Configuring Pattern Recognition |

**Caveat on `05_TECHNICAL_DOCS.md`:** partially corrected on 2026-08-21 but
still the least reliable document here. It describes a pre-refactor
architecture in places. Never brief a working session from it alone; trust the
source files. Its Testing and Dependencies sections and its phantom-file
references were fixed; its line counts are explicitly not maintained.

**Caveat on the two READMEs:** `../README.md` and `01_README.md` overlap and
have drifted apart. `../README.md` is the one being maintained.

## 2. Review records (what was found and fixed, historical)

Read these to understand *why* something is the way it is. They are dated
snapshots, not current state.

- [`PRODUCTION_REVIEW_2026-08-21.md`](PRODUCTION_REVIEW_2026-08-21.md): the most recent full review (11 independent reviewers). **Read this first when picking the module back up.**
- [`GROWTH_PATH_2026-08-21.md`](GROWTH_PATH_2026-08-21.md): where the module can go next, ordered.
- `PRODUCTION_AUDIT_2026-07-02.md`, `PRODUCTION_REVIEW_BRIEF_2026-06-30.md`, `FINAL_REVIEW_*.md`. Earlier rounds.
- `audit_2026-07-02_findings.json`. Machine output from that audit, not prose.

## 3. Design records for work that HAS shipped

These are titled "PLAN" or "SPEC" but describe delivered features. They explain
the reasoning behind a design; they are not a to-do list.

- `COMMENT_HUBS_PLAN.md`. Hubs are live in the renderer.
- `QUALITATIVE_TAB_PLAN.md`. The qual layer is in production.
- `SEGMENT_WAVE_TRENDS_PLAN.md`. Segment wave trends exist with tests.
- `COMPOSITE_BANNER_HANDOVER.md`, `EXECUTIVE_TAKEOUT_PLAN.md`,
  `PATTERN_RECOGNITION*.md`, `PPTX_BOARDROOM_SPEC.md`,
  `FINITE_POPULATION_CORRECTION_PLAN.md`. Check each file's own Status line,
  and verify against the code before treating any as open work.

## 4. Genuinely open plans

- `OPEN_END_CODING_PLAN.md`. Verbatim coding; no code yet.
- `GRID_SUPPORT_SPEC.md`. Grid question support; check the Status line.
- `COMMENT_ATTRIBUTES_PLAN.md`. Partially delivered; see its Status line.

## Conventions for adding a doc here

1. Put a `**Status:**` line in the first five lines of every plan, spec or
   handover, and **update it when the work lands**. A stale "not built" on
   shipped code is the single most misleading thing in this folder.
2. Number a doc (`NN_NAME.md`) only if it is a maintained user-facing guide.
3. Add it to the right bucket above in the same commit.
4. When a doc records a review, date it in the filename.
