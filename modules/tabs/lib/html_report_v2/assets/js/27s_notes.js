/**
 * v2 tracking annotations — analyst notes tagged to a data point of a
 * tracked metric ("Campaign launched", "COVID wave"). Keyed metric::year,
 * persisted in localStorage, hydrated from saved copies (user-state
 * island) and embedded by "Save copy" alongside insights and the story.
 * Rendered as dashed markers on trend charts and as removable chips.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var notes = TR.notes = {};
  var KEY = "turas_v2_annotations";
  var cache = null;

  function store() {
    if (cache) return cache;
    cache = {};
    var own = null;
    try {
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(KEY));
      if (raw) own = JSON.parse(raw) || null;
    } catch (e) { /* island-only */ }
    // Ownership marker: once the reader changes anything here, the persisted
    // localStorage state carries _owns:true and is authoritative — the island
    // seed is ignored on load, so deletions stay deleted. State without the
    // marker (legacy / first visit) seeds from the island and merges without
    // claiming ownership; only a reader change through the persist path does.
    if (own && own._owns) {
      Object.keys(own).forEach(function (k) { if (k !== "_owns") cache[k] = own[k]; });
      return cache;
    }
    if (TR.userState && TR.userState.annotations) {
      Object.keys(TR.userState.annotations).forEach(function (k) {
        if (k !== "_owns") cache[k] = TR.userState.annotations[k];
      });
    }
    if (own) Object.keys(own).forEach(function (k) { if (k !== "_owns") cache[k] = own[k]; });
    return cache;
  }

  function persist() {
    try {
      if (global.localStorage) {
        var out = { _owns: true };   // every persist here is a reader change
        Object.keys(store()).forEach(function (k) { out[k] = store()[k]; });
        localStorage.setItem(TR.d2.storeKey(KEY), JSON.stringify(out));
      }
    } catch (e) { /* in-memory only */ }
  }

  notes.all = function () { return store(); };

  /** Annotations of one metric: [{year, text}], oldest first. */
  notes.forMetric = function (metricKey) {
    var out = [];
    Object.keys(store()).forEach(function (k) {
      var at = k.lastIndexOf("::");
      if (k.slice(0, at) !== metricKey) return;
      out.push({ year: parseFloat(k.slice(at + 2)), text: store()[k] });
    });
    out.sort(function (a, b) { return a.year - b.year; });
    return out;
  };

  /** Set or clear (empty text) the note on metric::year. */
  notes.set = function (metricKey, year, text) {
    var k = metricKey + "::" + year;
    if (text && text.trim()) store()[k] = text.trim();
    else delete store()[k];
    persist();
  };

  notes.get = function (metricKey, year) {
    return store()[metricKey + "::" + year] || "";
  };

})(typeof window !== "undefined" ? window : globalThis);
