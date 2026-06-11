# Turas Report Re-architecture — Specification & Head-to-Head Brief

**Branch:** `feature/report-data-layer`
**Status:** prototype + spec. Touches **no** live code. The live generator is changed only
after a design is chosen — tests-first, separately.
**Read this cold:** it is the complete brief for whoever builds a prototype (Opus or Fable).
Build blind — do not look at the other model's prototype.

---

## 1. Problem

Turas HTML reports are **render-centric**: pre-rendered tables, pins captured as *images*, and
an inlined ~0.94 MB PptxGenJS library that exports each pin as a flat screenshot.

Measured on a real report (`SACAP_Student_Annual-2025_Crosstabs v2.html`, **7.0 MB**):

- **~80%** is the table grid: ~2.0 MB of `class=` attributes + ~3.6 MB of cell markup, across
  **26,500 cells** in 96 tables.
- **13%** (0.94 MB) is the PptxGenJS export library, shipped in **every** report.
- SVG charts are clean and tiny (**2.8%**) — not the problem.

Three headwinds fall out of the render-centric design:

1. **No cross-question visualisation** — you are combining *pictures*, which share no scale, axis
   or base. There is no data underneath to recompose.
2. **Exported decks are not presentation-grade** — `turas_pins_pptx.js` calls `slide.addImage()`
   with a PNG of the pin. Every slide is a screenshot: not editable, not native, not on-brand.
3. **Large files.**

## 2. Goal

A **data-centric**, self-contained report: embed the analysis data compactly, and render tables,
charts, **cross-question composites**, and exports *from that data*. Slicker, simpler, smaller,
more robust — and generic across projects.

## 3. Hard constraints (non-negotiable)

1. **Single self-contained HTML file.**
2. **Zero external dependencies** — no CDNs, no network fetches at view time. In-file vanilla JS is
   allowed and expected; no frameworks loaded from a CDN.
3. **No installations** for the recipient.
4. **Works in any modern browser** (current Chrome, Safari, Firefox, Edge).
5. **Generically reproducible** — the generator emits `{ data + one fixed renderer }` for any
   project. No per-project bespoke code.
6. **Does not regress existing functionality** — prototypes are standalone files only.

## 4. Architecture

### 4.1 Data layer
Each result embedded as compact JSON. Indicative schema:

```json
{
  "project": { "name": "...", "wave": "...", "brand_colour": "#323367" },
  "questions": [
    {
      "id": "q1",
      "title": "...",
      "type": "single | multi | numeric | scale | nps",
      "banner": ["Total", "Group A", "Group B"],
      "rows": [
        { "label": "...", "values": [/* per banner */], "bases": [/* per banner */], "sig": [/* flags */] }
      ],
      "scale": { "min": 1, "max": 5 },
      "meta": {}
    }
  ]
}
```

A small **inlined vanilla-JS renderer** builds tables + SVG charts from this. This replaces the
verbose per-cell markup.

### 4.2 Cross-question composer
In-file UI: pick **≥2** questions/series and render a combined view (e.g. mean-trend +
current-wave distribution, visually linked). Composes from the data layer. Self-contained, no deps.

### 4.3 Dual-tier export
- **Tier A — lean, default, in-file:** clipboard "paste into PowerPoint" + hi-res PNG. No
  PptxGenJS. (Both partly exist in Turas today.)
- **Tier B — in-file self-service, opt-in per project:** PptxGenJS building **native** slides from
  data (`addTable` / `addText` / `addChart`) — editable, on-brand — **not** screenshots.
  ~0.9 MB, shipped only when enabled.
- **Tier C — Turas-side, slickest:** `officer` + branded `turas_template.pptx`, native tables from
  data. Generalise the existing `modules/hub_app/lib/export_pptx.R` to any report.

The generator toggles which tiers ship per project.

## 5. Acceptance criteria (the scorecard)

| # | Criterion        | Test                                                       | Target                                   |
|---|------------------|------------------------------------------------------------|------------------------------------------|
| 1 | Smaller          | byte size for SACAP-scale data                             | materially < 7 MB (stretch: ≤ ~3 MB lean) |
| 2 | Self-contained   | no external http(s) *fetches* (xmlns identifiers excluded) | zero                                     |
| 3 | Offline          | open with the network disabled                             | renders fully                            |
| 4 | Any browser      | open in Chrome / Safari / Firefox                          | renders + interactions work              |
| 5 | Cross-question   | compose ≥2 questions into one view                         | works                                    |
| 6 | Native export    | exported slide contains an **editable** table/text         | Tier B/C                                 |
| 7 | Generic          | swap in a second project's data JSON                       | renders with no code change              |
| 8 | Robust           | core tables readable; graceful if a chart fails            | yes                                      |

## 6. Head-to-head protocol

- Identical spec → two **blind** prototypes: `prototypes/report-redesign/opus/` and `.../fable/`.
- Neither implementer sees the other's solution or the originating conversation.
- Score on §5 + design / slickness (taste) + code quality / robustness.
- Duncan picks the winner → it becomes the blueprint for the live build.

## 7. Out of scope (v1)

- Touching the live tabs generator (`modules/tabs/lib/html_report/`).
- The production migration — that follows the decision, tests-first, TRS-compliant, old path intact.

## 8. Inputs for the implementer

- **Sample report** (for sizing + structure): the SACAP crosstabs HTML, ~7 MB — Duncan to provide
  the local path.
- **Existing assets to learn from / reuse:** `modules/shared/js/turas_pins*.js`,
  `modules/shared/js/vendor/pptxgen.bundle.js`, `modules/hub_app/lib/export_pptx.R`.
- **Build ONLY** inside your `prototypes/report-redesign/<model>/` directory.
- Use a small synthetic data set (a handful of questions, a few banner cuts, one scale question
  with waves) so the prototype is self-demonstrating without the real file.
