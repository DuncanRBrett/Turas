/**
 * seg_pinned_views.js - Pin/unpin sections for presentation mode
 * in Turas Segment HTML reports.
 * Clones sections into a pinned container, persists state in a hidden element,
 * and restores pinned views on page hydration.
 */
(function() {
  'use strict';

  var pinnedSections = [];

  /**
   * Pin or unpin a section by its data key.
   * If already pinned, removes it (toggle behavior).
   * If not pinned, clones the section into the pinned container.
   * @param {string} sectionKey - Value of data-seg-section attribute
   */
  window.segPinSection = function(sectionKey) {
    if (!sectionKey) return;

    var section = document.querySelector('[data-seg-section="' + sectionKey + '"]');
    if (!section) return;

    // Toggle: remove if already pinned
    var existing = document.querySelector(
      '.seg-pinned-item[data-seg-pinned="' + sectionKey + '"]'
    );
    if (existing) {
      existing.remove();
      pinnedSections = pinnedSections.filter(function(s) {
        return s !== sectionKey;
      });
      updatePinnedStore();
      return;
    }

    // Clone the section
    var clone = section.cloneNode(true);
    clone.classList.add('seg-pinned-item');
    clone.setAttribute('data-seg-pinned', sectionKey);

    // Add remove button at the top of the cloned section
    var removeBtn = document.createElement('button');
    removeBtn.className = 'seg-pinned-remove';
    removeBtn.textContent = '\u00d7';
    removeBtn.title = 'Unpin this section';
    removeBtn.onclick = function() {
      clone.remove();
      pinnedSections = pinnedSections.filter(function(s) {
        return s !== sectionKey;
      });
      updatePinnedStore();
    };
    clone.insertBefore(removeBtn, clone.firstChild);

    // Append to pinned container
    var container = document.getElementById('seg-pinned-container');
    if (container) {
      container.appendChild(clone);
    }

    pinnedSections.push(sectionKey);
    updatePinnedStore();
  };

  /**
   * Persist the current pinned section keys into a hidden data element.
   * This allows the state to survive when the report HTML is saved.
   */
  function updatePinnedStore() {
    var store = document.getElementById('seg-pinned-views-data');
    if (store) {
      store.textContent = JSON.stringify(pinnedSections);
    }

    // Update visibility of the pinned container
    var container = document.getElementById('seg-pinned-container');
    if (container) {
      container.style.display = pinnedSections.length > 0 ? '' : 'none';
    }
  }

  /**
   * Restore pinned views from the persisted data element.
   * Called during page hydration to reconstruct pinned sections
   * from a previously saved report.
   */
  window.segHydratePinnedViews = function() {
    var store = document.getElementById('seg-pinned-views-data');
    if (!store) return;

    try {
      var saved = JSON.parse(store.textContent);
      if (!Array.isArray(saved) || saved.length === 0) return;

      // Clear existing pinned state before rehydrating
      pinnedSections = [];
      var container = document.getElementById('seg-pinned-container');
      if (container) {
        var items = container.querySelectorAll('.seg-pinned-item');
        for (var i = 0; i < items.length; i++) {
          items[i].remove();
        }
      }

      // Re-pin each saved section
      for (var j = 0; j < saved.length; j++) {
        if (typeof saved[j] === 'string') {
          window.segPinSection(saved[j]);
        }
      }
    } catch (e) {
      // Silently ignore malformed data
    }
  };
})();
