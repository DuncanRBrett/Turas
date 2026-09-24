# What if client-safe disclosure: independent review, 24 Sep 2026

Reviewed at local main 374ae172, read-only, in a detached worktree. Nothing in the repo was edited or committed. Every counterexample below was run; the scripts (a1 to a13) were kept in the reviewing session's scratchpad, not the repo. BRIEF_WHATIF_DISCLOSURE_FIX.md carries what is needed to rebuild the counterexamples.

Standard applied: a client-safe file must not let a reader work out any statistic (count, average, model result) about 1 to k-1 respondents, k = min_group = 5.

Test material: proj1 is whatif_write_test_project(n = 300, seed = 11) with A1's don't-knows cut to 1 and detractors cut to 2. proj2 is n = 100, seed 7, default n_boot 100, with Masters cut to 3 respondents. Random-context sweeps call disclosure_publish_groups() directly. The client-safe payload was cut by the real .read_whatif_contribution(), loaded from run_crosstabs.R without running the tabs main block (a11).

The SACAP 2025 What if config was not found on this machine (searched ~/Library/CloudStorage and ~/OneDrive*), so no real-data attack was run.

## Critical

### 1. Unions of hidden cells and three-way cells can be worked out exactly (disclosure_groups.R)

The recoverability check tests only single levels and two-way cells. Any set of small atoms is also a candidate, and the check never tests one.

Sweep a4: 23 of 150 random studies publish a group set from which a set of 1 to 4 respondents is recoverable. All 23 are unions of two small atoms. Sweep a6, with 4 or 5 variables and 2 to 5 crossings: 22 of 100 leak (21 unions, 4 three-way cells, 3 single atoms).

Counterexample A, union across rows and columns (seed 1035, n = 137, one crossing v1 x v2). Published: all 137, v1=L2 114, v2=L3 90, v2=L5 28, and the cells (L2,L3) 75 and (L2,L5) 22. all minus v1=L2 minus v2=L3 minus v2=L5, plus (L2,L3) plus (L2,L5), gives 2. The combination isolates "v1 is not L2 and v2 is neither L3 nor L5", which is rows L1, L3 and L4 by columns L1, L2 and L4 of the table. Only two of those nine cells are occupied: (L4,L1) and (L4,L4), one respondent each.

Counterexample B, three-way cell through nesting (seed 5020, n = 205). v2=L1 occurs only with v1=L1, like a course one campus offers. Published: (v1=L1, v3=L3) 14, (v2=L2, v3=L3), v3=L3. (v1=L1,v3=L3) + (v2=L2,v3=L3) - (v3=L3) = 2, which is the cell v1=L1, v2=L2, v3=L3. The same combination applied to group score totals returned -100, matching the true sum for those 2 people. Because the identity holds atom by atom, every group statistic in the file (actual, need, every effect) gives the same answer for them.

The island's own audit reports recoverable_failures = 0 in both cases: line 368 hard-codes it. release_audit_whatif passes both group sets as clean (a12).

Fix: make the candidate set exact. Every published group is a union of atoms, so any recoverable set under k is a union of atoms that each have under k respondents, and there are at most k-1 of them. Enumerate those subsets with a depth-first search pruned on the running total. Test each against the published span. Refuse, or coarsen the context, if the enumeration grows too large. Compute recoverable_failures from that test instead of writing 0.

## High

### 2. Need counts difference like membership counts (11_island.R:199)

A need count under k, or with a complement under k, is set to null for that group only. Nothing stops the same count being rebuilt from other groups, and nothing checks the counts that are shown against each other.

In proj1, a2 rebuilt 23 hidden need counts exactly from published ones. Examples:
- gender "Not said" (n = 9): all minus Female minus Male gives online need 1, reg need 2, teach need 3.
- campus Online, course Cert (n = 10): course Cert minus the North and South Cert cells gives admin need 1.
- campus Online, course MSc (n = 5): an eight-term combination gives teach need 2 and mentor need 2.
- course BA, year Honours (n = 12): teach need 9, so 3 do not need it.

Shown counts leak too (a13). Two nested groups can each pass the per-group rule and the nesting check, yet differ by a small need count. proj1 has 7 such cases and proj2 has 10. Example: course MSc (n = 28, online need 9) minus year Masters (n = 17, need 5) leaves 11 people, of whom 4 need it. proj2: course Cert (n = 30, teach need 16) minus North Cert (n = 19, need 7) leaves 11, of whom 2 do not.

release_audit_whatif checks each group's need on its own and passes both files.

Fix: need is a yes/no attribute, so publishing a group's need count is publishing the size of (group and needs it) and of (group and does not). Refine the atoms by that attribute, one lever at a time, and run the same exact recoverability test as issue 1 on the refined atoms. Suppress until nothing under k is recoverable, or drop need counts from client-safe files. Publishing need for every group or for none is not enough on its own, as the shown-count examples above show.

### 3. Published effects rest on 1 to 4 respondents (05_groups.R, 11_island.R:206)

A move changes only some respondents: floor touches only those below target, extend only those without the service, withdraw only those with it, a nested lever only users, and up1 or up2 nobody already at the top. Everyone else contributes exactly zero. So est times n is the summed model change of the few who move. The file publishes est, lo and hi for every group even when need is hidden for this very reason.

In a3 and a10:
- proj1: 45 of 1,026 published effects rest on 1 to 4 respondents. proj2: 59 of 567.
- gender "Not said" (n = 9), online floor: est 1.50 x 9 = 13.50, against the one moved respondent's own change of 13.47.
- campus Online, course Cert (n = 10), admin floor: est x n = 3.20, against the one respondent's 3.22 (the gap is rounding to 2 decimals).
- A non-zero floor effect also shows at least one respondent in that group is below target, even when need is null.

These were run on the unweighted variant. In a weighted file the group's weight total is not published, so est x n is not an exact sum. The reader still gets a weighted average of the model change over the same 1 to 4 people, which is still a model result about fewer than k.

Fix: "changed by this move" is a yes/no attribute, just like need. Count the respondents each move changes in each group, refine the atoms by that attribute, and apply the same recoverability test as issues 1 and 2. Suppressing only the groups with 1 to k-1 movers is not enough, because est x n differences across nested groups exactly as need does. Bundles need the same test.

## Medium

### 4. Whole-sample counts under k ship in meta and the model block

In proj1's client-safe payload (a1):
- meta.n_by_outcome is 2, 149, 149.
- meta.warnings carries "Only 2 respondents are Detractor. Effects at that end of the outcome rest on very few people."
- model.notes carries "Teaching 3, Admin 1" don't-know counts.
- model.levers[].missing ships admin = 1.

whatif_safe_model strips none of these, and release_audit_whatif reports no violation. These are whole-sample figures, so they do not tie the people to a group. They still break the stated rule, and the file itself hides a need count of 3 on the grounds that it "describes 3 people".

Fix: in the client-safe cut, publish n_by_outcome only when every category has k or more. Drop missing and the don't-know note from whatif_safe_model. Rebuild meta.warnings for the safe part without counts.

### 5. The release audit cannot catch 1 to 4, and false-alarms on small studies (turas_release_audit.R)

- Check 4 trusts recoverable_failures, which is always 0.
- Check 6 tests only "whole minus levels" and "level minus its cells", so both issue 1 examples pass.
- Check 7 tests need per group, not across groups, so issue 2 passes.
- Nothing tests effects resting on few movers (issue 3) or the meta counts (issue 4).
- False alarm: proj2 (n = 100, default 100 refits) fails with "holds a list about as long as the study (100)". The lists are model$ctx_offset and safe$profile$fits, both 101 long, which lengths_of does not exclude. So any study of about 106 or fewer cannot pass, and an operator learns to ignore the audit.

Fix: have the build re-run an exact recoverability test with the context before embedding (the audit alone has no atom counts). Add the across-group need and effect checks. Exclude every refit list from the length check.

## Low

### 6. Build a ... shows which levels fell under k (12_run.R whatif_safe_profile)

In proj2, Masters (3) and gender "Not said" (2) were pooled. The shipped level lists drop them, so a reader who knows the population sees they had under 5 respondents. The shipped rule "course BA year Masters" still names Masters, because rules are filtered by key, not level. The safe part also ships the publisher's whole audit (11_island.R:219 passes pub$audit as it is). candidates_checked counts the levels and two-way cells under k, including cells of crossings nobody declared, because disclosure_candidates() loops every pair of filter variables. nesting_hidden and recovery_hidden ship too.

The code's own note at 11_island.R:222-226 says naming such levels is to be avoided.

Fix: filter rules to levels still offered, and ship no audit counts beyond pass or fail. The omission itself is inherent to pooling on counts. Either accept a "fewer than k" bound or pool only by merges declared in the config.

safe.profile.combos lists only combinations with k or more, so its complement marks combinations under k. That gives a bound, not a count. I did not find an exact small count from it, and did not measure how often it gives one.

## No findings

- Weighted and unweighted versions: the real .read_whatif_contribution embeds one variant only, chosen by the report's weighting, in cube and none modes (a11). No variant list, open block, open profile or respondent ID reaches a client-safe payload. A records build that cannot line up by ID falls back to the safe part, and the min_reporting_base guard leaves the tab out when the report's k is higher.
- The client-safe model block carries no context-baseline coefficients.
- 27w_whatif.js reads only the precomputed safe groups and combos in client-safe mode. I read this code but did not run it in a browser.

## Not tested

- The SACAP 2025 config, which is not on this machine.
- Differencing between the What if groups and the tabs cube or banners in the same report. The cube's own margin hole is already a known open issue.
- Issues 2 and 3 on the weighted variant (see issue 3).
- Model inversion from the 101 refits' lever coefficients, lo and hi quantiles, and profile spread percentiles.
