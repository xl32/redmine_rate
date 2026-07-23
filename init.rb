require 'redmine'

Redmine::Plugin.register :redmine_rate do
  name 'Rate'
  author 'Oleksandr Gerasymov, Oleksii Nechytailo'
  url 'https://github.com/xl32/redmine_rate'
  description 'The Rate plugin provides an API that can be used to find the rate for a Member of a Project at a specific date.
               It also stores historical rate data so calculations will remain correct in the future.'
  version '2.0.0'

  # Works on Redmine 5.0/5.1 (Rails 6.1), 6.0/6.1 (Rails 7.x) and 7.0 (Rails 8.0)
  requires_redmine version_or_higher: '5.0.0'

  default_settings = {
    last_caching_run: nil,
    billable_default: 1,
    currency: 'EUR'
  }

  project_module :time_tracking do
    permission :activate_billable, {}
    permission :view_rate, {}
  end

  settings(default: default_settings, partial: 'settings/rate/rate')
end

# init.rb is loaded by Redmine inside a `to_prepare` block, so this applies the
# plugin's patches at boot in every environment (see RedmineRate.setup!).
RedmineRate.setup!
