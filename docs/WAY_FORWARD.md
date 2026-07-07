# Turas — Way Forward

**What this is:** the plan to make the active system clean, documented and safe to stake real client projects on — and to tidy the repo without losing anything.
**Status:** v0.2, 2026-07-05. Decisions settled (§1). Branch cleanup done (§2). Work now reprioritised around the five upcoming projects (§3).

## The situation, in plain terms

- The **new (V2) report** — Tabs, Tracker and Qualitative together, with confidence intervals and sample weighting — is the future. We are **not** going back to the old (classic) report for Tabs and Tracker. Fable reviewed the whole thing, closed 63 defects with regression tests, and finished the arc; the green light stands.
- **Jess is leaving (end of July 2026) and won't be replaced short-term.** So the Docker build and her machine's auto-update are **paused** — nothing pulls from `main` now. Two consequences: repo cleanup carries no deployment risk, and, more importantly, the system has to be trustworthy and self-documenting for you alone.
- The **whole active system is in `main`.** The repo is now a single clean branch (see §2).
- The **other modules** (segmentation, key driver, pricing, conjoint, MaxDiff) stay classic and untouched.

## Upcoming projects (all run together; all Tabs + Tracker, ASSA Tabs only)

VAS · CCPB · SACS · SACAP Student · ASSA. They launch together, so everything they depend on — a correct config template, clear docs, verified weighting and significance — has to be ready before any of them starts. That is now the top priority.

---

## §1 — Decisions (settled)

1. **The 3 unmerged branches** — binned, but rescued first as tags (`rescue/*`) so they're recoverable forever if "to the best of my knowledge" turns out wrong.
2. **Archive style** — old report moves into an in-repo `archive/` folder plus a git label; out of the way, one command to recall.
3. **Deployment** — paused with Jess's departure; no rebuild needed until/unless the setup is revived.
4. **Projects** — all five run together; readiness must cover all of them up front.
5. **Standalone Tracker** — Duncan may want to run it on its own in future, so the classic Tracker report is **archived, not deleted** (recoverable).

---

## §2 — Done: branch cleanup

- Restore point set: tag `pre-cleanup-2026-07-05` on `main` — the whole repo as of today is recoverable.
- The 3 unmerged branches rescued as `rescue/*` tags, then deleted.
- All other branches confirmed already in `main` and deleted.
- Stale leftover worktree removed.
- **Result: 73 branches → 1 (`main`).** Reversible via the tags above.

---

## §3 — The plan, reprioritised

Order changed for two reasons: the five projects launch together (protect them first), and with deployment paused the tidy-up has no deadline.

### Priority 1 — Protect the five projects (do first)

**A. Config template & documentation refresh.** *(This is the "documentation for future use" Fable handed off — its inputs are the three arc docs plus the commit messages.)*
1. Update the config template so every new option is present, each with a sensible default and a one-line plain explanation.
2. Update `OPERATOR_GUIDE.md` to match: what each new option does, what weighting and intervals need, how to set up or continue a tracker wave.

**B. Pre-flight readiness check** — run once against a real project before the five start, working through Fable's own checklist:
- regen a real project via launch_turas; eyeball the dashboard cards;
- the qualitative tab on SACS;
- a save-copy round trip (the exec-summary cover);
- the filtered-view significance letters against Excel on CCS/SACAP (the weighted case — the one thing worth being fussy about);
- export a deck containing a chart pin, a quote pin and a trend pin.

### Priority 2 — Tidy-up (no deadline; after the projects are safe)

**C. Archive the old Tabs & Tracker report (careful surgery).**
1. Trace every place the code points at the old report folders (`modules/tabs/lib/html_report/`, `modules/tracker/lib/html_report/`) and confirm the new report doesn't quietly rely on any of it — the one real risk is shared chart-colouring code.
2. Move them into `archive/classic-reporting/` (still in git); update the launcher/loader so only the new report is offered.
3. Run a real Tabs job and a real Tracker job end to end and confirm output is unchanged. Only then is it done.

**D. Top-level tidy.** Loose plan docs into `docs/`, remove the leftover temp/output folders and the stray Word lock file (`~$ras launcher.docx`).

---

## §4 — Deliberately parked (not forgotten)

- The other modules stay classic; whether they ever move into the new report is a later decision — plan already written at `modules/tabs/docs/V2_MIGRATION_PLAN.md`.
- The two-pin-system reconciliation across other modules stays its own roadmap item, unchanged.

---

## §5 — Unknown-unknowns worth naming

1. **Archiving is surgery, not a folder move.** Old and new reports share the calculation code and possibly the chart-colouring. → Priority 2C.1 guards it.
2. **A stale template is a live project risk, not tidiness.** A mis-set option on a real project costs credibility. → Priority 1A.
3. **A continuing tracker needs its prior wave in exactly the expected shape** — a mismatch fails mid-project, not at setup. Check the last-wave handoff for VAS (wave 2) and any other continuing tracker before starting it.
4. **You're the only checker now.** With Jess gone, the pre-flight eyeball (1B) isn't optional politeness — it's the only gate between a bug and a client. Budget the time for it.

---

## §6 — Fable (mostly closed)

Fable's arc closed the concerns I'd have referred up: all 63 audit defects fixed with regression tests, including the alpha/Bonferroni unification between R and the browser, the weighted/unweighted mixing family, and the disclosure export leaks — plus a diagnostic that now catches spelling-drift like the SACAP Q009 case before it ships. What remains is **your** manual eyeball checklist (§3B), not new Fable work. The only thing I'd still take up to Fable is a sanity check on the old/new separation during archiving (2C.1), if it looks entangled.
