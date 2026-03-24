/**
 * Turas Hub App — Core Application
 *
 * Initialises the app, manages view routing, and provides the
 * communication bridge between the vanilla JS frontend and the
 * Shiny R backend via Shiny.setInputValue / sendCustomMessage.
 */

var HubApp = (function() {
  "use strict";

  // ---- State ----
  var state = {
    projects: [],
    activeView: "projects",    // "projects" | "reports"
    activeProject: null,       // project object
    activeReports: [],         // report objects with URLs
    pinBoardVisible: false     // pin board side panel toggle
  };

  // ---- DOM References ----
  var dom = {};

  /**
   * Initialise the application.
   * Called once on page load. Sets up Shiny message handlers,
   * event listeners, and waits for project data from R.
   */
  function init() {
    // Cache DOM references
    dom.viewProjects = document.getElementById("view-projects");
    dom.viewReports = document.getElementById("view-reports");
    dom.projectGrid = document.getElementById("project-grid");
    dom.projectEmpty = document.getElementById("project-empty");
    dom.projectLoading = document.getElementById("project-loading");
    dom.projectCount = document.getElementById("project-count");
    dom.projectSearch = document.getElementById("project-search");
    dom.projectTitle = document.getElementById("project-title");
    dom.reportCount = document.getElementById("report-count");
    dom.reportTabs = document.getElementById("report-tabs");
    dom.reportContainer = document.getElementById("report-container");
    dom.reportLoading = document.getElementById("report-loading");
    dom.btnBack = document.getElementById("btn-back");
    dom.btnSearch = document.getElementById("btn-search");
    dom.btnPreferences = document.getElementById("btn-preferences");
    dom.btnRescan = document.getElementById("btn-rescan");
    dom.btnTogglePins = document.getElementById("btn-toggle-pins");
    dom.btnAddSection = document.getElementById("btn-add-section");
    dom.btnToggleAnnotations = document.getElementById("btn-toggle-annotations");
    dom.btnGenerateHub = document.getElementById("btn-generate-hub");
    dom.btnExportPdf = document.getElementById("btn-export-pdf");
    dom.btnExportPptx = document.getElementById("btn-export-pptx");
    dom.btnExportPngs = document.getElementById("btn-export-pngs");
    dom.pinBoardPanel = document.getElementById("pin-board-panel");
    dom.reportsLayout = document.getElementById("reports-layout");
    dom.toast = document.getElementById("toast");

    // Initialise persistence layer
    HubState.init();

    // Initialise annotations
    Annotations.init();

    // Initialise search
    Search.init();

    // Register state change listener — when sidecar data arrives, hydrate PinBoard
    HubState.onChange(function(eventType, items) {
      if (eventType === "hydrate-sidecar" || eventType === "hydrate-cache") {
        PinBoard.hydrate(items);
      }
    });

    // Register Shiny custom message handlers
    registerShinyHandlers();

    // Wire up UI event listeners
    bindEvents();
  }

  /**
   * Register handlers for messages sent from R via session$sendCustomMessage.
   * Uses polling to wait for Shiny to be available (the frontend loads
   * inside an iframe, so Shiny's JS may not be on this window).
   */
  function registerShinyHandlers() {
    // The Hub App frontend runs inside an iframe hosted by Shiny.
    // Shiny's JS API lives on the PARENT window, not this one.
    var shiny = findShiny();

    if (!shiny) {
      // Shiny not ready yet — retry
      setTimeout(registerShinyHandlers, 100);
      return;
    }

    shiny.addCustomMessageHandler("hub_projects", function(jsonStr) {
      var projects = parseJSON(jsonStr);
      if (projects) {
        state.projects = projects;
        ProjectBrowser.render(projects);

        // Auto-open last project if we're on the projects view and haven't opened anything yet
        if (state.activeView === "projects" && !state.activeProject && !state._autoOpenAttempted) {
          state._autoOpenAttempted = true;
          HubState.getLastProject(function(lastProject) {
            if (!lastProject || !lastProject.path) return;
            // Verify the last project is still in the scanned list
            var found = false;
            for (var i = 0; i < projects.length; i++) {
              if (projects[i].path === lastProject.path) {
                found = true;
                break;
              }
            }
            if (found && state.activeView === "projects") {
              console.log("[Hub App] Auto-opening last project:", lastProject.name);
              sendToShiny("hub_open_project", lastProject.path);
            }
          });
        }
      }
    });

    shiny.addCustomMessageHandler("hub_report_list", function(jsonStr) {
      var data = parseJSON(jsonStr);
      if (data) {
        state.activeProject = {
          name: data.project_name,
          path: data.project_path
        };
        state.activeReports = data.reports;
        showView("reports");
        ReportViewer.render(data);

        // Save as last-opened project
        HubState.saveLastProject(data.project_path, data.project_name);

        // Load pins for this project from sidecar
        HubState.loadForProject(data.project_path);

        // Load annotations for this project
        sendToShiny("hub_load_annotations", data.project_path);
      }
    });

    shiny.addCustomMessageHandler("hub_error", function(msg) {
      showToast("Error: " + msg, 5000);
    });

    shiny.addCustomMessageHandler("hub_save_confirm", function(type) {
      showToast("Saved " + type + " successfully");
    });

    shiny.addCustomMessageHandler("hub_export_complete", function(jsonStr) {
      var data = parseJSON(jsonStr);
      ExportManager.handlePptxComplete(data);
    });

    shiny.addCustomMessageHandler("hub_export_pngs_complete", function(jsonStr) {
      var data = parseJSON(jsonStr);
      ExportManager.handlePngZipComplete(data);
    });

    shiny.addCustomMessageHandler("hub_generate_complete", function(jsonStr) {
      var data = parseJSON(jsonStr);
      ExportManager.handleHubGenerateComplete(data);
    });

    shiny.addCustomMessageHandler("hub_pins_loaded", function(jsonStr) {
      if (jsonStr && jsonStr !== "null") {
        var data = parseJSON(jsonStr);
        if (data) {
          console.log("[Hub App] Loaded", data.pins ? data.pins.length : 0, "pins from sidecar");
          HubState.handleSidecarLoaded(data);
        }
      }
    });

    shiny.addCustomMessageHandler("hub_annotations_loaded", function(jsonStr) {
      if (jsonStr && jsonStr !== "null") {
        var data = parseJSON(jsonStr);
        if (data) {
          console.log("[Hub App] Loaded annotations from sidecar");
          Annotations.load(data);
        }
      } else {
        Annotations.load(null);
      }
    });

    shiny.addCustomMessageHandler("hub_save_annotations_confirm", function(msg) {
      // Silent confirmation — no toast for auto-save
    });

    shiny.addCustomMessageHandler("hub_preferences_loaded", function(jsonStr) {
      var data = parseJSON(jsonStr);
      if (data) {
        Preferences.load(data);
      }
    });

    shiny.addCustomMessageHandler("hub_search_results", function(jsonStr) {
      var data = parseJSON(jsonStr);
      Search.handleResults(data);
    });
  }

  /**
   * Find the Shiny object. It may be on this window (if running standalone)
   * or on the parent window (if embedded in a Shiny iframe).
   * @returns {object|null} Shiny object or null
   */
  function findShiny() {
    // Check this window first
    if (window.Shiny && window.Shiny.addCustomMessageHandler) {
      return window.Shiny;
    }
    // Check parent (Hub App runs in an iframe inside Shiny)
    try {
      if (window.parent && window.parent.Shiny &&
          window.parent.Shiny.addCustomMessageHandler) {
        return window.parent.Shiny;
      }
    } catch (e) {
      // Cross-origin — ignore
    }
    return null;
  }

  /**
   * Send a value to the Shiny server via setInputValue.
   * @param {string} name - Input name
   * @param {*} value - Value to send
   */
  function sendToShiny(name, value) {
    var shiny = findShiny();
    if (shiny && shiny.setInputValue) {
      shiny.setInputValue(name, value, { priority: "event" });
      return true;
    } else {
      console.warn("[Hub App] Shiny not available, cannot send:", name);
      return false;
    }
  }

  /**
   * Bind UI event listeners.
   */
  function bindEvents() {
    // Back button
    if (dom.btnBack) {
      dom.btnBack.addEventListener("click", function() {
        ReportViewer.cleanup();
        sendToShiny("hub_back_to_projects", Math.random());
        showView("projects");
      });
    }

    // Search button
    if (dom.btnSearch) {
      dom.btnSearch.addEventListener("click", function() {
        Search.show();
      });
    }

    // Preferences button
    if (dom.btnPreferences) {
      dom.btnPreferences.addEventListener("click", function() {
        Preferences.show();
      });
    }

    // Rescan button
    if (dom.btnRescan) {
      dom.btnRescan.addEventListener("click", function() {
        dom.projectLoading.style.display = "";
        dom.projectGrid.style.display = "none";
        dom.projectEmpty.style.display = "none";
        sendToShiny("hub_rescan", Math.random());
      });
    }

    // Project search filter
    if (dom.projectSearch) {
      dom.projectSearch.addEventListener("input", function() {
        ProjectBrowser.filter(this.value);
      });
    }

    // Pin board toggle
    if (dom.btnTogglePins) {
      dom.btnTogglePins.addEventListener("click", function() {
        togglePinBoard();
      });
    }

    // Add section divider
    if (dom.btnAddSection) {
      dom.btnAddSection.addEventListener("click", function() {
        PinBoard.addSection();
      });
    }

    // Annotations toggle
    if (dom.btnToggleAnnotations) {
      dom.btnToggleAnnotations.addEventListener("click", function() {
        Annotations.toggle();
        this.classList.toggle("active");
      });
    }

    // Generate Hub
    if (dom.btnGenerateHub) {
      dom.btnGenerateHub.addEventListener("click", function() {
        ExportManager.generateHub();
      });
    }

    // Export PDF
    if (dom.btnExportPdf) {
      dom.btnExportPdf.addEventListener("click", function() {
        ExportManager.exportPdf();
      });
    }

    // Export PPTX
    if (dom.btnExportPptx) {
      dom.btnExportPptx.addEventListener("click", function() {
        ExportManager.exportPptx();
      });
    }

    // Export all PNGs
    if (dom.btnExportPngs) {
      dom.btnExportPngs.addEventListener("click", function() {
        ExportManager.exportAllPngs();
      });
    }
  }

  /**
   * Switch between views.
   * @param {string} viewName - "projects" or "reports"
   */
  function showView(viewName) {
    state.activeView = viewName;

    dom.viewProjects.classList.toggle("active", viewName === "projects");
    dom.viewReports.classList.toggle("active", viewName === "reports");

    // Reset search when returning to projects
    if (viewName === "projects") {
      if (dom.projectSearch) {
        dom.projectSearch.value = "";
        ProjectBrowser.filter("");
      }
      // Close pin board and clear state
      state.pinBoardVisible = false;
      if (dom.pinBoardPanel) dom.pinBoardPanel.style.display = "none";
      if (dom.reportsLayout) dom.reportsLayout.classList.remove("pin-board-open");
      if (dom.btnTogglePins) dom.btnTogglePins.classList.remove("active");
      if (dom.btnAddSection) dom.btnAddSection.style.display = "none";
      if (dom.btnToggleAnnotations) dom.btnToggleAnnotations.classList.remove("active");
      Annotations.clear();
      HubState.clearProject();
    }
  }

  /**
   * Toggle the pin board side panel visibility.
   */
  function togglePinBoard() {
    state.pinBoardVisible = !state.pinBoardVisible;

    if (dom.pinBoardPanel) {
      dom.pinBoardPanel.style.display = state.pinBoardVisible ? "" : "none";
    }
    if (dom.reportsLayout) {
      dom.reportsLayout.classList.toggle("pin-board-open", state.pinBoardVisible);
    }
    if (dom.btnTogglePins) {
      dom.btnTogglePins.classList.toggle("active", state.pinBoardVisible);
    }
    if (dom.btnAddSection) {
      dom.btnAddSection.style.display = state.pinBoardVisible ? "" : "none";
    }
  }

  /**
   * Show a toast notification.
   * @param {string} message - Text to display
   * @param {number} [duration=2500] - Display duration in ms
   */
  function showToast(message, duration) {
    duration = duration || 2500;

    if (!dom.toast) return;
    dom.toast.textContent = message;
    dom.toast.classList.add("visible");

    clearTimeout(dom.toast._timeout);
    dom.toast._timeout = setTimeout(function() {
      dom.toast.classList.remove("visible");
    }, duration);
  }

  /**
   * Safely parse a JSON string. Returns null on failure.
   * Handles both raw JSON strings and pre-parsed objects
   * (Shiny sometimes pre-parses).
   * @param {string|object} input
   * @returns {*|null}
   */
  function parseJSON(input) {
    if (typeof input === "object" && input !== null) return input;
    if (typeof input !== "string") return null;
    try {
      return JSON.parse(input);
    } catch (e) {
      console.error("[Hub App] JSON parse error:", e.message);
      return null;
    }
  }

  // --- Public API ---
  return {
    init: init,
    sendToShiny: sendToShiny,
    showView: showView,
    showToast: showToast,
    parseJSON: parseJSON,
    state: state,
    dom: dom
  };
})();


// Initialise on DOM ready
document.addEventListener("DOMContentLoaded", function() {
  HubApp.init();
});
