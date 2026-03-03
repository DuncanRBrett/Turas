/* ==============================================================================
 * CATDRIVER HTML REPORT - NAVIGATION JS
 * ==============================================================================
 * Horizontal section nav bar, factor picker (with prefix scoping),
 * OR factor chip filtering, save report, hydrate, and print.
 * Supports multiple section nav bars (unified mode: one per analysis panel).
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // --------------------------------------------------------------------------
  // Section navigation — horizontal bar(s) (.cd-section-nav)
  // In single-report mode there is one nav bar; in unified mode there is
  // one per analysis panel.  Each is independently tracked.
  // --------------------------------------------------------------------------

  var navGroups = [];  // array of { navBar, links, sections }

  function initNavBars() {
    var allNavBars = document.querySelectorAll('.cd-section-nav');

    allNavBars.forEach(function(navBar) {
      var links = navBar.querySelectorAll('a');
      var sections = [];

      links.forEach(function(link) {
        var href = link.getAttribute('href');
        if (href && href.startsWith('#')) {
          var section = document.getElementById(href.slice(1));
          if (section) {
            sections.push({ el: section, link: link });
          }
        }

        link.addEventListener('click', function(e) {
          e.preventDefault();
          var target = document.getElementById(href.slice(1));
          if (target) {
            // Total sticky offset: tab bar (if present) + this nav bar
            var tabBar = document.querySelector('.cd-analysis-tabs');
            var tabBarHeight = tabBar ? tabBar.offsetHeight : 0;
            var navHeight = navBar.offsetHeight;
            var totalOffset = tabBarHeight + navHeight + 8;
            var targetY = target.getBoundingClientRect().top + window.scrollY - totalOffset;
            window.scrollTo({ top: targetY, behavior: 'smooth' });
          }
        });
      });

      navGroups.push({ navBar: navBar, links: links, sections: sections });
    });
  }

  function updateActiveNav() {
    navGroups.forEach(function(group) {
      if (group.sections.length === 0) return;

      // Only update if this nav bar is visible (its panel is active)
      var panel = group.navBar.closest('.cd-analysis-panel');
      if (panel && !panel.classList.contains('active')) return;

      var tabBar = document.querySelector('.cd-analysis-tabs');
      var tabBarHeight = tabBar ? tabBar.offsetHeight : 0;
      var navHeight = group.navBar.offsetHeight;
      var scrollY = window.scrollY + tabBarHeight + navHeight + 40;
      var active = null;

      for (var i = group.sections.length - 1; i >= 0; i--) {
        if (group.sections[i].el.offsetTop <= scrollY) {
          active = group.sections[i];
          break;
        }
      }

      group.links.forEach(function(link) { link.classList.remove('active'); });
      if (active) {
        active.link.classList.add('active');
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    initNavBars();
    updateActiveNav();
    // Hydrate saved state
    cdHydratePage();
  });

  window.addEventListener('scroll', updateActiveNav, { passive: true });

  // --------------------------------------------------------------------------
  // Factor picker — scoped by optional id_prefix
  // Called as cdShowFactor('varId', 'prefix-') or cdShowFactor('varId', '')
  // --------------------------------------------------------------------------
  window.cdShowFactor = function(factorId, prefix) {
    prefix = prefix || '';

    // Find the container section (the patterns section for this prefix)
    var containerId = prefix + 'cd-patterns';
    var container = document.getElementById(containerId) || document;

    // Deactivate all tabs and panels within this container
    container.querySelectorAll('.cd-factor-tab').forEach(function(tab) {
      tab.classList.remove('active');
    });
    container.querySelectorAll('.cd-factor-panel').forEach(function(panel) {
      panel.classList.remove('active');
    });

    // Activate selected — data-factor includes prefix
    var tab = container.querySelector('.cd-factor-tab[data-factor="' + prefix + factorId + '"]');
    var panel = document.getElementById(prefix + 'cd-panel-' + factorId);

    if (tab) tab.classList.add('active');
    if (panel) panel.classList.add('active');
  };

  // --------------------------------------------------------------------------
  // OR factor chip filtering
  // Toggle chip on/off, show/hide OR table rows by data-cd-factor attribute.
  // All chips start active (all rows visible). Toggling off hides matching rows.
  // --------------------------------------------------------------------------
  window.cdToggleOrFactor = function(factorLabel, prefix) {
    prefix = prefix || '';

    // Find the OR section for this prefix
    var sectionId = prefix + 'cd-odds-ratios';
    var section = document.getElementById(sectionId);
    if (!section) return;

    // Toggle chip active state
    var chip = section.querySelector('.cd-or-chip[data-cd-or-factor="' + factorLabel + '"]');
    if (!chip) return;

    chip.classList.toggle('active');
    var isActive = chip.classList.contains('active');

    // Show/hide rows matching this factor
    var table = section.querySelector('.cd-or-table');
    if (!table) return;

    table.querySelectorAll('tbody tr[data-cd-factor]').forEach(function(row) {
      if (row.getAttribute('data-cd-factor') === factorLabel) {
        row.style.display = isActive ? '' : 'none';
      }
    });
  };

  // --------------------------------------------------------------------------
  // Save Report — download HTML with current state preserved
  // --------------------------------------------------------------------------
  window.cdSaveReportHTML = function() {
    // Sync all insights to hidden stores
    if (typeof cdSyncAllInsights === 'function') cdSyncAllInsights();

    // Save pinned views data
    if (typeof cdSavePinnedData === 'function') cdSavePinnedData();

    // Stamp saved badge in header
    var savedBadge = document.getElementById('cd-saved-badge');
    if (savedBadge) {
      savedBadge.textContent = 'Last saved: ' + new Date().toLocaleString();
      savedBadge.style.display = 'inline-block';
    }

    // Clean ephemeral DOM before serializing
    var actionBar = document.querySelector('.cd-action-bar');
    var wasVisible = actionBar ? actionBar.style.display : '';
    if (actionBar) actionBar.style.display = 'none';

    // Hide all insight containers that are empty
    document.querySelectorAll('.cd-insight-container').forEach(function(c) {
      var editor = c.querySelector('.cd-insight-editor');
      if (editor && !editor.textContent.trim()) {
        c.setAttribute('data-cd-was-hidden', c.style.display || '');
        c.style.display = 'none';
      }
    });

    // Serialize
    var html = '<!DOCTYPE html>\n' + document.documentElement.outerHTML;
    var blob = new Blob([html], { type: 'text/html;charset=utf-8' });

    // Build filename from meta tag or title
    var metaFilename = document.querySelector('meta[name="turas-source-filename"]');
    var baseName = metaFilename ? metaFilename.getAttribute('content') : document.title;
    baseName = baseName.replace(/\.html$/i, '').replace(/[^a-zA-Z0-9_\-\s]/g, '');
    var filename = baseName + '_Updated.html';

    cdDownloadBlob(blob, filename);

    // Restore DOM
    if (actionBar) actionBar.style.display = wasVisible;
    document.querySelectorAll('.cd-insight-container[data-cd-was-hidden]').forEach(function(c) {
      c.style.display = c.getAttribute('data-cd-was-hidden');
      c.removeAttribute('data-cd-was-hidden');
    });
  };

  // --------------------------------------------------------------------------
  // Hydrate page — restore insights + pins from saved state
  // --------------------------------------------------------------------------
  window.cdHydratePage = function() {
    if (typeof cdHydrateInsights === 'function') cdHydrateInsights();
    if (typeof cdHydratePinnedViews === 'function') cdHydratePinnedViews();
  };

  // --------------------------------------------------------------------------
  // Print mode
  // --------------------------------------------------------------------------
  window.cdPrint = function() {
    window.print();
  };

})();
