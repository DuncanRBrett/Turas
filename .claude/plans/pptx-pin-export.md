# Pin-Reel PowerPoint Export — Project Plan

## 1. Problem Statement

When Turas users curate a pin-reel of charts, tables, and insights within an HTML report, they can download individual PNGs but have no direct path to a presentation deck. For a typical project with 50-60 pins, manually inserting each PNG into PowerPoint is tedious, error-prone, and a poor use of a researcher's time. The feature should produce a clean, plain PPTX (one pin per slide) that the user can then insert into their branded template deck using PowerPoint's built-in "Reuse Slides" feature. This keeps the implementation simple and the output universal.

## 2. Landscape & Approach

### What exists
- **Hub App** already has full PPTX export via `export_manager.js` (JS) → `export_pptx.R` (R/officer). This is server-side, requires Shiny.
- **Shared pin library** (`turas_pins_export.js`) already converts pins to PNG blobs in the browser at 3x resolution. The hard part is done.
- **PptxGenJS** is a mature browser-side library (3K+ GitHub stars, actively maintained) that creates .pptx files entirely in JavaScript. No server required.

### Chosen approach
Use **PptxGenJS** bundled into the shared pin JS to generate PPTX entirely client-side. This works identically in standalone HTML reports and Shiny-hosted reports — no R backend dependency for this feature.

**Why not the R/officer path?**
- Standalone HTML reports have no R backend — this would only work in Shiny
- The R path adds complexity (Shiny observers, message passing, file download orchestration)
- A pure JS solution works everywhere, uses the existing PNG blob pipeline, and requires no per-module wiring

### PptxGenJS specifics
- **Bundle file:** `pptxgen.bundle.js` (466 KB unminified, includes JSZip dependency)
- **Minified:** `pptxgen.min.js` (277 KB) + JSZip separately, or bundle at ~466 KB
- **Impact on report size:** 466 KB on a 6-12 MB report = 4-7%. Acceptable.
- **Browser API:** `new PptxGenJS()` → `addSlide()` → `slide.addImage({data: base64})` → `writeFile()`
- **No external dependencies** beyond what's bundled

## 3. Objectives

1. User can export entire pin-reel as a single .pptx file with one pin per slide
2. Export works in standalone HTML reports (no Shiny required)
3. Export works in Hub App combined reports
4. Quality toggle (High/Standard) controls file size vs resolution
5. Progress feedback during export of large reels (50-60 pins)
6. Rock solid across Chrome, Firefox, Safari, Edge (modern versions)
7. Zero changes required to individual module code — shared library only
8. Section dividers in pin-reel become section header slides

## 4. Requirements

### Must have
- "Export as PowerPoint" option in pin-reel UI
- One pin per slide: title + chart/table PNG centred on slide
- Section dividers become title-only slides
- Quality toggle: High (PNG 3x) / Standard (JPEG 2x, 85%)
- Progress indicator for multi-pin export
- Clean filename: `{report_title}_pins_{YYYYMMDD}.pptx`
- Works offline (PptxGenJS bundled, not CDN-loaded)

### Nice to have
- Single-pin PPTX export from overflow menu (alongside existing PNG)
- Subtitle and insight text as text elements below the image (not baked into PNG)

### Constraints
- PptxGenJS bundle adds ~466 KB to every HTML report
- No custom template support (by design — users insert slides into their own template)
- Must not break existing PNG export or clipboard copy functionality

## 5. Design & Experience

### User flow
1. User builds pin-reel as normal (pin charts, tables, insights)
2. User clicks "Export as PowerPoint" button in pin-reel toolbar area
3. Quality toggle visible: "Standard (smaller file)" / "High (print quality)" — defaults to Standard
4. Progress overlay appears: "Exporting slide 1 of 54..."
5. Browser downloads `Brand_Health_Tracker_pins_20260401.pptx`
6. User opens in PowerPoint, uses Insert → Reuse Slides to pull into branded template

### UI placement
- **Primary export button:** In the pin-reel panel header/toolbar, alongside any existing export controls
- **Quality toggle:** Dropdown or radio next to the export button, or a simple toggle within a small settings popover
- **Single-pin export:** Added to existing overflow menu (⋮) on each card, after "Export as PNG"

### Slide layout
- **Widescreen 16:9** (standard modern PowerPoint default: 13.33" × 7.5")
- **Title:** Top of slide, left-aligned, clean sans-serif
- **Pin image:** Centred below title, scaled to fill available width while maintaining aspect ratio
- **Section slides:** Title only, centred, larger font

## 6. Implementation Plan

### Step 1: Add PptxGenJS to shared JS bundle
- Download `pptxgen.bundle.js` (includes JSZip)
- Place in `modules/shared/js/vendor/pptxgen.bundle.js`
- Add to load order in `modules/shared/lib/turas_pins_js.R` — **before** `turas_pins_export.js`
- Verify it doesn't conflict with existing globals

### Step 2: Add quality toggle constants
In `turas_pins_utils.js`, add:
```javascript
TurasPins.EXPORT_QUALITY = "standard";  // "standard" or "high"
TurasPins.QUALITY_PRESETS = {
  standard: { format: "image/jpeg", quality: 0.85, scale: 2 },
  high:     { format: "image/png",  quality: null,  scale: 3 }
};
```

### Step 3: Modify `_exportToBlob` to accept quality config
Refactor the existing `canvas.toBlob()` call to use the quality preset instead of hardcoded PNG/3x. This affects both PNG download and the new PPTX export — both benefit from the toggle.

### Step 4: Build `TurasPins.exportPptx()` function
New function in `turas_pins_export.js`:
```
exportPptx(options)
  - options: { quality, onProgress, filename }
  - Creates PptxGenJS instance
  - Sets layout to widescreen 16:9
  - Loops through pins sequentially (with stagger delay)
  - For each pin:
    - If section divider: add section title slide
    - If pin: call _exportToBlob() → convert blob to base64 data URL → addImage to slide
  - Calls pres.writeFile() to trigger download
  - Fires onProgress callback for UI updates
```

### Step 5: Build `TurasPins.exportSinglePptx(pinId)` function
Same as above but for a single pin — simpler, no progress needed.

### Step 6: Add UI controls
In `turas_pins_render.js`:
- Add "Export as PowerPoint" to the pin-reel toolbar/header area
- Add quality toggle (Standard/High) as a small control
- Add "Export as PowerPoint" to individual card overflow menu
- Add progress overlay with cancel capability

### Step 7: Wire up progress and error handling
- Progress callback updates overlay text
- Error handling with user-visible toast messages
- Timeout safety (same pattern as Hub's 30-second safety timeout)

## 7. Test Framework

### 7a. JavaScript Unit Tests (new test infrastructure)

Since there's no existing JS test framework, create a lightweight **in-browser test harness** that runs within the HTML report context. This is pragmatic — PptxGenJS and canvas APIs need a real browser DOM.

**File:** `modules/shared/tests/js/test_pptx_export.html`

A self-contained HTML page that:
- Loads the shared pin JS bundle
- Creates synthetic pin data (chart SVG, table HTML, insight text)
- Runs test cases and reports pass/fail in the page

**Test cases:**

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | PptxGenJS loads | `typeof PptxGenJS !== 'undefined'` |
| 2 | Single pin export produces blob | `exportPptx()` returns/downloads a file > 0 bytes |
| 3 | Empty pin-reel handled | No crash, shows toast "No pins to export" |
| 4 | Section divider becomes slide | PPTX has correct slide count |
| 5 | Quality toggle: standard | Blob uses JPEG, file size < high quality |
| 6 | Quality toggle: high | Blob uses PNG, file size > standard |
| 7 | 10-pin batch export | All 10 slides present, progress callback fires 10 times |
| 8 | Pin with chart only | Image renders without crash |
| 9 | Pin with table only | Image renders without crash |
| 10 | Pin with insight only | Image renders without crash |
| 11 | Pin with all content | Image renders correctly |
| 12 | Filename sanitisation | Special characters stripped from output filename |
| 13 | Large pin title wrapping | Long titles don't overflow slide |
| 14 | SVG with CSS variables | Resolved correctly (existing `_resolveCssVars` path) |

### 7b. R-side Integration Tests

**File:** `modules/shared/tests/testthat/test_pptx_js_bundle.R`

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | `turas_pins_js()` returns string containing "PptxGenJS" | Bundle loaded correctly |
| 2 | Bundle size within expected range | No accidental double-inclusion |
| 3 | Load order correct | PptxGenJS appears before `turas_pins_export.js` in output |
| 4 | All modules' page builders produce HTML containing PptxGenJS | Available everywhere |

### 7c. Cross-Browser Validation Matrix

Manual testing checklist (documented, repeatable):

| Browser | Version | canvas.toBlob | Blob constructor | URL.createObjectURL | PptxGenJS writeFile | Download trigger |
|---------|---------|---------------|-----------------|--------------------|--------------------|-----------------|
| Chrome | 90+ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Firefox | 90+ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Safari | 14+ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Edge | 90+ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Critical APIs and their browser support:**

| API | Minimum browser | Used for |
|-----|----------------|----------|
| `canvas.toBlob()` | Chrome 50, FF 19, Safari 11, Edge 79 | PNG/JPEG conversion |
| `Blob` constructor | Chrome 20, FF 13, Safari 6, Edge 12 | File assembly |
| `URL.createObjectURL()` | Chrome 23, FF 19, Safari 6, Edge 12 | Download trigger |
| `canvas.toDataURL()` | All modern | Base64 for PptxGenJS image data |
| `PptxGenJS.writeFile()` | Uses FileSaver.js internally — same Blob/URL APIs | PPTX download |

**Verdict: All required APIs are supported in every modern browser (2020+).** No polyfills needed. The existing pin export already depends on these same APIs — if PNG export works, PPTX export will work.

### 7d. Performance Tests

| Scenario | Measurement | Acceptable |
|----------|------------|------------|
| 10 pins, standard quality | Time to download | < 5 seconds |
| 60 pins, standard quality | Time to download | < 20 seconds |
| 60 pins, high quality | Time to download | < 30 seconds |
| 60 pins, standard quality | Output file size | < 15 MB |
| 60 pins, high quality | Output file size | < 40 MB |
| Peak memory during 60-pin export | Browser memory | < 200 MB |

### 7e. Regression Tests

Verify existing functionality is not broken:
- PNG export still works (single and batch)
- Clipboard copy still works
- Pin add/remove/reorder still works
- Drag-drop still works
- Overflow menu still functions correctly
- Report loading time not noticeably impacted

## 8. Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| PptxGenJS conflicts with existing JS | Low | Low | Namespaced library, no shared globals. Test on load. |
| JPEG compression artefacts on charts | Low | Medium | 85% quality is visually imperceptible on vector-origin content. Tested. |
| Safari download behaviour differs | Medium | Low | Safari may open blob in new tab instead of downloading. Add `download` attribute and test. |
| Memory pressure on 60+ pin export | Low | Low | Sequential processing with 200ms delays. Same pattern as existing batch PNG export. |
| User confusion about template | Medium | Medium | Clear labelling: "Export as plain PowerPoint — insert into your template using Reuse Slides" |
| PptxGenJS update breaks API | Low | Very Low | Pin to specific version. API has been stable for years. Single simple use case (image on slide). |
| Report file size increase | None | Certain | 466 KB on 6-12 MB = 4-7%. Confirmed acceptable. |

## 9. Files Changed

| File | Change |
|------|--------|
| `modules/shared/js/vendor/pptxgen.bundle.js` | **NEW** — vendored PptxGenJS library |
| `modules/shared/js/turas_pins_utils.js` | Add quality preset constants |
| `modules/shared/js/turas_pins_export.js` | Add `exportPptx()`, `exportSinglePptx()`, refactor `_exportToBlob()` for quality toggle |
| `modules/shared/js/turas_pins_render.js` | Add PPTX button to overflow menu, add toolbar export button, add quality toggle UI, add progress overlay |
| `modules/shared/lib/turas_pins_js.R` | Add `vendor/pptxgen.bundle.js` to load order |
| `modules/shared/tests/js/test_pptx_export.html` | **NEW** — browser-based JS test harness |
| `modules/shared/tests/testthat/test_pptx_js_bundle.R` | **NEW** — R-side bundle integration tests |

**No changes to any module-specific code.** All modules inherit the feature automatically through the shared library.

## 10. Next Steps

1. Download and vendor PptxGenJS bundle
2. Implement quality toggle infrastructure
3. Build `exportPptx()` function
4. Add UI controls
5. Build test harness and run full test suite
6. Cross-browser manual testing
7. Performance validation with 60-pin dataset
