# V2 Lift Programme — Master Tracker

**Purpose:** bring the analytical modules (maxdiff, conjoint, pricing, keydriver, catdriver, segment) to tabs-v2-level solidity and reporting, with tabs integration where the data shape allows. This is the single coordinating document: every review and implementation session reads it first and updates its row before ending.
**Started:** 2026-07-10. Owner: Duncan. Process author: Fable review session (maxdiff).
**Companion docs:** `modules/tabs/docs/V2_MIGRATION_PLAN.md` (the socket contract + migration mechanics — the technical spine); per-module `{MODULE}_PRODUCTION_REVIEW_*.md` and `HANDOVER_{MODULE}_FOR_OPUS.md` in this folder.

---

## 1. Standing decisions (apply to every module unless a row says otherwise)

| # | Decision | Status |
|---|----------|--------|
| D1 | **Curated** content bar for v2 migration, not parity. Deliberate best-of into the interactive report; exhaustive diagnostics stay in the module's Excel deliverable. Every capability left behind is logged against V2_MIGRATION_PLAN §7's drop-list — a choice, never an accident. | Locked (plan rec, adopted 2026-07-10) |
| D2 | **Simulators stay standalone**, linked not embedded (pricing, conjoint, maxdiff). | Locked (plan rec, adopted 2026-07-10) |
| D3 | **Order: maxdiff first** (Duncan, 2026-07-10 — jumped the queue), then per review findings; default remainder segment → keydriver → catdriver → pricing → conjoint, re-orderable as reviews land. | Locked |
| D4 | **Correctness before lift.** Each module's engine/config fixes (its Phase 1) land before its reporting lift. No better report for wrong numbers. | Locked |
| D5 | **Honest-sig principle:** model *estimates* entering tabs or v2 sig machinery must carry their method; approximate/fallback estimators refuse export by default (override + prominent stamping). Mirrors the tracker aggregate-ingest honest-sig convention. | Locked |
| D6 | **Session pipeline per module** (§2). Fable for review + handover + pre-merge review of engine fixes; Opus 4.8 for implementation; Sonnet 5 optional for template/doc mechanical passes against a written spec. | Locked |

## 2. The pipeline each module goes through

1. **Fable review session** → `docs/v2_lift/{MODULE}_PRODUCTION_REVIEW_{date}.md`. Method (proven on maxdiff): four parallel independent readers — (a) statistical engine bug-hunt, (b) config/UX/doc-drift, (c) report gap-vs-v2 + report bugs, (d) tabs/v2 integration feasibility — plus a test-suite run and coordinator spot-verification of every CRITICAL claim. Findings carry file:line + severity; nothing unverified goes in unlabelled.
2. **Fable locks decisions + writes** `docs/v2_lift/HANDOVER_{MODULE}_FOR_OPUS.md` — explicit work orders with acceptance criteria, session split, branch names.
3. **Opus implementation session(s)**, one branch per session, suites green, no merge.
4. **Fable independent pre-merge review** of the engine-fix session (briefed as independent — no shared working notes with the fixing session).
5. **Duncan**: regenerate via `launch_turas()`, eyeball, merge, push. (Standing rule: sessions never headless-run pipelines on real projects or touch OneDrive.)
6. Session updates its row in §4 and appends to §5 log.

## 3. Programme-level work items

| ID | What | Who | Status |
|----|------|-----|--------|
| OPUS-0 | **Socket consolidation** (V2_MIGRATION_PLAN Phase-0 part 2): extract ONE Kish n_eff into `modules/shared/` (today: `modules/tabs/lib/weighting.R::calculate_effective_n` is canonical; duplicates in `modules/confidence/R/03_study_level.R`, dependency in `modules/tracker/lib/trend_significance.R`); ONE disclosure/min-base gate reusable by migrating modules; retire per-module `*_pins.js` onto shared TurasPins. Prerequisite for any Phase-4/v2 migration (not for correctness or tabs-exporter phases). Spec level: Opus-executable; Fable pre-merge review required. | Opus (Fable review after) | NOT STARTED |
| FAB-0 | Phase-0 part 1 — verify the 2026-07-02 audit stats bugs are closed in the live v2 JS. | Fable | **DONE 2026-07-10**: configurable alpha + Bonferroni divisor live (`21_stats.js:46-75,483-487`), weighted CIs use `baseEff` via `fpcBase` (`22_model.js:83`), FPC/effective-base machinery in `21c_confidence.js:184-188`. Checked directly in the JS, not from docs. |
| PROG-1 | cmdstanr + CmdStan toolchain into renv (needed for real Stan HB in maxdiff/conjoint once maxdiff C1 is fixed; installation is an environment decision). | Duncan | OPEN — decide at maxdiff Session A |

## 4. Module tracker

| Module | Review (Fable) | Handover | Implementation (Opus) | Pre-merge review | Merged |
|--------|---------------|----------|----------------------|------------------|--------|
| **maxdiff** | **DONE 2026-07-10** — `docs/v2_lift/MAXDIFF_PRODUCTION_REVIEW_2026-07-10.md`. 3 CRITICAL (silent EB-fallback mislabelled as HB; numeric resp_id phantom item in shares/TURF; ITEM_POSITION scores zero), template can't run, GUI success-on-refusal. | **DONE** — `docs/v2_lift/HANDOVER_MAXDIFF_FOR_OPUS.md`. Session A correctness / B report-fixes+tabs-exporter / C v2 (gated on OPUS-0). | NOT STARTED — A: `feature/maxdiff-correctness`; B: `feature/maxdiff-report-fixes-and-tabs-export`; C: `feature/maxdiff-v2-report` | pending A | — |
| conjoint | PENDING — reuse maxdiff review brief; extra foci: ChoiceModelR HB path (does it share maxdiff's silent-fallback pattern?), utilities scale/anchoring, market-simulator engine, respondent-level part-worths → tabs Allocation/Numeric shape | — | — | — | — |
| pricing | PENDING — extra foci: VW/GG interpolation correctness, demand/revenue curve math, price simulator, whether any respondent-level output suits tabs | — | — | — | — |
| keydriver | PENDING — extra foci: Shapley/relative-weights math, VIF, correlation-vs-regression honesty; closest to tracker's proven `index_scores` row pattern per V2_MIGRATION_PLAN §3 | — | — | — | — |
| catdriver | PENDING — extra foci: SHAP via shapr (cost/stability), dummy coding, sample-size gates. NOTE: not in V2_MIGRATION_PLAN's scope list — its landing zone must be defined in review | — | — | — | — |
| segment | PENDING — extra foci: assignment-file bridge to other modules; NOTE prior history — segment report v2 exists PARKED on `feature/segment-report-v2` (Duncan preferred classic v1) and a 6-fix bug audit is on local main unpushed; review must reconcile with both before proposing a lift | — | — | — | — |

Already at v2: tabs, tracker. Out of scope here: brand (own roadmap), report_hub (post-programme per NEXT roadmap).

## 5. Log

- 2026-07-10 — maxdiff review + handover written (Fable). FAB-0 verified. Standing decisions D1-D6 locked. Programme doc created. Next action: Duncan launches Fable reviews for the other five modules (any order; segment last is sensible given its parked-v2 history needs the most reconciliation), and/or starts maxdiff Session A in Opus — Session A is not blocked by anything.

## 6. Review-session brief (template for the five pending reviews)

Paste to a fresh Fable session:

> Read `docs/v2_lift/V2_LIFT_PROGRAM.md` §2 and follow the pipeline's step-1 method for the {module} module: four parallel independent readers (statistical engine; config/UX/doc-drift; report gap-vs-tabs-v2 + report bugs; tabs/v2 integration feasibility per `modules/tabs/docs/V2_MIGRATION_PLAN.md`), plus run the module's test suite and spot-verify every CRITICAL claim yourself before reporting. Extra foci for this module are in the §4 tracker row. Deliverables, all in `docs/v2_lift/`: `{MODULE}_PRODUCTION_REVIEW_{date}.md`, a locked-decisions handover `HANDOVER_{MODULE}_FOR_OPUS.md` modelled on the maxdiff one, and updates to the §4 row and §5 log. Review only — no code changes. No fabrication: every finding carries file:line evidence read this session; unverified claims are labelled.
