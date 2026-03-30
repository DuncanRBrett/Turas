/**
 * TurasPins Shared Library — Drag & Drop Reordering
 *
 * HTML5 Drag and Drop for reordering pin cards and section dividers.
 * Activated when config.features.dragDrop is true.
 * Uses data-pin-drag-idx attribute on draggable elements.
 *
 * Depends on: turas_pins.js (must be loaded first)
 * @namespace TurasPins
 */

/* global TurasPins */

(function() {
  "use strict";

  var _dragFromIdx = null;

  /**
   * Initialise drag/drop listeners. Called automatically by TurasPins.init()
   * when features.dragDrop is true. Safe to call multiple times.
   */
  TurasPins._initDragDrop = function() {
    // Prevent double-binding
    if (TurasPins._dragDropBound) return;
    TurasPins._dragDropBound = true;

    document.addEventListener("dragstart", _onDragStart);
    document.addEventListener("dragover", _onDragOver);
    document.addEventListener("dragleave", _onDragLeave);
    document.addEventListener("drop", _onDrop);
    document.addEventListener("dragend", _onDragEnd);
  };

  /** Handle drag start — capture source index */
  function _onDragStart(e) {
    var draggable = e.target.closest("[data-pin-drag-idx]");
    if (!draggable) return;
    if (e.target.isContentEditable ||
        e.target.tagName === "TEXTAREA" ||
        e.target.tagName === "INPUT") {
      e.preventDefault();
      return;
    }
    _dragFromIdx = parseInt(
      draggable.getAttribute("data-pin-drag-idx"), 10
    );
    draggable.classList.add("turas-pin-dragging");
    e.dataTransfer.effectAllowed = "move";
    _setDragGhost(draggable, e);
  }

  /** Handle drag over — show drop target indicator */
  function _onDragOver(e) {
    var target = e.target.closest("[data-pin-drag-idx]");
    if (!target || _dragFromIdx === null) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
    _clearDropTargets();
    target.classList.add("turas-pin-drop-target");
  }

  /** Handle drag leave — remove indicator */
  function _onDragLeave(e) {
    var target = e.target.closest("[data-pin-drag-idx]");
    if (target) target.classList.remove("turas-pin-drop-target");
  }

  /** Handle drop — execute reorder */
  function _onDrop(e) {
    e.preventDefault();
    _clearDragClasses();
    var target = e.target.closest("[data-pin-drag-idx]");
    if (!target || _dragFromIdx === null) return;
    var toIdx = parseInt(
      target.getAttribute("data-pin-drag-idx"), 10
    );
    if (_dragFromIdx !== toIdx) {
      TurasPins.moveByIndex(_dragFromIdx, toIdx);
    }
    _dragFromIdx = null;
  }

  /** Handle drag end — cleanup */
  function _onDragEnd() {
    _dragFromIdx = null;
    _clearDragClasses();
  }

  /** Create custom drag ghost showing item title */
  function _setDragGhost(draggable, e) {
    try {
      var titleEl = draggable.querySelector(
        "[class*='-card-title'], [class*='-section-title']"
      );
      var label = titleEl ?
        titleEl.textContent.substring(0, 30) : "Moving...";
      var ghost = document.createElement("div");
      ghost.style.cssText =
        "position:absolute;top:-999px;left:-999px;padding:8px 16px;" +
        "background:#e2e8f0;border-radius:6px;font-size:13px;" +
        "font-weight:500;color:#374151;white-space:nowrap;";
      ghost.textContent = label;
      document.body.appendChild(ghost);
      e.dataTransfer.setDragImage(ghost, 0, 0);
      setTimeout(function() {
        document.body.removeChild(ghost);
      }, 0);
    } catch (err) {
      // Drag ghost is cosmetic — failure is non-critical
    }
  }

  /** Remove all drop target indicators */
  function _clearDropTargets() {
    var targets = document.querySelectorAll(".turas-pin-drop-target");
    for (var i = 0; i < targets.length; i++) {
      targets[i].classList.remove("turas-pin-drop-target");
    }
  }

  /** Remove all drag-related CSS classes */
  function _clearDragClasses() {
    var els = document.querySelectorAll(
      ".turas-pin-drop-target, .turas-pin-dragging"
    );
    for (var i = 0; i < els.length; i++) {
      els[i].classList.remove(
        "turas-pin-drop-target", "turas-pin-dragging"
      );
    }
  }

})();
