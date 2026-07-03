/**
 * Saved custom banners — a custom banner ("cross anything by anything") the
 * analyst chooses to keep. Persisted in localStorage and embedded in saved
 * copies (the user-state island) so it survives reload and travels with the
 * report, exactly like insights and the story. Stored as an array of
 * { code, mode, name } — the same triple state.banner encodes as the id
 * "custom:<code>:<mode>".
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var saved = TR.savedBanners = {};
  var KEY = "turas_v2_banners";
  var cache = null;

  function store() {
    if (cache) return cache;
    cache = [];
    var own = null;
    try {
      // Scoped per report so a saved banner never leaks between survey reports
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
    if (TR.userState && Array.isArray(TR.userState.banners)) {
      cache = JSON.parse(JSON.stringify(TR.userState.banners));
    }
    if (Array.isArray(own)) {
      // un-owning local banners merge ADDITIVELY by id — a stale pre-existing
      // store for this project key must not hide the island's saved banners
      var have = {};
      cache.forEach(function (b) { have[saved.id(b)] = true; });
      own.forEach(function (b) { if (!have[saved.id(b)]) cache.push(b); });
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
    } catch (e) { /* storage full/blocked — saved banners stay in-memory */ }
  }

  /** The "custom:code:mode" id (matches what state.banner carries). */
  saved.id = function (b) { return "custom:" + b.code + ":" + b.mode; };

  saved.all = function () { return store(); };

  /** True when this custom-banner id is already saved. */
  saved.has = function (bannerId) {
    return store().some(function (b) { return saved.id(b) === bannerId; });
  };

  /** Persist the custom banner encoded as "custom:code:mode". No-op (returns
   *  false) if blank, not a custom id, or already saved. */
  saved.add = function (bannerId) {
    if (!bannerId || bannerId.indexOf("custom:") !== 0) return false;
    if (saved.has(bannerId)) return false;
    var parts = bannerId.split(":");            // ["custom", code, mode]
    var code = parts[1], mode = parts[2] || "net";
    if (!code) return false;
    var q = TR.d2.questionByCode(code);
    store().push({ code: code, mode: mode, name: q ? q.title : code });
    persist();
    return true;
  };

  /** Drop a saved banner by its "custom:code:mode" id. */
  saved.remove = function (bannerId) {
    cache = store().filter(function (b) { return saved.id(b) !== bannerId; });
    persist();
  };

})(typeof window !== "undefined" ? window : globalThis);
