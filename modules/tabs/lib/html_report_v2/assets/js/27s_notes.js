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
    if (TR.userState && TR.userState.annotations) {
      Object.keys(TR.userState.annotations).forEach(function (k) {
        cache[k] = TR.userState.annotations[k];
      });
    }
    try {
      var raw = global.localStorage && localStorage.getItem(KEY);
      if (raw) {
        var own = JSON.parse(raw) || {};
        Object.keys(own).forEach(function (k) { cache[k] = own[k]; });
      }
    } catch (e) { /* island-only */ }
    return cache;
  }

  function persist() {
    try {
      if (global.localStorage) localStorage.setItem(KEY, JSON.stringify(store()));
    } catch (e) { /* in-memory only */ }
  }

  notes.all = function () { return store(); };

  /** Annotations of one metric: [{year, text}], oldest first. */
  notes.forMetric = function (metricKey) {
    var out = [];
    Object.keys(store()).forEach(function (k) {
      var at = k.lastIndexOf("::");
      if (k.slice(0, at) !== metricKey) return;
      out.push({ year: parseInt(k.slice(at + 2), 10), text: store()[k] });
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
