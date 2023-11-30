module RedmineRate
  module Hooks
    class RedmineRateHookListenerk < Redmine::Hook::ViewListener
      render_on(:view_timelog_edit_form_bottom, partial: 'timelog/rate_form')
      render_on(:view_issue_timelog_edit_form_bottom, partial: 'timelog/rate_form')
      render_on(:view_users_memberships_table_header, partial: 'principal_memberships/rate_table_header')
      render_on(:view_projects_settings_members_table_header, partial: 'principal_memberships/rate_table_header')
      render_on(:view_users_memberships_table_row, partial: 'users/membership_rate')
      render_on(:view_projects_settings_members_table_row, partial: 'users/rate_table_row')
      render_on(:view_time_entries_bulk_edit_details_bottom, partial: 'change_billable_bulk')

      def model_project_copy_before_save(context = {})
        source = context[:source_project]
        destination = context[:destination_project]

        Rate.where(project_id: source.id).each do |source_rate|
          destination_rate = Rate.new

          destination_rate.attributes = source_rate.attributes.except('project_id')
          destination_rate.project = destination
          destination_rate.save # Need to save here because there is no relation on project to rate
        end
      end
    end
  end
end
