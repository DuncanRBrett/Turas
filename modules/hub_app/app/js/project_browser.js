/**
 * Turas Hub App — Project Browser
 *
 * Renders project tiles in a responsive grid. Each tile shows the project
 * name, coloured module badges (with counts), total report count, and
 * relative last-modified date.
 */

var ProjectBrowser = (function() {
  "use strict";

  var allProjects = [];
  var scanDirs = [];          // Known scan directories (from R)
  var activeFolder = null;    // null = "All", or a scan dir path to filter on

  // --- Module type mapping ---
  // Maps raw turas-report-type values to a display group.
  // Sub-types (e.g. "segment-exploration") roll up to their parent module.
  var TYPE_MAP = {
    "tabs":                  { label: "Tabs",        badge: "tabs" },
    "tracker":               { label: "Tracker",     badge: "tracker" },
    "segment":               { label: "Segment",     badge: "segment" },
    "segment-exploration":   { label: "Segment",     badge: "segment" },
    "segment-combined":      { label: "Segment",     badge: "segment" },
    "maxdiff":               { label: "MaxDiff",     badge: "maxdiff" },
    "conjoint":              { label: "Conjoint",     badge: "conjoint" },
    "pricing":               { label: "Pricing",     badge: "pricing" },
    "pricing-simulator":     { label: "Pricing",     badge: "pricing" },
    "confidence":            { label: "Confidence",  badge: "confidence" },
    "keydriver":             { label: "Key Driver",  badge: "keydriver" },
    "catdriver":             { label: "Cat Driver",  badge: "catdriver" },
    "catdriver-unified":     { label: "Cat Driver",  badge: "catdriver" },
    "catdriver-comparison":  { label: "Cat Driver",  badge: "catdriver" },
    "hub":                   { label: "Hub",         badge: "default" },
    "weighting":             { label: "Weighting",   badge: "weighting" }
  };

  /**
   * Ensure a value is an array. Handles JSON auto_unbox converting
   * single-element arrays to scalars or objects.
   * @param {*} val
   * @returns {Array}
   */
  function ensureArray(val) {
    if (!val) return [];
    if (Array.isArray(val)) return val;
    // Single object (auto_unbox converted [{...}] to {...})
    if (typeof val === "object") return [val];
    return [];
  }

  /**
   * Render the project grid from an array of project objects.
   * @param {Array} projects - Array from scan_for_projects()
   */
  function render(projects) {
    allProjects = ensureArray(projects);

    var grid = HubApp.dom.projectGrid;
    var empty = HubApp.dom.projectEmpty;
    var loading = HubApp.dom.projectLoading;
    var count = HubApp.dom.projectCount;

    if (loading) loading.style.display = "none";

    if (allProjects.length === 0) {
      grid.style.display = "none";
      empty.style.display = "";
      if (count) count.textContent = "";
      return;
    }

    grid.style.display = "";
    empty.style.display = "none";

    // Discover unique scan root folders from project paths
    discoverScanDirs();
    renderFolderChips();

    // Apply active folder filter
    var visibleProjects = getVisibleProjects();

    if (count) count.textContent = visibleProjects.length + " project" +
      (visibleProjects.length !== 1 ? "s" : "") +
      (activeFolder ? " in folder" : "");

    var html = "";
    for (var i = 0; i < visibleProjects.length; i++) {
      html += buildTile(visibleProjects[i]);
    }
    grid.innerHTML = html;

    if (visibleProjects.length === 0 && allProjects.length > 0) {
      empty.style.display = "";
    }

    // Bind click handlers
    var tiles = grid.querySelectorAll(".project-tile");
    for (var c = 0; c < tiles.length; c++) {
      tiles[c].addEventListener("click", handleTileClick);
    }
  }

  /**
   * Build HTML for a single project tile.
   * @param {object} project - Project object from R scanner
   * @returns {string} HTML string
   */
  function buildTile(project) {
    var reports = ensureArray(project.reports);
    var reportCount = project.report_count || reports.length || 0;
    var modules = groupByModule(reports);
    var badgesHtml = buildModuleBadges(modules);
    var timeAgo = relativeTime(project.last_modified || "");
    var displayPath = project.display_path || project.path || "";
    var sizeLabel = project.total_size_label || "";

    // Report list (show individual report titles, max 5)
    var reportListHtml = buildReportList(null, reports);

    return '<div class="project-tile" data-path="' + escapeAttr(project.path) + '">' +
      // Title row
      '<div class="tile-name">' + escapeHtml(project.name) + '</div>' +
      // Path subtitle
      '<div class="tile-path" title="' + escapeAttr(project.path) + '">' +
        '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
          '<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>' +
        '</svg>' +
        escapeHtml(displayPath) +
      '</div>' +
      // Module badges
      (badgesHtml ? '<div class="tile-badges">' + badgesHtml + '</div>' : '') +
      // Report list
      reportListHtml +
      // Meta row: count, size, time
      '<div class="tile-meta">' +
        '<span class="tile-meta-item">' +
          '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
            '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>' +
            '<polyline points="14 2 14 8 20 8"/>' +
          '</svg>' +
          reportCount + ' report' + (reportCount !== 1 ? 's' : '') +
        '</span>' +
        (sizeLabel
          ? '<span class="tile-meta-item">' +
              '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
                '<circle cx="12" cy="12" r="10"/>' +
                '<path d="M12 8v4l3 3"/>' +
              '</svg>' +
              escapeHtml(sizeLabel) +
            '</span>'
          : '') +
        (timeAgo
          ? '<span class="tile-meta-item">' +
              '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
                '<circle cx="12" cy="12" r="10"/>' +
                '<polyline points="12 6 12 12 16 14"/>' +
              '</svg>' +
              escapeHtml(timeAgo) +
            '</span>'
          : '') +
      '</div>' +
    '</div>';
  }

  /**
   * Build HTML list of individual report titles (max 5, then "... and N more").
   * Uses the reports array (which has label + type per report) as the source
   * of truth, since report_labels can be mangled by JSON auto_unbox.
   *
   * @param {Array|string} labels - Report label strings (may be scalar if 1 report)
   * @param {Array} reports - Full report objects (label, type, filename)
   * @returns {string} HTML string (empty if no reports)
   */
  function buildReportList(labels, reports) {
    // Build the list from the reports array directly (reliable structure)
    if (!reports || !Array.isArray(reports) || reports.length === 0) return "";

    var MAX_SHOW = 5;
    var html = '<div class="tile-report-list">';
    var count = Math.min(reports.length, MAX_SHOW);

    for (var i = 0; i < count; i++) {
      var r = reports[i];
      var label = (r && r.label) ? r.label : (r && r.filename ? r.filename : "");
      var type = (r && r.type) ? r.type : "";
      var filename = (r && r.filename) ? r.filename : "";
      html += '<div class="tile-report-item tile-report-link" ' +
        'data-report-filename="' + escapeAttr(filename) + '" ' +
        'title="Open ' + escapeAttr(label) + '">' +
        '<span class="tile-report-dot tile-dot-' + escapeAttr(type) + '"></span>' +
        escapeHtml(label) +
      '</div>';
    }

    if (reports.length > MAX_SHOW) {
      html += '<div class="tile-report-more">... and ' +
        (reports.length - MAX_SHOW) + ' more</div>';
    }

    html += '</div>';
    return html;
  }

  /**
   * Group reports by their parent module type.
   * Returns array of { label, badge, count } sorted by count desc.
   */
  function groupByModule(reports) {
    var groups = {};

    for (var i = 0; i < reports.length; i++) {
      var rawType = (reports[i].type || "").toLowerCase();
      var mapped = TYPE_MAP[rawType] || { label: rawType, badge: "default" };
      var key = mapped.badge;

      if (!groups[key]) {
        groups[key] = { label: mapped.label, badge: mapped.badge, count: 0 };
      }
      groups[key].count++;
    }

    // Convert to sorted array (highest count first)
    var arr = [];
    for (var k in groups) {
      arr.push(groups[k]);
    }
    arr.sort(function(a, b) { return b.count - a.count; });
    return arr;
  }

  /**
   * Build coloured badge HTML for module groups.
   * Shows count in badge when > 1 (e.g. "Tabs (3)").
   */
  function buildModuleBadges(modules) {
    var html = "";
    for (var i = 0; i < modules.length; i++) {
      var m = modules[i];
      var text = m.label;
      if (m.count > 1) text += " (" + m.count + ")";
      html += '<span class="tile-badge tile-badge-' + m.badge + '">' +
        escapeHtml(text) + '</span>';
    }
    return html;
  }

  /**
   * Convert a date string like "2026-03-20 14:30" to relative text.
   * Falls back to the raw string if parsing fails.
   */
  function relativeTime(dateStr) {
    if (!dateStr) return "";
    try {
      var d = new Date(dateStr.replace(" ", "T"));
      if (isNaN(d.getTime())) return dateStr;

      var now = Date.now();
      var diffMs = now - d.getTime();
      if (diffMs < 0) return dateStr;

      var mins = Math.floor(diffMs / 60000);
      if (mins < 1) return "Just now";
      if (mins < 60) return mins + " min" + (mins !== 1 ? "s" : "") + " ago";

      var hrs = Math.floor(mins / 60);
      if (hrs < 24) return hrs + " hour" + (hrs !== 1 ? "s" : "") + " ago";

      var days = Math.floor(hrs / 24);
      if (days === 1) return "Yesterday";
      if (days < 7) return days + " days ago";
      if (days < 30) {
        var weeks = Math.floor(days / 7);
        return weeks + " week" + (weeks !== 1 ? "s" : "") + " ago";
      }

      // Older than a month — show the date
      return dateStr.split(" ")[0];
    } catch (e) {
      return dateStr;
    }
  }

  /**
   * Handle click on a project tile.
   * If a specific report link was clicked, stores the target filename
   * so ReportViewer can auto-activate that tab.
   */
  function handleTileClick(e) {
    var path = this.getAttribute("data-path");
    if (!path) return;

    // Check if a specific report was clicked
    var reportLink = e.target.closest ? e.target.closest(".tile-report-link") : null;
    if (!reportLink && e.target.classList && e.target.classList.contains("tile-report-link")) {
      reportLink = e.target;
    }
    // Walk up for the dot child
    if (!reportLink) {
      var el = e.target;
      while (el && el !== this) {
        if (el.classList && el.classList.contains("tile-report-link")) {
          reportLink = el;
          break;
        }
        el = el.parentElement;
      }
    }

    var targetReport = null;
    if (reportLink) {
      targetReport = reportLink.getAttribute("data-report-filename");
    }

    // Store the target report for ReportViewer to pick up
    HubApp.state._pendingReportTarget = targetReport || null;

    var title = HubApp.dom.projectTitle;
    if (title) {
      for (var i = 0; i < allProjects.length; i++) {
        if (allProjects[i].path === path) {
          title.textContent = allProjects[i].name;
          break;
        }
      }
    }

    HubApp.sendToShiny("hub_open_project", path);
    HubApp.showToast(targetReport
      ? "Opening report..."
      : "Opening project...");
  }

  /**
   * Filter displayed projects by search text.
   * Matches against name, path, and module types.
   */
  function filter(query) {
    query = (query || "").toLowerCase().trim();

    var grid = HubApp.dom.projectGrid;
    var tiles = grid.querySelectorAll(".project-tile");
    var visibleCount = 0;

    for (var i = 0; i < tiles.length; i++) {
      var name = (tiles[i].querySelector(".tile-name") || {}).textContent || "";
      var badges = (tiles[i].querySelector(".tile-badges") || {}).textContent || "";

      var match = !query ||
        name.toLowerCase().indexOf(query) !== -1 ||
        badges.toLowerCase().indexOf(query) !== -1;

      tiles[i].style.display = match ? "" : "none";
      if (match) visibleCount++;
    }

    var count = HubApp.dom.projectCount;
    if (count) {
      if (query) {
        count.textContent = visibleCount + " of " + allProjects.length;
      } else {
        count.textContent = allProjects.length + " project" +
          (allProjects.length !== 1 ? "s" : "");
      }
    }

    var empty = HubApp.dom.projectEmpty;
    if (empty) {
      empty.style.display = (visibleCount === 0 && allProjects.length > 0) ? "" : "none";
    }
  }

  function escapeHtml(str) {
    if (!str) return "";
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function escapeAttr(str) {
    if (!str) return "";
    return str.replace(/&/g, "&amp;").replace(/"/g, "&quot;")
              .replace(/'/g, "&#39;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // ===========================================================================
  // Folder Discovery & Filtering
  // ===========================================================================

  /**
   * Discover scan root directories from the projects' paths.
   * Groups projects by their nearest scan root.
   * Also accepts scan_dirs sent from R.
   */
  function discoverScanDirs() {
    // Build unique parent-folder groups from project paths
    var dirs = {};
    for (var i = 0; i < allProjects.length; i++) {
      var p = allProjects[i];
      var path = p.path || "";
      // Use display_path for grouping label, full path for matching
      var parent = getParentPath(path);
      if (parent && !dirs[parent]) {
        dirs[parent] = {
          path: parent,
          label: abbreviatePath(parent),
          count: 0
        };
      }
      if (parent) dirs[parent].count++;
    }
    scanDirs = [];
    for (var key in dirs) {
      scanDirs.push(dirs[key]);
    }
    // Sort by count desc, then label
    scanDirs.sort(function(a, b) {
      return b.count - a.count || a.label.localeCompare(b.label);
    });
  }

  /**
   * Get the parent directory from a full path.
   */
  function getParentPath(path) {
    if (!path) return "";
    var parts = path.replace(/\\/g, "/").split("/");
    parts.pop();
    return parts.join("/");
  }

  /**
   * Abbreviate a path for display.
   * Shows the meaningful portion: strips common cloud storage prefixes,
   * replaces HOME with ~, keeps enough context to distinguish folders.
   */
  function abbreviatePath(path) {
    if (!path) return "";

    var display = path.replace(/\\/g, "/");

    // Try to derive from a project's display_path (R already does ~ substitution)
    for (var i = 0; i < allProjects.length; i++) {
      var dp = allProjects[i].display_path || "";
      var projPath = (allProjects[i].path || "").replace(/\\/g, "/");
      if (dp && projPath && projPath.indexOf(path) === 0) {
        // display_path is for the project dir; we want its parent
        var dpParts = dp.replace(/\\/g, "/").split("/");
        dpParts.pop(); // remove project folder name
        var parentDp = dpParts.join("/");
        if (parentDp) return parentDp;
      }
    }

    // Strip known cloud storage prefixes
    var cloudPrefixes = [
      /.*\/CloudStorage\/OneDrive[^/]*\//,
      /.*\/CloudStorage\/Dropbox[^/]*\//,
      /.*\/CloudStorage\/GoogleDrive[^/]*\//
    ];
    for (var c = 0; c < cloudPrefixes.length; c++) {
      if (cloudPrefixes[c].test(display)) {
        display = display.replace(cloudPrefixes[c], "OneDrive:/");
        break;
      }
    }

    // Replace HOME
    // Detect home dir from any project's path vs display_path
    for (var h = 0; h < allProjects.length; h++) {
      var dp2 = (allProjects[h].display_path || "").replace(/\\/g, "/");
      var fp2 = (allProjects[h].path || "").replace(/\\/g, "/");
      if (dp2.indexOf("~/") === 0 && fp2.indexOf("/Users/") === 0) {
        var homeDir = fp2.substring(0, fp2.length - dp2.length + 1);
        if (homeDir && display.indexOf(homeDir) === 0) {
          display = "~" + display.substring(homeDir.length - 1);
          break;
        }
      }
    }

    return display;
  }

  /**
   * Get projects visible after folder filter is applied.
   */
  function getVisibleProjects() {
    if (!activeFolder) return allProjects;
    return allProjects.filter(function(p) {
      var parent = getParentPath(p.path || "");
      return parent === activeFolder;
    });
  }

  /**
   * Render the folder filter chips.
   */
  function renderFolderChips() {
    var bar = document.getElementById("folder-filter-bar");
    var container = document.getElementById("folder-chips");
    var allBtn = document.getElementById("folder-filter-all");

    if (!bar || !container) return;

    // Hide bar if only 1 folder
    if (scanDirs.length <= 1) {
      bar.style.display = "none";
      return;
    }
    bar.style.display = "";

    // "All" button active state
    if (allBtn) {
      allBtn.className = "folder-chip" + (activeFolder ? "" : " folder-chip-active");
    }

    var html = "";
    for (var i = 0; i < scanDirs.length; i++) {
      var dir = scanDirs[i];
      var isActive = (activeFolder === dir.path);
      html += '<div class="folder-chip-group">' +
        '<button class="folder-chip' + (isActive ? ' folder-chip-active' : '') + '" ' +
          'data-folder="' + escapeAttr(dir.path) + '" ' +
          'onclick="ProjectBrowser.filterByFolder(\'' + escapeAttr(dir.path).replace(/'/g, "\\'") + '\')" ' +
          'title="' + escapeAttr(dir.path) + '">' +
          escapeHtml(dir.label) +
          ' <span class="folder-chip-count">' + dir.count + '</span>' +
        '</button>' +
        '<button class="folder-chip-remove" ' +
          'onclick="event.stopPropagation(); ProjectBrowser.removeFolder(\'' + escapeAttr(dir.path).replace(/'/g, "\\'") + '\')" ' +
          'title="Remove this folder from scan">&times;</button>' +
      '</div>';
    }
    container.innerHTML = html;
  }

  /**
   * Filter projects by a specific folder path.
   * @param {string|null} folderPath - Folder to filter to, or null for "All"
   */
  function filterByFolder(folderPath) {
    activeFolder = folderPath || null;
    render(allProjects);
    // Also clear any text search
    var searchInput = HubApp.dom.projectSearch;
    if (searchInput) searchInput.value = "";
  }

  /**
   * Remove a folder from the scan directories and rescan.
   * @param {string} folderPath - Parent folder path to remove
   */
  function removeFolder(folderPath) {
    if (!folderPath) return;
    // Tell R to remove this directory and rescan
    HubApp.sendToShiny("hub_remove_dir", folderPath);

    // If we were filtering on this folder, reset to "All"
    if (activeFolder === folderPath) {
      activeFolder = null;
    }
  }

  /**
   * Update the known scan directories from R.
   * Called when R sends the directory list.
   */
  function setScanDirs(dirs) {
    if (Array.isArray(dirs)) {
      scanDirs = dirs.map(function(d) {
        return { path: d, label: d, count: 0 };
      });
    }
  }

  return {
    render: render,
    filter: filter,
    filterByFolder: filterByFolder,
    removeFolder: removeFolder,
    setScanDirs: setScanDirs
  };
})();
