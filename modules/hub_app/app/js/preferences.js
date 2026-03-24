/**
 * Turas Hub App — Preferences Manager
 *
 * Settings modal for configuring scan directories, brand colours,
 * logo path, and auto-save interval. Persists to ~/.turas/hub_app_config.json
 * via the Shiny backend.
 *
 * Public API:
 *   Preferences.show()    — Open the settings modal
 *   Preferences.hide()    — Close the modal
 *   Preferences.load(data) — Hydrate from R-side preferences
 */

var Preferences = (function() {
  "use strict";

  var prefs = {
    scan_directories: [],
    brand_colour: "#2563EB",
    accent_colour: "#10B981",
    logo_path: "",
    auto_save_interval: 500,
    theme: "light"
  };

  /**
   * Show the preferences modal.
   */
  function show() {
    var modal = document.getElementById("preferences-modal");
    if (!modal) return;

    // Populate fields from current prefs
    var dirsEl = document.getElementById("pref-scan-dirs");
    var brandEl = document.getElementById("pref-brand-colour");
    var accentEl = document.getElementById("pref-accent-colour");
    var logoEl = document.getElementById("pref-logo-path");

    if (dirsEl) dirsEl.value = (prefs.scan_directories || []).join("\n");
    if (brandEl) brandEl.value = prefs.brand_colour || "#2563EB";
    if (accentEl) accentEl.value = prefs.accent_colour || "#10B981";
    if (logoEl) logoEl.value = prefs.logo_path || "";

    modal.style.display = "flex";

    // Request current prefs from R
    HubApp.sendToShiny("hub_load_preferences", Date.now());
  }

  /**
   * Hide the preferences modal.
   */
  function hide() {
    var modal = document.getElementById("preferences-modal");
    if (modal) modal.style.display = "none";
  }

  /**
   * Save preferences from the form to R.
   */
  function save() {
    var dirsEl = document.getElementById("pref-scan-dirs");
    var brandEl = document.getElementById("pref-brand-colour");
    var accentEl = document.getElementById("pref-accent-colour");
    var logoEl = document.getElementById("pref-logo-path");

    prefs.scan_directories = (dirsEl ? dirsEl.value : "")
      .split("\n")
      .map(function(s) { return s.trim(); })
      .filter(function(s) { return s.length > 0; });

    prefs.brand_colour = brandEl ? brandEl.value : "#2563EB";
    prefs.accent_colour = accentEl ? accentEl.value : "#10B981";
    prefs.logo_path = logoEl ? logoEl.value.trim() : "";

    var payload = JSON.stringify(prefs);
    HubApp.sendToShiny("hub_save_preferences", payload);

    hide();
    HubApp.showToast("Preferences saved");
  }

  /**
   * Load preferences from R-side data.
   * @param {object} data - Preferences object from R
   */
  function load(data) {
    if (!data) return;

    for (var key in data) {
      if (data.hasOwnProperty(key) && prefs.hasOwnProperty(key)) {
        prefs[key] = data[key];
      }
    }

    // Update form if modal is visible
    var modal = document.getElementById("preferences-modal");
    if (modal && modal.style.display !== "none") {
      var dirsEl = document.getElementById("pref-scan-dirs");
      var brandEl = document.getElementById("pref-brand-colour");
      var accentEl = document.getElementById("pref-accent-colour");
      var logoEl = document.getElementById("pref-logo-path");

      if (dirsEl) dirsEl.value = (prefs.scan_directories || []).join("\n");
      if (brandEl) brandEl.value = prefs.brand_colour || "#2563EB";
      if (accentEl) accentEl.value = prefs.accent_colour || "#10B981";
      if (logoEl) logoEl.value = prefs.logo_path || "";
    }
  }

  /**
   * Get current preferences.
   */
  function getPrefs() {
    return prefs;
  }

  return {
    show: show,
    hide: hide,
    save: save,
    load: load,
    getPrefs: getPrefs
  };
})();
