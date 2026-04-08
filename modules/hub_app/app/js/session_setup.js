/**
 * Turas Hub App — Session Setup
 *
 * First screen shown on launch. Allows the user to pick include/exclude
 * folders using the Shiny dir-bar buttons, then scan for projects.
 * Remembers the last 5 folder configurations ("views") for quick re-launch.
 *
 * Public API:
 *   SessionSetup.init()               — Cache DOM, bind events
 *   SessionSetup.show(prefs)          — Render setup view with saved prefs
 *   SessionSetup.hide()               — Transition to project browser
 *   SessionSetup.addDir(type, path)   — Add a folder from Shiny dir picker
 */

var SessionSetup = (function() {
  "use strict";

  var includeDirs = [];
  var excludeDirs = [];
  var recentViews = [];

  var dom = {};

  function init() {
    dom.view       = document.getElementById("view-setup");
    dom.includeList = document.getElementById("setup-include-list");
    dom.excludeList = document.getElementById("setup-exclude-list");
    dom.scanBtn    = document.getElementById("btn-start-scan");
    dom.recentWrap = document.getElementById("setup-recent-views");
    dom.recentList = document.getElementById("setup-recent-list");

    if (dom.scanBtn) {
      dom.scanBtn.addEventListener("click", startScan);
    }
  }

  /**
   * Show the setup view with saved preferences.
   * @param {object} prefs — Preferences from R: scan_directories, exclude_directories, recent_views
   */
  function show(prefs) {
    if (!prefs) prefs = {};

    // Pre-populate include dirs from saved preferences
    includeDirs = ensureStringArray(prefs.scan_directories);
    excludeDirs = ensureStringArray(prefs.exclude_directories);
    recentViews = ensureArray(prefs.recent_views);

    renderIncludeList();
    renderExcludeList();
    renderRecentViews();
    updateScanButton();

    HubApp.showView("setup");
  }

  function hide() {
    HubApp.showView("projects");
  }

  /**
   * Called when the Shiny dir picker returns a folder.
   * @param {string} type — "include" or "exclude"
   * @param {string} path — Folder path
   */
  function addDir(type, path) {
    if (!path) return;

    if (type === "include") {
      if (includeDirs.indexOf(path) === -1) {
        includeDirs.push(path);
        renderIncludeList();
        updateScanButton();
      }
    } else if (type === "exclude") {
      if (excludeDirs.indexOf(path) === -1) {
        excludeDirs.push(path);
        renderExcludeList();
      }
    }
  }

  // ---- Rendering ----

  function renderIncludeList() {
    if (!dom.includeList) return;
    if (includeDirs.length === 0) {
      dom.includeList.innerHTML =
        '<div class="setup-dir-empty">No folders added yet</div>';
      return;
    }
    var html = "";
    for (var i = 0; i < includeDirs.length; i++) {
      html += buildDirItem(includeDirs[i], "include", i);
    }
    dom.includeList.innerHTML = html;
    bindDirRemoveHandlers(dom.includeList, "include");
  }

  function renderExcludeList() {
    if (!dom.excludeList) return;
    if (excludeDirs.length === 0) {
      dom.excludeList.innerHTML =
        '<div class="setup-dir-empty">No exclusions</div>';
      return;
    }
    var html = "";
    for (var i = 0; i < excludeDirs.length; i++) {
      html += buildDirItem(excludeDirs[i], "exclude", i);
    }
    dom.excludeList.innerHTML = html;
    bindDirRemoveHandlers(dom.excludeList, "exclude");
  }

  function buildDirItem(path, type, index) {
    var displayPath = abbreviatePath(path);
    return '<div class="setup-dir-item" data-index="' + index + '">' +
      '<span class="setup-dir-path" title="' + escapeAttr(path) + '">' +
        escapeHtml(displayPath) +
      '</span>' +
      '<button class="setup-dir-remove" data-type="' + type + '" ' +
        'data-index="' + index + '" title="Remove">&times;</button>' +
    '</div>';
  }

  function bindDirRemoveHandlers(container, type) {
    var btns = container.querySelectorAll(".setup-dir-remove");
    for (var i = 0; i < btns.length; i++) {
      btns[i].addEventListener("click", function() {
        var idx = parseInt(this.getAttribute("data-index"), 10);
        if (type === "include") {
          includeDirs.splice(idx, 1);
          renderIncludeList();
          updateScanButton();
        } else {
          excludeDirs.splice(idx, 1);
          renderExcludeList();
        }
      });
    }
  }

  function renderRecentViews() {
    if (!dom.recentWrap || !dom.recentList) return;

    if (!recentViews || recentViews.length === 0) {
      dom.recentWrap.style.display = "none";
      return;
    }

    dom.recentWrap.style.display = "";
    var html = "";
    for (var i = 0; i < recentViews.length; i++) {
      var v = recentViews[i];
      var label = v.label || "Untitled view";
      var dirs = ensureStringArray(v.include_dirs);
      var excl = ensureStringArray(v.exclude_dirs);
      var timeAgo = v.timestamp ? formatTimeAgo(v.timestamp) : "";
      var subtitle = dirs.length + " folder" + (dirs.length !== 1 ? "s" : "");
      if (excl.length > 0) subtitle += ", " + excl.length + " excluded";

      html += '<div class="setup-recent-item" data-index="' + i + '">' +
        '<div class="setup-recent-info">' +
          '<div class="setup-recent-label">' + escapeHtml(label) + '</div>' +
          '<div class="setup-recent-meta">' + escapeHtml(subtitle) +
            (timeAgo ? ' &middot; ' + escapeHtml(timeAgo) : '') +
          '</div>' +
        '</div>' +
        '<span class="setup-recent-arrow">&rsaquo;</span>' +
      '</div>';
    }
    dom.recentList.innerHTML = html;

    // Bind click handlers
    var items = dom.recentList.querySelectorAll(".setup-recent-item");
    for (var j = 0; j < items.length; j++) {
      items[j].addEventListener("click", function() {
        var idx = parseInt(this.getAttribute("data-index"), 10);
        loadRecentView(idx);
      });
    }
  }

  function loadRecentView(index) {
    var view = recentViews[index];
    if (!view) return;

    includeDirs = ensureStringArray(view.include_dirs);
    excludeDirs = ensureStringArray(view.exclude_dirs);
    renderIncludeList();
    renderExcludeList();
    updateScanButton();

    // Auto-trigger scan
    startScan();
  }

  function updateScanButton() {
    if (!dom.scanBtn) return;
    dom.scanBtn.disabled = (includeDirs.length === 0);
    dom.scanBtn.textContent = includeDirs.length === 0
      ? "Add folders to scan"
      : "Scan for Projects (" + includeDirs.length + " folder" +
        (includeDirs.length !== 1 ? "s" : "") + ")";
  }

  function startScan() {
    if (includeDirs.length === 0) return;

    // Send as object — Shiny handles serialization natively
    HubApp.sendToShiny("hub_start_session", {
      include_dirs: includeDirs,
      exclude_dirs: excludeDirs
    });
    hide();
    HubApp.showToast("Scanning for projects...");
  }

  // ---- Utilities ----

  function abbreviatePath(path) {
    if (!path) return "";
    var home = "";
    // Try to detect home prefix for abbreviation
    if (path.indexOf("/Users/") === 0) {
      var parts = path.split("/");
      if (parts.length >= 3) {
        home = "/" + parts[1] + "/" + parts[2];
      }
    } else if (path.indexOf("C:\\Users\\") === 0 || path.indexOf("C:/Users/") === 0) {
      var parts2 = path.replace(/\\/g, "/").split("/");
      if (parts2.length >= 3) {
        home = parts2[0] + "/" + parts2[1] + "/" + parts2[2];
      }
    }
    if (home && path.indexOf(home) === 0) {
      return "~" + path.substring(home.length);
    }
    return path;
  }

  function formatTimeAgo(timestamp) {
    var now = Date.now() / 1000;
    var diff = now - timestamp;
    if (diff < 60) return "just now";
    if (diff < 3600) return Math.floor(diff / 60) + "m ago";
    if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
    if (diff < 604800) return Math.floor(diff / 86400) + "d ago";
    return new Date(timestamp * 1000).toLocaleDateString();
  }

  function ensureArray(val) {
    if (!val) return [];
    if (Array.isArray(val)) return val;
    if (typeof val === "object") return [val];
    return [];
  }

  function ensureStringArray(val) {
    if (!val) return [];
    if (Array.isArray(val)) {
      return val.filter(function(s) { return typeof s === "string" && s.length > 0; });
    }
    if (typeof val === "string") return [val];
    return [];
  }

  function escapeHtml(str) {
    if (!str) return "";
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function escapeAttr(str) {
    return escapeHtml(str);
  }

  return {
    init: init,
    show: show,
    hide: hide,
    addDir: addDir
  };
})();
