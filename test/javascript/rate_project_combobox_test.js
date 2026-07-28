/*
 * Behaviour test for assets/javascripts/rate_project_combobox.js.
 *
 * The Ruby suite renders the form but cannot exercise the widget: Capybara runs
 * on rack_test, which has no JavaScript. This harness loads the very jQuery +
 * jQuery UI bundle the surrounding Redmine ships, together with the markup
 * rates/_form.html.erb produces, and drives the combobox in jsdom.
 *
 * It is deliberately not wired into rake -- it needs node and jsdom, which a
 * Redmine plugin has no business requiring. Run it by hand from the plugin root:
 *
 *   npm install jsdom            # once, or set NODE_PATH to an existing install
 *   node test/javascript/rate_project_combobox_test.js
 *
 * The Redmine checkout is looked up two directories up (plugins/<plugin>/..);
 * override with REDMINE_ROOT=/path/to/redmine.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const PLUGIN_ROOT = path.resolve(__dirname, '..', '..');
const REDMINE_ROOT = process.env.REDMINE_ROOT || path.resolve(PLUGIN_ROOT, '..', '..');
const PLUGIN_JS = path.join(PLUGIN_ROOT, 'assets', 'javascripts', 'rate_project_combobox.js');

// Redmine 6.1+ keeps its javascripts in app/assets, older versions in public
function findJqueryUi() {
  const candidates = [
    path.join(REDMINE_ROOT, 'app', 'assets', 'javascripts'),
    path.join(REDMINE_ROOT, 'public', 'javascripts')
  ];

  for (const dir of candidates) {
    if (!fs.existsSync(dir)) { continue; }
    const file = fs.readdirSync(dir).find((name) => /^jquery.*ui.*\.js$/.test(name));
    if (file) { return path.join(dir, file); }
  }

  throw new Error(`no jquery-ui bundle found under ${REDMINE_ROOT}; set REDMINE_ROOT`);
}

// What rates/_form.html.erb renders, with a project tree and a disabled parent
const HTML = `<!doctype html><html><body>
<form>
  <span class="rate-project-picker" data-search-label="Search projects">
    <select name="rate[project_id]" id="rate_project_id" class="rate-project-select">
      <option value="">--- Default rate ---</option>
      <option value="1">eCookbook</option>
      <option value="6">&#187; Child of private child</option>
      <option value="3">&#187; eCookbook Subproject 1</option>
      <option value="4" selected="selected">&#187; eCookbook Subproject 2</option>
      <option value="9" disabled="disabled">Unpickable parent</option>
      <option value="2">KyN Defense</option>
    </select>
  </span>
</form>
</body></html>`;

const failures = [];

function check(name, condition, actual) {
  if (condition) {
    console.log(`  ok   ${name}`);
  } else {
    failures.push(name);
    console.log(`  FAIL ${name}${actual === undefined ? '' : ' -> ' + actual}`);
  }
}

async function main() {
  const dom = new JSDOM(HTML, { runScripts: 'dangerously', pretendToBeVisual: true });
  const { window } = dom;
  const errors = [];
  window.addEventListener('error', (event) => errors.push(event.message));

  for (const file of [findJqueryUi(), PLUGIN_JS]) {
    const script = window.document.createElement('script');
    script.textContent = fs.readFileSync(file, 'utf8');
    window.document.body.appendChild(script);
  }

  // jQuery runs its ready callbacks on a later tick
  await new Promise((resolve) => setTimeout(resolve, 100));

  const $ = window.jQuery;
  const select = window.document.querySelector('select.rate-project-select');
  const input = window.document.querySelector('input.rate-project-combobox');

  console.log('build');
  check('no script errors', errors.length === 0, errors.join('; '));
  check('combobox field inserted', !!input);
  if (!input) {
    console.log('\n1 FAILED: the widget was not built');
    process.exit(1);
  }
  check('select hidden but still submitted with the form',
    select.style.display === 'none' && !!select.form && select.getAttribute('name') === 'rate[project_id]');
  check('field shows the selected project without the tree prefix',
    input.value === 'eCookbook Subproject 2', JSON.stringify(input.value));
  check('placeholder taken from the localized data attribute',
    input.getAttribute('placeholder') === 'Search projects');
  check("field carries Redmine's autocomplete styling class",
    input.classList.contains('autocomplete'));

  const $input = $(input);
  const menuItems = () => $input.autocomplete('widget').find('li').map((_i, li) => $(li).text()).get();

  // Regression guard: capping the menu from the "open" callback happens after
  // jQuery UI positioned it, so the first open measured the full list and
  // flipped the menu above the field, sometimes out of view.
  console.log('menu height capped before the first open');
  const menuStyle = $input.autocomplete('widget')[0].style;
  check('max-height set at build time', menuStyle.maxHeight !== '', JSON.stringify(menuStyle.maxHeight));
  check('menu scrolls instead of growing', menuStyle.overflowY === 'auto', JSON.stringify(menuStyle.overflowY));

  console.log('focusing lists every project');
  $input.trigger('focus');
  check('field cleared so typing filters instead of appending',
    input.value === '', JSON.stringify(input.value));
  const all = menuItems();
  check('all selectable projects listed, unpickable parent left out',
    all.length === 6 && !all.some((text) => text.includes('Unpickable')), JSON.stringify(all));

  console.log('typing filters');
  $input.val('subproject').autocomplete('search', 'subproject');
  check('both subprojects match', menuItems().length === 2, JSON.stringify(menuItems()));

  console.log('matching ignores case and the tree prefix');
  $input.val('KYN def').autocomplete('search', 'KYN def');
  let items = menuItems();
  check('multi-term match', items.length === 1 && items[0].includes('KyN Defense'), JSON.stringify(items));

  console.log('picking an entry updates the select');
  $input.autocomplete('widget').find('li').first().trigger('mouseenter').children().first().trigger('click');
  check('select value updated', select.value === '2', select.value);
  check('field shows the picked project', input.value === 'KyN Defense', JSON.stringify(input.value));

  console.log('text matching nothing leaves the rate alone');
  $input.trigger('focus');
  $input.val('no such project').trigger('blur');
  check('select value kept', select.value === '2', select.value);
  check('field restored to the selected project',
    input.value === 'KyN Defense', JSON.stringify(input.value));

  console.log('the default rate stays pickable');
  $input.trigger('focus');
  $input.autocomplete('search', 'default');
  items = menuItems();
  check('default rate entry found',
    items.length === 1 && items[0].includes('Default rate'), JSON.stringify(items));
  $input.autocomplete('widget').find('li').first().trigger('mouseenter').children().first().trigger('click');
  check('select reset to the blank default option', select.value === '', JSON.stringify(select.value));

  console.log(failures.length
    ? `\n${failures.length} FAILED: ${failures.join(', ')}`
    : '\nall checks passed');
  process.exit(failures.length ? 1 : 0);
}

main();
