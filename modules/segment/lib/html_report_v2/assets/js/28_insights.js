/**
 * v2 analyst insights — per-question notes persisted in localStorage,
 * carried into story slides and exportable/importable as JSON so they
 * survive report regeneration and can be shared between analysts.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var insights = TR.insights = {};
  var KEY = "turas_v2_insights";
  var cache = null;

  function store() {
    if (cache) return cache;
    cache = {};
    // saved-copy state (embedded island) seeds the store; the reader's own
    // localStorage edits then take precedence over the author's
    if (TR.userState && TR.userState.insights) {
      Object.keys(TR.userState.insights).forEach(function (k) {
        cache[k] = TR.userState.insights[k];
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
    } catch (e) { /* storage full/blocked — insights stay in-memory */ }
  }

  /**
   * Config-provided default for a question (the classic report's Comments
   * sheet, carried as TR.AGG.comments[code] = [{banner, text}]). Banner-
   * specific entry wins; general entry (banner null) is the fallback. Shown
   * until the analyst types their own — their edit always takes precedence.
   */
  function configDefault(code, banner) {
    var all = (TR.AGG && TR.AGG.comments) || {};
    var entries = all[code];
    if (!entries || !entries.length) return "";
    var general = "";
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i];
      if (banner && e.banner === banner) return e.text;
      if ((e.banner === null || e.banner === undefined) && !general) general = e.text;
    }
    return general;
  }

  /**
   * Insights can be banner-specific (a Campus story differs from a Course
   * story): keyed code::banner with fallback to the general code key, then to
   * the config-provided default (so report comments pre-fill the box).
   */
  insights.get = function (code, banner) {
    var s = store();
    if (banner && s[code + "::" + banner]) return s[code + "::" + banner];
    if (s[code]) return s[code];
    return configDefault(code, banner);
  };

  insights.set = function (code, text, banner) {
    var key = banner ? code + "::" + banner : code;
    if (text) store()[key] = text;
    else delete store()[key];
    persist();
  };

  insights.all = function () {
    return store();
  };

  /** Download all insights + pins as a portable JSON sidecar. */
  insights.exportJson = function () {
    var payload = {
      project: TR.AGG.project.name,
      exported: "",
      insights: store(),
      story: TR.story2 ? TR.story2.items() : []
    };
    var blob = new Blob([JSON.stringify(payload, null, 2)],
      { type: "application/json" });
    var link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = TR.fmt.slug(TR.AGG.project.name) + "_insights.json";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
  };

  /** Import a sidecar produced by exportJson (merges, never deletes). */
  insights.importJson = function (file, onDone) {
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var payload = JSON.parse(reader.result);
        Object.keys(payload.insights || {}).forEach(function (code) {
          store()[code] = payload.insights[code];
        });
        persist();
        if (payload.story && TR.story2) TR.story2.merge(payload.story);
        onDone(true);
      } catch (e) {
        onDone(false);
      }
    };
    reader.readAsText(file);
  };

})(typeof window !== "undefined" ? window : globalThis);
