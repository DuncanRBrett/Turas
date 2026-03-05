/* ==============================================================================
 * KEYDRIVER HTML REPORT - NAVIGATION JS
 * ==============================================================================
 * Horizontal section nav bar, save report, hydrate, and print.
 * Supports multiple section nav bars (unified mode: one per analysis panel).
 * All functions prefixed kd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // --------------------------------------------------------------------------
  // Section navigation — horizontal bar(s) (.kd-section-nav)
  // In single-report mode there is one nav bar; in unified mode there is
  // one per analysis panel.  Each is independently tracked.
  // --------------------------------------------------------------------------

  var navGroups = [];  // array of { navBar, links, sections }

  function initNavBars() {
    var allNavBars = document.querySelectorAll('.kd-section-nav');

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
            var tabBar = document.querySelector('.kd-analysis-tabs');
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
      var panel = group.navBar.closest('.kd-analysis-panel');
      if (panel && !panel.classList.contains('active')) return;

      var tabBar = document.querySelector('.kd-analysis-tabs');
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
    kdHydratePage();
  });

  window.addEventListener('scroll', updateActiveNav, { passive: true });

  // --------------------------------------------------------------------------
  // Importance bar filtering — show/hide bars by threshold
  // Modes: 'all', 'top-3', 'top-5', 'top-8', 'significant'
  // --------------------------------------------------------------------------
  window.kdFilterImportanceBars = function(mode, prefix) {
    prefix = prefix || '';

    var sectionId = prefix + 'kd-importance';
    var section = document.getElementById(sectionId);
    if (!section) return;

    // Update chip active state
    var filterBar = section.querySelector('#' + CSS.escape(prefix + 'kd-importance-filter'));
    if (filterBar) {
      filterBar.querySelectorAll('.kd-or-chip').forEach(function(chip) {
        chip.classList.toggle('active', chip.getAttribute('data-kd-imp-mode') === mode);
      });
    }

    // Filter chart rows
    var chart = section.querySelector('svg.kd-importance-chart');
    if (chart) {
      var rows = chart.querySelectorAll('g.kd-importance-row');
      rows.forEach(function(g) {
        var rank = parseInt(g.getAttribute('data-kd-rank'), 10);
        var sig = g.getAttribute('data-kd-sig') === 'yes';
        var show = true;

        if (mode === 'top-3') show = rank <= 3;
        else if (mode === 'top-5') show = rank <= 5;
        else if (mode === 'top-8') show = rank <= 8;
        else if (mode === 'significant') show = sig;
        // 'all' shows everything

        g.style.display = show ? '' : 'none';
      });

      kdResizeImportanceChart(chart);
    }

    // Also filter table rows to match
    var table = section.querySelector('.kd-importance-table');
    if (table) {
      var trs = table.querySelectorAll('tbody tr');
      trs.forEach(function(tr, idx) {
        var rank = idx + 1;
        var show = true;

        if (mode === 'top-3') show = rank <= 3;
        else if (mode === 'top-5') show = rank <= 5;
        else if (mode === 'top-8') show = rank <= 8;
        else if (mode === 'significant') {
          // Check the sig column — kd-sig-none means not significant
          var sigCell = tr.querySelector('.kd-td-sig');
          show = sigCell ? !sigCell.classList.contains('kd-sig-none') : true;
        }

        tr.style.display = show ? '' : 'none';
      });
    }
  };

  // --------------------------------------------------------------------------
  // Importance chart dynamic resize — same approach as forest plot
  // --------------------------------------------------------------------------
  function kdResizeImportanceChart(svg) {
    var barHeight = 28;
    var gap = 8;
    var rowStep = barHeight + gap;  // 36
    var topPad = 25;
    var bottomPad = 15;

    var allRows = svg.querySelectorAll('g.kd-importance-row');
    var visibleIdx = 0;

    allRows.forEach(function(g, i) {
      if (g.style.display === 'none') {
        return;
      }
      var originalY = topPad + i * rowStep;
      var targetY = topPad + visibleIdx * rowStep;
      var deltaY = targetY - originalY;

      if (deltaY !== 0) {
        g.setAttribute('transform', 'translate(0,' + deltaY + ')');
      } else {
        g.removeAttribute('transform');
      }
      visibleIdx++;
    });

    if (visibleIdx === 0) return;

    var newHeight = topPad + visibleIdx * rowStep + bottomPad;

    // Update viewBox height
    var vb = svg.getAttribute('viewBox');
    if (vb) {
      var parts = vb.split(/\s+/);
      if (parts.length >= 4) {
        svg.setAttribute('viewBox', parts[0] + ' ' + parts[1] + ' ' + parts[2] + ' ' + newHeight);
      }
    }

    // Update gridlines — shorten their y2 to new height
    svg.querySelectorAll('line[stroke="#e2e8f0"]').forEach(function(line) {
      var y2 = parseFloat(line.getAttribute('y2'));
      if (y2 > newHeight) {
        line.setAttribute('y2', newHeight - 5);
      }
    });
  }

  // --------------------------------------------------------------------------
  // Save Report — download HTML with current state preserved
  // --------------------------------------------------------------------------
  window.kdSaveReportHTML = function() {
    // Sync all insights to hidden stores
    if (typeof kdSyncAllInsights === 'function') kdSyncAllInsights();

    // Save pinned views data
    if (typeof kdSavePinnedData === 'function') kdSavePinnedData();

    // Stamp saved badge in header
    var savedBadge = document.getElementById('kd-saved-badge');
    if (savedBadge) {
      savedBadge.textContent = 'Last saved: ' + new Date().toLocaleString();
      savedBadge.style.display = 'inline-block';
    }

    // Clean ephemeral DOM before serializing
    var actionBar = document.querySelector('.kd-action-bar');
    var wasVisible = actionBar ? actionBar.style.display : '';
    if (actionBar) actionBar.style.display = 'none';

    // Hide all insight containers that are empty
    document.querySelectorAll('.kd-insight-container').forEach(function(c) {
      var editor = c.querySelector('.kd-insight-editor');
      if (editor && !editor.textContent.trim()) {
        c.setAttribute('data-kd-was-hidden', c.style.display || '');
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

    kdDownloadBlob(blob, filename);

    // Restore DOM
    if (actionBar) actionBar.style.display = wasVisible;
    document.querySelectorAll('.kd-insight-container[data-kd-was-hidden]').forEach(function(c) {
      c.style.display = c.getAttribute('data-kd-was-hidden');
      c.removeAttribute('data-kd-was-hidden');
    });
  };

  // --------------------------------------------------------------------------
  // Hydrate page — restore insights + pins from saved state
  // --------------------------------------------------------------------------
  window.kdHydratePage = function() {
    if (typeof kdHydrateInsights === 'function') kdHydrateInsights();
    if (typeof kdHydratePinnedViews === 'function') kdHydratePinnedViews();
  };

  // --------------------------------------------------------------------------
  // Print mode
  // --------------------------------------------------------------------------
  window.kdPrint = function() {
    window.print();
  };

})();
