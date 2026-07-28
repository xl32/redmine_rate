/*
 * Turns the project drop-down on the rate form into a type-in combobox.
 *
 * An installation can easily have hundreds of active projects, and picking one
 * out of a plain <select> on the "New rate" / "Edit rate" forms means scrolling
 * the whole list. The drop-down is replaced at runtime by a jQuery UI
 * autocomplete field -- the widget Redmine already bundles and uses for its own
 * autocompletes, so it looks and behaves like the rest of the UI: click it to
 * see every project, type to narrow the list down, arrows and Enter to pick.
 *
 * The <select> stays in the DOM (hidden) and remains the field that is
 * submitted, so nothing changes server side and the form still works when
 * JavaScript (or jQuery UI) is unavailable.
 */
(function ($) {
  'use strict';

  if (!$ || !$.fn || !$.fn.autocomplete) { return; }
  if (window.rateProjectComboboxLoaded) { return; }
  window.rateProjectComboboxLoaded = true;

  var PICKER_SELECTOR = '.rate-project-picker';
  var SELECT_SELECTOR = '.rate-project-select';
  var MENU_MAX_HEIGHT = '20em';

  // Option labels carry the project tree prefix ("&#187; Name") and
  // non-breaking spaces; neither should take part in the match.
  function normalize(text) {
    return text.replace(/[\u00a0\u00bb]/g, ' ').replace(/\s+/g, ' ').trim().toLowerCase();
  }

  // Menu entries keep the tree prefix, the field itself shows the plain name
  function menuLabel(option) {
    return option.text.replace(/\u00a0/g, ' ');
  }

  function fieldLabel(option) {
    return menuLabel(option).replace(/^\s*\u00bb\s*/, '').trim();
  }

  function optionsMatching(select, term) {
    var terms = normalize(term).split(/\s+/).filter(Boolean);
    var items = [];

    $.each(select.options, function (_index, option) {
      // Parent projects that cannot be picked are tree structure, not results
      if (option.disabled) { return; }

      var text = normalize(option.text);
      var matched = terms.every(function (each) { return text.indexOf(each) !== -1; });
      if (matched) {
        items.push({ label: menuLabel(option), value: fieldLabel(option), option: option });
      }
    });

    return items;
  }

  function build(picker) {
    var select = picker.querySelector(SELECT_SELECTOR);
    if (!select || select.rateComboboxBuilt) { return; }
    select.rateComboboxBuilt = true;

    var $select = $(select);
    var hint = picker.getAttribute('data-search-label') || '';
    // Attributes are set through .attr on purpose: passing them to $('<input>', {...})
    // would dispatch "autocomplete" to the jQuery UI method of that name.
    var $input = $('<input>').attr({
      type: 'text',
      // .autocomplete gives the field Redmine's own search-box styling
      'class': 'rate-project-combobox autocomplete',
      autocomplete: 'off',
      placeholder: hint,
      title: hint
    });

    $input.outerWidth($select.outerWidth() || 250);
    $select.hide().after($input);

    function showSelection() {
      var option = select.options[select.selectedIndex];
      $input.val(option ? fieldLabel(option) : '');
    }

    $input.autocomplete({
      minLength: 0,
      delay: 0,
      autoFocus: true,
      position: { collision: 'flipfit' },
      source: function (request, response) { response(optionsMatching(select, request.term)); },
      select: function (event, ui) {
        $select.val(ui.item.option.value).trigger('change');
      }
    });

    // The height has to be capped here, before the menu is ever positioned, and
    // not from the "open" callback: that one runs *after* jQuery UI has placed
    // the menu, so on the first open it measured the full list (hundreds of
    // projects, thousands of pixels), found no room below the field and flipped
    // the menu above it -- occasionally out of view. Every later open then
    // behaved because the cap from the first one was still on the element.
    $input.autocomplete('widget').css({
      maxHeight: MENU_MAX_HEIGHT,
      overflowY: 'auto',
      overflowX: 'hidden'
    });

    // While focused the field is a search box: it starts out empty and lists
    // every project, so typing filters instead of being appended to the name of
    // the project that is currently selected.
    $input.on('focus', function () {
      $input.val('');
      $input.autocomplete('search', '');
    });

    // Clicking a focused field re-opens the list, the way the drop-down used to
    $input.on('click', function () {
      if (!$input.autocomplete('widget').is(':visible')) {
        $input.autocomplete('search', $input.val());
      }
    });

    // Leaving the field always shows the project the select actually holds,
    // whether it was just picked, or typed and never matched anything.
    $input.on('blur', showSelection);

    showSelection();
  }

  function buildAll() {
    $(PICKER_SELECTOR).each(function (_index, picker) { build(picker); });
  }

  $(document).ready(buildAll);
  // The form can come back with an xhr response (see rates/index.js.erb)
  $(document).on('ajaxComplete', buildAll);
})(window.jQuery);
