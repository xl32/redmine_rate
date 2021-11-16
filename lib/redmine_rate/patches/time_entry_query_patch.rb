module RedmineRate
  module Patches
    module TimeEntryQueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :initialize_available_filters_without_rate, :initialize_available_filters
          alias_method :initialize_available_filters, :initialize_available_filters_with_rate
          alias_method :available_columns_without_rate, :available_columns
          alias_method :available_columns, :available_columns_with_rate
        end
      end

      module InstanceMethods
        def available_columns_with_rate
          if @available_columns.blank?
            @available_columns = available_columns_without_rate
            @available_columns << QueryColumn.new(:cost,
                                                  sortable: "#{TimeEntry.table_name}.cost",
                                                  totalable: true)
            @available_columns << QueryColumn.new(:billable,
                                                  sortable: "#{TimeEntry.table_name}.billable")
          else
            available_columns_without_rate
          end
          @available_columns
        end

        def initialize_available_filters_with_rate
          initialize_available_filters_without_rate

          add_available_filter('cost', name: l(:field_cost), type: :float) unless available_filters.key?('cost')
          return if available_filters.key?('billable')

          add_available_filter('billable',
                               name: l(:field_billable),
                               type: :list,
                               values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']])
        end

        def total_for_cost(scope)
          map_total(scope.sum(:cost)) { |t| t.to_f.round(2) }
        end
      end
    end
  end
end

unless TimeEntryQuery.included_modules.include?(RedmineRate::Patches::TimeEntryQueryPatch)
  TimeEntryQuery.send(:include, RedmineRate::Patches::TimeEntryQueryPatch)
end
