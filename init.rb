require 'redmine'

Redmine::Plugin.register :redmine_rate do
  name 'Rate'
  author 'AlphaNodes GmbH, Eric Davis'
  url 'https://github.com/alphanodes/redmine_rate'
  description 'The Rate plugin provides an API that can be used to find the rate for a Member of a Project at a specific date.
               It also stores historical rate data so calculations will remain correct in the future.'
  version '1.0.0'

  requires_redmine version_or_higher: '3.3.0'

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
