# Changelog

## 2.1.0 — Disable rate lock

### Added

- **"Disable rate lock" plugin setting** (Administration -> Plugins -> Rate ->
  Configure, default off). With it checked, rates that already have time entries
  can be edited and deleted again — in the Rate History UI and through the REST
  API — so a rate entered incorrectly can be fixed instead of being frozen
  forever.
  - `Rate.lock_enforced?` reads the setting; the new `Rate#editable?` predicate
    (`unlocked? || !Rate.lock_enforced?`) drives the `before_save`/`before_destroy`
    guard, the edit/delete controls in `rates/_form` and `rates/_list`, and the
    lock error in `RatesController#update`. `locked?`/`unlocked?` keep their
    original meaning ("has time entries"), so the API's `locked` field is
    unchanged.
  - Editing a locked rate leaves its time entries assigned to it (`rate_id` is
    untouched); the existing `after_save` hook just recomputes their cached cost,
    so correcting an amount also corrects the costs already booked against it.
  - `RatesController#destroy` now branches on the return value of `destroy`
    instead of `locked?`, which stays true after a successful destroy of a rate
    that had time entries.
  - The REST API additionally exposes `editable` per rate, since `locked` alone
    no longer implies "cannot be written".
- Tests: model coverage for `#editable?` plus save/destroy/cost-refresh with the
  lock disabled, controller coverage for update/destroy/edit-button (HTML and
  API) and an admin-panel test for the new checkbox. `with_rate_lock_disabled`
  lives in `test/test_helper.rb`.

### Changed

- Russian locale: rates were translated as "платежи" (payments); corrected to
  "часовые ставки", and the previously untranslated `rate_locked_message` /
  `rate_label_edit_rate` are now translated.
- Bumped plugin version to `2.1.0`.

## 2.0.0 — REST API

### Added

- **REST API in the native Redmine style** (XML and JSON), admin-only.
  - Read: `GET /rates.{xml,json}?user_id=:id` (rate history) and
    `GET /rates/:id.{xml,json}` (a single rate).
  - Write: `POST /rates` (`201` or `422`), `PUT /rates/:id` (`204` or `422`) and
    `DELETE /rates/:id` (`204` or `422`). A locked rate (one that already has
    time entries) cannot be updated or deleted and returns `422`.
  - Implemented with `accept_api_auth`, `format.api` and `.api.rsb` builder
    templates (`app/views/rates/index.api.rsb`, `show.api.rsb`); serialization
    lives in a single `RateHelper#render_api_rate`. Writes use Redmine's
    `render_api_ok` / `render_validation_errors`. Every action runs behind
    `require_admin`, so the whole API requires an admin API key and "REST web
    service" enabled. Each rate exposes `id`, `amount`, `date_in_effect`,
    `locked`, `user` and (for project rates) `project`. See `README.rdoc`.

### Fixed

- **Patches are now applied in every environment, not just production.** Redmine
  marks a plugin's `lib` as an eager-load path, but with `eager_load` disabled
  (the default in development **and** test) `lib/redmine_rate.rb` was only
  autoloaded lazily, so its top-level `Rails.configuration.to_prepare` block
  never registered in time and `TimeEntry`/`Issue`/`IssueQuery`/etc. were left
  unpatched (cost caching, the `billable` field and rate columns silently did
  nothing). Patch loading now runs from `RedmineRate.setup!`, invoked by
  `init.rb` (which Redmine executes inside `to_prepare`), and loads each patch by
  referencing its constant so Zeitwerk resolves it without `$LOAD_PATH`.

### Removed / dropped (confirmed)

- **Broken write-action XML rendering** in `RatesController#new/create/update/destroy`
  (`format.xml { render xml: ... }`). It relied on `ActiveRecord#to_xml`, which
  was extracted out of Rails core into the `activemodel-serializers-xml` gem in
  Rails 5, so this code had been dead since before the Rails 6.1 baseline. The
  REST API is intentionally read-only; rates are still managed through the web UI.
- **`.rubocop.yml`** — pinned obsolete `TargetRubyVersion: 2.1` /
  `TargetRailsVersion: 4.2` and was unused.
- **`.stylelintrc`** — a CSS linter config, but the plugin ships no stylesheets.

### Changed

- Bumped plugin version to `2.0.0`.
- Modernized the test suite so it runs green on Redmine 6.1 (Rails 7.2). The
  full suite (unit, functional, integration, routing) passes locally against a
  Redmine 6.1 checkout. Changes:
  - Test group now uses `shoulda-context` + `shoulda-matchers` (6.x/8.x, Rails
    7.2/8.0 compatible) instead of the meta `shoulda` gem (pinned to matchers
    4.x), and adds `rails-controller-testing` for `assigns`/`assert_template`.
  - `test_helper.rb`: coverage (`simplecov`) made optional; `fixture_paths`
    instead of the removed `fixture_path`; `Shoulda::Matchers` configured for
    minitest; Capybara login/logout updated for Redmine 6.x markup and wired to
    `Capybara::Minitest::Assertions`.
  - `RatesController` XML test cases reworked into read-only REST API tests
    (XML + JSON) that authenticate with an API key and enable REST, matching how
    the API actually works.
  - Fixed pre-existing test bugs surfaced on modern Rails: Rails-5+ `params:`
    call syntax, `update_attribute` (the two-arg `update` never existed), a
    time-entry author/member requirement, and a Propshaft digested-asset matcher.
- Documentation overhaul in `README.rdoc`:
  - Fixed the clone URL (was the wrong `alphanodes` fork; the repo is
    `github.com/xl32/redmine_rate`).
  - Modernized install instructions (`bundle config set --local without ...`
    instead of the removed `bundle install --without` flag).
  - Corrected the requirements/version matrix, fixed the mixed Markdown/RDoc
    headings, and added dedicated **Ruby API** and **REST API** sections.

## 1.2.0 — Redmine 6.1 / 7.0 (Rails 7.2 / 8.0) compatibility

Minimal changes to run cleanly on Redmine 6.1 (Rails 7.2) and 7.0 (Rails 8.0),
in addition to the already-supported Redmine 5.0/5.1 (Rails 6.1). The plugin was
already largely modern (strong parameters, `before_action`, `update` instead of
the removed `update_attributes`, Zeitwerk-compatible file naming), so only the
following Rails-behaviour changes required code fixes.

### Fixed

- **Model callbacks now abort with `throw :abort` instead of returning `false`**
  (`app/models/rate.rb`).
  Since Rails 5 a `before_*` callback that returns `false` no longer halts the
  callback chain — the `ActiveSupport.halt_callback_chains_on_return_false` shim
  was removed in Rails 5.2. The `before_save`/`before_destroy :unlocked?`
  callbacks therefore no longer prevented saving or deleting a *locked* rate
  (a rate with time entries), silently defeating the plugin's rate-locking
  feature and the controller error handling that expects `update`/`destroy` to
  return `false` for locked rates.
  A dedicated private callback `ensure_unlocked` now does `throw :abort if locked?`.
  The public `unlocked?`/`locked?` predicates are unchanged, so controllers and
  views keep working. Cost-cache recalculation is unaffected because it uses
  `update_columns`, which bypasses callbacks.

- **Plugin settings are persisted as a plain Hash, not `ActionController::Parameters`**
  (`Rate.store_cache_timestamp` in `app/models/rate.rb`).
  `RedmineRate.settings` wraps the stored setting in `ActionController::Parameters`.
  Writing that object straight back into `Setting.plugin_redmine_rate` embedded a
  `Parameters` instance in the serialized setting. Rails 7.1+ (Redmine 6.1/7.0)
  deserializes settings through YAML safe-load, which rejects the `Parameters`
  class and would raise when the setting is read back. The merged value is now
  converted with `to_unsafe_h` before being stored, matching how the normal
  settings form already saves a plain hash.

### Changed

- Bumped plugin version to `1.2.0` and documented the supported Redmine/Rails
  matrix in `init.rb` and `README.rdoc`. The `requires_redmine` lower bound stays
  at `5.0.0`, which already permits installation on 6.1 and 7.0.

### Known pre-existing limitations (not introduced by 6.x/7.0, left unchanged)

These predate the Rails 6.1 baseline and are out of scope for this minimal
compatibility update; they are recorded here so they are not mistaken for
regressions:

- The XML API responses (`format.xml { render xml: ... }` in
  `RatesController`) rely on `ActiveModel`/`ActiveRecord#to_xml`, which was
  extracted out of Rails core into the `activemodel-serializers-xml` gem back in
  Rails 5. These endpoints require that gem to be present; the JSON/HTML paths
  and the `Rate.for` Ruby API are unaffected.
- The inline "set rate" form in `app/views/users/_membership_rate.html.erb` uses
  `<% form_for ... %>` (statement, not `<%= ... %>` output) and so renders no
  markup. Rates can still be managed from the Rate History form.
