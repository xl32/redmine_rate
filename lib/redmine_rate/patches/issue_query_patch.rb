module RedmineRate
  module Patches
    module IssueQueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :available_columns_without_rate, :available_columns
          alias_method :available_columns, :available_columns_with_rate
        end
      end

      module InstanceMethods
        def available_columns_with_rate
          return @available_columns if @available_columns
          available_columns_without_rate

          # insert the column after total_estimated_hours or at the end
          index = @available_columns.find_index { |column| column.name == :total_spent_hours }
          index = (index ? index + 1 : -1)

          @available_columns.insert index, QueryColumn.new(:cost,
                                                           sortable: "COALESCE((SELECT SUM(#{TimeEntry.table_name}.cost)
                                                                      FROM #{TimeEntry.table_name}
                                                                      WHERE #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id), 0)",
                                                           default_order: 'desc',
                                                           caption: :field_cost,
                                                           totalable: true)
          @available_columns.insert index + 1, QueryColumn.new(:total_cost,
                                                               sortable: "COALESCE((SELECT SUM(cost)
                                                                          FROM #{TimeEntry.table_name} JOIN #{Issue.table_name} subtasks
                                                                            ON subtasks.id = #{TimeEntry.table_name}.issue_id
                                                                          WHERE subtasks.root_id = #{Issue.table_name}.root_id
                                                                          AND subtasks.lft >= #{Issue.table_name}.lft
                                                                          AND subtasks.rgt <= #{Issue.table_name}.rgt), 0)",
                                                               default_order: 'desc',
                                                               caption: :label_total_cost)
        end

        # Returns sum of all the issue's time entries hours
        def total_for_cost(scope)
          total = if group_by_column.try(:name) == :project
                    # TODO: remove this when https://github.com/rails/rails/issues/21922 is fixed
                    # We have to do a custom join without the time_entries.project_id column
                    # that would trigger a ambiguous column name error
                    scope.joins("JOIN (SELECT issue_id, cost FROM #{TimeEntry.table_name}) AS joined_time_entries
                                ON joined_time_entries.issue_id = #{Issue.table_name}.id")
                         .sum('joined_time_entries.cost')
                  else
                    scope.joins(:time_entries).sum("#{TimeEntry.table_name}.cost")
                  end
          map_total(total) { |t| t.to_f.round(2) }
        end
      end
    end
  end
end

unless IssueQuery.included_modules.include?(RedmineRate::Patches::IssueQueryPatch)
  IssueQuery.send(:include, RedmineRate::Patches::IssueQueryPatch)
end
