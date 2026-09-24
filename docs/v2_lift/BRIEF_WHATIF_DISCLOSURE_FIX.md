# Brief: fix the What if client-safe disclosure leaks

Repo: /Users/duncan/Dev/Turas. Local main is at 374ae172 (the What if merge), 10 commits ahead of origin and not pushed. Invoke fable-method first. Check the branch and whether you are in a worktree, then branch from main to fix/whatif-disclosure. Do not push and do not merge. Duncan decides that after an independent re-review.

## What is being protected

A client-safe tabs report may carry the What if tab. The client knows the population (for example a student list). So the file must not let anyone work out any statistic about 1 to k-1 respondents, where k = min_group (default 5). That covers counts, averages and model results. It applies to anything a reader can derive by adding and subtracting published numbers, not just to what is printed.

An independent review on 24 Sep 2026 broke this six ways. Its report is docs/v2_lift/REVIEW_WHATIF_DISCLOSURE_2026_09_24.md. Its attack scripts (a1 to a13) stayed in that session's scratchpad and may be gone. Everything you need to rebuild the counterexamples is in this brief.

## The one idea behind the fix

Every published number is a sum over respondents in some set. Three kinds of set are involved:
- group membership (n, actual, and every group-average statistic);
- group AND "needs the fix" for lever j (the need count);
- group AND "changed by move m on lever j" (the effect est, lo and hi, since non-movers contribute exactly zero).

A reader can recover a statistic about set S if S's indicator is a linear combination of the published sets' indicators. Work on atoms, the distinct combinations of the filter variables, refined by the need or moved attribute where relevant. Any recoverable set under k is a union of at most k-1 atoms that each have under k respondents. So the check can be exact.

Build one shared engine in modules/shared/lib/disclosure_groups.R and use it three times. Suggested shape: `disclosure_small_recoverable(atom_n, A, k)`, where A is atoms by published sets. Take a basis N of the left null space of A. A set S of atoms is recoverable when the rows of N over S sum to zero. Search subsets of small atoms (count under k, at most k-1 atoms, total 1 to k-1) for a zero sum:
- singles are rows that are zero;
- pairs are rows that cancel;
- larger subsets by hashing partial sums (meet in the middle), with a tolerance around 1e-8.

Cap the work. Past the cap, return a TRS refusal (CALC_DISCLOSURE_RECOVERABLE) that tells the analyst to declare fewer crossings or raise the minimum. Never pass silently. Keep the file free of side effects when sourced, because three tabs tests source every file in modules/shared/lib.

## Fixes, in order

1. **Membership (critical).** In disclosure_publish_groups(), replace the single-level and two-way candidate list with the exact engine. Keep the loop: hide the smallest published group in the recovering combination, then repeat. Compute audit$recoverable_failures from the engine; it is hard-coded 0L today (line 368). Update the file header, which says three-way cells and unions are not tested.

2. **Need counts (high).** For each lever, refine the atoms by the need mask. The published sets are the groups whose need is shown, together with every group's membership. Run the engine and set need to null for the smallest group in each recovering combination, until nothing is recoverable. The per-group rule at 11_island.R:199 stays as the starting point. Shown counts leak too: two nested groups can each pass and still differ by a small need count.

3. **Effects (high).** For each lever and move, the moved set is `deltas[[key]][[move]] != 0`, which is the same for the weighted and unweighted variants. Refine by it and run the engine over the groups whose effect is shown. Set est, lo and hi to null where the check fails. Treat bundles the same way, using the union of their moves. Compute the suppression once, from counts, and apply it to both variants. 27w_whatif.js must render a null effect as "not shown", as it already does for need. Check the effort table, the bundle sums and "Sum of each part".

4. **Whole-sample counts (medium).** In the client-safe cut, apply these rules:
   - Publish meta.n_by_outcome only if every category has k or more; otherwise null.
   - Drop model.levers[].missing and the don't-know sentence in model.notes, in whatif_safe_model().
   - Rebuild meta.warnings for the safe part without counts. The outcome warning "Only %d respondents are %s" is one example.

   The open part keeps all of these.

5. **Release audit (medium),** in release_audit_whatif():
   - Stop trusting recoverable_failures blindly: require it to be 0 AND require new fields that record the need and effect checks ran.
   - Add an across-group need check. Any integer combination of shown need counts over nested pairs that lands in 1 to k-1 is a violation; the full test needs context, so this is a backstop.
   - Add checks for n_by_outcome, levers[].missing and counts in warnings.
   - Exclude every refit list from the "as long as the study" check: model$ctx_offset, safe$profile$fits, and anything else of length n_boot + 1. A study of about 106 or fewer currently fails with the default 100 refits.

6. **Build a ... (low).** In whatif_safe_profile(), keep only Structure rules whose levels are still offered. Ship only a pass or fail audit in the safe part: drop candidates_checked, nesting_hidden and recovery_hidden from safe$audit. They count small cells, including crossings nobody declared. Leave level pooling as it is, but tell Duncan in the notes that a level missing from the lists still implies "fewer than k". Whether that bound is acceptable is his call; it has not been decided.

## Tests (write each as a failing test first)

Add the tests to modules/shared/tests/testthat/test_disclosure_groups.R, modules/whatif/tests/testthat/test_run_whatif.R, modules/shared/tests/testthat/test_release_audit.R and modules/tabs/tests/testthat/test_whatif_island.R.

- **Union across rows (review counterexample A).** The seed-1035 study from the generator in the appendix, with k = 5. Published groups today let all, minus v1=L2, minus v2=L3, minus v2=L5, plus cells (L2,L3) and (L2,L5), give 2.
- **Three-way cell through nesting (counterexample B).** The seed-5020 study from gen2. (v1=L1,v3=L3) + (v2=L2,v3=L3) - (v3=L3) = 2, because v2=L1 occurs only with v1=L1.
- **A property test.** Across 150 gen() and 100 gen2() studies, no set of 1 to k-1 is recoverable. Check it with an independent brute force that the engine does not share: every atom, every three-way cell, and every union of up to k-1 small atoms against qr.resid. Before the fix the review's weaker brute force (atoms, three-way cells, unions of two atoms) found 23 of 150 and 22 of 100.
- **Need.** whatif_write_test_project(n = 300, seed = 11), then in data.csv keep one A1 "DK" (set the rest to "Good") and keep two NPS scores of 0 to 6 among Complete rows (set the rest to 8). The review rebuilt 23 hidden need counts, among them gender "Not said" online need 1 (all minus Female minus Male). It also found 7 nested pairs with both counts shown that leak, for example course MSc (28, online need 9) minus year Masters (17, need 5). After the fix, none of either.
- **Effects.** In the same project, 45 of 1,026 effects rested on 1 to 4 movers, for example gender "Not said" online floor, where est x 9 was one respondent's change. After the fix, none, including across nested groups.
- **Whole-sample counts.** Cut A1's don't-knows to 1 and detractors to 2. None of the counts in fix 4 may appear in the safe cut.
- **Small study.** n = 100 with default n_boot passes the release audit when clean. A Masters level cut to 3 does not appear in the shipped rules.
- **Engine refusal.** Test the refusal past the cap, and test that a leaking island fails the release audit.

## Done means

- All new tests pass.
- The existing suites pass with their counts quoted from the run: whatif, disclosure, release audit and tabs whatif (304, 305, 71 and 72 at the merge, per the memory note; rerun them before you start), and the full tabs and shared suites. Known pre-existing failures are the launcher 14-module count, two ADR smoke checks, and the examples/segment saveWorkbook call.
- Report how many groups, need counts and effects the synthetic projects lose to the new suppression, so Duncan can judge the cost.
- Write the notes to docs/v2_lift/NOTES_WHATIF_DISCLOSURE_FIX.md. Commit on the branch, and update the What if memory note.
- Then ask Duncan for an independent re-review before anything client-safe goes to SACAP. SACAP data was not available to the reviewer. If the SACAP config is on disk by then, run it and quote how many groups it publishes (282 before).

Rules: follow TRS (no stop(); refusals boxed in the console). No em dashes in any string. Use turas_saveWorkbook for any workbook. Run R from a worktree with the RENV_CONFIG_AUTOLOADER_ENABLED=FALSE and R_LIBS_USER prefix, because a worktree's renv library is empty.

## Appendix: the review's study generator

```r
k <- 5
gen <- function(seed) {
  set.seed(seed)
  n <- sample(60:300, 1); nv <- sample(3:4, 1)
  ctx <- list()
  for (v in seq_len(nv)) {
    L <- sample(2:5, 1); p <- rgamma(L, 0.8); p <- p / sum(p)
    vals <- sample(paste0("L", seq_len(L)), n, TRUE, p)
    if (v == 2 && runif(1) < 0.5) {
      only <- ctx[[1]]$values == ctx[[1]]$values[1]
      vals[!only & vals == "L1"] <- "L2"
    }
    ctx[[paste0("v", v)]] <- list(label = paste0("V", v), values = vals)
  }
  pairs <- combn(names(ctx), 2, simplify = FALSE)
  cr <- pairs[sample(length(pairs), sample(1:min(3, length(pairs)), 1))]
  list(ctx = ctx, cr = cr)
}
gen2 <- function(seed) {
  set.seed(seed); st <- gen(seed); n <- length(st$ctx[[1]]$values)
  L <- sample(2:4, 1)
  st$ctx$v5 <- list(label = "V5", values = sample(paste0("L", 1:L), n, TRUE, {p <- rgamma(L, .8); p / sum(p)}))
  pairs <- combn(names(st$ctx), 2, simplify = FALSE)
  st$cr <- pairs[sample(length(pairs), sample(2:5, 1))]
  st
}
# gen() seeds 1001:1150; gen2() seeds 5001:5100. Counterexamples: gen(1035), gen2(5020).
# disclosure_publish_groups(st$ctx, st$cr, k)
```
