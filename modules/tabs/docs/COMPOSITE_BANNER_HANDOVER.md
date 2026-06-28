# Composite banner — handover for a new session

**Status: BUILT (2026‑06‑28), uncommitted on `feature/tabs-executive-takeout`.**
Shipped as a **profile banner** per Duncan's clarified use case: a hand‑picked set
of spotlight groups (Total · Marketing · Admin · Cape Town · Tenure 5y+…), each
from any question, shown as columns across **every** table. The silent‑error trap
below was dissolved by the design, not just guarded: significance is **each column
vs THE REST** (disjoint by construction), never pairwise — so overlapping columns
can't produce a wrong letter because no pairwise letter is ever produced.

## As built
- **vs‑the‑rest significance, bidirectional.** Each column tested against its
  complement (everyone not in it): `▲` above the rest / `▼` below at 95%, hollow
  `▵`/`▿` at the 80% level in dual mode. Mirrors the Differences view's `restPct`
  (weighted‑safe; box‑scored NETs keep the full answered base as denominator).
  Pairwise letters are impossible because composite columns carry an empty letter.
- **Engine:** `columnsFor` composite branch (21_stats.js) → heterogeneous member
  columns; `applyCompositeSignificance` (22_model.js) writes the arrows per cell;
  `forQuestion` routes composite through the microdata recompute and excludes it
  from the FPC re‑letter pass. Render branches on `model.composite` (23_render.js).
- **Persistence:** `TR.compositeBanners` store (28c_composite.js) — localStorage +
  saved‑copy island (`composites`), same shape as saved custom banners. The
  localStorage key is scoped per report via `d2.storeKey` (= base + project name +
  wave) so a composite never leaks between survey reports sharing a browser origin;
  the same wrap was applied to the saved‑custom‑banner store (28b). The other
  per‑report stores (insights, notes, story, report fields, takeout curation) share
  the same fixed‑global‑key root cause and can take the identical `d2.storeKey` wrap.
- **UI:** builder in 26_filter.js (`openCompositeBuilder` — pick question → pick one
  group → repeat → name → save); saved `▦` tabs + "+ Composite…" button + remove in
  25_cards.js; one‑line methodology note in the context strip; `bannerDescription`.
- **Fallbacks:** Differences / dashboard‑heatmap resolve composite → firstBanner;
  snap‑pins resolve via `pinBanner()`; pinned current‑question exhibits keep the
  composite faithfully (spec travels in the island).
- **Verified:** `tests/composite_tests.mjs` (7/7 — heterogeneous overlap, ▲/▼/null,
  mean Welch path, dual ▵, the no‑pairwise‑letter trap, Total never tested) + full
  38‑module vm load + takeout 27/27 + bundler 25/25 + html_report 87/87.

Everything below is the original pre‑build design note, kept for rationale.

---

**Original status:** NOT STARTED. This was item #4 of the tabs‑v2 enhancement batch
(`project_tabs_v2_enhancement_batch` in memory). The other six items are done and
committed (`7ee36f34` feat, `092c3e44` template fix) on branch
`feature/tabs-executive-takeout`. This is the one we deliberately left for a fresh,
focused pass because it is the only item that can introduce a **silent statistical
error**.

**Model steer:** do this on Opus 4.8 (medium effort is fine). The risk is not
volume — it is a subtle correctness hole in significance testing that passes a
glance. Verify with the harnesses + suites, never by reasoning alone.

---

## What Duncan asked for

> "Allow me to create a composite banner – e.g. Total, Cape Town Campus, Marketing
> Department."

One banner whose **columns each come from a different variable**:

| Total | Cape Town Campus | Marketing Dept |
|-------|------------------|----------------|
| (everyone) | Q02 = "Cape Town" | Q03 = "Marketing" |

This is unlike every banner today, where all columns are the mutually‑exclusive
options of **one** question (e.g. all the Campuses, or all the Departments).

---

## ⚠️ The trap — read this first

Significance letters are computed by `stats.sigLetters` (21_stats.js:385). For each
column it runs a **two‑proportion pooled z‑test** (`stats.propZ`, 21_stats.js:344)
against **every other non‑Total column**, and a Welch t‑test for means
(`stats.meanZ`). That test assumes the two groups are **independent / disjoint**
samples. That holds today because a respondent is in exactly one Campus (or one
Department, or one NET box).

In a composite banner the columns can **overlap**: a respondent can be *both* Cape
Town Campus *and* Marketing Department. Running the pairwise two‑proportion test
between overlapping columns is **statistically invalid** — it will still produce
letters, they will just be wrong. A weaker implementation will ship this and it
will look fine.

**Decision you must make explicitly (recommended default in bold):**

- **Suppress pairwise cross‑column significance letters for composite banners.**
  Show the values per column with no inter‑column letters. Honest and safe.
- *Optional, tasteful enhancement:* a "vs Total / vs the rest" indicator computed
  the way the Differences view already does it — `restPct` in 27d_diffs.js:36
  builds "everyone EXCEPT this column" (a genuinely disjoint complement) and tests
  the column against that with the same z‑test. That comparison **is** valid even
  for an overlapping column, because column vs (not‑column) is disjoint by
  construction. If you add per‑column sig, do it this way, not pairwise.
- Do **not** try to be clever and "only compare columns from the same source
  variable" unless Duncan asks — it complicates the UI and the common composite is
  one column per variable (nothing to compare within a variable anyway).

Whatever you choose, **state it in the UI** (a one‑line note under the banner:
"composite banner — significance is shown vs Total only / not shown between
columns") so the analyst is never misled.

---

## How banners flow today (pointers)

The pipeline is clean and the column abstraction makes adding heterogeneous
columns *easy*; the only hard part is the sig decision above.

1. **Banner id → columns.** `stats.columnsFor(banner)` (21_stats.js:117) returns
   `{ columns: [{label, letter, member: Uint8Array|null}], custom, ... }`.
   `member === null` is the Total column; otherwise `member[r] === 1` marks a
   respondent in that column. Two existing branches:
   - preset banner ("Q02"): one column per option, membership from
     `TR.MICRO.banner_vars` (21_stats.js:159).
   - custom banner ("custom:code:mode"): columns from one question's cats / NETs /
     boxes, membership via `memberArray` / `boxMemberArray` (21_stats.js:120‑157).
   **A composite just needs a third branch that builds one `member` array per
   column, each from a different question/value.** The `member`‑array abstraction
   already supports this perfectly — `memberArray(TR.MICRO.answers[code], n, [rowIndex])`.

2. **Columns → model.** `model.forQuestion(code, bannerId, filters, opts)`
   (22_model.js:415). `needCompute = custom || filtered` (line 421) routes through
   `computedModel`, which calls `columnsFor` (22_model.js:109), `tabulate`
   (line 111), and `sigLetters` (lines 61‑82 / 137 / `netRow` 144). **Composite
   must set `needCompute = true`** so it recomputes from microdata like a custom
   banner. Weighting is already handled — `tabulate` uses Kish n_eff.

3. **Model → render.** The table/chart just read `model.columns` + per‑cell
   `sig`; no renderer change needed beyond the sig suppression flowing through as
   empty strings. Each column carries its own `base` (different denominators per
   column is expected and already supported).

---

## Recommended design

### Data model — a composite is a *saved* entity
A composite banner is too rich for the `"custom:code:mode"` string id. It is also
inherently something you build deliberately and want to keep. Tie it to the
saved‑banner work just shipped:

- `28b_banners.js` (`TR.savedBanners`) already persists custom banners
  (localStorage + user‑state island + saved copies). Extend it (or add a parallel
  `TR.compositeBanners` store with the same shape) to hold composites:
  `{ id, name, columns: [ {code, mode, value/rowIndex|net|box, label}, ... ] }`
  where the first column is implicitly Total (or an explicit `{total:true}`).
- Banner id scheme: `"composite:<token>"`. `columnsFor` resolves the token to the
  stored spec and builds the columns. `bannerTabsHtml` (25_cards.js:355) renders
  saved composites as tabs alongside saved custom banners (reuse the
  `.btab.saved` styling; mark them e.g. with a different glyph).
- `state.banner` then holds `"composite:<token>"`. `model.forQuestion` /
  `pinBanner` (30_story.js:70) must treat composite like custom (can't recompute a
  pinned exhibit's live spec → resolve to firstBanner for pins, as custom does).

### `columnsFor` composite branch (the core)
```
if (banner.indexOf("composite:") === 0) {
  var spec = TR.compositeBanners.get(token);   // {columns:[...]}
  var cols = [{label:"Total", letter:"", member:null}];
  spec.columns.forEach(function (def, i) {
    var q = TR.d2.questionByCode(def.code);
    var answers = TR.MICRO.answers[def.code];
    var member = def.box != null
      ? boxMemberArray(TR.MICRO.boxes[def.code], n, def.box)
      : memberArray(answers, n, def.rows);     // def.rows = [rowIndex] or NET members
    cols.push({ label: def.label, letter: String.fromCharCode(65+i),
                member: member, composite: true });
  });
  return { columns: cols, composite: true };
}
```

### Significance
- In `computedModel` (22_model.js), when `spec.composite`, either skip the
  `sigLetters` calls (pass through `""`), or replace them with a vs‑Total/vs‑rest
  test per column (see the trap section; reuse the `restPct` idea from
  27d_diffs.js). Recommend: **suppress pairwise; ship vs‑Total only if time.**
- Make sure the `dual` (95+80) path and the `netRow` path (22_model.js:144) honour
  the same suppression — three call sites.

### UI — a small multi‑column builder
Extend the custom‑banner picker in 26_filter.js (`openPicker` /
`pickBannerMode` / `pickValues`). Flow: "+ Composite…" → pick a question → pick a
value/grouping → "add another column" (pick a *different* question + value) →
repeat → name it → save. It is naturally a saved entity (you just built it; you
don't want to lose it — same motivation as items #3/#9). Total is always column 0.

### Render / exports
Minimal. Confirm: per‑column base + low‑base ⚠ flags still work (they key off each
column's base — already per‑column); the "COMPUTED / recompute live" badge applies
(it is a microdata recompute, like custom); PNG/PPTX exports carry the columns
(they read `model.columns`). No change to `23_render.js`/`27_views.js` expected.

---

## Edge cases to get right
- **Overlapping columns** are fine for *display* (a respondent counts in both Cape
  Town and Marketing). They are NOT fine for pairwise sig — that's the whole trap.
- **Different bases per column** — expected; each column has its own denominator.
  Low‑base ⚠ is per‑column already.
- **Filters + composite** — an audience filter `mask` still applies; columns are
  intersected with the mask in `tabulate`. Make sure the composite branch passes
  the mask through (it does, via `tabulate(q, spec.columns, mask)`).
- **Total‑only reports (CCS)** — composites still work (Total + columns); don't
  dereference `banner_groups[0]` unguarded (see the `firstBanner()` guards already
  added for that crash class).
- **Pins / saved copies** — a pinned composite exhibit can't recompute a live spec;
  resolve `pinBanner()` to firstBanner like custom does (30_story.js:70), OR store
  the resolved column values in the pin. Composite spec must travel in the
  user‑state island if you want saved copies to keep it (extend `saveCopy`,
  32_report.js:217, like `banners` was added).

---

## Verification (do NOT skip)
Mirror what the rest of the batch did — node `vm` harnesses + the testthat suites.
Never headless‑run the real pipeline or touch OneDrive deliverables; **Duncan
regenerates via `launch_turas` himself** and eyeballs.

- Build a composite spec in a node harness, call `stats.columnsFor("composite:…")`,
  assert: heterogeneous `member` arrays correct (a known respondent is 1 in the
  right columns), Total is `null`, bases differ as expected.
- `model.forQuestion(code, "composite:…", [], {})` → values per column correct,
  and **sig letters are empty (or vs‑Total only) — never pairwise**. Plant an
  overlapping pair and assert no cross letters appear.
- Re‑run: `node modules/tabs/lib/html_report_v2/tests/takeout_tests.mjs` (27),
  `test_report_v2_bundler.R` (25), `test_html_report.R` (87), and a full‑bundle
  `vm` load (37+ modules) for syntax/load‑order.
- Load modules the way the harnesses in this batch did (see
  `tests/takeout_tests.mjs` for the `vm.createContext` pattern; the scratchpad
  harnesses were ephemeral).

## Files you'll touch (checklist)
- [ ] `21_stats.js` — `columnsFor` composite branch.
- [ ] `22_model.js` — route composite through `computedModel`; suppress/redirect
      sig at the three call sites (proportions, dual‑80, `netRow`).
- [ ] `28b_banners.js` (or a new `compositeBanners` store) — persist the spec.
- [ ] `25_cards.js` — `bannerTabsHtml` renders saved composite tabs + select.
- [ ] `26_filter.js` — the multi‑column composite builder UI.
- [ ] `30_story.js` / `32_report.js` — pin + saved‑copy handling for composites.
- [ ] CSS in `styles.css` if a new tab/builder style is needed.
- [ ] A one‑line UI note stating how composite significance is handled.

## Context you may want
- Memory: `project_tabs_v2_enhancement_batch` (the whole batch + what each item did),
  `project_executive_takeout` (the pattern tab), `feedback_tabs_v2_regen_via_launch_turas`
  (Duncan regenerates; don't run the pipeline).
- The saved‑banner store from this batch (`28b_banners.js`) and the live‑custom
  banner state (`state.customBanner`, 20_data.js / 25_cards.js / 26_filter.js) are
  the natural foundation to build composites on.
