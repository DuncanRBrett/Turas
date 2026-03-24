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
    if (count) count.textContent = allProjects.length + " project" +
      (allProjects.length !== 1 ? "s" : "");

    var html = "";
    for (var i = 0; i < allProjects.length; i++) {
      html += buildTile(allProjects[i]);
    }
    grid.innerHTML = html;

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
      html += '<div class="tile-report-item">' +
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
   */
  function handleTileClick() {
    var path = this.getAttribute("data-path");
    if (!path) return;

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
    HubApp.showToast("Opening project...");
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

  return {
    render: render,
    filter: filter
  };
})();
