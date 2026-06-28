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
  var cache = null;

  function store() {
    if (cache) return cache;
    cache = [];
    // saved-copy island seeds the list; the reader's own localStorage wins.
    if (TR.userState && Array.isArray(TR.userState.composites)) {
      cache = JSON.parse(JSON.stringify(TR.userState.composites));
    }
    try {
      // Scoped per report so a composite never leaks between survey reports
      // sharing a browser origin (see d2.storeKey).
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(KEY));
      if (raw) {
        var own = JSON.parse(raw);
        if (Array.isArray(own)) cache = own;
      }
    } catch (e) { /* island-only */ }
    return cache;
  }

  function persist() {
    try {
      if (global.localStorage) localStorage.setItem(TR.d2.storeKey(KEY), JSON.stringify(store()));
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

  /** Next stable token: max existing numeric suffix + 1 (no RNG, so the node
   *  harness and any deterministic test see predictable ids). */
  function nextToken() {
    var max = 0;
    store().forEach(function (b) {
      var t = parseInt(String(b.id || "").split(":")[1], 10);
      if (!isNaN(t) && t > max) max = t;
    });
    return String(max + 1);
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
