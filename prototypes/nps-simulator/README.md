# What-if driver simulator prototypes

Throwaway prototypes from a planning session on 23 Sep 2026. Read PLAN.md first.

Files:

- `fit_sacap.py`, `template_sacap.html`: SACAP 2025 students, multinomial model.
- `fit_ccpb.py`, `template_ccpb.html`: CCPB 2026 outlets, promoter vs rest.
- `fit_ccpb_v3.py`, `template_ccpb_v3.html`: CCPB v3. Ordinal model, coverage
  and nested levers, cascading group choices, effort table, 2025 vs 2026.
- `fit_sacap_safe.py`, `template_sacap_safe.html`: SACAP client-safe build. No
  respondent rows in the page; group results precomputed, minimum group 5.
- `whatif_engine.py`: the generic What if engine. A study file builds a spec
  (data, levers, context, profile sentence, crossings, bundles, symptoms) and
  calls `run(spec)`. Writes `build/whatif_<id>_safe.json` (no respondent rows,
  audited) and `build/whatif_<id>_open.json` (respondent rows, open view only).
- `study_sacap.py`, `study_ccpb.py`: the two study definitions.
- `template_whatif.html`: the "What if" tab mockup in the report shell, one page
  per study, with an Open / Client-safe switch. Built mockups carry respondent
  rows for the open view, so they are INTERNAL ONLY.
- `access_ccpb.py`, `stability_ccpb.py`: the analyses behind PLAN.md.
- `robustness.py`: the robustness checks in PLAN.md (needs R with `ordinal`).
- `build.py`: injects `build/model_*.json` into each template.

Run from this folder: a fit or study script, then `python3 build.py`. Output lands in
`build/`, which is gitignored. The built pages and JSON contain respondent-level
client data. They stay on disk and must never be committed or published.

The fit scripts read the client data files from hardcoded OneDrive paths. That is
fine for a prototype and not how a Turas module should work.
