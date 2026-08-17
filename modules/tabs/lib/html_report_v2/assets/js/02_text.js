/**
 * Authored report text (TR.txt).
 *
 * The interpretive prose in this report — the explainers, legends and method
 * notes — is written by the report author in the Turas Callout Editor, not in
 * this renderer. It arrives in the #data-text island, keyed, and every place
 * that shows a sentence asks for it here.
 *
 * WHY THERE IS NO FALLBACK WORDING
 * A key with no text renders NOTHING. That is deliberate: wording baked in
 * here as a safety net is wording the author never wrote and cannot edit, and
 * they would have no way to tell the two apart on the page. The build refuses
 * before it gets here (report_text.R checks every key the renderer calls
 * against the registry), so an empty value in a shipped report means the
 * author deliberately switched that block off.
 *
 * MARKUP AND ESCAPING
 * Authored text is trusted HTML — it is written by the report author and
 * validated at build time against a small whitelist of balanced, attribute-free
 * inline tags. Placeholder VALUES are not trusted: they come from the data and
 * the project config, so every one is HTML-escaped before it is substituted.
 *
 * FINDING A KEY ON THE PAGE
 * txt.block() tags its wrapper with data-txt-key, always. The attribute costs
 * nothing, gives the node tests something stable to assert on instead of
 * wording the author is entitled to change, and drives the author-only key
 * badges (see shell.textKeys).
 *
 * Pure — no DOM access — so it unit-tests in node like the other 00–06 modules.
 */
(function (global) {
  "use strict";

  var TR = global.TR = global.TR || {};

  /** key -> authored string. Replaced wholesale at boot by txt.load(). */
  var CATALOGUE = {};

  /** Keys asked for that the catalogue does not hold. Empty in a report that
   *  built cleanly — the build refuses on an unauthored key — so this can only
   *  fill if the renderer asks for a key it never declared in the manifest.
   *  Surfaced by the #selftest case in 31_selftest.js. */
  var MISSES = [];

  function escapeHtml(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  /**
   * Look up an authored string and substitute its placeholders.
   *
   * @param {string} key - manifest key, e.g. "report.construction.computed"
   * @param {object} [vars] - placeholder values; each is HTML-escaped
   * @returns {string} HTML-ready text, or "" when the key is blank or absent
   */
  function txt(key, vars) {
    var raw = CATALOGUE[key];
    if (raw === undefined) {
      if (MISSES.indexOf(key) === -1) MISSES.push(key);
      return "";
    }
    if (!raw) return "";                       // authored blank = show nothing
    if (!vars) return raw;
    return String(raw).replace(/\{([a-z][a-z0-9_]*)\}/g, function (whole, name) {
      // A brace group with no supplied value is left as written rather than
      // blanked, so a mismatch is visible in review instead of silently
      // swallowing a sentence's subject.
      if (!Object.prototype.hasOwnProperty.call(vars, name)) return whole;
      var v = vars[name];
      // {html: "..."} is the renderer explicitly passing markup it built
      // itself — an in-sentence control, a formatted figure. Everything else
      // is data and is escaped. The distinction is deliberate: it keeps a
      // sentence whole for the author instead of splitting it around a button.
      return (v && typeof v === "object" && typeof v.html === "string")
        ? v.html : escapeHtml(v);
    });
  }

  TR.txt = txt;

  /**
   * The same text wrapped in its own element, tagged with its key.
   *
   * @param {string} key - manifest key
   * @param {object} [vars] - placeholder values
   * @param {object} [opts] - {tag: "p", cls: "hint"}; tag defaults to "p"
   * @returns {string} "" when the text is blank, so a switched-off block
   *   leaves no empty element behind
   */
  txt.block = function (key, vars, opts) {
    var body = txt(key, vars);
    if (!body) return "";
    var o = opts || {};
    var tag = o.tag || "p";
    return "<" + tag + ' data-txt-key="' + escapeHtml(key) + '"' +
      (o.cls ? ' class="' + escapeHtml(o.cls) + '"' : "") + ">" +
      body + "</" + tag + ">";
  };

  /** True when the key holds text that would render. */
  txt.has = function (key) { return !!CATALOGUE[key]; };

  /** Install the catalogue (the #data-text island). Called once, at boot. */
  txt.load = function (obj) {
    CATALOGUE = (obj && typeof obj === "object") ? obj : {};
    MISSES.length = 0;
    return CATALOGUE;
  };

  /** Keys asked for and not found — for the selftest and for tests. */
  txt.misses = function () { return MISSES.slice(); };

  /** Every key the catalogue carries. Used by the key-badge overlay. */
  txt.keys = function () { return Object.keys(CATALOGUE); };

})(typeof window !== "undefined" ? window : globalThis);
