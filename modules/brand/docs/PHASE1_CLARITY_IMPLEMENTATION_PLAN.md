# Brand Report — Phase 1 (Clarity) Implementation Plan

**Branch:** `review/brand-report-v2-upgrade-2026-06`
**Parent review:** [BRAND_REPORT_V2_UPGRADE_REVIEW.md](BRAND_REPORT_V2_UPGRADE_REVIEW.md) — Duncan greenlit Phase 1 (clarity).
**Constraint:** I fix code + run test suites; **Duncan regenerates via `launch_turas()` and eyeballs**. I cannot visually verify rendering, so every slice is **additive, reversible, and unit-tested on the emitted HTML structure** — never a blind CSS guess.

---

## Goal

Replace "every element shown at once, equal weight" with a **three-level hierarchy**: Executive → Category story (Level 2) → Detail appendix (Level 3). See the review §5 for the rationale.

## The seam (verified by reading the code)

- **Top nav:** `build_br_tab_nav()` → `.br-tab-nav` / `.br-tab-btn`; switched by `switchBrandTab()` (brand_report.js:12).
- **Per-category sub-tabs:** `build_br_category_panel()` builds a `flat_tabs` list → `.br-subtab-nav` / `.br-subtab-btn`; switched by `switchCategorySubtab()` (brand_report.js:46). Each button carries `data-group / data-subtab / data-subpanel / data-internal-tab`.
- **Sub-tab CSS:** inline in `build_brand_page()` (03_page_builder.R ~1215–1226).
- **On load:** no JS sub-tab sync runs — the active `.br-subtab-btn` / `.br-subpanel` are whatever the HTML rendered.

## Current per-category sub-tab order (the "too much" surface)

`Brand Funnel · Brand Attitude · Brand Attributes · Category Entry Points · [Mental Advantage] · MA Metrics · Category Buying · Word of Mouth · [Branded Reach] · [Demographics] · [Ad Hoc] · [Audience Lens]` — up to 12, all equal weight, with the MA **headline** (Metrics) buried last in the MA group.

## The taxonomy (single source of truth)

`.BR_PRIMARY_SUBTABS <- c("fn-funnel", "ma-metrics", "rep", "wom")` — the category story an analyst presents. **Everything else is Level-3 appendix.** Editing this one vector re-tiers the report.

| Tier | Sub-tabs |
|---|---|
| **Primary (Level 2)** | Brand Funnel · MA Metrics · Category Buying · Word of Mouth |
| **Appendix (Level 3)** | Brand Attitude · Brand Attributes · Category Entry Points · Mental Advantage · Branded Reach · Demographics · Ad Hoc · Audience Lens |

---

## Staged slices (each independently shippable + verifiable by Duncan)

- [x] **Slice 1 — Tier & demote the sub-tab nav.** Primary tabs first (in `.BR_PRIMARY_SUBTABS` order), then the appendix ("detail") tabs after a **subtle gap**, rendered muted — **no divider, no label** (Duncan's chosen treatment; the first-cut "│ Detail" divider was replaced). Pure HTML/CSS via a new pure helper `build_br_subtab_nav()`. **Load-state-safe:** tiering only engages when the active-on-load tab (`flat_tabs[[1]]`, always `fn-funnel` when a funnel is derived) is itself primary — so the sub-panel shown on load never changes; only the order of the *non-active* tabs and the divider change. No-funnel categories fall back to the original untiered order. Unit-tested.
- [ ] **Slice 2 — Collapse the appendix** behind a native `<details>`/`<summary>` "More detail" disclosure (zero JS, keyboard + screen-reader accessible). *Deferred until Duncan confirms Slice 1 renders correctly* — collapse changes layout and must be eyeballed.
- [ ] **Slice 3 — Significance as a toggle.** Default clean view; a "Show significance" control reveals markers (borrow tabs v2 `sigMode`). Tackles the 2,324 "significant" markers.
- [ ] **Slice 4 — Consolidate export chrome.** One toolbar per Level-2 section, not per sub-table (~40 pin / 32 PNG / 16 Excel → ~12–15 sets).
- [ ] **Slice 5 — Search / jump-to** across category sub-tabs.
- [ ] **Slice 6 — Strengthen the Executive landing** (verdict + 3–4 anchor numbers per category; demote the rest).

## Slice 1 — files touched

| File | Change |
|---|---|
| `modules/brand/lib/html_report/03_page_builder.R` | Add `.BR_PRIMARY_SUBTABS` constant; add pure `build_br_subtab_nav(flat_tabs, cat_id)`; replace the inline nav block in `build_br_category_panel()` with a call to it; add the appendix gap (adjacency selector) + `.br-subtab-btn--appendix` muted CSS in `build_brand_page()`. |
| `modules/brand/tests/testthat/test_subtab_nav_tiers.R` | New: known-answer structural tests for `build_br_subtab_nav()`. |

## Slice 1 — risk & verification

- **Risk:** Low. Additive + reversible. No element removed; all sub-panels still render; `switchCategorySubtab()` untouched (appendix buttons keep the `br-subtab-btn` class + all `data-*` attributes). The active-on-load sub-panel is provably unchanged.
- **Automated gate:** `Rscript -e "testthat::test_dir('modules/brand/tests/testthat')"` — new tests + full suite green.
- **Duncan eyeballs (after `launch_turas()` regen):** (1) each category opens on **Brand Funnel** as before; (2) the primary tabs (Funnel · MA Metrics · Category Buying · Word of Mouth) sit together first; (3) the appendix tabs follow after a gap, slightly greyed (no divider, no label); (4) clicking any tab — primary or appendix — still switches correctly. If the gap/spacing looks off, that's a CSS tweak — tell me and I'll adjust (I can't see it).
