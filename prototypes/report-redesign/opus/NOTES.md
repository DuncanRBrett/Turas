# Opus prototype — self-check

`index.html` — one self-contained file. View it at `http://localhost:8774` (preview config
`report-prototype`) or just open the file in any browser. All content renders from the embedded
`#report-data` JSON; swap that island for another project's data and it regenerates unchanged.

## Acceptance criteria (SPEC §5)

| # | Criterion        | Status        | Evidence / caveat                                                                 |
|---|------------------|---------------|-----------------------------------------------------------------------------------|
| 1 | Smaller          | ✓ (architecture) | 24 KB with synthetic 4-question data. Scales with the **data**, not marked-up cells. A like-for-like vs the 7 MB SACAP report needs SACAP-scale data fed in — not done yet. |
| 2 | Self-contained   | ✓             | 0 external http(s) fetches; 0 CDN/link/script-src/import/fetch (grep-verified).    |
| 3 | Offline          | ✓             | Follows from #2 — no network needed.                                               |
| 4 | Any modern browser | ◑           | Vanilla JS + standard APIs; rendered clean in the preview (Chromium). Not yet opened in Safari/Firefox specifically. |
| 5 | Cross-question   | ✓             | Composer renders the mean-trend + latest-distribution **linked** view from data (verified live). Generic side-by-side for other pairings. |
| 6 | Native export    | ◑ implemented | "Copy" writes `text/html` → pastes into PowerPoint as an editable object, not an image. PNG export renders the SVG. Round-trip into actual PowerPoint not yet verified. |
| 7 | Generic          | ✓             | Renderer reads only from `#report-data`; no per-project code.                      |
| 8 | Robust           | ✓             | Charts wrapped in try/catch (table still shows on failure); no console errors.     |

## What it demonstrates re: the headwinds
- **Cross-question visualisation** — solved by the data layer: any question's series can be
  composed; the trend + distribution pairing is the wired example.
- **Native (not screenshot) export** — `text/html` clipboard is the leanest native path, zero
  library weight. Full `.pptx` (Tier B/C) would build the same native objects via PptxGenJS / officer.

## Not in this prototype (belongs in the live build)
- Real Tier B (`.pptx` download via PptxGenJS-from-data) and Tier C (officer + branded template).
- The data-layer **generator** in the tabs module — this hand-wrote the JSON; the real work emits
  it from R.
- Full significance / weighting / NPS engines — illustrative here.
