/**
 * Turas Hub App — Preferences Manager
 *
 * Settings modal for configuring scan directories, exclude directories,
 * brand colours, logo path, and auto-save interval. Persists to
 * ~/.turas/hub_app_config.json via the Shiny backend.
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
    exclude_directories: [],
    brand_colour: "#2563EB",
    accent_colour: "#10B981",
    logo_path: "",
    auto_save_interval: 500,
    theme: "light"
  };

  function escapeHtml(str) {
    if (!str) return "";
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function abbreviatePath(path) {
    if (!path) return "";
    if (path.indexOf("/Users/") === 0) {
      var parts = path.split("/");
      if (parts.length >= 3) {
        var home = "/" + parts[1] + "/" + parts[2];
        return "~" + path.substring(home.length);
      }
    }
    return path;
  }

  /**
   * Render a directory list into a container element.
   */
  function renderDirList(container, dirs, type) {
    if (!container) return;
    dirs = dirs || [];

    if (dirs.length === 0) {
      container.innerHTML =
        '<div class="pref-dir-empty">None configured</div>';
      return;
    }

    var html = "";
    for (var i = 0; i < dirs.length; i++) {
      html += '<div class="pref-dir-item">' +
        '<span class="pref-dir-path" title="' + escapeHtml(dirs[i]) + '">' +
          escapeHtml(abbreviatePath(dirs[i])) +
        '</span>' +
        '<button class="pref-dir-remove" data-type="' + type + '" ' +
          'data-index="' + i + '" title="Remove">&times;</button>' +
      '</div>';
    }
    container.innerHTML = html;

    // Bind remove handlers
    var btns = container.querySelectorAll(".pref-dir-remove");
    for (var b = 0; b < btns.length; b++) {
      btns[b].addEventListener("click", function() {
        var idx = parseInt(this.getAttribute("data-index"), 10);
        var t = this.getAttribute("data-type");
        if (t === "scan") {
          prefs.scan_directories.splice(idx, 1);
          renderDirList(document.getElementById("pref-scan-dirs-list"),
                        prefs.scan_directories, "scan");
        } else if (t === "exclude") {
          prefs.exclude_directories.splice(idx, 1);
          renderDirList(document.getElementById("pref-exclude-dirs-list"),
                        prefs.exclude_directories, "exclude");
        }
      });
    }
  }

  /**
   * Show the preferences modal.
   */
  function show() {
    var modal = document.getElementById("preferences-modal");
    if (!modal) return;

    // Populate fields from current prefs
    renderDirList(document.getElementById("pref-scan-dirs-list"),
                  prefs.scan_directories, "scan");
    renderDirList(document.getElementById("pref-exclude-dirs-list"),
                  prefs.exclude_directories, "exclude");

    var brandEl = document.getElementById("pref-brand-colour");
    var accentEl = document.getElementById("pref-accent-colour");
    var logoEl = document.getElementById("pref-logo-path");

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
    var brandEl = document.getElementById("pref-brand-colour");
    var accentEl = document.getElementById("pref-accent-colour");
    var logoEl = document.getElementById("pref-logo-path");

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

    // Ensure arrays
    if (!Array.isArray(prefs.scan_directories)) prefs.scan_directories = [];
    if (!Array.isArray(prefs.exclude_directories)) prefs.exclude_directories = [];

    // Update form if modal is visible
    var modal = document.getElementById("preferences-modal");
    if (modal && modal.style.display !== "none") {
      renderDirList(document.getElementById("pref-scan-dirs-list"),
                    prefs.scan_directories, "scan");
      renderDirList(document.getElementById("pref-exclude-dirs-list"),
                    prefs.exclude_directories, "exclude");

      var brandEl = document.getElementById("pref-brand-colour");
      var accentEl = document.getElementById("pref-accent-colour");
      var logoEl = document.getElementById("pref-logo-path");

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
