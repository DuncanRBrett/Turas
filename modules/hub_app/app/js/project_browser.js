/**
 * Turas Hub App — Project Browser
 *
 * Renders project cards in a grid layout. Each card shows the project name,
 * path, report count, types, and last modified date. Clicking a card
 * tells the R backend to open that project.
 */

var ProjectBrowser = (function() {
  "use strict";

  var allProjects = [];

  /**
   * Render the project grid from an array of project objects.
   * @param {Array} projects - Array from scan_for_projects()
   */
  function render(projects) {
    allProjects = projects || [];

    var grid = HubApp.dom.projectGrid;
    var empty = HubApp.dom.projectEmpty;
    var loading = HubApp.dom.projectLoading;
    var count = HubApp.dom.projectCount;

    // Hide loading
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

    // Build card HTML
    var html = "";
    for (var i = 0; i < allProjects.length; i++) {
      html += buildProjectCard(allProjects[i]);
    }
    grid.innerHTML = html;

    // Bind click handlers
    var cards = grid.querySelectorAll(".project-card");
    for (var c = 0; c < cards.length; c++) {
      cards[c].addEventListener("click", handleCardClick);
    }
  }

  /**
   * Build HTML string for a single project card.
   * @param {object} project - Project object from R
   * @returns {string} HTML string
   */
  function buildProjectCard(project) {
    var reportCount = project.report_count || 0;
    var types = getUniqueTypes(project.reports || []);
    var typeBadges = "";
    for (var t = 0; t < types.length; t++) {
      typeBadges += '<span class="type-badge">' + escapeHtml(types[t]) + '</span>';
    }

    // Shorten path for display
    var displayPath = project.path || "";
    var home = "";
    try {
      // Try to detect home directory from path
      var parts = displayPath.split("/");
      if (parts.length > 3 && parts[1] === "Users") {
        displayPath = "~/" + parts.slice(3).join("/");
      }
    } catch (e) { /* keep original */ }

    return '<div class="project-card" data-path="' + escapeAttr(project.path) + '">' +
      '<div class="project-card-name">' + escapeHtml(project.name) + '</div>' +
      '<div class="project-card-path">' + escapeHtml(displayPath) + '</div>' +
      '<div class="project-card-meta">' +
        '<div class="project-card-meta-item">' +
          '<span class="meta-dot"></span>' +
          reportCount + ' report' + (reportCount !== 1 ? 's' : '') +
        '</div>' +
        '<div class="project-card-meta-item">' +
          escapeHtml(project.total_size_label || '') +
        '</div>' +
        '<div class="project-card-meta-item">' +
          escapeHtml(project.last_modified || '') +
        '</div>' +
      '</div>' +
      (typeBadges ? '<div class="project-card-types">' + typeBadges + '</div>' : '') +
    '</div>';
  }

  /**
   * Handle click on a project card.
   * Sends the project path to R to open it.
   */
  function handleCardClick() {
    var path = this.getAttribute("data-path");
    if (!path) return;

    // Show loading state in the reports view
    var title = HubApp.dom.projectTitle;
    if (title) {
      // Find project name from our data
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
   * @param {string} query - Search string
   */
  function filter(query) {
    query = (query || "").toLowerCase().trim();

    var grid = HubApp.dom.projectGrid;
    var cards = grid.querySelectorAll(".project-card");

    var visibleCount = 0;

    for (var i = 0; i < cards.length; i++) {
      var name = (cards[i].querySelector(".project-card-name") || {}).textContent || "";
      var path = (cards[i].querySelector(".project-card-path") || {}).textContent || "";
      var types = (cards[i].querySelector(".project-card-types") || {}).textContent || "";

      var match = !query ||
        name.toLowerCase().indexOf(query) !== -1 ||
        path.toLowerCase().indexOf(query) !== -1 ||
        types.toLowerCase().indexOf(query) !== -1;

      cards[i].style.display = match ? "" : "none";
      if (match) visibleCount++;
    }

    // Update count
    var count = HubApp.dom.projectCount;
    if (count) {
      if (query) {
        count.textContent = visibleCount + " of " + allProjects.length;
      } else {
        count.textContent = allProjects.length + " project" +
          (allProjects.length !== 1 ? "s" : "");
      }
    }

    // Show empty state if no matches
    var empty = HubApp.dom.projectEmpty;
    if (empty) {
      empty.style.display = (visibleCount === 0 && allProjects.length > 0) ? "" : "none";
    }
  }

  /**
   * Extract unique report types from a reports array.
   * @param {Array} reports
   * @returns {Array} Unique type strings
   */
  function getUniqueTypes(reports) {
    var seen = {};
    var types = [];
    for (var i = 0; i < reports.length; i++) {
      var t = reports[i].type;
      if (t && !seen[t]) {
        seen[t] = true;
        types.push(t);
      }
    }
    return types;
  }

  /**
   * Escape HTML special characters.
   * @param {string} str
   * @returns {string}
   */
  function escapeHtml(str) {
    if (!str) return "";
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  /**
   * Escape a string for use in an HTML attribute.
   * @param {string} str
   * @returns {string}
   */
  function escapeAttr(str) {
    if (!str) return "";
    return str
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  // --- Public API ---
  return {
    render: render,
    filter: filter
  };
})();
