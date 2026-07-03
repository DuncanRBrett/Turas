/**
 * Composite banners — a "profile banner" the analyst assembles by hand: a set
 * of spotlight groups (each from ANY question) shown as columns across EVERY
 * table, e.g. Total · Marketing · Admin · Cape Town Campus · Tenure 5y+.
 *
 * Unlike a normal banner (the mutually-exclusive options of ONE question) a
 * composite's columns come from different questions and may OVERLAP — a
 * respondent can be both Marketing AND Cape Town. Because of that overlap the
 * report never runs the pairwise column-vs-column z-test on a composite (it
 * assumes disjoint samples); significance is each column vs THE REST, which is
 * disjoint by construction. See model.applyCompositeSignificance.
 *
 * Persisted in localStorage and embedded in saved copies (the user-state
 * island) so it survives reload and travels with the report, exactly like saved
 * custom banners and the story. Stored as
 *   { id:"composite:<token>", name, columns:[ {code, label, rows:[rowIndex…],
 *     box?:boxRowIndex} ] }
 * — the per-column {rows, box} mirrors the audience-filter shape so columnsFor
 * rebuilds membership with the same memberArray / boxMemberArray helpers.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var comp = TR.compositeBanners = {};
  var KEY = "turas_v2_composites";
  var SEQ_KEY = "turas_v2_composites_seq";   // monotonic id high-water mark
  var cache = null;
  var seqHW = 0;                              // in-memory high-water (storage-free sessions)

  function store() {
    if (cache) return cache;
    cache = [];
    var own = null;
    try {
      // Scoped per report so a composite never leaks between survey reports
      // sharing a browser origin (see d2.storeKey).
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(KEY));
      if (raw) own = JSON.parse(raw) || null;
    } catch (e) { /* island-only */ }
    // Ownership marker: once the reader changes anything here, the persisted
    // localStorage state carries _owns:true and is authoritative — the island
    // seed is ignored on load, so deletions stay deleted. State without the
    // marker (legacy / first visit) seeds from the island and merges without
    // claiming ownership; only a reader change through the persist path does.
    if (own && !Array.isArray(own) && own._owns) {
      cache = Array.isArray(own.items) ? own.items : [];
      return cache;
    }
    if (TR.userState && Array.isArray(TR.userState.composites)) {
      cache = JSON.parse(JSON.stringify(TR.userState.composites));
    }
    if (Array.isArray(own)) {
      // un-owning local composites merge ADDITIVELY by id — a stale pre-existing
      // store for this project key must not hide the island's composites
      var have = {};
      cache.forEach(function (b) { have[b.id] = true; });
      own.forEach(function (b) { if (!have[b.id]) cache.push(b); });
    }
    return cache;
  }

  function persist() {
    try {
      if (global.localStorage) {
        // every persist here is a reader change
        localStorage.setItem(TR.d2.storeKey(KEY),
          JSON.stringify({ _owns: true, items: store() }));
      }
    } catch (e) { /* storage full/blocked — composites stay in-memory */ }
  }

  comp.all = function () { return store(); };

  /** The stored composite for a "composite:<token>" id, or null. */
  comp.get = function (bannerId) {
    var list = store();
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === bannerId) return list[i];
    }
    return null;
  };

  comp.has = function (bannerId) { return !!comp.get(bannerId); };

  /** Next MONOTONIC token (no RNG, so the node harness sees predictable ids).
   *  It never reissues a freed id — removing the highest composite and adding a
   *  new one used to reuse that id, and the new (differently-defined) profile
   *  banner then inherited the removed one's saved analyst insight/note. The
   *  high-water mark is the max of any live id, the persisted counter and the
   *  in-memory counter, so ids only ever climb — within a session and across
   *  them (persisted where storage is available). */
  function nextToken() {
    var maxExisting = 0;
    store().forEach(function (b) {
      var t = parseInt(String(b.id || "").split(":")[1], 10);
      if (!isNaN(t) && t > maxExisting) maxExisting = t;
    });
    var persisted = 0;
    try {
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(SEQ_KEY));
      persisted = raw ? (parseInt(raw, 10) || 0) : 0;
    } catch (e) { /* in-memory only */ }
    var next = Math.max(maxExisting, persisted, seqHW) + 1;
    seqHW = next;
    try {
      if (global.localStorage) localStorage.setItem(TR.d2.storeKey(SEQ_KEY), String(next));
    } catch (e) { /* storage blocked — seqHW keeps the session monotonic */ }
    return String(next);
  }

  /**
   * Persist a composite spec {name, columns:[{code,label,rows,box?}]}. Assigns
   * and returns its "composite:<token>" id, or null when the spec carries no
   * columns — a composite needs at least one spotlight column besides Total.
   */
  comp.add = function (spec) {
    if (!spec || !Array.isArray(spec.columns) || !spec.columns.length) return null;
    var id = "composite:" + nextToken();
    store().push({ id: id, name: spec.name || "Composite",
      columns: JSON.parse(JSON.stringify(spec.columns)) });
    persist();
    return id;
  };

  /** Drop a composite by its "composite:<token>" id. */
  comp.remove = function (bannerId) {
    cache = store().filter(function (b) { return b.id !== bannerId; });
    persist();
  };

})(typeof window !== "undefined" ? window : globalThis);
