# Growth Path: Tabs Microdata + Tabs-Integrated Tracker

**Date:** 2026-06-14
**Current state:** The tabs v2 report can recompute any filtered / custom-banner
view (weighted-correct) from an anonymised microdata island, and assemble a
Tracking tab from per-wave microdata contributions — both off by default.
**Stack:** R writers (`microdata_writer.R`, `tracking_island.R`, `score_utils.R`,
`data_layer_writer.R`) + a vendored vanilla-JS renderer (`21_stats.js`/`22_model.js`
recompute engine, `22w_waves.js` wave engine).

## Architecture readiness

Supported without significant rework:
- **Filtering / custom banners by any single- or multi-select question** — the
  `answers` island + `stats.columnsFor`/`mask` already drive this generically.
- **Weighted recompute** — `tabulate`/`indexMeans`/`netCounts` carry weighted
  counts + Kish effective base; adding a weighted project needs only the weight
  column configured.
- **Mean / NPS metrics over waves** — `scores` + `wave_contribution` already
  produce the tracking island; a new tracker lights up from wave 2 onward.
- **Logos / branding** — `encode_logo_data_uri` + the shell render both researcher
  and client logos from config paths.

Requires significant rework:
- **Weighted wave trends** — `meanOfScores` (22w_waves.js) is unweighted. Needs a
  parallel per-wave `weights` array in the contribution + a weighted mean/SD in
  the wave engine (small, localised; ~half a day).
- **Per-segment (banner-aware) wave history** — the tracking island is Total-only;
  per-segment recompute needs segment membership carried per wave.
- **NET / proportion tracking over waves** — currently only mean-kind metrics
  carry scores; proportion trends need per-wave distributions or answers.

## Natural next steps

### 1. Weighted wave trends
**What:** Carry per-wave `weights` in the contribution; weight `meanOfScores` /
`sdOfScores`.
**Why now:** The live wave is already weighted-correct; the trend should match.
**Effort:** Small — one field in `wave_contribution`, a weighted reducer in
`22w_waves.js` (guard so absent weights = current unweighted behaviour).
**Dependencies:** None.
**Risk:** Low — additive, falls back to unweighted.

### 2. Recompute-ready NET / box-category rows under filter
**What:** Emit `net_members` per question so top-2-box etc. recompute live instead
of showing "—".
**Why now:** Top-box NETs are common tracker headline metrics.
**Effort:** Medium — derive box-category membership from the structure; the engine
already consumes `net_members`.
**Risk:** Medium — membership derivation must match the processor's box logic
exactly (cover with known-answer tests).

### 3. Structure-bridged value recodes (the `DK` → "Don't know" edge)
**What:** When a multi-select has no options but the data uses canonical missing
tokens, map them to the matching published row.
**Why now:** Removes the one known recompute miss without data changes.
**Effort:** Small — reuse `cell_calculator.R`'s canonical missing-token list, map
only when exactly one set-row exists.
**Risk:** Low if guarded to unambiguous cases.

### 4. Microdata size guard for very large surveys
**What:** Skip / sample microdata emission above an n × questions threshold.
**Why now:** Pre-empts multi-MB reports before a 50k-respondent study hits it.
**Effort:** Small.
**Risk:** Low — the report degrades to published-only, exactly as today.

## Known limitations

| Limitation | When it matters | Mitigation |
|------------|-----------------|------------|
| Wave means unweighted | A weighted tracker's trend | Next step 1 |
| NET / numeric means show "—" under filter | Filtering a tracker on a top-box metric | Next step 2 (today: honest "—") |
| `DK`→"Don't know" recode under custom filter | Multi-select with no structure option | Define the option in `Survey_Structure`, or next step 3 |
| Total-only wave history | Per-segment trend exploration | Banner-aware waves (larger) |
| Island size ~ n × questions | n ≳ 20–50k | Next step 4 |

## Technical debt

| Debt | Why accepted | When to pay down |
|------|-------------|-----------------|
| Two logo encoders (classic `embed_logo` + `encode_logo_data_uri`) | Sharing them means touching the tested classic report | Next time the classic report logo code is opened |
| Renderer vendored + kept in sync by hand | The prototype is the JS source of truth | If drift ever appears, add a sync gate to CI |

## External dependencies to watch

| Dependency | Concern |
|------------|---------|
| `base64enc` | Optional (logos degrade to the brand dot if absent) — pin if logos become standard |
| `jsonlite` | Core to all islands; already required by the writers |
| Vendored renderer JS | No third-party JS; self-contained, no runtime deps |

## Summary
Option 2 (microdata interactivity) is complete and production-ready; Option 3
(tabs-integrated tracker) is a solid, verified foundation with weighted trends and
NET tracking as the two highest-value next steps. The biggest constraint is that
the wave engine is Total-only and unweighted — both are localised, additive
changes when a weighted or segment-level tracker engagement calls for them.
