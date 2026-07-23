unless ENV['SKIP_COVERAGE']
  begin
    require 'simplecov'
    formatters = [SimpleCov::Formatter::HTMLFormatter]
    begin
      require 'simplecov-rcov'
      formatters << SimpleCov::Formatter::RcovFormatter
    rescue LoadError
      # simplecov-rcov is optional
    end
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(formatters)

    SimpleCov.start :rails do
      add_filter 'init.rb'
      root File.expand_path(File.dirname(__FILE__) + '/..')
    end
  rescue LoadError
    # simplecov not installed; run without coverage
  end
end

require_relative '../../../test/test_helper'
require_relative '../../../test/object_helpers'
require_relative 'object_helpers'
require 'capybara/rails'
require 'capybara/minitest'

# shoulda-matchers must be wired into the test framework explicitly.
require 'shoulda-matchers'
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

# Rails 7.1+ renamed fixture_path (singular) to fixture_paths (an additive array);
# the singular setter is gone in Rails 7.2 (Redmine 6.1+).
rate_fixtures_dir = File.expand_path("#{File.dirname(__FILE__)}/../../../test/fixtures")
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths |= [rate_fixtures_dir]
else
  ActiveSupport::TestCase.fixture_path = rate_fixtures_dir
end

class ActiveSupport::TestCase
  fixtures :users, :issues, :projects, :time_entries
end

class RedmineRateIntegrationTest < Redmine::IntegrationTest
  include Redmine::I18n
  include Capybara::DSL
  # So Capybara's assert_* count towards Minitest's assertion tally.
  include Capybara::Minitest::Assertions

  # Mirrors Redmine's own Capybara login helper (see
  # test/application_system_test_case.rb#log_user); the login page markup
  # changed in Redmine 6.x (fields are username/password, form is a descendant
  # of #login-form).
  def login_as(user = 'admin', password = 'admin')
    Capybara.reset_sessions!
    visit '/login'

    within('#login-form form') do
      fill_in 'username', with: user
      fill_in 'password', with: password
      find('input[name=login]').click
    end

    assert_current_path '/my/page', ignore_query: true
  end

  def logout
    Capybara.reset_sessions!
  end

  def assert_forbidden
    assert_response :forbidden
    assert_template 'common/error'
  end

  def assert_requires_login
    assert_response :success
    assert_template 'account/login'
  end
end
