/* ==============================================================================
 * CATDRIVER HTML REPORT - QUALITATIVE SLIDES
 * ==============================================================================
 * Add free-form qualitative slides (text + optional image) to the report.
 * Slides support markdown editing, image upload (base64), reordering, and
 * pinning to the Pinned Views panel via cdPinnedViews.
 * All functions prefixed cd to avoid global namespace conflicts.
 * ============================================================================== */

(function() {
  'use strict';

  // ---------------------------------------------------------------------------
  // Markdown helpers
  // ---------------------------------------------------------------------------

  /**
   * Render a subset of markdown to HTML.
   * Supports: ## heading, **bold**, *italic*, - bullets, > blockquote,
   * blank-line paragraph breaks.
   * @param {string} md - Raw markdown text
   * @returns {string} HTML string
   */
  window.cdRenderMarkdown = function(md) {
    if (!md) return '';

    var lines = md.split('\n');
    var html = [];
    var inList = false;
    var inQuote = false;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Headings (## only — keep it simple)
      if (/^##\s+/.test(line)) {
        if (inList) { html.push('</ul>'); inList = false; }
        if (inQuote) { html.push('</blockquote>'); inQuote = false; }
        html.push('<h3>' + inlineFormat(line.replace(/^##\s+/, '')) + '</h3>');
        continue;
      }

      // Bullet list items
      if (/^\s*[-*]\s+/.test(line)) {
        if (inQuote) { html.push('</blockquote>'); inQuote = false; }
        if (!inList) { html.push('<ul>'); inList = true; }
        html.push('<li>' + inlineFormat(line.replace(/^\s*[-*]\s+/, '')) + '</li>');
        continue;
      } else if (inList) {
        html.push('</ul>');
        inList = false;
      }

      // Blockquote
      if (/^>\s?/.test(line)) {
        if (inList) { html.push('</ul>'); inList = false; }
        if (!inQuote) { html.push('<blockquote>'); inQuote = true; }
        html.push(inlineFormat(line.replace(/^>\s?/, '')) + '<br>');
        continue;
      } else if (inQuote) {
        html.push('</blockquote>');
        inQuote = false;
      }

      // Blank line — paragraph break
      if (line.trim() === '') {
        html.push('<br>');
        continue;
      }

      // Regular text
      html.push('<p>' + inlineFormat(line) + '</p>');
    }

    if (inList) html.push('</ul>');
    if (inQuote) html.push('</blockquote>');

    return html.join('\n');
  };

  /**
   * Apply inline formatting: **bold** and *italic*.
   * @param {string} text
   * @returns {string}
   */
  function inlineFormat(text) {
    // Bold first (greedy inner match)
    text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    // Italic
    text = text.replace(/\*(.+?)\*/g, '<em>$1</em>');
    return text;
  }

  /**
   * Strip markdown formatting for plain-text contexts.
   * @param {string} md - Raw markdown
   * @returns {string} Plain text
   */
  window.cdStripMarkdown = function(md) {
    if (!md) return '';
    return md
      .replace(/^##\s+/gm, '')
      .replace(/\*\*(.+?)\*\*/g, '$1')
      .replace(/\*(.+?)\*/g, '$1')
      .replace(/^>\s?/gm, '')
      .replace(/^\s*[-*]\s+/gm, '')
      .trim();
  };

  // ---------------------------------------------------------------------------
  // Slide management
  // ---------------------------------------------------------------------------

  /**
   * Generate a unique slide ID.
   * @returns {string}
   */
  function generateSlideId() {
    return 'qual-' + Date.now() + '-' + Math.random().toString(36).substr(2, 6);
  }

  /**
   * Get the slides container element.
   * @returns {HTMLElement|null}
   */
  function getContainer() {
    return document.getElementById('cd-qual-slides-container');
  }

  /**
   * Render all existing qualitative slide cards on page load.
   * Hydrates markdown previews and images from hidden store textareas.
   */
  window.cdRenderAllQualSlides = function() {
    var container = getContainer();
    if (!container) return;

    var cards = container.querySelectorAll('.cd-qual-slide-card');
    for (var i = 0; i < cards.length; i++) {
      var card = cards[i];
      hydrateCard(card);
    }
    cdUpdateQualEmptyState();
  };

  /**
   * Hydrate a single card: render markdown preview and restore image.
   * @param {HTMLElement} card
   */
  function hydrateCard(card) {
    var mdStore = card.querySelector('.cd-qual-md-store');
    var rendered = card.querySelector('.cd-qual-md-rendered');
    var imgStore = card.querySelector('.cd-qual-img-store');
    var imgPreview = card.querySelector('.cd-qual-img-preview');

    // Render markdown
    if (mdStore && rendered) {
      rendered.innerHTML = cdRenderMarkdown(mdStore.value || '');
    }

    // Restore image
    if (imgStore && imgStore.value && imgPreview) {
      var dataUrl = imgStore.value;
      imgPreview.innerHTML = '<img src="' + dataUrl + '" alt="Slide image" ' +
        'style="max-width:100%; max-height:300px; border-radius:4px;" ' +
        'data-img-width="' + (card.getAttribute('data-img-width') || '') + '" ' +
        'data-img-height="' + (card.getAttribute('data-img-height') || '') + '">';
    }
  }

  /**
   * Toggle edit/view mode on a qualitative slide card.
   * @param {HTMLElement} card - The .cd-qual-slide-card element
   */
  window.cdToggleQualEdit = function(card) {
    if (!card) return;

    var editor = card.querySelector('.cd-qual-md-editor');
    var rendered = card.querySelector('.cd-qual-md-rendered');
    var mdStore = card.querySelector('.cd-qual-md-store');

    if (!editor || !rendered || !mdStore) return;

    var isEditing = editor.style.display !== 'none';

    if (isEditing) {
      // Save and switch to view mode
      mdStore.value = editor.value;
      rendered.innerHTML = cdRenderMarkdown(editor.value);
      editor.style.display = 'none';
      rendered.style.display = 'block';
    } else {
      // Switch to edit mode
      editor.value = mdStore.value || '';
      editor.style.display = 'block';
      rendered.style.display = 'none';
      editor.focus();
    }
  };

  /**
   * Add a new empty qualitative slide with editing mode active.
   */
  window.cdAddQualSlide = function() {
    var container = getContainer();
    if (!container) return;

    var slideId = generateSlideId();

    var cardHtml =
      '<div class="cd-qual-slide-card" data-slide-id="' + slideId + '">' +
        '<div class="cd-qual-slide-header">' +
          '<h4 class="cd-qual-slide-title" contenteditable="true" ' +
            'placeholder="Slide title...">Untitled Slide</h4>' +
          '<div class="cd-qual-slide-actions">' +
            '<button class="cd-qual-btn cd-qual-btn-move-up" title="Move up" ' +
              'onclick="cdMoveQualSlide(\'' + slideId + '\', \'up\')">' +
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">' +
                '<path d="M7 11V3M3 7l4-4 4 4"/>' +
              '</svg>' +
            '</button>' +
            '<button class="cd-qual-btn cd-qual-btn-move-down" title="Move down" ' +
              'onclick="cdMoveQualSlide(\'' + slideId + '\', \'down\')">' +
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">' +
                '<path d="M7 3v8M3 7l4 4 4-4"/>' +
              '</svg>' +
            '</button>' +
            '<button class="cd-qual-btn cd-qual-btn-pin" title="Pin to Pinned Views" ' +
              'onclick="cdPinQualSlide(\'' + slideId + '\')">' +
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.5">' +
                '<path d="M7 1v8M4 4l3-3 3 3M2 13h10"/>' +
              '</svg>' +
            '</button>' +
            '<button class="cd-qual-btn cd-qual-btn-remove" title="Remove slide" ' +
              'onclick="cdRemoveQualSlide(\'' + slideId + '\')">' +
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">' +
                '<path d="M3 3l8 8M11 3l-8 8"/>' +
              '</svg>' +
            '</button>' +
          '</div>' +
        '</div>' +
        '<div class="cd-qual-slide-body">' +
          '<textarea class="cd-qual-md-editor" ' +
            'placeholder="Write your content here... (supports **bold**, *italic*, ## headings, - bullets, > quotes)" ' +
            'rows="6" style="display:block;"></textarea>' +
          '<div class="cd-qual-md-rendered" style="display:none;"></div>' +
          '<textarea class="cd-qual-md-store" style="display:none;"></textarea>' +
        '</div>' +
        '<div class="cd-qual-slide-image">' +
          '<div class="cd-qual-img-preview"></div>' +
          '<input type="file" class="cd-qual-img-input" accept="image/*" ' +
            'style="display:none;" ' +
            'onchange="cdHandleQualImage(\'' + slideId + '\', this)">' +
          '<textarea class="cd-qual-img-store" style="display:none;"></textarea>' +
          '<div class="cd-qual-img-actions">' +
            '<button class="cd-qual-btn cd-qual-btn-add-img" title="Add image" ' +
              'onclick="cdTriggerQualImage(\'' + slideId + '\')">' +
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.5">' +
                '<rect x="1" y="2" width="12" height="10" rx="2"/>' +
                '<circle cx="4.5" cy="5.5" r="1.5"/>' +
                '<path d="M1 10l3-3 2 2 3-3 4 4"/>' +
              '</svg>' +
              ' Image' +
            '</button>' +
            '<button class="cd-qual-btn cd-qual-btn-remove-img" title="Remove image" ' +
              'onclick="cdRemoveQualImage(\'' + slideId + '\')" style="display:none;">' +
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">' +
                '<path d="M3 3l8 8M11 3l-8 8"/>' +
              '</svg>' +
              ' Remove image' +
            '</button>' +
          '</div>' +
        '</div>' +
      '</div>';

    container.insertAdjacentHTML('beforeend', cardHtml);
    cdUpdateQualEmptyState();

    // Focus the editor on the new card
    var newCard = container.querySelector('[data-slide-id="' + slideId + '"]');
    if (newCard) {
      var editor = newCard.querySelector('.cd-qual-md-editor');
      if (editor) editor.focus();
    }
  };

  /**
   * Handle image file input — read as base64 data URL, store dimensions.
   * @param {string} slideId - Slide ID
   * @param {HTMLInputElement} input - The file input element
   */
  window.cdHandleQualImage = function(slideId, input) {
    if (!input.files || !input.files[0]) return;

    var file = input.files[0];
    var card = getCardById(slideId);
    if (!card) return;

    var reader = new FileReader();
    reader.onload = function(e) {
      var dataUrl = e.target.result;

      // Get image dimensions
      var img = new Image();
      img.onload = function() {
        card.setAttribute('data-img-width', img.naturalWidth);
        card.setAttribute('data-img-height', img.naturalHeight);

        // Store base64 data
        var imgStore = card.querySelector('.cd-qual-img-store');
        if (imgStore) imgStore.value = dataUrl;

        // Show preview
        var preview = card.querySelector('.cd-qual-img-preview');
        if (preview) {
          preview.innerHTML = '<img src="' + dataUrl + '" alt="Slide image" ' +
            'style="max-width:100%; max-height:300px; border-radius:4px;" ' +
            'data-img-width="' + img.naturalWidth + '" ' +
            'data-img-height="' + img.naturalHeight + '">';
        }

        // Toggle button visibility
        var addBtn = card.querySelector('.cd-qual-btn-add-img');
        var removeBtn = card.querySelector('.cd-qual-btn-remove-img');
        if (addBtn) addBtn.style.display = 'none';
        if (removeBtn) removeBtn.style.display = 'inline-flex';
      };
      img.src = dataUrl;
    };
    reader.readAsDataURL(file);
  };

  /**
   * Trigger the hidden file input for image upload.
   * @param {string} slideId - Slide ID
   */
  window.cdTriggerQualImage = function(slideId) {
    var card = getCardById(slideId);
    if (!card) return;

    var input = card.querySelector('.cd-qual-img-input');
    if (input) input.click();
  };

  /**
   * Remove an image from a slide.
   * @param {string} slideId - Slide ID
   */
  window.cdRemoveQualImage = function(slideId) {
    var card = getCardById(slideId);
    if (!card) return;

    // Clear stores and preview
    var imgStore = card.querySelector('.cd-qual-img-store');
    var preview = card.querySelector('.cd-qual-img-preview');
    var input = card.querySelector('.cd-qual-img-input');

    if (imgStore) imgStore.value = '';
    if (preview) preview.innerHTML = '';
    if (input) input.value = '';

    card.removeAttribute('data-img-width');
    card.removeAttribute('data-img-height');

    // Toggle button visibility
    var addBtn = card.querySelector('.cd-qual-btn-add-img');
    var removeBtn = card.querySelector('.cd-qual-btn-remove-img');
    if (addBtn) addBtn.style.display = 'inline-flex';
    if (removeBtn) removeBtn.style.display = 'none';
  };

  /**
   * Remove a qualitative slide card (with confirmation).
   * @param {string} slideId - Slide ID
   */
  window.cdRemoveQualSlide = function(slideId) {
    if (!confirm('Remove this slide? This cannot be undone.')) return;

    var card = getCardById(slideId);
    if (card) card.remove();

    cdUpdateQualEmptyState();
  };

  /**
   * Move a slide up or down in the container.
   * @param {string} slideId - Slide ID
   * @param {string} direction - 'up' or 'down'
   */
  window.cdMoveQualSlide = function(slideId, direction) {
    var card = getCardById(slideId);
    if (!card) return;

    var container = getContainer();
    if (!container) return;

    if (direction === 'up') {
      var prev = card.previousElementSibling;
      if (prev && prev.classList.contains('cd-qual-slide-card')) {
        container.insertBefore(card, prev);
      }
    } else if (direction === 'down') {
      var next = card.nextElementSibling;
      if (next && next.classList.contains('cd-qual-slide-card')) {
        container.insertBefore(next, card);
      }
    }
  };

  /**
   * Pin a qualitative slide to Pinned Views.
   * Creates a pin object with pinType "qualitative" and pushes it to
   * the cdPinnedViews array via window.cdGetPinnedViews().
   * @param {string} slideId - Slide ID
   */
  window.cdPinQualSlide = function(slideId) {
    var card = getCardById(slideId);
    if (!card) return;

    // Gather slide content
    var titleEl = card.querySelector('.cd-qual-slide-title');
    var mdStore = card.querySelector('.cd-qual-md-store');
    var editor = card.querySelector('.cd-qual-md-editor');
    var imgStore = card.querySelector('.cd-qual-img-store');

    // Sync editor to store if still in edit mode
    if (editor && editor.style.display !== 'none') {
      if (mdStore) mdStore.value = editor.value;
    }

    var title = titleEl ? titleEl.textContent.trim() : 'Untitled Slide';
    var mdText = mdStore ? mdStore.value : '';
    var imgData = imgStore ? imgStore.value : '';

    // Build the pin object
    var pin = {
      type: 'pin',
      pinType: 'qualitative',
      id: 'pin-' + Date.now() + '-' + Math.random().toString(36).substr(2, 6),
      sectionKey: 'qualitative-' + slideId,
      sectionTitle: title,
      panelLabel: 'Qualitative',
      insightText: cdStripMarkdown(mdText),
      markdownText: mdText,
      chartSvg: '',
      tableHtml: imgData
        ? '<div class="cd-qual-pinned-image"><img src="' + imgData + '" ' +
          'style="max-width:100%; border-radius:4px;" alt="' + title + '"></div>'
        : '',
      timestamp: new Date().toISOString(),
      imgWidth: card.getAttribute('data-img-width') || '',
      imgHeight: card.getAttribute('data-img-height') || ''
    };

    // Push to the shared pinned views array
    var pins = window.cdGetPinnedViews();
    pins.push(pin);

    // Persist and re-render
    if (typeof window.cdSavePinnedData === 'function') {
      window.cdSavePinnedData();
    }
    if (typeof window.cdRenderPinnedCards === 'function') {
      window.cdRenderPinnedCards();
    }
    if (typeof window.cdUpdatePinBadge === 'function') {
      window.cdUpdatePinBadge();
    }
  };

  /**
   * Show or hide the empty-state placeholder based on slide count.
   */
  window.cdUpdateQualEmptyState = function() {
    var container = getContainer();
    var emptyState = document.getElementById('cd-qual-empty-state');
    if (!container || !emptyState) return;

    var cards = container.querySelectorAll('.cd-qual-slide-card');
    emptyState.style.display = cards.length === 0 ? 'block' : 'none';
  };

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /**
   * Find a slide card by its data-slide-id.
   * @param {string} slideId
   * @returns {HTMLElement|null}
   */
  function getCardById(slideId) {
    var container = getContainer();
    if (!container) return null;
    return container.querySelector('.cd-qual-slide-card[data-slide-id="' + slideId + '"]');
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  document.addEventListener('DOMContentLoaded', function() {
    cdRenderAllQualSlides();

    // Double-click on rendered markdown area toggles to edit mode
    var container = getContainer();
    if (container) {
      container.addEventListener('dblclick', function(e) {
        var rendered = e.target.closest('.cd-qual-md-rendered');
        if (!rendered) return;

        var card = rendered.closest('.cd-qual-slide-card');
        if (card) {
          cdToggleQualEdit(card);
        }
      });
    }
  });

})();
