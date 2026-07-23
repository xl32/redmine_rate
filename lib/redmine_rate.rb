module RedmineRate
  class << self
    def settings
      ActionController::Parameters.new(Setting[:plugin_redmine_rate])
    end

    def setting?(value)
      return true if settings[value].to_i == 1

      false
    end

    # Loads the plugin's patches, helpers and hooks and registers the Deface
    # overrides path.
    #
    # This is called from init.rb, which Redmine executes inside a `to_prepare`
    # block, so it runs at boot in every environment. The previous approach --
    # a top-level `Rails.configuration.to_prepare` in this file -- only worked
    # when the plugin lib was eager loaded (production): with eager_load
    # disabled (development and test) this file was merely autoloaded lazily, so
    # the block never registered in time and TimeEntry/Issue/etc. were left
    # unpatched.
    def setup!
      # Referencing each constant makes Zeitwerk load its file; the file body
      # applies the patch to its target class (or self-registers, for the
      # helpers module and the hook listener). require/require_dependency can't
      # be used here: the plugin lib is on Zeitwerk's autoload path, not $LOAD_PATH.
      [
        Patches::IssuePatch,
        Patches::IssueQueryPatch,
        Patches::TimeEntryPatch,
        Patches::TimeEntryQueryPatch,
        Patches::TimeReportPatch,
        Patches::UsersHelperPatch,
        Patches::QueriesHelperPatch,
        Helpers,
        Hooks
      ].each(&:name)

      register_overrides_path
    end

    private

    # include deface overwrites
    def register_overrides_path
      Rails.application.paths['app/overrides'] ||= []
      dir = "#{Redmine::Plugin.directory}/redmine_rate/app/overrides".freeze
      return if Rails.application.paths['app/overrides'].include?(dir)

      Rails.application.paths['app/overrides'] << dir
    end
  end
end
