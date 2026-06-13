# Data-centric report v2 — renderer assets

Vendored, dependency-free renderer for the data-centric (v2) tabs report.
Bundled at run time by `../build_report_v2.R` into a single self-contained
`*_report_v2.html` whenever `html_report_v2: Y` is set in a tabs config.

## Contents

- `js/` — 29 modules: the 5 shared engine modules (`00_namespace`, `01_format`,
  `03_svg`, `13_zip`, `14_pptx_parts`) load first, then the 24 v2 modules
  (`20_*`–`32_*`). `bundle_report_v2_js()` enforces that order.
- `styles.css` — the report stylesheet.
- `template.html` — the shell with the `{{TITLE}}`, `{{CSS}}`, `{{JS}}` and the
  four data-island tokens (`{{DATA_AGG}}`, `{{DATA_MICRO}}`, `{{DATA_PREV}}`,
  `{{DATA_VERIFY}}`).

## Provenance

Copied verbatim from `prototypes/report-redesign/fable/` (the production-review
DEPLOY prototype): the engine modules from `fable/src/js/`, the v2 modules + CSS
+ template from `fable/v2/src/`. That prototype remains the reference and its
gate suite (`v2/tests/`) is the source of the renderer's golden tests.

**To refresh after a prototype change:** re-copy the files above. The renderer
is intentionally dependency-free, so a copy is the whole update. Until the
prototype is retired, treat the prototype as the source of truth for the JS/CSS.

## Scope of this cut

The bundler currently inlines the **aggregates** island only; microdata,
prior-wave and verification islands are inlined as `null`. The renderer
degrades gracefully (no live filtering, no Tracking tab). Those islands arrive
with the microdata and tracking-config sessions.

Note: appending `#selftest` to an aggregates-only report shows **9/15** — the
6 "failures" are the built-in microdata and wave-tracking checks, which have no
data to run against in this cut (not defects). They return to 15/15 once those
islands are wired. End-user reports never invoke the selftest panel.
