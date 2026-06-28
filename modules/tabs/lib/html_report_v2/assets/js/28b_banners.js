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
    // saved-copy island seeds the list; the reader's own localStorage wins.
    if (TR.userState && Array.isArray(TR.userState.banners)) {
      cache = JSON.parse(JSON.stringify(TR.userState.banners));
    }
    try {
      // Scoped per report so a saved banner never leaks between survey reports
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
