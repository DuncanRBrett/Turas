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
  var currentSort = "recent";  // "recent" | "oldest" | "name" | "name-desc" | "files" | "modules"
  var activeTypeFilters = [];   // module type strings e.g. ["tabs", "tracker"]
  var pathSearchQuery = "";     // partial folder name match
  var dateFrom = null;          // Date object or null
  var dateTo = null;            // Date object or null

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
    externalLink: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>',
    misc: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>'
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
      hideFilterBar();
      return;
    }

    grid.style.display = "";
    empty.style.display = "none";

    discoverScanDirs();
    renderFilterBar();

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
    if (counts.misc) summaryParts.push(counts.misc + " misc");
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

    // HTML Reports — open in system browser
    var htmlReports = ensureArray(files.html_reports);
    if (htmlReports.length > 0) {
      html += '<div class="overlay-section">' +
        '<div class="overlay-section-header">' + ICONS.html + ' HTML Reports</div>';
      for (var h = 0; h < htmlReports.length; h++) {
        var r = htmlReports[h];
        var displayName = escapeHtml(r.filename || r.label || "");
        html += '<div class="overlay-file-item overlay-file-html" ' +
          'data-file-path="' + escapeAttr(r.path || "") + '" ' +
          'data-project-path="' + escapeAttr(project.path) + '" ' +
          'data-report-filename="' + escapeAttr(r.filename || "") + '" ' +
          'title="Open in browser">' +
          '<span class="overlay-file-name">' + displayName + '</span>' +
          ICONS.externalLink +
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

    // Misc (templates, parsed files, etc.)
    var misc = ensureArray(files.misc);
    if (misc.length > 0) {
      html += buildOverlayFileSection("Misc", ICONS.misc, misc);
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

    // HTML report clicks — open in system browser
    var htmlItems = overlay.querySelectorAll(".overlay-file-html");
    for (var h = 0; h < htmlItems.length; h++) {
      htmlItems[h].addEventListener("click", function() {
        var filePath = this.getAttribute("data-file-path");
        if (!filePath) return;
        HubApp.sendToShiny("hub_open_html_in_browser", filePath);
        HubApp.showToast("Opening in browser...");
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
                       (ac.excel_reports || 0) + (ac.diagnostics || 0) + (ac.misc || 0);
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
      case "oldest":
        sorted.sort(function(a, b) {
          return (a.last_modified_ts || 0) - (b.last_modified_ts || 0);
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
    return allProjects.filter(function(p) {
      // Folder filter
      if (activeFolder) {
        var parent = getParentPath(p.path || "");
        if (parent !== activeFolder) return false;
      }

      // Type filter (OR logic: project has ANY of selected types)
      if (activeTypeFilters.length > 0) {
        var projectModules = ensureArray(p.modules).map(function(m) {
          return (m || "").toLowerCase();
        });
        // Map to badge keys for matching
        var projectBadges = {};
        for (var t = 0; t < projectModules.length; t++) {
          var mapped = TYPE_MAP[projectModules[t]];
          if (mapped) projectBadges[mapped.badge] = true;
        }
        var hasMatch = false;
        for (var f = 0; f < activeTypeFilters.length; f++) {
          if (projectBadges[activeTypeFilters[f]]) { hasMatch = true; break; }
        }
        if (!hasMatch) return false;
      }

      // Path search (partial match)
      if (pathSearchQuery) {
        var matchPath = (p.display_path || p.path || "").toLowerCase();
        var matchName = (p.name || "").toLowerCase();
        if (matchPath.indexOf(pathSearchQuery) === -1 &&
            matchName.indexOf(pathSearchQuery) === -1) return false;
      }

      // Date range
      if (dateFrom || dateTo) {
        var projTs = (p.last_modified_ts || 0) * 1000;
        if (dateFrom && projTs < dateFrom.getTime()) return false;
        if (dateTo) {
          var endOfDay = new Date(dateTo);
          endOfDay.setHours(23, 59, 59, 999);
          if (projTs > endOfDay.getTime()) return false;
        }
      }

      return true;
    });
  }

  // =========================================================================
  // Filter Bar
  // =========================================================================

  function hideFilterBar() {
    var bar = document.getElementById("filter-bar");
    if (bar) bar.style.display = "none";
  }

  function renderFilterBar() {
    var bar = document.getElementById("filter-bar");
    if (!bar) return;

    bar.style.display = "";

    // --- Type filter dropdown ---
    renderTypeFilterMenu();

    // --- Folder dropdown ---
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

      var items = menu.querySelectorAll(".folder-menu-item");
      for (var mi = 0; mi < items.length; mi++) {
        items[mi].addEventListener("click", function() {
          activeFolder = this.getAttribute("data-folder") || null;
          menu.style.display = "none";
          render(allProjects);
        });
      }
    }

    // --- Bind dropdowns (once) ---
    bindDropdownToggle("folder-dropdown-btn", "folder-dropdown-menu");
    bindDropdownToggle("sort-dropdown-btn", "sort-dropdown-menu");
    bindDropdownToggle("type-filter-btn", "type-filter-menu");

    // --- Bind sort options ---
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
            var sortLabel = document.getElementById("sort-dropdown-label");
            if (sortLabel) sortLabel.textContent = this.textContent;
            render(allProjects);
          });
        }
      }
    }

    // --- Bind path search ---
    var pathInput = document.getElementById("filter-path-search");
    if (pathInput && !pathInput._bound) {
      pathInput._bound = true;
      pathInput.value = pathSearchQuery;
      pathInput.addEventListener("input", function() {
        pathSearchQuery = this.value.trim().toLowerCase();
        render(allProjects);
      });
    }

    // --- Bind date range ---
    var dateFromEl = document.getElementById("filter-date-from");
    var dateToEl = document.getElementById("filter-date-to");
    if (dateFromEl && !dateFromEl._bound) {
      dateFromEl._bound = true;
      dateFromEl.addEventListener("change", function() {
        dateFrom = this.value ? new Date(this.value) : null;
        render(allProjects);
      });
    }
    if (dateToEl && !dateToEl._bound) {
      dateToEl._bound = true;
      dateToEl.addEventListener("change", function() {
        dateTo = this.value ? new Date(this.value) : null;
        render(allProjects);
      });
    }

    // --- Bind clear button ---
    var clearBtn = document.getElementById("btn-clear-filters");
    if (clearBtn && !clearBtn._bound) {
      clearBtn._bound = true;
      clearBtn.addEventListener("click", clearAllFilters);
    }

    // --- Close dropdowns on outside click ---
    if (!document._filterClickBound) {
      document._filterClickBound = true;
      document.addEventListener("click", function() {
        var menus = document.querySelectorAll(".filter-dropdown-menu, .folder-dropdown-menu, .sort-dropdown-menu");
        for (var x = 0; x < menus.length; x++) menus[x].style.display = "none";
      });
    }

    // --- Render filter chips ---
    renderFilterChips();
  }

  function bindDropdownToggle(btnId, menuId) {
    var btn = document.getElementById(btnId);
    if (btn && !btn._bound) {
      btn._bound = true;
      btn.addEventListener("click", function(e) {
        e.stopPropagation();
        // Close all other dropdown menus
        var allMenus = document.querySelectorAll(".filter-dropdown-menu, .folder-dropdown-menu, .sort-dropdown-menu");
        for (var x = 0; x < allMenus.length; x++) {
          if (allMenus[x].id !== menuId) allMenus[x].style.display = "none";
        }
        var m = document.getElementById(menuId);
        if (m) m.style.display = (m.style.display === "none") ? "block" : "none";
      });
    }
  }

  function renderTypeFilterMenu() {
    var menu = document.getElementById("type-filter-menu");
    if (!menu) return;

    // Discover all unique module types across projects
    var allTypes = {};
    for (var i = 0; i < allProjects.length; i++) {
      var mods = ensureArray(allProjects[i].modules);
      for (var m = 0; m < mods.length; m++) {
        var mod = (mods[m] || "").toLowerCase();
        var mapped = TYPE_MAP[mod];
        if (mapped && !allTypes[mapped.badge]) {
          allTypes[mapped.badge] = { label: mapped.label, count: 0 };
        }
        if (mapped) allTypes[mapped.badge].count++;
      }
    }

    var html = '';
    for (var key in allTypes) {
      var checked = activeTypeFilters.indexOf(key) !== -1;
      html += '<label class="filter-checkbox-item">' +
        '<input type="checkbox" value="' + escapeAttr(key) + '"' +
        (checked ? ' checked' : '') + '>' +
        '<span class="tile-badge tile-badge-' + key + '">' +
        escapeHtml(allTypes[key].label) + '</span>' +
        '<span class="filter-count">' + allTypes[key].count + '</span>' +
      '</label>';
    }
    menu.innerHTML = html;

    // Bind checkbox changes
    var checkboxes = menu.querySelectorAll('input[type="checkbox"]');
    for (var c = 0; c < checkboxes.length; c++) {
      checkboxes[c].addEventListener("change", function(e) {
        e.stopPropagation();
        activeTypeFilters = [];
        var allCbs = menu.querySelectorAll('input[type="checkbox"]:checked');
        for (var x = 0; x < allCbs.length; x++) {
          activeTypeFilters.push(allCbs[x].value);
        }
        // Update label
        var typeLabel = document.getElementById("type-filter-label");
        if (typeLabel) {
          typeLabel.textContent = activeTypeFilters.length === 0
            ? "All types"
            : activeTypeFilters.length + " type" + (activeTypeFilters.length !== 1 ? "s" : "");
        }
        render(allProjects);
      });
    }
  }

  function renderFilterChips() {
    var container = document.getElementById("filter-chips");
    var clearBtn = document.getElementById("btn-clear-filters");
    if (!container) return;

    var chips = [];
    var hasFilters = false;

    for (var i = 0; i < activeTypeFilters.length; i++) {
      hasFilters = true;
      var mapped = TYPE_MAP[activeTypeFilters[i]] || { label: activeTypeFilters[i] };
      chips.push('<span class="filter-chip">' + escapeHtml(mapped.label) +
        '<button class="filter-chip-remove" data-chip-type="type" ' +
        'data-chip-value="' + escapeAttr(activeTypeFilters[i]) + '">&times;</button></span>');
    }

    if (activeFolder) {
      hasFilters = true;
      var dirLabel = abbreviatePath(activeFolder);
      chips.push('<span class="filter-chip">' + escapeHtml(dirLabel) +
        '<button class="filter-chip-remove" data-chip-type="folder">&times;</button></span>');
    }

    if (pathSearchQuery) {
      hasFilters = true;
      chips.push('<span class="filter-chip">Path: "' + escapeHtml(pathSearchQuery) +
        '"<button class="filter-chip-remove" data-chip-type="path">&times;</button></span>');
    }

    if (dateFrom || dateTo) {
      hasFilters = true;
      var dateLabel = (dateFrom ? formatDate(dateFrom) : "...") +
        " \u2013 " + (dateTo ? formatDate(dateTo) : "...");
      chips.push('<span class="filter-chip">' + escapeHtml(dateLabel) +
        '<button class="filter-chip-remove" data-chip-type="date">&times;</button></span>');
    }

    container.innerHTML = chips.join("");
    container.style.display = hasFilters ? "flex" : "none";
    if (clearBtn) clearBtn.style.display = hasFilters ? "" : "none";

    // Bind chip remove clicks
    var removeBtns = container.querySelectorAll(".filter-chip-remove");
    for (var r = 0; r < removeBtns.length; r++) {
      removeBtns[r].addEventListener("click", function(e) {
        e.stopPropagation();
        var chipType = this.getAttribute("data-chip-type");
        var chipValue = this.getAttribute("data-chip-value");
        if (chipType === "type" && chipValue) {
          activeTypeFilters = activeTypeFilters.filter(function(t) { return t !== chipValue; });
        } else if (chipType === "folder") {
          activeFolder = null;
        } else if (chipType === "path") {
          pathSearchQuery = "";
          var pathInput = document.getElementById("filter-path-search");
          if (pathInput) pathInput.value = "";
        } else if (chipType === "date") {
          dateFrom = null;
          dateTo = null;
          var df = document.getElementById("filter-date-from");
          var dt = document.getElementById("filter-date-to");
          if (df) df.value = "";
          if (dt) dt.value = "";
        }
        render(allProjects);
      });
    }
  }

  function clearAllFilters() {
    activeFolder = null;
    activeTypeFilters = [];
    pathSearchQuery = "";
    dateFrom = null;
    dateTo = null;

    var pathInput = document.getElementById("filter-path-search");
    if (pathInput) pathInput.value = "";
    var df = document.getElementById("filter-date-from");
    var dt = document.getElementById("filter-date-to");
    if (df) df.value = "";
    if (dt) dt.value = "";

    render(allProjects);
  }

  function formatDate(d) {
    if (!d) return "";
    var y = d.getFullYear();
    var m = String(d.getMonth() + 1).padStart(2, "0");
    var day = String(d.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + day;
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
