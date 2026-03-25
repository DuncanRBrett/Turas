/**
 * Turas Hub App — Project Browser
 *
 * Renders project tiles in a responsive grid. Cards are collapsed by default
 * (showing name, note, path, module badges, file counts) and expand to a
 * full-screen overlay showing categorized file lists with clickable items.
 *
 * Features:
 *   - Folder filter dropdown (replaces inline chips)
 *   - Sort controls (recent, name, files, modules)
 *   - Full-screen overlay for expanded project detail
 */

var ProjectBrowser = (function() {
  "use strict";

  var allProjects = [];
  var scanDirs = [];
  var activeFolder = null;
  var currentSort = "recent";  // "recent" | "name" | "name-desc" | "files" | "modules"

  // --- Module type mapping ---
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
    "weighting":             { label: "Weighting",   badge: "weighting" },
    "report_hub":            { label: "Report Hub",  badge: "default" }
  };

  // --- SVG icons ---
  var ICONS = {
    folder: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>',
    chevronRight: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>',
    chevronDown: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>',
    html: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
    excel: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/></svg>',
    data: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>',
    diagnostic: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>',
    play: '<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>',
    close: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
    externalLink: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>'
  };

  function ensureArray(val) {
    if (!val) return [];
    if (Array.isArray(val)) return val;
    if (typeof val === "object") return [val];
    return [];
  }

  // =========================================================================
  // Rendering
  // =========================================================================

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
      hideFolderSortBar();
      return;
    }

    grid.style.display = "";
    empty.style.display = "none";

    discoverScanDirs();
    renderFolderSortBar();

    var visibleProjects = sortProjects(getVisibleProjects());

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

    bindTileHandlers();
  }

  // =========================================================================
  // Tile Building (collapsed card)
  // =========================================================================

  function buildTile(project) {
    var modules = ensureArray(project.modules);
    var counts = project.counts || {};
    var note = project.note || "";
    var displayPath = project.display_path || project.path || "";
    var timeAgo = relativeTime(project.last_modified || "");

    var badgesHtml = buildModuleBadges(modules);

    var summaryParts = [];
    if (counts.html_reports) summaryParts.push(counts.html_reports + " report" + (counts.html_reports !== 1 ? "s" : ""));
    if (counts.configs) summaryParts.push(counts.configs + " config" + (counts.configs !== 1 ? "s" : ""));
    if (counts.data_files) summaryParts.push(counts.data_files + " data file" + (counts.data_files !== 1 ? "s" : ""));
    if (counts.excel_reports) summaryParts.push(counts.excel_reports + " excel output" + (counts.excel_reports !== 1 ? "s" : ""));
    if (counts.diagnostics) summaryParts.push(counts.diagnostics + " diagnostic" + (counts.diagnostics !== 1 ? "s" : ""));
    var summaryText = summaryParts.join(" \u00b7 ") || "No files detected";

    return '<div class="project-tile" ' +
      'data-path="' + escapeAttr(project.path) + '" ' +
      'data-id="' + escapeAttr(project.id) + '">' +

      '<div class="tile-header">' +
        '<button class="tile-toggle" data-id="' + escapeAttr(project.id) + '" title="Expand">' +
          ICONS.chevronRight +
        '</button>' +
        '<div class="tile-name">' + escapeHtml(project.name) + '</div>' +
        (timeAgo ? '<span class="tile-time">' + escapeHtml(timeAgo) + '</span>' : '') +
      '</div>' +

      '<div class="tile-note" data-path="' + escapeAttr(project.path) + '">' +
        '<span class="tile-note-text' + (note ? '' : ' tile-note-placeholder') + '">' +
          escapeHtml(note || "Click to add a note...") +
        '</span>' +
      '</div>' +

      '<div class="tile-path" data-folder="' + escapeAttr(project.path) + '" title="Open in file manager">' +
        ICONS.folder + ' ' +
        '<span class="tile-path-text">' + escapeHtml(displayPath) + '</span>' +
      '</div>' +

      (badgesHtml ? '<div class="tile-badges">' + badgesHtml + '</div>' : '') +

      '<div class="tile-counts">' + escapeHtml(summaryText) + '</div>' +
    '</div>';
  }


  // =========================================================================
  // Overlay (expanded project detail)
  // =========================================================================

  function openOverlay(projectId) {
    var project = null;
    for (var i = 0; i < allProjects.length; i++) {
      if (allProjects[i].id === projectId) {
        project = allProjects[i];
        break;
      }
    }
    if (!project) return;

    var overlay = document.getElementById("project-overlay");
    if (!overlay) return;

    var content = overlay.querySelector(".project-overlay-content");
    if (!content) return;

    content.innerHTML = buildOverlayContent(project);
    overlay.style.display = "flex";
    document.body.style.overflow = "hidden";

    // Bind overlay event handlers
    bindOverlayHandlers(overlay, project);
  }

  function closeOverlay() {
    var overlay = document.getElementById("project-overlay");
    if (overlay) {
      overlay.style.display = "none";
      document.body.style.overflow = "";
    }
  }

  function buildOverlayContent(project) {
    var files = project.files || {};
    var modules = ensureArray(project.modules);
    var counts = project.counts || {};
    var note = project.note || "";
    var displayPath = project.display_path || project.path || "";
    var timeAgo = relativeTime(project.last_modified || "");

    var badgesHtml = buildModuleBadges(modules);

    // Header
    var html = '<div class="overlay-header">' +
      '<div class="overlay-title-row">' +
        '<h2 class="overlay-title">' + escapeHtml(project.name) + '</h2>' +
        (timeAgo ? '<span class="overlay-time">' + escapeHtml(timeAgo) + '</span>' : '') +
        '<button class="overlay-close" title="Close">' + ICONS.close + '</button>' +
      '</div>' +
      '<div class="overlay-note" data-path="' + escapeAttr(project.path) + '">' +
        '<span class="overlay-note-text' + (note ? '' : ' overlay-note-placeholder') + '">' +
          escapeHtml(note || "Click to add a note...") +
        '</span>' +
      '</div>' +
      '<div class="overlay-path" data-folder="' + escapeAttr(project.path) + '" title="Open in file manager">' +
        ICONS.folder + ' <span>' + escapeHtml(displayPath) + '</span> ' + ICONS.externalLink +
      '</div>' +
      (badgesHtml ? '<div class="overlay-badges">' + badgesHtml + '</div>' : '') +
    '</div>';

    // File sections in columns
    html += '<div class="overlay-files">';

    // HTML Reports
    var htmlReports = ensureArray(files.html_reports);
    if (htmlReports.length > 0) {
      html += '<div class="overlay-section">' +
        '<div class="overlay-section-header">' + ICONS.html + ' HTML Reports</div>';
      for (var h = 0; h < htmlReports.length; h++) {
        var r = htmlReports[h];
        html += '<div class="overlay-file-item overlay-file-html" ' +
          'data-project-path="' + escapeAttr(project.path) + '" ' +
          'data-report-filename="' + escapeAttr(r.filename || "") + '" ' +
          'title="Open in report viewer">' +
          '<span class="overlay-file-name">' + escapeHtml(r.label || r.filename || "") + '</span>' +
          '<span class="overlay-file-date">' + escapeHtml(r.last_modified || "") + '</span>' +
          '<span class="overlay-file-size">' + escapeHtml(r.size_label || "") + '</span>' +
        '</div>';
      }
      html += '</div>';
    }

    // Config Files (with Run buttons)
    var configs = ensureArray(files.configs);
    if (configs.length > 0) {
      html += '<div class="overlay-section">' +
        '<div class="overlay-section-header">' + ICONS.excel + ' Config Files</div>';
      for (var c = 0; c < configs.length; c++) {
        var cf = configs[c];
        html += '<div class="overlay-file-item overlay-config-item">' +
          '<span class="overlay-file-open" data-file-path="' + escapeAttr(cf.path || "") + '" title="Open in Excel">' +
            '<span class="overlay-file-name">' + escapeHtml(cf.filename || "") + '</span>' +
          '</span>' +
          '<span class="overlay-file-date">' + escapeHtml(cf.last_modified || "") + '</span>' +
          '<span class="overlay-file-size">' + escapeHtml(cf.size_label || "") + '</span>';
        if (cf.script) {
          html += '<button class="overlay-run-btn" ' +
            'data-module="' + escapeAttr(cf.module || "") + '" ' +
            'data-config="' + escapeAttr(cf.path || "") + '" ' +
            'data-script="' + escapeAttr(cf.script || "") + '" ' +
            'title="Run ' + escapeAttr(cf.module_label || cf.module || "") + '">' +
            ICONS.play + ' Run' +
          '</button>';
        }
        html += '</div>';
      }
      html += '</div>';
    }

    // Data Files
    var dataFiles = ensureArray(files.data_files);
    if (dataFiles.length > 0) {
      html += buildOverlayFileSection("Data Files", ICONS.data, dataFiles);
    }

    // Excel Reports
    var excelReports = ensureArray(files.excel_reports);
    if (excelReports.length > 0) {
      html += buildOverlayFileSection("Excel Reports", ICONS.excel, excelReports);
    }

    // Diagnostics
    var diagnostics = ensureArray(files.diagnostics);
    if (diagnostics.length > 0) {
      html += buildOverlayFileSection("Diagnostics", ICONS.diagnostic, diagnostics);
    }

    html += '</div>';
    return html;
  }

  function buildOverlayFileSection(title, icon, files) {
    var html = '<div class="overlay-section">' +
      '<div class="overlay-section-header">' + icon + ' ' + escapeHtml(title) + '</div>';
    for (var i = 0; i < files.length; i++) {
      var f = files[i];
      html += '<div class="overlay-file-item overlay-file-open" ' +
        'data-file-path="' + escapeAttr(f.path || "") + '" ' +
        'title="Open in default application">' +
        '<span class="overlay-file-name">' + escapeHtml(f.filename || "") + '</span>' +
        '<span class="overlay-file-date">' + escapeHtml(f.last_modified || "") + '</span>' +
        '<span class="overlay-file-size">' + escapeHtml(f.size_label || "") + '</span>' +
      '</div>';
    }
    html += '</div>';
    return html;
  }

  function bindOverlayHandlers(overlay, project) {
    // Close button
    var closeBtn = overlay.querySelector(".overlay-close");
    if (closeBtn) {
      closeBtn.addEventListener("click", closeOverlay);
    }

    // Click outside content to close
    overlay.addEventListener("click", function(e) {
      if (e.target === overlay) closeOverlay();
    });

    // Escape key to close
    var escHandler = function(e) {
      if (e.key === "Escape") {
        closeOverlay();
        document.removeEventListener("keydown", escHandler);
      }
    };
    document.addEventListener("keydown", escHandler);

    // Path click
    var pathEl = overlay.querySelector(".overlay-path");
    if (pathEl) {
      pathEl.addEventListener("click", function() {
        HubApp.sendToShiny("hub_open_folder", project.path);
      });
    }

    // Note editing
    var noteEl = overlay.querySelector(".overlay-note");
    if (noteEl) {
      noteEl.addEventListener("click", function(e) {
        handleOverlayNoteClick(e, noteEl, project);
      });
    }

    // HTML report clicks
    var htmlItems = overlay.querySelectorAll(".overlay-file-html");
    for (var h = 0; h < htmlItems.length; h++) {
      htmlItems[h].addEventListener("click", function() {
        var projectPath = this.getAttribute("data-project-path");
        var reportFilename = this.getAttribute("data-report-filename");
        if (!projectPath) return;
        HubApp.state._pendingReportTarget = reportFilename || null;
        var title = HubApp.dom.projectTitle;
        if (title) title.textContent = project.name;
        HubApp.sendToShiny("hub_open_project", projectPath);
        closeOverlay();
        HubApp.showToast(reportFilename ? "Opening report..." : "Opening project...");
      });
    }

    // File open clicks
    var fileItems = overlay.querySelectorAll(".overlay-file-open");
    for (var f = 0; f < fileItems.length; f++) {
      fileItems[f].addEventListener("click", function(e) {
        var el = e.target.closest(".overlay-file-open") || this;
        var filePath = el.getAttribute("data-file-path");
        if (!filePath) return;
        HubApp.sendToShiny("hub_open_file", filePath);
        HubApp.showToast("Opening " + (filePath.split("/").pop() || "file") + "...");
      });
    }

    // Run buttons
    var runBtns = overlay.querySelectorAll(".overlay-run-btn");
    for (var r = 0; r < runBtns.length; r++) {
      runBtns[r].addEventListener("click", function(e) {
        e.stopPropagation();
        var moduleId = this.getAttribute("data-module");
        var configPath = this.getAttribute("data-config");
        var script = this.getAttribute("data-script");
        if (!moduleId || !script) return;
        HubApp.sendToShiny("hub_launch_module", JSON.stringify({
          module: moduleId,
          config_path: configPath,
          script: script
        }));
        HubApp.showToast("Launching " + moduleId + "...");
      });
    }
  }

  function handleOverlayNoteClick(e, noteEl, project) {
    e.stopPropagation();
    var textSpan = noteEl.querySelector(".overlay-note-text") ||
                   noteEl.querySelector(".overlay-note-placeholder");
    if (!textSpan) return;
    if (noteEl.querySelector("input")) return;

    var currentNote = textSpan.classList.contains("overlay-note-placeholder")
      ? "" : textSpan.textContent;

    var input = document.createElement("input");
    input.type = "text";
    input.className = "overlay-note-input";
    input.value = currentNote;
    input.placeholder = "Add a project note...";

    textSpan.style.display = "none";
    noteEl.appendChild(input);
    input.focus();
    input.select();

    var saveNote = function() {
      var newNote = input.value.trim();
      textSpan.textContent = newNote || "Click to add a note...";
      textSpan.className = newNote ? "overlay-note-text" : "overlay-note-text overlay-note-placeholder";
      textSpan.style.display = "";
      if (input.parentNode) input.parentNode.removeChild(input);

      HubApp.sendToShiny("hub_save_project_note", JSON.stringify({
        path: project.path,
        note: newNote
      }));

      project.note = newNote;
      // Also update in grid
      for (var i = 0; i < allProjects.length; i++) {
        if (allProjects[i].path === project.path) {
          allProjects[i].note = newNote;
          break;
        }
      }
    };

    input.addEventListener("blur", saveNote);
    input.addEventListener("keydown", function(ev) {
      if (ev.key === "Enter") input.blur();
      else if (ev.key === "Escape") {
        textSpan.style.display = "";
        if (input.parentNode) input.parentNode.removeChild(input);
      }
    });
  }


  // =========================================================================
  // Module Badges
  // =========================================================================

  function buildModuleBadges(modules) {
    if (!modules || modules.length === 0) return "";
    var html = "";
    var seen = {};
    for (var i = 0; i < modules.length; i++) {
      var mod = (modules[i] || "").toLowerCase();
      var mapped = TYPE_MAP[mod] || { label: mod, badge: "default" };
      if (seen[mapped.badge]) continue;
      seen[mapped.badge] = true;
      html += '<span class="tile-badge tile-badge-' + mapped.badge + '">' +
        escapeHtml(mapped.label) + '</span>';
    }
    return html;
  }


  // =========================================================================
  // Event Binding (grid tiles)
  // =========================================================================

  function bindTileHandlers() {
    var grid = HubApp.dom.projectGrid;
    if (!grid) return;

    // Toggle (expand to overlay)
    var toggles = grid.querySelectorAll(".tile-toggle");
    for (var t = 0; t < toggles.length; t++) {
      toggles[t].addEventListener("click", handleToggle);
    }

    // Tile name click = open overlay
    var names = grid.querySelectorAll(".tile-name");
    for (var n = 0; n < names.length; n++) {
      names[n].addEventListener("click", handleNameClick);
    }

    // Path click = open folder
    var paths = grid.querySelectorAll(".tile-path");
    for (var p = 0; p < paths.length; p++) {
      paths[p].addEventListener("click", handlePathClick);
    }

    // Note click = edit inline
    var notes = grid.querySelectorAll(".tile-note");
    for (var no = 0; no < notes.length; no++) {
      notes[no].addEventListener("click", handleNoteClick);
    }
  }


  function handleToggle(e) {
    e.stopPropagation();
    var id = this.getAttribute("data-id");
    if (id) openOverlay(id);
  }

  function handleNameClick(e) {
    e.stopPropagation();
    var tile = e.target.closest(".project-tile");
    if (!tile) return;
    var id = tile.getAttribute("data-id");
    if (id) openOverlay(id);
  }

  function handlePathClick(e) {
    e.stopPropagation();
    var folder = this.getAttribute("data-folder");
    if (!folder) return;
    HubApp.sendToShiny("hub_open_folder", folder);
  }

  function handleNoteClick(e) {
    e.stopPropagation();
    var noteDiv = this;
    var projectPath = noteDiv.getAttribute("data-path");
    var textSpan = noteDiv.querySelector(".tile-note-text");
    if (!textSpan || !projectPath) return;

    if (noteDiv.querySelector("input")) return;

    var currentNote = textSpan.classList.contains("tile-note-placeholder")
      ? "" : textSpan.textContent;

    var input = document.createElement("input");
    input.type = "text";
    input.className = "tile-note-input";
    input.value = currentNote;
    input.placeholder = "Add a project note...";

    textSpan.style.display = "none";
    noteDiv.appendChild(input);
    input.focus();
    input.select();

    var saveNote = function() {
      var newNote = input.value.trim();
      textSpan.textContent = newNote || "Click to add a note...";
      textSpan.className = "tile-note-text" + (newNote ? "" : " tile-note-placeholder");
      textSpan.style.display = "";
      if (input.parentNode) input.parentNode.removeChild(input);

      HubApp.sendToShiny("hub_save_project_note", JSON.stringify({
        path: projectPath,
        note: newNote
      }));

      for (var i = 0; i < allProjects.length; i++) {
        if (allProjects[i].path === projectPath) {
          allProjects[i].note = newNote;
          break;
        }
      }
    };

    input.addEventListener("blur", saveNote);
    input.addEventListener("keydown", function(ev) {
      if (ev.key === "Enter") input.blur();
      else if (ev.key === "Escape") {
        textSpan.style.display = "";
        if (input.parentNode) input.parentNode.removeChild(input);
      }
    });
  }


  // =========================================================================
  // Sorting
  // =========================================================================

  function sortProjects(projects) {
    var sorted = projects.slice();
    switch (currentSort) {
      case "name":
        sorted.sort(function(a, b) {
          return (a.name || "").localeCompare(b.name || "");
        });
        break;
      case "name-desc":
        sorted.sort(function(a, b) {
          return (b.name || "").localeCompare(a.name || "");
        });
        break;
      case "files":
        sorted.sort(function(a, b) {
          var ac = a.counts || {}, bc = b.counts || {};
          var totalA = (ac.html_reports || 0) + (ac.configs || 0) + (ac.data_files || 0) +
                       (ac.excel_reports || 0) + (ac.diagnostics || 0);
          var totalB = (bc.html_reports || 0) + (bc.configs || 0) + (bc.data_files || 0) +
                       (bc.excel_reports || 0) + (bc.diagnostics || 0);
          return totalB - totalA;
        });
        break;
      case "modules":
        sorted.sort(function(a, b) {
          return (ensureArray(b.modules).length) - (ensureArray(a.modules).length);
        });
        break;
      case "recent":
      default:
        sorted.sort(function(a, b) {
          return (b.last_modified_ts || 0) - (a.last_modified_ts || 0);
        });
        break;
    }
    return sorted;
  }


  // =========================================================================
  // Utility Functions
  // =========================================================================

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
      if (mins < 60) return mins + "m ago";

      var hrs = Math.floor(mins / 60);
      if (hrs < 24) return hrs + "h ago";

      var days = Math.floor(hrs / 24);
      if (days === 1) return "Yesterday";
      if (days < 7) return days + "d ago";
      if (days < 30) {
        var weeks = Math.floor(days / 7);
        return weeks + "w ago";
      }

      return dateStr.split(" ")[0];
    } catch (e) {
      return dateStr;
    }
  }

  function filter(query) {
    query = (query || "").toLowerCase().trim();

    var grid = HubApp.dom.projectGrid;
    var tiles = grid.querySelectorAll(".project-tile");
    var visibleCount = 0;

    for (var i = 0; i < tiles.length; i++) {
      var name = (tiles[i].querySelector(".tile-name") || {}).textContent || "";
      var badges = (tiles[i].querySelector(".tile-badges") || {}).textContent || "";
      var note = (tiles[i].querySelector(".tile-note-text") || {}).textContent || "";
      var path = (tiles[i].querySelector(".tile-path-text") || {}).textContent || "";

      var match = !query ||
        name.toLowerCase().indexOf(query) !== -1 ||
        badges.toLowerCase().indexOf(query) !== -1 ||
        note.toLowerCase().indexOf(query) !== -1 ||
        path.toLowerCase().indexOf(query) !== -1;

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

  // =========================================================================
  // Folder Discovery & Filtering
  // =========================================================================

  function discoverScanDirs() {
    var dirs = {};
    for (var i = 0; i < allProjects.length; i++) {
      var p = allProjects[i];
      var path = p.path || "";
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
    scanDirs.sort(function(a, b) {
      return b.count - a.count || a.label.localeCompare(b.label);
    });
  }

  function getParentPath(path) {
    if (!path) return "";
    var parts = path.replace(/\\/g, "/").split("/");
    parts.pop();
    return parts.join("/");
  }

  function abbreviatePath(path) {
    if (!path) return "";
    var display = path.replace(/\\/g, "/");

    // Try to use display_path from projects to find home dir
    for (var i = 0; i < allProjects.length; i++) {
      var dp = allProjects[i].display_path || "";
      var projPath = (allProjects[i].path || "").replace(/\\/g, "/");
      if (dp && projPath && projPath.indexOf(path) === 0) {
        var dpParts = dp.replace(/\\/g, "/").split("/");
        dpParts.pop();
        var parentDp = dpParts.join("/");
        if (parentDp) return parentDp;
      }
    }

    // Shorten cloud storage paths
    var cloudPrefixes = [
      { re: /.*\/CloudStorage\/OneDrive[^/]*\//, label: "OneDrive:/" },
      { re: /.*\/CloudStorage\/Dropbox[^/]*\//, label: "Dropbox:/" },
      { re: /.*\/CloudStorage\/GoogleDrive[^/]*\//, label: "GDrive:/" }
    ];
    for (var c = 0; c < cloudPrefixes.length; c++) {
      if (cloudPrefixes[c].re.test(display)) {
        display = display.replace(cloudPrefixes[c].re, cloudPrefixes[c].label);
        return display;
      }
    }

    // Home dir substitution
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

  function getVisibleProjects() {
    if (!activeFolder) return allProjects;
    return allProjects.filter(function(p) {
      var parent = getParentPath(p.path || "");
      return parent === activeFolder;
    });
  }

  // =========================================================================
  // Folder & Sort Dropdowns
  // =========================================================================

  function hideFolderSortBar() {
    var bar = document.getElementById("folder-sort-bar");
    if (bar) bar.style.display = "none";
  }

  function renderFolderSortBar() {
    var bar = document.getElementById("folder-sort-bar");
    if (!bar) return;

    bar.style.display = "flex";

    // Update folder dropdown label
    var folderLabel = document.getElementById("folder-dropdown-label");
    if (folderLabel) {
      if (activeFolder) {
        var activeDirLabel = "";
        for (var i = 0; i < scanDirs.length; i++) {
          if (scanDirs[i].path === activeFolder) {
            activeDirLabel = scanDirs[i].label;
            break;
          }
        }
        folderLabel.textContent = activeDirLabel || "Selected folder";
      } else {
        folderLabel.textContent = "All folders (" + scanDirs.length + ")";
      }
    }

    // Build folder dropdown menu
    var menu = document.getElementById("folder-dropdown-menu");
    if (menu) {
      var html = '<button class="folder-menu-item' + (!activeFolder ? ' folder-menu-item-active' : '') +
        '" data-folder="">All folders <span class="folder-menu-count">' + allProjects.length + '</span></button>';

      for (var d = 0; d < scanDirs.length; d++) {
        var dir = scanDirs[d];
        var isActive = (activeFolder === dir.path);
        html += '<button class="folder-menu-item' + (isActive ? ' folder-menu-item-active' : '') +
          '" data-folder="' + escapeAttr(dir.path) + '" title="' + escapeAttr(dir.path) + '">' +
          '<span class="folder-menu-label">' + escapeHtml(dir.label) + '</span>' +
          ' <span class="folder-menu-count">' + dir.count + '</span>' +
        '</button>';
      }
      menu.innerHTML = html;

      // Bind folder menu clicks
      var items = menu.querySelectorAll(".folder-menu-item");
      for (var mi = 0; mi < items.length; mi++) {
        items[mi].addEventListener("click", function() {
          var folder = this.getAttribute("data-folder") || null;
          activeFolder = folder;
          menu.style.display = "none";
          render(allProjects);
        });
      }
    }

    // Bind folder dropdown toggle
    var folderBtn = document.getElementById("folder-dropdown-btn");
    if (folderBtn && !folderBtn._bound) {
      folderBtn._bound = true;
      folderBtn.addEventListener("click", function(e) {
        e.stopPropagation();
        var m = document.getElementById("folder-dropdown-menu");
        var sm = document.getElementById("sort-dropdown-menu");
        if (sm) sm.style.display = "none";
        if (m) m.style.display = (m.style.display === "none") ? "block" : "none";
      });
    }

    // Bind sort dropdown toggle
    var sortBtn = document.getElementById("sort-dropdown-btn");
    if (sortBtn && !sortBtn._bound) {
      sortBtn._bound = true;
      sortBtn.addEventListener("click", function(e) {
        e.stopPropagation();
        var sm = document.getElementById("sort-dropdown-menu");
        var m = document.getElementById("folder-dropdown-menu");
        if (m) m.style.display = "none";
        if (sm) sm.style.display = (sm.style.display === "none") ? "block" : "none";
      });
    }

    // Bind sort options
    var sortMenu = document.getElementById("sort-dropdown-menu");
    if (sortMenu) {
      var sortOpts = sortMenu.querySelectorAll(".sort-option");
      for (var s = 0; s < sortOpts.length; s++) {
        sortOpts[s].className = "sort-option" +
          (sortOpts[s].getAttribute("data-sort") === currentSort ? " sort-option-active" : "");

        if (!sortOpts[s]._bound) {
          sortOpts[s]._bound = true;
          sortOpts[s].addEventListener("click", function() {
            currentSort = this.getAttribute("data-sort") || "recent";
            sortMenu.style.display = "none";
            // Update sort label
            var sortLabel = document.getElementById("sort-dropdown-label");
            if (sortLabel) sortLabel.textContent = this.textContent;
            render(allProjects);
          });
        }
      }
    }

    // Close dropdowns on outside click
    if (!document._folderSortClickBound) {
      document._folderSortClickBound = true;
      document.addEventListener("click", function() {
        var m = document.getElementById("folder-dropdown-menu");
        var sm = document.getElementById("sort-dropdown-menu");
        if (m) m.style.display = "none";
        if (sm) sm.style.display = "none";
      });
    }
  }

  function filterByFolder(folderPath) {
    activeFolder = folderPath || null;
    render(allProjects);
    var searchInput = HubApp.dom.projectSearch;
    if (searchInput) searchInput.value = "";
  }

  function removeFolder(folderPath) {
    if (!folderPath) return;
    HubApp.sendToShiny("hub_remove_dir", folderPath);
    if (activeFolder === folderPath) {
      activeFolder = null;
    }
  }

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
    setScanDirs: setScanDirs,
    openOverlay: openOverlay,
    closeOverlay: closeOverlay
  };
})();
