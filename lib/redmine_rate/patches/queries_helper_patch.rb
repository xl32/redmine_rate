module RedmineRate
  module Patches
    # Overwrite QueriesHelper
    module QueriesHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :column_value_without_rate, :column_value
          alias_method :column_value, :column_value_with_rate
        end
      end

      # Instance methods to add customize values
      module InstanceMethods
        def column_value_with_rate(column, list_object, value)
          if column.name == :cost && list_object.is_a?(TimeEntry)
            show_number_with_currency value
          elsif column.name == :costs && list_object.is_a?(Issue)
            show_number_with_currency value
          else
            column_value_without_rate(column, list_object, value)
          end
        end
      end
    end
  end
end

unless QueriesHelper.included_modules.include?(RedmineRate::Patches::QueriesHelperPatch)
  QueriesHelper.send(:include, RedmineRate::Patches::QueriesHelperPatch)
end
