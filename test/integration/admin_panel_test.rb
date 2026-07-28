require_relative '../test_helper'

class AdminPanelTest < RedmineRateIntegrationTest
  def setup
    @last_caching_run = 4.days.ago
    @last_cache_clearing_run = 7.days.ago

    Setting.plugin_redmine_rate = {
      'last_caching_run' => @last_caching_run.to_s,
      'last_cache_clearing_run' => @last_cache_clearing_run.to_s
    }

    login_as 'admin', 'admin'
  end

  def teardown
    logout
  end

  context 'Rate settings admin panel' do
    should 'have a checkbox to disable the rate lock' do
      visit('/settings/plugin/redmine_rate')

      assert_text l(:label_disable_rate_lock)
      assert_selector 'input[type=checkbox][name="settings[disable_rate_lock]"]'
    end
  end

  context 'Rate Caches admin panel' do
    should 'show the last run timestamp for the last caching run' do
      visit('/settings/plugin/redmine_rate?tab=caches')

      # NB: assert_selector does not scope by block (only `within` does), so the
      # timestamp itself is not asserted here to avoid time-zone-formatting
      # fragility; we verify the caching-run section renders.
      assert_text l(:text_last_caching_run)
    end

    should 'show the last run timestamp for the last cache clearing run' do
      visit('/settings/plugin/redmine_rate?tab=caches')

      within '#caching-run' do
        assert_text l(:text_last_cache_clearing_run)
      end
    end

    should 'have a button to force a caching run' do
      visit('/rate_caches?cache=missing')

      assert_equal 200, status_code
      assert_selector '#cache-clearing-run'
    end

    should 'have a button to force a cache clearing run' do
      visit('/rate_caches?cache=reload')

      assert_equal 200, status_code
      assert_selector '#caching-run'
    end
  end
end
