# What if: don't-know respondents and the halo check

Built 24 September 2026 on `fix/whatif-dk-halo` (based on `fix/whatif-disclosure`),
from the two open items in `BLINDSPOT_WHATIF_RESULTS_2026_09_24.md`.

## What changed

Don't-know respondents. A respondent with no rating of their own for a lever
(every item don't-know or blank) still carries a fill in the model (the
`dont_know` rule, unchanged), but is now flagged `dk` on the lever
(`09_prepare.R`, guarded in `00_guard.R`). `whatif_need_mask()` leaves them
out and `whatif_move_delta()` returns 0 for them, so a fill sitting below the
target no longer counts as someone to fix or gets lifted. A partial
don't-know on a multi-item lever (one of three items) is not flagged: the
respondent still has a rating from the other items. The open part of the
contribution file carries `open.dk` per lever; the tabs reader lines it up by
respondent like every other open row; the live tab uses it in the need count
and every move, so live numbers still equal the R engine's.

Halo check. `whatif_halo_check()` (07_calibration.R) fits each lever alone
and compares the fix move's whole-sample effect from that fit with the partial
effect from the main fit. Ratio under `WHATIF_HALO_RATIO` (1/3) flags the
lever. The model block ships `halo` (single, partial, ratio, flag per lever)
and `halo_ratio`, in both the open and the client-safe blocks (whole-sample
averages). The tab writes "Caught in the halo: fixed on its own this area is
worth X points for everyone, Y with the other areas held where they are"
under the area, marks the row (`wi-halo`), keeps the number, and lists the
areas in How this works. The workbook's Effort sheets gain Fixed_alone,
Halo_ratio and Halo.

Relative importance. `whatif_lmg()` (07_calibration.R): LMG shares of the
linear R2 of the score on the levers, up to 12 levers (NULL beyond). Workbook
sheet Relative_importance.

## Numbers that move

Any study with don't-know answers below the target: need counts fall by the
flagged respondents and the floor effect no longer includes their lift. On
SACAP 2025 with `dont_know = centre`, value for money's need count would drop
by up to 59. The prototype reproduction in `dev/verify_sacap_2025.R` compares
against numbers that included those lifts and will now differ on the floor
move for levers with don't-knows; Duncan reruns the SACAP config and reports
which counts moved.

On the synthetic fixture the halo check flags `admin` (fixed alone +9.4,
partial +2.1): the fixture's `reg` lever is built from the same admin answers,
so this is the check finding the planted overlap, not a false alarm.

## Tests

- whatif suite (worktree, primary renv library): 1148 passed, 0 failed.
- shared `test_release_audit.R`: 88 passed.
- tabs `test_whatif_island.R`: 100 passed.
- node `whatif_view_tests.mjs`: 19 passed.
- Fixture regenerated: `modules/tabs/tests/fixtures/whatif/synthetic_whatif_island.json`.

## Not done

- No client config was run. Duncan reruns SACAP 2025 through the What If tile.
- The mediator lever kind and the tracker shift-share are design items, not
  in this change.
