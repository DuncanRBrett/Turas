# I20 — Reader-mark re-keying: design

**Status:** DESIGN — approved for implementation (Fable design 2026-08-06;
implementation is a separate step).
**Scope:** the open residual of I20 only — the idx→stable-key migration for
reader marks. The other half of I20 (frozen hub pins carrying withheld text
past a disclosure-tightening rebuild) is already fixed: `qual.textPublished`
re-gates every frozen qualitative pin at render (`27q_qualitative.js:287-303`,
commit `8d1eea85`).

---

## 1. The problem, precisely

Three reader-owned stores key marks by `qcode + "#" + idx`:

| Store | localStorage key | Contents |
|---|---|---|
| Shortlist | `turas_v2_qualsaved` | `qcode#idx → 1` (`27q_qualitative.js:481`) |
| Highlights | `turas_v2_qualhl` | `qcode#idx → [[start,end],…]` character ranges (`27q:550-563`) |
| Hubs | `turas_v2_qualhubs` | per-hub `marks` maps keyed `qcode#idx` (`27q:964`) |

`idx` is positional. In the standalone comment report (Phase 1) it is the
respondent's position in the sorted id list (`qual_assemble.R:44-56`); in the
integrated report (Phase 2) it is the host survey's 0-based row index
(`qual_host_id_to_idx`, `qual_assemble.R:177-192`). Either way it shifts when
the data is re-exported: add or remove one respondent (Phase 1), or merely
reorder the export (Phase 2), and every mark silently re-attaches to a
*different respondent's comment*. localStorage is scoped to project name +
wave (`20_data.js:232-235`), so marks made against the old build are read by
the new build — which is exactly what makes them survive rebuilds, and
exactly what makes the mis-attachment silent.

The obvious stable key — the respondent id the coding workbook carries
(`rec$id`, usually the host ResponseID) — is deliberately **not** in the
island. `qual_build_record_island` (`qual_island_builder.R:112-146`) ships
`idx`, text, tier, sentiment, themes, demos — never the id. That is a design
property, not an oversight: the island is readable in View-Source, and a
shipped ResponseID would let anyone holding the raw export (client, Alchemer)
join an "anonymous" comment back to a named respondent, even when the text
itself is scrubbed or hidden. The fix must not weaken this.

## 2. Design space (fully enumerated)

A key stable across roster changes must come from one of exactly three
places: **state** (a persisted assignment), **derivation from the id** (a
hash), or **derivation from the content** (a text hash). There is no fourth
source.

- **Content hash — rejected.** Duplicate verbatims on the same question are
  common in real open-ends ("N/A", "Nothing", "Good service") and collide;
  the colliding records can differ in demographics, so a mark would attach to
  the wrong tags. Text also changes across rebuilds for legitimate reasons
  (a typo fix in the coding workbook, an improved PII scrub, a text-mode
  change), orphaning marks; and hidden-text records have no content to hash.
- **Keyed hash of the id (HMAC + secret salt) — rejected.** Works only while
  the salt stays secret: respondent ids are a small guessable space (recnos,
  sequential ResponseIDs), so a leaked salt makes every token reversible by
  brute force. It buys nothing over persisted random tokens (both need a
  build-side file that must not be lost) and costs a security argument that
  has to be defended at every audit.
- **Making idx itself stable via a persisted assignment — rejected.** In
  Phase 2 `idx` *is* the MICRO row index; the banner filter masks join on it
  (`qual_assemble.R:196-203`). Decoupling it from the row order breaks
  filtering. Any stable key must be an additional field.
- **Persisted random tokens — chosen.** An opaque token per respondent,
  minted R-side, persisted in a sidecar that never ships. Unconditionally
  non-reversible (the token carries zero bits of the id), no crypto argument
  to defend, no new dependency, and it follows the established
  sidecar-next-to-config convention (`_ai_insights.json`,
  `data_layer_writer.R:974`).

## 3. The design

### 3.1 R side — the `rid` token and its sidecar

**New file `modules/tabs/lib/qual_reader_keys.R`** with one public function:

```r
qual_reader_keys(ids, config_obj)
# -> list(status, map)   # map: named chr, normalised respondent id -> token
```

- **Sidecar path:** `paste0(tools::file_path_sans_ext(config_obj$config_file_path),
  "_reader_keys.json")` — beside the config, exactly like the AI-insights
  sidecar. It lives in the project folder (OneDrive), travels with the
  project, and is never copied into any deliverable.
- **Format:** `{"version": 1, "built": "<timestamp>", "keys": {"<id>": "<token>", …}}`.
- **Token:** 16 lowercase hex characters, drawn with `sample()` (no new
  dependency), uniqueness-checked against the map before acceptance.
- **Semantics — append-only, never delete:**
  - Sidecar absent → mint a token for every id, write the file.
  - Sidecar present → reuse tokens for known ids, mint only for new ids,
    rewrite only when something was minted. Ids absent from this export
    **keep** their entry, so a respondent who drops out of one export and
    returns in the next re-attaches to their old marks.
  - Ids are the *normalised workbook ids* (`qual_id_norm` /
    the numeric-format guard from I19) — the same id universe as
    `names(master$id_to_idx)` in both phases, so Phase 1 and Phase 2 share
    one keying rule.
- **Failure modes (all loud, all safe):**
  - `config_obj$config_file_path` missing/blank → `status = "NO_PATH"`,
    `map = NULL`, console warning. The island builds **without** rids and the
    JS stays on idx keying (legacy mode). Nothing mis-attaches; continuity is
    simply not gained.
  - Sidecar unreadable/corrupt JSON → **do not re-mint** (silent re-minting
    would orphan every existing mark). `status = "CORRUPT"`, `map = NULL`,
    boxed console warning naming the file and the fix (restore or delete it).
    Island builds without rids; rid-keyed marks in readers' browsers become
    temporarily invisible but are *not* deleted (see §3.3 rule 6), so fixing
    the sidecar restores them.
  - Write failure → warning; the run continues with the in-memory map (marks
    made this session survive until the next successful write).

**Island plumbing** (all default-NULL, so every existing caller and test is
untouched):

- `qual_build_data_qual(questions, master, config, rid_map = NULL)`
- `qual_build_question_island(…, rid_map = NULL)`
- `qual_build_record_island(rec, idx, …, rid = NULL)` — emits
  `record$rid <- rid` only when non-NULL.

Both entry points gain the same three lines: `build_integrated_qual_island`
(`qual_report.R:83-118`) and `build_qual_report_v2` (`qual_report.R:247-273`)
call `qual_reader_keys(names(master$id_to_idx)-universe, config_obj)` and pass
`map` through. `serialize_data_qual` (`qual_report.R:25-28`) is generic
`toJSON` — no change.

`rid` ships under every privacy dial (`block` / `safe` / `hidden` /
aggregates-only): it is uniform random, so it discloses nothing under any of
them — see §4.

### 3.2 JS side — keying

One rule, applied in `27q_qualitative.js`:

```js
function markKeyFor(qcode, record) {
  return qcode + "#" + (record.rid != null ? "@" + record.rid : record.idx);
}
```

- Island records carry `rid` → keys are `qcode#@<rid>`. The `@` prefix makes
  rid keys and legacy idx keys unambiguous by inspection (a hex token can be
  all digits; the prefix removes the ambiguity rather than arguing odds).
- Island records lack `rid` (report built before this ships, or a NO_PATH /
  CORRUPT build) → keys stay `qcode#<idx>`, byte-identical to today. Legacy
  mode is the *absence* of the feature, not a second code path.

Call sites that change: `savedKey`/`isSaved`/`toggleSave`/`savedFilter`
(`27q:481-500`), the highlight get/add/remove key construction
(`27q:550-563`), hub `markKey`/`hubHasMark`/mark toggling (`27q:964+`), and
the wire()/render handlers that currently pass `r.idx` — they pass the record
instead. Everything else keeps `idx`: the k-gate's distinct-respondent count
(`hubDistinctRespondents`, `27q:1050-1055`), collection exports, filter
masks, priority quotes (authored, tier-based, re-resolved — no reader keys
involved).

### 3.3 JS side — the migration shim

A single shared `migrateMarkStore(stored, kind)` applied inside the three
store loaders (`savedStore`, `hlStore`, `normalizeHubs`), governed by a store
version stamp `_v`:

1. **Trigger:** store has no `_v` stamp **and** the current island carries
   rids. (A `_v: 2` store is never re-migrated — idempotent by construction.)
2. **Map:** built once per load from the island itself — for every question
   `q`, every record `r`: `map[q.code + "#" + r.idx] = q.code + "#@" + r.rid`.
   This is exact because the legacy key *was* this island's idx assignment.
3. **Rewrite:** each old key that resolves through the map is re-keyed,
   values (the `1`, the range arrays, the hub mark entries) carried verbatim.
   For hubs, `seq`, `order`, `name`, `insight` are untouched — only each
   hub's `marks` map is rewritten.
4. **Unresolved keys** (idx no longer present) are dropped, with one
   `console.info` naming the count — they point at nothing renderable and
   keeping them would only masquerade as data.
5. **Ownership:** `_owns` is preserved exactly as found. Migration is not a
   reader change — it must not claim ownership on an un-owning store (that
   would make the island seed stop merging). The migrated store *is*
   persisted immediately, with `_v: 2` added.
6. **No down-migration, no destruction:** a `_v: 2` (rid-keyed) store read
   against a rid-less island is left completely untouched. Marks are
   invisible until a rid-bearing island returns (the CORRUPT-sidecar case);
   they are never rewritten toward idx.
7. **The upgrade is one-way.** Once migrated, re-opening the *old* report
   file (old JS, idx lookups) finds no marks — expected, since that file is
   superseded, but worth knowing: the old build's JS would also treat the
   `_v` stamp as a mark key in its total count. Cosmetic, in a file that
   should no longer be in use.

**Seeds need no migration.** Saved copies are self-contained: an old copy
carries old JS + old island (consistent idx keys), a new copy carries new JS
+ rid island + rid-keyed `userState` (`32_report.js:410-412` embeds
`savedAll()`/`highlightsAll()` output, which is post-migration). The only
place new JS meets idx-format data is localStorage shared through the
project+wave `storeKey` — which is exactly what the shim covers. The seed
path routes through the same normaliser anyway, as cheap defence.

### 3.4 The one-rebuild caveat (unavoidable, must be documented)

The shim maps old keys through the **current** island's idx assignment. That
is correct precisely when the first rid-bearing rebuild uses the same data
(roster and, for Phase 2, row order) as the build the marks were made
against. If the first rid rebuild also changes the roster, legacy marks
migrate to the wrong respondents — once, exactly as they would have
mis-attached under the status quo. There is no client-side detection (the old
build's roster is unknowable from the new one).

**Operator rule, to go in the guide:** after this ships, regenerate each
project once *from the unchanged data* before the next real re-export, so
marks lock onto their tokens while idx still matches.

## 4. Privacy analysis

- **Joinability to external data:** none. `rid` is uniform random; without
  the sidecar (which never leaves the operator's project folder) there is no
  computation linking it to any id, and no brute-force surface exists because
  there is nothing to brute-force *toward*.
- **Cross-question linkage within a report:** unchanged — `idx` already
  links one respondent's comments across questions by design (it is the
  master index); `rid` adds the same linkage, not more.
- **Cross-build linkage:** stability across rebuilds is the feature, and it
  is bounded by the sidecar's scope: the sidecar derives from the *config
  file* path, and each wave has its own config, so tokens do not implicitly
  persist across waves. Two rebuilds of the *same* wave are linkable —
  that is the point.
- **Dials:** `demographic_cuts = "block"`, `safe` k-anonymisation,
  `qual_confidentiality_mode`, `verbatim_scope` all gate *content*; `rid`
  carries none, so it ships under all of them unchanged.

## 5. Test plan (implementation must include all of these)

**R — new `test_qual_reader_keys.R` + additions to `test_qual_island_builder.R`:**

1. Fresh mint: sidecar written; one token per unique id; 16 lowercase hex;
   all distinct.
2. Stability: second call, same ids → identical map, file not rewritten.
3. Growth: one new id → one new token appended; every old token unchanged.
4. Shrink + return: id absent from the ids vector keeps its sidecar entry; a
   later call with it back returns the original token.
5. Records carry `rid` matching the map; the same respondent has the same
   `rid` across questions; `rid` is absent when `rid_map = NULL`
   (existing-island shape regression).
6. NO_PATH: no `config_file_path` → island without rids + console warning.
7. CORRUPT: unparseable sidecar → island without rids, loud warning, file
   NOT overwritten.
8. Serialisation round-trip: `rid` survives `serialize_data_qual`.

**JS — node suite (new `test_qual_rekey.js` or folded into the 27q suites):**

1. rid island → new marks key `qcode#@<rid>` in all three stores.
2. rid-less island → keys are `qcode#<idx>`, byte-identical to current
   behaviour (regression).
3. Migration: version-less idx store + rid island → rid keys, values intact,
   `_owns` preserved (both owned and un-owning inputs), `_v: 2` stamped.
4. Hubs: marks migrated; `seq`/`order`/`name`/`insight` untouched.
5. Highlights: range arrays survive migration verbatim.
6. Unresolved idx keys dropped; resolvable ones kept; count logged.
7. Idempotence: migrating a `_v: 2` store is a byte-level no-op.
8. No down-migration: `_v: 2` store + rid-less island → untouched.
9. `savedAll()`/`highlightsAll()` (the saveCopy embed) emit rid keys
   post-migration.

**Docs:** OPERATOR_GUIDE gains the sidecar (what it is, do not delete it, it
travels with the config) and the one-rebuild caveat from §3.4.

## 6. Out of scope

- Story/present/PPTX pin snapshots — already re-gated via `textPublished`.
- Priority pins — authored (tier 3 in the workbook), re-resolve every render,
  no reader keys involved.
- Question-keyed stores (notes `27s`, insights `28`) — keyed by question
  code, not respondent; unaffected by roster changes.
- Cross-wave mark continuity — a different feature with real privacy
  trade-offs; not requested, not designed here.
